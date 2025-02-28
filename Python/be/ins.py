from typing import Dict, List, Tuple, Union
import networkx as nx
from log import Log
import numpy as np
from be.dram import DramAllocRes
from be import helper
import base

INS_NONE = 0b11111111
INS_CONV = 0b00000001
INS_MAXP = 0b00000010
INS_AVGP = 0b00000011
INS_ADD = 0b00000100
INS_REMAP = 0b00000101
INS_FC = 0b00000110

class Conv:
    def __init__(self) -> None:
        self.name: str = ""

        self.op_type: int = -1
        self.xphs_addr: int = -1
        self.xphs_len: int = -1
        self.W_addr: int = -1
        self.W_n_bytes: int = -1
        self.B_addr: int = -1
        self.X_addr: int = -1
        self.Y_addr: int = -1
        self.OC: int = -1
        self.INC: int = -1
        self.INW_: int = -1
        self.KH: int = -1
        self.KW: int = -1
        self.strideH: int = -1
        self.strideW: int = -1
        self.padL: int = -1
        self.padU: int = -1
        self.INH2: int = -1
        self.INW2: int = -1
        self.ifm_height: int = -1
        self.ofm_height: int = -1
        self.n_last_batch: int = -1
        self.n_W_round: int = -1
        self.row_bound: int = -1
        self.col_bound: int = -1
        self.vec_size: int = -1
        self.vec_size_minus_1: int = -1
        self.Xz: int = -1
        self.Wz: int = -1
        self.Yz: int = -1
        self.m1: int = -1
        self.n1: int = -1
        self.obj1: int = -1
        self.obj2: int = -1
        self.obj3: int = -1
        self.obj4: int = -1

    def to_arr(self) -> np.ndarray:
        return np.array([
            self.op_type,
            self.xphs_addr & 0x00ff, (self.xphs_addr & 0xff00) >> 8, 
            self.xphs_len & 0x00ff, (self.xphs_len & 0xff00) >> 8, 
            self.W_addr & 0x000000ff, (self.W_addr & 0x0000ff00) >> 8, (self.W_addr & 0x00ff0000) >> 16,  (self.W_addr & 0xff000000) >> 24,
            self.W_n_bytes & 0x000000ff, (self.W_n_bytes & 0x0000ff00) >> 8, (self.W_n_bytes & 0x00ff0000) >> 16,  (self.W_n_bytes & 0xff000000) >> 24,
            self.B_addr & 0x00ff, (self.B_addr & 0xff00) >> 8, 
            self.X_addr & 0x000000ff, (self.X_addr & 0x0000ff00) >> 8, (self.X_addr & 0x00ff0000) >> 16,  (self.X_addr & 0xff000000) >> 24,
            self.Y_addr & 0x000000ff, (self.Y_addr & 0x0000ff00) >> 8, (self.Y_addr & 0x00ff0000) >> 16,  (self.Y_addr & 0xff000000) >> 24,
            self.OC & 0x00ff, (self.OC & 0xff00) >> 8,
            self.INC & 0x00ff, (self.INC & 0xff00) >> 8,
            self.INW_ & 0x00ff, (self.INW_ & 0xff00) >> 8,
            self.KH,
            self.KW,
            (self.strideW << 4) + self.strideH,
            (self.padU << 4) + self.padL,
            self.INH2 & 0x00ff, (self.INH2 & 0xff00) >> 8,
            self.INW2 & 0x00ff, (self.INW2 & 0xff00) >> 8,
            self.ifm_height & 0x00ff, (self.ifm_height & 0xff00) >> 8,
            self.ofm_height & 0x00ff, (self.ofm_height & 0xff00) >> 8,
            self.n_last_batch,
            self.n_W_round & 0x00ff, (self.n_W_round & 0xff00) >> 8,
            self.row_bound & 0x00ff, (self.row_bound & 0xff00) >> 8,
            self.col_bound & 0x00ff, (self.col_bound & 0xff00) >> 8,
            self.vec_size & 0x00ff, (self.vec_size & 0xff00) >> 8,
            self.vec_size_minus_1 & 0x00ff, (self.vec_size_minus_1 & 0xff00) >> 8,
            self.Xz,
            self.Wz,
            self.Yz,
            self.m1 & 0x000000ff, (self.m1 & 0x0000ff00) >> 8, (self.m1 & 0x00ff0000) >> 16,  (self.m1 & 0xff000000) >> 24,
            self.n1,
            self.obj1,
            self.obj2,
            self.obj3,
            self.obj4
        ]).astype(np.uint8)

