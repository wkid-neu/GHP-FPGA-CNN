`timescale 1ns / 1ps
`include "../incl.vh"

/*
 * AXI4 DMA
 */
module axi_dma (
    input  wire                       clk,
    input  wire                       rst,

    /*
     * AXI read descriptor input
     */
    input  wire [`DDR_AXI_ADDR_WIDTH-1:0]  s_axis_read_desc_addr,
    input  wire [`DDR_LEN_WIDTH-1:0]       s_axis_read_desc_len,
    input  wire [`DDR_TAG_WIDTH-1:0]       s_axis_read_desc_tag,
    input  wire [`DDR_AXIS_ID_WIDTH-1:0]   s_axis_read_desc_id,
    input  wire [`DDR_AXIS_DEST_WIDTH-1:0] s_axis_read_desc_dest,
    input  wire [`DDR_AXIS_USER_WIDTH-1:0] s_axis_read_desc_user,
    input  wire                       s_axis_read_desc_valid,
    output wire                       s_axis_read_desc_ready,

    /*
     * AXI read descriptor status output
     */
    output wire [`DDR_TAG_WIDTH-1:0]       m_axis_read_desc_status_tag,
    output wire [3:0]                 m_axis_read_desc_status_error,
    output wire                       m_axis_read_desc_status_valid,

    /*
     * AXI stream read data output
     */
    output wire [`DDR_AXIS_DATA_WIDTH-1:0] m_axis_read_data_tdata,
    output wire [`DDR_AXIS_KEEP_WIDTH-1:0] m_axis_read_data_tkeep,
    output wire                       m_axis_read_data_tvalid,
    input  wire                       m_axis_read_data_tready,
    output wire                       m_axis_read_data_tlast,
    output wire [`DDR_AXIS_ID_WIDTH-1:0]   m_axis_read_data_tid,
    output wire [`DDR_AXIS_DEST_WIDTH-1:0] m_axis_read_data_tdest,
    output wire [`DDR_AXIS_USER_WIDTH-1:0] m_axis_read_data_tuser,

    /*
     * AXI write descriptor input
     */
    input  wire [`DDR_AXI_ADDR_WIDTH-1:0]  s_axis_write_desc_addr,
    input  wire [`DDR_LEN_WIDTH-1:0]       s_axis_write_desc_len,
    input  wire [`DDR_TAG_WIDTH-1:0]       s_axis_write_desc_tag,
    input  wire                       s_axis_write_desc_valid,
    output wire                       s_axis_write_desc_ready,

    /*
     * AXI write descriptor status output
     */
    output wire [`DDR_LEN_WIDTH-1:0]       m_axis_write_desc_status_len,
    output wire [`DDR_TAG_WIDTH-1:0]       m_axis_write_desc_status_tag,
    output wire [`DDR_AXIS_ID_WIDTH-1:0]   m_axis_write_desc_status_id,
    output wire [`DDR_AXIS_DEST_WIDTH-1:0] m_axis_write_desc_status_dest,
    output wire [`DDR_AXIS_USER_WIDTH-1:0] m_axis_write_desc_status_user,
    output wire [3:0]                 m_axis_write_desc_status_error,
    output wire                       m_axis_write_desc_status_valid,

    /*
     * AXI stream write data input
     */
    input  wire [`DDR_AXIS_DATA_WIDTH-1:0] s_axis_write_data_tdata,
    input  wire [`DDR_AXIS_KEEP_WIDTH-1:0] s_axis_write_data_tkeep,
    input  wire                       s_axis_write_data_tvalid,
    output wire                       s_axis_write_data_tready,
    input  wire                       s_axis_write_data_tlast,
    input  wire [`DDR_AXIS_ID_WIDTH-1:0]   s_axis_write_data_tid,
    input  wire [`DDR_AXIS_DEST_WIDTH-1:0] s_axis_write_data_tdest,
    input  wire [`DDR_AXIS_USER_WIDTH-1:0] s_axis_write_data_tuser,

    /*
     * AXI master interface
     */
    output wire [`DDR_AXI_ID_WIDTH-1:0]    m_axi_awid,
    output wire [`DDR_AXI_ADDR_WIDTH-1:0]  m_axi_awaddr,
    output wire [7:0]                 m_axi_awlen,
    output wire [2:0]                 m_axi_awsize,
    output wire [1:0]                 m_axi_awburst,
    output wire                       m_axi_awlock,
    output wire [3:0]                 m_axi_awcache,
    output wire [2:0]                 m_axi_awprot,
    output wire                       m_axi_awvalid,
    input  wire                       m_axi_awready,
    output wire [`DMA_AXI_DATA_WIDTH-1:0]  m_axi_wdata,
    output wire [`DDR_AXI_STRB_WIDTH-1:0]  m_axi_wstrb,
    output wire                       m_axi_wlast,
    output wire                       m_axi_wvalid,
    input  wire                       m_axi_wready,
    input  wire [`DDR_AXI_ID_WIDTH-1:0]    m_axi_bid,
    input  wire [1:0]                 m_axi_bresp,
    input  wire                       m_axi_bvalid,
    output wire                       m_axi_bready,
    output wire [`DDR_AXI_ID_WIDTH-1:0]    m_axi_arid,
    output wire [`DDR_AXI_ADDR_WIDTH-1:0]  m_axi_araddr,
    output wire [7:0]                 m_axi_arlen,
    output wire [2:0]                 m_axi_arsize,
    output wire [1:0]                 m_axi_arburst,
    output wire                       m_axi_arlock,
    output wire [3:0]                 m_axi_arcache,
    output wire [2:0]                 m_axi_arprot,
    output wire                       m_axi_arvalid,
    input  wire                       m_axi_arready,
    input  wire [`DDR_AXI_ID_WIDTH-1:0]    m_axi_rid,
    input  wire [`DMA_AXI_DATA_WIDTH-1:0]  m_axi_rdata,
    input  wire [1:0]                 m_axi_rresp,
    input  wire                       m_axi_rlast,
    input  wire                       m_axi_rvalid,
    output wire                       m_axi_rready,

    /*
     * Configuration
     */
    input  wire                       read_enable,
    input  wire                       write_enable,
    input  wire                       write_abort
);

