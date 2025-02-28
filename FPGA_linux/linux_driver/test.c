#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <fcntl.h>
#include <unistd.h>
#include <time.h>
#include <assert.h>
#include <string.h>
#include <math.h>

#include "hw.h"
#include "utils.h"
#include "base.h"

// Move data from Host to IM directly.
static void im_wr_through(int h2c_fd, void* csr_map_base, int im_d2c_intr_fd, void* ins_buf, uint32_t n_bytes) {
    uint32_t tmp_dram_addr = 0x80000000;
    /* Host -> DRAM */
    dram_wr(h2c_fd, ins_buf, tmp_dram_addr, n_bytes);
    /* DRAM -> IM */
    im_d2c(tmp_dram_addr, n_bytes, csr_map_base, im_d2c_intr_fd);
}

// Move data from Host to XPHM directly.
static void xphm_wr_through(int h2c_fd, void* csr_map_base, int xphm_d2c_intr_fd, uint32_t xphm_addr, void* xphs_buf, uint32_t n_bytes) {
    uint32_t tmp_dram_addr = 0x80000000;
    /* Host -> DRAM */
    dram_wr(h2c_fd, xphs_buf, tmp_dram_addr, n_bytes);
    /* DRAM -> XPHM */
    xphm_d2c(tmp_dram_addr, xphm_addr, n_bytes, csr_map_base, xphm_d2c_intr_fd);
}

// Move data from Host to BM directly.
static void bm_wr_through(int h2c_fd, void* csr_map_base, int bm_d2c_intr_fd, uint32_t bm_addr, void* buf, uint32_t n_bytes) {
    uint32_t tmp_dram_addr = 0x80000000;
    /* Host -> DRAM */
    dram_wr(h2c_fd, buf, tmp_dram_addr, n_bytes);
    /* DRAM -> BM */
    bm_d2c(tmp_dram_addr, bm_addr, n_bytes, csr_map_base, bm_d2c_intr_fd);
}

// Move data from Host to RTM directly.
static void rtm_wr_through(int h2c_fd, void* csr_map_base, int rtm_d2c_intr_fd, uint32_t rtm_addr, void* buf, uint32_t n_bytes) {
    uint32_t tmp_dram_addr = 0x80000000;
    /* Host -> DRAM */
    dram_wr(h2c_fd, buf, tmp_dram_addr, n_bytes);
    /* DRAM -> RTM */
    rtm_d2c(tmp_dram_addr, rtm_addr, n_bytes, csr_map_base, rtm_d2c_intr_fd);
}

// Move data from RTM to Host directly.
static void rtm_rd_through(int c2h_fd, void* csr_map_base, int rtm_c2d_intr_fd, uint32_t rtm_addr, void* buf, uint32_t n_bytes) {
    uint32_t tmp_dram_addr = 0x80000000;
    /* RTM -> DRAM */
    rtm_c2d(tmp_dram_addr,rtm_addr, n_bytes, csr_map_base, rtm_c2d_intr_fd);
    /* DRAM -> Host */
    dram_rd(c2h_fd, buf, tmp_dram_addr, n_bytes);
}

// Move data from Host to CWM directly.
static void cwm_wr_through(int h2c_fd, void* csr_map_base, int cwm_d2c_intr_fd, uint32_t cwm_addr, void* buf, uint32_t n_bytes) {
    uint32_t tmp_dram_addr = 0x80000000;
    /* Host -> DRAM */
    dram_wr(h2c_fd, buf, tmp_dram_addr, n_bytes);
    /* DRAM -> CWM */
    cwm_d2c(tmp_dram_addr, cwm_addr, n_bytes, csr_map_base, cwm_d2c_intr_fd);
}

// Parameters of MaxPool/AvgPool
static void pool_params(
    /* Inputs */
    uint32_t INH_, uint32_t INW_, 
    uint32_t KH, uint32_t KW, uint32_t strideH, uint32_t strideW, 
    uint32_t padL, uint32_t padR, uint32_t padU, uint32_t padD,
    uint32_t M, uint32_t P, uint32_t R, uint32_t S,
    /* Outputs */
    uint32_t* INH2, uint32_t* INW2, 
    uint32_t* ifm_height, uint32_t* ofm_height, 
    uint32_t* n_last_batch, uint32_t* n_w_rnd, 
    uint32_t* row_bound, uint32_t* col_bound, 
    uint32_t* vec_size, uint32_t* vec_size_minus_1
) {
    uint32_t OH, OW;
    conv_get_ofm_shape(
        INH_, INW_, KH, KW, strideH, strideW,
        padL, padR, padU, padD,
        &OH, &OW
    );

    *INH2 = INH_+padU;
    *INW2 = INW_+padL;
    *ifm_height = (uint32_t)(ceil(INH_*INW_*1.0/R));
    *ofm_height = (uint32_t)(ceil(OH*OW*1.0/R));

    uint32_t n_x_rnd = (uint32_t)(ceil(OH*OW*1.0/P));
    if (n_x_rnd == 1)
        *n_last_batch = (uint32_t)(ceil(OH*OW*1.0/R));
    else
        *n_last_batch = (uint32_t)(ceil((OH*OW-(n_x_rnd-1)*P)*1.0/R));

    *n_w_rnd = 1;
    *row_bound = (OH-1)*strideH;
    *col_bound = (OW-1)*strideW;
    *vec_size = KH*KW;
    *vec_size_minus_1 = *vec_size-1;
}

// Parameters of Conv
static void conv_params(
    /* Inputs */
    uint32_t OC, uint32_t INC,
    uint32_t INH_, uint32_t INW_, 
    uint32_t KH, uint32_t KW, uint32_t strideH, uint32_t strideW, 
    uint32_t padL, uint32_t padR, uint32_t padU, uint32_t padD,
    uint32_t M, uint32_t P, uint32_t R, uint32_t S,
    /* Outputs */
    uint32_t* INH2, uint32_t* INW2, 
    uint32_t* ifm_height, uint32_t* ofm_height, 
    uint32_t* n_last_batch, uint32_t* n_w_rnd, 
    uint32_t* row_bound, uint32_t* col_bound, 
    uint32_t* vec_size, uint32_t* vec_size_minus_1
) {
    uint32_t OH, OW;
    conv_get_ofm_shape(
        INH_, INW_, KH, KW, strideH, strideW,
        padL, padR, padU, padD,
        &OH, &OW
    );

    *INH2 = INH_+padU;
    *INW2 = INW_+padL;
    *ifm_height = (uint32_t)(ceil(INH_*INW_*1.0/R));
    *ofm_height = (uint32_t)(ceil(OH*OW*1.0/R));

    uint32_t n_x_rnd = (uint32_t)(ceil(OH*OW*1.0/P));
    if (n_x_rnd == 1)
        *n_last_batch = (uint32_t)(ceil(OH*OW*1.0/R));
    else
        *n_last_batch = (uint32_t)(ceil((OH*OW-(n_x_rnd-1)*P)*1.0/R));

    *n_w_rnd = (uint32_t)(ceil(OC*1.0/(M*2)));
    *row_bound = (OH-1)*strideH;
    *col_bound = (OW-1)*strideW;
    *vec_size = INC*KH*KW/2;
    *vec_size_minus_1 = *vec_size-1;
}

// Load params.txt for Conv
static void load_params_conv(
    char* dir_path,
    uint32_t* m1, uint32_t* n1,
    uint32_t* w_zero_point, uint32_t* x_zero_point, uint32_t* y_zero_point
) {
    char file_path [1024];
    sprintf(file_path, "%sparams.txt", dir_path);
    FILE* f = fopen(file_path, "r");
    if (f == NULL) {
        printf("Open file failed, file_path: %s\n", file_path);
        exit(-1);
    }
    fscanf(f, "m1: %u\n", m1);
    fscanf(f, "n1: %u\n", n1);
    fscanf(f, "w_zero_point: %u\n", w_zero_point);
    fscanf(f, "x_zero_point: %u\n", x_zero_point);
    fscanf(f, "y_zero_point: %u\n", y_zero_point);
    fclose(f);
}

// load test data for Conv
static void load_data_conv(
    char* dir_path, 
    void* x, void* w, void* B, void* y, void* xphs
) {
    /* x.hex */
    char x_file_path [1024];
    sprintf(x_file_path, "%sx.hex", dir_path);
    rd_hex_file(x_file_path, x);
    /* w.hex */
    char w_file_path [1024];
    sprintf(w_file_path, "%sw.hex", dir_path);
    rd_hex_file(w_file_path, w);
    /* B.hex */
    char B_file_path [1024];
    sprintf(B_file_path, "%sB.hex", dir_path);
    rd_hex_file(B_file_path, B);
    /* y.hex */
    char y_file_path [1024];
    sprintf(y_file_path, "%sy.hex", dir_path);
    rd_hex_file(y_file_path, y);
    /* xphs.hex */
    char xphs_file_path [1024];
    sprintf(xphs_file_path, "%sxphs.hex", dir_path);
    rd_hex_file(xphs_file_path, xphs);
}

// Load params.txt for AveragePool
static void load_params_avgp(
    char* dir_path,
    uint32_t* m1, uint32_t* n1,
    uint32_t* x_zero_point, uint32_t* y_zero_point
) {
    char file_path [1024];
    sprintf(file_path, "%sparams.txt", dir_path);
    FILE* f = fopen(file_path, "r");
    if (f == NULL) {
        printf("Open file failed, file_path: %s\n", file_path);
        exit(-1);
    }
    fscanf(f, "m1: %u\n", m1);
    fscanf(f, "n1: %u\n", n1);
    fscanf(f, "x_zero_point: %u\n", x_zero_point);
    fscanf(f, "y_zero_point: %u\n", y_zero_point);
    fclose(f);
}

