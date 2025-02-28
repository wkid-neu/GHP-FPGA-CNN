`timescale 1ns / 1ps
`include "../../incl.vh"

//
// Processing element of the Pool engine.
//
module Pool_PE (
    input clk,
    // inputs
    input [7:0] x,
    input [3:0] cmd,  // {end, max, avg, start}
    input [$clog2(`S/2)-1:0] sel,
    input [$clog2(`S/2)-1:0] sel_delay,
    // outputs
    output [13:0] y,
    output reg y_vld = 0
);
    // We have S/2 y_reg, only one y_reg is updated at a clock cycle.
    reg [(`S/2)*14-1:0] y_regs = 0;
    
    always @(posedge clk)
        if (cmd[0])
            y_regs[sel*14+:14] <= x;
        else if (cmd[1])
            y_regs[sel*14+:14] <= y_regs[sel*14+:14]+x;
        else if (cmd[2])
            y_regs[sel*14+:14] <= (x>y_regs[sel*14+:14]?x:y_regs[sel*14+:14]);

    always @(posedge clk)
        y_vld <= cmd[3];

    assign y = y_regs[sel_delay*14+:14];
endmodule
