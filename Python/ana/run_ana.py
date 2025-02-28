import os
import shutil

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

def _run_cmd(cmd):
    ret = os.popen(cmd).read()
    return ret

def run_all():
    for i in range(1, len(models), 1):
        model_name = models[i]
        for accel in accels:
            print(f"Processing {model_name}_{accel}.")
            # Copy proc.py
            shutil.copy(f"./alexnetb_{accel}/proc.py", f"./{model_name}_{accel}/proc.py")
            # Run proc.py
            cmd = f"cd ./{model_name}_{accel} && python3 proc.py"
            _run_cmd(cmd)

run_all()
