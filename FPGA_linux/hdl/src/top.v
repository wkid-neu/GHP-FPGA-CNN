`timescale 1ns / 1ps
`include "incl.vh"

//
// Top module of the accelerator
//
module top (
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 main_clk CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF sr_cr_S_AXI:dma_m_axi, ASSOCIATED_RESET main_rst, FREQ_HZ 250000000" *)
    input main_clk,
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 sa_clk CLK" *)
    (* X_INTERFACE_PARAMETER = "FREQ_HZ 398437500" *)
    input sa_clk,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 main_rst RST" *)
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_HIGH" *)
    input main_rst,
    // sr_cr AXI4LITE interface
    input [`SR_CR_AXI_ADDR_WIDTH-1 : 0] sr_cr_S_AXI_AWADDR,
    input [2 : 0] sr_cr_S_AXI_AWPROT,
    input sr_cr_S_AXI_AWVALID,
    output sr_cr_S_AXI_AWREADY,
    input [`SR_CR_AXI_DATA_WIDTH-1 : 0] sr_cr_S_AXI_WDATA,   
    input [(`SR_CR_AXI_DATA_WIDTH/8)-1 : 0] sr_cr_S_AXI_WSTRB,
    input sr_cr_S_AXI_WVALID,
    output sr_cr_S_AXI_WREADY,
    output [1 : 0] sr_cr_S_AXI_BRESP,
    output sr_cr_S_AXI_BVALID,
    input sr_cr_S_AXI_BREADY,
    input [`SR_CR_AXI_ADDR_WIDTH-1 : 0] sr_cr_S_AXI_ARADDR,
    input [2 : 0] sr_cr_S_AXI_ARPROT,
    input sr_cr_S_AXI_ARVALID,
    output sr_cr_S_AXI_ARREADY,
    output [`SR_CR_AXI_DATA_WIDTH-1 : 0] sr_cr_S_AXI_RDATA,
    output [1 : 0] sr_cr_S_AXI_RRESP,
    output sr_cr_S_AXI_RVALID,
    input sr_cr_S_AXI_RREADY,
    // DMA AXI master interface
    output [`DDR_AXI_ID_WIDTH-1:0] dma_m_axi_awid,
    output [`DDR_AXI_ADDR_WIDTH-1:0] dma_m_axi_awaddr,
    output [7:0] dma_m_axi_awlen,
    output [2:0] dma_m_axi_awsize,
    output [1:0] dma_m_axi_awburst,
    output dma_m_axi_awlock,
    output [3:0] dma_m_axi_awcache,
    output [2:0] dma_m_axi_awprot,
    output dma_m_axi_awvalid,
    input dma_m_axi_awready,
    output [`DMA_AXI_DATA_WIDTH-1:0] dma_m_axi_wdata,
    output [`DDR_AXI_STRB_WIDTH-1:0] dma_m_axi_wstrb,
    output dma_m_axi_wlast,
    output dma_m_axi_wvalid,
    input dma_m_axi_wready,
    input [`DDR_AXI_ID_WIDTH-1:0] dma_m_axi_bid,
    input [1:0] dma_m_axi_bresp,
    input dma_m_axi_bvalid,
    output dma_m_axi_bready,
    output [`DDR_AXI_ID_WIDTH-1:0] dma_m_axi_arid,
    output [`DDR_AXI_ADDR_WIDTH-1:0] dma_m_axi_araddr,
    output [7:0] dma_m_axi_arlen,
    output [2:0] dma_m_axi_arsize,
    output [1:0] dma_m_axi_arburst,
    output dma_m_axi_arlock,
    output [3:0] dma_m_axi_arcache,
    output [2:0] dma_m_axi_arprot,
    output dma_m_axi_arvalid,
    input dma_m_axi_arready,
    input [`DDR_AXI_ID_WIDTH-1:0] dma_m_axi_rid,
    input [`DMA_AXI_DATA_WIDTH-1:0] dma_m_axi_rdata,
    input [1:0] dma_m_axi_rresp,
    input dma_m_axi_rlast,
    input dma_m_axi_rvalid,
    output dma_m_axi_rready,
    // XDMA usr_irq
    output [`XDMA_USR_INTR_COUNT-1:0] xdma_usr_irq_req
);
    wire [`DDR_AXI_ADDR_WIDTH-1:0] dma_read_desc_addr;
    wire [`DDR_LEN_WIDTH-1:0] dma_read_desc_len;
    wire [`DDR_TAG_WIDTH-1:0] dma_read_desc_tag;
    wire [`DDR_AXIS_ID_WIDTH-1:0] dma_read_desc_id;
    wire [`DDR_AXIS_DEST_WIDTH-1:0] dma_read_desc_dest;
    wire [`DDR_AXIS_USER_WIDTH-1:0] dma_read_desc_user;
    wire dma_read_desc_valid;
    wire dma_read_desc_ready;
    wire [`DDR_TAG_WIDTH-1:0] dma_read_desc_status_tag;
    wire [3:0] dma_read_desc_status_error;
    wire dma_read_desc_status_valid;
    wire [`DDR_AXIS_DATA_WIDTH-1:0] dma_read_data_tdata;
    wire [`DDR_AXIS_KEEP_WIDTH-1:0] dma_read_data_tkeep;
    wire dma_read_data_tvalid;
    wire dma_read_data_tready;
    wire dma_read_data_tlast;
    wire [`DDR_AXIS_ID_WIDTH-1:0] dma_read_data_tid;
    wire [`DDR_AXIS_DEST_WIDTH-1:0] dma_read_data_tdest;
    wire [`DDR_AXIS_USER_WIDTH-1:0] dma_read_data_tuser;
    wire [`DDR_AXI_ADDR_WIDTH-1:0] dma_write_desc_addr;
    wire [`DDR_LEN_WIDTH-1:0] dma_write_desc_len;
    wire [`DDR_TAG_WIDTH-1:0] dma_write_desc_tag;
    wire dma_write_desc_valid;
    wire dma_write_desc_ready;
    wire [`DDR_LEN_WIDTH-1:0] dma_write_desc_status_len;
    wire [`DDR_TAG_WIDTH-1:0] dma_write_desc_status_tag;
    wire [`DDR_AXIS_ID_WIDTH-1:0] dma_write_desc_status_id;
    wire [`DDR_AXIS_DEST_WIDTH-1:0] dma_write_desc_status_dest;
    wire [`DDR_AXIS_USER_WIDTH-1:0] dma_write_desc_status_user;
    wire [3:0] dma_write_desc_status_error;
    wire dma_write_desc_status_valid;
    wire [`DDR_AXIS_DATA_WIDTH-1:0] dma_write_data_tdata;
    wire [`DDR_AXIS_KEEP_WIDTH-1:0] dma_write_data_tkeep;
    wire dma_write_data_tvalid;
    wire dma_write_data_tready;
    wire dma_write_data_tlast;
    wire [`DDR_AXIS_ID_WIDTH-1:0] dma_write_data_tid;
    wire [`DDR_AXIS_DEST_WIDTH-1:0] dma_write_data_tdest;
    wire [`DDR_AXIS_USER_WIDTH-1:0] dma_write_data_tuser;
    wire dma_read_enable;
    wire dma_write_enable;

    wire rtm_hc_d2c_start_pulse;
    wire [31:0] rtm_hc_d2c_d_addr;
    wire [31:0] rtm_hc_d2c_c_addr;
    wire [31:0] rtm_hc_d2c_n_bytes;
    wire rtm_hc_d2c_done_pulse;
    wire rtm_hc_c2d_start_pulse;
    wire [31:0] rtm_hc_c2d_d_addr;
    wire [31:0] rtm_hc_c2d_c_addr;
    wire [31:0] rtm_hc_c2d_n_bytes;
    wire rtm_hc_c2d_done_pulse;
    wire rtm_ic_d2c_start_pulse = 0;
    wire [31:0] rtm_ic_d2c_d_addr = 0;
    wire [31:0] rtm_ic_d2c_c_addr = 0;
    wire [31:0] rtm_ic_d2c_n_bytes = 0;
    wire rtm_ic_d2c_done_pulse;
    wire rtm_ic_c2d_start_pulse = 0;
    wire [31:0] rtm_ic_c2d_d_addr = 0;
    wire [31:0] rtm_ic_c2d_c_addr = 0;
    wire [31:0] rtm_ic_c2d_n_bytes = 0;
    wire rtm_ic_c2d_done_pulse;
    wire [`DDR_AXI_ADDR_WIDTH-1:0] rtm_dma_wr_desc_addr;
    wire [`DDR_LEN_WIDTH-1:0] rtm_dma_wr_desc_len;
    wire rtm_dma_wr_desc_valid;
    wire rtm_dma_wr_desc_status_valid;
    wire [`DDR_AXIS_DATA_WIDTH-1:0] rtm_dma_wr_write_data_tdata;
    wire rtm_dma_wr_write_data_tvalid;
    wire rtm_dma_wr_write_data_tready;
    wire rtm_dma_wr_write_data_tlast;
    wire [`DDR_AXI_ADDR_WIDTH-1:0] rtm_dma_rd_desc_addr;
    wire [`DDR_LEN_WIDTH-1:0] rtm_dma_rd_desc_len;
    wire rtm_dma_rd_desc_valid;
    wire [`DDR_AXIS_DATA_WIDTH-1:0] rtm_dma_rd_read_data_tdata;
    wire rtm_dma_rd_read_data_tvalid;
    wire rtm_dma_rd_read_data_tlast;
    wire rtm_wr_vld_conv;
    wire [`S-1:0] rtm_wr_en_conv;
    wire [`S*$clog2(`RTM_DEPTH)-1:0] rtm_wr_addr_conv;
    wire [`S*`R*8-1:0] rtm_din_conv;
    wire rtm_wr_vld_pool;
    wire [`S-1:0] rtm_wr_en_pool;
    wire [`S*$clog2(`RTM_DEPTH)-1:0] rtm_wr_addr_pool;
    wire [`S*`R*8-1:0] rtm_din_pool;
    wire rtm_wr_vld_fc;
    wire [`S-1:0] rtm_wr_en_fc;
    wire [`S*$clog2(`RTM_DEPTH)-1:0] rtm_wr_addr_fc;
    wire [`S*`R*8-1:0] rtm_din_fc;
    wire rtm_wr_vld_add;
    wire [`S-1:0] rtm_wr_en_add;
    wire [`S*$clog2(`RTM_DEPTH)-1:0] rtm_wr_addr_add;
    wire [`S*`R*8-1:0] rtm_din_add;
    wire rtm_wr_vld_remap;
    wire [`S-1:0] rtm_wr_en_remap;
    wire [`S*$clog2(`RTM_DEPTH)-1:0] rtm_wr_addr_remap;
    wire [`S*`R*8-1:0] rtm_din_remap;
    wire rtm_rd_vld_xbus;
    wire [`S-1:0] rtm_rd_en_xbus;
    wire [`XPHM_DATA_WIDTH+$clog2(`R/`Q)+1:0] rtm_rd_att_xbus;
    wire [`S*$clog2(`RTM_DEPTH)-1:0] rtm_rd_addr_xbus;
    wire [`S*`R*8-1:0] rtm_dout_xbus;
    wire [`XPHM_DATA_WIDTH+$clog2(`R/`Q)+1:0] rtm_dout_att_xbus;
    wire rtm_dout_vld_xbus;
    wire rtm_rd_vld_fc;
    wire rtm_rd_vec_begin_fc;
    wire rtm_rd_vec_end_fc;
    wire rtm_rd_last_fc;
    wire [`S-1:0] rtm_rd_en_fc;
    wire [`S*$clog2(`RTM_DEPTH)-1:0] rtm_rd_addr_fc;
    wire [`S*`R*8-1:0] rtm_dout_fc;
    wire rtm_dout_vld_fc;
    wire rtm_dout_vec_begin_fc;
    wire rtm_dout_vec_end_fc;
    wire rtm_dout_last_fc;
    wire rtm_rd_vld_add;
    wire rtm_rd_last_add;
    wire [`S-1:0] rtm_rd_en_add;
    wire [`S*$clog2(`RTM_DEPTH)-1:0] rtm_rd_addr_add;
    wire [`S*`R*8-1:0] rtm_dout_add;
    wire rtm_dout_vld_add;
    wire rtm_dout_last_add;
    wire rtm_rd_vld_remap;
    wire rtm_rd_last_remap;
    wire [`S-1:0] rtm_rd_en_remap;
    wire [`S*$clog2(`RTM_DEPTH)-1:0] rtm_rd_addr_remap;
    wire [`S*`R*8-1:0] rtm_dout_remap;
    wire rtm_dout_vld_remap;
    wire rtm_dout_last_remap;

    wire cwm_hc_d2c_start_pulse;
    wire [31:0] cwm_hc_d2c_d_addr;
    wire [31:0] cwm_hc_d2c_c_addr;
    wire [31:0] cwm_hc_d2c_n_bytes;
    wire cwm_hc_d2c_done_pulse;
    wire cwm_ic_d2c_start_pulse;
    wire [31:0] cwm_ic_d2c_d_addr;
    wire [31:0] cwm_ic_d2c_c_addr;
    wire [31:0] cwm_ic_d2c_n_bytes;
    wire cwm_ic_d2c_done_pulse;
    wire [`DDR_AXI_ADDR_WIDTH-1:0] cwm_dma_rd_desc_addr;
    wire [`DDR_LEN_WIDTH-1:0] cwm_dma_rd_desc_len;
    wire cwm_dma_rd_desc_valid;
    wire [`DDR_AXIS_DATA_WIDTH-1:0] cwm_dma_rd_read_data_tdata;
    wire cwm_dma_rd_read_data_tvalid;
    wire cwm_dma_rd_read_data_tlast;
    wire [$clog2(`CWM_DEPTH):0] cwm_wr_ptr;
    wire cwm_rd_en;
    wire [$clog2(`CWM_DEPTH)-1:0] cwm_rd_addr;
    wire [`M*4*8-1:0] cwm_dout;
    wire cwm_dout_vld;

    wire im_hc_d2c_start_pulse;
    wire [31:0] im_hc_d2c_d_addr;
    wire [31:0] im_hc_d2c_n_bytes;
    wire im_hc_d2c_done_pulse;
    wire [`DDR_AXI_ADDR_WIDTH-1:0] im_dma_rd_desc_addr;
    wire [`DDR_LEN_WIDTH-1:0] im_dma_rd_desc_len;
    wire im_dma_rd_desc_valid;
    wire [`DDR_AXIS_DATA_WIDTH-1:0] im_dma_rd_read_data_tdata;
    wire im_dma_rd_read_data_tvalid;
    wire im_dma_rd_read_data_tlast;
    wire im_rd_en;
    wire [$clog2(`INS_RAM_DEPTH)-1:0] im_rd_addr;
    wire [`INS_RAM_DATA_WIDTH-1:0] im_dout;
    wire im_dout_vld;

    wire bm_hc_d2c_start_pulse;
    wire [31:0] bm_hc_d2c_d_addr;
    wire [31:0] bm_hc_d2c_c_addr;
    wire [31:0] bm_hc_d2c_n_bytes;
    wire bm_hc_d2c_done_pulse;
    wire [`DDR_AXI_ADDR_WIDTH-1:0] bm_dma_rd_desc_addr;
    wire [`DDR_LEN_WIDTH-1:0] bm_dma_rd_desc_len;
    wire bm_dma_rd_desc_valid;
    wire [`DDR_AXIS_DATA_WIDTH-1:0] bm_dma_rd_read_data_tdata;
    wire bm_dma_rd_read_data_tvalid;
    wire bm_dma_rd_read_data_tlast;
    wire bm_rd_en_conv;
    wire [$clog2(`BM_DEPTH)-1:0] bm_rd_addr_conv;
    wire [`BM_DATA_WIDTH-1:0] bm_dout_conv;
    wire bm_dout_vld_conv;
    wire bm_rd_en_fc;
    wire [$clog2(`BM_DEPTH)-1:0] bm_rd_addr_fc;
    wire [`BM_DATA_WIDTH-1:0] bm_dout_fc;
    wire bm_dout_vld_fc;

    wire xphm_hc_d2c_start_pulse;
    wire [31:0] xphm_hc_d2c_d_addr;
    wire [31:0] xphm_hc_d2c_c_addr;
    wire [31:0] xphm_hc_d2c_n_bytes;
    wire xphm_hc_d2c_done_pulse;
    wire [`DDR_AXI_ADDR_WIDTH-1:0] xphm_dma_rd_desc_addr;
    wire [`DDR_LEN_WIDTH-1:0] xphm_dma_rd_desc_len;
    wire xphm_dma_rd_desc_valid;
    wire [`DDR_AXIS_DATA_WIDTH-1:0] xphm_dma_rd_read_data_tdata;
    wire xphm_dma_rd_read_data_tvalid;
    wire xphm_dma_rd_read_data_tlast;
    wire xphm_rd_en;
    wire xphm_rd_last;
    wire [$clog2(`XPHM_DEPTH)-1:0] xphm_rd_addr;
    wire [`XPHM_DATA_WIDTH-1:0] xphm_dout;
    wire xphm_dout_vld;
    wire xphm_dout_last;

    wire [`DDR_AXI_ADDR_WIDTH-1:0] fcws_dma_desc_addr;
    wire [`DDR_LEN_WIDTH-1:0] fcws_dma_desc_len;
    wire fcws_dma_desc_valid;
    wire [`DDR_AXIS_DATA_WIDTH-1:0] fcws_dma_read_data_tdata;
    wire fcws_dma_read_data_tvalid;
    wire fcws_dma_read_data_tready;
    wire fcws_dma_read_data_tlast;

    wire hc_exec_start_pulse;
    wire hc_exec_done_pulse;
    wire [`LATENCY_COUNTER_WIDTH-1:0] conv_latency;
    wire [`LATENCY_COUNTER_WIDTH-1:0] pool_latency;
    wire [`LATENCY_COUNTER_WIDTH-1:0] add_latency;
    wire [`LATENCY_COUNTER_WIDTH-1:0] remap_latency;
    wire [`LATENCY_COUNTER_WIDTH-1:0] fc_latency;

    wire [`XDMA_USR_INTR_COUNT-1:0] intr_clr;
    wire [`XDMA_USR_INTR_COUNT-1:0] intr_clr_vld;

    sr_cr sr_cr_inst(
    	.S_AXI_ACLK(main_clk),
        .S_AXI_ARESETN(~main_rst),
        .S_AXI_AWADDR(sr_cr_S_AXI_AWADDR),
        .S_AXI_AWPROT(sr_cr_S_AXI_AWPROT),
        .S_AXI_AWVALID(sr_cr_S_AXI_AWVALID),
        .S_AXI_AWREADY(sr_cr_S_AXI_AWREADY),
        .S_AXI_WDATA(sr_cr_S_AXI_WDATA),
        .S_AXI_WSTRB(sr_cr_S_AXI_WSTRB),
        .S_AXI_WVALID(sr_cr_S_AXI_WVALID),
        .S_AXI_WREADY(sr_cr_S_AXI_WREADY),
        .S_AXI_BRESP(sr_cr_S_AXI_BRESP),
        .S_AXI_BVALID(sr_cr_S_AXI_BVALID),
        .S_AXI_BREADY(sr_cr_S_AXI_BREADY),
        .S_AXI_ARADDR(sr_cr_S_AXI_ARADDR),
        .S_AXI_ARPROT(sr_cr_S_AXI_ARPROT),
        .S_AXI_ARVALID(sr_cr_S_AXI_ARVALID),
        .S_AXI_ARREADY(sr_cr_S_AXI_ARREADY),
        .S_AXI_RDATA(sr_cr_S_AXI_RDATA),
        .S_AXI_RRESP(sr_cr_S_AXI_RRESP),
        .S_AXI_RVALID(sr_cr_S_AXI_RVALID),
        .S_AXI_RREADY(sr_cr_S_AXI_RREADY),
        .im_d2c_start_pulse(im_hc_d2c_start_pulse),
        .im_d2c_d_addr(im_hc_d2c_d_addr),
        .im_d2c_n_bytes(im_hc_d2c_n_bytes),
        .rtm_d2c_start_pulse(rtm_hc_d2c_start_pulse),
        .rtm_d2c_d_addr(rtm_hc_d2c_d_addr),
        .rtm_d2c_c_addr(rtm_hc_d2c_c_addr),
        .rtm_d2c_n_bytes(rtm_hc_d2c_n_bytes),
        .rtm_c2d_start_pulse(rtm_hc_c2d_start_pulse),
        .rtm_c2d_d_addr(rtm_hc_c2d_d_addr),
        .rtm_c2d_c_addr(rtm_hc_c2d_c_addr),
        .rtm_c2d_n_bytes(rtm_hc_c2d_n_bytes),
        .cwm_d2c_start_pulse(cwm_hc_d2c_start_pulse),
        .cwm_d2c_d_addr(cwm_hc_d2c_d_addr),
        .cwm_d2c_c_addr(cwm_hc_d2c_c_addr),
        .cwm_d2c_n_bytes(cwm_hc_d2c_n_bytes),
        .bm_d2c_start_pulse(bm_hc_d2c_start_pulse),
        .bm_d2c_d_addr(bm_hc_d2c_d_addr),
        .bm_d2c_c_addr(bm_hc_d2c_c_addr),
        .bm_d2c_n_bytes(bm_hc_d2c_n_bytes),
        .xphm_d2c_start_pulse(xphm_hc_d2c_start_pulse),
        .xphm_d2c_d_addr(xphm_hc_d2c_d_addr),
        .xphm_d2c_c_addr(xphm_hc_d2c_c_addr),
        .xphm_d2c_n_bytes(xphm_hc_d2c_n_bytes),
        .exec_start_pulse(hc_exec_start_pulse),
        .conv_latency(conv_latency),
        .pool_latency(pool_latency),
        .add_latency(add_latency),
        .remap_latency(remap_latency),
        .fc_latency(fc_latency),
        .intr_clr(intr_clr),
        .intr_clr_vld(intr_clr_vld)
    );

    axi_dma axi_dma_inst(
    	.clk(main_clk),
        .rst(main_rst),
        .s_axis_read_desc_addr(dma_read_desc_addr),
        .s_axis_read_desc_len(dma_read_desc_len),
        .s_axis_read_desc_tag(dma_read_desc_tag),
        .s_axis_read_desc_id(dma_read_desc_id),
        .s_axis_read_desc_dest(dma_read_desc_dest),
        .s_axis_read_desc_user(dma_read_desc_user),
        .s_axis_read_desc_valid(dma_read_desc_valid),
        .s_axis_read_desc_ready(dma_read_desc_ready),
        .m_axis_read_desc_status_tag(dma_read_desc_status_tag),
        .m_axis_read_desc_status_error(dma_read_desc_status_error),
        .m_axis_read_desc_status_valid(dma_read_desc_status_valid),
        .m_axis_read_data_tdata(dma_read_data_tdata),
        .m_axis_read_data_tkeep(dma_read_data_tkeep),
        .m_axis_read_data_tvalid(dma_read_data_tvalid),
        .m_axis_read_data_tready(dma_read_data_tready),
        .m_axis_read_data_tlast(dma_read_data_tlast),
        .m_axis_read_data_tid(dma_read_data_tid),
        .m_axis_read_data_tdest(dma_read_data_tdest),
        .m_axis_read_data_tuser(dma_read_data_tuser),
        .s_axis_write_desc_addr(dma_write_desc_addr),
        .s_axis_write_desc_len(dma_write_desc_len),
        .s_axis_write_desc_tag(dma_write_desc_tag),
        .s_axis_write_desc_valid(dma_write_desc_valid),
        .s_axis_write_desc_ready(dma_write_desc_ready),
        .m_axis_write_desc_status_len(dma_write_desc_status_len),
        .m_axis_write_desc_status_tag(dma_write_desc_status_tag),
        .m_axis_write_desc_status_id(dma_write_desc_status_id),
        .m_axis_write_desc_status_dest(dma_write_desc_status_dest),
        .m_axis_write_desc_status_user(dma_write_desc_status_user),
        .m_axis_write_desc_status_error(dma_write_desc_status_error),
        .m_axis_write_desc_status_valid(dma_write_desc_status_valid),
        .s_axis_write_data_tdata(dma_write_data_tdata),
        .s_axis_write_data_tkeep(dma_write_data_tkeep),
        .s_axis_write_data_tvalid(dma_write_data_tvalid),
        .s_axis_write_data_tready(dma_write_data_tready),
        .s_axis_write_data_tlast(dma_write_data_tlast),
        .s_axis_write_data_tid(dma_write_data_tid),
        .s_axis_write_data_tdest(dma_write_data_tdest),
        .s_axis_write_data_tuser(dma_write_data_tuser),
        .m_axi_awid(dma_m_axi_awid),
        .m_axi_awaddr(dma_m_axi_awaddr),
        .m_axi_awlen(dma_m_axi_awlen),
        .m_axi_awsize(dma_m_axi_awsize),
        .m_axi_awburst(dma_m_axi_awburst),
        .m_axi_awlock(dma_m_axi_awlock),
        .m_axi_awcache(dma_m_axi_awcache),
        .m_axi_awprot(dma_m_axi_awprot),
        .m_axi_awvalid(dma_m_axi_awvalid),
        .m_axi_awready(dma_m_axi_awready),
        .m_axi_wdata(dma_m_axi_wdata),
        .m_axi_wstrb(dma_m_axi_wstrb),
        .m_axi_wlast(dma_m_axi_wlast),
        .m_axi_wvalid(dma_m_axi_wvalid),
        .m_axi_wready(dma_m_axi_wready),
        .m_axi_bid(dma_m_axi_bid),
        .m_axi_bresp(dma_m_axi_bresp),
        .m_axi_bvalid(dma_m_axi_bvalid),
        .m_axi_bready(dma_m_axi_bready),
        .m_axi_arid(dma_m_axi_arid),
        .m_axi_araddr(dma_m_axi_araddr),
        .m_axi_arlen(dma_m_axi_arlen),
        .m_axi_arsize(dma_m_axi_arsize),
        .m_axi_arburst(dma_m_axi_arburst),
        .m_axi_arlock(dma_m_axi_arlock),
        .m_axi_arcache(dma_m_axi_arcache),
        .m_axi_arprot(dma_m_axi_arprot),
        .m_axi_arvalid(dma_m_axi_arvalid),
        .m_axi_arready(dma_m_axi_arready),
        .m_axi_rid(dma_m_axi_rid),
        .m_axi_rdata(dma_m_axi_rdata),
        .m_axi_rresp(dma_m_axi_rresp),
        .m_axi_rlast(dma_m_axi_rlast),
        .m_axi_rvalid(dma_m_axi_rvalid),
        .m_axi_rready(dma_m_axi_rready),
        .read_enable(dma_read_enable),
        .write_enable(dma_write_enable),
        .write_abort(1'b0)
    );

    dma_rd_ctrl dma_rd_ctrl_inst(
    	.clk(main_clk),
        .enable(dma_read_enable),
        .desc_addr(dma_read_desc_addr),
        .desc_len(dma_read_desc_len),
        .desc_valid(dma_read_desc_valid),
        .desc_ready(dma_read_desc_ready),
        .read_data_tdata(dma_read_data_tdata),
        .read_data_tkeep(dma_read_data_tkeep),
        .read_data_tvalid(dma_read_data_tvalid),
        .read_data_tready(dma_read_data_tready),
        .read_data_tlast(dma_read_data_tlast),
        .rtm_dma_desc_addr(rtm_dma_rd_desc_addr),
        .rtm_dma_desc_len(rtm_dma_rd_desc_len),
        .rtm_dma_desc_valid(rtm_dma_rd_desc_valid),
        .rtm_dma_read_data_tdata(rtm_dma_rd_read_data_tdata),
        .rtm_dma_read_data_tvalid(rtm_dma_rd_read_data_tvalid),
        .rtm_dma_read_data_tlast(rtm_dma_rd_read_data_tlast),
        .im_dma_desc_addr(im_dma_rd_desc_addr),
        .im_dma_desc_len(im_dma_rd_desc_len),
        .im_dma_desc_valid(im_dma_rd_desc_valid),
        .im_dma_read_data_tdata(im_dma_rd_read_data_tdata),
        .im_dma_read_data_tvalid(im_dma_rd_read_data_tvalid),
        .im_dma_read_data_tlast(im_dma_rd_read_data_tlast),
        .bm_dma_desc_addr(bm_dma_rd_desc_addr),
        .bm_dma_desc_len(bm_dma_rd_desc_len),
        .bm_dma_desc_valid(bm_dma_rd_desc_valid),
        .bm_dma_read_data_tdata(bm_dma_rd_read_data_tdata),
        .bm_dma_read_data_tvalid(bm_dma_rd_read_data_tvalid),
        .bm_dma_read_data_tlast(bm_dma_rd_read_data_tlast),
        .xphm_dma_desc_addr(xphm_dma_rd_desc_addr),
        .xphm_dma_desc_len(xphm_dma_rd_desc_len),
        .xphm_dma_desc_valid(xphm_dma_rd_desc_valid),
        .xphm_dma_read_data_tdata(xphm_dma_rd_read_data_tdata),
        .xphm_dma_read_data_tvalid(xphm_dma_rd_read_data_tvalid),
        .xphm_dma_read_data_tlast(xphm_dma_rd_read_data_tlast),
        .cwm_dma_desc_addr(cwm_dma_rd_desc_addr),
        .cwm_dma_desc_len(cwm_dma_rd_desc_len),
        .cwm_dma_desc_valid(cwm_dma_rd_desc_valid),
        .cwm_dma_read_data_tdata(cwm_dma_rd_read_data_tdata),
        .cwm_dma_read_data_tvalid(cwm_dma_rd_read_data_tvalid),
        .cwm_dma_read_data_tlast(cwm_dma_rd_read_data_tlast),
        .fcws_dma_desc_addr(fcws_dma_desc_addr),
        .fcws_dma_desc_len(fcws_dma_desc_len),
        .fcws_dma_desc_valid(fcws_dma_desc_valid),
        .fcws_dma_read_data_tdata(fcws_dma_read_data_tdata),
        .fcws_dma_read_data_tvalid(fcws_dma_read_data_tvalid),
        .fcws_dma_read_data_tready(fcws_dma_read_data_tready),
        .fcws_dma_read_data_tlast(fcws_dma_read_data_tlast)
    );

    dma_wr_ctrl dma_wr_ctrl_inst(
    	.clk(main_clk),
        .enable(dma_write_enable),
        .desc_addr(dma_write_desc_addr),
        .desc_len(dma_write_desc_len),
        .desc_valid(dma_write_desc_valid),
        .desc_ready(dma_write_desc_ready),
        .desc_status_valid(dma_write_desc_status_valid),
        .write_data_tdata(dma_write_data_tdata),
        .write_data_tkeep(dma_write_data_tkeep),
        .write_data_tvalid(dma_write_data_tvalid),
        .write_data_tready(dma_write_data_tready),
        .write_data_tlast(dma_write_data_tlast),
        .rtm_dma_desc_addr(rtm_dma_wr_desc_addr),
        .rtm_dma_desc_len(rtm_dma_wr_desc_len),
        .rtm_dma_desc_valid(rtm_dma_wr_desc_valid),
        .rtm_dma_desc_status_valid(rtm_dma_wr_desc_status_valid),
        .rtm_dma_write_data_tdata(rtm_dma_wr_write_data_tdata),
        .rtm_dma_write_data_tvalid(rtm_dma_wr_write_data_tvalid),
        .rtm_dma_write_data_tready(rtm_dma_wr_write_data_tready),
        .rtm_dma_write_data_tlast(rtm_dma_wr_write_data_tlast)
    );

    rtm rtm_inst(
    	.clk(main_clk),
        .hc_d2c_start_pulse(rtm_hc_d2c_start_pulse),
        .hc_d2c_d_addr(rtm_hc_d2c_d_addr),
        .hc_d2c_c_addr(rtm_hc_d2c_c_addr),
        .hc_d2c_n_bytes(rtm_hc_d2c_n_bytes),
        .hc_d2c_done_pulse(rtm_hc_d2c_done_pulse),
        .hc_c2d_start_pulse(rtm_hc_c2d_start_pulse),
        .hc_c2d_d_addr(rtm_hc_c2d_d_addr),
        .hc_c2d_c_addr(rtm_hc_c2d_c_addr),
        .hc_c2d_n_bytes(rtm_hc_c2d_n_bytes),
        .hc_c2d_done_pulse(rtm_hc_c2d_done_pulse),
        .ic_d2c_start_pulse(rtm_ic_d2c_start_pulse),
        .ic_d2c_d_addr(rtm_ic_d2c_d_addr),
        .ic_d2c_c_addr(rtm_ic_d2c_c_addr),
        .ic_d2c_n_bytes(rtm_ic_d2c_n_bytes),
        .ic_d2c_done_pulse(rtm_ic_d2c_done_pulse),
        .ic_c2d_start_pulse(rtm_ic_c2d_start_pulse),
        .ic_c2d_d_addr(rtm_ic_c2d_d_addr),
        .ic_c2d_c_addr(rtm_ic_c2d_c_addr),
        .ic_c2d_n_bytes(rtm_ic_c2d_n_bytes),
        .ic_c2d_done_pulse(rtm_ic_c2d_done_pulse),
        .dma_wr_desc_addr(rtm_dma_wr_desc_addr),
        .dma_wr_desc_len(rtm_dma_wr_desc_len),
        .dma_wr_desc_valid(rtm_dma_wr_desc_valid),
        .dma_wr_desc_status_valid(rtm_dma_wr_desc_status_valid),
        .dma_wr_write_data_tdata(rtm_dma_wr_write_data_tdata),
        .dma_wr_write_data_tvalid(rtm_dma_wr_write_data_tvalid),
        .dma_wr_write_data_tready(rtm_dma_wr_write_data_tready),
        .dma_wr_write_data_tlast(rtm_dma_wr_write_data_tlast),
        .dma_rd_desc_addr(rtm_dma_rd_desc_addr),
        .dma_rd_desc_len(rtm_dma_rd_desc_len),
        .dma_rd_desc_valid(rtm_dma_rd_desc_valid),
        .dma_rd_read_data_tdata(rtm_dma_rd_read_data_tdata),
        .dma_rd_read_data_tvalid(rtm_dma_rd_read_data_tvalid),
        .dma_rd_read_data_tlast(rtm_dma_rd_read_data_tlast),
        .rtm_wr_vld_conv(rtm_wr_vld_conv),
        .rtm_wr_en_conv(rtm_wr_en_conv),
        .rtm_wr_addr_conv(rtm_wr_addr_conv),
        .rtm_din_conv(rtm_din_conv),
        .rtm_wr_vld_pool(rtm_wr_vld_pool),
        .rtm_wr_en_pool(rtm_wr_en_pool),
        .rtm_wr_addr_pool(rtm_wr_addr_pool),
        .rtm_din_pool(rtm_din_pool),
        .rtm_wr_vld_fc(rtm_wr_vld_fc),
        .rtm_wr_en_fc(rtm_wr_en_fc),
        .rtm_wr_addr_fc(rtm_wr_addr_fc),
        .rtm_din_fc(rtm_din_fc),
        .rtm_wr_vld_add(rtm_wr_vld_add),
        .rtm_wr_en_add(rtm_wr_en_add),
        .rtm_wr_addr_add(rtm_wr_addr_add),
        .rtm_din_add(rtm_din_add),
        .rtm_wr_vld_remap(rtm_wr_vld_remap),
        .rtm_wr_en_remap(rtm_wr_en_remap),
        .rtm_wr_addr_remap(rtm_wr_addr_remap),
        .rtm_din_remap(rtm_din_remap),
        .rtm_rd_vld_xbus(rtm_rd_vld_xbus),
        .rtm_rd_en_xbus(rtm_rd_en_xbus),
        .rtm_rd_att_xbus(rtm_rd_att_xbus),
        .rtm_rd_addr_xbus(rtm_rd_addr_xbus),
        .rtm_dout_xbus(rtm_dout_xbus),
        .rtm_dout_att_xbus(rtm_dout_att_xbus),
        .rtm_dout_vld_xbus(rtm_dout_vld_xbus),
        .rtm_rd_vld_fc(rtm_rd_vld_fc),
        .rtm_rd_en_fc(rtm_rd_en_fc),
        .rtm_rd_vec_begin_fc(rtm_rd_vec_begin_fc),
        .rtm_rd_vec_end_fc(rtm_rd_vec_end_fc),
        .rtm_rd_last_fc(rtm_rd_last_fc),
        .rtm_rd_addr_fc(rtm_rd_addr_fc),
        .rtm_dout_fc(rtm_dout_fc),
        .rtm_dout_vld_fc(rtm_dout_vld_fc),
        .rtm_dout_vec_begin_fc(rtm_dout_vec_begin_fc),
        .rtm_dout_vec_end_fc(rtm_dout_vec_end_fc),
        .rtm_dout_last_fc(rtm_dout_last_fc),
        .rtm_rd_vld_add(rtm_rd_vld_add),
        .rtm_rd_last_add(rtm_rd_last_add),
        .rtm_rd_en_add(rtm_rd_en_add),
        .rtm_rd_addr_add(rtm_rd_addr_add),
        .rtm_dout_add(rtm_dout_add),
        .rtm_dout_vld_add(rtm_dout_vld_add),
        .rtm_dout_last_add(rtm_dout_last_add),
        .rtm_rd_vld_remap(rtm_rd_vld_remap),
        .rtm_rd_last_remap(rtm_rd_last_remap),
        .rtm_rd_en_remap(rtm_rd_en_remap),
        .rtm_rd_addr_remap(rtm_rd_addr_remap),
        .rtm_dout_remap(rtm_dout_remap),
        .rtm_dout_vld_remap(rtm_dout_vld_remap),
        .rtm_dout_last_remap(rtm_dout_last_remap)
    );

    cwm cwm_inst(
        .clk(main_clk),
        .hc_d2c_start_pulse(cwm_hc_d2c_start_pulse),
        .hc_d2c_d_addr(cwm_hc_d2c_d_addr),
        .hc_d2c_c_addr(cwm_hc_d2c_c_addr),
        .hc_d2c_n_bytes(cwm_hc_d2c_n_bytes),
        .hc_d2c_done_pulse(cwm_hc_d2c_done_pulse),
        .ic_d2c_start_pulse(cwm_ic_d2c_start_pulse),
        .ic_d2c_d_addr(cwm_ic_d2c_d_addr),
        .ic_d2c_c_addr(cwm_ic_d2c_c_addr),
        .ic_d2c_n_bytes(cwm_ic_d2c_n_bytes),
        .ic_d2c_done_pulse(cwm_ic_d2c_done_pulse),
        .dma_rd_desc_addr(cwm_dma_rd_desc_addr),
        .dma_rd_desc_len(cwm_dma_rd_desc_len),
        .dma_rd_desc_valid(cwm_dma_rd_desc_valid),
        .dma_rd_read_data_tdata(cwm_dma_rd_read_data_tdata),
        .dma_rd_read_data_tvalid(cwm_dma_rd_read_data_tvalid),
        .dma_rd_read_data_tlast(cwm_dma_rd_read_data_tlast),
        .wr_ptr(cwm_wr_ptr),
        .rd_en(cwm_rd_en),
        .rd_addr(cwm_rd_addr),
        .dout(cwm_dout),
        .dout_vld(cwm_dout_vld)
    );

    im im_inst(
    	.clk(main_clk),
        .hc_d2c_start_pulse(im_hc_d2c_start_pulse),
        .hc_d2c_d_addr(im_hc_d2c_d_addr),
        .hc_d2c_n_bytes(im_hc_d2c_n_bytes),
        .hc_d2c_done_pulse(im_hc_d2c_done_pulse),
        .dma_rd_desc_addr(im_dma_rd_desc_addr),
        .dma_rd_desc_len(im_dma_rd_desc_len),
        .dma_rd_desc_valid(im_dma_rd_desc_valid),
        .dma_rd_read_data_tdata(im_dma_rd_read_data_tdata),
        .dma_rd_read_data_tvalid(im_dma_rd_read_data_tvalid),
        .dma_rd_read_data_tlast(im_dma_rd_read_data_tlast),
        .rd_en(im_rd_en),
        .rd_addr(im_rd_addr),
        .dout(im_dout),
        .dout_vld(im_dout_vld)
    );

    bm bm_inst(
    	.clk(main_clk),
        .hc_d2c_start_pulse(bm_hc_d2c_start_pulse),
        .hc_d2c_d_addr(bm_hc_d2c_d_addr),
        .hc_d2c_c_addr(bm_hc_d2c_c_addr),
        .hc_d2c_n_bytes(bm_hc_d2c_n_bytes),
        .hc_d2c_done_pulse(bm_hc_d2c_done_pulse),
        .dma_rd_desc_addr(bm_dma_rd_desc_addr),
        .dma_rd_desc_len(bm_dma_rd_desc_len),
        .dma_rd_desc_valid(bm_dma_rd_desc_valid),
        .dma_rd_read_data_tdata(bm_dma_rd_read_data_tdata),
        .dma_rd_read_data_tvalid(bm_dma_rd_read_data_tvalid),
        .dma_rd_read_data_tlast(bm_dma_rd_read_data_tlast),
        .rd_en_conv(bm_rd_en_conv),
        .rd_addr_conv(bm_rd_addr_conv),
        .dout_conv(bm_dout_conv),
        .dout_vld_conv(bm_dout_vld_conv),
        .rd_en_fc(bm_rd_en_fc),
        .rd_addr_fc(bm_rd_addr_fc),
        .dout_fc(bm_dout_fc),
        .dout_vld_fc(bm_dout_vld_fc)
    );

    xphm xphm_inst(
        .clk(main_clk),
        .hc_d2c_start_pulse(xphm_hc_d2c_start_pulse),
        .hc_d2c_d_addr(xphm_hc_d2c_d_addr),
        .hc_d2c_c_addr(xphm_hc_d2c_c_addr),
        .hc_d2c_n_bytes(xphm_hc_d2c_n_bytes),
        .hc_d2c_done_pulse(xphm_hc_d2c_done_pulse),
        .dma_rd_desc_addr(xphm_dma_rd_desc_addr),
        .dma_rd_desc_len(xphm_dma_rd_desc_len),
        .dma_rd_desc_valid(xphm_dma_rd_desc_valid),
        .dma_rd_read_data_tdata(xphm_dma_rd_read_data_tdata),
        .dma_rd_read_data_tvalid(xphm_dma_rd_read_data_tvalid),
        .dma_rd_read_data_tlast(xphm_dma_rd_read_data_tlast),
        .rd_en(xphm_rd_en),
        .rd_last(xphm_rd_last),
        .rd_addr(xphm_rd_addr),
        .dout(xphm_dout),
        .dout_vld(xphm_dout_vld),
        .dout_last(xphm_dout_last)
    );

    exec exec_inst(
        .main_clk(main_clk),
        .sa_clk(sa_clk),
        .sys_rst(main_rst),
        .hc_exec_start_pulse(hc_exec_start_pulse),
        .hc_exec_done_pulse(hc_exec_done_pulse),
        .conv_latency(conv_latency),
        .pool_latency(pool_latency),
        .add_latency(add_latency),
        .remap_latency(remap_latency),
        .fc_latency(fc_latency),
        .im_rd_en(im_rd_en),
        .im_rd_addr(im_rd_addr),
        .im_dout(im_dout),
        .im_dout_vld(im_dout_vld),
        .xphm_rd_en(xphm_rd_en),
        .xphm_rd_last(xphm_rd_last),
        .xphm_rd_addr(xphm_rd_addr),
        .xphm_dout(xphm_dout),
        .xphm_dout_vld(xphm_dout_vld),
        .xphm_dout_last(xphm_dout_last),
        .bm_rd_en_conv(bm_rd_en_conv),
        .bm_rd_addr_conv(bm_rd_addr_conv),
        .bm_dout_conv(bm_dout_conv),
        .bm_dout_vld_conv(bm_dout_vld_conv),
        .bm_rd_en_fc(bm_rd_en_fc),
        .bm_rd_addr_fc(bm_rd_addr_fc),
        .bm_dout_fc(bm_dout_fc),
        .bm_dout_vld_fc(bm_dout_vld_fc),
        .cwm_ic_d2c_start_pulse(cwm_ic_d2c_start_pulse),
        .cwm_ic_d2c_d_addr(cwm_ic_d2c_d_addr),
        .cwm_ic_d2c_c_addr(cwm_ic_d2c_c_addr),
        .cwm_ic_d2c_n_bytes(cwm_ic_d2c_n_bytes),
        .cwm_wr_ptr(cwm_wr_ptr),
        .cwm_rd_en(cwm_rd_en),
        .cwm_rd_addr(cwm_rd_addr),
        .cwm_dout(cwm_dout),
        .cwm_dout_vld(cwm_dout_vld),
        .dma_rd_desc_addr_fc(fcws_dma_desc_addr),
        .dma_rd_desc_len_fc(fcws_dma_desc_len),
        .dma_rd_desc_valid_fc(fcws_dma_desc_valid),
        .dma_rd_read_data_tdata_fc(fcws_dma_read_data_tdata),
        .dma_rd_read_data_tvalid_fc(fcws_dma_read_data_tvalid),
        .dma_rd_read_data_tready_fc(fcws_dma_read_data_tready),
        .dma_rd_read_data_tlast_fc(fcws_dma_read_data_tlast),
        .rtm_rd_vld_xbus(rtm_rd_vld_xbus),
        .rtm_rd_en_xbus(rtm_rd_en_xbus),
        .rtm_rd_att_xbus(rtm_rd_att_xbus),
        .rtm_rd_addr_xbus(rtm_rd_addr_xbus),
        .rtm_dout_xbus(rtm_dout_xbus),
        .rtm_dout_att_xbus(rtm_dout_att_xbus),
        .rtm_dout_vld_xbus(rtm_dout_vld_xbus),
        .rtm_rd_vld_add(rtm_rd_vld_add),
        .rtm_rd_last_add(rtm_rd_last_add),
        .rtm_rd_en_add(rtm_rd_en_add),
        .rtm_rd_addr_add(rtm_rd_addr_add),
        .rtm_dout_add(rtm_dout_add),
        .rtm_dout_vld_add(rtm_dout_vld_add),
        .rtm_dout_last_add(rtm_dout_last_add),
        .rtm_rd_vld_remap(rtm_rd_vld_remap),
        .rtm_rd_last_remap(rtm_rd_last_remap),
        .rtm_rd_en_remap(rtm_rd_en_remap),
        .rtm_rd_addr_remap(rtm_rd_addr_remap),
        .rtm_dout_remap(rtm_dout_remap),
        .rtm_dout_vld_remap(rtm_dout_vld_remap),
        .rtm_dout_last_remap(rtm_dout_last_remap),
        .rtm_rd_vld_fc(rtm_rd_vld_fc),
        .rtm_rd_en_fc(rtm_rd_en_fc),
        .rtm_rd_vec_begin_fc(rtm_rd_vec_begin_fc),
        .rtm_rd_vec_end_fc(rtm_rd_vec_end_fc),
        .rtm_rd_last_fc(rtm_rd_last_fc),
        .rtm_rd_addr_fc(rtm_rd_addr_fc),
        .rtm_dout_fc(rtm_dout_fc),
        .rtm_dout_vld_fc(rtm_dout_vld_fc),
        .rtm_dout_vec_begin_fc(rtm_dout_vec_begin_fc),
        .rtm_dout_vec_end_fc(rtm_dout_vec_end_fc),
        .rtm_dout_last_fc(rtm_dout_last_fc),
        .rtm_wr_vld_conv(rtm_wr_vld_conv),
        .rtm_wr_en_conv(rtm_wr_en_conv),
        .rtm_wr_addr_conv(rtm_wr_addr_conv),
        .rtm_din_conv(rtm_din_conv),
        .rtm_wr_vld_pool(rtm_wr_vld_pool),
        .rtm_wr_en_pool(rtm_wr_en_pool),
        .rtm_wr_addr_pool(rtm_wr_addr_pool),
        .rtm_din_pool(rtm_din_pool),
        .rtm_wr_vld_add(rtm_wr_vld_add),
        .rtm_wr_en_add(rtm_wr_en_add),
        .rtm_wr_addr_add(rtm_wr_addr_add),
        .rtm_din_add(rtm_din_add),
        .rtm_wr_vld_remap(rtm_wr_vld_remap),
        .rtm_wr_en_remap(rtm_wr_en_remap),
        .rtm_wr_addr_remap(rtm_wr_addr_remap),
        .rtm_din_remap(rtm_din_remap),
        .rtm_wr_vld_fc(rtm_wr_vld_fc),
        .rtm_wr_en_fc(rtm_wr_en_fc),
        .rtm_wr_addr_fc(rtm_wr_addr_fc),
        .rtm_din_fc(rtm_din_fc)
    );

    xdma_usr_irq xdma_usr_irq_inst(
    	.clk(main_clk),
        .sys_rst(main_rst),
        .im_d2c_done_pulse(im_hc_d2c_done_pulse),
        .rtm_d2c_done_pulse(rtm_hc_d2c_done_pulse),
        .rtm_c2d_done_pulse(rtm_hc_c2d_done_pulse),
        .xphm_d2c_done_pulse(xphm_hc_d2c_done_pulse),
        .cwm_d2c_done_pulse(cwm_hc_d2c_done_pulse),
        .bm_d2c_done_pulse(bm_hc_d2c_done_pulse),
        .exec_done_pulse(hc_exec_done_pulse),
        .intr_clr(intr_clr),
        .intr_clr_vld(intr_clr_vld),
        .xdma_usr_irq_req(xdma_usr_irq_req)
    );
endmodule