// load test data for AveragePool
static void load_data_avgp(
    char* dir_path, 
    void* X, void* Y, void* xphs
) {
    /* X.hex */
    char X_file_path [1024];
    sprintf(X_file_path, "%sX.hex", dir_path);
    rd_hex_file(X_file_path, X);
    /* Y.hex */
    char Y_file_path [1024];
    sprintf(Y_file_path, "%sY.hex", dir_path);
    rd_hex_file(Y_file_path, Y);
    /* xphs.hex */
    char xphs_file_path [1024];
    sprintf(xphs_file_path, "%sxphs.hex", dir_path);
    rd_hex_file(xphs_file_path, xphs);
}

// load test data for MaxPool
static void load_data_maxp(
    char* dir_path, 
    void* X, void* Y, void* xphs
) {
    /* X.hex */
    char X_file_path [1024];
    sprintf(X_file_path, "%sX.hex", dir_path);
    rd_hex_file(X_file_path, X);
    /* Y.hex */
    char Y_file_path [1024];
    sprintf(Y_file_path, "%sY.hex", dir_path);
    rd_hex_file(Y_file_path, Y);
    /* xphs.hex */
    char xphs_file_path [1024];
    sprintf(xphs_file_path, "%sxphs.hex", dir_path);
    rd_hex_file(xphs_file_path, xphs);
}

// Load params.txt for Add
static void load_params_add(
    char* dir_path, 
    uint8_t* A_zero_point, uint8_t* B_zero_point, uint8_t* C_zero_point,
    uint32_t* m1, uint32_t* m2, uint8_t* n
) {
    char file_path [1024];
    sprintf(file_path, "%sparams.txt", dir_path);
    FILE* f = fopen(file_path, "r");
    if (f == NULL) {
        printf("Open file failed, file_path: %s\n", file_path);
        exit(-1);
    }
    fscanf(f, "A_zero_point: %hhd\n", A_zero_point);
    fscanf(f, "B_zero_point: %hhd\n", B_zero_point);
    fscanf(f, "C_zero_point: %hhd\n", C_zero_point);
    fscanf(f, "m1: %u\n", m1);
    fscanf(f, "m2: %u\n", m2);
    fscanf(f, "n: %hhd\n", n);
    fclose(f);
}

// load test data for Add
static void load_data_add(
    char* dir_path, 
    void* A, void* B, void* C
) {
    /* A.hex */
    char A_file_path [1024];
    sprintf(A_file_path, "%sA.hex", dir_path);
    rd_hex_file(A_file_path, A);
    /* B.hex */
    char B_file_path [1024];
    sprintf(B_file_path, "%sB.hex", dir_path);
    rd_hex_file(B_file_path, B);
    /* C.hex */
    char C_file_path [1024];
    sprintf(C_file_path, "%sC.hex", dir_path);
    rd_hex_file(C_file_path, C);
}

// Load params.txt for Remap
static void load_params_remap(
    char* dir_path, 
    uint8_t* X_zero_point, uint8_t* Y_zero_point,
    uint32_t* m1, uint8_t* n1
) {
    char file_path [1024];
    sprintf(file_path, "%sparams.txt", dir_path);
    FILE* f = fopen(file_path, "r");
    if (f == NULL) {
        printf("Open file failed, file_path: %s\n", file_path);
        exit(-1);
    }
    fscanf(f, "X_zero_point: %hhd\n", X_zero_point);
    fscanf(f, "Y_zero_point: %hhd\n", Y_zero_point);
    fscanf(f, "m1: %u\n", m1);
    fscanf(f, "n1: %hhd\n", n1);
    fclose(f);
}

// Load test data for Remap
static void load_data_remap(
    char* dir_path, 
    void* X, void* Y
) {
    /* X.hex */
    char X_file_path [1024];
    sprintf(X_file_path, "%sX.hex", dir_path);
    rd_hex_file(X_file_path, X);
    /* Y.hex */
    char Y_file_path [1024];
    sprintf(Y_file_path, "%sY.hex", dir_path);
    rd_hex_file(Y_file_path, Y);
}

// Load params.txt for Fc
static void load_params_fc(
    char* dir_path, 
    uint32_t* a_zero_point, uint32_t* b_zero_point, uint32_t* y_zero_point,
    uint32_t* m1, uint32_t* n1
) {
    uint32_t INC, OC;
    char file_path [1024];
    sprintf(file_path, "%sparams.txt", dir_path);
    FILE* f = fopen(file_path, "r");
    if (f == NULL) {
        printf("Open file failed, file_path: %s\n", file_path);
        exit(-1);
    }
    fscanf(f, "INC: %u\n", &INC);
    fscanf(f, "OC: %u\n", &OC);
    fscanf(f, "a_zero_point: %u\n", a_zero_point);
    fscanf(f, "b_zero_point: %u\n", b_zero_point);
    fscanf(f, "m1: %u\n", m1);
    fscanf(f, "n1: %u\n", n1);
    fscanf(f, "y_zero_point: %u\n", y_zero_point);
    fclose(f);
}

// Load test data for Fc
static void load_data_fc(
    char* dir_path, 
    void* x, void* bias, void* w, void* y
) {
    /* x.hex */
    char x_file_path [1024];
    sprintf(x_file_path, "%sx.hex", dir_path);
    rd_hex_file(x_file_path, x);
    /* bias.hex */
    char bias_file_path [1024];
    sprintf(bias_file_path, "%sbias.hex", dir_path);
    rd_hex_file(bias_file_path, bias);
    /* w.hex */
    char w_file_path [1024];
    sprintf(w_file_path, "%sw.hex", dir_path);
    rd_hex_file(w_file_path, w);
    /* y.hex */
    char y_file_path [1024];
    sprintf(y_file_path, "%sy.hex", dir_path);
    rd_hex_file(y_file_path, y);
}

void test_dram_rw(int h2c_fd, int c2h_fd, uint32_t addr, uint32_t size, long* h2c_latency, long* c2h_latency) {
    struct timespec start, end;
    void *src_buf, *dst_buf;

    /* Prepare data */
    posix_memalign((void **)&src_buf, 4096, size);
    for (uint32_t i=0; i<size; i++)
        *(((uint8_t*)src_buf)+i) = rand()%256;
    posix_memalign((void **)&dst_buf, 4096, size);
    memset(dst_buf, 0, size);
    /* Host -> DRAM */
    clock_gettime(CLOCK_MONOTONIC, &start);
    dram_wr(h2c_fd, src_buf, addr, size);
    clock_gettime(CLOCK_MONOTONIC, &end);
    timespec_sub(&end, &start);
    *h2c_latency = end.tv_nsec;
    /* DRAM -> Host */
    clock_gettime(CLOCK_MONOTONIC, &start);
    dram_rd(c2h_fd, dst_buf, addr, size);
    clock_gettime(CLOCK_MONOTONIC, &end);
    timespec_sub(&end, &start);
    *c2h_latency = end.tv_nsec;
    /* Check results */
    uint32_t match = 0, mismatch = 0;
    check_buf(src_buf, dst_buf, size, &match, &mismatch);
    printf("Total: %u, Match: %u, Mismatch: %u\n", size, match, mismatch);

    free(src_buf);
    free(dst_buf);
}

void test_rtm_rw(
    int h2c_fd, int c2h_fd, 
    void* csr_map_base, 
    int rtm_d2c_intr_fd, int rtm_c2d_intr_fd, 
    uint32_t rtm_addr, uint32_t n_bytes,
    long* d2c_latency, long* c2d_latency
) {
    struct timespec start, end;
    void *src_buf, *dst_buf;

    /* Prepare data */
    posix_memalign((void **)&src_buf, 4096, n_bytes);
    for (uint32_t i=0; i<n_bytes; i++)
        *(((uint8_t*)src_buf)+i) = rand()%256;
    posix_memalign((void **)&dst_buf, 4096, n_bytes);
    memset(dst_buf, 0, n_bytes);
    /* Host -> DRAM, DRAM -> RTM */
    uint32_t src_dram_addr = 0x80000000;
    dram_wr(h2c_fd, src_buf, src_dram_addr, n_bytes);
    clock_gettime(CLOCK_MONOTONIC, &start);
    rtm_d2c(src_dram_addr, rtm_addr, n_bytes, csr_map_base, rtm_d2c_intr_fd);
    clock_gettime(CLOCK_MONOTONIC, &end);
    timespec_sub(&end, &start);
    *d2c_latency = end.tv_nsec;
    /* RTM -> DRAM, DRAM -> Host */
    uint32_t dst_dram_addr = src_dram_addr + n_bytes;
    clock_gettime(CLOCK_MONOTONIC, &start);
    rtm_c2d(dst_dram_addr, rtm_addr, n_bytes, csr_map_base, rtm_c2d_intr_fd);
    clock_gettime(CLOCK_MONOTONIC, &end);
    timespec_sub(&end, &start);
    *c2d_latency = end.tv_nsec;
    dram_rd(c2h_fd, dst_buf, dst_dram_addr, n_bytes);
    /* Check results */
    uint32_t match = 0, mismatch = 0;
    check_buf(src_buf, dst_buf, n_bytes, &match, &mismatch);
    printf("Total: %u, Match: %u, Mismatch: %u\n", n_bytes, match, mismatch);

    free(src_buf);
    free(dst_buf);
}

