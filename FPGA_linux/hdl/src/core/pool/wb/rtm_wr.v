`timescale 1ns / 1ps
`include "../../../incl.vh"

//
// This module reads write-back descriptor from the desc fifo.
// It writes the gathered data into RTM according to the desc.
//
module Pool_wb_rtm_wr (
    input clk,
    output done_pulse,
    // Gathered data
    input [`S*`R*8-1:0] gathered_data,
    input gathered_data_vld,
    // desc fifo read ports
    output reg desc_fifo_rd_en = 0,
    input [$clog2(`RTM_DEPTH)-1:0] desc_fifo_dout_addr,
    input desc_fifo_dout_mask,
    input desc_fifo_dout_last,
    input desc_fifo_dout_vld,
    // RTM write ports
    output reg rtm_wr_vld = 0,
    output reg [`S-1:0] rtm_wr_en = 0,
    output reg [`S*$clog2(`RTM_DEPTH)-1:0] rtm_wr_addr = 0,
    output reg [`S*`R*8-1:0] rtm_din = 0
);
    integer i;
    // gathered_data should be delayed 2 cycles to synchronize with the desc
    wire [`S*`R*8-1:0] gathered_data_delay;

    // desc_fifo_rd_en
    always @(posedge clk) 
        desc_fifo_rd_en <= gathered_data_vld;

    // gathered_data_delay
    shift_reg #(2, `S*`R*8) shift_reg_ppus_outs(clk, gathered_data, gathered_data_delay);

    // rtm_wr_vld, rtm_wr_en, rtm_wr_addr, rtm_din
    always @(posedge clk) begin
        rtm_wr_vld <= desc_fifo_dout_vld;
        for (i=0; i<`S; i=i+1)
            rtm_wr_en[i] <= (desc_fifo_dout_vld && ~desc_fifo_dout_mask);
        for (i=0; i<`S; i=i+1)
            rtm_wr_addr[i*$clog2(`RTM_DEPTH)+:$clog2(`RTM_DEPTH)] <= desc_fifo_dout_addr;
        rtm_din <= gathered_data_delay;
    end

    // done_pulse
    reg done_pulse_reg = 0;
    always @(posedge clk)
        done_pulse_reg <= (desc_fifo_dout_vld && desc_fifo_dout_last);
    shift_reg #(5, 1) shift_reg_done_pulse(clk, done_pulse_reg, done_pulse);
endmodule
