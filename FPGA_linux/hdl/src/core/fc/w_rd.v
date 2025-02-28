`timescale 1ns / 1ps
`include "../../incl.vh"

//
// Read weights from DRAM and write into fifo
// OC*INC < (1<<27)
//
module Fc_w_rd (
    input clk,
    // instruction
    input start_pulse,
    input [7:0] wz,
    input [31:0] w_addr,
    input [31:0] w_n_bytes,
    // DMA
    output reg [`DDR_AXI_ADDR_WIDTH-1:0] dma_rd_desc_addr = 0,
    output reg [`DDR_LEN_WIDTH-1:0] dma_rd_desc_len = 0,
    output reg dma_rd_desc_valid = 0,
    input [`DDR_AXIS_DATA_WIDTH-1:0] dma_rd_read_data_tdata,
    input dma_rd_read_data_tvalid,
    output reg dma_rd_read_data_tready = 0,
    input dma_rd_read_data_tlast,
    // W FIFO write ports
    output w_fifo_wr_en,
    output [`DDR_AXIS_DATA_WIDTH/8*9-1:0] w_fifo_din,
    input w_fifo_prog_full
);
    reg w_fifo_wr_en_reg = 0;
    reg [`DDR_AXIS_DATA_WIDTH/8*9-1:0] w_fifo_din_reg = 0;

    // post processing
    reg post_vld = 0;
    reg [`DDR_AXIS_DATA_WIDTH/8*9-1:0] post_val = 0;
    integer i;
    
    // dma_rd_desc_addr, dma_rd_desc_len, dma_rd_desc_valid
    always @(posedge clk) begin
        dma_rd_desc_valid <= start_pulse;
        dma_rd_desc_addr <= w_addr;
        dma_rd_desc_len <= w_n_bytes;
    end

    // dma_rd_read_data_tready
    always @(posedge clk)
        dma_rd_read_data_tready <= ~w_fifo_prog_full;

    // post_vld, post_val
    always @(posedge clk) begin
        post_vld <= (dma_rd_read_data_tvalid && dma_rd_read_data_tready);
        for (i=0; i<`DDR_AXIS_DATA_WIDTH/8; i=i+1)
            post_val[i*9+:9] <= {1'b0, dma_rd_read_data_tdata[i*8+:8]};
    end

    // w_fifo_wr_en_reg, w_fifo_din_reg
    always @(posedge clk) begin
        w_fifo_wr_en_reg <= post_vld;
        for (i=0; i<`DDR_AXIS_DATA_WIDTH/8; i=i+1)
            w_fifo_din_reg[i*9+:9] <= $signed(post_val[i*9+:9])-$signed({1'b0, wz});
    end

`ifdef M32P64Q16R16S8
    // Add additional pipeline stages for high performance
    shift_reg #(1, 1) shift_reg_w_fifo_wr_en(clk, w_fifo_wr_en_reg, w_fifo_wr_en);
    shift_reg #(1, `DDR_AXIS_DATA_WIDTH/8*9) shift_reg_w_fifo_din(clk, w_fifo_din_reg, w_fifo_din);
`elsif M32P96Q16R16S8
    // Add additional pipeline stages for high performance
    shift_reg #(1, 1) shift_reg_w_fifo_wr_en(clk, w_fifo_wr_en_reg, w_fifo_wr_en);
    shift_reg #(1, `DDR_AXIS_DATA_WIDTH/8*9) shift_reg_w_fifo_din(clk, w_fifo_din_reg, w_fifo_din);
`elsif M64P64Q16R16S8
    // Add additional pipeline stages for high performance
    shift_reg #(1, 1) shift_reg_w_fifo_wr_en(clk, w_fifo_wr_en_reg, w_fifo_wr_en);
    shift_reg #(1, `DDR_AXIS_DATA_WIDTH/8*9) shift_reg_w_fifo_din(clk, w_fifo_din_reg, w_fifo_din);
`else
    assign w_fifo_wr_en = w_fifo_wr_en_reg;
    assign w_fifo_din = w_fifo_din_reg;
`endif
endmodule
