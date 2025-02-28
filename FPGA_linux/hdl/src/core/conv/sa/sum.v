`timescale 1ns / 1ps
`include "../../../incl.vh"

//
// The sum unit.
// It accumulates partial sums to make the final sum.
// It is responsibile for 8 PEs.
//
module Conv_sa_sum(
    input clk,
    // Data ports
    input [18:0] in_psum1,
    input [18:0] in_psum2,
    output [31:0] out_sum1,
    output [31:0] out_sum2,
    // Flag ports
    input in_psum_vld,  // 1 cycle delay
    input in_psum_last_rnd,  // 1 cycle delay
    input [2:0] in_psum_wr_addr,  // 1 cycle delay
    input [2:0] in_psum_prefetch_addr,
    output reg out_psum_vld = 0,
    output reg out_psum_last_rnd = 0,
    output reg [2:0] out_psum_wr_addr = 0,
    output reg [2:0] out_psum_prefetch_addr = 0
);
    reg [63:0] mem [7:0];
    integer i;

    initial begin
        for (i=0; i<8; i=i+1)
            mem[i] = 0;
    end

    //
    // Prefetch
    //
    reg [31:0] prefetched_psum1 = 0;
    reg [31:0] prefetched_psum2 = 0;
    always @(posedge clk)
        {prefetched_psum2, prefetched_psum1} <= mem[in_psum_prefetch_addr];

    //
    // Write
    //
    reg [31:0] psum1 = 0;
    reg [31:0] psum2 = 0;
    always @(posedge clk) begin
        psum1 <= prefetched_psum1 + in_psum1;
        psum2 <= prefetched_psum2 + in_psum2;
    end

    always @(posedge clk) begin
        if (in_psum_vld) begin
            if (in_psum_last_rnd) 
                mem[in_psum_wr_addr] <= 0;
            else
                mem[in_psum_wr_addr] <= {psum2, psum1};
        end
    end

    assign out_sum1 = psum1;
    assign out_sum2 = psum2;

    //
    // Chain
    //
    always @(posedge clk) begin
        out_psum_vld <= in_psum_vld;
        out_psum_last_rnd <= in_psum_last_rnd;
        out_psum_wr_addr <= in_psum_wr_addr;
        out_psum_prefetch_addr <= in_psum_prefetch_addr;
    end
endmodule
