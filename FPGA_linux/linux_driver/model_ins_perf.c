#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <fcntl.h>
#include <unistd.h>
#include <getopt.h>
#include <string.h>
#include <math.h>
#include <assert.h>

#include "utils.h"
#include "base.h"
#include "hw.h"
#include "model.h"

static const struct option long_opts[] = {
    {"model_dir_path", required_argument, NULL, 0},
    {"perf_file_path", required_argument, NULL, 1}
};

void run(
    char* model_dir_path, char* perf_file_path
);

int main(int argc, char const *argv[]) {
    int cmd_opt;
    char* model_dir_path;
    char* perf_file_path;

    while ((cmd_opt = getopt_long(
        argc, (char * const*)argv, "0:1:", long_opts, NULL
    )) != -1) {
        switch (cmd_opt)
        {
        case 0:
            model_dir_path = strdup(optarg);
            break;
        case 1:
            perf_file_path = strdup(optarg);
            break;
        default:
            printf("Arguments error\n");
			exit(0);
            break;
        }
    }

    run(
        model_dir_path, perf_file_path
    );
    return 0;
}

void run(
    char* model_dir_path, char* perf_file_path
) {
    int print_log = 1;
    FILE* pref_f = fopen(perf_file_path, "w");
    if (pref_f == NULL) {
        printf("Open file failed, file_path: %s\n", perf_file_path);
        exit(-1);
    }
    fprintf(pref_f, "ins_idx,latency(cycles),latency(ns)\n");
    /* Devices */
    int csr_fd;
    int h2c_fd;
    int c2h_fd;
    int rtm_d2c_intr_fd;
    int rtm_c2d_intr_fd;
    int xphm_d2c_intr_fd;
    int cwm_d2c_intr_fd;
    int bm_d2c_intr_fd;
    int im_d2c_intr_fd;
    int exec_intr_fd;
    void* csr_map_base;
    /* Open devices */
    csr_fd = open(DEVICE_CSR, O_RDWR | O_SYNC);
    h2c_fd = open(DEVICE_H2C, O_RDWR | O_NONBLOCK);
    c2h_fd = open(DEVICE_C2H, O_RDWR | O_NONBLOCK);
    rtm_d2c_intr_fd = open(DEVICE_INTR_RTM_D2C, O_RDWR | O_SYNC);
    rtm_c2d_intr_fd = open(DEVICE_INTR_RTM_C2D, O_RDWR | O_SYNC);
    xphm_d2c_intr_fd = open(DEVICE_INTR_XPHM_D2C, O_RDWR | O_SYNC);
    cwm_d2c_intr_fd = open(DEVICE_INTR_CWM_D2C, O_RDWR | O_SYNC);
    bm_d2c_intr_fd = open(DEVICE_INTR_BM_D2C, O_RDWR | O_SYNC);
    im_d2c_intr_fd = open(DEVICE_INTR_IM_D2C, O_RDWR | O_SYNC);
    exec_intr_fd = open(DEVICE_INTR_EXEC, O_RDWR | O_SYNC);
    csr_map_base = csr_mmap(csr_fd);
    /* Load model from file */
    struct Model* model = malloc(sizeof(struct Model));
    Model_load(model_dir_path, model);
    /* Configurate DRAM */
    cfg_dram(model, h2c_fd, print_log);
    /* Configurate on-chip buffers */
    cfg_fpga(model, csr_map_base, im_d2c_intr_fd, bm_d2c_intr_fd, xphm_d2c_intr_fd, cwm_d2c_intr_fd, print_log);
    /* Execute instructions one-by-one */
    uint32_t n_ins = model->ins_ddr_len/64;
    uint8_t ins_type;
    void* ins_buf;
    uint32_t latency;
    posix_memalign((void **)&ins_buf, 4096, 64*2);
    for (uint32_t i=0; i<n_ins-1; i++) {
        ins_type = *(model->ins+i*64);
        printf("%u/%u, ", i+1, n_ins-1);
        if (ins_type == INS_CONV) {
            printf("Conv, ");
        } else if (ins_type == INS_MAXP) {
            printf("MaxPool, ");
        } else if (ins_type == INS_AVGP) {
            printf("AveragePool, ");
        } else if (ins_type == INS_ADD) {
            printf("Add, ");
        } else if (ins_type == INS_REMAP) {
            printf("Remap, ");
        } else if (ins_type == INS_FC) {
            printf("Fc, ");
        } else {
            printf("Unknown instruction type: %d", ins_type);
            exit(-1);
        }
        /* Current instruction. */
        memcpy(ins_buf, model->ins+i*64, 64);
        /* End instruction */
        memcpy(((uint8_t*)ins_buf)+64, model->ins+(n_ins-1)*64, 64);
        /* Make sure the last one is End instruction */
        assert(*(((uint8_t*)ins_buf)+64) == INS_NONE);
        /* Write instructions */
        dram_wr(h2c_fd, ins_buf, 0x80000000, 64*2);
        im_d2c(0x80000000, 64*2, csr_map_base, im_d2c_intr_fd);
        /* Execute instructions */
        exec(csr_map_base, exec_intr_fd);
        /* Read the latency register. */
        if (ins_type == INS_CONV)
            reg_rd(csr_map_base, CSR_EXEC_LATENCY_CONV, &latency);
        else if (ins_type == INS_MAXP || ins_type == INS_AVGP)
            reg_rd(csr_map_base, CSR_EXEC_LATENCY_POOL, &latency);
        else if (ins_type == INS_ADD)
            reg_rd(csr_map_base, CSR_EXEC_LATENCY_ADD, &latency);
        else if (ins_type == INS_REMAP)
            reg_rd(csr_map_base, CSR_EXEC_LATENCY_REMAP, &latency);
        else if (ins_type == INS_FC)
            reg_rd(csr_map_base, CSR_EXEC_LATENCY_FC, &latency);
        /* Save result into file. */
        fprintf(pref_f, "%u,%u,%u\n", i+1, latency, LATENCY_NS(latency));
        printf("Latency(cycles): %u, Latency(ns): %u\n", latency, LATENCY_NS(latency));
    }
    /* Close devices */
    close(csr_fd);
    close(h2c_fd);
    close(c2h_fd);
    close(rtm_d2c_intr_fd);
    close(rtm_c2d_intr_fd);
    close(xphm_d2c_intr_fd);
    close(cwm_d2c_intr_fd);
    close(bm_d2c_intr_fd);
    close(im_d2c_intr_fd);
    close(exec_intr_fd);
    fclose(pref_f);
    /* Free up memory blocks. */
    free(model);
    free(ins_buf);
}


