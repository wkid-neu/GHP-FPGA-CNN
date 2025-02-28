`timescale 1ns / 1ps
`include "../../incl.vh"

//
// Write back to the RTM
//
module Remap_wb (
    input clk,
    // instruction
    input start_pulse,
    output done_pulse,
    input [$clog2(`RTM_DEPTH)-1:0] Y_addr,
    // ppus outputs
    input [`S*`R*8-1:0] ppus_outs,
    input ppus_out_vld,
    input ppus_out_last,
    // RTM write ports
    output reg rtm_wr_vld = 0,
    output reg [`S-1:0] rtm_wr_en = 0,
    output reg [`S*$clog2(`RTM_DEPTH)-1:0] rtm_wr_addr = 0,
    output reg [`S*`R*8-1:0] rtm_din = 0
);
    reg [$clog2(`RTM_DEPTH)-1:0] next_addr = 0;
    integer i;

    // next_addr
    always @(posedge clk)
        if (start_pulse)
            next_addr <= Y_addr;
        else if (ppus_out_vld)
            next_addr <= next_addr+1;

    // rtm_wr_vld, rtm_wr_en, rtm_wr_addr, rtm_din
    always @(posedge clk) begin
        rtm_wr_vld <= ppus_out_vld;
        for (i=0; i<`S; i=i+1) begin
            rtm_wr_en[i] <= ppus_out_vld;
            rtm_wr_addr[i*$clog2(`RTM_DEPTH)+:$clog2(`RTM_DEPTH)] <= next_addr;
        end
        rtm_din <= ppus_outs;
    end

    // done_pulse
    reg done_pulse_reg = 0;
    always @(posedge clk)
        done_pulse_reg <= (ppus_out_vld && ppus_out_last);
    shift_reg #(5, 1) shift_reg_inst(clk, done_pulse_reg, done_pulse);
endmodule
