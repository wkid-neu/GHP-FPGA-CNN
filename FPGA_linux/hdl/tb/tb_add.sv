`timescale 1ns / 1ps
`include "../src/incl.vh"

`ifndef DIR_PATH
// This is the default directory.
`define DIR_PATH "/home/hp50/Desktop/FPGA_linux/cnn_accel6/hdl/tb/sim_add"
`endif

import axi_vip_pkg::*;
import verify_top_axi_vip_0_0_pkg::*;
import verify_top_axi_vip_0_1_pkg::*;

module tb_add;
    class Ins;
        bit [31:0] A_addr, B_addr, C_addr;
        bit [31:0] len_minus_1;
        bit [31:0] m1, m2;
        bit [7:0] n;
        bit [7:0] Az, Bz, Cz;
    endclass

    class Data;
        bit [7:0] A [][];
        bit [7:0] B [][];
        bit [7:0] C [][];
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
                if (dut.verify_top_i.top.inst.exec_inst.exec_fsm_inst.add_start_pulse==1) begin
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
                if (dut.verify_top_i.top.inst.exec_inst.exec_fsm_inst.add_done_pulse==1) begin
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
        /* Write Vectors into RTM */
        $display("Write Vectors into RTM.");
        wr_vec();
        /* Start checking */
        $display("Start checking.");
        check_C();
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
                ins_fd, "%0d %0d %0d %0d %0d %0d %0d %0d %0d %0d\n", 
                ins.A_addr, ins.B_addr, ins.C_addr, ins.len_minus_1, ins.m1, ins.m2, ins.n, ins.Az, ins.Bz, ins.Cz
            );
        end
        $fclose(ins_fd);

        /* Load data from files */
        data.A = new [case_count];
        data.B = new [case_count];
        data.C = new [case_count];
        for (int i=0; i<case_count; i++) begin
            read_hex_file({dir_path, "/", $sformatf("A%0d.hex", i)}, data.A[i]);
            read_hex_file({dir_path, "/", $sformatf("B%0d.hex", i)}, data.B[i]);
            read_hex_file({dir_path, "/", $sformatf("C%0d.hex", i)}, data.C[i]);
        end
    endtask 

    // Write instructions to IM
    task automatic wr_ins();
        bit [`INS_RAM_DATA_WIDTH-1:0] im_data [];
        Ins ins;

        im_data = new [instructions.size()+1];
        for (int i=0; i<instructions.size(); i++) begin
            ins = instructions[i];
            im_data[i] = {ins.Cz, ins.Bz, ins.Az, ins.n, ins.m2, ins.m1, ins.len_minus_1, ins.C_addr, ins.B_addr, ins.A_addr, `INS_ADD};
        end
        im_data[instructions.size()] = `INS_NONE;

        im_wr(0, instructions.size()+1, im_data);
    endtask 

    // Write vectors into RTM
    task automatic wr_vec();
        Ins ins;

        for (int i=0; i<instructions.size(); i++) begin
            ins = instructions[i];
            rtm_wr_byte(ins.A_addr, ins.len_minus_1+1, data.A[i]);
            rtm_wr_byte(ins.B_addr, ins.len_minus_1+1, data.B[i]);
        end
    endtask 

    // check results
    task automatic check_C();
        for (int i=0; i<instructions.size(); i++) begin
            automatic int ins_idx=i;
            fork
                check_C_ins(ins_idx, ins_start_event[ins_idx], ins_done_event[ins_idx]);
            join_none
        end
    endtask

    // check result for the given instruction
    task automatic check_C_ins(input int ins_idx, input event start_ev, input event done_ev);
        Ins ins;
        bit [7:0] hw_C [];
        bit[31:0] match = 0, mismatch = 0;
        bit [7:0] expected = 0, got = 0;

        @start_ev;
        @done_ev;
        $display("Check_C:: Start, test case %0d, curr_time %0t", ins_idx, $time);
        ins = instructions[ins_idx];

        /* Read C from RTM and check */
        rtm_rd_byte(ins.C_addr, ins.len_minus_1+1, hw_C);
        for (bit[31:0] i=0; i<hw_C.size(); i++)
            if (data.C[ins_idx][i] == hw_C[i]) match ++;
            else begin
                // $display("Byte: %0d, Expected: %0d, got: %0d", i, data.C[ins_idx][i], hw_C[i]);
                mismatch ++;
            end 
        if (mismatch == 0)
            $display("Check_C:: Done, all passed, test case: %0d, curr_time: %0t", ins_idx, $time);
        else
            $display("Check_C:: Done, failed, Total: %0d, match: %0d, mismatch: %0d, test case: %0d, curr_time: %0t", hw_C.size(), match, mismatch, ins_idx, $time);
        $display("--------------------------------");
    endtask 

`include "comm_func.sv"
    verify_top_wrapper dut(
    	.main_clk (main_clk ),
        .main_rst (main_rst ),
        .sa_clk   (sa_clk   )
    );
endmodule
