`timescale 1ns / 1ps
`include "../../incl.vh"

//
// Processing element in the Fc engine
//
module Fc_pe (
    input clk,
    input [8:0] in_x,
    output [8:0] out_x,
    input [8:0] in_w,
    input in_begin,
    output out_begin,
    input in_end,  // flush the result out
    output out_end,
    output reg [31:0] out_res = 0
);
    // flags (begin, end)
    reg vec_begin = 0;
    reg vec_end = 0;
    always @(posedge clk) begin
        vec_begin <= in_begin;
        vec_end <= in_end;
    end

    // Pipeline stage1 (read inputs to local registers)
    reg [8:0] local_w = 0;
    reg [8:0] local_x = 0;
    always @(posedge clk) begin
        local_w <= in_w;
        local_x <= in_x;
    end

    // Pipeline stage2 (inputs of DSP48)
    reg signed [8:0] a = 0;
    reg signed [8:0] b = 0;
    always @(posedge clk) begin
        a <= local_w;
        b <= local_x;
    end

    // Pipeline stage3 (M register)
    reg signed [18:0] m_reg = 0;
    always @(posedge clk)
        m_reg <= a*b;

    // Pipeline stage4 (Outputs of DSP48)
    (* use_dsp="yes" *) reg signed [31:0] p = 0;
    always @(posedge clk)
        if (vec_begin)
            p <= m_reg;
        else
            p <= m_reg+p;

    // Result
    always @(posedge clk)
        if (vec_end)
            out_res <= p;

    // Chain
    assign out_x = local_x;
    assign out_begin = vec_begin;
    assign out_end = vec_end;
endmodule
