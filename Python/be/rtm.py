from typing import List, Dict, Tuple, Optional
import math
from log import Log
import utils
import helper
import networkx as nx

class ReferenceTableItem:
    """Item of reference tables"""
    def __init__(self) -> None:
        self.addr: int = -1
        self.len: int = -1
        # references
        self.refs: List[str] = []
    
    def __str__(self) -> str:
        return f"addr: {self.addr}, len: {self.len}, refs: {self.refs}"
    
    def __repr__(self) -> str:
        return self.__str__() 

def _find_idle_fragments(ref_table: List[ReferenceTableItem]) -> List[Tuple[int, int]]:  # [(addr, len), (addr, len), ...]
    """Find idle fragments in ref_table"""
    ret = []
    if len(ref_table) > 0:
        if len(ref_table) == 1:
            if ref_table[0].addr != 0:
                ret.append((0, ref_table[0].addr))
        else:
            if ref_table[0].addr != 0:
                ret.append((0, ref_table[0].addr))
            for i in range(1, len(ref_table), 1):
                pre, next = ref_table[i-1], ref_table[i]
                idle_size = next.addr-(pre.addr+pre.len)
                if idle_size > 0:
                    ret.append((pre.addr+pre.len, idle_size))
    return ret

def _find_available_idle_fragment(idle_fragments: List[Tuple[int, int]], size: int) -> Optional[Tuple[int, int]]:
    """Find available idle fragment for the given size."""
    for fragment in idle_fragments:
        _, fragment_size = fragment[0], fragment[1]
        if fragment_size > size:
            return fragment
    return None

def _alloc(ref_table: List[ReferenceTableItem], size: int) -> int:
    """Allocate memory for a tensor or vector."""
    # If ref_table if empty, start from the low address
    if len(ref_table) == 0:
        addr = 0
    # Reference table is not empty, use idle fragments or allocate new space
    else:
        idle_fragments = _find_idle_fragments(ref_table)
        # Idle fragments are not found, allocate new space
        if len(idle_fragments) == 0:
            addr = ref_table[-1].addr+ref_table[-1].len
        # Idle fragments exist, try to use idle fragments
        else:
            avai_fragment = _find_available_idle_fragment(idle_fragments, size)
            if avai_fragment is not None:
                addr = avai_fragment[0]
            else:
                addr = ref_table[-1].addr+ref_table[-1].len
    return addr       

def _get_input_tensor_size(INC, INH_, INW_, R, S) -> int:
    """RTM size that should be allocated for the input tensor."""
    fm_height = math.ceil(INH_*INW_/R)
    n_fm_group = math.ceil(INC/S)
    return n_fm_group*fm_height

def _get_input_vertor_size(INC, R, S) -> int:
    """RTM size that should be allocated for the input vector."""
    return math.ceil(INC/(R*S))

def _get_output_tensor_size(OC, OH, OW, M, R, S) -> int:
    """RTM size that should be allocated for an output tensor.
    Note: The number of output channels are required to be a multiple of M."""
    n_w_rnd = math.ceil(OC/M)
    aligned_OC = n_w_rnd*M
    n_fm_group = aligned_OC//S
    fm_height = math.ceil(OH*OW/R)
    return fm_height*n_fm_group

def _get_output_vector_size(OC, R, S) -> int:
    """RTM size that should be allocated for an output vector.
    Note: The length of output vectors are required to be a multiple of 64."""
    n_rnd = math.ceil(OC/64)
    aligned_OC = n_rnd*64
    return math.ceil(aligned_OC/(R*S))

def _get_output_size(graph: nx.DiGraph, exec_seq: List[str], params: dict, M: int, R: int, S: int) -> Dict[str, int]:  # node_name -> size
    """Compute memory sizes of output tensors/vectors for the given graph."""
    ret = {}

    for node_name in exec_seq:
        onnx_node = graph.nodes[node_name]["att_obj"]
        node_params = params[onnx_node.name]
        if onnx_node.op_type == "QLinearConv":
            OC, OH, OW = node_params["OC"], node_params["OH"], node_params["OW"]
            size = _get_output_tensor_size(OC, OH, OW, M, R, S)
        elif onnx_node.op_type == "QGemm":
            OC = node_params["N"]
            size = _get_output_vector_size(OC, R, S)
        elif onnx_node.op_type == "QLinearAdd":
            OC, OH, OW = node_params["A_shape"]
            size = _get_output_tensor_size(OC, OH, OW, M, R, S)
        elif onnx_node.op_type == "QLinearConcat":
            OC, OH, OW = node_params["Y_shape"]
            size = _get_output_tensor_size(OC, OH, OW, M, R, S)
        elif onnx_node.op_type == "QLinearAveragePool":
            OC, OH, OW = node_params["OC"], node_params["OH"], node_params["OW"]
            size = _get_output_tensor_size(OC, OH, OW, M, R, S)
        elif onnx_node.op_type == "QLinearGlobalAveragePool":
            OC, OH, OW = node_params["OC"], node_params["OH"], node_params["OW"]
            size = _get_output_tensor_size(OC, OH, OW, M, R, S)
        elif onnx_node.op_type == "MaxPool":
            OC, OH, OW = node_params["OC"], node_params["OH"], node_params["OW"]
            size = _get_output_tensor_size(OC, OH, OW, M, R, S)
        else:
            raise ValueError(f"Unsupported node {onnx_node.name} with type {onnx_node.op_type}.")
        if size > 0:
            ret[onnx_node.name] = size
    return ret

