import argparse
import os
import yaml
import numpy as np
import utils
import base
import math
import shutil
from fe.op_QGemm import make_hw_graph, exec_graph

def parse_hw_params(args) -> dict:
    """Parse hardware parameters according to arguments.
    If the option --hw_params_fp is present, we will load parameters from this file.
    Otherwise we will load parameters from args directly.
    """
    ret = {}
    fp = str(args.hw_params_fp)
    if not os.path.exists(fp):
        ret.update({"R": int(args.R)})
        ret.update({"S": int(args.S)})
        ret.update({"DMA_AXI_DATA_WIDTH": int(args.DMA_AXI_DATA_WIDTH)})
    else:
        with open(fp, mode="r", encoding="utf8") as f:
            ret = yaml.safe_load(f)
    return ret

def parse_testcase_conf(args) -> dict:
    """Parse testcase parameters according to arguments.
    If the option --testcase_conf_fp is present, we will load parameters from this file.
    Otherwise we will load parameters from args directly.
    """
    fp = str(args.testcase_conf_fp)
    if not os.path.exists(fp):
        # Only one testcase is given.
        testcase = {}
        testcase.update({"OC": int(args.OC)})
        testcase.update({"INC": int(args.INC)})
        testcase.update({"x_mode": str(args.w_mode)})

        ret = {}
        ret.update({"cases": [testcase]})
    else:
        with open(fp, mode="r", encoding="utf8") as f:
            ret = yaml.safe_load(f)
    return ret

def gen(
    hw_params: dict,
    testcase_conf: dict,
    output_dir_path: str,
    rand_state: int = 1024
):
    """Generate testcases according to the given hw parameters and configurations."""
    np.random.seed(rand_state)

    shutil.rmtree(output_dir_path, ignore_errors=True)
    os.makedirs(output_dir_path)

    instructions = []
    rtm_addr = 0
    bm_addr = 0
    ddr_addr = 0x80000000
    for case_idx in range(len(testcase_conf["cases"])):
        print(f"Generating testcase{case_idx}.")
        test_case = testcase_conf["cases"][case_idx]
        OC = int(test_case["OC"])
        INC = int(test_case["INC"])
        x_mode = str(test_case["x_mode"])
        R = int(hw_params["R"])
        S = int(hw_params["S"])
        DMA_AXI_DATA_WIDTH = int(hw_params["DMA_AXI_DATA_WIDTH"])

        # Generate tensors
        ori_A = np.random.randn(1, INC)
        ori_B = np.random.randn(OC, INC)
        ori_C = np.random.randn(OC, )
        ori_Y = np.matmul(ori_A, ori_B.T)+ori_C

        # Run hw_graph
        A, a_scale, a_zero_point = utils.quant_auto(ori_A, n_bits=8, signed=False)
        B, b_scale, b_zero_point = utils.quant_auto(ori_B, n_bits=8, signed=False)
        C = utils.quant(
            ori_C, a_scale*b_scale, 0,
            n_bits=32, signed=True
        )
        _, y_scale, y_zero_point = utils.quant_auto(ori_Y, n_bits=8, signed=False)
        A, a_scale, a_zero_point = A.astype(np.uint8), np.array([a_scale]), np.array([a_zero_point])
        B, b_scale, b_zero_point = B.astype(np.uint8), np.array([b_scale]), np.array([b_zero_point])
        y_scale, y_zero_point = np.array([y_scale]), np.array([y_zero_point])
        C = C.astype(np.int32)
        hw_graph = make_hw_graph(
            A, a_scale, a_zero_point,
            B, b_scale, b_zero_point,
            C,
            y_scale, y_zero_point
        )
        Y = exec_graph(hw_graph, A)

        # Reorder weights
        reordered_w = base.fc_reorder_weights(B)

        # Save tensors into file
        A.tofile(os.path.join(output_dir_path, f"x{case_idx}.hex"))
        reordered_w.tofile(os.path.join(output_dir_path, f"w{case_idx}.hex"))
        C.tofile(os.path.join(output_dir_path, f"bias{case_idx}.hex"))
        Y.tofile(os.path.join(output_dir_path, f"y{case_idx}.hex"))

        # Generate instruction (a tuple)
        M1 = float(a_scale)*float(b_scale)/float(y_scale)
        n1, m1 = utils.quantize_M(M1, 26)
        # Address
        n_rnd = OC//(DMA_AXI_DATA_WIDTH//8)
        W_addr, W_n_bytes = ddr_addr, OC*INC
        ddr_addr += W_n_bytes
        if x_mode == "V-mode":
            X_addr, X_len = rtm_addr, math.ceil(INC/(R*S))
        else:
            X_addr, X_len = rtm_addr, math.ceil(INC/S)
        rtm_addr += X_len
        Y_addr, Y_len = rtm_addr, math.ceil(OC/(R*S))
        rtm_addr += Y_len
        B_addr, B_len = bm_addr, OC//(DMA_AXI_DATA_WIDTH//32)
        bm_addr += B_len
        instructions.append((
            0, n_rnd-1, W_addr, W_n_bytes, B_addr, X_addr, Y_addr,
            0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, INC, INC-1,
            int(a_zero_point), int(b_zero_point), int(y_zero_point), m1, n1-1,
            0 if x_mode == "T-mode" else 1, 0, 0, 0
        ))

    # Save instructions into file
    with open(os.path.join(output_dir_path, "ins.txt"), mode="w", encoding="utf8") as f:
        for ins in instructions:
            f.write(" ".join([str(field) for field in ins]))
            f.write("\n")

def main():
    parser = argparse.ArgumentParser()
    # Hardware Parameters
    parser.add_argument("--hw_params_fp", default="")
    parser.add_argument("--R", default=0)
    parser.add_argument("--S", default=0)
    parser.add_argument("--DMA_AXI_DATA_WIDTH", default=0)
    # Testcase Configurations
    parser.add_argument("--testcase_conf_fp", default="")
    parser.add_argument("--OC", default=0)
    parser.add_argument("--INC", default=0)
    parser.add_argument("--x_mode", default="sta")
    # Output directory
    parser.add_argument("--output_dir_path", default="")
    # Random state
    parser.add_argument("--rand_state", default=2023)

    args = parser.parse_args()
    hw_params = parse_hw_params(args)
    testcase_conf = parse_testcase_conf(args)
    output_dir_path = str(args.output_dir_path)
    rand_state = int(args.rand_state)

    # Generate testcase
    gen(hw_params, testcase_conf, output_dir_path, rand_state)

if __name__=="__main__":
    main()
