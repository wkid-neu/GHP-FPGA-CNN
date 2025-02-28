`timescale 1ns / 1ps

`include "../incl.vh"

//
// XDMA interrupt
//
module xdma_usr_irq (
    input clk,
    input sys_rst,
    // Interruption requests
    input im_d2c_done_pulse,
    input rtm_d2c_done_pulse,
    input rtm_c2d_done_pulse,
    input xphm_d2c_done_pulse,
    input cwm_d2c_done_pulse,
    input bm_d2c_done_pulse,
    input exec_done_pulse,
    // Host, clear interrupt
    input [`XDMA_USR_INTR_COUNT-1:0] intr_clr,
    input [`XDMA_USR_INTR_COUNT-1:0] intr_clr_vld,
    // Output register
    output reg [`XDMA_USR_INTR_COUNT-1:0] xdma_usr_irq_req = 0
);
    // Interruption of transferring instructions from DRAM to IM
    always @(posedge clk)
        if (sys_rst)
            xdma_usr_irq_req[0] <= 0;
        else if (~xdma_usr_irq_req[0] && im_d2c_done_pulse)
            xdma_usr_irq_req[0] <= 1;
        else if (xdma_usr_irq_req[0] && intr_clr[0] && intr_clr_vld[0])
            xdma_usr_irq_req[0] <= 0;

    // Interruption of transferring data from DRAM to RTM
    always @(posedge clk) 
        if (sys_rst)
            xdma_usr_irq_req[1] <= 0;
        else if (~xdma_usr_irq_req[1] && rtm_d2c_done_pulse)
            xdma_usr_irq_req[1] <= 1;
        else if (xdma_usr_irq_req[1] && intr_clr[1] && intr_clr_vld[1])
            xdma_usr_irq_req[1] <= 0;

    // Interruption of transferring data from RTM to DRAM
    always @(posedge clk)
        if (sys_rst)
            xdma_usr_irq_req[2] <= 0;
        else if (~xdma_usr_irq_req[2] && rtm_c2d_done_pulse)
            xdma_usr_irq_req[2] <= 1;
        else if (xdma_usr_irq_req[2] && intr_clr[2] && intr_clr_vld[2])
            xdma_usr_irq_req[2] <= 0;

    // Interruption of transferring data from DRAM to XPHM
    always @(posedge clk)
        if (sys_rst)
            xdma_usr_irq_req[3] <= 0;
        else if (~xdma_usr_irq_req[3] && xphm_d2c_done_pulse)
            xdma_usr_irq_req[3] <= 1;
        else if (xdma_usr_irq_req[3] && intr_clr[3] && intr_clr_vld[3])
            xdma_usr_irq_req[3] <= 0;

    // Interrupt of transferring weights from DRAM to CWM
    always @(posedge clk)
        if (sys_rst)
            xdma_usr_irq_req[4] <= 0;
        else if (~xdma_usr_irq_req[4] && cwm_d2c_done_pulse)
            xdma_usr_irq_req[4] <= 1;
        else if (xdma_usr_irq_req[4] && intr_clr[4] && intr_clr_vld[4])
            xdma_usr_irq_req[4] <= 0;
    
    // Interrupt of transferring bias from DRAM to BM
    always @(posedge clk)
        if (sys_rst)
            xdma_usr_irq_req[5] <= 0;
        else if (~xdma_usr_irq_req[5] && bm_d2c_done_pulse)
            xdma_usr_irq_req[5] <= 1;
        else if (xdma_usr_irq_req[5] && intr_clr[5] && intr_clr_vld[5])
            xdma_usr_irq_req[5] <= 0;
    
    // Interrupt of inferring
    always @(posedge clk)
        if (sys_rst)
            xdma_usr_irq_req[6] <= 0;
        else if (~xdma_usr_irq_req[6] && exec_done_pulse)
            xdma_usr_irq_req[6] <= 1;
        else if (xdma_usr_irq_req[6] && intr_clr[6] && intr_clr_vld[6])
            xdma_usr_irq_req[6] <= 0;
endmodule
