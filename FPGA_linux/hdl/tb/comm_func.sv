//
// This file will be included by most test modules.
//

`ifndef M
`include "../src/incl.vh"
`endif

//////////////////////////////////////////////////////////////////////////
//  Register space
// Write data into register space
task automatic sr_cr_write(input bit [31:0] reg_idx, input bit [31:0] data);
    xil_axi_resp_t sr_cr_resp;
    bit[31:0] sr_cr_base_addr = 32'h0000_0000;
    sr_cr_agent.AXI4LITE_WRITE_BURST(sr_cr_base_addr+reg_idx*4,0,data,sr_cr_resp);
endtask

//////////////////////////////////////////////////////////////////////////
//  DRAM 
// Write a batch of data into DRAM
task automatic dram_wr(input bit[31:0] addr, input [31:0] n_bytes, input [7:0] arr []);
    bit [511:0] wr_data = 0;
    bit [31:0] wr_addr = 0;
    
    wr_addr = addr;
    for (bit[31:0] i=0; i<n_bytes/64; i++) begin
        for (int j=0; j<64; j++)
            wr_data[j*8+:8] = arr[i*64+j];
        backdoor_mem_write(wr_addr, wr_data);
        wr_addr += 64;
    end
endtask 

// Read a batch of data from DRAM
task automatic dram_rd(input bit[31:0] addr, input [31:0] n_bytes, output [7:0] arr []);
    bit [511:0] rd_data = 0;
    bit [31:0] rd_addr = 0;

    arr = new [n_bytes];
    rd_addr = addr;
    for (bit[31:0] i=0; i<n_bytes/64; i++) begin
        backdoor_mem_read(rd_addr, rd_data);
        for (int j=0; j<64; j++)
            arr[i*64+j] = rd_data[j*8+:8];
        rd_addr += 64;
    end
endtask 

// Write data (64 bytes) into DRAM
task automatic backdoor_mem_write(input bit[31:0] addr, input bit [511:0] wr_data);
    bit[31:0] a, b;
    int l, r;
    bit [512-1:0] data1, data2;
    bit [63:0] strb1, strb2;
    
    if (addr%64==0) 
        ddr_agent.mem_model.backdoor_memory_write(addr, wr_data, {64{1'b1}});
    else begin
        a = (addr / 64) * 64;
        b = a + 64;
        l = b - addr;
        r = 64 - l;

        for (int i = 0; i < 64; i++)
            if (i < (64 - l)) begin
                data1[i*8+:8] = 0;
                strb1[i] = 0;
            end else begin
                data1[i*8+:8] = wr_data[8*(i-(64-l))+:8];
                strb1[i] = 1;
            end 

        for (int i = 0; i < 64; i++)
            if (i < r) begin
                data2[i*8+:8] = wr_data[8*(i+l)+:8];;
                strb2[i] = 1;
            end else begin
                data2[i*8+:8] = 0;
                strb2[i] = 0;
            end 

        ddr_agent.mem_model.backdoor_memory_write(a, data1, strb1);
        ddr_agent.mem_model.backdoor_memory_write(b, data2, strb2);
    end
endtask

// Read data (64 bytes) from DRAM
task automatic backdoor_mem_read(input bit[31:0] addr, output bit [511:0] data);
    bit[31:0] a, b;
    int l, r;
    bit [512-1:0] data1, data2;

    if (addr % 64 == 0) 
        data = ddr_agent.mem_model.backdoor_memory_read(addr);
    else begin
        a = (addr/64)*64;
        b = a + 64;
        l = b - addr;
        r = 64 - l;
        data1 = ddr_agent.mem_model.backdoor_memory_read(a);
        data2 = ddr_agent.mem_model.backdoor_memory_read(b);
        for (int i = 0; i < l; i++) 
            data[i*8+:8] = data1[(64-l+i)*8+:8];
        for (int i = 0; i < r; i++)
            data[(i+l)*8+:8] = data2[i*8+:8];
    end
endtask 

//////////////////////////////////////////////////////////////////////////
//  RTM 
// Read an item from RTM
task automatic rtm_item_rd(input int ram_id, input bit[31:0] addr, output bit[`R*8-1:0] data);
    case (ram_id)
        0: data = dut.verify_top_i.top.inst.rtm_inst.rtm_mem_inst.RTM[0].sdp_uram_inst.mem[addr];
        1: data = dut.verify_top_i.top.inst.rtm_inst.rtm_mem_inst.RTM[1].sdp_uram_inst.mem[addr];
        2: data = dut.verify_top_i.top.inst.rtm_inst.rtm_mem_inst.RTM[2].sdp_uram_inst.mem[addr];
        3: data = dut.verify_top_i.top.inst.rtm_inst.rtm_mem_inst.RTM[3].sdp_uram_inst.mem[addr];
