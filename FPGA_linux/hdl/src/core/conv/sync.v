`timescale 1ns / 1ps
`include "../../incl.vh"

//
// This module reads column vectors and row vectors from CWM and MXM
// and then write them to the Weight-Activation
//
module Conv_sync (
    input clk,
    // instruction
    input start_pulse,
    input [31:0] W_addr,
    input [15:0] n_X_rnd_minus_1,
    input [15:0] n_W_rnd_minus_1,
    input [15:0] vec_size2_minus_1,  // INC*KH*KW/2-1
    input [31:0] W_n_bytes,
    input [$clog2(`CWM_DEPTH)-1:0] cwm_sta_addr,
    // CWM control ports
    output reg cwm_ic_d2c_start_pulse = 0,
    output reg [31:0] cwm_ic_d2c_d_addr = 0,
    output reg [31:0] cwm_ic_d2c_c_addr = 0,
    output reg [31:0] cwm_ic_d2c_n_bytes = 0,
    // CWM read ports
    input [$clog2(`CWM_DEPTH):0] cwm_wr_ptr,
    output cwm_rd_en,
    output [$clog2(`CWM_DEPTH)-1:0] cwm_rd_addr,
    input [`M*4*8-1:0] cwm_dout,
    input cwm_dout_vld,
    // MXM read ports
    output reg mxm_rd_en = 0,
    output reg mxm_rd_last_rnd = 0,
    input [`P*2*8-1:0] mxm_dout,
    input mxm_dout_vld,
    input mxm_empty,
    input mxm_almost_empty,
    // Weight-Activation write ports
    output wx_fifo_wr_en ,
    output [`SA_TAG_DW+`M*4*8+`P*2*8-1:0] wx_fifo_din,
    input wx_fifo_prog_full
);
    reg cwm_rd_en_reg = 0;
    reg [$clog2(`CWM_DEPTH)-1:0] cwm_rd_addr_reg = 0;

    reg rd = 0;
    reg [15:0] vec_cnt = 0;
    reg [15:0] w_cnt = 0;
    reg [15:0] x_cnt = 0;
    reg [$clog2(`CWM_DEPTH)-1:0] next_w_addr = 0;

    wire is_dyn;
    wire vec_cnt_full, w_cnt_full, x_cnt_full;
    wire next_w_ready, next_x_ready;
    // start_pulse should be delayed for several cycles to clear the cwm_wr_ptr
    wire fsm_start_pulse;

    assign is_dyn = W_addr[31];
    assign vec_cnt_full = (vec_cnt==vec_size2_minus_1);
    assign w_cnt_full = (w_cnt==n_W_rnd_minus_1);
    assign x_cnt_full = (x_cnt==n_X_rnd_minus_1);
    assign next_w_ready = ~is_dyn ? 1 : (cwm_wr_ptr>next_w_addr);
    assign next_x_ready = ~mxm_empty && (~mxm_almost_empty || ~mxm_rd_en);
    shift_reg #(10, 1) shift_reg_start_pulse (clk, start_pulse, fsm_start_pulse);

    // rd
    always @(posedge clk)
        if (fsm_start_pulse)
            rd <= 1;
        else if (rd && ~wx_fifo_prog_full && vec_cnt_full && w_cnt_full && x_cnt_full && next_w_ready && next_x_ready)
            rd <= 0;

    //
    // Counters
    //
    // vec_cnt
    always @(posedge clk)
        if (rd && ~wx_fifo_prog_full && next_w_ready && next_x_ready) begin
            if (vec_cnt_full)
                vec_cnt <= 0;
            else
                vec_cnt <= vec_cnt+1; 
        end

    // w_cnt
    always @(posedge clk)
        if (rd && ~wx_fifo_prog_full && next_w_ready && next_x_ready && vec_cnt_full) begin
            if (w_cnt_full)
                w_cnt <= 0;
            else
                w_cnt <= w_cnt+1; 
        end

    // x_cnt
    always @(posedge clk)
        if (start_pulse) 
            x_cnt <= 0;
        else if (rd && ~wx_fifo_prog_full && next_w_ready && next_x_ready && vec_cnt_full && w_cnt_full) 
            x_cnt <= x_cnt+1;

    //
    // CWM control ports
    //
    always @(posedge clk) begin
        cwm_ic_d2c_start_pulse <= (start_pulse && is_dyn);
        if (start_pulse) begin
            cwm_ic_d2c_d_addr <= W_addr;
            cwm_ic_d2c_c_addr <= cwm_sta_addr;
            cwm_ic_d2c_n_bytes <= W_n_bytes;
        end
    end

    //
    // CWM read ports
    //
    // next_w_addr
    always @(posedge clk)
        if (start_pulse)
            next_w_addr <= is_dyn ? cwm_sta_addr : W_addr;
        else if (rd && ~wx_fifo_prog_full && next_w_ready && next_x_ready) begin
            if (w_cnt_full && vec_cnt_full)
                next_w_addr <= is_dyn ? cwm_sta_addr : W_addr;
            else
                next_w_addr <= next_w_addr+1;
        end

    // cwm_rd_en_reg, cwm_rd_addr_reg
    always @(posedge clk) begin
        cwm_rd_en_reg <= (rd && ~wx_fifo_prog_full && next_w_ready && next_x_ready);
        cwm_rd_addr_reg <= next_w_addr;
    end

`ifdef M32P64Q16R16S8
    // Add additional pipeline stages for high performance
    shift_reg #(2, 1) shift_reg_cwm_rd_en(clk, cwm_rd_en_reg, cwm_rd_en);
    shift_reg #(2, $clog2(`CWM_DEPTH)) shift_reg_cwm_rd_addr(clk, cwm_rd_addr_reg, cwm_rd_addr);
