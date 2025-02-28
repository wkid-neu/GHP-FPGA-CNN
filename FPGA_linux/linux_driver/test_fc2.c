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
#include "test.h"

static const struct option long_opts[] = {
    {"R", required_argument, NULL, 0},
    {"S", required_argument, NULL, 1},
    {"OC", required_argument, NULL, 2},
    {"INC",required_argument,NULL, 3},
    {"t_mode",required_argument,NULL, 4},
    {"test_case_dir_path", required_argument, NULL, 5}
};

void run(
    uint32_t R, uint32_t S,
    uint32_t OC, uint32_t INC, int t_mode, 
    char* test_case_dir_path
);

int main(int argc, char const *argv[]) {
    int cmd_opt;
    uint32_t R, S, OC, INC;
    int t_mode = 0;
    char* test_case_dir_path;

    while ((cmd_opt = getopt_long(
        argc, (char * const*)argv, "0:1:2:3:4:5:", long_opts, NULL
    )) != -1) {
        switch (cmd_opt)
        {
        case 0:
            R = atol(optarg);
            break;
        case 1:
            S = atol(optarg);
            break;
        case 2:
            OC = atol(optarg);
            break;
        case 3:
            INC = atol(optarg);
            break;
        case 4:
            t_mode = atoi(optarg);
            break;
        case 5:
            test_case_dir_path = strdup(optarg);
            break;
        default:
            printf("Arguments error\n");
			exit(0);
            break;
        }
    }

    run(
        R, S, 
        OC, INC, t_mode, 
        test_case_dir_path
    );
    return 0;
}

void run(
    uint32_t R, uint32_t S,
    uint32_t OC, uint32_t INC, int t_mode, 
    char* test_case_dir_path
) {
    uint32_t dma_max_size = (1<<27);
    uint32_t rtm_mem_size = (1<<16);
    uint32_t x_rtm_size;
    if (t_mode)
        x_rtm_size = (uint32_t)ceil(INC/S);
    else
        x_rtm_size = (uint32_t)ceil(INC/(R*S));
    uint32_t y_rtm_size = (uint32_t)ceil(OC/(R*S));
    /* Parameters checking */
    assert(OC%64 == 0);
    assert(INC >= 32);
    assert(OC*INC < dma_max_size);
    assert(x_rtm_size + y_rtm_size <= rtm_mem_size);
    /* Devices */
    int csr_fd;
    int h2c_fd;
    int c2h_fd;
    int rtm_d2c_intr_fd;
    int rtm_c2d_intr_fd;
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
    bm_d2c_intr_fd = open(DEVICE_INTR_BM_D2C, O_RDWR | O_SYNC);
    im_d2c_intr_fd = open(DEVICE_INTR_IM_D2C, O_RDWR | O_SYNC);
    exec_intr_fd = open(DEVICE_INTR_EXEC, O_RDWR | O_SYNC);
    csr_map_base = csr_mmap(csr_fd);
    /* Run the test */
    uint32_t latency;
    test_fc2(
        h2c_fd, c2h_fd,
        csr_map_base,
        rtm_d2c_intr_fd, rtm_c2d_intr_fd,
        bm_d2c_intr_fd,
        im_d2c_intr_fd, exec_intr_fd,
        OC, INC, t_mode, &latency,
        test_case_dir_path
    );
    /* Display test results */
    printf("Latency: %u cycles, Time(ns): %u\n", latency, LATENCY_NS(latency));
    /* Close devices */
    close(csr_fd);
    close(h2c_fd);
    close(c2h_fd);
    close(rtm_d2c_intr_fd);
    close(rtm_c2d_intr_fd);
    close(bm_d2c_intr_fd);
    close(im_d2c_intr_fd);
    close(exec_intr_fd);
}
