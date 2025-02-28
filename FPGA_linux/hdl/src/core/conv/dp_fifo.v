`timescale 1ns / 1ps
`include "../../incl.vh"

//
// Dot-product FIFO (async fifo, BRAM)
// Read Latency is 3
//
module Conv_dp_fifo(
    // Write Ports
    input sa_clk,
    input wr_en,
    input [`P*2*32-1:0] din,
    output prog_full,
    // Read Ports
    input main_clk,
    input rd_en,
    output [`P*2*32-1:0] dout,
    output empty,
    output almost_empty
);
    localparam DATA_WIDTH = `P*2*32, 
        DEPTH = 512, 
        PROG_FULL = 256;
    localparam RAM_PRT_WIDTH = $clog2(DEPTH);

    (* ram_style="block" *) reg [DATA_WIDTH-1:0] mem [DEPTH-1:0];
    reg [DATA_WIDTH-1:0] mem_reg = 0, dout_reg1 = 0, dout_reg2 = 0;
    assign dout = dout_reg2;

    // Write
    reg [RAM_PRT_WIDTH-1:0] wr_addr = 0;
    always @(posedge sa_clk) begin
        if (wr_en)
            mem[wr_addr] <= din;
        wr_addr <= wr_addr+wr_en;
    end

    // Read
    reg [RAM_PRT_WIDTH-1:0] rd_addr = 0;
    always @(posedge main_clk) begin
        if (rd_en)
            mem_reg <= mem[rd_addr];
        rd_addr <= rd_addr+rd_en;
    end

    always @(posedge main_clk)
        {dout_reg2, dout_reg1} <= {dout_reg1, mem_reg};
    
    // 1bit width fifo
    xpm_fifo_async #(
        .CDC_SYNC_STAGES(3),
        .DOUT_RESET_VALUE("0"),
        .ECC_MODE("no_ecc"),
        .FIFO_MEMORY_TYPE("distributed"),
        .FIFO_READ_LATENCY(3),
        .FIFO_WRITE_DEPTH(DEPTH),
        .FULL_RESET_VALUE(0),
        .PROG_EMPTY_THRESH(3),
        .PROG_FULL_THRESH(PROG_FULL),
        .RD_DATA_COUNT_WIDTH(1),  // not used
        .READ_DATA_WIDTH(1),
        .READ_MODE("std"),
        .RELATED_CLOCKS(0),
        .SIM_ASSERT_CHK(0),
        .USE_ADV_FEATURES("0802"),  // almost_empty, prog_full
        .WAKEUP_TIME(0),
        .WRITE_DATA_WIDTH(1),
        .WR_DATA_COUNT_WIDTH(1)  // not used
   ) xpm_fifo_async_inst (
        .almost_empty(almost_empty),
        .dout(),
        .empty(empty),
        .full(),
        .prog_full(prog_full),
        .din(1'b1),
        .rd_clk(main_clk),  
        .rd_en(rd_en),
        .rst(1'b0),
        .wr_clk(sa_clk),
        .wr_en(wr_en)
    );
endmodule
