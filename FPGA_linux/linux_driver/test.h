#if !defined(__TEST_H__)
#define __TEST_H__

#include <stdint.h>

//
// Memory
//
/* Loopback test of DRAM, with read and write latency measured. */
void test_dram_rw(int h2c_fd, int c2h_fd, uint32_t addr, uint32_t size, long* h2c_latency, long* c2h_latency);
/* Loopback test of RTM, with read and write latency measured.  */
void test_rtm_rw(
    int h2c_fd, int c2h_fd, 
    void* csr_map_base, 
    int rtm_d2c_intr_fd, int rtm_c2d_intr_fd, 
    uint32_t rtm_addr, uint32_t n_bytes,
    long* d2c_latency, long* c2d_latency
);

//
// Instructions
//
// Construct and execute a Conv instruction without accuracy checking.
void test_conv1(
    int h2c_fd,
    void* csr_map_base, 
    int im_d2c_intr_fd, int xphm_d2c_intr_fd, int exec_intr_fd,
    uint32_t OC, uint32_t INC, uint32_t INH_, uint32_t INW_, 
    uint32_t KH, uint32_t KW, uint32_t strideH, uint32_t strideW, 
    uint32_t padL, uint32_t padR, uint32_t padU, uint32_t padD, int sta_mode,
    uint32_t M, uint32_t P, uint32_t Q, uint32_t R, uint32_t S,
    uint32_t* latency
);
// Construct and execute a Conv instruction with accuracy checking.
void test_conv2(
    int h2c_fd, int c2h_fd,
    void* csr_map_base, 
    int rtm_d2c_intr_fd, int rtm_c2d_intr_fd, 
    int cwm_d2c_intr_fd, int bm_d2c_intr_fd, 
    int im_d2c_intr_fd, int xphm_d2c_intr_fd, int exec_intr_fd,
    uint32_t OC, uint32_t INC, uint32_t INH_, uint32_t INW_, 
    uint32_t KH, uint32_t KW, uint32_t strideH, uint32_t strideW, 
    uint32_t padL, uint32_t padR, uint32_t padU, uint32_t padD, int sta_mode,
    uint32_t M, uint32_t P, uint32_t Q, uint32_t R, uint32_t S,
    uint32_t* latency,
    char* test_case_dir_path
);
// Construct and execute a MaxPool instruction without accuracy checking.
void test_maxp1(
    int h2c_fd,
    void* csr_map_base, 
    int im_d2c_intr_fd, int xphm_d2c_intr_fd, int exec_intr_fd,
    uint32_t OC, uint32_t INC, uint32_t INH_, uint32_t INW_, 
    uint32_t KH, uint32_t KW, uint32_t strideH, uint32_t strideW, 
    uint32_t padL, uint32_t padR, uint32_t padU, uint32_t padD,
    uint32_t M, uint32_t P, uint32_t Q, uint32_t R, uint32_t S,
    uint32_t* latency
);
// Construct and execute a MaxPool instruction with accuracy checking.
void test_maxp2(
    int h2c_fd, int c2h_fd,
    void* csr_map_base, 
    int rtm_d2c_intr_fd, int rtm_c2d_intr_fd, 
    int im_d2c_intr_fd, int xphm_d2c_intr_fd, int exec_intr_fd,
    uint32_t OC, uint32_t INC, uint32_t INH_, uint32_t INW_, 
    uint32_t KH, uint32_t KW, uint32_t strideH, uint32_t strideW, 
    uint32_t padL, uint32_t padR, uint32_t padU, uint32_t padD,
    uint32_t M, uint32_t P, uint32_t Q,
    uint32_t* latency,
    char* test_case_dir_path
);
// Construct and execute an AveragePool instruction without accuracy checking.
void test_avgp1(
    int h2c_fd,
    void* csr_map_base, 
    int im_d2c_intr_fd, int xphm_d2c_intr_fd, int exec_intr_fd,
    uint32_t OC, uint32_t INC, uint32_t INH_, uint32_t INW_, 
    uint32_t KH, uint32_t KW, uint32_t strideH, uint32_t strideW, 
    uint32_t padL, uint32_t padR, uint32_t padU, uint32_t padD,
    uint32_t M, uint32_t P, uint32_t Q, uint32_t R, uint32_t S,
    uint32_t* latency
);
// Construct and execute an AveragePool instruction with accuracy checking.
void test_avgp2(
    int h2c_fd, int c2h_fd,
    void* csr_map_base, 
    int rtm_d2c_intr_fd, int rtm_c2d_intr_fd, 
    int im_d2c_intr_fd, int xphm_d2c_intr_fd, int exec_intr_fd,
    uint32_t OC, uint32_t INC, uint32_t INH_, uint32_t INW_, 
    uint32_t KH, uint32_t KW, uint32_t strideH, uint32_t strideW, 
    uint32_t padL, uint32_t padR, uint32_t padU, uint32_t padD,
    uint32_t M, uint32_t P, uint32_t Q,
    uint32_t* latency,
    char* test_case_dir_path
);
// Construct and execute an Add instruction without accuracy checking.
void test_add1(
    int h2c_fd,
    void* csr_map_base, 
    int im_d2c_intr_fd, int exec_intr_fd,
    uint32_t vec_size, uint32_t* latency
);
// Construct and execute an Add instruction with accuracy checking.
void test_add2(
    int h2c_fd, int c2h_fd,
    void* csr_map_base, 
    int rtm_d2c_intr_fd, int rtm_c2d_intr_fd, 
    int im_d2c_intr_fd, int exec_intr_fd,
    uint32_t vec_size, uint32_t* latency,
    char* test_case_dir_path
);
// Construct and execute a Remap instruction without accuracy checking.
void test_remap1(
    int h2c_fd,
    void* csr_map_base, 
    int im_d2c_intr_fd, int exec_intr_fd,
    uint32_t vec_size, uint32_t* latency
);
// Construct and execute a Remap instruction with accuracy checking.
void test_remap2(
    int h2c_fd, int c2h_fd,
    void* csr_map_base, 
    int rtm_d2c_intr_fd, int rtm_c2d_intr_fd, 
    int im_d2c_intr_fd, int exec_intr_fd,
    uint32_t vec_size, uint32_t* latency,
    char* test_case_dir_path
);
// Construct and execute a Fc instruction without accuracy checking.
void test_fc1(
    int h2c_fd,
    void* csr_map_base,
    int im_d2c_intr_fd, int exec_intr_fd,
    uint32_t OC, uint32_t INC, int t_mode, uint32_t* latency
);
// Construct and execute a Fc instruction with accuracy checking.
void test_fc2(
    int h2c_fd, int c2h_fd, 
    void* csr_map_base,
    int rtm_d2c_intr_fd, int rtm_c2d_intr_fd, 
    int bm_d2c_intr_fd,
    int im_d2c_intr_fd, int exec_intr_fd,
    uint32_t OC, uint32_t INC, int t_mode, uint32_t* latency,
    char* test_case_dir_path
) ;
#endif // __TEST_H__
