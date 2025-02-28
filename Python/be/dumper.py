import os
import numpy as np
from onnx import GraphProto
from typing import List, Union, Dict, Tuple
import networkx as nx
from log import Log
from be import helper
from be.ins import INS_CONV, INS_FC, INS_MAXP, INS_AVGP, INS_ADD, INS_REMAP, get_ins_type
from be.dram import DramAllocRes
from be.ins import Conv, Remap, Add

class HwModel:
    def __init__(self) -> None:
        # static conv weights in dram
        self.sta_conv_weight_ddr_addr: int = -1
        self.sta_conv_weight_ddr_len: int = -1
        # dynamic conv weights in dram
        self.dyn_conv_weight_ddr_addr: int = -1
        self.dyn_conv_weight_ddr_len: int = -1
        # fc weights in dram
        self.fc_weight_ddr_addr: int = -1
        self.fc_weight_ddr_len: int = -1
        # bias in dram
        self.bias_ddr_addr: int = -1
        self.bias_ddr_len: int = -1
        # instructions in dram
        self.ins_ddr_addr: int = -1
        self.ins_ddr_len: int = -1
        # x packet headers in dram
        self.xphs_ddr_addr: int = -1
        self.xphs_ddr_len: int = -1
        # input in dram and rtm
        self.input_ddr_addr: int = -1
        self.input_ddr_len: int = -1
        self.input_rtm_addr: int = -1
        # output in dram and rtm
        self.output_ddr_addr: int = -1
        self.output_ddr_len: int = -1
        self.output_rtm_addr: int = -1
        self.output_rtm_mode: str = ""
        # the input tensor/vector
        self.input_n_chan: int = -1
        self.input_height: int = -1
        self.input_width: int = -1
        # quantization parameters
        self.input_s: float = 0.
        self.input_z: int = -1
        self.output_s: float = 0.
        self.output_z: int = -1

def dump_model_info(
    onnx_graph: GraphProto,
    graph: nx.DiGraph,
    params: dict,
    dram_res: DramAllocRes,
    ins_seq: List[Union[Conv, Add, Remap]], 
    rtm_res: Dict[str, Tuple[str, int, int]],
    output_dir_path: str
) -> None:
    """Dump model information."""
    Log.i(f"Dumper: Start dumping model information.")
    model = HwModel()
    model.sta_conv_weight_ddr_addr, model.sta_conv_weight_ddr_len = dram_res.sta_conv_weight_desc
    model.dyn_conv_weight_ddr_addr, model.dyn_conv_weight_ddr_len = dram_res.dyn_conv_weight_desc
    model.fc_weight_ddr_addr, model.fc_weight_ddr_len = dram_res.fc_weight_desc
    model.bias_ddr_addr, model.bias_ddr_len = dram_res.bias_desc
    model.ins_ddr_addr, model.ins_ddr_len = dram_res.ins_desc
    model.xphs_ddr_addr, model.xphs_ddr_len = dram_res.xphs_desc
    model.input_ddr_addr, model.input_ddr_len = dram_res.input_desc
    _, model.input_rtm_addr, _ = rtm_res["input"]
    model.output_ddr_addr, model.output_ddr_len = dram_res.output_desc
    # Output tensor/vector in RTM
    last_vld_ins = ins_seq[-2]
    model.output_rtm_mode, model.output_rtm_addr, _ = rtm_res[last_vld_ins.name]
    # Input tensor/vector
    input_shape = helper.find_input_shape(graph, params)
    if len(input_shape) == 3:
        model.input_n_chan, model.input_height,model.input_width = input_shape
    else:
        model.input_n_chan, model.input_height,model.input_width = input_shape, 1, 1
    # Quantization parameters
    model.input_s, model.input_z, model.output_s, model.output_z = helper.find_quan_params(onnx_graph)
    # Save into file
    with open(os.path.join(output_dir_path, "model.yaml"), mode="w", encoding="utf8") as f:
        f.write(f"sta_conv_weight_ddr_addr: {model.sta_conv_weight_ddr_addr}\n")
        f.write(f"sta_conv_weight_ddr_len: {model.sta_conv_weight_ddr_len}\n")
        f.write(f"dyn_conv_weight_ddr_addr: {model.dyn_conv_weight_ddr_addr}\n")
        f.write(f"dyn_conv_weight_ddr_len: {model.dyn_conv_weight_ddr_len}\n")
        f.write(f"fc_weight_ddr_addr: {model.fc_weight_ddr_addr}\n")
        f.write(f"fc_weight_ddr_len: {model.fc_weight_ddr_len}\n")
        f.write(f"bias_ddr_addr: {model.bias_ddr_addr}\n")
        f.write(f"bias_ddr_len: {model.bias_ddr_len}\n")
        f.write(f"ins_ddr_addr: {model.ins_ddr_addr}\n")
        f.write(f"ins_ddr_len: {model.ins_ddr_len}\n")
        f.write(f"xphs_ddr_addr: {model.xphs_ddr_addr}\n")
        f.write(f"xphs_ddr_len: {model.xphs_ddr_len}\n")
        f.write(f"input_ddr_addr: {model.input_ddr_addr}\n")
        f.write(f"input_ddr_len: {model.input_ddr_len}\n")
        f.write(f"input_rtm_addr: {model.input_rtm_addr}\n")
        f.write(f"output_ddr_addr: {model.output_ddr_addr}\n")
        f.write(f"output_ddr_len: {model.output_ddr_len}\n")
        f.write(f"output_rtm_addr: {model.output_rtm_addr}\n")
        f.write(f"output_rtm_mode: {model.output_rtm_mode}\n")
        f.write(f"input_n_chan: {model.input_n_chan}\n")
        f.write(f"input_height: {model.input_height}\n")
        f.write(f"input_width: {model.input_width}\n")
        f.write(f"input_s: {model.input_s}\n")
        f.write(f"input_z: {model.input_z}\n")
        f.write(f"output_s: {model.output_s}\n")
        f.write(f"output_z: {model.output_z}\n")
    Log.i("Dumper: Dump model information successfully.")

