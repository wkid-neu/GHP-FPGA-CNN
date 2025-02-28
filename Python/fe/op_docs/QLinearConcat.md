# `QLinearConcat` Implementation

Inputs
=============
$Y_S$, $Y_Z$, $X1_q$, $X1_S$, $X1_Z$, $X2_q$, $X2_S$, $X2_Z$, ... , $XN_q$, $XN_S$, $XN_Z$

Outputs
=============
$Y_q$

Processing
=============
with $r=S(q-Z)$, we have

$$ X1_r = X1_S(X1_q-X1_Z) $$
$$ X2_r = X2_S(X2_q-X2_Z) $$
$$ \dots $$
$$ XN_r = XN_S(XN_q-XN_Z) $$
$$ Y_r = Y_S(Y_q-Y_Z) $$

Taking $X1$ as an example, with $Y1_r=X1_r$, we have

$$
\begin{align*}
Y_S(Y1_q-Y_Z) &= X1_S(X1_q-X1_Z) \\
Y1_q &= \frac{X1_S}{Y_S}(X1_q-X1_Z)+Y_Z \\
Y1_q &= M_1(X1_q-X1_Z)+Y_Z
\end{align*}
$$

where $M_1=\frac{X1_S}{Y_S}$ is a floating-point number. By representing it as a fixed-point number in the form of $M_1=2^{-n_1}m_1$, we have

$$
\begin{align*}
Y1_q &= 2^{-n_1}m_1 (X1_q-X1_Z)+Y_Z \\
Y2_q &= 2^{-n_2}m_2 (X2_q-X2_Z)+Y_Z \\
\dots \\
YN_q &= 2^{-n_N}m_N (XN_q-XN_Z)+Y_Z
\end{align*}
$$


Quantization Parameters
=============
| Name | #bits | signed/unsigned |
|  ----  | ----  | ----  |
| $Y_Z$ | 8 | unsigned |
| $m_1$ | 26 | unsigned |
| $n_1$ | 8 | unsigned |
| $X1_Z$ | 8 | unsigned |
| $m_2$ | 26 | unsigned |
| $n_2$ | 8 | unsigned |
| $X2_Z$ | 8 | unsigned |
| ... | ... | ... |
| $m_N$ | 26 | unsigned |
| $n_N$ | 8 | unsigned |
| $XN_Z$ | 8 | unsigned |


Instruction (For one tensor)
=============
| Field | #bits | Note |
|  ----  | ---- | ---- |
| op_type | 8 |
| X_addr | 32 |
| Y_addr | 32 |
| len | 32 | the real value is $len-1$ |
| $m_1$ | 32 |
| $n_1$ | 8 | the real value is $n_1-1$ |
| $X_z$ | 16 | the real value is $-X_z$ |
| $Y_z$ | 8 |