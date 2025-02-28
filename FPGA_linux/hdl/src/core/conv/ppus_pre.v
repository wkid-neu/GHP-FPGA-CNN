`timescale 1ns / 1ps
`include "../../incl.vh"

//
// This module reads Dot-product and Bias from the Dot-product FIFO and Bias FIFO, respectively.
// It prepares the inputs for the PPUs module.
//
module Conv_ppus_pre (
    input clk,
    // instruction
    input [25:0] m1,
    input [5:0] n1,
    input [7:0] Yz,
    // Bias FIFO read ports
    output bias_fifo_rd_en,
    input [63:0] bias_fifo_dout,
    input bias_fifo_data_valid,
    // Dot-product FIFO read ports
    output dp_fifo_rd_en,
    input dp_fifo_empty,
    input dp_fifo_almost_empty,
    input [2*`P*32-1:0] dp_fifo_dout,
    // PPUs inputs
    output [`S*`R*32-1:0] ppus_dps,
    output [`S*32-1:0] ppus_bias,
    output ppus_dps_vld,
    output [25:0] ppus_m1,
    output [5:0] ppus_n1, 
    output [7:0] ppus_Yz
);
    wire [`S*`R*32-1:0] ppus_dps_int;
    wire [`S*32-1:0] ppus_bias_int;
    wire ppus_dps_vld_int;

    generate
        if (`P==`R) begin
            Conv_ppus_pre_P_eq_R Conv_ppus_pre_P_eq_R_inst(
                .clk(clk),
                .bias_fifo_rd_en(bias_fifo_rd_en),
                .bias_fifo_dout(bias_fifo_dout),
                .bias_fifo_data_valid(bias_fifo_data_valid),
                .dp_fifo_rd_en(dp_fifo_rd_en),
                .dp_fifo_empty(dp_fifo_empty),
                .dp_fifo_almost_empty(dp_fifo_almost_empty),
                .dp_fifo_dout(dp_fifo_dout),
                .ppus_dps(ppus_dps_int),
                .ppus_bias(ppus_bias_int),
                .ppus_dps_vld(ppus_dps_vld_int)
            );
        end else if (`P>`R) begin
            Conv_ppus_pre_P_gt_R Conv_ppus_pre_P_gt_R_inst(
                .clk(clk),
                .bias_fifo_rd_en(bias_fifo_rd_en),
                .bias_fifo_dout(bias_fifo_dout),
                .bias_fifo_data_valid(bias_fifo_data_valid),
                .dp_fifo_rd_en(dp_fifo_rd_en),
                .dp_fifo_empty(dp_fifo_empty),
                .dp_fifo_almost_empty(dp_fifo_almost_empty),
                .dp_fifo_dout(dp_fifo_dout),
                .ppus_dps(ppus_dps_int),
                .ppus_bias(ppus_bias_int),
                .ppus_dps_vld(ppus_dps_vld_int)
            );
        end
    endgenerate

`ifdef M32P64Q16R16S8
    // Add additional pipeline stages for high performance
    shift_reg #(1, `S*`R*32) shift_reg_ppus_dps(clk, ppus_dps_int, ppus_dps);
    shift_reg #(1, `S*32) shift_reg_ppus_bias(clk, ppus_bias_int, ppus_bias);
    shift_reg #(1, 1) shift_reg_ppus_dps_vld(clk, ppus_dps_vld_int, ppus_dps_vld);
`elsif M32P96Q16R16S8
    // Add additional pipeline stages for high performance
    shift_reg #(1, `S*`R*32) shift_reg_ppus_dps(clk, ppus_dps_int, ppus_dps);
    shift_reg #(1, `S*32) shift_reg_ppus_bias(clk, ppus_bias_int, ppus_bias);
    shift_reg #(1, 1) shift_reg_ppus_dps_vld(clk, ppus_dps_vld_int, ppus_dps_vld);
`elsif M64P64Q16R16S8
    // Add additional pipeline stages for high performance
    shift_reg #(1, `S*`R*32) shift_reg_ppus_dps(clk, ppus_dps_int, ppus_dps);
    shift_reg #(1, `S*32) shift_reg_ppus_bias(clk, ppus_bias_int, ppus_bias);
    shift_reg #(1, 1) shift_reg_ppus_dps_vld(clk, ppus_dps_vld_int, ppus_dps_vld);
`else
    assign ppus_dps = ppus_dps_int;
    assign ppus_bias = ppus_bias_int;
    assign ppus_dps_vld = ppus_dps_vld_int;
`endif