def dump_ins(
    ins_seq: List[Union[Conv, Add, Remap]], 
    output_dir_path: str
) -> None:
    """Dump instructions into .hex file."""
    Log.i(f"Dumper: Start dumping instructions, number of instructions: {len(ins_seq)}.")
    arr_list = []
    for ins in ins_seq:
        arr = ins.to_arr()
        arr = np.pad(arr, (0, 64-arr.shape[0]), "constant", constant_values=0)
        arr_list.append(arr)
    ins_mat = np.row_stack(arr_list)
    ins_mat.tofile(os.path.join(output_dir_path, "ins.hex"))
    Log.i("Dumper: Dump instructions successfully.")

def dump_sta_conv_weights(
    ins_seq: List[Union[Conv, Add, Remap]],
    output_dir_path: str,
    mem_weights: Dict[str, np.ndarray]
) -> None:
    """Dump sta_conv_weights into .hex file."""
    Log.i(f"Dumper: Start dumping static convolutional weights.")
    # Find convolution instructions with static weights
    ins_list = []
    for ins in ins_seq:
        if ins.op_type == INS_CONV:
            if ins.W_addr < 0x80000000:
                ins_list.append(ins)
    ins_list = sorted(ins_list, key=lambda k: k.W_addr, reverse=False)
    # Combine weights
    arr_list = []
    for ins in ins_list:
        weight = mem_weights[ins.name]
        arr = weight.flatten()
        arr_list.append(arr)
    if len(arr_list) > 0:
        weight_mat = np.concatenate(arr_list, axis=0)
        weight_mat.tofile(os.path.join(output_dir_path, "sta_conv_weights.hex"))
    Log.i("Dumper: Dump static convolutional weights successfully.")

def dump_dyn_conv_weights(
    ins_seq: List[Union[Conv, Add, Remap]],
    output_dir_path: str,
    mem_weights: Dict[str, np.ndarray]
) -> None:
    """Dump dyn_conv_weights into .hex file."""
    Log.i(f"Dumper: Start dumping dynamic convolutional weights.")
    ins_list = []
    for ins in ins_seq:
        if ins.op_type == INS_CONV:
            if ins.W_addr >= 0x80000000:
                ins_list.append(ins)
    ins_list = sorted(ins_list, key=lambda k: k.W_addr, reverse=False)
    # Combine weights
    arr_list = []
    for ins in ins_list:
        weight = mem_weights[ins.name]
        arr = weight.flatten()
        arr_list.append(arr)
    if len(arr_list) > 0:
        weight_mat = np.concatenate(arr_list, axis=0)
        weight_mat.tofile(os.path.join(output_dir_path, "dyn_conv_weights.hex"))
    Log.i("Dumper: Dump dynamic convolutional weights successfully.")

