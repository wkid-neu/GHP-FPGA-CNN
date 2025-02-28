`timescale 1ns / 1ps
`include "../../../incl.vh"

//
// This module generates the write-back descriptors.
//
module Pool_wb_desc_fifo_wr (
    input clk,
    input start_pulse,
    // Instruction
    input [$clog2(`RTM_DEPTH)-1:0] Y_addr,
    input [15:0] INC2_minus_1,
    input [15:0] n_X_rnd_minus_1,
    input [15:0] ofm_height,
    input [7:0] n_last_batch,
    // fifo write ports
    output reg fifo_wr_en = 0,
    output reg [$clog2(`RTM_DEPTH)-1:0] fifo_din_addr = 0,
    output reg fifo_din_mask = 0,
    output reg fifo_din_last = 0,
    input fifo_prog_full
);
    localparam N1 = `P/`R;
    reg counting = 0;
    // counters
    reg [$clog2(N1+1)-1:0] n1_cnt = 0;  // The ideal width is $clog2(N1), use $clog2(N1+1) to support N1=1 
    reg [15:0] inc_cnt = 0;
    reg [15:0] x_cnt = 0;
    // basic addresses
    reg [$clog2(`RTM_DEPTH)-1:0] chan_base = 0;
    reg [$clog2(`RTM_DEPTH)-1:0] fm_base = 0;
    // Compute the final address according to basic addresses and the n1_cnt.
    // final_addr = chan_base+fm_base+n1_cnt
    // Manage this process as pipeline to achieve better performance.
    // Pipeline stage1
    reg [$clog2(`RTM_DEPTH)-1:0] addr1 = 0;  // chan_base+fm_base
    reg [$clog2(N1+1)-1:0] n1_cnt1 = 0;  // n1_cnt
    reg last_x_rnd = 0;
    reg vld1 = 0, last1 = 0;
    // Pipeline stage2 (Output)

    // counting
    always @(posedge clk)
        if (start_pulse)
            counting <= 1;
        else if (counting && ~fifo_prog_full && n1_cnt==N1-1 && inc_cnt==INC2_minus_1 && x_cnt==n_X_rnd_minus_1)
            counting <= 0;

    // n1_cnt
    always @(posedge clk)
        if (counting && ~fifo_prog_full) begin
            if (n1_cnt==N1-1)
                n1_cnt <= 0;
            else
                n1_cnt <= n1_cnt+1;
        end

    // inc_cnt
    always @(posedge clk)
        if (counting && ~fifo_prog_full && n1_cnt==N1-1) begin
            if (inc_cnt==INC2_minus_1)
                inc_cnt <= 0;
            else
                inc_cnt <= inc_cnt+1;
        end

    // x_cnt
    always @(posedge clk)
        if (start_pulse)
            x_cnt <= 0;
        else if (counting && ~fifo_prog_full && n1_cnt==N1-1 && inc_cnt==INC2_minus_1)
            x_cnt <= x_cnt+1;

    // chan_base
    always @(posedge clk)
        if (start_pulse) begin
            chan_base <= Y_addr;
        end else if (counting && ~fifo_prog_full && n1_cnt==N1-1) begin
            if (inc_cnt==INC2_minus_1)
                chan_base <= Y_addr;
            else
                chan_base <= chan_base+ofm_height;
        end

    // fm_base
    always @(posedge clk)
        if (start_pulse)
            fm_base <= 0;
        else if (counting && ~fifo_prog_full && n1_cnt==N1-1 && inc_cnt==INC2_minus_1)
            fm_base <= fm_base+N1;

    // Pipeline stage1
    always @(posedge clk) begin
        addr1 <= chan_base+fm_base;
        n1_cnt1 <= n1_cnt;
        last_x_rnd <= (counting && ~fifo_prog_full && x_cnt==n_X_rnd_minus_1);
        vld1 <= (counting && ~fifo_prog_full);
        last1 <= (counting && ~fifo_prog_full && n1_cnt==N1-1 && inc_cnt==INC2_minus_1 && x_cnt==n_X_rnd_minus_1);
    end

    // Pipeline stage2 (output)
    always @(posedge clk) begin
        fifo_wr_en <= vld1;
        fifo_din_addr <= addr1+n1_cnt1;
        fifo_din_mask <= (last_x_rnd && n1_cnt1>=n_last_batch);
        fifo_din_last <= last1;
    end
endmodule
