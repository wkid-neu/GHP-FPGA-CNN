`timescale 1ns / 1ps
`include "../../incl.vh"

//
// Runtime tensor memory
//
module rtm (
    input clk,
    // host control signals (hc_*)
    input hc_d2c_start_pulse,  // dram to chip
    input [31:0] hc_d2c_d_addr,
    input [31:0] hc_d2c_c_addr,
    input [31:0] hc_d2c_n_bytes,
    output reg hc_d2c_done_pulse = 0,
    input hc_c2d_start_pulse,  // chip to dram
    input [31:0] hc_c2d_d_addr,
    input [31:0] hc_c2d_c_addr,
    input [31:0] hc_c2d_n_bytes, 
    output reg hc_c2d_done_pulse = 0,
    // instruction control signals (ic_*)
    input ic_d2c_start_pulse,  // dram to chip
    input [31:0] ic_d2c_d_addr,
    input [31:0] ic_d2c_c_addr,
    input [31:0] ic_d2c_n_bytes,
    output reg ic_d2c_done_pulse = 0,
    input ic_c2d_start_pulse,  // chip to dram
    input [31:0] ic_c2d_d_addr,
    input [31:0] ic_c2d_c_addr,
    input [31:0] ic_c2d_n_bytes, 
    output reg ic_c2d_done_pulse = 0,
    // DMA write controller
    output [`DDR_AXI_ADDR_WIDTH-1:0] dma_wr_desc_addr,
    output [`DDR_LEN_WIDTH-1:0] dma_wr_desc_len,
    output dma_wr_desc_valid,
    input dma_wr_desc_status_valid,
    output [`DDR_AXIS_DATA_WIDTH-1:0] dma_wr_write_data_tdata,
    output dma_wr_write_data_tvalid,
    input dma_wr_write_data_tready,
    output dma_wr_write_data_tlast,
    // DMA read controller
    output [`DDR_AXI_ADDR_WIDTH-1:0] dma_rd_desc_addr,
    output [`DDR_LEN_WIDTH-1:0] dma_rd_desc_len,
    output dma_rd_desc_valid,
    input [`DDR_AXIS_DATA_WIDTH-1:0] dma_rd_read_data_tdata,
    input dma_rd_read_data_tvalid,
    input dma_rd_read_data_tlast,
    // Write signals from Conv
    input rtm_wr_vld_conv,
    input [`S-1:0] rtm_wr_en_conv,
    input [`S*$clog2(`RTM_DEPTH)-1:0] rtm_wr_addr_conv,
    input [`S*`R*8-1:0] rtm_din_conv,
    // Write signals from Pool
    input rtm_wr_vld_pool,
    input [`S-1:0] rtm_wr_en_pool,
    input [`S*$clog2(`RTM_DEPTH)-1:0] rtm_wr_addr_pool,
    input [`S*`R*8-1:0] rtm_din_pool,
    // Write signals from Fc
    input rtm_wr_vld_fc,
    input [`S-1:0] rtm_wr_en_fc,
    input [`S*$clog2(`RTM_DEPTH)-1:0] rtm_wr_addr_fc,
    input [`S*`R*8-1:0] rtm_din_fc,
    // Write signals from Add
    input rtm_wr_vld_add,
    input [`S-1:0] rtm_wr_en_add,
    input [`S*$clog2(`RTM_DEPTH)-1:0] rtm_wr_addr_add,
    input [`S*`R*8-1:0] rtm_din_add,
    // Write signals from Remap
    input rtm_wr_vld_remap,
    input [`S-1:0] rtm_wr_en_remap,
    input [`S*$clog2(`RTM_DEPTH)-1:0] rtm_wr_addr_remap,
    input [`S*`R*8-1:0] rtm_din_remap,
    // Read signals from X-bus
    input rtm_rd_vld_xbus,
    input [`S-1:0] rtm_rd_en_xbus,
    input [`XPHM_DATA_WIDTH+$clog2(`R/`Q)+1:0] rtm_rd_att_xbus,
    input [`S*$clog2(`RTM_DEPTH)-1:0] rtm_rd_addr_xbus,
    output [`S*`R*8-1:0] rtm_dout_xbus,
    output [`XPHM_DATA_WIDTH+$clog2(`R/`Q)+1:0] rtm_dout_att_xbus,
    output rtm_dout_vld_xbus,
    // Read signals from Fc
    input rtm_rd_vld_fc,
    input [`S-1:0] rtm_rd_en_fc,
    input rtm_rd_vec_begin_fc,
    input rtm_rd_vec_end_fc,
    input rtm_rd_last_fc,
    input [`S*$clog2(`RTM_DEPTH)-1:0] rtm_rd_addr_fc,
    output [`S*`R*8-1:0] rtm_dout_fc,
    output rtm_dout_vld_fc,
    output rtm_dout_vec_begin_fc,
    output rtm_dout_vec_end_fc,
    output rtm_dout_last_fc,
    // Read signals from Add
    input rtm_rd_vld_add,
    input rtm_rd_last_add,
    input [`S-1:0] rtm_rd_en_add,
    input [`S*$clog2(`RTM_DEPTH)-1:0] rtm_rd_addr_add,
    output [`S*`R*8-1:0] rtm_dout_add,
    output rtm_dout_vld_add,
    output rtm_dout_last_add,
    // Read signals from Remap
    input rtm_rd_vld_remap,
    input rtm_rd_last_remap,
    input [`S-1:0] rtm_rd_en_remap,
    input [`S*$clog2(`RTM_DEPTH)-1:0] rtm_rd_addr_remap,
    output [`S*`R*8-1:0] rtm_dout_remap,
    output rtm_dout_vld_remap,
    output rtm_dout_last_remap
);
    reg c2d_source = 0;  // host (0) or instruction (1)
    reg c2d_start_pulse = 0;
    reg [31:0] c2d_d_addr = 0;
    reg [31:0] c2d_c_addr = 0;
    reg [31:0] c2d_n_bytes = 0;
    wire c2d_done_pulse;
    wire rtm_rd_vld_dram;
    wire rtm_rd_last_dram;
    wire [`S-1:0] rtm_rd_en_dram;
    wire [`S*$clog2(`RTM_DEPTH)-1:0] rtm_rd_addr_dram;
    wire [`S*`R*8-1:0] rtm_dout_dram;
    wire rtm_dout_vld_dram;
    wire rtm_dout_last_dram;

    reg d2c_source = 0;  // host (0) or instruction (1)
    reg d2c_start_pulse = 0;
    reg [31:0] d2c_d_addr = 0;
    reg [31:0] d2c_c_addr = 0;
    reg [31:0] d2c_n_bytes = 0;
    wire d2c_done_pulse;
    wire rtm_wr_vld_dram;
    wire [`S-1:0] rtm_wr_en_dram;
    wire [`S*$clog2(`RTM_DEPTH)-1:0] rtm_wr_addr_dram;
    wire [`S*`R*8-1:0] rtm_din_dram;

    wire [`S-1:0] wr_en;
    wire [`S*$clog2(`RTM_DEPTH)-1:0] wr_addr;
    wire [`S*`R*8-1:0] din;
    wire [`S-1:0] rd_en;
    wire [`S*$clog2(`RTM_DEPTH)-1:0] rd_addr;
    wire [`S*`R*8-1:0] dout;

    //
    // Chip to DRAM
    //    
    always @(posedge clk) 
        if (hc_c2d_start_pulse)
            c2d_source <= 0;
        else if (ic_c2d_start_pulse)
            c2d_source <= 1;

    always @(posedge clk) begin
        c2d_start_pulse <= (hc_c2d_start_pulse || ic_c2d_start_pulse);
        if (hc_c2d_start_pulse) begin
            c2d_d_addr <= hc_c2d_d_addr;
            c2d_c_addr <= hc_c2d_c_addr;
            c2d_n_bytes <= hc_c2d_n_bytes;
        end else if (ic_c2d_start_pulse) begin
            c2d_d_addr <= ic_c2d_d_addr;
            c2d_c_addr <= ic_c2d_c_addr;
            c2d_n_bytes <= ic_c2d_n_bytes;
        end
    end

    always @(posedge clk)
        hc_c2d_done_pulse <= (~c2d_source & c2d_done_pulse);

    always @(posedge clk)
        ic_c2d_done_pulse <= (c2d_source & c2d_done_pulse);
    
    //
    // DRAM to Chip
    //
    always @(posedge clk) 
        if (hc_d2c_start_pulse)
            d2c_source <= 0;
        else if (ic_d2c_start_pulse)
            d2c_source <= 1;
    
    always @(posedge clk) begin
        d2c_start_pulse <= (hc_d2c_start_pulse || ic_d2c_start_pulse);
        if (hc_d2c_start_pulse) begin
            d2c_d_addr <= hc_d2c_d_addr;
            d2c_c_addr <= hc_d2c_c_addr;
            d2c_n_bytes <= hc_d2c_n_bytes;
        end else if (ic_d2c_start_pulse) begin
            d2c_d_addr <= ic_d2c_d_addr;
            d2c_c_addr <= ic_d2c_c_addr;
            d2c_n_bytes <= ic_d2c_n_bytes;
        end
    end

    always @(posedge clk)
        hc_d2c_done_pulse <= (~d2c_source & d2c_done_pulse);

    always @(posedge clk)
        ic_d2c_done_pulse <= (d2c_source & d2c_done_pulse);

    rtm_c2d rtm_c2d_inst(
        .clk(clk),
        .start_pulse(c2d_start_pulse),
        .d_addr(c2d_d_addr),
        .c_addr(c2d_c_addr),
        .n_bytes(c2d_n_bytes),
        .done_pulse(c2d_done_pulse),
        .dma_wr_desc_addr(dma_wr_desc_addr),
        .dma_wr_desc_len(dma_wr_desc_len),
        .dma_wr_desc_valid(dma_wr_desc_valid),
        .dma_wr_desc_status_valid(dma_wr_desc_status_valid),
        .dma_wr_write_data_tdata(dma_wr_write_data_tdata),
        .dma_wr_write_data_tvalid(dma_wr_write_data_tvalid),
        .dma_wr_write_data_tready(dma_wr_write_data_tready),
        .dma_wr_write_data_tlast(dma_wr_write_data_tlast),
        .rtm_rd_vld(rtm_rd_vld_dram),
        .rtm_rd_last(rtm_rd_last_dram),
        .rtm_rd_en(rtm_rd_en_dram),
        .rtm_rd_addr(rtm_rd_addr_dram),
        .rtm_dout(rtm_dout_dram),
        .rtm_dout_vld(rtm_dout_vld_dram),
        .rtm_dout_last(rtm_dout_last_dram)
    );

    rtm_d2c rtm_d2c_inst(
        .clk(clk),
        .start_pulse(d2c_start_pulse),
        .d_addr(d2c_d_addr),
        .c_addr(d2c_c_addr),
        .n_bytes(d2c_n_bytes),
        .done_pulse(d2c_done_pulse),
        .dma_rd_desc_addr(dma_rd_desc_addr),
        .dma_rd_desc_len(dma_rd_desc_len),
        .dma_rd_desc_valid(dma_rd_desc_valid),
        .dma_rd_read_data_tdata(dma_rd_read_data_tdata),
        .dma_rd_read_data_tvalid(dma_rd_read_data_tvalid),
        .dma_rd_read_data_tlast(dma_rd_read_data_tlast),
        .rtm_wr_vld(rtm_wr_vld_dram),
        .rtm_wr_en(rtm_wr_en_dram),
        .rtm_wr_addr(rtm_wr_addr_dram),
        .rtm_din(rtm_din_dram)
    );

    rtm_wr_ctrl rtm_wr_ctrl_inst(
        .clk(clk),
        .wr_vld_dram(rtm_wr_vld_dram),
        .wr_en_dram(rtm_wr_en_dram),
        .wr_addr_dram(rtm_wr_addr_dram),
        .din_dram(rtm_din_dram),
        .wr_vld_conv(rtm_wr_vld_conv),
        .wr_en_conv(rtm_wr_en_conv),
        .wr_addr_conv(rtm_wr_addr_conv),
        .din_conv(rtm_din_conv),
        .wr_vld_pool(rtm_wr_vld_pool),
        .wr_en_pool(rtm_wr_en_pool),
        .wr_addr_pool(rtm_wr_addr_pool),
        .din_pool(rtm_din_pool),
        .wr_vld_fc(rtm_wr_vld_fc),
        .wr_en_fc(rtm_wr_en_fc),
        .wr_addr_fc(rtm_wr_addr_fc),
        .din_fc(rtm_din_fc),
        .wr_vld_add(rtm_wr_vld_add),
        .wr_en_add(rtm_wr_en_add),
        .wr_addr_add(rtm_wr_addr_add),
        .din_add(rtm_din_add),
        .wr_vld_remap(rtm_wr_vld_remap),
        .wr_en_remap(rtm_wr_en_remap),
        .wr_addr_remap(rtm_wr_addr_remap),
        .din_remap(rtm_din_remap),
        .wr_en(wr_en),
        .wr_addr(wr_addr),
        .din(din)
    );
    
    rtm_rd_ctrl rtm_rd_ctrl_inst(
        .clk(clk),
        .rd_vld_dram(rtm_rd_vld_dram),
        .rd_last_dram(rtm_rd_last_dram),
        .rd_en_dram(rtm_rd_en_dram),
        .rd_addr_dram(rtm_rd_addr_dram),
        .dout_dram(rtm_dout_dram),
        .dout_vld_dram(rtm_dout_vld_dram),
        .dout_last_dram(rtm_dout_last_dram),
        .rd_vld_xbus(rtm_rd_vld_xbus),
        .rd_en_xbus(rtm_rd_en_xbus),
        .rd_att_xbus(rtm_rd_att_xbus),
        .rd_addr_xbus(rtm_rd_addr_xbus),
        .dout_xbus(rtm_dout_xbus),
        .dout_att_xbus(rtm_dout_att_xbus),
        .dout_vld_xbus(rtm_dout_vld_xbus),
        .rd_vld_fc(rtm_rd_vld_fc),
        .rd_en_fc(rtm_rd_en_fc),
        .rd_vec_begin_fc(rtm_rd_vec_begin_fc),
        .rd_vec_end_fc(rtm_rd_vec_end_fc),
        .rd_last_fc(rtm_rd_last_fc),
        .rd_addr_fc(rtm_rd_addr_fc),
        .dout_fc(rtm_dout_fc),
        .dout_vld_fc(rtm_dout_vld_fc),
        .dout_vec_begin_fc(rtm_dout_vec_begin_fc),
        .dout_vec_end_fc(rtm_dout_vec_end_fc),
        .dout_last_fc(rtm_dout_last_fc),
        .rd_vld_add(rtm_rd_vld_add),
        .rd_last_add(rtm_rd_last_add),
        .rd_en_add(rtm_rd_en_add),
        .rd_addr_add(rtm_rd_addr_add),
        .dout_add(rtm_dout_add),
        .dout_vld_add(rtm_dout_vld_add),
        .dout_last_add(rtm_dout_last_add),
        .rd_vld_remap(rtm_rd_vld_remap),
        .rd_last_remap(rtm_rd_last_remap),
        .rd_en_remap(rtm_rd_en_remap),
        .rd_addr_remap(rtm_rd_addr_remap),
        .dout_remap(rtm_dout_remap),
        .dout_vld_remap(rtm_dout_vld_remap),
        .dout_last_remap(rtm_dout_last_remap),
        .rd_en(rd_en),
        .rd_addr(rd_addr),
        .dout(dout)
    );

    rtm_mem rtm_mem_inst(
        .clk(clk),
        .rd_en(rd_en),
        .rd_addr(rd_addr),
        .dout(dout),
        .wr_en(wr_en),
        .wr_addr(wr_addr),
        .din(din)
    );
endmodule
