`timescale 1ns / 1ps
`include "../../incl.vh"

//
// This module reads bias from BM and write them into the Bias FIFO
//
module Conv_bias_fifo_wr(
    input clk,
    // instruction
    input start_pulse,
    input [$clog2(`BM_DEPTH)-1:0] B_addr,
    input [15:0] n_X_rnd_minus_1,
    input [15:0] n_W_rnd_minus_1,
    // BM Read ports
    output reg bm_rd_en = 0,
    output reg [$clog2(`BM_DEPTH)-1:0] bm_rd_addr = 0,
    input [`BM_DATA_WIDTH-1:0] bm_dout,
    input bm_dout_vld,
    // Bias fifo write ports
    output reg fifo_wr_en = 0,
    output reg [63:0] fifo_din = 0,
    input fifo_prog_full
);
    //
    // Read bias from BM
    //
    localparam N = `BM_DATA_WIDTH/64;

    reg rd = 0;
    reg [15:0] x_cnt = 0;
    reg [15:0] w_cnt = 0;
    reg [$clog2(`M)-1:0] m_cnt = 0;
    reg [$clog2(`M):0] m_cnt_plus_1 = 1;
    reg [$clog2(`BM_DEPTH)-1:0] next_bm_addr = 0;

    // rd
    always @(posedge clk)
        if (start_pulse)
            rd <= 1;
        else if (rd && ~fifo_prog_full && x_cnt==n_X_rnd_minus_1 && w_cnt==n_W_rnd_minus_1 && m_cnt==`M-1)
            rd <= 0;

    // m_cnt
    always @(posedge clk)
        if (rd && ~fifo_prog_full) begin
            if (m_cnt==`M-1)
                m_cnt <= 0;
            else
                m_cnt <= m_cnt+1;
        end

    // m_cnt_plus_1
    always @(posedge clk)
        if (rd && ~fifo_prog_full) begin
            if (m_cnt_plus_1==`M)
                m_cnt_plus_1 <= 1;
            else
                m_cnt_plus_1 <= m_cnt_plus_1+1;
        end

    // w_cnt
    always @(posedge clk)
        if (rd && ~fifo_prog_full && m_cnt==`M-1) begin
            if (w_cnt==n_W_rnd_minus_1)
                w_cnt <= 0;
            else
                w_cnt <= w_cnt+1;
        end

    // x_cnt
    always @(posedge clk)
        if (start_pulse)
            x_cnt <= 0;
        else if (rd && ~fifo_prog_full && m_cnt==`M-1 && w_cnt==n_W_rnd_minus_1)
            x_cnt <= x_cnt+1;

    // next_bm_addr
    always @(posedge clk)
        if (start_pulse) 
            next_bm_addr <= B_addr;
        else if (rd && ~fifo_prog_full) begin
            if (w_cnt==n_W_rnd_minus_1 && m_cnt==`M-1)
                next_bm_addr <= B_addr;
            else if (m_cnt_plus_1[$clog2(N)-1:0]==0)
                next_bm_addr <= next_bm_addr+1;
        end

    // bm_rd_en, bm_rd_addr
    always @(posedge clk) begin
        bm_rd_en <= (rd && ~fifo_prog_full);
        bm_rd_addr <= next_bm_addr;
    end

    // 
    // Write bias into Bias FIFO
    //
    reg [$clog2(N)-1:0] wr_idx = 0;

    // wr_idx
    always @(posedge clk)
        if (start_pulse)
            wr_idx <= 0;
        else if (bm_dout_vld)
            wr_idx <= wr_idx+1;

    // fifo_wr_en, fifo_din
    always @(posedge clk) begin
        fifo_wr_en <= bm_dout_vld;
        fifo_din <= bm_dout[wr_idx*64+:64];
    end
endmodule
