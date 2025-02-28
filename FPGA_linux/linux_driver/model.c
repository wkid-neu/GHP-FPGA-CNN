#include <stdio.h>
#include <stdlib.h>

#include "hw.h"
#include "model.h"

void cfg_dram(struct Model* model, int h2c_fd, int print_log) {
    /* Write sta_conv_weight */
    if (print_log)
        printf("Move sta_conv_weights to DRAM, addr: 0x%x, size: %u\n", model->sta_conv_weight_ddr_addr, model->sta_conv_weight_ddr_len);
    if (model->sta_conv_weight_ddr_len > 0)
        dram_wr(h2c_fd, model->sta_conv_weights, model->sta_conv_weight_ddr_addr, model->sta_conv_weight_ddr_len);
    /* Write dyn_conv_weight */
    if (print_log)
        printf("Move dyn_conv_weight to DRAM, addr: 0x%x, size: %u\n", model->dyn_conv_weight_ddr_addr, model->dyn_conv_weight_ddr_len);
    if (model->dyn_conv_weight_ddr_len > 0)
        dram_wr(h2c_fd, model->dyn_conv_weights, model->dyn_conv_weight_ddr_addr, model->dyn_conv_weight_ddr_len);
    /* Write fc_weight */
    if (print_log)
        printf("Move fc_weight to DRAM, addr: 0x%x, size: %u\n", model->dyn_conv_weight_ddr_addr, model->dyn_conv_weight_ddr_len);
    if (model->fc_weight_ddr_len > 0)
        dram_wr(h2c_fd, model->fc_weights, model->fc_weight_ddr_addr, model->fc_weight_ddr_len);
    /* Write bias */
    if (print_log)
        printf("Move bias to DRAM, addr: 0x%x, size: %u\n", model->bias_ddr_addr, model->bias_ddr_len);
    if (model->bias_ddr_len > 0)
        dram_wr(h2c_fd, model->bias, model->bias_ddr_addr, model->bias_ddr_len);
    /* Write ins */
    if (print_log)
        printf("Move instructions to DRAM, addr: 0x%x, size: %u\n", model->ins_ddr_addr, model->ins_ddr_len);
    dram_wr(h2c_fd, model->ins, model->ins_ddr_addr, model->ins_ddr_len);
    /* Write xphs */
    if (print_log)
        printf("Move xphs to DRAM, addr: 0x%x, size: %u\n", model->xphs_ddr_addr, model->xphs_ddr_len);
    if (model->xphs_ddr_len > 0)
        dram_wr(h2c_fd, model->xphs, model->xphs_ddr_addr, model->xphs_ddr_len);
}

void cfg_fpga(
    struct Model* model,
    void* csr_map_base,
    int im_d2c_intr_fd, int bm_d2c_intr_fd, int xphm_d2c_intr_fd, int cwm_d2c_intr_fd,
    int print_log
) {
    /* Write instructions */
    if (print_log)
        printf("Load instructions.\n");
    im_d2c(model->ins_ddr_addr, model->ins_ddr_len, csr_map_base, im_d2c_intr_fd);
    /* Write bias */
    if (print_log)
        printf("Load bias.\n");
    bm_d2c(model->bias_ddr_addr, 0, model->bias_ddr_len, csr_map_base, bm_d2c_intr_fd);
    /* Write xphs */
    if (print_log)
        printf("Load xphs.\n");
    if (model->xphs_ddr_len > 0)
        xphm_d2c(model->xphs_ddr_addr, 0, model->xphs_ddr_len, csr_map_base, xphm_d2c_intr_fd);
    /* Write sta_conv_weights */
    if (print_log)
        printf("Load sta_conv_weights.\n");
    if (model->sta_conv_weight_ddr_len > 0)
        cwm_d2c(model->sta_conv_weight_ddr_addr, 0, model->sta_conv_weight_ddr_len, csr_map_base, cwm_d2c_intr_fd);
}
