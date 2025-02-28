`timescale 1ns / 1ps
`include "../../incl.vh"

`define CMD_OPCODE_HEAD 0
`define CMD_OPCODE_ADDR 1

//
// This module reads commands from cmd fifo.
// It reads RTM according to commands and dispatches packets. 
//
module xbus_pkt_gen_disp (
    input clk,
    input start_pulse,
    // bus
    output [`XBUS_TAG_WIDTH-1:0] pkt_tag,
    output [`Q*`S*8-1:0] pkt_data,
    // stall
    input stall,
    // cmd fifo (handshake signals)
    output cmd_fifo_rd_en,
    input cmd_fifo_dout_opcode,
    input [`XPHM_DATA_WIDTH-1:0] cmd_fifo_dout_operand,
    input cmd_fifo_dout_last,
    input cmd_fifo_empty,
    // rtm read ports
    output rtm_rd_vld,
    output [`S-1:0] rtm_rd_en,
    output [`XPHM_DATA_WIDTH+$clog2(`R/`Q)+1:0] rtm_rd_att,
    output [`S*$clog2(`RTM_DEPTH)-1:0] rtm_rd_addr,
    input [`S*`R*8-1:0] rtm_dout,
    input [`XPHM_DATA_WIDTH+$clog2(`R/`Q)+1:0] rtm_dout_att,
    input rtm_dout_vld
);
    generate
        if (`Q == `R) begin
            xbus_pkt_gen_disp_1_1 xbus_pkt_gen_disp_1_1_inst(
                .clk(clk),
                .start_pulse(start_pulse),
                .pkt_tag(pkt_tag),
                .pkt_data(pkt_data),
                .stall(stall),
                .cmd_fifo_rd_en(cmd_fifo_rd_en),
                .cmd_fifo_dout_opcode(cmd_fifo_dout_opcode),
                .cmd_fifo_dout_operand(cmd_fifo_dout_operand),
                .cmd_fifo_dout_last(cmd_fifo_dout_last),
                .cmd_fifo_empty(cmd_fifo_empty),
                .rtm_rd_vld(rtm_rd_vld),
                .rtm_rd_en(rtm_rd_en),
                .rtm_rd_att(rtm_rd_att),
                .rtm_rd_addr(rtm_rd_addr),
                .rtm_dout(rtm_dout),
                .rtm_dout_att(rtm_dout_att),
                .rtm_dout_vld(rtm_dout_vld)
            );
        end else begin
            xbus_pkt_gen_disp_N_1 xbus_pkt_gen_disp_N_1_inst(
                .clk(clk),
                .start_pulse(start_pulse),
                .pkt_tag(pkt_tag),
                .pkt_data(pkt_data),
                .stall(stall),
                .cmd_fifo_rd_en(cmd_fifo_rd_en),
                .cmd_fifo_dout_opcode(cmd_fifo_dout_opcode),
                .cmd_fifo_dout_operand(cmd_fifo_dout_operand),
                .cmd_fifo_dout_last(cmd_fifo_dout_last),
                .cmd_fifo_empty(cmd_fifo_empty),
                .rtm_rd_vld(rtm_rd_vld),
                .rtm_rd_en(rtm_rd_en),
                .rtm_rd_att(rtm_rd_att),
                .rtm_rd_addr(rtm_rd_addr),
                .rtm_dout(rtm_dout),
                .rtm_dout_att(rtm_dout_att),
                .rtm_dout_vld(rtm_dout_vld)
            );
        end
    endgenerate
endmodule

//
// R : Q = 1 : 1
//
module xbus_pkt_gen_disp_1_1 (
    input clk,
    input start_pulse,
    // bus
    output reg [`XBUS_TAG_WIDTH-1:0] pkt_tag = 0,
    output reg [`Q*`S*8-1:0] pkt_data = 0,
    // stall
    input stall,
    // cmd fifo (handshake signals)
    output reg cmd_fifo_rd_en = 0,
    input cmd_fifo_dout_opcode,
    input [`XPHM_DATA_WIDTH-1:0] cmd_fifo_dout_operand,
    input cmd_fifo_dout_last,
    input cmd_fifo_empty,
    // rtm read ports
    output reg rtm_rd_vld = 0,
    output reg [`S-1:0] rtm_rd_en = 0,
    output [`XPHM_DATA_WIDTH+$clog2(`R/`Q)+1:0] rtm_rd_att,
    output reg [`S*$clog2(`RTM_DEPTH)-1:0] rtm_rd_addr = 0,
    input [`S*`R*8-1:0] rtm_dout,
    input [`XPHM_DATA_WIDTH+$clog2(`R/`Q)+1:0] rtm_dout_att,
    input rtm_dout_vld
);
    // Parameter Assertions
    initial begin
        if (`Q != `R) begin
            $error("Hyper parameter mismatch, please make sure that Q=R, current values are: Q = %0d, R = %0d", `Q, `R);
            $finish;
        end
    end

    localparam RD_IDLE = 0, RD_CMD = 1, RD_END = 2, RD_DONE = 3;
    reg [1:0] rd_state = RD_IDLE;
    reg end_vld = 0;

    localparam FLAG_HEAD = 3, FLAG_BODY = 2, FLAG_END = 1, FLAG_INVALID = 0;
    reg [1:0] flag = FLAG_INVALID;
    reg [`XPHM_DATA_WIDTH-1:0] head = 0;

    integer i;

    // State Machine
    always @(posedge clk)
        if (start_pulse)
            rd_state <= RD_CMD;
        else
            case (rd_state)
                RD_CMD: begin
                    if (cmd_fifo_rd_en && ~cmd_fifo_empty && cmd_fifo_dout_last)
                        rd_state <= RD_END;
                end
                RD_END: rd_state <= RD_DONE;
                RD_DONE: rd_state <= RD_IDLE;
                default: rd_state <= RD_IDLE;
            endcase

    //
    // Signals controlled by state machine.
    //
    // cmd_fifo_rd_en, end_vld
    always @(posedge clk) begin
        cmd_fifo_rd_en <= (rd_state==RD_CMD && ~cmd_fifo_empty && ~stall);
        end_vld <= rd_state==RD_END;
    end

    //
    // Inputs of pipeline
    //
    // rtm_rd_vld, rtm_rd_en, rtm_rd_addr, flag
    always @(posedge clk) begin
        rtm_rd_vld <= (cmd_fifo_rd_en && ~cmd_fifo_empty && cmd_fifo_dout_opcode==`CMD_OPCODE_ADDR);
        for (i=0; i<`S; i=i+1)
            rtm_rd_en[i] <= (cmd_fifo_rd_en && ~cmd_fifo_empty && cmd_fifo_dout_opcode==`CMD_OPCODE_ADDR);
        for (i=0; i<`S; i=i+1)
            rtm_rd_addr[i*$clog2(`RTM_DEPTH)+:$clog2(`RTM_DEPTH)] <= cmd_fifo_dout_operand[$clog2(`RTM_DEPTH)-1:0];
        
        if (cmd_fifo_rd_en && ~cmd_fifo_empty) begin
            if (cmd_fifo_dout_opcode==`CMD_OPCODE_ADDR)
                flag <= FLAG_BODY;
            else
                flag <= FLAG_HEAD;
        end else if (end_vld)
            flag <= FLAG_END;
        else
            flag <= FLAG_INVALID;

        if (cmd_fifo_rd_en && ~cmd_fifo_empty && cmd_fifo_dout_opcode==`CMD_OPCODE_HEAD)
            head <= cmd_fifo_dout_operand[`XPHM_DATA_WIDTH-1:0];
    end

    assign rtm_rd_att = {flag, head};

    wire [1:0] piped_flag;
    wire [`XPHM_DATA_WIDTH-1:0] piped_head;
    assign {piped_flag, piped_head} = rtm_dout_att;

    //
    // Outputs
    //
    // pkt_data
    always @(posedge clk)
        case (piped_flag)
            FLAG_HEAD: pkt_data <= piped_head;
            FLAG_BODY: pkt_data <= rtm_dout;
        endcase

    // pkt_tag
    always @(posedge clk)
        case (piped_flag)
            FLAG_HEAD: pkt_tag <= `XBUS_TAG_HEAD;
            FLAG_BODY: pkt_tag <= `XBUS_TAG_BODY;
            FLAG_END: pkt_tag <= `XBUS_TAG_END;
            FLAG_INVALID: pkt_tag <= `XBUS_TAG_INVALID;
        endcase