`ifdef M32P64Q16R16S8
    shift_reg #(2, 26) shift_reg_ppus_m1(clk, m1, ppus_m1);
    shift_reg #(2, 6) shift_reg_ppus_n1(clk, n1, ppus_n1);
    shift_reg #(2, 8) shift_reg_ppus_Yz(clk, Yz, ppus_Yz);
`elsif M32P96Q16R16S8
    shift_reg #(2, 26) shift_reg_ppus_m1(clk, m1, ppus_m1);
    shift_reg #(2, 6) shift_reg_ppus_n1(clk, n1, ppus_n1);
    shift_reg #(2, 8) shift_reg_ppus_Yz(clk, Yz, ppus_Yz);
`elsif M64P64Q16R16S8
    shift_reg #(2, 26) shift_reg_ppus_m1(clk, m1, ppus_m1);
    shift_reg #(2, 6) shift_reg_ppus_n1(clk, n1, ppus_n1);
    shift_reg #(2, 8) shift_reg_ppus_Yz(clk, Yz, ppus_Yz);
`else
    shift_reg #(1, 26) shift_reg_ppus_m1(clk, m1, ppus_m1);
    shift_reg #(1, 6) shift_reg_ppus_n1(clk, n1, ppus_n1);
    shift_reg #(1, 8) shift_reg_ppus_Yz(clk, Yz, ppus_Yz);
`endif
endmodule

//
// P = R, write back directly.
//
module Conv_ppus_pre_P_eq_R (
    input clk,
    // Bias FIFO read ports
    output reg bias_fifo_rd_en = 0,
    input [63:0] bias_fifo_dout,
    input bias_fifo_data_valid,
    // Dot-product FIFO read ports
    output reg dp_fifo_rd_en = 0,
    input dp_fifo_empty,
    input dp_fifo_almost_empty,
    input [2*`P*32-1:0] dp_fifo_dout,
    // PPUs inputs
    output reg [`S*`R*32-1:0] ppus_dps = 0,
    output reg [`S*32-1:0] ppus_bias = 0,
    output reg ppus_dps_vld = 0
);
    // Parameter Assertions
    initial begin
        if (`P != `R) begin
            $error("Hyper parameter mismatch, please make sure that P==R, current values are: P = %0d, R = %0d", `P, `R);
            $finish;
        end
    end

    // We can write S channels into RTM at a clock cycle.
    // A item in Dot-product FIFO has 2 channels.
    // So we should collect S/2 items and then send them to the PPUs module.
    localparam N = `S/2;
    integer i, j;
    
    wire dp_ready;
    assign dp_ready = (~dp_fifo_empty && (~dp_fifo_rd_en || ~dp_fifo_almost_empty));

    // dp_fifo_rd_en, bias_fifo_rd_en
    always @(posedge clk) begin
        dp_fifo_rd_en <= dp_ready;
        bias_fifo_rd_en <= dp_ready;
    end

    reg [N-1:0] shreg = {1'b1, {{N-1}{1'b0}}};

    // shreg
    always @(posedge clk)
        if (bias_fifo_data_valid)
            shreg <= {shreg[0], shreg[N-1:1]};

    // ppus_dps
    always @(posedge clk)
        for (i=0; i<N; i=i+1)
            if (shreg[i])
                ppus_dps[i*2*`P*32+:2*`P*32] <= dp_fifo_dout;

    // ppus_bias
    always @(posedge clk)
        for (i=0; i<N; i=i+1)
            if (shreg[i])
                ppus_bias[i*64+:64] <= bias_fifo_dout;

    // ppus_dps_vld
    always @(posedge clk)
        ppus_dps_vld <= (bias_fifo_data_valid && shreg[0]);
endmodule

