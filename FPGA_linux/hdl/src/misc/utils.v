`timescale 1ns / 1ps

//
// Detect the rising edge of the signal
//
module posedge_det (
    input clk,
    input sig,
    output reg pulse = 0
);
    reg ff = 0, ff2 = 0;

    always @(posedge clk) begin
        ff <= sig;
        ff2 <= ff;
    end

    always @(posedge clk)
        pulse <= (ff && ~ff2);
endmodule

//
// Shift register
//
module shift_reg #(
    parameter DELAY = 192,
    parameter DATA_WIDTH = 8
) (
    input clk,
    input [DATA_WIDTH-1:0] i,
    output [DATA_WIDTH-1:0] o
);
    generate
        if (DELAY==0) begin
            assign o = i;
        end else begin
            reg [DATA_WIDTH-1:0] pipes [DELAY-1:0];
            integer k;

            initial begin
                for (k=0; k<DELAY; k=k+1) 
                    pipes[k] <= {DATA_WIDTH{1'b0}};
            end

            assign o = pipes[DELAY-1];

            always @(posedge clk) begin
                pipes[0] <= i;
                for (k=1; k<DELAY; k=k+1) 
                    pipes[k] <= pipes[k-1];
            end
        end
    endgenerate
endmodule

module gen_fake_sig #(
    parameter W = 4,
    parameter P = W-1
)(
    input clk,
    output sig
);
    reg [W-1:0] cnt = 0;

    always @(posedge clk) begin
        cnt <= cnt+1;
    end

    assign sig = cnt[P];
endmodule

//
// Synchronious FIFO
// Read and write operations are always valid.
//
module sync_fifo #(
    parameter DATA_WIDTH = 512,
    parameter DEPTH = 32,
    parameter PROG_FULL = 16,
    parameter READ_LATENCY = 1,  // read latency, default value is 1 cycle
    parameter HAS_EMPTY = 1,
    parameter HAS_ALMOST_EMPTY = 1,
    parameter HAS_DATA_VALID = 0,
    parameter HAS_PROG_FULL = 0,
    parameter RAM_STYLE = "distributed"
)(
    input clk,
    // Read ports
    input rd_en,
    output [DATA_WIDTH-1:0] dout,
    output data_valid,
    output reg empty = 1,
    output reg almost_empty = 1,
    // Write ports
    input wr_en,
    input [DATA_WIDTH-1:0] din,
    output reg prog_full = 0
);
    localparam RAM_PRT_WIDTH = $clog2(DEPTH);
    (* ram_style=RAM_STYLE *) reg [DATA_WIDTH-1:0] mem [DEPTH-1:0];
    integer k;

    // count
    reg [RAM_PRT_WIDTH:0] count = 0;
    reg [RAM_PRT_WIDTH:0] count_next;

    always @(*) begin
        if (rd_en && ~wr_en)
            count_next = count-1;
        else if (~rd_en && wr_en)
            count_next = count+1;
        else
            count_next = count;
    end

    always @(posedge clk)
        count <= count_next;

    // Write
    reg [RAM_PRT_WIDTH-1:0] wr_ptr = 0;
    wire [RAM_PRT_WIDTH-1:0] wr_ptr_next;
    assign wr_ptr_next = wr_ptr+wr_en;

    always @(posedge clk) begin
        if (wr_en)
            mem[wr_ptr] <= din;
        wr_ptr <= wr_ptr_next;
    end

    // Read
    reg [DATA_WIDTH-1:0] dout_reg = 0;
    reg [RAM_PRT_WIDTH-1:0] rd_ptr = 0;
    wire [RAM_PRT_WIDTH-1:0] rd_ptr_next;
    assign rd_ptr_next = rd_ptr+rd_en;

    always @(posedge clk) begin
        if (rd_en)
            dout_reg <= mem[rd_ptr];
        rd_ptr <= rd_ptr_next;
    end

    shift_reg #(
        .DELAY(READ_LATENCY-1),
        .DATA_WIDTH(DATA_WIDTH)
    ) shift_reg_inst(
        .clk(clk),
        .i(dout_reg),
        .o(dout)
    );

    // Flags
    generate if (HAS_EMPTY) begin: gen_empty
        always @(posedge clk) 
            empty <= (count_next==0);
    end endgenerate

    generate if (HAS_ALMOST_EMPTY) begin: gen_al_empty
        always @(posedge clk) 
            almost_empty <= (count_next==0 || count_next==1);
    end endgenerate

    generate if (HAS_PROG_FULL) begin: gen_prog_full
        always @(posedge clk) 
            prog_full <= (count_next>PROG_FULL);
    end endgenerate

    generate if (HAS_DATA_VALID) begin: gen_data_valid
        shift_reg #(
            .DELAY(READ_LATENCY),
            .DATA_WIDTH(1)
        ) shift_reg_inst(
            .clk(clk),
            .i(rd_en),
            .o(data_valid)
        );
    end endgenerate
endmodule

//
// True Dual Port BRAM
//
module tdp_bram # (
    parameter DATA_WIDTH = 36,
    parameter DEPTH = 2**10,
    parameter NUM_PIPE = 2
) (
    input clk,
    // Port A
    input wea,
    input [DATA_WIDTH-1:0] dina,
    input [$clog2(DEPTH)-1:0] addra,
    output [DATA_WIDTH-1:0] douta,
    // Port B
    input web,
    input [DATA_WIDTH-1:0] dinb,
    input [$clog2(DEPTH)-1:0] addrb,
    output [DATA_WIDTH-1:0] doutb
);
    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] mem [DEPTH-1:0];

    reg [DATA_WIDTH-1:0] memrega = 0;
    reg [DATA_WIDTH-1:0] mem_pipe_rega [NUM_PIPE-1:0];
    reg [DATA_WIDTH-1:0] memregb = 0;
    reg [DATA_WIDTH-1:0] mem_pipe_regb [NUM_PIPE-1:0];
    integer i;

    initial begin
        for (i=1; i<NUM_PIPE; i=i+1) begin
            mem_pipe_rega[i] = 0;
            mem_pipe_regb[i] = 0;
        end
    end

    //
    // Port A
    //
    always @(posedge clk)
        if (wea)
            mem[addra] <= dina;
        else
            memrega <= mem[addra];

    always @(posedge clk) begin
        mem_pipe_rega[0] <= memrega;
        for (i=1; i<NUM_PIPE; i=i+1)
            mem_pipe_rega[i] <= mem_pipe_rega[i-1];
    end

    assign douta = mem_pipe_rega[NUM_PIPE-1];

    //
    // Port B
    //
    always @(posedge clk)
        if (web)
            mem[addrb] <= dinb;
        else
            memregb <= mem[addrb];
    
    always @(posedge clk) begin
        mem_pipe_regb[0] <= memregb;
        for (i=1; i<NUM_PIPE; i=i+1)
            mem_pipe_regb[i] <= mem_pipe_regb[i-1];
    end

    assign doutb = mem_pipe_regb[NUM_PIPE-1];
endmodule

//
// True Dual Port URAM
//
module tdp_uram #(
    parameter DATA_WIDTH = 256,
    parameter DEPTH = 2**16,
    parameter NUM_PIPE = 10
) (
    input clk,
    // Port A
    input wea,
    input [DATA_WIDTH-1:0] dina,
    input [$clog2(DEPTH)-1:0] addra,
    output [DATA_WIDTH-1:0] douta,
    // Port B
    input web,
    input [DATA_WIDTH-1:0] dinb,
    input [$clog2(DEPTH)-1:0] addrb,
    output [DATA_WIDTH-1:0] doutb
);
    (* ram_style = "ultra" *) reg [DATA_WIDTH-1:0] mem [DEPTH-1:0];

    reg [DATA_WIDTH-1:0] memrega = 0;
    reg [DATA_WIDTH-1:0] mem_pipe_rega [NUM_PIPE-1:0];
    reg [DATA_WIDTH-1:0] memregb = 0;
    reg [DATA_WIDTH-1:0] mem_pipe_regb [NUM_PIPE-1:0];
    integer i;

    initial begin
        for (i=1; i<NUM_PIPE; i=i+1) begin
            mem_pipe_rega[i] = 0;
            mem_pipe_regb[i] = 0;
        end
    end

    //
    // Port A
    //
    always @(posedge clk)
        if (wea)
            mem[addra] <= dina;
        else
            memrega <= mem[addra];

    always @(posedge clk) begin
        mem_pipe_rega[0] <= memrega;
        for (i=1; i<NUM_PIPE; i=i+1)
            mem_pipe_rega[i] <= mem_pipe_rega[i-1];
    end

    assign douta = mem_pipe_rega[NUM_PIPE-1];

    //
    // Port B
    //
    always @(posedge clk)
        if (web)
            mem[addrb] <= dinb;
        else
            memregb <= mem[addrb];
    
    always @(posedge clk) begin
        mem_pipe_regb[0] <= memregb;
        for (i=1; i<NUM_PIPE; i=i+1)
            mem_pipe_regb[i] <= mem_pipe_regb[i-1];
    end

    assign doutb = mem_pipe_regb[NUM_PIPE-1];
endmodule

//
// Simple Dual Port URAM
//
module sdp_uram #(
    parameter DATA_WIDTH = 72,
    parameter DEPTH = 2**13,
    parameter NUM_PIPE = 3
)(
    input clk,
    // Write Ports
    input wr_en,
    input [DATA_WIDTH-1:0] din,
    input [$clog2(DEPTH)-1:0] wr_addr,
    // Read Ports
    input rd_en,
    input [$clog2(DEPTH)-1:0] rd_addr,
    output [DATA_WIDTH-1:0] dout
);
    (* ram_style = "ultra" *) reg [DATA_WIDTH-1:0] mem [DEPTH-1:0];

    reg [DATA_WIDTH-1:0] memreg = 0;
    reg [DATA_WIDTH-1:0] mem_pipe_reg [NUM_PIPE-1:0];
    reg [NUM_PIPE-1:0] rd_en_pipe = 0;
    integer i;

    initial begin
        for (i=0; i<NUM_PIPE; i=i+1)
            mem_pipe_reg[i] = 0;
    end

    always @(posedge clk)
        if (wr_en)
            mem[wr_addr] <= din;

    always @(posedge clk)
        if (rd_en)
            memreg <= mem[rd_addr];

    always @(posedge clk) begin
        if (rd_en_pipe[0])
            mem_pipe_reg[0] <= memreg;
        for (i=1; i<NUM_PIPE; i=i+1)
            if (rd_en_pipe[i])
                mem_pipe_reg[i] <= mem_pipe_reg[i-1];
    end

    always @(posedge clk) begin
        rd_en_pipe[0] <= rd_en;
        for (i=1; i<NUM_PIPE; i=i+1)
            rd_en_pipe[i] <= rd_en_pipe[i-1];
    end

    assign dout = mem_pipe_reg[NUM_PIPE-1];
endmodule

//
// Simple Dual Port BRAM
//
module sdp_bram #(
    parameter DATA_WIDTH = 36,
    parameter DEPTH = 2**10,
    parameter NUM_PIPE = 2
)(
    input clk,
    // Write Ports
    input wr_en,
    input [DATA_WIDTH-1:0] din,
    input [$clog2(DEPTH)-1:0] wr_addr,
    // Read Ports
    input rd_en,
    input [$clog2(DEPTH)-1:0] rd_addr,
    output [DATA_WIDTH-1:0] dout
);
    (* ram_style = "block" *) reg [DATA_WIDTH-1:0] mem [DEPTH-1:0];

    reg [DATA_WIDTH-1:0] memreg = 0;
    reg [DATA_WIDTH-1:0] mem_pipe_reg [NUM_PIPE-1:0];
    integer i;

    initial begin
        for (i=0; i<NUM_PIPE; i=i+1)
            mem_pipe_reg[i] = 0;
    end

    always @(posedge clk)
        if (wr_en)
            mem[wr_addr] <= din;

    always @(posedge clk)
        if (rd_en)
            memreg <= mem[rd_addr];

    always @(posedge clk) begin
        mem_pipe_reg[0] <= memreg;
        for (i=1; i<NUM_PIPE; i=i+1)
            mem_pipe_reg[i] <= mem_pipe_reg[i-1];
    end

    assign dout = mem_pipe_reg[NUM_PIPE-1];
endmodule
