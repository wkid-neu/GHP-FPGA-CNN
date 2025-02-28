# `QLinearConv` Implementation

Inputs
=============
$X_q$, $X_S$, $X_Z$, $W_q$, $W_S$, $W_Z$, $B$, $Y_S$, $Y_Z$

Outputs
=============
$Y_q$

Processing
=============
with $r=S(q-Z), B_S=X_S W_S, B_Z = 0$, we have

$$ X_r = X_S(X_q-X_Z) $$
$$ W_r = W_S(W_q-W_Z) $$
$$ B_r = B_S(B_q-B_Z) = X_S W_S B_q $$
$$ Y_r = Y_S(Y_q-Y_Z) $$

Considering the following dot-product $Y_r= \sum_{}{} X_r W_r + B_r$, we have

$$
\begin{align*}
Y_S(Y_q-Y_Z) &= \sum_{}{} \left( X_S(X_q-X_Z) W_S(W_q-W_Z) \right) + X_S W_S B_q  \\
Y_S(Y_q-Y_Z) &= X_S W_S \sum_{}{} (X_q-X_Z) (W_q-W_Z) + X_S W_S B_q \\
Y_q &= \frac{X_S W_S}{Y_S} \sum_{}{} (X_q-X_Z) (W_q-W_Z) + \frac{X_S W_S}{Y_S} B_q + Y_Z  \\
Y_q &= \frac{X_S W_S}{Y_S} \left( \sum_{}{} (X_q-X_Z) (W_q-W_Z) + B_q \right) + Y_Z  \\
Y_q &= M_1 \left( \sum_{}{} (X_q-X_Z) (W_q-W_Z) + B_q \right) + Y_Z  
\end{align*}
$$

where $M_1=\frac{X_S W_S}{Y_S}$ is floating-point data. By representing it as a fixed-point number in the form of $M_1=2^{-n_1}m_1$, we have
$$ Y_q = 2^{-n_1}m_1 \left( \sum_{}{} (X_q-X_Z) (W_q-W_Z) + B_q \right) + Y_Z  $$

Quantization Parameters
=============
| Name | #bits | signed/unsigned |
|  ----  | ----  | ----  |
| $m_1$ | 26 | unsigned |
| $n_1$ | 8 | unsigned |
| $X_Z$ | 8 | unsigned |
| $W_Z$ | 8 | unsigned |
| $Y_Z$ | 8 | unsigned |

Instruction 
=============
| Field | #bits | Note |
|  ----  | ---- | ---- |
| op_type | 8 |
| xphs_addr | 16 |
| xphs_len | 16 | the real value is xphs_len-1 |
| W_addr | 32 |
| W_n_bytes | 32 |
| B_addr | 16 |
| X_addr | 32 |
| Y_addr | 32 |
| OC | 16 |
| INC | 16 | the real value is INC/4-1 |
| INW_ | 16 |
| KH | 8 | the real value is KH-1 |
| KW | 8 | the real value is KW-1 |
| strideH | 4 |
| strideW | 4 |
| padL | 4 |
| padU | 4 |
| INH2 | 16 |
| INW2 | 16 |
| ifm_height | 16 | the real value is ceil(INH*INW/32) |
| ofm_height | 16 | the real value is ceil(OH*OW/32) |
| n_last_batch | 8 | the real value is ceil(X_size_last_round/32) |
| n_W_round | 16 | the real value is ceil(OC/M)-1 |
| row_bound | 16 |
| col_bound | 16 |
| vec_size | 16 | the real value is INC\*KH\*KW/4 |
| vec_size_minus_1 | 16 | the real value is INC\*KH\*KW/4-1 |
| $X_z$ | 8 |
| $W_z$ | 8 |
| $Y_z$ | 8 |
| $m_1$ | 32 |
| $n_1$ | 8 | the real value is $n_1-1$ |
| obj1 | 8 | $cwm\_sta\_addr=\{obj4, obj3, obj2, obj1\}$ |
| obj2 | 8 |
| obj3 | 8 |
| obj4 | 8 |
