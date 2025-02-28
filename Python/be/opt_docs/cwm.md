# CWM optimization

## Symbols
$D$: Memory size. \
For the Conv instruction i: \
${l_s}^{(i)}$: Latency when using the static segment. \
${l_d}^{(i)}$: Latency when using the dynamic segment. \
$s^{(i)}$: Tensor size. \
$p^{(i)}$: Tensor position, 0 is static segment, 1 is dynamic segment. 

## Optimization
Latency of the Conv instruction i: 
$$ \begin{align*}
    l^{(i)} &= (1-p^{(i)}){l_s}^{(i)} + p^{(i)}{l_d}^{(i)} \\
    &= {l_s}^{(i)} + ({l_d}^{(i)}-{l_s}^{(i)})p^{(i)}
\end{align*} $$

Total latency:
$$ \begin{align*}
    L &= \sum{l^{(i)}} \\
    &= \sum{{l_s}^{(i)}} + \sum{({l_d}^{(i)}-{l_s}^{(i)})p^{(i)}} \\
    &= C_1 + \vec{\Delta}\vec{p}
\end{align*} $$

Static segment size of the Conv instruction i:
$$ \begin{align*}
    {S_s}^{(i)} &= (1-p^{(i)})s^{(i)} \\
    &= s^{(i)} - s^{(i)}p^{(i)}
\end{align*} $$

Static segment size:
$$ \begin{align*}
    S_s &= \sum{{S_s}^{(i)}} \\
    &= \sum{s^{(i)}} - \sum{s^{(i)}p^{(i)}} \\
    &= C_2 - \vec{s}\vec{p}
\end{align*} $$

Dynamic segment size:
$$ S_l = \max(s^{(i)}p^{(i)}) $$

Total size: 
$$ S = S_s + S_l = C_2 - \vec{s}\vec{p} + \max(s^{(i)}p^{(i)}) $$

## Final Expression
$$ \underset{\vec{p}}{{\arg\min}~L(\vec{p})} = C_1 + \vec{\Delta}\vec{p} $$
$$ s.t.~~ C_2 - \vec{s}\vec{p} + \max(s^{(i)}p^{(i)}) < D $$


