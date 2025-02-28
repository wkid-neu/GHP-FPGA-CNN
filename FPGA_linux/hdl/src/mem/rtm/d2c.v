`timescale 1ns / 1ps
`include "../../incl.vh"

//
// Load data from DRAM
// 
module rtm_d2c (
    input clk,
    // control signal
    input start_pulse,
    input [31:0] d_addr,
    input [31:0] c_addr,
    input [31:0] n_bytes, 
    output reg done_pulse = 0,
    // DMA read controller
    output reg [`DDR_AXI_ADDR_WIDTH-1:0] dma_rd_desc_addr = 0,
    output reg [`DDR_LEN_WIDTH-1:0] dma_rd_desc_len = 0,
    output reg dma_rd_desc_valid = 0,
    input [`DDR_AXIS_DATA_WIDTH-1:0] dma_rd_read_data_tdata,
    input dma_rd_read_data_tvalid,
    input dma_rd_read_data_tlast,
    // RTM write ports (for DRAM)
    output rtm_wr_vld,
    output [`S-1:0] rtm_wr_en,
    output [`S*$clog2(`RTM_DEPTH)-1:0] rtm_wr_addr,
    output [`S*`R*8-1:0] rtm_din
);
    always @(posedge clk) begin
        dma_rd_desc_valid <= start_pulse;
        dma_rd_desc_addr <= d_addr;
        dma_rd_desc_len <= n_bytes;
    end

    always @(posedge clk)
        done_pulse <= (dma_rd_read_data_tvalid && dma_rd_read_data_tlast);

    generate
        if (`S*`R*8 == `DDR_AXIS_DATA_WIDTH) begin  // 1:1
            rtm_d2c_1_1 rtm_d2c_1_1_inst(
                .clk(clk),
                .start_pulse(start_pulse),
                .c_addr(c_addr),
                .dma_rd_read_data_tdata(dma_rd_read_data_tdata),
                .dma_rd_read_data_tvalid(dma_rd_read_data_tvalid),
                .rtm_wr_vld(rtm_wr_vld),
                .rtm_wr_en(rtm_wr_en),
                .rtm_wr_addr(rtm_wr_addr),
                .rtm_din(rtm_din)
            );
        end else begin  // N:1
            rtm_d2c_N_1 rtm_d2c_N_1_inst(
                .clk(clk),
                .start_pulse(start_pulse),
                .c_addr(c_addr),
                .dma_rd_read_data_tdata(dma_rd_read_data_tdata),
                .dma_rd_read_data_tvalid(dma_rd_read_data_tvalid),
                .rtm_wr_vld(rtm_wr_vld),
                .rtm_wr_en(rtm_wr_en),
                .rtm_wr_addr(rtm_wr_addr),
                .rtm_din(rtm_din)
            );
        end
    endgenerate
endmodule

//
// RTM A bandwidth : DRAM bandwidth = 1 : 1
//
module rtm_d2c_1_1 (
    input clk,
    // control signals
    input start_pulse,
    input [31:0] c_addr,
    // DMA read controller
    input [`DDR_AXIS_DATA_WIDTH-1:0] dma_rd_read_data_tdata,
    input dma_rd_read_data_tvalid,
    // RTM write ports (for DRAM)
    output reg rtm_wr_vld = 0,
    output reg [`S-1:0] rtm_wr_en = 0,
    output reg [`S*$clog2(`RTM_DEPTH)-1:0] rtm_wr_addr = 0,
    output reg [`S*`R*8-1:0] rtm_din = 0
);
    // Parameter Assertions
    initial begin
        if (`S*`R*8 != `DDR_AXIS_DATA_WIDTH) begin
            $error("Hyper parameter mismatch, please make sure that S*R*8==DDR_AXIS_DATA_WIDTH, current values are: DDR_AXIS_DATA_WIDTH = %0d, R = %0d, S = %0d", `DDR_AXIS_DATA_WIDTH, `R, `S);
            $finish;
        end
    end

    reg [$clog2(`RTM_DEPTH)-1:0] next_addr = 0;
    integer i;

    // next_addr
    always @(posedge clk)
        if (start_pulse)
            next_addr <= c_addr;
        else if (dma_rd_read_data_tvalid)
            next_addr <= next_addr+1;

    always @(posedge clk) begin
        rtm_wr_vld <= dma_rd_read_data_tvalid;
        for (i=0; i<`S; i=i+1) begin
            rtm_wr_en[i] <= dma_rd_read_data_tvalid;
            rtm_wr_addr[i*$clog2(`RTM_DEPTH)+:$clog2(`RTM_DEPTH)] <= next_addr;
        end
        rtm_din <= dma_rd_read_data_tdata;
    end
endmodule

//
// RTM A bandwidth : DRAM bandwidth = N : 1
// N = 2, 4, ...
//
module rtm_d2c_N_1 (
    input clk,
    // control signals
    input start_pulse,
    input [31:0] c_addr,
    // DMA read controller
    input [`DDR_AXIS_DATA_WIDTH-1:0] dma_rd_read_data_tdata,
    input dma_rd_read_data_tvalid,
    // RTM write ports (for DRAM)
    output reg rtm_wr_vld = 0,
    output reg [`S-1:0] rtm_wr_en = 0,
    output reg [`S*$clog2(`RTM_DEPTH)-1:0] rtm_wr_addr = 0,
    output reg [`S*`R*8-1:0] rtm_din = 0
);
    // Parameter Assertions
    initial begin
        if ((`S*`R*8)%`DDR_AXIS_DATA_WIDTH != 0) begin
            $error("Hyper parameter mismatch, please make sure that S*R*8 is a multiple of DDR_AXIS_DATA_WIDTH, current values are: DDR_AXIS_DATA_WIDTH = %0d, R = %0d, S = %0d", `DDR_AXIS_DATA_WIDTH, `R, `S);
            $finish;
        end
    end

    localparam N = `S*`R*8/`DDR_AXIS_DATA_WIDTH;
    
    reg [$clog2(`RTM_DEPTH)-1:0] next_addr = 0;
    reg [N-1:0] shreg = {{{N-1}{1'b0}}, 1'b1};
    integer i, j;

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

    always @(posedge clk) begin
        rtm_wr_vld <= dma_rd_read_data_tvalid;

        for (j=0; j<N; j=j+1)
            for (i=0; i<`S/N; i=i+1)
                rtm_wr_en[j*`S/N+i] <= (dma_rd_read_data_tvalid && shreg[j]);
        for (i=0; i<`S; i=i+1)
            rtm_wr_addr[i*$clog2(`RTM_DEPTH)+:$clog2(`RTM_DEPTH)] <= next_addr;

        for (j=0; j<N; j=j+1)
            if (shreg[j])
                rtm_din[j*`DDR_AXIS_DATA_WIDTH+:`DDR_AXIS_DATA_WIDTH] <= dma_rd_read_data_tdata;
    end
endmodule
