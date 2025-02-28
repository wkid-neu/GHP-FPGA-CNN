`timescale 1ns / 1ps
`include "../../incl.vh"

//
// The Conv instruction
//
module Conv (
    input main_clk,
    input sa_clk,
    input start_pulse,
    output done_pulse,
    // instruction
    input [`INS_RAM_DATA_WIDTH-1:0] ins,
    // X-bus control signals
    output xbus_start_pulse,
    output [$clog2(`XPHM_DEPTH)-1:0] xbus_xphm_addr,
    output [$clog2(`XPHM_DEPTH)-1:0] xbus_xphm_len_minus_1,
    output [$clog2(`RTM_DEPTH)-1:0] xbus_X_addr,
    output [15:0] xbus_INC2_minus_1,
    output [15:0] xbus_INW_,
    output [15:0] xbus_INH2,
    output [15:0] xbus_INW2,
    output [7:0] xbus_KH_minus_1,
    output [7:0] xbus_KW_minus_1,
    output [3:0] xbus_strideH,
    output [3:0] xbus_strideW,
    output [3:0] xbus_padL,
    output [3:0] xbus_padU,
    output [15:0] xbus_ifm_height,
    output [15:0] xbus_row_bound,
    output [15:0] xbus_col_bound,
    output [7:0] xbus_Xz,
    // MXM read ports
    output [15:0] mxm_vec_size,
    output [15:0] mxm_vec_size_minus_1,
    output mxm_rd_en,
    output mxm_rd_last_rnd,
    input [`P*2*8-1:0] mxm_dout,
    input mxm_dout_vld,
    input mxm_empty,
    input mxm_almost_empty,
    // CWM control ports
    output cwm_ic_d2c_start_pulse,
    output [31:0] cwm_ic_d2c_d_addr,
    output [31:0] cwm_ic_d2c_c_addr,
    output [31:0] cwm_ic_d2c_n_bytes,
    // CWM read ports
    input [$clog2(`CWM_DEPTH):0] cwm_wr_ptr,
    output cwm_rd_en,
    output [$clog2(`CWM_DEPTH)-1:0] cwm_rd_addr,
    input [`M*4*8-1:0] cwm_dout,
    input cwm_dout_vld,
    // BM read ports
    output bm_rd_en,
    output [$clog2(`BM_DEPTH)-1:0] bm_rd_addr,
    input [`BM_DATA_WIDTH-1:0] bm_dout,
    input bm_dout_vld,
    // ppus inputs
    output [`S*`R*32-1:0] ppus_dps,
    output [`S*32-1:0] ppus_bias,
    output ppus_dps_vld,
    output [25:0] ppus_m1,
    output [5:0] ppus_n1, 
    output [7:0] ppus_Yz,
    // ppus outputs
    input [`S*`R*8-1:0] ppus_outs,
    input ppus_out_vld,
    // RTM write ports
    output rtm_wr_vld,
    output [`S-1:0] rtm_wr_en,
    output [`S*$clog2(`RTM_DEPTH)-1:0] rtm_wr_addr,
    output [`S*`R*8-1:0] rtm_din
);
    wire [`INS_RAM_DATA_WIDTH-1:0] local_ins;
    wire local_start_pulse;

    wire [$clog2(`XPHM_DEPTH)-1:0] xphs_addr;
    wire [15:0] xphs_len_minus_1;
    wire [31:0] W_addr;
    wire [31:0] W_n_bytes;
    wire [$clog2(`BM_DEPTH)-1:0] B_addr;
    wire [$clog2(`RTM_DEPTH)-1:0] X_addr;
    wire [$clog2(`RTM_DEPTH)-1:0] Y_addr;
    wire [15:0] OC;
    wire [15:0] INC2_minus_1;
    wire [15:0] INW_;
    wire [7:0] KH_minus_1;
    wire [7:0] KW_minus_1;
    wire [3:0] strideH;
    wire [3:0] strideW;
    wire [3:0] padL;
    wire [3:0] padU;
    wire [15:0] INH2;
    wire [15:0] INW2;
    wire [15:0] ifm_height;
    wire [15:0] ofm_height;
    wire [7:0] n_last_batch;
    wire [15:0] n_W_rnd_minus_1;
    wire [15:0] row_bound;
    wire [15:0] col_bound;
    wire [15:0] vec_size;
    wire [15:0] vec_size_minus_1;
    wire [7:0] Xz;
    wire [7:0] Wz;
    wire [7:0] Yz;
    wire [25:0] m1;
    wire [5:0] n1;
    wire [7:0] obj1;
    wire [7:0] obj2;
    wire [7:0] obj3;
    wire [7:0] obj4;
    // Generated parameters
    wire [$clog2(`CWM_DEPTH)-1:0] cwm_sta_addr;

    wire wx_fifo_wr_en;
    wire [`SA_TAG_DW+`M*4*8+`P*2*8-1:0] wx_fifo_din;
    wire wx_fifo_prog_full;
    wire wx_fifo_rd_en;
    wire wx_fifo_empty;
    wire wx_fifo_almost_empty;
    wire [`SA_TAG_DW+`M*4*8+`P*2*8-1:0] wx_fifo_dout;

