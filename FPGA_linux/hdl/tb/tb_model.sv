`timescale 1ns / 1ps
`include "../src/incl.vh"

/* Make sure that MODEL_DIR is defined */
`ifndef MODEL_DIR
    $error("The macro `MODEL_DIR must be defined, simulation will be stopped soon.");
    `define MODEL_DIR ""
    `define RES_FP ""
`endif

import axi_vip_pkg::*;
import verify_top_axi_vip_0_0_pkg::*;
import verify_top_axi_vip_0_1_pkg::*;

module tb_model;
    /* Check the macro `MODEL_DIR */
    initial begin
        if (`MODEL_DIR=="")
            $finish;
    end

    class Model;
        bit [31:0] sta_conv_weight_ddr_addr, sta_conv_weight_ddr_len;
        bit [31:0] dyn_conv_weight_ddr_addr, dyn_conv_weight_ddr_len;
        bit [31:0] fc_weight_ddr_addr, fc_weight_ddr_len;
        bit [31:0] bias_ddr_addr, bias_ddr_len;
        bit [31:0] ins_ddr_addr, ins_ddr_len;
        bit [31:0] xphs_ddr_addr, xphs_ddr_len;
        bit [31:0] input_ddr_addr, input_ddr_len, input_rtm_addr;
        bit [31:0] output_ddr_addr, output_ddr_len, output_rtm_addr;
    endclass

    class Data;
        bit[7:0] ins[];
        bit[7:0] sta_conv_weights[];
        bit[7:0] dyn_conv_weights[];
        bit[7:0] fc_weights[];
        bit[7:0] xphs[];
        bit[7:0] bias[];
    endclass

    bit main_clk = 0;
    bit main_rst = 0;
    bit sa_clk = 0;

    verify_top_axi_vip_0_1_slv_mem_t ddr_agent;
    verify_top_axi_vip_0_0_mst_t sr_cr_agent;
    Model model = new ();
    Data data = new ();

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

    initial begin
        /* Parse model configuration file. */
        $display("Parse model configuration file.");
        parse_model_info();
        /* Load data from files. */
        $display("Load data from files.");
        load_data_from_file();
        /* Write data into DRAM. */
        $display("Write data into DRAM.");
        wr_data_into_dram();
        /* Start monitoring the execution. */
        $display("Start running the monitors.");
        fork
            /* Display simulation time */
            display_sim_time();
            /* Display instruction execution */
            monitor_ins();
            /* Display write back informations */
            display_wb();
        join_none
    end

    // Run the model.
    task automatic run();
        pre_load();
        exec_model();
    endtask

    // Load data from DRAM to the chip
    task automatic pre_load();
        /* Load instructions onto the chip */
        $display("Start loading instrcutions, curr_time: %0t.", $time);
        sr_cr_write(59, model.ins_ddr_addr);
        sr_cr_write(58, model.ins_ddr_len);
        sr_cr_write(60, 32'h00000000);
        sr_cr_write(60, 32'h00000001);
        wait(dut.verify_top_i.top.inst.xdma_usr_irq_req[0]==1);
        $display("Finished loading instructions, curr_time: %0t.", $time);
        sr_cr_write(0, 32'h00010001);
        sr_cr_write(0, 32'h00000000);

        /* Load sta_conv_weights onto the chip */
        if (model.sta_conv_weight_ddr_len > 0) begin
            $display("Start loading sta_conv_weights, curr_time: %0t.", $time);
            sr_cr_write(29, model.sta_conv_weight_ddr_addr);
            sr_cr_write(28, 32'h00000000);
            sr_cr_write(27, model.sta_conv_weight_ddr_len);
            sr_cr_write(30, 32'h00000000);
            sr_cr_write(30, 32'h00000001);
            wait(dut.verify_top_i.top.inst.xdma_usr_irq_req[4]==1);
            $display("Finished loading sta_conv_weights, curr_time: %0t.", $time);
            sr_cr_write(0, 32'h00100010);
            sr_cr_write(0, 32'h00000000); 
        end

        /* Load xphs onto the chip */
        if (model.xphs_ddr_len > 0) begin
            $display("Start loading xphs, curr_time: %0t.", $time);
            sr_cr_write(39, model.xphs_ddr_addr);
            sr_cr_write(38, 32'h00000000);
            sr_cr_write(37, model.xphs_ddr_len);
            sr_cr_write(40, 32'h00000000);
            sr_cr_write(40, 32'h00000001);
            wait(dut.verify_top_i.top.inst.xdma_usr_irq_req[3]==1);
            $display("Finished loading xphs, curr_time: %0t.", $time);
            sr_cr_write(0, 32'h00080008);
            sr_cr_write(0, 32'h00000000); 
        end

        /* Load bias onto the chip */
        if (model.bias_ddr_len > 0) begin
            $display("Start loading bias, curr_time: %0t.", $time);
            sr_cr_write(19, model.bias_ddr_addr);
            sr_cr_write(18, 32'h00000000);
            sr_cr_write(17, model.bias_ddr_len);
            sr_cr_write(20, 32'h00000000);
            sr_cr_write(20, 32'h00000001);
            wait(dut.verify_top_i.top.inst.xdma_usr_irq_req[5]==1);
            $display("Finished loading bias, curr_time: %0t.", $time);
            sr_cr_write(0, 32'h00200020);
            sr_cr_write(0, 32'h00000000); 
        end
    endtask 

    // Execute the model
    task automatic exec_model();
        /* Load inputs onto the chip */
        $display("Start loading inputs, curr_time: %0t.", $time);
        sr_cr_write(49, model.input_ddr_addr);
        sr_cr_write(48, model.input_rtm_addr);
        sr_cr_write(47, model.input_ddr_len);
        sr_cr_write(50, 32'h00000000);
        sr_cr_write(50, 32'h00000001);
        wait(dut.verify_top_i.top.inst.xdma_usr_irq_req[1]==1);
        $display("Finished loading inputs, curr_time: %0t.", $time);
        sr_cr_write(0, 32'h00020002);
        sr_cr_write(0, 32'h00000000);

        /* Start inference */
        sr_cr_write(10, 32'h00000000);
        sr_cr_write(10, 32'h00000001);
        wait(dut.verify_top_i.top.inst.xdma_usr_irq_req[6]==1);
        $display("Inference finished, curr_time: %0t.", $time);
        sr_cr_write(0, 32'h00400040);
        sr_cr_write(0, 32'h00000000);

        /* Read outputs from the chip */
        $display("Start reading outputs, curr_time: %0t.", $time);
        sr_cr_write(45, model.output_ddr_addr);
        sr_cr_write(44, model.output_rtm_addr);
        sr_cr_write(43, model.output_ddr_len);
        sr_cr_write(46, 32'h00000000);
        sr_cr_write(46, 32'h00000001);
        wait(dut.verify_top_i.top.inst.xdma_usr_irq_req[2]==1);
        $display("Finished reading outputs, curr_time: %0t.", $time);
        sr_cr_write(0, 32'h00040004);
        sr_cr_write(0, 32'h00000000);
    endtask

    // Parse model information
    task automatic parse_model_info();
        int fd;
        fd = $fopen({`MODEL_DIR, "/", "model.yaml"}, "r");
        $fscanf(fd, "sta_conv_weight_ddr_addr: %d\n", model.sta_conv_weight_ddr_addr);
        $fscanf(fd, "sta_conv_weight_ddr_len: %d\n", model.sta_conv_weight_ddr_len);
        $fscanf(fd, "dyn_conv_weight_ddr_addr: %d\n", model.dyn_conv_weight_ddr_addr);
        $fscanf(fd, "dyn_conv_weight_ddr_len: %d\n", model.dyn_conv_weight_ddr_len);
        $fscanf(fd, "fc_weight_ddr_addr: %d\n", model.fc_weight_ddr_addr);
        $fscanf(fd, "fc_weight_ddr_len: %d\n", model.fc_weight_ddr_len);
        $fscanf(fd, "bias_ddr_addr: %d\n", model.bias_ddr_addr);
        $fscanf(fd, "bias_ddr_len: %d\n", model.bias_ddr_len);
        $fscanf(fd, "ins_ddr_addr: %d\n", model.ins_ddr_addr);
        $fscanf(fd, "ins_ddr_len: %d\n", model.ins_ddr_len);
        $fscanf(fd, "xphs_ddr_addr: %d\n", model.xphs_ddr_addr);
        $fscanf(fd, "xphs_ddr_len: %d\n", model.xphs_ddr_len);
        $fscanf(fd, "input_ddr_addr: %d\n", model.input_ddr_addr);
        $fscanf(fd, "input_ddr_len: %d\n", model.input_ddr_len);
        $fscanf(fd, "input_rtm_addr: %d\n", model.input_rtm_addr);
        $fscanf(fd, "output_ddr_addr: %d\n", model.output_ddr_addr);
        $fscanf(fd, "output_ddr_len: %d\n", model.output_ddr_len);
        $fscanf(fd, "output_rtm_addr: %d\n", model.output_rtm_addr);
        $fclose(fd);
    endtask

    // Read data from files
    task automatic load_data_from_file();
        /* Load instructions */
        $display("Load instructions from file.");
        read_hex_file({`MODEL_DIR, "/", "ins.hex"}, data.ins);
        /* Load sta_conv_weights */
        $display("Load sta_conv_weights from file.");
        if (model.sta_conv_weight_ddr_len > 0)
            read_hex_file({`MODEL_DIR, "/", "sta_conv_weights.hex"}, data.sta_conv_weights);
        /* Load dyn_conv_weights */
        $display("Load dyn_conv_weights from file.");
        if (model.dyn_conv_weight_ddr_len > 0)
            read_hex_file({`MODEL_DIR, "/", "dyn_conv_weights.hex"}, data.dyn_conv_weights);
        /* Load fc_weights */
        $display("Load fc_weights from file.");
        if (model.fc_weight_ddr_len > 0)
            read_hex_file({`MODEL_DIR, "/", "fc_weights.hex"}, data.fc_weights);
        /* Load xphs */
        $display("Load xphs from file.");
        if (model.xphs_ddr_len > 0)
            read_hex_file({`MODEL_DIR, "/", "xphs.hex"}, data.xphs);
        /* Load bias */
        $display("Load bias from file.");
        if (model.bias_ddr_len > 0)
            read_hex_file({`MODEL_DIR, "/", "bias.hex"}, data.bias);
    endtask

    // Write data into DRAM
    task automatic wr_data_into_dram();
        bit [7:0] fake_inputs [];

        /* Write Fake inputs */
        fake_inputs = new [model.input_ddr_len];
        for (bit [31:0] i=0; i<model.input_ddr_len; i++)
            fake_inputs[i] = $random;
        $display("Write fake inputs into DRAM.");
        dram_wr(model.input_ddr_addr, model.input_ddr_len, fake_inputs);
        /* Write instructions */
        $display("Write instructions into DRAM.");
        dram_wr(model.ins_ddr_addr, model.ins_ddr_len, data.ins);
        /* Write sta_conv_weights */
        $display("Write sta_conv_weights into DRAM.");
        if (model.sta_conv_weight_ddr_len > 0)
            dram_wr(model.sta_conv_weight_ddr_addr, model.sta_conv_weight_ddr_len, data.sta_conv_weights);
        /* Write dyn_conv_weights */
        $display("Write dyn_conv_weights into DRAM.");
        if (model.dyn_conv_weight_ddr_len > 0)
            dram_wr(model.dyn_conv_weight_ddr_addr, model.dyn_conv_weight_ddr_len, data.dyn_conv_weights);
        /* Write fc_weights */
        $display("Write fc_weights into DRAM.");
        if (model.fc_weight_ddr_len > 0)
            dram_wr(model.fc_weight_ddr_addr, model.fc_weight_ddr_len, data.fc_weights);
        /* Write xphs */
        $display("Write xphs into DRAM.");
        if (model.xphs_ddr_len > 0)
            dram_wr(model.xphs_ddr_addr, model.xphs_ddr_len, data.xphs);
        /* Write bias */
        $display("Write bias into DRAM.");
        if (model.bias_ddr_len > 0)
            dram_wr(model.bias_ddr_addr, model.bias_ddr_len, data.bias);
    endtask

    // Monitor of the Exector
    task automatic monitor_ins();
        int ins_idx = 0;
        int fd;

        fd = $fopen(`RES_FP, "w");
        $fwrite(fd, "start,end\n");
        $fclose(fd);

        forever begin
            @(posedge main_clk) begin
                /* Conv */
                if (dut.verify_top_i.top.inst.exec_inst.exec_fsm_inst.conv_start_pulse==1) begin
                    $display("--------------------------------");
                    $display("Start executing ins %0d, curr_time: %0t, type: Conv", ins_idx, $time);
                    fd = $fopen(`RES_FP, "a");
                    $fwrite(fd, "%0t,", $time);
                    $fclose(fd);
                end
                if (dut.verify_top_i.top.inst.exec_inst.exec_fsm_inst.conv_done_pulse==1) begin
                    $display("Execute ins %0d successfully, curr_time: %0t, type: Conv", ins_idx, $time);
                    $display("--------------------------------");
                    fd = $fopen(`RES_FP, "a");
                    $fwrite(fd, "%0t\n", $time);
                    $fclose(fd);
                    ins_idx ++;
                end
                /* Pool */
                if (dut.verify_top_i.top.inst.exec_inst.exec_fsm_inst.pool_start_pulse==1) begin
                    $display("--------------------------------");
                    $display("Start executing ins %0d, curr_time: %0t, type: Pool", ins_idx, $time);
                    fd = $fopen(`RES_FP, "a");
                    $fwrite(fd, "%0t,", $time);
                    $fclose(fd);
                end
                if (dut.verify_top_i.top.inst.exec_inst.exec_fsm_inst.pool_done_pulse==1) begin
                    $display("Execute ins %0d successfully, curr_time: %0t, type: Pool", ins_idx, $time);
                    $display("--------------------------------");
                    fd = $fopen(`RES_FP, "a");
                    $fwrite(fd, "%0t\n", $time);
                    $fclose(fd);
                    ins_idx ++;
                end
                /* Add */
                if (dut.verify_top_i.top.inst.exec_inst.exec_fsm_inst.add_start_pulse==1) begin
                    $display("--------------------------------");
                    $display("Start executing ins %0d, curr_time: %0t, type: Add", ins_idx, $time);
                    fd = $fopen(`RES_FP, "a");
                    $fwrite(fd, "%0t,", $time);
                    $fclose(fd);
                end
                if (dut.verify_top_i.top.inst.exec_inst.exec_fsm_inst.add_done_pulse==1) begin
                    $display("Execute ins %0d successfully, curr_time: %0t, type: Add", ins_idx, $time);
                    $display("--------------------------------");
                    fd = $fopen(`RES_FP, "a");
                    $fwrite(fd, "%0t\n", $time);
                    $fclose(fd);
                    ins_idx ++;
                end
                /* Remap */
                if (dut.verify_top_i.top.inst.exec_inst.exec_fsm_inst.remap_start_pulse==1) begin
                    $display("--------------------------------");
                    $display("Start executing ins %0d, curr_time: %0t, type: Remap", ins_idx, $time);
                    fd = $fopen(`RES_FP, "a");
                    $fwrite(fd, "%0t,", $time);
                    $fclose(fd);
                end
                if (dut.verify_top_i.top.inst.exec_inst.exec_fsm_inst.remap_done_pulse==1) begin
                    $display("Execute ins %0d successfully, curr_time: %0t, type: Remap", ins_idx, $time);
                    $display("--------------------------------");
                    fd = $fopen(`RES_FP, "a");
                    $fwrite(fd, "%0t\n", $time);
                    $fclose(fd);
                    ins_idx ++;
                end
                /* Fc */
                if (dut.verify_top_i.top.inst.exec_inst.exec_fsm_inst.fc_start_pulse==1) begin
                    $display("--------------------------------");
                    $display("Start executing ins %0d, curr_time: %0t, type: Fc", ins_idx, $time);
                    fd = $fopen(`RES_FP, "a");
                    $fwrite(fd, "%0t,", $time);
                    $fclose(fd);
                end
                if (dut.verify_top_i.top.inst.exec_inst.exec_fsm_inst.fc_done_pulse==1) begin
                    $display("Execute ins %0d successfully, curr_time: %0t, type: Fc", ins_idx, $time);
                    $display("--------------------------------");
                    fd = $fopen(`RES_FP, "a");
                    $fwrite(fd, "%0t\n", $time);
                    $fclose(fd);
                    ins_idx ++;
                end
            end
        end
    endtask

    /* Display simulation time */
    task automatic display_sim_time();
        bit [31:0] curr_time = 0;
        bit [31:0] cnt = 0;

        forever begin
            @(posedge main_clk) begin
                cnt ++;
                if (cnt == 400) begin
                    cnt = 0;
                    $display("----- curr_time: %0t -----", $time);
                end
            end
        end
    endtask

    /* Display the write back information of current running instruction */
    task automatic display_wb();
        bit [31:0] conv_wr_cnt = 0;
        bit [31:0] pool_wr_cnt = 0;
        bit [31:0] add_wr_cnt = 0;
        bit [31:0] remap_wr_cnt = 0;
        bit [31:0] fc_wr_cnt = 0;

        forever begin
            @(posedge main_clk) begin
                /* Clear the counter */
                if (dut.verify_top_i.top.inst.exec_inst.Conv_inst.start_pulse) 
                    conv_wr_cnt = 0;
                if (dut.verify_top_i.top.inst.exec_inst.Pool_inst.start_pulse) 
                    pool_wr_cnt = 0;
                if (dut.verify_top_i.top.inst.exec_inst.Add_inst.start_pulse) 
                    add_wr_cnt = 0;
                if (dut.verify_top_i.top.inst.exec_inst.Remap_inst.start_pulse) 
                    remap_wr_cnt = 0;
                if (dut.verify_top_i.top.inst.exec_inst.Fc_inst.start_pulse) 
                    fc_wr_cnt = 0;

                /* Count */
                if (dut.verify_top_i.top.inst.exec_inst.Conv_inst.rtm_wr_en) begin
                    $display("Conv_wb, wr_cnt: %0d, curr_time: %0t", conv_wr_cnt, $time);
                    conv_wr_cnt ++;
                end
                if (dut.verify_top_i.top.inst.exec_inst.Pool_inst.rtm_wr_en) begin
                    $display("Pool_wb, wr_cnt: %0d, curr_time: %0t", pool_wr_cnt, $time);
                    pool_wr_cnt ++;
                end
                if (dut.verify_top_i.top.inst.exec_inst.Add_inst.rtm_wr_en) begin
                    $display("Add_wb, wr_cnt: %0d, curr_time: %0t", add_wr_cnt, $time);
                    add_wr_cnt ++;
                end
                if (dut.verify_top_i.top.inst.exec_inst.Remap_inst.rtm_wr_en) begin
                    $display("Remap_wb, wr_cnt: %0d, curr_time: %0t", remap_wr_cnt, $time);
                    remap_wr_cnt ++;
                end
                if (dut.verify_top_i.top.inst.exec_inst.Fc_inst.rtm_wr_en) begin
                    $display("Fc_wb, wr_cnt: %0d, curr_time: %0t", fc_wr_cnt, $time);
                    fc_wr_cnt ++;
                end
            end
        end
    endtask

`include "comm_func.sv"
    verify_top_wrapper dut(
    	.main_clk (main_clk ),
        .main_rst (main_rst ),
        .sa_clk   (sa_clk   )
    );
endmodule
