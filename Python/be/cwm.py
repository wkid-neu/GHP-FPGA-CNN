from typing import Dict, List, Tuple
from log import Log
import numpy as np
import networkx as nx
import os
from be import cwm_alg
from be import helper

def get_tensor_size(OC, INC, KH, KW, M, S) -> int:
    """Tensor size of weight tensor in CWM"""
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
    return aligned_OC*aligned_INC*KH*KW//(4*M)

def get_weight_sizes(graph: nx.DiGraph, exec_seq: List[str], params: dict, M: int, S: int) -> Dict[str, int]:  # vertex_name -> size
    """Compute memory size for all convolution weight tensors."""
    ret = {}
    for node_name in exec_seq:
        onnx_node = graph.nodes[node_name]["att_obj"]
        node_params = params[node_name]
        if onnx_node.op_type == "QLinearConv":
            OC, INC, KH, KW = node_params["OC"], node_params["INC"], node_params["KH"], node_params["KW"]
            ret[node_name] = get_tensor_size(OC, INC, KH, KW, M, S)
    return ret

def load_prior_knowledge(fp: str) -> Dict[tuple, int]:  # primary_kyes -> n_cycle
    """Load prior knowledge from file. Return None if error occurred."""
    if (fp is None) or not os.path.exists(fp):
        return None

    data = {}
    raw_data = np.loadtxt(fp, str, delimiter=",")
    for i in range(1, len(raw_data)):
        M, P, Q, R, S, OC, INC, INH_, INW_, KH, KW, strideH, strideW, padL, padR, padU, padD, mode, latency_cycles = raw_data[i]
        primary_keys = (
            int(M), int(P), int(Q), 
            int(OC), int(INC), int(INH_), int(INW_), 
            int(KH), int(KW), int(strideH), int(strideW), 
            int(padL), int(padR), int(padU), int(padD), 
            mode
        )
        data[primary_keys] = int(latency_cycles)

    return data

def find_solution_default(
    weight_sizes: Dict[str, int],
    cwm_dep: int,
) -> Tuple[List[str], List[str]]:  # sta_list, dyn_list
    """Allocate memory by using the default algorithm."""
    Log.i("CWM: Using the default allocation algorithm.")
    sta, dyn = [], list(weight_sizes.keys())
    dyn = sorted(dyn, key=lambda k: weight_sizes[k], reverse=True)  # Sort in descending order
    traversal_list = [it for it in dyn]
    for i in range(len(traversal_list)):
        weight_name = traversal_list[i]
        weight_size = weight_sizes[weight_name]
        # Try to move the weight to the static segment
        pre_sta_size = sum([weight_sizes[k] for k in sta])+weight_size
        pre_dyn_size = weight_sizes[dyn[1]] if i==0 else weight_sizes[dyn[0]]
        # Movement is illegal, try the next weight
        if (pre_sta_size+pre_dyn_size) > cwm_dep:
            continue
        # Movement is legal
        else:
            Log.i(f"CWM: Move {weight_name} to the static segment.")
            sta.append(weight_name)
            dyn.remove(weight_name)
    return sta, dyn

def find_sloution_with_prior_knowledge(
    params: dict,
    weight_sizes: Dict[str, int],
    prior_know: Dict[tuple, int],
    cwm_dep: int,
    M: int, P: int, Q: int, R: int, S: int
) -> Tuple[List[str], List[str]]:  # sta_list, dyn_list
    """allocate memmory by using prior knowledge. Return None if error occurred."""
    Log.i("CWM: Using prior knowledge.")
    sta_list, dyn_list = [], []
    # Prepare inputs
    sta_latency_dict = {}
    dyn_latency_dict = {}
    for node_name, weight_size in weight_sizes.items():
        node_params = params[node_name]
        # Find Conv shape parameters
        OC, INC, INH_, INW_ = node_params["OC"], node_params["INC"], node_params["INH_"], node_params["INW_"]
        KH, KW, strideH, strideW = node_params["KH"], node_params["KW"], node_params["strideH"], node_params["strideW"]
        padL, padR, padU, padD = node_params["padL"], node_params["padR"], node_params["padU"], node_params["padD"]
        # OC, INC alignment
        OC, INC = helper.conv_params_alignment(OC, INC, KH, KW, M, S)
        # Find latency value
        sta_key = (M, P, Q, R, S, OC, INC, INH_, INW_, KH, KW, strideH, strideW, padL, padR, padU, padD, "sta")
        dyn_key = (M, P, Q, R, S, OC, INC, INH_, INW_, KH, KW, strideH, strideW, padL, padR, padU, padD, "dyn")
        if sta_key not in prior_know.keys():
            Log.i(f"Failed to find record in the database, key: {sta_key}")
            return None, None
        if dyn_key not in prior_know.keys():
            Log.i(f"Failed to find record in the database, key: {dyn_key}")
            return None, None
        sta_latency_dict[node_name] = prior_know[sta_key]
        dyn_latency_dict[node_name] = prior_know[dyn_key]
    # Run the optimization algorithm
    mode_dict, _ = cwm_alg.opt(
        sta_latency_dict=sta_latency_dict,
        dyn_latency_dict=dyn_latency_dict,
        size_dict=weight_sizes,
        cwm_dep=cwm_dep
    )
    # Results
    for node_name, mode in mode_dict.items():
        if mode == "sta":
            sta_list.append(node_name)
        else:
            dyn_list.append(node_name)
    return sta_list, dyn_list

