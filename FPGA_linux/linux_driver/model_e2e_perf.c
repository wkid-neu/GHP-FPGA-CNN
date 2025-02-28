#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <fcntl.h>
#include <unistd.h>
#include <getopt.h>
#include <string.h>
#include <math.h>
#include <assert.h>
#include <time.h>

#include "utils.h"
#include "base.h"
#include "hw.h"
#include "model.h"

static const struct option long_opts[] = {
    {"model_dir_path", required_argument, NULL, 0},
    {"perf_file_path", required_argument, NULL, 1},
    {"repeat", required_argument, NULL, 2}
};

void run(
    char* model_dir_path, char* perf_file_path, 
    uint32_t repeat
);

int main(int argc, char const *argv[]) {
    int cmd_opt;
    char* model_dir_path;
    char* perf_file_path;
    uint32_t repeat;

    while ((cmd_opt = getopt_long(
        argc, (char * const*)argv, "0:1:2:", long_opts, NULL
    )) != -1) {
        switch (cmd_opt)
        {
        case 0:
            model_dir_path = strdup(optarg);
            break;
        case 1:
            perf_file_path = strdup(optarg);
            break;
        case 2:
            repeat = atol(optarg);
            break;
        default:
            printf("Arguments error\n");
			exit(0);
            break;
        }
    }

    run(
        model_dir_path, perf_file_path, repeat
    );
    return 0;
}

void run(
    char* model_dir_path, char* perf_file_path, uint32_t repeat
) {
    int print_log = 1;
    FILE* pref_f = fopen(perf_file_path, "w");
    if (pref_f == NULL) {
        printf("Open file failed, file_path: %s\n", perf_file_path);
        exit(-1);
    }
    fprintf(pref_f, "round_idx,t1(ns),t2(ns),t3(ns),t4(ns),t5(ns),total(ns)\n");
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
    /* Generate fake input/output tensor. */
    struct timespec start, end;
    long t1, t2, t3, t4, t5, total;
    void *input_tensor, *output_tensor;
    posix_memalign((void **)&input_tensor, 4096, model->input_ddr_len);
    posix_memalign((void **)&output_tensor, 4096, model->output_ddr_len);
    for (uint32_t i=0; i<repeat; i++) {
        /* (1) Input tensor: Host -> DRAM */
        clock_gettime(CLOCK_MONOTONIC, &start);
        dram_wr(h2c_fd, input_tensor, model->input_ddr_addr, model->input_ddr_len);
        clock_gettime(CLOCK_MONOTONIC, &end);
        timespec_sub(&end, &start);
        t1 = end.tv_nsec;
        /* (2) Input tensor: DRAM -> FPGA */
        clock_gettime(CLOCK_MONOTONIC, &start);
        rtm_d2c(model->input_ddr_addr, model->input_rtm_addr, model->input_ddr_len, csr_map_base, rtm_d2c_intr_fd);
        clock_gettime(CLOCK_MONOTONIC, &end);
        timespec_sub(&end, &start);
        t2 = end.tv_nsec;
        /* (3) FPGA executes instructions */
        clock_gettime(CLOCK_MONOTONIC, &start);
        exec(csr_map_base, exec_intr_fd);
        clock_gettime(CLOCK_MONOTONIC, &end);
        timespec_sub(&end, &start);
        t3 = end.tv_nsec;
        /* (4) Output tensor: FPGA -> DRAM */
        clock_gettime(CLOCK_MONOTONIC, &start);
        rtm_c2d(model->output_ddr_addr, model->output_rtm_addr, model->output_ddr_len, csr_map_base, rtm_c2d_intr_fd);
        clock_gettime(CLOCK_MONOTONIC, &end);
        timespec_sub(&end, &start);
        t4 = end.tv_nsec;
        /* (5) Output tensor: DRAM -> Host */
        clock_gettime(CLOCK_MONOTONIC, &start);
        dram_rd(c2h_fd, output_tensor, model->output_ddr_addr, model->output_ddr_len);
        clock_gettime(CLOCK_MONOTONIC, &end);
        timespec_sub(&end, &start);
        t5 = end.tv_nsec;
        /* Save result into file. */
        total = t1+t2+t3+t4+t5;
        fprintf(pref_f, "%u,%ld,%ld,%ld,%ld,%ld,%ld\n", i+1, t1, t2, t3, t4, t5, total);
        printf("%u/%u, t1: %ld ns, t2: %ld ns, t3: %ld ns, t4: %ld ns, t5: %ld ns, total: %ld ns\n", i+1, repeat, t1, t2, t3, t4, t5, total);
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
    free(input_tensor);
}
