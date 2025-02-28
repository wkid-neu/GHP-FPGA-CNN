`timescale 1ns / 1ps
`include "../../incl.vh"

//
// PE array
//
module Pool_arr (
    input clk,
    // inputs
    input [`P*2*8-1:0] xs,
    input [3:0] cmd,
    input [$clog2(`S/2)-1:0] sel,
    input [$clog2(`S/2)-1:0] sel_delay,
    // outputs
    output [`P*2*14-1:0] ys,
    output y_vld
);
    wire [`P*2-1:0] y_vld_list;
    assign y_vld = y_vld_list[0];

    genvar i;
    generate
        for(i=0; i<`P*2; i=i+1) begin
            Pool_PE Pool_PE_inst(
                .clk(clk),
                .x(xs[i*8+:8]),
                .cmd(cmd),
                .sel(sel),
                .sel_delay(sel_delay),
                .y(ys[i*14+:14]),
                .y_vld(y_vld_list[i])
            );
        end
    endgenerate
endmodule
