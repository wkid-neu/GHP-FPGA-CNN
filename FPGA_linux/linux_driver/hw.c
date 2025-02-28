#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <assert.h>
#include <unistd.h>
#include <time.h>
#include <math.h>

#include "hw.h"
#include "base.h"
#include "utils.h"

inline void reg_wr(void* map_base, uint32_t reg, uint32_t reg_val) {
    *(((volatile uint32_t*)map_base) + reg) = reg_val;
}

inline void reg_rd(void* map_base, uint32_t reg, uint32_t* reg_val) {
    *reg_val = *(((volatile uint32_t*)map_base) + reg);
}

void dram_wr(int h2c_fd, void* buf, uint32_t addr, uint32_t size) {
    lseek(h2c_fd, addr, SEEK_SET);
    int rc = write(h2c_fd, buf, size);
    assert(rc == size);
}

void dram_rd(int c2h_fd, void* buf, uint32_t addr, uint32_t size) {
	lseek(c2h_fd, addr, SEEK_SET);
	int rc = read(c2h_fd, buf, size);
	assert(rc == size);
}

void rtm_d2c(uint32_t dram_addr, uint32_t rtm_addr, uint32_t n_bytes, void* csr_map_base, int intr_fd) {
    /* Control registers */
    reg_wr(csr_map_base, CSR_RTM_D2C_DRAM_ADDR, dram_addr);
    reg_wr(csr_map_base, CSR_RTM_D2C_RTM_ADDR, rtm_addr);
    reg_wr(csr_map_base, CSR_RTM_D2C_N_BYTES, n_bytes);
    /* Start moving */
    reg_wr(csr_map_base, CSR_RTM_D2C, 0x00000000);
    reg_wr(csr_map_base, CSR_RTM_D2C, 0x00000001);
    /* Wait for the interruption */
    int intr_val;
    read(intr_fd, &intr_val, 4);
    /* Clear the interruption */
    reg_wr(csr_map_base, 0, ((0x0001<<CSR_INTR_IDX_RTM_D2C)<<16)+(0x0001<<CSR_INTR_IDX_RTM_D2C));
    reg_wr(csr_map_base, 0, 0x00000000);
}

void rtm_c2d(uint32_t dram_addr, uint32_t rtm_addr, uint32_t n_bytes, void* csr_map_base, int intr_fd) {
    /* Control registers */
    reg_wr(csr_map_base, CSR_RTM_C2D_DRAM_ADDR, dram_addr);
    reg_wr(csr_map_base, CSR_RTM_C2D_RTM_ADDR, rtm_addr);
    reg_wr(csr_map_base, CSR_RTM_C2D_N_BYTES, n_bytes);
    /* Start moving */
    reg_wr(csr_map_base, CSR_RTM_C2D, 0x00000000);
    reg_wr(csr_map_base, CSR_RTM_C2D, 0x00000001);
    /* Wait for the interruption */
    int intr_val;
    read(intr_fd, &intr_val, 4);
    /* Clear the interruption */
    reg_wr(csr_map_base, 0, ((0x0001<<CSR_INTR_IDX_RTM_C2D)<<16)+(0x0001<<CSR_INTR_IDX_RTM_C2D));
    reg_wr(csr_map_base, 0, 0x00000000);
}

void cwm_d2c(uint32_t dram_addr, uint32_t cwm_addr, uint32_t n_bytes, void* csr_map_base, int intr_fd) {
    /* Control registers */
    reg_wr(csr_map_base, CSR_CWM_D2C_DRAM_ADDR, dram_addr);
    reg_wr(csr_map_base, CSR_CWM_D2C_RTM_ADDR, cwm_addr);
    reg_wr(csr_map_base, CSR_CWM_D2C_N_BYTES, n_bytes);
    /* Start moving */
    reg_wr(csr_map_base, CSR_CWM_D2C, 0x00000000);
    reg_wr(csr_map_base, CSR_CWM_D2C, 0x00000001);
    /* Wait for the interruption */
    int intr_val;
    read(intr_fd, &intr_val, 4);
    /* Clear the interruption */
    reg_wr(csr_map_base, 0, ((0x0001<<CSR_INTR_IDX_CWM_D2C)<<16)+(0x0001<<CSR_INTR_IDX_CWM_D2C));
    reg_wr(csr_map_base, 0, 0x00000000);
}

