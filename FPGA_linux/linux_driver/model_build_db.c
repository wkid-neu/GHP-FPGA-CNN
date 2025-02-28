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
#include "model.h"

static const struct option long_opts[] = {
    {"M", required_argument, NULL, 0},
    {"P", required_argument, NULL, 1},
    {"Q", required_argument, NULL, 2},
    {"R", required_argument, NULL, 3},
    {"S", required_argument, NULL, 4},
    {"model_dir_path", required_argument, NULL, 5},
    {"db_file_path", required_argument, NULL, 6}
};

struct ConvShape {
    uint32_t OC; uint32_t INC; uint32_t INH_; uint32_t INW_; 
    uint32_t KH; uint32_t KW; uint32_t strideH; uint32_t strideW; 
    uint32_t padL; uint32_t padR; uint32_t padU; uint32_t padD;
};

void run(
    uint32_t M, uint32_t P, uint32_t Q, uint32_t R, uint32_t S,
    char* model_dir_path, char* db_file_path
);

int main(int argc, char const *argv[]) {
    int cmd_opt;
    uint32_t M, P, Q, R, S;
    char* model_dir_path;
    char* db_file_path;

    while ((cmd_opt = getopt_long(
        argc, (char * const*)argv, "0:1:2:3:4:5:6:", long_opts, NULL
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
            model_dir_path = strdup(optarg);
            break;
        case 6:
            db_file_path = strdup(optarg);
            break;
        default:
            printf("Arguments error\n");
			exit(0);
            break;
        }
    }

    run(
        M, P, Q, R, S, 
        model_dir_path, db_file_path
    );
    return 0;
}

void display_results(
    uint32_t M, uint32_t P, uint32_t Q, uint32_t R, uint32_t S,
    uint32_t OC, uint32_t INC, uint32_t INH_, uint32_t INW_, 
    uint32_t KH, uint32_t KW, uint32_t strideH, uint32_t strideW, 
    uint32_t padL, uint32_t padR, uint32_t padU, uint32_t padD,
    uint32_t latency
) {
    float n_op = conv_get_n_op(
        OC, INC, INH_, INW_, KH, KW, strideH, strideW, padL, padR, padU, padD
    );
    uint32_t time_ns = LATENCY_NS(latency);
    float ideal_throughput = get_ideal_throughput(M, P, SA_CLK);
    float real_throughput = get_throughput_gops(n_op, latency, MAIN_CLK);
    float eff = real_throughput*100/ideal_throughput;
    printf(
        "Latency: %u cycles, Time(ns): %u, Ideal throughput: %.2f GOPS, Real throughput: %.2f GOPS, Efficiency: %.2f\n", 
        latency, time_ns, ideal_throughput, real_throughput, eff
    );
}

void run(
    uint32_t M, uint32_t P, uint32_t Q, uint32_t R, uint32_t S,
    char* model_dir_path, char* db_file_path
) {
    int print_log = 1;
    FILE* db_f = fopen(db_file_path, "w");
    if (db_f == NULL) {
        printf("Open file failed, file_path: %s\n", db_file_path);
        exit(-1);
    }
    fprintf(db_f, "OC,INC,INH_,INW_,KH,KW,strideH,strideW,padL,padR,padU,padD,mode,latency(cycles)\n");
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
    /* Load Conv shapes from file. */
    char shape_file_path [1024];
    sprintf(shape_file_path, "%sconv_shapes.hex", model_dir_path);
    uint32_t shapes_file_size = get_file_size(shape_file_path);
    uint32_t n_conv = shapes_file_size/(12*4);
    uint32_t* shapes = malloc(shapes_file_size);
    rd_hex_file(shape_file_path, shapes);
    /* Run Conv with sta and dyn weights */
    uint32_t OC, INC, INH_, INW_, KH, KW, strideH, strideW, padL, padR, padU, padD;
    for (uint32_t i=0; i<n_conv; i++) {
        OC = shapes[i*12];
        INC = shapes[i*12+1];
        INH_ = shapes[i*12+2];
        INW_ = shapes[i*12+3];
        KH = shapes[i*12+4];
        KW = shapes[i*12+5];
        strideH = shapes[i*12+6];
        strideW = shapes[i*12+7];
        padL = shapes[i*12+8];
        padR = shapes[i*12+9];
        padU = shapes[i*12+10];
        padD = shapes[i*12+11];
        printf("----------------------------\n");
        printf(
            "OC: %u, INC: %u, INH_: %u, INW_: %u, KH: %u, KW: %u, strideH: %u, strideW: %u, padL: %u padR: %u, padU: %u, padD: %u\n",
            OC, INC, INH_, INW_, KH, KW, strideH, strideW, padL, padR, padU, padD
        );
        /* Static mode */
        uint32_t sta_latency;
        test_conv1(
            h2c_fd, csr_map_base, im_d2c_intr_fd, xphm_d2c_intr_fd, exec_intr_fd,
            OC, INC, INH_, INW_, KH, KW, strideH, strideW, padL, padR, padU, padD,
            1,
            M, P, Q, R, S, 
            &sta_latency
        );
        fprintf(
            db_f, "%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,sta,%u\n",
            OC, INC, INH_, INW_, KH, KW, strideH, strideW, padL, padR, padU, padD, sta_latency
        );
        printf("sta mode:\n");
        display_results(
            M, P, Q, R, S, 
            OC, INC, INH_, INW_, KH, KW, strideH, strideW, padL, padR, padU, padD,
            sta_latency
        );
        /* Dynamic mode */
        uint32_t dyn_latency;
        test_conv1(
            h2c_fd, csr_map_base, im_d2c_intr_fd, xphm_d2c_intr_fd, exec_intr_fd,
            OC, INC, INH_, INW_, KH, KW, strideH, strideW, padL, padR, padU, padD,
            0,
            M, P, Q, R, S, 
            &dyn_latency
        );
        fprintf(
            db_f, "%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,%u,dyn,%u\n",
            OC, INC, INH_, INW_, KH, KW, strideH, strideW, padL, padR, padU, padD, dyn_latency
        );
        printf("dyn mode:\n");
        display_results(
            M, P, Q, R, S, 
            OC, INC, INH_, INW_, KH, KW, strideH, strideW, padL, padR, padU, padD,
            dyn_latency
        );
        printf("----------------------------\n");
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
    fclose(db_f);
}
