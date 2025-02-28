import numpy as np

x = np.random.randint(0, 256, (2,3,2,2))
y = np.einsum("...jk->...", [x])
print(x)
print(y)