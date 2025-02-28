from typing import Dict, List, Tuple
import networkx as nx
from log import Log
import math

def _get_xphs_size(OH, OW, P) -> int:
    """Compute memory size for Conv/Pool packtet headers."""
    of_size = OH*OW
    return math.ceil(of_size/P)

def malloc(
    graph: nx.DiGraph,
    exec_seq: List[str],
    params: dict,
    P: int
)-> Dict[str, Tuple[int, int]]:  # node_name -> (address, length)
    """Allocate memory for Conv/Pool packet headers."""
    Log.i("XPHM: Start running.")
    ret = {}
    addr = 0
    for node_name in exec_seq:
        onnx_node = graph.nodes[node_name]["att_obj"]
        node_params = params[node_name]
        if onnx_node.op_type in ("QLinearConv", "QLinearAveragePool", "QLinearGlobalAveragePool", "MaxPool"):
            OH, OW = node_params["OH"], node_params["OW"]
            size = _get_xphs_size(OH, OW, P)
            ret[node_name] = (addr, size)
            addr += size
    Log.i("XPHM: Done.")
    return ret
