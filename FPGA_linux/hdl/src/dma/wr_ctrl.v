`timescale 1ns / 1ps
`include "../incl.vh"

//
// Write controller of DMA
//
module dma_wr_ctrl (
    input clk,
    // AXI write descriptor
    output reg enable = 0,
    output reg [`DDR_AXI_ADDR_WIDTH-1:0] desc_addr = 0,
    output reg [`DDR_LEN_WIDTH-1:0] desc_len = 0,
    output reg desc_valid = 0,
    input desc_ready, 
    input desc_status_valid,
    // AXI stream write data input
    output reg [`DDR_AXIS_DATA_WIDTH-1:0] write_data_tdata = 0,
    output [`DDR_AXIS_KEEP_WIDTH-1:0] write_data_tkeep,
    output reg write_data_tvalid = 0,
    input write_data_tready,
    output reg write_data_tlast = 0,
    // RTM
    input [`DDR_AXI_ADDR_WIDTH-1:0] rtm_dma_desc_addr,
    input [`DDR_LEN_WIDTH-1:0] rtm_dma_desc_len,
    input rtm_dma_desc_valid,
    output reg rtm_dma_desc_status_valid = 0,
    input [`DDR_AXIS_DATA_WIDTH-1:0] rtm_dma_write_data_tdata,
    input rtm_dma_write_data_tvalid,
    output reg rtm_dma_write_data_tready = 0,
    input rtm_dma_write_data_tlast
);
    // enable
    always @(posedge clk)
        if (rtm_dma_desc_valid)
            enable <= 1;
        else if (desc_status_valid)
            enable <= 0;

    // desc_addr, desc_len, desc_valid
    always @(posedge clk) begin
        if (rtm_dma_desc_valid) begin
            desc_addr <= rtm_dma_desc_addr;
            desc_len <= rtm_dma_desc_len;
        end

        if (rtm_dma_desc_valid)
            desc_valid <= 1;
        else if (desc_valid && desc_ready)
            desc_valid <= 0;
    end
    
    always @(*) begin
        write_data_tdata = rtm_dma_write_data_tdata;
        write_data_tvalid = rtm_dma_write_data_tvalid;
        write_data_tlast = rtm_dma_write_data_tlast;
        rtm_dma_desc_status_valid = desc_status_valid;
        rtm_dma_write_data_tready = write_data_tready;
    end

    assign write_data_tkeep = {`DDR_AXIS_KEEP_WIDTH{1'b1}};
endmodule

