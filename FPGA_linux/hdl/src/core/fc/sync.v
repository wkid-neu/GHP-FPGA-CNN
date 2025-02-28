`timescale 1ns / 1ps
`include "../../incl.vh"

//
// Synchronization of W and X
//
module Fc_sync (
    input clk,
    // X FIFO
    input x_fifo_empty,
    input x_fifo_almost_empty,
    output reg x_fifo_rd_en = 0,
    input [8:0] x_fifo_dout,
    input x_fifo_dout_vec_begin,
    input x_fifo_dout_vec_end,
    input x_fifo_dout_last,
    // W FIFO
    input w_fifo_empty,
    input w_fifo_almost_empty,
    output reg w_fifo_rd_en = 0,
    input [`DDR_AXIS_DATA_WIDTH/8*9-1:0] w_fifo_dout,
    // PE Array inputs
    output reg [8:0] mat_x = 0,
    output reg [`DDR_AXIS_DATA_WIDTH/8*9-1:0] mat_w = 0,
    output reg mat_begin = 0,
    output reg mat_end = 0,
    output reg mat_end_last = 0
);
    wire x_ready, w_ready;
    reg x_vld = 0;

    assign x_ready = (~x_fifo_empty && (~x_fifo_rd_en || ~x_fifo_almost_empty));
    assign w_ready = (~w_fifo_empty && (~w_fifo_rd_en || ~w_fifo_almost_empty));

    // x_fifo_rd_en, w_fifo_rd_en
    always @(posedge clk) begin
        x_fifo_rd_en <= (x_ready && w_ready);
        w_fifo_rd_en <= (x_ready && w_ready);
    end

    // x_vld
    always @(posedge clk)
        x_vld <= x_fifo_rd_en;

    // mat_x
    always @(posedge clk)
        if (x_vld)
            mat_x <= x_fifo_dout;
        else
            mat_x <= 0;

    // mat_w
    always @(posedge clk)
        mat_w <= w_fifo_dout;

    // mat_begin
    always @(posedge clk)
        mat_begin <= (x_vld && x_fifo_dout_vec_begin);

    // mat_end
    always @(posedge clk)
        mat_end <= (x_vld && x_fifo_dout_vec_end);

    // mat_end_last
    always @(posedge clk)
        mat_end_last <= (x_vld && x_fifo_dout_last);
endmodule
