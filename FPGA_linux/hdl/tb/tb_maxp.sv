`timescale 1ns / 1ps
`include "../src/incl.vh"

`ifndef DIR_PATH
// This is the default directory.
`define DIR_PATH "/home/hp50/Desktop/FPGA_linux/cnn_accel6/hdl/tb/sim_maxp"
`endif

import axi_vip_pkg::*;
import verify_top_axi_vip_0_0_pkg::*;
import verify_top_axi_vip_0_1_pkg::*;

module tb_maxp;
    class Ins;
        bit [15:0] xphs_addr;
        bit [15:0] xphs_len_minus_1;
        bit [31:0] W_addr;
        bit [31:0] W_n_bytes;
        bit [15:0] B_addr;
        bit [31:0] X_addr, Y_addr;
        bit [15:0] OC;
        bit [15:0] INC2_minus_1;
        bit [15:0] INW_;
        bit [7:0] KH_minus_1, KW_minus_1;
        bit [3:0] strideH, strideW, padL, padU;
        bit [15:0] INH2, INW2;
        bit [15:0] ifm_height, ofm_height;
        bit [7:0] n_last_batch;
        bit [15:0] n_W_rnd;
        bit [15:0] row_bound, col_bound;
        bit [15:0] vec_size, vec_size_minus_1;
        bit [7:0] Xz, Wz, Yz;
        bit [31:0] m1;
        bit [7:0] n1;
        bit [7:0] obj1, obj2, obj3, obj4;
    endclass 

    class Data;
        bit[7:0] X[][];
        bit[7:0] Y[][];
        bit[7:0] xphs[][];
        bit[7:0] mat[][];
    endclass

    bit main_clk = 0;
    bit main_rst = 0;
    bit sa_clk = 0;

    verify_top_axi_vip_0_1_slv_mem_t ddr_agent;
    verify_top_axi_vip_0_0_mst_t sr_cr_agent;
    Ins instructions [];
    Data data = new ();
    event ins_start_event [1024];
    event ins_done_event [1024];

    initial begin
        main_clk <= 0;
        forever begin
            #2 main_clk = ~main_clk;
        end
    end

    initial begin
        #0.11 sa_clk <= 1;
        forever begin
            #1.25 sa_clk = ~sa_clk;
        end
    end 

    int curr_start_ins = 0, curr_done_ins = 0;
    initial begin
        forever begin
            @(posedge main_clk) begin
                if (dut.verify_top_i.top.inst.exec_inst.exec_fsm_inst.pool_start_pulse==1) begin
                    $display("--------------------------------");
                    $display("Start executing instruction of test case %0d at %0t", curr_start_ins, $time);
                    -> ins_start_event[curr_start_ins];
                    curr_start_ins ++;
                end
            end
        end
    end

    initial begin
        forever begin
            @(posedge main_clk) begin
                if (dut.verify_top_i.top.inst.exec_inst.exec_fsm_inst.pool_done_pulse==1) begin
                    $display("Finished executing of test case %0d at %0t", curr_done_ins, $time);
                    -> ins_done_event[curr_done_ins];
                    curr_done_ins ++;
                end
            end
        end
    end

    initial begin
        main_clk <= 0;
        main_rst <= 1;
        # 2000 begin
            main_rst <= 0;
            run();
            #1000;
            $display("Simulation finished, curr_time: %0t", $time);
            $finish;
        end
    end

    initial begin
        /* Parse configuration file */
        $display("Parse the configuration file.");
        parse_cfg();
        /* Write instructions into IM */
        $display("Write instructions into IM.");
        wr_ins();
        /* Write headers to XPHM */
        $display("Write xphs into XPHM.");
        wr_xphs();
        /* Write input tensors */
        $display("Write input tensors into RTM.");
        wr_X();
        /* Start checking MX */
        $display("Start checking MX.");
        check_MX();
        /* Start checking results */
        $display("Start checking Y.");
        check_Y();
    end

    initial begin
        ddr_agent = new("ddr agent",dut.verify_top_i.ddr.inst.IF);
        ddr_agent.vif_proxy.set_dummy_drive_type(XIL_AXI_VIF_DRIVE_NONE);
        ddr_agent.set_agent_tag("DDR VIP");
        ddr_agent.set_verbosity(0);
        ddr_agent.start_slave();

        sr_cr_agent = new("sr_cr agent",dut.verify_top_i.sr_cr.inst.IF);
        sr_cr_agent.vif_proxy.set_dummy_drive_type(XIL_AXI_VIF_DRIVE_NONE);
        sr_cr_agent.set_agent_tag("SR_CR VIP");
        sr_cr_agent.set_verbosity(0);
        sr_cr_agent.start_master();
    end

    // run test cases.
    task automatic run();
        /* Start inference */
        $display("Start the inference task, curr_time: %0t.", $time);
        sr_cr_write(10, 32'h00000000);
        sr_cr_write(10, 32'h00000001);
        /* Waiting for interruption */
        wait(dut.verify_top_i.top.inst.xdma_usr_irq_req[6]==1);
        $display("Inference finished, curr_time: %0t.", $time);
        /* Clear interruption */
        sr_cr_write(0, 32'h00400040);
        sr_cr_write(0, 32'h00000000);
    endtask

    // Parse the configuration file
    task automatic parse_cfg();
        int ins_fd;
        string dir_path = `DIR_PATH;
        int case_count = 0;
        Ins ins;

        case_count = get_case_count({dir_path, "/", "ins.txt"});

        /* Parse instructions */
        instructions = new [case_count];
        for (int i=0; i<case_count; i++)
            instructions[i] = new ();
        ins_fd = $fopen({dir_path, "/", "ins.txt"}, "r");
        for (int i=0; i<case_count; i++) begin
            ins = instructions[i];
            $fscanf(
                ins_fd, "%0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d %0d\n", 
                ins.xphs_addr, ins.xphs_len_minus_1, ins.W_addr, ins.W_n_bytes, ins.B_addr, ins.X_addr, ins.Y_addr, ins.OC, ins.INC2_minus_1, ins.INW_, ins.KH_minus_1, ins.KW_minus_1, ins.strideH, ins.strideW, ins.padL, ins.padU, ins.INH2, ins.INW2, ins.ifm_height, ins.ofm_height, ins.n_last_batch, ins.n_W_rnd, ins.row_bound, ins.col_bound, ins.vec_size, ins.vec_size_minus_1, ins.Xz, ins.Wz, ins.Yz, ins.m1, ins.n1, ins.obj1, ins.obj2, ins.obj3, ins.obj4
            );
        end
        $fclose(ins_fd);

        /* Load data from files */
        data.X = new [case_count];
        data.Y = new [case_count];
        data.xphs = new [case_count];
        data.mat = new [case_count];
        for (int i=0; i<case_count; i++) begin
            read_hex_file({dir_path, "/", $sformatf("X%0d.hex", i)}, data.X[i]);
            read_hex_file({dir_path, "/", $sformatf("Y%0d.hex", i)}, data.Y[i]);
            read_hex_file({dir_path, "/", $sformatf("xphs%0d.hex", i)}, data.xphs[i]);
            read_hex_file({dir_path, "/", $sformatf("mat%0d.hex", i)}, data.mat[i]);
        end
    endtask 

    // Write instructions to IM
    task automatic wr_ins();
        bit [`INS_RAM_DATA_WIDTH-1:0] im_data [];
        Ins ins;

        im_data = new [instructions.size()+1];
        for (int i=0; i<instructions.size(); i++) begin
            ins = instructions[i];
            im_data[i] = {ins.obj4, ins.obj3, ins.obj2, ins.obj1, ins.n1, ins.m1, ins.Yz, ins.Wz, ins.Xz, ins.vec_size_minus_1, ins.vec_size, ins.col_bound, ins.row_bound, ins.n_W_rnd, ins.n_last_batch, ins.ofm_height, ins.ifm_height, ins.INW2, ins.INH2, ins.padU, ins.padL, ins.strideW, ins.strideH, ins.KW_minus_1, ins.KH_minus_1, ins.INW_, ins.INC2_minus_1, ins.OC, ins.Y_addr, ins.X_addr, ins.B_addr, ins.W_n_bytes, ins.W_addr, ins.xphs_len_minus_1, ins.xphs_addr, `INS_MAXP};
        end
        im_data[instructions.size()] = `INS_NONE;

        im_wr(0, instructions.size()+1, im_data);
    endtask 

    // Write headers to XPHM
    task automatic wr_xphs();
        Ins ins;

        for (int i=0; i<instructions.size(); i++) begin
            ins = instructions[i];
            xphm_wr_byte(ins.xphs_addr, ins.xphs_len_minus_1+1, data.xphs[i]);
        end
    endtask

    // Write input tensors
    task automatic wr_X();
        Ins ins;

        for (int i=0; i<instructions.size(); i++) begin
            ins = instructions[i];
            rtm_wr_tensor(ins.X_addr, data.X[i], (ins.INC2_minus_1+1)*`S, ins.INH2-ins.padU, ins.INW_);
        end
    endtask

    // check MX
    task automatic check_MX();
        for (int i=0; i<instructions.size(); i++) begin
            automatic int ins_idx=i;
            fork
                check_MX_ins(ins_idx, ins_start_event[ins_idx], ins_done_event[ins_idx]);
            join_none
        end
    endtask

    task automatic check_MX_ins(input int ins_idx, input event start_ev, input event done_ev);
        bit [`P*2*8-1:0] expected, got;
        bit [31:0] arr_idx = 0;
        bit [31:0] check_idx = 0;
        bit [31:0] total_cnt = 0;
        int progress_rate = 0, next_progress_rate = 0;

        total_cnt = data.mat[ins_idx].size()/(`P*2);
        @start_ev;
        $display("check_MX, start, test case: %0d, curr_time: %0t", ins_idx, $time);

        forever begin
            @(posedge main_clk) begin
                if (dut.verify_top_i.top.inst.exec_inst.xbus_inst.mxm_wr_en) begin
                    /* Display the progress rate */
                    progress_rate = (check_idx+1)*100/total_cnt;
                    if (progress_rate == next_progress_rate) begin
                        $display("check_MX, in progress %0d%%(%0d/%0d), test case: %0d, curr_time: %0t", progress_rate, check_idx+1, total_cnt, ins_idx, $time);
                        next_progress_rate ++;
                    end
                    /* Compare expected and got */
                    got = dut.verify_top_i.top.inst.exec_inst.xbus_inst.mxm_din;
                    for (int i=0; i<`P*2; i++) begin
                        expected[i*8+:8] = data.mat[ins_idx][arr_idx];
                        arr_idx ++;
                    end
                    if (got != expected) begin
                        $display("check_MX, mismatch, test case: %0d, check_idx: %0d, curr_time: %0t", ins_idx, check_idx, $time);
                        $display("exp: %0h", expected);
                        $display("got: %0h", got);
                        break;
                    end
                    check_idx ++;
                    /* End */
                    if (check_idx == total_cnt) begin
                        $display("check_MX, all passed, test case: %0d, curr_time: %0t", ins_idx, $time);
                        break;
                    end
                end
            end
        end
    endtask

    // check Y
    task automatic check_Y();
        for (int i=0; i<instructions.size(); i++) begin
            automatic int ins_idx=i;
            fork
                check_Y_ins(ins_idx, ins_start_event[ins_idx], ins_done_event[ins_idx]);
            join_none
        end
    endtask

    task automatic check_Y_ins(input int ins_idx, input event start_ev, input event done_ev);
        Ins ins;
        bit [7:0] hw_Y [];
        int real_of_size = 0, padded_of_size = 0;
        int of_idx = 0, of_offset = 0;
        bit[31:0] match = 0, mismatch = 0;
        bit [7:0] expected = 0, got = 0;

        @start_ev;
        @done_ev;
        $display("check_Y, start, test case: %0d, curr_time: %0t", ins_idx, $time);
        
        ins = instructions[ins_idx];
        real_of_size = data.Y[ins_idx].size()/ins.OC;
        padded_of_size = ins.ofm_height*(`R);

        /* Read Y from RTM and check */
        rtm_rd_tensor(ins.Y_addr, hw_Y, ins.OC, ins.ofm_height);
        for (bit[31:0] i=0; i<data.Y[ins_idx].size(); i++) begin
            of_idx = i/real_of_size;
            of_offset = i - of_idx*real_of_size;
            expected = data.Y[ins_idx][i];
            got = hw_Y[of_idx*padded_of_size+of_offset];
            if (expected == got)
                match ++;
            else begin
                $display("check_Y, mismatch at byte: %0d, expected: %0d, got: %0d", i,expected, got);
                mismatch ++;
            end
        end
        if (mismatch == 0)
            $display("check_Y, done, all passed, test case: %0d, curr_time: %0t", ins_idx, $time);
        else
            $display("check_Y, done, failed, Total: %0d, match: %0d, mismatch: %0d, test case: %0d, curr_time: %0t", data.Y[ins_idx].size(), match, mismatch, ins_idx, $time);
        $display("--------------------------------");
    endtask
    
`include "comm_func.sv"
    verify_top_wrapper dut(
    	.main_clk (main_clk ),
        .main_rst (main_rst ),
        .sa_clk   (sa_clk   )
    );
endmodule
