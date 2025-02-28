from typing import List
import math
import utils
import numpy as np

class Xph:
    """X Packet header"""
    def __init__(self) -> None:
        self.X_a_: int = -1  # uint16_t
        self.len_per_chan: int = -1  # uint16_t
        self.win_x: int = -1  # uint16_t
        self.win_y: int = -1  # uint16_t

def gen_xphs (
    INH_, INW_, KH, KW, strideH, strideW,
    padL, padR, padU, padD,
    P, Q
) -> List[Xph]:
    """Generate X packet headers"""
    xphs = []

    OH, OW = utils.conv_get_ofm_shape(
        INH_, INW_, KH, KW, strideH, strideW,
        padL, padR, padU, padD
    )
    n_x_rnd = math.ceil(OH*OW/P)

    for x_rnd in range(n_x_rnd):
        xph = Xph()
        in_pos_start, in_pos_end = math.inf, -math.inf
        for p in range(P):
            out_pos = x_rnd*P+p
            if out_pos > OH*OW-1:
                out_pos = OH*OW-1
            out_row, out_col = out_pos//OW, out_pos%OW
            win_y, win_x = out_row*strideH, out_col*strideW
            if p==0:
                xph.win_x = win_x
                xph.win_y = win_y
            for kh in range(KH):
                for kw in range(KW):
                    x, y = win_x+kw, win_y+kh
                    x_,y_ = x-padL, y-padU
                    if x_<0 or x_>INW_-1 or y_<0 or y_>INH_-1:
                        continue
                    in_pos = y_*INW_+x_
                    if in_pos < in_pos_start:
                        in_pos_start = in_pos
                    if in_pos > in_pos_end:
                        in_pos_end = in_pos
        start_a_ = in_pos_start//Q
        start_b_ = in_pos_start%Q
        end_a_ = in_pos_end//Q
        end_b_ = in_pos_end%Q
        xph.X_a_ = start_a_
        xph.len_per_chan=end_a_-start_a_+1
        xphs.append(xph)
    return xphs

def conv_params(
    OC, INC, 
    INH_, INW_,
    KH, KW, strideH, strideW,
    padL, padR, padU, padD,
    M, P, R, S
):
    """Parameters of Conv"""
    OH, OW = utils.conv_get_ofm_shape(
        INH_, INW_,
        KH, KW, strideH, strideW,
        padL, padR, padU, padD
    )

    INH2 = INH_+padU
    INW2 = INW_+padL
    ifm_height = math.ceil(INH_*INW_/R)
    ofm_height = math.ceil(OH*OW/R)

    n_x_rnd = math.ceil(OH*OW/P)
    if n_x_rnd == 1:
        n_last_batch = math.ceil(OH*OW/R)
    else:
        n_last_batch = math.ceil((OH*OW-(n_x_rnd-1)*P)/R)
    
    n_w_rnd = math.ceil(OC/(M*2))
    row_bound = (OH-1)*strideH
    col_bound = (OW-1)*strideW
    vec_size = INC*KH*KW//2
    vec_size_minus_1 = vec_size-1

    return (
        INH2, INW2, ifm_height, ofm_height, n_last_batch, n_w_rnd, 
        row_bound, col_bound, vec_size, vec_size_minus_1
    )

def pool_params(
    OC, INC, 
    INH_, INW_,
    KH, KW, strideH, strideW,
    padL, padR, padU, padD,
    M, P, R, S
):
    """Parameters of MaxPool/AvgPool"""
    OH, OW = utils.conv_get_ofm_shape(
        INH_, INW_,
        KH, KW, strideH, strideW,
        padL, padR, padU, padD
    )

    INH2 = INH_+padU
    INW2 = INW_+padL
    ifm_height = math.ceil(INH_*INW_/R)
    ofm_height = math.ceil(OH*OW/R)

    n_x_rnd = math.ceil(OH*OW/P)
    if n_x_rnd == 1:
        n_last_batch = math.ceil(OH*OW/R)
    else:
        n_last_batch = math.ceil((OH*OW-(n_x_rnd-1)*P)/R)

    n_w_rnd = 1
    row_bound = (OH-1)*strideH
    col_bound = (OW-1)*strideW
    vec_size = KH*KW
    vec_size_minus_1 = vec_size-1

    return (
        INH2, INW2, ifm_height, ofm_height, n_last_batch, n_w_rnd, 
        row_bound, col_bound, vec_size, vec_size_minus_1
    )

