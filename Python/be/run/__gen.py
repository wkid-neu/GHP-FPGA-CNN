models = [
    "alexnetb", 
    "inceptionv3", "inceptionv4",
    "resnet18", "resnet34", "resnet50", "resnet101", "resnet152", 
    "selecsls42b", "selecsls60", 
    "squeezenet_v1_0", "squeezenet_v1_1", 
    "vgg11", "vgg13", "vgg16", "vgg19", 
    "vovnet27s"
]

accs = [
    "M32P32Q16R32S4",
    "M32P32Q16R16S8",
    "M32P64Q16R32S4",
    "M32P64Q16R16S8",
    "M32P96Q16R32S4",
    "M32P96Q16R16S8",
    "M64P64Q16R32S4",
    "M64P64Q16R16S8",
]

def M32P32Q16R32S4(model_name):
    with open(f"{model_name}_M32P32Q16R32S4.sh", mode="w", encoding="utf8") as f:
        f.write(f"""export PYTHONPATH=/home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6
python3 /home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/be/main.py --cfg_fp /home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/be/run_cfg/{model_name}_M32P32Q16R32S4.yaml
""")
                
def M32P32Q16R16S8(model_name):
    with open(f"{model_name}_M32P32Q16R16S8.sh", mode="w", encoding="utf8") as f:
        f.write(f"""export PYTHONPATH=/home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6
python3 /home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/be/main.py --cfg_fp /home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/be/run_cfg/{model_name}_M32P32Q16R16S8.yaml
""")

def M32P64Q16R32S4(model_name):
    with open(f"{model_name}_M32P64Q16R32S4.sh", mode="w", encoding="utf8") as f:
        f.write(f"""export PYTHONPATH=/home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6
python3 /home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/be/main.py --cfg_fp /home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/be/run_cfg/{model_name}_M32P64Q16R32S4.yaml
""")
                
def M32P64Q16R16S8(model_name):
    with open(f"{model_name}_M32P64Q16R16S8.sh", mode="w", encoding="utf8") as f:
        f.write(f"""export PYTHONPATH=/home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6
python3 /home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/be/main.py --cfg_fp /home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/be/run_cfg/{model_name}_M32P64Q16R16S8.yaml
""")

def M32P96Q16R32S4(model_name):
    with open(f"{model_name}_M32P96Q16R32S4.sh", mode="w", encoding="utf8") as f:
        f.write(f"""export PYTHONPATH=/home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6
python3 /home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/be/main.py --cfg_fp /home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/be/run_cfg/{model_name}_M32P96Q16R32S4.yaml
""")
                
def M32P96Q16R16S8(model_name):
    with open(f"{model_name}_M32P96Q16R16S8.sh", mode="w", encoding="utf8") as f:
        f.write(f"""export PYTHONPATH=/home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6
python3 /home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/be/main.py --cfg_fp /home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/be/run_cfg/{model_name}_M32P96Q16R16S8.yaml
""")

def M64P64Q16R32S4(model_name):
    with open(f"{model_name}_M64P64Q16R32S4.sh", mode="w", encoding="utf8") as f:
        f.write(f"""export PYTHONPATH=/home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6
python3 /home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/be/main.py --cfg_fp /home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/be/run_cfg/{model_name}_M64P64Q16R32S4.yaml
""")
                
def M64P64Q16R16S8(model_name):
    with open(f"{model_name}_M64P64Q16R16S8.sh", mode="w", encoding="utf8") as f:
        f.write(f"""export PYTHONPATH=/home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6
python3 /home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/be/main.py --cfg_fp /home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/be/run_cfg/{model_name}_M64P64Q16R16S8.yaml
""")

def run_all(model_name):
    with open(f"{model_name}.sh", mode="w", encoding="utf8") as f:
        for acc_name in accs:
            f.write(f"bash {model_name}_{acc_name}.sh\n")

for model_name in models:
    M32P32Q16R16S8(model_name)
    M32P32Q16R32S4(model_name)
    M32P64Q16R16S8(model_name)
    M32P64Q16R32S4(model_name)
    M32P96Q16R16S8(model_name)
    M32P96Q16R32S4(model_name)
    M64P64Q16R16S8(model_name)
    M64P64Q16R32S4(model_name)
    run_all(model_name)
