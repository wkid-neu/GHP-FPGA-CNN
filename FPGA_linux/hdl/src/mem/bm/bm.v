`timescale 1ns / 1ps
`include "../../incl.vh"

//
// Bias Memory (BM)
//
module bm (
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
    // Read ports from conv
    input rd_en_conv,
    input [$clog2(`BM_DEPTH)-1:0] rd_addr_conv,
    output [`BM_DATA_WIDTH-1:0] dout_conv,
    output dout_vld_conv,
    // Read ports from fc
    input rd_en_fc,
    input [$clog2(`BM_DEPTH)-1:0] rd_addr_fc,
    output [`BM_DATA_WIDTH-1:0] dout_fc,
    output dout_vld_fc
);
    wire rd_en;
    wire [$clog2(`BM_DEPTH)-1:0] rd_addr;
    wire [`BM_DATA_WIDTH-1:0] dout;
    wire wr_en;
    wire [$clog2(`BM_DEPTH)-1:0] wr_addr;
    wire [`BM_DATA_WIDTH-1:0] din;

    bm_d2c bm_d2c_inst(
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
        .dma_rd_read_data_tlast  (dma_rd_read_data_tlast  ),
        .wr_en(wr_en),
        .wr_addr(wr_addr),
        .din(din)
    );

    bm_rd_ctrl bm_rd_ctrl_inst(
        .clk(clk),
        .rd_en_conv(rd_en_conv),
        .rd_addr_conv(rd_addr_conv),
        .dout_conv(dout_conv),
        .dout_vld_conv(dout_vld_conv),
        .rd_en_fc(rd_en_fc),
        .rd_addr_fc(rd_addr_fc),
        .dout_fc(dout_fc),
        .dout_vld_fc(dout_vld_fc),
        .rd_en(rd_en),
        .rd_addr(rd_addr),
        .dout(dout)
    );

    bm_mem bm_mem_inst(
        .clk(clk),
        .wr_en(wr_en),
        .wr_addr(wr_addr),
        .din(din),
        .rd_en(rd_en),
        .rd_addr(rd_addr),
        .dout(dout)
    );
endmodule