void test_conv1(
    int h2c_fd,
    void* csr_map_base, 
    int im_d2c_intr_fd, int xphm_d2c_intr_fd, int exec_intr_fd,
    uint32_t OC, uint32_t INC, uint32_t INH_, uint32_t INW_, 
    uint32_t KH, uint32_t KW, uint32_t strideH, uint32_t strideW, 
    uint32_t padL, uint32_t padR, uint32_t padU, uint32_t padD, int sta_mode,
    uint32_t M, uint32_t P, uint32_t Q, uint32_t R, uint32_t S,
    uint32_t* latency
) {
    /* Parameters. */
    uint32_t OH, OW;
    uint32_t INH2; uint32_t INW2;
    uint32_t ifm_height; uint32_t ofm_height;
    uint32_t n_last_batch; uint32_t n_w_rnd;
    uint32_t row_bound; uint32_t col_bound;
    uint32_t vec_size; uint32_t vec_size_minus_1;
    uint32_t n_x_rnd;
    conv_get_ofm_shape(
        INH_, INW_, KH, KW, strideH, strideW,
        padL, padR, padU, padD,
        &OH, &OW
    );
    conv_params(
        OC, INC,
        INH_, INW_,
        KH, KW, strideH, strideW,
        padL, padR, padU, padD,
        M, P, R, S,
        &INH2, &INW2, 
        &ifm_height, &ofm_height, 
        &n_last_batch, &n_w_rnd, 
        &row_bound, &col_bound, 
        &vec_size, &vec_size_minus_1
    );
    /* Generate X packte headers. */
    n_x_rnd = (uint32_t)(ceil(OH*OW*1.0/P));
    struct Xph* xphs = (struct Xph*) malloc(sizeof(struct Xph)*n_x_rnd);
    gen_Xphs(
        INH_, INW_, KH, KW, strideH, strideW,
        padL, padR, padU, padD, P, Q, xphs
    );
    /* Write xphs to XPHM */
    void* xphs_buf;
    posix_memalign((void **)&xphs_buf, 4096, 64*n_x_rnd);
    Xphs_bytes(xphs, n_x_rnd, (uint8_t*)xphs_buf);
    xphm_wr_through(h2c_fd, csr_map_base, xphm_d2c_intr_fd, 0, xphs_buf, 64*n_x_rnd);
    /* Build Conv instruction. */
    struct Conv* conv_ins = malloc(sizeof(struct Conv));
    conv_ins->op_type = INS_CONV;
    conv_ins->xphs_addr = 0;
    conv_ins->xphs_len = n_x_rnd-1;
    conv_ins->W_addr = (sta_mode ? 0 : 0x80000000);
    conv_ins->W_n_bytes = OC*INC*KH*KW;
    conv_ins->B_addr = 0;
    conv_ins->X_addr = 0;
    conv_ins->Y_addr = 0;
    conv_ins->OC = OC;
    conv_ins->INC = INC/S-1;
    conv_ins->INW_ = INW_;
    conv_ins->KH = KH-1;
    conv_ins->KW = KW-1;
    conv_ins->strideH = strideH;
    conv_ins->strideW = strideW;
    conv_ins->padL = padL;
    conv_ins->padU = padU;
    conv_ins->INH2 = INH2;
    conv_ins->INW2 = INW2;
    conv_ins->ifm_height = ifm_height;
    conv_ins->ofm_height = ofm_height;
    conv_ins->n_last_batch = n_last_batch;
    conv_ins->n_W_round = n_w_rnd-1;
    conv_ins->row_bound = row_bound;
    conv_ins->col_bound = col_bound;
    conv_ins->vec_size = vec_size;
    conv_ins->vec_size_minus_1 = vec_size_minus_1;
    conv_ins->Xz = 0;
    conv_ins->Wz = 0;
    conv_ins->Yz = 0;
    conv_ins->m1 = 1024;
    conv_ins->n1 = 2;
    conv_ins->obj1 = 0x00;
    conv_ins->obj2 = 0x80;
    conv_ins->obj3 = 0;
    conv_ins->obj4 = 0;
    /* Build End instruction. */
    struct End* end_ins = malloc(sizeof(struct End));
    end_ins->op_type = INS_NONE;
    /* Make instruction buffer. */
    void* ins_buf;
    posix_memalign((void **)&ins_buf, 4096, 64*2);
    Conv_bytes(conv_ins, (uint8_t*)ins_buf);
    End_bytes(end_ins, (uint8_t*)ins_buf+64);
    /* Write instructions. */
    im_wr_through(h2c_fd, csr_map_base, im_d2c_intr_fd, ins_buf, 64*2);
    /* Execute instructions. */
    exec(csr_map_base, exec_intr_fd);
    /* Read the latency register. */
    reg_rd(csr_map_base, CSR_EXEC_LATENCY_CONV, latency);

    free(xphs);
    free(xphs_buf);
    free(conv_ins);
    free(end_ins);
    free(ins_buf);
}

// void test_conv2(
//     int h2c_fd, int c2h_fd,
//     void* csr_map_base, 
//     int rtm_d2c_intr_fd, int rtm_c2d_intr_fd, 
//     int cwm_d2c_intr_fd, int bm_d2c_intr_fd, 
//     int im_d2c_intr_fd, int xphm_d2c_intr_fd, int exec_intr_fd,
//     uint32_t OC, uint32_t INC, uint32_t INH_, uint32_t INW_, 
//     uint32_t KH, uint32_t KW, uint32_t strideH, uint32_t strideW, 
//     uint32_t padL, uint32_t padR, uint32_t padU, uint32_t padD, int sta_mode,
//     uint32_t M, uint32_t P, uint32_t Q, uint32_t R, uint32_t S,
//     uint32_t* latency,
//     char* test_case_dir_path
// ) {
//     uint32_t m1, n1, w_zero_point, x_zero_point, y_zero_point;
//     void *x, *w, *B, *y, *xphs;
//     /* Parameters. */
//     uint32_t OH, OW;
//     uint32_t INH2; uint32_t INW2;
//     uint32_t ifm_height; uint32_t ofm_height;
//     uint32_t n_last_batch; uint32_t n_w_rnd;
//     uint32_t row_bound; uint32_t col_bound;
//     uint32_t vec_size; uint32_t vec_size_minus_1;
//     uint32_t n_x_rnd;
//     conv_get_ofm_shape(
//         INH_, INW_, KH, KW, strideH, strideW,
//         padL, padR, padU, padD,
//         &OH, &OW
//     );
//     conv_params(
//         OC, INC,
//         INH_, INW_,
//         KH, KW, strideH, strideW,
//         padL, padR, padU, padD,
//         M, P, R, S,
//         &INH2, &INW2, 
//         &ifm_height, &ofm_height, 
//         &n_last_batch, &n_w_rnd, 
//         &row_bound, &col_bound, 
//         &vec_size, &vec_size_minus_1
//     );
//     n_x_rnd = (uint32_t)(ceil(OH*OW*1.0/P));
//     /* Load quantization parameters from file. */
//     load_params_conv(
//         test_case_dir_path,
//         &m1, &n1, &w_zero_point, &x_zero_point, &y_zero_point
//     );
//     /* Load data from file. */
//     posix_memalign((void **)&x, 4096, INC*INH_*INW_);
//     posix_memalign((void **)&w, 4096, OC*INC*KH*KW);
//     posix_memalign((void **)&B, 4096, OC*4);
//     posix_memalign((void **)&y, 4096, OC*OH*OW);
//     posix_memalign((void **)&xphs, 4096, n_x_rnd*8);
//     load_data_conv(
//         test_case_dir_path,
//         x, w, B, y, xphs
//     );
//     /* Generate X packte headers in the driver side. */
//     struct Xph* xphs_dri = (struct Xph*) malloc(sizeof(struct Xph)*n_x_rnd);
//     gen_Xphs(
//         INH_, INW_, KH, KW, strideH, strideW,
//         padL, padR, padU, padD, P, Q, xphs_dri
//     );
//     /* Make sure generated xphs are the same as that provided by the test case. */
//     for (uint32_t i=0; i<n_x_rnd; i++) {
//         if ((xphs_dri+i)->X_a_ != *(((uint16_t*)xphs)+i*4)) {
//             printf("Check xphs failed, X_a_ mismatch, x_rnd_idx: %d\n", i);
//             exit(-1);
//         }
//         if ((xphs_dri+i)->len_per_chan != *(((uint16_t*)xphs)+i*4+1)) {
//             printf("Check xphs failed, len_per_chan mismatch, x_rnd_idx: %d\n", i);
//             exit(-1);
//         }
//         if ((xphs_dri+i)->win_x != *(((uint16_t*)xphs)+i*4+2)) {
//             printf("Check xphs failed, win_x mismatch, x_rnd_idx: %d\n", i);
//             exit(-1);
//         }
//         if ((xphs_dri+i)->win_y != *(((uint16_t*)xphs)+i*4+3)) {
//             printf("Check xphs failed, win_y mismatch, x_rnd_idx: %d\n", i);
//             exit(-1);
//         }
//     }
//     /* Write xphs to XPHM */
//     void* xphs_buf;
//     posix_memalign((void **)&xphs_buf, 4096, 64*n_x_rnd);
//     Xphs_bytes(xphs, n_x_rnd, (uint8_t*)xphs_buf);
//     xphm_wr_through(h2c_fd, csr_map_base, xphm_d2c_intr_fd, 0, xphs_buf, 64*n_x_rnd);
//     /* Build Conv instruction. */
//     struct Conv* conv_ins = malloc(sizeof(struct Conv));
//     conv_ins->op_type = INS_CONV;
//     conv_ins->xphs_addr = 0;
//     conv_ins->xphs_len = n_x_rnd-1;
//     conv_ins->W_addr = (sta_mode ? 0 : 0x80000000);
//     conv_ins->W_n_bytes = OC*INC*KH*KW;
//     conv_ins->B_addr = 0;
//     conv_ins->X_addr = 0;
//     conv_ins->Y_addr = conv_ins->X_addr + INC/4*ifm_height;
//     conv_ins->OC = OC;
//     conv_ins->INC = INC/4-1;
//     conv_ins->INW_ = INW_;
//     conv_ins->KH = KH-1;
//     conv_ins->KW = KW-1;
//     conv_ins->strideH = strideH;
//     conv_ins->strideW = strideW;
//     conv_ins->padL = padL;
//     conv_ins->padU = padU;
//     conv_ins->INH2 = INH2;
//     conv_ins->INW2 = INW2;
//     conv_ins->ifm_height = ifm_height;
//     conv_ins->ofm_height = ofm_height;
//     conv_ins->n_last_batch = n_last_batch;
//     conv_ins->n_W_round = n_w_rnd-1;
//     conv_ins->row_bound = row_bound;
//     conv_ins->col_bound = col_bound;
//     conv_ins->vec_size = vec_size;
//     conv_ins->vec_size_minus_1 = vec_size_minus_1;
//     conv_ins->Xz = x_zero_point;
//     conv_ins->Wz = w_zero_point;
//     conv_ins->Yz = y_zero_point;
//     conv_ins->m1 = m1;
//     conv_ins->n1 = n1-1;
//     conv_ins->obj1 = 0x00;
//     conv_ins->obj2 = 0x80;
//     conv_ins->obj3 = 0;
//     conv_ins->obj4 = 0;
//     /* Build End instruction. */
//     struct End* end_ins = malloc(sizeof(struct End));
//     end_ins->op_type = INS_NONE;
//     /* Make instruction buffer. */
//     void* ins_buf;
//     posix_memalign((void **)&ins_buf, 4096, 64*2);
//     Conv_bytes(conv_ins, (uint8_t*)ins_buf);
//     End_bytes(end_ins, (uint8_t*)ins_buf+64);
//     /* Write instructions. */
//     im_wr_through(h2c_fd, csr_map_base, im_d2c_intr_fd, ins_buf, 64*2);
//     /* Write x. */
//     void* aligned_x;
//     posix_memalign((void **)&aligned_x, 4096, INC/4*ifm_height*128);
//     rtm_tensor_align(INC, INH_, INW_, x, aligned_x);
//     rtm_wr_through(h2c_fd, csr_map_base, rtm_d2c_intr_fd, conv_ins->X_addr, aligned_x, INC/4*ifm_height*128);
//     /* Write B. */
//     bm_wr_through(h2c_fd, csr_map_base, bm_d2c_intr_fd, conv_ins->B_addr, B, OC*4);
//     /* Write w. */
//     if (sta_mode) {
//         cwm_wr_through(h2c_fd, csr_map_base, cwm_d2c_intr_fd, conv_ins->W_addr, w, OC*INC*KH*KW);
//     } else {
//         dram_wr(h2c_fd, w, 0x80000000, OC*INC*KH*KW);
//     }
//     /* Execute instructions. */
//     exec(csr_map_base, exec_intr_fd);
//     /* Read the latency register. */
//     reg_rd(csr_map_base, CSR_EXEC_LATENCY_CONV, latency);
//     /* Read y. */
//     void* dst_y;
//     posix_memalign((void **)&dst_y, 4096, OC/4*ofm_height*128);
//     rtm_rd_through(c2h_fd, csr_map_base, rtm_c2d_intr_fd, conv_ins->Y_addr, dst_y, OC/4*ofm_height*128);
//     /* Check results */
//     uint8_t expected, got;
//     uint32_t expected_offset, got_offset;
//     uint32_t match = 0, mismatch = 0;
//     uint32_t ofm_size = OH*OW;
//     for (uint32_t oc=0; oc<OC; oc++) {
//         for (uint32_t h=0; h<ofm_height; h++) {
//             for (uint32_t i=0; i<32; i++) {
//                 got_offset = (oc/4*ofm_height+h)*128 + (oc%4*32+i);
//                 if (h*32+i<ofm_size) {
//                     expected_offset = oc*ofm_size + h*32+i;
//                     expected = *(((uint8_t*)y)+expected_offset);
//                     got = *(((uint8_t*)dst_y)+got_offset);
//                     if (expected == got)
//                         match++;
//                     else
//                         mismatch ++;
//                 }
//             }
//         }
//     }
//     printf("Total: %u, Match: %u, Mismatch: %u\n", OC*OH*OW, match, mismatch);

