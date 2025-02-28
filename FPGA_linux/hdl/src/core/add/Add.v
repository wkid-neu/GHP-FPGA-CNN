`timescale 1ns / 1ps
`include "../../incl.vh"

//
// The Add instruction
//
module Add (
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
    output [`S*`R*9-1:0] ppus_Xs,
    output ppus_Xs_vld,
    output ppus_Xs_last,
    output [25:0] ppus_m1,
    output [25:0] ppus_m2,
    output [5:0] ppus_n,
    output [7:0] ppus_Cz,
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

    wire [$clog2(`RTM_DEPTH)-1:0] A_addr;
    wire [$clog2(`RTM_DEPTH)-1:0] B_addr;
    wire [$clog2(`RTM_DEPTH)-1:0] C_addr;
    wire [$clog2(`RTM_DEPTH)-1:0] len_minus_1;
    wire [25:0] m1;
    wire [25:0] m2;
    wire [5:0] n;
    wire [7:0] Az;
    wire [7:0] Bz;
    wire [7:0] Cz;

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

    id_Add id_Add_inst(
        .ins(local_ins),
        .A_addr(A_addr),
        .B_addr(B_addr),
        .C_addr(C_addr),
        .len_minus_1(len_minus_1),
        .m1(m1),
        .m2(m2),
        .n(n),
        .Az(Az),
        .Bz(Bz),
        .Cz(Cz)
    );

    Add_pre Add_pre_inst(
        .clk(clk),
        .start_pulse(local_start_pulse),
        .A_addr(A_addr),
        .B_addr(B_addr),
        .len_minus_1(len_minus_1),
        .m1(m1),
        .m2(m2),
        .n(n),
        .Az(Az),
        .Bz(Bz),
        .Cz(Cz),
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
        .ppus_m1(ppus_m1),
        .ppus_m2(ppus_m2),
        .ppus_n(ppus_n),
        .ppus_Cz(ppus_Cz)
    );

    Add_wb Add_wb_inst(
        .clk(clk),
        .start_pulse(local_start_pulse),
        .done_pulse(done_pulse),
        .C_addr(C_addr),
        .ppus_outs(ppus_outs),
        .ppus_out_vld(ppus_out_vld),
        .ppus_out_last(ppus_out_last),
        .rtm_wr_vld(rtm_wr_vld),
        .rtm_wr_en(rtm_wr_en),
        .rtm_wr_addr(rtm_wr_addr),
        .rtm_din(rtm_din)
    );
endmodule
