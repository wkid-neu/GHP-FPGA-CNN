import matplotlib.pyplot as plt
import numpy as np

accs = ["M32P32Q16R16S8", "M32P64Q16R16S8", "M32P96Q16R16S8", "M64P64Q16R16S8"]
models = [
    "alexnetb", 
    "inceptionv3", "inceptionv4",
    "resnet18", "resnet34", "resnet50", "resnet101", "resnet152", 
    "selecsls42b", "selecsls60", 
    "squeezenet_v1_0", "squeezenet_v1_1", 
    "vgg11", "vgg13", "vgg16", "vgg19", 
    "vovnet27s"
]

def _load_conv_throughput(model_name, acc_name):
    ret = []
    data = np.loadtxt(f"./{model_name}_{acc_name}/res_ins.csv", str, delimiter=",")
    for i in range(1, len(data)):
        ins_type = data[i][1]
        if "Conv" in ins_type:
            throughput = float(data[i][8])
            ret.append(throughput)
    return ret

def _load_norm_latency(model_name, acc_name):
    ret = {
        "Conv": 0, "Fc": 0, "Pool": 0, "Add": 0, "Remap": 0
    }
    data = np.loadtxt(f"./{model_name}_{acc_name}/res_ins.csv", str, delimiter=",")
    for i in range(1, len(data)):
        ins_type = data[i][1]
        contirb = float(data[i][5])
        if "Conv" in ins_type:
            ret["Conv"] += contirb/100
        if "Pool" in ins_type:
            ret["Pool"] += contirb/100
        if "Add" in ins_type:
            ret["Add"] += contirb/100
        if "Remap" in ins_type:
            ret["Remap"] += contirb/100
        if "Fc" in ins_type:
            ret["Fc"] += contirb/100
    return ret

def plot_conv_throughput(model_name):
    conv_throughputs = []
    for acc_name in accs:
        conv_throughputs.append(_load_conv_throughput(model_name, acc_name))
    n_conv_ins = len(conv_throughputs[0])

    # colors = ['#FF0000', '#008A00', '#0000FF', '#FF00FF']
    colors = ["#6C8EBF", "#82B366", "#B85450", "#9673A6"]
    markers = ["D", "o", "h", "d"]
    spine_width = 3
    for i in range(len(accs)):
        plt.plot(range(n_conv_ins), conv_throughputs[i], color=colors[i], marker=markers[i], markersize=15, linewidth=3)
    for i in range(len(accs)):
        plt.plot([0,n_conv_ins-1], [1450.67*(i+1), 1450.67*(i+1)], color=colors[i], linestyle="-.", linewidth=3)
    plt.ylim((0,6000))
    
    ax = plt.gca()
    ax.xaxis.set_visible(False)

    ax.tick_params(which='both', width=3, length=7, direction='in')
    ax.yaxis.set_tick_params(labelsize=20)
    plt.xticks([0,n_conv_ins-1], ["", ""])
    plt.yticks([0,1450,2901,4352,5803,6000], ["", "$\mathbf{1.45T}$","$\mathbf{2.90T}$","$\mathbf{4.35T}$","$\mathbf{5.80T}$", ""])

    ax.spines['top'].set_linewidth(0)
    ax.spines['bottom'].set_linewidth(spine_width)
    ax.spines['left'].set_linewidth(spine_width)
    ax.spines['right'].set_linewidth(0)
    
    plt.subplots_adjust(left=0.15, right=0.99, top=0.97, bottom=0.03)
    
    plt.savefig(f"./{model_name}_throughput.png")

def plot_normalized_latency(model_name):
    normalized_latencys = []
    for acc_name in accs:
        normalized_latencys.append(_load_norm_latency(model_name, acc_name))

    # colors = ['c', 'm', 'y', "#6A00FF"]
    colors = ["#6C8EBF", "#82B366", "#B85450", "#9673A6", "#D79B00"]
    width = 0.75
    spine_width = 6

    plt.figure(figsize=(2.4,4.8))
    for i in range(len(accs)):
        normalized_latency = normalized_latencys[i]
        plt.bar([i], normalized_latency["Conv"], bottom=0, color=colors[0], width=width)
        plt.bar([i], normalized_latency["Fc"], bottom=normalized_latency["Conv"], color=colors[1], width=width)
        plt.bar([i], normalized_latency["Pool"], bottom=normalized_latency["Conv"]+normalized_latency["Fc"], color=colors[2], width=width)
        plt.bar([i], normalized_latency["Add"], bottom=normalized_latency["Conv"]+normalized_latency["Fc"]+normalized_latency["Pool"], color=colors[3], width=width)
        plt.bar([i], normalized_latency["Remap"], bottom=normalized_latency["Conv"]+normalized_latency["Fc"]+normalized_latency["Pool"]+normalized_latency["Add"], color=colors[4], width=width)
    plt.xlim((-0.5,3.5))
    plt.ylim((0,1))

    ax = plt.gca()
    ax.yaxis.set_visible(False)
    ax.tick_params(which='both', width=6, length=10, direction='in')
    ax.xaxis.set_tick_params(labelsize=20)
    plt.xticks([0,1,2,3], ["M32P32","M32P64", "M32P96", "M64P64"], rotation=60)

    ax.spines['top'].set_linewidth(0)
    ax.spines['bottom'].set_linewidth(spine_width)
    ax.spines['left'].set_linewidth(0)
    ax.spines['right'].set_linewidth(0)

    plt.subplots_adjust(left=0.03, right=0.97, top=0.97, bottom=0.25)

    plt.savefig(f"./{model_name}_normalized_latency.png")

for model_name in models:
    print(f"Processing {model_name}")
    plot_conv_throughput(model_name)
    plt.close()
    plot_normalized_latency(model_name)
    plt.close()
