`timescale 1ns / 1ps
`include "../../incl.vh"

//
// The Remap instruction
//
module Remap (
    input clk,
    input start_pulse,
    output done_pulse,
    // instruction
    input [`INS_RAM_DATA_WIDTH-1:0] ins,
    // RTM read ports
    output rtm_rd_vld,
    output rtm_rd_last,
    output [`S-1:0] rtm_rd_en,
    output [`S*$clog2(`RTM_DEPTH)-1:0] rtm_rd_addr,
    input [`S*`R*8-1:0] rtm_dout,
    input rtm_dout_vld,
    input rtm_dout_last,
    // ppus inputs
    output [`S*`R*8-1:0] ppus_Xs,
    output ppus_Xs_vld,
    output ppus_Xs_last,
    output signed [8:0] ppus_neg_Xz,  // 0-Xz
    output [7:0] ppus_Yz,
    output [25:0] ppus_m1,
    output [5:0] ppus_n1,
    // ppus outputs
    input [`S*`R*8-1:0] ppus_outs,
    input ppus_out_vld,
    input ppus_out_last,
    // RTM write ports
    output rtm_wr_vld,
    output [`S-1:0] rtm_wr_en,
    output [`S*$clog2(`RTM_DEPTH)-1:0] rtm_wr_addr,
    output [`S*`R*8-1:0] rtm_din
);
    wire [`INS_RAM_DATA_WIDTH-1:0] local_ins;
    wire local_start_pulse;

    wire [$clog2(`RTM_DEPTH)-1:0] X_addr;
    wire [$clog2(`RTM_DEPTH)-1:0] Y_addr;
    wire [$clog2(`RTM_DEPTH)-1:0] len_minus_1;
    wire [25:0] m1;
    wire [5:0] n1;
    wire signed [8:0] neg_Xz;
    wire [7:0] Yz;

`ifdef M32P64Q16R16S8
    shift_reg #(1, `INS_RAM_DATA_WIDTH) shift_reg_ins(clk, ins, local_ins);
    shift_reg #(1, 1) shift_reg_start_pulse(clk, start_pulse, local_start_pulse);
`elsif M32P96Q16R16S8
    shift_reg #(1, `INS_RAM_DATA_WIDTH) shift_reg_ins(clk, ins, local_ins);
    shift_reg #(1, 1) shift_reg_start_pulse(clk, start_pulse, local_start_pulse);
`elsif M64P64Q16R16S8
    shift_reg #(1, `INS_RAM_DATA_WIDTH) shift_reg_ins(clk, ins, local_ins);
    shift_reg #(1, 1) shift_reg_start_pulse(clk, start_pulse, local_start_pulse);
`else
    assign local_ins = ins;
    assign local_start_pulse = start_pulse;
`endif

    id_Remap id_Remap_inst(
        .ins(local_ins),
        .X_addr(X_addr),
        .Y_addr(Y_addr),
        .len_minus_1(len_minus_1),
        .m1(m1),
        .n1(n1),
        .neg_Xz(neg_Xz),
        .Yz(Yz)
    );

    Remap_pre Remap_pre_inst(
        .clk(clk),
        .start_pulse(local_start_pulse),
        .X_addr(X_addr),
        .len_minus_1(len_minus_1),
        .m1(m1),
        .n1(n1),
        .neg_Xz(neg_Xz),
        .Yz(Yz),
        .rtm_rd_vld(rtm_rd_vld),
        .rtm_rd_last(rtm_rd_last),
        .rtm_rd_en(rtm_rd_en),
        .rtm_rd_addr(rtm_rd_addr),
        .rtm_dout(rtm_dout),
        .rtm_dout_vld(rtm_dout_vld),
        .rtm_dout_last(rtm_dout_last),
        .ppus_Xs(ppus_Xs),
        .ppus_Xs_vld(ppus_Xs_vld),
        .ppus_Xs_last(ppus_Xs_last),
        .ppus_neg_Xz(ppus_neg_Xz),
        .ppus_Yz(ppus_Yz),
        .ppus_m1(ppus_m1),
        .ppus_n1(ppus_n1)
    );

    Remap_wb Remap_wb_inst(
        .clk(clk),
        .start_pulse(local_start_pulse),
        .done_pulse(done_pulse),
        .Y_addr(Y_addr),
        .ppus_outs(ppus_outs),
        .ppus_out_vld(ppus_out_vld),
        .ppus_out_last(ppus_out_last),
        .rtm_wr_vld(rtm_wr_vld),
        .rtm_wr_en(rtm_wr_en),
        .rtm_wr_addr(rtm_wr_addr),
        .rtm_din(rtm_din)
    );
endmodule
