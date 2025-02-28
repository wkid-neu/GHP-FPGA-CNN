from typing import List, Union, Dict
from log import Log
import networkx as nx
from onnx import GraphProto
from be.ins import Conv, Add, Remap, INS_CONV, INS_MAXP, INS_AVGP, INS_ADD, INS_REMAP, INS_FC
import numpy as np
import utils
import math
from be import helper
import base

class Xph:
    """X Packet header"""
    def __init__(self) -> None:
        self.X_a_: int = -1  # uint16_t
        self.len_per_chan: int = -1  # uint16_t
        self.win_x: int = -1  # uint16_t
        self.win_y: int = -1  # uint16_t

def _gen_xphs_for_ins (
    INH_, INW_, KH, KW, strideH, strideW,
    padL, padR, padU, padD,
    P, Q
) -> List[Xph]:
    """Generate X packet headers based on the given shape parameters."""
    ret = []

    OH, OW = utils.conv_get_ofm_shape(
        INH_, INW_, KH, KW, strideH, strideW,
        padL, padR, padU, padD
    )
    n_x_rnd = math.ceil(OH*OW/P)

    for x_rnd in range(n_x_rnd):
        xph = Xph()
        in_pos_start, in_pos_end = math.inf, -math.inf
        for p in range(P):
            out_pos = x_rnd*P+p
            if out_pos > OH*OW-1:
                out_pos = OH*OW-1
            out_row, out_col = out_pos//OW, out_pos%OW
            win_y, win_x = out_row*strideH, out_col*strideW
            if p==0:
                xph.win_x = win_x
                xph.win_y = win_y
            for kh in range(KH):
                for kw in range(KW):
                    x, y = win_x+kw, win_y+kh
                    x_,y_ = x-padL, y-padU
                    if x_<0 or x_>INW_-1 or y_<0 or y_>INH_-1:
                        continue
                    in_pos = y_*INW_+x_
                    if in_pos < in_pos_start:
                        in_pos_start = in_pos
                    if in_pos > in_pos_end:
                        in_pos_end = in_pos
        start_a_ = in_pos_start//Q
        start_b_ = in_pos_start%Q
        end_a_ = in_pos_end//Q
        end_b_ = in_pos_end%Q
        xph.X_a_ = start_a_
        xph.len_per_chan = end_a_-start_a_+1
        ret.append(xph)
    return ret

def gen_xphs(
    ins_seq: List[Union[Conv, Add, Remap]],
    params: dict,
    P: int, Q: int
) -> Dict[str, np.ndarray]:  # ins_name -> xphs array
    """Generate X packet headers for each Conv/Pool instruction."""
    Log.i("MemGen: Start generating xphs.")
    ret = {}
    for ins in ins_seq:
        if ins.op_type in (INS_CONV, INS_MAXP, INS_AVGP):
            Log.i(f"MemGen: Generate xphs for {ins.name}.")
            ins_params = params[ins.name]
            INH_, INW_ = ins_params["INH_"], ins_params["INW_"]
            KH, KW, strideH, strideW = ins_params["KH"], ins_params["KW"], ins_params["strideH"], ins_params["strideW"]
            padL, padR, padU, padD = ins_params["padL"], ins_params["padR"], ins_params["padU"], ins_params["padD"]
            xphs = _gen_xphs_for_ins(
                INH_, INW_, KH, KW, strideH, strideW,
                padL, padR, padU, padD,
                P, Q
            )
            arr = np.array([
                [
                    xph.X_a_ & 0x00ff, (xph.X_a_ & 0xff00) >> 8,
                    xph.len_per_chan & 0x00ff, (xph.len_per_chan & 0xff00) >> 8,
                    xph.win_x & 0x00ff, (xph.win_x & 0xff00) >> 8,
                    xph.win_y & 0x00ff, (xph.win_y & 0xff00) >> 8
                ] for xph in xphs
            ]).astype(np.uint8)
            ret[ins.name] = arr
    Log.i("MemGen: Generate xphs successfully.")
    return ret

