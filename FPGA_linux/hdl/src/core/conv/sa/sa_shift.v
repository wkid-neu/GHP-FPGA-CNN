`timescale 1ns / 1ps
`include "../../../incl.vh"

//
// Input shifted systolic array
//
module Conv_ (
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
    wire [`M*8-1:0] shifted_w1;
    wire [`M*8-1:0] shifted_w2;
    wire [`P*8-1:0] shifted_x;

    genvar i;
    generate
        for (i=0; i<`M; i=i+1)  begin: W1
            shift_reg #(
                .DELAY(i),
                .DATA_WIDTH(8)
            ) shift_reg_inst(
                .clk(clk),
                .i(mat_w1[i*8+:8]),
                .o(shifted_w1[i*8+:8])
            );
        end

        for (i=0; i<`M; i=i+1)  begin: W2
            shift_reg #(
                .DELAY(i),
                .DATA_WIDTH(8)
            ) shift_reg_inst(
                .clk(clk),
                .i(mat_w2[i*8+:8]),
                .o(shifted_w2[i*8+:8])
            );
        end

        for (i=0; i<`P; i=i+1) begin: X
            shift_reg #(
                .DELAY(i),
                .DATA_WIDTH(8)
            ) shift_reg_inst(
                .clk(clk),
                .i(mat_x[i*8+:8]),
                .o(shifted_x[i*8+:8])
            );
        end
    endgenerate

    Conv_sa Conv_sa_inst(
`ifdef DEBUG
        .dbg_mat_vec_begin(dbg_mat_vec_begin),
        .dbg_mat_vec_end(dbg_mat_vec_end),
        .dbg_mat_vec_rst(dbg_mat_vec_rst),
`endif
        .clk(clk),
        .mat_w1(shifted_w1),
        .mat_w2(shifted_w2),
        .mat_x(shifted_x),
        .mat_wz(mat_wz),
        .mat_y1(mat_y1),
        .mat_y2(mat_y2),
        .mat_rst(mat_rst),
        .mat_flush(mat_flush),
        .mat_psum_vld(mat_psum_vld),
        .mat_psum_last_rnd(mat_psum_last_rnd),
        .mat_psum_wr_addr(mat_psum_wr_addr),
        .mat_psum_prefetch_addr(mat_psum_prefetch_addr),
        .post_rstp(post_rstp),
        .post_sel(post_sel)
    );
endmodule