class Add:
    def __init__(self) -> None:
        self.name: str = ""

        self.op_type: int = -1
        self.A_addr: int = -1
        self.B_addr: int = -1
        self.C_addr: int = -1
        self.len: int = -1
        self.m1: int = -1
        self.m2: int = -1
        self.n: int = -1
        self.Az: int = -1
        self.Bz: int = -1
        self.Cz: int = -1

    def to_arr(self) -> np.ndarray:
        return np.array([
            self.op_type,
            self.A_addr & 0x000000ff, (self.A_addr & 0x0000ff00) >> 8, (self.A_addr & 0x00ff0000) >> 16,  (self.A_addr & 0xff000000) >> 24,
            self.B_addr & 0x000000ff, (self.B_addr & 0x0000ff00) >> 8, (self.B_addr & 0x00ff0000) >> 16,  (self.B_addr & 0xff000000) >> 24,
            self.C_addr & 0x000000ff, (self.C_addr & 0x0000ff00) >> 8, (self.C_addr & 0x00ff0000) >> 16,  (self.C_addr & 0xff000000) >> 24,
            self.len & 0x000000ff, (self.len & 0x0000ff00) >> 8, (self.len & 0x00ff0000) >> 16,  (self.len & 0xff000000) >> 24,
            self.m1 & 0x000000ff, (self.m1 & 0x0000ff00) >> 8, (self.m1 & 0x00ff0000) >> 16,  (self.m1 & 0xff000000) >> 24,
            self.m2 & 0x000000ff, (self.m2 & 0x0000ff00) >> 8, (self.m2 & 0x00ff0000) >> 16,  (self.m2 & 0xff000000) >> 24,
            self.n,
            self.Az,
            self.Bz,
            self.Cz
        ]).astype(np.uint8)

class Remap:
    def __init__(self) -> None:
        self.name: str = ""

        self.op_type: int = -1
        self.X_addr: int = -1
        self.Y_addr: int = -1
        self.len: int = -1
        self.m1: int = -1
        self.n1: int = -1
        self.Xz: int = -1
        self.Yz: int = -1

    def to_arr(self) -> np.ndarray:
        return np.array([
            self.op_type,
            self.X_addr & 0x000000ff, (self.X_addr & 0x0000ff00) >> 8, (self.X_addr & 0x00ff0000) >> 16,  (self.X_addr & 0xff000000) >> 24,
            self.Y_addr & 0x000000ff, (self.Y_addr & 0x0000ff00) >> 8, (self.Y_addr & 0x00ff0000) >> 16,  (self.Y_addr & 0xff000000) >> 24,
            self.len & 0x000000ff, (self.len & 0x0000ff00) >> 8, (self.len & 0x00ff0000) >> 16,  (self.len & 0xff000000) >> 24,
            self.m1 & 0x000000ff, (self.m1 & 0x0000ff00) >> 8, (self.m1 & 0x00ff0000) >> 16,  (self.m1 & 0xff000000) >> 24,
            self.n1,
            self.Xz & 0x00ff, (self.Xz & 0xff00) >> 8,
            self.Yz
        ]).astype(np.uint8)

class End:
    def __init__(self) -> None:
        self.name: str = ""

        self.op_type: int = -1

    def to_arr(self) -> np.ndarray:
        return np.array([
            self.op_type
        ]).astype(np.uint8)

