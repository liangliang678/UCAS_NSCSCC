// Copyright 1986-2019 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2019.2 (win64) Build 2708876 Wed Nov  6 21:40:23 MST 2019
// Date        : Sat Jun 19 15:30:56 2021
// Host        : DESKTOP running 64-bit major release  (build 9200)
// Command     : write_verilog -force -mode synth_stub
//               e:/NSCSCC/func_test_v0.01/soc_axi_func/rtl/xilinx_ip/Tag_RAM/Tag_RAM_stub.v
// Design      : Tag_RAM
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7a200tfbg676-2
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* x_core_info = "blk_mem_gen_v8_4_4,Vivado 2019.2" *)
module Tag_RAM(clka, ena, wea, addra, dina, douta)
/* synthesis syn_black_box black_box_pad_pin="clka,ena,wea[0:0],addra[7:0],dina[19:0],douta[19:0]" */;
  input clka;
  input ena;
  input [0:0]wea;
  input [7:0]addra;
  input [19:0]dina;
  output [19:0]douta;
endmodule
