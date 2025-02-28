from typing import Tuple, Optional, List, Union
import numpy as np
import torch
import networkx as nx
from onnx import GraphProto, NodeProto, AttributeProto, ValueInfoProto, numpy_helper, TensorProto
import math

#
# Common 
#
def topk(a: np.ndarray, k: int, axis=-1):
    """The indices of topk elements."""
    if axis is None:
        axis_size = a.size
    else:
        axis_size = a.shape[axis]
    index_array = np.argpartition(a, axis_size - k, axis=axis)
    topk_indices = np.take(index_array, -np.arange(k) - 1, axis=axis)
    return topk_indices

def quantize_M(
    M: float,
    n_bits: int
) -> Tuple[int,int]:  # n, m
    """Quantize floating-point data M in the form of M=m*(2**(-n))."""
    n = 0
    M0 = M
    while M0 < (2**n_bits):
        M0 = M0 * 2
        n += 1
    qM0 = round(M0/2)
    return n-1, qM0

def dequantize_M(
    n: int, m: int
) -> float:
    """Dequantization of fixed point data."""
    return m/(2**n)

def quantize_M_list(
    M_list: List[float],
    n_bits: int
) -> Tuple[int,Tuple[int,int]]: # n, (m1, m2, ...)
    """A batch of M which have the same exponent."""

    n = 0
    m_list = M_list
    while max(m_list) < (2**n_bits):
        m_list = [it*2 for it in m_list]
        n += 1
    qm_list = [round(it/2) for it in m_list]
    return n-1, qm_list

def quant(
    t: np.ndarray,
    scale: int, zero_point: int,
    n_bits: int = 8,
    signed: bool = False
):
    """Quantization"""
    new_t = np.divide(t, scale)
    new_t = np.round(new_t)
    new_t = np.add(new_t, zero_point)
    if signed:
        min_, max_ = -2**(n_bits-1), (2**(n_bits-1))-1
    else:
        min_, max_ = 0, (2**n_bits)-1
    new_t = np.clip(new_t, min_, max_)
    return new_t.astype(np.int64)

def dequant(
    t: np.ndarray,
    scale: int, zero_point: int
) -> np.ndarray:
    """De-quantization"""
    new_t = np.subtract(t, scale)
    new_t = np.multiply(new_t, zero_point)
    return new_t 

def quant_auto(
    t: np.ndarray,
    n_bits: int = 8,
    signed: bool = False
) -> Tuple[np.ndarray, float, int]:
    min_, max_ = t.min(), t.max()
    scale = (max_-min_)/255
    zero_point = round(-min_/scale)
    if zero_point < 0:
        zero_point = 0
    if zero_point > 255:
        zero_point = 255
    qt = quant(t, scale, zero_point, n_bits, signed)
    return qt, scale, zero_point

def im2col(
    im: torch.Tensor,
    KH: int, KW: int,
    strideH: int, strideW: int,
    padL: int, padR: int, padU: int, padD: int,
    pad_const: int = 0
) -> torch.Tensor:
    """Image to column vectors"""
    m = torch.nn.ConstantPad2d(
        padding=(padL, padR, padU, padD),
        value=pad_const
    )
    ret = m(im)
    m = torch.nn.Unfold(
        kernel_size=(KH, KW),
        padding=(0, 0),
        stride=(strideH, strideW)
    )
    ret = m(ret)
    return ret

#
# ONNX
#
def onnx_find_node_by_name(
    graph: GraphProto,
    node_name: str
) -> Optional[NodeProto]:
    """Find a node based on the node_name."""
    for node in graph.node:
        if node.name == node_name:
            return node
    return None

def onnx_find_attr_by_name(
    node: NodeProto,
    attr_name: str
) -> Optional[AttributeProto]:
    """Find an attribute of the given node based on attr_name."""
    for attr in node.attribute:
        if attr.name == attr_name:
            return attr
    return None

def onnx_find_tensor_by_name(
    graph: GraphProto,
    tensor_name: str,
    return_raw_obj: bool = False
) -> Optional[Union[np.ndarray, NodeProto]]:
    """Find a tensor from the initializer of the onnx graph based on tensor_name."""
    for tensor in graph.initializer:
        if tensor.name == tensor_name:
            if return_raw_obj:
                return tensor
            else:
                return numpy_helper.to_array(tensor)
    return None