def alg_eval(
    sta_list: List[str],
    dyn_list: List[str],
    prior_know: Dict[tuple, int],
    params: dict,
    M: int, P: int, Q: int, R:int, S: int
) -> int:  # total latency
    """Evaluate the given allocation algorithm by calculating the total latency."""
    ret = 0
    ls = sta_list
    ls.extend(dyn_list)
    for node_name in ls:
        node_params = params[node_name]
        # Find Conv shape parameters
        OC, INC, INH_, INW_ = node_params["OC"], node_params["INC"], node_params["INH_"], node_params["INW_"]
        KH, KW, strideH, strideW = node_params["KH"], node_params["KW"], node_params["strideH"], node_params["strideW"]
        padL, padR, padU, padD = node_params["padL"], node_params["padR"], node_params["padU"], node_params["padD"]
        # OC, INC alignment
        OC, INC = helper.conv_params_alignment(OC, INC, KH, KW, M, S)
        # Find latency value
        if node_name in sta_list:
            key = (M, P, Q, R, S, OC, INC, INH_, INW_, KH, KW, strideH, strideW, padL, padR, padU, padD, "sta")
        else:
            key = (M, P, Q, R, S, OC, INC, INH_, INW_, KH, KW, strideH, strideW, padL, padR, padU, padD, "dyn")
        if key in prior_know.keys():
            ret += prior_know[key]
        else:
            Log.i(f"CWM: Failed to find record in the database, key: {key}")
            return -1
    return ret

def malloc(
    graph: nx.DiGraph,
    exec_seq: List[str],
    params: dict,
    M: int, P: int, Q: int, R:int, S: int, 
    cwm_dep: int,
    prior_knowledge_fp: str = ""
) -> Dict[str, Tuple[bool, int, int]]:  # [node_name, (is_static, address, length)]
    """Allocate memory for all weights."""
    Log.i("CWM: Start running.")
    ret = {}
    weight_sizes = get_weight_sizes(graph, exec_seq, params, M, S)

    # 1. Check if CWM is large enogh to store the maximum weight tensor
    max_weight_size = max(weight_sizes.values())
    if max_weight_size > cwm_dep:
        raise ValueError(f"CWM size {cwm_dep} is too small, the maximum weight size is {max_weight_size}.")
    
    # 2. Check if all tensors can be stored in the static segment.
    if sum(weight_sizes.values()) < cwm_dep:
        Log.i("CWM: Storing all weight tensors in the static segment.")
        sta_addr = 0
        for k, v in weight_sizes.items():
            ret[k] = (True, sta_addr, v)
            sta_addr += v
        Log.i("CWM: Done.")
        return ret

    # 3. Determine which weights should be saved in the static segment to minimum the inference latency.
    # Load prior knowledge
    prior_know = load_prior_knowledge(prior_knowledge_fp)
    if prior_know is None:
        Log.i("CWM: Failed to load prior knowledge, the default allocation algorithm will be used.")
    # 3.1 Default algorithm
    sta_default, dyn_default = find_solution_default(
        weight_sizes=weight_sizes,
        cwm_dep=cwm_dep
    )
    total_default = -1
    if prior_know is not None:
        total_default = alg_eval(sta_default, dyn_default, prior_know, params, M, P, Q, R, S)
    if total_default > 0:
        Log.i(f"CWM: Total latency of the default algorithm is {total_default}.")
    # 3.2 Try to use prior knowledge
    sta_pk, dyn_pk = None, None
    total_pk = -1
    if prior_know is not None:
        sta_pk, dyn_pk = find_sloution_with_prior_knowledge(
            params=params,
            weight_sizes=weight_sizes,
            prior_know=prior_know,
            cwm_dep=cwm_dep,
            M=M, P=P, Q=Q, R=R, S=S
        )
        if sta_pk is None:
            Log.i("CWM: Failed to use prior knowledge, the default allocation algorithm will be used.")
        else:
            total_pk = alg_eval(sta_pk, dyn_pk, prior_know, params, M, P, Q, R, S)
    if total_pk > 0:
        Log.i(f"CWM: Total latency of the prior_know algorithm is {total_pk}.")
    # 3.3 Select the best algorithm
    if (total_pk > 0) and (total_pk < total_default):
        sta, dyn = sta_pk, dyn_pk
        Log.i(f"CWM: Allocation results of the prior_know algorithm is selected.")
    else:
        sta, dyn = sta_default, dyn_default
        Log.i(f"CWM: Allocation results of the default algorithm is selected.")

    # 4. Update result
    sta_addr, dyn_addr = 0, 0
    for k in sta:
        ret[k] = (True, sta_addr, weight_sizes[k])
        sta_addr += weight_sizes[k]
    for k in dyn:  # use the dram address and length
        n_bytes = weight_sizes[k]*M*4
        ret[k] = (False, dyn_addr, n_bytes)
        dyn_addr += n_bytes

    Log.i("CWM: Done.")
    return ret
