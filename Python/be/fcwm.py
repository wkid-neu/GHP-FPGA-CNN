from typing import Dict, List, Tuple
from log import Log
import networkx as nx

def get_fc_weight_size(OC, INC):
    """Fc weight size in DRAM."""
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
    return size

def malloc(
    graph: nx.DiGraph,
    exec_seq: List[str],
    params: dict
) -> Dict[str, Tuple[int, int]]:  # node_name -> (addr_in_dram, len_in_dram)
    """Allocation memory for Fc weights."""
    Log.i("FCWM: Start running.")
    ret = {}
    addr = 0
    for node_name in exec_seq:
        onnx_node = graph.nodes[node_name]["att_obj"]
        node_params = params[node_name]
        if onnx_node.op_type == "QGemm":
            OC, INC = node_params["N"], node_params["K"]
            size = get_fc_weight_size(OC, INC)
            ret[node_name] = (addr, size)
            addr += size
    Log.i("FCWM: Done.")
    return ret
