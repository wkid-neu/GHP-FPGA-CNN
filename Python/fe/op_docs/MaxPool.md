# `MaxPool` Implementation

Inputs
=============
$X_q$

Outputs
=============
$Y_q$

Processing
=============

$$ Y_q = max(X_q) $$

in order to leverage the hardware of `QLinearAveragePool`, this can be rewritten as 

$$ Y_q = 2^{-n_1}m_1 (max(X_q) -N X_z) + Y_Z $$ 

where $X_z=0$, $N X_z=0$, $Y_Z=0$, $m_1=1024$, $n_1=10$.

Quantization Parameters
=============
| Name | #bits | signed/unsigned |
|  ----  | ----  | ----  |
| None | None | None |

Instruction 
=============
| Field | #bits | Note |
|  ----  | ---- | ---- |
| op_type | 8 |
| xphs_addr | 16 |
| xphs_len | 16 | the real value is xphs_len-1 |
| W_addr | 32 | not used |
| W_n_bytes | 32 | not used |
| B_addr | 16 | not used |
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
| n_W_round | 16 | not used |
| row_bound | 16 |
| col_bound | 16 |
| vec_size | 16 | the real value is KH*KW |
| vec_size_minus_1 | 16 | the real value is KH*KW-1 |
| $X_z$ | 8 | must be `0` |
| $W_z$ | 8 | not used |
| $Y_z$ | 8 | must be `0` |
| $m_1$ | 32 | must be `1024` |
| $n_1$ | 8 | must be `9(10-1)` |
| obj1 | 8 | must be `0` |
| obj2 | 8 | must be `0` |
| obj3 | 8 | not used |
| obj4 | 8 | not used |