//     free(x);
//     free(w);
//     free(B);
//     free(y);
//     free(xphs);
//     free(xphs_dri);
//     free(xphs_buf);
//     free(conv_ins);
//     free(end_ins);
//     free(ins_buf);
//     free(aligned_x);
//     free(dst_y);
// }

void test_maxp1(
    int h2c_fd,
    void* csr_map_base, 
    int im_d2c_intr_fd, int xphm_d2c_intr_fd, int exec_intr_fd,
    uint32_t OC, uint32_t INC, uint32_t INH_, uint32_t INW_, 
    uint32_t KH, uint32_t KW, uint32_t strideH, uint32_t strideW, 
    uint32_t padL, uint32_t padR, uint32_t padU, uint32_t padD,
    uint32_t M, uint32_t P, uint32_t Q, uint32_t R, uint32_t S,
    uint32_t* latency
) {
    /* Parameters. */
    uint32_t OH, OW;
    uint32_t INH2; uint32_t INW2;
    uint32_t ifm_height; uint32_t ofm_height;
    uint32_t n_last_batch; uint32_t n_w_rnd;
    uint32_t row_bound; uint32_t col_bound;
    uint32_t vec_size; uint32_t vec_size_minus_1;
    uint32_t n_x_rnd;
    conv_get_ofm_shape(
        INH_, INW_, KH, KW, strideH, strideW,
        padL, padR, padU, padD,
        &OH, &OW
    );
    pool_params(
        INH_, INW_,
        KH, KW, strideH, strideW,
        padL, padR, padU, padD,
        M, P, R, S, 
        &INH2, &INW2, 
        &ifm_height, &ofm_height, 
        &n_last_batch, &n_w_rnd, 
        &row_bound, &col_bound, 
        &vec_size, &vec_size_minus_1
    );
    /* Generate X packte headers. */
    n_x_rnd = (uint32_t)(ceil(OH*OW*1.0/P));
    struct Xph* xphs = (struct Xph*) malloc(sizeof(struct Xph)*n_x_rnd);
    gen_Xphs(
        INH_, INW_, KH, KW, strideH, strideW,
        padL, padR, padU, padD, P, Q, xphs
    );
    /* Write xphs to XPHM */
    void* xphs_buf;
    posix_memalign((void **)&xphs_buf, 4096, 64*n_x_rnd);
    Xphs_bytes(xphs, n_x_rnd, (uint8_t*)xphs_buf);
    xphm_wr_through(h2c_fd, csr_map_base, xphm_d2c_intr_fd, 0, xphs_buf, 64*n_x_rnd);
    /* Build MaxPool instruction. */
    struct Conv* maxp_ins = malloc(sizeof(struct Conv));
    maxp_ins->op_type = INS_MAXP;
    maxp_ins->xphs_addr = 0;
    maxp_ins->xphs_len = n_x_rnd-1;
    maxp_ins->W_addr = 0;
    maxp_ins->W_n_bytes = 0;
    maxp_ins->B_addr = 0;
    maxp_ins->X_addr = 0;
    maxp_ins->Y_addr = 0;
    maxp_ins->OC = OC;
    maxp_ins->INC = INC/S-1;
    maxp_ins->INW_ = INW_;
    maxp_ins->KH = KH-1;
    maxp_ins->KW = KW-1;
    maxp_ins->strideH = strideH;
    maxp_ins->strideW = strideW;
    maxp_ins->padL = padL;
    maxp_ins->padU = padU;
    maxp_ins->INH2 = INH2;
    maxp_ins->INW2 = INW2;
    maxp_ins->ifm_height = ifm_height;
    maxp_ins->ofm_height = ofm_height;
    maxp_ins->n_last_batch = n_last_batch;
    maxp_ins->n_W_round = 0;
    maxp_ins->row_bound = row_bound;
    maxp_ins->col_bound = col_bound;
    maxp_ins->vec_size = vec_size;
    maxp_ins->vec_size_minus_1 = vec_size_minus_1;
    maxp_ins->Xz = 0;
    maxp_ins->Wz = 0;
    maxp_ins->Yz = 0;
    maxp_ins->m1 = 1024;
    maxp_ins->n1 = 10-1;
    maxp_ins->obj1 = 0;
    maxp_ins->obj2 = 0;
    maxp_ins->obj3 = 0;
    maxp_ins->obj4 = 0;
    /* Build End instruction. */
    struct End* end_ins = malloc(sizeof(struct End));
    end_ins->op_type = INS_NONE;
    /* Make instruction buffer. */
    void* ins_buf;
    posix_memalign((void **)&ins_buf, 4096, 64*2);
    Conv_bytes(maxp_ins, (uint8_t*)ins_buf);
    End_bytes(end_ins, (uint8_t*)ins_buf+64);
    /* Write instructions. */
    im_wr_through(h2c_fd, csr_map_base, im_d2c_intr_fd, ins_buf, 64*2);
    /* Execute instructions. */
    exec(csr_map_base, exec_intr_fd);
    /* Read the latency register. */
    reg_rd(csr_map_base, CSR_EXEC_LATENCY_POOL, latency);

    free(xphs);
    free(xphs_buf);
    free(maxp_ins);
    free(end_ins);
    free(ins_buf);
}

