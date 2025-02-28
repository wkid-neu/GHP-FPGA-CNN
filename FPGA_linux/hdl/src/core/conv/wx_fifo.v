`timescale 1ns / 1ps
`include "../../incl.vh"

//
// Weight-Activation FIFO (async fifo, LUTRAM)
//
module Conv_wx_fifo(
    // Write Ports
    input main_clk,
    input wr_en,
    input [`SA_TAG_DW+`M*4*8+`P*2*8-1:0] din,
    output prog_full,
    // Read Ports
    input sa_clk,
    input rd_en,
    output empty,
    output almost_empty,
    output [`SA_TAG_DW+`M*4*8+`P*2*8-1:0] dout
);
    localparam DEPTH = 64, 
        PROG_FULL = 32, 
        DATA_WIDTH = `SA_TAG_DW+`M*4*8+`P*2*8;
    localparam RAM_PRT_WIDTH = $clog2(DEPTH);

    (* ram_style="distributed" *) reg [DATA_WIDTH-1:0] mem [DEPTH-1:0];
    reg [DATA_WIDTH-1:0] mem_reg = 0, dout_reg = 0;
    assign dout = dout_reg;

    // Write
    reg [RAM_PRT_WIDTH-1:0] wr_addr = 0;
    always @(posedge main_clk) begin
        if (wr_en)
            mem[wr_addr] <= din;
        wr_addr <= wr_addr+wr_en;
    end

    // Read
    reg [RAM_PRT_WIDTH-1:0] rd_addr = 0;
    always @(posedge sa_clk) begin
        if (rd_en)
            mem_reg <= mem[rd_addr];
        rd_addr <= rd_addr+rd_en;
    end

    always @(posedge sa_clk)
        dout_reg <= mem_reg;

    // 1bit width fifo
    xpm_fifo_async #(
        .CDC_SYNC_STAGES(3),
        .DOUT_RESET_VALUE("0"),
        .ECC_MODE("no_ecc"),
        .FIFO_MEMORY_TYPE("distributed"),
        .FIFO_READ_LATENCY(2),
        .FIFO_WRITE_DEPTH(DEPTH),
        .FULL_RESET_VALUE(0),
        .PROG_EMPTY_THRESH(3),
        .PROG_FULL_THRESH(PROG_FULL),
        .RD_DATA_COUNT_WIDTH(1),  // not used
        .READ_DATA_WIDTH(1),
        .READ_MODE("std"),
        .RELATED_CLOCKS(0),
        .SIM_ASSERT_CHK(0),
        .USE_ADV_FEATURES("0802"),  // prog_full
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
        .rd_clk(sa_clk),  
        .rd_en(rd_en),
        .rst(1'b0),
        .wr_clk(main_clk),
        .wr_en(wr_en)
    );
endmodule
