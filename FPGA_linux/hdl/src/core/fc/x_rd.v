`timescale 1ns / 1ps
`include "../../incl.vh"

//
// Read X from RTM and write into X FIFO
// Two modes:
// (1) S channels in one RTM entry (T-mode)
// (2) S*R channels in one RTM entry (V-mode)
//
module Fc_x_rd (
    input clk,
    input start_pulse,
    // instruction
    input [$clog2(`RTM_DEPTH)-1:0] x_addr,
    input [15:0] vec_size_minus_1,
    input [15:0] n_rnd_minus_1,
    input [7:0] xz,
    input x_mode,
    // RTM read ports
    output reg rtm_rd_vld = 0,
    output reg [`S-1:0] rtm_rd_en = 0,
    output reg rtm_rd_vec_begin = 0,
    output reg rtm_rd_vec_end = 0,
    output reg rtm_rd_last = 0,
    output reg [`S*$clog2(`RTM_DEPTH)-1:0] rtm_rd_addr = 0,
    input [`S*`R*8-1:0] rtm_dout,
    input rtm_dout_vld,
    input rtm_dout_vec_begin,
    input rtm_dout_vec_end,
    input rtm_dout_last,
    // X FIFO
    output reg x_fifo_wr_en = 0,
    output reg [8:0] x_fifo_din = 0,
    output reg x_fifo_din_vec_begin = 0,
    output reg x_fifo_din_vec_end = 0,
    output reg x_fifo_din_last = 0,
    input x_fifo_prog_full
);
    reg rd = 0;
    reg [15:0] ele_cnt = 0, ele_cnt_plus_1 = 1;
    reg [15:0] rnd_cnt = 0;
    reg [$clog2(`RTM_DEPTH)-1:0] next_addr = 0;
    // post processing
    reg post_vld = 0, post_vec_begin = 0, post_vec_end = 0, post_last = 0;
    reg [8:0] post_val = 0;
    reg [$clog2(`S*`R)-1:0] ele_idx = 0;
    reg [15:0] fifo_wr_ele_cnt = 0;
    integer i;

    // rd
    always @(posedge clk)
        if (start_pulse)
            rd <= 1;
        else if (rd && ~x_fifo_prog_full && ele_cnt==vec_size_minus_1 && rnd_cnt==n_rnd_minus_1)
            rd <= 0;

    // ele_cnt
    always @(posedge clk)
        if (rd && ~x_fifo_prog_full) begin
            if (ele_cnt==vec_size_minus_1)
                ele_cnt <= 0;
            else
                ele_cnt <= ele_cnt+1;
        end

    // ele_cnt_plus_1
    always @(posedge clk)
        if (rd && ~x_fifo_prog_full) begin
            if (ele_cnt==vec_size_minus_1)
                ele_cnt_plus_1 <= 1;
            else
                ele_cnt_plus_1 <= ele_cnt_plus_1+1;
        end

    // rnd_cnt
    always @(posedge clk)
        if (start_pulse)
            rnd_cnt <= 0;
        else if (rd && ~x_fifo_prog_full && ele_cnt==vec_size_minus_1)
            rnd_cnt <= rnd_cnt+1;

    // next_addr
    always @(posedge clk)
        if (start_pulse)
            next_addr <= x_addr;
        else if (rd && ~x_fifo_prog_full) begin
            if (ele_cnt==vec_size_minus_1)
                next_addr <= x_addr;
            else
                case (x_mode)
                    1'b0: begin
                        if (ele_cnt_plus_1[$clog2(`S)-1:0]=={{$clog2(`S)}{1'b0}})
                            next_addr <= next_addr+1;
                    end
                    1'b1: begin
                        if (ele_cnt_plus_1[$clog2(`S*`R)-1:0]=={{$clog2(`S*`R)}{1'b0}})
                            next_addr <= next_addr+1;
                    end
                endcase
        end

    // rtm_rd_vld, rtm_rd_en, rtm_rd_addr, rtm_rd_vec_begin, rtm_rd_vec_end, rtm_rd_last
    always @(posedge clk) begin
        rtm_rd_vld <= (rd && ~x_fifo_prog_full);
        for (i=0; i<`S; i=i+1)
            rtm_rd_en[i] <= (rd && ~x_fifo_prog_full);
        for (i=0; i<`S; i=i+1)
            rtm_rd_addr[i*$clog2(`RTM_DEPTH)+:$clog2(`RTM_DEPTH)] <= next_addr;
        rtm_rd_vec_begin <= (rd && ~x_fifo_prog_full && ele_cnt==0);
        rtm_rd_vec_end <= (rd && ~x_fifo_prog_full && ele_cnt==vec_size_minus_1);
        rtm_rd_last <= (rd && ~x_fifo_prog_full && ele_cnt==vec_size_minus_1 && rnd_cnt==n_rnd_minus_1);
    end

    // fifo_wr_ele_cnt
    always @(posedge clk)
        if (start_pulse)
            fifo_wr_ele_cnt <= 0;
        else if (rtm_dout_vld) begin
            if (fifo_wr_ele_cnt==vec_size_minus_1)
                fifo_wr_ele_cnt <= 0;
            else
                fifo_wr_ele_cnt <= fifo_wr_ele_cnt+1;
        end

    // ele_idx
    always @(posedge clk)
        if (start_pulse)
            ele_idx <= 0;
        else if (rtm_dout_vld) begin
            if (fifo_wr_ele_cnt==vec_size_minus_1)
                ele_idx <= 0;
            else
                case (x_mode)
                    1'b0: ele_idx <= ele_idx+`R;
                    1'b1: ele_idx <= ele_idx+1;
                endcase
        end

    // post_vld, post_vec_begin, post_vec_end, post_last, post_val
    always @(posedge clk) begin
        post_vld <= rtm_dout_vld;
        post_vec_begin <= rtm_dout_vec_begin;
        post_vec_end <= rtm_dout_vec_end;
        post_last <= rtm_dout_last;
        post_val <= $signed({1'b0, rtm_dout[ele_idx*8+:8]});
    end

    // x_fifo_wr_en, x_fifo_din, x_fifo_din_vec_begin, x_fifo_din_vec_end, x_fifo_din_last
    always @(posedge clk) begin
        x_fifo_wr_en <= post_vld;
        x_fifo_din <= post_val-$signed({1'b0,xz});
        x_fifo_din_vec_begin <= post_vec_begin;
        x_fifo_din_vec_end <= post_vec_end;
        x_fifo_din_last <= post_last;
    end
endmodule
