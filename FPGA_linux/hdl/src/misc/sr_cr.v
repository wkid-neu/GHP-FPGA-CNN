`timescale 1ns / 1ps
`include "../incl.vh"

// slv_reg0 [15:0] Clear interruption of XDMA, assert corresponding bit to clear interruption. RW
// slv_reg0 [31:16] Clear signal is valid or not, RW
// slv_reg0[0], slv_reg0[16] Interruption of transferring instructions from DRAM to IM
// slv_reg0[1], slv_reg0[17] Interruption of transferring data from DRAM to RTM
// slv_reg0[2], slv_reg0[18] Interruption of transferring data from RTM to DRAM
// slv_reg0[3], slv_reg0[19] Interruption of transferring data from DRAM to XPHM
// slv_reg0[4], slv_reg0[20] Interrupt of transferring weights from DRAM to CWM
// slv_reg0[5], slv_reg0[21] Interrupt of transferring bias from DRAM to BM
// slv_reg0[6], slv_reg0[22] Interrupt of inferring

// slv_reg60[0] start transferring instructions from DRAM to IM, RW 
// slv_reg59[31:0] instructions address in DDR4, RW 
// slv_reg58[31:0] number of bytes of this transfer, RW 

// slv_reg50[0] start transferring data from DRAM to RTM, RW 
// slv_reg49[31:0] address in DRAM, RW 
// slv_reg48[31:0] address in RTM, RW 
// slv_reg47[31:0] number of bytes, RW 
// slv_reg46[0] start transferring data from RTM to DRAM, RW
// slv_reg45[31:0] address in DRAM, RW 
// slv_reg44[31:0] address in RTM, RW 
// slv_reg43[31:0] number of bytes, RW

// slv_reg40[0] start transferring data from DRAM to XPHM, RW 
// slv_reg39[31:0] address in DRAM, RW 
// slv_reg38[31:0] address in XPHM, RW 
// slv_reg37[31:0] number of bytes, RW

// slv_reg30[0] start transferring weights from DRAM to CWM, RW
// slv_reg29[31:0] address in DRAM, RW 
// slv_reg28[31:0] address in CWM, RW 
// slv_reg27[31:0] number of bytes, RW

// slv_reg20[0] start transferring bias from DRAM to BM, RW
// slv_reg19[31:0] address in DRAM, RW 
// slv_reg18[31:0] address in BM, RW 
// slv_reg17[31:0] number of bytes, RW

// slv_reg10[0] start inferring, RW
// slv_reg9[31:0] latency of the CONV instruction, R 
// slv_reg8[31:0] latency of the POOL instruction, R 
// slv_reg7[31:0] latency of the ADD instruction, R 
// slv_reg6[31:0] latency of the REMAP instruction, R 
// slv_reg5[31:0] latency of the FC instruction, R 

