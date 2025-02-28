`timescale 1ns / 1ps
`include "../../incl.vh"

//
// Memory instances of IM
//
module im_mem (
    input clk,
    // write ports
    input wr_en,
    input [$clog2(`INS_RAM_DEPTH)-1:0] wr_addr,
    input [`INS_RAM_DATA_WIDTH-1:0] din,
    // read ports
    input rd_en,
    input [$clog2(`INS_RAM_DEPTH)-1:0] rd_addr,
    output [`INS_RAM_DATA_WIDTH-1:0] dout
);
    sdp_bram  #(
        .DATA_WIDTH(`INS_RAM_DATA_WIDTH),
        .DEPTH(`INS_RAM_DEPTH),
        .NUM_PIPE(`INS_RAM_NUM_PIPE)
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
