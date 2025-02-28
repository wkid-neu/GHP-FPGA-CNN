import argparse
import yaml
import os
import shutil
import onnx
from be import preproc
from be import exec
from be import rtm
from be import cwm
from be import fcwm
from be import bm
from be import xphm
from be import dram
from be import ins
from be import mem_gen
from be import dumper
from be import report
import numpy as np

np.random.seed(2022) 

if __name__=="__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--cfg_fp")
    args = parser.parse_args()

    cfg_fp = str(args.cfg_fp)
    with open(cfg_fp, mode="r", encoding="utf8") as f:
        cfg_data = yaml.safe_load(f)
        ir_model_path = cfg_data["ir_model_path"]
        params_path = cfg_data["params_path"]
        M = cfg_data["M"]
        P = cfg_data["P"]
        Q = cfg_data["Q"]
        R = cfg_data["R"]
        S = cfg_data["S"]
        cwm_dep = cfg_data["cwm_dep"]
        bm_dep = cfg_data["bm_dep"]
        im_dep = cfg_data["im_dep"]
        xphm_dep = cfg_data["xphm_dep"]
        rtm_dep = cfg_data["rtm_dep"]
        cwm_prior_knowledge_fp = cfg_data["cwm_prior_knowledge_fp"]
        output_dir_path = cfg_data["output_dir_path"]

    # Clear output directory
    shutil.rmtree(output_dir_path, ignore_errors=True)
    os.makedirs(output_dir_path)

    onnx_graph = onnx.load(ir_model_path).graph
    with open(params_path, mode="r", encoding="utf8") as f:
        params = yaml.safe_load(f)

    # Pre-processing
    graph = preproc.proc(
        onnx_graph=onnx_graph,
        output_dir_path=output_dir_path
    )

    # exec_seq
    exec_seq = exec.make_exec_seq(graph)

    # RTM
    rtm_res = rtm.malloc(
        graph=graph,
        exec_seq=exec_seq,
        params=params,
        M=M, R=R, S=S
    )
    
    # CWM
    cwm_res = cwm.malloc(
        graph=graph,
        exec_seq=exec_seq,
        params=params,
        M=M, P=P, Q=Q, R=R, S=S,
        cwm_dep=cwm_dep,
        prior_knowledge_fp=cwm_prior_knowledge_fp
    )

    # FCWM
    fcwm_res = fcwm.malloc(
        graph=graph,
        exec_seq=exec_seq,
        params=params
    )

    # BM
    bm_res = bm.malloc(
        graph=graph,
        exec_seq=exec_seq,
        params=params,
        M=M
    )

    # XPHM
    xphm_res = xphm.malloc(
        graph=graph,
        exec_seq=exec_seq,
        params=params,
        P=P
    )

    # DRAM
    dram_res = dram.malloc(
        graph=graph,
        exec_seq=exec_seq,
        cwm_res=cwm_res,
        fcwm_res=fcwm_res,
        bm_res=bm_res,
        xphm_res=xphm_res,
        rtm_res=rtm_res,
        M=M, R=R, S=S
    )

    # Instructions
    ins_seq = ins.gen_ins(
        graph=graph,
        exec_seq=exec_seq,
        params=params,
        cwm_res=cwm_res,
        fcwm_res=fcwm_res,
        rtm_res=rtm_res,
        bm_res=bm_res,
        xphm_res=xphm_res,
        dram_res=dram_res,
        M=M, P=P, R=R, S=S
    )

    # Memory Generator
    mem_xphs = mem_gen.gen_xphs(
        ins_seq=ins_seq,
        params=params,
        P=P, Q=Q
    )
    mem_weights = mem_gen.gen_weights(
        onnx_graph=onnx_graph,
        graph=graph,
        ins_seq=ins_seq,
        params=params,
        M=M, S=S
    )
    mem_bias = mem_gen.gen_bias(
        onnx_graph=onnx_graph,
        graph=graph,
        ins_seq=ins_seq,
        params=params,
        M=M, S=S
    )

    # Dumper
    dumper.dump_model_info(
        onnx_graph=onnx_graph,
        graph=graph,
        params=params,
        dram_res=dram_res,
        ins_seq=ins_seq,
        rtm_res=rtm_res,
        output_dir_path=output_dir_path
    )
    dumper.dump_ins(
        ins_seq=ins_seq,
        output_dir_path=output_dir_path
    )
    dumper.dump_sta_conv_weights(
        ins_seq=ins_seq,
        output_dir_path=output_dir_path,
        mem_weights=mem_weights
    )
    dumper.dump_dyn_conv_weights(
        ins_seq=ins_seq,
        output_dir_path=output_dir_path,
        mem_weights=mem_weights
    )
    dumper.dump_fc_weights(
        ins_seq=ins_seq,
        output_dir_path=output_dir_path,
        mem_weights=mem_weights
    )
    dumper.dump_xphs(
        ins_seq=ins_seq,
        output_dir_path=output_dir_path,
        mem_xphs=mem_xphs
    )
    dumper.dump_bias(
        ins_seq=ins_seq,
        output_dir_path=output_dir_path,
        mem_bias=mem_bias
    )
    dumper.dump_layer_info(
        graph=graph,
        exec_seq=exec_seq,
        params=params,
        output_dir_path=output_dir_path
    )
    dumper.dump_conv_shape_params(
        ins_seq=ins_seq,
        params=params,
        output_dir_path=output_dir_path,
        S=S
    )
    dumper.dump_debug_ins_seq(
        ins_seq=ins_seq,
        output_dir_path=output_dir_path
    )
    dumper.dump_debug_xphs(
        output_dir_path=output_dir_path,
        mem_xphs=mem_xphs
    )

    # Report
    report.report_rtm(
        rtm_res=rtm_res,
        rtm_dep=rtm_dep,
        output_dir_path=output_dir_path
    )
    report.report_cwm(
        ins_seq=ins_seq,
        cwm_res=cwm_res,
        cwm_dep=cwm_dep,
        output_dir_path=output_dir_path,
        M=M
    )
    report.report_bm(
        ins_seq=ins_seq,
        bm_res=bm_res,
        output_dir_path=output_dir_path,
        bm_dep=bm_dep
    )
    report.report_xphm(
        ins_seq=ins_seq,
        xphm_res=xphm_res,
        output_dir_path=output_dir_path,
        xphm_dep=xphm_dep
    )
    report.report_im(
        ins_seq=ins_seq,
        output_dir_path=output_dir_path,
        im_dep=im_dep
    )
