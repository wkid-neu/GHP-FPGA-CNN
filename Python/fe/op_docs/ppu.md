# Post-Processing Unit

## 1. Hardware modules
$$
\begin{align*}
M1 &: int27 \times int35 = int62  \\
A1 &: int36 + int36 = int37 \\
S1 &: int62 >> uint6 = int9  \\
A2 &: int9 + uint8 = uint8
\end{align*}
$$

## 2. Modes
### 2.1 Mode1
$$
\begin{align*}
O &= A(B+C)>>S+Z \\
uint8 &= int27 \times (int34 + int34) >> uint6 + uint8
\end{align*}
$$
### 2. Mode2
$$
\begin{align*}
O &= (DE+FH)>>S+Z \\
uint8 &= (int27 \times int9 + int27 \times int9 ) >> uint6 + uint8
\end{align*}
$$

## 3. Operator Implementation
### 3.1 `QLinearConv` implemented with `mode1`
$$ Y_q = 2^{-n_1}m_1 \left( \sum_{}{} (X_q-X_Z) (W_q-W_Z) + B_q \right) + Y_Z  $$
$$
A = m1;
B = \sum_{}{} (X_q-X_Z) (W_q-W_Z);
C = B_q;
S = n_1;
Z = Y_Z
$$
### 3.2 `QGemm` implemented with `mode1`
$$ Y_q = 2^{-n_1}m_1 \left( \sum_{}{} (A_q-A_Z) (B_q-B_Z) + C_q \right) + Y_Z  $$
$$
A = m1;
B = \sum_{}{} (A_q-A_Z) (B_q-B_Z);
C = C_q;
S = n_1;
Z = Y_Z
$$
### 3.3 `QLinearAveragePool` implemented with `mode1`
$$ Y_q = 2^{-n_1}m_1 (\sum_{}{} X_q -N X_z) + Y_Z  $$
$$
A = m1;
B = \sum_{}{} X_q;
C = -N X_z;
S = n_1;
Z = Y_Z
$$
### 3.4 `MaxPool` implemented with `mode1`
$$ Y_q = max(X_q) $$
$$
A = 1024;
B = max(X_q);
C = 0;
S = 10;
Z = 0
$$
### 3.5 `QLinearConcat` implemented with `mode1`
$$ Y1_q = 2^{-n_1}m_1 (X1_q-X1_Z)+Y_Z $$
$$
A = m1;
B = X1_q;
C = -X1_Z;
S = n_1;
Z = Y_Z
$$
### 3.6 `QLinearAdd` implemented with `mode2`
$$ C_q = 2^{-n} \left( m_1(A_q-A_Z)+m_2(B_q-B_Z) \right)+C_Z $$
$$
D = m1;
E = A_q-A_Z;
F = m2;
H = B_q-B_Z;
S = n;
Z = C_Z
$$

