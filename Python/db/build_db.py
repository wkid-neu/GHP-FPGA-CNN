import os
import numpy as np

exp_res_dir_path = "/media/fpgagogogo/E1FDBB88D64498E9/program/FPGA_linux/cnn_accel6/linux_driver/exp_res"
dst_file_path = "db.csv"

def parse_MP(dir_name):
    mMpP = dir_name.split("_")[-1]
    if mMpP == "M32P32Q16R16S8":
        return 32, 32, 16, 16, 8
    elif mMpP == "M32P64Q16R16S8":
        return 32, 64, 16, 16, 8
    elif mMpP == "M32P96Q16R16S8":
        return 32 ,96, 16, 16, 8
    elif mMpP == "M64P64Q16R16S8":
        return 64, 64, 16, 16, 8
    else:
        raise ValueError(f"Unknown accelerator {mMpP}")

def build():
    """
    Table format:
    M, P, Q, R, S, OC, INC, INH_, INW_, KH, KW, strideH, strideW, padL, padR, padU, padD, mode, latency(cycles)
    """
    records = {}
    for dir_name in os.listdir(exp_res_dir_path):
        print(f"Processing {dir_name}")
        if not os.path.isdir(os.path.join(exp_res_dir_path, dir_name)):
            continue
        M, P, Q, R, S = parse_MP(dir_name)
        db_file_path = os.path.join(exp_res_dir_path, dir_name, "db.csv")
        data = np.loadtxt(db_file_path, str, delimiter=",")
        for i in range(1, len(data)):
            OC, INC, INH_, INW_, KH, KW, strideH, strideW, padL, padR, padU, padD, mode, latency_cycles = data[i]
            primary_keys = (M, P, Q, R, S, OC, INC, INH_, INW_, KH, KW, strideH, strideW, padL, padR, padU, padD, mode)
            records.update({
                primary_keys: latency_cycles
            })
    # Save
    with open(dst_file_path, mode="w", encoding="utf8") as f:
        f.write("M, P, Q, R, S, OC, INC, INH_, INW_, KH, KW, strideH, strideW, padL, padR, padU, padD, mode, latency(cycles)\n")
        for k, v in records.items():
            f.write(",".join([str(field) for field in k]))
            f.write(f",{v}\n")

build()


