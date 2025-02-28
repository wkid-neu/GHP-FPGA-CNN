//Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2022.1 (lin64) Build 3526262 Mon Apr 18 15:47:01 MDT 2022
//Date        : Sun Nov 10 21:06:18 2024
//Host        : lvxing-System-Product-Name running 64-bit Ubuntu 20.04.6 LTS
//Command     : generate_target verify_top_wrapper.bd
//Design      : verify_top_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

module verify_top_wrapper
   (main_clk,
    main_rst,
    sa_clk);
  input main_clk;
  input main_rst;
  input sa_clk;

  wire main_clk;
  wire main_rst;
  wire sa_clk;

  verify_top verify_top_i
       (.main_clk(main_clk),
        .main_rst(main_rst),
        .sa_clk(sa_clk));
endmodule
