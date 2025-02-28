`timescale 1ns / 1ps
`include "../../incl.vh"

//
// Write results back to RTM
//
module Fc_wb (
    input clk,
    input start_pulse,
    output done_pulse,
    // instruction
    input [$clog2(`RTM_DEPTH)-1:0] y_addr,
    // ppus outputs
    input [`DDR_AXIS_DATA_WIDTH/8*8-1:0] ppus_outs,
    input ppus_out_vld,
    input ppus_out_last,
    // RTM write ports
    output rtm_wr_vld,
    output [`S-1:0] rtm_wr_en,
    output [`S*$clog2(`RTM_DEPTH)-1:0] rtm_wr_addr,
    output [`S*`R*8-1:0] rtm_din
);
    generate
        if (`DDR_AXIS_DATA_WIDTH/8 == `S*`R) begin  // 1:1
            Fc_wb_1_1 Fc_wb_1_1_inst(
                .clk(clk),
                .start_pulse(start_pulse),
                .done_pulse(done_pulse),
                .y_addr(y_addr),
                .ppus_outs(ppus_outs),
                .ppus_out_vld(ppus_out_vld),
                .ppus_out_last(ppus_out_last),
                .rtm_wr_vld(rtm_wr_vld),
                .rtm_wr_en(rtm_wr_en),
                .rtm_wr_addr(rtm_wr_addr),
                .rtm_din(rtm_din)
            );
        end else begin  // N:1
            Fc_wb_N_1 Fc_wb_N_1_inst(
                .clk(clk),
                .start_pulse(start_pulse),
                .done_pulse(done_pulse),
                .y_addr(y_addr),
                .ppus_outs(ppus_outs),
                .ppus_out_vld(ppus_out_vld),
                .ppus_out_last(ppus_out_last),
                .rtm_wr_vld(rtm_wr_vld),
                .rtm_wr_en(rtm_wr_en),
                .rtm_wr_addr(rtm_wr_addr),
                .rtm_din(rtm_din)
            );
        end
    endgenerate
endmodule

//
// RTM bandwidth : write back bandwidth = 1:1,
// which means DDR_AXIS_DATA_WIDTH/8 == S*R
//
module Fc_wb_1_1 (
    input clk,
    input start_pulse,
    output done_pulse,
    // instruction
    input [$clog2(`RTM_DEPTH)-1:0] y_addr,
    // ppus outputs
    input [`DDR_AXIS_DATA_WIDTH/8*8-1:0] ppus_outs,
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
            next_addr <= y_addr;
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

//
// RTM bandwidth : write back bandwidth = N:1 and
// DDR_AXIS_DATA_WIDTH/8 is a multiple of R
//
module Fc_wb_N_1 (
    input clk,
    input start_pulse,
    output done_pulse,
    // instruction
    input [$clog2(`RTM_DEPTH)-1:0] y_addr,
    // ppus outputs
    input [`DDR_AXIS_DATA_WIDTH/8*8-1:0] ppus_outs,
    input ppus_out_vld,
    input ppus_out_last,
    // RTM write ports
    output reg rtm_wr_vld = 0,
    output reg [`S-1:0] rtm_wr_en = 0,
    output reg [`S*$clog2(`RTM_DEPTH)-1:0] rtm_wr_addr = 0,
    output reg [`S*`R*8-1:0] rtm_din = 0
);
    localparam N = (`S*`R)/(`DDR_AXIS_DATA_WIDTH/8);
    reg [$clog2(`RTM_DEPTH)-1:0] next_addr = 0;
    reg [N-1:0] shreg = 0;
    integer i, j;

    // shreg
    always @(posedge clk)
        if (start_pulse)
            shreg <= {{{N-1}{1'b0}}, 1'b1};
        else if (ppus_out_vld)
            shreg <= {shreg[N-2:0], shreg[N-1]};

    // next_addr
    always @(posedge clk)
        if (start_pulse)
            next_addr <= y_addr;
        else if (ppus_out_vld && shreg[N-1])
            next_addr <= next_addr+1;

    // rtm_wr_vld, rtm_wr_en, rtm_wr_addr, rtm_din
    always @(posedge clk) begin
        rtm_wr_vld <= ppus_out_vld;
        for (i=0; i<N; i=i+1)
            for (j=0; j<`S/N; j=j+1)
                rtm_wr_en[i*`S/N+j] <= (ppus_out_vld && shreg[i]);
        for (i=0; i<`S; i=i+1)
            rtm_wr_addr[i*$clog2(`RTM_DEPTH)+:$clog2(`RTM_DEPTH)] <= next_addr;
        for (i=0; i<N; i=i+1)
            rtm_din[i*`DDR_AXIS_DATA_WIDTH+:`DDR_AXIS_DATA_WIDTH] <= ppus_outs;
    end

    // done_pulse
    reg done_pulse_reg = 0;
    always @(posedge clk)
        done_pulse_reg <= (ppus_out_vld && ppus_out_last);
    shift_reg #(5, 1) shift_reg_inst(clk, done_pulse_reg, done_pulse);
endmodule
