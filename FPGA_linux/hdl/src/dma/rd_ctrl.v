`timescale 1ns / 1ps
`include "../incl.vh"

//
// Read controller of AXI DMA
//
module dma_rd_ctrl (
    input clk,
    // AXI read descriptor input
    output reg enable = 0,
    output reg [`DDR_AXI_ADDR_WIDTH-1:0] desc_addr = 0,
    output reg [`DDR_LEN_WIDTH-1:0] desc_len = 0,
    output reg desc_valid = 0,
    input desc_ready,
    // AXI stream read data output
    input [`DDR_AXIS_DATA_WIDTH-1:0] read_data_tdata,
    input [`DDR_AXIS_KEEP_WIDTH-1:0] read_data_tkeep,
    input read_data_tvalid,
    output reg read_data_tready = 0,
    input read_data_tlast,
    // 
    // RTM
    //
    input [`DDR_AXI_ADDR_WIDTH-1:0] rtm_dma_desc_addr,
    input [`DDR_LEN_WIDTH-1:0] rtm_dma_desc_len,
    input rtm_dma_desc_valid,
    output reg [`DDR_AXIS_DATA_WIDTH-1:0] rtm_dma_read_data_tdata = 0,
    output reg rtm_dma_read_data_tvalid = 0,
    output reg rtm_dma_read_data_tlast = 0,
    // 
    // IM
    //
    input [`DDR_AXI_ADDR_WIDTH-1:0] im_dma_desc_addr,
    input [`DDR_LEN_WIDTH-1:0] im_dma_desc_len,
    input im_dma_desc_valid,
    output reg [`DDR_AXIS_DATA_WIDTH-1:0] im_dma_read_data_tdata = 0,
    output reg im_dma_read_data_tvalid = 0,
    output reg im_dma_read_data_tlast = 0,
    //
    // BM
    //
    input [`DDR_AXI_ADDR_WIDTH-1:0] bm_dma_desc_addr,
    input [`DDR_LEN_WIDTH-1:0] bm_dma_desc_len,
    input bm_dma_desc_valid,
    output reg [`DDR_AXIS_DATA_WIDTH-1:0] bm_dma_read_data_tdata = 0,
    output reg bm_dma_read_data_tvalid = 0,
    output reg bm_dma_read_data_tlast = 0,
    //
    // XPHM
    //
    input [`DDR_AXI_ADDR_WIDTH-1:0] xphm_dma_desc_addr,
    input [`DDR_LEN_WIDTH-1:0] xphm_dma_desc_len,
    input xphm_dma_desc_valid,
    output reg [`DDR_AXIS_DATA_WIDTH-1:0] xphm_dma_read_data_tdata = 0,
    output reg xphm_dma_read_data_tvalid = 0,
    output reg xphm_dma_read_data_tlast = 0,
    //
    // CWM
    //
    input [`DDR_AXI_ADDR_WIDTH-1:0] cwm_dma_desc_addr,
    input [`DDR_LEN_WIDTH-1:0] cwm_dma_desc_len,
    input cwm_dma_desc_valid,
    output reg [`DDR_AXIS_DATA_WIDTH-1:0] cwm_dma_read_data_tdata = 0,
    output reg cwm_dma_read_data_tvalid = 0,
    output reg cwm_dma_read_data_tlast = 0,
    //
    // Fully-connected weights
    //
    input [`DDR_AXI_ADDR_WIDTH-1:0] fcws_dma_desc_addr,
    input [`DDR_LEN_WIDTH-1:0] fcws_dma_desc_len,
    input fcws_dma_desc_valid,
    output reg [`DDR_AXIS_DATA_WIDTH-1:0] fcws_dma_read_data_tdata = 0,
    output reg fcws_dma_read_data_tvalid = 0,
    input fcws_dma_read_data_tready,
    output reg fcws_dma_read_data_tlast = 0
);
    localparam IDLE = 0,
        RTM = 1,
        INS = 2,
        BIAS = 3,
        XPHS = 4,
        CWS = 5,
        FCWS = 6;
    reg [2:0] state = IDLE;
    reg [2:0] next_state;

    always @(*)
        case (state)
            IDLE: begin
                if (rtm_dma_desc_valid)
                    next_state = RTM;
                else if (im_dma_desc_valid)
                    next_state = INS;
                else if (bm_dma_desc_valid)
                    next_state = BIAS;
                else if (xphm_dma_desc_valid)
                    next_state = XPHS;
                else if (cwm_dma_desc_valid)
                    next_state = CWS;
                else if (fcws_dma_desc_valid)
                    next_state = FCWS;
                else
                    next_state = IDLE;
            end
            RTM: next_state = (read_data_tvalid && read_data_tready && read_data_tlast) ? IDLE : RTM;
            INS: next_state = (read_data_tvalid && read_data_tready && read_data_tlast) ? IDLE : INS;
            BIAS: next_state = (read_data_tvalid && read_data_tready && read_data_tlast) ? IDLE : BIAS;
            XPHS: next_state = (read_data_tvalid && read_data_tready && read_data_tlast) ? IDLE : XPHS;
            CWS: next_state = (read_data_tvalid && read_data_tready && read_data_tlast) ? IDLE : CWS;
            FCWS: next_state = (read_data_tvalid && read_data_tready && read_data_tlast) ? IDLE : FCWS;
            default: next_state = IDLE;
        endcase

    always @(posedge clk)
        state <= next_state;

    // desc_addr, desc_len, desc_valid
    always @(posedge clk) begin
        if (rtm_dma_desc_valid) begin
            desc_addr <= rtm_dma_desc_addr;
            desc_len <= rtm_dma_desc_len;
        end else if (im_dma_desc_valid) begin
            desc_addr <= im_dma_desc_addr;
            desc_len <= im_dma_desc_len;
        end else if (bm_dma_desc_valid) begin
            desc_addr <= bm_dma_desc_addr;
            desc_len <= bm_dma_desc_len;
        end else if (xphm_dma_desc_valid) begin
            desc_addr <= xphm_dma_desc_addr;
            desc_len <= xphm_dma_desc_len;
        end else if (cwm_dma_desc_valid) begin
            desc_addr <= cwm_dma_desc_addr;
            desc_len <= cwm_dma_desc_len;
        end else if (fcws_dma_desc_valid) begin
            desc_addr <= fcws_dma_desc_addr;
            desc_len <= fcws_dma_desc_len;
        end

        if (rtm_dma_desc_valid || im_dma_desc_valid || bm_dma_desc_valid || xphm_dma_desc_valid || cwm_dma_desc_valid || fcws_dma_desc_valid)
            desc_valid <= 1;
        else if (desc_valid && desc_ready)
            desc_valid <= 0;
    end

    // enable, read_data_tready
    always @(*) begin
        enable = (state != IDLE);

        case (state)
            RTM: read_data_tready = 1;
            INS: read_data_tready = 1;
            BIAS: read_data_tready = 1;
            XPHS: read_data_tready = 1;
            CWS: read_data_tready = 1;
            FCWS: read_data_tready = fcws_dma_read_data_tready;
            default: read_data_tready = 0;
        endcase
    end

    // RTM
    always @(*) begin
        rtm_dma_read_data_tdata = read_data_tdata;
        rtm_dma_read_data_tvalid = (state==RTM) && read_data_tvalid;
        rtm_dma_read_data_tlast = read_data_tlast;
    end

    // Instrcution
    always @(*) begin
        im_dma_read_data_tdata = read_data_tdata;
        im_dma_read_data_tvalid = (state==INS) && read_data_tvalid;
        im_dma_read_data_tlast = read_data_tlast;
    end

    // Bias
    always @(*) begin
        bm_dma_read_data_tdata = read_data_tdata;
        bm_dma_read_data_tvalid = (state==BIAS) && read_data_tvalid;
        bm_dma_read_data_tlast = read_data_tlast;
    end

    // X packet headers
    always @(*) begin
        xphm_dma_read_data_tdata = read_data_tdata;
        xphm_dma_read_data_tvalid = (state==XPHS) && read_data_tvalid;
        xphm_dma_read_data_tlast = read_data_tlast;
    end

    // Convloution weights
    always @(*) begin
        cwm_dma_read_data_tdata = read_data_tdata;
        cwm_dma_read_data_tvalid = (state==CWS) && read_data_tvalid;
        cwm_dma_read_data_tlast = read_data_tlast;
    end

    // Fully-connected weights
    always @(*) begin
        fcws_dma_read_data_tdata = read_data_tdata;
        fcws_dma_read_data_tvalid = (state==FCWS) && read_data_tvalid;
        fcws_dma_read_data_tlast = read_data_tlast;
    end
endmodule

