`timescale 1ns / 1ps
`include "../../../incl.vh"

//
// A row of the post unit.
// It contains P post units.
//
module Conv_sa_post_row (
    input clk,
    // Column sums
    input [`M/8*`P*32-1:0] sum1,
    input [`M/8*`P*32-1:0] sum2,
    // Final outputs
    output [`P*32-1:0] y1,
    output [`P*32-1:0] y2,
    // Activation input of last row of thw first block.
    input [`P*8-1:0] x,
    // Zero-point of weight tensor
    input [`P*8-1:0] wz,
    // Flags
    input in_rstp,  // clear the p register
    input [$clog2(`M/8)-1:0] in_sel  // select a valid block
);
    wire [`P-1:0] out_rstp_list;
    wire [$clog2(`M/8)-1:0] out_sel_list [`P-1:0];
    wire [`P*`M/8*32-1:0] reordered_sum1;
    wire [`P*`M/8*32-1:0] reordered_sum2;
    genvar i, j;

    generate
        for (i=0; i<`M/8; i=i+1) begin
            for (j=0; j<`P; j=j+1) begin
                assign reordered_sum1[(j*`M/8+i)*32+:32] = sum1[(i*`P+j)*32+:32];
                assign reordered_sum2[(j*`M/8+i)*32+:32] = sum2[(i*`P+j)*32+:32];
            end
        end
    endgenerate

    generate
        for (i=0; i<`P; i=i+1) begin: POST
            Conv_sa_post Conv_sa_post_inst(
                .clk(clk),
                .sum1(reordered_sum1[i*`M/8*32+:`M/8*32]),
                .sum2(reordered_sum2[i*`M/8*32+:`M/8*32]),
                .y1(y1[i*32+:32]),
                .y2(y2[i*32+:32]),
                .x(x[i*8+:8]),
                .wz(wz[i*8+:8]),
                .in_rstp(i==0?in_rstp:out_rstp_list[i-1]),
                .in_sel(i==0?in_sel:out_sel_list[i-1]),
                .out_rstp(out_rstp_list[i]),
                .out_sel(out_sel_list[i])
            );
        end
    endgenerate
endmodule