// void test_maxp2(
//     int h2c_fd, int c2h_fd,
//     void* csr_map_base, 
//     int rtm_d2c_intr_fd, int rtm_c2d_intr_fd, 
//     int im_d2c_intr_fd, int xphm_d2c_intr_fd, int exec_intr_fd,
//     uint32_t OC, uint32_t INC, uint32_t INH_, uint32_t INW_, 
//     uint32_t KH, uint32_t KW, uint32_t strideH, uint32_t strideW, 
//     uint32_t padL, uint32_t padR, uint32_t padU, uint32_t padD,
//     uint32_t M, uint32_t P, uint32_t Q,
//     uint32_t* latency,
//     char* test_case_dir_path
// ) {
//     void *X, *Y, *xphs;
//     /* Parameters. */
//     uint32_t OH, OW;
//     uint32_t INH2; uint32_t INW2;
//     uint32_t ifm_height; uint32_t ofm_height;
//     uint32_t n_last_batch; uint32_t n_w_rnd;
//     uint32_t row_bound; uint32_t col_bound;
//     uint32_t vec_size; uint32_t vec_size_minus_1;
//     uint32_t n_x_rnd;
//     conv_get_ofm_shape(
//         INH_, INW_, KH, KW, strideH, strideW,
//         padL, padR, padU, padD,
//         &OH, &OW
//     );
//     pool_params(
//         INH_, INW_,
//         KH, KW, strideH, strideW,
//         padL, padR, padU, padD,
//         M, P, R, S, 
//         &INH2, &INW2, 
//         &ifm_height, &ofm_height, 
//         &n_last_batch, &n_w_rnd, 
//         &row_bound, &col_bound, 
//         &vec_size, &vec_size_minus_1
//     );
//     n_x_rnd = (uint32_t)(ceil(OH*OW*1.0/P));
//     /* Load data from file. */
//     posix_memalign((void **)&X, 4096, INC*INH_*INW_);
//     posix_memalign((void **)&Y, 4096, OC*OH*OW);
//     posix_memalign((void **)&xphs, 4096, n_x_rnd*8);
//     load_data_maxp(
//         test_case_dir_path,
//         X, Y, xphs
//     );
//     /* Generate X packte headers in the driver side. */
//     struct Xph* xphs_dri = (struct Xph*) malloc(sizeof(struct Xph)*n_x_rnd);
//     gen_Xphs(
//         INH_, INW_, KH, KW, strideH, strideW,
//         padL, padR, padU, padD, P, Q, xphs_dri
//     );
//     /* Make sure generated xphs are the same as that provided by the test case. */
//     for (uint32_t i=0; i<n_x_rnd; i++) {
//         if ((xphs_dri+i)->X_a_ != *(((uint16_t*)xphs)+i*4)) {
//             printf("Check xphs failed, X_a_ mismatch, x_rnd_idx: %d\n", i);
//             exit(-1);
//         }
//         if ((xphs_dri+i)->len_per_chan != *(((uint16_t*)xphs)+i*4+1)) {
//             printf("Check xphs failed, len_per_chan mismatch, x_rnd_idx: %d\n", i);
//             exit(-1);
//         }
//         if ((xphs_dri+i)->win_x != *(((uint16_t*)xphs)+i*4+2)) {
//             printf("Check xphs failed, win_x mismatch, x_rnd_idx: %d\n", i);
//             exit(-1);
//         }
//         if ((xphs_dri+i)->win_y != *(((uint16_t*)xphs)+i*4+3)) {
//             printf("Check xphs failed, win_y mismatch, x_rnd_idx: %d\n", i);
//             exit(-1);
//         }
//     }
//     /* Write xphs to XPHM */
//     void* xphs_buf;
//     posix_memalign((void **)&xphs_buf, 4096, 64*n_x_rnd);
//     Xphs_bytes(xphs, n_x_rnd, (uint8_t*)xphs_buf);
//     xphm_wr_through(h2c_fd, csr_map_base, xphm_d2c_intr_fd, 0, xphs_buf, 64*n_x_rnd);
//     /* Build MaxPool instruction. */
//     struct Conv* maxp_ins = malloc(sizeof(struct Conv));
//     maxp_ins->op_type = INS_MAXP;
//     maxp_ins->xphs_addr = 0;
//     maxp_ins->xphs_len = n_x_rnd-1;
//     maxp_ins->W_addr = 0;
//     maxp_ins->W_n_bytes = 0;
//     maxp_ins->B_addr = 0;
//     maxp_ins->X_addr = 0;
//     maxp_ins->Y_addr = maxp_ins->X_addr + INC/4*ifm_height;
//     maxp_ins->OC = OC;
//     maxp_ins->INC = INC/4-1;
//     maxp_ins->INW_ = INW_;
//     maxp_ins->KH = KH-1;
//     maxp_ins->KW = KW-1;
//     maxp_ins->strideH = strideH;
//     maxp_ins->strideW = strideW;
//     maxp_ins->padL = padL;
//     maxp_ins->padU = padU;
//     maxp_ins->INH2 = INH2;
//     maxp_ins->INW2 = INW2;
//     maxp_ins->ifm_height = ifm_height;
//     maxp_ins->ofm_height = ofm_height;
//     maxp_ins->n_last_batch = n_last_batch;
//     maxp_ins->n_W_round = 0;
//     maxp_ins->row_bound = row_bound;
//     maxp_ins->col_bound = col_bound;
//     maxp_ins->vec_size = vec_size;
//     maxp_ins->vec_size_minus_1 = vec_size_minus_1;
//     maxp_ins->Xz = 0;
//     maxp_ins->Wz = 0;
//     maxp_ins->Yz = 0;
//     maxp_ins->m1 = 1024;
//     maxp_ins->n1 = 9;
//     maxp_ins->obj1 = 0;
//     maxp_ins->obj2 = 0;
//     maxp_ins->obj3 = 0;
//     maxp_ins->obj4 = 0;
//     /* Build End instruction. */
//     struct End* end_ins = malloc(sizeof(struct End));
//     end_ins->op_type = INS_NONE;
//     /* Make instruction buffer. */
//     void* ins_buf;
//     posix_memalign((void **)&ins_buf, 4096, 64*2);
//     Conv_bytes(maxp_ins, (uint8_t*)ins_buf);
//     End_bytes(end_ins, (uint8_t*)ins_buf+64);
//     /* Write instructions. */
//     im_wr_through(h2c_fd, csr_map_base, im_d2c_intr_fd, ins_buf, 64*2);
//     /* Write X. */
//     void* aligned_X;
//     posix_memalign((void **)&aligned_X, 4096, INC/4*ifm_height*128);
//     rtm_tensor_align(INC, INH_, INW_, X, aligned_X);
//     rtm_wr_through(h2c_fd, csr_map_base, rtm_d2c_intr_fd, maxp_ins->X_addr, aligned_X, INC/4*ifm_height*128);
//     /* Execute instructions. */
//     exec(csr_map_base, exec_intr_fd);
//     /* Read the latency register. */
//     reg_rd(csr_map_base, CSR_EXEC_LATENCY_POOL, latency);
//     /* Read Y. */
//     void* dst_Y;
//     posix_memalign((void **)&dst_Y, 4096, OC/4*ofm_height*128);
//     rtm_rd_through(c2h_fd, csr_map_base, rtm_c2d_intr_fd, maxp_ins->Y_addr, dst_Y, OC/4*ofm_height*128);
//     /* Check results */
//     uint8_t expected, got;
//     uint32_t expected_offset, got_offset;
//     uint32_t match = 0, mismatch = 0;
//     uint32_t ofm_size = OH*OW;
//     for (uint32_t oc=0; oc<OC; oc++) {
//         for (uint32_t h=0; h<ofm_height; h++) {
//             for (uint32_t i=0; i<32; i++) {
//                 got_offset = (oc/4*ofm_height+h)*128 + (oc%4*32+i);
//                 if (h*32+i<ofm_size) {
//                     expected_offset = oc*ofm_size + h*32+i;
//                     expected = *(((uint8_t*)Y)+expected_offset);
//                     got = *(((uint8_t*)dst_Y)+got_offset);
//                     if (expected == got)
//                         match++;
//                     else
//                         mismatch ++;
//                 }
//             }
//         }
//     }
//     printf("Total: %u, Match: %u, Mismatch: %u\n", OC*OH*OW, match, mismatch);

//     free(X);
//     free(Y);
//     free(xphs);
//     free(xphs_dri);
//     free(xphs_buf);
//     free(maxp_ins);
//     free(end_ins);
//     free(ins_buf);
//     free(aligned_X);
//     free(dst_Y);
// }

