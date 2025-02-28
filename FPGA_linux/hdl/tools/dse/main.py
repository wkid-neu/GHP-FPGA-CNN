import numpy as np
import os
import math

def _load_db(fp):
    """Load database from file."""
    ret = {}
    if os.path.exists(fp):
        raw_data = np.loadtxt(fp, str, delimiter=",")
        for i in range(1, len(raw_data)):
            M, P, Q, R, S, OC, INC, INH_, INW_, KH, KW, strideH, strideW, padL, padR, padU, padD, w_mode, latency = raw_data[i]
            primary_keys = (
                int(M), int(P), int(Q), int(R), int(S),
                int(OC), int(INC), int(INH_), int(INW_), 
                int(KH), int(KW), int(strideH), int(strideW), 
                int(padL), int(padR), int(padU), int(padD), 
                str(w_mode)
            )
            ret[primary_keys] = int(latency)
    return ret

def _save_dp(fp, db: dict):
    """Save database to file."""
    with open(fp, mode="w", encoding="utf8") as f:
        f.write("M, P, Q, R, S, OC, INC, INH_, INW_, KH, KW, strideH, strideW, padL, padR, padU, padD, w_mode, latency\n")
        for k, v in db.items():
            f.write(",".join([str(field) for field in k]))
            f.write(f",{v}\n")

def _find_conv_shapes(db: dict):
    """Find different Conv shapes from database."""
    ret = set()
    for k, v in db.items():
        M, P, Q, R, S, OC, INC, INH_, INW_, KH, KW, strideH, strideW, padL, padR, padU, padD, w_mode = k
        ret.add((OC, INC, INH_, INW_, KH, KW, strideH, strideW, padL, padR, padU, padD))
    return list(ret)

def gen_acc_db_file(
    M: int, P: int, 
    confs: list, w_mode: str,
    ori_db_fp: str, new_db_fp: str
):
    """Generate database file for the given accelerator."""
    # Load original database
    ori_db = _load_db(ori_db_fp)
    # Find all Conv shapes
    shapes = _find_conv_shapes(ori_db)
    # Create new database
    new_db = dict()
    # For a Conv shape, if records for all confs can be found, these records will be added to the new database
    for shape in shapes:
        OC, INC, INH_, INW_, KH, KW, strideH, strideW, padL, padR, padU, padD = shape
        found = True
        curr_records = {}
        for conf in confs:
            Q, R, S = conf
            primary_keys = (
                M, P, Q, R, S,
                OC, INC, INH_, INW_, KH, KW, strideH, strideW, padL, padR, padU, padD,
                w_mode
            )
            if primary_keys in ori_db.keys():
                curr_records.update({primary_keys: ori_db[primary_keys]})
            else:
                found = False
                break
        if found:
            new_db.update(curr_records)
    # Save new database to file
    _save_dp(new_db_fp, new_db)

def _get_ofm_shape(
    INH_: int, INW_: int,
    KH: int, KW: int,
    strideH: int, strideW: int,
    padL: int, padR: int, padU: int, padD: int,
    ceil_mode: bool = False,
    dilationH: int = 1, dilationW: int = 1
):
    """Calculate the shape of output feature map."""
    if not ceil_mode:
        OH = math.floor((INH_+padU+padD-((KH-1)*dilationH+1))/strideH+1)
        OW = math.floor((INW_+padL+padR-((KW-1)*dilationW+1))/strideW+1)
    else:
        OH = math.ceil((INH_+padU+padD-((KH-1)*dilationH+1))/strideH+1)
        OW = math.ceil((INW_+padL+padR-((KW-1)*dilationW+1))/strideW+1)
    return OH, OW

def _get_score(
    M, P,
    OC, INC, INH_, INW_, KH, KW, strideH, strideW, padL, padR, padU, padD,
    latency
):
    """Calculate the score value for a given record.
    score = real_throughput / ideal_throughput * 100%
    """
    OH, OW = _get_ofm_shape(
        INH_, INW_,
        KH, KW, strideH, strideW,
        padL, padR, padU, padD
    )
    ideal = M*P*(32/9)*0.4
    real = OC*OH*OW*INC*KH*KW*2/latency
    score = int(real/ideal*100)
    return score

def explore(
    M: int, P: int, 
    confs: list, w_mode: str,
    ori_db_fp: str, new_db_fp: str
):
    """Run design space exploration."""
    # Generate database file for the given accelerator
    gen_acc_db_file(
        M, P, confs, w_mode, ori_db_fp, new_db_fp
    )
    # Load records
    records = _load_db(new_db_fp)
    # Calculate scores
    scores = [0 for _ in confs]
    record_idx = 0
    for k, v in records.items():
        M, P, Q, R, S, OC, INC, INH_, INW_, KH, KW, strideH, strideW, padL, padR, padU, padD, w_mode = k
        score = _get_score(
            M, P,
            OC, INC, INH_, INW_, KH, KW, strideH, strideW, padL, padR, padU, padD,
            int(v)
        )
        scores[record_idx%len(confs)] += score
        record_idx += 1
    total_cnt = record_idx/(len(confs))
    scores = [score/total_cnt for score in scores]
    # Find the best conf
    best_idx = 0
    best_score = 0
    for i in range(len(scores)):
        score = scores[i]
        if score > best_score:
            best_idx, best_score = i, score
    print(f"Scores are {scores}")
    print(f"The best configuration is {confs[best_idx]}")
    
M, P = 64, 64
confs = [
    (16, 32, 4),
    (16, 16, 8)
]
w_mode = "sta"
print(f"M{M}P{P}")
explore(
    M, P, 
    confs, w_mode,
    "/home/hp50/Desktop/FPGA_linux/cnn_accel6/hdl/tools/build_db/db.csv",
    f"/home/hp50/Desktop/FPGA_linux/cnn_accel6/hdl/tools/build_db/db_M{M}P{P}_{w_mode}.csv"
)
