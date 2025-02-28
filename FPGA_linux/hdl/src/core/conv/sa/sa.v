`timescale 1ns / 1ps
`include "../../../incl.vh"

//
// The systolic array.
// It has M/8 blocks
//
module Conv_sa (
// Ports for debugging
`ifdef DEBUG
    input [`M-1:0] dbg_mat_vec_begin,  // current input is the first element
    input [`M-1:0] dbg_mat_vec_end,  // current input is the last element
    input [`M-1:0] dbg_mat_vec_rst,  // current input is invaild, this is a reset cycle
`endif
    input clk,
    // Data ports
    input [`M*8-1:0] mat_w1,
    input [`M*8-1:0] mat_w2,
    input [`P*8-1:0] mat_x,
    input [`P*8-1:0] mat_wz,
    output [`P*32-1:0] mat_y1,
    output [`P*32-1:0] mat_y2,
    // Flag ports
    input [`M-1:0] mat_rst,
    input [`M-1:0] mat_flush,
    input [`M/8-1:0] mat_psum_vld,
    input [`M/8-1:0] mat_psum_last_rnd,
    input [`M/8*3-1:0] mat_psum_wr_addr,
    input [`M/8*3-1:0] mat_psum_prefetch_addr,
    input post_rstp,
    input [$clog2(`M/8)-1:0] post_sel
);
    wire [`P*8-1:0] out_x_list [`M/8-1:0];
    wire [`M/8*`P*32-1:0] out_sum1_list;
    wire [`M/8*`P*32-1:0] out_sum2_list;

    genvar i;
    generate
        for (i=0; i<`M/8; i=i+1) begin: BLOCK
            Conv_sa_block Conv_sa_block_inst(
`ifdef DEBUG
                .dbg_in_vec_begin(dbg_mat_vec_begin[i*8+:8]),
                .dbg_in_vec_end(dbg_mat_vec_end[i*8+:8]),
                .dbg_in_vec_rst(dbg_mat_vec_rst[i*8+:8]),
`endif
                .clk(clk),
                .in_w1(mat_w1[i*(8*8)+:(8*8)]),
                .in_w2(mat_w2[i*(8*8)+:(8*8)]),
                .in_x(i==0?mat_x:out_x_list[i-1]),
                .out_x(out_x_list[i]),
                .out_sum1(out_sum1_list[i*(`P*32)+:(`P*32)]),
                .out_sum2(out_sum2_list[i*(`P*32)+:(`P*32)]),
                .in_rst(mat_rst[i*8+:8]),
                .in_flush(mat_flush[i*8+:8]),
                .in_psum_vld(mat_psum_vld[i]),
                .in_psum_last_rnd(mat_psum_last_rnd[i]),
                .in_psum_wr_addr(mat_psum_wr_addr[i*3+:3]),
                .in_psum_prefetch_addr(mat_psum_prefetch_addr[i*3+:3])
            );
        end
    endgenerate

    Conv_sa_post_row Conv_sa_post_row_inst(
        .clk(clk),
        .sum1(out_sum1_list),
        .sum2(out_sum2_list),
        .y1(mat_y1),
        .y2(mat_y2),
        .x(out_x_list[0]),
        .wz(mat_wz),
        .in_rstp(post_rstp),
        .in_sel(post_sel)
    );
endmodule
