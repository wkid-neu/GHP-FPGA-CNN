`timescale 1ns / 1ps
`include "../../../incl.vh"

//
// This module generates the write-back descriptors.
//
module Conv_wb_desc_fifo_wr (
    input clk,
    input start_pulse,
    // Instruction
    input [$clog2(`RTM_DEPTH)-1:0] Y_addr,
    input [15:0] n_W_rnd_minus_1,
    input [15:0] n_X_rnd_minus_1,
    input [15:0] ofm_height,
    input [7:0] n_last_batch,
    // fifo write ports
    output fifo_wr_en,
    output [$clog2(`RTM_DEPTH)-1:0] fifo_din_addr,
    output fifo_din_mask,
    output fifo_din_last,
    input fifo_prog_full
);
    // Parameter Assertions
    initial begin
        if (`S!=4 && `S!=8) begin
            $error("Hyper parameter mismatch, please make sure that S in {4, 8}, current values are: S = %0d", `S);
            $finish;
        end
    end

    generate
        if (`S==4) begin
            Conv_wb_desc_fifo_wr_S_4 Conv_wb_desc_fifo_wr_S_4_inst(
                .clk(clk),
                .start_pulse(start_pulse),
                .Y_addr(Y_addr),
                .n_W_rnd_minus_1(n_W_rnd_minus_1),
                .n_X_rnd_minus_1(n_X_rnd_minus_1),
                .ofm_height(ofm_height),
                .n_last_batch(n_last_batch),
                .fifo_wr_en(fifo_wr_en),
                .fifo_din_addr(fifo_din_addr),
                .fifo_din_mask(fifo_din_mask),
                .fifo_din_last(fifo_din_last),
                .fifo_prog_full(fifo_prog_full)
            );
        end else if (`S==8) begin
            Conv_wb_desc_fifo_wr_S_8 Conv_wb_desc_fifo_wr_S_8_inst(
                .clk(clk),
                .start_pulse(start_pulse),
                .Y_addr(Y_addr),
                .n_W_rnd_minus_1(n_W_rnd_minus_1),
                .n_X_rnd_minus_1(n_X_rnd_minus_1),
                .ofm_height(ofm_height),
                .n_last_batch(n_last_batch),
                .fifo_wr_en(fifo_wr_en),
                .fifo_din_addr(fifo_din_addr),
                .fifo_din_mask(fifo_din_mask),
                .fifo_din_last(fifo_din_last),
                .fifo_prog_full(fifo_prog_full)
            );
        end
    endgenerate
endmodule

//
// S==4.
//
module Conv_wb_desc_fifo_wr_S_4 (
    input clk,
    input start_pulse,
    // Instruction
    input [$clog2(`RTM_DEPTH)-1:0] Y_addr,
    input [15:0] n_W_rnd_minus_1,
    input [15:0] n_X_rnd_minus_1,
    input [15:0] ofm_height,
    input [7:0] n_last_batch,
    // fifo write ports
    output reg fifo_wr_en = 0,
    output reg [$clog2(`RTM_DEPTH)-1:0] fifo_din_addr = 0,
    output reg fifo_din_mask = 0,
    output reg fifo_din_last = 0,
    input fifo_prog_full
);
    // Parameter Assertions
    initial begin
        if (`S!=4) begin
            $error("Hyper parameter mismatch, please make sure that S==4, current values are: S = %0d", `S);
            $finish;
        end
    end

    // N1 rows will come one after one.
    localparam N1 = `P/`R;

    reg counting = 0;
    // counters
    reg [$clog2(N1+1)-1:0] n1_cnt = 0;  // The ideal width is $clog2(N1), use $clog2(N1+1) to support N1=1 
    reg [1:0] inner_blk_cnt = 0;  // There are four rows of fms in a block
    reg [$clog2(`M/8)-1:0] blk_cnt = 0;
    reg [15:0] w_cnt = 0;
    reg [15:0] x_cnt = 0;
    // basic addresses
    reg [$clog2(`RTM_DEPTH)-1:0] w_base = 0;
    reg [$clog2(`RTM_DEPTH)-1:0] blk_base = 0;
    reg [$clog2(`RTM_DEPTH)-1:0] inner_blk_base = 0;
    reg [$clog2(`RTM_DEPTH)-1:0] fm_base = 0;
    // Compute the final address according to basic addresses and the n1_cnt.
    // final_addr = w_base+blk_base+inner_blk_base+fm_base+n1_cnt
    // Manage this process as pipeline to achieve better performance.
    // Pipeline stage1
    reg [$clog2(`RTM_DEPTH)-1:0] addr1_1 = 0;  // w_base+blk_base
    reg [$clog2(`RTM_DEPTH)-1:0] addr1_2 = 0;  // inner_blk_base+fm_base
    reg [$clog2(N1+1)-1:0] n1_cnt1 = 0;  // n1_cnt
    reg last_x_rnd = 0;
    reg vld1 = 0, last1 = 0;
    // Pipeline stage2
    reg [$clog2(`RTM_DEPTH)-1:0] addr2 = 0;  // addr1_1+addr1_2
    reg [$clog2(N1+1)-1:0] n1_cnt2 = 0;  // n1_cnt1
    reg mask2 = 0;
    reg vld2 = 0, last2 = 0;
    // Pipeline stage3 (Output)

    // counting
    always @(posedge clk)
        if (start_pulse)
            counting <= 1;
        else if (counting && ~fifo_prog_full && n1_cnt==N1-1 && inner_blk_cnt==3 && blk_cnt==`M/8-1 && w_cnt==n_W_rnd_minus_1 && x_cnt==n_X_rnd_minus_1)
            counting <= 0;

    // n1_cnt
    always @(posedge clk)
        if (counting && ~fifo_prog_full) begin
            if (n1_cnt==N1-1)
                n1_cnt <= 0;
            else
                n1_cnt <= n1_cnt+1;
        end

    // inner_blk_cnt
    always @(posedge clk)
        if (counting && ~fifo_prog_full && n1_cnt==N1-1) begin
            if (inner_blk_cnt==3)
                inner_blk_cnt <= 0;
            else
                inner_blk_cnt <= inner_blk_cnt+1;
        end

    // blk_cnt
    always @(posedge clk)
        if (counting && ~fifo_prog_full && n1_cnt==N1-1 && inner_blk_cnt==3) begin
            if (blk_cnt==`M/8-1)
                blk_cnt <= 0;
            else
                blk_cnt <= blk_cnt+1;
        end

    // w_cnt
    always @(posedge clk)
        if (counting && ~fifo_prog_full && n1_cnt==N1-1 && inner_blk_cnt==3 && blk_cnt==`M/8-1) begin
            if (w_cnt==n_W_rnd_minus_1)
                w_cnt <= 0;
            else
                w_cnt <= w_cnt+1;
        end

    // x_cnt
    always @(posedge clk)
        if (start_pulse)
            x_cnt <= 0;
        else if (counting && ~fifo_prog_full && n1_cnt==N1-1 && inner_blk_cnt==3 && blk_cnt==`M/8-1 && w_cnt==n_W_rnd_minus_1)
            x_cnt <= x_cnt+1;

    // w_base
    always @(posedge clk)
        if (start_pulse) begin
            w_base <= Y_addr;
        end else if (counting && ~fifo_prog_full && n1_cnt==N1-1 && inner_blk_cnt==3 && blk_cnt==`M/8-1) begin
            if (w_cnt==n_W_rnd_minus_1)
                w_base <= Y_addr;
            else
                w_base <= w_base+ofm_height*(`M/2);
        end

    // blk_base
    always @(posedge clk)
        if (start_pulse) begin
            blk_base <= 0;
        end else if (counting && ~fifo_prog_full && n1_cnt==N1-1 && inner_blk_cnt==3) begin
            if (blk_cnt==`M/8-1)
                blk_base <= 0;
            else
                blk_base <= blk_base+ofm_height*4;
        end

    // inner_blk_base
    always @(posedge clk)
        if (start_pulse) begin
            inner_blk_base <= ofm_height*3;
        end else if (counting && ~fifo_prog_full && n1_cnt==N1-1) begin
            if (inner_blk_cnt==3)
                inner_blk_base <= ofm_height*3;
            else
                inner_blk_base <= inner_blk_base-ofm_height;
        end

    // fm_base
    always @(posedge clk)
        if (start_pulse)
            fm_base <= 0;
        else if (counting && ~fifo_prog_full && n1_cnt==N1-1 && inner_blk_cnt==3 && blk_cnt==`M/8-1 && w_cnt==n_W_rnd_minus_1)
            fm_base <= fm_base+N1;

    // Pipeline stage1
    always @(posedge clk) begin
        addr1_1 <= w_base+blk_base;
        addr1_2 <= inner_blk_base+fm_base;
        n1_cnt1 <= n1_cnt;
        last_x_rnd <= (counting && ~fifo_prog_full && x_cnt==n_X_rnd_minus_1);
        vld1 <= (counting && ~fifo_prog_full);
        last1 <= (counting && ~fifo_prog_full && n1_cnt==N1-1 && inner_blk_cnt==3 && blk_cnt==`M/8-1 && w_cnt==n_W_rnd_minus_1 && x_cnt==n_X_rnd_minus_1);
    end

    // Pipeline stage2
    always @(posedge clk) begin
        addr2 <= addr1_1+addr1_2;
        n1_cnt2 <= n1_cnt1;
        mask2 <= (last_x_rnd && n1_cnt1>=n_last_batch);
        {vld2, last2} <= {vld1, last1};
    end

    // Pipeline stage3 (output)
    always @(posedge clk) begin
        fifo_wr_en <= vld2;
        fifo_din_addr <= addr2+n1_cnt2;
        fifo_din_mask <= mask2;
        fifo_din_last <= last2;
    end
endmodule

//
// S==8.
//
module Conv_wb_desc_fifo_wr_S_8 (
    input clk,
    input start_pulse,
    // Instruction
    input [$clog2(`RTM_DEPTH)-1:0] Y_addr,
    input [15:0] n_W_rnd_minus_1,
    input [15:0] n_X_rnd_minus_1,
    input [15:0] ofm_height,
    input [7:0] n_last_batch,
    // fifo write ports
    output reg fifo_wr_en = 0,
    output reg [$clog2(`RTM_DEPTH)-1:0] fifo_din_addr = 0,
    output reg fifo_din_mask = 0,
    output reg fifo_din_last = 0,
    input fifo_prog_full
);
    // Parameter Assertions
    initial begin
        if (`S!=8) begin
            $error("Hyper parameter mismatch, please make sure that S==8, current values are: S = %0d", `S);
            $finish;
        end
    end

    // N1 rows will come one after one.
    localparam N1 = `P/`R;

    reg counting = 0;
    // counters
    reg [$clog2(N1+1)-1:0] n1_cnt = 0;  // The ideal width is $clog2(N1), use $clog2(N1+1) to support N1=1 
    reg [0:0] inner_blk_cnt = 0;  // There are two rows of fms in a block
    reg [$clog2(`M/8)-1:0] blk_cnt = 0;
    reg [15:0] w_cnt = 0;
    reg [15:0] x_cnt = 0;
    // basic addresses
    reg [$clog2(`RTM_DEPTH)-1:0] w_base = 0;
    reg [$clog2(`RTM_DEPTH)-1:0] blk_base = 0;
    reg [$clog2(`RTM_DEPTH)-1:0] inner_blk_base = 0;
    reg [$clog2(`RTM_DEPTH)-1:0] fm_base = 0;
    // Compute the final address according to basic addresses and the n1_cnt.
    // final_addr = w_base+blk_base+inner_blk_base+fm_base+n1_cnt
    // Manage this process as pipeline to achieve better performance.
    // Pipeline stage1
    reg [$clog2(`RTM_DEPTH)-1:0] addr1_1 = 0;  // w_base+blk_base
    reg [$clog2(`RTM_DEPTH)-1:0] addr1_2 = 0;  // inner_blk_base+fm_base
    reg [$clog2(N1+1)-1:0] n1_cnt1 = 0;  // n1_cnt
    reg last_x_rnd = 0;
    reg vld1 = 0, last1 = 0;
    // Pipeline stage2
    reg [$clog2(`RTM_DEPTH)-1:0] addr2 = 0;  // addr1_1+addr1_2
    reg [$clog2(N1+1)-1:0] n1_cnt2 = 0;  // n1_cnt1
    reg mask2 = 0;
    reg vld2 = 0, last2 = 0;
    // Pipeline stage3 (Output)

    // counting
    always @(posedge clk)
        if (start_pulse)
            counting <= 1;
        else if (counting && ~fifo_prog_full && n1_cnt==N1-1 && inner_blk_cnt==1 && blk_cnt==`M/8-1 && w_cnt==n_W_rnd_minus_1 && x_cnt==n_X_rnd_minus_1)
            counting <= 0;

    // n1_cnt
    always @(posedge clk)
        if (counting && ~fifo_prog_full) begin
            if (n1_cnt==N1-1)
                n1_cnt <= 0;
            else
                n1_cnt <= n1_cnt+1;
        end

    // inner_blk_cnt
    always @(posedge clk)
        if (counting && ~fifo_prog_full && n1_cnt==N1-1) begin
            if (inner_blk_cnt==1)
                inner_blk_cnt <= 0;
            else
                inner_blk_cnt <= inner_blk_cnt+1;
        end

    // blk_cnt
    always @(posedge clk)
        if (counting && ~fifo_prog_full && n1_cnt==N1-1 && inner_blk_cnt==1) begin
            if (blk_cnt==`M/8-1)
                blk_cnt <= 0;
            else
                blk_cnt <= blk_cnt+1;
        end

    // w_cnt
    always @(posedge clk)
        if (counting && ~fifo_prog_full && n1_cnt==N1-1 && inner_blk_cnt==1 && blk_cnt==`M/8-1) begin
            if (w_cnt==n_W_rnd_minus_1)
                w_cnt <= 0;
            else
                w_cnt <= w_cnt+1;
        end

    // x_cnt
    always @(posedge clk)
        if (start_pulse)
            x_cnt <= 0;
        else if (counting && ~fifo_prog_full && n1_cnt==N1-1 && inner_blk_cnt==1 && blk_cnt==`M/8-1 && w_cnt==n_W_rnd_minus_1)
            x_cnt <= x_cnt+1;

    // w_base
    always @(posedge clk)
        if (start_pulse) begin
            w_base <= Y_addr;
        end else if (counting && ~fifo_prog_full && n1_cnt==N1-1 && inner_blk_cnt==1 && blk_cnt==`M/8-1) begin
            if (w_cnt==n_W_rnd_minus_1)
                w_base <= Y_addr;
            else
                w_base <= w_base+ofm_height*(`M/4);
        end

    // blk_base
    always @(posedge clk)
        if (start_pulse) begin
            blk_base <= 0;
        end else if (counting && ~fifo_prog_full && n1_cnt==N1-1 && inner_blk_cnt==1) begin
            if (blk_cnt==`M/8-1)
                blk_base <= 0;
            else
                blk_base <= blk_base+ofm_height*2;
        end

    // inner_blk_base
    always @(posedge clk)
        if (start_pulse) begin
            inner_blk_base <= ofm_height;
        end else if (counting && ~fifo_prog_full && n1_cnt==N1-1) begin
            if (inner_blk_cnt==1)
                inner_blk_base <= ofm_height;
            else
                inner_blk_base <= 0;
        end

    // fm_base
    always @(posedge clk)
        if (start_pulse)
            fm_base <= 0;
        else if (counting && ~fifo_prog_full && n1_cnt==N1-1 && inner_blk_cnt==1 && blk_cnt==`M/8-1 && w_cnt==n_W_rnd_minus_1)
            fm_base <= fm_base+N1;

    // Pipeline stage1
    always @(posedge clk) begin
        addr1_1 <= w_base+blk_base;
        addr1_2 <= inner_blk_base+fm_base;
        n1_cnt1 <= n1_cnt;
        last_x_rnd <= (counting && ~fifo_prog_full && x_cnt==n_X_rnd_minus_1);
        vld1 <= (counting && ~fifo_prog_full);
        last1 <= (counting && ~fifo_prog_full && n1_cnt==N1-1 && inner_blk_cnt==1 && blk_cnt==`M/8-1 && w_cnt==n_W_rnd_minus_1 && x_cnt==n_X_rnd_minus_1);
    end

    // Pipeline stage2
    always @(posedge clk) begin
        addr2 <= addr1_1+addr1_2;
        n1_cnt2 <= n1_cnt1;
        mask2 <= (last_x_rnd && n1_cnt1>=n_last_batch);
        {vld2, last2} <= {vld1, last1};
    end

    // Pipeline stage3 (output)
    always @(posedge clk) begin
        fifo_wr_en <= vld2;
        fifo_din_addr <= addr2+n1_cnt2;
        fifo_din_mask <= mask2;
        fifo_din_last <= last2;
    end
endmodule