void test_avgp1(
    int h2c_fd,
    void* csr_map_base, 
    int im_d2c_intr_fd, int xphm_d2c_intr_fd, int exec_intr_fd,
    uint32_t OC, uint32_t INC, uint32_t INH_, uint32_t INW_, 
    uint32_t KH, uint32_t KW, uint32_t strideH, uint32_t strideW, 
    uint32_t padL, uint32_t padR, uint32_t padU, uint32_t padD,
    uint32_t M, uint32_t P, uint32_t Q, uint32_t R, uint32_t S,
    uint32_t* latency
) {
    /* Parameters. */
    uint32_t OH, OW;
    uint32_t INH2; uint32_t INW2;
    uint32_t ifm_height; uint32_t ofm_height;
    uint32_t n_last_batch; uint32_t n_w_rnd;
    uint32_t row_bound; uint32_t col_bound;
    uint32_t vec_size; uint32_t vec_size_minus_1;
    uint32_t n_x_rnd;
    conv_get_ofm_shape(
        INH_, INW_, KH, KW, strideH, strideW,
        padL, padR, padU, padD,
        &OH, &OW
    );
    pool_params(
        INH_, INW_,
        KH, KW, strideH, strideW,
        padL, padR, padU, padD,
        M, P, R, S, 
        &INH2, &INW2, 
        &ifm_height, &ofm_height, 
        &n_last_batch, &n_w_rnd, 
        &row_bound, &col_bound, 
        &vec_size, &vec_size_minus_1
    );
    /* Generate X packte headers. */
    n_x_rnd = (uint32_t)(ceil(OH*OW*1.0/P));
    struct Xph* xphs = (struct Xph*) malloc(sizeof(struct Xph)*n_x_rnd);
    gen_Xphs(
        INH_, INW_, KH, KW, strideH, strideW,
        padL, padR, padU, padD, P, Q, xphs
    );
    /* Write xphs to XPHM */
    void* xphs_buf;
    posix_memalign((void **)&xphs_buf, 4096, 64*n_x_rnd);
    Xphs_bytes(xphs, n_x_rnd, (uint8_t*)xphs_buf);
    xphm_wr_through(h2c_fd, csr_map_base, xphm_d2c_intr_fd, 0, xphs_buf, 64*n_x_rnd);
    /* Build AveragePool instruction. */
    struct Conv* avgp_ins = malloc(sizeof(struct Conv));
    avgp_ins->op_type = INS_AVGP;
    avgp_ins->xphs_addr = 0;
    avgp_ins->xphs_len = n_x_rnd-1;
    avgp_ins->W_addr = 0;
    avgp_ins->W_n_bytes = 0;
    avgp_ins->B_addr = 0;
    avgp_ins->X_addr = 0;
    avgp_ins->Y_addr = 0;
    avgp_ins->OC = OC;
    avgp_ins->INC = INC/S-1;
    avgp_ins->INW_ = INW_;
    avgp_ins->KH = KH-1;
    avgp_ins->KW = KW-1;
    avgp_ins->strideH = strideH;
    avgp_ins->strideW = strideW;
    avgp_ins->padL = padL;
    avgp_ins->padU = padU;
    avgp_ins->INH2 = INH2;
    avgp_ins->INW2 = INW2;
    avgp_ins->ifm_height = ifm_height;
    avgp_ins->ofm_height = ofm_height;
    avgp_ins->n_last_batch = n_last_batch;
    avgp_ins->n_W_round = 0;
    avgp_ins->row_bound = row_bound;
    avgp_ins->col_bound = col_bound;
    avgp_ins->vec_size = vec_size;
    avgp_ins->vec_size_minus_1 = vec_size_minus_1;
    avgp_ins->Xz = 0;
    avgp_ins->Wz = 0;
    avgp_ins->Yz = 0;
    avgp_ins->m1 = 1024;
    avgp_ins->n1 = 2;
    avgp_ins->obj1 = 0;
    avgp_ins->obj2 = 0;
    avgp_ins->obj3 = 0;
    avgp_ins->obj4 = 0;
    /* Build End instruction. */
    struct End* end_ins = malloc(sizeof(struct End));
    end_ins->op_type = INS_NONE;
    /* Make instruction buffer. */
    void* ins_buf;
    posix_memalign((void **)&ins_buf, 4096, 64*2);
    Conv_bytes(avgp_ins, (uint8_t*)ins_buf);
    End_bytes(end_ins, (uint8_t*)ins_buf+64);
    /* Write instructions. */
    im_wr_through(h2c_fd, csr_map_base, im_d2c_intr_fd, ins_buf, 64*2);
    /* Execute instructions. */
    exec(csr_map_base, exec_intr_fd);
    /* Read the latency register. */
    reg_rd(csr_map_base, CSR_EXEC_LATENCY_POOL, latency);

    free(xphs);
    free(xphs_buf);
    free(avgp_ins);
    free(end_ins);
    free(ins_buf);
}

// void test_avgp2(
//     int h2c_fd, int c2h_fd,
//     void* csr_map_base, 
//     int rtm_d2c_intr_fd, int rtm_c2d_intr_fd, 
//     int im_d2c_intr_fd, int xphm_d2c_intr_fd, int exec_intr_fd,
//     uint32_t OC, uint32_t INC, uint32_t INH_, uint32_t INW_, 
//     uint32_t KH, uint32_t KW, uint32_t strideH, uint32_t strideW, 
//     uint32_t padL, uint32_t padR, uint32_t padU, uint32_t padD,
//     uint32_t M, uint32_t P, uint32_t Q,
//     uint32_t* latency,
//     char* test_case_dir_path
// ) {
//     uint32_t m1, n1, x_zero_point, y_zero_point;
//     void *X, *Y, *xphs;
//     /* Parameters. */
//     uint32_t OH, OW;
//     uint32_t INH2; uint32_t INW2;
//     uint32_t ifm_height; uint32_t ofm_height;
//     uint32_t n_last_batch; uint32_t n_w_rnd;
//     uint32_t row_bound; uint32_t col_bound;
//     uint32_t vec_size; uint32_t vec_size_minus_1;
//     uint32_t n_x_rnd;
//     conv_get_ofm_shape(
//         INH_, INW_, KH, KW, strideH, strideW,
//         padL, padR, padU, padD,
//         &OH, &OW
//     );
//     pool_params(
//         INH_, INW_,
//         KH, KW, strideH, strideW,
//         padL, padR, padU, padD,
//         M, P, R, S,
//         &INH2, &INW2, 
//         &ifm_height, &ofm_height, 
//         &n_last_batch, &n_w_rnd, 
//         &row_bound, &col_bound, 
//         &vec_size, &vec_size_minus_1
//     );
//     n_x_rnd = (uint32_t)(ceil(OH*OW*1.0/P));
//     /* Load quantization parameters from file. */
//     load_params_avgp(
//         test_case_dir_path,
//         &m1, &n1, &x_zero_point, &y_zero_point
//     );
//     /* Load data from file. */
//     posix_memalign((void **)&X, 4096, INC*INH_*INW_);
//     posix_memalign((void **)&Y, 4096, OC*OH*OW);
//     posix_memalign((void **)&xphs, 4096, n_x_rnd*8);
//     load_data_avgp(
//         test_case_dir_path,
//         X, Y, xphs
//     );
//     /* Generate X packte headers in the driver side. */
//     struct Xph* xphs_dri = (struct Xph*) malloc(sizeof(struct Xph)*n_x_rnd);
//     gen_Xphs(
//         INH_, INW_, KH, KW, strideH, strideW,
//         padL, padR, padU, padD, P, Q, xphs_dri
//     );
//     /* Make sure generated xphs are the same as that provided by the test case. */
//     for (uint32_t i=0; i<n_x_rnd; i++) {
//         if ((xphs_dri+i)->X_a_ != *(((uint16_t*)xphs)+i*4)) {
//             printf("Check xphs failed, X_a_ mismatch, x_rnd_idx: %d\n", i);
//             exit(-1);
//         }
//         if ((xphs_dri+i)->len_per_chan != *(((uint16_t*)xphs)+i*4+1)) {
//             printf("Check xphs failed, len_per_chan mismatch, x_rnd_idx: %d\n", i);
//             exit(-1);
//         }
//         if ((xphs_dri+i)->win_x != *(((uint16_t*)xphs)+i*4+2)) {
//             printf("Check xphs failed, win_x mismatch, x_rnd_idx: %d\n", i);
//             exit(-1);
//         }
//         if ((xphs_dri+i)->win_y != *(((uint16_t*)xphs)+i*4+3)) {
//             printf("Check xphs failed, win_y mismatch, x_rnd_idx: %d\n", i);
//             exit(-1);
//         }
//     }
//     /* Write xphs to XPHM */
//     void* xphs_buf;
//     posix_memalign((void **)&xphs_buf, 4096, 64*n_x_rnd);
//     Xphs_bytes(xphs, n_x_rnd, (uint8_t*)xphs_buf);
//     xphm_wr_through(h2c_fd, csr_map_base, xphm_d2c_intr_fd, 0, xphs_buf, 64*n_x_rnd);
//     /* Build MaxPool instruction. */
//     uint16_t neg_nxz = (uint16_t)(-KH*KW*x_zero_point);
//     struct Conv* avgp_ins = malloc(sizeof(struct Conv));
//     avgp_ins->op_type = INS_AVGP;
//     avgp_ins->xphs_addr = 0;
//     avgp_ins->xphs_len = n_x_rnd-1;
//     avgp_ins->W_addr = 0;
//     avgp_ins->W_n_bytes = 0;
//     avgp_ins->B_addr = 0;
//     avgp_ins->X_addr = 0;
//     avgp_ins->Y_addr = avgp_ins->X_addr + INC/4*ifm_height;
//     avgp_ins->OC = OC;
//     avgp_ins->INC = INC/4-1;
//     avgp_ins->INW_ = INW_;
//     avgp_ins->KH = KH-1;
//     avgp_ins->KW = KW-1;
//     avgp_ins->strideH = strideH;
//     avgp_ins->strideW = strideW;
//     avgp_ins->padL = padL;
//     avgp_ins->padU = padU;
//     avgp_ins->INH2 = INH2;
//     avgp_ins->INW2 = INW2;
//     avgp_ins->ifm_height = ifm_height;
//     avgp_ins->ofm_height = ofm_height;
//     avgp_ins->n_last_batch = n_last_batch;
//     avgp_ins->n_W_round = 0;
//     avgp_ins->row_bound = row_bound;
//     avgp_ins->col_bound = col_bound;
//     avgp_ins->vec_size = vec_size;
//     avgp_ins->vec_size_minus_1 = vec_size_minus_1;
//     avgp_ins->Xz = x_zero_point;
//     avgp_ins->Wz = 0;
//     avgp_ins->Yz = y_zero_point;
//     avgp_ins->m1 = m1;
//     avgp_ins->n1 = n1-1;
//     avgp_ins->obj1 = (neg_nxz & 0x000000ff);
//     avgp_ins->obj2 = (neg_nxz & 0x0000ff00) >> 8;
//     avgp_ins->obj3 = 0;
//     avgp_ins->obj4 = 0;
//     /* Build End instruction. */
//     struct End* end_ins = malloc(sizeof(struct End));
//     end_ins->op_type = INS_NONE;
//     /* Make instruction buffer. */
//     void* ins_buf;
//     posix_memalign((void **)&ins_buf, 4096, 64*2);
//     Conv_bytes(avgp_ins, (uint8_t*)ins_buf);
//     End_bytes(end_ins, (uint8_t*)ins_buf+64);
//     /* Write instructions. */
//     im_wr_through(h2c_fd, csr_map_base, im_d2c_intr_fd, ins_buf, 64*2);
//     /* Write X. */
//     void* aligned_X;
//     posix_memalign((void **)&aligned_X, 4096, INC/4*ifm_height*128);
//     rtm_tensor_align(INC, INH_, INW_, X, aligned_X);
//     rtm_wr_through(h2c_fd, csr_map_base, rtm_d2c_intr_fd, avgp_ins->X_addr, aligned_X, INC/4*ifm_height*128);
//     /* Execute instructions. */
//     exec(csr_map_base, exec_intr_fd);
//     /* Read the latency register. */
//     reg_rd(csr_map_base, CSR_EXEC_LATENCY_POOL, latency);
//     /* Read Y. */
//     void* dst_Y;
//     posix_memalign((void **)&dst_Y, 4096, OC/4*ofm_height*128);
//     rtm_rd_through(c2h_fd, csr_map_base, rtm_c2d_intr_fd, avgp_ins->Y_addr, dst_Y, OC/4*ofm_height*128);
//     /* Check results */
//     uint8_t expected, got;
//     uint32_t expected_offset, got_offset;
//     uint32_t match = 0, mismatch = 0;
//     uint32_t ofm_size = OH*OW;
//     for (uint32_t oc=0; oc<OC; oc++) {
//         for (uint32_t h=0; h<ofm_height; h++) {
//             for (uint32_t i=0; i<32; i++) {
//                 got_offset = (oc/4*ofm_height+h)*128 + (oc%4*32+i);
//                 if (h*32+i<ofm_size) {
//                     expected_offset = oc*ofm_size + h*32+i;
//                     expected = *(((uint8_t*)Y)+expected_offset);
//                     got = *(((uint8_t*)dst_Y)+got_offset);
//                     if (expected == got)
//                         match++;
//                     else
//                         mismatch ++;
//                 }
//             }
//         }
//     }
//     printf("Total: %u, Match: %u, Mismatch: %u\n", OC*OH*OW, match, mismatch);

