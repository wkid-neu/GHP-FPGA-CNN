`timescale 1ns / 1ps
`include "../incl.vh"

// Cache cmd, Z,X,E
`define CACHE_CMD_OPCODE_Z 0
`define CACHE_CMD_OPCODE_X 1
`define CACHE_CMD_OPCODE_E 2

module xbus_filter(
    input clk,
    input rst,
    // Parameters
    input [15:0] INC2_minus_1,
    input [15:0] INW_,
    input [15:0] INH2,
    input [15:0] INW2,
    input [7:0] KH_minus_1,
    input [7:0] KW_minus_1,
    input [3:0] strideH,
    input [3:0] strideW,
    input [3:0] padL,
    input [3:0] padU,
    input [15:0] row_bound,
    input [15:0] col_bound,
    input [7:0] Xz,
    // bus
    input [`XBUS_TAG_WIDTH-1:0] in_pkt_tag,
    input [`Q*`S*8-1:0] in_pkt_data,
    output [`XBUS_TAG_WIDTH-1:0] out_pkt_tag,
    output [`Q*`S*8-1:0] out_pkt_data,
    // vector fifo
    output vec_fifo_wr_en,
    output [`S*8-1:0] vec_fifo_din,
    input vec_fifo_prog_full,
    // cache full
    output cache_full
);
    wire cache_wr_en;
    wire [`XBUS_TAG_WIDTH-1:0] cache_din_tag;
    wire [`Q*`S*8-1:0] cache_din_data;
    wire cache_prog_full;
    wire cache_rd_en;
    wire [$clog2(`XBUS_CACHE_DEPTH+1)-1:0] cache_rd_step;
    wire [`XBUS_TAG_WIDTH-1:0] cache_dout_tag;
    wire [`Q*`S*8-1:0] cache_dout_data;
    wire cache_empty;
    wire [$clog2(`XBUS_CACHE_DEPTH+1)-1:0] cache_cnt;

    wire cmd_gen_start_pulse;
    wire [15:0] cmd_gen_X_a_;
    wire [15:0] cmd_gen_len_per_chan;
    wire [15:0] cmd_gen_my_win_x;
    wire [15:0] cmd_gen_my_win_y;
    wire cmd_vld;
    wire cmd_rdy;
    wire [1:0] cmd_opcode;
    wire [15:0] cmd_shift;
    wire [$clog2(`Q)-1:0] cmd_b_;

    assign cache_full = cache_prog_full;

    xbus_filter_header_converter xbus_filter_header_converter_inst(
    	.clk(clk),
        .strideH(strideH),
        .strideW(strideW),
        .row_bound(row_bound),
        .col_bound(col_bound),
        .in_pkt_tag(in_pkt_tag),
        .in_pkt_data(in_pkt_data),
        .out_pkt_tag(out_pkt_tag),
        .out_pkt_data(out_pkt_data)
    );

    xbus_filter_cache xbus_filter_cache_inst(
    	.clk(clk),
        .wr_en(cache_wr_en),
        .din_tag(cache_din_tag),
        .din_data(cache_din_data),
        .prog_full(cache_prog_full),
        .rd_en(cache_rd_en),
        .rd_step(cache_rd_step),
        .dout_tag(cache_dout_tag),
        .dout_data(cache_dout_data),
        .empty(cache_empty),
        .cnt(cache_cnt)
    );

    xbus_filter_cache_wr xbus_filter_cache_wr_inst(
    	.clk(clk),
        .in_pkt_tag(in_pkt_tag),
        .in_pkt_data(in_pkt_data),
        .cache_wr_en(cache_wr_en),
        .cache_din_tag(cache_din_tag),
        .cache_din_data(cache_din_data)
    );

    xbus_filter_cmd_gen xbus_filter_cmd_gen_inst(
    	.clk(clk),
        .start_pulse(cmd_gen_start_pulse),
        .INC2_minus_1(INC2_minus_1),
        .INW_(INW_),
        .INH2(INH2),
        .INW2(INW2),
        .KH_minus_1(KH_minus_1),
        .KW_minus_1(KW_minus_1),
        .padL(padL),
        .padU(padU),
        .X_a_(cmd_gen_X_a_),
        .len_per_chan(cmd_gen_len_per_chan),
        .my_win_x(cmd_gen_my_win_x),
        .my_win_y(cmd_gen_my_win_y),
        .vld(cmd_vld),
        .rdy(cmd_rdy),
        .opcode(cmd_opcode),
        .shift(cmd_shift),
        .b_(cmd_b_)
    );

    xbus_filter_fsm xbus_filter_fsm_inst(
    	.clk(clk),
        .start_pulse(rst),
        .Xz(Xz),
        .cache_empty(cache_empty),
        .cache_cnt(cache_cnt),
        .cache_rd_en(cache_rd_en),
        .cache_rd_step(cache_rd_step),
        .cache_dout_tag(cache_dout_tag),
        .cache_dout_data(cache_dout_data),
        .cmd_gen_start_pulse(cmd_gen_start_pulse),
        .cmd_gen_X_a_(cmd_gen_X_a_),
        .cmd_gen_len_per_chan(cmd_gen_len_per_chan),
        .cmd_gen_win_x(cmd_gen_my_win_x),
        .cmd_gen_win_y(cmd_gen_my_win_y),
        .cmd_vld(cmd_vld),
        .cmd_rdy(cmd_rdy),
        .cmd_opcode(cmd_opcode),
        .cmd_shift(cmd_shift),
        .cmd_b_(cmd_b_),
        .vec_fifo_wr_en(vec_fifo_wr_en),
        .vec_fifo_din(vec_fifo_din),
        .vec_fifo_prog_full(vec_fifo_prog_full)
    );
endmodule

//
// Convert header
//
module xbus_filter_header_converter (
    input clk,
    input [3:0] strideH,
    input [3:0] strideW,
    input [15:0] row_bound,
    input [15:0] col_bound,
    // bus
    input [`XBUS_TAG_WIDTH-1:0] in_pkt_tag,
    input [`Q*`S*8-1:0] in_pkt_data,
    output reg [`XBUS_TAG_WIDTH-1:0] out_pkt_tag = 0,
    output reg [`Q*`S*8-1:0] out_pkt_data = 0
);
    reg [15:0] int_win_x;
    reg [15:0] int_win_y;
    reg [15:0] int_win_x_next;
    reg [15:0] int_win_y_next;

    always @(*) begin
        int_win_x = in_pkt_data[47:32];
        int_win_y = in_pkt_data[63:48];
        if (int_win_x==col_bound && int_win_y==row_bound) begin
            int_win_x_next = int_win_x;
            int_win_y_next = int_win_y;
        end else if (int_win_x==col_bound) begin
            int_win_x_next = 0;
            int_win_y_next = int_win_y+strideH;
        end else begin
            int_win_x_next = int_win_x+strideW;
            int_win_y_next = int_win_y;
        end
    end

    always @(posedge clk)
        out_pkt_tag <= in_pkt_tag;
    
    always @(posedge clk) begin
        if (in_pkt_tag==`XBUS_TAG_HEAD) begin
            out_pkt_data[47:32] <= int_win_x_next;
            out_pkt_data[63:48] <= int_win_y_next;
        end else begin
            out_pkt_data[47:32] <= in_pkt_data[47:32];
            out_pkt_data[63:48] <= in_pkt_data[63:48];
        end
        out_pkt_data[31:0] <= in_pkt_data[31:0];
        out_pkt_data[`Q*`S*8-1:64] <= in_pkt_data[`Q*`S*8-1:64];
    end
endmodule

//
// Cache FIFO
//
module xbus_filter_cache (
    input clk,
    // Write ports
    input wr_en,
    input [`XBUS_TAG_WIDTH-1:0] din_tag,
    input [`Q*`S*8-1:0] din_data,
    output reg prog_full = 0,
    // Read ports
    input rd_en,
    input [$clog2(`XBUS_CACHE_DEPTH+1)-1:0] rd_step,
    output [`XBUS_TAG_WIDTH-1:0] dout_tag,
    output [`Q*`S*8-1:0] dout_data,
    output reg empty = 1,
    // Count
    output [$clog2(`XBUS_CACHE_DEPTH+1)-1:0] cnt
);
    localparam DEPTH = `XBUS_CACHE_DEPTH,
        DATA_WIDTH = `XBUS_TAG_WIDTH+`Q*`S*8,
        PROG_FULL = `XBUS_CACHE_FULL,
        NUM_PIPE = 2;
    localparam RAM_PRT_WIDTH = $clog2(DEPTH);

    (* ram_style="block" *) reg [DATA_WIDTH-1:0] mem [DEPTH-1:0];
    reg [DATA_WIDTH-1:0] mem_reg = 0;    
    reg [DATA_WIDTH-1:0] dout_pipes [NUM_PIPE-1:0];
    assign {dout_tag, dout_data} = dout_pipes[NUM_PIPE-1];

    // count
    reg [RAM_PRT_WIDTH:0] count = 0, count_next;
    assign cnt = count;

    always @(*) begin
        case ({rd_en, wr_en})
            2'b00: count_next = count;
            2'b01: count_next = count+1;
            2'b10: count_next = count-rd_step;
            2'b11: count_next = count-rd_step+1;
            default: count_next = count;
        endcase
    end

    always @(posedge clk)
        count <= count_next;
    
    // Write
    reg [RAM_PRT_WIDTH-1:0] wr_ptr = 0;
    wire [RAM_PRT_WIDTH-1:0] wr_ptr_next;
    assign wr_ptr_next = wr_ptr+wr_en;

    always @(posedge clk) begin
        if (wr_en)
            mem[wr_ptr] <= {din_tag, din_data};
        wr_ptr <= wr_ptr_next;
    end

    // Read
    reg [RAM_PRT_WIDTH-1:0] rd_ptr = 0, rd_ptr_next;
    reg [RAM_PRT_WIDTH-1:0] real_rd_ptr;

    always @(*) begin
        if (rd_en)
            rd_ptr_next = rd_ptr+rd_step;
        else
            rd_ptr_next = rd_ptr;
        real_rd_ptr = rd_ptr_next-1;
    end

    always @(posedge clk) begin
        if (rd_en)
            mem_reg <= mem[real_rd_ptr];
        rd_ptr <= rd_ptr_next;
    end

    integer k;
    always @(posedge clk) begin
        dout_pipes[0] <= mem_reg;
        for (k=1; k<NUM_PIPE; k=k+1)
            dout_pipes[k] <= dout_pipes[k-1];
    end

    initial begin
        for (k=0; k<NUM_PIPE; k=k+1)
            dout_pipes[k] = 0;
    end

    // Flags
    always @(posedge clk)
        empty <= (count_next==0);

    always @(posedge clk)
        prog_full <= (count_next>PROG_FULL);
endmodule

//
// Write X packet data into cache
//
module xbus_filter_cache_wr (
    input clk,
    input [`XBUS_TAG_WIDTH-1:0] in_pkt_tag,
    input [`Q*`S*8-1:0] in_pkt_data,
    output cache_wr_en,
    output [`XBUS_TAG_WIDTH-1:0] cache_din_tag,
    output [`Q*`S*8-1:0] cache_din_data
);
    reg cache_wr_en_reg = 0;
    reg [`XBUS_TAG_WIDTH-1:0] cache_din_tag_reg = 0;
    reg [`Q*`S*8-1:0] cache_din_data_reg = 0;

    always @(posedge clk) begin
        cache_wr_en_reg <= (in_pkt_tag==`XBUS_TAG_BODY || in_pkt_tag==`XBUS_TAG_HEAD || in_pkt_tag==`XBUS_TAG_END);
        cache_din_tag_reg <= in_pkt_tag;
        cache_din_data_reg <= in_pkt_data;
    end

`ifdef M32P64Q16R16S8
    // Add additional pipeline stages for high performance
    shift_reg #(1, 1) shift_reg_cache_wr_en(clk, cache_wr_en_reg, cache_wr_en);
    shift_reg #(1, `XBUS_TAG_WIDTH) shift_reg_cache_din_tag(clk, cache_din_tag_reg, cache_din_tag);
    shift_reg #(1, `Q*`S*8) shift_reg_cache_din_data(clk, cache_din_data_reg, cache_din_data);
`elsif M32P96Q16R16S8
    // Add additional pipeline stages for high performance
    shift_reg #(1, 1) shift_reg_cache_wr_en(clk, cache_wr_en_reg, cache_wr_en);
    shift_reg #(1, `XBUS_TAG_WIDTH) shift_reg_cache_din_tag(clk, cache_din_tag_reg, cache_din_tag);
    shift_reg #(1, `Q*`S*8) shift_reg_cache_din_data(clk, cache_din_data_reg, cache_din_data);
