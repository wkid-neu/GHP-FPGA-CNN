import os

def _get_n_lines(fp):
    ret = 0
    with open(fp, mode="r", encoding="utf8") as f:
        for line in f:
            line = line.strip()
            if line == "":
                continue
            ret += 1
    return ret

def _scan(dir_path, file_types=None):
    ret = 0
    for it in os.listdir(dir_path):
        path = os.path.join(dir_path, it)
        if os.path.isfile(path):
            if file_types is None:
                ret += _get_n_lines(path)
            else:
                suffix = it.split(".")[1]
                if suffix in file_types:
                    ret += _get_n_lines(path)
        else:
            ret += _scan(path)
    return ret

print(_scan("/home/hp50/Desktop/FPGA_linux/cnn_accel6/hdl/src"))
