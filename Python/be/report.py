from log import Log
import os
from typing import Dict, Tuple, List, Union
from be.ins import Conv, Remap, Add, INS_CONV, INS_FC, INS_MAXP, INS_AVGP

def report_rtm(
    rtm_res: Dict[str, Tuple[str, int, int]],
    rtm_dep: int,
    output_dir_path: str
) -> None:
    """Report the usage of RTM."""
    Log.i("Report: Start reporting RTM utilization.")
    max_addr = 0
    total_size = 0
    with open(os.path.join(output_dir_path, "rpt_rtm.csv"), mode="w", encoding="utf8") as f:
        f.write("Tensor/Vector_name,Start,End,Size,Mode\n")
        for name, (mode, addr, size) in rtm_res.items():
            f.write(f"{name},{addr},{addr+size-1},{size},{mode}\n")
            total_size += size
            max_addr = max(max_addr, addr+size-1)
        # Final report
        percent = "{}/{} ({:.2f}%)".format(max_addr+1, rtm_dep, (max_addr+1)*100/rtm_dep)
        f.write(f"TOTAL,0,{percent},{total_size},--\n")
        # Capacity checking
        if max_addr+1 > rtm_dep:
            Log.e(f"RTM is used up, required: {max_addr+1}, provided: {rtm_dep}.")

    Log.i("Report: Report RTM utilization successfully.")

def report_cwm(
    ins_seq: List[Union[Conv, Add, Remap]],
    cwm_res: Dict[str, Tuple[bool, int, int]],
    cwm_dep: int,
    output_dir_path: str,
    M: int
) -> None:
    """Report the usage of CWM."""
    Log.i("Report: Start reporting CWM utilization.")
    # Find instructions with static and dynamic weights
    sta_ins_list, dyn_ins_list = [], []
    for ins in ins_seq:
        if ins.op_type == INS_CONV:
            if ins.W_addr < 0x80000000:
                sta_ins_list.append(ins)
            else:
                dyn_ins_list.append(ins)
    # Sort in ascending order
    sta_ins_list = sorted(sta_ins_list, key=lambda k: cwm_res[k.name][1], reverse=False)
    dyn_ins_list = sorted(dyn_ins_list, key=lambda k: cwm_res[k.name][1], reverse=False)
    # Weights tensors
    with open(os.path.join(output_dir_path, "rpt_cwm.csv"), mode="w", encoding="utf8") as f:
        f.write("Ins_index,Ins_name,Start,End,Size,Segment\n")
        # Static segment
        sta_total_size = 0
        for ins in sta_ins_list:
            index = ins_seq.index(ins)+1
            _, addr, size = cwm_res[ins.name]
            f.write(f"{index},{ins.name},{addr},{addr+size-1},{size},Static\n")
            sta_total_size += size
        # Dynamic segment
        dyn_max_size_in_cwm = 0
        for ins in dyn_ins_list:
            index = ins_seq.index(ins)+1
            _, addr, size = cwm_res[ins.name]
            size_in_cwm = size//(M*4)
            f.write(f"{index},{ins.name},{sta_total_size},{sta_total_size+size_in_cwm-1},{size_in_cwm},Dynamic\n")
            dyn_max_size_in_cwm = max(dyn_max_size_in_cwm, size_in_cwm)
        # Total
        percent_static = "{}/{} ({:.2f}%)".format(sta_total_size, cwm_dep, sta_total_size*100/cwm_dep)
        percent_dynamic = "{}/{} ({:.2f}%)".format(dyn_max_size_in_cwm, cwm_dep, dyn_max_size_in_cwm*100/cwm_dep)
        percent_total = "{}/{} ({:.2f}%)".format(sta_total_size+dyn_max_size_in_cwm, cwm_dep, (sta_total_size+dyn_max_size_in_cwm)*100/cwm_dep)
        f.write(f"TOTAL_Static,--,0,{sta_total_size-1},{percent_static},Static\n")
        f.write(f"TOTAL_Dynamic,--,{sta_total_size},{sta_total_size+dyn_max_size_in_cwm-1},{percent_dynamic},Dynamic\n")
        f.write(f"TOTAL_All,--,0,{sta_total_size+dyn_max_size_in_cwm-1},{percent_total},--\n")

    Log.i("Report: Report CWM utilization successfully.")

