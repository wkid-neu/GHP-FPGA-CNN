`timescale 1ns / 1ps
`include "../../incl.vh"

`define CMD_OPCODE_HEAD 0
`define CMD_OPCODE_ADDR 1

//
// This module reads packet headers from the header fifo.
// It generates RTM access commands and writes them into the cmd fifo.
//
module xbus_pkt_gen_cmd_wr (
    input clk,
    input start_pulse,
    // Instruction
    input [$clog2(`RTM_DEPTH)-1:0] X_addr,
    input [15:0] INC2_minus_1,
    input [15:0] ifm_height,
    // xphs fifo (handshake signal)
    input xphs_fifo_empty,
    output xphs_fifo_rd_en,
    input [`XPHM_DATA_WIDTH-1:0] xphs_fifo_dout,
    input xphs_fifo_dout_last,
    // cmd fifo
    output cmd_fifo_wr_en,
    output cmd_fifo_din_last,
    output cmd_fifo_din_opcode,
    output [`XPHM_DATA_WIDTH-1:0] cmd_fifo_din_operand,
    input cmd_fifo_prog_full
);
    generate
        if (`Q == `R) begin
            xbus_pkt_gen_cmd_wr_1_1 xbus_pkt_gen_cmd_wr_1_1_inst(
                .clk(clk),
                .start_pulse(start_pulse),
                .X_addr(X_addr),
                .INC2_minus_1(INC2_minus_1),
                .ifm_height(ifm_height),
                .xphs_fifo_empty(xphs_fifo_empty),
                .xphs_fifo_rd_en(xphs_fifo_rd_en),
                .xphs_fifo_dout(xphs_fifo_dout),
                .xphs_fifo_dout_last(xphs_fifo_dout_last),
                .cmd_fifo_wr_en(cmd_fifo_wr_en),
                .cmd_fifo_din_last(cmd_fifo_din_last),
                .cmd_fifo_din_opcode(cmd_fifo_din_opcode),
                .cmd_fifo_din_operand(cmd_fifo_din_operand),
                .cmd_fifo_prog_full(cmd_fifo_prog_full)
            );
        end else begin
            xbus_pkt_gen_cmd_wr_N_1 xbus_pkt_gen_cmd_wr_N_1_inst(
                .clk(clk),
                .start_pulse(start_pulse),
                .X_addr(X_addr),
                .INC2_minus_1(INC2_minus_1),
                .ifm_height(ifm_height),
                .xphs_fifo_empty(xphs_fifo_empty),
                .xphs_fifo_rd_en(xphs_fifo_rd_en),
                .xphs_fifo_dout(xphs_fifo_dout),
                .xphs_fifo_dout_last(xphs_fifo_dout_last),
                .cmd_fifo_wr_en(cmd_fifo_wr_en),
                .cmd_fifo_din_last(cmd_fifo_din_last),
                .cmd_fifo_din_opcode(cmd_fifo_din_opcode),
                .cmd_fifo_din_operand(cmd_fifo_din_operand),
                .cmd_fifo_prog_full(cmd_fifo_prog_full)
            );
        end
    endgenerate
endmodule

//
// R : Q = 1 : 1
//
module xbus_pkt_gen_cmd_wr_1_1 (
    input clk,
    input start_pulse,
    // Instruction
    input [$clog2(`RTM_DEPTH)-1:0] X_addr,
    input [15:0] INC2_minus_1,
    input [15:0] ifm_height,
    // xphs fifo (handshake signal)
    input xphs_fifo_empty,
    output reg xphs_fifo_rd_en = 0,
    input [`XPHM_DATA_WIDTH-1:0] xphs_fifo_dout,
    input xphs_fifo_dout_last,
    // cmd fifo
    output reg cmd_fifo_wr_en = 0,
    output reg cmd_fifo_din_last = 0,
    output reg cmd_fifo_din_opcode = 0,
    output reg [`XPHM_DATA_WIDTH-1:0] cmd_fifo_din_operand = 0,
    input cmd_fifo_prog_full
);
    // Parameter Assertions
    initial begin
        if (`Q != `R) begin
            $error("Hyper parameter mismatch, please make sure that Q=R, current values are: Q = %0d, R = %0d", `Q, `R);
            $finish;
        end
    end

    localparam IDLE = 0, FETCH_HEAD = 1, WR_ADDR = 2, DONE = 3;
    reg [1:0] state = IDLE;

    reg [15:0] len_cnt = 0;
    reg [15:0] grp_cnt = 0;
    reg [`XPHM_DATA_WIDTH-1:0] curr_xph = 0;
    reg curr_is_last = 0;
    reg [15:0] curr_len_minus_1 = 0;

    reg [$clog2(`RTM_DEPTH)-1:0] base_addr = 0;
    wire [$clog2(`RTM_DEPTH)-1:0] addr;

    assign addr = base_addr+len_cnt[15:0];

    always @(posedge clk)
        if (start_pulse)
            state <= FETCH_HEAD;
        else
            case (state)
                FETCH_HEAD: begin
                    if (~xphs_fifo_empty && ~cmd_fifo_prog_full)
                        state <= WR_ADDR;
                end
                WR_ADDR: begin
                    if (~cmd_fifo_prog_full && grp_cnt==INC2_minus_1 && len_cnt==curr_len_minus_1) begin
                        if (curr_is_last)
                            state <= DONE;
                        else
                            state <= FETCH_HEAD;
                    end
                end
                DONE: state <= IDLE;
                default: state <= IDLE;
            endcase

    // xphs_fifo_rd_en
    always @(posedge clk)
        xphs_fifo_rd_en <= (state==FETCH_HEAD && ~xphs_fifo_empty && ~cmd_fifo_prog_full);

    // curr_xph, curr_is_last, curr_len_minus_1
    always @(posedge clk) begin
        if (state==FETCH_HEAD && ~xphs_fifo_empty && ~cmd_fifo_prog_full) begin
            curr_xph <= xphs_fifo_dout;
            curr_is_last <= xphs_fifo_dout_last;
            curr_len_minus_1 <= xphs_fifo_dout[`XPHM_X_a__WIDTH+:`XPHM_len_per_chan_WIDTH]-1;
        end
    end

    // len_cnt
    always @(posedge clk)
        if (state==WR_ADDR && ~cmd_fifo_prog_full) begin
            if (len_cnt==curr_len_minus_1)
                len_cnt <= 0;
            else
                len_cnt <= len_cnt+1;
        end

    // grp_cnt
    always @(posedge clk)
        if (state==FETCH_HEAD && ~xphs_fifo_empty && ~cmd_fifo_prog_full)
            grp_cnt <= 0;
        else if (state==WR_ADDR && ~cmd_fifo_prog_full && len_cnt==curr_len_minus_1)
            grp_cnt <= grp_cnt+1;

    // base_addr
    always @(posedge clk)
        if (state==FETCH_HEAD && ~xphs_fifo_empty && ~cmd_fifo_prog_full)
            base_addr <= X_addr+xphs_fifo_dout[`XPHM_X_a__WIDTH-1:0];
        else if (state==WR_ADDR && ~cmd_fifo_prog_full && len_cnt==curr_len_minus_1)
            base_addr <= base_addr+ifm_height;

    // cmd_fifo_wr_en, cmd_fifo_din_last, cmd_fifo_din_opcode, cmd_fifo_din_operand
    always @(posedge clk) begin
        cmd_fifo_wr_en <= (state==FETCH_HEAD && ~xphs_fifo_empty && ~cmd_fifo_prog_full) || (state==WR_ADDR && ~cmd_fifo_prog_full);
        cmd_fifo_din_last <= (state==WR_ADDR && ~cmd_fifo_prog_full && grp_cnt==INC2_minus_1 && len_cnt==curr_len_minus_1 && curr_is_last);
        cmd_fifo_din_opcode <= (state==FETCH_HEAD) ? `CMD_OPCODE_HEAD : `CMD_OPCODE_ADDR;
        cmd_fifo_din_operand <= (state==FETCH_HEAD) ? xphs_fifo_dout : addr;
    end
endmodule

//
// R : Q = N : 1
// N is 2, 4, 8, ...
//
module xbus_pkt_gen_cmd_wr_N_1 (
    input clk,
    input start_pulse,
    // Instruction
    input [$clog2(`RTM_DEPTH)-1:0] X_addr,
    input [15:0] INC2_minus_1,
    input [15:0] ifm_height,
    // xphs fifo (handshake signal)
    input xphs_fifo_empty,
    output reg xphs_fifo_rd_en = 0,
    input [`XPHM_DATA_WIDTH-1:0] xphs_fifo_dout,
    input xphs_fifo_dout_last,
    // cmd fifo
    output reg cmd_fifo_wr_en = 0,
    output reg cmd_fifo_din_last = 0,
    output reg cmd_fifo_din_opcode = 0,
    output reg [`XPHM_DATA_WIDTH-1:0] cmd_fifo_din_operand = 0,
    input cmd_fifo_prog_full
);
    // Parameter Assertions
    initial begin
        if (`R % `Q != 0) begin
            $error("Hyper parameter mismatch, please make sure that R is a multiple of Q, current values are: Q = %0d, R = %0d", `Q, `R);
            $finish;
        end
    end

    localparam N = `R/`Q;

    localparam IDLE = 0, FETCH_HEAD = 1, WR_ADDR = 2, DONE = 3;
    reg [1:0] state = IDLE;

    reg [15:0] len_cnt = 0;
    reg [15:0] grp_cnt = 0;
    reg [`XPHM_DATA_WIDTH-1:0] curr_xph = 0;
    reg curr_is_last = 0;
    reg [15:0] curr_len_minus_1 = 0;
    reg [$clog2(N)-1:0] curr_from_seg = 0;

    reg [$clog2(`RTM_DEPTH)-1:0] base_addr = 0;
    wire [$clog2(`RTM_DEPTH)-1:0] addr;
    wire [$clog2(N)-1:0] seg_id;

    wire [15:0] shifted_len_cnt;

    assign shifted_len_cnt = len_cnt+curr_from_seg;
    assign addr = base_addr+shifted_len_cnt[15:$clog2(N)];
    assign seg_id = shifted_len_cnt[$clog2(N)-1:0];

    always @(posedge clk)
        if (start_pulse)
            state <= FETCH_HEAD;
        else
            case (state)
                FETCH_HEAD: begin
                    if (~xphs_fifo_empty && ~cmd_fifo_prog_full)
                        state <= WR_ADDR;
                end
                WR_ADDR: begin
                    if (~cmd_fifo_prog_full && grp_cnt==INC2_minus_1 && len_cnt==curr_len_minus_1) begin
                        if (curr_is_last)
                            state <= DONE;
                        else
                            state <= FETCH_HEAD;
                    end
                end
                DONE: state <= IDLE;
                default: state <= IDLE;
            endcase

    // xphs_fifo_rd_en
    always @(posedge clk)
        xphs_fifo_rd_en <= (state==FETCH_HEAD && ~xphs_fifo_empty && ~cmd_fifo_prog_full);

    // curr_xph, curr_is_last, curr_len_minus_1, curr_from_seg
    always @(posedge clk) begin
        if (state==FETCH_HEAD && ~xphs_fifo_empty && ~cmd_fifo_prog_full) begin
            curr_xph <= xphs_fifo_dout;
            curr_is_last <= xphs_fifo_dout_last;
            curr_len_minus_1 <= xphs_fifo_dout[`XPHM_X_a__WIDTH+:`XPHM_len_per_chan_WIDTH]-1;
            curr_from_seg <= xphs_fifo_dout[$clog2(N)-1:0];
        end
    end

    // len_cnt
    always @(posedge clk)
        if (state==WR_ADDR && ~cmd_fifo_prog_full) begin
            if (len_cnt==curr_len_minus_1)
                len_cnt <= 0;
            else
                len_cnt <= len_cnt+1;
        end

    // grp_cnt
    always @(posedge clk)
        if (state==FETCH_HEAD && ~xphs_fifo_empty && ~cmd_fifo_prog_full)
            grp_cnt <= 0;
        else if (state==WR_ADDR && ~cmd_fifo_prog_full && len_cnt==curr_len_minus_1)
            grp_cnt <= grp_cnt+1;

    // base_addr
    always @(posedge clk)
        if (state==FETCH_HEAD && ~xphs_fifo_empty && ~cmd_fifo_prog_full)
            base_addr <= X_addr+xphs_fifo_dout[15:$clog2(N)];
        else if (state==WR_ADDR && ~cmd_fifo_prog_full && len_cnt==curr_len_minus_1)
            base_addr <= base_addr+ifm_height;

    // cmd_fifo_wr_en, cmd_fifo_din_last, cmd_fifo_din_opcode, cmd_fifo_din_operand
    always @(posedge clk) begin
        cmd_fifo_wr_en <= (state==FETCH_HEAD && ~xphs_fifo_empty && ~cmd_fifo_prog_full) || (state==WR_ADDR && ~cmd_fifo_prog_full);
        cmd_fifo_din_last <= (state==WR_ADDR && ~cmd_fifo_prog_full && grp_cnt==INC2_minus_1 && len_cnt==curr_len_minus_1 && curr_is_last);
        cmd_fifo_din_opcode <= (state==FETCH_HEAD) ? `CMD_OPCODE_HEAD : `CMD_OPCODE_ADDR;
        cmd_fifo_din_operand <= (state==FETCH_HEAD) ? xphs_fifo_dout : {seg_id, addr};
    end
endmodule
