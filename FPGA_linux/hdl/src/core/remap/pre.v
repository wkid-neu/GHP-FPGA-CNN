`timescale 1ns / 1ps
`include "../../incl.vh"

//
// Prepare inputs for ppus
//
module Remap_pre (
    input clk,
    // instruction
    input start_pulse,
    input [$clog2(`RTM_DEPTH)-1:0] X_addr,
    input [$clog2(`RTM_DEPTH)-1:0] len_minus_1,
    input [25:0] m1,
    input [5:0] n1,
    input signed [8:0] neg_Xz,
    input [7:0] Yz,
    // RTM read ports
    output reg rtm_rd_vld = 0,
    output reg rtm_rd_last = 0,
    output reg [`S-1:0] rtm_rd_en = 0,
    output reg [`S*$clog2(`RTM_DEPTH)-1:0] rtm_rd_addr = 0,
    input [`S*`R*8-1:0] rtm_dout,
    input rtm_dout_vld,
    input rtm_dout_last,
    // ppus inputs
    output [`S*`R*8-1:0] ppus_Xs,
    output ppus_Xs_vld,
    output ppus_Xs_last,
    output signed [8:0] ppus_neg_Xz,
    output [7:0] ppus_Yz,
    output [25:0] ppus_m1,
    output [5:0] ppus_n1
);
    reg [`S*`R*8-1:0] ppus_Xs_reg = 0;
    reg ppus_Xs_vld_reg = 0;
    reg ppus_Xs_last_reg = 0;
    integer i;

    //
    // Read items from RTM
    //
    reg rd = 0;
    reg [$clog2(`RTM_DEPTH)-1:0] cnt = 0;
    reg [$clog2(`RTM_DEPTH)-1:0] next_addr = 0;

    // rd
    always @(posedge clk)
        if (start_pulse)
            rd <= 1;
        else if (rd && cnt==len_minus_1)
            rd <= 0;

    // cnt
    always @(posedge clk)
        if (start_pulse)
            cnt <= 0;
        else if (rd)
            cnt <= cnt+1;

    // next_addr
    always @(posedge clk)
        if (start_pulse)
            next_addr <= X_addr;
        else if (rd)
            next_addr <= next_addr+1;

    // rtm_rd_vld, rtm_rd_last, rtm_rd_en, rtm_rd_addr
    always @(posedge clk) begin
        rtm_rd_vld <= rd;
        rtm_rd_last <= rd && cnt==len_minus_1;
        for (i=0; i<`S; i=i+1) begin
            rtm_rd_en[i] <= rd;
            rtm_rd_addr[i*$clog2(`RTM_DEPTH)+:$clog2(`RTM_DEPTH)] <= next_addr;
        end
    end

    //
    // Send RTM outputs to ppus
    //
    always @(posedge clk) begin
        ppus_Xs_reg <= rtm_dout;
        ppus_Xs_vld_reg <= rtm_dout_vld;
        ppus_Xs_last_reg <= rtm_dout_last;
    end

`ifdef M32P64Q16R16S8
    // Add additional pipeline stages for high performance
    shift_reg #(1, `S*`R*8) shift_reg_ppus_Xs(clk, ppus_Xs_reg, ppus_Xs);
    shift_reg #(1, 1) shift_reg_ppus_Xs_vld(clk, ppus_Xs_vld_reg, ppus_Xs_vld);
    shift_reg #(1, 1) shift_reg_ppus_Xs_last(clk, ppus_Xs_last_reg, ppus_Xs_last);
`elsif M32P96Q16R16S8
    // Add additional pipeline stages for high performance
    shift_reg #(1, `S*`R*8) shift_reg_ppus_Xs(clk, ppus_Xs_reg, ppus_Xs);
    shift_reg #(1, 1) shift_reg_ppus_Xs_vld(clk, ppus_Xs_vld_reg, ppus_Xs_vld);
    shift_reg #(1, 1) shift_reg_ppus_Xs_last(clk, ppus_Xs_last_reg, ppus_Xs_last);
`elsif M64P64Q16R16S8
    // Add additional pipeline stages for high performance
    shift_reg #(1, `S*`R*8) shift_reg_ppus_Xs(clk, ppus_Xs_reg, ppus_Xs);
    shift_reg #(1, 1) shift_reg_ppus_Xs_vld(clk, ppus_Xs_vld_reg, ppus_Xs_vld);
    shift_reg #(1, 1) shift_reg_ppus_Xs_last(clk, ppus_Xs_last_reg, ppus_Xs_last);
`else
    assign ppus_Xs = ppus_Xs_reg;
    assign ppus_Xs_vld = ppus_Xs_vld_reg;
    assign ppus_Xs_last = ppus_Xs_last_reg;
`endif

`ifdef M32P64Q16R16S8
    shift_reg #(2, 9) shift_reg_ppus_neg_Xz(clk, neg_Xz, ppus_neg_Xz);
    shift_reg #(2, 8) shift_reg_ppus_Yz(clk, Yz, ppus_Yz);
    shift_reg #(2, 26) shift_reg_ppus_m1(clk, m1, ppus_m1);
    shift_reg #(2, 6) shift_reg_ppus_n1(clk, n1, ppus_n1);
`elsif M32P96Q16R16S8
    shift_reg #(2, 9) shift_reg_ppus_neg_Xz(clk, neg_Xz, ppus_neg_Xz);
    shift_reg #(2, 8) shift_reg_ppus_Yz(clk, Yz, ppus_Yz);
    shift_reg #(2, 26) shift_reg_ppus_m1(clk, m1, ppus_m1);
    shift_reg #(2, 6) shift_reg_ppus_n1(clk, n1, ppus_n1);
`elsif M64P64Q16R16S8
    shift_reg #(2, 9) shift_reg_ppus_neg_Xz(clk, neg_Xz, ppus_neg_Xz);
    shift_reg #(2, 8) shift_reg_ppus_Yz(clk, Yz, ppus_Yz);
    shift_reg #(2, 26) shift_reg_ppus_m1(clk, m1, ppus_m1);
    shift_reg #(2, 6) shift_reg_ppus_n1(clk, n1, ppus_n1);
`else
    shift_reg #(1, 9) shift_reg_ppus_neg_Xz(clk, neg_Xz, ppus_neg_Xz);
    shift_reg #(1, 8) shift_reg_ppus_Yz(clk, Yz, ppus_Yz);
    shift_reg #(1, 26) shift_reg_ppus_m1(clk, m1, ppus_m1);
    shift_reg #(1, 6) shift_reg_ppus_n1(clk, n1, ppus_n1);
`endif
endmodule