def gen_weights(
    onnx_graph: GraphProto,
    graph: nx.DiGraph,
    ins_seq: List[Union[Conv, Add, Remap]],
    params: dict,
    M: int, S: int
) -> Dict[str, np.ndarray]:  # ins_name -> weight array
    """Generate weights for each Conv/Fc instruction"""
    Log.i("MemGen: Start generating weights.")
    ret = {}
    for ins in ins_seq:
        if ins.op_type == INS_CONV:
            Log.i(f"MemGen: Generate weights for {ins.name}.")
            ins_params = params[ins.name]
            # Find original weight tensor from onnx_graph
            onnx_node = graph.nodes[ins.name]["att_obj"]
            w_name = onnx_node.input[3]
            weight = utils.onnx_find_tensor_by_name(onnx_graph, w_name)
            # Parameters
            OC, INC, KH, KW = ins_params["OC"], ins_params["INC"], ins_params["KH"], ins_params["KW"]
            Wz = ins_params["wz"]
            # Shape parameters alignment
            aligned_OC, aligned_INC = helper.conv_params_alignment(OC, INC, KH, KW, M, S)
            aligned_weight = np.pad(weight, ((0,aligned_OC-OC), (0,aligned_INC-INC), (0,0), (0,0)), "constant", constant_values=Wz)
            # Reorder
            reordered_weight = base.conv_reorder_weights(aligned_weight, M, S)
            ret[ins.name] = reordered_weight
        elif ins.op_type == INS_FC:
            Log.i(f"MemGen: Generate weights for {ins.name}.")
            ins_params = params[ins.name]
            # Find original weight tensor from onnx_graph
            onnx_node = graph.nodes[ins.name]["att_obj"]
            w_name = onnx_node.input[3]
            weight = utils.onnx_find_tensor_by_name(onnx_graph, w_name)
            # Parameters
            OC, INC = ins_params["N"], ins_params["K"]
            Wz = ins_params["bz"]
            # Shape parameters alignment
            aligned_OC, aligned_INC = helper.fc_params_alignment(OC, INC)
            aligned_weight = np.pad(weight, ((0,aligned_OC-OC), (0,aligned_INC-INC)), "constant", constant_values=Wz)
            # Reorder
            reordered_weight = base.fc_reorder_weights(aligned_weight)
            ret[ins.name] = reordered_weight
    Log.i("MemGen: Generate weights successfully.")
    return ret

def gen_bias(
    onnx_graph: GraphProto,
    graph: nx.DiGraph,
    ins_seq: List[Union[Conv, Add, Remap]],
    params: dict,
    M: int, S: int
) -> Dict[str, np.ndarray]:  # ins_name -> bias array
    """Generate bias for each Conv/Fc instruction"""
    Log.i("MemGen: Start generating bias.")
    ret = {}
    for ins in ins_seq:
        if ins.op_type == INS_CONV:
            Log.i(f"MemGen: Generate bias for {ins.name}.")
            ins_params = params[ins.name]
            # Find original bias tensor from onnx_graph
            onnx_node = graph.nodes[ins.name]["att_obj"]
            w_name = onnx_node.input[3]
            b_name = onnx_node.input[8]
            weight = utils.onnx_find_tensor_by_name(onnx_graph, w_name)
            bias = utils.onnx_find_tensor_by_name(onnx_graph, b_name)
            # Parameters
            OC, INC, KH, KW = ins_params["OC"], ins_params["INC"], ins_params["KH"], ins_params["KW"]
            Xz, Wz = ins_params["xz"], ins_params["wz"]
            # Shape parameters alignment
            aligned_OC, aligned_INC = helper.conv_params_alignment(OC, INC, KH, KW, M, S)
            aligned_weight = np.pad(weight, ((0,aligned_OC-OC), (0,aligned_INC-INC), (0,0), (0,0)), "constant", constant_values=Wz)
            aligned_bias = np.pad(bias, (0, aligned_OC-OC), "constant", constant_values=0)
            # Re-generate bias
            re_gen_bias = base.conv_regen_bias(aligned_bias, aligned_weight, Xz, Wz)
            # Reorder bias
            reordered_bias = base.conv_reorder_bias(re_gen_bias, M)
            ret[ins.name] = reordered_bias
        elif ins.op_type == INS_FC:
            Log.i(f"MemGen: Generate bias for {ins.name}.")
            ins_params = params[ins.name]
            # Find original bias tensor from onnx_graph
            onnx_node = graph.nodes[ins.name]["att_obj"]
            b_name = onnx_node.input[6]
            bias = utils.onnx_find_tensor_by_name(onnx_graph, b_name)
            # Parameters
            OC, INC = ins_params["N"], ins_params["K"]
            # Shape parameters alignment
            aligned_OC, _ = helper.fc_params_alignment(OC, INC)
            aligned_bias = np.pad(bias, (0, aligned_OC-OC), "constant", constant_values=0)
            ret[ins.name] = aligned_bias
    Log.i("MemGen: Generate bias successfully.")
    return ret
