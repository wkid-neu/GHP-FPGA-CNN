import numpy as np
import yaml

M, P = 32, 96

def get_n_op_conv(
    OC, INC, INH_, INW_,
    KH, KW, strideH, strideW, 
    padL, padR, padU, padD
):
    OH = (INH_+padU+padD-KH)//strideH+1
    OW = (INW_+padL+padR-KW)//strideW+1
    n_pixels = OC*OH*OW
    n_op_pixel = INC*KH*KW*2
    return n_pixels*n_op_pixel

def load_layer_info():  # layer_name -> (layer_type, OC, INC, ..., padD)
    ret = {}
    data = np.loadtxt("layer_info.csv", str, delimiter=",")
    for i in range(1, len(data)):
        ret[data[i][0]] = (
            data[i][1], 
            int(data[i][2]), int(data[i][3]), int(data[i][4]), int(data[i][5]), 
            int(data[i][6]), int(data[i][7]), int(data[i][8]), int(data[i][9]), 
            int(data[i][10]), int(data[i][11]), int(data[i][12]), int(data[i][13])
        )
    return ret

def load_ins_seq():  # ins_name -> (ins_idx, ins_type)
    ret = {}
    data = np.loadtxt("ins_seq.csv", str, delimiter=",")
    for i in range(1, len(data)):
        ret[data[i][1]] = (
            int(data[i][0]), data[i][2]
        )
    return ret

def load_ins_perf():  # ins_idx -> (latency_cycles, latency_ns)
    ret = {}
    data = np.loadtxt(f"ins_perf.csv", str, delimiter=",")
    for i in range(1, len(data)):
        ret[int(data[i][0])] = (int(data[i][1]), int(data[i][2]))
    return ret

def load_e2e_perf():  # [(t1, t2, t3, t4, t5), (t1, t2, t3, t4, t5), ...]
    ret = []
    data = np.loadtxt(f"e2e_perf.csv", str, delimiter=",")
    for i in range(1, len(data)):
        ret.append((int(data[i][1]), int(data[i][2]), int(data[i][3]), int(data[i][4]), int(data[i][5])))
    return ret

def res_ins():
    layer_info = load_layer_info()
    ins_seq = load_ins_seq()
    ins_perf = load_ins_perf()

    # total latency (cycles)
    total_latency_cycles = 0
    for ins_idx, (latency_cycles, _) in ins_perf.items():
        total_latency_cycles += latency_cycles
    
    with open(f"res_ins.csv", mode="w", encoding="utf8") as f:
        f.write("ins_idx,ins_type,latency(cycles),latency(ns),latency(ms),latency_contrib(%),operations(OP),operations(MOP),throughput(GOP/s),efficiency(%)\n")
    
        for ins_name, (ins_idx, ins_type) in ins_seq.items():
            if ins_type == "Conv":
                # latency (cycles, ns, ms)
                latency_cycles, latency_ns = ins_perf[ins_idx]
                latency_ms = latency_ns/(10**6)
                # latency_contrib
                latency_contrib = latency_cycles/total_latency_cycles
                # Operations(OP, MOP)
                n_ops = get_n_op_conv(*layer_info[ins_name][1:])
                mops = n_ops/(10**6)
                # throughput(GOP/s)
                gop_s = n_ops/latency_ns
                # efficiency
                effs = gop_s/(M*P*0.3984375*(32/9))
                f.write("{},{},{},{},{},{},{},{},{},{}\n".format(
                    ins_idx, ins_type, latency_cycles, latency_ns,
                    "{:.2f}".format(latency_ms),
                    "{:.2f}".format(latency_contrib*100),
                    n_ops,
                    "{:.2f}".format(mops),
                    "{:.2f}".format(gop_s),
                    "{:.2f}".format(effs*100),
                ))
            elif ins_type in ("MaxPool", "AveragePool", "Add", "Remap"):
                # latency (cycles, ns, ms)
                latency_cycles, latency_ns = ins_perf[ins_idx]
                latency_ms = latency_ns/(10**6)
                # latency_contrib
                latency_contrib = latency_cycles/total_latency_cycles
                f.write("{},{},{},{},{},{},{},{},{},{}\n".format(
                    ins_idx, ins_type, latency_cycles, latency_ns,
                    "{:.2f}".format(latency_ms),
                    "{:.2f}".format(latency_contrib*100),
                    0, 0, 0, 0
                ))
            elif ins_type == "Fc":
                # latency (cycles, ns, ms)
                latency_cycles, latency_ns = ins_perf[ins_idx]
                latency_ms = latency_ns/(10**6)
                # latency_contrib
                latency_contrib = latency_cycles/total_latency_cycles
                # Operations(OP, MOP)
                n_ops = get_n_op_conv(layer_info[ins_name][1], layer_info[ins_name][2], 1, 1, 1, 1, 1, 1, 0, 0, 0, 0)
                mops = n_ops/(10**6)
                # throughput(GOP/s)
                gop_s = n_ops/latency_ns
                # efficiency
                effs = gop_s/(64*0.25*2)
                f.write("{},{},{},{},{},{},{},{},{},{}\n".format(
                    ins_idx, ins_type, latency_cycles, latency_ns,
                    "{:.2f}".format(latency_ms),
                    "{:.2f}".format(latency_contrib*100),
                    n_ops,
                    "{:.2f}".format(mops),
                    "{:.2f}".format(gop_s),
                    "{:.2f}".format(effs*100),
                ))
            elif ins_type == "End":
                pass
            else:
                raise ValueError(f"Unknown instruction type {ins_type}")