`ifdef DEBUG
    wire [`M-1:0] dbg_sa_mat_vec_begin;
    wire [`M-1:0] dbg_sa_mat_vec_end;
    wire [`M-1:0] dbg_sa_mat_vec_rst;
`endif
    wire [`M*8-1:0] sa_mat_w1;
    wire [`M*8-1:0] sa_mat_w2;
    wire [`P*8-1:0] sa_mat_x;
    wire [`P*8-1:0] sa_mat_wz;
    wire [`P*32-1:0] sa_mat_y1;
    wire [`P*32-1:0] sa_mat_y2;
    wire [`M-1:0] sa_mat_rst;
    wire [`M-1:0] sa_mat_flush;
    wire [`M/8-1:0] sa_mat_psum_vld;
    wire [`M/8-1:0] sa_mat_psum_last_rnd;
    wire [`M/8*3-1:0] sa_mat_psum_wr_addr;
    wire [`M/8*3-1:0] sa_mat_psum_prefetch_addr;
    wire sa_post_rstp;
    wire [$clog2(`M/8)-1:0] sa_post_sel;

    wire [7:0] wz_sa_clk;

    wire dp_fifo_wr_en;
    wire [`P*2*32-1:0] dp_fifo_din;
    wire dp_fifo_prog_full;
    wire dp_fifo_rd_en;
    wire [`P*2*32-1:0] dp_fifo_dout;
    wire dp_fifo_empty;
    wire dp_fifo_almost_empty;

    wire bias_fifo_wr_en;
    wire [63:0] bias_fifo_din;
    wire bias_fifo_prog_full;
    wire bias_fifo_rd_en;
    wire [63:0] bias_fifo_dout;
    wire bias_fifo_data_valid;
    wire bias_fifo_empty;
    wire bias_fifo_almost_empty;

`ifdef M32P64Q16R16S8
    shift_reg #(1, `INS_RAM_DATA_WIDTH) shift_reg_ins(main_clk, ins, local_ins);
    shift_reg #(1, 1) shift_reg_start_pulse(main_clk, start_pulse, local_start_pulse);
`elsif M32P96Q16R16S8
    shift_reg #(1, `INS_RAM_DATA_WIDTH) shift_reg_ins(main_clk, ins, local_ins);
    shift_reg #(1, 1) shift_reg_start_pulse(main_clk, start_pulse, local_start_pulse);
`elsif M64P64Q16R16S8
    shift_reg #(1, `INS_RAM_DATA_WIDTH) shift_reg_ins(main_clk, ins, local_ins);
    shift_reg #(1, 1) shift_reg_start_pulse(main_clk, start_pulse, local_start_pulse);
