`timescale 1ns / 1ps
`include "../../../incl.vh"

//
// A row of the sum unit.
// It contains P sum units.
//
module Conv_sa_sum_row(
    input clk,
    // Data ports
    input [`P*19-1:0] in_psum1,
    input [`P*19-1:0] in_psum2,
    output [`P*32-1:0] out_sum1,
    output [`P*32-1:0] out_sum2,
    // Flag ports
    input in_psum_vld,
    input in_psum_last_rnd,
    input [2:0] in_psum_wr_addr,
    input [2:0] in_psum_prefetch_addr
);
    wire [`P-1:0] out_psum_vld_list;
    wire [`P-1:0] out_psum_last_rnd_list;
    wire [2:0] out_psum_wr_addr_list [`P-1:0];
    wire [2:0] out_psum_prefetch_addr_list [`P-1:0];
    
    genvar i;
    generate
        for (i=0; i<`P; i=i+1) begin: SUM
            Conv_sa_sum Conv_sa_sum_inst(
                .clk(clk),
                .in_psum1(in_psum1[i*19+:19]),
                .in_psum2(in_psum2[i*19+:19]),
                .out_sum1(out_sum1[i*32+:32]),
                .out_sum2(out_sum2[i*32+:32]),
                .in_psum_vld(i==0?in_psum_vld:out_psum_vld_list[i-1]),
                .in_psum_last_rnd(i==0?in_psum_last_rnd:out_psum_last_rnd_list[i-1]),
                .in_psum_wr_addr(i==0?in_psum_wr_addr:out_psum_wr_addr_list[i-1]),
                .in_psum_prefetch_addr(i==0?in_psum_prefetch_addr:out_psum_prefetch_addr_list[i-1]),
                .out_psum_vld(out_psum_vld_list[i]),
                .out_psum_last_rnd(out_psum_last_rnd_list[i]),
                .out_psum_wr_addr(out_psum_wr_addr_list[i]),
                .out_psum_prefetch_addr(out_psum_prefetch_addr_list[i])
            );
        end
    endgenerate
endmodule
