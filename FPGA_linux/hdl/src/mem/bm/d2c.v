`timescale 1ns / 1ps
`include "../../incl.vh"

//
// Load Bias from DRAM
//
module bm_d2c (
    input clk,
    // control signal
    input start_pulse,
    input [31:0] d_addr,
    input [31:0] c_addr,
    input [31:0] n_bytes, 
    output reg done_pulse = 0,
    // DMA read controller
    output reg [`DDR_AXI_ADDR_WIDTH-1:0] dma_rd_desc_addr = 0,
    output reg [`DDR_LEN_WIDTH-1:0] dma_rd_desc_len = 0,
    output reg dma_rd_desc_valid = 0,
    input [`DDR_AXIS_DATA_WIDTH-1:0] dma_rd_read_data_tdata,
    input dma_rd_read_data_tvalid,
    input dma_rd_read_data_tlast,
    // BM write ports
    output wr_en,
    output [$clog2(`BM_DEPTH)-1:0] wr_addr,
    output [`BM_DATA_WIDTH-1:0] din
);
    reg wr_en_reg = 0;
    reg [$clog2(`BM_DEPTH)-1:0] wr_addr_reg = 0;
    reg [`BM_DATA_WIDTH-1:0] din_reg = 0;

    // dma_rd_desc_addr, dma_rd_desc_len, dma_rd_desc_valid
    always @(posedge clk) begin
        dma_rd_desc_valid <= start_pulse;
        dma_rd_desc_addr <= d_addr;
        dma_rd_desc_len <= n_bytes;
    end

    reg [$clog2(`BM_DEPTH)-1:0] next_addr = 0;

    // next_addr
    always @(posedge clk)
        if (start_pulse)
            next_addr <= c_addr;
        else if (dma_rd_read_data_tvalid)
            next_addr <= next_addr+1;

    // wr_en_reg, wr_addr_reg, din_reg
    always @(posedge clk) begin
        wr_en_reg <= dma_rd_read_data_tvalid;
        wr_addr_reg <= next_addr;
        din_reg <= dma_rd_read_data_tdata;
    end

    // done_pulse
    always @(posedge clk) 
        done_pulse <= (dma_rd_read_data_tvalid && dma_rd_read_data_tlast);

`ifdef M32P64Q16R16S8
    shift_reg #(1, 1) shift_reg_wr_en(clk, wr_en_reg, wr_en);
    shift_reg #(1, $clog2(`BM_DEPTH)) shift_reg_wr_addr(clk, wr_addr_reg, wr_addr);
    shift_reg #(1, `BM_DATA_WIDTH) shift_reg_din(clk, din_reg, din);
`elsif M32P96Q16R16S8
    shift_reg #(1, 1) shift_reg_wr_en(clk, wr_en_reg, wr_en);
    shift_reg #(1, $clog2(`BM_DEPTH)) shift_reg_wr_addr(clk, wr_addr_reg, wr_addr);
    shift_reg #(1, `BM_DATA_WIDTH) shift_reg_din(clk, din_reg, din);
`elsif M64P64Q16R16S8
    shift_reg #(1, 1) shift_reg_wr_en(clk, wr_en_reg, wr_en);
    shift_reg #(1, $clog2(`BM_DEPTH)) shift_reg_wr_addr(clk, wr_addr_reg, wr_addr);
    shift_reg #(1, `BM_DATA_WIDTH) shift_reg_din(clk, din_reg, din);
`else
    assign wr_en = wr_en_reg;
    assign wr_addr = wr_addr_reg;
    assign din = din_reg;
`endif
endmodule
