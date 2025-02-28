`timescale 1ns / 1ps
`include "../../incl.vh"

//
// Memory instances of BM
//
module bm_mem (
    input clk,
    // Write ports
    input wr_en,
    input [$clog2(`BM_DEPTH)-1:0] wr_addr,
    input [`BM_DATA_WIDTH-1:0] din, 
    // Read ports
    input rd_en,
    input [$clog2(`BM_DEPTH)-1:0] rd_addr,
    output [`BM_DATA_WIDTH-1:0] dout
);
    sdp_bram #(
        .DATA_WIDTH(`BM_DATA_WIDTH),
        .DEPTH(`BM_DEPTH),
        .NUM_PIPE(`BM_NUM_PIPE)
    ) sdp_bram_inst(
    	.clk(clk),
        .rd_en(rd_en),
        .rd_addr(rd_addr),
        .dout(dout),
        .wr_en(wr_en),
        .din(din),
        .wr_addr(wr_addr)
    );
endmodule