`ifdef __S_6
        4: data = dut.verify_top_i.top.inst.rtm_inst.rtm_mem_inst.RTM[4].sdp_uram_inst.mem[addr];
        5: data = dut.verify_top_i.top.inst.rtm_inst.rtm_mem_inst.RTM[5].sdp_uram_inst.mem[addr];
`endif
`ifdef __S_8
        6: data = dut.verify_top_i.top.inst.rtm_inst.rtm_mem_inst.RTM[6].sdp_uram_inst.mem[addr];
        7: data = dut.verify_top_i.top.inst.rtm_inst.rtm_mem_inst.RTM[7].sdp_uram_inst.mem[addr];
`endif
`ifdef __S_10
        8: data = dut.verify_top_i.top.inst.rtm_inst.rtm_mem_inst.RTM[8].sdp_uram_inst.mem[addr];
        9: data = dut.verify_top_i.top.inst.rtm_inst.rtm_mem_inst.RTM[9].sdp_uram_inst.mem[addr];
`endif
`ifdef __S_12
        10: data = dut.verify_top_i.top.inst.rtm_inst.rtm_mem_inst.RTM[10].sdp_uram_inst.mem[addr];
        11: data = dut.verify_top_i.top.inst.rtm_inst.rtm_mem_inst.RTM[11].sdp_uram_inst.mem[addr];
`endif
        default: data = dut.verify_top_i.top.inst.rtm_inst.rtm_mem_inst.RTM[0].sdp_uram_inst.mem[addr];
    endcase
endtask

// Read data from RTM
task automatic rtm_rd(input bit[31:0] addr, input bit[31:0] len, output bit [`S*`R*8-1:0] arr []);
    arr = new [len];
    for (bit[31:0] i=0; i<len; i++)
        for (int j=0; j<`S; j++)
            rtm_item_rd(j, addr+i, arr[i][j*`R*8+:`R*8]);
endtask

// Read data from RTM (byte mode)
task automatic rtm_rd_byte(input bit[31:0] addr, input bit[31:0] len, output bit [7:0] arr []);
    bit [`R*8-1:0] rtm_data; 
    
    arr = new [`R*`S*len];
    for (bit[31:0] i=0; i<len; i++)
        for (int j=0; j<`S; j++) begin
            rtm_item_rd(j, addr+i, rtm_data);
            for (int k=0; k<`R; k++)
                arr[i*`R*`S+j*`R+k] = rtm_data[k*8+:8];
        end
endtask

// Read data from RTM (tensor mode)
task automatic rtm_rd_tensor(input bit[31:0] addr, output bit [7:0] arr [], input int OC, input int ofm_height);
    bit [`R*8-1:0] rtm_data;
    int OF_size = 0;

    OF_size = `R*ofm_height;

    arr = new [OF_size*OC];
    for (int oc=0; oc<OC; oc++)
        for (int h=0; h<ofm_height; h++) begin
            rtm_item_rd(oc%`S, addr+oc/`S*ofm_height+h, rtm_data);
            for (int i=0; i<`R; i++)
                arr[oc*OF_size+h*`R+i] = rtm_data[i*8+:8];
        end
endtask

// Read data from RTM (vector mode, vectors with any size are supported)
task automatic rtm_rd_vector(input bit[31:0] addr, output bit [7:0] arr [], input int vec_size);
    bit [`R*8-1:0] rtm_data;
    int batch_cnt = 0;
    int valid_ele_cnt = 0;

    batch_cnt = $ceil(vec_size*1.0/`R);

    arr = new [vec_size];
    for (int i=0; i<batch_cnt; i++) begin
        /* Determine the numver of valid elements in this batch. */
        valid_ele_cnt = `R;
        if (i == batch_cnt-1)
            valid_ele_cnt = vec_size-(batch_cnt-1)*`R;
        /* Read data from RTM */
        rtm_item_rd(i%`S, addr+i/`S, rtm_data);
        /* Copy data to arr */
        for (int j=0; j<valid_ele_cnt; j++)
            arr[i*`R+j] = rtm_data[j*8+:8];
    end
endtask