def _gen_conv_ins(
    graph: nx.DiGraph,
    params: dict,
    node_name: str,
    cwm_res: Dict[str, Tuple[bool, int, int]],
    rtm_res: Dict[str, Tuple[str, int, int]],
    xphm_res: Dict[str, Tuple[int, int]],
    bm_res: Dict[str, Tuple[int, int]],
    dram_res: DramAllocRes,
    M: int, P: int, R: int, S: int
) -> Conv:
    """Generate Conv instruction."""
    ret = Conv()

    node_params = params[node_name]
    OC, INC, INH_, INW_ = node_params["OC"], node_params["INC"], node_params["INH_"], node_params["INW_"]
    KH, KW, strideH, strideW = node_params["KH"], node_params["KW"], node_params["strideH"], node_params["strideW"]
    padL, padR, padU, padD = node_params["padL"], node_params["padR"], node_params["padU"], node_params["padD"]
    m1, n1 = node_params["m1"], node_params["n1"]
    xz, wz, yz = node_params["xz"], node_params["wz"], node_params["yz"]
    
    # OC, INC alignment
    OC, INC = helper.conv_params_alignment(OC, INC, KH, KW, M, S)

    # Handle convolutional parameters
    (
        INH2, INW2, ifm_height, ofm_height, n_last_batch, n_w_rnd, 
        row_bound, col_bound, vec_size, vec_size_minus_1
    ) = base.conv_params(
        OC, INC, INH_, INW_,
        KH, KW, strideH, strideW,
        padL, padR, padU, padD,
        M, P, R, S
    )

    # Handle tensor address
    # X_addr
    predecessors = list(graph.predecessors(node_name))
    if len(predecessors) == 0:  # Input
        _, X_addr, _ = rtm_res["input"]
    elif len(predecessors) == 1:
        _, X_addr, _ = rtm_res[predecessors[0]]
    else:
        raise ValueError(f"Cannot get X_addr of node {node_name} because it has {len(predecessors)} predecessors.")
    # Y_addr
    _, Y_addr, _ = rtm_res[node_name]
    # xphs_addr, xphs_len
    xphs_addr, xphs_len = xphm_res[node_name]
    # B_addr
    B_addr, _ = bm_res[node_name]
    # W_addr, W_n_bytes
    is_sta, w_addr, w_size = cwm_res[node_name]
    if is_sta:
        W_addr, W_n_bytes = w_addr, w_size*M*4
    else:
        W_addr, W_n_bytes = dram_res.dyn_conv_weight_desc[0]+w_addr, w_size
    # Static segment size of CWM
    sta_size = dram_res.sta_conv_weight_desc[1]//(M*4)

    # Build instruction
    ret.name = node_name
    ret.op_type = INS_CONV
    ret.xphs_addr = xphs_addr
    ret.xphs_len = xphs_len-1
    ret.W_addr = W_addr
    ret.W_n_bytes = W_n_bytes
    ret.B_addr = B_addr
    ret.X_addr = X_addr
    ret.Y_addr = Y_addr
    ret.OC = OC
    ret.INC = INC//S-1
    ret.INW_ = INW_
    ret.KH = KH-1
    ret.KW = KW-1
    ret.strideH = strideH
    ret.strideW = strideW
    ret.padL = padL
    ret.padU = padU
    ret.INH2 = INH2
    ret.INW2 = INW2
    ret.ifm_height = ifm_height
    ret.ofm_height = ofm_height
    ret.n_last_batch = n_last_batch
    ret.n_W_round = n_w_rnd-1
    ret.row_bound = row_bound
    ret.col_bound = col_bound
    ret.vec_size = vec_size
    ret.vec_size_minus_1 = vec_size_minus_1
    ret.Xz = xz
    ret.Wz = wz
    ret.Yz = yz
    ret.m1 = m1
    ret.n1 = n1-1
    ret.obj1 = sta_size & 0x000000ff
    ret.obj2 = (sta_size & 0x0000ff00) >> 8
    ret.obj3 = (sta_size & 0x00ff0000) >> 16
    ret.obj4 = (sta_size & 0xff000000) >> 24

    return ret

