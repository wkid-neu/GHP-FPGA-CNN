`timescale 1ns / 1ps
`include "../../incl.vh"

//
// The Fc instruction
// Parameter contrains:
// (1) T-mode
//   INC>=16, OC%64==0, OC*INC<(1<<27)
// (2) V-mode
//   INC>=16, OC%64==0, OC*INC<(1<<27)
//
module Fc (
    input clk,
    input start_pulse,
    output done_pulse,
    // instruction
    input [`INS_RAM_DATA_WIDTH-1:0] ins,
    // BM read ports
    output bm_rd_en,
    output [$clog2(`BM_DEPTH)-1:0] bm_rd_addr,
    input [`BM_DATA_WIDTH-1:0] bm_dout,
    input bm_dout_vld,
    // Weights (DMA)
    output [`DDR_AXI_ADDR_WIDTH-1:0] dma_rd_desc_addr,
    output [`DDR_LEN_WIDTH-1:0] dma_rd_desc_len,
    output dma_rd_desc_valid,
    input [`DDR_AXIS_DATA_WIDTH-1:0] dma_rd_read_data_tdata,
    input dma_rd_read_data_tvalid,
    output dma_rd_read_data_tready,
    input dma_rd_read_data_tlast,
    // ppus inputs
    output [`DDR_AXIS_DATA_WIDTH/8*32-1:0] ppus_accs,
    output [`DDR_AXIS_DATA_WIDTH/8*32-1:0] ppus_bias,
    output ppus_accs_vld,
    output ppus_accs_last,
    output [25:0] ppus_m1,
    output [5:0] ppus_n1, 
    output [7:0] ppus_Yz,
    // ppus outputs
    input [`DDR_AXIS_DATA_WIDTH/8*8-1:0] ppus_outs,
    input ppus_out_vld,
    input ppus_out_last,
    // RTM read ports
    output rtm_rd_vld,
    output [`S-1:0] rtm_rd_en,
    output rtm_rd_vec_begin,
    output rtm_rd_vec_end,
    output rtm_rd_last,
    output [`S*$clog2(`RTM_DEPTH)-1:0] rtm_rd_addr,
    input [`S*`R*8-1:0] rtm_dout,
    input rtm_dout_vld,
    input rtm_dout_vec_begin,
    input rtm_dout_vec_end,
    input rtm_dout_last,
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
    wire [15:0] n_rnd_minus_1;
    wire x_mode;

    wire x_fifo_wr_en;
    wire [8:0] x_fifo_din;
    wire x_fifo_din_vec_begin;
    wire x_fifo_din_vec_end;
    wire x_fifo_din_last;
    wire x_fifo_prog_full;
    wire x_fifo_rd_en;
    wire [8:0] x_fifo_dout;
    wire x_fifo_dout_vec_begin;
    wire x_fifo_dout_vec_end;
    wire x_fifo_dout_last;
    wire x_fifo_empty;
    wire x_fifo_almost_empty;

    wire w_fifo_wr_en;
    wire [`DDR_AXIS_DATA_WIDTH/8*9-1:0] w_fifo_din;
    wire w_fifo_prog_full;
    wire w_fifo_rd_en;
    wire [`DDR_AXIS_DATA_WIDTH/8*9-1:0] w_fifo_dout;
    wire w_fifo_empty;
    wire w_fifo_almost_empty;

    wire [8:0] mat_x;
    wire [`DDR_AXIS_DATA_WIDTH/8*9-1:0] mat_w;
    wire mat_begin;
    wire mat_end;
    wire mat_end_last;
    wire [`DDR_AXIS_DATA_WIDTH/8*32-1:0] mat_y;
    wire mat_y_vld;
    wire mat_y_last;

    wire [`DDR_AXIS_DATA_WIDTH/8*32-1:0] bias;
    wire read_next_bias;

`ifdef M32P64Q16R16S8
    shift_reg #(1, `INS_RAM_DATA_WIDTH) shift_reg_ins(clk, ins, local_ins);
    shift_reg #(1, 1) shift_reg_start_pulse(clk, start_pulse, local_start_pulse);
`elsif M32P96Q16R16S8
    shift_reg #(1, `INS_RAM_DATA_WIDTH) shift_reg_ins(clk, ins, local_ins);
    shift_reg #(1, 1) shift_reg_start_pulse(clk, start_pulse, local_start_pulse);