//
// P > R, use ping-pong buffer to manage data
//
module Conv_ppus_pre_P_gt_R (
    input clk,
    // Bias FIFO read ports
    output reg bias_fifo_rd_en = 0,
    input [63:0] bias_fifo_dout,
    input bias_fifo_data_valid,
    // Dot-product FIFO read ports
    output reg dp_fifo_rd_en = 0,
    input dp_fifo_empty,
    input dp_fifo_almost_empty,
    input [2*`P*32-1:0] dp_fifo_dout,
    // PPUs inputs
    output reg [`S*`R*32-1:0] ppus_dps = 0,
    output reg [`S*32-1:0] ppus_bias = 0,
    output reg ppus_dps_vld = 0
);
    // Parameter Assertions
    initial begin
        if (`P <= `R) begin
            $error("Hyper parameter mismatch, please make sure that P>R, current values are: P = %0d, R = %0d", `P, `R);
            $finish;
        end

        if (`P%`R != 0) begin
            $error("Hyper parameter mismatch, please make sure that P is a multiple of R, current values are: P = %0d, R = %0d", `P, `R);
            $finish;
        end

        if (`P/`R > 8) begin
            $error("Hyper parameter mismatch, please make sure that P/R<=8, current values are: P = %0d, R = %0d", `P, `R);
            $finish;
        end
    end

    localparam NUM_R = `S/2, NUM_W = `P/`R;
    
    wire dp_ready;
    assign dp_ready = (~dp_fifo_empty && (~dp_fifo_rd_en || ~dp_fifo_almost_empty));

    //
    // Read data from fifo
    //
    generate
        // If NUM_R>=NUM_W, we can read dot-prods whenever the fifo is ready to read
        if (NUM_R>=NUM_W) begin
            // dp_fifo_rd_en, bias_fifo_rd_en
            always @(posedge clk) begin
                dp_fifo_rd_en <= dp_ready;
                bias_fifo_rd_en <= dp_ready;
            end
        // If NUM_R<NUM_W, the read process should be paused to wait the write process.
        end else begin
            localparam RD = 0, RD_PAUSE = 1;
            (* fsm_encoding = "one_hot" *) reg [0:0] rd_state = RD;
            reg [$clog2(NUM_W)-1:0] rd_cnt = 0;

            always @(posedge clk)
                case (rd_state)
                    RD: if (dp_ready && rd_cnt==NUM_R-1) rd_state <= RD_PAUSE;
                    RD_PAUSE: if (rd_cnt==NUM_W-1) rd_state <= RD;
                endcase

            always @(posedge clk)
                if (rd_state==RD) begin
                    if (dp_ready)
                        rd_cnt <= rd_cnt+1;
                end else if (rd_state==RD_PAUSE) begin
                    if (rd_cnt==NUM_W-1)
                        rd_cnt <= 0;
                    else
                        rd_cnt <= rd_cnt+1; 
                end

            always @(posedge clk) begin
                dp_fifo_rd_en <= (rd_state==RD && dp_ready && rd_cnt<=NUM_R-1);
                bias_fifo_rd_en <= (rd_state==RD && dp_ready && rd_cnt<=NUM_R-1);
            end
        end
    endgenerate

    //
    // Write data into the ping-pong buffer
    //
    reg [NUM_W*`S*`R*32-1:0] dp_reg1 = 0;
    reg [NUM_W*`S*`R*32-1:0] dp_reg2 = 0;
    reg [NUM_R*64-1:0] bias_reg1 = 0;
    reg [NUM_R*64-1:0] bias_reg2 = 0;
    // Use shift register to indicate which parts should be updated when valid dp and bias come. 
    reg [NUM_R*2-1:0] rd_shreg = {{{NUM_R}{1'b0}}, 1'b1, {{NUM_R-1}{1'b0}}};
    integer i, j, k;

    // rd_shreg
    always @(posedge clk)
        if (bias_fifo_data_valid)
            rd_shreg <= {rd_shreg[0], rd_shreg[NUM_R*2-1:1]};

    // dp_reg1
    always @(posedge clk)
        for (i=0; i<NUM_R; i=i+1) begin
            if (rd_shreg[i]) begin
                for (j=0; j<NUM_W; j=j+1) begin
                    dp_reg1[(i*2*`R+j*`S*`R)*32+:`R*32] <= dp_fifo_dout[j*`R*32+:`R*32];
                    dp_reg1[(i*2*`R+j*`S*`R+`R)*32+:`R*32] <= dp_fifo_dout[(j*`R+`P)*32+:`R*32];
                end
            end
        end

    // dp_reg2
    always @(posedge clk)
        for (i=0; i<NUM_R; i=i+1) begin
            if (rd_shreg[i+NUM_R]) begin
                for (j=0; j<NUM_W; j=j+1) begin
                    dp_reg2[(i*2*`R+j*`S*`R)*32+:`R*32] <= dp_fifo_dout[j*`R*32+:`R*32];
                    dp_reg2[(i*2*`R+j*`S*`R+`R)*32+:`R*32] <= dp_fifo_dout[(j*`R+`P)*32+:`R*32];
                end
            end
        end

    // bias_reg1
    always @(posedge clk)
        for (i=0; i<NUM_R; i=i+1)
            if (rd_shreg[i])
                bias_reg1[i*64+:64] <= bias_fifo_dout;

    // bias_reg2
    always @(posedge clk)
        for (i=0; i<NUM_R; i=i+1)
            if (rd_shreg[i+NUM_R])
                bias_reg2[i*64+:64] <= bias_fifo_dout;

    //
    // Read data from the ping-pong buffer and send them to PPUs
    //
    reg sel1 = 0, sel2 = 0;
    reg [$clog2(NUM_W)-1:0] idx = 0;

    // sel1
    always @(posedge clk)
        if (bias_fifo_data_valid && rd_shreg[0])
            sel1 <= 1;
        else if (sel1 && idx==NUM_W-1)
            sel1 <= 0;

    // sel2
    always @(posedge clk)
        if (bias_fifo_data_valid && rd_shreg[NUM_R])
            sel2 <= 1; 
        else if (sel2 && idx==NUM_W-1)
            sel2 <= 0; 

    // idx
    always @(posedge clk)
        if (bias_fifo_data_valid && (rd_shreg[0] || rd_shreg[NUM_R]))
            idx <= 0;
        else if (sel1 || sel2)
            idx <= idx+1;

    // ppus_dps
    generate
        if (NUM_W==2) begin
            always @(posedge clk)
                if (sel1)
                    case (idx)
                        0: ppus_dps <= dp_reg1[`S*`R*32-1:0];
                        1: ppus_dps <= dp_reg1[`S*`R*32+:`S*`R*32];
                    endcase
                else
                    case (idx)
                        0: ppus_dps <= dp_reg2[`S*`R*32-1:0];
                        1: ppus_dps <= dp_reg2[`S*`R*32+:`S*`R*32];
                    endcase
        // Note that the value of idx can be 3, which is an invalid index of dp_reg1 and dp_reg2.
        // So we should use case statement rather than using the idx value directly.
        end else if (NUM_W==3) begin
            always @(posedge clk)
                if (sel1)
                    case (idx)
                        0: ppus_dps <= dp_reg1[`S*`R*32-1:0];
                        1: ppus_dps <= dp_reg1[`S*`R*32+:`S*`R*32];
                        default: ppus_dps <= dp_reg1[`S*`R*2*32+:`S*`R*32];
                    endcase
                else
                    case (idx)
                        0: ppus_dps <= dp_reg2[`S*`R*32-1:0];
                        1: ppus_dps <= dp_reg2[`S*`R*32+:`S*`R*32];
                        default: ppus_dps <= dp_reg2[`S*`R*2*32+:`S*`R*32];
                    endcase
        end else if (NUM_W==4) begin
            always @(posedge clk)
                if (sel1)
                    case (idx)
                        0: ppus_dps <= dp_reg1[`S*`R*32-1:0];
                        1: ppus_dps <= dp_reg1[`S*`R*32+:`S*`R*32];
                        2: ppus_dps <= dp_reg1[`S*`R*2*32+:`S*`R*32];
                        default: ppus_dps <= dp_reg1[`S*`R*3*32+:`S*`R*32];
                    endcase
                else
                    case (idx)
                        0: ppus_dps <= dp_reg2[`S*`R*32-1:0];
                        1: ppus_dps <= dp_reg2[`S*`R*32+:`S*`R*32];
                        2: ppus_dps <= dp_reg2[`S*`R*2*32+:`S*`R*32];
                        default: ppus_dps <= dp_reg2[`S*`R*3*32+:`S*`R*32];
                    endcase
        end else if (NUM_W==5) begin
            always @(posedge clk)
                if (sel1)
                    case (idx)
                        0: ppus_dps <= dp_reg1[`S*`R*32-1:0];
                        1: ppus_dps <= dp_reg1[`S*`R*32+:`S*`R*32];
                        2: ppus_dps <= dp_reg1[`S*`R*2*32+:`S*`R*32];
                        3: ppus_dps <= dp_reg1[`S*`R*3*32+:`S*`R*32];
                        default: ppus_dps <= dp_reg1[`S*`R*4*32+:`S*`R*32];
                    endcase
                else
                    case (idx)
                        0: ppus_dps <= dp_reg2[`S*`R*32-1:0];
                        1: ppus_dps <= dp_reg2[`S*`R*32+:`S*`R*32];
                        2: ppus_dps <= dp_reg2[`S*`R*2*32+:`S*`R*32];
                        3: ppus_dps <= dp_reg2[`S*`R*3*32+:`S*`R*32];
                        default: ppus_dps <= dp_reg2[`S*`R*4*32+:`S*`R*32];
                    endcase
        end else if (NUM_W==6) begin
            always @(posedge clk)
                if (sel1)
                    case (idx)
                        0: ppus_dps <= dp_reg1[`S*`R*32-1:0];
                        1: ppus_dps <= dp_reg1[`S*`R*32+:`S*`R*32];
                        2: ppus_dps <= dp_reg1[`S*`R*2*32+:`S*`R*32];
                        3: ppus_dps <= dp_reg1[`S*`R*3*32+:`S*`R*32];
                        4: ppus_dps <= dp_reg1[`S*`R*4*32+:`S*`R*32];
                        default: ppus_dps <= dp_reg1[`S*`R*5*32+:`S*`R*32];
                    endcase
                else
                    case (idx)
                        0: ppus_dps <= dp_reg2[`S*`R*32-1:0];
                        1: ppus_dps <= dp_reg2[`S*`R*32+:`S*`R*32];
                        2: ppus_dps <= dp_reg2[`S*`R*2*32+:`S*`R*32];
                        3: ppus_dps <= dp_reg2[`S*`R*3*32+:`S*`R*32];
                        4: ppus_dps <= dp_reg2[`S*`R*4*32+:`S*`R*32];
                        default: ppus_dps <= dp_reg2[`S*`R*5*32+:`S*`R*32];
                    endcase
        end else if (NUM_W==7) begin
            always @(posedge clk)
                if (sel1)
                    case (idx)
                        0: ppus_dps <= dp_reg1[`S*`R*32-1:0];
                        1: ppus_dps <= dp_reg1[`S*`R*32+:`S*`R*32];
                        2: ppus_dps <= dp_reg1[`S*`R*2*32+:`S*`R*32];
                        3: ppus_dps <= dp_reg1[`S*`R*3*32+:`S*`R*32];
                        4: ppus_dps <= dp_reg1[`S*`R*4*32+:`S*`R*32];
                        5: ppus_dps <= dp_reg1[`S*`R*5*32+:`S*`R*32];
                        default: ppus_dps <= dp_reg1[`S*`R*6*32+:`S*`R*32];
                    endcase
                else
                    case (idx)
                        0: ppus_dps <= dp_reg2[`S*`R*32-1:0];
                        1: ppus_dps <= dp_reg2[`S*`R*32+:`S*`R*32];
                        2: ppus_dps <= dp_reg2[`S*`R*2*32+:`S*`R*32];
                        3: ppus_dps <= dp_reg2[`S*`R*3*32+:`S*`R*32];
                        4: ppus_dps <= dp_reg2[`S*`R*4*32+:`S*`R*32];
                        5: ppus_dps <= dp_reg2[`S*`R*5*32+:`S*`R*32];
                        default: ppus_dps <= dp_reg2[`S*`R*6*32+:`S*`R*32];
                    endcase
        end else if (NUM_W==8) begin
            always @(posedge clk)
                if (sel1)
                    case (idx)
                        0: ppus_dps <= dp_reg1[`S*`R*32-1:0];
                        1: ppus_dps <= dp_reg1[`S*`R*32+:`S*`R*32];
                        2: ppus_dps <= dp_reg1[`S*`R*2*32+:`S*`R*32];
                        3: ppus_dps <= dp_reg1[`S*`R*3*32+:`S*`R*32];
                        4: ppus_dps <= dp_reg1[`S*`R*4*32+:`S*`R*32];
                        5: ppus_dps <= dp_reg1[`S*`R*5*32+:`S*`R*32];
                        6: ppus_dps <= dp_reg1[`S*`R*6*32+:`S*`R*32];
                        default: ppus_dps <= dp_reg1[`S*`R*7*32+:`S*`R*32];
                    endcase
                else
                    case (idx)
                        0: ppus_dps <= dp_reg2[`S*`R*32-1:0];
                        1: ppus_dps <= dp_reg2[`S*`R*32+:`S*`R*32];
                        2: ppus_dps <= dp_reg2[`S*`R*2*32+:`S*`R*32];
                        3: ppus_dps <= dp_reg2[`S*`R*3*32+:`S*`R*32];
                        4: ppus_dps <= dp_reg2[`S*`R*4*32+:`S*`R*32];
                        5: ppus_dps <= dp_reg2[`S*`R*5*32+:`S*`R*32];
                        6: ppus_dps <= dp_reg2[`S*`R*6*32+:`S*`R*32];
                        default: ppus_dps <= dp_reg2[`S*`R*7*32+:`S*`R*32];
                    endcase
        end
    endgenerate

    // ppus_bias
    always @(posedge clk)
        if (sel1)
            for (i=0; i<`S; i=i+1)
                ppus_bias[i*32+:32] <= bias_reg1[i*32+:32];
        else
            for (i=0; i<`S; i=i+1)
                ppus_bias[i*32+:32] <= bias_reg2[i*32+:32];

    // ppus_dps_vld
    always @(posedge clk) 
        ppus_dps_vld <= (sel1 || sel2);
endmodule
