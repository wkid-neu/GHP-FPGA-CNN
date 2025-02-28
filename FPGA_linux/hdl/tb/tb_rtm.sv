`timescale 1ns / 1ps
`include "../src/incl.vh"

import axi_vip_pkg::*;
import verify_top_axi_vip_0_0_pkg::*;
import verify_top_axi_vip_0_1_pkg::*;

module tb_rtm;
    bit main_clk = 0;
    bit main_rst = 0;
    bit sa_clk = 0;

    verify_top_axi_vip_0_1_slv_mem_t ddr_agent;
    verify_top_axi_vip_0_0_mst_t sr_cr_agent;

    initial begin
        main_clk <= 0;
        forever begin
            #2 main_clk = ~main_clk;
        end
    end

    initial begin
        main_clk <= 0;
        main_rst <= 1;
        # 2000 begin
            main_rst <= 0;
            
            $display("----------------------- DRAM to Chip -----------------------");
            $display("*** case 1 ***");
            hc_d2c(32'h80000000, 16'h8000, 128);
            $display("*** case 2 ***");
            hc_d2c(32'h80000000, 16'h8000, 256);
            $display("*** case 3 ***");
            hc_d2c(32'h80000000, 16'h8000, 1024*64);
            
            $display("----------------------- Chip to DRAM -----------------------");
            $display("*** case 1 ***");
            hc_c2d(32'h80000000, 16'h8000, 128);
            $display("*** case 2 ***");
            hc_c2d(32'h80000000, 16'h8000, 256);
            $display("*** case 3 ***");
            hc_c2d(32'h80000000, 16'h8000, 1024*64);

            $display("----------------------- Bidirection -----------------------");
            fork
                begin
                    hc_d2c(32'h80000000, 16'h8000, 128);
                    hc_d2c(32'h80000000, 16'h8000, 256);
                    hc_d2c(32'h80000000, 16'h8000, 1024*64);
                end

                begin
                    hc_c2d(32'h90000000, 16'h9000, 128);
                    hc_c2d(32'h90000000, 16'h9000, 256);
                    hc_c2d(32'h90000000, 16'h9000, 1024*64);
                end
            join

            #1000;
            $display("Finished at %0t", $time);
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

    // DRAM to Chip controlled by the host
    task automatic hc_d2c(input bit[31:0] d_addr, input bit[31:0] c_addr, input bit[31:0] n_bytes);
        bit[7:0] dram_data [];
        bit [`S*`R*8-1:0] rtm_data [];
        bit[31:0] match = 0, mismatch = 0;
        bit [7:0] expected = 0, got = 0;

        $display("info: d_addr: 0x%0x, c_addr: 0x%0x, n_bytes: %0d", d_addr, c_addr, n_bytes);
        /* Generate data */
        dram_data = new [n_bytes];
        for (bit[31:0] i=0; i<n_bytes; i++)
            dram_data[i] = $random;
        /* Write data into DRAM */
        dram_wr(d_addr, n_bytes, dram_data);
        /* Start transferring */
        sr_cr_write(49, d_addr);
        sr_cr_write(48, c_addr);
        sr_cr_write(47, n_bytes);
        sr_cr_write(50, 32'h00000000);
        sr_cr_write(50, 32'h00000001);
        /* Waiting for interruption */
        wait(dut.verify_top_i.top.inst.xdma_usr_irq_req[1]==1);
        $display("Transfer finished at %0t", $time);
        /* Clear interruption */
        sr_cr_write(0, 32'h00020002);
        sr_cr_write(0, 32'h00000000);
        /* Check data */
        rtm_rd(c_addr, n_bytes/(`S*`R), rtm_data);
        for (bit[31:0] i=0; i<rtm_data.size(); i++)
            for (int j=0; j<(`S*`R); j++) begin
                expected = dram_data[i*(`S*`R)+j];
                got = rtm_data[i][j*8+:8];
                if (expected == got)
                    match ++;
                else
                    mismatch ++;
            end
        if (mismatch == 0)
            $display("Data checker passed.");
        else
            $display("Data checker failed, Total: %0d, match: %0d, mismatch: %0d", n_bytes, match, mismatch);
    endtask 

    // Chip to DRAM controlled by the host
    task automatic hc_c2d(input bit[31:0] d_addr, input bit[31:0] c_addr, input bit[31:0] n_bytes);
        bit[7:0] dram_data [];
        bit [`S*`R*8-1:0] rtm_data [];
        bit[31:0] match = 0, mismatch = 0;
        bit [7:0] expected = 0, got = 0;

        $display("info: d_addr: 0x%0x, c_addr: 0x%0x, n_bytes: %0d", d_addr, c_addr, n_bytes);
        /* Generate data */
        rtm_data = new [n_bytes/(`S*`R)];
        for (bit[31:0] i=0; i<rtm_data.size(); i++)
            rtm_data[i] = $random;
        /* Write data into RTM */
        rtm_wr(c_addr, n_bytes/(`S*`R), rtm_data);
        /* Start transferring */
        sr_cr_write(45, d_addr);
        sr_cr_write(44, c_addr);
        sr_cr_write(43, n_bytes);
        sr_cr_write(46, 32'h00000000);
        sr_cr_write(46, 32'h00000001);
        /* Waiting for interruption */
        wait(dut.verify_top_i.top.inst.xdma_usr_irq_req[2]==1);
        $display("Transfer finished at %0t", $time);
        /* Clear interruption */
        sr_cr_write(0, 32'h00040004);
        sr_cr_write(0, 32'h00000000);
        /* Check data */
        dram_rd(d_addr, n_bytes, dram_data);
        for (bit[31:0] i=0; i<rtm_data.size(); i++)
            for (int j=0; j<(`S*`R); j++) begin
                expected = dram_data[i*(`S*`R)+j];
                got = rtm_data[i][j*8+:8];
                if (expected == got)
                    match ++;
                else
                    mismatch ++;
            end
        if (mismatch == 0)
            $display("Data checker passed.");
        else
            $display("Data checker failed, Total: %0d, match: %0d, mismatch: %0d", n_bytes, match, mismatch);
    endtask 

`include "comm_func.sv"
    verify_top_wrapper dut(
    	.main_clk (main_clk ),
        .main_rst (main_rst ),
        .sa_clk   (sa_clk   )
    );
endmodule
