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
    {"vec_size", required_argument, NULL, 2},
    {"test_case_dir_path", required_argument, NULL, 3}
};

void run(
    uint32_t R, uint32_t S, 
    uint32_t vec_size, char* test_case_dir_path
);

int main(int argc, char const *argv[]) {
    int cmd_opt;
    uint32_t R, S;
    uint32_t vec_size = 0;
    char* test_case_dir_path;

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
            vec_size = atol(optarg);
            break;
        case 3:
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
        vec_size, test_case_dir_path
    );
}

void run(
    uint32_t R, uint32_t S, 
    uint32_t vec_size, char* test_case_dir_path
) {
    uint32_t rtm_mem_size = (1<<16);
    uint32_t rtm_data_width = R*S;
    uint32_t test_size = vec_size/rtm_data_width;
    /* Parameters checking */
    assert(vec_size%rtm_data_width == 0);
    assert(test_size <= rtm_mem_size/2);
    /* Devices */
    int csr_fd;
    int h2c_fd;
    int c2h_fd;
    int rtm_d2c_intr_fd;
    int rtm_c2d_intr_fd;
    int im_d2c_intr_fd;
    int exec_intr_fd;
    void* csr_map_base;
    /* Open devices */
    csr_fd = open(DEVICE_CSR, O_RDWR | O_SYNC);
    h2c_fd = open(DEVICE_H2C, O_RDWR | O_NONBLOCK);
    c2h_fd = open(DEVICE_C2H, O_RDWR | O_NONBLOCK);
    rtm_d2c_intr_fd = open(DEVICE_INTR_RTM_D2C, O_RDWR | O_SYNC);
    rtm_c2d_intr_fd = open(DEVICE_INTR_RTM_C2D, O_RDWR | O_SYNC);
    im_d2c_intr_fd = open(DEVICE_INTR_IM_D2C, O_RDWR | O_SYNC);
    exec_intr_fd = open(DEVICE_INTR_EXEC, O_RDWR | O_SYNC);
    csr_map_base = csr_mmap(csr_fd);
    /* Run the test */
    uint32_t latency;
    test_add2(
        h2c_fd, c2h_fd, csr_map_base,
        rtm_d2c_intr_fd, rtm_c2d_intr_fd,
        im_d2c_intr_fd, exec_intr_fd,
        vec_size, &latency,
        test_case_dir_path
    );
    /* Display test results */
    printf("Vector size: %u, Latency: %u cycles\n", vec_size, latency);
    /* Close devices */
    close(csr_fd);
    close(h2c_fd);
    close(c2h_fd);
    close(rtm_d2c_intr_fd);
    close(rtm_c2d_intr_fd);
    close(im_d2c_intr_fd);
    close(exec_intr_fd);
}
