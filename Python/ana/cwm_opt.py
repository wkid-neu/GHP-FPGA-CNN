from cwm_alg import opt
import numpy as np

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
cwm_depth_list = [
    163840, 163840, 163840, 81920
]
# db_file_path = "/media/fpgagogogo/E1FDBB88D64498E9/program/Python/cnn_accel6/db/db.csv"
# db_file_path = "F:\program\Python\cnn_accel6\db\db.csv"
db_file_path = "/home/lvxing/SSD1_500G/FPGAcode/cyzcode/Python/cnn_accel6/db/db.csv"

def _get_latency_ns(n_cycles):
    return n_cycles*2.5

def _parse_conf(acc_name):
    if acc_name == "M32P32Q16R16S8":
        return 32, 32, 16, 16, 8
    elif acc_name == "M32P64Q16R16S8":
        return 32, 64, 16, 16, 8
    elif acc_name == "M32P96Q16R16S8":
        return 32 ,96, 16, 16, 8
    elif acc_name == "M64P64Q16R16S8":
        return 64, 64, 16, 16, 8
    else:
        raise ValueError(f"Unknown accelerator {acc_name}")

def _conv_params_alignment(OC, INC, KH, KW, M, S) -> tuple:  # aligned_OC, aligned_INC 
    """Parameters aligment for Conv."""
    # OC must be multiple of 2M
    if OC%(M*2) != 0:
        aligned_OC = (OC//(M*2)+1)*(M*2)
    else:
        aligned_OC = OC
    # INC must be multiple of S
    # Vector size must be a multiple of 8
    # Vector size must be larger than M.
    aligned_INC = INC
    while (aligned_INC*KH*KW < M) or ((aligned_INC*KH*KW)%8 != 0) or (aligned_INC%S != 0):
        aligned_INC += 1
    return aligned_OC, aligned_INC

def _load_db(file_path) -> dict:
    ret = {}
    raw_data = np.loadtxt(file_path, str, delimiter=",")
    for i in range(1, len(raw_data)):
        M, P, Q, R, S, OC, INC, INH_, INW_, KH, KW, strideH, strideW, padL, padR, padU, padD, mode, latency_cycles = raw_data[i]
        primary_keys = (
            int(M), int(P), int(Q), int(R), int(S), 
            int(OC), int(INC), int(INH_), int(INW_), 
            int(KH), int(KW), int(strideH), int(strideW), 
            int(padL), int(padR), int(padU), int(padD), 
            mode
        )
        ret[primary_keys] = int(latency_cycles)
    return ret

def _get_tensor_size(OC, INC, KH, KW, M, S) -> int:
    if OC%(M*2) != 0:
        aligned_OC = (OC//(M*2)+1)*(M*2)
    else:
        aligned_OC = OC
    aligned_INC = INC
    while (aligned_INC*KH*KW < M) or ((aligned_INC*KH*KW)%8 != 0) or (aligned_INC%S != 0):
        aligned_INC += 1
    return aligned_OC*aligned_INC*KH*KW//(4*M)

def _load_conv_layers(model_name, acc_name):
    ret = {}
    data = np.loadtxt(f"./{model_name}_{acc_name}/layer_info.csv", str, delimiter=",")
    for i in range(1, len(data)):
        layer_name = data[i][0]
        layer_type = data[i][1]
        OC, INC, INH_, INW_, KH, KW, strideH, strideW, padL, padR, padU, padD = (
            int(data[i][2]), int(data[i][3]), int(data[i][4]), int(data[i][5]), 
            int(data[i][6]), int(data[i][7]), int(data[i][8]), int(data[i][9]), 
            int(data[i][10]), int(data[i][11]), int(data[i][12]), int(data[i][13])
        )
        if layer_type == "Conv":
            ret[layer_name] = (OC, INC, INH_, INW_, KH, KW, strideH, strideW, padL, padR, padU, padD)
    return ret

def run(model_name, acc_name, cwm_depth):
    # print(f"Processing {model_name}_{acc_name}")
    # Parse configurations from acc_name
    M, P, Q, R, S = _parse_conf(acc_name)
    # Load database
    db_records = _load_db(db_file_path)
    # Load convolutional layers
    conv_layers = _load_conv_layers(model_name, acc_name)
    # Build size_dict
    size_dict = {}
    for layer_name, (OC, INC, INH_, INW_, KH, KW, strideH, strideW, padL, padR, padU, padD) in conv_layers.items():
        tensor_size = _get_tensor_size(OC, INC, KH, KW, M, S)
        size_dict[layer_name] = tensor_size
    # Build sta_latency_dict, dyn_latency_dict
    sta_latency_dict = {}
    dyn_latency_dict = {}
    for layer_name, (OC, INC, INH_, INW_, KH, KW, strideH, strideW, padL, padR, padU, padD) in conv_layers.items():
        OC, INC = _conv_params_alignment(OC, INC, KH, KW, M, S)
        sta_primary_keys = (
            int(M), int(P), int(Q), int(R), int(S), 
            int(OC), int(INC), int(INH_), int(INW_), 
            int(KH), int(KW), int(strideH), int(strideW), 
            int(padL), int(padR), int(padU), int(padD), 
            "sta"
        )
        dyn_primary_keys = (
            int(M), int(P), int(Q), int(R), int(S), 
            int(OC), int(INC), int(INH_), int(INW_), 
            int(KH), int(KW), int(strideH), int(strideW), 
            int(padL), int(padR), int(padU), int(padD), 
            "dyn"
        )
        sta_latency_dict[layer_name] = int(db_records[sta_primary_keys])
        dyn_latency_dict[layer_name] = int(db_records[dyn_primary_keys])
    # Store tensors in static mode
    sta_req_size = sum(size_dict.values())
    if sta_req_size <= cwm_depth:
        # print("All tensors can be stored in static mode.")
        return (True, -1, -1)
    # Store tensors in dynamic mode
    dyn_latency = 0
    for layer_name, (OC, INC, INH_, INW_, KH, KW, strideH, strideW, padL, padR, padU, padD) in conv_layers.items():
        OC, INC = _conv_params_alignment(OC, INC, KH, KW, M, S)
        primary_keys = (
            int(M), int(P), int(Q), int(R), int(S), 
            int(OC), int(INC), int(INH_), int(INW_), 
            int(KH), int(KW), int(strideH), int(strideW), 
            int(padL), int(padR), int(padU), int(padD), 
            "dyn"
        )
        latency = int(db_records[primary_keys])
        dyn_latency += latency
    # Use PSO to find the best solution
    mode_dict, best_latency = opt(
        sta_latency_dict,
        dyn_latency_dict,
        size_dict,
        cwm_depth
    )
    return (False, dyn_latency, best_latency)

for model_name in models:
    for (acc_name, cwm_depth) in zip(accels, cwm_depth_list):
        is_sta, dyn_latency, best_latency = run(model_name, acc_name, cwm_depth)
        if not is_sta:
            before = _get_latency_ns(dyn_latency)
            after = _get_latency_ns(best_latency)
            gain = before - after
            rate = gain/before*100
            print(f"{model_name}_{acc_name}, before: {before} ns, after: {after} ns, gain: {gain} ns, rate: {rate}%")
