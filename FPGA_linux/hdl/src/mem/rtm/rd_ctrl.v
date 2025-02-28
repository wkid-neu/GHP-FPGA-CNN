`timescale 1ns / 1ps
`include "../../incl.vh"

//
// RTM read controller
//
module rtm_rd_ctrl (
    input clk,
    // DRAM
    input rd_vld_dram,
    input rd_last_dram,
    input [`S-1:0] rd_en_dram,
    input [`S*$clog2(`RTM_DEPTH)-1:0] rd_addr_dram,
    output reg [`S*`R*8-1:0] dout_dram,
    output dout_vld_dram,
    output dout_last_dram,
    // X-bus
    input rd_vld_xbus,
    input [`S-1:0] rd_en_xbus,
    input [`XPHM_DATA_WIDTH+$clog2(`R/`Q)+1:0] rd_att_xbus,
    input [`S*$clog2(`RTM_DEPTH)-1:0] rd_addr_xbus,
    output reg [`S*`R*8-1:0] dout_xbus = 0,
    output [`XPHM_DATA_WIDTH+$clog2(`R/`Q)+1:0] dout_att_xbus,
    output dout_vld_xbus,
    // Fc
    input rd_vld_fc,
    input [`S-1:0] rd_en_fc,
    input rd_vec_begin_fc,
    input rd_vec_end_fc,
    input rd_last_fc,
    input [`S*$clog2(`RTM_DEPTH)-1:0] rd_addr_fc,
    output reg [`S*`R*8-1:0] dout_fc = 0,
    output dout_vld_fc,
    output dout_vec_begin_fc,
    output dout_vec_end_fc,
    output dout_last_fc,
    // Add
    input rd_vld_add,
    input rd_last_add,
    input [`S-1:0] rd_en_add,
    input [`S*$clog2(`RTM_DEPTH)-1:0] rd_addr_add,
    output reg [`S*`R*8-1:0] dout_add = 0,
    output dout_vld_add,
    output dout_last_add,
    // Remap
    input rd_vld_remap,
    input rd_last_remap,
    input [`S-1:0] rd_en_remap,
    input [`S*$clog2(`RTM_DEPTH)-1:0] rd_addr_remap,
    output reg [`S*`R*8-1:0] dout_remap = 0,
    output dout_vld_remap,
    output dout_last_remap,
    // rtm read ports
    output reg [`S-1:0] rd_en = 0,
    output reg [`S*$clog2(`RTM_DEPTH)-1:0] rd_addr = 0,
    input [`S*`R*8-1:0] dout
);
    // rd_en
    always @(posedge clk)
        if (rd_vld_dram)
            rd_en <= rd_en_dram;
        else if (rd_vld_xbus)
            rd_en <= rd_en_xbus;
        else if (rd_vld_fc)
            rd_en <= rd_en_fc;
        else if (rd_vld_add)
            rd_en <= rd_en_add;
        else if (rd_vld_remap)
            rd_en <= rd_en_remap;
        else
            rd_en <= {`S{1'b0}};
    
    // rd_addr
    always @(posedge clk)
        if (rd_vld_dram)
            rd_addr <= rd_addr_dram;
        else if (rd_vld_xbus)
            rd_addr <= rd_addr_xbus;
        else if (rd_vld_fc)
            rd_addr <= rd_addr_fc;
        else if (rd_vld_add)
            rd_addr <= rd_addr_add;
        else
            rd_addr <= rd_addr_remap;
    
    always @(posedge clk) begin
        dout_dram <= dout;
        dout_xbus <= dout;
        dout_fc <= dout;
        dout_add <= dout;
        dout_remap <= dout;
    end

    shift_reg #(`RTM_URAM_NUM_PIPE+3, 2) shift_reg_dram(clk, {rd_vld_dram, rd_last_dram}, {dout_vld_dram, dout_last_dram});
    shift_reg #(`RTM_URAM_NUM_PIPE+3, `XPHM_DATA_WIDTH+$clog2(`R/`Q)+3) shift_reg_xbus(clk, {rd_vld_xbus, rd_att_xbus}, {dout_vld_xbus, dout_att_xbus});
    shift_reg #(`RTM_URAM_NUM_PIPE+3, 4) shift_reg_fc(clk, {rd_vld_fc, rd_vec_begin_fc, rd_vec_end_fc, rd_last_fc}, {dout_vld_fc, dout_vec_begin_fc, dout_vec_end_fc, dout_last_fc});
    shift_reg #(`RTM_URAM_NUM_PIPE+3, 2) shift_reg_add(clk, {rd_vld_add, rd_last_add}, {dout_vld_add, dout_last_add});
    shift_reg #(`RTM_URAM_NUM_PIPE+3, 2) shift_reg_remap(clk, {rd_vld_remap, rd_last_remap}, {dout_vld_remap, dout_last_remap});
endmodule