//     free(X);
//     free(Y);
//     free(xphs);
//     free(xphs_dri);
//     free(xphs_buf);
//     free(avgp_ins);
//     free(end_ins);
//     free(ins_buf);
//     free(aligned_X);
//     free(dst_Y);
// }

void test_add1(
    int h2c_fd,
    void* csr_map_base, 
    int im_d2c_intr_fd, int exec_intr_fd,
    uint32_t vec_size, uint32_t* latency
) {
    assert(vec_size%128 == 0);
    uint32_t size = vec_size/128;

    /* Build Add instruction. */
    struct Add* add_ins = malloc(sizeof(struct Add));
    add_ins->op_type = INS_ADD;
    add_ins->A_addr = 0x00000000;
    add_ins->B_addr = 0x00000000;
    add_ins->C_addr = 0x00000000;
    add_ins->len = size - 1;
    add_ins->m1 = 1024;
    add_ins->m2 = 1024;
    add_ins->n = 2;
    add_ins->Az = 0;
    add_ins->Bz = 0;
    add_ins->Cz = 0;
    /* Build End instruction. */
    struct End* end_ins = malloc(sizeof(struct End));
    end_ins->op_type = INS_NONE;
    /* Make instruction buffer. */
    void* ins_buf;
    posix_memalign((void **)&ins_buf, 4096, 64*2);
    Add_bytes(add_ins, ins_buf);
    End_bytes(end_ins, ins_buf+64);
    /* Write instructions. */
    im_wr_through(h2c_fd, csr_map_base, im_d2c_intr_fd, ins_buf, 64*2);
    /* Execute instructions. */
    exec(csr_map_base, exec_intr_fd);
    /* Read the latency register. */
    reg_rd(csr_map_base, CSR_EXEC_LATENCY_ADD, latency);

    free(add_ins);
    free(end_ins);
    free(ins_buf);
}

// void test_add2(
//     int h2c_fd, int c2h_fd,
//     void* csr_map_base, 
//     int rtm_d2c_intr_fd, int rtm_c2d_intr_fd, 
//     int im_d2c_intr_fd, int exec_intr_fd,
//     uint32_t vec_size, uint32_t* latency,
//     char* test_case_dir_path
// ) {
//     uint8_t A_zero_point, B_zero_point, C_zero_point;
//     uint32_t m1, m2;
//     uint8_t n;
//     void *A, *B, *C;
//     /* Load parameters from file. */
//     load_params_add(
//         test_case_dir_path, 
//         &A_zero_point, &B_zero_point,  &C_zero_point, 
//         &m1, &m2, &n
//     );
//     /* Load data from file. */
//     posix_memalign((void **)&A, 4096, vec_size);
//     posix_memalign((void **)&B, 4096, vec_size);
//     posix_memalign((void **)&C, 4096, vec_size);
//     load_data_add(
//         test_case_dir_path, 
//         A, B, C
//     );
//     /* Build Add instruction. */
//     uint32_t size = vec_size/128;
//     struct Add* add_ins = malloc(sizeof(struct Add));
//     add_ins->op_type = INS_ADD;
//     add_ins->A_addr = 0x00000000;
//     add_ins->B_addr = add_ins->A_addr + size;
//     add_ins->C_addr = add_ins->B_addr;
//     add_ins->len = size - 1;
//     add_ins->m1 = m1;
//     add_ins->m2 = m2;
//     add_ins->n = n - 1;
//     add_ins->Az = A_zero_point;
//     add_ins->Bz = B_zero_point;
//     add_ins->Cz = C_zero_point;
//     /* Build End instruction. */
//     struct End* end_ins = malloc(sizeof(struct End));
//     end_ins->op_type = INS_NONE;
//     /* Write instructions. */
//     void* ins_buf;
//     posix_memalign((void **)&ins_buf, 4096, 64*2);
//     Add_bytes(add_ins, (uint8_t*)ins_buf);
//     End_bytes(end_ins, ((uint8_t*)ins_buf)+64);
//     im_wr_through(h2c_fd, csr_map_base, im_d2c_intr_fd, ins_buf, 64*2);
//     /* Write A, B. */
//     rtm_wr_through(h2c_fd, csr_map_base, rtm_d2c_intr_fd, add_ins->A_addr, A, vec_size);
//     rtm_wr_through(h2c_fd, csr_map_base, rtm_d2c_intr_fd, add_ins->B_addr, B, vec_size);
//     /* Execute instructions. */
//     exec(csr_map_base, exec_intr_fd);
//     /* Read the latency register. */
//     reg_rd(csr_map_base, CSR_EXEC_LATENCY_ADD, latency);
//     /* Read Y. */
//     void* dst_C;
//     posix_memalign((void **)&dst_C, 4096, vec_size);
//     rtm_rd_through(c2h_fd, csr_map_base, rtm_c2d_intr_fd, add_ins->C_addr, dst_C, vec_size);
//     /* Check results */
//     uint32_t match = 0, mismatch = 0;
//     check_buf(C, dst_C, vec_size, &match, &mismatch);
//     printf("Total: %u, Match: %u, Mismatch: %u\n", vec_size, match, mismatch);

//     free(A);
//     free(B);
//     free(C);
//     free(add_ins);
//     free(end_ins);
//     free(ins_buf);
//     free(dst_C);
// }

void test_remap1(
    int h2c_fd,
    void* csr_map_base, 
    int im_d2c_intr_fd, int exec_intr_fd,
    uint32_t vec_size, uint32_t* latency
) {
    uint32_t size = vec_size/128;
    
    /* Build Reamp instruction. */
    struct Remap* remap_ins = malloc(sizeof(struct Remap));
    remap_ins->op_type = INS_REMAP;
    remap_ins->X_addr = 0x00000000;
    remap_ins->Y_addr = remap_ins->X_addr + size;
    remap_ins->len = size - 1;
    remap_ins->m1 = 1024;
    remap_ins->n1 = 2;
    remap_ins->Xz = 0;
    remap_ins->Yz = 0;
    /* Build End instruction. */
    struct End* end_ins = malloc(sizeof(struct End));
    end_ins->op_type = INS_NONE;
    /* Make instruction buffer. */
    void* ins_buf;
    posix_memalign((void **)&ins_buf, 4096, 64*2);
    Remap_bytes(remap_ins, (uint8_t*)ins_buf);
    End_bytes(end_ins, ((uint8_t*)ins_buf)+64);
    /* Write instructions. */
    im_wr_through(h2c_fd, csr_map_base, im_d2c_intr_fd, ins_buf, 64*2);
    /* Execute instructions. */
    exec(csr_map_base, exec_intr_fd);
    /* Read the latency register. */
    reg_rd(csr_map_base, CSR_EXEC_LATENCY_REMAP, latency);

    free(remap_ins);
    free(end_ins);
    free(ins_buf);
}

