// (c) Copyright 1995-2024 Xilinx, Inc. All rights reserved.
// 
// This file contains confidential and proprietary information
// of Xilinx, Inc. and is protected under U.S. and
// international copyright and other intellectual property
// laws.
// 
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// Xilinx, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) Xilinx shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or Xilinx had been advised of the
// possibility of the same.
// 
// CRITICAL APPLICATIONS
// Xilinx products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of Xilinx products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
// 
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
// 
// DO NOT MODIFY THIS FILE.


// IP VLNV: xilinx.com:module_ref:top:1.0
// IP Revision: 1

`timescale 1ns/1ps

(* IP_DEFINITION_SOURCE = "module_ref" *)
(* DowngradeIPIdentifiedWarnings = "yes" *)
module verify_top_top_0 (
  main_clk,
  sa_clk,
  main_rst,
  sr_cr_S_AXI_AWADDR,
  sr_cr_S_AXI_AWPROT,
  sr_cr_S_AXI_AWVALID,
  sr_cr_S_AXI_AWREADY,
  sr_cr_S_AXI_WDATA,
  sr_cr_S_AXI_WSTRB,
  sr_cr_S_AXI_WVALID,
  sr_cr_S_AXI_WREADY,
  sr_cr_S_AXI_BRESP,
  sr_cr_S_AXI_BVALID,
  sr_cr_S_AXI_BREADY,
  sr_cr_S_AXI_ARADDR,
  sr_cr_S_AXI_ARPROT,
  sr_cr_S_AXI_ARVALID,
  sr_cr_S_AXI_ARREADY,
  sr_cr_S_AXI_RDATA,
  sr_cr_S_AXI_RRESP,
  sr_cr_S_AXI_RVALID,
  sr_cr_S_AXI_RREADY,
  dma_m_axi_awid,
  dma_m_axi_awaddr,
  dma_m_axi_awlen,
  dma_m_axi_awsize,
  dma_m_axi_awburst,
  dma_m_axi_awlock,
  dma_m_axi_awcache,
  dma_m_axi_awprot,
  dma_m_axi_awvalid,
  dma_m_axi_awready,
  dma_m_axi_wdata,
  dma_m_axi_wstrb,
  dma_m_axi_wlast,
  dma_m_axi_wvalid,
  dma_m_axi_wready,
  dma_m_axi_bid,
  dma_m_axi_bresp,
  dma_m_axi_bvalid,
  dma_m_axi_bready,
  dma_m_axi_arid,
  dma_m_axi_araddr,
  dma_m_axi_arlen,
  dma_m_axi_arsize,
  dma_m_axi_arburst,
  dma_m_axi_arlock,
  dma_m_axi_arcache,
  dma_m_axi_arprot,
  dma_m_axi_arvalid,
  dma_m_axi_arready,
  dma_m_axi_rid,
  dma_m_axi_rdata,
  dma_m_axi_rresp,
  dma_m_axi_rlast,
  dma_m_axi_rvalid,
  dma_m_axi_rready,
  xdma_usr_irq_req
);

(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME main_clk, ASSOCIATED_RESET main_rst, ASSOCIATED_BUSIF sr_cr_S_AXI:dma_m_axi, FREQ_HZ 250000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN verify_top_main_clk, INSERT_VIP 0" *)
(* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 main_clk CLK" *)
input wire main_clk;
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME sa_clk, FREQ_HZ 398437500, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN verify_top_sa_clk, INSERT_VIP 0" *)
(* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 sa_clk CLK" *)
input wire sa_clk;
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME main_rst, POLARITY ACTIVE_HIGH, INSERT_VIP 0" *)
(* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 main_rst RST" *)
input wire main_rst;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 sr_cr_S_AXI AWADDR" *)
input wire [7 : 0] sr_cr_S_AXI_AWADDR;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 sr_cr_S_AXI AWPROT" *)
input wire [2 : 0] sr_cr_S_AXI_AWPROT;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 sr_cr_S_AXI AWVALID" *)
input wire sr_cr_S_AXI_AWVALID;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 sr_cr_S_AXI AWREADY" *)
output wire sr_cr_S_AXI_AWREADY;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 sr_cr_S_AXI WDATA" *)
input wire [31 : 0] sr_cr_S_AXI_WDATA;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 sr_cr_S_AXI WSTRB" *)
input wire [3 : 0] sr_cr_S_AXI_WSTRB;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 sr_cr_S_AXI WVALID" *)
input wire sr_cr_S_AXI_WVALID;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 sr_cr_S_AXI WREADY" *)
output wire sr_cr_S_AXI_WREADY;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 sr_cr_S_AXI BRESP" *)
output wire [1 : 0] sr_cr_S_AXI_BRESP;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 sr_cr_S_AXI BVALID" *)
output wire sr_cr_S_AXI_BVALID;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 sr_cr_S_AXI BREADY" *)
input wire sr_cr_S_AXI_BREADY;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 sr_cr_S_AXI ARADDR" *)
input wire [7 : 0] sr_cr_S_AXI_ARADDR;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 sr_cr_S_AXI ARPROT" *)
input wire [2 : 0] sr_cr_S_AXI_ARPROT;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 sr_cr_S_AXI ARVALID" *)
input wire sr_cr_S_AXI_ARVALID;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 sr_cr_S_AXI ARREADY" *)
output wire sr_cr_S_AXI_ARREADY;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 sr_cr_S_AXI RDATA" *)
output wire [31 : 0] sr_cr_S_AXI_RDATA;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 sr_cr_S_AXI RRESP" *)
output wire [1 : 0] sr_cr_S_AXI_RRESP;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 sr_cr_S_AXI RVALID" *)
output wire sr_cr_S_AXI_RVALID;
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME sr_cr_S_AXI, DATA_WIDTH 32, PROTOCOL AXI4LITE, FREQ_HZ 250000000, ID_WIDTH 0, ADDR_WIDTH 8, AWUSER_WIDTH 0, ARUSER_WIDTH 0, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_WRITE, HAS_BURST 0, HAS_LOCK 0, HAS_PROT 1, HAS_CACHE 0, HAS_QOS 0, HAS_REGION 0, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 0, NUM_READ_OUTSTANDING 1, NUM_WRITE_OUTSTANDING 1, MAX_BURST_LENGTH 1, PHASE 0.0, CLK_DOMAIN verify_top_main_clk, NUM_READ_THREADS 1, NUM_WRITE_THRE\
ADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0" *)
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 sr_cr_S_AXI RREADY" *)
input wire sr_cr_S_AXI_RREADY;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma_m_axi AWID" *)
output wire [7 : 0] dma_m_axi_awid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma_m_axi AWADDR" *)
output wire [31 : 0] dma_m_axi_awaddr;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma_m_axi AWLEN" *)
output wire [7 : 0] dma_m_axi_awlen;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma_m_axi AWSIZE" *)
output wire [2 : 0] dma_m_axi_awsize;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma_m_axi AWBURST" *)
output wire [1 : 0] dma_m_axi_awburst;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma_m_axi AWLOCK" *)
output wire dma_m_axi_awlock;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma_m_axi AWCACHE" *)
output wire [3 : 0] dma_m_axi_awcache;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma_m_axi AWPROT" *)
output wire [2 : 0] dma_m_axi_awprot;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma_m_axi AWVALID" *)
output wire dma_m_axi_awvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma_m_axi AWREADY" *)
input wire dma_m_axi_awready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma_m_axi WDATA" *)
output wire [511 : 0] dma_m_axi_wdata;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma_m_axi WSTRB" *)
output wire [63 : 0] dma_m_axi_wstrb;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma_m_axi WLAST" *)
output wire dma_m_axi_wlast;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma_m_axi WVALID" *)
output wire dma_m_axi_wvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma_m_axi WREADY" *)
input wire dma_m_axi_wready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma_m_axi BID" *)
input wire [7 : 0] dma_m_axi_bid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma_m_axi BRESP" *)
input wire [1 : 0] dma_m_axi_bresp;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma_m_axi BVALID" *)
input wire dma_m_axi_bvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma_m_axi BREADY" *)
output wire dma_m_axi_bready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma_m_axi ARID" *)
output wire [7 : 0] dma_m_axi_arid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma_m_axi ARADDR" *)
output wire [31 : 0] dma_m_axi_araddr;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma_m_axi ARLEN" *)
output wire [7 : 0] dma_m_axi_arlen;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma_m_axi ARSIZE" *)
output wire [2 : 0] dma_m_axi_arsize;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma_m_axi ARBURST" *)
output wire [1 : 0] dma_m_axi_arburst;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma_m_axi ARLOCK" *)
output wire dma_m_axi_arlock;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma_m_axi ARCACHE" *)
output wire [3 : 0] dma_m_axi_arcache;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma_m_axi ARPROT" *)
output wire [2 : 0] dma_m_axi_arprot;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma_m_axi ARVALID" *)
output wire dma_m_axi_arvalid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma_m_axi ARREADY" *)
input wire dma_m_axi_arready;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma_m_axi RID" *)
input wire [7 : 0] dma_m_axi_rid;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma_m_axi RDATA" *)
input wire [511 : 0] dma_m_axi_rdata;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma_m_axi RRESP" *)
input wire [1 : 0] dma_m_axi_rresp;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma_m_axi RLAST" *)
input wire dma_m_axi_rlast;
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma_m_axi RVALID" *)
input wire dma_m_axi_rvalid;
(* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME dma_m_axi, DATA_WIDTH 512, PROTOCOL AXI4, FREQ_HZ 250000000, ID_WIDTH 8, ADDR_WIDTH 32, AWUSER_WIDTH 0, ARUSER_WIDTH 0, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_WRITE, HAS_BURST 1, HAS_LOCK 1, HAS_PROT 1, HAS_CACHE 1, HAS_QOS 0, HAS_REGION 0, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, SUPPORTS_NARROW_BURST 1, NUM_READ_OUTSTANDING 2, NUM_WRITE_OUTSTANDING 2, MAX_BURST_LENGTH 256, PHASE 0.0, CLK_DOMAIN verify_top_main_clk, NUM_READ_THREADS 1, NUM_WRITE_THREAD\
S 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0" *)
(* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 dma_m_axi RREADY" *)
output wire dma_m_axi_rready;
output wire [15 : 0] xdma_usr_irq_req;

  top inst (
    .main_clk(main_clk),
    .sa_clk(sa_clk),
    .main_rst(main_rst),
    .sr_cr_S_AXI_AWADDR(sr_cr_S_AXI_AWADDR),
    .sr_cr_S_AXI_AWPROT(sr_cr_S_AXI_AWPROT),
    .sr_cr_S_AXI_AWVALID(sr_cr_S_AXI_AWVALID),
    .sr_cr_S_AXI_AWREADY(sr_cr_S_AXI_AWREADY),
    .sr_cr_S_AXI_WDATA(sr_cr_S_AXI_WDATA),
    .sr_cr_S_AXI_WSTRB(sr_cr_S_AXI_WSTRB),
    .sr_cr_S_AXI_WVALID(sr_cr_S_AXI_WVALID),
    .sr_cr_S_AXI_WREADY(sr_cr_S_AXI_WREADY),
    .sr_cr_S_AXI_BRESP(sr_cr_S_AXI_BRESP),
    .sr_cr_S_AXI_BVALID(sr_cr_S_AXI_BVALID),
    .sr_cr_S_AXI_BREADY(sr_cr_S_AXI_BREADY),
    .sr_cr_S_AXI_ARADDR(sr_cr_S_AXI_ARADDR),
    .sr_cr_S_AXI_ARPROT(sr_cr_S_AXI_ARPROT),
    .sr_cr_S_AXI_ARVALID(sr_cr_S_AXI_ARVALID),
    .sr_cr_S_AXI_ARREADY(sr_cr_S_AXI_ARREADY),
    .sr_cr_S_AXI_RDATA(sr_cr_S_AXI_RDATA),
    .sr_cr_S_AXI_RRESP(sr_cr_S_AXI_RRESP),
    .sr_cr_S_AXI_RVALID(sr_cr_S_AXI_RVALID),
    .sr_cr_S_AXI_RREADY(sr_cr_S_AXI_RREADY),
    .dma_m_axi_awid(dma_m_axi_awid),
    .dma_m_axi_awaddr(dma_m_axi_awaddr),
    .dma_m_axi_awlen(dma_m_axi_awlen),
    .dma_m_axi_awsize(dma_m_axi_awsize),
    .dma_m_axi_awburst(dma_m_axi_awburst),
    .dma_m_axi_awlock(dma_m_axi_awlock),
    .dma_m_axi_awcache(dma_m_axi_awcache),
    .dma_m_axi_awprot(dma_m_axi_awprot),
    .dma_m_axi_awvalid(dma_m_axi_awvalid),
    .dma_m_axi_awready(dma_m_axi_awready),
    .dma_m_axi_wdata(dma_m_axi_wdata),
    .dma_m_axi_wstrb(dma_m_axi_wstrb),
    .dma_m_axi_wlast(dma_m_axi_wlast),
    .dma_m_axi_wvalid(dma_m_axi_wvalid),
    .dma_m_axi_wready(dma_m_axi_wready),
    .dma_m_axi_bid(dma_m_axi_bid),
    .dma_m_axi_bresp(dma_m_axi_bresp),
    .dma_m_axi_bvalid(dma_m_axi_bvalid),
    .dma_m_axi_bready(dma_m_axi_bready),
    .dma_m_axi_arid(dma_m_axi_arid),
    .dma_m_axi_araddr(dma_m_axi_araddr),
    .dma_m_axi_arlen(dma_m_axi_arlen),
    .dma_m_axi_arsize(dma_m_axi_arsize),
    .dma_m_axi_arburst(dma_m_axi_arburst),
    .dma_m_axi_arlock(dma_m_axi_arlock),
    .dma_m_axi_arcache(dma_m_axi_arcache),
    .dma_m_axi_arprot(dma_m_axi_arprot),
    .dma_m_axi_arvalid(dma_m_axi_arvalid),
    .dma_m_axi_arready(dma_m_axi_arready),
    .dma_m_axi_rid(dma_m_axi_rid),
    .dma_m_axi_rdata(dma_m_axi_rdata),
    .dma_m_axi_rresp(dma_m_axi_rresp),
    .dma_m_axi_rlast(dma_m_axi_rlast),
    .dma_m_axi_rvalid(dma_m_axi_rvalid),
    .dma_m_axi_rready(dma_m_axi_rready),
    .xdma_usr_irq_req(xdma_usr_irq_req)
  );
endmodule