`elsif M32P96Q16R16S8
    // Add additional pipeline stages for high performance
    shift_reg #(2, 1) shift_reg_cwm_rd_en(clk, cwm_rd_en_reg, cwm_rd_en);
    shift_reg #(2, $clog2(`CWM_DEPTH)) shift_reg_cwm_rd_addr(clk, cwm_rd_addr_reg, cwm_rd_addr);
`elsif M64P64Q16R16S8
    // Add additional pipeline stages for high performance
    shift_reg #(2, 1) shift_reg_cwm_rd_en(clk, cwm_rd_en_reg, cwm_rd_en);
    shift_reg #(2, $clog2(`CWM_DEPTH)) shift_reg_cwm_rd_addr(clk, cwm_rd_addr_reg, cwm_rd_addr);
`else
    assign cwm_rd_en = cwm_rd_en_reg;
    assign cwm_rd_addr = cwm_rd_addr_reg;
`endif

    //
    // MXM read ports
    // Unlike CWM, MXM mxm_rd_en should read its value at next clock cycle.
    // Therefore,  MXM read ports can not be delayed.
    //
    always @(posedge clk) begin
        mxm_rd_en <= (rd && ~wx_fifo_prog_full && next_w_ready && next_x_ready);
        mxm_rd_last_rnd <= w_cnt_full;
    end

    //
    // Weight-Activation write ports
    //
    reg [`SA_TAG_DW-1:0] vec_tag;

    // Outputs from MXM and CWM should be synchronized
`ifdef M32P64Q16R16S8
    // The number of additional pipeline stage should synchronize with CWM read ports.
    // Currently the number is 2
    localparam MXM_NUM_PIPE = `CWM_NUM_PIPE-`MXM_NUM_PIPE-1+2;
    localparam TAG_NUM_PIPE = `CWM_NUM_PIPE+1+2;
`elsif M32P96Q16R16S8
    // The number of additional pipeline stage should synchronize with CWM read ports.
    // Currently the number is 2
    localparam MXM_NUM_PIPE = `CWM_NUM_PIPE-`MXM_NUM_PIPE-1+2;
    localparam TAG_NUM_PIPE = `CWM_NUM_PIPE+1+2;
`elsif M64P64Q16R16S8
    // The number of additional pipeline stage should synchronize with CWM read ports.
    // Currently the number is 2
    localparam MXM_NUM_PIPE = `CWM_NUM_PIPE-`MXM_NUM_PIPE-1+2;
    localparam TAG_NUM_PIPE = `CWM_NUM_PIPE+1+2;
`else
    localparam MXM_NUM_PIPE = `CWM_NUM_PIPE-`MXM_NUM_PIPE-1;
    localparam TAG_NUM_PIPE = `CWM_NUM_PIPE+1;
`endif
    wire [`P*2*8-1:0] mxm_dout_sync;
    wire vec_tag_sync;

    // mxm_dout_sync
    shift_reg #(
        .DELAY(MXM_NUM_PIPE),
        .DATA_WIDTH(`P*2*8)
    ) shift_reg_mxm_dout_sync(
        .clk(clk),
        .i(mxm_dout),
        .o(mxm_dout_sync)
    );

    // vec_tag_sync
    shift_reg #(
        .DELAY(TAG_NUM_PIPE),
        .DATA_WIDTH(`SA_TAG_DW)
    ) shift_reg_vec_tag_sync(
        .clk(clk),
        .i(vec_tag),
        .o(vec_tag_sync)
    );

    // vec_tag
    always @(posedge clk)
        vec_tag <= vec_cnt_full ? `SA_TAG_END : `SA_TAG_NONE;

`ifdef M32P64Q16R16S8
    // Add additional pipeline stages for high performance
    shift_reg #(2, 1) shift_reg_wx_fifo_wr_en(clk, cwm_dout_vld, wx_fifo_wr_en);
    shift_reg #(2, `SA_TAG_DW+`M*4*8+`P*2*8) shift_reg_wx_fifo_wr_din(clk, {vec_tag_sync, cwm_dout, mxm_dout_sync}, wx_fifo_din);
`elsif M32P96Q16R16S8
    // Add additional pipeline stages for high performance
    shift_reg #(2, 1) shift_reg_wx_fifo_wr_en(clk, cwm_dout_vld, wx_fifo_wr_en);
    shift_reg #(2, `SA_TAG_DW+`M*4*8+`P*2*8) shift_reg_wx_fifo_wr_din(clk, {vec_tag_sync, cwm_dout, mxm_dout_sync}, wx_fifo_din);
`elsif M64P64Q16R16S8
    // Add additional pipeline stages for high performance
    shift_reg #(2, 1) shift_reg_wx_fifo_wr_en(clk, cwm_dout_vld, wx_fifo_wr_en);
    shift_reg #(2, `SA_TAG_DW+`M*4*8+`P*2*8) shift_reg_wx_fifo_wr_din(clk, {vec_tag_sync, cwm_dout, mxm_dout_sync}, wx_fifo_din);
`else
    assign wx_fifo_wr_en = cwm_dout_vld;
    assign wx_fifo_din = {vec_tag_sync, cwm_dout, mxm_dout_sync};
`endif
endmodule
