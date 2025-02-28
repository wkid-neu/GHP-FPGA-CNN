import os
import time

accs = [
    (32, 32, 16, 32, 4),
    (32, 32, 16, 16, 8),
    (32, 64, 16, 32, 4),
    (32, 64, 16, 16, 8),
    (32, 96, 16, 32, 4),
    (32, 96, 16, 16, 8),
    (64, 64, 16, 32, 4),
    (64, 64, 16, 16, 8)
]

def main(model_name):
    cmd = ""
    for acc in accs:
        M, P, Q, R, S = acc
        workdir_name = f"{M}_{P}_{Q}_{R}_{S}_{model_name}_{time.time_ns()}"
        model_dir_path = f"/home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/be_out/{model_name}_M{M}P{P}Q{Q}R{R}S{S}"
        res_fp = f"/home/hp50/Desktop/FPGA_linux/cnn_accel6/hdl/tools/sim_model/results/{model_name}_M{M}P{P}Q{Q}R{R}S{S}.txt"
        workdir = f"/home/hp50/Desktop/FPGA_linux/cnn_accel6/hdl/tools/sim_model/run/{workdir_name}"
        curr_cmd = f"python3 /home/hp50/Desktop/FPGA_linux/cnn_accel6/hdl/tools/sim_model/run_tb.py --M {M} --P {P} --Q {Q} --R {R} --S {S} --model_dir {model_dir_path} --res_fp {res_fp} --workdir {workdir} --ori_src_dir /home/hp50/Desktop/FPGA_linux/cnn_accel6/hdl/src --ori_tb_dir /home/hp50/Desktop/FPGA_linux/cnn_accel6/hdl/tb --ori_work_dir /home/hp50/Desktop/FPGA_linux/cnn_accel6/hdl/work"
        cmd += f"{curr_cmd} & \n"
    os.system(cmd)

main("alexnetb")
