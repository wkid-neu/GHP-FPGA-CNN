# `QLinearGlobalAveragePool` Implementation

Inputs
=============
$X_q$, $X_S$, $X_Z$, $Y_S$, $Y_Z$

Outputs
=============
$Y_q$

Processing
=============
with $r=S(q-Z)$, we have

$$ X_r = X_S(X_q-X_Z) $$
$$ Y_r = Y_S(Y_q-Y_Z) $$

with $Y_r= \frac{1}{N} \sum_{}{} X_r$, we have

$$
\begin{align*}
Y_S(Y_q-Y_Z) &= \frac{1}{N} \sum_{}{} \left( X_S(X_q-X_Z) \right) \\
Y_S(Y_q-Y_Z) &= \frac{X_S}{N} \sum_{}{} (X_q-X_Z) \\
Y_q &= \frac{X_S}{N Y_S} \sum_{}{} (X_q-X_Z) + Y_Z  \\
Y_q &= M_1 \sum_{}{} (X_q-X_Z) + Y_Z
\end{align*}
$$

where $M_1=\frac{X_S}{N Y_S}$ is floating-point data. By representing it as a fixed-point number in the form of $M_1=2^{-n_1}m_1$, we have
$$ Y_q= 2^{-n_1}m_1 \sum_{}{} (X_q-X_Z) + Y_Z $$

Quantization Parameters
=============
| Name | #bits | signed/unsigned |
|  ----  | ----  | ----  |
| $m_1$ | 34 | unsigned |
| $n_1$ | 8 | unsigned |
| $X_Z$ | 8 | unsigned |
| $Y_Z$ | 8 | unsigned |

Instruction 
=============
The same as `QLinearAveragePool`
