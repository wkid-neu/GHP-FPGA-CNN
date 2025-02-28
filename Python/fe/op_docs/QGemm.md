# `QGemm` Implementation

Inputs
=============
$A_q$, $A_S$, $A_Z$, $B_q$, $B_S$, $B_Z$, $C$, $Y_S$, $Y_Z$

Outputs
=============
$Y_q$

Processing
=============
with $r=S(q-Z), C_S=A_S B_S, C_Z = 0$, we have

$$ A_r = A_S(A_q-A_Z) $$
$$ B_r = B_S(B_q-B_Z) $$
$$ C_r = C_S(C_q-C_Z) = A_S B_S C_q $$
$$ Y_r = Y_S(Y_q-Y_Z) $$

Considering the following dot-product $Y_r= \sum_{}{} A_r B_r + C_r$, we have

$$
\begin{align*}
Y_S(Y_q-Y_Z) &= \sum_{}{} \left( A_S(A_q-A_Z) B_S(B_q-B_Z) \right) + A_S B_S C_q  \\
Y_S(Y_q-Y_Z) &= A_S B_S \sum_{}{} (A_q-A_Z) (B_q-B_Z) + A_S B_S C_q \\
Y_q &= \frac{A_S B_S}{Y_S} \sum_{}{} (A_q-A_Z) (B_q-B_Z) + \frac{A_S B_S}{Y_S} C_q + Y_Z  \\
Y_q &= \frac{A_S B_S}{Y_S} \left( \sum_{}{} (A_q-A_Z) (B_q-B_Z) + C_q \right) + Y_Z  \\
Y_q &= M_1 \left( \sum_{}{} (A_q-A_Z) (B_q-B_Z) + C_q \right) + Y_Z  
\end{align*}
$$

where $M_1=\frac{A_S B_S}{Y_S}$ is floating-point data. By representing it as a fixed-point number in the form of $M_1=2^{-n_1}m_1$, we have
$$ Y_q = 2^{-n_1}m_1 \left( \sum_{}{} (A_q-A_Z) (B_q-B_Z) + C_q \right) + Y_Z  $$

Quantization Parameters
=============
| Name | #bits | signed/unsigned |
|  ----  | ----  | ----  |
| $m_1$ | 26 | unsigned |
| $n_1$ | 8 | unsigned |
| $A_Z$ | 8 | unsigned |
| $B_Z$ | 8 | unsigned |
| $Y_Z$ | 8 | unsigned |

Instruction 
=============
| Field | #bits | Note |
|  ----  | ---- | ---- |
| op_type | 8 |
| xphs_addr | 16 | not used |
| xphs_len | 16 | the real value is $n\_X\_round-1$ |
| W_addr | 32 |
| W_n_bytes | 32 |
| B_addr | 16 |
| X_addr | 32 |
| Y_addr | 32 |
| OC | 16 | not used |
| INC | 16 | not used |
| INW_ | 16 | not used |
| KH | 8 | not used |
| KW | 8 | not used |
| strideH | 4 | not used |
| strideW | 4 | not used |
| padL | 4 | not used |
| padU | 4 | not used |
| INH2 | 16 | not used |
| INW2 | 16 | not used |
| ifm_height | 16 | not used |
| ofm_height | 16 | not used |
| n_last_batch | 8 | not used |
| n_W_round | 16 | not used |
| row_bound | 16 | not used |
| col_bound | 16 | not used |
| vec_size | 16 | the real value is len(input_vector) |
| vec_size_minus_1 | 16 | the real value is len(input_vector)-1 |
| $X_z$ | 8 |
| $W_z$ | 8 |
| $Y_z$ | 8 |
| $m_1$ | 32 |
| $n_1$ | 8 | the real value is $n_1-1$ |
| obj1 | 8 | x_mode, 0 is T-mode, 1 is V-mode |
| obj2 | 8 | not used |
| obj3 | 8 | not used |
| obj4 | 8 | not used |
