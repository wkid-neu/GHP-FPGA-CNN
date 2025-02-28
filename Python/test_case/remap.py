import argparse
import os
import yaml
import numpy as np
import utils
import shutil
from fe.op_QLinearConcat import make_hw_graph, exec_graph

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
        ori_inputs = []
        for i in range(2):
            ori_inputs.append(np.random.randn(1, 1, 1, vec_size))

        # prepare inputs
        input_list, scale_list, zero_point_list = [], [], []
        for i in range(2):
            input, input_scale, input_zero_point = utils.quant_auto(ori_inputs[i], n_bits=8, signed=False)
            input_list.append(input.astype(np.uint8))
            scale_list.append(input_scale)
            zero_point_list.append(input_zero_point)
        if scale_list[0] > scale_list[1]:
            X_idx, Y_idx = 1, 0
        else:
            X_idx, Y_idx = 0, 1
        X, X_scale, X_zero_point = input_list[X_idx], scale_list[X_idx], zero_point_list[X_idx]
        _, Y_scale, Y_zero_point = input_list[Y_idx], scale_list[Y_idx], zero_point_list[Y_idx]

        # Run hw_graph
        input_list = [it.astype(np.uint8) for it in input_list]
        scale_list = [np.array([it]) for it in scale_list]
        zero_point_list = [np.array([it]) for it in zero_point_list]
        Y_scale, Y_zero_point = np.array([Y_scale]), np.array([Y_zero_point])
        inputs = []
        for i in range(2):
            inputs.append([input_list[i], scale_list[i], zero_point_list[i]])
        hw_graph = make_hw_graph(
            Y_scale, Y_zero_point,
            inputs
        )
        hw_res = exec_graph(
            hw_graph,
            input_list
        )
        Y = hw_res[:, X_idx, :, :].flatten()

        # Save tensors into file
        X.tofile(os.path.join(output_dir_path, f"X{case_idx}.hex"))
        Y.tofile(os.path.join(output_dir_path, f"Y{case_idx}.hex"))

        # Generate instruction
        n_item = vec_size//(R*S)
        M = float(X_scale)/float(Y_scale)
        n1, m1 = utils.quantize_M(M, 26)
        # Address
        X_addr = rtm_addr
        rtm_addr += n_item
        Y_addr = rtm_addr
        rtm_addr += n_item
        instructions.append((
            X_addr, Y_addr, n_item-1, m1, n1-1, int(X_zero_point), int(Y_zero_point)
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
