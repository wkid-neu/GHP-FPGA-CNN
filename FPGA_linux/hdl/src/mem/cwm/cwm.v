`timescale 1ns / 1ps
`include "../../incl.vh"

//
// Convolution Weight Memory
//
module cwm (
    input clk,
    // host control signals (hc_*)
    input hc_d2c_start_pulse,  // dram to chip
    input [31:0] hc_d2c_d_addr,
    input [31:0] hc_d2c_c_addr,
    input [31:0] hc_d2c_n_bytes,
    output reg hc_d2c_done_pulse = 0,
    // instruction control signals (ic_*)
    input ic_d2c_start_pulse,  // dram to chip
    input [31:0] ic_d2c_d_addr,
    input [31:0] ic_d2c_c_addr,
    input [31:0] ic_d2c_n_bytes,
    output reg ic_d2c_done_pulse = 0,
    // DMA read controller
    output [`DDR_AXI_ADDR_WIDTH-1:0] dma_rd_desc_addr,
    output [`DDR_LEN_WIDTH-1:0] dma_rd_desc_len,
    output dma_rd_desc_valid,
    input [`DDR_AXIS_DATA_WIDTH-1:0] dma_rd_read_data_tdata,
    input dma_rd_read_data_tvalid,
    input dma_rd_read_data_tlast,
    // write pointer (use one more bit to make the last entry available)
    output [$clog2(`CWM_DEPTH):0] wr_ptr,
    // Read ports
    input rd_en,
    input [$clog2(`CWM_DEPTH)-1:0] rd_addr,
    output [`M*4*8-1:0] dout,
    output dout_vld
);
    reg d2c_source = 0;  // host (0) or instruction (1)
    reg d2c_start_pulse = 0;
    reg [31:0] d2c_d_addr = 0;
    reg [31:0] d2c_c_addr = 0;
    reg [31:0] d2c_n_bytes = 0;
    wire d2c_done_pulse;

    wire wr_en;
    wire [$clog2(`CWM_DEPTH)-1:0] wr_addr;
    wire [`M*4*8-1:0] din;

    always @(posedge clk)
        if (hc_d2c_start_pulse)
            d2c_source <= 0;
        else if (ic_d2c_start_pulse)
            d2c_source <= 1;

    always @(posedge clk) begin
        d2c_start_pulse <= (hc_d2c_start_pulse || ic_d2c_start_pulse);
        if (hc_d2c_start_pulse) begin
            d2c_d_addr <= hc_d2c_d_addr;
            d2c_c_addr <= hc_d2c_c_addr;
            d2c_n_bytes <= hc_d2c_n_bytes;
        end else if (ic_d2c_start_pulse) begin
            d2c_d_addr <= ic_d2c_d_addr;
            d2c_c_addr <= ic_d2c_c_addr;
            d2c_n_bytes <= ic_d2c_n_bytes;
        end
    end

    always @(posedge clk)
        hc_d2c_done_pulse <= (~d2c_source & d2c_done_pulse);

    always @(posedge clk)
        ic_d2c_done_pulse <= (d2c_source & d2c_done_pulse);

    cwm_d2c cwm_d2c_inst(
        .clk(clk),
        .start_pulse(d2c_start_pulse),
        .d_addr(d2c_d_addr),
        .c_addr(d2c_c_addr),
        .n_bytes(d2c_n_bytes),
        .done_pulse(d2c_done_pulse),
        .dma_rd_desc_addr(dma_rd_desc_addr),
        .dma_rd_desc_len(dma_rd_desc_len),
        .dma_rd_desc_valid(dma_rd_desc_valid),
        .dma_rd_read_data_tdata(dma_rd_read_data_tdata),
        .dma_rd_read_data_tvalid(dma_rd_read_data_tvalid),
        .dma_rd_read_data_tlast(dma_rd_read_data_tlast),
        .wr_en(wr_en),
        .wr_addr(wr_addr),
        .din(din),
        .wr_ptr(wr_ptr)
    );

    cwm_mem cwm_mem_inst(
    	.clk(clk),
        .rd_en(rd_en),
        .rd_addr(rd_addr),
        .dout(dout),
        .dout_vld(dout_vld),
        .wr_en(wr_en),
        .wr_addr(wr_addr),
        .din(din)
    );
endmodule
