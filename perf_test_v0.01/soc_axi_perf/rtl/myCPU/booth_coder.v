module booth_coder(
  input [2:0] y,
  input [32:0] x,
  input [5:0] i,  //0,2,4...,32
  output [63:0] p,
  output c
);
wire [33:0] part_p;
wire [63:0] part_p_2;
wire snx;     //-x
wire spx;     //+x
wire sndx;    //-2x
wire spdx;    //+2x
assign snx = (y[2] & y[1] & ~y[0])  | (y[2] & ~y[1] & y[0]);
assign spx = (~y[2] & y[1] & ~y[0]) | (~y[2] & ~y[1] & y[0]);
assign sndx = (y[2] & ~y[1] & ~y[0]);
assign spdx = (~y[2] & y[1] & y[0]);

assign part_p = ({34{spx}}  &  {x[32],x}) |
                ({34{snx}}  &  {x[32],x}) |
                ({34{spdx}} &  {x,1'b0})  |
                ({34{sndx}} &  {x,1'b0});
assign c = snx | sndx;

assign part_p_2 = {{30{part_p[33]}},part_p} << i;
assign p = c ? ~part_p_2 : part_p_2;

endmodule

/*
assign part_p[0]  = ((~x[0]) & snx)  | ((x[0]) & spx)  | (1'b1 & sndx)     | (1'b0 & spdx);
assign part_p[1]  = ((~x[1]) & snx)  | ((x[1]) & spx)  | ((~x[0]) & sndx)  | ((x[0]) & spdx);
assign part_p[2]  = ((~x[2]) & snx)  | ((x[2]) & spx)  | ((~x[1]) & sndx)  | ((x[1]) & spdx);
assign part_p[3]  = ((~x[3]) & snx)  | ((x[3]) & spx)  | ((~x[2]) & sndx)  | ((x[2]) & spdx);
assign part_p[4]  = ((~x[4]) & snx)  | ((x[4]) & spx)  | ((~x[3]) & sndx)  | ((x[3]) & spdx);
assign part_p[5]  = ((~x[5]) & snx)  | ((x[5]) & spx)  | ((~x[4]) & sndx)  | ((x[4]) & spdx);
assign part_p[6]  = ((~x[6]) & snx)  | ((x[6]) & spx)  | ((~x[5]) & sndx)  | ((x[5]) & spdx);
assign part_p[7]  = ((~x[7]) & snx)  | ((x[7]) & spx)  | ((~x[6]) & sndx)  | ((x[6]) & spdx);
assign part_p[8]  = ((~x[8]) & snx)  | ((x[8]) & spx)  | ((~x[7]) & sndx)  | ((x[7]) & spdx);
assign part_p[9]  = ((~x[9]) & snx)  | ((x[9]) & spx)  | ((~x[8]) & sndx)  | ((x[8]) & spdx);
assign part_p[10] = ((~x[10]) & snx) | ((x[10]) & spx) | ((~x[9]) & sndx)  | ((x[9]) & spdx);
assign part_p[11] = ((~x[11]) & snx) | ((x[11]) & spx) | ((~x[10]) & sndx) | ((x[10]) & spdx);
assign part_p[12] = ((~x[12]) & snx) | ((x[12]) & spx) | ((~x[11]) & sndx) | ((x[11]) & spdx);
assign part_p[13] = ((~x[13]) & snx) | ((x[13]) & spx) | ((~x[12]) & sndx) | ((x[12]) & spdx);
assign part_p[14] = ((~x[14]) & snx) | ((x[14]) & spx) | ((~x[13]) & sndx) | ((x[13]) & spdx);
assign part_p[15] = ((~x[15]) & snx) | ((x[15]) & spx) | ((~x[14]) & sndx) | ((x[14]) & spdx);
assign part_p[16] = ((~x[16]) & snx) | ((x[16]) & spx) | ((~x[15]) & sndx) | ((x[15]) & spdx);
assign part_p[17] = ((~x[17]) & snx) | ((x[17]) & spx) | ((~x[16]) & sndx) | ((x[16]) & spdx);
assign part_p[18] = ((~x[18]) & snx) | ((x[18]) & spx) | ((~x[17]) & sndx) | ((x[17]) & spdx);
assign part_p[19] = ((~x[19]) & snx) | ((x[19]) & spx) | ((~x[18]) & sndx) | ((x[18]) & spdx);
assign part_p[20] = ((~x[20]) & snx) | ((x[20]) & spx) | ((~x[19]) & sndx) | ((x[19]) & spdx);
assign part_p[21] = ((~x[21]) & snx) | ((x[21]) & spx) | ((~x[20]) & sndx) | ((x[20]) & spdx);
assign part_p[22] = ((~x[22]) & snx) | ((x[22]) & spx) | ((~x[21]) & sndx) | ((x[21]) & spdx);
assign part_p[23] = ((~x[23]) & snx) | ((x[23]) & spx) | ((~x[22]) & sndx) | ((x[22]) & spdx);
assign part_p[24] = ((~x[24]) & snx) | ((x[24]) & spx) | ((~x[23]) & sndx) | ((x[23]) & spdx);
assign part_p[25] = ((~x[25]) & snx) | ((x[25]) & spx) | ((~x[24]) & sndx) | ((x[24]) & spdx);
assign part_p[26] = ((~x[26]) & snx) | ((x[26]) & spx) | ((~x[25]) & sndx) | ((x[25]) & spdx);
assign part_p[27] = ((~x[27]) & snx) | ((x[27]) & spx) | ((~x[26]) & sndx) | ((x[26]) & spdx);
assign part_p[28] = ((~x[28]) & snx) | ((x[28]) & spx) | ((~x[27]) & sndx) | ((x[27]) & spdx);
assign part_p[29] = ((~x[29]) & snx) | ((x[29]) & spx) | ((~x[28]) & sndx) | ((x[28]) & spdx);
assign part_p[30] = ((~x[30]) & snx) | ((x[30]) & spx) | ((~x[29]) & sndx) | ((x[29]) & spdx);
assign part_p[31] = ((~x[31]) & snx) | ((x[31]) & spx) | ((~x[30]) & sndx) | ((x[30]) & spdx);

assign part_p[32] = ((~x[32]) & snx) | ((x[32]) & spx) | ((~x[31]) & sndx) | ((x[31]) & spdx);
*/
