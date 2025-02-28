#if !defined(__HW_H__)
#define __HW_H__

#include <stdint.h>

//
// Devices
//
#define DEVICE_CSR "/dev/xdma0_user"
#define DEVICE_INTR_IM_D2C "/dev/xdma0_events_0"
#define DEVICE_INTR_RTM_D2C "/dev/xdma0_events_1"
#define DEVICE_INTR_RTM_C2D "/dev/xdma0_events_2"
#define DEVICE_INTR_XPHM_D2C "/dev/xdma0_events_3"
#define DEVICE_INTR_CWM_D2C "/dev/xdma0_events_4"
#define DEVICE_INTR_BM_D2C "/dev/xdma0_events_5"
#define DEVICE_INTR_EXEC "/dev/xdma0_events_6"
#define DEVICE_H2C "/dev/xdma0_h2c_0"
#define DEVICE_C2H "/dev/xdma0_c2h_0"

//
// Control and Status registers
//
/* IM, DRAM -> Chip */
#define CSR_IM_D2C 60
#define CSR_IM_D2C_DRAM_ADDR 59
#define CSR_IM_D2C_N_BYTES 58
/* RTM, DRAM -> Chip */
#define CSR_RTM_D2C 50
#define CSR_RTM_D2C_DRAM_ADDR 49
#define CSR_RTM_D2C_RTM_ADDR 48
#define CSR_RTM_D2C_N_BYTES 47
/* RTM, Chip -> DRAM */
#define CSR_RTM_C2D 46
#define CSR_RTM_C2D_DRAM_ADDR 45
#define CSR_RTM_C2D_RTM_ADDR 44
#define CSR_RTM_C2D_N_BYTES 43
/* XPHM, DRAM -> Chip */
#define CSR_XPHM_D2C 40
#define CSR_XPHM_D2C_DRAM_ADDR 39
#define CSR_XPHM_D2C_RTM_ADDR 38
#define CSR_XPHM_D2C_N_BYTES 37
/* CWM, DRAM -> Chip */
#define CSR_CWM_D2C 30
#define CSR_CWM_D2C_DRAM_ADDR 29
#define CSR_CWM_D2C_RTM_ADDR 28
#define CSR_CWM_D2C_N_BYTES 27
/* BM, DRAM -> Chip */
#define CSR_BM_D2C 20
#define CSR_BM_D2C_DRAM_ADDR 19
#define CSR_BM_D2C_RTM_ADDR 18
#define CSR_BM_D2C_N_BYTES 17
/* Executor */
#define CSR_EXEC 10
#define CSR_EXEC_LATENCY_CONV 9
#define CSR_EXEC_LATENCY_POOL 8
#define CSR_EXEC_LATENCY_ADD 7
#define CSR_EXEC_LATENCY_REMAP 6
#define CSR_EXEC_LATENCY_FC 5
/* Interruptions */
#define CSR_INTR_IDX_IM_D2C 0
#define CSR_INTR_IDX_RTM_D2C 1
#define CSR_INTR_IDX_RTM_C2D 2
#define CSR_INTR_IDX_XPHM_D2C 3
#define CSR_INTR_IDX_CWM_D2C 4
#define CSR_INTR_IDX_BM_D2C 5
#define CSR_INTR_IDX_EXEC 6

#define MAIN_CLK 250000000
#define SA_CLK 398437500
#define LATENCY_NS(n_cycles) ((uint32_t)((1000000000*1.0/MAIN_CLK)*(n_cycles)))

//
// Registers
//
// Write control register
void reg_wr(void* map_base, uint32_t reg, uint32_t reg_val);
// Read status register
void reg_rd(void* map_base, uint32_t reg, uint32_t* reg_val);

//
// DRAM
//
// Write data into DRAM
void dram_wr(int h2c_fd, void* buf, uint32_t addr, uint32_t size);
// Read data from DRAM
void dram_rd(int c2h_fd, void* buf, uint32_t addr, uint32_t size);

//
// Memory
//
// Move data from DRAM to RTM
void rtm_d2c(uint32_t dram_addr, uint32_t rtm_addr, uint32_t n_bytes, void* csr_map_base, int intr_fd);
// Move data from RTM to DRAM
void rtm_c2d(uint32_t dram_addr, uint32_t rtm_addr, uint32_t n_bytes, void* csr_map_base, int intr_fd);
// Move data from DRAM to CWM
void cwm_d2c(uint32_t dram_addr, uint32_t cwm_addr, uint32_t n_bytes, void* csr_map_base, int intr_fd);
// Move data from DRAM to IM
void im_d2c(uint32_t dram_addr, uint32_t n_bytes, void* csr_map_base, int intr_fd);
// Move data from DRAM to XPHM
void xphm_d2c(uint32_t dram_addr, uint32_t xphm_addr, uint32_t n_bytes, void* csr_map_base, int intr_fd);
// Move data from DRAM to BM
void bm_d2c(uint32_t dram_addr, uint32_t bm_addr, uint32_t n_bytes, void* csr_map_base, int intr_fd);

//
// Executor
//
// Execute instructions.
void exec(void* csr_map_base, int intr_fd);

//
// XDMA
//
// Open axi4-lite device
void* csr_mmap(int fd);

//
// Helper functions
//
// Align tensor so that it can be stored in RTM
void rtm_tensor_align(uint32_t S, uint32_t R, uint32_t INC, uint32_t INH_, uint32_t INW_, void* src, void* dst);

#endif // __HW_H__
