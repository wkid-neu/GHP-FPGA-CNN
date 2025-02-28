`timescale 1ns / 1ps
`include "../incl.vh"

//
// Put all filters together
//
module xbus_filters (
    input clk,
    input rst,
    // Parameters
    input [15:0] INC2_minus_1,
    input [15:0] INW_,
    input [15:0] INH2,
    input [15:0] INW2,
    input [7:0] KH_minus_1,
    input [7:0] KW_minus_1,
    input [3:0] strideH,
    input [3:0] strideW,
    input [3:0] padL,
    input [3:0] padU,
    input [15:0] row_bound,
    input [15:0] col_bound,
    input [7:0] Xz,
    // bus
    input [`XBUS_TAG_WIDTH-1:0] pkt_tag,
    input [`Q*`S*8-1:0] pkt_data,
    // vector fifos
    output [`P-1:0] vec_fifos_wr_en,
    output [`P*`S*8-1:0] vec_fifos_din,
    input [`P-1:0] vec_fifos_prog_full,
    // cache full
    output [`P-1:0] cache_full
);
    reg [`P-1:0] rst_pipe = 0;
    reg [`P*16-1:0] INC2_minus_1_pipe = 0;
    reg [`P*16-1:0] INW__pipe = 0;
    reg [`P*16-1:0] INH2_pipe = 0;
    reg [`P*16-1:0] INW2_pipe = 0;
    reg [`P*8-1:0] KH_minus_1_pipe = 0;
    reg [`P*8-1:0] KW_minus_1_pipe = 0;
    reg [`P*4-1:0] strideH_pipe = 0;
    reg [`P*4-1:0] strideW_pipe = 0;
    reg [`P*4-1:0] padL_pipe = 0;
    reg [`P*4-1:0] padU_pipe = 0;
    reg [`P*16-1:0] row_bound_pipe = 0;
    reg [`P*16-1:0] col_bound_pipe = 0;
    reg [`P*8-1:0] Xz_pipe = 0;
    integer i;

    always @(posedge clk) begin
        rst_pipe[0] <= rst;
        INC2_minus_1_pipe[15:0] <= INC2_minus_1;
        INW__pipe[15:0] <= INW_;
        INH2_pipe[15:0] <= INH2;
        INW2_pipe[15:0] <= INW2;
        KH_minus_1_pipe[7:0] <= KH_minus_1;
        KW_minus_1_pipe[7:0] <= KW_minus_1;
        strideH_pipe[3:0] <= strideH;
        strideW_pipe[3:0] <= strideW;
        padL_pipe[3:0] <= padL;
        padU_pipe[3:0] <= padU;
        row_bound_pipe[15:0] <= row_bound;
        col_bound_pipe[15:0] <= col_bound;
        Xz_pipe[7:0] <= Xz;
        for (i=1; i<`P; i=i+1) begin
            rst_pipe[i] <= rst_pipe[i-1];
            INC2_minus_1_pipe[i*16+:16] <= INC2_minus_1_pipe[(i-1)*16+:16];
            INW__pipe[i*16+:16] <= INW__pipe[(i-1)*16+:16];
            INH2_pipe[i*16+:16] <= INH2_pipe[(i-1)*16+:16];
            INW2_pipe[i*16+:16] <= INW2_pipe[(i-1)*16+:16];
            KH_minus_1_pipe[i*8+:8] <= KH_minus_1_pipe[(i-1)*8+:8];
            KW_minus_1_pipe[i*8+:8] <= KW_minus_1_pipe[(i-1)*8+:8];
            strideH_pipe[i*4+:4] <= strideH_pipe[(i-1)*4+:4];
            strideW_pipe[i*4+:4] <= strideW_pipe[(i-1)*4+:4];
            padL_pipe[i*4+:4] <= padL_pipe[(i-1)*4+:4];
            padU_pipe[i*4+:4] <= padU_pipe[(i-1)*4+:4];
            row_bound_pipe[i*16+:16] <= row_bound_pipe[(i-1)*16+:16];
            col_bound_pipe[i*16+:16] <= col_bound_pipe[(i-1)*16+:16];
            Xz_pipe[i*8+:8] <= Xz_pipe[(i-1)*8+:8];
        end
    end

    wire [`P*`XBUS_TAG_WIDTH-1:0] out_pkt_tag_chain;
    wire [`P*`Q*`S*8-1:0] out_pkt_data_chain;

    genvar k;
    generate
        for (k=0; k<`P; k=k+1) begin: XBUS_FILTER_GEN
            if (k==0) begin
                xbus_filter xbus_filter_inst(
                	.clk(clk),
                    .rst(rst_pipe[k]),
                    .INC2_minus_1(INC2_minus_1_pipe[k*16+:16]),
                    .INW_(INW__pipe[k*16+:16]),
                    .INH2(INH2_pipe[k*16+:16]),
                    .INW2(INW2_pipe[k*16+:16]),
                    .KH_minus_1(KH_minus_1_pipe[k*8+:8]),
                    .KW_minus_1(KW_minus_1_pipe[k*8+:8]),
                    .strideH(strideH_pipe[k*4+:4]),
                    .strideW(strideW_pipe[k*4+:4]),
                    .padL(padL_pipe[k*4+:4]),
                    .padU(padU_pipe[k*4+:4]),
                    .row_bound(row_bound_pipe[k*16+:16]),
                    .col_bound(col_bound_pipe[k*16+:16]),
                    .Xz(Xz_pipe[k*8+:8]),
                    .in_pkt_tag(pkt_tag),
                    .in_pkt_data(pkt_data),
                    .out_pkt_tag(out_pkt_tag_chain[k*`XBUS_TAG_WIDTH+:`XBUS_TAG_WIDTH]),
                    .out_pkt_data(out_pkt_data_chain[k*`Q*`S*8+:`Q*`S*8]),
                    .vec_fifo_wr_en(vec_fifos_wr_en[k]),
                    .vec_fifo_din(vec_fifos_din[k*`S*8+:`S*8]),
                    .vec_fifo_prog_full(vec_fifos_prog_full[k]),
                    .cache_full(cache_full[k])
                );
            end else begin
                xbus_filter xbus_filter_inst(
                	.clk(clk),
                    .rst(rst_pipe[k]),
                    .INC2_minus_1(INC2_minus_1_pipe[k*16+:16]),
                    .INW_(INW__pipe[k*16+:16]),
                    .INH2(INH2_pipe[k*16+:16]),
                    .INW2(INW2_pipe[k*16+:16]),
                    .KH_minus_1(KH_minus_1_pipe[k*8+:8]),
                    .KW_minus_1(KW_minus_1_pipe[k*8+:8]),
                    .strideH(strideH_pipe[k*4+:4]),
                    .strideW(strideW_pipe[k*4+:4]),
                    .padL(padL_pipe[k*4+:4]),
                    .padU(padU_pipe[k*4+:4]),
                    .row_bound(row_bound_pipe[k*16+:16]),
                    .col_bound(col_bound_pipe[k*16+:16]),
                    .Xz(Xz_pipe[k*8+:8]),
                    .in_pkt_tag(out_pkt_tag_chain[(k-1)*`XBUS_TAG_WIDTH+:`XBUS_TAG_WIDTH]),
                    .in_pkt_data(out_pkt_data_chain[(k-1)*`Q*`S*8+:`Q*`S*8]),
                    .out_pkt_tag(out_pkt_tag_chain[k*`XBUS_TAG_WIDTH+:`XBUS_TAG_WIDTH]),
                    .out_pkt_data(out_pkt_data_chain[k*`Q*`S*8+:`Q*`S*8]),
                    .vec_fifo_wr_en(vec_fifos_wr_en[k]),
                    .vec_fifo_din(vec_fifos_din[k*`S*8+:`S*8]),
                    .vec_fifo_prog_full(vec_fifos_prog_full[k]),
                    .cache_full(cache_full[k])
                );
            end
        end
    endgenerate
endmodule
