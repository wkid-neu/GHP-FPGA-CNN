`timescale 1ns / 1ps
`include "../incl.vh"

//
// Remap instruction decoder
//
module id_Remap (
    input [`INS_RAM_DATA_WIDTH-1:0] ins,
    output [$clog2(`RTM_DEPTH)-1:0] X_addr,
    output [$clog2(`RTM_DEPTH)-1:0] Y_addr,
    output [$clog2(`RTM_DEPTH)-1:0] len_minus_1,
    output [25:0] m1,
    output [5:0] n1,
    output signed [8:0] neg_Xz,
    output [7:0] Yz
);
    assign X_addr = ins[39:8];
    assign Y_addr = ins[71:40];
    assign len_minus_1 = ins[103:72];
    assign m1 = ins[135:104];
    assign n1 = ins[143:136];
    assign neg_Xz = ins[159:144];
    assign Yz = ins[167:160];
endmodule

//
// Add instruction decoder
//
module id_Add (
    input [`INS_RAM_DATA_WIDTH-1:0] ins,
    output [$clog2(`RTM_DEPTH)-1:0] A_addr,
    output [$clog2(`RTM_DEPTH)-1:0] B_addr,
    output [$clog2(`RTM_DEPTH)-1:0] C_addr,
    output [$clog2(`RTM_DEPTH)-1:0] len_minus_1,
    output [25:0] m1,
    output [25:0] m2,
    output [5:0] n,
    output [7:0] Az,
    output [7:0] Bz,
    output [7:0] Cz
);
    assign A_addr = ins[39:8];
    assign B_addr = ins[71:40];
    assign C_addr = ins[103:72];
    assign len_minus_1 = ins[135:104];
    assign m1 = ins[167:136];
    assign m2 = ins[199:168];
    assign n = ins[207:200];
    assign Az = ins[215:208];
    assign Bz = ins[223:216];
    assign Cz = ins[231:224];
endmodule

//
// Conv instruction decoder
//
module id_Conv (
    input [`INS_RAM_DATA_WIDTH-1:0] ins,
    output [$clog2(`XPHM_DEPTH)-1:0] xphs_addr,
    output [15:0] xphs_len_minus_1,
    output [31:0] W_addr,
    output [31:0] W_n_bytes,
    output [$clog2(`BM_DEPTH)-1:0] B_addr,
    output [$clog2(`RTM_DEPTH)-1:0] X_addr,
    output [$clog2(`RTM_DEPTH)-1:0] Y_addr,
    output [15:0] OC,
    output [15:0] INC2_minus_1,
    output [15:0] INW_,
    output [7:0] KH_minus_1,
    output [7:0] KW_minus_1,
    output [3:0] strideH,
    output [3:0] strideW,
    output [3:0] padL,
    output [3:0] padU,
    output [15:0] INH2,
    output [15:0] INW2,
    output [15:0] ifm_height,
    output [15:0] ofm_height,
    output [7:0] n_last_batch,
    output [15:0] n_W_rnd_minus_1,
    output [15:0] row_bound,
    output [15:0] col_bound,
    output [15:0] vec_size,
    output [15:0] vec_size_minus_1,
    output [7:0] Xz,
    output [7:0] Wz,
    output [7:0] Yz,
    output [25:0] m1,
    output [5:0] n1,
    output [7:0] obj1,
    output [7:0] obj2,
    output [7:0] obj3,
    output [7:0] obj4
);
    assign xphs_addr = ins[23:8];
    assign xphs_len_minus_1 = ins[39:24];
    assign W_addr = ins[71:40];
    assign W_n_bytes = ins[103:72];
    assign B_addr = ins[119:104];
    assign X_addr = ins[151:120];
    assign Y_addr = ins[183:152];
    assign OC = ins[199:184];
    assign INC2_minus_1 = ins[215:200];
    assign INW_ = ins[231:216];
    assign KH_minus_1 = ins[239:232];
    assign KW_minus_1 = ins[247:240];
    assign strideH = ins[251:248];
    assign strideW = ins[255:252];
    assign padL = ins[259:256];
    assign padU = ins[263:260];
    assign INH2 = ins[279:264];
    assign INW2 = ins[295:280];
    assign ifm_height = ins[311:296];
    assign ofm_height = ins[327:312];
    assign n_last_batch = ins[335:328];
    assign n_W_rnd_minus_1 = ins[351:336];
    assign row_bound = ins[367:352];
    assign col_bound = ins[383:368];
    assign vec_size = ins[399:384];
    assign vec_size_minus_1 = ins[415:400];
    assign Xz = ins[423:416];
    assign Wz = ins[431:424];
    assign Yz = ins[439:432];
    assign m1 = ins[471:440];
    assign n1 = ins[479:472];
    assign obj1 = ins[487:480];
    assign obj2 = ins[495:488];
    assign obj3 = ins[503:496];
    assign obj4 = ins[511:504];
endmodule
