import numpy as np
import yaml

models = [
    "alexnetb", 
    "inceptionv3", "inceptionv4",
    "resnet18", "resnet34", "resnet50", "resnet101", "resnet152", 
    "selecsls42b", "selecsls60", 
    "squeezenet_v1_0", "squeezenet_v1_1", 
    "vgg11", "vgg13", "vgg16", "vgg19", 
    "vovnet27s"
]

def _find_unique_kernel_size(model_name):
    ret = set()
    data = np.loadtxt(f"./{model_name}_m32p32/layer_info.csv", str, delimiter=",")
    for i in range(1, len(data)):
        if data[i][1] in ("Conv", "MaxPool", "AvgPool"):
            KH, KW = int(data[i][6]), int(data[i][7])
            ret.add((KH,KW))
    ret = sorted(ret)
    return ret

def _find_unique_strides(model_name):
    ret = set()
    data = np.loadtxt(f"./{model_name}_m32p32/layer_info.csv", str, delimiter=",")
    for i in range(1, len(data)):
        if data[i][1] in ("Conv", "MaxPool", "AvgPool"):
            strideH, strideW = int(data[i][8]), int(data[i][9])
            ret.add((strideH,strideW))
    ret = sorted(ret)
    return ret

def _find_unique_pads(model_name):
    ret = set()
    data = np.loadtxt(f"./{model_name}_m32p32/layer_info.csv", str, delimiter=",")
    for i in range(1, len(data)):
        if data[i][1] in ("Conv", "MaxPool", "AveragePool"):
            padL, padR, padU, padD = int(data[i][10]), int(data[i][11]), int(data[i][12]), int(data[i][13])
            ret.add((padL, padR, padU, padD))
    ret = sorted(ret)
    return ret

def _find_layers(model_name):
    conv, pool, add, fc = 0, 0, 0, 0
    data = np.loadtxt(f"./{model_name}_m32p32/layer_info.csv", str, delimiter=",")
    for i in range(1, len(data)):
        layer_type = data[i][1]
        if layer_type == "Conv":
            conv += 1
        elif layer_type == "MaxPool" or layer_type == "AveragePool":
            pool += 1
        elif layer_type == "Add":
            add += 1
        elif layer_type == "Fc":
            fc += 1
        else:
            raise ValueError(f"Unknown layer type: {layer_type}")
    return (conv, pool, add, fc)

def _find_gop(model_name):
    with open(f"./{model_name}_m32p32/res_e2e.yaml", mode="r", encoding="utf8") as f:
        data = yaml.safe_load(f)
        n_op = int(data["hw_conv_op"].replace(" OP", ""))
        return n_op/(10**9)

with open("model_topo.csv", mode="w", encoding="utf8") as f:
    data = []
    for model_name in models:
        model_data = {"name": model_name}

        kernel_sizes = _find_unique_kernel_size(model_name)
        model_data.update({
            "kernel_size": kernel_sizes
        })

        strides = _find_unique_strides(model_name)
        model_data.update({
            "strides": strides
        })

        pads = _find_unique_pads(model_name)
        model_data.update({
            "pads": pads
        })

        n_layers = _find_layers(model_name)
        model_data.update({
            "layers": f"{n_layers[0]} Conv, {n_layers[1]} Pool, {n_layers[2]} Add, {n_layers[3]} Fc"
        })

        gop = _find_gop(model_name)
        model_data.update({
            "gop": "{:.2f}".format(gop)
        })

        data.append(model_data)
    
    yaml.safe_dump(data, f, sort_keys=False, default_flow_style=True)
