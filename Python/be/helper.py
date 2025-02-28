from typing import Tuple
from onnx import GraphProto
import networkx as nx
import utils

def conv_params_alignment(OC, INC, KH, KW, M, S) -> Tuple[int, int]:  # aligned_OC, aligned_INC 
    """Parameters aligment for Conv."""
    # OC must be multiple of 2M
    if OC%(M*2) != 0:
        aligned_OC = (OC//(M*2)+1)*(M*2)
    else:
        aligned_OC = OC
    # INC must be multiple of S
    # Vector size must be a multiple of 8
    # Vector size must be larger than M.
    aligned_INC = INC
    while (aligned_INC*KH*KW < M) or ((aligned_INC*KH*KW)%8 != 0) or (aligned_INC%S != 0):
        aligned_INC += 1
    return aligned_OC, aligned_INC

def pool_params_alignment(INC, S) -> int:  # aligned_INC
    """Parameters aligment for MaxPool/AvgPool."""
    if INC%S != 0:
        aligned_INC = (INC//S+1)*S
    else:
        aligned_INC = INC
    return aligned_INC

def fc_params_alignment(OC, INC) -> Tuple[int, int]:  # aligned_OC, aligned_INC 
    """Parameters aligment for Fc."""
    # OC must be multiple of 64
    if OC%64 != 0:
        aligned_OC = (OC//64+1)*64
    else:
        aligned_OC = OC
    # INC must be at least 32
    if INC < 32:
        aligned_INC = 32
    else:
        aligned_INC = INC
    # weight size must be smaller than 1<<27
    size = aligned_OC*aligned_INC
    assert size<(1<<27), f"Weight size must be smaller than 2**27, required: {size}, OC: {aligned_OC}, INC: {aligned_INC}"
    return aligned_OC, aligned_INC 

def find_input_shape(graph: nx.DiGraph, params: dict) -> tuple:
    """Find the shape of the input tensor/vector.
    Return (INC, INH_, INW_) if the input is a 3D tensor, or (INC) if the input is a 1D vector.
    """
    # Find the input node
    node_name = utils.dag_get_input_nodes(graph)
    assert len(node_name) == 1, f"Unsupported DAG with {len(node_name)} input node(s), node(s): {node_name}."
    node_name = node_name[0]
    # Find the input tensor/vector shape
    onnx_node = graph.nodes[node_name]["att_obj"]
    node_params = params[node_name]
    if onnx_node.op_type in ("QLinearConv", "QLinearAveragePool", "MaxPool", "QLinearGlobalAveragePool"):
        return (node_params["INC"], node_params["INH_"], node_params["INW_"])
    elif onnx_node.op_type in ("QGemm"):
        return (node_params["K"])
    else:
        raise ValueError(f"Unsupported input node {node_name} with type {onnx_node.op_type}.")

def find_quan_params(onnx_graph: GraphProto) -> Tuple[float, int, float, int]:  # input_s, input_z, output_s, output_z
    """Find the quantization parameters for the input and output tensor/vector."""
    # Build DAG
    graph = utils.onnx_to_dag(onnx_graph)
    # Find the input node
    first_node = []
    for node, attr in graph.nodes.items():
        if graph.in_degree(node) == 0:
            first_node.append(node)
    assert len(first_node) == 1, f"Unsupported DAG with {len(first_node)} input node(s), node(s): {first_node}."
    first_node = first_node[0]
    onnx_node = graph.nodes[first_node]["att_obj"]
    assert onnx_node.op_type == "QuantizeLinear", f"The input node must be QuantizeLinear, current is {onnx_node.op_type}."
    input_s = utils.onnx_find_tensor_by_name(onnx_graph, onnx_node.input[1])
    input_z = utils.onnx_find_tensor_by_name(onnx_graph, onnx_node.input[2])
    # Find the output node
    last_node = []
    for node, attr in graph.nodes.items():
        if graph.out_degree(node) == 0:
            last_node.append(node)
    assert len(last_node) == 1, f"Unsupported DAG with {len(last_node)} output node(s), node(s): {last_node}."
    last_node = last_node[0]
    # The last node must be DequantizeLinear
    onnx_node = graph.nodes[last_node]["att_obj"]
    assert onnx_node.op_type == "DequantizeLinear", f"The output node must be QuantizeLinear, current is {onnx_node.op_type}."
    output_s = utils.onnx_find_tensor_by_name(onnx_graph, onnx_node.input[1])
    output_z = utils.onnx_find_tensor_by_name(onnx_graph, onnx_node.input[2])

    return float(input_s), int(input_z), float(output_s), int(output_z)

