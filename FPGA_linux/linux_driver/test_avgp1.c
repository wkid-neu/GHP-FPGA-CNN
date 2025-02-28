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
    {"M", required_argument, NULL, 0},
    {"P", required_argument, NULL, 1},
    {"Q", required_argument, NULL, 2},
    {"R", required_argument, NULL, 3},
    {"S", required_argument, NULL, 4},
    {"OC", required_argument, NULL, 5},
    {"INC", required_argument, NULL, 6},
    {"INH_", required_argument, NULL, 7},
    {"INW_", required_argument, NULL, 8},
    {"KH", required_argument, NULL, 9},
    {"KW", required_argument, NULL, 10},
    {"strideH", required_argument, NULL, 11},
    {"strideW", required_argument, NULL, 12},
    {"padL", required_argument, NULL, 13},
    {"padR", required_argument, NULL, 14},
    {"padU", required_argument, NULL, 15},
    {"padD", required_argument, NULL, 16}
};

void run(
    uint32_t M, uint32_t P, uint32_t Q, uint32_t R, uint32_t S,
    uint32_t OC, uint32_t INC, uint32_t INH_, uint32_t INW_, 
    uint32_t KH, uint32_t KW, uint32_t strideH, uint32_t strideW, 
    uint32_t padL, uint32_t padR, uint32_t padU, uint32_t padD
);

int main(int argc, char const *argv[]) {
    int cmd_opt;
    uint32_t M, P, Q, R, S, OC, INC, INH_, INW_, KH, KW, strideH, strideW, padL, padR, padU, padD;

    while ((cmd_opt = getopt_long(
        argc, (char * const*)argv, "0:1:2:3:4:5:6:7:8:9:10:11:12:13:14:15:16:", long_opts, NULL
    )) != -1) {
        switch (cmd_opt)
        {
        case 0:
            M = atol(optarg);
            break;
        case 1:
            P = atol(optarg);
            break;
        case 2:
            Q = atol(optarg);
            break;
        case 3:
            R = atol(optarg);
            break;
        case 4:
            S = atol(optarg);
            break;
        case 5:
            OC = atol(optarg);
            break;
        case 6:
            INC = atol(optarg);
            break;
        case 7:
            INH_ = atol(optarg);
            break;
        case 8:
            INW_ = atol(optarg);
            break;
        case 9:
            KH = atol(optarg);
            break;
        case 10:
            KW = atol(optarg);
            break;
        case 11:
            strideH = atol(optarg);
            break;
        case 12:
            strideW = atol(optarg);
            break;
        case 13:
            padL = atol(optarg);
            break;
        case 14:
            padR = atol(optarg);
            break;
        case 15:
            padU = atol(optarg);
            break;
        case 16:
            padD = atol(optarg);
            break;
        default:
            printf("Arguments error\n");
			exit(0);
            break;
        }
    }

    run(
        M, P, Q, R, S, 
        OC, INC, INH_, INW_, KH, KW, strideH, strideW, padL, padR, padU, padD
    );
}

void run(
    uint32_t M, uint32_t P, uint32_t Q, uint32_t R, uint32_t S,
    uint32_t OC, uint32_t INC, uint32_t INH_, uint32_t INW_, 
    uint32_t KH, uint32_t KW, uint32_t strideH, uint32_t strideW, 
    uint32_t padL, uint32_t padR, uint32_t padU, uint32_t padD
) {
    /* Parameters checking */
    assert(OC==INC);
    assert(INC%S==0);
    assert(KH*KW>=4);
    /* Devices */
    int csr_fd;
    int h2c_fd;
    int im_d2c_intr_fd;
    int xphm_d2c_intr_fd;
    int exec_intr_fd;
    void* csr_map_base;
    /* Open devices */
    csr_fd = open(DEVICE_CSR, O_RDWR | O_SYNC);
    h2c_fd = open(DEVICE_H2C, O_RDWR | O_NONBLOCK);
    im_d2c_intr_fd = open(DEVICE_INTR_IM_D2C, O_RDWR | O_SYNC);
    xphm_d2c_intr_fd = open(DEVICE_INTR_XPHM_D2C, O_RDWR | O_SYNC);
    exec_intr_fd = open(DEVICE_INTR_EXEC, O_RDWR | O_SYNC);
    csr_map_base = csr_mmap(csr_fd);
    /* Run the test */
    uint32_t latency;
    test_avgp1(
        h2c_fd, csr_map_base, im_d2c_intr_fd, xphm_d2c_intr_fd, exec_intr_fd,
        OC, INC, INH_, INW_, KH, KW, strideH, strideW, padL, padR, padU, padD,
        M, P, Q, R, S, 
        &latency
    );
    /* Display test results */
    // printf(
    //     "M: %u, P: %u, Q: %u, OC: %u, INC: %u, INH_: %u, INW_: %u, KH: %u, KW: %u, strideH: %u, strideW: %u, padL: %u padR: %u, padU: %u, padD: %u\n",
    //     M, P, Q, OC, INC, INH_, INW_, KH, KW, strideH, strideW, padL, padR, padU, padD
    // );
    printf("Latency: %u cycles, Time(ns): %u\n", latency, LATENCY_NS(latency));
    /* Close devices */
    close(csr_fd);
    close(h2c_fd);
    close(im_d2c_intr_fd);
    close(xphm_d2c_intr_fd);
    close(exec_intr_fd);
}