// void test_remap2(
//     int h2c_fd, int c2h_fd,
//     void* csr_map_base, 
//     int rtm_d2c_intr_fd, int rtm_c2d_intr_fd, 
//     int im_d2c_intr_fd, int exec_intr_fd,
//     uint32_t vec_size, uint32_t* latency,
//     char* test_case_dir_path
// ) {
//     uint8_t X_zero_point, Y_zero_point;
//     uint32_t m1;
//     uint8_t n1;
//     void *X, *Y;
//     /* Load parameters from file. */
//     load_params_remap(
//         test_case_dir_path, 
//         &X_zero_point, &Y_zero_point, &m1, &n1
//     );
//     /* Load data from file. */
//     posix_memalign((void **)&X, 4096, vec_size);
//     posix_memalign((void **)&Y, 4096, vec_size);
//     load_data_remap(
//         test_case_dir_path, 
//         X, Y
//     );
//     /* Build Remap instruction. */
//     uint32_t size = vec_size/128;
//     struct Remap* remap_ins = malloc(sizeof(struct Remap));
//     remap_ins->op_type = INS_REMAP;
//     remap_ins->X_addr = 0x00000000;
//     remap_ins->Y_addr = remap_ins->X_addr + size;
//     remap_ins->len = size - 1;
//     remap_ins->m1 = m1;
//     remap_ins->n1 = n1 - 1;
//     remap_ins->Xz = (uint16_t)(-X_zero_point);
//     remap_ins->Yz = Y_zero_point;
//     /* Build End instruction. */
//     struct End* end_ins = malloc(sizeof(struct End));
//     end_ins->op_type = INS_NONE;
//     /* Write instructions. */
//     void* ins_buf;
//     posix_memalign((void **)&ins_buf, 4096, 64*2);
//     Remap_bytes(remap_ins, (uint8_t*)ins_buf);
//     End_bytes(end_ins, ((uint8_t*)ins_buf)+64);
//     im_wr_through(h2c_fd, csr_map_base, im_d2c_intr_fd, ins_buf, 64*2);
//     /* Write X. */
//     rtm_wr_through(h2c_fd, csr_map_base, rtm_d2c_intr_fd, remap_ins->X_addr, X, vec_size);
//     /* Execute instructions. */
//     exec(csr_map_base, exec_intr_fd);
//     /* Read the latency register. */
//     reg_rd(csr_map_base, CSR_EXEC_LATENCY_REMAP, latency);
//     /* Read Y. */
//     void* dst_Y;
//     posix_memalign((void **)&dst_Y, 4096, vec_size);
//     rtm_rd_through(c2h_fd, csr_map_base, rtm_c2d_intr_fd, remap_ins->Y_addr, dst_Y, vec_size);
//     /* Check results */
//     uint32_t match = 0, mismatch = 0;
//     check_buf(Y, dst_Y, vec_size, &match, &mismatch);
//     printf("Total: %u, Match: %u, Mismatch: %u\n", vec_size, match, mismatch);

//     free(X);
//     free(Y);
//     free(remap_ins);
//     free(end_ins);
//     free(ins_buf);
//     free(dst_Y);
// }

void test_fc1(
    int h2c_fd,
    void* csr_map_base,
    int im_d2c_intr_fd, int exec_intr_fd,
    uint32_t OC, uint32_t INC, int t_mode, uint32_t* latency
) {
    uint32_t n_rnd = OC/64;

    /* Build Fc instruction. */
    struct Conv* fc_ins = malloc(sizeof(struct Conv));
    fc_ins->op_type = INS_FC;
    fc_ins->xphs_addr = 0;
    fc_ins->xphs_len = n_rnd-1;
    fc_ins->W_addr = 0x80000000;
    fc_ins->W_n_bytes = OC*INC;
    fc_ins->B_addr = 0;
    fc_ins->X_addr = 0;
    fc_ins->Y_addr = 0;
    fc_ins->OC = 0;
    fc_ins->INC = 0;
    fc_ins->INW_ = 0;
    fc_ins->KH = 0;
    fc_ins->KW = 0;
    fc_ins->strideH = 0;
    fc_ins->strideW = 0;
    fc_ins->padL = 0;
    fc_ins->padU = 0;
    fc_ins->INH2 = 0;
    fc_ins->INW2 = 0;
    fc_ins->ifm_height = 0;
    fc_ins->ofm_height = 0;
    fc_ins->n_last_batch = 0;
    fc_ins->n_W_round = 0;
    fc_ins->row_bound = 0;
    fc_ins->col_bound = 0;
    fc_ins->vec_size = INC;
    fc_ins->vec_size_minus_1 = INC-1;
    fc_ins->Xz = 0;
    fc_ins->Wz = 0;
    fc_ins->Yz = 0;
    fc_ins->m1 = 1024;
    fc_ins->n1 = 2;
    fc_ins->obj1 = (t_mode ? 0 : 1);
    fc_ins->obj2 = 0;
    fc_ins->obj3 = 0;
    fc_ins->obj4 = 0;
    /* Build End instruction. */
    struct End* end_ins = malloc(sizeof(struct End));
    end_ins->op_type = INS_NONE;
    /* Make instruction buffer. */
    void* ins_buf;
    posix_memalign((void **)&ins_buf, 4096, 64*2);
    Conv_bytes(fc_ins, (uint8_t*)ins_buf);
    End_bytes(end_ins, ((uint8_t*)ins_buf)+64);
    /* Write instructions. */
    im_wr_through(h2c_fd, csr_map_base, im_d2c_intr_fd, ins_buf, 64*2);
    /* Execute instructions. */
    exec(csr_map_base, exec_intr_fd);
    /* Read the latency register. */
    reg_rd(csr_map_base, CSR_EXEC_LATENCY_FC, latency);

    free(fc_ins);
    free(end_ins);
    free(ins_buf);
}

// void test_fc2(
//     int h2c_fd, int c2h_fd, 
//     void* csr_map_base,
//     int rtm_d2c_intr_fd, int rtm_c2d_intr_fd, 
//     int bm_d2c_intr_fd,
//     int im_d2c_intr_fd, int exec_intr_fd,
//     uint32_t OC, uint32_t INC, int t_mode, uint32_t* latency,
//     char* test_case_dir_path
// ) {
//     uint32_t a_zero_point = 0, b_zero_point = 0, y_zero_point = 0;
//     uint32_t m1 = 0;
//     uint32_t n1 = 0;
//     void *w, *bias, *x, *y;
//     /* Load parameters from file. */
//     load_params_fc(
//         test_case_dir_path,
//         &a_zero_point, &b_zero_point, &y_zero_point,
//         &m1, &n1
//     );
//     /* Load data from file. */
//     posix_memalign((void **)&x, 4096, INC);
//     posix_memalign((void **)&bias, 4096, OC*4);
//     posix_memalign((void **)&w, 4096, INC*OC);
//     posix_memalign((void **)&y, 4096, OC);
//     load_data_fc(
//         test_case_dir_path,
//         x, bias, w, y
//     );
//     /* Build Fc instruction. */
//     uint32_t n_rnd = OC/64;
//     uint32_t x_size = t_mode ? ((uint32_t)(ceil(INC*1.0/4))) : ((uint32_t)(ceil(INC*1.0/128)));
//     struct Conv* fc_ins = malloc(sizeof(struct Conv));
//     fc_ins->op_type = INS_FC;
//     fc_ins->xphs_addr = 0;
//     fc_ins->xphs_len = n_rnd-1;
//     fc_ins->W_addr = 0x80000000;
//     fc_ins->W_n_bytes = OC*INC;
//     fc_ins->B_addr = 0;
//     fc_ins->X_addr = 0;
//     fc_ins->Y_addr = fc_ins->X_addr + x_size;
//     fc_ins->OC = 0;
//     fc_ins->INC = 0;
//     fc_ins->INW_ = 0;
//     fc_ins->KH = 0;
//     fc_ins->KW = 0;
//     fc_ins->strideH = 0;
//     fc_ins->strideW = 0;
//     fc_ins->padL = 0;
//     fc_ins->padU = 0;
//     fc_ins->INH2 = 0;
//     fc_ins->INW2 = 0;
//     fc_ins->ifm_height = 0;
//     fc_ins->ofm_height = 0;
//     fc_ins->n_last_batch = 0;
//     fc_ins->n_W_round = 0;
//     fc_ins->row_bound = 0;
//     fc_ins->col_bound = 0;
//     fc_ins->vec_size = INC;
//     fc_ins->vec_size_minus_1 = INC-1;
//     fc_ins->Xz = a_zero_point;
//     fc_ins->Wz = b_zero_point;
//     fc_ins->Yz = y_zero_point;
//     fc_ins->m1 = m1;
//     fc_ins->n1 = n1-1;
//     fc_ins->obj1 = (t_mode ? 0 : 1);
//     fc_ins->obj2 = 0;
//     fc_ins->obj3 = 0;
//     fc_ins->obj4 = 0;
//     /* Build End instruction. */
//     struct End* end_ins = malloc(sizeof(struct End));
//     end_ins->op_type = INS_NONE;
//     /* Write instructions. */
//     void* ins_buf;
//     posix_memalign((void **)&ins_buf, 4096, 64*2);
//     Conv_bytes(fc_ins, (uint8_t*)ins_buf);
//     End_bytes(end_ins, ((uint8_t*)ins_buf)+64);
//     im_wr_through(h2c_fd, csr_map_base, im_d2c_intr_fd, ins_buf, 64*2);
//     /* Write x. */
//     void* aligned_x;
//     posix_memalign((void **)&aligned_x, 4096, x_size*128);
//     if (t_mode) {
//         for (uint32_t i=0; i<INC; i++)
//             *(((uint8_t*)aligned_x)+i*32) = *(((uint8_t*)x)+i);
//     } else {
//         for (uint32_t i=0; i<INC; i++)
//             *(((uint8_t*)aligned_x)+i) = *(((uint8_t*)x)+i);
//     }
//     rtm_wr_through(h2c_fd, csr_map_base, rtm_d2c_intr_fd, fc_ins->X_addr, aligned_x, x_size*128);
//     /* Write bias. */
//     bm_wr_through(h2c_fd, csr_map_base, bm_d2c_intr_fd, fc_ins->B_addr, bias, OC*4);
//     /* Write w. */
//     dram_wr(h2c_fd, w, fc_ins->W_addr, OC*INC);
//     /* Execute instructions. */
//     exec(csr_map_base, exec_intr_fd);
//     /* Read the latency register. */
//     reg_rd(csr_map_base, CSR_EXEC_LATENCY_FC, latency);
//     /* Read y. */
//     void* dst_y;
//     posix_memalign((void **)&dst_y, 4096, OC);
//     rtm_rd_through(c2h_fd, csr_map_base, rtm_c2d_intr_fd, fc_ins->Y_addr, dst_y, OC);
//     /* Check results */
//     uint32_t match = 0, mismatch = 0;
//     check_buf(y, dst_y, OC, &match, &mismatch);
//     printf("Total: %u, Match: %u, Mismatch: %u\n", OC, match, mismatch);

//     free(w);
//     free(bias);
//     free(x);
//     free(y);
//     free(fc_ins);
//     free(end_ins);
//     free(ins_buf);
//     free(aligned_x);
//     free(dst_y);
// }
