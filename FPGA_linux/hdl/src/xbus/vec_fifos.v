`timescale 1ns / 1ps
`include "../incl.vh"

//
// Vector fifos
//
module xbus_vec_fifos (
    input clk,
    // Write ports
    input [`P-1:0] wr_en,
    input [`P*`S*8-1:0] din,
    output [`P-1:0] prog_full,
    // Read ports
    input [`P-1:0] rd_en,
    output [`P*`S*8-1:0] dout,
    output [`P-1:0] empty
);
    genvar i;
    generate
        for (i=0; i<`P; i=i+1) begin
            sync_fifo #(
                .DATA_WIDTH(`S*8),
                .DEPTH(64),
                .PROG_FULL(54),
                .HAS_EMPTY(1),
                .HAS_ALMOST_EMPTY(0),
                .HAS_PROG_FULL(1),
                .RAM_STYLE("distributed")
            ) sync_fifo_inst(
                .clk(clk),
                .rd_en(rd_en[i]),
                .dout(dout[i*`S*8+:`S*8]),
                .empty(empty[i]),
                .wr_en(wr_en[i]),
                .din(din[i*`S*8+:`S*8]),
                .prog_full(prog_full[i])
            );
        end
    endgenerate
endmodule
