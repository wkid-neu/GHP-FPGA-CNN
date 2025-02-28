`timescale 1ns / 1ps
`include "../../incl.vh"

//
// This module prepares inputs for ppus.
// Make sure that DDR_AXIS_DATA_WIDTH/8 <= S*R.
// Only the first DDR_AXIS_DATA_WIDTH/8 elements of the ppu array are used.
//
module Fc_ppus_pre (
    input clk,
    // instruction
    input [25:0] m1,
    input [5:0] n1,
    input [7:0] Yz,
    // Bias preparation module
    input [`DDR_AXIS_DATA_WIDTH/8*32-1:0] bias,
    output reg read_next_bias = 0,
    // PE Array outputs
    input [`DDR_AXIS_DATA_WIDTH/8*32-1:0] mat_y,
    input mat_y_vld,
    input mat_y_last,
    // ppus inputs
    output [`DDR_AXIS_DATA_WIDTH/8*32-1:0] ppus_accs,
    output [`DDR_AXIS_DATA_WIDTH/8*32-1:0] ppus_bias,
    output ppus_accs_vld,
    output ppus_accs_last,
    output [25:0] ppus_m1,
    output [5:0] ppus_n1, 
    output [7:0] ppus_Yz
);
    // Parameter Assertions
    initial begin
        // Make sure that the ppus bandwidth is enough for the PE array.
        // Otherwise the hardware can not work correctly.
        if (`DDR_AXIS_DATA_WIDTH/8 > `S*`R) begin
            $error("Hyper parameter mismatch, please make sure that DDR_AXIS_DATA_WIDTH/8 <= S*R, current values are: DDR_AXIS_DATA_WIDTH = %0d, R = %0d, S = %0d", `DDR_AXIS_DATA_WIDTH, `R, `S);
            $finish;
        end
    end

    reg [`DDR_AXIS_DATA_WIDTH/8*32-1:0] ppus_accs_reg = 0;
    reg [`DDR_AXIS_DATA_WIDTH/8*32-1:0] ppus_bias_reg = 0;
    reg ppus_accs_vld_reg = 0;
    reg ppus_accs_last_reg = 0;

    // read_next_bias
    always @(posedge clk)
        read_next_bias <= (mat_y_vld && ~mat_y_last);

    // ppus_accs_reg, ppus_bias_reg, ppus_accs_vld_reg, ppus_accs_last_reg
    always @(posedge clk) begin
        ppus_accs_reg <= mat_y;
        ppus_bias_reg <= bias;
        ppus_accs_vld_reg <= mat_y_vld;
        ppus_accs_last_reg <= mat_y_last;
    end

`ifdef M32P64Q16R16S8
    // Add additional pipeline stages for high performance
    shift_reg #(1, `DDR_AXIS_DATA_WIDTH/8*32) shift_reg_ppus_accs(clk, ppus_accs_reg, ppus_accs);
    shift_reg #(1, `DDR_AXIS_DATA_WIDTH/8*32) shift_reg_ppus_bias(clk, ppus_bias_reg, ppus_bias);
    shift_reg #(1, 1) shift_reg_ppus_accs_vld(clk, ppus_accs_vld_reg, ppus_accs_vld);
    shift_reg #(1, 1) shift_reg_ppus_accs_last(clk, ppus_accs_last_reg, ppus_accs_last);
`elsif M32P96Q16R16S8
    // Add additional pipeline stages for high performance
    shift_reg #(1, `DDR_AXIS_DATA_WIDTH/8*32) shift_reg_ppus_accs(clk, ppus_accs_reg, ppus_accs);
    shift_reg #(1, `DDR_AXIS_DATA_WIDTH/8*32) shift_reg_ppus_bias(clk, ppus_bias_reg, ppus_bias);
    shift_reg #(1, 1) shift_reg_ppus_accs_vld(clk, ppus_accs_vld_reg, ppus_accs_vld);
    shift_reg #(1, 1) shift_reg_ppus_accs_last(clk, ppus_accs_last_reg, ppus_accs_last);
`elsif M64P64Q16R16S8
    // Add additional pipeline stages for high performance
    shift_reg #(1, `DDR_AXIS_DATA_WIDTH/8*32) shift_reg_ppus_accs(clk, ppus_accs_reg, ppus_accs);
    shift_reg #(1, `DDR_AXIS_DATA_WIDTH/8*32) shift_reg_ppus_bias(clk, ppus_bias_reg, ppus_bias);
    shift_reg #(1, 1) shift_reg_ppus_accs_vld(clk, ppus_accs_vld_reg, ppus_accs_vld);
    shift_reg #(1, 1) shift_reg_ppus_accs_last(clk, ppus_accs_last_reg, ppus_accs_last);
`else
    assign ppus_accs = ppus_accs_reg;
    assign ppus_bias = ppus_bias_reg;
    assign ppus_accs_vld = ppus_accs_vld_reg;
    assign ppus_accs_last = ppus_accs_last_reg;
`endif

`ifdef M32P64Q16R16S8
    shift_reg #(2, 26) shift_reg_ppus_m1(clk, m1, ppus_m1);
    shift_reg #(2, 6) shift_reg_ppus_n1(clk, n1, ppus_n1);
    shift_reg #(2, 8) shift_reg_ppus_Yz(clk, Yz, ppus_Yz);
`elsif M32P96Q16R16S8
    shift_reg #(2, 26) shift_reg_ppus_m1(clk, m1, ppus_m1);
    shift_reg #(2, 6) shift_reg_ppus_n1(clk, n1, ppus_n1);
    shift_reg #(2, 8) shift_reg_ppus_Yz(clk, Yz, ppus_Yz);
`elsif M64P64Q16R16S8
    shift_reg #(2, 26) shift_reg_ppus_m1(clk, m1, ppus_m1);
    shift_reg #(2, 6) shift_reg_ppus_n1(clk, n1, ppus_n1);
    shift_reg #(2, 8) shift_reg_ppus_Yz(clk, Yz, ppus_Yz);
`else
    shift_reg #(1, 26) shift_reg_ppus_m1(clk, m1, ppus_m1);
    shift_reg #(1, 6) shift_reg_ppus_n1(clk, n1, ppus_n1);
    shift_reg #(1, 8) shift_reg_ppus_Yz(clk, Yz, ppus_Yz);
`endif
endmodule
