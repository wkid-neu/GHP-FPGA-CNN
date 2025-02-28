`timescale 1ns / 1ps
`include "../../../incl.vh"

//
// A row of PE.
// It contains P PEs.
//
module Conv_sa_pe_row (
// Ports for debugging
`ifdef DEBUG
    input dbg_in_vec_begin,  // current input is the first element
    input dbg_in_vec_end,  // current input is the last element
    input dbg_in_vec_rst,  // current input is invaild, this is a reset cycle
`endif
    input clk,
    // Data ports
    input [7:0] in_w1,
    input [7:0] in_w2,
    input [`P*8-1:0] in_x,
    input [`P*19-1:0] in_psum1,
    input [`P*19-1:0] in_psum2,
    output [`P*8-1:0] out_x,
    output [`P*19-1:0] out_psum1,
    output [`P*19-1:0] out_psum2,
    // Flag ports
    input in_rst,
    input in_flush
);
    wire [7:0] out_w1_list [`P-1:0];
    wire [7:0] out_w2_list [`P-1:0];
    wire [`P-1:0] out_rst_list;
    wire [`P-1:0] out_flush_list;
`ifdef DEBUG
    wire [`P-1:0] dbg_out_vec_begin_list;
    wire [`P-1:0] dbg_out_vec_end_list;
    wire [`P-1:0] dbg_out_vec_rst_list;
`endif

    genvar i;
    generate
        for (i=0; i<`P; i=i+1) begin: PE
            Conv_sa_pe Conv_sa_pe_inst(
`ifdef DEBUG
                .dbg_in_vec_begin(i==0?dbg_in_vec_begin:dbg_out_vec_begin_list[i-1]),
                .dbg_in_vec_end(i==0?dbg_in_vec_end:dbg_out_vec_end_list[i-1]),
                .dbg_in_vec_rst(i==0?dbg_in_vec_rst:dbg_out_vec_rst_list[i-1]),
                .dbg_out_vec_begin(dbg_out_vec_begin_list[i]),
                .dbg_out_vec_end(dbg_out_vec_end_list[i]),
                .dbg_out_vec_rst(dbg_out_vec_rst_list[i]),
`endif
                .clk(clk),
                .in_w1(i==0?in_w1:out_w1_list[i-1]),
                .in_w2(i==0?in_w2:out_w2_list[i-1]),
                .in_x(in_x[i*8+:8]),
                .in_psum1(in_psum1[i*19+:19]),
                .in_psum2(in_psum2[i*19+:19]),
                .out_w1(out_w1_list[i]),
                .out_w2(out_w2_list[i]),
                .out_x(out_x[i*8+:8]),
                .out_psum1(out_psum1[i*19+:19]),
                .out_psum2(out_psum2[i*19+:19]),
                .in_rst(i==0?in_rst:out_rst_list[i-1]),
                .in_flush(i==0?in_flush:out_flush_list[i-1]),
                .out_rst(out_rst_list[i]),
                .out_flush(out_flush_list[i])
            );
        end
    endgenerate
endmodule
