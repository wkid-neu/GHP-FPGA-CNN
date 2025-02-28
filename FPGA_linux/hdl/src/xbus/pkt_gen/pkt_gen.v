`timescale 1ns / 1ps
`include "../../incl.vh"

//
// X packet generator
//
module xbus_pkt_gen (
    input clk,
    input start_pulse,
    // Instruction
    input [$clog2(`XPHM_DEPTH)-1:0] xphm_addr,
    input [$clog2(`XPHM_DEPTH)-1:0] xphm_len_minus_1,
    input [$clog2(`RTM_DEPTH)-1:0] X_addr,
    input [15:0] INC2_minus_1,
    input [15:0] ifm_height,
    // Generated packets
    output [`XBUS_TAG_WIDTH-1:0] pkt_tag,
    output [`Q*`S*8-1:0] pkt_data,
    // Stall signal
    input stall,
    // XPHM read ports
    output xphm_rd_en,
    output xphm_rd_last,
    output [$clog2(`XPHM_DEPTH)-1:0] xphm_rd_addr,
    input [`XPHM_DATA_WIDTH-1:0] xphm_dout,
    input xphm_dout_vld,
    input xphm_dout_last,
    // RTM read ports
    output rtm_rd_vld,
    output [`S-1:0] rtm_rd_en,
    output [`XPHM_DATA_WIDTH+$clog2(`R/`Q)+1:0] rtm_rd_att,
    output [`S*$clog2(`RTM_DEPTH)-1:0] rtm_rd_addr,
    input [`S*`R*8-1:0] rtm_dout,
    input [`XPHM_DATA_WIDTH+$clog2(`R/`Q)+1:0] rtm_dout_att,
    input rtm_dout_vld
);
    wire xphs_fifo_rd_en;
    wire [`XPHM_DATA_WIDTH-1:0] xphs_fifo_dout;
    wire xphs_fifo_dout_last;
    wire xphs_fifo_empty;
    wire xphs_fifo_wr_en;
    wire [`XPHM_DATA_WIDTH-1:0] xphs_fifo_din;
    wire xphs_fifo_din_last;
    wire xphs_fifo_prog_full;

    wire cmd_fifo_rd_en;
    wire cmd_fifo_dout_opcode;
    wire [`XPHM_DATA_WIDTH-1:0] cmd_fifo_dout_operand;
    wire cmd_fifo_dout_last;
    wire cmd_fifo_empty;
    wire cmd_fifo_wr_en;
    wire cmd_fifo_din_opcode;
    wire [`XPHM_DATA_WIDTH-1:0] cmd_fifo_din_operand;
    wire cmd_fifo_din_last;
    wire cmd_fifo_prog_full;

    xpm_fifo_sync #(
        .DOUT_RESET_VALUE("0"),
        .ECC_MODE("no_ecc"),
        .FIFO_MEMORY_TYPE("distributed"),
        .FIFO_READ_LATENCY(0),
        .FIFO_WRITE_DEPTH(32),
        .FULL_RESET_VALUE(0),
        .PROG_EMPTY_THRESH(3),  // not used
        .PROG_FULL_THRESH(12),
        .RD_DATA_COUNT_WIDTH(1),  // not used
        .READ_DATA_WIDTH(`XPHM_DATA_WIDTH+1),
        .READ_MODE("fwft"),
        .SIM_ASSERT_CHK(0),
        .USE_ADV_FEATURES("0002"),  // prog_full
        .WAKEUP_TIME(0),
        .WRITE_DATA_WIDTH(`XPHM_DATA_WIDTH+1),
        .WR_DATA_COUNT_WIDTH(1)  // not used
    ) xphs_fifo_inst (
        .empty(xphs_fifo_empty),
        .dout({xphs_fifo_dout_last, xphs_fifo_dout}),
        .din({xphs_fifo_din_last, xphs_fifo_din}),
        .prog_full(xphs_fifo_prog_full),
        .rd_en(xphs_fifo_rd_en),
        .rst(1'b0),
        .sleep(1'b0),
        .wr_clk(clk),
        .wr_en(xphs_fifo_wr_en)
    );

    xbus_pkt_gen_xphm_rd xbus_pkt_gen_xphm_rd_inst(
        .clk(clk),
        .start_pulse(start_pulse),
        .xphm_addr(xphm_addr),
        .xphm_len_minus_1(xphm_len_minus_1),
        .xphm_rd_en(xphm_rd_en),
        .xphm_rd_last(xphm_rd_last),
        .xphm_rd_addr(xphm_rd_addr),
        .xphm_dout(xphm_dout),
        .xphm_dout_vld(xphm_dout_vld),
        .xphm_dout_last(xphm_dout_last),
        .fifo_wr_en(xphs_fifo_wr_en),
        .fifo_din(xphs_fifo_din),
        .fifo_din_last(xphs_fifo_din_last),
        .fifo_prog_full(xphs_fifo_prog_full)
    );

    xpm_fifo_sync #(
        .DOUT_RESET_VALUE("0"),
        .ECC_MODE("no_ecc"),
        .FIFO_MEMORY_TYPE("distributed"),
        .FIFO_READ_LATENCY(0),
        .FIFO_WRITE_DEPTH(32),
        .FULL_RESET_VALUE(0),
        .PROG_EMPTY_THRESH(3),  // not used
        .PROG_FULL_THRESH(16),
        .RD_DATA_COUNT_WIDTH(1),  // not used
        .READ_DATA_WIDTH(`XPHM_DATA_WIDTH+2),
        .READ_MODE("fwft"),
        .SIM_ASSERT_CHK(0),
        .USE_ADV_FEATURES("0002"),  // prog_full
        .WAKEUP_TIME(0),
        .WRITE_DATA_WIDTH(`XPHM_DATA_WIDTH+2),
        .WR_DATA_COUNT_WIDTH(1)  // not used
    ) cmd_fifo_inst (
        .empty(cmd_fifo_empty),
        .dout({cmd_fifo_dout_last, cmd_fifo_dout_opcode, cmd_fifo_dout_operand}),
        .din({cmd_fifo_din_last, cmd_fifo_din_opcode, cmd_fifo_din_operand}),
        .prog_full(cmd_fifo_prog_full),
        .rd_en(cmd_fifo_rd_en),
        .rst(1'b0),
        .sleep(1'b0),
        .wr_clk(clk),
        .wr_en(cmd_fifo_wr_en)
    );

    xbus_pkt_gen_cmd_wr xbus_pkt_gen_cmd_wr_inst(
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
    
    xbus_pkt_gen_disp xbus_pkt_gen_disp_inst(
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
endmodule
