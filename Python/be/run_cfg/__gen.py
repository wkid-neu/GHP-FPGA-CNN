models = [
    "alexnetb", 
    "inceptionv3", "inceptionv4",
    "resnet18", "resnet34", "resnet50", "resnet101", "resnet152", 
    "selecsls42b", "selecsls60", 
    "squeezenet_v1_0", "squeezenet_v1_1", 
    "vgg11", "vgg13", "vgg16", "vgg19", 
    "vovnet27s"
]

def M32P32Q16R32S4(model_name):
    with open(f"{model_name}_M32P32Q16R32S4.yaml", mode="w", encoding="utf8") as f:
        f.write(f"""# inputs
ir_model_path: /home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/fe_out/{model_name}/ir.onnx
params_path: /home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/fe_out/{model_name}/params.yaml
M: 32
P: 32
Q: 16
R: 32
S: 4
cwm_dep: 163840
bm_dep: 8192
im_dep: 1024
xphm_dep: 8192
rtm_dep: 65536
cwm_prior_knowledge_fp: null
# outputs
output_dir_path: /home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/be_out/{model_name}_M32P32Q16R32S4/
""")

def M32P32Q16R16S8(model_name):
    with open(f"{model_name}_M32P32Q16R16S8.yaml", mode="w", encoding="utf8") as f:
        f.write(f"""# inputs
ir_model_path: /home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/fe_out/{model_name}/ir.onnx
params_path: /home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/fe_out/{model_name}/params.yaml
M: 32
P: 32
Q: 16
R: 16
S: 8
cwm_dep: 163840
bm_dep: 8192
im_dep: 1024
xphm_dep: 8192
rtm_dep: 65536
cwm_prior_knowledge_fp: null
# outputs
output_dir_path: /home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/be_out/{model_name}_M32P32Q16R16S8/
""")

def M32P64Q16R32S4(model_name):
    with open(f"{model_name}_M32P64Q16R32S4.yaml", mode="w", encoding="utf8") as f:
        f.write(f"""# inputs
ir_model_path: /home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/fe_out/{model_name}/ir.onnx
params_path: /home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/fe_out/{model_name}/params.yaml
M: 32
P: 64
Q: 16
R: 32
S: 4
cwm_dep: 163840
bm_dep: 8192
im_dep: 1024
xphm_dep: 8192
rtm_dep: 65536
cwm_prior_knowledge_fp: null
# outputs
output_dir_path: /home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/be_out/{model_name}_M32P64Q16R32S4/
""")
                
def M32P64Q16R16S8(model_name):
    with open(f"{model_name}_M32P64Q16R16S8.yaml", mode="w", encoding="utf8") as f:
        f.write(f"""# inputs
ir_model_path: /home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/fe_out/{model_name}/ir.onnx
params_path: /home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/fe_out/{model_name}/params.yaml
M: 32
P: 64
Q: 16
R: 16
S: 8
cwm_dep: 163840
bm_dep: 8192
im_dep: 1024
xphm_dep: 8192
rtm_dep: 65536
cwm_prior_knowledge_fp: null
# outputs
output_dir_path: /home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/be_out/{model_name}_M32P64Q16R16S8/
""")

def M32P96Q16R32S4(model_name):
    with open(f"{model_name}_M32P96Q16R32S4.yaml", mode="w", encoding="utf8") as f:
        f.write(f"""# inputs
ir_model_path: /home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/fe_out/{model_name}/ir.onnx
params_path: /home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/fe_out/{model_name}/params.yaml
M: 32
P: 96
Q: 16
R: 32
S: 4
cwm_dep: 163840
bm_dep: 8192
im_dep: 1024
xphm_dep: 8192
rtm_dep: 65536
cwm_prior_knowledge_fp: null
# outputs
output_dir_path: /home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/be_out/{model_name}_M32P96Q16R32S4/
""")

def M32P96Q16R16S8(model_name):
    with open(f"{model_name}_M32P96Q16R16S8.yaml", mode="w", encoding="utf8") as f:
        f.write(f"""# inputs
ir_model_path: /home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/fe_out/{model_name}/ir.onnx
params_path: /home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/fe_out/{model_name}/params.yaml
M: 32
P: 96
Q: 16
R: 16
S: 8
cwm_dep: 163840
bm_dep: 8192
im_dep: 1024
xphm_dep: 8192
rtm_dep: 65536
cwm_prior_knowledge_fp: null
# outputs
output_dir_path: /home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/be_out/{model_name}_M32P96Q16R16S8/
""")

def M64P64Q16R32S4(model_name):
    with open(f"{model_name}_M64P64Q16R32S4.yaml", mode="w", encoding="utf8") as f:
        f.write(f"""# inputs
ir_model_path: /home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/fe_out/{model_name}/ir.onnx
params_path: /home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/fe_out/{model_name}/params.yaml
M: 64
P: 64
Q: 16
R: 32
S: 4
cwm_dep: 81920
bm_dep: 8192
im_dep: 1024
xphm_dep: 8192
rtm_dep: 65536
cwm_prior_knowledge_fp: null
# outputs
output_dir_path: /home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/be_out/{model_name}_M64P64Q16R32S4/
""")

def M64P64Q16R16S8(model_name):
    with open(f"{model_name}_M64P64Q16R16S8.yaml", mode="w", encoding="utf8") as f:
        f.write(f"""# inputs
ir_model_path: /home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/fe_out/{model_name}/ir.onnx
params_path: /home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/fe_out/{model_name}/params.yaml
M: 64
P: 64
Q: 16
R: 16
S: 8
cwm_dep: 81920
bm_dep: 8192
im_dep: 1024
xphm_dep: 8192
rtm_dep: 65536
cwm_prior_knowledge_fp: null
# outputs
output_dir_path: /home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/be_out/{model_name}_M64P64Q16R16S8/
""")

for model_name in models:
    M32P32Q16R16S8(model_name)
    M32P32Q16R32S4(model_name)
    M32P64Q16R16S8(model_name)
    M32P64Q16R32S4(model_name)
    M32P96Q16R16S8(model_name)
    M32P96Q16R32S4(model_name)
    M64P64Q16R16S8(model_name)
    M64P64Q16R32S4(model_name)
