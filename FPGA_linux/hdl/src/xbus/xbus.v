`timescale 1ns / 1ps
`include "../incl.vh"

//
// X-bus
//
module xbus (
    input clk,
    // Control signals from Conv
    input conv_start_pulse,
    input [$clog2(`XPHM_DEPTH)-1:0] conv_xphm_addr,
    input [$clog2(`XPHM_DEPTH)-1:0] conv_xphm_len_minus_1,
    input [$clog2(`RTM_DEPTH)-1:0] conv_X_addr,
    input [15:0] conv_INC2_minus_1,
    input [15:0] conv_INW_,
    input [15:0] conv_INH2,
    input [15:0] conv_INW2,
    input [7:0] conv_KH_minus_1,
    input [7:0] conv_KW_minus_1,
    input [3:0] conv_strideH,
    input [3:0] conv_strideW,
    input [3:0] conv_padL,
    input [3:0] conv_padU,
    input [15:0] conv_ifm_height,
    input [15:0] conv_row_bound,
    input [15:0] conv_col_bound,
    input [7:0] conv_Xz,
    // Control signals from Pool
    input pool_start_pulse,
    input [$clog2(`XPHM_DEPTH)-1:0] pool_xphm_addr,
    input [$clog2(`XPHM_DEPTH)-1:0] pool_xphm_len_minus_1,
    input [$clog2(`RTM_DEPTH)-1:0] pool_X_addr,
    input [15:0] pool_INC2_minus_1,
    input [15:0] pool_INW_,
    input [15:0] pool_INH2,
    input [15:0] pool_INW2,
    input [7:0] pool_KH_minus_1,
    input [7:0] pool_KW_minus_1,
    input [3:0] pool_strideH,
    input [3:0] pool_strideW,
    input [3:0] pool_padL,
    input [3:0] pool_padU,
    input [15:0] pool_ifm_height,
    input [15:0] pool_row_bound,
    input [15:0] pool_col_bound,
    input [7:0] pool_Xz,
    // XPHM read ports
    output xphm_rd_en,
    output xphm_rd_last,
    output [$clog2(`XPHM_DEPTH)-1:0] xphm_rd_addr,
    input [`XPHM_DATA_WIDTH-1:0] xphm_dout,
    input xphm_dout_vld,
    input xphm_dout_last,
    // RTM read ports
    output rtm_rd_vld,
    output [`S-1:0] rtm_rd_en,
    output [`XPHM_DATA_WIDTH+$clog2(`R/`Q)+1:0]rtm_rd_att,
    output [`S*$clog2(`RTM_DEPTH)-1:0] rtm_rd_addr,
    input [`S*`R*8-1:0] rtm_dout,
    input [`XPHM_DATA_WIDTH+$clog2(`R/`Q)+1:0]rtm_dout_att,
    input rtm_dout_vld,
    // MXM write ports
    output mxm_wr_en,
    output [`P*2*8-1:0] mxm_din,
    input mxm_prog_full
);
    reg start_pulse = 0;
    reg [$clog2(`XPHM_DEPTH)-1:0] xphm_addr = 0;
    reg [$clog2(`XPHM_DEPTH)-1:0] xphm_len_minus_1 = 0;
    reg [$clog2(`RTM_DEPTH)-1:0] X_addr = 0;
    reg [15:0] INC2_minus_1 = 0;
    reg [15:0] INW_ = 0;
    reg [15:0] INH2 = 0;
    reg [15:0] INW2 = 0;
    reg [7:0] KH_minus_1 = 0;
    reg [7:0] KW_minus_1 = 0;
    reg [3:0] strideH = 0;
    reg [3:0] strideW = 0;
    reg [3:0] padL = 0;
    reg [3:0] padU = 0;
    reg [15:0] ifm_height = 0;
    reg [15:0] row_bound = 0;
    reg [15:0] col_bound = 0;
    reg [7:0] Xz = 0;

    wire [`XBUS_TAG_WIDTH-1:0] pkt_gen_pkt_tag;
    wire [`Q*`S*8-1:0] pkt_gen_pkt_data; 
    reg pkt_gen_stall = 0;

    wire [`P-1:0] filters_cache_full;

    wire [`P-1:0] vec_fifos_wr_en;
    wire [`P*`S*8-1:0] vec_fifos_din;
    wire [`P-1:0] vec_fifos_prog_full;
    wire [`P-1:0] vec_fifos_rd_en;
    wire [`P*`S*8-1:0] vec_fifos_dout;
    wire [`P-1:0] vec_fifos_empty;

    always @(posedge clk) begin
        start_pulse <= (conv_start_pulse || pool_start_pulse);
        if (conv_start_pulse) begin
            xphm_addr <= conv_xphm_addr;
            xphm_len_minus_1 <= conv_xphm_len_minus_1;
            X_addr <= conv_X_addr;
            INC2_minus_1 <= conv_INC2_minus_1;
            INW_ <= conv_INW_;
            INH2 <= conv_INH2;
            INW2 <= conv_INW2;
            KH_minus_1 <= conv_KH_minus_1;
            KW_minus_1 <= conv_KW_minus_1;
            strideH <= conv_strideH;
            strideW <= conv_strideW;
            padL <= conv_padL;
            padU <= conv_padU;
            ifm_height <= conv_ifm_height;
            row_bound <= conv_row_bound;
            col_bound <= conv_col_bound;
            Xz <= conv_Xz;
        end else begin
            xphm_addr <= pool_xphm_addr;
            xphm_len_minus_1 <= pool_xphm_len_minus_1;
            X_addr <= pool_X_addr;
            INC2_minus_1 <= pool_INC2_minus_1;
            INW_ <= pool_INW_;
            INH2 <= pool_INH2;
            INW2 <= pool_INW2;
            KH_minus_1 <= pool_KH_minus_1;
            KW_minus_1 <= pool_KW_minus_1;
            strideH <= pool_strideH;
            strideW <= pool_strideW;
            padL <= pool_padL;
            padU <= pool_padU;
            ifm_height <= pool_ifm_height;
            row_bound <= pool_row_bound;
            col_bound <= pool_col_bound;
            Xz <= pool_Xz;
        end
    end

    xbus_pkt_gen xbus_pkt_gen_inst(
        .clk(clk),
        .start_pulse(start_pulse),
        .xphm_addr(xphm_addr),
        .xphm_len_minus_1(xphm_len_minus_1),
        .X_addr(X_addr),
        .INC2_minus_1(INC2_minus_1),
        .ifm_height(ifm_height),
        .pkt_tag(pkt_gen_pkt_tag),
        .pkt_data(pkt_gen_pkt_data),
        .stall(pkt_gen_stall),
        .xphm_rd_en(xphm_rd_en),
        .xphm_rd_last(xphm_rd_last),
        .xphm_rd_addr(xphm_rd_addr),
        .xphm_dout(xphm_dout),
        .xphm_dout_vld(xphm_dout_vld),
        .xphm_dout_last(xphm_dout_last),
        .rtm_rd_vld(rtm_rd_vld),
        .rtm_rd_en(rtm_rd_en),
        .rtm_rd_att(rtm_rd_att),
        .rtm_rd_addr(rtm_rd_addr),
        .rtm_dout(rtm_dout),
        .rtm_dout_att(rtm_dout_att),
        .rtm_dout_vld(rtm_dout_vld)
    );

    xbus_filters xbus_filters_inst(
        .clk(clk),
        .rst(start_pulse),
        .INC2_minus_1(INC2_minus_1),
        .INW_(INW_),
        .INH2(INH2),
        .INW2(INW2),
        .KH_minus_1(KH_minus_1),
        .KW_minus_1(KW_minus_1),
        .strideH(strideH),
        .strideW(strideW),
        .padL(padL),
        .padU(padU),
        .row_bound(row_bound),
        .col_bound(col_bound),
        .Xz(Xz),
        .pkt_tag(pkt_gen_pkt_tag),
        .pkt_data(pkt_gen_pkt_data),
        .vec_fifos_wr_en(vec_fifos_wr_en),
        .vec_fifos_din(vec_fifos_din),
        .vec_fifos_prog_full(vec_fifos_prog_full),
        .cache_full(filters_cache_full)
    );

    xbus_vec_fifos xbus_vec_fifos_inst(
        .clk(clk),
        .wr_en(vec_fifos_wr_en),
        .din(vec_fifos_din),
        .prog_full(vec_fifos_prog_full),
        .rd_en(vec_fifos_rd_en),
        .dout(vec_fifos_dout),
        .empty(vec_fifos_empty)
    );

    xbus_mxm_wr xbus_mxm_wr(
        .clk(clk),
        .vec_fifos_rd_en(vec_fifos_rd_en),
        .vec_fifos_dout(vec_fifos_dout),
        .vec_fifos_empty(vec_fifos_empty),
        .mxm_wr_en(mxm_wr_en),
        .mxm_din(mxm_din),
        .mxm_prog_full(mxm_prog_full)
    );

    always @(posedge clk)
        pkt_gen_stall <= filters_cache_full != {`P{1'b0}};
endmodule