def dump_fc_weights(
    ins_seq: List[Union[Conv, Add, Remap]],
    output_dir_path: str,
    mem_weights: Dict[str, np.ndarray]
) -> None:
    """Dump fc_weights into .hex file."""
    Log.i(f"Dumper: Start dumping fc weights.")
    ins_list = []
    for ins in ins_seq:
        if ins.op_type == INS_FC:
            ins_list.append(ins)
    ins_list = sorted(ins_list, key=lambda k: k.W_addr, reverse=False)
    # Combine weights
    arr_list = []
    for ins in ins_list:
        weight = mem_weights[ins.name]
        arr = weight.flatten()
        arr_list.append(arr)
    if len(arr_list) > 0:
        weight_mat = np.concatenate(arr_list, axis=0)
        weight_mat.tofile(os.path.join(output_dir_path, "fc_weights.hex"))
    Log.i("Dumper: Dump fc weights successfully.")

def dump_xphs(
    ins_seq: List[Union[Conv, Add, Remap]],
    output_dir_path: str,
    mem_xphs: Dict[str, np.ndarray]
) -> None:
    """Dump X packet headers into .hex file."""
    Log.i(f"Dumper: Start dumping x packet headers.")
    ins_list = []
    for ins in ins_seq:
        if ins.op_type in (INS_CONV, INS_MAXP, INS_AVGP):
            ins_list.append(ins)
    ins_list = sorted(ins_list, key=lambda k: k.xphs_addr, reverse=False)
    # Combine xphs
    arr_list = []
    for ins in ins_list:
        xphs = mem_xphs[ins.name]
        xphs = np.pad(xphs, ((0, 0), (0, 64-xphs.shape[1])), "constant", constant_values=0)
        arr = xphs.flatten()
        arr_list.append(arr)
    if len(arr_list) > 0:
        xphs_mat = np.concatenate(arr_list, axis=0)
        xphs_mat.tofile(os.path.join(output_dir_path, "xphs.hex"))
    Log.i("Dumper: Dump x packet headers successfully.")

def dump_bias(
    ins_seq: List[Union[Conv, Add, Remap]],
    output_dir_path: str,
    mem_bias: Dict[str, np.ndarray]
) -> None:
    """Dump bias into .hex file."""
    Log.i(f"Dumper: Start dumping bias.")
    ins_list = []
    for ins in ins_seq:
        if ins.op_type in (INS_CONV, INS_FC):
            ins_list.append(ins)
    ins_list = sorted(ins_list, key=lambda k: k.B_addr, reverse=False)
    # Combine bias
    arr_list = []
    for ins in ins_list:
        bias = mem_bias[ins.name]
        arr = bias.flatten()
        arr_list.append(arr)
    if len(arr_list) > 0:
        bias_mat = np.concatenate(arr_list, axis=0)
        bias_mat.tofile(os.path.join(output_dir_path, "bias.hex"))
    Log.i("Dumper: Dump bias successfully.")

