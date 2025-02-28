from sko.PSO import PSO
import numpy as np
from typing import Dict, Tuple

def opt(
    sta_latency_dict: Dict[str, int],  # latency values in sta mode
    dyn_latency_dict: Dict[str, int],  # latency values in dyn mode
    size_dict: Dict[str, int],  # tensor size
    cwm_dep: int,  # CWM depth
) -> Tuple[Dict[str, str], int]:
    # preparation
    tensor_list = []
    vec_ls, vec_ld, vec_s = [], [], []
    for k, v in sta_latency_dict.items():
        tensor_list.append(k)
        vec_ls.append(v)
        vec_ld.append(dyn_latency_dict[k])
        vec_s.append(size_dict[k])
    D = cwm_dep
    # Run the optimization algorithm
    impl = Impl(
        vec_ls=np.array(vec_ls),
        vec_ld=np.array(vec_ld),
        vec_s=np.array(vec_s),
        D=D
    )
    impl.run()
    # Results
    mode_dict = {}
    for i in range(len(tensor_list)):
        tensor_name = tensor_list[i]
        if impl.best_x[i]:
            mode_dict[tensor_name] = "dyn"
        else:
            mode_dict[tensor_name] = "sta"
    return mode_dict, int(impl.best_y)

class Impl:
    def __init__(self, vec_ls, vec_ld, vec_s, D) -> None:
        self.vec_ls = vec_ls
        self.vec_ld = vec_ld
        self.vec_s = vec_s
        self.D = D

        self.N = len(vec_ls)
        self.vec_delta = vec_ld - vec_ls
        self.C1 = np.sum(vec_ls)
        self.C2 = np.sum(vec_s)

    def run(self):
        np.random.seed(2023)

        pso = PSO(
            func=self.obj,
            n_dim=self.N,
            pop=40,
            max_iter=300,
            lb=np.zeros(self.N,),
            ub=np.ones(self.N,),
            constraint_ueq=[self.constr],
            verbose=False
        )
        pso.run()
        
        best_x, best_y, best_y_hist = pso.gbest_x, pso.gbest_y, pso.gbest_y_hist

        # Post-processing
        best_x = np.choose(best_x<0.5, [1,0])
        best_y = self.C1 + best_y
        best_y_hist = [self.C1 + it for it in best_y_hist]

        # Results
        self.best_x = best_x
        self.best_y = best_y
        self.best_y_hist = best_y_hist

    def obj(self, p):
        # p = 0 if p < 0.5 else 1
        p = np.choose(p<0.5, [1,0])
        inner_prod = np.inner(self.vec_delta, p)
        return int(inner_prod)

    def constr(self, p):
        p = np.choose(p<0.5, [1,0])
        # static segment size
        Ss = self.C2 - np.inner(self.vec_s, p)
        # dynamic segment size
        Sd = np.max(np.multiply(self.vec_s, p))
        # total size
        S = Ss + Sd
        return S - self.D

if __name__=="__main__":
    cnt = 3
    sta, dyn, size = {}, {}, {}
    for i in range(cnt):
        sta[f"case{i+1}"] = np.random.randint(1,100)
        dyn[f"case{i+1}"] = sta[f"case{i+1}"] + np.random.randint(0,5)
        size[f"case{i+1}"] = np.random.randint(10,20)
    cwm_dep = 20
    opt(sta, dyn, size, cwm_dep)
