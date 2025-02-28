`timescale 1ns / 1ps
`include "../incl.vh"

//
// Executor FSM
//
module exec_fsm (
    input clk,
    input sys_rst,
    input start_pulse,
    output reg done_pulse = 0,
    output reg [`LATENCY_COUNTER_WIDTH-1:0] conv_latency = 0,
    output reg [`LATENCY_COUNTER_WIDTH-1:0] pool_latency = 0,
    output reg [`LATENCY_COUNTER_WIDTH-1:0] add_latency = 0,
    output reg [`LATENCY_COUNTER_WIDTH-1:0] remap_latency = 0,
    output reg [`LATENCY_COUNTER_WIDTH-1:0] fc_latency = 0,
    // IM read ports
    output reg im_rd_en = 0,
    output reg [$clog2(`INS_RAM_DEPTH)-1:0] im_rd_addr = 0,
    input [`INS_RAM_DATA_WIDTH-1:0] im_dout,
    input im_dout_vld,
    // Conv
    output reg is_conv = 0,
    output reg conv_start_pulse = 0,
    output reg [`INS_RAM_DATA_WIDTH-1:0] conv_ins = 0,
    input conv_done_pulse,
    // Pool
    output reg is_pool = 0,
    output reg pool_start_pulse = 0,
    output reg [`INS_RAM_DATA_WIDTH-1:0] pool_ins = 0,
    input pool_done_pulse,
    // Add
    output reg is_add = 0,
    output reg add_start_pulse = 0,
    output reg [`INS_RAM_DATA_WIDTH-1:0] add_ins = 0,
    input add_done_pulse,
    // Remap
    output reg is_remap = 0,
    output reg remap_start_pulse = 0,
    output reg [`INS_RAM_DATA_WIDTH-1:0] remap_ins = 0,
    input remap_done_pulse,
    // Fc
    output reg is_fc = 0,
    output reg fc_start_pulse = 0,
    output reg [`INS_RAM_DATA_WIDTH-1:0] fc_ins = 0,
    input fc_done_pulse
);
    localparam IDLE = 0, RD_INS = 1, WAIT_INS = 2, WAIT_INS_DONE = 3, DONE = 4;
    (* fsm_encoding = "one_hot" *) reg [2:0] state = IDLE;
    reg exec_last_ins = 0;

    always @(posedge clk)
        if (sys_rst) 
            state <= IDLE;
        else
            case (state)
                IDLE: begin
                    if (start_pulse)
                        state <= RD_INS;
                end
                RD_INS: state <= WAIT_INS;
                WAIT_INS: begin
                    if (im_dout_vld)
                        state <= WAIT_INS_DONE;
                end
                WAIT_INS_DONE: begin
                    if (exec_last_ins)
                        state <= DONE;
                    else if (conv_done_pulse || pool_done_pulse || add_done_pulse || remap_done_pulse || fc_done_pulse)
                        state <= RD_INS;
                end
                DONE: state <= IDLE;
            endcase

    // IM read ports
    reg [$clog2(`INS_RAM_DEPTH)-1:0] next_im_addr = 0;

    always @(posedge clk)
        if (start_pulse)
            next_im_addr <= 0;
        else if (state==RD_INS)
            next_im_addr <= next_im_addr+1;

    always @(posedge clk) begin
        im_rd_en <= (state == RD_INS);
        im_rd_addr <= next_im_addr;
    end

    // exec_last_ins
    always @(posedge clk)
        if (start_pulse)
            exec_last_ins <= 0;
        else if (state==WAIT_INS && im_dout_vld && im_dout[7:0]==`INS_NONE)
            exec_last_ins <= 1;

    // conv_start_pulse, conv_ins, is_conv
    always @(posedge clk) begin
        conv_start_pulse <= (state==WAIT_INS && im_dout_vld && im_dout[7:0]==`INS_CONV);
        if (state==WAIT_INS)
            conv_ins <= im_dout;

        if (conv_start_pulse)
            is_conv <= 1;
        else if (conv_done_pulse)
            is_conv <= 0;
    end

    // conv_latency
    always @(posedge clk)
        if (conv_start_pulse)
            conv_latency <= 0;
        else if (is_conv)
            conv_latency <= conv_latency+1;

    // pool_start_pulse, pool_ins, is_pool
    always @(posedge clk) begin
        pool_start_pulse <= (state==WAIT_INS && im_dout_vld && (im_dout[7:0]==`INS_MAXP || im_dout[7:0]==`INS_AVGP));
        if (state==WAIT_INS)
            pool_ins <= im_dout;
        
        if (pool_start_pulse)
            is_pool <= 1;
        else if (pool_done_pulse)
            is_pool <= 0;
    end

    // pool_latency
    always @(posedge clk)
        if (pool_start_pulse)
            pool_latency <= 0;
        else if (is_pool)
            pool_latency <= pool_latency+1;

    // add_start_pulse, add_ins, is_add
    always @(posedge clk) begin
        add_start_pulse <= (state==WAIT_INS && im_dout_vld && im_dout[7:0]==`INS_ADD);
        if (state==WAIT_INS)
            add_ins <= im_dout;

        if (add_start_pulse)
            is_add <= 1;
        else if (add_done_pulse)
            is_add <= 0;
    end

    // add_latency
    always @(posedge clk)
        if (add_start_pulse)
            add_latency <= 0;
        else if (is_add)
            add_latency <= add_latency+1;

    // remap_start_pulse, remap_ins, is_remap
    always @(posedge clk) begin
        remap_start_pulse <= (state==WAIT_INS && im_dout_vld && im_dout[7:0]==`INS_REMAP);
        if (state==WAIT_INS)
            remap_ins <= im_dout;

        if (remap_start_pulse)
            is_remap <= 1;
        else if (remap_done_pulse)
            is_remap <= 0;
    end

    // remap_latency
    always @(posedge clk)
        if (remap_start_pulse)
            remap_latency <= 0;
        else if (is_remap)
            remap_latency <= remap_latency+1;

    // fc_start_pulse, fc_ins, is_fc
    always @(posedge clk) begin
        fc_start_pulse <= (state==WAIT_INS && im_dout_vld && im_dout[7:0]==`INS_FC);
        if (state==WAIT_INS)
            fc_ins <= im_dout;

        if (fc_start_pulse)
            is_fc <= 1;
        else if (fc_done_pulse)
            is_fc <= 0;
    end

    // fc_latency
    always @(posedge clk)
        if (fc_start_pulse)
            fc_latency <= 0;
        else if (is_fc)
            fc_latency <= fc_latency+1;

    // done_pulse
    always @(posedge clk)
        done_pulse <= (state==DONE);
endmodule