endmodule

//
// R : Q = N : 1
//
module xbus_pkt_gen_disp_N_1 (
    input clk,
    input start_pulse,
    // bus
    output reg [`XBUS_TAG_WIDTH-1:0] pkt_tag = 0,
    output reg [`Q*`S*8-1:0] pkt_data = 0,
    // stall
    input stall,
    // cmd fifo (handshake signals)
    output reg cmd_fifo_rd_en = 0,
    input cmd_fifo_dout_opcode,
    input [`XPHM_DATA_WIDTH-1:0] cmd_fifo_dout_operand,
    input cmd_fifo_dout_last,
    input cmd_fifo_empty,
    // rtm read ports
    output reg rtm_rd_vld = 0,
    output reg [`S-1:0] rtm_rd_en = 0,
    output [`XPHM_DATA_WIDTH+$clog2(`R/`Q)+1:0] rtm_rd_att,
    output reg [`S*$clog2(`RTM_DEPTH)-1:0] rtm_rd_addr = 0,
    input [`S*`R*8-1:0] rtm_dout,
    input [`XPHM_DATA_WIDTH+$clog2(`R/`Q)+1:0] rtm_dout_att,
    input rtm_dout_vld
);
    // Parameter Assertions
    initial begin
        if (`R % `Q != 0) begin
            $error("Hyper parameter mismatch, please make sure that R is a multiple of Q, current values are: Q = %0d, R = %0d", `Q, `R);
            $finish;
        end
    end

    localparam N = `R/`Q;

    localparam RD_IDLE = 0, RD_CMD = 1, RD_END = 2, RD_DONE = 3;
    reg [1:0] rd_state = RD_IDLE;
    reg end_vld = 0;
    reg [$clog2(N)-1:0] seg_id = 0;

    localparam FLAG_HEAD = 3, FLAG_BODY = 2, FLAG_END = 1, FLAG_INVALID = 0;
    reg [1:0] flag = FLAG_INVALID;
    reg [`XPHM_DATA_WIDTH-1:0] head = 0;

    integer i;

    // State Machine
    always @(posedge clk)
        if (start_pulse)
            rd_state <= RD_CMD;
        else
            case (rd_state)
                RD_CMD: begin
                    if (cmd_fifo_rd_en && ~cmd_fifo_empty && cmd_fifo_dout_last)
                        rd_state <= RD_END;
                end
                RD_END: rd_state <= RD_DONE;
                RD_DONE: rd_state <= RD_IDLE;
                default: rd_state <= RD_IDLE;
            endcase

    //
    // Signals controlled by state machine.
    //
    // cmd_fifo_rd_en
    always @(posedge clk) begin
        cmd_fifo_rd_en <= (rd_state==RD_CMD && ~cmd_fifo_empty && ~stall);
        end_vld <= rd_state==RD_END;
    end

    //
    // Inputs of pipeline
    //
    // rtm_rd_vld, rtm_rd_en, rtm_rd_addr, seg_id, flag
    always @(posedge clk) begin
        rtm_rd_vld <= (cmd_fifo_rd_en && ~cmd_fifo_empty && cmd_fifo_dout_opcode==`CMD_OPCODE_ADDR);
        for (i=0; i<`S; i=i+1)
            rtm_rd_en[i] <= (cmd_fifo_rd_en && ~cmd_fifo_empty && cmd_fifo_dout_opcode==`CMD_OPCODE_ADDR);
        for (i=0; i<`S; i=i+1)
            rtm_rd_addr[i*$clog2(`RTM_DEPTH)+:$clog2(`RTM_DEPTH)] <= cmd_fifo_dout_operand[$clog2(`RTM_DEPTH)-1:0];
        seg_id <= cmd_fifo_dout_operand[$clog2(`RTM_DEPTH)+:$clog2(N)];
        
        if (cmd_fifo_rd_en && ~cmd_fifo_empty) begin
            if (cmd_fifo_dout_opcode==`CMD_OPCODE_ADDR)
                flag <= FLAG_BODY;
            else
                flag <= FLAG_HEAD;
        end else if (end_vld)
            flag <= FLAG_END;
        else
            flag <= FLAG_INVALID;

        if (cmd_fifo_rd_en && ~cmd_fifo_empty && cmd_fifo_dout_opcode==`CMD_OPCODE_HEAD)
            head <= cmd_fifo_dout_operand[`XPHM_DATA_WIDTH-1:0];
    end

    assign rtm_rd_att = {seg_id, flag, head};

    wire [$clog2(N)-1:0] piped_seg_id;
    wire [1:0] piped_flag;
    wire [`XPHM_DATA_WIDTH-1:0] piped_head;
    assign {piped_seg_id, piped_flag, piped_head} = rtm_dout_att;

    // Outputs
    // pkt_data
    always @(posedge clk)
        case (piped_flag)
            FLAG_HEAD: pkt_data <= piped_head;
            FLAG_BODY: begin
                for (i=0; i<`S; i=i+1)
                    pkt_data[i*`Q*8+:`Q*8] <= rtm_dout[i*`R*8+piped_seg_id*`Q*8+:`Q*8];
            end
        endcase

    // pkt_tag
    always @(posedge clk)
        case (piped_flag)
            FLAG_HEAD: pkt_tag <= `XBUS_TAG_HEAD;
            FLAG_BODY: pkt_tag <= `XBUS_TAG_BODY;
            FLAG_END: pkt_tag <= `XBUS_TAG_END;
            FLAG_INVALID: pkt_tag <= `XBUS_TAG_INVALID;
        endcase
endmodule
