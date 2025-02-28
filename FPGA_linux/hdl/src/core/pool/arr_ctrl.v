`timescale 1ns / 1ps
`include "../../incl.vh"

//
// This module reads vectors from MXM and sends them to the PE array
//
module Pool_arr_ctrl (
    input clk,
    input start_pulse,
    // Instruction
    input is_maxp,
    input [15:0] vec_size_minus_1,
    // MXM read ports
    output reg mxm_rd_en = 0,
    output mxm_rd_last_rnd,
    input [`P*2*8-1:0] mxm_dout,
    input mxm_dout_vld,
    input mxm_empty,
    input mxm_almost_empty,
    // PE array inputs
    output [`P*2*8-1:0] pe_arr_xs,
    output [3:0] pe_arr_cmd,  // {end, max, avg, start}
    output [$clog2(`S/2)-1:0] pe_arr_sel,
    output [$clog2(`S/2)-1:0] pe_arr_sel_delay
);
    
    reg [`P*2*8-1:0] pe_arr_xs_reg = 0;
    reg [3:0] pe_arr_cmd_reg = 0;
    reg [$clog2(`S/2)-1:0] pe_arr_sel_reg = 0;
    reg [$clog2(`S/2)-1:0] pe_arr_sel_delay_reg = 0;
    reg [$clog2(`S/2)-1:0] sel_cnt = 0;
    reg [15:0] ele_cnt = 0;
    integer i;

    // sel_cnt
    always @(posedge clk)
        if (mxm_dout_vld) begin
            if (sel_cnt==`S/2-1)
                sel_cnt <= 0;
            else
                sel_cnt <= sel_cnt+1;
        end

    // ele_cnt
    always @(posedge clk)
        if (start_pulse) begin
            ele_cnt <= 0;
        end else if (mxm_dout_vld && sel_cnt==`S/2-1) begin
            if (ele_cnt==vec_size_minus_1)
                ele_cnt <= 0;
            else
                ele_cnt <= ele_cnt+1; 
        end

    // mxm_rd_en
    always @(posedge clk)
        mxm_rd_en <= ~mxm_empty && (~mxm_almost_empty || ~mxm_rd_en);

    // mxm_rd_last_rnd
    assign mxm_rd_last_rnd = 1;

    // pe_arr_xs_reg
    // We sperate data at this stage.
    // After sperating, the first and last P elements are from different channels
    always @(posedge clk)
        for (i=0; i<`P; i=i+1) begin
            pe_arr_xs_reg[i*8+:8] <= mxm_dout[i*8*2+:8];
            pe_arr_xs_reg[(i+`P)*8+:8] <= mxm_dout[i*8*2+8+:8];
        end
    
    // pe_arr_cmd_reg
    always @(posedge clk) begin
        pe_arr_cmd_reg[0] <= (mxm_dout_vld && ele_cnt==0);  // start
        pe_arr_cmd_reg[1] <= (mxm_dout_vld && ~is_maxp);  // avgp
        pe_arr_cmd_reg[2] <= (mxm_dout_vld && is_maxp);  // maxp
        pe_arr_cmd_reg[3] <= (mxm_dout_vld && ele_cnt==vec_size_minus_1);  // end
    end

    // pe_arr_sel_reg
    always @(posedge clk)
        pe_arr_sel_reg <= sel_cnt;

    // pe_arr_sel_delay_reg
    always @(posedge clk)
        pe_arr_sel_delay_reg <= pe_arr_sel_reg;

`ifdef M32P64Q16R16S8
    // Add additional pipeline stages for high performance
    shift_reg #(1, `P*2*8) shift_reg_pe_arr_xs(clk, pe_arr_xs_reg, pe_arr_xs);
    shift_reg #(1, 4) shift_reg_pe_arr_cmd(clk, pe_arr_cmd_reg, pe_arr_cmd);
    shift_reg #(1, $clog2(`S/2)) shift_reg_pe_arr_sel(clk, pe_arr_sel_reg, pe_arr_sel);
    shift_reg #(1, $clog2(`S/2)) shift_reg_pe_arr_sel_delay(clk, pe_arr_sel_delay_reg, pe_arr_sel_delay);
`elsif M32P96Q16R16S8
    // Add additional pipeline stages for high performance
    shift_reg #(1, `P*2*8) shift_reg_pe_arr_xs(clk, pe_arr_xs_reg, pe_arr_xs);
    shift_reg #(1, 4) shift_reg_pe_arr_cmd(clk, pe_arr_cmd_reg, pe_arr_cmd);
    shift_reg #(1, $clog2(`S/2)) shift_reg_pe_arr_sel(clk, pe_arr_sel_reg, pe_arr_sel);
    shift_reg #(1, $clog2(`S/2)) shift_reg_pe_arr_sel_delay(clk, pe_arr_sel_delay_reg, pe_arr_sel_delay);
`elsif M64P64Q16R16S8
    // Add additional pipeline stages for high performance
    shift_reg #(1, `P*2*8) shift_reg_pe_arr_xs(clk, pe_arr_xs_reg, pe_arr_xs);
    shift_reg #(1, 4) shift_reg_pe_arr_cmd(clk, pe_arr_cmd_reg, pe_arr_cmd);
    shift_reg #(1, $clog2(`S/2)) shift_reg_pe_arr_sel(clk, pe_arr_sel_reg, pe_arr_sel);
    shift_reg #(1, $clog2(`S/2)) shift_reg_pe_arr_sel_delay(clk, pe_arr_sel_delay_reg, pe_arr_sel_delay);
`else
    assign pe_arr_xs = pe_arr_xs_reg;
    assign pe_arr_cmd = pe_arr_cmd_reg;
    assign pe_arr_sel = pe_arr_sel_reg;
    assign pe_arr_sel_delay = pe_arr_sel_delay_reg;
`endif
endmodule