def _find_concat_pattern(graph: nx.DiGraph, exec_seq: List[str]) -> Dict[str, List[str]]:  # (concat_node_name, previous nodes)
    """Find concat nodes and their predecessors from the given graph."""
    ret = {}
    for node_name in exec_seq:
        onnx_node = graph.nodes[node_name]["att_obj"]
        if onnx_node.op_type == "QLinearConcat":
            predecessors = list(graph.predecessors(node_name))
            ret[node_name] = predecessors
    return ret

def _is_concat_input(graph: nx.DiGraph, node_name: str) -> Tuple[bool, str]:  # succ, concat_node
    """Whether the given node is a predecessor to a concat node."""
    for successor in graph.successors(node_name):
        onnx_node = graph.nodes[successor]["att_obj"]
        if onnx_node.op_type == "QLinearConcat":
            return True, successor
    return False, ""

def _get_memory_mode(
    graph: nx.DiGraph,
    exec_seq: List[str],
    params: dict
) -> Dict[str, str]:  # node_name -> mode
    """Assign memory mode for each tensor/vector."""
    ret = {}
    
    # Input
    input_shape = helper.find_input_shape(graph, params)
    if len(input_shape) == 3:
        ret["input"] = "T-mode"
    else:
        ret["input"] = "V-mode"
    
    # Nodes
    for node_name in exec_seq:
        onnx_node = graph.nodes[node_name]["att_obj"]
        if onnx_node.op_type in ("QLinearConv", "QLinearAveragePool", "MaxPool", "QLinearGlobalAveragePool", "QLinearConcat", "QLinearAdd"):
            ret[node_name] = "T-mode"
        elif onnx_node.op_type in ("QGemm"):
            ret[node_name] = "V-mode"
        else:
            raise ValueError(f"Unsupported node {node_name} with type {onnx_node.op_type}.")
    return ret

def malloc(
    graph: nx.DiGraph,
    exec_seq: List[str],
    params: dict,
    M: int, R: int, S: int
) -> Dict[str, Tuple[str, int, int]]:  # node_name -> (mode, addr, size)
    """Allocate memory for all tensors/vectors."""
    Log.i("RTM: Start running.")
    ret = {}
    ref_table = []
    concat_patterns = _find_concat_pattern(graph, exec_seq)
    output_sizes = _get_output_size(graph, exec_seq, params, M, R, S)

    # Input tensor/vector
    input_shape = helper.find_input_shape(graph, params)
    rti = ReferenceTableItem()
    rti.addr = 0
    if len(input_shape) == 3:
        rti.len = _get_input_tensor_size(*input_shape, R, S)
    else:
        rti.len = _get_input_vertor_size(*input_shape, R, S)
    rti.refs.append(utils.dag_get_input_nodes(graph)[0])
    ref_table.append(rti)
    ret.update({"input": ("", 0, rti.len)})

    for node_name in exec_seq:
        Log.i(f"RTM: Allocate memory for output tensor/vector of {node_name}.")

        # 1. Allocate memory
        onnx_node = graph.nodes[node_name]["att_obj"]
        out_size = output_sizes[node_name]
        # 1.1 Concat node, used the address of the first predecessor
        if onnx_node.op_type == "QLinearConcat":
            parents = concat_patterns[node_name]
            addr = ret[parents[0]][1]
        # 1.2 Not concat node, find idle spaces from low address
        else:
            # 1.2.1 Predecessor of concat node
            succ, concat_node_name = _is_concat_input(graph, node_name)
            if succ:
                # If this is the first predecessor of this concate node, allocate memory for this concat node
                if node_name == concat_patterns[concat_node_name][0]:
                    addr = _alloc(ref_table, output_sizes[concat_node_name])
                # If this is not the first predecessor, use the allocated memory directly.
                else:
                    concat_idx = concat_patterns[concat_node_name].index(node_name)
                    prev_node_name = concat_patterns[concat_node_name][concat_idx-1]
                    addr = ret[prev_node_name][1]+output_sizes[prev_node_name]
            else:
                addr = _alloc(ref_table, out_size)
        ret.update({node_name: ("", addr, out_size)})

        # 2. Add reference to allocated memory segment
        succ, _ = _is_concat_input(graph, node_name)
        if not succ:
            successors = list(graph.successors(node_name))
            if len(successors) > 0:
                rti = ReferenceTableItem()
                rti.addr = addr
                rti.len = out_size
                rti.refs.extend(successors)
                ref_table.append(rti)

        # 3. Update reference table
        removed_rtis = []
        for i in range(len(ref_table)):
            rti = ref_table[i]
            if node_name in rti.refs:
                rti.refs.remove(node_name)
            # Removed item
            if len(rti.refs) == 0:
                removed_rtis.append(rti)
        for rti in removed_rtis:
            ref_table.remove(rti)

        # 4. Sort
        ref_table.sort(key=lambda it: it.addr)

    # Assign memory mode
    Log.i("RTM: Start assigning memory mode for vectors/tensors.")
    modes = _get_memory_mode(graph, exec_seq, params)
    for k, v in ret.items():
        ret.update({k: (modes[k], v[1], v[2])})

    Log.i("RTM: Done.")
    return ret
