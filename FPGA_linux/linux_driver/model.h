#if !defined(__MODEL_H__)
#define __MODEL_H__

#include "base.h"

// Configurate DRAM
void cfg_dram(struct Model* model, int h2c_fd, int print_log);
// Configurate FPGA
void cfg_fpga(
    struct Model* model,
    void* csr_map_base,
    int im_d2c_intr_fd, int bm_d2c_intr_fd, int xphm_d2c_intr_fd, int cwm_d2c_intr_fd,
    int print_log
);

#endif // __MODEL_H__
