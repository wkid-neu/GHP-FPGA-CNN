import os
import shutil

ana_dir_path = "/media/fpgagogogo/E1FDBB88D64498E9/program/Python/cnn_accel6/ana"
exp_res_dir_path = "/media/fpgagogogo/E1FDBB88D64498E9/program/FPGA_linux/cnn_accel6/linux_driver/exp_res"
be_out_dir_path = "/media/fpgagogogo/E1FDBB88D64498E9/program/Python/cnn_accel6/be_out"

models = [
    "alexnetb", 
    "inceptionv3", "inceptionv4",
    "resnet18", "resnet34", "resnet50", "resnet101", "resnet152", 
    "selecsls42b", "selecsls60", 
    "squeezenet_v1_0", "squeezenet_v1_1", 
    "vgg11", "vgg13", "vgg16", "vgg19", 
    "vovnet27s"
]
accels = [
    "M32P32Q16R16S8", "M32P64Q16R16S8", "M32P96Q16R16S8", "M64P64Q16R16S8"
]

def _create_dir():
    for model_name in models:
        for accel_name in accels:
            dir_name = f"{model_name}_{accel_name}"
            dir_path = os.path.join(ana_dir_path, dir_name)
            if not os.path.exists(dir_path):
                os.makedirs(dir_path)

def _cp_e2e_perf():
    for model_name in models:
        for accel_name in accels:
            dst_file_path = os.path.join(ana_dir_path, f"{model_name}_{accel_name}", "e2e_perf.csv")
            src_file_path = os.path.join(exp_res_dir_path, f"{model_name}_{accel_name}", "e2e_perf.csv")
            if os.path.exists(src_file_path):
                shutil.copy(src_file_path, dst_file_path)

def _cp_ins_perf():
    for model_name in models:
        for accel_name in accels:
            dst_file_path = os.path.join(ana_dir_path, f"{model_name}_{accel_name}", "ins_perf.csv")
            src_file_path = os.path.join(exp_res_dir_path, f"{model_name}_{accel_name}", "ins_perf.csv")
            if os.path.exists(src_file_path):
                shutil.copy(src_file_path, dst_file_path)

def _cp_ins_seq():
    for model_name in models:
        for accel_name in accels:
            dst_file_path = os.path.join(ana_dir_path, f"{model_name}_{accel_name}", "ins_seq.csv")
            src_file_path = os.path.join(be_out_dir_path, f"{model_name}_{accel_name}", "debug", "ins_seq.csv")
            if os.path.exists(src_file_path):
                shutil.copy(src_file_path, dst_file_path)

def _cp_layer_info():
    for model_name in models:
        for accel_name in accels:
            dst_file_path = os.path.join(ana_dir_path, f"{model_name}_{accel_name}", "layer_info.csv")
            src_file_path = os.path.join(be_out_dir_path, f"{model_name}_{accel_name}", "layer_info.csv")
            if os.path.exists(src_file_path):
                shutil.copy(src_file_path, dst_file_path)

_create_dir()
_cp_e2e_perf()
_cp_ins_perf()
_cp_ins_seq()
_cp_layer_info()
