import os
import numpy as np
import time

def _load_conv_shapes(fp):
    ret = set()
    raw_data = np.loadtxt(fp, str, delimiter=",")
    for i in range(1, len(raw_data)):
        _, _, OC, INC, INH_, INW_, KH, KW, strideH, strideW, padL, padR, padU, padD = raw_data[i]
        ret.add((
            int(OC), int(INC), int(INH_), int(INW_), 
            int(KH), int(KW), int(strideH), int(strideW), 
            int(padL), int(padR), int(padU), int(padD), 
        ))
    return list(ret)

def main(M, P, Q, R, S, fp):
    shapes = _load_conv_shapes(fp)
    if len(shapes) == 0:
        print(f"There is no conv shape in the file {fp}")
        exit(0)
    # Build command
    cmd = ""
    for shape in shapes:
        OC, INC, INH_, INW_, KH, KW, strideH, strideW, padL, padR, padU, padD = shape
        for w_mode in ["sta", "dyn"]:
            workdir_name = f"{M}_{P}_{Q}_{R}_{S}_{OC}_{INC}_{INH_}_{INW_}_{KH}_{KW}_{strideH}_{strideW}_{padL}_{padR}_{padU}_{padD}_{w_mode}_{time.time_ns()}"
            workdir = f"/home/hp50/Desktop/FPGA_linux/cnn_accel6/hdl/tools/build_db/run/{workdir_name}"
            curr_cmd = f"python3 /home/hp50/Desktop/FPGA_linux/cnn_accel6/hdl/tools/build_db/run_tb.py --M {M} --P {P} --Q {Q} --R {R} --S {S} --OC {OC} --INC {INC} --INH_ {INH_} --INW_ {INW_} --KH {KH} --KW {KW} --strideH {strideH} --strideW {strideW} --padL {padL} --padR {padR} --padU {padU} --padD {padD} --w_mode {w_mode} --workdir {workdir} --db_fp /home/hp50/Desktop/FPGA_linux/cnn_accel6/hdl/tools/build_db/db.csv --ori_src_dir /home/hp50/Desktop/FPGA_linux/cnn_accel6/hdl/src --ori_tb_dir /home/hp50/Desktop/FPGA_linux/cnn_accel6/hdl/tb --ori_work_dir /home/hp50/Desktop/FPGA_linux/cnn_accel6/hdl/work"
            cmd += f"{curr_cmd} & \n"

    os.system(cmd)

# M, P, Q, R, S = 32, 32, 16, 32, 4
# M, P, Q, R, S = 32, 32, 16, 16, 8
# M, P, Q, R, S = 32, 64, 16, 32, 4
# M, P, Q, R, S = 32, 64, 16, 16, 8
# M, P, Q, R, S = 32, 96, 16, 32, 4
# M, P, Q, R, S = 32, 96, 16, 16, 8
# M, P, Q, R, S = 64, 64, 16, 32, 4
M, P, Q, R, S = 64, 64, 16, 16, 8
model_name = "inceptionv3"
main(
    M, P, Q, R, S, 
    f"/home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/be_out/{model_name}_M{M}P{P}Q{Q}R{R}S{S}/conv_shapes.csv"
)