axi_dma_rd #(
    .AXI_DATA_WIDTH(`DMA_AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(`DDR_AXI_ADDR_WIDTH),
    .AXI_STRB_WIDTH(`DDR_AXI_STRB_WIDTH),
    .AXI_ID_WIDTH(`DDR_AXI_ID_WIDTH),
    .AXI_MAX_BURST_LEN(`DDR_AXI_MAX_BURST_LEN),
    .AXIS_DATA_WIDTH(`DDR_AXIS_DATA_WIDTH),
    .AXIS_KEEP_ENABLE(`DDR_AXIS_KEEP_ENABLE),
    .AXIS_KEEP_WIDTH(`DDR_AXIS_KEEP_WIDTH),
    .AXIS_LAST_ENABLE(`DDR_AXIS_LAST_ENABLE),
    .AXIS_ID_ENABLE(`DDR_AXIS_ID_ENABLE),
    .AXIS_ID_WIDTH(`DDR_AXIS_ID_WIDTH),
    .AXIS_DEST_ENABLE(`DDR_AXIS_DEST_ENABLE),
    .AXIS_DEST_WIDTH(`DDR_AXIS_DEST_WIDTH),
    .AXIS_USER_ENABLE(`DDR_AXIS_USER_ENABLE),
    .AXIS_USER_WIDTH(`DDR_AXIS_USER_WIDTH),
    .LEN_WIDTH(`DDR_LEN_WIDTH),
    .TAG_WIDTH(`DDR_TAG_WIDTH),
    .ENABLE_SG(0),
    .ENABLE_UNALIGNED(1)
)
axi_dma_rd_inst (
    .clk(clk),
    .rst(rst),
    .s_axis_read_desc_addr(s_axis_read_desc_addr),
    .s_axis_read_desc_len(s_axis_read_desc_len),
    .s_axis_read_desc_tag(s_axis_read_desc_tag),
    .s_axis_read_desc_id(s_axis_read_desc_id),
    .s_axis_read_desc_dest(s_axis_read_desc_dest),
    .s_axis_read_desc_user(s_axis_read_desc_user),
    .s_axis_read_desc_valid(s_axis_read_desc_valid),
    .s_axis_read_desc_ready(s_axis_read_desc_ready),
    .m_axis_read_desc_status_tag(m_axis_read_desc_status_tag),
    .m_axis_read_desc_status_error(m_axis_read_desc_status_error),
    .m_axis_read_desc_status_valid(m_axis_read_desc_status_valid),
    .m_axis_read_data_tdata(m_axis_read_data_tdata),
    .m_axis_read_data_tkeep(m_axis_read_data_tkeep),
    .m_axis_read_data_tvalid(m_axis_read_data_tvalid),
    .m_axis_read_data_tready(m_axis_read_data_tready),
    .m_axis_read_data_tlast(m_axis_read_data_tlast),
    .m_axis_read_data_tid(m_axis_read_data_tid),
    .m_axis_read_data_tdest(m_axis_read_data_tdest),
    .m_axis_read_data_tuser(m_axis_read_data_tuser),
    .m_axi_arid(m_axi_arid),
    .m_axi_araddr(m_axi_araddr),
    .m_axi_arlen(m_axi_arlen),
    .m_axi_arsize(m_axi_arsize),
    .m_axi_arburst(m_axi_arburst),
    .m_axi_arlock(m_axi_arlock),
    .m_axi_arcache(m_axi_arcache),
    .m_axi_arprot(m_axi_arprot),
    .m_axi_arvalid(m_axi_arvalid),
    .m_axi_arready(m_axi_arready),
    .m_axi_rid(m_axi_rid),
    .m_axi_rdata(m_axi_rdata),
    .m_axi_rresp(m_axi_rresp),
    .m_axi_rlast(m_axi_rlast),
    .m_axi_rvalid(m_axi_rvalid),
    .m_axi_rready(m_axi_rready),
    .enable(read_enable)
);

axi_dma_wr #(
    .AXI_DATA_WIDTH(`DMA_AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH(`DDR_AXI_ADDR_WIDTH),
    .AXI_STRB_WIDTH(`DDR_AXI_STRB_WIDTH),
    .AXI_ID_WIDTH(`DDR_AXI_ID_WIDTH),
    .AXI_MAX_BURST_LEN(`DDR_AXI_MAX_BURST_LEN),
    .AXIS_DATA_WIDTH(`DDR_AXIS_DATA_WIDTH),
    .AXIS_KEEP_ENABLE(`DDR_AXIS_KEEP_ENABLE),
    .AXIS_KEEP_WIDTH(`DDR_AXIS_KEEP_WIDTH),
    .AXIS_LAST_ENABLE(`DDR_AXIS_LAST_ENABLE),
    .AXIS_ID_ENABLE(`DDR_AXIS_ID_ENABLE),
    .AXIS_ID_WIDTH(`DDR_AXIS_ID_WIDTH),
    .AXIS_DEST_ENABLE(`DDR_AXIS_DEST_ENABLE),
    .AXIS_DEST_WIDTH(`DDR_AXIS_DEST_WIDTH),
    .AXIS_USER_ENABLE(`DDR_AXIS_USER_ENABLE),
    .AXIS_USER_WIDTH(`DDR_AXIS_USER_WIDTH),
    .LEN_WIDTH(`DDR_LEN_WIDTH),
    .TAG_WIDTH(`DDR_TAG_WIDTH),
    .ENABLE_SG(0),
    .ENABLE_UNALIGNED(1)
)
axi_dma_wr_inst (
    .clk(clk),
    .rst(rst),
    .s_axis_write_desc_addr(s_axis_write_desc_addr),
    .s_axis_write_desc_len(s_axis_write_desc_len),
    .s_axis_write_desc_tag(s_axis_write_desc_tag),
    .s_axis_write_desc_valid(s_axis_write_desc_valid),
    .s_axis_write_desc_ready(s_axis_write_desc_ready),
    .m_axis_write_desc_status_len(m_axis_write_desc_status_len),
    .m_axis_write_desc_status_tag(m_axis_write_desc_status_tag),
    .m_axis_write_desc_status_id(m_axis_write_desc_status_id),
    .m_axis_write_desc_status_dest(m_axis_write_desc_status_dest),
    .m_axis_write_desc_status_user(m_axis_write_desc_status_user),
    .m_axis_write_desc_status_error(m_axis_write_desc_status_error),
    .m_axis_write_desc_status_valid(m_axis_write_desc_status_valid),
    .s_axis_write_data_tdata(s_axis_write_data_tdata),
    .s_axis_write_data_tkeep(s_axis_write_data_tkeep),
    .s_axis_write_data_tvalid(s_axis_write_data_tvalid),
    .s_axis_write_data_tready(s_axis_write_data_tready),
    .s_axis_write_data_tlast(s_axis_write_data_tlast),
    .s_axis_write_data_tid(s_axis_write_data_tid),
    .s_axis_write_data_tdest(s_axis_write_data_tdest),
    .s_axis_write_data_tuser(s_axis_write_data_tuser),
    .m_axi_awid(m_axi_awid),
    .m_axi_awaddr(m_axi_awaddr),
    .m_axi_awlen(m_axi_awlen),
    .m_axi_awsize(m_axi_awsize),
    .m_axi_awburst(m_axi_awburst),
    .m_axi_awlock(m_axi_awlock),
    .m_axi_awcache(m_axi_awcache),
    .m_axi_awprot(m_axi_awprot),
    .m_axi_awvalid(m_axi_awvalid),
    .m_axi_awready(m_axi_awready),
    .m_axi_wdata(m_axi_wdata),
    .m_axi_wstrb(m_axi_wstrb),
    .m_axi_wlast(m_axi_wlast),
    .m_axi_wvalid(m_axi_wvalid),
    .m_axi_wready(m_axi_wready),
    .m_axi_bid(m_axi_bid),
    .m_axi_bresp(m_axi_bresp),
    .m_axi_bvalid(m_axi_bvalid),
    .m_axi_bready(m_axi_bready),
    .enable(write_enable),
    .abort(write_abort)
);

endmodule
