`timescale 1ns / 1ps
`include "../incl.vh"

//
// Read vectors from Vector FIFOs and write them into MXM
//
module xbus_mxm_wr (
    input clk,
    // Vector FIFOs
    output reg [`P-1:0] vec_fifos_rd_en = 0,
    input [`P*`S*8-1:0] vec_fifos_dout,
    input [`P-1:0] vec_fifos_empty,
    // MXM write ports
    output mxm_wr_en,
    output [`P*2*8-1:0] mxm_din,
    input mxm_prog_full
);
    // Parameter Assertion
    initial begin
        if ((`S!=4) && (`S!=8)) begin
            $error("Hyper parameter mismatch, please make sure that S is in {4, 8}, current values are: S = %0d", `S);
            $finish;
        end
    end

    localparam N = `S/2;  // 2, 4, ...
    reg mxm_wr_en_reg = 0;
    reg [`P*2*8-1:0] mxm_din_reg = 0;
    integer i;

    //
    // Vector FIFO Read Ports
    //
    wire ready;
    assign ready = vec_fifos_empty=={`P{1'b0}};

    generate
        if (N == 2) begin
            localparam RD = 0, STALL = 1;
            (* fsm_encoding = "one_hot" *) reg [0:0] state = RD;

            always @(posedge clk)
                case (state)
                    RD: if (ready) state <= STALL; 
                    STALL: if (~mxm_prog_full) state <= RD;
                endcase

            always @(posedge clk)
                for (i=0; i<`P; i=i+1)
                    vec_fifos_rd_en[i] <= (state==RD && ready);
        end else if (N == 4) begin
            localparam RD = 0, STALL1 = 1, STALL2 = 2, STALL3 = 3;
            (* fsm_encoding = "one_hot" *) reg [1:0] state = RD;

            always @(posedge clk)
                case (state)
                    RD: if (ready) state <= STALL1;
                    STALL1: state <= STALL2;
                    STALL2: state <= STALL3;
                    STALL3: if (~mxm_prog_full) state <= RD;
                endcase

            always @(posedge clk)
                for (i=0; i<`P; i=i+1)
                    vec_fifos_rd_en[i] <= (state==RD && ready);
        end
    endgenerate

    //
    // MXM write ports
    //
    reg dout_vld = 0;
    always @(posedge clk)
        dout_vld <= vec_fifos_rd_en[0];

    generate
        if (N == 2) begin
            reg dout_vld2 = 0;
            always @(posedge clk)
                dout_vld2 <= dout_vld;

            always @(posedge clk)
                mxm_wr_en_reg <= (dout_vld || dout_vld2);

            always @(posedge clk)
                for (i=0; i<`P; i=i+1)
                    if (dout_vld)
                        mxm_din_reg[i*2*8+:2*8] <= vec_fifos_dout[i*`S*8+:2*8];
                    else
                        mxm_din_reg[i*2*8+:2*8] <= vec_fifos_dout[i*`S*8+2*8+:2*8];
        end else if (N == 4) begin
            reg dout_vld2 = 0, dout_vld3 = 0, dout_vld4 = 0;
            always @(posedge clk)
                {dout_vld2, dout_vld3, dout_vld4} <= {dout_vld, dout_vld2, dout_vld3};

            always @(posedge clk)   
                mxm_wr_en_reg <= (dout_vld || dout_vld2 || dout_vld3 || dout_vld4);

            always @(posedge clk)
                for (i=0; i<`P; i=i+1)
                    if (dout_vld)
                        mxm_din_reg[i*2*8+:2*8] <= vec_fifos_dout[i*`S*8+:2*8];
                    else if (dout_vld2)
                        mxm_din_reg[i*2*8+:2*8] <= vec_fifos_dout[i*`S*8+2*8+:2*8];
                    else if (dout_vld3)
                        mxm_din_reg[i*2*8+:2*8] <= vec_fifos_dout[i*`S*8+2*8*2+:2*8];
                    else
                        mxm_din_reg[i*2*8+:2*8] <= vec_fifos_dout[i*`S*8+2*8*3+:2*8];
        end
    endgenerate

`ifdef M32P64Q16R16S8
    // Add additional pipeline stages for high performance
    shift_reg #(1, 1) shift_reg_mxm_wr_en(clk, mxm_wr_en_reg, mxm_wr_en);
    shift_reg #(1, `P*2*8) shift_reg_mxm_din(clk, mxm_din_reg, mxm_din);
`elsif M32P96Q16R16S8
    // Add additional pipeline stages for high performance
    shift_reg #(1, 1) shift_reg_mxm_wr_en(clk, mxm_wr_en_reg, mxm_wr_en);
    shift_reg #(1, `P*2*8) shift_reg_mxm_din(clk, mxm_din_reg, mxm_din);
`elsif M64P64Q16R16S8
    // Add additional pipeline stages for high performance
    shift_reg #(1, 1) shift_reg_mxm_wr_en(clk, mxm_wr_en_reg, mxm_wr_en);
    shift_reg #(1, `P*2*8) shift_reg_mxm_din(clk, mxm_din_reg, mxm_din);
`else
    assign mxm_wr_en = mxm_wr_en_reg;
    assign mxm_din = mxm_din_reg;
`endif
endmodule