def _gen_fc_ins(
    graph: nx.DiGraph,
    params: dict,
    node_name: str,
    fcwm_res: Dict[str, Tuple[int, int]],
    rtm_res: Dict[str, Tuple[str, int, int]],
    bm_res: Dict[str, Tuple[int, int]],
    dram_res: DramAllocRes
) -> Conv:
    """Generate Fc instruction."""
    ret = Conv()

    node_params = params[node_name]
    OC, INC = node_params["N"], node_params["K"]
    m1, n1 = node_params["m1"], node_params["n1"]
    az, bz, yz = node_params["az"], node_params["bz"], node_params["yz"]

    # OC, INC alignment
    OC, INC = helper.fc_params_alignment(OC, INC)

    # Parameters
    n_rnd = OC//64

    # Address
    # X_addr, X_mode
    predecessors = list(graph.predecessors(node_name))
    if len(predecessors) == 0:  # Input
        X_mode, X_addr, _ = rtm_res["input"]
    elif len(predecessors) == 1:
        X_mode, X_addr, _ = rtm_res[predecessors[0]]
    else:
        raise ValueError(f"Cannot get X_addr of node {node_name} because it has {len(predecessors)} predecessors.")
    # W_addr
    W_addr, W_n_bytes = dram_res.fc_weight_desc[0]+fcwm_res[node_name][0], fcwm_res[node_name][1]
    # B_addr
    B_addr, _ = bm_res[node_name]
    # Y_addr
    _, Y_addr, _ = rtm_res[node_name]

    # Build instruction
    ret.name = node_name
    ret.op_type = INS_FC
    ret.xphs_addr = 0
    ret.xphs_len = n_rnd-1
    ret.W_addr = W_addr
    ret.W_n_bytes = W_n_bytes
    ret.B_addr = B_addr
    ret.X_addr = X_addr
    ret.Y_addr = Y_addr
    ret.OC = 0
    ret.INC = 0
    ret.INW_ = 0
    ret.KH = 0
    ret.KW = 0
    ret.strideH = 0
    ret.strideW = 0
    ret.padL = 0
    ret.padU = 0
    ret.INH2 = 0
    ret.INW2 = 0
    ret.ifm_height = 0
    ret.ofm_height = 0
    ret.n_last_batch = 0
    ret.n_W_round = 0
    ret.row_bound = 0
    ret.col_bound = 0
    ret.vec_size = INC
    ret.vec_size_minus_1 = INC-1
    ret.Xz = az
    ret.Wz = bz
    ret.Yz = yz
    ret.m1 = m1
    ret.n1 = n1-1
    ret.obj1 = 0 if X_mode == "T-mode" else 1
    ret.obj2 = 0
    ret.obj3 = 0
    ret.obj4 = 0

    return ret

def _gen_add_ins(
    graph: nx.DiGraph,
    params: dict,
    node_name: str,
    rtm_res: Dict[str, Tuple[str, int, int]]
) -> Add:
    """Generate Add instruction."""
    ret = Add()

    node_params = params[node_name]
    m1, m2, n = node_params["m1"], node_params["m2"], node_params["n"]
    az, bz, cz = node_params["az"], node_params["bz"], node_params["cz"]

    # Address
    predecessors = list(graph.predecessors(node_name))
    assert len(predecessors) == 2, f"Cannot get A_addr of node {node_name} because it has {len(predecessors)} predecessors."
    _, A_addr, _ = rtm_res[predecessors[0]]
    _, B_addr, _ = rtm_res[predecessors[1]]
    _, C_addr, C_size = rtm_res[node_name]

    # Build instruction
    ret.name = node_name
    ret.op_type = INS_ADD
    ret.A_addr = A_addr
    ret.B_addr = B_addr
    ret.C_addr = C_addr
    ret.len = C_size-1
    ret.m1 = m1
    ret.m2 = m2
    ret.n = n-1
    ret.Az = az
    ret.Bz = bz
    ret.Cz = cz

    return ret

