`timescale 1ns / 1ps
`include "../incl.vh"

`define TAG_WIDTH 8

//
// This module controls the ppu array.
//
module ppu_arr_ctrl (
    input clk,
    // Conv
    input is_conv,
    input [`S*`R*32-1:0] conv_dps,
    input [`S*32-1:0] conv_bias,
    input conv_dps_vld,
    input [25:0] conv_m1,
    input [5:0] conv_n1, 
    input [7:0] conv_Yz,
    output reg [`S*`R*8-1:0] conv_outs = 0,
    output reg conv_out_vld = 0,
    // Pool
    input is_pool,
    input [(`P/2)*14-1:0] pool_Ys,
    input pool_Ys_vld,
    input signed [15:0] pool_neg_NXz,
    input [7:0] pool_Yz,
    input [25:0] pool_m1,
    input [5:0] pool_n1,
    output reg [(`P/2)*8-1:0] pool_outs = 0,
    output reg pool_out_vld = 0,
    // Add
    input is_add,
    input [`S*`R*9-1:0] add_Xs,
    input add_Xs_vld,
    input add_Xs_last,
    input [25:0] add_m1,
    input [25:0] add_m2,
    input [5:0] add_n, 
    input [7:0] add_Cz,
    output reg [`S*`R*8-1:0] add_outs = 0,
    output reg add_out_vld = 0,
    output reg add_out_last = 0,
    // Remap
    input is_remap,
    input [`S*`R*8-1:0] remap_Xs,
    input remap_Xs_vld,
    input remap_Xs_last,
    input signed [8:0] remap_neg_Xz,
    input [7:0] remap_Yz,
    input [25:0] remap_m1,
    input [5:0] remap_n1,
    output reg [`S*`R*8-1:0] remap_outs = 0,
    output reg remap_out_vld = 0,
    output reg remap_out_last = 0, 
    // inputs from Fc
    input is_fc,
    input [`DDR_AXIS_DATA_WIDTH/8*32-1:0] fc_accs,
    input [`DDR_AXIS_DATA_WIDTH/8*32-1:0] fc_bias,
    input fc_accs_vld,
    input fc_accs_last,
    input [25:0] fc_m1,
    input [5:0] fc_n1, 
    input [7:0] fc_Yz,
    output reg [`DDR_AXIS_DATA_WIDTH/8*8-1:0] fc_outs = 0,
    output reg fc_out_vld = 0,
    output reg fc_out_last = 0,
    // ppu_arr input
    output reg mode = 0,
    output reg [`TAG_WIDTH-1:0] in_tag = 0,
    output reg [`S*`R*27-1:0] As = 0,
    output reg [`S*`R*34-1:0] Bs = 0,
    output reg [`S*`R*34-1:0] Cs = 0,
    output reg [`S*`R*27-1:0] Ds = 0,
    output reg [`S*`R*9-1:0] Es = 0,
    output reg [`S*`R*6-1:0] Ss = 0,
    output reg [`S*`R*8-1:0] Zs = 0,
    // ppu_arr outputs
    input [`S*`R*8-1:0] outs,
    input [`TAG_WIDTH-1:0] out_tag
);
    integer i, j;
    // multiplixer of As, Bs, Cs
    reg [1:0] sel_mux_0 = 0;
    // multiplixer of Ss and Zs
    reg [2:0] sel_mux_1 = 0;

    // sel_mux_0
    always @(posedge clk)
        if (is_conv)
            sel_mux_0 <= 0;
        else if (is_pool)
            sel_mux_0 <= 1;
        else if (is_remap)
            sel_mux_0 <= 2;
        else
            sel_mux_0 <= 3;  // fc

    // sel_mux_1
    always @(posedge clk)
        if (is_conv)
            sel_mux_1 <= 0;
        else if (is_pool)
            sel_mux_1 <= 1;
        else if (is_add)
            sel_mux_1 <= 2;
        else if (is_remap)
            sel_mux_1 <= 3;
        else
            sel_mux_1 <= 4;  // fc

    // mode
    always @(posedge clk)
        if (is_conv || is_pool || is_remap || is_fc)
            mode <= 0;
        else
            mode <= 1;

    // As
    always @(posedge clk)
        for (i=0; i<`S*`R; i=i+1)
            case (sel_mux_0)
                0: As[i*27+:27] <= {1'b0, conv_m1};
                1: As[i*27+:27] <= {1'b0, pool_m1};
                2: As[i*27+:27] <= {1'b0, remap_m1};
                3: As[i*27+:27] <= {1'b0, fc_m1};
            endcase

    // Bs
    always @(posedge clk)
        case (sel_mux_0)
            0: begin // Conv
                for (i=0; i<`S*`R; i=i+1)
                    Bs[i*34+:34] <= {conv_dps[i*32+31], conv_dps[i*32+31], conv_dps[i*32+:32]};
            end
            1: begin  // Pool
                for (i=0; i<`P/2; i=i+1)
                    Bs[i*34+:34] <= pool_Ys[i*14+:14];
            end
            2: begin  // Remap
                for (i=0; i<`S*`R; i=i+1)
                    Bs[i*34+:34] <= remap_Xs[i*8+:8];
            end
            3: begin  // Fc
                for (i=0; i<`DDR_AXIS_DATA_WIDTH/8; i=i+1)
                    Bs[i*34+:34] <= {fc_accs[i*32+31], fc_accs[i*32+31], fc_accs[i*32+:32]};
            end
        endcase

    // Cs
    always @(posedge clk)
        case (sel_mux_0)
            0: begin  // Conv
                for (i=0; i<`S; i=i+1)
                    for (j=0; j<`R; j=j+1)
                        Cs[(i*`R+j)*34+:34] <= {conv_bias[(i+1)*32-1], conv_bias[(i+1)*32-1], conv_bias[i*32+:32]};
            end
            1: begin  // Pool
                for (i=0; i<`S*`R; i=i+1)
                    Cs[i*34+:34] <= {{18{pool_neg_NXz[15]}}, pool_neg_NXz};
            end
            2: begin  // Remap
                for (i=0; i<`S*`R; i=i+1)
                    Cs[i*34+:34] <= {{26{remap_neg_Xz[8]}}, remap_neg_Xz};
            end
            3: begin  // Fc
                for (i=0; i<`DDR_AXIS_DATA_WIDTH/8; i=i+1)
                    Cs[i*34+:34] <= {fc_bias[i*32+31], fc_bias[i*32+31], fc_bias[i*32+:32]};
            end
        endcase

    // Ds
    always @(posedge clk)
        for (i=0; i<`S*`R; i=i+1)
            if (add_Xs_vld)
                Ds[i*27+:27] <= {1'b0, add_m2};
            else
                Ds[i*27+:27] <= {1'b0, add_m1};

    // Es
    always @(posedge clk)
        for (i=0; i<`S*`R; i=i+1)
            Es[i*9+:9] <= add_Xs[i*9+:9];

    // Ss
    always @(posedge clk)
        for (i=0; i<`S*`R; i=i+1)
            case (sel_mux_1)
                0,5: Ss[i*6+:6] <= conv_n1;
                1,6: Ss[i*6+:6] <= pool_n1;
                2,7: Ss[i*6+:6] <= add_n;
                3: Ss[i*6+:6] <= remap_n1;
                4: Ss[i*6+:6] <= fc_n1;
            endcase

    // Zs
    always @(posedge clk)
        for (i=0; i<`S*`R; i=i+1)
            case (sel_mux_1)
                0,5: Zs[i*8+:8] <= conv_Yz;
                1,6: Zs[i*8+:8] <= pool_Yz;
                2,7: Zs[i*8+:8] <= add_Cz;
                3: Zs[i*8+:8] <= remap_Yz;
                4: Zs[i*8+:8] <= fc_Yz;
            endcase

    // in_tag
    always @(posedge clk)
        in_tag <= {
            is_fc && fc_accs_vld, is_fc && fc_accs_last,
            is_remap && remap_Xs_vld, is_remap && remap_Xs_last,
            is_add && add_Xs_vld, is_add && add_Xs_last,
            is_pool && pool_Ys_vld,
            is_conv && conv_dps_vld
        };

    wire out_tag_fc_vld;
    wire out_tag_fc_last;
    wire out_tag_remap_vld;
    wire out_tag_remap_last;
    wire out_tag_add_vld;
    wire out_tag_add_last;
    wire out_tag_pool_vld;
    wire out_tag_conv_vld;

    assign {
        out_tag_fc_vld, out_tag_fc_last,
        out_tag_remap_vld, out_tag_remap_last,
        out_tag_add_vld, out_tag_add_last,
        out_tag_pool_vld,
        out_tag_conv_vld
    } = out_tag;

    // outputs
    always @(posedge clk) begin
        // Conv
        for (i=0; i<`S*`R; i=i+1)
            conv_outs[i*8+:8] <= outs[i*8+:8];
        // Pool
        for (i=0; i<`P/2; i=i+1)
            pool_outs[i*8+:8] <= outs[i*8+:8];
        // Add
        for (i=0; i<`S*`R; i=i+1)
            add_outs[i*8+:8] <= outs[i*8+:8];
        // Remap
        for (i=0; i<`S*`R; i=i+1)
            remap_outs[i*8+:8] <= outs[i*8+:8];
        // Fc
        for (i=0; i<`DDR_AXIS_DATA_WIDTH/8; i=i+1)
            fc_outs[i*8+:8] <= outs[i*8+:8];
        conv_out_vld <= out_tag_conv_vld;
        pool_out_vld <= out_tag_pool_vld;
        add_out_vld <= out_tag_add_vld;
        add_out_last <= out_tag_add_last;
        remap_out_vld <= out_tag_remap_vld;
        remap_out_last <= out_tag_remap_last;
        fc_out_vld <= out_tag_fc_vld;
        fc_out_last <= out_tag_fc_last;
    end
endmodule