def dump_layer_info(
    graph: nx.DiGraph,
    exec_seq: List[str],
    params: dict,
    output_dir_path: str
) -> None:
    """Dump layer information."""
    """"""
    Log.i(f"Dumper: Start dumping layer information.")
    with open(os.path.join(output_dir_path, "layer_info.csv"), mode="w", encoding="utf8") as f:
        f.write("Name,Type,OC,INC,INH_,INW_,KH,KW,strideH,strideW,padL,padR,padU,padD\n")
        for node_name in exec_seq:
            onnx_node = graph.nodes[node_name]["att_obj"]
            node_params = params[node_name]
            OC, INC, INH_, INW_ = 0, 0, 0, 0
            KH, KW, strideH, strideW = 0, 0, 0, 0
            padL, padR, padU, padD = 0, 0, 0, 0
            if onnx_node.op_type in ("QLinearConv", "MaxPool", "QLinearAveragePool", "QLinearGlobalAveragePool"):
                OC, INC, INH_, INW_ = node_params["OC"], node_params["INC"], node_params["INH_"], node_params["INW_"]
                KH, KW, strideH, strideW = node_params["KH"], node_params["KW"], node_params["strideH"], node_params["strideW"]
                padL, padR, padU, padD = node_params["padL"], node_params["padR"], node_params["padU"], node_params["padD"]
                if onnx_node.op_type == "QLinearConv":
                    layer_type = "Conv"
                elif onnx_node.op_type == "MaxPool":
                    layer_type = "MaxPool"
                elif onnx_node.op_type == "QLinearAveragePool":
                    layer_type = "AveragePool"
                elif onnx_node.op_type == "QLinearGlobalAveragePool":
                    layer_type = "GlobalAveragePool"
            elif onnx_node.op_type == "QGemm":
                OC, INC = node_params["N"], node_params["K"]
                layer_type = "Fc"
            elif onnx_node.op_type == "QLinearAdd":
                layer_type = "Add"
            elif onnx_node.op_type == "QLinearConcat":
                continue
            else:
                raise ValueError(f"Unsupported node {onnx_node.name} with type {onnx_node.op_type}.")
            f.write(f"{node_name},{layer_type},{OC},{INC},{INH_},{INW_},{KH},{KW},{strideH},{strideW},{padL},{padR},{padU},{padD}\n")
    Log.i("Dumper: Dump layer information successfully.")

def dump_conv_shape_params(
    ins_seq: List[Union[Conv, Add, Remap]],
    params: dict,
    output_dir_path: str,
    S: int
) -> None:
    """Dump conv shape parameters (.csv and .hex). Note that OC and INC should be aligned because this file is used by the hardware directly."""
    Log.i(f"Dumper: Start dumping conv shape parameters.")
    arr_list = []
    # csv file
    with open(os.path.join(output_dir_path, "conv_shapes.csv"), mode="w", encoding="utf8") as f:
        f.write("Index,Name,OC,INC,INH_,INW_,KH,KW,strideH,strideW,padL,padR,padU,padD\n")
        for ins in ins_seq:
            if ins.op_type == INS_CONV:
                index = ins_seq.index(ins)+1
                node_params = params[ins.name]
                # Find shape parameters
                OC, INC, INH_, INW_ = ins.OC, (ins.INC+1)*S, node_params["INH_"], node_params["INW_"]
                KH, KW, strideH, strideW = node_params["KH"], node_params["KW"], node_params["strideH"], node_params["strideW"]
                padL, padR, padU, padD = node_params["padL"], node_params["padR"], node_params["padU"], node_params["padD"]
                f.write(f"{index},{ins.name},{OC},{INC},{INH_},{INW_},{KH},{KW},{strideH},{strideW},{padL},{padR},{padU},{padD}\n")
                # Build array
                arr = np.array([OC, INC, INH_, INW_, KH, KW, strideH, strideW, padL, padR, padU, padD]).astype(np.uint32)
                arr_list.append(arr)
    # hex file
    if len(arr_list) > 0:
        mat = np.concatenate(arr_list, axis=0)
        mat.tofile(os.path.join(output_dir_path, "conv_shapes.hex"))
    Log.i("Dumper: Dump conv shape parameters successfully.")

