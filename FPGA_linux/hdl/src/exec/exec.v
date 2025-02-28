`timescale 1ns / 1ps
`include "../incl.vh"

//
// Instruction executor
//
module exec (
    input main_clk,
    input sa_clk,
    input sys_rst,
    // host control signals (hc_*)
    input hc_exec_start_pulse,
    output hc_exec_done_pulse,
    output [`LATENCY_COUNTER_WIDTH-1:0] conv_latency,
    output [`LATENCY_COUNTER_WIDTH-1:0] pool_latency,
    output [`LATENCY_COUNTER_WIDTH-1:0] add_latency,
    output [`LATENCY_COUNTER_WIDTH-1:0] remap_latency,
    output [`LATENCY_COUNTER_WIDTH-1:0] fc_latency,
    // IM read ports
    output im_rd_en,
    output [$clog2(`INS_RAM_DEPTH)-1:0] im_rd_addr,
    input [`INS_RAM_DATA_WIDTH-1:0] im_dout,
    input im_dout_vld,
    // XPHM read ports
    output xphm_rd_en,
    output xphm_rd_last,
    output [$clog2(`XPHM_DEPTH)-1:0] xphm_rd_addr,
    input [`XPHM_DATA_WIDTH-1:0] xphm_dout,
    input xphm_dout_vld,
    input xphm_dout_last,
    // BM read ports (for conv)
    output bm_rd_en_conv,
    output [$clog2(`BM_DEPTH)-1:0] bm_rd_addr_conv,
    input [`BM_DATA_WIDTH-1:0] bm_dout_conv,
    input bm_dout_vld_conv,
    // BM read ports (for fc)
    output bm_rd_en_fc,
    output [$clog2(`BM_DEPTH)-1:0] bm_rd_addr_fc,
    input [`BM_DATA_WIDTH-1:0] bm_dout_fc,
    input bm_dout_vld_fc,
    // CWM control and read ports
    output cwm_ic_d2c_start_pulse,
    output [31:0] cwm_ic_d2c_d_addr,
    output [31:0] cwm_ic_d2c_c_addr,
    output [31:0] cwm_ic_d2c_n_bytes,
    input [$clog2(`CWM_DEPTH):0] cwm_wr_ptr,
    output cwm_rd_en,
    output [$clog2(`CWM_DEPTH)-1:0] cwm_rd_addr,
    input [`M*4*8-1:0] cwm_dout,
    input cwm_dout_vld,
    // Fc weights
    output [`DDR_AXI_ADDR_WIDTH-1:0] dma_rd_desc_addr_fc,
    output [`DDR_LEN_WIDTH-1:0] dma_rd_desc_len_fc,
    output dma_rd_desc_valid_fc,
    input [`DDR_AXIS_DATA_WIDTH-1:0] dma_rd_read_data_tdata_fc,
    input dma_rd_read_data_tvalid_fc,
    output dma_rd_read_data_tready_fc,
    input dma_rd_read_data_tlast_fc,
    // RTM read ports (for X-bus)
    output rtm_rd_vld_xbus,
    output [`S-1:0] rtm_rd_en_xbus,
    output [`XPHM_DATA_WIDTH+$clog2(`R/`Q)+1:0] rtm_rd_att_xbus,
    output [`S*$clog2(`RTM_DEPTH)-1:0] rtm_rd_addr_xbus,
    input [`S*`R*8-1:0] rtm_dout_xbus,
    input [`XPHM_DATA_WIDTH+$clog2(`R/`Q)+1:0] rtm_dout_att_xbus,
    input rtm_dout_vld_xbus,
    // RTM read ports (for Add)
    output rtm_rd_vld_add,
    output rtm_rd_last_add,
    output [`S-1:0] rtm_rd_en_add,
    output [`S*$clog2(`RTM_DEPTH)-1:0] rtm_rd_addr_add,
    input [`S*`R*8-1:0] rtm_dout_add,
    input rtm_dout_vld_add,
    input rtm_dout_last_add,
    // RTM read ports (for Remap)
    output rtm_rd_vld_remap,
    output rtm_rd_last_remap,
    output [`S-1:0] rtm_rd_en_remap,
    output [`S*$clog2(`RTM_DEPTH)-1:0] rtm_rd_addr_remap,
    input [`S*`R*8-1:0] rtm_dout_remap,
    input rtm_dout_vld_remap,
    input rtm_dout_last_remap,
    // RTM read ports (for Fc)
    output rtm_rd_vld_fc,
    output [`S-1:0] rtm_rd_en_fc,
    output rtm_rd_vec_begin_fc,
    output rtm_rd_vec_end_fc,
    output rtm_rd_last_fc,
    output [`S*$clog2(`RTM_DEPTH)-1:0] rtm_rd_addr_fc,
    input [`S*`R*8-1:0] rtm_dout_fc,
    input rtm_dout_vld_fc,
    input rtm_dout_vec_begin_fc,
    input rtm_dout_vec_end_fc,
    input rtm_dout_last_fc,
    // RTM write ports (for Conv)
    output rtm_wr_vld_conv,
    output [`S-1:0] rtm_wr_en_conv,
    output [`S*$clog2(`RTM_DEPTH)-1:0] rtm_wr_addr_conv,
    output [`S*`R*8-1:0] rtm_din_conv,
    // RTM write ports (for Pool)
    output rtm_wr_vld_pool,
    output [`S-1:0] rtm_wr_en_pool,
    output [`S*$clog2(`RTM_DEPTH)-1:0] rtm_wr_addr_pool,
    output [`S*`R*8-1:0] rtm_din_pool,
    // RTM write ports (for Add)
    output rtm_wr_vld_add,
    output [`S-1:0] rtm_wr_en_add,
    output [`S*$clog2(`RTM_DEPTH)-1:0] rtm_wr_addr_add,
    output [`S*`R*8-1:0] rtm_din_add,
    // RTM write ports (for Remap)
    output rtm_wr_vld_remap,
    output [`S-1:0] rtm_wr_en_remap,
    output [`S*$clog2(`RTM_DEPTH)-1:0] rtm_wr_addr_remap,
    output [`S*`R*8-1:0] rtm_din_remap,
    // RTM write ports (for Fc)
    output rtm_wr_vld_fc,
    output [`S-1:0] rtm_wr_en_fc,
    output [`S*$clog2(`RTM_DEPTH)-1:0] rtm_wr_addr_fc,
    output [`S*`R*8-1:0] rtm_din_fc
);
    wire is_conv;
    wire conv_start_pulse;
    wire conv_done_pulse;
    wire [`INS_RAM_DATA_WIDTH-1:0] conv_ins;
    wire conv_xbus_start_pulse;
    wire [$clog2(`XPHM_DEPTH)-1:0] conv_xbus_xphm_addr;
    wire [$clog2(`XPHM_DEPTH)-1:0] conv_xbus_xphm_len_minus_1;
    wire [$clog2(`RTM_DEPTH)-1:0] conv_xbus_X_addr;
    wire [15:0] conv_xbus_INC2_minus_1;
    wire [15:0] conv_xbus_INW_;
    wire [15:0] conv_xbus_INH2;
    wire [15:0] conv_xbus_INW2;
    wire [7:0] conv_xbus_KH_minus_1;
    wire [7:0] conv_xbus_KW_minus_1;
    wire [3:0] conv_xbus_strideH;
    wire [3:0] conv_xbus_strideW;
    wire [3:0] conv_xbus_padL;
    wire [3:0] conv_xbus_padU;
    wire [15:0] conv_xbus_ifm_height;
    wire [15:0] conv_xbus_row_bound;
    wire [15:0] conv_xbus_col_bound;
    wire [7:0] conv_xbus_Xz;
    wire [15:0] conv_mxm_vec_size;
    wire [15:0] conv_mxm_vec_size_minus_1;
    wire conv_mxm_rd_en;
    wire conv_mxm_rd_last_rnd;
    wire [`P*2*8-1:0] conv_mxm_dout;
    wire conv_mxm_dout_vld;
    wire [`S*`R*32-1:0] conv_ppus_dps;
    wire [`S*32-1:0] conv_ppus_bias;
    wire conv_ppus_dps_vld;
    wire [25:0] conv_ppus_m1;
    wire [5:0] conv_ppus_n1;
    wire [7:0] conv_ppus_Yz;
    wire [`S*`R*8-1:0] conv_ppus_outs;
    wire conv_ppus_out_vld;

    wire is_pool;
    wire pool_start_pulse;
    wire pool_done_pulse;
    wire [`INS_RAM_DATA_WIDTH-1:0] pool_ins;
    wire pool_xbus_start_pulse;
    wire [$clog2(`XPHM_DEPTH)-1:0] pool_xbus_xphm_addr;
    wire [$clog2(`XPHM_DEPTH)-1:0] pool_xbus_xphm_len_minus_1;
    wire [$clog2(`RTM_DEPTH)-1:0] pool_xbus_X_addr;
    wire [15:0] pool_xbus_INC2_minus_1;
    wire [15:0] pool_xbus_INW_;
    wire [15:0] pool_xbus_INH2;
    wire [15:0] pool_xbus_INW2;
    wire [7:0] pool_xbus_KH_minus_1;
    wire [7:0] pool_xbus_KW_minus_1;
    wire [3:0] pool_xbus_strideH;
    wire [3:0] pool_xbus_strideW;
    wire [3:0] pool_xbus_padL;
    wire [3:0] pool_xbus_padU;
    wire [15:0] pool_xbus_ifm_height;
    wire [15:0] pool_xbus_row_bound;
    wire [15:0] pool_xbus_col_bound;
    wire [7:0] pool_xbus_Xz;
    wire [15:0] pool_mxm_vec_size;
    wire [15:0] pool_mxm_vec_size_minus_1;
    wire pool_mxm_rd_en;
    wire pool_mxm_rd_last_rnd;
    wire [`P*2*8-1:0] pool_mxm_dout;
    wire pool_mxm_dout_vld;
    wire [(`P/2)*14-1:0] pool_ppus_Ys;
    wire pool_ppus_Ys_vld;
    wire signed [15:0] pool_ppus_neg_NXz;
    wire [7:0] pool_ppus_Yz;
    wire [25:0] pool_ppus_m1;
    wire [5:0] pool_ppus_n1;
    wire [(`P/2)*8-1:0] pool_ppus_outs;
    wire pool_ppus_out_vld;

    wire mxm_wr_en;
    wire [`P*2*8-1:0] mxm_din;
    wire mxm_prog_full;
    wire mxm_empty;
    wire mxm_almost_empty;

    wire is_add;
    wire add_start_pulse;
    wire add_done_pulse;
    wire [`INS_RAM_DATA_WIDTH-1:0] add_ins;
    wire [`S*`R*9-1:0] add_Xs;
    wire add_Xs_vld;
    wire add_Xs_last;
    wire [25:0] add_m1;
    wire [25:0] add_m2;
    wire [5:0] add_n;
    wire [7:0] add_Cz;
    wire [`S*`R*8-1:0] add_ppus_outs;
    wire add_ppus_out_vld;
    wire add_ppus_out_last;

    wire is_remap;
    wire remap_start_pulse;
    wire remap_done_pulse;
    wire [`INS_RAM_DATA_WIDTH-1:0] remap_ins;
    wire [`S*`R*8-1:0] remap_Xs;
    wire remap_Xs_vld;
    wire remap_Xs_last;
    wire signed [8:0] remap_neg_Xz;
    wire [7:0] remap_Yz;
    wire [25:0] remap_m1;
    wire [5:0] remap_n1;
    wire [`S*`R*8-1:0] remap_ppus_outs;
    wire remap_ppus_out_vld;
    wire remap_ppus_out_last;

    wire is_fc;
    wire fc_start_pulse;
    wire fc_done_pulse;
    wire [`INS_RAM_DATA_WIDTH-1:0] fc_ins;
    wire [`DDR_AXIS_DATA_WIDTH/8*32-1:0] fc_ppus_accs;
    wire [`DDR_AXIS_DATA_WIDTH/8*32-1:0] fc_ppus_bias;
    wire fc_ppus_accs_vld;
    wire fc_ppus_accs_last;
    wire [25:0] fc_ppus_m1;
    wire [5:0] fc_ppus_n1;
    wire [7:0] fc_ppus_Yz;
    wire [`DDR_AXIS_DATA_WIDTH/8*8-1:0] fc_ppus_outs;
    wire fc_ppus_out_vld;
    wire fc_ppus_out_last;

    exec_fsm exec_fsm_inst(
        .clk(main_clk),
        .sys_rst(sys_rst),
        .start_pulse(hc_exec_start_pulse),
        .done_pulse(hc_exec_done_pulse),
        .conv_latency(conv_latency),
        .pool_latency(pool_latency),
        .add_latency(add_latency),
        .remap_latency(remap_latency),
        .fc_latency(fc_latency),
        .im_rd_en(im_rd_en),
        .im_rd_addr(im_rd_addr),
        .im_dout(im_dout),
        .im_dout_vld(im_dout_vld),
        .is_conv(is_conv),
        .conv_start_pulse(conv_start_pulse),
        .conv_ins(conv_ins),
        .conv_done_pulse(conv_done_pulse),
        .is_pool(is_pool),
        .pool_start_pulse(pool_start_pulse),
        .pool_ins(pool_ins),
        .pool_done_pulse(pool_done_pulse),
        .is_add(is_add),
        .add_start_pulse(add_start_pulse),
        .add_ins(add_ins),
        .add_done_pulse(add_done_pulse),
        .is_remap(is_remap),
        .remap_start_pulse(remap_start_pulse),
        .remap_ins(remap_ins),
        .remap_done_pulse(remap_done_pulse),
        .is_fc(is_fc),
        .fc_start_pulse(fc_start_pulse),
        .fc_ins(fc_ins),
        .fc_done_pulse(fc_done_pulse)
    );

    Conv Conv_inst(
        .main_clk(main_clk),
        .sa_clk(sa_clk),
        .start_pulse(conv_start_pulse),
        .done_pulse(conv_done_pulse),
        .ins(conv_ins),
        .xbus_start_pulse(conv_xbus_start_pulse),
        .xbus_xphm_addr(conv_xbus_xphm_addr),
        .xbus_xphm_len_minus_1(conv_xbus_xphm_len_minus_1),
        .xbus_X_addr(conv_xbus_X_addr),
        .xbus_INC2_minus_1(conv_xbus_INC2_minus_1),
        .xbus_INW_(conv_xbus_INW_),
        .xbus_INH2(conv_xbus_INH2),
        .xbus_INW2(conv_xbus_INW2),
        .xbus_KH_minus_1(conv_xbus_KH_minus_1),
        .xbus_KW_minus_1(conv_xbus_KW_minus_1),
        .xbus_strideH(conv_xbus_strideH),
        .xbus_strideW(conv_xbus_strideW),
        .xbus_padL(conv_xbus_padL),
        .xbus_padU(conv_xbus_padU),
        .xbus_ifm_height(conv_xbus_ifm_height),
        .xbus_row_bound(conv_xbus_row_bound),
        .xbus_col_bound(conv_xbus_col_bound),
        .xbus_Xz(conv_xbus_Xz),
        .mxm_vec_size(conv_mxm_vec_size),
        .mxm_vec_size_minus_1(conv_mxm_vec_size_minus_1),
        .mxm_rd_en(conv_mxm_rd_en),
        .mxm_rd_last_rnd(conv_mxm_rd_last_rnd),
        .mxm_dout(conv_mxm_dout),
        .mxm_dout_vld(conv_mxm_dout_vld),
        .mxm_empty(mxm_empty),
        .mxm_almost_empty(mxm_almost_empty),
        .cwm_ic_d2c_start_pulse(cwm_ic_d2c_start_pulse),
        .cwm_ic_d2c_d_addr(cwm_ic_d2c_d_addr),
        .cwm_ic_d2c_c_addr(cwm_ic_d2c_c_addr),
        .cwm_ic_d2c_n_bytes(cwm_ic_d2c_n_bytes),
        .cwm_wr_ptr(cwm_wr_ptr),
        .cwm_rd_en(cwm_rd_en),
        .cwm_rd_addr(cwm_rd_addr),
        .cwm_dout(cwm_dout),
        .cwm_dout_vld(cwm_dout_vld),
        .bm_rd_en(bm_rd_en_conv),
        .bm_rd_addr(bm_rd_addr_conv),
        .bm_dout(bm_dout_conv),
        .bm_dout_vld(bm_dout_vld_conv),
        .ppus_dps(conv_ppus_dps),
        .ppus_bias(conv_ppus_bias),
        .ppus_dps_vld(conv_ppus_dps_vld),
        .ppus_m1(conv_ppus_m1),
        .ppus_n1(conv_ppus_n1),
        .ppus_Yz(conv_ppus_Yz),
        .ppus_outs(conv_ppus_outs),
        .ppus_out_vld(conv_ppus_out_vld),
        .rtm_wr_vld(rtm_wr_vld_conv),
        .rtm_wr_en(rtm_wr_en_conv),
        .rtm_wr_addr(rtm_wr_addr_conv),
        .rtm_din(rtm_din_conv)
    );

    Pool Pool_inst(
        .clk(main_clk),
        .start_pulse(pool_start_pulse),
        .done_pulse(pool_done_pulse),
        .ins(pool_ins),
        .xbus_start_pulse(pool_xbus_start_pulse),
        .xbus_xphm_addr(pool_xbus_xphm_addr),
        .xbus_xphm_len_minus_1(pool_xbus_xphm_len_minus_1),
        .xbus_X_addr(pool_xbus_X_addr),
        .xbus_INC2_minus_1(pool_xbus_INC2_minus_1),
        .xbus_INW_(pool_xbus_INW_),
        .xbus_INH2(pool_xbus_INH2),
        .xbus_INW2(pool_xbus_INW2),
        .xbus_KH_minus_1(pool_xbus_KH_minus_1),
        .xbus_KW_minus_1(pool_xbus_KW_minus_1),
        .xbus_strideH(pool_xbus_strideH),
        .xbus_strideW(pool_xbus_strideW),
        .xbus_padL(pool_xbus_padL),
        .xbus_padU(pool_xbus_padU),
        .xbus_ifm_height(pool_xbus_ifm_height),
        .xbus_row_bound(pool_xbus_row_bound),
        .xbus_col_bound(pool_xbus_col_bound),
        .xbus_Xz(pool_xbus_Xz),
        .mxm_vec_size(pool_mxm_vec_size),
        .mxm_vec_size_minus_1(pool_mxm_vec_size_minus_1),
        .mxm_rd_en(pool_mxm_rd_en),
        .mxm_rd_last_rnd(pool_mxm_rd_last_rnd),
        .mxm_dout(pool_mxm_dout),
        .mxm_dout_vld(pool_mxm_dout_vld),
        .mxm_empty(mxm_empty),
        .mxm_almost_empty(mxm_almost_empty),
        .ppus_Ys(pool_ppus_Ys),
        .ppus_Ys_vld(pool_ppus_Ys_vld),
        .ppus_neg_NXz(pool_ppus_neg_NXz),
        .ppus_Yz(pool_ppus_Yz),
        .ppus_m1(pool_ppus_m1),
        .ppus_n1(pool_ppus_n1),
        .ppus_outs(pool_ppus_outs),
        .ppus_out_vld(pool_ppus_out_vld),
        .rtm_wr_vld(rtm_wr_vld_pool),
        .rtm_wr_en(rtm_wr_en_pool),
        .rtm_wr_addr(rtm_wr_addr_pool),
        .rtm_din(rtm_din_pool)
    );

    Add Add_inst(
        .clk(main_clk),
        .start_pulse(add_start_pulse),
        .done_pulse(add_done_pulse),
        .ins(add_ins),
        .rtm_rd_vld(rtm_rd_vld_add),
        .rtm_rd_last(rtm_rd_last_add),
        .rtm_rd_en(rtm_rd_en_add),
        .rtm_rd_addr(rtm_rd_addr_add),
        .rtm_dout(rtm_dout_add),
        .rtm_dout_vld(rtm_dout_vld_add),
        .rtm_dout_last(rtm_dout_last_add),
        .ppus_Xs(add_Xs),
        .ppus_Xs_vld(add_Xs_vld),
        .ppus_Xs_last(add_Xs_last),
        .ppus_m1(add_m1),
        .ppus_m2(add_m2),
        .ppus_n(add_n),
        .ppus_Cz(add_Cz),
        .ppus_outs(add_ppus_outs),
        .ppus_out_vld(add_ppus_out_vld),
        .ppus_out_last(add_ppus_out_last),
        .rtm_wr_vld(rtm_wr_vld_add),
        .rtm_wr_en(rtm_wr_en_add),
        .rtm_wr_addr(rtm_wr_addr_add),
        .rtm_din(rtm_din_add)
    );

    Remap Remap_inst(
        .clk(main_clk),
        .start_pulse(remap_start_pulse),
        .done_pulse(remap_done_pulse),
        .ins(remap_ins),
        .rtm_rd_vld(rtm_rd_vld_remap),
        .rtm_rd_last(rtm_rd_last_remap),
        .rtm_rd_en(rtm_rd_en_remap),
        .rtm_rd_addr(rtm_rd_addr_remap),
        .rtm_dout(rtm_dout_remap),
        .rtm_dout_vld(rtm_dout_vld_remap),
        .rtm_dout_last(rtm_dout_last_remap),
        .ppus_Xs(remap_Xs),
        .ppus_Xs_vld(remap_Xs_vld),
        .ppus_Xs_last(remap_Xs_last),
        .ppus_neg_Xz(remap_neg_Xz),
        .ppus_Yz(remap_Yz),
        .ppus_m1(remap_m1),
        .ppus_n1(remap_n1),
        .ppus_outs(remap_ppus_outs),
        .ppus_out_vld(remap_ppus_out_vld),
        .ppus_out_last(remap_ppus_out_last),
        .rtm_wr_vld(rtm_wr_vld_remap),
        .rtm_wr_en(rtm_wr_en_remap),
        .rtm_wr_addr(rtm_wr_addr_remap),
        .rtm_din(rtm_din_remap)
    );

    Fc Fc_inst(
        .clk(main_clk),
        .start_pulse(fc_start_pulse),
        .done_pulse(fc_done_pulse),
        .ins(fc_ins),
        .bm_rd_en(bm_rd_en_fc),
        .bm_rd_addr(bm_rd_addr_fc),
        .bm_dout(bm_dout_fc),
        .bm_dout_vld(bm_dout_vld_fc),
        .dma_rd_desc_addr(dma_rd_desc_addr_fc),
        .dma_rd_desc_len(dma_rd_desc_len_fc),
        .dma_rd_desc_valid(dma_rd_desc_valid_fc),
        .dma_rd_read_data_tdata(dma_rd_read_data_tdata_fc),
        .dma_rd_read_data_tvalid(dma_rd_read_data_tvalid_fc),
        .dma_rd_read_data_tready(dma_rd_read_data_tready_fc),
        .dma_rd_read_data_tlast(dma_rd_read_data_tlast_fc),
        .ppus_accs(fc_ppus_accs),
        .ppus_bias(fc_ppus_bias),
        .ppus_accs_vld(fc_ppus_accs_vld),
        .ppus_accs_last(fc_ppus_accs_last),
        .ppus_m1(fc_ppus_m1),
        .ppus_n1(fc_ppus_n1),
        .ppus_Yz(fc_ppus_Yz),
        .ppus_outs(fc_ppus_outs),
        .ppus_out_vld(fc_ppus_out_vld),
        .ppus_out_last(fc_ppus_out_last),
        .rtm_rd_vld(rtm_rd_vld_fc),
        .rtm_rd_en(rtm_rd_en_fc),
        .rtm_rd_vec_begin(rtm_rd_vec_begin_fc),
        .rtm_rd_vec_end(rtm_rd_vec_end_fc),
        .rtm_rd_last(rtm_rd_last_fc),
        .rtm_rd_addr(rtm_rd_addr_fc),
        .rtm_dout(rtm_dout_fc),
        .rtm_dout_vld(rtm_dout_vld_fc),
        .rtm_dout_vec_begin(rtm_dout_vec_begin_fc),
        .rtm_dout_vec_end(rtm_dout_vec_end_fc),
        .rtm_dout_last(rtm_dout_last_fc),
        .rtm_wr_vld(rtm_wr_vld_fc),
        .rtm_wr_en(rtm_wr_en_fc),
        .rtm_wr_addr(rtm_wr_addr_fc),
        .rtm_din(rtm_din_fc)
    );

    xbus xbus_inst(
        .clk(main_clk),
        .conv_start_pulse(conv_xbus_start_pulse),
        .conv_xphm_addr(conv_xbus_xphm_addr),
        .conv_xphm_len_minus_1(conv_xbus_xphm_len_minus_1),
        .conv_X_addr(conv_xbus_X_addr),
        .conv_INC2_minus_1(conv_xbus_INC2_minus_1),
        .conv_INW_(conv_xbus_INW_),
        .conv_INH2(conv_xbus_INH2),
        .conv_INW2(conv_xbus_INW2),
        .conv_KH_minus_1(conv_xbus_KH_minus_1),
        .conv_KW_minus_1(conv_xbus_KW_minus_1),
        .conv_strideH(conv_xbus_strideH),
        .conv_strideW(conv_xbus_strideW),
        .conv_padL(conv_xbus_padL),
        .conv_padU(conv_xbus_padU),
        .conv_ifm_height(conv_xbus_ifm_height),
        .conv_row_bound(conv_xbus_row_bound),
        .conv_col_bound(conv_xbus_col_bound),
        .conv_Xz(conv_xbus_Xz),
        .pool_start_pulse(pool_xbus_start_pulse),
        .pool_xphm_addr(pool_xbus_xphm_addr),
        .pool_xphm_len_minus_1(pool_xbus_xphm_len_minus_1),
        .pool_X_addr(pool_xbus_X_addr),
        .pool_INC2_minus_1(pool_xbus_INC2_minus_1),
        .pool_INW_(pool_xbus_INW_),
        .pool_INH2(pool_xbus_INH2),
        .pool_INW2(pool_xbus_INW2),
        .pool_KH_minus_1(pool_xbus_KH_minus_1),
        .pool_KW_minus_1(pool_xbus_KW_minus_1),
        .pool_strideH(pool_xbus_strideH),
        .pool_strideW(pool_xbus_strideW),
        .pool_padL(pool_xbus_padL),
        .pool_padU(pool_xbus_padU),
        .pool_ifm_height(pool_xbus_ifm_height),
        .pool_row_bound(pool_xbus_row_bound),
        .pool_col_bound(pool_xbus_col_bound),
        .pool_Xz(pool_xbus_Xz),
        .xphm_rd_en(xphm_rd_en),
        .xphm_rd_last(xphm_rd_last),
        .xphm_rd_addr(xphm_rd_addr),
        .xphm_dout(xphm_dout),
        .xphm_dout_vld(xphm_dout_vld),
        .xphm_dout_last(xphm_dout_last),
        .rtm_rd_vld(rtm_rd_vld_xbus),
        .rtm_rd_en(rtm_rd_en_xbus),
        .rtm_rd_att(rtm_rd_att_xbus),
        .rtm_rd_addr(rtm_rd_addr_xbus),
        .rtm_dout(rtm_dout_xbus),
        .rtm_dout_att(rtm_dout_att_xbus),
        .rtm_dout_vld(rtm_dout_vld_xbus),
        .mxm_wr_en(mxm_wr_en),
        .mxm_din(mxm_din),
        .mxm_prog_full(mxm_prog_full)
    );

    mxm mxm_inst(
        .clk(main_clk),
        .wr_en(mxm_wr_en),
        .din(mxm_din),
        .prog_full(mxm_prog_full),
        .is_conv(is_conv),
        .conv_vec_size(conv_mxm_vec_size),
        .conv_vec_size_minus_1(conv_mxm_vec_size_minus_1),
        .conv_rd_en(conv_mxm_rd_en),
        .conv_rd_last_rnd(conv_mxm_rd_last_rnd),
        .conv_dout(conv_mxm_dout),
        .conv_dout_vld(conv_mxm_dout_vld),
        .is_pool(is_pool),
        .pool_vec_size(pool_mxm_vec_size),
        .pool_vec_size_minus_1(pool_mxm_vec_size_minus_1),
        .pool_rd_en(pool_mxm_rd_en),
        .pool_rd_last_rnd(pool_mxm_rd_last_rnd),
        .pool_dout(pool_mxm_dout),
        .pool_dout_vld(pool_mxm_dout_vld),
        .empty(mxm_empty),
        .almost_empty(mxm_almost_empty)
    );

    ppus ppus_inst(
        .clk(main_clk),
        .is_conv(is_conv),
        .conv_dps(conv_ppus_dps),
        .conv_bias(conv_ppus_bias),
        .conv_dps_vld(conv_ppus_dps_vld),
        .conv_m1(conv_ppus_m1),
        .conv_n1(conv_ppus_n1),
        .conv_Yz(conv_ppus_Yz),
        .conv_outs(conv_ppus_outs),
        .conv_out_vld(conv_ppus_out_vld),
        .is_pool(is_pool),
        .pool_Ys(pool_ppus_Ys),
        .pool_Ys_vld(pool_ppus_Ys_vld),
        .pool_neg_NXz(pool_ppus_neg_NXz),
        .pool_Yz(pool_ppus_Yz),
        .pool_m1(pool_ppus_m1),
        .pool_n1(pool_ppus_n1),
        .pool_outs(pool_ppus_outs),
        .pool_out_vld(pool_ppus_out_vld),
        .is_add(is_add),
        .add_Xs(add_Xs),
        .add_Xs_vld(add_Xs_vld),
        .add_Xs_last(add_Xs_last),
        .add_m1(add_m1),
        .add_m2(add_m2),
        .add_n(add_n),
        .add_Cz(add_Cz),
        .add_outs(add_ppus_outs),
        .add_out_vld(add_ppus_out_vld),
        .add_out_last(add_ppus_out_last),
        .is_remap(is_remap),
        .remap_Xs(remap_Xs),
        .remap_Xs_vld(remap_Xs_vld),
        .remap_Xs_last(remap_Xs_last),
        .remap_neg_Xz(remap_neg_Xz),
        .remap_Yz(remap_Yz),
        .remap_m1(remap_m1),
        .remap_n1(remap_n1),
        .remap_outs(remap_ppus_outs),
        .remap_out_vld(remap_ppus_out_vld),
        .remap_out_last(remap_ppus_out_last),
        .is_fc(is_fc),
        .fc_accs(fc_ppus_accs),
        .fc_bias(fc_ppus_bias),
        .fc_accs_vld(fc_ppus_accs_vld),
        .fc_accs_last(fc_ppus_accs_last),
        .fc_m1(fc_ppus_m1),
        .fc_n1(fc_ppus_n1),
        .fc_Yz(fc_ppus_Yz),
        .fc_outs(fc_ppus_outs),
        .fc_out_vld(fc_ppus_out_vld),
        .fc_out_last(fc_ppus_out_last)
    );
endmodule
