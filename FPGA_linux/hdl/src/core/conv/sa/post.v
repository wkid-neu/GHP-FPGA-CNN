`timescale 1ns / 1ps
`include "../../../incl.vh"

//
// This module runs the post-processing for a column.
//
module Conv_sa_post (
    input clk,
    // Column sums
    input [`M/8*32-1:0] sum1,
    input [`M/8*32-1:0] sum2,
    // Final outputs
    output reg signed [31:0] y1 = 0,
    output reg signed [31:0] y2 = 0,
    // Activation input of last row of thw first block.
    input [7:0] x,
    // Zero-point of weight tensor
    input [7:0] wz,
    // Flags
    input in_rstp,  // clear the p register
    input [$clog2(`M/8)-1:0] in_sel,  // select a valid block
    output reg out_rstp = 0,
    output reg [$clog2(`M/8)-1:0] out_sel = 0
);
    // x should be delayed to make sure that acc is synchronized with y1_reg.
    // in_rstp should also be delayed, which is implemented by the controller.
    wire [7:0] delayed_x;
    shift_reg #(3, 8) shift_reg_x(clk, x, delayed_x);
    
    reg [15:0] m = 0;
    always @(posedge clk)
        m <= wz*delayed_x;

    reg [31:0] p = 0;
    always @(posedge clk)
        if (in_rstp)
            p <= 0;
        else
            p <= p+m;

    reg [31:0] acc = 0;
    always @(posedge clk)
        if (in_rstp)
            acc <= p;

    reg [31:0] y1_reg = 0; 
    reg [31:0] y2_reg = 0; 
    always @(posedge clk) begin
        y1_reg <= sum1[in_sel*32+:32];
        y2_reg <= sum2[in_sel*32+:32];
    end

    always @(posedge clk) begin
        y1 <= $signed(y1_reg)-$signed(acc);
        y2 <= $signed(y2_reg)-$signed(acc);
    end

    always @(posedge clk) begin
        out_rstp <= in_rstp;
        out_sel <= in_sel;
    end
endmodule