def _gen_remap_ins(
    graph: nx.DiGraph,
    params: dict,
    node_name: str,
    rtm_res: Dict[str, Tuple[str, int, int]]
) -> List[Remap]:
    """Generate Remap instructions for QLinearConcat"""
    ret = []

    predecessors = list(graph.predecessors(node_name))
    node_params = params[node_name]
    m_dict, n_dict, xz_dict = {}, {}, {}
    for i in range(len(predecessors)):
        tensor_name = node_params[f"name{i}"]
        m_dict[tensor_name] = node_params[f"m{i}"]
        n_dict[tensor_name] = node_params[f"n{i}"]
        xz_dict[tensor_name] = node_params[f"xz{i}"]
    yz = node_params["yz"]
    primary_tensor_name = node_params["primary_tensor_name"]

    # Build instructions
    for i in range(len(predecessors)):
        predecessor = predecessors[i]
        prev_onnx_node = graph.nodes[predecessor]["att_obj"]
        tensor_name = prev_onnx_node.output[0]
        # Skip the primary tensor
        if tensor_name == primary_tensor_name:
            continue
        
        ins = Remap()
        # X_addr
        _, X_addr, X_len = rtm_res[predecessor]
        Y_addr = X_addr
        m1, n1, Xz = m_dict[tensor_name], n_dict[tensor_name], xz_dict[tensor_name]
        # Instruction
        ins.name = f"{node_name}/{i}"
        ins.op_type = INS_REMAP
        ins.X_addr = X_addr
        ins.Y_addr = Y_addr
        ins.len = X_len-1
        ins.m1 = m1
        ins.n1 = n1-1
        ins.Xz = -Xz
        ins.Yz = yz
        ret.append(ins)

    return ret

def _gen_maxpool_ins(
    graph: nx.DiGraph,
    params: dict,
    node_name: str,
    rtm_res: Dict[str, Tuple[str, int, int]],
    xphm_res: Dict[str, Tuple[int, int]],
    M: int, P: int, R: int, S: int
) -> Conv:
    """Generate Pool instruction for MaxPool."""
    ret = Conv()

    node_params = params[node_name]
    OC, INC, INH_, INW_ = node_params["OC"], node_params["INC"], node_params["INH_"], node_params["INW_"]
    KH, KW, strideH, strideW = node_params["KH"], node_params["KW"], node_params["strideH"], node_params["strideW"]
    padL, padR, padU, padD = node_params["padL"], node_params["padR"], node_params["padU"], node_params["padD"]

    # INC alignment
    INC = helper.pool_params_alignment(INC, S)

    # Handle pooling parameters
    (
        INH2, INW2, ifm_height, ofm_height, n_last_batch, n_w_rnd, 
        row_bound, col_bound, vec_size, vec_size_minus_1
    ) = base.pool_params(
        OC, INC, INH_, INW_,
        KH, KW, strideH, strideW,
        padL, padR, padU, padD,
        M, P, R, S
    )

    # Handle tensor address
    # X_addr
    predecessors = list(graph.predecessors(node_name))
    if len(predecessors) == 0:  # Input
        _, X_addr, _ = rtm_res["input"]
    elif len(predecessors) == 1:
        _, X_addr, _ = rtm_res[predecessors[0]]
    else:
        raise ValueError(f"Cannot get X_addr of node {node_name} because it has {len(predecessors)} predecessors.")
    # Y_addr
    _, Y_addr, _ = rtm_res[node_name]
    # xphs_addr, xphs_len
    xphs_addr, xphs_len = xphm_res[node_name]

    # Build instruction
    ret.name = node_name
    ret.op_type = INS_MAXP
    ret.xphs_addr = xphs_addr
    ret.xphs_len = xphs_len-1
    ret.W_addr = 0
    ret.W_n_bytes = 0
    ret.B_addr = 0
    ret.X_addr = X_addr
    ret.Y_addr = Y_addr
    ret.OC = OC
    ret.INC = INC//S-1
    ret.INW_ = INW_
    ret.KH = KH-1
    ret.KW = KW-1
    ret.strideH = strideH
    ret.strideW = strideW
    ret.padL = padL
    ret.padU = padU
    ret.INH2 = INH2
    ret.INW2 = INW2
    ret.ifm_height = ifm_height
    ret.ofm_height = ofm_height
    ret.n_last_batch = n_last_batch
    ret.n_W_round = 0
    ret.row_bound = row_bound
    ret.col_bound = col_bound
    ret.vec_size = vec_size
    ret.vec_size_minus_1 = vec_size_minus_1
    ret.Xz = 0
    ret.Wz = 0
    ret.Yz = 0
    ret.m1 = 1024
    ret.n1 = 10-1
    ret.obj1 = 0
    ret.obj2 = 0
    ret.obj3 = 0
    ret.obj4 = 0

    return ret

