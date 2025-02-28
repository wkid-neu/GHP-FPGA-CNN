`timescale 1ns / 1ps
`include "../../incl.vh"

// 
// This module reads packet headers from XPHM and then writes them into FIFO.
//
module xbus_pkt_gen_xphm_rd (
    input clk,
    input start_pulse,
    // XPHM descriptor
    input [$clog2(`XPHM_DEPTH)-1:0] xphm_addr,
    input [$clog2(`XPHM_DEPTH)-1:0] xphm_len_minus_1,
    // XPHM read ports
    output reg xphm_rd_en = 0,
    output reg xphm_rd_last = 0,
    output reg [$clog2(`XPHM_DEPTH)-1:0] xphm_rd_addr = 0,
    input [`XPHM_DATA_WIDTH-1:0] xphm_dout,
    input xphm_dout_vld,
    input xphm_dout_last,
    // FIFO write ports
    output reg fifo_wr_en = 0,
    output reg [`XPHM_DATA_WIDTH-1:0] fifo_din = 0,
    output reg fifo_din_last = 0, 
    input fifo_prog_full
);
    reg rd = 0;
    reg [$clog2(`XPHM_DEPTH)-1:0] cnt = 0;
    reg [$clog2(`XPHM_DEPTH)-1:0] next_rd_addr = 0;

    // rd
    always @(posedge clk)
        if (start_pulse)
            rd <= 1;
        else if (rd && cnt==xphm_len_minus_1 && ~fifo_prog_full)
            rd <= 0;

    // cnt
    always @(posedge clk)
        if (start_pulse)
            cnt <= 0;
        else if (rd && ~fifo_prog_full)
            cnt <= cnt+1;

    // next_rd_addr
    always @(posedge clk)
        if (start_pulse)
            next_rd_addr <= xphm_addr;
        else if (rd && ~fifo_prog_full)
            next_rd_addr <= next_rd_addr+1;

    // xphm_rd_en, xphm_rd_last, xphm_rd_addr
    always @(posedge clk) begin
        xphm_rd_en <= (rd && ~fifo_prog_full);
        xphm_rd_last <= (rd && ~fifo_prog_full && cnt==xphm_len_minus_1);
        xphm_rd_addr <= next_rd_addr;
    end

    // fifo_wr_en, fifo_din, fifo_din_last
    always @(posedge clk) begin
        fifo_wr_en <= xphm_dout_vld;
        fifo_din_last <= xphm_dout_last;
        fifo_din <= xphm_dout;
    end
endmodule
