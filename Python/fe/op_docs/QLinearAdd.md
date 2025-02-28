# `QLinearAdd` Implementation

Inputs
=============
$A_q$, $A_S$, $A_Z$, $B_q$, $B_S$, $B_Z$, $C_S$, $C_Z$

Outputs
=============
$C_q$

Processing
=============
with $r=S(q-Z)$, we have

$$ A_r = A_S(A_q-A_Z) $$
$$ B_r = B_S(B_q-B_Z) $$
$$ C_r = C_S(C_q-C_Z) $$

with $C_r=A_r+B_r$, we have

$$
\begin{align*}
C_S(C_q-C_Z) &= A_S(A_q-A_Z)+B_S(B_q-B_Z) \\
C_q &= \frac{A_S}{C_S}(A_q-A_Z)+\frac{B_S}{C_S}(B_q-B_Z)+C_Z \\
C_q &= M_1(A_q-A_Z)+M_2(B_q-B_Z)+C_Z
\end{align*}
$$

where $M_1=\frac{A_S}{C_S}$ and $M_2=\frac{B_S}{C_S}$ are both floating-point data. By representing them as fixed-point numbers in the form of $M_1=2^{-n_1}m_1, M_2=2^{-n_2}m_2$, we have


$$
C_q = 2^{-n_1}m_1(A_q-A_Z)+2^{-n_2}m_2(B_q-B_Z)+C_Z
$$

To simplify the addition operation on hardware, $M_1$ and $M_2$ should have the same exponent, so we have

$$
\begin{align*}
C_q &= 2^{-n}m_1(A_q-A_Z)+2^{-n}m_2(B_q-B_Z)+C_Z \\
C_q &= 2^{-n} \left( m_1(A_q-A_Z)+m_2(B_q-B_Z) \right)+C_Z
\end{align*}
$$

Quantization Parameters
=============
| Name | #bits | signed/unsigned |
|  ----  | ----  | ----  |
| $m_1$ | 26 | unsigned |
| $m_2$ | 26 | unsigned |
| $n$ | 8 | unsigned |
| $A_Z$ | 8 | unsigned |
| $B_Z$ | 8 | unsigned |
| $C_Z$ | 8 | unsigned | 

Instruction 
=============
| Field | #bits | Note |
|  ----  | ---- | ---- |
| op_type | 8 |
| A_addr | 32 |
| B_addr | 32 |
| C_addr | 32 |
| len | 32 | the real value is $len-1$ |
| $m_1$ | 32 |
| $m_2$ | 32 |
| $n$ | 8 | the real value is $n-1$ |
| $A_z$ | 8 | 
| $B_z$ | 8 |
| $C_z$ | 8 |
