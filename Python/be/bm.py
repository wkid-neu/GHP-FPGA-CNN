from typing import Dict, List, Tuple
import networkx as nx
from log import Log

def get_conv_bias_size(OC, M):
    """Compute memory size for convolution bias."""
    # OC must be multiple of 2M
    if OC%(M*2) != 0:
        aligned_OC = (OC//(M*2)+1)*(M*2)
    else:
        aligned_OC = OC
    return aligned_OC//16

def get_fc_bias_size(OC):
    """Compute memory size for fully-connected bias."""
    # OC must be multiple of 64
    if OC%64 != 0:
        aligned_OC = (OC//64+1)*64
    else:
        aligned_OC = OC
    return aligned_OC//16

def malloc(
    graph: nx.DiGraph,
    exec_seq: List[str],
    params: dict,
    M: int
) -> Dict[str, Tuple[int, int]]:  # node_name -> (address, length)
    """Allocate memory for bias tensors."""
    Log.i("BM: Start running.")
    ret = {}
    addr = 0
    for node_name in exec_seq:
        onnx_node = graph.nodes[node_name]["att_obj"]
        node_params = params[node_name]
        if onnx_node.op_type == "QGemm":
            OC = node_params["N"]
            size = get_fc_bias_size(OC)
        elif onnx_node.op_type == "QLinearConv":
            OC = node_params["OC"]
            size = get_conv_bias_size(OC, M)
        else:
            continue
        ret[node_name] = (addr, size)
        addr += size
    Log.i("BM: Done.")
    return ret
