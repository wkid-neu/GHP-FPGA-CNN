//Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2022.1 (lin64) Build 3526262 Mon Apr 18 15:47:01 MDT 2022
//Date        : Sun Nov 10 21:06:18 2024
//Host        : lvxing-System-Product-Name running 64-bit Ubuntu 20.04.6 LTS
//Command     : generate_target verify_top.bd
//Design      : verify_top
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

(* CORE_GENERATION_INFO = "verify_top,IP_Integrator,{x_ipVendor=xilinx.com,x_ipLibrary=BlockDiagram,x_ipName=verify_top,x_ipVersion=1.00.a,x_ipLanguage=VERILOG,numBlks=4,numReposBlks=4,numNonXlnxBlks=0,numHierBlks=0,maxHierDepth=0,numSysgenBlks=0,numHlsBlks=0,numHdlrefBlks=1,numPkgbdBlks=0,bdsource=USER,synth_mode=OOC_per_IP}" *) (* HW_HANDOFF = "verify_top.hwdef" *) 
module verify_top
   (main_clk,
    main_rst,
    sa_clk);
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 CLK.MAIN_CLK CLK" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME CLK.MAIN_CLK, ASSOCIATED_RESET main_rst, CLK_DOMAIN verify_top_main_clk, FREQ_HZ 250000000, FREQ_TOLERANCE_HZ 0, INSERT_VIP 0, PHASE 0.0" *) input main_clk;
  (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 RST.MAIN_RST RST" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME RST.MAIN_RST, INSERT_VIP 0, POLARITY ACTIVE_HIGH" *) input main_rst;
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 CLK.SA_CLK CLK" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME CLK.SA_CLK, CLK_DOMAIN verify_top_sa_clk, FREQ_HZ 398437500, FREQ_TOLERANCE_HZ 0, INSERT_VIP 0, PHASE 0.0" *) input sa_clk;

  wire main_clk_0_1;
  wire main_rst_0_1;
  wire sa_clk_0_1;
  wire [31:0]sr_cr_M_AXI_ARADDR;
  wire [2:0]sr_cr_M_AXI_ARPROT;
  wire sr_cr_M_AXI_ARREADY;
  wire sr_cr_M_AXI_ARVALID;
  wire [31:0]sr_cr_M_AXI_AWADDR;
  wire [2:0]sr_cr_M_AXI_AWPROT;
  wire sr_cr_M_AXI_AWREADY;
  wire sr_cr_M_AXI_AWVALID;
  wire sr_cr_M_AXI_BREADY;
  wire [1:0]sr_cr_M_AXI_BRESP;
  wire sr_cr_M_AXI_BVALID;
  wire [31:0]sr_cr_M_AXI_RDATA;
  wire sr_cr_M_AXI_RREADY;
  wire [1:0]sr_cr_M_AXI_RRESP;
  wire sr_cr_M_AXI_RVALID;
  wire [31:0]sr_cr_M_AXI_WDATA;
  wire sr_cr_M_AXI_WREADY;
  wire [3:0]sr_cr_M_AXI_WSTRB;
  wire sr_cr_M_AXI_WVALID;
  wire [31:0]top_dma_m_axi_ARADDR;
  wire [1:0]top_dma_m_axi_ARBURST;
  wire [3:0]top_dma_m_axi_ARCACHE;
  wire [7:0]top_dma_m_axi_ARID;
  wire [7:0]top_dma_m_axi_ARLEN;
  wire top_dma_m_axi_ARLOCK;
  wire [2:0]top_dma_m_axi_ARPROT;
  wire top_dma_m_axi_ARREADY;
  wire [2:0]top_dma_m_axi_ARSIZE;
  wire top_dma_m_axi_ARVALID;
  wire [31:0]top_dma_m_axi_AWADDR;
  wire [1:0]top_dma_m_axi_AWBURST;
  wire [3:0]top_dma_m_axi_AWCACHE;
  wire [7:0]top_dma_m_axi_AWID;
  wire [7:0]top_dma_m_axi_AWLEN;
  wire top_dma_m_axi_AWLOCK;
  wire [2:0]top_dma_m_axi_AWPROT;
  wire top_dma_m_axi_AWREADY;
  wire [2:0]top_dma_m_axi_AWSIZE;
  wire top_dma_m_axi_AWVALID;
  wire [7:0]top_dma_m_axi_BID;
  wire top_dma_m_axi_BREADY;
  wire [1:0]top_dma_m_axi_BRESP;
  wire top_dma_m_axi_BVALID;
  wire [511:0]top_dma_m_axi_RDATA;
  wire [7:0]top_dma_m_axi_RID;
  wire top_dma_m_axi_RLAST;
  wire top_dma_m_axi_RREADY;
  wire [1:0]top_dma_m_axi_RRESP;
  wire top_dma_m_axi_RVALID;
  wire [511:0]top_dma_m_axi_WDATA;
  wire top_dma_m_axi_WLAST;
  wire top_dma_m_axi_WREADY;
  wire [63:0]top_dma_m_axi_WSTRB;
  wire top_dma_m_axi_WVALID;
  wire [0:0]util_vector_logic_0_Res;

  assign main_clk_0_1 = main_clk;
  assign main_rst_0_1 = main_rst;
  assign sa_clk_0_1 = sa_clk;
  verify_top_axi_vip_0_1 ddr
       (.aclk(main_clk_0_1),
        .aresetn(util_vector_logic_0_Res),
        .s_axi_araddr(top_dma_m_axi_ARADDR),
        .s_axi_arburst(top_dma_m_axi_ARBURST),
        .s_axi_arcache(top_dma_m_axi_ARCACHE),
        .s_axi_arid(top_dma_m_axi_ARID),
        .s_axi_arlen(top_dma_m_axi_ARLEN),
        .s_axi_arlock(top_dma_m_axi_ARLOCK),
        .s_axi_arprot(top_dma_m_axi_ARPROT),
        .s_axi_arready(top_dma_m_axi_ARREADY),
        .s_axi_arsize(top_dma_m_axi_ARSIZE),
        .s_axi_arvalid(top_dma_m_axi_ARVALID),
        .s_axi_awaddr(top_dma_m_axi_AWADDR),
        .s_axi_awburst(top_dma_m_axi_AWBURST),
        .s_axi_awcache(top_dma_m_axi_AWCACHE),
        .s_axi_awid(top_dma_m_axi_AWID),
        .s_axi_awlen(top_dma_m_axi_AWLEN),
        .s_axi_awlock(top_dma_m_axi_AWLOCK),
        .s_axi_awprot(top_dma_m_axi_AWPROT),
        .s_axi_awready(top_dma_m_axi_AWREADY),
        .s_axi_awsize(top_dma_m_axi_AWSIZE),
        .s_axi_awvalid(top_dma_m_axi_AWVALID),
        .s_axi_bid(top_dma_m_axi_BID),
        .s_axi_bready(top_dma_m_axi_BREADY),
        .s_axi_bresp(top_dma_m_axi_BRESP),
        .s_axi_bvalid(top_dma_m_axi_BVALID),
        .s_axi_rdata(top_dma_m_axi_RDATA),
        .s_axi_rid(top_dma_m_axi_RID),
        .s_axi_rlast(top_dma_m_axi_RLAST),
        .s_axi_rready(top_dma_m_axi_RREADY),
        .s_axi_rresp(top_dma_m_axi_RRESP),
        .s_axi_rvalid(top_dma_m_axi_RVALID),
        .s_axi_wdata(top_dma_m_axi_WDATA),
        .s_axi_wlast(top_dma_m_axi_WLAST),
        .s_axi_wready(top_dma_m_axi_WREADY),
        .s_axi_wstrb(top_dma_m_axi_WSTRB),
        .s_axi_wvalid(top_dma_m_axi_WVALID));
  verify_top_axi_vip_0_0 sr_cr
       (.aclk(main_clk_0_1),
        .aresetn(util_vector_logic_0_Res),
        .m_axi_araddr(sr_cr_M_AXI_ARADDR),
        .m_axi_arprot(sr_cr_M_AXI_ARPROT),
        .m_axi_arready(sr_cr_M_AXI_ARREADY),
        .m_axi_arvalid(sr_cr_M_AXI_ARVALID),
        .m_axi_awaddr(sr_cr_M_AXI_AWADDR),
        .m_axi_awprot(sr_cr_M_AXI_AWPROT),
        .m_axi_awready(sr_cr_M_AXI_AWREADY),
        .m_axi_awvalid(sr_cr_M_AXI_AWVALID),
        .m_axi_bready(sr_cr_M_AXI_BREADY),
        .m_axi_bresp(sr_cr_M_AXI_BRESP),
        .m_axi_bvalid(sr_cr_M_AXI_BVALID),
        .m_axi_rdata(sr_cr_M_AXI_RDATA),
        .m_axi_rready(sr_cr_M_AXI_RREADY),
        .m_axi_rresp(sr_cr_M_AXI_RRESP),
        .m_axi_rvalid(sr_cr_M_AXI_RVALID),
        .m_axi_wdata(sr_cr_M_AXI_WDATA),
        .m_axi_wready(sr_cr_M_AXI_WREADY),
        .m_axi_wstrb(sr_cr_M_AXI_WSTRB),
        .m_axi_wvalid(sr_cr_M_AXI_WVALID));
  verify_top_top_0 top
       (.dma_m_axi_araddr(top_dma_m_axi_ARADDR),
        .dma_m_axi_arburst(top_dma_m_axi_ARBURST),
        .dma_m_axi_arcache(top_dma_m_axi_ARCACHE),
        .dma_m_axi_arid(top_dma_m_axi_ARID),
        .dma_m_axi_arlen(top_dma_m_axi_ARLEN),
        .dma_m_axi_arlock(top_dma_m_axi_ARLOCK),
        .dma_m_axi_arprot(top_dma_m_axi_ARPROT),
        .dma_m_axi_arready(top_dma_m_axi_ARREADY),
        .dma_m_axi_arsize(top_dma_m_axi_ARSIZE),
        .dma_m_axi_arvalid(top_dma_m_axi_ARVALID),
        .dma_m_axi_awaddr(top_dma_m_axi_AWADDR),
        .dma_m_axi_awburst(top_dma_m_axi_AWBURST),
        .dma_m_axi_awcache(top_dma_m_axi_AWCACHE),
        .dma_m_axi_awid(top_dma_m_axi_AWID),
        .dma_m_axi_awlen(top_dma_m_axi_AWLEN),
        .dma_m_axi_awlock(top_dma_m_axi_AWLOCK),
        .dma_m_axi_awprot(top_dma_m_axi_AWPROT),
        .dma_m_axi_awready(top_dma_m_axi_AWREADY),
        .dma_m_axi_awsize(top_dma_m_axi_AWSIZE),
        .dma_m_axi_awvalid(top_dma_m_axi_AWVALID),
        .dma_m_axi_bid(top_dma_m_axi_BID),
        .dma_m_axi_bready(top_dma_m_axi_BREADY),
        .dma_m_axi_bresp(top_dma_m_axi_BRESP),
        .dma_m_axi_bvalid(top_dma_m_axi_BVALID),
        .dma_m_axi_rdata(top_dma_m_axi_RDATA),
        .dma_m_axi_rid(top_dma_m_axi_RID),
        .dma_m_axi_rlast(top_dma_m_axi_RLAST),
        .dma_m_axi_rready(top_dma_m_axi_RREADY),
        .dma_m_axi_rresp(top_dma_m_axi_RRESP),
        .dma_m_axi_rvalid(top_dma_m_axi_RVALID),
        .dma_m_axi_wdata(top_dma_m_axi_WDATA),
        .dma_m_axi_wlast(top_dma_m_axi_WLAST),
        .dma_m_axi_wready(top_dma_m_axi_WREADY),
        .dma_m_axi_wstrb(top_dma_m_axi_WSTRB),
        .dma_m_axi_wvalid(top_dma_m_axi_WVALID),
        .main_clk(main_clk_0_1),
        .main_rst(main_rst_0_1),
        .sa_clk(sa_clk_0_1),
        .sr_cr_S_AXI_ARADDR(sr_cr_M_AXI_ARADDR[7:0]),
        .sr_cr_S_AXI_ARPROT(sr_cr_M_AXI_ARPROT),
        .sr_cr_S_AXI_ARREADY(sr_cr_M_AXI_ARREADY),
        .sr_cr_S_AXI_ARVALID(sr_cr_M_AXI_ARVALID),
        .sr_cr_S_AXI_AWADDR(sr_cr_M_AXI_AWADDR[7:0]),
        .sr_cr_S_AXI_AWPROT(sr_cr_M_AXI_AWPROT),
        .sr_cr_S_AXI_AWREADY(sr_cr_M_AXI_AWREADY),
        .sr_cr_S_AXI_AWVALID(sr_cr_M_AXI_AWVALID),
        .sr_cr_S_AXI_BREADY(sr_cr_M_AXI_BREADY),
        .sr_cr_S_AXI_BRESP(sr_cr_M_AXI_BRESP),
        .sr_cr_S_AXI_BVALID(sr_cr_M_AXI_BVALID),
        .sr_cr_S_AXI_RDATA(sr_cr_M_AXI_RDATA),
        .sr_cr_S_AXI_RREADY(sr_cr_M_AXI_RREADY),
        .sr_cr_S_AXI_RRESP(sr_cr_M_AXI_RRESP),
        .sr_cr_S_AXI_RVALID(sr_cr_M_AXI_RVALID),
        .sr_cr_S_AXI_WDATA(sr_cr_M_AXI_WDATA),
        .sr_cr_S_AXI_WREADY(sr_cr_M_AXI_WREADY),
        .sr_cr_S_AXI_WSTRB(sr_cr_M_AXI_WSTRB),
        .sr_cr_S_AXI_WVALID(sr_cr_M_AXI_WVALID));
  verify_top_util_vector_logic_0_0 util_vector_logic_0
       (.Op1(main_rst_0_1),
        .Res(util_vector_logic_0_Res));
endmodule