def conv_reorder_weights(weight: np.ndarray, M: int, S: int) -> np.ndarray:
    """Reorder the weight tensor for CONV.
    See test_case/conv_w.drawio for details."""
    OC, INC, KH, KW = weight.shape
    n_w_rnd = OC//(M*2)
    # All Fs
    Fs = []
    for i in range(n_w_rnd):
        # block
        blk = weight[i*(M*2):(i+1)*(M*2), :, :, :]
        # A
        A = blk.reshape((M*2, -1)).T
        # B1, B2
        B1_sub, B2_sub = [], []
        for j in range(INC//2):
            B1_sub.append(A[j*(KH*KW*2):j*(KH*KW*2)+KH*KW, :])
            B2_sub.append(A[j*(KH*KW*2)+KH*KW:(j+1)*(KH*KW*2), :])
        B1 = np.row_stack(B1_sub)
        B2 = np.row_stack(B2_sub)
        # C
        C_cols = []
        for j in range(M*2):
            C_cols.append(B1[:, j])
            C_cols.append(B2[:, j])
        C = np.column_stack(C_cols)
        # All Es
        Es = []
        for j in range(INC//S):
            D = C[j*KH*KW*S//2:(j+1)*KH*KW*S//2, :]
            E_rows = []
            for k in range(KH*KW):
                for l in range(S//2):
                    E_rows.append(D[l*KH*KW+k, :])
            E = np.row_stack(E_rows)
            Es.append(E)
        # F
        F = np.row_stack(Es)
        Fs.append(F)
    G = np.row_stack(Fs)
    return G

def conv_regen_bias(ori_bias: np.ndarray, weight: np.ndarray, xz: int, wz: int):
    """Re-generate bias for Conv."""
    OC, INC, KH, KW = weight.shape
    N = INC*KH*KW
    A = np.zeros(shape=(OC, ), dtype=np.int32)
    for i in range(OC):
        A[i] = np.sum(weight[i, :, :, :])
    A = np.multiply(A, -xz)
    B = N*xz*wz
    return A+B+ori_bias

def conv_reorder_bias(bias: np.ndarray, M: int) -> np.ndarray:
    """Reorder the bias tensor for CONV.
    See test_case/conv_b.drawio for details."""
    OC = bias.shape[0]
    n_rnd = OC//(M*2)
    ret = []
    for i in range(n_rnd):
        rnd_offset = 2*M*i
        for j in range(M//8):
            blk_offset = rnd_offset+j*16
            for k in range(8):
                ret.append(bias[blk_offset+2*(7-k)])
                ret.append(bias[blk_offset+2*(7-k)+1])
    return np.array(ret)

def fc_reorder_weights(weight: np.ndarray) -> np.ndarray:
    """Reorder the weight tensor for FC."""
    OC, INC = weight.shape  # (256,128)
    n_rnd = OC//64
    ret = []
    for i in range(n_rnd):
        mat = weight.T[:, i*64:(i+1)*64]  # (128, 64)
        ret.append(mat)
    ret = np.row_stack(ret)
    return ret  # (512, 64)

if __name__=="__main__":
    OC, INC, KH, KW = 512, 512, 3, 3
    w = np.random.randint(low=0, high=255, size=(OC, INC, KH, KW), dtype=np.uint8)
    b = np.random.randint(low=-(2**31), high=(2**31)-1, size=(OC, ), dtype=np.int32)
    xz, wz = 110, 138
    new_b = conv_regen_bias(b, w, xz, wz)
    print(new_b.shape)