`elsif M64P64Q16R16S8
    // Add additional pipeline stages for high performance
    shift_reg #(1, 1) shift_reg_cache_wr_en(clk, cache_wr_en_reg, cache_wr_en);
    shift_reg #(1, `XBUS_TAG_WIDTH) shift_reg_cache_din_tag(clk, cache_din_tag_reg, cache_din_tag);
    shift_reg #(1, `Q*`S*8) shift_reg_cache_din_data(clk, cache_din_data_reg, cache_din_data);
`else
    assign cache_wr_en = cache_wr_en_reg;
    assign cache_din_tag = cache_din_tag_reg;
    assign cache_din_data = cache_din_data_reg;
`endif
endmodule

//
// Cache cmd generator
//
module xbus_filter_cmd_gen (
    input clk,
    input start_pulse,
    // instruction
    input [15:0] INC2_minus_1,
    input [15:0] INW_,
    input [15:0] INH2,
    input [15:0] INW2,
    input [7:0] KH_minus_1,
    input [7:0] KW_minus_1,
    input [3:0] padL,
    input [3:0] padU,
    input [15:0] X_a_,
    input [15:0] len_per_chan,
    input [15:0] my_win_x,
    input [15:0] my_win_y,
    // Handshake signals
    output reg vld = 0,
    input rdy,
    output reg [1:0] opcode = 0,
    output reg [15:0] shift = 0,
    output reg [$clog2(`Q)-1:0] b_ = 0
);
    localparam IDLE = 0, GEN_FIRST_CMD = 1, GEN_CMD = 2, GEN_END_CMD = 3, DONE = 4;
    reg [2:0] state = IDLE;

    reg [15:0] init_len_per_chan_plus_X_a_ = 0;
    reg [15:0] init_len_per_chan_plus_X_a__minus_1 = 0;
    reg wr_first_X_cmd = 0;
    // loop variables
    reg [15:0] inc_cnt = 0;
    reg [7:0] kh_cnt = 0;
    reg [7:0] kw_cnt = 0;
    // Pipe stage1
    reg [15:0] x = 0;
    reg [15:0] y = 0;
    reg [15:0] inc1 = 0;
    reg first_cmd1 = 0, end_cmd1 = 0, vld1 = 0;
    // Pipe stage2
    reg [15:0] x_ = 0;
    reg [15:0] y_ = 0;
    reg is_bound = 0;
    reg [15:0] inc2 = 0;
    reg first_cmd2 = 0, end_cmd2 = 0, vld2 = 0;
    // Pipe stage3
    reg [1:0] cmd_type = 0;
    (*use_dsp="no"*) reg [31:0] tmp1 = 0;
    reg [15:0] x_3 = 0;
    reg [15:0] inc3 = 0;
    reg first_cmd3 = 0, vld3 = 0;
    // Pipe stage4
    reg [1:0] cmd_type4 = 0;
    reg [31:0] tmp2 = 0;
    reg [15:0] inc4 = 0;
    reg first_cmd4 = 0, vld4 = 0;
    // Pipe stage5
    reg [15:0] base_desc_inc = 0;
    reg [15:0] base_desc_a_ = 0;
    reg [$clog2(`Q)-1:0] base_desc_b_ = 0;
    reg [15:0] obj_desc_inc = 0;
    reg [15:0] obj_desc_a_ = 0;
    reg [$clog2(`Q)-1:0] obj_desc_b_ = 0;
    reg [1:0] cmd_type5 = 0;
    reg vld5 = 0;
    // Pipe stage6
    reg [15:0] shift6 = 0;
    reg [$clog2(`Q)-1:0] b_6 = 0;
    reg [1:0] cmd_type6 = 0;
    reg vld6 = 0;

    // state is GEN_FIRST_CMD or GEN_CMD
    wire cnt_state = (state==GEN_FIRST_CMD || state==GEN_CMD);
    // pipeline forward
    wire next = (~vld || (vld && rdy));  

    always @(posedge clk) 
        case (state)
            IDLE: if (start_pulse) state <= GEN_FIRST_CMD;
            GEN_FIRST_CMD: if (next) state <= GEN_CMD;
            GEN_CMD: if (inc_cnt==INC2_minus_1 && kh_cnt==KH_minus_1 && kw_cnt==KW_minus_1 && next) state <= GEN_END_CMD;
            GEN_END_CMD: if (next) state <= DONE;
            DONE: state <= IDLE;
        endcase

    // kw_cnt
    always @(posedge clk)
        if (cnt_state && next) begin
            if (kw_cnt==KW_minus_1)
                kw_cnt <= 0;
            else
                kw_cnt <= kw_cnt+1;
        end

    // kh_cnt
    always @(posedge clk)
        if (cnt_state && next && kw_cnt==KW_minus_1) begin
            if (kh_cnt==KH_minus_1)
                kh_cnt <= 0;
            else
                kh_cnt <= kh_cnt+1;
        end

    // inc_cnt
    always @(posedge clk)
        if (start_pulse)
            inc_cnt <= 0;
        else if (cnt_state && next && kw_cnt==KW_minus_1 && kh_cnt==KH_minus_1)
            inc_cnt <= inc_cnt+1;

    // Pipe stage1
    always @(posedge clk)
        if (next) begin
            if (cnt_state) begin
                x <= my_win_x+kw_cnt;
                y <= my_win_y+kh_cnt;
                inc1 <= inc_cnt;
            end
            first_cmd1 <= (state==GEN_FIRST_CMD);
            end_cmd1 <= (state==GEN_END_CMD);
            vld1 <= (cnt_state || state==GEN_END_CMD);
        end

    // Pipe stage2
    always @(posedge clk)
        if (next) begin
            x_ <= x-padL;
            y_ <= y-padU;
            is_bound <= (x<padL) || (x>=INW2) || (y<padU) || (y>=INH2);
            inc2 <= inc1;
            {first_cmd2, end_cmd2, vld2} <= {first_cmd1, end_cmd1, vld1}; 
        end

    // Pipe stage3
    always @(posedge clk)
        if (next) begin
            if (end_cmd2)
                cmd_type <= `CACHE_CMD_OPCODE_E;
            else if (is_bound)
                cmd_type <= `CACHE_CMD_OPCODE_Z;
            else
                cmd_type <= `CACHE_CMD_OPCODE_X;
            tmp1 <= y_*INW_;
            x_3 <= x_;
            inc3 <= inc2;
            {first_cmd3, vld3} <= {first_cmd2, vld2}; 
        end

    // Pipe stage4
    always @(posedge clk)
        if (next) begin
            tmp2 <= tmp1+x_3;
            inc4 <= inc3;
            cmd_type4 <= cmd_type;
            {first_cmd4, vld4} <= {first_cmd3, vld3};
        end

    // Pipe stage5
    always @(posedge clk)
        if (next) begin
            if (first_cmd4) begin
                if (cmd_type4 == `CACHE_CMD_OPCODE_X) begin
                    base_desc_inc <= 0;
                    base_desc_a_ <= X_a_;
                    base_desc_b_ <= 0;
                    obj_desc_inc <= inc4;
                    obj_desc_a_ <= tmp2[31:$clog2(`Q)];
                    obj_desc_b_ <= tmp2[$clog2(`Q)-1:0];
                end else begin
                    base_desc_inc <= 0;
                    base_desc_a_ <= X_a_;
                    base_desc_b_ <= 0;
                    obj_desc_inc <= 0;
                    obj_desc_a_ <= X_a_;
                    obj_desc_b_ <= 0;
                end
            end else begin
                if (cmd_type4 == `CACHE_CMD_OPCODE_E) begin
                    base_desc_inc <= obj_desc_inc;
                    base_desc_a_ <= obj_desc_a_;
                    base_desc_b_ <= obj_desc_b_;
                    obj_desc_inc <= inc4;
                    obj_desc_a_ <= init_len_per_chan_plus_X_a__minus_1;
                    obj_desc_b_ <= 0;
                end else if (cmd_type4 == `CACHE_CMD_OPCODE_X) begin
                    base_desc_inc <= obj_desc_inc;
                    base_desc_a_ <= obj_desc_a_;
                    base_desc_b_ <= obj_desc_b_;
                    obj_desc_inc <= inc4;
                    obj_desc_a_ <= tmp2[31:$clog2(`Q)];
                    obj_desc_b_ <= tmp2[$clog2(`Q)-1:0];
                end
            end
            cmd_type5 <= cmd_type4;
            vld5 <= vld4;
        end

    // Pipe stage6
    always @(posedge clk)
        if (next) begin
            if (cmd_type5==`CACHE_CMD_OPCODE_X || cmd_type5==`CACHE_CMD_OPCODE_E) begin
                if (obj_desc_inc == base_desc_inc)
                    shift6 <= obj_desc_a_-base_desc_a_;
                else
                    shift6 <= obj_desc_a_+len_per_chan-base_desc_a_;
                b_6 <= obj_desc_b_;
            end
            cmd_type6 <= cmd_type5;
            vld6 <= vld5;
        end

    // vld, opcode, shift, b_
    always @(posedge clk)
        if (next) begin
            vld <= vld6;
            case (cmd_type6)
                `CACHE_CMD_OPCODE_E: begin
                    opcode <= `CACHE_CMD_OPCODE_E;
                    shift <= shift6;
                    b_ <= 0;
                end
                `CACHE_CMD_OPCODE_Z: begin
                    opcode <= `CACHE_CMD_OPCODE_Z;
                    shift <= 0;
                    b_ <= 0;
                end
                `CACHE_CMD_OPCODE_X: begin
                    opcode <= `CACHE_CMD_OPCODE_X;
                    if (wr_first_X_cmd)
                        shift <= shift6+1;
                    else
                        shift <= shift6;
                    b_ <= b_6;
                end
            endcase
        end

    // wr_first_X_cmd
    always @(posedge clk)
        if (start_pulse) 
            wr_first_X_cmd <= 1;
        else if (vld6 && next && cmd_type6==`CACHE_CMD_OPCODE_X && wr_first_X_cmd) 
            wr_first_X_cmd <= 0;
    
    always @(posedge clk) begin
        init_len_per_chan_plus_X_a_ <= len_per_chan+X_a_;
        init_len_per_chan_plus_X_a__minus_1 <= init_len_per_chan_plus_X_a_-1;
    end
endmodule

module xbus_filter_fsm (
    input clk,
    input start_pulse,
    // Parameters
    input [7:0] Xz,
    // Cache read ports
    input cache_empty,
    input [$clog2(`XBUS_CACHE_DEPTH+1)-1:0] cache_cnt,
    output reg cache_rd_en = 0,
    output reg [$clog2(`XBUS_CACHE_DEPTH+1)-1:0] cache_rd_step = 0,
    input [`XBUS_TAG_WIDTH-1:0] cache_dout_tag,
    input [`Q*`S*8-1:0] cache_dout_data,
    // cache cmd gen
    output reg cmd_gen_start_pulse = 0,
    output reg [15:0] cmd_gen_X_a_ = 0,
    output reg [15:0] cmd_gen_len_per_chan = 0,
    output reg [15:0] cmd_gen_win_x = 0,
    output reg [15:0] cmd_gen_win_y = 0,
    // cmd fifo read ports
    input cmd_vld,
    output reg cmd_rdy = 0,
    input [1:0] cmd_opcode,
    input [15:0] cmd_shift,
    input [$clog2(`Q)-1:0] cmd_b_,
    // vector fifo write ports
    output vec_fifo_wr_en,
    output [`S*8-1:0] vec_fifo_din,
    input vec_fifo_prog_full
);
    localparam NUM_PIPE = 3;
    localparam IDLE = 0, RD_HEAD = 1, WAIT_HEAD = 2, EXEC_CMD = 3, DONE = 4;
    reg [2:0] state = IDLE;

    reg vec_fifo_wr_en_reg = 0;
    reg [`S*8-1:0] vec_fifo_din_reg = 0;

    wire cache_vld;

    reg [NUM_PIPE-1:0] cache_rd_en_pipe = 0;
    // pending cmd
    reg [1:0] pending_cmd_opcode = 0;
    reg [15:0] pending_cmd_shift = 0;
    reg [$clog2(`Q)-1:0] pending_cmd_b_ = 0;
    reg pending_cmd_vld = 0;
    // write task
    reg wr_task_vld = 0;
    reg wr_task_flag = 0;  // 0 for writing 0, 1 for writing X
    reg [$clog2(`Q)-1:0] wr_task_b_ = 0;
    reg [NUM_PIPE-1:0] wr_task_vld_pipe = 0;
    reg [NUM_PIPE-1:0] wr_task_flag_pipe = 0;
    reg [NUM_PIPE*$clog2(`Q)-1:0] wr_task_b__pipe = 0;
    integer i;

    assign cache_vld = cache_rd_en_pipe[NUM_PIPE-1];

    always @(posedge clk)
        case (state)
            IDLE: begin
                if (start_pulse)
                    state <= RD_HEAD;
            end
            RD_HEAD: begin
                if ((~cache_rd_en && ~cache_empty) || (cache_rd_en && cache_cnt>=cache_rd_step+1))
                    state <= WAIT_HEAD;
            end
            WAIT_HEAD: begin
                if (cache_vld && cache_dout_tag==`XBUS_TAG_HEAD)
                    state <= EXEC_CMD;
                else if (cache_vld && cache_dout_tag==`XBUS_TAG_END)
                    state <= DONE;
            end
            EXEC_CMD: begin
                if (
                    (cmd_vld && cmd_rdy && cmd_opcode==`CACHE_CMD_OPCODE_E && cache_cnt>=((cache_rd_en?cache_rd_step:0)+cmd_shift)) ||
                    (pending_cmd_vld && pending_cmd_opcode==`CACHE_CMD_OPCODE_E && cache_cnt>=((cache_rd_en?cache_rd_step:0)+pending_cmd_shift))
                ) state <= RD_HEAD;
            end
            DONE: state <= IDLE;
        endcase

    // cmd_gen_start_pulse, cmd_gen_X_a_, cmd_gen_len_per_chan, cmd_gen_win_x,cmd_gen_win_y 
    always @(posedge clk) begin
        cmd_gen_start_pulse <= (state==WAIT_HEAD && cache_vld && cache_dout_tag==`XBUS_TAG_HEAD);
        if (state==WAIT_HEAD && cache_vld && cache_dout_tag==`XBUS_TAG_HEAD) begin
            cmd_gen_X_a_ <= cache_dout_data[15:0];
            cmd_gen_len_per_chan <= cache_dout_data[31:16];
            cmd_gen_win_x <= cache_dout_data[47:32];
            cmd_gen_win_y <= cache_dout_data[63:48]; 
        end
    end

    // cmd_rdy (ready)
    always @(posedge clk)
        case (state)
            WAIT_HEAD: cmd_rdy <= 1;  // Ready to read next
            EXEC_CMD: begin
                if (cmd_vld && cmd_rdy)
                    case (cmd_opcode)
                        `CACHE_CMD_OPCODE_Z: cmd_rdy <= ~vec_fifo_prog_full;
                        `CACHE_CMD_OPCODE_E: cmd_rdy <= 0;  // No more valid cmd, not ready
                        `CACHE_CMD_OPCODE_X: cmd_rdy <= (cache_cnt>=((cache_rd_en?cache_rd_step:0)+cmd_shift) && ~vec_fifo_prog_full);
                    endcase
                else if (pending_cmd_vld)
                    case (pending_cmd_opcode)
                        `CACHE_CMD_OPCODE_Z: cmd_rdy <= ~vec_fifo_prog_full;
                        `CACHE_CMD_OPCODE_E: cmd_rdy <= 0;  // No more valid cmd, not ready
                        `CACHE_CMD_OPCODE_X: cmd_rdy <= (cache_cnt>=((cache_rd_en?cache_rd_step:0)+pending_cmd_shift) && ~vec_fifo_prog_full);
                    endcase
            end
            default: cmd_rdy <= 0;
        endcase
    
    // pending_cmd_vld
    always @(posedge clk)
        case (state)
            EXEC_CMD: begin
                if (cmd_vld && cmd_rdy)
                    case (cmd_opcode)
                        `CACHE_CMD_OPCODE_Z: pending_cmd_vld <= vec_fifo_prog_full;
                        `CACHE_CMD_OPCODE_E: pending_cmd_vld <= cache_cnt<((cache_rd_en?cache_rd_step:0)+cmd_shift);
                        `CACHE_CMD_OPCODE_X: pending_cmd_vld <= (vec_fifo_prog_full || cache_cnt<((cache_rd_en?cache_rd_step:0)+cmd_shift));
                    endcase
                else if (pending_cmd_vld)
                    case (pending_cmd_opcode)
                        `CACHE_CMD_OPCODE_Z: pending_cmd_vld <= vec_fifo_prog_full;
                        `CACHE_CMD_OPCODE_E: pending_cmd_vld <= cache_cnt<((cache_rd_en?cache_rd_step:0)+pending_cmd_shift);
                        `CACHE_CMD_OPCODE_X: pending_cmd_vld <= (vec_fifo_prog_full || cache_cnt<((cache_rd_en?cache_rd_step:0)+pending_cmd_shift));
                    endcase
            end
            default: pending_cmd_vld <= 0;
        endcase

    // pending_cmd_opcode, pending_cmd_shift, pending_cmd_b_
    always @(posedge clk)
        if (cmd_vld && cmd_rdy) begin
            pending_cmd_opcode <= cmd_opcode;
            pending_cmd_shift <= cmd_shift;
            pending_cmd_b_ <= cmd_b_;
        end

    // cache_rd_en
    always @(posedge clk)
        case (state)
            RD_HEAD: cache_rd_en <= ((~cache_rd_en && ~cache_empty) || (cache_rd_en && cache_cnt>=cache_rd_step+1));
            EXEC_CMD: begin
                if (cmd_vld && cmd_rdy)
                    case (cmd_opcode)
                        `CACHE_CMD_OPCODE_Z: cache_rd_en <= 0;
                        `CACHE_CMD_OPCODE_E: cache_rd_en <= cache_cnt>=((cache_rd_en?cache_rd_step:0)+cmd_shift) && cmd_shift!=0;
                        `CACHE_CMD_OPCODE_X: cache_rd_en <= cache_cnt>=((cache_rd_en?cache_rd_step:0)+cmd_shift) && ~vec_fifo_prog_full && cmd_shift!=0;
                    endcase
                else if (pending_cmd_vld)
                    case (pending_cmd_opcode)
                        `CACHE_CMD_OPCODE_Z: cache_rd_en <= 0;
                        `CACHE_CMD_OPCODE_E: cache_rd_en <= cache_cnt>=((cache_rd_en?cache_rd_step:0)+pending_cmd_shift) && pending_cmd_shift!=0;
                        `CACHE_CMD_OPCODE_X: cache_rd_en <= cache_cnt>=((cache_rd_en?cache_rd_step:0)+pending_cmd_shift) && ~vec_fifo_prog_full && pending_cmd_shift!=0;
                    endcase
            end
            default: cache_rd_en <= 0;
        endcase

    // cache_rd_step
    always @(posedge clk)
        case (state)
            RD_HEAD: cache_rd_step <= 1;
            EXEC_CMD: begin
                if (cmd_vld && cmd_rdy)
                    cache_rd_step <= cmd_shift;
                else if (pending_cmd_vld)
                    cache_rd_step <= pending_cmd_shift;
            end
        endcase

    // wr_task_vld
    always @(posedge clk)
        case (state)
            EXEC_CMD: begin
                if (cmd_vld && cmd_rdy)
                    case (cmd_opcode)
                        `CACHE_CMD_OPCODE_Z: wr_task_vld <= ~vec_fifo_prog_full;
                        `CACHE_CMD_OPCODE_E: wr_task_vld <= 0;
                        `CACHE_CMD_OPCODE_X: wr_task_vld <= cache_cnt>=((cache_rd_en?cache_rd_step:0)+cmd_shift) && ~vec_fifo_prog_full;
                    endcase
                else if (pending_cmd_vld)
                    case (pending_cmd_opcode)
                        `CACHE_CMD_OPCODE_Z: wr_task_vld <= ~vec_fifo_prog_full;
                        `CACHE_CMD_OPCODE_E: wr_task_vld <= 0;
                        `CACHE_CMD_OPCODE_X: wr_task_vld <= cache_cnt>=((cache_rd_en?cache_rd_step:0)+pending_cmd_shift) && ~vec_fifo_prog_full;
                    endcase
            end
            default: wr_task_vld <= 0;
        endcase

    // wr_task_flag
    always @(posedge clk)
        if (cmd_vld && cmd_rdy) begin
            if (cmd_opcode==`CACHE_CMD_OPCODE_Z)
                wr_task_flag <= 0;
            else
                wr_task_flag <= 1;
        end else if (pending_cmd_vld) begin
            if (pending_cmd_opcode==`CACHE_CMD_OPCODE_Z)
                wr_task_flag <= 0;
            else
                wr_task_flag <= 1;
        end

    // wr_task_b_
    always @(posedge clk)
        if (cmd_vld && cmd_rdy)
            wr_task_b_ <= cmd_b_;
        else if (pending_cmd_vld)
            wr_task_b_ <= pending_cmd_b_;

    // Write task
    always @(posedge clk) begin
        wr_task_vld_pipe[0] <= wr_task_vld;
        for (i=1; i<NUM_PIPE; i=i+1)
            wr_task_vld_pipe[i] <= wr_task_vld_pipe[i-1];
    end

    always @(posedge clk) begin
        wr_task_flag_pipe[0] <= wr_task_flag;
        for (i=1; i<NUM_PIPE; i=i+1)
            wr_task_flag_pipe[i] <= wr_task_flag_pipe[i-1];
    end

    always @(posedge clk) begin
        wr_task_b__pipe[$clog2(`Q)-1:0] <= wr_task_b_;
        for (i=1; i<NUM_PIPE; i=i+1)
            wr_task_b__pipe[i*$clog2(`Q)+:$clog2(`Q)] <= wr_task_b__pipe[(i-1)*$clog2(`Q)+:$clog2(`Q)];
    end

    // cache_rd_en_pipe
    always @(posedge clk) begin
        cache_rd_en_pipe[0] <= cache_rd_en;
        for(i=1; i<NUM_PIPE; i=i+1) 
            cache_rd_en_pipe[i] <= cache_rd_en_pipe[i-1];
    end

    // Outputs (vec_fifo_wr_en_reg, vec_fifo_din_reg)
    always @(posedge clk) begin
        vec_fifo_wr_en_reg <= wr_task_vld_pipe[NUM_PIPE-1];
        if (~wr_task_flag_pipe[NUM_PIPE-1])
            for (i=0; i<`S; i=i+1)
                vec_fifo_din_reg[i*8+:8] <= Xz;
        else
            for (i=0; i<`S; i=i+1)
                vec_fifo_din_reg[i*8+:8] <= cache_dout_data[(i*`Q+wr_task_b__pipe[(NUM_PIPE-1)*$clog2(`Q)+:$clog2(`Q)])*8+:8];
    end