void im_d2c(uint32_t dram_addr, uint32_t n_bytes, void* csr_map_base, int intr_fd) {
    /* Control registers */
    reg_wr(csr_map_base, CSR_IM_D2C_DRAM_ADDR, dram_addr);
    reg_wr(csr_map_base, CSR_IM_D2C_N_BYTES, n_bytes);
    /* Start moving */
    reg_wr(csr_map_base, CSR_IM_D2C, 0x00000000);
    reg_wr(csr_map_base, CSR_IM_D2C, 0x00000001);
    /* Wait for the interruption */
    int intr_val;
    read(intr_fd, &intr_val, 4);
    /* Clear the interruption */
    reg_wr(csr_map_base, 0, ((0x0001<<CSR_INTR_IDX_IM_D2C)<<16)+(0x0001<<CSR_INTR_IDX_IM_D2C));
    reg_wr(csr_map_base, 0, 0x00000000);
}

void xphm_d2c(uint32_t dram_addr, uint32_t xphm_addr, uint32_t n_bytes, void* csr_map_base, int intr_fd) {
    /* Control registers */
    reg_wr(csr_map_base, CSR_XPHM_D2C_DRAM_ADDR, dram_addr);
    reg_wr(csr_map_base, CSR_XPHM_D2C_RTM_ADDR, xphm_addr);
    reg_wr(csr_map_base, CSR_XPHM_D2C_N_BYTES, n_bytes);
    /* Start moving */
    reg_wr(csr_map_base, CSR_XPHM_D2C, 0x00000000);
    reg_wr(csr_map_base, CSR_XPHM_D2C, 0x00000001);
    /* Wait for the interruption */
    int intr_val;
    read(intr_fd, &intr_val, 4);
    /* Clear the interruption */
    reg_wr(csr_map_base, 0, ((0x0001<<CSR_INTR_IDX_XPHM_D2C)<<16)+(0x0001<<CSR_INTR_IDX_XPHM_D2C));
    reg_wr(csr_map_base, 0, 0x00000000);
}

void bm_d2c(uint32_t dram_addr, uint32_t bm_addr, uint32_t n_bytes, void* csr_map_base, int intr_fd) {
    /* Control registers */
    reg_wr(csr_map_base, CSR_BM_D2C_DRAM_ADDR, dram_addr);
    reg_wr(csr_map_base, CSR_BM_D2C_RTM_ADDR, bm_addr);
    reg_wr(csr_map_base, CSR_BM_D2C_N_BYTES, n_bytes);
    /* Start moving */
    reg_wr(csr_map_base, CSR_BM_D2C, 0x00000000);
    reg_wr(csr_map_base, CSR_BM_D2C, 0x00000001);
    /* Wait for the interruption */
    int intr_val;
    read(intr_fd, &intr_val, 4);
    /* Clear the interruption */
    reg_wr(csr_map_base, 0, ((0x0001<<CSR_INTR_IDX_BM_D2C)<<16)+(0x0001<<CSR_INTR_IDX_BM_D2C));
    reg_wr(csr_map_base, 0, 0x00000000);
}

void exec(void* csr_map_base, int intr_fd) {
    /* Start execution */
    reg_wr(csr_map_base, CSR_EXEC, 0x00000000);
    reg_wr(csr_map_base, CSR_EXEC, 0x00000001);
    /* Wait for the interruption */
    int intr_val;
    read(intr_fd, &intr_val, 4);
    /* Clear the interruption */
    reg_wr(csr_map_base, 0, ((0x0001<<CSR_INTR_IDX_EXEC)<<16)+(0x0001<<CSR_INTR_IDX_EXEC));
    reg_wr(csr_map_base, 0, 0x00000000);
}

void* csr_mmap(int fd) {
    void* ret;
    ret = mmap(NULL, 1024*1024, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (ret == (void *)-1) exit(-1);
    return (void *)((uint64_t)ret);
}

void rtm_tensor_align(uint32_t S, uint32_t R, uint32_t INC, uint32_t INH_, uint32_t INW_, void* src, void* dst) {
    uint32_t ifm_size = INH_*INW_;
    uint32_t ifm_height = ((uint32_t)ceil(ifm_size*1.0/R));

    uint32_t dst_offset = 0;
    uint32_t src_offset = 0;
    for (uint32_t inc=0; inc<INC; inc++) {
        for (uint32_t h=0; h<ifm_height; h++) {
            for (uint32_t i=0; i<R; i++) {
                dst_offset = (inc/S*ifm_height+h)*S*R + (inc%S*R+i);
                if (h*R+i<ifm_size) {
                    src_offset = inc*ifm_size + h*R+i;
                    *(((uint8_t*)dst)+dst_offset) = *(((uint8_t*)src)+src_offset);
                } else {
                    *(((uint8_t*)dst)+dst_offset) = 0;
                }
            }
        }
    }
}