`timescale 1ns / 1ps
`include "../../incl.vh"

//
// Memory instances of RTM
//
module rtm_mem (
    input clk,
    // Read ports
    input [`S-1:0] rd_en,
    input [`S*$clog2(`RTM_DEPTH)-1:0] rd_addr,
    output [`S*`R*8-1:0] dout,
    // Write ports
    input [`S-1:0] wr_en,
    input [`S*$clog2(`RTM_DEPTH)-1:0] wr_addr,
    input [`S*`R*8-1:0] din
);
    genvar i;
    generate
        for (i=0; i<`S; i=i+1) begin: RTM
            sdp_uram #(
                .DATA_WIDTH(`R*8),
                .DEPTH(`RTM_DEPTH),
                .NUM_PIPE(`RTM_URAM_NUM_PIPE)
            ) sdp_uram_inst(
            	.clk(clk),
                .wr_en(wr_en[i]),
                .din(din[i*`R*8+:`R*8]),
                .wr_addr(wr_addr[i*$clog2(`RTM_DEPTH)+:$clog2(`RTM_DEPTH)]),
                .rd_en(rd_en[i]),
                .rd_addr(rd_addr[i*$clog2(`RTM_DEPTH)+:$clog2(`RTM_DEPTH)]),
                .dout(dout[i*`R*8+:`R*8])
            );
        end
    endgenerate
endmodule
