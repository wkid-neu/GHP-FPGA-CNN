`timescale 1ns / 1ps
`include "../../incl.vh"

//
// Memory instances of CWM
//
module cwm_mem (
    input clk,
    // Read ports
    input rd_en,
    input [$clog2(`CWM_DEPTH)-1:0] rd_addr,
    output [`M*4*8-1:0] dout,
    output dout_vld,
    // Write ports
    input wr_en,
    input [$clog2(`CWM_DEPTH)-1:0] wr_addr,
    input [`M*4*8-1:0] din
);
    sdp_uram #(
        .DATA_WIDTH(`M*4*8),
        .DEPTH(`CWM_DEPTH),
        .NUM_PIPE(`CWM_NUM_PIPE)
    ) sdp_uram_inst(
        .clk(clk),
        .wr_en(wr_en),
        .din(din),
        .wr_addr(wr_addr),
        .rd_en(rd_en),
        .rd_addr(rd_addr),
        .dout(dout)
    );

    shift_reg #(`CWM_NUM_PIPE+1, 1) shift_reg_inst(clk, rd_en, dout_vld);
endmodule
