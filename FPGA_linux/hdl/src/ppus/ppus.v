`timescale 1ns / 1ps
`include "../incl.vh"

`define TAG_WIDTH 8

//
// Post processing units
//
module ppus (
    input clk,
    // inputs from Conv
    input is_conv,
    input [`S*`R*32-1:0] conv_dps,
    input [`S*32-1:0] conv_bias,
    input conv_dps_vld,
    input [25:0] conv_m1,
    input [5:0] conv_n1, 
    input [7:0] conv_Yz,
    output [`S*`R*8-1:0] conv_outs,
    output conv_out_vld,
    // inputs from Pool
    input is_pool,
    input [(`P/2)*14-1:0] pool_Ys,
    input pool_Ys_vld,
    input signed [15:0] pool_neg_NXz,
    input [7:0] pool_Yz,
    input [25:0] pool_m1,
    input [5:0] pool_n1,
    output [(`P/2)*8-1:0] pool_outs,
    output pool_out_vld,
    // inputs from Add
    input is_add,
    input [`S*`R*9-1:0] add_Xs,
    input add_Xs_vld,
    input add_Xs_last,
    input [25:0] add_m1,
    input [25:0] add_m2,
    input [5:0] add_n, 
    input [7:0] add_Cz,
    output [`S*`R*8-1:0] add_outs,
    output add_out_vld,
    output add_out_last,
    // inputs from Remap
    input is_remap,
    input [`S*`R*8-1:0] remap_Xs,
    input remap_Xs_vld,
    input remap_Xs_last,
    input signed [8:0] remap_neg_Xz,
    input [7:0] remap_Yz,
    input [25:0] remap_m1,
    input [5:0] remap_n1,
    output [`S*`R*8-1:0] remap_outs,
    output remap_out_vld,
    output remap_out_last,
    // inputs from Fc
    input is_fc,
    input [`DDR_AXIS_DATA_WIDTH/8*32-1:0] fc_accs,
    input [`DDR_AXIS_DATA_WIDTH/8*32-1:0] fc_bias,
    input fc_accs_vld,
    input fc_accs_last,
    input [25:0] fc_m1,
    input [5:0] fc_n1, 
    input [7:0] fc_Yz,
    output [`DDR_AXIS_DATA_WIDTH/8*8-1:0] fc_outs,
    output fc_out_vld,
    output fc_out_last
);
    wire mode;
    wire [`TAG_WIDTH-1:0] in_tag;
    wire [`S*`R*27-1:0] As;
    wire [`S*`R*34-1:0] Bs;
    wire [`S*`R*34-1:0] Cs;
    wire [`S*`R*27-1:0] Ds;
    wire [`S*`R*9-1:0] Es;
    wire [`S*`R*6-1:0] Ss;
    wire [`S*`R*8-1:0] Zs;
    wire [`S*`R*8-1:0] outs;
    wire [`TAG_WIDTH-1:0] out_tag;

    ppu_arr_ctrl ppu_arr_ctrl_inst(
        .clk(clk),
        .is_conv(is_conv),
        .conv_dps(conv_dps),
        .conv_bias(conv_bias),
        .conv_dps_vld(conv_dps_vld),
        .conv_m1(conv_m1),
        .conv_n1(conv_n1),
        .conv_Yz(conv_Yz),
        .conv_outs(conv_outs),
        .conv_out_vld(conv_out_vld),
        .is_pool(is_pool),
        .pool_Ys(pool_Ys),
        .pool_Ys_vld(pool_Ys_vld),
        .pool_neg_NXz(pool_neg_NXz),
        .pool_Yz(pool_Yz),
        .pool_m1(pool_m1),
        .pool_n1(pool_n1),
        .pool_outs(pool_outs),
        .pool_out_vld(pool_out_vld),
        .is_add(is_add),
        .add_Xs(add_Xs),
        .add_Xs_vld(add_Xs_vld),
        .add_Xs_last(add_Xs_last),
        .add_m1(add_m1),
        .add_m2(add_m2),
        .add_n(add_n),
        .add_Cz(add_Cz),
        .add_outs(add_outs),
        .add_out_vld(add_out_vld),
        .add_out_last(add_out_last),
        .is_remap(is_remap),
        .remap_Xs(remap_Xs),
        .remap_Xs_vld(remap_Xs_vld),
        .remap_Xs_last(remap_Xs_last),
        .remap_neg_Xz(remap_neg_Xz),
        .remap_Yz(remap_Yz),
        .remap_m1(remap_m1),
        .remap_n1(remap_n1),
        .remap_outs(remap_outs),
        .remap_out_vld(remap_out_vld),
        .remap_out_last(remap_out_last),
        .is_fc(is_fc),
        .fc_accs(fc_accs),
        .fc_bias(fc_bias),
        .fc_accs_vld(fc_accs_vld),
        .fc_accs_last(fc_accs_last),
        .fc_m1(fc_m1),
        .fc_n1(fc_n1),
        .fc_Yz(fc_Yz),
        .fc_outs(fc_outs),
        .fc_out_vld(fc_out_vld),
        .fc_out_last(fc_out_last),
        .mode(mode),
        .in_tag(in_tag),
        .As(As),
        .Bs(Bs),
        .Cs(Cs),
        .Ds(Ds),
        .Es(Es),
        .Ss(Ss),
        .Zs(Zs),
        .outs(outs),
        .out_tag(out_tag)
    );

    ppu_arr #(
        .TAG_WIDTH(`TAG_WIDTH)
    ) ppu_arr_inst(
        .clk(clk),
        .mode(mode),
        .in_tag(in_tag),
        .As(As),
        .Bs(Bs),
        .Cs(Cs),
        .Ds(Ds),
        .Es(Es),
        .Ss(Ss),
        .Zs(Zs),
        .outs(outs),
        .out_tag(out_tag)
    );
endmodule
