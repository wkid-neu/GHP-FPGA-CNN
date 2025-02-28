`timescale 1ns / 1ps
`include "../../incl.vh"

//
// Controller of the systolic array
//
module Conv_sa_ctrl (
    input clk,
    input [7:0] wz,
    // Weight-Activation fifo read ports
    output wx_fifo_rd_en,
    input [`SA_TAG_DW+`M*4*8+`P*2*8-1:0] wx_fifo_dout,
    input wx_fifo_empty,
    input wx_fifo_almost_empty,
    // Systolic Array input ports
    output [`M*8-1:0] sa_mat_w1,
    output [`M*8-1:0] sa_mat_w2,
    output [`P*8-1:0] sa_mat_x,
    output [`P*8-1:0] sa_mat_wz,
`ifdef DEBUG
    output [`M-1:0] dbg_sa_mat_vec_begin,  // current input is the first element
    output [`M-1:0] dbg_sa_mat_vec_end,  // current input is the last element
    output [`M-1:0] dbg_sa_mat_vec_rst,  // current input is invaild, this is a reset cycle
`endif
    output [`M-1:0] sa_mat_rst,
    output [`M-1:0] sa_mat_flush,
    output [`M/8-1:0] sa_mat_psum_vld,
    output [`M/8-1:0] sa_mat_psum_last_rnd,
    output [`M/8*3-1:0] sa_mat_psum_wr_addr,
    output [`M/8*3-1:0] sa_mat_psum_prefetch_addr,
    output sa_post_rstp,
    output [$clog2(`M/8)-1:0] sa_post_sel,
    // Systolic Array output ports
    input [`P*32-1:0] sa_mat_y1,
    input [`P*32-1:0] sa_mat_y2,
    // Dot-product fifo write ports
    input dp_fifo_prog_full,
    output dp_fifo_wr_en,
    output [2*`P*32-1:0] dp_fifo_din
);
    wire [`SA_TAG_DW+`M*4*8+`P*2*8-1:0] wx_data;
    wire wx_flag_data1;
    wire wx_flag_data2;
    wire wx_flag_rst;

    wire vec_end;

    wire output_fifo_wr_en;
    wire [2*`P*32-1:0] output_fifo_din;
    wire output_fifo_prog_full;
    wire output_fifo_rd_en;
    wire [2*`P*32-1:0] output_fifo_dout;
    wire output_fifo_empty;
    wire output_fifo_almost_empty;
    wire output_fifo_data_valid;

    Conv_sa_wx_fifo_reader Conv_sa_wx_fifo_reader_inst(
        .clk(clk),
        .wx_fifo_rd_en(wx_fifo_rd_en),
        .wx_fifo_dout(wx_fifo_dout),
        .wx_fifo_empty(wx_fifo_empty),
        .wx_fifo_almost_empty(wx_fifo_almost_empty),
        .data(wx_data),
        .flag_data1(wx_flag_data1),
        .flag_data2(wx_flag_data2),
        .flag_rst(wx_flag_rst),
        .output_fifo_prog_full (output_fifo_prog_full )
    );

    Conv_sa_inputs_ctrl Conv_sa_inputs_ctrl_inst(
        .clk(clk),
        .wz(wz),
        .wx_data(wx_data),
        .wx_flag_data1(wx_flag_data1),
        .wx_flag_data2(wx_flag_data2),
        .wx_flag_rst(wx_flag_rst),
        .sa_mat_w1(sa_mat_w1),
        .sa_mat_w2(sa_mat_w2),
        .sa_mat_x(sa_mat_x),
        .sa_mat_wz(sa_mat_wz),
`ifdef DEBUG
        .dbg_sa_mat_vec_begin(dbg_sa_mat_vec_begin),
        .dbg_sa_mat_vec_end(dbg_sa_mat_vec_end),
        .dbg_sa_mat_vec_rst(dbg_sa_mat_vec_rst),
`endif
        .sa_mat_rst(sa_mat_rst),
        .sa_mat_flush(sa_mat_flush),
        .sa_mat_psum_vld(sa_mat_psum_vld),
        .sa_mat_psum_last_rnd(sa_mat_psum_last_rnd),
        .sa_mat_psum_wr_addr(sa_mat_psum_wr_addr),
        .sa_mat_psum_prefetch_addr(sa_mat_psum_prefetch_addr),
        .sa_post_rstp(sa_post_rstp),
        .sa_post_sel(sa_post_sel),
        .vec_end(vec_end)
    );

    sync_fifo #(
        .DATA_WIDTH(2*`P*32),
        .DEPTH(1024),
        .PROG_FULL(512),
        .READ_LATENCY(2),
        .HAS_EMPTY(1),
        .HAS_ALMOST_EMPTY(1),
        .HAS_DATA_VALID(1),
        .HAS_PROG_FULL(1),
        .RAM_STYLE("block")
    ) Conv_sa_output_fifo_inst(
        .clk(clk),
        .rd_en(output_fifo_rd_en),
        .dout(output_fifo_dout),
        .data_valid(output_fifo_data_valid),
        .empty(output_fifo_empty),
        .almost_empty(output_fifo_almost_empty),
        .wr_en(output_fifo_wr_en),
        .din(output_fifo_din),
        .prog_full(output_fifo_prog_full)
    );

    Conv_sa_output_fifo_writer Conv_sa_output_fifo_writer_inst(
        .clk(clk),
        .output_fifo_wr_en(output_fifo_wr_en),
        .output_fifo_din(output_fifo_din),
        .sa_mat_y1(sa_mat_y1),
        .sa_mat_y2(sa_mat_y2),
        .vec_end(vec_end)
    );

    Conv_sa_dp_fifo_writer Conv_sa_dp_fifo_writer_inst(
        .clk(clk),
        .output_fifo_rd_en(output_fifo_rd_en),
        .output_fifo_dout(output_fifo_dout),
        .output_fifo_empty(output_fifo_empty),
        .output_fifo_almost_empty(output_fifo_almost_empty),
        .output_fifo_data_valid(output_fifo_data_valid),
        .dp_fifo_prog_full(dp_fifo_prog_full),
        .dp_fifo_wr_en(dp_fifo_wr_en),
        .dp_fifo_din(dp_fifo_din)
    );
endmodule

//
// Read and prepare weights and activations
//
module Conv_sa_wx_fifo_reader (
    input clk,
    // Weight-Activation fifo read ports
    output reg wx_fifo_rd_en = 0,
    input [`SA_TAG_DW+`M*4*8+`P*2*8-1:0] wx_fifo_dout,
    input wx_fifo_empty,
    input wx_fifo_almost_empty,
    // Prepared data
    output [`SA_TAG_DW+`M*4*8+`P*2*8-1:0] data,
    output flag_data1,
    output flag_data2,
    output flag_rst,
    // output fifo state
    input output_fifo_prog_full
);
    localparam RD = 0, STALL = 1, RST = 2;
    (* fsm_encoding = "one_hot" *) reg [1:0] state = RD;
    reg [1:0] cnt = 0;
    wire readable;
    assign readable = ~output_fifo_prog_full && ~wx_fifo_empty && (~wx_fifo_almost_empty || ~wx_fifo_rd_en);

    always @(posedge clk)
        case (state)
            RD: begin
                if (readable)
                    state <= STALL;
            end
            STALL: begin
                if (cnt==3)
                    state <= RST;
                else
                    state <= RD;
            end
            RST: state <= RD;
        endcase

    // wx_fifo_rd_en
    always @(posedge clk) 
        wx_fifo_rd_en <= (state==RD && readable);

    // cnt
    always @(posedge clk)
        if (state==STALL)
            cnt <= cnt+1;

    // Flags
    shift_reg #(2, 1) shift_reg_inst1(clk, wx_fifo_rd_en, flag_data1);
    shift_reg #(1, 1) shift_reg_inst2(clk, flag_data1, flag_data2);
    shift_reg #(3, 1) shift_reg_inst3(clk, state==RST, flag_rst);
    assign data = wx_fifo_dout;
endmodule

//
// Controller of Systolic Array input ports
//
module Conv_sa_inputs_ctrl (
    input clk,
    input [7:0] wz,
    // Weight-Activation fifo reader
    input [`SA_TAG_DW+`M*4*8+`P*2*8-1:0] wx_data,
    input wx_flag_data1,
    input wx_flag_data2,
    input wx_flag_rst,
    // Systolic Array input ports
    output reg [`M*8-1:0] sa_mat_w1 = 0,
    output reg [`M*8-1:0] sa_mat_w2 = 0,
    output reg [`P*8-1:0] sa_mat_x = 0,
    output reg [`P*8-1:0] sa_mat_wz = 0,
`ifdef DEBUG
    output reg [`M-1:0] dbg_sa_mat_vec_begin = 0,  // current input is the first element
    output reg [`M-1:0] dbg_sa_mat_vec_end = 0,  // current input is the last element
    output reg [`M-1:0] dbg_sa_mat_vec_rst = 0,  // current input is invaild, this is a reset cycle
`endif
    output reg [`M-1:0] sa_mat_rst = 0,
    output [`M-1:0] sa_mat_flush,
    output [`M/8-1:0] sa_mat_psum_vld,
    output [`M/8-1:0] sa_mat_psum_last_rnd,
    output [`M/8*3-1:0] sa_mat_psum_wr_addr,
    output [`M/8*3-1:0] sa_mat_psum_prefetch_addr,
    output sa_post_rstp,
    output [$clog2(`M/8)-1:0] sa_post_sel,
    // Vector end
    output reg vec_end = 0
);
    localparam NUM_PIPE_RST = 2;
    localparam NUM_PIPE_FLUSH = 8+3;
    localparam NUM_PIPE_VEC_END = NUM_PIPE_FLUSH;

    reg [NUM_PIPE_RST-1:0] rst_pipe = 0;
    reg [NUM_PIPE_FLUSH-1:0] flush_pipe = 0;
    reg [NUM_PIPE_VEC_END-1:0] vec_end_pipe = 0;
    integer i;
    genvar k;

    // sa_mat_wz
    always @(posedge clk) begin
        sa_mat_wz[7:0] <= wz;
        for (i=1; i<`P; i=i+1)
            sa_mat_wz[i*8+:8] <= sa_mat_wz[(i-1)*8+:8];
    end

    // sa_mat_x
    always @(posedge clk)
        if (wx_flag_data1)
            for (i=0; i<`P; i=i+1)
                sa_mat_x[i*8+:8] <= wx_data[i*(8*2)+:8];
        else if (wx_flag_data2)
            for (i=0; i<`P; i=i+1)
                sa_mat_x[i*8+:8] <= wx_data[i*(8*2)+8+:8];
        else
            sa_mat_x <= 0;

    // sa_mat_w1
    always @(posedge clk)
        if (wx_flag_data1)
            for (i=0; i<`M; i=i+1)
                sa_mat_w1[i*8+:8] <= wx_data[`P*2*8+i*(8*4)+:8];
        else
            for (i=0; i<`M; i=i+1)
                sa_mat_w1[i*8+:8] <= wx_data[`P*2*8+i*(8*4)+8+:8];

    // sa_mat_w2
    always @(posedge clk)
        if (wx_flag_data1)
            for (i=0; i<`M; i=i+1)
                sa_mat_w2[i*8+:8] <= wx_data[`P*2*8+i*(8*4)+8*2+:8];
        else
            for (i=0; i<`M; i=i+1)
                sa_mat_w2[i*8+:8] <= wx_data[`P*2*8+i*(8*4)+8*3+:8];

`ifdef DEBUG
    // dbg_sa_mat_vec_begin

    // dbg_sa_mat_vec_end
    always @(posedge clk) begin
        dbg_sa_mat_vec_end[0] <= (wx_flag_data2 && (wx_data[`M*4*8+`P*2*8+:`SA_TAG_DW]==`SA_TAG_END));
        for (i=1; i<`P; i=i+1)
            dbg_sa_mat_vec_end[i] <= dbg_sa_mat_vec_end[i-1];
    end

    // dbg_sa_mat_vec_rst
    always @(posedge clk) begin
        dbg_sa_mat_vec_rst[0] <= wx_flag_rst;
        for (i=1; i<`P; i=i+1)
            dbg_sa_mat_vec_rst[i] <= dbg_sa_mat_vec_rst[i-1];
    end
`endif

    // sa_mat_rst
    always @(posedge clk) begin
        sa_mat_rst[0] <= rst_pipe[NUM_PIPE_RST-1];
        for (i=1; i<`M; i=i+1)
            sa_mat_rst[i] <= sa_mat_rst[i-1];
    end

    // sa_mat_flush
    reg [7:0] flush_of_first_block = 0;
    always @(posedge clk) begin
        if (flush_pipe[NUM_PIPE_FLUSH-1])
            flush_of_first_block <= 8'b11111110;
        else
            flush_of_first_block <= flush_of_first_block<<1;
    end
    assign sa_mat_flush[7:0] = flush_of_first_block;
    generate
        for (k=1; k<`M/8; k=k+1) begin
            shift_reg #(.DELAY(8),.DATA_WIDTH(8)) shift_reg_inst(.clk(clk),.i(sa_mat_flush[(k-1)*8+:8]),.o(sa_mat_flush[k*8+:8]));
        end
    endgenerate

    // sa_mat_psum_vld
    reg psum_vld_first_block = 0;
    reg [7:0] psum_vld_first_block_shreg = 0;
    always @(posedge clk) begin
        if (flush_pipe[NUM_PIPE_FLUSH-1])
            psum_vld_first_block_shreg <= 8'b11111111;
        else
            psum_vld_first_block_shreg <= psum_vld_first_block_shreg>>1;

        psum_vld_first_block <= (psum_vld_first_block_shreg!=0);
    end
    assign sa_mat_psum_vld[0] = psum_vld_first_block;
    generate
        for (k=1; k<`M/8; k=k+1) begin
            shift_reg #(.DELAY(8),.DATA_WIDTH(1)) shift_reg_inst(.clk(clk),.i(sa_mat_psum_vld[k-1]),.o(sa_mat_psum_vld[k]));
        end
    endgenerate

    // sa_mat_psum_last_rnd
    reg psum_last_rnd_first_block = 0;
    reg [7:0] psum_last_rnd_first_block_shreg = 0;
    always @(posedge clk) begin
        if (vec_end_pipe[NUM_PIPE_VEC_END-1])
            psum_last_rnd_first_block_shreg <= 8'b11111111;
        else
            psum_last_rnd_first_block_shreg <= psum_last_rnd_first_block_shreg>>1;

        psum_last_rnd_first_block <= (psum_last_rnd_first_block_shreg!=0);
    end
    assign sa_mat_psum_last_rnd[0] = psum_last_rnd_first_block;
    generate
        for (k=1; k<`M/8; k=k+1) begin
            shift_reg #(.DELAY(8),.DATA_WIDTH(1)) shift_reg_inst(.clk(clk),.i(sa_mat_psum_last_rnd[k-1]),.o(sa_mat_psum_last_rnd[k]));
        end
    endgenerate

    // sa_mat_psum_wr_addr
    // The wr_addr legs prefetched_addr by 2 clock cycles
    shift_reg #(2, `M/8*3) shift_reg_wr_addr(clk, sa_mat_psum_prefetch_addr, sa_mat_psum_wr_addr);

    // sa_mat_psum_prefetch_addr
    reg [2:0] psum_prefetch_addr_first_block = 0;
    always @(posedge clk) begin
        if (flush_pipe[NUM_PIPE_FLUSH-2])
            psum_prefetch_addr_first_block <= 7;
        else
            psum_prefetch_addr_first_block <= psum_prefetch_addr_first_block-1;
    end
    assign sa_mat_psum_prefetch_addr[2:0] = psum_prefetch_addr_first_block;
    generate
        for (k=1; k<`M/8; k=k+1) begin
            shift_reg #(.DELAY(8),.DATA_WIDTH(3)) shift_reg_inst(.clk(clk),.i(sa_mat_psum_prefetch_addr[(k-1)*3+:3]),.o(sa_mat_psum_prefetch_addr[k*3+:3]));
        end
    endgenerate

    // sa_post_rstp
    shift_reg #(13, 1) shift_reg_post_rstp(clk, vec_end, sa_post_rstp);

    // sa_post_sel
    reg [$clog2(`M)-1:0] post_cnt = 0;
    wire post_cnt_start;
    shift_reg #(12, 1) shift_reg_post_cnt_start(clk, vec_end, post_cnt_start);
    always @(posedge clk)
        if (post_cnt_start)
            post_cnt <= 0;
        else
            post_cnt <= post_cnt+1;
    assign sa_post_sel = post_cnt[$clog2(`M)-1:3];

    // vec_end
    always @(posedge clk)
        vec_end <= (wx_flag_data2 && (wx_data[`M*4*8+`P*2*8+:`SA_TAG_DW]==`SA_TAG_END));

    // rst_pipe, flush_pipe, vec_end_pipe
    always @(posedge clk) begin
        rst_pipe[0] <= wx_flag_rst;
        flush_pipe[0] <= wx_flag_rst;
        vec_end_pipe[0] <= vec_end;
        for (i=1; i<NUM_PIPE_RST; i=i+1)
            rst_pipe[i] <= rst_pipe[i-1];
        for (i=1; i<NUM_PIPE_FLUSH; i=i+1)
            flush_pipe[i] <= flush_pipe[i-1];
        for (i=1; i<NUM_PIPE_VEC_END; i=i+1)
            vec_end_pipe[i] <= vec_end_pipe[i-1];
    end
endmodule

//
// This module catches systolic array outputs and write them into the output fifo
//
module Conv_sa_output_fifo_writer (
    input clk,
    // Output fifo write ports
    output reg output_fifo_wr_en = 0,
    output reg [2*`P*32-1:0] output_fifo_din = 0,
    // Systolic Array outputs
    input [`P*32-1:0] sa_mat_y1,
    input [`P*32-1:0] sa_mat_y2,
    // flags
    input vec_end
);
    reg [`M-1:0] vld_pulse_shreg = 0;
    wire vld;

    // vld_pulse_shreg
    always @(posedge clk)
        if (vec_end)
            vld_pulse_shreg <= {`M{1'b1}};
        else
            vld_pulse_shreg <= vld_pulse_shreg<<1;

    // vld
    shift_reg #(`P+8+5, 1) shift_reg_vld(clk, vld_pulse_shreg[`M-1], vld);
    
    wire [`P*32-1:0] aligned_mat_y1;
    wire [`P*32-1:0] aligned_mat_y2;

    genvar i;
    generate
        for (i=0; i<`P; i=i+1) begin
            shift_reg #(
                .DELAY(`P-1-i),
                .DATA_WIDTH(32)
            ) shift_reg_inst1(
                .clk(clk),
                .i(sa_mat_y1[i*32+:32]),
                .o(aligned_mat_y1[i*32+:32])
            );

            shift_reg #(
                .DELAY(`P-1-i),
                .DATA_WIDTH(32)
            ) shift_reg_inst2(
                .clk(clk),
                .i(sa_mat_y2[i*32+:32]),
                .o(aligned_mat_y2[i*32+:32])
            );
        end
    endgenerate

    // output_fifo_wr_en, output_fifo_din
    always @(posedge clk) begin
        output_fifo_wr_en <= vld;
        output_fifo_din <= {aligned_mat_y2, aligned_mat_y1};
    end
endmodule

//
// This module reads data from the output fifo and writes them into the dp fifo.
//
module Conv_sa_dp_fifo_writer(
    input clk,
    // Output fifo read ports,
    output reg output_fifo_rd_en = 0,
    input [2*`P*32-1:0] output_fifo_dout,
    input output_fifo_empty,
    input output_fifo_almost_empty,
    input output_fifo_data_valid,
    // Dot-product fifo write ports
    input dp_fifo_prog_full,
    output reg dp_fifo_wr_en = 0,
    output reg [2*`P*32-1:0] dp_fifo_din = 0
);
    // output_fifo_rd_en
    always @(posedge clk)
        output_fifo_rd_en <= ~output_fifo_empty && (~output_fifo_almost_empty || ~output_fifo_rd_en) && ~dp_fifo_prog_full;

    // dp_fifo_wr_en, dp_fifo_din
    always @(posedge clk) begin
        dp_fifo_wr_en <= output_fifo_data_valid;
        dp_fifo_din <= output_fifo_dout;
    end
endmodule
