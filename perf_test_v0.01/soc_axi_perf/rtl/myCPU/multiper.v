`timescale 1ns / 1ps
module mul(
  input mul_clk,
  input resetn,
  input mul_signed,       //1'b1 signed; 1'b0 unsigned
  input [31:0] y,
  input [31:0] x,
  output [63:0] result
);

reg  [63:0] s_to_plus_r;
reg  [63:0] c_to_plus_r;
reg  final_c;

wire [32:0] input_x;     //input to booth_coder
wire [34:0] input_y;     //input to booth_coder
wire [63:0] p[16:0];     //output from booth_coder part_product
wire [16:0] c;           //output from booth_coder plus 1 for ins, mind c[16] is always 0
wire [16:0] out[63:0];   //output from switch
wire [13:0] c_to_tree[64:0];  //carryin for tree, only 0-63 will be used, 0 come from plus 1 for ins
wire [63:0] c_to_plus;        //carryin to final plus, come from tree0 - tree63
wire [63:0] final_c_to_plus;  //final plus, come from tree0 - tree62 and c[14]
wire [63:0] s_to_plus;        //final plus, come from tree0 - tree63


assign input_x = {(mul_signed & x[31]),x};
assign input_y = {{2{(mul_signed & y[31])}},y,1'b0};

booth_coder inst_booth_coder_0(
    .x(input_x),
    .y(input_y[2:0]),
    .i(6'b0),
    .p(p[0]),
    .c(c[0])
);
booth_coder inst_booth_coder_1(
    .x(input_x),
    .y(input_y[4:2]),
    .i(6'd2),
    .p(p[1]),
    .c(c[1])
);
booth_coder inst_booth_coder_2(
    .x(input_x),
    .y(input_y[6:4]),
    .i(6'd4),
    .p(p[2]),
    .c(c[2])
);
booth_coder inst_booth_coder_3(
    .x(input_x),
    .y(input_y[8:6]),
    .i(6'd6),
    .p(p[3]),
    .c(c[3])
);
booth_coder inst_booth_coder_4(
    .x(input_x),
    .y(input_y[10:8]),
    .i(6'd8),
    .p(p[4]),
    .c(c[4])
);
booth_coder inst_booth_coder_5(
    .x(input_x),
    .y(input_y[12:10]),
    .i(6'd10),
    .p(p[5]),
    .c(c[5])
);
booth_coder inst_booth_coder_6(
    .x(input_x),
    .y(input_y[14:12]),
    .i(6'd12),
    .p(p[6]),
    .c(c[6])
);
booth_coder inst_booth_coder_7(
    .x(input_x),
    .y(input_y[16:14]),
    .i(6'd14),
    .p(p[7]),
    .c(c[7])
);
booth_coder inst_booth_coder_8(
    .x(input_x),
    .y(input_y[18:16]),
    .i(6'd16),
    .p(p[8]),
    .c(c[8])
);
booth_coder inst_booth_coder_9(
    .x(input_x),
    .y(input_y[20:18]),
    .i(6'd18),
    .p(p[9]),
    .c(c[9])
);
booth_coder inst_booth_coder_10(
    .x(input_x),
    .y(input_y[22:20]),
    .i(6'd20),
    .p(p[10]),
    .c(c[10])
);
booth_coder inst_booth_coder_11(
    .x(input_x),
    .y(input_y[24:22]),
    .i(6'd22),
    .p(p[11]),
    .c(c[11])
);
booth_coder inst_booth_coder_12(
    .x(input_x),
    .y(input_y[26:24]),
    .i(6'd24),
    .p(p[12]),
    .c(c[12])
);
booth_coder inst_booth_coder_13(
    .x(input_x),
    .y(input_y[28:26]),
    .i(6'd26),
    .p(p[13]),
    .c(c[13])
);
booth_coder inst_booth_coder_14(
    .x(input_x),
    .y(input_y[30:28]),
    .i(6'd28),
    .p(p[14]),
    .c(c[14])
);
booth_coder inst_booth_coder_15(
    .x(input_x),
    .y(input_y[32:30]),
    .i(6'd30),
    .p(p[15]),
    .c(c[15])
);
booth_coder inst_booth_coder_16(
    .x(input_x),
    .y(input_y[34:32]),
    .i(6'd32),
    .p(p[16]),
    .c(c[16])
);

switch inst_switch(
    .p0(p[0]),
    .p1(p[1]),    .p9(p[9]),
    .p2(p[2]),    .p10(p[10]),
    .p3(p[3]),    .p11(p[11]),
    .p4(p[4]),    .p12(p[12]),
    .p5(p[5]),    .p13(p[13]),
    .p6(p[6]),    .p14(p[14]),
    .p7(p[7]),    .p15(p[15]),
    .p8(p[8]),    .p16(p[16]),

    .out1(out[0]),    .out9(out[8]),
    .out2(out[1]),    .out10(out[9]),
    .out3(out[2]),    .out11(out[10]),
    .out4(out[3]),    .out12(out[11]),
    .out5(out[4]),    .out13(out[12]),
    .out6(out[5]),    .out14(out[13]),
    .out7(out[6]),    .out15(out[14]),
    .out8(out[7]),    .out16(out[15]),
    .out17(out[16]),  .out25(out[24]),
    .out18(out[17]),  .out26(out[25]),
    .out19(out[18]),  .out27(out[26]),
    .out20(out[19]),  .out28(out[27]),
    .out21(out[20]),  .out29(out[28]),
    .out22(out[21]),  .out30(out[29]),
    .out23(out[22]),  .out31(out[30]),
    .out24(out[23]),  .out32(out[31]),
    .out33(out[32]),  .out41(out[40]),
    .out34(out[33]),  .out42(out[41]),
    .out35(out[34]),  .out43(out[42]),
    .out36(out[35]),  .out44(out[43]),
    .out37(out[36]),  .out45(out[44]),
    .out38(out[37]),  .out46(out[45]),
    .out39(out[38]),  .out47(out[46]),
    .out40(out[39]),  .out48(out[47]),
    .out49(out[48]),  .out57(out[56]),
    .out50(out[49]),  .out58(out[57]),
    .out51(out[50]),  .out59(out[58]),
    .out52(out[51]),  .out60(out[59]),
    .out53(out[52]),  .out61(out[60]),
    .out54(out[53]),  .out62(out[61]),
    .out55(out[54]),  .out63(out[62]),
    .out56(out[55]),  .out64(out[63])
);

assign c_to_tree[0] = c[13:0];

genvar i;
generate for (i=0; i<64; i=i+1) begin : inst_tree
    tree inst_tree(
        .in(out[i]),
        .cin(c_to_tree[i]),
        .cout(c_to_tree[i+1]),
        .c_to_plus(c_to_plus[i]),
        .s_to_plus(s_to_plus[i])
    );
end endgenerate

assign final_c_to_plus = {c_to_plus[62:0],c[14]};

always@(posedge mul_clk)
begin
    if(!resetn)
        s_to_plus_r <= 64'b0;
    else
        s_to_plus_r <= s_to_plus;
end

always@(posedge mul_clk)
begin
    if(!resetn)
        c_to_plus_r <= 64'b0;
    else
        c_to_plus_r <= final_c_to_plus;
end

always@(posedge mul_clk)
begin
    if(!resetn)
        final_c <= 1'b0;
    else
        final_c <= c[15];
end

assign result = s_to_plus_r + c_to_plus_r + final_c;

endmodule