`elsif M64P64Q16R16S8
    shift_reg #(1, `INS_RAM_DATA_WIDTH) shift_reg_ins(clk, ins, local_ins);
    shift_reg #(1, 1) shift_reg_start_pulse(clk, start_pulse, local_start_pulse);
`else
    assign local_ins = ins;
    assign local_start_pulse = start_pulse;
`endif

    assign n_rnd_minus_1 = xphs_len_minus_1;
    assign x_mode = obj1[0];

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

    Fc_x_rd Fc_x_rd_inst(
    	.clk(clk),
        .start_pulse(local_start_pulse),
        .x_addr(X_addr),
        .vec_size_minus_1(vec_size_minus_1),
        .n_rnd_minus_1(n_rnd_minus_1),
        .xz(Xz),
        .x_mode(x_mode),
        .rtm_rd_vld(rtm_rd_vld),
        .rtm_rd_en(rtm_rd_en),
        .rtm_rd_vec_begin(rtm_rd_vec_begin),
        .rtm_rd_vec_end(rtm_rd_vec_end),
        .rtm_rd_last(rtm_rd_last),
        .rtm_rd_addr(rtm_rd_addr),
        .rtm_dout(rtm_dout),
        .rtm_dout_vld(rtm_dout_vld),
        .rtm_dout_vec_begin(rtm_dout_vec_begin),
        .rtm_dout_vec_end(rtm_dout_vec_end),
        .rtm_dout_last(rtm_dout_last),
        .x_fifo_wr_en(x_fifo_wr_en),
        .x_fifo_din(x_fifo_din),
        .x_fifo_din_vec_begin(x_fifo_din_vec_begin),
        .x_fifo_din_vec_end(x_fifo_din_vec_end),
        .x_fifo_din_last(x_fifo_din_last),
        .x_fifo_prog_full(x_fifo_prog_full)
    );

    sync_fifo #(
        .DATA_WIDTH(9+3),
        .DEPTH(32),
        .PROG_FULL(8),
        .HAS_EMPTY(1),
        .HAS_ALMOST_EMPTY(1),
        .HAS_PROG_FULL(1),
        .RAM_STYLE("distributed")
    ) Fc_x_fifo_inst(
        .clk(clk),
        .rd_en(x_fifo_rd_en),
        .dout({x_fifo_dout_last, x_fifo_dout_vec_end, x_fifo_dout_vec_begin, x_fifo_dout}),
        .empty(x_fifo_empty),
        .almost_empty(x_fifo_almost_empty),
        .wr_en(x_fifo_wr_en),
        .din({x_fifo_din_last, x_fifo_din_vec_end, x_fifo_din_vec_begin, x_fifo_din}),
        .prog_full(x_fifo_prog_full)
    );

    Fc_w_rd Fc_w_rd_inst(
        .clk(clk),
        .start_pulse(local_start_pulse),
        .wz(Wz),
        .w_addr(W_addr),
        .w_n_bytes(W_n_bytes),
        .dma_rd_desc_addr(dma_rd_desc_addr),
        .dma_rd_desc_len(dma_rd_desc_len),
        .dma_rd_desc_valid(dma_rd_desc_valid),
        .dma_rd_read_data_tdata(dma_rd_read_data_tdata),
        .dma_rd_read_data_tvalid(dma_rd_read_data_tvalid),
        .dma_rd_read_data_tready(dma_rd_read_data_tready),
        .dma_rd_read_data_tlast(dma_rd_read_data_tlast),
        .w_fifo_wr_en(w_fifo_wr_en),
        .w_fifo_din(w_fifo_din),
        .w_fifo_prog_full(w_fifo_prog_full)
    );

    sync_fifo #(
        .DATA_WIDTH(`DDR_AXIS_DATA_WIDTH/8*9),
        .DEPTH(32),
        .PROG_FULL(8),
        .HAS_EMPTY(1),
        .HAS_ALMOST_EMPTY(1),
        .HAS_PROG_FULL(1),
        .RAM_STYLE("distributed")
    ) Fc_w_fifo_inst(
        .clk(clk),
        .rd_en(w_fifo_rd_en),
        .dout(w_fifo_dout),
        .empty(w_fifo_empty),
        .almost_empty(w_fifo_almost_empty),
        .wr_en(w_fifo_wr_en),
        .din(w_fifo_din),
        .prog_full(w_fifo_prog_full)
    );

    Fc_sync Fc_sync_inst(
        .clk(clk),
        .x_fifo_empty(x_fifo_empty),
        .x_fifo_almost_empty(x_fifo_almost_empty),
        .x_fifo_rd_en(x_fifo_rd_en),
        .x_fifo_dout(x_fifo_dout),
        .x_fifo_dout_vec_begin(x_fifo_dout_vec_begin),
        .x_fifo_dout_vec_end(x_fifo_dout_vec_end),
        .x_fifo_dout_last(x_fifo_dout_last),
        .w_fifo_empty(w_fifo_empty),
        .w_fifo_almost_empty(w_fifo_almost_empty),
        .w_fifo_rd_en(w_fifo_rd_en),
        .w_fifo_dout(w_fifo_dout),
        .mat_x(mat_x),
        .mat_w(mat_w),
        .mat_begin(mat_begin),
        .mat_end(mat_end),
        .mat_end_last(mat_end_last)
    );

    Fc_pe_arr Fc_pe_arr_inst(
        .clk(clk),
        .mat_x(mat_x),
        .mat_w(mat_w),
        .mat_begin(mat_begin),
        .mat_end(mat_end),
        .mat_end_last(mat_end_last),
        .mat_y(mat_y),
        .mat_y_vld(mat_y_vld),
        .mat_y_last(mat_y_last)
    );

    Fc_bias_pre Fc_bias_pre_inst(
        .clk(clk),
        .start_pulse(local_start_pulse),
        .B_addr(B_addr),
        .bm_rd_en(bm_rd_en),
        .bm_rd_addr(bm_rd_addr),
        .bm_dout(bm_dout),
        .bm_dout_vld(bm_dout_vld),
        .bias(bias),
        .read_next(read_next_bias)
    );

    Fc_ppus_pre Fc_ppus_pre_inst(
        .clk(clk),
        .m1(m1),
        .n1(n1),
        .Yz(Yz),
        .bias(bias),
        .read_next_bias(read_next_bias),
        .mat_y(mat_y),
        .mat_y_vld(mat_y_vld),
        .mat_y_last(mat_y_last),
        .ppus_accs(ppus_accs),
        .ppus_bias(ppus_bias),
        .ppus_accs_vld(ppus_accs_vld),
        .ppus_accs_last(ppus_accs_last),
        .ppus_m1(ppus_m1),
        .ppus_n1(ppus_n1),
        .ppus_Yz(ppus_Yz)
    );

    Fc_wb Fc_wb_inst(
        .clk(clk),
        .start_pulse(local_start_pulse),
        .done_pulse(done_pulse),
        .y_addr(Y_addr),
        .ppus_outs(ppus_outs),
        .ppus_out_vld(ppus_out_vld),
        .ppus_out_last(ppus_out_last),
        .rtm_wr_vld(rtm_wr_vld),
        .rtm_wr_en(rtm_wr_en),
        .rtm_wr_addr(rtm_wr_addr),
        .rtm_din(rtm_din)
    );
endmodule
