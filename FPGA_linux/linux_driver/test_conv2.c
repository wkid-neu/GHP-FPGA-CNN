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
    {"padD", required_argument, NULL, 16},
    {"sta_mode", required_argument, NULL, 17},
    {"test_case_dir_path", required_argument, NULL, 18}
};

void run(
    uint32_t M, uint32_t P, uint32_t Q, uint32_t R, uint32_t S,
    uint32_t OC, uint32_t INC, uint32_t INH_, uint32_t INW_, 
    uint32_t KH, uint32_t KW, uint32_t strideH, uint32_t strideW, 
    uint32_t padL, uint32_t padR, uint32_t padU, uint32_t padD,
    int sta_mode,
    char* test_case_dir_path
);

int main(int argc, char const *argv[]) {
    int cmd_opt;
    uint32_t M, P, Q, R, S, OC, INC, INH_, INW_, KH, KW, strideH, strideW, padL, padR, padU, padD;
    int sta_mode;
    char* test_case_dir_path;

    while ((cmd_opt = getopt_long(
        argc, (char * const*)argv, "0:1:2:3:4:5:6:7:8:9:10:11:12:13:14:15:16:17:18", long_opts, NULL
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
        case 17:
            sta_mode = atol(optarg);
            break;
        case 18:
            test_case_dir_path = strdup(optarg);
            break;
        default:
            printf("Arguments error\n");
			exit(0);
            break;
        }
    }

    run(
        M, P, Q, R, S, 
        OC, INC, INH_, INW_, KH, KW, strideH, strideW, padL, padR, padU, padD,
        sta_mode, test_case_dir_path
    );
    return 0;
}

void run(
    uint32_t M, uint32_t P, uint32_t Q, uint32_t R, uint32_t S,
    uint32_t OC, uint32_t INC, uint32_t INH_, uint32_t INW_, 
    uint32_t KH, uint32_t KW, uint32_t strideH, uint32_t strideW, 
    uint32_t padL, uint32_t padR, uint32_t padU, uint32_t padD,
    int sta_mode,
    char* test_case_dir_path
) {
    /* Parameters checking */
    assert(OC>0 && OC%(M*2)==0);
    assert(INC>0 && INC%S==0);
    assert(INC*KH*KW>=M);
    assert(INC*KH*KW%8==0);
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
    /* Run the test */
    uint32_t latency;
    test_conv2(
        h2c_fd, c2h_fd,
        csr_map_base,
        rtm_d2c_intr_fd, rtm_c2d_intr_fd,
        cwm_d2c_intr_fd, bm_d2c_intr_fd,
        im_d2c_intr_fd, xphm_d2c_intr_fd, exec_intr_fd,
        OC, INC, INH_, INW_, KH, KW, strideH, strideW, padL, padR, padU, padD, sta_mode,
        M, P, Q, R, S, 
        &latency,
        test_case_dir_path
    );
    /* Display test results */
    uint32_t n_op = conv_get_n_op(
        OC, INC, INH_, INW_, KH, KW, strideH, strideW, padL, padR, padU, padD
    );
    uint32_t time_ns = LATENCY_NS(latency);
    float ideal_throughput = get_ideal_throughput(M, P, SA_CLK);
    float real_throughput = get_throughput_gops(n_op, latency, MAIN_CLK);
    float eff = real_throughput*100/ideal_throughput;
    printf(
        "Latency: %u cycles, Time(ns): %u, Ideal throughput: %.2f GOPS, Real throughput: %.2f GOPS, Effiency: %.2f\n", 
        latency, time_ns, ideal_throughput, real_throughput, eff
    );
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
}