def report_bm(
    ins_seq: List[Union[Conv, Add, Remap]],
    bm_res: Dict[str, Tuple[int, int]],
    output_dir_path: str,
    bm_dep: int
) -> None:
    """Report the usage of BM."""
    Log.i("Report: Start reporting BM utilization.")
    # Find conv and fc instructions
    ins_list = []
    for ins in ins_seq:
        if ins.op_type in (INS_CONV, INS_FC):
            ins_list.append(ins)
    # Sort in ascending order.
    ins_list = sorted(ins_list, key=lambda k: k.B_addr, reverse=False)
    with open(os.path.join(output_dir_path, "rpt_bm.csv"), mode="w", encoding="utf8") as f:
        f.write("Ins_index,Ins_name,Start,End,Size\n")
        total_size = 0
        for ins in ins_list:
            index = ins_seq.index(ins)+1
            addr, size = bm_res[ins.name]
            total_size += size
            f.write(f"{index},{ins.name},{addr},{addr+size-1},{size}\n")
        # Total
        percent = "{}/{} ({:.2f}%)".format(total_size, bm_dep, total_size*100/bm_dep)
        f.write(f"TOTAL,--,0,{total_size-1},{percent}\n")
        # Capacity checking
        if total_size > bm_dep:
            Log.e(f"BM is used up, required: {total_size}, provided: {bm_dep}.")
    Log.i("Report: Report BM utilization successfully.")

def report_xphm(
    ins_seq: List[Union[Conv, Add, Remap]],
    xphm_res: Dict[str, Tuple[int, int]],
    output_dir_path: str,
    xphm_dep: int
) -> None:
    """Report the usage of XPHM."""
    Log.i("Report: Start reporting XPHM utilization.")
    # Find conv and pool instructions
    ins_list = []
    for ins in ins_seq:
        if ins.op_type in (INS_CONV, INS_MAXP, INS_AVGP):
            ins_list.append(ins)
    # Sort in ascending order
    ins_list = sorted(ins_list, key=lambda k: xphm_res[k.name][0], reverse=False)
    with open(os.path.join(output_dir_path, "rpt_xphm.csv"), mode="w", encoding="utf8") as f:
        f.write("Ins_index,Ins_name,Start,End,Size\n")
        total_size = 0
        for ins in ins_list:
            index = ins_seq.index(ins)+1
            addr, size = xphm_res[ins.name]
            total_size += size
            f.write(f"{index},{ins.name},{addr},{addr+size-1},{size}\n")
        # Total
        percent = "{}/{} ({:.2f}%)".format(total_size, xphm_dep, total_size*100/xphm_dep)
        f.write(f"TOTAL,--,0,{total_size-1},{percent}\n")
        # Capacity checking
        if total_size > xphm_dep:
            Log.e(f"XPHM is used up, required: {total_size}, provided: {xphm_dep}.")
    Log.i("Report: Report XPHM utilization successfully.")

def report_im(
    ins_seq: List[Union[Conv, Add, Remap]],
    output_dir_path: str,
    im_dep: int
) -> None:
    """Report the usage of IM."""
    Log.i("Report: Start reporting IM utilization.")
    with open(os.path.join(output_dir_path, "rpt_im.csv"), mode="w", encoding="utf8") as f:
        f.write("Ins_index,Ins_name,Addr\n")
        total_size = 0
        for i in range(len(ins_seq)):
            ins = ins_seq[i]
            index = ins_seq.index(ins)+1
            total_size += 1
            f.write(f"{index},{ins.name},{i}\n")
        # Total
        percent = "{}/{} ({:.2f}%)".format(total_size, im_dep, total_size*100/im_dep)
        f.write(f"TOTAL,--,{percent}\n")
        # Capacity checking
        if total_size > im_dep:
            Log.e(f"IM is used up, required: {total_size}, provided: {im_dep}.")
    Log.i("Report: Report IM utilization successfully.")
