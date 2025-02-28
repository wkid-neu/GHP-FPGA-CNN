import argparse
import os
import yaml
import numpy as np
import utils
import shutil
from fe.op_QLinearAdd import make_hw_graph, exec_graph

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
        testcase.update({"vec_size": int(args.vec_size)})

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
    for case_idx in range(len(testcase_conf["cases"])):
        print(f"Generating testcase{case_idx}.")
        test_case = testcase_conf["cases"][case_idx]
        vec_size = int(test_case["vec_size"])
        R = int(hw_params["R"])
        S = int(hw_params["S"])

        # Generate tensors
        shape = (1, 1, 1, vec_size)
        ori_A = np.random.randn(*shape)
        ori_B = np.random.randn(*shape)
        ori_C = ori_A+ori_B

        # Run hw_graph
        A, A_scale, A_zero_point = utils.quant_auto(ori_A, n_bits=8, signed=False)
        B, B_scale, B_zero_point = utils.quant_auto(ori_B, n_bits=8, signed=False)
        _, C_scale, C_zero_point = utils.quant_auto(ori_C, n_bits=8, signed=False)
        A, A_scale, A_zero_point = A.astype(np.uint8), np.array([A_scale]), np.array([A_zero_point])
        B, B_scale, B_zero_point = B.astype(np.uint8), np.array([B_scale]), np.array([B_zero_point])
        C_scale, C_zero_point = np.array([C_scale]), np.array([C_zero_point])
        hw_graph = make_hw_graph(
            A, A_scale, A_zero_point,
            B, B_scale, B_zero_point,
            C_scale, C_zero_point
        )
        hw_res = exec_graph(
            hw_graph,
            A, B
        )
        C = hw_res.flatten()

        # Save tensors into file
        A.tofile(os.path.join(output_dir_path, f"A{case_idx}.hex"))
        B.tofile(os.path.join(output_dir_path, f"B{case_idx}.hex"))
        C.tofile(os.path.join(output_dir_path, f"C{case_idx}.hex"))

        # Generate instruction
        n_item = vec_size//(R*S)
        M1, M2 = float(A_scale)/float(C_scale), float(B_scale)/float(C_scale)
        n, (m1, m2) = utils.quantize_M_list((M1, M2), 26)
        # Address
        A_addr = rtm_addr
        rtm_addr += n_item
        B_addr = rtm_addr
        rtm_addr += n_item
        C_addr = rtm_addr
        rtm_addr += n_item
        instructions.append((
            A_addr, B_addr, C_addr, n_item-1, m1, m2, n-1, int(A_zero_point), int(B_zero_point), int(C_zero_point)
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
    # Testcase Configurations
    parser.add_argument("--testcase_conf_fp", default="")
    parser.add_argument("--vec_size", default=0)
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
