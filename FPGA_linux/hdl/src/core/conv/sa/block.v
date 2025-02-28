`timescale 1ns / 1ps
`include "../../../incl.vh"

//
// A block.
// It has 8 rows of PEs and one row of sum units
//
module Conv_sa_block(
// Ports for debugging
`ifdef DEBUG
    input [7:0] dbg_in_vec_begin,  // current input is the first element
    input [7:0] dbg_in_vec_end,  // current input is the last element
    input [7:0] dbg_in_vec_rst,  // current input is invaild, this is a reset cycle
`endif
    input clk,
    // Data ports
    input [8*8-1:0] in_w1,
    input [8*8-1:0] in_w2,
    input [`P*8-1:0] in_x,
    output [`P*8-1:0] out_x,
    output [`P*32-1:0] out_sum1,
    output [`P*32-1:0] out_sum2,
    // Flag ports
    input [7:0] in_rst,
    input [7:0] in_flush,
    input in_psum_vld,
    input in_psum_last_rnd,
    input [2:0] in_psum_wr_addr,
    input [2:0] in_psum_prefetch_addr
);
    wire [`P*8-1:0] out_x_list [7:0];
    wire [`P*19-1:0] out_psum1_list [7:0];
    wire [`P*19-1:0] out_psum2_list [7:0];

    genvar i;
    generate
        for (i=0; i<8; i=i+1) begin: ROW
            Conv_sa_pe_row Conv_sa_pe_row_inst(
`ifdef DEBUG
                .dbg_in_vec_begin(dbg_in_vec_begin[i]),
                .dbg_in_vec_end(dbg_in_vec_end[i]),
                .dbg_in_vec_rst(dbg_in_vec_rst[i]),
`endif
                .clk(clk),
                .in_w1(in_w1[i*8+:8]),
                .in_w2(in_w2[i*8+:8]),
                .in_x(i==0?in_x:out_x_list[i-1]),
                .in_psum1(i==0?{{`P*19}{1'bZ}}:out_psum1_list[i-1]),
                .in_psum2(i==0?{{`P*19}{1'bZ}}:out_psum2_list[i-1]),
                .out_x(out_x_list[i]),
                .out_psum1(out_psum1_list[i]),
                .out_psum2(out_psum2_list[i]),
                .in_rst(in_rst[i]),
                .in_flush(in_flush[i])
            );
        end
    endgenerate

    Conv_sa_sum_row Conv_sa_sum_row_inst(
        .clk(clk),
        .in_psum1(out_psum1_list[7]),
        .in_psum2(out_psum2_list[7]),
        .out_sum1(out_sum1),
        .out_sum2(out_sum2),
        .in_psum_vld(in_psum_vld),
        .in_psum_last_rnd(in_psum_last_rnd),
        .in_psum_wr_addr(in_psum_wr_addr),
        .in_psum_prefetch_addr(in_psum_prefetch_addr)
    );

    assign out_x = out_x_list[7];
endmodule
