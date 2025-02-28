`timescale 1ns / 1ps
`include "../../incl.vh"

//
// Write controller of RTM
//
module rtm_wr_ctrl (
    input clk,
    // DRAM
    input wr_vld_dram,
    input [`S-1:0] wr_en_dram,
    input [`S*$clog2(`RTM_DEPTH)-1:0] wr_addr_dram,
    input [`S*`R*8-1:0] din_dram,
    // Conv
    input wr_vld_conv,
    input [`S-1:0] wr_en_conv,
    input [`S*$clog2(`RTM_DEPTH)-1:0] wr_addr_conv,
    input [`S*`R*8-1:0] din_conv,
    // Pool
    input wr_vld_pool,
    input [`S-1:0] wr_en_pool,
    input [`S*$clog2(`RTM_DEPTH)-1:0] wr_addr_pool,
    input [`S*`R*8-1:0] din_pool,
    // Fc
    input wr_vld_fc,
    input [`S-1:0] wr_en_fc,
    input [`S*$clog2(`RTM_DEPTH)-1:0] wr_addr_fc,
    input [`S*`R*8-1:0] din_fc,
    // Add
    input wr_vld_add,
    input [`S-1:0] wr_en_add,
    input [`S*$clog2(`RTM_DEPTH)-1:0] wr_addr_add,
    input [`S*`R*8-1:0] din_add,
    // Remap
    input wr_vld_remap,
    input [`S-1:0] wr_en_remap,
    input [`S*$clog2(`RTM_DEPTH)-1:0] wr_addr_remap,
    input [`S*`R*8-1:0] din_remap,
    // rtm write ports
    output [`S-1:0] wr_en,
    output [`S*$clog2(`RTM_DEPTH)-1:0] wr_addr,
    output [`S*`R*8-1:0] din
);
    reg [`S-1:0] wr_en_reg = 0;
    reg [`S*$clog2(`RTM_DEPTH)-1:0] wr_addr_reg = 0;
    reg [`S*`R*8-1:0] din_reg = 0;

    // wr_en_reg
    always @(posedge clk)
        if (wr_vld_dram)
            wr_en_reg <= wr_en_dram;
        else if (wr_vld_conv)
            wr_en_reg <= wr_en_conv;
        else if (wr_vld_pool)
            wr_en_reg <= wr_en_pool;
        else if (wr_vld_fc)
            wr_en_reg <= wr_en_fc;
        else if (wr_vld_add)
            wr_en_reg <= wr_en_add;
        else if (wr_vld_remap)
            wr_en_reg <= wr_en_remap;
        else
            wr_en_reg <= {`S{1'b0}};

    // wr_addr_reg
    always @(posedge clk)
        if (wr_vld_dram)
            wr_addr_reg <= wr_addr_dram;
        else if (wr_vld_conv)
            wr_addr_reg <= wr_addr_conv;
        else if (wr_vld_pool)
            wr_addr_reg <= wr_addr_pool;
        else if (wr_vld_fc)
            wr_addr_reg <= wr_addr_fc;
        else if (wr_vld_add)
            wr_addr_reg <= wr_addr_add;
        else
            wr_addr_reg <= wr_addr_remap;

    // din_reg
    always @(posedge clk)
        if (wr_vld_dram)
            din_reg <= din_dram;
        else if (wr_vld_conv)
            din_reg <= din_conv;
        else if (wr_vld_pool)
            din_reg <= din_pool;
        else if (wr_vld_fc)
            din_reg <= din_fc;
        else if (wr_vld_add)
            din_reg <= din_add;
        else
            din_reg <= din_remap;

`ifdef M32P64Q16R16S8
    shift_reg #(1, `S) shift_reg_wr_en(clk, wr_en_reg, wr_en);
    shift_reg #(1, `S*$clog2(`RTM_DEPTH)) shift_reg_wr_addr(clk, wr_addr_reg, wr_addr);
    shift_reg #(1, `S*`R*8) shift_reg_din_reg(clk, din_reg, din);
`elsif M32P96Q16R16S8
    shift_reg #(1, `S) shift_reg_wr_en(clk, wr_en_reg, wr_en);
    shift_reg #(1, `S*$clog2(`RTM_DEPTH)) shift_reg_wr_addr(clk, wr_addr_reg, wr_addr);
    shift_reg #(1, `S*`R*8) shift_reg_din_reg(clk, din_reg, din);
`elsif M64P64Q16R16S8
    shift_reg #(1, `S) shift_reg_wr_en(clk, wr_en_reg, wr_en);
    shift_reg #(1, `S*$clog2(`RTM_DEPTH)) shift_reg_wr_addr(clk, wr_addr_reg, wr_addr);
    shift_reg #(1, `S*`R*8) shift_reg_din_reg(clk, din_reg, din);
`else
    assign wr_en = wr_en_reg;
    assign wr_addr = wr_addr_reg;
    assign din = din_reg;
`endif
endmodule
