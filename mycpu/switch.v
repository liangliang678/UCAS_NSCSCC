module switch(
  input [63:0] p0,  input [63:0] p1,  input [63:0] p2,  input [63:0] p3,  
  input [63:0] p4,  input [63:0] p5,  input [63:0] p6,  input [63:0] p7,  
  input [63:0] p8,  input [63:0] p9,  input [63:0] p10, input [63:0] p11, 
  input [63:0] p12, input [63:0] p13, input [63:0] p14, input [63:0] p15, 
  input [63:0] p16,

  output [16:0] out1, output [16:0] out2, output [16:0] out3, output [16:0] out4, 
  output [16:0] out5, output [16:0] out6, output [16:0] out7, output [16:0] out8, 
  output [16:0] out9, output [16:0] out10, output [16:0] out11, output [16:0] out12, 
  output [16:0] out13, output [16:0] out14, output [16:0] out15, output [16:0] out16, 
  output [16:0] out17, output [16:0] out18, output [16:0] out19, output [16:0] out20, 
  output [16:0] out21, output [16:0] out22, output [16:0] out23, output [16:0] out24, 
  output [16:0] out25, output [16:0] out26, output [16:0] out27, output [16:0] out28, 
  output [16:0] out29, output [16:0] out30, output [16:0] out31, output [16:0] out32, 
  output [16:0] out33, output [16:0] out34, output [16:0] out35, output [16:0] out36, 
  output [16:0] out37, output [16:0] out38, output [16:0] out39, output [16:0] out40, 
  output [16:0] out41, output [16:0] out42, output [16:0] out43, output [16:0] out44, 
  output [16:0] out45, output [16:0] out46, output [16:0] out47, output [16:0] out48, 
  output [16:0] out49, output [16:0] out50, output [16:0] out51, output [16:0] out52, 
  output [16:0] out53, output [16:0] out54, output [16:0] out55, output [16:0] out56, 
  output [16:0] out57, output [16:0] out58, output [16:0] out59, output [16:0] out60,
  output [16:0] out61, output [16:0] out62, output [16:0] out63, output [16:0] out64

);

wire [16:0] part_res[63:0];

genvar i;
generate for (i=0; i<64; i=i+1) begin : switch  
    assign part_res[i] = {p16[i],p15[i],p14[i],p13[i],p12[i],p11[i],p10[i],p9[i],p8[i],p7[i],p6[i],p5[i],p4[i],p3[i],p2[i],p1[i],p0[i]} ;
end endgenerate

assign out1 = part_res[0];
assign out2 = part_res[1];
assign out3 = part_res[2];
assign out4 = part_res[3];
assign out5 = part_res[4];
assign out6 = part_res[5];
assign out7 = part_res[6];
assign out8 = part_res[7];
assign out9 = part_res[8];
assign out10 = part_res[9];
assign out11 = part_res[10];
assign out12 = part_res[11];
assign out13 = part_res[12];
assign out14 = part_res[13];
assign out15 = part_res[14];
assign out16 = part_res[15];
assign out17 = part_res[16];
assign out18 = part_res[17];
assign out19 = part_res[18];
assign out20 = part_res[19];
assign out21 = part_res[20];
assign out22 = part_res[21];
assign out23 = part_res[22];
assign out24 = part_res[23];
assign out25 = part_res[24];
assign out26 = part_res[25];
assign out27 = part_res[26];
assign out28 = part_res[27];
assign out29 = part_res[28];
assign out30 = part_res[29];
assign out31 = part_res[30];
assign out32 = part_res[31];
assign out33 = part_res[32];
assign out34 = part_res[33];
assign out35 = part_res[34];
assign out36 = part_res[35];
assign out37 = part_res[36];
assign out38 = part_res[37];
assign out39 = part_res[38];
assign out40 = part_res[39];
assign out41 = part_res[40];
assign out42 = part_res[41];
assign out43 = part_res[42];
assign out44 = part_res[43];
assign out45 = part_res[44];
assign out46 = part_res[45];
assign out47 = part_res[46];
assign out48 = part_res[47];
assign out49 = part_res[48];
assign out50 = part_res[49];
assign out51 = part_res[50];
assign out52 = part_res[51];
assign out53 = part_res[52];
assign out54 = part_res[53];
assign out55 = part_res[54];
assign out56 = part_res[55];
assign out57 = part_res[56];
assign out58 = part_res[57];
assign out59 = part_res[58];
assign out60 = part_res[59];
assign out61 = part_res[60];
assign out62 = part_res[61];
assign out63 = part_res[62];
assign out64 = part_res[63];

endmodule