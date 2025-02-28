`timescale 1ns / 1ps
`include "../../incl.vh"

//
// X packet heads memory (XPHM)
//
module xphm (
    input clk,
    // host control signals (hc_*)
    input hc_d2c_start_pulse,  // dram to chip
    input [31:0] hc_d2c_d_addr,
    input [31:0] hc_d2c_c_addr,
    input [31:0] hc_d2c_n_bytes,
    output hc_d2c_done_pulse,
    // DMA read controller
    output [`DDR_AXI_ADDR_WIDTH-1:0] dma_rd_desc_addr,
    output [`DDR_LEN_WIDTH-1:0] dma_rd_desc_len,
    output dma_rd_desc_valid,
    input [`DDR_AXIS_DATA_WIDTH-1:0] dma_rd_read_data_tdata,
    input dma_rd_read_data_tvalid,
    input dma_rd_read_data_tlast,
    // Read Ports
    input rd_en,
    input rd_last,
    input [$clog2(`XPHM_DEPTH)-1:0] rd_addr,
    output [`XPHM_DATA_WIDTH-1:0] dout,
    output dout_vld,
    output dout_last
);
    wire wr_en;
    wire [$clog2(`XPHM_DEPTH)-1:0] wr_addr;
    wire [`XPHM_DATA_WIDTH-1:0] din;

    xphm_d2c xphm_d2c_inst(
        .clk(clk),
        .start_pulse(hc_d2c_start_pulse),
        .d_addr(hc_d2c_d_addr),
        .c_addr(hc_d2c_c_addr),
        .n_bytes(hc_d2c_n_bytes),
        .done_pulse(hc_d2c_done_pulse),
        .dma_rd_desc_addr(dma_rd_desc_addr),
        .dma_rd_desc_len(dma_rd_desc_len),
        .dma_rd_desc_valid(dma_rd_desc_valid),
        .dma_rd_read_data_tdata(dma_rd_read_data_tdata),
        .dma_rd_read_data_tvalid(dma_rd_read_data_tvalid),
        .dma_rd_read_data_tlast(dma_rd_read_data_tlast),
        .wr_en(wr_en),
        .wr_addr(wr_addr),
        .din(din)
    );

    xphm_mem xphm_mem_inst(
        .clk(clk),
        .rd_en(rd_en),
        .rd_addr(rd_addr),
        .dout(dout),
        .wr_en(wr_en),
        .wr_addr(wr_addr),
        .din(din)
    );

    shift_reg #(
        .DELAY(`XPHM_NUM_PIPE+1),
        .DATA_WIDTH(2)
    ) shift_reg(
        .clk(clk),
        .i({rd_en, rd_last}),
        .o({dout_vld, dout_last})
    );
endmodule