def _gen_avgpool_ins(
    graph: nx.DiGraph,
    params: dict,
    node_name: str,
    rtm_res: Dict[str, Tuple[str, int, int]],
    xphm_res: Dict[str, Tuple[int, int]],
    M: int, P: int, R: int, S: int
) -> Conv:
    """Generate Pool instruction for QLinearAveragePool/QLinearGlobalAveragePool."""
    ret = Conv()

    node_params = params[node_name]
    OC, INC, INH_, INW_ = node_params["OC"], node_params["INC"], node_params["INH_"], node_params["INW_"]
    KH, KW, strideH, strideW = node_params["KH"], node_params["KW"], node_params["strideH"], node_params["strideW"]
    padL, padR, padU, padD = node_params["padL"], node_params["padR"], node_params["padU"], node_params["padD"]
    m1, n1 = node_params["m1"], node_params["n1"]
    xz, nxz, yz = node_params["xz"], node_params["nxz"], node_params["yz"]

    # INC alignment
    INC = helper.pool_params_alignment(INC, S)

    # Handle pooling parameters
    (
        INH2, INW2, ifm_height, ofm_height, n_last_batch, n_w_rnd, 
        row_bound, col_bound, vec_size, vec_size_minus_1
    ) = base.pool_params(
        OC, INC, INH_, INW_,
        KH, KW, strideH, strideW,
        padL, padR, padU, padD,
        M, P, R, S
    )
    neg_nxz = -nxz

    # Handle tensor address
    # X_addr
    predecessors = list(graph.predecessors(node_name))
    if len(predecessors) == 0:  # Input
        _, X_addr, _ = rtm_res["input"]
    elif len(predecessors) == 1:
        _, X_addr, _ = rtm_res[predecessors[0]]
    else:
        raise ValueError(f"Cannot get X_addr of node {node_name} because it has {len(predecessors)} predecessors.")
    # Y_addr
    _, Y_addr, _ = rtm_res[node_name]
    # xphs_addr, xphs_len
    xphs_addr, xphs_len = xphm_res[node_name]

    # Build instruction
    ret.name = node_name
    ret.op_type = INS_AVGP
    ret.xphs_addr = xphs_addr
    ret.xphs_len = xphs_len-1
    ret.W_addr = 0
    ret.W_n_bytes = 0
    ret.B_addr = 0
    ret.X_addr = X_addr
    ret.Y_addr = Y_addr
    ret.OC = OC
    ret.INC = INC//S-1
    ret.INW_ = INW_
    ret.KH = KH-1
    ret.KW = KW-1
    ret.strideH = strideH
    ret.strideW = strideW
    ret.padL = padL
    ret.padU = padU
    ret.INH2 = INH2
    ret.INW2 = INW2
    ret.ifm_height = ifm_height
    ret.ofm_height = ofm_height
    ret.n_last_batch = n_last_batch
    ret.n_W_round = 0
    ret.row_bound = row_bound
    ret.col_bound = col_bound
    ret.vec_size = vec_size
    ret.vec_size_minus_1 = vec_size_minus_1
    ret.Xz = xz
    ret.Wz = 0
    ret.Yz = yz
    ret.m1 = m1
    ret.n1 = n1-1
    ret.obj1 = neg_nxz & 0x000000ff
    ret.obj2 = (neg_nxz & 0x0000ff00) >> 8
    ret.obj3 = 0
    ret.obj4 = 0

    return ret

