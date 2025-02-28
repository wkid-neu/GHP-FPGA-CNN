#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <fcntl.h>
#include <unistd.h>
#include <getopt.h>
#include <string.h>
#include <math.h>
#include <assert.h>

#include "base.h"
#include "hw.h"
#include "test.h"

static const struct option long_opts[] = {
    {"R", required_argument, NULL, 0},
    {"S", required_argument, NULL, 1},
    {"vec_size", required_argument, NULL, 2}
};

void run(
    uint32_t R, uint32_t S, 
    uint32_t vec_size
);

int main(int argc, char const *argv[]) {
    int cmd_opt;
    uint32_t R, S;
    uint32_t vec_size = 0;

    while ((cmd_opt = getopt_long(
        argc, (char * const*)argv, "0:1:2:", long_opts, NULL
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
            vec_size = atol(optarg);
            break;
        default:
            printf("Arguments error\n");
            exit(0);
            break;
        }
    }

    run(
        R, S, 
        vec_size
    );
}

void run(
    uint32_t R, uint32_t S, 
    uint32_t vec_size
) {
    uint32_t rtm_mem_size = (1<<16);
    uint32_t rtm_data_width = R*S;
    uint32_t test_size = vec_size/rtm_data_width;
    /* Parameters checking */
    assert(vec_size%rtm_data_width == 0);
    assert(test_size <= rtm_mem_size);
    /* Devices */
    int csr_fd;
    int h2c_fd;
    int im_d2c_intr_fd;
    int exec_intr_fd;
    void* csr_map_base;
    /* Open devices */
    csr_fd = open(DEVICE_CSR, O_RDWR | O_SYNC);
    h2c_fd = open(DEVICE_H2C, O_RDWR | O_NONBLOCK);
    im_d2c_intr_fd = open(DEVICE_INTR_IM_D2C, O_RDWR | O_SYNC);
    exec_intr_fd = open(DEVICE_INTR_EXEC, O_RDWR | O_SYNC);
    csr_map_base = csr_mmap(csr_fd);
    /* Run the test */
    uint32_t latency;
    test_remap1(h2c_fd, csr_map_base, im_d2c_intr_fd, exec_intr_fd, vec_size, &latency);
    /* Display test results */
    printf("Vector size: %u, Latency (cycles): %u\n", vec_size, latency);
    /* Close devices */
    close(csr_fd);
    close(h2c_fd);
    close(im_d2c_intr_fd);
    close(exec_intr_fd);
}
