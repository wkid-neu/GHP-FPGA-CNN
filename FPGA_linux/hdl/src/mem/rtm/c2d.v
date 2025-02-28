`timescale 1ns / 1ps
`include "../../incl.vh"

//
// Write data back to DRAM
//
module rtm_c2d (
    input clk,
    // Control signals
    input start_pulse,
    input [31:0] d_addr,
    input [31:0] c_addr,
    input [31:0] n_bytes, 
    output done_pulse,
    // DMA write controller
    output reg [`DDR_AXI_ADDR_WIDTH-1:0] dma_wr_desc_addr = 0,
    output reg [`DDR_LEN_WIDTH-1:0] dma_wr_desc_len = 0,
    output reg dma_wr_desc_valid = 0,
    input dma_wr_desc_status_valid,
    output [`DDR_AXIS_DATA_WIDTH-1:0] dma_wr_write_data_tdata,
    output dma_wr_write_data_tvalid,
    input dma_wr_write_data_tready,
    output dma_wr_write_data_tlast,
    // RTM read ports
    output rtm_rd_vld,
    output rtm_rd_last,
    output [`S-1:0] rtm_rd_en,
    output [`S*$clog2(`RTM_DEPTH)-1:0] rtm_rd_addr,
    input [`S*`R*8-1:0] rtm_dout,
    input rtm_dout_vld,
    input rtm_dout_last
);  
    // fifo ports
    wire fifo_rd_en;
    wire [`DDR_AXIS_DATA_WIDTH-1:0] fifo_dout;
    wire fifo_dout_last;
    wire fifo_empty;
    wire fifo_wr_en;
    wire [`DDR_AXIS_DATA_WIDTH-1:0] fifo_din;
    wire fifo_din_last;
    wire fifo_prog_full;
    
    reg [$clog2(`RTM_DEPTH)-1:0] init_rtm_len = 0;

    always @(posedge clk)
        init_rtm_len <= n_bytes[31:$clog2(`R*`S)]-1;

    // dma_wr_desc_addr, dma_wr_desc_len, dma_wr_desc_valid
    always @(posedge clk) begin
        dma_wr_desc_valid <= start_pulse;
        dma_wr_desc_addr <= d_addr;
        dma_wr_desc_len <= n_bytes;
    end

    generate
        if (`S*`R*8 == `DDR_AXIS_DATA_WIDTH) begin  // 1:1
            rtm_c2d_1_1 rtm_c2d_1_1_inst(
                .clk(clk),
                .start_pulse(start_pulse),
                .c_addr(c_addr),
                .init_rtm_len(init_rtm_len),
                .rtm_rd_vld(rtm_rd_vld),
                .rtm_rd_last(rtm_rd_last),
                .rtm_rd_en(rtm_rd_en),
                .rtm_rd_addr(rtm_rd_addr),
                .rtm_dout(rtm_dout),
                .rtm_dout_vld(rtm_dout_vld),
                .rtm_dout_last(rtm_dout_last),
                .fifo_wr_en(fifo_wr_en),
                .fifo_din(fifo_din),
                .fifo_din_last(fifo_din_last),
                .fifo_prog_full(fifo_prog_full)
            );
        end else begin  // N:1
            rtm_c2d_N_1 rtm_c2d_N_1_inst(
                .clk(clk),
                .start_pulse(start_pulse),
                .c_addr(c_addr),
                .init_rtm_len(init_rtm_len),
                .rtm_rd_vld(rtm_rd_vld),
                .rtm_rd_last(rtm_rd_last),
                .rtm_rd_en(rtm_rd_en),
                .rtm_rd_addr(rtm_rd_addr),
                .rtm_dout(rtm_dout),
                .rtm_dout_vld(rtm_dout_vld),
                .rtm_dout_last(rtm_dout_last),
                .fifo_wr_en(fifo_wr_en),
                .fifo_din(fifo_din),
                .fifo_din_last(fifo_din_last),
                .fifo_prog_full(fifo_prog_full)
            );
        end
    endgenerate

    assign dma_wr_write_data_tdata = fifo_dout;
    assign dma_wr_write_data_tvalid = ~fifo_empty;
    assign dma_wr_write_data_tlast = fifo_dout_last;
    assign fifo_rd_en = dma_wr_write_data_tready;
    assign done_pulse = dma_wr_desc_status_valid;

    xpm_fifo_sync #(
        .DOUT_RESET_VALUE("0"),
        .ECC_MODE("no_ecc"),
        .FIFO_MEMORY_TYPE("distributed"),
        .FIFO_READ_LATENCY(0),
        .FIFO_WRITE_DEPTH(32),
        .FULL_RESET_VALUE(0),
        .PROG_EMPTY_THRESH(3),  // prog_empty is not used
        .PROG_FULL_THRESH(16),  // prog_full is set to 16
        .RD_DATA_COUNT_WIDTH(1),  // rd_data_count is not used
        .READ_DATA_WIDTH(`DDR_AXIS_DATA_WIDTH+1),
        .READ_MODE("fwft"),
        .SIM_ASSERT_CHK(0),
        .USE_ADV_FEATURES("0002"),  // prog_full
        .WAKEUP_TIME(0),
        .WRITE_DATA_WIDTH(`DDR_AXIS_DATA_WIDTH+1),
        .WR_DATA_COUNT_WIDTH(1)  // wr_data_count is not used
    ) xpm_fifo_sync_inst (
        .empty(fifo_empty),
        .dout({fifo_dout_last, fifo_dout}),
        .din({fifo_din_last, fifo_din}),
        .prog_full(fifo_prog_full),
        .rd_en(fifo_rd_en),
        .rst(1'b0),
        .sleep(1'b0),
        .wr_clk(clk),
        .wr_en(fifo_wr_en)
    );
endmodule

//
// RTM A bandwidth : DRAM bandwidth = 1 : 1
//
module rtm_c2d_1_1 (
    input clk,
    // Control signals
    input start_pulse,
    input [31:0] c_addr,
    input [$clog2(`RTM_DEPTH)-1:0] init_rtm_len,
    // RTM read ports
    output reg rtm_rd_vld = 0,
    output reg rtm_rd_last = 0,
    output reg [`S-1:0] rtm_rd_en = 0,
    output reg [`S*$clog2(`RTM_DEPTH)-1:0] rtm_rd_addr = 0,
    input [`S*`R*8-1:0] rtm_dout,
    input rtm_dout_vld,
    input rtm_dout_last,
    // FIFO write ports
    output reg fifo_wr_en = 0,
    output reg [`DDR_AXIS_DATA_WIDTH-1:0] fifo_din = 0,
    output reg fifo_din_last = 0,
    input fifo_prog_full
);
    // Parameter Assertions
    initial begin
        if (`S*`R*8 != `DDR_AXIS_DATA_WIDTH) begin
            $error("Hyper parameter mismatch, please make sure that S*R*8==DDR_AXIS_DATA_WIDTH, current values are: DDR_AXIS_DATA_WIDTH = %0d, R = %0d, S = %0d", `DDR_AXIS_DATA_WIDTH, `R, `S);
            $finish;
        end
    end

    reg rd = 0;
    reg [$clog2(`RTM_DEPTH)-1:0] next_addr = 0;
    reg [$clog2(`RTM_DEPTH)-1:0] cnt = 0;
    integer i;

    // rd
    always @(posedge clk)
        if (start_pulse)
            rd <= 1;
        else if (rd && ~fifo_prog_full && cnt==init_rtm_len)
            rd <= 0;

    // cnt
    always @(posedge clk)
        if (start_pulse)
            cnt <= 0;
        else if (rd && ~fifo_prog_full)
            cnt <= cnt+1;

    // next_addr
    always @(posedge clk)
        if (start_pulse)
            next_addr <= c_addr;
        else if (rd && ~fifo_prog_full)
            next_addr <= next_addr+1;

    // rtm_rd_vld, rtm_rd_last, rtm_rd_en, rtm_rd_addr
    always @(posedge clk) begin
        rtm_rd_vld <= (rd && ~fifo_prog_full);
        rtm_rd_last <= (rd && ~fifo_prog_full && cnt==init_rtm_len);
        for (i=0; i<`S; i=i+1)
            rtm_rd_en[i] <= (rd && ~fifo_prog_full);
        for (i=0; i<`S; i=i+1)
            rtm_rd_addr[i*$clog2(`RTM_DEPTH)+:$clog2(`RTM_DEPTH)] <= next_addr;
    end

    // fifo_wr_en, fifo_din, fifo_din_last
    always @(posedge clk) begin
        fifo_wr_en <= rtm_dout_vld;
        fifo_din <= rtm_dout;
        fifo_din_last <= rtm_dout_last;
    end
endmodule

//
// RTM A bandwidth : DRAM bandwidth = N : 1
// N = 2, 4, ...
//
module rtm_c2d_N_1 (
    input clk,
    // Control signals
    input start_pulse,
    input [31:0] c_addr,
    input [$clog2(`RTM_DEPTH)-1:0] init_rtm_len,
    // RTM read ports
    output reg rtm_rd_vld = 0,
    output reg rtm_rd_last = 0,
    output reg [`S-1:0] rtm_rd_en = 0,
    output reg [`S*$clog2(`RTM_DEPTH)-1:0] rtm_rd_addr = 0,
    input [`S*`R*8-1:0] rtm_dout,
    input rtm_dout_vld,
    input rtm_dout_last,
    // FIFO write ports
    output reg fifo_wr_en = 0,
    output reg [`DDR_AXIS_DATA_WIDTH-1:0] fifo_din = 0,
    output reg fifo_din_last = 0,
    input fifo_prog_full
);
    // Parameter Assertions
    initial begin
        if ((`S*`R*8)%`DDR_AXIS_DATA_WIDTH != 0) begin
            $error("Hyper parameter mismatch, please make sure that S*R*8 is a multiple of DDR_AXIS_DATA_WIDTH, current values are: DDR_AXIS_DATA_WIDTH = %0d, R = %0d, S = %0d", `DDR_AXIS_DATA_WIDTH, `R, `S);
            $finish;
        end
    end

    localparam N = `S*`R*8/`DDR_AXIS_DATA_WIDTH;

    //
    // Read Logic
    //
    reg rd = 0;
    reg [$clog2(`RTM_DEPTH)-1:0] next_addr = 0;
    reg [$clog2(`RTM_DEPTH)-1:0] cnt = 0;
    reg [N-1:0] rd_shreg = {{{N-1}{1'b0}}, 1'b1};
    integer i;

    // rd
    always @(posedge clk)
        if (start_pulse)
            rd <= 1;
        else if (rd && ~fifo_prog_full && cnt==init_rtm_len && rd_shreg[N-1])
            rd <= 0;

    // cnt
    always @(posedge clk)
        if (start_pulse)
            cnt <= 0;
        else if (rd && ~fifo_prog_full && rd_shreg[N-1])
            cnt <= cnt+1;

    // rd_shreg
    always @(posedge clk)
        if (rd && ~fifo_prog_full)
            rd_shreg <= {rd_shreg[N-2:0], rd_shreg[N-1]};

    // next_addr
    always @(posedge clk)
        if (start_pulse)
            next_addr <= c_addr;
        else if (rd && ~fifo_prog_full && rd_shreg[N-1])
            next_addr <= next_addr+1;

    // rtm_rd_vld, rtm_rd_last, rtm_rd_en, rtm_rd_addr
    always @(posedge clk) begin
        rtm_rd_vld <= (rd && ~fifo_prog_full);
        rtm_rd_last <= (rd && ~fifo_prog_full && cnt==init_rtm_len && rd_shreg[N-1]);
        for (i=0; i<`S; i=i+1)
            rtm_rd_en[i] <= (rd && ~fifo_prog_full);
        for (i=0; i<`S; i=i+1)
            rtm_rd_addr[i*$clog2(`RTM_DEPTH)+:$clog2(`RTM_DEPTH)] <= next_addr;
    end

    //
    // Write Logic
    //
    reg [N-1:0] wr_shreg = {{{N-1}{1'b0}}, 1'b1};

    // wr_shreg
    always @(posedge clk)
        if (rtm_dout_vld)
            wr_shreg <= {wr_shreg[N-2:0], wr_shreg[N-1]};

    // fifo_wr_en, fifo_din, fifo_din_last
    always @(posedge clk) begin
        fifo_wr_en <= rtm_dout_vld;
        for (i=0; i<N; i=i+1)
            if (wr_shreg[i])
                fifo_din <= rtm_dout[i*`DDR_AXIS_DATA_WIDTH+:`DDR_AXIS_DATA_WIDTH];
        fifo_din_last <= rtm_dout_last;
    end
endmodule
