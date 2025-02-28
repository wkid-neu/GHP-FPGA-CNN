`timescale 1ns / 1ps
`include "../../incl.vh"

//
// PE Array
//
module Fc_pe_arr (
    input clk,
    input [8:0] mat_x,
    input [`DDR_AXIS_DATA_WIDTH/8*9-1:0] mat_w,
    input mat_begin,
    input mat_end,
    input mat_end_last,
    output [`DDR_AXIS_DATA_WIDTH/8*32-1:0] mat_y,
    output mat_y_vld,  // mat_y is valid
    output mat_y_last  // the last mat_y
);
    genvar i;

    //
    // The flags `begin` and `end` should be delayed to sync with PE internal dataflow
    //
    wire shifted_begin;
    wire shifted_end;

    shift_reg #(
        .DELAY(2),
        .DATA_WIDTH(1)
    ) shift_begin_inst(
    	.clk(clk),
        .i(mat_begin),
        .o(shifted_begin)
    );

    shift_reg #(
        .DELAY(3),
        .DATA_WIDTH(1)
    ) shift_end_inst (
    	.clk(clk),
        .i(mat_end),
        .o(shifted_end)
    );

    //
    // shifted weights
    //
    wire [`DDR_AXIS_DATA_WIDTH/8*9-1:0] shifted_w;

    generate
        for (i=0; i<`DDR_AXIS_DATA_WIDTH/8; i=i+1) begin
            shift_reg #(
                .DELAY(i),
                .DATA_WIDTH(9)
            ) shift_w_inst(
                .clk(clk),
                .i(mat_w[9*i+:9]),
                .o(shifted_w[9*i+:9])
            );
        end
    endgenerate

    //
    // PE Array
    //
    wire [8:0] out_x_list [`DDR_AXIS_DATA_WIDTH/8-1:0];
    wire [`DDR_AXIS_DATA_WIDTH/8-1:0] out_begin_list;
    wire [`DDR_AXIS_DATA_WIDTH/8-1:0] out_end_list;
    wire [`DDR_AXIS_DATA_WIDTH/8*32-1:0] raw_mat_y;

    generate
        for (i=0; i<`DDR_AXIS_DATA_WIDTH/8; i=i+1) begin
            Fc_pe Fc_pe_inst(
            	.clk(clk),
                .in_x(i==0 ? mat_x : out_x_list[i-1]),
                .out_x(out_x_list[i]),
                .in_w(shifted_w[i*9+:9]),
                .in_begin(i==0 ? shifted_begin : out_begin_list[i-1]),
                .out_begin(out_begin_list[i]),
                .in_end(i==0 ? shifted_end : out_end_list[i-1]),
                .out_end(out_end_list[i]),
                .out_res(raw_mat_y[i*32+:32])
            );
        end
    endgenerate

    //
    // Outputs in different columns should be synchronized
    //
    generate
        for (i=0; i<`DDR_AXIS_DATA_WIDTH/8; i=i+1) begin
            shift_reg #(
                .DELAY(`DDR_AXIS_DATA_WIDTH/8-1-i),
                .DATA_WIDTH(32)
            ) shift_y_inst(
            	.clk(clk),
                .i(raw_mat_y[i*32+:32]),
                .o(mat_y[i*32+:32])
            );
        end
    endgenerate

    //
    // Output flags
    //
    shift_reg #(
        .DELAY(`DDR_AXIS_DATA_WIDTH/8+4),
        .DATA_WIDTH(2)
    ) shift_y_flag_inst (
    	.clk(clk),
        .i({mat_end, mat_end_last}),
        .o({mat_y_vld, mat_y_last})
    );
endmodule