`ifdef M32P64Q16R16S8
    // Add additional pipeline stages for high performance
    shift_reg #(1, 1) shift_reg_vec_fifo_wr_en(clk, vec_fifo_wr_en_reg, vec_fifo_wr_en);
    shift_reg #(1, `S*8) shift_reg_vec_fifo_din(clk, vec_fifo_din_reg, vec_fifo_din);
`elsif M32P96Q16R16S8
    // Add additional pipeline stages for high performance
    shift_reg #(1, 1) shift_reg_vec_fifo_wr_en(clk, vec_fifo_wr_en_reg, vec_fifo_wr_en);
    shift_reg #(1, `S*8) shift_reg_vec_fifo_din(clk, vec_fifo_din_reg, vec_fifo_din);
`elsif M64P64Q16R16S8
    // Add additional pipeline stages for high performance
    shift_reg #(1, 1) shift_reg_vec_fifo_wr_en(clk, vec_fifo_wr_en_reg, vec_fifo_wr_en);
    shift_reg #(1, `S*8) shift_reg_vec_fifo_din(clk, vec_fifo_din_reg, vec_fifo_din);
`else
    assign vec_fifo_wr_en = vec_fifo_wr_en_reg;
    assign vec_fifo_din = vec_fifo_din_reg;
`endif
endmodule
