`timescale 1ns / 1ps
`include "../../incl.vh"

//
// This module reads PE array outputs from the out_fifo and sends them to the PPUs module.
// An item of the out_fifo has 2P elements.
// This module reads one item and takes four cycles to send them to PPUs.
//
module Pool_ppus_pre (
    input clk,
    // instruction
    input [25:0] m1,
    input [5:0] n1,
    input signed [15:0] neg_NXz,
    input [7:0] Yz,
    // Output FIFO read ports
    output reg out_fifo_rd_en = 0,
    input [`P*2*14-1:0] out_fifo_dout,
    input out_fifo_dout_vld,
    input out_fifo_empty,
    // ppus inputs
    output [(`P/2)*14-1:0] ppus_Ys,
    output ppus_Ys_vld,
    output signed [15:0] ppus_neg_NXz,
    output [7:0] ppus_Yz,
    output [25:0] ppus_m1,
    output [5:0] ppus_n1
);
    // Parameter Assertions
    initial begin
        // array output bandwidth: 2P/vec_size
        // The supported minimum kernel size is KH=KW=2 thereby the maximum bw is 2P/4
        // RTM bandwidth: SR
        // Make sure that array output bandwidth is less than or equals to the RTM bandwidth
        if (2*`P/4 > `R*`S) begin
            $error("Hyper parameter mismatch, please make sure that 2P/4<=RS, current values are: P = %0d, R = %0d, S = %0d", `P, `R, `S);
            $finish;
        end
    end

    reg [(`P/2)*14-1:0] ppus_Ys_reg = 0;
    reg ppus_Ys_vld_reg = 0;

    localparam RD = 0, PAUSE1 = 1, PAUSE2 = 2, PAUSE3 = 3;
    reg [1:0] state = RD;

    // state
    always @(posedge clk)
        case (state)
            RD: if (~out_fifo_empty) state <= PAUSE1;
            PAUSE1: state <= PAUSE2;
            PAUSE2: state <= PAUSE3;
            PAUSE3: state <= RD;
        endcase

    // out_fifo_rd_en
    always @(posedge clk)
        out_fifo_rd_en <= (state==RD && ~out_fifo_empty);

    // The valid output will be sent to PPUs in 4 cycles,
    // with each cycle corresponding P/2 elements.
    reg vld1 = 0, vld2 = 0, vld3 = 0, vld4 = 0;
    reg [`P*2*14-1:0] out_fifo_dout_delay = 0;

    always @(posedge clk)
        {vld4, vld3, vld2, vld1} <= {vld3, vld2, vld1, out_fifo_dout_vld};

    always @(posedge clk)
        out_fifo_dout_delay <= out_fifo_dout;

    // ppus_Ys_vld_reg
    always @(posedge clk)
        ppus_Ys_vld_reg <= (vld1 || vld2 || vld3 || vld4);

    // ppus_Ys_reg
    always @(posedge clk)
        if (vld1)  // The first P/2 elements in the first channel
            ppus_Ys_reg <= out_fifo_dout_delay[`P/2*14-1:0];
        else if (vld2)
            ppus_Ys_reg <= out_fifo_dout_delay[`P/2*14+:`P/2*14];
        else if (vld3)
            ppus_Ys_reg <= out_fifo_dout_delay[`P/2*14*2+:`P/2*14];
        else
            ppus_Ys_reg <= out_fifo_dout_delay[`P/2*14*3+:`P/2*14];

`ifdef M32P64Q16R16S8
    // Add additional pipeline stages for high performance
    shift_reg #(1, (`P/2)*14) shift_reg_ppus_Ys(clk, ppus_Ys_reg, ppus_Ys);
    shift_reg #(1, 1) shift_reg_ppus_Ys_vld(clk, ppus_Ys_vld_reg, ppus_Ys_vld);
`elsif M32P96Q16R16S8
    // Add additional pipeline stages for high performance
    shift_reg #(1, (`P/2)*14) shift_reg_ppus_Ys(clk, ppus_Ys_reg, ppus_Ys);
    shift_reg #(1, 1) shift_reg_ppus_Ys_vld(clk, ppus_Ys_vld_reg, ppus_Ys_vld);
`elsif M64P64Q16R16S8
    // Add additional pipeline stages for high performance
    shift_reg #(1, (`P/2)*14) shift_reg_ppus_Ys(clk, ppus_Ys_reg, ppus_Ys);
    shift_reg #(1, 1) shift_reg_ppus_Ys_vld(clk, ppus_Ys_vld_reg, ppus_Ys_vld);
`else
    assign ppus_Ys = ppus_Ys_reg;
    assign ppus_Ys_vld = ppus_Ys_vld_reg;
`endif

`ifdef M32P64Q16R16S8
    shift_reg #(2, 16) shift_reg_ppus_neg_NXz(clk, neg_NXz, ppus_neg_NXz);
    shift_reg #(2, 8) shift_reg_ppus_Yz(clk, Yz, ppus_Yz);
    shift_reg #(2, 26) shift_reg_ppus_m1(clk, m1, ppus_m1);
    shift_reg #(2, 6) shift_reg_ppus_n1(clk, n1, ppus_n1);
`elsif M32P96Q16R16S8
    shift_reg #(2, 16) shift_reg_ppus_neg_NXz(clk, neg_NXz, ppus_neg_NXz);
    shift_reg #(2, 8) shift_reg_ppus_Yz(clk, Yz, ppus_Yz);
    shift_reg #(2, 26) shift_reg_ppus_m1(clk, m1, ppus_m1);
    shift_reg #(2, 6) shift_reg_ppus_n1(clk, n1, ppus_n1);
`elsif M64P64Q16R16S8
    shift_reg #(2, 16) shift_reg_ppus_neg_NXz(clk, neg_NXz, ppus_neg_NXz);
    shift_reg #(2, 8) shift_reg_ppus_Yz(clk, Yz, ppus_Yz);
    shift_reg #(2, 26) shift_reg_ppus_m1(clk, m1, ppus_m1);
    shift_reg #(2, 6) shift_reg_ppus_n1(clk, n1, ppus_n1);
`else
    shift_reg #(1, 16) shift_reg_ppus_neg_NXz(clk, neg_NXz, ppus_neg_NXz);
    shift_reg #(1, 8) shift_reg_ppus_Yz(clk, Yz, ppus_Yz);
    shift_reg #(1, 26) shift_reg_ppus_m1(clk, m1, ppus_m1);
    shift_reg #(1, 6) shift_reg_ppus_n1(clk, n1, ppus_n1);
`endif
endmodule
