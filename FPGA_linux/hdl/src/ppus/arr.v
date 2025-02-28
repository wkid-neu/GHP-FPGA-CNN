`timescale 1ns / 1ps
`include "../incl.vh"

//
// PPU array
//
module ppu_arr #(
    parameter TAG_WIDTH = 1
) (
    input clk,
    input mode,
    input [TAG_WIDTH-1:0] in_tag,
    // mode0
    input [`S*`R*27-1:0] As,
    input [`S*`R*34-1:0] Bs,
    input [`S*`R*34-1:0] Cs,
    // mode1
    input [`S*`R*27-1:0] Ds,
    input [`S*`R*9-1:0] Es,
    // shift and add
    input [`S*`R*6-1:0] Ss,
    input [`S*`R*8-1:0] Zs,
    // output
    output [`S*`R*8-1:0] outs,
    output [TAG_WIDTH-1:0] out_tag
);
    genvar i;
    generate 
        for (i=0; i<`S*`R; i=i+1) begin: PPUS_GEN
            if (i==0) begin
                ppu #(
                    .TAG_WIDTH(TAG_WIDTH)
                ) ppu_inst1(
                    .clk(clk),
                    .mode(mode),
                    .in_tag(in_tag),
                    .A(As[i*27+:27]),
                    .B(Bs[i*34+:34]),
                    .C(Cs[i*34+:34]),
                    .D(Ds[i*27+:27]),
                    .E(Es[i*9+:9]),
                    .S(Ss[i*6+:6]),
                    .Z(Zs[i*8+:8]),
                    .out(outs[i*8+:8]),
                    .out_tag(out_tag)
                );
            end else begin
                ppu ppu_inst2(
                    .clk(clk),
                    .mode(mode),
                    .in_tag(),
                    .A(As[i*27+:27]),
                    .B(Bs[i*34+:34]),
                    .C(Cs[i*34+:34]),
                    .D(Ds[i*27+:27]),
                    .E(Es[i*9+:9]),
                    .S(Ss[i*6+:6]),
                    .Z(Zs[i*8+:8]),
                    .out(outs[i*8+:8]),
                    .out_tag()
                );
            end
        end 
    endgenerate
endmodule