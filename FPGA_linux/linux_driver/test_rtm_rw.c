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
    {"rtm_addr", required_argument, NULL, 2},
    {"n_bytes",required_argument,NULL, 3}
};

void run(
    uint32_t R, uint32_t S, 
    uint32_t rtm_addr, uint32_t n_bytes
);

int main(int argc, char const *argv[]) {
    int cmd_opt;
    uint32_t R, S;
    uint32_t rtm_addr = 0, n_bytes = 0;

    while ((cmd_opt = getopt_long(
        argc, (char * const*)argv, "0:1:2:3:", long_opts, NULL
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
            // rtm_addr = strtoul(optarg, NULL, 16);
            rtm_addr = atol(optarg);
            break;
        case 3:
            n_bytes = atol(optarg);
            break;
        default:
            printf("Arguments error\n");
			exit(0);
            break;
        }
    }

    run(
        R, S, 
        rtm_addr, n_bytes
    );
}

void run(
    uint32_t R, uint32_t S, 
    uint32_t rtm_addr, uint32_t n_bytes
) {
    uint32_t rtm_mem_size = (1<<16);
    uint32_t rtm_data_width = R*S;
    uint32_t test_size = n_bytes/rtm_data_width;
    /* Parameters checking */
    assert(n_bytes%rtm_data_width == 0);
    assert(rtm_addr < rtm_mem_size);
    assert(rtm_addr + test_size <= rtm_mem_size);
    /* Devices */
    int csr_fd;
    int h2c_fd, c2h_fd;
    int rtm_d2c_intr_fd, rtm_c2d_intr_fd;
    void* csr_map_base;
    /* Open devices */
    csr_fd = open(DEVICE_CSR, O_RDWR | O_SYNC);
    h2c_fd = open(DEVICE_H2C, O_RDWR | O_NONBLOCK);
    c2h_fd = open(DEVICE_C2H, O_RDWR | O_NONBLOCK);
    rtm_d2c_intr_fd = open(DEVICE_INTR_RTM_D2C, O_RDWR | O_SYNC);
    rtm_c2d_intr_fd = open(DEVICE_INTR_RTM_C2D, O_RDWR | O_SYNC);
    csr_map_base = csr_mmap(csr_fd);
    /* Run the test */
    long d2c_latency = 0, c2d_latency = 0;
    test_rtm_rw(h2c_fd, c2h_fd, csr_map_base, rtm_d2c_intr_fd, rtm_c2d_intr_fd, rtm_addr, n_bytes, &d2c_latency, &c2d_latency);
    float d2c_speed = get_mem_speed_GBPS(d2c_latency, n_bytes);
    float c2d_speed = get_mem_speed_GBPS(c2d_latency, n_bytes);
    printf("wr_speed: %.2f GB/s, rd_speed: %.2f GB/s\n", d2c_speed, c2d_speed);
    /* Close devices */
    close(csr_fd);
    close(h2c_fd);
    close(c2h_fd);
    close(rtm_d2c_intr_fd);
    close(rtm_c2d_intr_fd);
}