def onnx_get_tensor_shape_by_value_info(
    value_info: ValueInfoProto
) -> List[int]:
    """Find the shape of the given tensor."""
    ret = []
    for _dim in value_info.type.tensor_type.shape.dim:
        if _dim.dim_value == 0:
            ret.append(_dim.dim_param)
        else:
            ret.append(_dim.dim_value)
    return ret

def onnx_find_parents(
    src_node: NodeProto,
    graph: GraphProto
) -> List[NodeProto]:
    """Find parent nodes for the given node in ONNX graph."""
    ret = []
    for input_tensor_name in src_node.input:
        for dst_node in graph.node:
            for output_tensor_name in dst_node.output:
                if output_tensor_name == input_tensor_name:
                    ret.append(dst_node)
                    break
    return ret

def onnx_find_children(
    src_node: NodeProto,
    graph: GraphProto
) -> List[NodeProto]:
    """Find child nodes for the given node in ONNX graph."""
    ret = []
    for output_tensor_name in src_node.output:
        for dst_node in graph.node:
            for input_tensor_name in dst_node.input:
                if output_tensor_name == input_tensor_name:
                    ret.append(dst_node)
                    break
    return ret

def onnx_to_dag(graph: GraphProto) -> nx.DiGraph:
    """ONNX graph to DAG"""
    def find_in_vertices(_node, _nodes):
        """Find input vertices of the given node."""
        _onnx_node_inputs = _node.input
        if len(_onnx_node_inputs) == 0:
            return []
        ret = []
        for _node in _nodes:
            for _node_output in _node.output:
                if _node_output in _onnx_node_inputs:
                    ret.append(_node.name)
        return ret

    ret = nx.DiGraph()
    # Nodes
    for node in graph.node:
        ret.add_node(node.name, att_obj=node)
    # Edges
    for node in graph.node:
        in_vertices = find_in_vertices(node, graph.node)
        if len(in_vertices) > 0:
            for in_vertex in in_vertices:
                ret.add_edge(in_vertex, node.name)
    return ret

def dag_get_input_nodes(dag: nx.DiGraph) -> List[str]:
    """Find input nodes of the given DAG.
    Input nodes are nodes whose in_degree is 0."""
    ret = []
    for node, attr in dag.nodes.items():
        if dag.in_degree(node) == 0:
            ret.append(node)
    return ret

def visualize_dag(dag: nx.DiGraph, file_path: str):
    """Visualization of DAG."""
    import graphviz

    dot = graphviz.Digraph()
    for node, _ in dag.nodes.items():
        dot.node(node, node)
    for edge, _ in dag.edges.items():
        dot.edge(edge[0], edge[1])
    dot.render(file_path, view=False, cleanup=True, format="png")

#
# Conv dimension
#
def conv_get_ofm_shape(
    INH_: int, INW_: int,
    KH: int, KW: int,
    strideH: int, strideW: int,
    padL: int, padR: int, padU: int, padD: int,
    ceil_mode: bool = False,
    dilationH: int = 1, dilationW: int = 1
) -> Tuple[int, int]:
    """Calculate the shape of output feature map."""
    if not ceil_mode:
        OH = math.floor((INH_+padU+padD-((KH-1)*dilationH+1))/strideH+1)
        OW = math.floor((INW_+padL+padR-((KW-1)*dilationW+1))/strideW+1)
    else:
        OH = math.ceil((INH_+padU+padD-((KH-1)*dilationH+1))/strideH+1)
        OW = math.ceil((INW_+padL+padR-((KW-1)*dilationW+1))/strideW+1)
    return OH, OW

def pool_ceil_mode_to_pads(
    INH_: int, INW_: int,
    KH: int, KW: int,
    strideH: int, strideW: int,
    padL: int, padR: int, padU: int, padD: int,
) -> Tuple[int, int, int, int]:  # padL, padR, padU, padD
    """Convert ceil_mode to pads."""
    new_padR = math.ceil((INW_+padL+padR-KW)/strideW)*strideW-INW_-padL+KW
    new_padD = math.ceil((INH_+padU+padD-KH)/strideH)*strideH-INH_-padU+KH
    return padL, new_padR, padU, new_padD
