`timescale 1ns / 1ps
`include "../../../incl.vh"

//
// This module writes Pooling results back to RTM.
//
module Pool_wb (
    input clk,
    input start_pulse,
    output done_pulse,
    // Instruction
    input [$clog2(`RTM_DEPTH)-1:0] Y_addr,
    input [15:0] INC2_minus_1,
    input [15:0] n_X_rnd_minus_1,
    input [15:0] ofm_height,
    input [7:0] n_last_batch,
    // ppus outputs
    input [(`P/2)*8-1:0] ppus_outs,
    input ppus_out_vld,
    // RTM write ports
    output rtm_wr_vld,
    output [`S-1:0] rtm_wr_en,
    output [`S*$clog2(`RTM_DEPTH)-1:0] rtm_wr_addr,
    output [`S*`R*8-1:0] rtm_din
);
    wire [`S*`R*8-1:0] gathered_data;
    wire gathered_data_vld;

    wire desc_fifo_wr_en;
    wire [$clog2(`RTM_DEPTH)-1:0] desc_fifo_din_addr;
    wire desc_fifo_din_mask;
    wire desc_fifo_din_last;
    wire desc_fifo_prog_full;
    wire desc_fifo_rd_en;
    wire [$clog2(`RTM_DEPTH)-1:0] desc_fifo_dout_addr;
    wire desc_fifo_dout_mask;
    wire desc_fifo_dout_last;
    wire desc_fifo_dout_vld;

    Pool_wb_gather Pool_wb_gather_inst(
        .clk(clk),
        .ppus_outs(ppus_outs),
        .ppus_out_vld(ppus_out_vld),
        .gathered_data(gathered_data),
        .gathered_data_vld(gathered_data_vld)
    );

    sync_fifo #(
        .DATA_WIDTH($clog2(`RTM_DEPTH)+2),
        .DEPTH(32),
        .PROG_FULL(16),
        .READ_LATENCY(1),
        .HAS_EMPTY(0),
        .HAS_ALMOST_EMPTY(0),
        .HAS_DATA_VALID(1),
        .HAS_PROG_FULL(1),
        .RAM_STYLE("distributed")
    ) desc_fifo_inst(
        .clk(clk),
        .rd_en(desc_fifo_rd_en),
        .dout({desc_fifo_dout_last, desc_fifo_dout_mask, desc_fifo_dout_addr}),
        .data_valid(desc_fifo_dout_vld),
        .wr_en(desc_fifo_wr_en),
        .din({desc_fifo_din_last, desc_fifo_din_mask, desc_fifo_din_addr}),
        .prog_full(desc_fifo_prog_full)
    );

    Pool_wb_desc_fifo_wr Pool_wb_desc_fifo_wr_inst(
        .clk(clk),
        .start_pulse(start_pulse),
        .Y_addr(Y_addr),
        .INC2_minus_1(INC2_minus_1),
        .n_X_rnd_minus_1(n_X_rnd_minus_1),
        .ofm_height(ofm_height),
        .n_last_batch(n_last_batch),
        .fifo_wr_en(desc_fifo_wr_en),
        .fifo_din_addr(desc_fifo_din_addr),
        .fifo_din_mask(desc_fifo_din_mask),
        .fifo_din_last(desc_fifo_din_last),
        .fifo_prog_full(desc_fifo_prog_full)
    );

    Pool_wb_rtm_wr Pool_wb_rtm_wr_inst(
        .clk(clk),
        .done_pulse(done_pulse),
        .gathered_data(gathered_data),
        .gathered_data_vld(gathered_data_vld),
        .desc_fifo_rd_en(desc_fifo_rd_en),
        .desc_fifo_dout_addr(desc_fifo_dout_addr),
        .desc_fifo_dout_mask(desc_fifo_dout_mask),
        .desc_fifo_dout_last(desc_fifo_dout_last),
        .desc_fifo_dout_vld(desc_fifo_dout_vld),
        .rtm_wr_vld(rtm_wr_vld),
        .rtm_wr_en(rtm_wr_en),
        .rtm_wr_addr(rtm_wr_addr),
        .rtm_din(rtm_din)
    );
endmodule