def gen_ins(
    graph: nx.DiGraph,
    exec_seq: List[str],
    params: dict,
    cwm_res: Dict[str, Tuple[bool, int, int]],
    fcwm_res: Dict[str, Tuple[int, int]],
    rtm_res: Dict[str, Tuple[str, int, int]],
    bm_res: Dict[str, Tuple[int, int]],
    xphm_res: Dict[str, Tuple[int, int]],
    dram_res: DramAllocRes,
    M: int, P: int, R: int, S:int
) -> List[Union[Conv, Add, Remap]]:
    """Generate instruction sequence."""
    Log.i("InsGen: Start generating.")
    ret = []
    for node_name in exec_seq:
        Log.i(f"InsGen: Generate instructions for node {node_name}.")
        onnx_node = graph.nodes[node_name]["att_obj"]
        if onnx_node.op_type == "QLinearConv":
            ret.append(_gen_conv_ins(
                graph=graph,
                params=params,
                node_name=node_name,
                cwm_res=cwm_res,
                rtm_res=rtm_res,
                xphm_res=xphm_res,
                bm_res=bm_res,
                dram_res=dram_res,
                M=M, P=P, R=R, S=S
            ))
        elif onnx_node.op_type == "QGemm":
            ret.append(_gen_fc_ins(
                graph=graph,
                params=params,
                node_name=node_name,
                fcwm_res=fcwm_res,
                rtm_res=rtm_res,
                bm_res=bm_res,
                dram_res=dram_res
            ))
        elif onnx_node.op_type == "QLinearAdd":
            ret.append(_gen_add_ins(
                graph=graph,
                params=params,
                node_name=node_name,
                rtm_res=rtm_res
            ))
        elif onnx_node.op_type == "QLinearConcat":
            ret.extend(_gen_remap_ins(
                graph=graph,
                params=params,
                node_name=node_name,
                rtm_res=rtm_res
            ))
        elif onnx_node.op_type == "QLinearAveragePool":
            ret.append(_gen_avgpool_ins(
                graph=graph,
                params=params,
                node_name=node_name,
                rtm_res=rtm_res,
                xphm_res=xphm_res,
                M=M, P=P, R=R, S=S
            ))
        elif onnx_node.op_type == "QLinearGlobalAveragePool":
            ret.append(_gen_avgpool_ins(
                graph=graph,
                params=params,
                node_name=node_name,
                rtm_res=rtm_res,
                xphm_res=xphm_res,
                M=M, P=P, R=R, S=S
            ))
        elif onnx_node.op_type == "MaxPool":
            ret.append(_gen_maxpool_ins(
                graph=graph,
                params=params,
                node_name=node_name,
                rtm_res=rtm_res,
                xphm_res=xphm_res,
                M=M, P=P, R=R, S=S
            ))
        else:
            raise ValueError(f"Unsupported node {node_name} with type {onnx_node.op_type}")
    # Append the end instruction
    end_ins = End()
    end_ins.name = "End"
    end_ins.op_type = INS_NONE
    ret.append(end_ins)
    Log.i("InsGen: Done.")
    return ret

def get_ins_type(ins: Union[Conv, Remap, Add]) -> str:
    """Get the op_type representation of the given instruction."""
    if ins.op_type == INS_CONV:
        return "Conv"
    elif ins.op_type == INS_MAXP:
        return "MaxPool"
    elif ins.op_type == INS_AVGP:
        return "AveragePool"
    elif ins.op_type == INS_ADD:
        return "Add"
    elif ins.op_type == INS_REMAP:
        return "Remap"
    elif ins.op_type == INS_FC:
        return "Fc"
    elif ins.op_type == INS_NONE:
        return "End"
