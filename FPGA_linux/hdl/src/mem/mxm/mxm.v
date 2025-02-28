`timescale 1ns / 1ps
`include "../../incl.vh"

//
// Matrix X memory
//
module mxm (
    input clk,
    // write ports
    input wr_en,
    input [`P*2*8-1:0] din,
    // Write flags (From the writer's viewpoint)
    output reg prog_full = 0,
    // Read ports from Conv
    input is_conv,
    input [15:0] conv_vec_size,
    input [15:0] conv_vec_size_minus_1,
    input conv_rd_en,
    input conv_rd_last_rnd,
    output [`P*2*8-1:0] conv_dout,
    output conv_dout_vld,
    // Read ports from Pool
    input is_pool,
    input [15:0] pool_vec_size,
    input [15:0] pool_vec_size_minus_1,
    input pool_rd_en,
    input pool_rd_last_rnd,
    output [`P*2*8-1:0] pool_dout,
    output pool_dout_vld,
    // Read flags (from the reader's viewpoint)
    output reg empty = 1,
    output reg almost_empty = 1
);
    localparam MEM_PRT_WIDTH = $clog2(`MXM_DEPTH);

    wire rd_en;
    wire rd_last_rnd;
    reg [15:0] vec_size = 0;
    reg [15:0] vec_size_minus_1 = 0;

    reg mem_rd_en = 0;
    reg [$clog2(`MXM_DEPTH)-1:0] mem_rd_addr = 0;
    wire [`P*2*8-1:0] mem_dout;
    wire mem_dout_vld;
    wire mem_wr_en;
    wire [$clog2(`MXM_DEPTH)-1:0] mem_wr_addr;
    wire [`P*2*8-1:0] mem_din;

    assign rd_en = ((is_conv && conv_rd_en) || (is_pool && pool_rd_en));
    assign rd_last_rnd = (is_conv ? conv_rd_last_rnd : pool_rd_last_rnd);

    always @(posedge clk)
        if (is_conv) begin
            vec_size <= conv_vec_size;
            vec_size_minus_1 <= conv_vec_size_minus_1;
        end else begin
            vec_size <= pool_vec_size;
            vec_size_minus_1 <= pool_vec_size_minus_1;
        end

    //
    // Read
    //
    reg [MEM_PRT_WIDTH:0] rd_cnt = 0, rd_cnt_next;
    reg [MEM_PRT_WIDTH-1:0] rnd_base_addr = 0;
    reg [MEM_PRT_WIDTH-1:0] ele_cnt = 0;

    always @(*) begin
        case ({rd_en, wr_en, rd_last_rnd})
            3'b000: rd_cnt_next = rd_cnt;
            3'b001: rd_cnt_next = rd_cnt;
            3'b010: rd_cnt_next = rd_cnt+1;
            3'b011: rd_cnt_next = rd_cnt+1;
            3'b100: begin
                if (ele_cnt==vec_size_minus_1)
                    rd_cnt_next = rd_cnt+vec_size_minus_1;
                else
                    rd_cnt_next = rd_cnt-1;
            end
            3'b101: rd_cnt_next = rd_cnt-1;
            3'b110: begin
                if (ele_cnt==vec_size_minus_1)
                    rd_cnt_next = rd_cnt+vec_size;
                else
                    rd_cnt_next = rd_cnt;
            end
            3'b111: rd_cnt_next = rd_cnt;
        endcase
    end

    // rd_cnt
    always @(posedge clk)
        rd_cnt <= rd_cnt_next;

    // rnd_base_addr
    always @(posedge clk)
        if (rd_en && rd_last_rnd && ele_cnt==vec_size_minus_1)
            rnd_base_addr <= rnd_base_addr+vec_size;

    // ele_cnt
    always @(posedge clk) 
        if (rd_en)
            if (ele_cnt==vec_size_minus_1)
                ele_cnt <= 0;
            else
                ele_cnt <= ele_cnt+1;

    // empty, almost_empty
    always @(posedge clk) begin
        empty <= (rd_cnt_next==0);
        almost_empty <= (rd_cnt_next==0 || rd_cnt_next==1);
    end

    // One additional clock cycle latency for timing optimization
    always @(posedge clk) begin
        mem_rd_en <= rd_en;
        mem_rd_addr <= rnd_base_addr+ele_cnt;
    end

    //
    // Write
    //
    reg [MEM_PRT_WIDTH:0] wr_cnt = 0, wr_cnt_next;
    reg [MEM_PRT_WIDTH-1:0] wr_ptr = 0;

    always @(*) begin
        case ({rd_en, wr_en, rd_last_rnd})
            3'b000: wr_cnt_next = wr_cnt;
            3'b001: wr_cnt_next = wr_cnt;
            3'b010: wr_cnt_next = wr_cnt+1;
            3'b011: wr_cnt_next = wr_cnt+1;
            3'b100: wr_cnt_next = wr_cnt;
            3'b101: wr_cnt_next = wr_cnt-1;
            3'b110: wr_cnt_next = wr_cnt+1;
            3'b111: wr_cnt_next = wr_cnt;
        endcase
    end

    // wr_cnt
    always @(posedge clk)
        wr_cnt <= wr_cnt_next;

    // wr_ptr
    always @(posedge clk)
        wr_ptr <= wr_ptr+wr_en;

    assign mem_wr_en = wr_en;
    assign mem_wr_addr = wr_ptr;
    assign mem_din = din;

    // prog_full
    always @(posedge clk)
        prog_full <= (wr_cnt_next>`MXM_PROG_FULL);

    // Outputs
    assign conv_dout = mem_dout;
    assign conv_dout_vld = mem_dout_vld && is_conv;
    assign pool_dout = mem_dout;
    assign pool_dout_vld = mem_dout_vld && ~is_conv;

    mxm_mem mxm_mem_inst(
    	.clk(clk),
        .rd_en(mem_rd_en),
        .rd_addr(mem_rd_addr),
        .dout(mem_dout),
        .wr_en(mem_wr_en),
        .wr_addr(mem_wr_addr),
        .din(mem_din)
    );

    shift_reg #(`MXM_NUM_PIPE+1, 1) shift_reg_inst(clk, mem_rd_en, mem_dout_vld);
endmodule
