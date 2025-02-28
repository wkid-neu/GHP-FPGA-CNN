`timescale 1ns / 1ps
`include "../../incl.vh"

//
// The Pool instruction
//
module Pool (
    input clk,
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
    // ppus inputs
    output [(`P/2)*14-1:0] ppus_Ys,
    output ppus_Ys_vld,
    output signed [15:0] ppus_neg_NXz,
    output [7:0] ppus_Yz,
    output [25:0] ppus_m1,
    output [5:0] ppus_n1,
    // ppus outputs
    input [(`P/2)*8-1:0] ppus_outs,
    input ppus_out_vld,
    // RTM write ports
    output rtm_wr_vld,
    output [`S-1:0] rtm_wr_en,
    output [`S*$clog2(`RTM_DEPTH)-1:0] rtm_wr_addr,
    output [`S*`R*8-1:0] rtm_din
);
    wire [`INS_RAM_DATA_WIDTH-1:0] local_ins;
    wire local_start_pulse;

    wire is_maxp;
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
    wire signed [15:0] neg_NXz;

    wire [`P*2*8-1:0] pe_arr_xs;
    wire [3:0] pe_arr_cmd;
    wire [$clog2(`S/2)-1:0] pe_arr_sel;
    wire [$clog2(`S/2)-1:0] pe_arr_sel_delay;
    wire [`P*2*14-1:0] pe_arr_ys;
    wire pe_arr_y_vld;

    wire out_fifo_rd_en;
    wire [`P*2*14-1:0] out_fifo_dout;
    wire out_fifo_dout_vld;
    wire out_fifo_empty;

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

    shift_reg #(1, 1) shift_reg_is_maxp(clk, (local_ins[7:0]==`INS_MAXP), is_maxp);
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
    assign neg_NXz = {obj2, obj1};

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

    Pool_arr_ctrl Pool_arr_ctrl_inst(
        .clk(clk),
        .start_pulse(local_start_pulse),
        .is_maxp(is_maxp),
        .vec_size_minus_1(vec_size_minus_1),
        .mxm_rd_en(mxm_rd_en),
        .mxm_rd_last_rnd(mxm_rd_last_rnd),
        .mxm_dout(mxm_dout),
        .mxm_dout_vld(mxm_dout_vld),
        .mxm_empty(mxm_empty),
        .mxm_almost_empty(mxm_almost_empty),
        .pe_arr_xs(pe_arr_xs),
        .pe_arr_cmd(pe_arr_cmd),
        .pe_arr_sel(pe_arr_sel),
        .pe_arr_sel_delay(pe_arr_sel_delay)
    );

    Pool_arr Pool_arr_inst(
        .clk(clk),
        .xs(pe_arr_xs),
        .cmd(pe_arr_cmd),
        .sel(pe_arr_sel),
        .sel_delay(pe_arr_sel_delay),
        .ys(pe_arr_ys),
        .y_vld(pe_arr_y_vld)
    );

    sync_fifo #(
        .DATA_WIDTH(`P*2*14),
        .DEPTH(32),
        .READ_LATENCY(1),
        .HAS_EMPTY(1),
        .HAS_ALMOST_EMPTY(0),
        .HAS_DATA_VALID(1),
        .HAS_PROG_FULL(0),
        .RAM_STYLE("distributed")
    ) out_fifo_inst(
        .clk(clk),
        .rd_en(out_fifo_rd_en),
        .dout(out_fifo_dout),
        .data_valid(out_fifo_dout_vld),
        .empty(out_fifo_empty),
        .wr_en(pe_arr_y_vld),
        .din(pe_arr_ys)
    );

    Pool_ppus_pre Pool_ppus_pre_inst(
        .clk(clk),
        .m1(m1),
        .n1(n1),
        .neg_NXz(neg_NXz),
        .Yz(Yz),
        .out_fifo_rd_en(out_fifo_rd_en),
        .out_fifo_dout(out_fifo_dout),
        .out_fifo_dout_vld(out_fifo_dout_vld),
        .out_fifo_empty(out_fifo_empty),
        .ppus_Ys(ppus_Ys),
        .ppus_Ys_vld(ppus_Ys_vld),
        .ppus_neg_NXz(ppus_neg_NXz),
        .ppus_Yz(ppus_Yz),
        .ppus_m1(ppus_m1),
        .ppus_n1(ppus_n1)
    );

    Pool_wb Pool_wb_inst(
        .clk(clk),
        .start_pulse(local_start_pulse),
        .done_pulse(done_pulse),
        .Y_addr(Y_addr),
        .INC2_minus_1(INC2_minus_1),
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
