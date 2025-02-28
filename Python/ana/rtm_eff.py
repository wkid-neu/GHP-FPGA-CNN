import numpy as np
import matplotlib.pyplot as plt

models = [
    "alexnetb", 
    "inceptionv3", "inceptionv4",
    "resnet18", "resnet34", "resnet50", "resnet101", "resnet152", 
    "selecsls42b", "selecsls60", 
    "squeezenet_v1_0", "squeezenet_v1_1", 
    "vgg11", "vgg13", "vgg16", "vgg19", 
    "vovnet27s"
]
labels = [
    "$\mathbf{alexnetb}$",
    "$\mathbf{inceptionv3}$", "$\mathbf{inceptionv4}$",
    "$\mathbf{resnet18}$", "$\mathbf{resnet34}$", "$\mathbf{resnet50}$", "$\mathbf{resnet101}$", "$\mathbf{resnet152}$", 
    "$\mathbf{selecsls42b}$", "$\mathbf{selecsls60}$",
    "$\mathbf{squeezenet 1.0}$", "$\mathbf{squeezenet 1.1}$",
    "$\mathbf{vgg11}$", "$\mathbf{vgg13}$", "$\mathbf{vgg16}$", "$\mathbf{vgg19}$",
    "$\mathbf{vovnet27s}$"
]

def _find_mem_size(model_name):
    data = np.loadtxt(f"../be_out/{model_name}_M32P32Q16R16S8/rpt_rtm.csv", str, delimiter=",")
    algo_size = data[-1][2].split("/")[0]
    linear_size = data[-1][3]
    return int(algo_size), int(linear_size)

def plot():
    data_linear, data_algo = [], []
    for model_name in models:
        algo_size, linear_size = _find_mem_size(model_name)
        data_linear.append(linear_size)
        data_algo.append(algo_size)

    min_ratio, min_idx = 1000, -1
    for i in range(len(data_linear)):
        model_name, lin, algo = models[i], data_linear[i], data_algo[i]
        ratio = lin/algo
        if ratio < min_ratio:
            min_ratio, min_idx = ratio, i
    print(models[min_idx], data_linear[min_idx], data_algo[min_idx], min_ratio)

    max_ratio, max_idx = 0, -1
    for i in range(len(data_linear)):
        model_name, lin, algo = models[i], data_linear[i], data_algo[i]
        ratio = lin/algo
        if ratio > max_ratio:
            max_ratio, max_idx = ratio, i
    print(models[max_idx], data_linear[max_idx], data_algo[max_idx], max_ratio)

    # plt.figure(figsize=(4.8,6.4))

    width = 0.75
    spine_width = 1
    colors = ['#6C8EBF', '#B85450']
    plt.bar([it-(width/4) for it in range(len(models))], data_linear, width=width/2, color=colors[0],label="Sequential")
    plt.bar([it+(width/4) for it in range(len(models))], data_algo, width=width/2, color=colors[1],label="Algorithm 3.1")
    plt.plot([-1,len(models)],[65536,65536], linestyle="--", color=colors[1])

    plt.xticks(range(len(models)), labels, rotation=65)
    ax = plt.gca()
    ax.tick_params(which='both', width=3, length=0, direction='in')
    ax.yaxis.set_tick_params(labelsize=15)
    ax.xaxis.set_tick_params(labelsize=13)
    y_ticks = range(0, 350000, 50000)
    y_labels = ["$\mathbf{" + str(it) + "}$" for it in y_ticks] 
    plt.yticks(y_ticks, y_labels)

    ax.spines['top'].set_linewidth(0)
    ax.spines['bottom'].set_linewidth(spine_width)
    ax.spines['left'].set_linewidth(spine_width)
    ax.spines['right'].set_linewidth(0)

    plt.xlim((-0.5, len(models)-0.5))
    
    plt.subplots_adjust(left=0.15, right=0.97, top=0.97, bottom=0.3)
    plt.savefig("rtm_eff.png")

plot()
