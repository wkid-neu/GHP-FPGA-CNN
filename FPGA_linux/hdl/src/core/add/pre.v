`timescale 1ns / 1ps
`include "../../incl.vh"

//
// Prepare inputs for ppus
//
module Add_pre (
    input clk,
    // instruction
    input start_pulse,
    input [$clog2(`RTM_DEPTH)-1:0] A_addr,
    input [$clog2(`RTM_DEPTH)-1:0] B_addr,
    input [$clog2(`RTM_DEPTH)-1:0] len_minus_1,
    input [25:0] m1,
    input [25:0] m2,
    input [5:0] n,
    input [7:0] Az,
    input [7:0] Bz,
    input [7:0] Cz,
    // RTM read ports
    output reg rtm_rd_vld = 0,
    output reg rtm_rd_last = 0,
    output reg [`S-1:0] rtm_rd_en = 0,
    output reg [`S*$clog2(`RTM_DEPTH)-1:0] rtm_rd_addr = 0,
    input [`S*`R*8-1:0] rtm_dout,
    input rtm_dout_vld,
    input rtm_dout_last,
    // ppus inputs
    output [`S*`R*9-1:0] ppus_Xs,
    output ppus_Xs_vld,
    output ppus_Xs_last,
    output [25:0] ppus_m1,
    output [25:0] ppus_m2,
    output [5:0] ppus_n,
    output [7:0] ppus_Cz
);
    reg [`S*`R*9-1:0] ppus_Xs_reg = 0;
    reg ppus_Xs_vld_reg = 0;
    reg ppus_Xs_last_reg = 0;
    integer i;

    // 
    // Read A and B from RTM
    //
    localparam RD_IDLE = 0, RD_A = 1, RD_B = 2;
    (* fsm_encoding = "one_hot" *) reg [1:0] rd_state = RD_IDLE;
    reg [$clog2(`RTM_DEPTH)-1:0] rd_cnt = 0;
    reg [$clog2(`RTM_DEPTH)-1:0] next_A_addr = 0;
    reg [$clog2(`RTM_DEPTH)-1:0] next_B_addr = 0;

    always @(posedge clk)
        if (start_pulse)
            rd_state <= RD_A;
        else
            case (rd_state)
                RD_IDLE: rd_state <= RD_IDLE;
                RD_A: rd_state <= RD_B;
                RD_B: begin
                    if (rd_cnt==len_minus_1)
                        rd_state <= RD_IDLE;
                    else
                        rd_state <= RD_A;
                end
                default: rd_state <= RD_IDLE;
            endcase

    // rd_cnt
    always @(posedge clk)
        if (start_pulse) 
            rd_cnt <= 0;
        else if (rd_state==RD_B) 
            rd_cnt <= rd_cnt+1;

    // next_A_addr
    always @(posedge clk)
        if (start_pulse) 
            next_A_addr <= A_addr;
        else if (rd_state==RD_A) 
            next_A_addr <= next_A_addr+1;

    // next_B_addr
    always @(posedge clk)
        if (start_pulse) 
            next_B_addr <= B_addr;
        else if (rd_state==RD_B) 
            next_B_addr <= next_B_addr+1;

    // rtm_rd_vld, rtm_rd_last, rtm_rd_en, rtm_rd_addr
    always @(posedge clk) begin
        rtm_rd_vld <= (rd_state==RD_A || rd_state==RD_B);
        rtm_rd_last <= (rd_state==RD_B && rd_cnt==len_minus_1);
        for (i=0; i<`S; i=i+1) begin
            rtm_rd_en[i] <= (rd_state==RD_A || rd_state==RD_B);
            if (rd_state==RD_A)
                rtm_rd_addr[i*$clog2(`RTM_DEPTH)+:$clog2(`RTM_DEPTH)] <= next_A_addr;
            else
                rtm_rd_addr[i*$clog2(`RTM_DEPTH)+:$clog2(`RTM_DEPTH)] <= next_B_addr;
        end
    end

    //
    // Send RTM outputs to ppus
    //
    localparam SEND_IDLE = 0, SEND_A = 1, SEND_B = 2;
    (* fsm_encoding = "one_hot" *) reg [1:0] send_state = SEND_IDLE;
    reg signed [8:0] next_zero_point = 0;

    always @(posedge clk)
        if (start_pulse)
            send_state <= SEND_A;
        else
            case (send_state)
                SEND_IDLE: send_state <= SEND_IDLE;
                SEND_A: begin
                    if (rtm_dout_vld)
                        send_state <= SEND_B;
                end
                SEND_B: begin
                    if (rtm_dout_vld) begin
                        if (rtm_dout_last)
                            send_state <= SEND_IDLE;
                        else
                            send_state <= SEND_A;
                    end
                end
                default: send_state <= SEND_IDLE;
            endcase

    // next_zero_point
    always @(posedge clk)
        if (start_pulse) 
            next_zero_point <= Az;
        else if (send_state==SEND_A && rtm_dout_vld) 
            next_zero_point <= Bz;
        else if (send_state==SEND_B && rtm_dout_vld) 
            next_zero_point <= Az;

    // ppus_Xs_reg, ppus_Xs_vld_reg, ppus_Xs_last_reg
    always @(posedge clk) begin
        for (i=0; i<`S*`R; i=i+1)
            ppus_Xs_reg[i*9+:9] <= $signed({1'b0, rtm_dout[i*8+:8]}) - next_zero_point;
        ppus_Xs_vld_reg <= (rtm_dout_vld && send_state==SEND_B);
        ppus_Xs_last_reg <= rtm_dout_last;
    end

`ifdef M32P64Q16R16S8
    // Add additional pipeline stages for high performance
    shift_reg #(1, `S*`R*9) shift_reg_ppus_Xs(clk, ppus_Xs_reg, ppus_Xs);
    shift_reg #(1, 1) shift_reg_ppus_Xs_vld(clk, ppus_Xs_vld_reg, ppus_Xs_vld);
    shift_reg #(1, 1) shift_reg_ppus_Xs_last(clk, ppus_Xs_last_reg, ppus_Xs_last);
`elsif M32P96Q16R16S8
    // Add additional pipeline stages for high performance
    shift_reg #(1, `S*`R*9) shift_reg_ppus_Xs(clk, ppus_Xs_reg, ppus_Xs);
    shift_reg #(1, 1) shift_reg_ppus_Xs_vld(clk, ppus_Xs_vld_reg, ppus_Xs_vld);
    shift_reg #(1, 1) shift_reg_ppus_Xs_last(clk, ppus_Xs_last_reg, ppus_Xs_last);
`elsif M64P64Q16R16S8
    // Add additional pipeline stages for high performance
    shift_reg #(1, `S*`R*9) shift_reg_ppus_Xs(clk, ppus_Xs_reg, ppus_Xs);
    shift_reg #(1, 1) shift_reg_ppus_Xs_vld(clk, ppus_Xs_vld_reg, ppus_Xs_vld);
    shift_reg #(1, 1) shift_reg_ppus_Xs_last(clk, ppus_Xs_last_reg, ppus_Xs_last);
`else
    assign ppus_Xs = ppus_Xs_reg;
    assign ppus_Xs_vld = ppus_Xs_vld_reg;
    assign ppus_Xs_last = ppus_Xs_last_reg;
`endif

`ifdef M32P64Q16R16S8
    shift_reg #(2, 26) shift_reg_ppus_m1(clk, m1, ppus_m1);
    shift_reg #(2, 26) shift_reg_ppus_m2(clk, m2, ppus_m2);
    shift_reg #(2, 6) shift_reg_ppus_n(clk, n, ppus_n);
    shift_reg #(2, 8) shift_reg_ppus_Cz(clk, Cz, ppus_Cz);
`elsif M32P96Q16R16S8
    shift_reg #(2, 26) shift_reg_ppus_m1(clk, m1, ppus_m1);
    shift_reg #(2, 26) shift_reg_ppus_m2(clk, m2, ppus_m2);
    shift_reg #(2, 6) shift_reg_ppus_n(clk, n, ppus_n);
    shift_reg #(2, 8) shift_reg_ppus_Cz(clk, Cz, ppus_Cz);
`elsif M64P64Q16R16S8
    shift_reg #(2, 26) shift_reg_ppus_m1(clk, m1, ppus_m1);
    shift_reg #(2, 26) shift_reg_ppus_m2(clk, m2, ppus_m2);
    shift_reg #(2, 6) shift_reg_ppus_n(clk, n, ppus_n);
    shift_reg #(2, 8) shift_reg_ppus_Cz(clk, Cz, ppus_Cz);
`else
    shift_reg #(1, 26) shift_reg_ppus_m1(clk, m1, ppus_m1);
    shift_reg #(1, 26) shift_reg_ppus_m2(clk, m2, ppus_m2);
    shift_reg #(1, 6) shift_reg_ppus_n(clk, n, ppus_n);
    shift_reg #(1, 8) shift_reg_ppus_Cz(clk, Cz, ppus_Cz);
`endif
endmodule
