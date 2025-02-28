`timescale 1ns / 1ps
`include "../../incl.vh"

//
// Read controller of BM
//
module bm_rd_ctrl (
    input clk,
    // Read ports from conv
    input rd_en_conv,
    input [$clog2(`BM_DEPTH)-1:0] rd_addr_conv,
    output reg [`BM_DATA_WIDTH-1:0] dout_conv = 0,
    output dout_vld_conv,
    // Read ports from fc
    input rd_en_fc,
    input [$clog2(`BM_DEPTH)-1:0] rd_addr_fc,
    output reg [`BM_DATA_WIDTH-1:0] dout_fc = 0,
    output dout_vld_fc,
    // BM read ports
    output reg rd_en = 0,
    output reg [$clog2(`BM_DEPTH)-1:0] rd_addr = 0,
    input [`BM_DATA_WIDTH-1:0] dout
);
    // rd_en
    always @(posedge clk)
        rd_en <= (rd_en_conv || rd_en_fc);

    // rd_addr
    always @(posedge clk)
        if (rd_en_conv)
            rd_addr <= rd_addr_conv;
        else
            rd_addr <= rd_addr_fc;

    // dout_conv
    always @(posedge clk)
        dout_conv <= dout;

    // dout_vld_fc
    always @(posedge clk)
        dout_fc <= dout;

    shift_reg #(`BM_NUM_PIPE+3, 1) shift_reg_inst1(clk, rd_en_conv, dout_vld_conv);
    shift_reg #(`BM_NUM_PIPE+3, 1) shift_reg_inst2(clk, rd_en_fc, dout_vld_fc);
endmodule
