`timescale 1ns / 1ps
`include "../../incl.vh"

//
// Prepare bias
//
module Fc_bias_pre (
    input clk,
    input start_pulse,
    // instruction
    input [$clog2(`BM_DEPTH)-1:0] B_addr,
    // BM read ports
    output reg bm_rd_en = 0,
    output reg [$clog2(`BM_DEPTH)-1:0] bm_rd_addr = 0,
    input [`BM_DATA_WIDTH-1:0] bm_dout,
    input bm_dout_vld,
    // prepared bias
    output reg [`DDR_AXIS_DATA_WIDTH/8*32-1:0] bias = 0,
    // read the next one
    input read_next
);
    // Ratio of required bandwith and provided bandwidth
    // The value is greater than 1 and the current value is 4.
    localparam N = (`DDR_AXIS_DATA_WIDTH/8*32)/`BM_DATA_WIDTH;

    //
    // Read bias
    //
    reg [N-1:0] rd_shreg = 0;
    reg [$clog2(`BM_DEPTH)-1:0] next_addr = 0;

    // rd_shreg
    always @(posedge clk)
        if (start_pulse)
            rd_shreg <= {{{N-1}{1'b0}}, 1'b1};
        else if (rd_shreg != {N{1'b0}}) begin
            if (rd_shreg[N-1]) begin
                if (read_next)
                    rd_shreg <= {{{N-1}{1'b0}}, 1'b1};
                else
                    rd_shreg <= {N{1'b0}};
            end else
                rd_shreg <= {rd_shreg[N-2:0], 1'b0};
        end else if (read_next)
            rd_shreg <= {{{N-1}{1'b0}}, 1'b1};

    // next_addr
    always @(posedge clk)
        if (start_pulse)
            next_addr <= B_addr;
        else if (rd_shreg != {N{1'b0}})
            next_addr <= next_addr+1;

    // bm_rd_en, bm_rd_addr
    always @(posedge clk) begin
        bm_rd_en <= (rd_shreg != {N{1'b0}});
        bm_rd_addr <= next_addr;
    end

    //
    // Save bias
    //
    reg [N-1:0] wr_shreg = {{{N-1}{1'b0}}, 1'b1};
    reg [`BM_DATA_WIDTH-1:0] bm_dout_delay = 0;
    reg [N-1:0] wr_en = 0;
    integer i;

    // wr_shreg
    always @(posedge clk)
        if (bm_dout_vld)
            wr_shreg <= {wr_shreg[N-2:0], wr_shreg[N-1]};

    // bm_dout_delay, wr_en
    always @(posedge clk) begin
        bm_dout_delay <= bm_dout;
        for (i=0; i<N; i=i+1)
            wr_en[i] <= (bm_dout_vld && wr_shreg[i]);
    end

    // bias
    always @(posedge clk)
        for (i=0; i<N; i=i+1)
            if (wr_en[i])
                bias[i*`BM_DATA_WIDTH+:`BM_DATA_WIDTH] <= bm_dout_delay;
endmodule
