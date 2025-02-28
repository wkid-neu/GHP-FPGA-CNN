`timescale 1ns / 1ps
`include "../../../incl.vh"

//
// The processing element of the systolic array.
// It occupies one DSP48E2.
// It can run 2 uint8 multiplies and accumulations at every clock cycle.
//
module Conv_sa_pe (
// Ports for debugging
`ifdef DEBUG
    input dbg_in_vec_begin,  // current input is the first element
    input dbg_in_vec_end,  // current input is the last element
    input dbg_in_vec_rst,  // current input is invaild, this is a reset cycle
    output reg dbg_out_vec_begin = 0,
    output reg dbg_out_vec_end = 0,
    output reg dbg_out_vec_rst = 0,
`endif
    input clk,
    // Data ports
    input [7:0] in_w1,  // the first weight vector
    input [7:0] in_w2,  // the second weight vector
    input [7:0] in_x,  // the activation vector
    input [18:0] in_psum1,  // the first partial sum of the upper PE
    input [18:0] in_psum2,  // the second partial sum of the upper PE
    output [7:0] out_w1,
    output [7:0] out_w2,
    output [7:0] out_x,
    output [18:0] out_psum1,
    output [18:0] out_psum2,
    // Flag ports
    input in_rst,  // p should be reset and saved at this cycle
    input in_flush,  // shift register mode
    output out_rst,
    output out_flush
);
    //
    // MACC
    //
    reg signed [26:0] A1 = 0;
    reg signed [17:0] B1 = 0;
    reg [7:0] out_x_reg = 0;
    always @(posedge clk) begin
        A1 <= {in_w2, {11{1'b0}}, in_w1};
        B1 <= {{10{1'b0}}, in_x};
        out_x_reg <= in_x;
    end

    reg signed [47:0] M = 0;
    reg signed [47:0] C = 0;
    reg A1_MSB = 0;
    always @(posedge clk) begin
        M <= A1*B1;
        A1_MSB <= A1[26];
        C <= {{13{1'b0}}, out_x_reg, {27{1'b0}}};
    end

    reg signed [47:0] P = 0;
    always @(posedge clk) begin
        if (in_rst)
            P <= 0;
        else
            P <= P + M + (A1_MSB?C:0);
    end

    //
    // FLUSH
    //
    reg [18:0] psum1_reg = 0;
    reg [18:0] psum2_reg = 0;
    always @(posedge clk) begin
        if (in_rst) begin
            psum1_reg <= P[18:0];
            psum2_reg <= P[37:19];
        end else if (in_flush) begin
            psum1_reg <= in_psum1;
            psum2_reg <= in_psum2;
        end
    end

    //
    // Chain
    //
    reg [7:0] out_w1_reg = 0;
    reg [7:0] out_w2_reg = 0;
    reg out_rst_reg = 0;
    reg out_flush_reg = 0;
    always @(posedge clk) begin
        out_w1_reg <= in_w1;
        out_w2_reg <= in_w2;
        out_rst_reg <= in_rst;
        out_flush_reg <= in_flush;
    end

    assign out_w1 = out_w1_reg;
    assign out_w2 = out_w2_reg;
    assign out_x = out_x_reg;
    assign out_psum1 = psum1_reg;
    assign out_psum2 = psum2_reg;
    assign out_rst = out_rst_reg;
    assign out_flush = out_flush_reg;

`ifdef DEBUG
    always @(posedge clk) begin
        dbg_out_vec_begin <= dbg_in_vec_begin;
        dbg_out_vec_end <= dbg_in_vec_end;
        dbg_out_vec_rst <= dbg_in_vec_rst;
    end
`endif
endmodule