def res_e2e():
    e2e_perf = load_e2e_perf()
    layer_info = load_layer_info()
    ins_seq = load_ins_seq()
    ins_perf = load_ins_perf()
    res = {}

    # Latency measured on the hardware side.
    hw_total_latency = 0
    hw_conv_latency = 0
    hw_conv_op = 0
    for ins_name, (ins_idx, ins_type) in ins_seq.items():
        if ins_type != "End":
            _, latency_ns = ins_perf[ins_idx]
            hw_total_latency += latency_ns
        if ins_type == "Conv":
            _, latency_ns = ins_perf[ins_idx]
            hw_conv_latency += latency_ns
            n_ops = get_n_op_conv(*layer_info[ins_name][1:])
            hw_conv_op += n_ops
    hw_other_latency = hw_total_latency - hw_conv_latency
    hw_total_throughput = hw_conv_op/hw_total_latency
    hw_conv_throughput = hw_conv_op/hw_conv_latency
    hw_fps = (10**9)/hw_total_latency
    res.update({
        "hw_total_latency_ns": f"{hw_total_latency} ns", 
        "hw_conv_latency_ns": f"{hw_conv_latency} ns", 
        "hw_total_latency_ms": "{:.3f} ms".format(hw_total_latency/(10**6)),
        "hw_conv_latency_ms": "{:.3f} ms".format(hw_conv_latency/(10**6)),
        "hw_other_latency_ms": "{:.3f} ms".format(hw_other_latency/(10**6)),
        "hw_conv_op": f"{hw_conv_op} OP",
        "hw_conv_op_MOP": "{:.3f} MOP".format(hw_conv_op/(10**6)),
        "hw_total_throughput": "{:.3f} GOP/s".format(hw_total_throughput),
        "hw_conv_throughput": "{:.3f} GOP/s".format(hw_conv_throughput),
        "hw_fps": "{:.3f} Frame/s".format(hw_fps)
    })

    # Latency measured on the software side.
    t1 = sum([it[0] for it in e2e_perf])/len(e2e_perf)
    t2 = sum([it[1] for it in e2e_perf])/len(e2e_perf)
    t3 = sum([it[2] for it in e2e_perf])/len(e2e_perf)
    t4 = sum([it[3] for it in e2e_perf])/len(e2e_perf)
    t5 = sum([it[4] for it in e2e_perf])/len(e2e_perf)
    t = t1 + t2 + t3 + t4 + t5
    sw_fps = (10**9)/t
    res.update({
        "sw_t1_ns": f"{t1} ns", 
        "sw_t2_ns": f"{t2} ns", 
        "sw_t3_ns": f"{t3} ns", 
        "sw_t4_ns": f"{t4} ns", 
        "sw_t5_ns": f"{t5} ns", 
        "sw_t_ns": f"{t} ns", 
        "sw_t3_ms": "{:.3f} ms".format(t3/(10**6)),
        "sw_t_ms": "{:.3f} ms".format(t/(10**6)),
        "sw_fps": "{:.3f} Frame/s".format(sw_fps)
    })

    with open(f"res_e2e.yaml", mode="w", encoding="utf8") as f:
        yaml.safe_dump(res, f, sort_keys=False)

res_ins()
res_e2e()
