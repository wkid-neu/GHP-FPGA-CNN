#if !defined(__UTILS_H__)
#define __UTILS_H__

#include <stdint.h>

// Read .hex file into memory.
void rd_hex_file(char* fp, void* dst_buf);
// Get file size.
long get_file_size(char* fp);

// Conv output shape
void conv_get_ofm_shape(
    uint32_t INH_, uint32_t INW_, 
    uint32_t KH, uint32_t KW, uint32_t strideH, uint32_t strideW, 
    uint32_t padL, uint32_t padR, uint32_t padU, uint32_t padD,
    uint32_t* OH, uint32_t* OW
);

// Compute the number of operations based on Conv shape parameters
float conv_get_n_op(
    uint32_t OC, uint32_t INC,
    uint32_t INH_, uint32_t INW_, 
    uint32_t KH, uint32_t KW, uint32_t strideH, uint32_t strideW, 
    uint32_t padL, uint32_t padR, uint32_t padU, uint32_t padD
);

float get_ideal_throughput(uint32_t M, uint32_t P, float sa_clk);
float get_throughput_gops(float n_op, uint32_t n_cycle, float main_clk);

/* Compute memory speed. (MB/s) */
float get_mem_speed_MBPS(long latency_ns, uint32_t size) ;
/* Compute memory speed. (GB/s) */
float get_mem_speed_GBPS(long latency_ns, uint32_t size) ;

void timespec_sub(struct timespec *t1, struct timespec *t2);

void rd_tensor(char* fp, uint32_t len, float* buf);

// Check data in two buffers
void check_buf(void* src, void* dst, uint32_t size, uint32_t* match, uint32_t* mismatch);

#endif // __UTILS_H__
