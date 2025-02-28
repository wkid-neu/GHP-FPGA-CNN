import argparse
import os
import yaml
import numpy as np
import torch
import torch.nn.functional as F
import utils
import base
import shutil
import math
from fe.op_QLinearAveragePool import make_hw_graph, exec_graph

def parse_hw_params(args) -> dict:
    """Parse hardware parameters according to arguments.
    If the option --hw_params_fp is present, we will load parameters from this file.
    Otherwise we will load parameters from args directly.
    """
    ret = {}
    fp = str(args.hw_params_fp)
    if not os.path.exists(fp):
        ret.update({"M": int(args.M)})
        ret.update({"P": int(args.P)})
        ret.update({"Q": int(args.Q)})
        ret.update({"R": int(args.R)})
        ret.update({"S": int(args.S)})
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
        testcase.update({"INH_": int(args.INH_)})
        testcase.update({"INW_": int(args.INW_)})
        testcase.update({"KH": int(args.KH)})
        testcase.update({"KW": int(args.KW)})
        testcase.update({"strideH": int(args.strideH)})
        testcase.update({"strideW": int(args.strideW)})
        testcase.update({"padL": int(args.padL)})
        testcase.update({"padR": int(args.padR)})
        testcase.update({"padU": int(args.padU)})
        testcase.update({"padD": int(args.padD)})

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
    """Generate testcases according to the given hw_params and testcase_conf."""
    np.random.seed(rand_state)

    shutil.rmtree(output_dir_path, ignore_errors=True)
    os.makedirs(output_dir_path)

    instructions = []
    xphm_addr = 0
    rtm_addr = 0
    for case_idx in range(len(testcase_conf["cases"])):
        print(f"Generating testcase{case_idx}.")
        test_case = testcase_conf["cases"][case_idx]
        OC, INC, INH_, INW_ = int(test_case["OC"]), int(test_case["INC"]), int(test_case["INH_"]), int(test_case["INW_"])
        KH, KW, strideH, strideW = int(test_case["KH"]), int(test_case["KW"]), int(test_case["strideH"]), int(test_case["strideW"])
        padL, padR, padU, padD = int(test_case["padL"]), int(test_case["padR"]), int(test_case["padU"]), int(test_case["padD"])
        M, P, Q, R, S = int(hw_params["M"]), int(hw_params["P"]), int(hw_params["Q"]), int(hw_params["R"]), int(hw_params["S"])

        OH, OW = utils.conv_get_ofm_shape(
            INH_, INW_, KH, KW, strideH, strideW,
            padL, padR, padU, padD
        )

        # Generate tensors
        ori_X = np.random.randn(1, INC, INH_, INW_)
        ori_Y = F.pad(
            input=torch.tensor(ori_X),
            pad=(padL, padR, padU, padD),
            mode="constant",
            value=0.0
        )
        ori_Y = F.avg_pool2d(
            input=ori_Y,
            kernel_size=(KH, KW),
            stride=(strideH, strideW),
            padding=(0,0),
            ceil_mode=False,
            count_include_pad=True
        ).numpy()

        # Run hw_graph
        X, x_scale, x_zero_point = utils.quant_auto(ori_X, n_bits=8, signed=False)
        _, y_scale, y_zero_point = utils.quant_auto(ori_Y, n_bits=8, signed=False)
        X, x_scale, x_zero_point = X.astype(np.uint8), np.array([x_scale]), np.array([x_zero_point])
        y_scale, y_zero_point = np.array([y_scale]), np.array([y_zero_point])
        hw_graph = make_hw_graph(
            X, x_scale, x_zero_point,
            y_scale, y_zero_point,
            kernel_shape=(KH, KW),
            pads=(padU, padL, padD, padR),  # new paddings
            strides=(strideH, strideW)
        )
        Y = exec_graph(hw_graph, X)

        # Generate xphs
        xphs = base.gen_xphs(
            INH_, INW_, KH, KW, strideH, strideH,
            padL, padR, padU, padD,
            P, Q
        )
        n_x_rnd = len(xphs)
        xphs = np.array([
            [xph.X_a_, xph.len_per_chan, xph.win_x, xph.win_y] for xph in xphs
        ]).astype(np.uint16)

        # Generate Matrix X, see conv.drawio for details
        Cs = []
        for i in range(S):
            # blk
            blk = X[:, i::S, :, :][0]
            # A
            A = utils.im2col(
                torch.tensor(blk.astype(np.float32)), 
                KH, KW, strideH, strideH, padL, padR, padU, padD, 
                int(x_zero_point)
            ).numpy().astype(np.uint8)
            # B
            n_pad_cols = n_x_rnd*P-A.shape[-1]
            if n_pad_cols > 0:
                last_col = A[:, -1]
                B = np.column_stack((A, np.column_stack([last_col]*n_pad_cols)))
            else:
                B = A
            # C
            sub_C = []
            for x_rnd in range(n_x_rnd):
                sub_C.append(B[:, x_rnd*P:(x_rnd+1)*P])
            C = np.row_stack(sub_C)
            Cs.append(C)
        # D
        Ds = []
        for i in range(S//2):
            C1, C2 = Cs[i*2], Cs[i*2+1]
            D_cols = []
            for j in range(C1.shape[-1]):
                D_cols.append(C1[:, j])
                D_cols.append(C2[:, j])
            D = np.column_stack(D_cols)
            Ds.append(D)
        # E
        E_rows = []
        for i in range(Ds[0].shape[0]):
            for j in range(len(Ds)):
                E_rows.append(Ds[j][i, :])
        E = np.row_stack(E_rows)
        # E is the final mat_X
        mat_X = E

        # Save tensors into file
        X.tofile(os.path.join(output_dir_path, f"X{case_idx}.hex"))
        Y.tofile(os.path.join(output_dir_path, f"Y{case_idx}.hex"))
        xphs.tofile(os.path.join(output_dir_path, f"xphs{case_idx}.hex"))
        mat_X.tofile(os.path.join(output_dir_path, f"mat{case_idx}.hex"))

        # Generate instruction (a tuple)
        N = KH*KW
        M1 = float(x_scale)/(float(y_scale)*N)
        n1, m1 = utils.quantize_M(M1, 26)
        n_x_rnd = math.ceil(OH*OW/P)
        (
            INH2, INW2, ifm_height, ofm_height, n_last_batch, n_w_rnd, 
            row_bound, col_bound, vec_size, vec_size_minus_1
        ) = base.pool_params(
            OC, INC, INH_, INW_,
            KH, KW, strideH, strideW,
            padL, padR, padU, padD,
            M, P, R, S
        )
        neg_nxz = -KH*KW*int(x_zero_point)
        # Address
        xphs_addr = xphm_addr
        xphm_addr += n_x_rnd
        X_addr, X_len = rtm_addr, INC//S*ifm_height
        rtm_addr += X_len
        Y_addr, Y_len = rtm_addr, OC//S*ofm_height
        rtm_addr += Y_len
        instructions.append((
            xphs_addr, n_x_rnd-1, 0, 0, 0, X_addr, Y_addr,
            OC, INC//S-1, INW_, KH-1, KW-1, strideH, strideW, padL, padU,
            INH2, INW2, ifm_height, ofm_height, n_last_batch, 0, row_bound, col_bound, vec_size, vec_size_minus_1,
            int(x_zero_point), 0, int(y_zero_point), m1, n1-1,
            neg_nxz & 0x000000ff, (neg_nxz & 0x0000ff00) >> 8, 0, 0
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
    parser.add_argument("--M", default=0)
    parser.add_argument("--P", default=0)
    parser.add_argument("--Q", default=0)
    parser.add_argument("--R", default=0)
    parser.add_argument("--S", default=0)
    # Testcase Configurations
    parser.add_argument("--testcase_conf_fp", default="")
    parser.add_argument("--OC", default=0)
    parser.add_argument("--INC", default=0)
    parser.add_argument("--INH_", default=0)
    parser.add_argument("--INW_", default=0)
    parser.add_argument("--KH", default=0)
    parser.add_argument("--KW", default=0)
    parser.add_argument("--strideH", default=0)
    parser.add_argument("--strideW", default=0)
    parser.add_argument("--padL", default=0)
    parser.add_argument("--padR", default=0)
    parser.add_argument("--padU", default=0)
    parser.add_argument("--padD", default=0)
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
