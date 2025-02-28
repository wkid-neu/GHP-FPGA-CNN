from typing import Dict, List, Tuple
import networkx as nx
from log import Log

class DramAllocRes:
    def __init__(self) -> None:
        self.sta_conv_weight_desc: Tuple[int, int] = (-1,-1)
        self.dyn_conv_weight_desc: Tuple[int, int] = (-1,-1)
        self.fc_weight_desc: Tuple[int, int] = (-1,-1)
        self.bias_desc: Tuple[int, int] = (-1,-1)
        self.ins_desc: Tuple[int, int] = (-1,-1)
        self.xphs_desc: Tuple[int, int] = (-1,-1)
        self.input_desc: Tuple[int, int] = (-1,-1)
        self.output_desc: Tuple[int, int] = (-1,-1)

def malloc(
    graph: nx.DiGraph,
    exec_seq: List[str],
    cwm_res: Dict[str, Tuple[bool, int, int]],
    fcwm_res: Dict[str, Tuple[int, int]],
    bm_res: Dict[str, Tuple[int, int]],
    xphm_res: Dict[str, Tuple[int, int]],
    rtm_res: Dict[str, Tuple[str, int, int]], 
    M: int, R: int, S: int
) -> DramAllocRes:
    """sta_conv_weights, dyn_conv_weights, fc_weights, bias, instructions, pkt_headers, input, output"""
    Log.i("DRAM: Start running.")
    ret = DramAllocRes()
    addr = 0x80000000

    # Convlution weights
    conv_sta_len, conv_dyn_len = 0, 0  # number of bytes
    for k, v in cwm_res.items():
        if v[0]: 
            conv_sta_len += v[2]*4*M
        else: 
            conv_dyn_len += v[2]
    ret.sta_conv_weight_desc = (addr, conv_sta_len)
    addr += conv_sta_len
    Log.i(f"DRAM: Allocate memory for static convolution weights, result -> {ret.sta_conv_weight_desc}.")
    ret.dyn_conv_weight_desc = (addr, conv_dyn_len)
    addr += conv_dyn_len
    Log.i(f"DRAM: Allocate memory for dynamic convolution weights, result -> {ret.dyn_conv_weight_desc}.")

    # Fully-connected weights
    size = sum([v[1] for k, v in fcwm_res.items()])
    ret.fc_weight_desc = (addr, size)
    addr += size
    Log.i(f"DRAM: Allocate memory for Fully-connected weights, result -> {ret.fc_weight_desc}.")

    # Bias
    size = sum([v[1] for k, v in bm_res.items()])*64
    ret.bias_desc = (addr, size)
    addr += size
    Log.i(f"DRAM: Allocate memory for bias, result -> {ret.bias_desc}.")

    # Instructions
    n_ins = 1  # The end instruction should also be counted.
    for node_name in exec_seq:
        onnx_node = graph.nodes[node_name]["att_obj"]
        if onnx_node.op_type != "QLinearConcat":
            n_ins += 1
        else:
            # Additional (N-1) Remap instructions
            N = len(list(graph.predecessors(node_name)))
            n_ins += (N-1)
    size = n_ins*64
    ret.ins_desc = (addr, size)
    addr += size
    Log.i(f"DRAM: Allocate memory for instructions., result -> {ret.ins_desc}")

    # X packet headers
    size = sum([v[1] for k, v in xphm_res.items()])*64
    ret.xphs_desc = (addr, size)
    addr += size
    Log.i(f"DRAM: Allocate memory for X packet headers, result -> {ret.xphs_desc}.")

    # Input tensor
    size = rtm_res["input"][2]*(R*S)
    ret.input_desc = (addr, size)
    addr += size
    Log.i(f"DRAM: Allocate memory for input image, result -> {ret.input_desc}.")

    # Output tensor
    last_vertex = exec_seq[-1]
    size = rtm_res[last_vertex][2]*(R*S)
    ret.output_desc = (addr, size)
    Log.i(f"DRAM: Allocate memory for outputs, result -> {ret.output_desc}.")

    Log.i("DRAM: Done.")
    return ret
