`timescale 1ns / 1ps
`include "../../incl.vh"

//
// Memory instances of MXM
//
module mxm_mem (
    input clk,
    // Read ports
    input rd_en,
    input [$clog2(`MXM_DEPTH)-1:0] rd_addr,
    output [`P*2*8-1:0] dout,
    // Write ports
    input wr_en,
    input [$clog2(`MXM_DEPTH)-1:0] wr_addr,
    input [`P*2*8-1:0] din
);
    sdp_uram #(
        .DATA_WIDTH(`P*2*8),
        .DEPTH(`MXM_DEPTH),
        .NUM_PIPE(`MXM_NUM_PIPE)
    ) sdp_uram_inst(
        .clk(clk),
        .wr_en(wr_en),
        .din(din),
        .wr_addr(wr_addr),
        .rd_en(rd_en),
        .rd_addr(rd_addr),
        .dout(dout)
    );
endmodule
