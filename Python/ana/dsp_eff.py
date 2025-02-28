import numpy as np

accs = ["m32p32", "m32p64", "m32p96", "m64p64"]
models = [
    "alexnetb", 
    "inceptionv3", "inceptionv4",
    "resnet18", "resnet34", "resnet50", "resnet101", "resnet152", 
    "selecsls42b", "selecsls60", 
    "squeezenet_v1_0", "squeezenet_v1_1", 
    "vgg11", "vgg13", "vgg16", "vgg19", 
    "vovnet27s"
]

def _find_best_dsp_eff(model_name, acc_name):
    data = np.loadtxt(f"./{model_name}_{acc_name}/res_ins.csv", str, delimiter=",")
    best = 0
    for i in range(1, len(data)):
        dsp_eff = float(data[i][-1])
        best = max(best, dsp_eff)
    return best

for acc_name in accs:
    best = 0
    for model_name in models:
        model_best = _find_best_dsp_eff(model_name, acc_name)
        best = max(best, model_best)
    print(best)