`else
    assign local_ins = ins;
    assign local_start_pulse = start_pulse;
`endif

    assign cwm_sta_addr = {obj4, obj3, obj2, obj1};

    assign xbus_start_pulse = local_start_pulse;
    assign xbus_xphm_addr = xphs_addr;
    assign xbus_xphm_len_minus_1 = xphs_len_minus_1;
    assign xbus_X_addr = X_addr;
    assign xbus_INC2_minus_1 = INC2_minus_1;
    assign xbus_INW_ = INW_;
    assign xbus_INH2 = INH2;
    assign xbus_INW2 = INW2;
    assign xbus_KH_minus_1 = KH_minus_1;
    assign xbus_KW_minus_1 = KW_minus_1;
    assign xbus_strideH = strideH;
    assign xbus_strideW = strideW;
    assign xbus_padL = padL;
    assign xbus_padU = padU;
    assign xbus_ifm_height = ifm_height;
    assign xbus_row_bound = row_bound;
    assign xbus_col_bound = col_bound;
    assign xbus_Xz = Xz;

    assign mxm_vec_size = vec_size;
    assign mxm_vec_size_minus_1 = vec_size_minus_1;

    id_Conv id_Conv_inst(
        .ins(local_ins),
        .xphs_addr(xphs_addr),
        .xphs_len_minus_1(xphs_len_minus_1),
        .W_addr(W_addr),
        .W_n_bytes(W_n_bytes),
        .B_addr(B_addr),
        .X_addr(X_addr),
        .Y_addr(Y_addr),
        .OC(OC),
        .INC2_minus_1(INC2_minus_1),
        .INW_(INW_),
        .KH_minus_1(KH_minus_1),
        .KW_minus_1(KW_minus_1),
        .strideH(strideH),
        .strideW(strideW),
        .padL(padL),
        .padU(padU),
        .INH2(INH2),
        .INW2(INW2),
        .ifm_height(ifm_height),
        .ofm_height(ofm_height),
        .n_last_batch(n_last_batch),
        .n_W_rnd_minus_1(n_W_rnd_minus_1),
        .row_bound(row_bound),
        .col_bound(col_bound),
        .vec_size(vec_size),
        .vec_size_minus_1(vec_size_minus_1),
        .Xz(Xz),
        .Wz(Wz),
        .Yz(Yz),
        .m1(m1),
        .n1(n1),
        .obj1(obj1),
        .obj2(obj2),
        .obj3(obj3),
        .obj4(obj4)
    );

    Conv_sync Conv_sync_inst(
        .clk(main_clk),
        .start_pulse(local_start_pulse),
        .W_addr(W_addr),
        .n_X_rnd_minus_1(xphs_len_minus_1),
        .n_W_rnd_minus_1(n_W_rnd_minus_1),
        .vec_size2_minus_1(vec_size_minus_1),
        .W_n_bytes(W_n_bytes),
        .cwm_sta_addr(cwm_sta_addr),
        .cwm_ic_d2c_start_pulse(cwm_ic_d2c_start_pulse),
        .cwm_ic_d2c_d_addr(cwm_ic_d2c_d_addr),
        .cwm_ic_d2c_c_addr(cwm_ic_d2c_c_addr),
        .cwm_ic_d2c_n_bytes(cwm_ic_d2c_n_bytes),
        .cwm_wr_ptr(cwm_wr_ptr),
        .cwm_rd_en(cwm_rd_en),
        .cwm_rd_addr(cwm_rd_addr),
        .cwm_dout(cwm_dout),
        .cwm_dout_vld(cwm_dout_vld),
        .mxm_rd_en(mxm_rd_en),
        .mxm_rd_last_rnd(mxm_rd_last_rnd),
        .mxm_dout(mxm_dout),
        .mxm_dout_vld(mxm_dout_vld),
        .mxm_empty(mxm_empty),
        .mxm_almost_empty(mxm_almost_empty),
        .wx_fifo_wr_en(wx_fifo_wr_en),
        .wx_fifo_din(wx_fifo_din),
        .wx_fifo_prog_full(wx_fifo_prog_full)
    );

    Conv_wx_fifo Conv_wx_fifo_inst(
        .main_clk(main_clk),
        .wr_en(wx_fifo_wr_en),
        .din(wx_fifo_din),
        .prog_full(wx_fifo_prog_full),
        .sa_clk(sa_clk),
        .rd_en(wx_fifo_rd_en),
        .empty(wx_fifo_empty),
        .almost_empty(wx_fifo_almost_empty),
        .dout(wx_fifo_dout)
    );

    Conv_sa_shift Conv_sa_shift_inst(
`ifdef DEBUG
        .dbg_mat_vec_begin(dbg_sa_mat_vec_begin),
        .dbg_mat_vec_end(dbg_sa_mat_vec_end),
        .dbg_mat_vec_rst(dbg_sa_mat_vec_rst),
`endif
        .clk(sa_clk),
        .mat_w1(sa_mat_w1),
        .mat_w2(sa_mat_w2),
        .mat_x(sa_mat_x),
        .mat_wz(sa_mat_wz),
        .mat_y1(sa_mat_y1),
        .mat_y2(sa_mat_y2),
        .mat_rst(sa_mat_rst),
        .mat_flush(sa_mat_flush),
        .mat_psum_vld(sa_mat_psum_vld),
        .mat_psum_last_rnd(sa_mat_psum_last_rnd),
        .mat_psum_wr_addr(sa_mat_psum_wr_addr),
        .mat_psum_prefetch_addr(sa_mat_psum_prefetch_addr),
        .post_rstp(sa_post_rstp),
        .post_sel(sa_post_sel)
    );

    xpm_cdc_array_single #(
      .DEST_SYNC_FF(10),
      .INIT_SYNC_FF(1),
      .SIM_ASSERT_CHK(0),
      .SRC_INPUT_REG(1),
      .WIDTH(8)
   ) xpm_cdc_array_single_inst (
        .dest_out(wz_sa_clk),
        .dest_clk(sa_clk),
        .src_clk(main_clk),
        .src_in(Wz)
   );

    Conv_sa_ctrl Conv_sa_ctrl_inst(
        .clk(sa_clk),
        .wz(wz_sa_clk),
        .wx_fifo_rd_en(wx_fifo_rd_en),
        .wx_fifo_dout(wx_fifo_dout),
        .wx_fifo_empty(wx_fifo_empty),
        .wx_fifo_almost_empty(wx_fifo_almost_empty),
        .sa_mat_w1(sa_mat_w1),
        .sa_mat_w2(sa_mat_w2),
        .sa_mat_x(sa_mat_x),
        .sa_mat_wz(sa_mat_wz),
`ifdef DEBUG
        .dbg_sa_mat_vec_begin(dbg_sa_mat_vec_begin),
        .dbg_sa_mat_vec_end(dbg_sa_mat_vec_end),
        .dbg_sa_mat_vec_rst(dbg_sa_mat_vec_rst),
`endif
        .sa_mat_rst(sa_mat_rst),
        .sa_mat_flush(sa_mat_flush),
        .sa_mat_psum_vld(sa_mat_psum_vld),
        .sa_mat_psum_last_rnd(sa_mat_psum_last_rnd),
        .sa_mat_psum_wr_addr(sa_mat_psum_wr_addr),
        .sa_mat_psum_prefetch_addr(sa_mat_psum_prefetch_addr),
        .sa_post_rstp(sa_post_rstp),
        .sa_post_sel(sa_post_sel),
        .sa_mat_y1(sa_mat_y1),
        .sa_mat_y2(sa_mat_y2),
        .dp_fifo_prog_full(dp_fifo_prog_full),
        .dp_fifo_wr_en(dp_fifo_wr_en),
        .dp_fifo_din(dp_fifo_din)
    );

    Conv_dp_fifo Conv_dp_fifo_inst(
        .sa_clk(sa_clk),
        .wr_en(dp_fifo_wr_en),
        .din(dp_fifo_din),
        .prog_full(dp_fifo_prog_full),
        .main_clk(main_clk),
        .rd_en(dp_fifo_rd_en),
        .dout(dp_fifo_dout),
        .empty(dp_fifo_empty),
        .almost_empty(dp_fifo_almost_empty)
    );

    sync_fifo #(
        .DATA_WIDTH(64),
        .DEPTH(32),
        .PROG_FULL(8),
        .READ_LATENCY(3),
        .HAS_EMPTY(1),
        .HAS_ALMOST_EMPTY(1),
        .HAS_DATA_VALID(1),
        .HAS_PROG_FULL(1),
        .RAM_STYLE("distributed")
    ) bias_fifo_inst(
        .clk(main_clk),
        .rd_en(bias_fifo_rd_en),
        .dout(bias_fifo_dout),
        .data_valid(bias_fifo_data_valid),
        .empty(bias_fifo_empty),
        .almost_empty(bias_fifo_almost_empty),
        .wr_en(bias_fifo_wr_en),
        .din(bias_fifo_din),
        .prog_full(bias_fifo_prog_full)
    );

    Conv_bias_fifo_wr Conv_bias_fifo_wr_inst(
        .clk(main_clk),
        .start_pulse(local_start_pulse),
        .B_addr(B_addr),
        .n_X_rnd_minus_1(xphs_len_minus_1),
        .n_W_rnd_minus_1(n_W_rnd_minus_1),
        .bm_rd_en(bm_rd_en),
        .bm_rd_addr(bm_rd_addr),
        .bm_dout(bm_dout),
        .bm_dout_vld(bm_dout_vld),
        .fifo_wr_en(bias_fifo_wr_en),
        .fifo_din(bias_fifo_din),
        .fifo_prog_full(bias_fifo_prog_full)
    );

    Conv_ppus_pre Conv_ppus_pre_inst(
        .clk(main_clk),
        .m1(m1),
        .n1(n1),
        .Yz(Yz),
        .bias_fifo_rd_en(bias_fifo_rd_en),
        .bias_fifo_dout(bias_fifo_dout),
        .bias_fifo_data_valid(bias_fifo_data_valid),
        .dp_fifo_rd_en(dp_fifo_rd_en),
        .dp_fifo_empty(dp_fifo_empty),
        .dp_fifo_almost_empty(dp_fifo_almost_empty),
        .dp_fifo_dout(dp_fifo_dout),
        .ppus_dps(ppus_dps),
        .ppus_bias(ppus_bias),
        .ppus_dps_vld(ppus_dps_vld),
        .ppus_m1(ppus_m1),
        .ppus_n1(ppus_n1),
        .ppus_Yz(ppus_Yz)
    );

    Conv_wb Conv_wb_inst(
        .clk(main_clk),
        .start_pulse(local_start_pulse),
        .done_pulse(done_pulse),
        .Y_addr(Y_addr),
        .n_W_rnd_minus_1(n_W_rnd_minus_1),
        .n_X_rnd_minus_1(xphs_len_minus_1),
        .ofm_height(ofm_height),
        .n_last_batch(n_last_batch),
        .ppus_outs(ppus_outs),
        .ppus_out_vld(ppus_out_vld),
        .rtm_wr_vld(rtm_wr_vld),
        .rtm_wr_en(rtm_wr_en),
        .rtm_wr_addr(rtm_wr_addr),
        .rtm_din(rtm_din)
    );
endmodule