module sr_cr(
	// AXI4LITE interface
    input wire  S_AXI_ACLK,
    input wire  S_AXI_ARESETN,
    input wire [`SR_CR_AXI_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
    input wire [2 : 0] S_AXI_AWPROT,
    input wire  S_AXI_AWVALID,
    output wire  S_AXI_AWREADY,
    input wire [`SR_CR_AXI_DATA_WIDTH-1 : 0] S_AXI_WDATA,   
    input wire [(`SR_CR_AXI_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
    input wire  S_AXI_WVALID,
    output wire  S_AXI_WREADY,
    output wire [1 : 0] S_AXI_BRESP,
    output wire  S_AXI_BVALID,
    input wire  S_AXI_BREADY,
    input wire [`SR_CR_AXI_ADDR_WIDTH-1 : 0] S_AXI_ARADDR,
    input wire [2 : 0] S_AXI_ARPROT,
    input wire  S_AXI_ARVALID,
    output wire  S_AXI_ARREADY,
    output wire [`SR_CR_AXI_DATA_WIDTH-1 : 0] S_AXI_RDATA,
    output wire [1 : 0] S_AXI_RRESP,
    output wire  S_AXI_RVALID,
    input wire  S_AXI_RREADY,
	// Instrcution Memory (IM)
	output wire im_d2c_start_pulse,
	output reg [31:0] im_d2c_d_addr = 0,
	output reg [31:0] im_d2c_n_bytes = 0,
	// Runtime Tensor Memory (RTM)
	output wire rtm_d2c_start_pulse,
	output reg [31:0] rtm_d2c_d_addr = 0,
	output reg [31:0] rtm_d2c_c_addr = 0,
	output reg [31:0] rtm_d2c_n_bytes = 0,
	output wire rtm_c2d_start_pulse,
	output reg [31:0] rtm_c2d_d_addr = 0,
	output reg [31:0] rtm_c2d_c_addr = 0,
	output reg [31:0] rtm_c2d_n_bytes = 0,
	// Convolution Weight Memory (CWM)
	output wire cwm_d2c_start_pulse,
	output reg [31:0] cwm_d2c_d_addr = 0,
	output reg [31:0] cwm_d2c_c_addr = 0,
	output reg [31:0] cwm_d2c_n_bytes = 0,
	// Bias Memory (BM)
	output wire bm_d2c_start_pulse,
	output reg [31:0] bm_d2c_d_addr = 0,
	output reg [31:0] bm_d2c_c_addr = 0,
	output reg [31:0] bm_d2c_n_bytes = 0,
	// X packer header memory (XPHM)
	output wire xphm_d2c_start_pulse,
	output reg [31:0] xphm_d2c_d_addr = 0,
	output reg [31:0] xphm_d2c_c_addr = 0,
	output reg [31:0] xphm_d2c_n_bytes = 0,
	// Executor
	output wire exec_start_pulse,
	input wire [31:0] conv_latency,
	input wire [31:0] pool_latency,
	input wire [31:0] add_latency,
	input wire [31:0] remap_latency,
	input wire [31:0] fc_latency,
	// XDMA usr irq
    output wire [`XDMA_USR_INTR_COUNT-1:0] intr_clr,
    output wire [`XDMA_USR_INTR_COUNT-1:0] intr_clr_vld
);
    // Width of S_AXI data bus
    localparam integer C_S_AXI_DATA_WIDTH = `SR_CR_AXI_DATA_WIDTH;
    // Width of S_AXI address bus
    localparam integer C_S_AXI_ADDR_WIDTH = `SR_CR_AXI_ADDR_WIDTH;
    // Interrupt count of XDMA, 1...16
    localparam integer XDMA_USR_INTR_COUNT = `XDMA_USR_INTR_COUNT;

	// AXI4LITE signals
	reg [C_S_AXI_ADDR_WIDTH-1 : 0] 	axi_awaddr;
	reg  	axi_awready;
	reg  	axi_wready;
	reg [1 : 0] 	axi_bresp;
	reg  	axi_bvalid;
	reg [C_S_AXI_ADDR_WIDTH-1 : 0] 	axi_araddr;
	reg  	axi_arready;
	reg [C_S_AXI_DATA_WIDTH-1 : 0] 	axi_rdata;
	reg [1 : 0] 	axi_rresp;
	reg  	axi_rvalid;

	// Example-specific design signals
	// local parameter for addressing 32 bit / 64 bit C_S_AXI_DATA_WIDTH
	// ADDR_LSB is used for addressing 32/64 bit registers/memories
	// ADDR_LSB = 2 for 32 bits (n downto 2)
	// ADDR_LSB = 3 for 64 bits (n downto 3)
	localparam integer ADDR_LSB = (C_S_AXI_DATA_WIDTH/32) + 1;
	localparam integer OPT_MEM_ADDR_BITS = 5;
	//----------------------------------------------
	//-- Signals for user logic register space example
	//------------------------------------------------
	//-- Number of Slave Registers 64
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg0 = 0;
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg1 = 0; 
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg2 = 0; 
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg3 = 0; 
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg4 = 0; 
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg5 = 0; 
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg6 = 0; 
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg7 = 0; 
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg8 = 0; 
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg9 = 0; 
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg10 = 0;
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg11 = 0;
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg12 = 0;
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg13 = 0;
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg14 = 0;
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg15 = 0;
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg16 = 0;
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg17 = 0;
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg18 = 0;
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg19 = 0;
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg20 = 0;
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg21 = 0;
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg22 = 0;
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg23 = 0;
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg24 = 0;
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg25 = 0;
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg26 = 0;
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg27 = 0;
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg28 = 0;
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg29 = 0;
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg30 = 0;
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg31 = 0;
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg32 = 0;
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg33 = 0;
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg34 = 0;
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg35 = 0;
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg36 = 0;
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg37 = 0;
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg38 = 0;
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg39 = 0;
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg40 = 0;
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg41 = 0;
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg42 = 0;
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg43 = 0;
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg44 = 0;
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg45 = 0;
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg46 = 0;
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg47 = 0;
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg48 = 0;
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg49 = 0;
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg50 = 0;
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg51 = 0;
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg52 = 0;
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg53 = 0;
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg54 = 0;
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg55 = 0;
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg56 = 0;
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg57 = 0;
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg58 = 0;
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg59 = 0;
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg60 = 0;
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg61 = 0;
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg62 = 0;
	reg [C_S_AXI_DATA_WIDTH-1:0]    slv_reg63 = 0;
	wire	 slv_reg_rden;
	wire	 slv_reg_wren;
	reg [C_S_AXI_DATA_WIDTH-1:0]	 reg_data_out;
	integer	 byte_index;
	reg	 aw_en;

	// I/O Connections assignments
	assign S_AXI_AWREADY	= axi_awready;
	assign S_AXI_WREADY	= axi_wready;
	assign S_AXI_BRESP	= axi_bresp;
	assign S_AXI_BVALID	= axi_bvalid;
	assign S_AXI_ARREADY	= axi_arready;
	assign S_AXI_RDATA	= axi_rdata;
	assign S_AXI_RRESP	= axi_rresp;
	assign S_AXI_RVALID	= axi_rvalid;
	// Implement axi_awready generation
	// axi_awready is asserted for one S_AXI_ACLK clock cycle when both
	// S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_awready is
	// de-asserted when reset is low.

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_awready <= 1'b0;
	      aw_en <= 1'b1;
	    end 
	  else
	    begin    
	      if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en)
	        begin
	          // slave is ready to accept write address when 
	          // there is a valid write address and write data
	          // on the write address and data bus. This design 
	          // expects no outstanding transactions. 
	          axi_awready <= 1'b1;
	          aw_en <= 1'b0;
	        end
	        else if (S_AXI_BREADY && axi_bvalid)
	            begin
	              aw_en <= 1'b1;
	              axi_awready <= 1'b0;
	            end
	      else           
	        begin
	          axi_awready <= 1'b0;
	        end
	    end 
	end       

	// Implement axi_awaddr latching
	// This process is used to latch the address when both 
	// S_AXI_AWVALID and S_AXI_WVALID are valid. 

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_awaddr <= 0;
	    end 
	  else
	    begin    
	      if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en)
	        begin
	          // Write Address latching 
	          axi_awaddr <= S_AXI_AWADDR;
	        end
	    end 
	end       

	// Implement axi_wready generation
	// axi_wready is asserted for one S_AXI_ACLK clock cycle when both
	// S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_wready is 
	// de-asserted when reset is low. 

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_wready <= 1'b0;
	    end 
	  else
	    begin    
	      if (~axi_wready && S_AXI_WVALID && S_AXI_AWVALID && aw_en )
	        begin
	          // slave is ready to accept write data when 
	          // there is a valid write address and write data
	          // on the write address and data bus. This design 
	          // expects no outstanding transactions. 
	          axi_wready <= 1'b1;
	        end
	      else
	        begin
	          axi_wready <= 1'b0;
	        end
	    end 
	end       

	// Implement memory mapped register select and write logic generation
	// The write data is accepted and written to memory mapped registers when
	// axi_awready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted. Write strobes are used to
	// select byte enables of slave registers while writing.
	// These registers are cleared when reset (active low) is applied.
	// Slave register write enable is asserted when valid address and data are available
	// and the slave is ready to accept the write address and write data.
	assign slv_reg_wren = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID;

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      slv_reg0 <= 0;
		  slv_reg1 <= 0;
	      slv_reg2 <= 0;
	      slv_reg3 <= 0;
	      slv_reg4 <= 0;
	    //   slv_reg5 <= 0;
	    //   slv_reg6 <= 0;
	    //   slv_reg7 <= 0;
	    //   slv_reg8 <= 0;
	    //   slv_reg9 <= 0;
	      slv_reg10 <= 0;
	      slv_reg11 <= 0;
	      slv_reg12 <= 0;
	      slv_reg13 <= 0;
	      slv_reg14 <= 0;
	      slv_reg15 <= 0;
	      slv_reg16 <= 0;
	      slv_reg17 <= 0;
	      slv_reg18 <= 0;
	      slv_reg19 <= 0;
	      slv_reg20 <= 0;
	      slv_reg21 <= 0;
	      slv_reg22 <= 0;
	      slv_reg23 <= 0;
	      slv_reg24 <= 0;
	      slv_reg25 <= 0;
	      slv_reg26 <= 0;
	      slv_reg27 <= 0;
	      slv_reg28 <= 0;
	      slv_reg29 <= 0;
	      slv_reg30 <= 0;
	      slv_reg31 <= 0;
	      slv_reg32 <= 0;
	      slv_reg33 <= 0;
	      slv_reg34 <= 0;
	      slv_reg35 <= 0;
	      slv_reg36 <= 0;
	      slv_reg37 <= 0;
	      slv_reg38 <= 0;
	      slv_reg39 <= 0;
	      slv_reg40 <= 0;
	      slv_reg41 <= 0;
	      slv_reg42 <= 0;
	      slv_reg43 <= 0;
	      slv_reg44 <= 0;
	      slv_reg45 <= 0;
	      slv_reg46 <= 0;
	      slv_reg47 <= 0;
	      slv_reg48 <= 0;
	      slv_reg49 <= 0;
	      slv_reg50 <= 0;
	      slv_reg51 <= 0;
	      slv_reg52 <= 0;
	      slv_reg53 <= 0;
	      slv_reg54 <= 0;
	      slv_reg55 <= 0;
	      slv_reg56 <= 0;
	      slv_reg57 <= 0;
	      slv_reg58 <= 0;
	      slv_reg59 <= 0;
		  slv_reg60 <= 0;
	      slv_reg61 <= 0;
	      slv_reg62 <= 0;
	      slv_reg63 <= 0;
	    end 
	  else begin
	    if (slv_reg_wren)
	      begin
	        case ( axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] )
	          6'h00:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 0
	                slv_reg0[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          6'h01:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 1
	                slv_reg1[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          6'h02:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 2
	                slv_reg2[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          6'h03:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 3
	                slv_reg3[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end 
	          6'h04:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 4
	                slv_reg4[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          6'h05:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 5
	                // slv_reg5[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end
	          6'h06:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 6
	                // slv_reg6[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          6'h07:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 7
	                // slv_reg7[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          6'h08:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 8
	                // slv_reg8[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          6'h09:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 9
	                // slv_reg9[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          6'h0A:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 10
	                slv_reg10[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end
	          6'h0B:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 11
	                slv_reg11[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end 
	          6'h0C:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 12
	                slv_reg12[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end 
	          6'h0D:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 13
	                slv_reg13[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end 
	          6'h0E:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 14
	                slv_reg14[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end 
	          6'h0F:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 15
	                slv_reg15[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end 
	          6'h10:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 16
	                slv_reg16[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end
	          6'h11:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 17
	                slv_reg17[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          6'h12:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 18
	                slv_reg18[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          6'h13:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 19
	                slv_reg19[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          6'h14:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 20
	                slv_reg20[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          6'h15:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 21
	                slv_reg21[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          6'h16:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 22
	                slv_reg22[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          6'h17:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 23
	                slv_reg23[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          6'h18:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 24
	                slv_reg24[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          6'h19:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 25
	                slv_reg25[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          6'h1A:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 26
	                slv_reg26[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          6'h1B:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 27
	                slv_reg27[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          6'h1C:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 28
	                slv_reg28[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          6'h1D:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 29
	                slv_reg29[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          6'h1E:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 30
	                slv_reg30[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          6'h1F:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 31
	                slv_reg31[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          6'h20:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 32
	                slv_reg32[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          6'h21:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 33
	                slv_reg33[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          6'h22:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 34
	                slv_reg34[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          6'h23:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 35
	                slv_reg35[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          6'h24:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 36
	                slv_reg36[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          6'h25:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 37
	                slv_reg37[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          6'h26:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 38
	                slv_reg38[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          6'h27:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 39
	                slv_reg39[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          6'h28:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 40
	                slv_reg40[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          6'h29:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 41
	                slv_reg41[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          6'h2A:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 42
	                slv_reg42[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          6'h2B:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 43
	                slv_reg43[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          6'h2C:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 44
	                slv_reg44[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          6'h2D:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 45
	                slv_reg45[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          6'h2E:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 46
	                slv_reg46[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          6'h2F:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 47
	                slv_reg47[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          6'h30:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 48
	                slv_reg48[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          6'h31:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 49
	                slv_reg49[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          6'h32:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 50
	                slv_reg50[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          6'h33:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 51
	                slv_reg51[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          6'h34:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 52
	                slv_reg52[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          6'h35:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 53
	                slv_reg53[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          6'h36:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 54
	                slv_reg54[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          6'h37:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 55
	                slv_reg55[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          6'h38:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 56
	                slv_reg56[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          6'h39:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 57
	                slv_reg57[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          6'h3A:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 58
	                slv_reg58[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          6'h3B:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 59
	                slv_reg59[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          6'h3C:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 60
	                slv_reg60[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          6'h3D:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 61
	                slv_reg61[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          6'h3E:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 62
	                slv_reg62[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          6'h3F:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 63
	                slv_reg63[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          default : ;
	        endcase
	      end
	  end
	end    

	// Implement write response logic generation
	// The write response and response valid signals are asserted by the slave 
	// when axi_wready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted.  
	// This marks the acceptance of address and indicates the status of 
	// write transaction.

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_bvalid  <= 0;
	      axi_bresp   <= 2'b0;
	    end 
	  else
	    begin    
	      if (axi_awready && S_AXI_AWVALID && ~axi_bvalid && axi_wready && S_AXI_WVALID)
	        begin
	          // indicates a valid write response is available
	          axi_bvalid <= 1'b1;
	          axi_bresp  <= 2'b0; // 'OKAY' response 
	        end                   // work error responses in future
	      else
	        begin
	          if (S_AXI_BREADY && axi_bvalid) 
	            //check if bready is asserted while bvalid is high) 
	            //(there is a possibility that bready is always asserted high)   
	            begin
	              axi_bvalid <= 1'b0; 
	            end  
	        end
	    end
	end   

	// Implement axi_arready generation
	// axi_arready is asserted for one S_AXI_ACLK clock cycle when
	// S_AXI_ARVALID is asserted. axi_awready is 
	// de-asserted when reset (active low) is asserted. 
	// The read address is also latched when S_AXI_ARVALID is 
	// asserted. axi_araddr is reset to zero on reset assertion.

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_arready <= 1'b0;
	      axi_araddr  <= 32'b0;
	    end 
	  else
	    begin    
	      if (~axi_arready && S_AXI_ARVALID)
	        begin
	          // indicates that the slave has acceped the valid read address
	          axi_arready <= 1'b1;
	          // Read address latching
	          axi_araddr  <= S_AXI_ARADDR;
	        end
	      else
	        begin
	          axi_arready <= 1'b0;
	        end
	    end 
	end       

	// Implement axi_arvalid generation
	// axi_rvalid is asserted for one S_AXI_ACLK clock cycle when both 
	// S_AXI_ARVALID and axi_arready are asserted. The slave registers 
	// data are available on the axi_rdata bus at this instance. The 
	// assertion of axi_rvalid marks the validity of read data on the 
	// bus and axi_rresp indicates the status of read transaction.axi_rvalid 
	// is deasserted on reset (active low). axi_rresp and axi_rdata are 
	// cleared to zero on reset (active low).  
	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_rvalid <= 0;
	      axi_rresp  <= 0;
	    end 
	  else
	    begin    
	      if (axi_arready && S_AXI_ARVALID && ~axi_rvalid)
	        begin
	          // Valid read data is available at the read data bus
	          axi_rvalid <= 1'b1;
	          axi_rresp  <= 2'b0; // 'OKAY' response
	        end   
	      else if (axi_rvalid && S_AXI_RREADY)
	        begin
	          // Read data is accepted by the master
	          axi_rvalid <= 1'b0;
	        end                
	    end
	end    

	// Implement memory mapped register select and read logic generation
	// Slave register read enable is asserted when valid address is available
	// and the slave is ready to accept the read address.
	assign slv_reg_rden = axi_arready & S_AXI_ARVALID & ~axi_rvalid;
	always @(*)
	begin
	      // Address decoding for reading registers
	      case ( axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] )
	        6'h00   : reg_data_out <= slv_reg0;
	        6'h01   : reg_data_out <= slv_reg1;
	        6'h02   : reg_data_out <= slv_reg2;
	        6'h03   : reg_data_out <= slv_reg3;
	        6'h04   : reg_data_out <= slv_reg4;
	        6'h05   : reg_data_out <= slv_reg5;
	        6'h06   : reg_data_out <= slv_reg6;
	        6'h07   : reg_data_out <= slv_reg7;
	        6'h08   : reg_data_out <= slv_reg8;
	        6'h09   : reg_data_out <= slv_reg9;
	        6'h0A   : reg_data_out <= slv_reg10;
	        6'h0B   : reg_data_out <= slv_reg11;
	        6'h0C   : reg_data_out <= slv_reg12;
	        6'h0D   : reg_data_out <= slv_reg13;
	        6'h0E   : reg_data_out <= slv_reg14;
	        6'h0F   : reg_data_out <= slv_reg15;
	        6'h10   : reg_data_out <= slv_reg16;
	        6'h11   : reg_data_out <= slv_reg17;
	        6'h12   : reg_data_out <= slv_reg18;
	        6'h13   : reg_data_out <= slv_reg19;
	        6'h14   : reg_data_out <= slv_reg20;
	        6'h15   : reg_data_out <= slv_reg21;
	        6'h16   : reg_data_out <= slv_reg22;
	        6'h17   : reg_data_out <= slv_reg23;
	        6'h18   : reg_data_out <= slv_reg24;
	        6'h19   : reg_data_out <= slv_reg25;
	        6'h1A   : reg_data_out <= slv_reg26;
	        6'h1B   : reg_data_out <= slv_reg27;
	        6'h1C   : reg_data_out <= slv_reg28;
	        6'h1D   : reg_data_out <= slv_reg29;
	        6'h1E   : reg_data_out <= slv_reg30;
	        6'h1F   : reg_data_out <= slv_reg31;
	        6'h20   : reg_data_out <= slv_reg32;
	        6'h21   : reg_data_out <= slv_reg33;
	        6'h22   : reg_data_out <= slv_reg34;
	        6'h23   : reg_data_out <= slv_reg35;
	        6'h24   : reg_data_out <= slv_reg36;
	        6'h25   : reg_data_out <= slv_reg37;
	        6'h26   : reg_data_out <= slv_reg38;
	        6'h27   : reg_data_out <= slv_reg39;
	        6'h28   : reg_data_out <= slv_reg40;
	        6'h29   : reg_data_out <= slv_reg41;
	        6'h2A   : reg_data_out <= slv_reg42;
	        6'h2B   : reg_data_out <= slv_reg43;
	        6'h2C   : reg_data_out <= slv_reg44;
	        6'h2D   : reg_data_out <= slv_reg45;
	        6'h2E   : reg_data_out <= slv_reg46;
	        6'h2F   : reg_data_out <= slv_reg47;
	        6'h30   : reg_data_out <= slv_reg48;
	        6'h31   : reg_data_out <= slv_reg49;
	        6'h32   : reg_data_out <= slv_reg50;
	        6'h33   : reg_data_out <= slv_reg51;
	        6'h34   : reg_data_out <= slv_reg52;
	        6'h35   : reg_data_out <= slv_reg53;
	        6'h36   : reg_data_out <= slv_reg54;
	        6'h37   : reg_data_out <= slv_reg55;
	        6'h38   : reg_data_out <= slv_reg56;
	        6'h39   : reg_data_out <= slv_reg57;
	        6'h3A   : reg_data_out <= slv_reg58;
	        6'h3B   : reg_data_out <= slv_reg59;
	        6'h3C   : reg_data_out <= slv_reg60;
	        6'h3D   : reg_data_out <= slv_reg61;
	        6'h3E   : reg_data_out <= slv_reg62;
	        6'h3F   : reg_data_out <= slv_reg63;
	        default : reg_data_out <= 0;
	      endcase
	end

	// Output register or memory read data
	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_rdata  <= 0;
	    end 
	  else
	    begin    
	      // When there is a valid read address (S_AXI_ARVALID) with 
	      // acceptance of read address by the slave (axi_arready), 
	      // output the read dada 
	      if (slv_reg_rden)
	        begin
	          axi_rdata <= reg_data_out;     // register read data
	        end   
	    end
	end 

	//
	// Instrcution Memory (IM)
	//
	posedge_det posedge_det_im(S_AXI_ACLK, slv_reg60[0], im_d2c_start_pulse);
	always @(posedge S_AXI_ACLK) begin
		im_d2c_d_addr <= slv_reg59;
		im_d2c_n_bytes <= slv_reg58;
	end

	//
	// Runtime Tensor Memory (RTM)
	//
	posedge_det posedge_det_rtm_d2c(S_AXI_ACLK, slv_reg50[0], rtm_d2c_start_pulse);
	posedge_det posedge_det_rtm_c2d(S_AXI_ACLK, slv_reg46[0], rtm_c2d_start_pulse);
	always @(posedge S_AXI_ACLK) begin
		rtm_d2c_d_addr <= slv_reg49;
		rtm_d2c_c_addr <= slv_reg48;
		rtm_d2c_n_bytes <= slv_reg47;
		rtm_c2d_d_addr <= slv_reg45;
		rtm_c2d_c_addr <= slv_reg44;
		rtm_c2d_n_bytes <= slv_reg43;
	end
	
	//
	// Convolution Weight Memory (CWM)
	//
	posedge_det posedge_det_cwm(S_AXI_ACLK, slv_reg30[0], cwm_d2c_start_pulse);
	always @(posedge S_AXI_ACLK) begin
		cwm_d2c_d_addr <= slv_reg29;
		cwm_d2c_c_addr <= slv_reg28;
		cwm_d2c_n_bytes <= slv_reg27;
	end

	//
	// Bias Memory (BM)
	//
	posedge_det posedge_det_bm(S_AXI_ACLK, slv_reg20[0], bm_d2c_start_pulse);
	always @(posedge S_AXI_ACLK) begin
		bm_d2c_d_addr <= slv_reg19;
		bm_d2c_c_addr <= slv_reg18;
		bm_d2c_n_bytes <= slv_reg17; 
	end

	//
	// X packer header memory (XPHM)
	//
	posedge_det posedge_det_xphm(S_AXI_ACLK, slv_reg40[0], xphm_d2c_start_pulse);
	always @(posedge S_AXI_ACLK) begin
		xphm_d2c_d_addr <= slv_reg39;
		xphm_d2c_c_addr <= slv_reg38;
		xphm_d2c_n_bytes <= slv_reg37; 
	end

	//
	// Executor
	//
	posedge_det posedge_det_exec(S_AXI_ACLK, slv_reg10[0], exec_start_pulse);
	always @(posedge S_AXI_ACLK) begin
		slv_reg9 <= conv_latency;
		slv_reg8 <= pool_latency;
		slv_reg7 <= add_latency;
		slv_reg6 <= remap_latency;
		slv_reg5 <= fc_latency;
	end

	//
	// XDMA usr irq
	//
    assign intr_clr = slv_reg0[XDMA_USR_INTR_COUNT-1:0];
    assign intr_clr_vld = slv_reg0[XDMA_USR_INTR_COUNT+15:16];
endmodule
