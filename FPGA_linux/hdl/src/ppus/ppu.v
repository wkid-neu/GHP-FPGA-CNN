`timescale 1ns / 1ps
`include "../incl.vh"

//
// Post processing unit.
// It has two modes and can be configured at runtime
//
module ppu #(
    parameter TAG_WIDTH = 1
)(
    input clk,
    input mode,
    input [TAG_WIDTH-1:0] in_tag,
    // mode0
    input signed [26:0] A,
    input signed [33:0] B,
    input signed [33:0] C,
    // mode1
    input signed [26:0] D,  // F at next clock edge
    input signed [8:0] E,  // H at next clock edge
    // shift and add
    input [5:0] S,
    input [7:0] Z,
    // output
    output [7:0] out,
    output [TAG_WIDTH-1:0] out_tag
);
    wire signed [61:0] mul_c;
    wire [TAG_WIDTH-1:0] mul_out_tag;

    wire signed [36:0] adder_c;
    wire [TAG_WIDTH-1:0] adder_out_tag;

    wire signed [9:0] shift_c;
    wire [TAG_WIDTH-1:0] shift_out_tag;

    wire signed [8:0] round_b;
    wire [TAG_WIDTH-1:0] round_out_tag;

    // mode, waiting for the adder output
    reg signed [26:0] A_delay = 0;
    // register the output of multipler as adder input
    reg signed [35:0] mul_c_delay = 0;

    always @(posedge clk) begin
        A_delay <= A;
        mul_c_delay <= mul_c;
    end

    ppu_mul #(
        .TAG_WIDTH(TAG_WIDTH)
    ) ppu_mul_inst(
    	.clk(clk),
        .a((~mode) ? adder_c[34:0] : {{26{E[8]}}, E[8:0]}),
        .b((~mode) ? A_delay : D),
        .in_tag((~mode) ? adder_out_tag : in_tag),
        .c(mul_c),
        .out_tag(mul_out_tag)
    );

    ppu_adder #(
        .TAG_WIDTH(TAG_WIDTH)
    ) ppu_adder_inst(
    	.clk(clk),
        .a((~mode) ? {B[33], B[33], B[33:0]} : mul_c[35:0]),
        .b((~mode) ? {C[33], C[33], C[33:0]} : mul_c_delay),
        .in_tag((~mode) ? in_tag : mul_out_tag),
        .c(adder_c),
        .out_tag(adder_out_tag)
    );
    
    ppu_shift #(
        .TAG_WIDTH(TAG_WIDTH)
    ) ppu_shift_inst(
    	.clk(clk),
        .a((~mode) ? mul_c : {{25{adder_c[36]}}, adder_c[36:0]}),
        .b(S),
        .in_tag((~mode) ? mul_out_tag : adder_out_tag),
        .c(shift_c),
        .out_tag(shift_out_tag)
    );

    ppu_round #(
        .TAG_WIDTH(TAG_WIDTH)
    ) ppu_round_inst(
    	.clk(clk),
        .a(shift_c),
        .in_tag(shift_out_tag),
        .b(round_b),
        .out_tag(round_out_tag)
    );
    
    ppu_add_zero_point #(
        .TAG_WIDTH(TAG_WIDTH)
    ) ppu_add_zero_point_inst(
    	.clk(clk),
        .a(round_b),
        .zero_point(Z),
        .in_tag(round_out_tag),
        .b(out),
        .out_tag(out_tag)
    );
endmodule

//
// 35*27 multiplier
//
module ppu_mul #(
    parameter TAG_WIDTH = 1
)(
    input clk,
    input signed [34:0] a,
    input signed [26:0] b,
    input [TAG_WIDTH-1:0] in_tag,
    output reg signed [61:0] c = 0,
    output reg [TAG_WIDTH-1:0] out_tag = 0
);
    reg signed [34:0] a1 = 0;
    reg signed [26:0] b1 = 0;
    reg [TAG_WIDTH-1:0] tag1 = 0;

    reg signed [34:0] a2 = 0;
    reg signed [26:0] b2 = 0;
    reg [TAG_WIDTH-1:0] tag2 = 0;

    reg signed [61:0] m = 0;
    reg [TAG_WIDTH-1:0] tag3 = 0;
    
    always @(posedge clk) begin
        a1 <= a;
        b1 <= b;
        tag1 <= in_tag;

        a2 <= a1;
        b2 <= b1;
        tag2 <= tag1;

        m <= a2*b2;
        tag3 <= tag2;

        c <= m;
        out_tag <= tag3;
    end
endmodule

//
// 36-bit adder
//
module ppu_adder #(
    parameter TAG_WIDTH = 1
)(
    input clk,
    input signed [35:0] a,
    input signed [35:0] b,
    input [TAG_WIDTH-1:0] in_tag,
    output reg signed [36:0] c = 0,
    output reg [TAG_WIDTH-1:0] out_tag = 0
);
    always @(posedge clk) begin
        c <= a+b;
        out_tag <= in_tag;
    end
endmodule

//
// Perform right shift on a 62-bit signed data to produce a 10-bit signed data
//
module ppu_shift #(
    parameter TAG_WIDTH = 1
)(
    input clk,
    input signed [61:0] a,
    input [5:0] b,
    input [TAG_WIDTH-1:0] in_tag,
    output reg signed [9:0] c = 0,
    output reg [TAG_WIDTH-1:0] out_tag = 0
);
    always @(posedge clk) begin
        c <= a >>> b;
        out_tag <= in_tag;
    end
endmodule

//
// Perform round on the fixed-point data `a` with 1 fraction bits.
//
module ppu_round #(
    parameter TAG_WIDTH = 1
)(
    input clk,
    input signed [9:0] a,
    input [TAG_WIDTH-1:0] in_tag,
    output reg signed [8:0] b = 0,
    output reg [TAG_WIDTH-1:0] out_tag = 0
);
    localparam BMAX = 255;
    localparam BMIN = -256;
    
    wire signed [9:0] tmp;
    wire add; 

    // assign add = a[24] ? (a[15] & (|a[14:0])) : a[15];
    assign add = a[0];
    assign tmp = {a[9], a[9:1]} + add;

    always @(posedge clk) begin
        if (tmp > BMAX)
            b <= BMAX;
        else if (tmp < BMIN)
            b <= BMIN;
        else
            b <= tmp;

        out_tag <= in_tag;
    end
endmodule

//
// Add zero_point
//
module ppu_add_zero_point #(
    parameter TAG_WIDTH = 1
)(
    input clk,
    input signed [8:0] a,
    input [7:0] zero_point,
    input [TAG_WIDTH-1:0] in_tag,
    output reg [7:0] b = 0,
    output reg [TAG_WIDTH-1:0] out_tag = 0
);
    wire signed [9:0] tmp;
    assign tmp = a + $signed({1'b0, zero_point});

    always @(posedge clk) begin
        if (tmp > 255)
            b <= 255;
        else if
            (tmp < 0) b <= 0;
        else
            b <= tmp;

        out_tag <= in_tag;
    end
endmodule