// Write an item into RTM
task automatic rtm_item_wr(input int ram_id, input bit[31:0] addr, input bit[`R*8-1:0] data);
    case (ram_id)
        0: dut.verify_top_i.top.inst.rtm_inst.rtm_mem_inst.RTM[0].sdp_uram_inst.mem[addr] = data;
        1: dut.verify_top_i.top.inst.rtm_inst.rtm_mem_inst.RTM[1].sdp_uram_inst.mem[addr] = data;
        2: dut.verify_top_i.top.inst.rtm_inst.rtm_mem_inst.RTM[2].sdp_uram_inst.mem[addr] = data;
        3: dut.verify_top_i.top.inst.rtm_inst.rtm_mem_inst.RTM[3].sdp_uram_inst.mem[addr] = data;
        default: dut.verify_top_i.top.inst.rtm_inst.rtm_mem_inst.RTM[0].sdp_uram_inst.mem[addr] = data;
`ifdef __S_6
        4: dut.verify_top_i.top.inst.rtm_inst.rtm_mem_inst.RTM[4].sdp_uram_inst.mem[addr] = data;
        5: dut.verify_top_i.top.inst.rtm_inst.rtm_mem_inst.RTM[5].sdp_uram_inst.mem[addr] = data;
`endif
`ifdef __S_8
        6: dut.verify_top_i.top.inst.rtm_inst.rtm_mem_inst.RTM[6].sdp_uram_inst.mem[addr] = data;
        7: dut.verify_top_i.top.inst.rtm_inst.rtm_mem_inst.RTM[7].sdp_uram_inst.mem[addr] = data;
`endif
`ifdef __S_10
        8: dut.verify_top_i.top.inst.rtm_inst.rtm_mem_inst.RTM[8].sdp_uram_inst.mem[addr] = data;
        9: dut.verify_top_i.top.inst.rtm_inst.rtm_mem_inst.RTM[9].sdp_uram_inst.mem[addr] = data;
`endif
`ifdef __S_12
        10: dut.verify_top_i.top.inst.rtm_inst.rtm_mem_inst.RTM[10].sdp_uram_inst.mem[addr] = data;
        11: dut.verify_top_i.top.inst.rtm_inst.rtm_mem_inst.RTM[11].sdp_uram_inst.mem[addr] = data;
`endif
    endcase
endtask

// Write data to RTM
task automatic rtm_wr(input bit[31:0] addr, input bit[31:0] len, input bit [`R*`S*8-1:0] arr []);
    for (bit[31:0] i=0; i<len; i++)
        for (int j=0; j<`S; j++)
            rtm_item_wr(j, addr+i, arr[i][j*`R*8+:`R*8]);
endtask 

// Write data to RTM (byte mode)
task automatic rtm_wr_byte(input bit[31:0] addr, input bit[31:0] len, input bit [7:0] arr []);
    bit [`R*8-1:0] rtm_data;

    for (bit[31:0] i=0; i<len; i++)
        for (int j=0; j<`S; j++) begin
            for (int k=0; k<`R; k++)
                rtm_data[k*8+:8] = arr[i*`S*`R+j*`R+k];
            rtm_item_wr(j, addr+i, rtm_data);
        end
endtask 

// Write data to RTM (tensor mode, support tensors with any shape.)
task automatic rtm_wr_tensor(input bit[31:0] addr, input bit [7:0] arr [], input int INC, input int INH_, input int INW_);
    int IF_size = 0, ifm_height = 0;
    bit [`R*8-1:0] rtm_data;

    IF_size = INH_*INW_;
    ifm_height = $ceil(IF_size*1.0/`R);

    for (int inc=0; inc<INC; inc++)
        for (int h=0; h<ifm_height; h++) begin
            for (int i=0; i<`R; i++)
                if (h*`R+i<IF_size) 
                    rtm_data[i*8+:8] = arr[inc*IF_size+h*`R+i];
                else 
                    rtm_data[i*8+:8] = 0;
            rtm_item_wr(inc%`S, addr+inc/`S*ifm_height+h, rtm_data);
        end
endtask

// Write data to RTM (vector mode, vectors with any size are supported)
task automatic rtm_wr_vector(input bit[31:0] addr, input bit [7:0] arr []);
    bit [`R*8-1:0] rtm_data;
    int batch_cnt = 0;
    int valid_ele_cnt = 0;

    batch_cnt = $ceil(arr.size()*1.0/`R);

    for (int i=0; i<batch_cnt; i++) begin
        /* Determine the numver of valid elements in this batch. */
        valid_ele_cnt = `R;
        if (i == batch_cnt-1)
            valid_ele_cnt = arr.size()-(batch_cnt-1)*`R;
        /* Copy data from arr */
        for (int j=0; j<valid_ele_cnt; j++)
            rtm_data[j*8+:8] = arr[i*`R+j];
        /* Write data into RTM */
        rtm_item_wr(i%`S, addr+i/`S, rtm_data);
    end
endtask

//////////////////////////////////////////////////////////////////////////
//  CWM 
// Write an entry into CWM
task automatic cwm_item_wr(input bit[31:0] addr, input bit[`M*4*8-1:0] data);
    dut.verify_top_i.top.inst.cwm_inst.cwm_mem_inst.sdp_uram_inst.mem[addr] = data;
endtask 

// Write data to CWM (byte mode)
task automatic cwm_wr_bytes(input bit[31:0] addr, input bit[31:0] len, input bit [7:0] arr []);
    bit [`M*4*8-1:0] cwm_data;

    for (bit[31:0] i=0; i<len; i++) begin
        for (int j=0; j<`M*4; j++)
            cwm_data[j*8+:8] = arr[i*`M*4+j];
        cwm_item_wr(addr+i, cwm_data);
    end
endtask

//////////////////////////////////////////////////////////////////////////
//  IM
// Write data to IM
task automatic im_wr(input bit[31:0] addr, input bit[31:0] len, input bit[`INS_RAM_DATA_WIDTH-1:0] arr []);
    for (bit[31:0] i=0; i<len; i++)
        im_item_wr(addr+i, arr[i]);
endtask 

// Write an entry into IM
task automatic im_item_wr(input bit[31:0] addr, input bit[`INS_RAM_DATA_WIDTH-1:0] data);
    dut.verify_top_i.top.inst.im_inst.im_mem_inst.sdp_bram_inst.mem[addr] = data;
endtask

//////////////////////////////////////////////////////////////////////////
//  BM 
// Write an entry into BM
task automatic bm_item_wr(input bit[31:0] addr, input bit[`BM_DATA_WIDTH-1:0] data);
    dut.verify_top_i.top.inst.bm_inst.bm_mem_inst.sdp_bram_inst.mem[addr] = data;
endtask 

// Write data into BM (byte mode)
task automatic bm_wr_bytes(input bit[31:0] addr, input bit[31:0] len, input bit [7:0] arr []);
    bit [`BM_DATA_WIDTH-1:0] bm_data;

    for (bit[31:0] i=0; i<len; i++) begin
        for (int j=0; j<`BM_DATA_WIDTH/8; j++)
            bm_data[j*8+:8] = arr[i*`BM_DATA_WIDTH/8+j];
        bm_item_wr(addr+i, bm_data);
    end
endtask

//////////////////////////////////////////////////////////////////////////
//  XPHM 
// Write data to XPHM
task automatic xphm_wr(input bit[31:0] addr, input bit[31:0] len, input bit[`XPHM_DATA_WIDTH-1:0] arr []);
    for (bit[31:0] i=0; i<len; i++)
        xphm_item_wr(addr+i, arr[i]);
endtask

// Write data to XPHM (byte mode)
task automatic xphm_wr_byte(input bit[31:0] addr, input bit[31:0] len, input bit[7:0] arr []);
    bit[`XPHM_DATA_WIDTH-1:0] xphm_data;
    
    for (bit[31:0] i=0; i<len; i++) begin
        for (bit[31:0] j=0; j<`XPHM_DATA_WIDTH/8; j++)
            xphm_data[j*8+:8] = arr[i*`XPHM_DATA_WIDTH/8+j];
        xphm_item_wr(addr+i, xphm_data);
    end
endtask 

// Write an entry into XPHM
task automatic xphm_item_wr(input bit[31:0] addr, input bit [`XPHM_DATA_WIDTH-1:0] data);
    dut.verify_top_i.top.inst.xphm_inst.xphm_mem_inst.sdp_bram_inst.mem[addr] = data;
endtask

//////////////////////////////////////////////////////////////////////////
//  File Utils
// File size (number of bytes)
function automatic int get_file_size(input string fp);
    int fd;
    int ret;

    fd = $fopen(fp, "rb");
    $fseek(fd, 0, 2);
    ret = $ftell(fd);
    $fclose(fd);
    return ret;
endfunction

// Read .hex file
task automatic read_hex_file(input string fp, output bit [7:0] bytes []);
    int fd;
    int n_bytes;

    n_bytes = get_file_size(fp);
    bytes = new [n_bytes];
    fd = $fopen(fp, "rb");
    for (int i=0; i<n_bytes; i++) 
        $fscanf(fd, "%c", bytes[i]);
    $fclose(fd);
endtask 

//////////////////////////////////////////////////////////////////////////
//  Other Utils
function automatic int get_progress_rate(input int curr, input int total);
    int ret = 0;
    ret = curr*100/total;
    return ret;
endfunction

// Find the number of testcases by reading the ins.txt file.
function automatic int get_case_count(input string ins_file_path);
    int ret = 0;
    int fd = 0;
    string line = "";

    fd = $fopen(ins_file_path, "r");
    while (!$feof(fd)) begin
        $fgets(line, fd);
        ret ++;
    end

    $fclose(fd);
    return ret-1;
endfunction

// Write a line to a file in append mode
function automatic void append_line(input string fp, input string line);
    int fd = 0;

    fd = $fopen(fp, "a");
    $fdisplay(fd, line);

    $fclose(fd);
endfunction
