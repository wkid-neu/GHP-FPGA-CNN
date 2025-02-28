`timescale 1ns / 1ps
`include "../../incl.vh"

//
// DRAM to Chip
//
module cwm_d2c (
    input clk,
    // control signal
    input start_pulse,
    input [31:0] d_addr,
    input [31:0] c_addr,
    input [31:0] n_bytes, 
    output done_pulse,
    // DMA read controller
    output reg [`DDR_AXI_ADDR_WIDTH-1:0] dma_rd_desc_addr = 0,
    output reg [`DDR_LEN_WIDTH-1:0] dma_rd_desc_len = 0,
    output reg dma_rd_desc_valid = 0,
    input [`DDR_AXIS_DATA_WIDTH-1:0] dma_rd_read_data_tdata,
    input dma_rd_read_data_tvalid,
    input dma_rd_read_data_tlast,
    // CWM write ports
    output wr_en,
    output [$clog2(`CWM_DEPTH)-1:0] wr_addr,
    output [`M*4*8-1:0] din,
    output reg [$clog2(`CWM_DEPTH):0] wr_ptr = 0
);
    localparam N = `M*4*8/`DDR_AXIS_DATA_WIDTH;

    reg [N-1:0] shreg = {{{N-1}{1'b0}}, 1'b1};
    reg [$clog2(`CWM_DEPTH)-1:0] next_addr = 0;
    reg wr_en_reg = 0;
    reg [$clog2(`CWM_DEPTH)-1:0] wr_addr_reg = 0;
    reg [`M*4*8-1:0] din_reg = 0;
    integer i;

    // shreg
    always @(posedge clk)
        if (dma_rd_read_data_tvalid)
            shreg <= {shreg[N-2:0], shreg[N-1]};

    // next_addr
    always @(posedge clk)
        if (start_pulse)
            next_addr <= c_addr;
        else if (dma_rd_read_data_tvalid && shreg[N-1])
            next_addr <= next_addr+1;

    // dma_rd_desc_addr, dma_rd_desc_len, dma_rd_desc_valid
    always @(posedge clk) begin
        dma_rd_desc_valid <= start_pulse;
        dma_rd_desc_addr <= d_addr;
        dma_rd_desc_len <= n_bytes;
    end

    // wr_en_reg, wr_addr_reg, din_reg
    always @(posedge clk) begin
        wr_en_reg <= (dma_rd_read_data_tvalid && shreg[N-1]);
        wr_addr_reg <= next_addr;
        for (i=0; i<N; i=i+1)
            if (shreg[i])
                din_reg[i*`DDR_AXIS_DATA_WIDTH+:`DDR_AXIS_DATA_WIDTH] <= dma_rd_read_data_tdata;
    end

    // wr_ptr
    always @(posedge clk)
        if (start_pulse)
            wr_ptr <= c_addr;
        else if (wr_en)  // Note that this is wr_en, not wr_en_reg
            wr_ptr <= wr_ptr+1;

`ifdef M32P64Q16R16S8
    // Add additional pipeline stages for high performance.
    shift_reg #(1, 1) shift_reg_wr_en(clk, wr_en_reg, wr_en);
    shift_reg #(1, $clog2(`CWM_DEPTH)) shift_reg_wr_addr(clk, wr_addr_reg, wr_addr);
    shift_reg #(1, `M*4*8) shift_reg_din(clk, din_reg, din);
`elsif M32P96Q16R16S8
    // Add additional pipeline stages for high performance.
    shift_reg #(1, 1) shift_reg_wr_en(clk, wr_en_reg, wr_en);
    shift_reg #(1, $clog2(`CWM_DEPTH)) shift_reg_wr_addr(clk, wr_addr_reg, wr_addr);
    shift_reg #(1, `M*4*8) shift_reg_din(clk, din_reg, din);
`elsif M64P64Q16R16S8
    // Add additional pipeline stages for high performance.
    shift_reg #(1, 1) shift_reg_wr_en(clk, wr_en_reg, wr_en);
    shift_reg #(1, $clog2(`CWM_DEPTH)) shift_reg_wr_addr(clk, wr_addr_reg, wr_addr);
    shift_reg #(1, `M*4*8) shift_reg_din(clk, din_reg, din);
`else
    assign wr_en = wr_en_reg;
    assign wr_addr = wr_addr_reg;
    assign din = din_reg;
`endif

    // done_pulse
    // It not necessary to set this pulse exactly.
    shift_reg #(10, 1) shift_reg_done_pulse(clk, (dma_rd_read_data_tvalid && dma_rd_read_data_tlast), done_pulse);
endmodule