def dump_debug_ins_seq(
    ins_seq: List[Union[Conv, Add, Remap]],
    output_dir_path: str
) -> None:
    """Dump human-readable instructions for debugging purpose."""
    Log.i("Dumper: Start dumping instructions for debugging.")
    debug_dir = os.path.join(output_dir_path, "debug")
    if not os.path.exists(debug_dir):
        os.makedirs(debug_dir)
    # Instruction sequence
    with open(os.path.join(debug_dir, "ins_seq.csv"), mode="w", encoding="utf8") as f:
        f.write("Index,Name,Type\n")
        for i in range(len(ins_seq)):
            ins = ins_seq[i]
            f.write(f"{i+1},{ins.name},{get_ins_type(ins)}\n")
    # Conv
    with open(os.path.join(debug_dir, "ins_conv.csv"), mode="w", encoding="utf8") as f:
        f.write("Index,Name,xphs_addr,xphs_len,W_addr,W_n_bytes,B_addr,X_addr,Y_addr,OC,INC,INW_,KH,KW,strideH,strideW,padL,padU,INH2,INW2,ifm_height,ofm_height,n_last_batch,n_W_round,row_bound,col_bound,vec_size,vec_size_minus_1,Xz,Wz,Yz,m1,n1,obj1,obj2,obj3,obj4\n")
        for ins in ins_seq:
            if ins.op_type == INS_CONV:
                index = ins_seq.index(ins)+1
                f.write(f"{index},{ins.name},{ins.xphs_addr},{ins.xphs_len},{ins.W_addr},{ins.W_n_bytes},{ins.B_addr},{ins.X_addr},{ins.Y_addr},{ins.OC},{ins.INC},{ins.INW_},{ins.KH},{ins.KW},{ins.strideH},{ins.strideW},{ins.padL},{ins.padU},{ins.INH2},{ins.INW2},{ins.ifm_height},{ins.ofm_height},{ins.n_last_batch},{ins.n_W_round},{ins.row_bound},{ins.col_bound},{ins.vec_size},{ins.vec_size_minus_1},{ins.Xz},{ins.Wz},{ins.Yz},{ins.m1},{ins.n1},{ins.obj1},{ins.obj2},{ins.obj3},{ins.obj4}\n")
    # MaxPool
    with open(os.path.join(debug_dir, "ins_maxp.csv"), mode="w", encoding="utf8") as f:
        f.write("Index,Name,xphs_addr,xphs_len,W_addr,W_n_bytes,B_addr,X_addr,Y_addr,OC,INC,INW_,KH,KW,strideH,strideW,padL,padU,INH2,INW2,ifm_height,ofm_height,n_last_batch,n_W_round,row_bound,col_bound,vec_size,vec_size_minus_1,Xz,Wz,Yz,m1,n1,obj1,obj2,obj3,obj4\n")
        for ins in ins_seq:
            if ins.op_type == INS_MAXP:
                index = ins_seq.index(ins)+1
                f.write(f"{index},{ins.name},{ins.xphs_addr},{ins.xphs_len},{ins.W_addr},{ins.W_n_bytes},{ins.B_addr},{ins.X_addr},{ins.Y_addr},{ins.OC},{ins.INC},{ins.INW_},{ins.KH},{ins.KW},{ins.strideH},{ins.strideW},{ins.padL},{ins.padU},{ins.INH2},{ins.INW2},{ins.ifm_height},{ins.ofm_height},{ins.n_last_batch},{ins.n_W_round},{ins.row_bound},{ins.col_bound},{ins.vec_size},{ins.vec_size_minus_1},{ins.Xz},{ins.Wz},{ins.Yz},{ins.m1},{ins.n1},{ins.obj1},{ins.obj2},{ins.obj3},{ins.obj4}\n")
    # AveragePool
    with open(os.path.join(debug_dir, "ins_avgp.csv"), mode="w", encoding="utf8") as f:
        f.write("Index,Name,xphs_addr,xphs_len,W_addr,W_n_bytes,B_addr,X_addr,Y_addr,OC,INC,INW_,KH,KW,strideH,strideW,padL,padU,INH2,INW2,ifm_height,ofm_height,n_last_batch,n_W_round,row_bound,col_bound,vec_size,vec_size_minus_1,Xz,Wz,Yz,m1,n1,obj1,obj2,obj3,obj4\n")
        for ins in ins_seq:
            if ins.op_type == INS_AVGP:
                index = ins_seq.index(ins)+1
                f.write(f"{index},{ins.name},{ins.xphs_addr},{ins.xphs_len},{ins.W_addr},{ins.W_n_bytes},{ins.B_addr},{ins.X_addr},{ins.Y_addr},{ins.OC},{ins.INC},{ins.INW_},{ins.KH},{ins.KW},{ins.strideH},{ins.strideW},{ins.padL},{ins.padU},{ins.INH2},{ins.INW2},{ins.ifm_height},{ins.ofm_height},{ins.n_last_batch},{ins.n_W_round},{ins.row_bound},{ins.col_bound},{ins.vec_size},{ins.vec_size_minus_1},{ins.Xz},{ins.Wz},{ins.Yz},{ins.m1},{ins.n1},{ins.obj1},{ins.obj2},{ins.obj3},{ins.obj4}\n")
    # Add
    with open(os.path.join(debug_dir, "ins_add.csv"), mode="w", encoding="utf8") as f:
        f.write("Index,Name,A_addr,B_addr,C_addr,len,m1,m2,n,Az,Bz,Cz\n")
        for ins in ins_seq:
            if ins.op_type == INS_ADD:
                index = ins_seq.index(ins)+1
                f.write(f"{index},{ins.name},{ins.A_addr},{ins.B_addr},{ins.C_addr},{ins.len},{ins.m1},{ins.m2},{ins.n},{ins.Az},{ins.Bz},{ins.Cz}\n")
    # Remap
    with open(os.path.join(debug_dir, "ins_remap.csv"), mode="w", encoding="utf8") as f:
        f.write("Index,Name,X_addr,Y_addr,len,m1,n1,Xz,Yz\n")
        for ins in ins_seq:
            if ins.op_type == INS_REMAP:
                index = ins_seq.index(ins)+1
                f.write(f"{index},{ins.name},{ins.X_addr},{ins.Y_addr},{ins.len},{ins.m1},{ins.n1},{ins.Xz},{ins.Yz}\n")
    # Fc
    with open(os.path.join(debug_dir, "ins_fc.csv"), mode="w", encoding="utf8") as f:
        f.write("Index,Name,xphs_addr,xphs_len,W_addr,W_n_bytes,B_addr,X_addr,Y_addr,OC,INC,INW_,KH,KW,strideH,strideW,padL,padU,INH2,INW2,ifm_height,ofm_height,n_last_batch,n_W_round,row_bound,col_bound,vec_size,vec_size_minus_1,Xz,Wz,Yz,m1,n1,obj1,obj2,obj3,obj4\n")
        for ins in ins_seq:
            if ins.op_type == INS_FC:
                index = ins_seq.index(ins)+1
                f.write(f"{index},{ins.name},{ins.xphs_addr},{ins.xphs_len},{ins.W_addr},{ins.W_n_bytes},{ins.B_addr},{ins.X_addr},{ins.Y_addr},{ins.OC},{ins.INC},{ins.INW_},{ins.KH},{ins.KW},{ins.strideH},{ins.strideW},{ins.padL},{ins.padU},{ins.INH2},{ins.INW2},{ins.ifm_height},{ins.ofm_height},{ins.n_last_batch},{ins.n_W_round},{ins.row_bound},{ins.col_bound},{ins.vec_size},{ins.vec_size_minus_1},{ins.Xz},{ins.Wz},{ins.Yz},{ins.m1},{ins.n1},{ins.obj1},{ins.obj2},{ins.obj3},{ins.obj4}\n")
            
    Log.i("Dumper: Dump instructions for debugging sucessfully.")

def dump_debug_xphs(
    output_dir_path: str,
    mem_xphs: Dict[str, np.ndarray]
) -> None:
    """Dump human-readable xphs for debugging purpose."""
    Log.i("Dumper: Start dumping X packet headers for debugging.")
    debug_dir = os.path.join(output_dir_path, "debug")
    if not os.path.exists(debug_dir):
        os.makedirs(debug_dir)
    with open(os.path.join(debug_dir, "xphs.csv"), mode="w", encoding="utf8") as f:
        f.write("Ins_name,Index,X_a_,len_per_chan,win_x,win_y\n")
        for ins_name, xphs in mem_xphs.items():
            for i in range(xphs.shape[0]):
                arr = xphs[i]
                f.write(f"{ins_name},{i+1},{(arr[1]<<8)+arr[0]},{(arr[3]<<8)+arr[2]},{(arr[5]<<8)+arr[4]},{(arr[7]<<8)+arr[6]}\n")
    Log.i("Dumper: Dump X packet headers for debugging sucessfully.")
