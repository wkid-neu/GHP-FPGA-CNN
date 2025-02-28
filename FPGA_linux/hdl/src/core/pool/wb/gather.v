`timescale 1ns / 1ps
`include "../../../incl.vh"

//
// This module collects PPUs outputs to fully use RTM bandwidth.
// It uses ping-pong registers to manage data.
//
module Pool_wb_gather (
    input clk,
    // ppus outputs
    input [(`P/2)*8-1:0] ppus_outs,
    input ppus_out_vld,
    // gathered data
    output [`S*`R*8-1:0] gathered_data,
    output gathered_data_vld
);
    // Parameter Assertions
    initial begin
        if (`S*2 < `P/`R) begin
            $error("Hyper parameter mismatch, please make sure that 2S<=P/R, current values are: P = %0d, R = %0d, S = %0d", `P, `R, `S);
            $finish;
        end

        if (`P%`R != 0) begin
            $error("Hyper parameter mismatch, please make sure that P is a multiple of R, current values are: P = %0d, R = %0d", `P, `R);
            $finish;
        end

        if (`P/`R > 6) begin
            $error("Hyper parameter mismatch, please make sure that P/R<=6, current values are: P = %0d, R = %0d", `P, `R);
            $finish;
        end
    end

    // We should collect S*2 PPUs outputs and gather them.
    // Then we send P/R data to RTM.
    // Note that N1>=N2
    localparam N1 = `S*2, N2 = `P/`R;

    reg [N1*(`P/2)*8-1:0] data1 = 0;
    reg [N1*(`P/2)*8-1:0] data2 = 0;
    reg [N1*2-1:0] shreg = {{{N1*2-1}{1'b0}}, 1'b1};
    reg [`S*`R*8-1:0] gathered_data_reg = 0;
    reg gathered_data_vld_reg = 0;
    integer i;

    //
    // Collect PPUs outputs
    //
    // shreg
    always @(posedge clk)
        if (ppus_out_vld)
            shreg <= {shreg[N1*2-2:0], shreg[N1*2-1]};

    // data1
    always @(posedge clk)
        for (i=0; i<N1; i=i+1)
            if (shreg[i])
                data1[i*(`P/2)*8+:(`P/2)*8] <= ppus_outs;

    // data2
    always @(posedge clk)
        for (i=0; i<N1; i=i+1)
            if (shreg[i+N1])
                data2[i*(`P/2)*8+:(`P/2)*8] <= ppus_outs;

    //
    // Send data to RTM
    //
    reg sel1 = 0, sel2 = 0;
    reg [$clog2(N2+1)-1:0] idx = 0;  // Use $clog2(N2+1) bits to support N2=1

    // sel1
    always @(posedge clk)
        if (ppus_out_vld && shreg[N1-1])
            sel1 <= 1;
        else if (sel1 && idx==N2-1)
            sel1 <= 0;

    // sel2
    always @(posedge clk)
        if (ppus_out_vld && shreg[N1*2-1])
            sel2 <= 1;
        else if (sel2 && idx==N2-1)
            sel2 <= 0;

    // idx
    always @(posedge clk)
        if (ppus_out_vld && (shreg[N1-1] || shreg[N1*2-1]))
            idx <= 0;
        else if (sel1 || sel2)
            idx <= idx+1;

    // gathered_data_reg
    generate
        if (N2==1) begin
            always @(posedge clk)
                if (sel1)
                    gathered_data_reg <= data1;
                else
                    gathered_data_reg <= data2;
        end else if (N2==2) begin
            always @(posedge clk)
                if (sel1) begin
                    case (idx)
                        0: begin
                            for (i=0; i<`S; i=i+1)
                                gathered_data_reg[i*`R*8+:`R*8] <= data1[i*`P*8+:`R*8];
                        end
                        default: begin
                            for (i=0; i<`S; i=i+1)
                                gathered_data_reg[i*`R*8+:`R*8] <= data1[(i*`P+`R)*8+:`R*8];
                        end
                    endcase
                end else begin
                    case (idx)
                        0: begin
                            for (i=0; i<`S; i=i+1)
                                gathered_data_reg[i*`R*8+:`R*8] <= data2[i*`P*8+:`R*8];
                        end
                        default: begin
                            for (i=0; i<`S; i=i+1)
                                gathered_data_reg[i*`R*8+:`R*8] <= data2[(i*`P+`R)*8+:`R*8];
                        end
                    endcase
                end
        end else if (N2==3) begin
            always @(posedge clk)
                if (sel1) begin
                    case (idx)
                        0: begin
                            for (i=0; i<`S; i=i+1)
                                gathered_data_reg[i*`R*8+:`R*8] <= data1[i*`P*8+:`R*8];
                        end
                        1: begin
                            for (i=0; i<`S; i=i+1)
                                gathered_data_reg[i*`R*8+:`R*8] <= data1[(i*`P+`R)*8+:`R*8];
                        end
                        default: begin
                            for (i=0; i<`S; i=i+1)
                                gathered_data_reg[i*`R*8+:`R*8] <= data1[(i*`P+`R*2)*8+:`R*8];
                        end
                    endcase
                end else begin
                    case (idx)
                        0: begin
                            for (i=0; i<`S; i=i+1)
                                gathered_data_reg[i*`R*8+:`R*8] <= data2[i*`P*8+:`R*8];
                        end
                        1: begin
                            for (i=0; i<`S; i=i+1)
                                gathered_data_reg[i*`R*8+:`R*8] <= data2[(i*`P+`R)*8+:`R*8];
                        end
                        default: begin
                            for (i=0; i<`S; i=i+1)
                                gathered_data_reg[i*`R*8+:`R*8] <= data2[(i*`P+`R*2)*8+:`R*8];
                        end
                    endcase
                end
        end else if (N2==4) begin
            always @(posedge clk)
                if (sel1) begin
                    case (idx)
                        0: begin
                            for (i=0; i<`S; i=i+1)
                                gathered_data_reg[i*`R*8+:`R*8] <= data1[i*`P*8+:`R*8];
                        end
                        1: begin
                            for (i=0; i<`S; i=i+1)
                                gathered_data_reg[i*`R*8+:`R*8] <= data1[(i*`P+`R)*8+:`R*8];
                        end
                        2: begin
                            for (i=0; i<`S; i=i+1)
                                gathered_data_reg[i*`R*8+:`R*8] <= data1[(i*`P+`R*2)*8+:`R*8];
                        end
                        default: begin
                            for (i=0; i<`S; i=i+1)
                                gathered_data_reg[i*`R*8+:`R*8] <= data1[(i*`P+`R*3)*8+:`R*8];
                        end
                    endcase
                end else begin
                    case (idx)
                        0: begin
                            for (i=0; i<`S; i=i+1)
                                gathered_data_reg[i*`R*8+:`R*8] <= data2[i*`P*8+:`R*8];
                        end
                        1: begin
                            for (i=0; i<`S; i=i+1)
                                gathered_data_reg[i*`R*8+:`R*8] <= data2[(i*`P+`R)*8+:`R*8];
                        end
                        2: begin
                            for (i=0; i<`S; i=i+1)
                                gathered_data_reg[i*`R*8+:`R*8] <= data2[(i*`P+`R*2)*8+:`R*8];
                        end
                        default: begin
                            for (i=0; i<`S; i=i+1)
                                gathered_data_reg[i*`R*8+:`R*8] <= data2[(i*`P+`R*3)*8+:`R*8];
                        end
                    endcase
                end
        end else if (N2==5) begin
            always @(posedge clk)
                if (sel1) begin
                    case (idx)
                        0: begin
                            for (i=0; i<`S; i=i+1)
                                gathered_data_reg[i*`R*8+:`R*8] <= data1[i*`P*8+:`R*8];
                        end
                        1: begin
                            for (i=0; i<`S; i=i+1)
                                gathered_data_reg[i*`R*8+:`R*8] <= data1[(i*`P+`R)*8+:`R*8];
                        end
                        2: begin
                            for (i=0; i<`S; i=i+1)
                                gathered_data_reg[i*`R*8+:`R*8] <= data1[(i*`P+`R*2)*8+:`R*8];
                        end
                        3: begin
                            for (i=0; i<`S; i=i+1)
                                gathered_data_reg[i*`R*8+:`R*8] <= data1[(i*`P+`R*3)*8+:`R*8];
                        end
                        default: begin
                            for (i=0; i<`S; i=i+1)
                                gathered_data_reg[i*`R*8+:`R*8] <= data1[(i*`P+`R*4)*8+:`R*8];
                        end
                    endcase
                end else begin
                    case (idx)
                        0: begin
                            for (i=0; i<`S; i=i+1)
                                gathered_data_reg[i*`R*8+:`R*8] <= data2[i*`P*8+:`R*8];
                        end
                        1: begin
                            for (i=0; i<`S; i=i+1)
                                gathered_data_reg[i*`R*8+:`R*8] <= data2[(i*`P+`R)*8+:`R*8];
                        end
                        2: begin
                            for (i=0; i<`S; i=i+1)
                                gathered_data_reg[i*`R*8+:`R*8] <= data2[(i*`P+`R*2)*8+:`R*8];
                        end
                        3: begin
                            for (i=0; i<`S; i=i+1)
                                gathered_data_reg[i*`R*8+:`R*8] <= data2[(i*`P+`R*3)*8+:`R*8];
                        end
                        default: begin
                            for (i=0; i<`S; i=i+1)
                                gathered_data_reg[i*`R*8+:`R*8] <= data2[(i*`P+`R*4)*8+:`R*8];
                        end
                    endcase
                end
        end else if (N2==6) begin
            always @(posedge clk)
                if (sel1) begin
                    case (idx)
                        0: begin
                            for (i=0; i<`S; i=i+1)
                                gathered_data_reg[i*`R*8+:`R*8] <= data1[i*`P*8+:`R*8];
                        end
                        1: begin
                            for (i=0; i<`S; i=i+1)
                                gathered_data_reg[i*`R*8+:`R*8] <= data1[(i*`P+`R)*8+:`R*8];
                        end
                        2: begin
                            for (i=0; i<`S; i=i+1)
                                gathered_data_reg[i*`R*8+:`R*8] <= data1[(i*`P+`R*2)*8+:`R*8];
                        end
                        3: begin
                            for (i=0; i<`S; i=i+1)
                                gathered_data_reg[i*`R*8+:`R*8] <= data1[(i*`P+`R*3)*8+:`R*8];
                        end
                        4: begin
                            for (i=0; i<`S; i=i+1)
                                gathered_data_reg[i*`R*8+:`R*8] <= data1[(i*`P+`R*4)*8+:`R*8];
                        end
                        default: begin
                            for (i=0; i<`S; i=i+1)
                                gathered_data_reg[i*`R*8+:`R*8] <= data1[(i*`P+`R*5)*8+:`R*8];
                        end
                    endcase
                end else begin
                    case (idx)
                        0: begin
                            for (i=0; i<`S; i=i+1)
                                gathered_data_reg[i*`R*8+:`R*8] <= data2[i*`P*8+:`R*8];
                        end
                        1: begin
                            for (i=0; i<`S; i=i+1)
                                gathered_data_reg[i*`R*8+:`R*8] <= data2[(i*`P+`R)*8+:`R*8];
                        end
                        2: begin
                            for (i=0; i<`S; i=i+1)
                                gathered_data_reg[i*`R*8+:`R*8] <= data2[(i*`P+`R*2)*8+:`R*8];
                        end
                        3: begin
                            for (i=0; i<`S; i=i+1)
                                gathered_data_reg[i*`R*8+:`R*8] <= data2[(i*`P+`R*3)*8+:`R*8];
                        end
                        4: begin
                            for (i=0; i<`S; i=i+1)
                                gathered_data_reg[i*`R*8+:`R*8] <= data2[(i*`P+`R*4)*8+:`R*8];
                        end
                        default: begin
                            for (i=0; i<`S; i=i+1)
                                gathered_data_reg[i*`R*8+:`R*8] <= data2[(i*`P+`R*5)*8+:`R*8];
                        end
                    endcase
                end
        end
    endgenerate

    // gathered_data_vld_reg
    always @(posedge clk)
        gathered_data_vld_reg <= (sel1 || sel2);

`ifdef M32P64Q16R16S8
    shift_reg #(1, `S*`R*8) shift_reg_gathered_data(clk, gathered_data_reg, gathered_data);
    shift_reg #(1, 1) shift_reg_gathered_data_vld(clk, gathered_data_vld_reg, gathered_data_vld);
`elsif M32P96Q16R16S8
    shift_reg #(1, `S*`R*8) shift_reg_gathered_data(clk, gathered_data_reg, gathered_data);
    shift_reg #(1, 1) shift_reg_gathered_data_vld(clk, gathered_data_vld_reg, gathered_data_vld);
`elsif M64P64Q16R16S8
    shift_reg #(1, `S*`R*8) shift_reg_gathered_data(clk, gathered_data_reg, gathered_data);
    shift_reg #(1, 1) shift_reg_gathered_data_vld(clk, gathered_data_vld_reg, gathered_data_vld);
`else
    assign gathered_data = gathered_data_reg;
    assign gathered_data_vld = gathered_data_vld_reg;
`endif
endmodule
