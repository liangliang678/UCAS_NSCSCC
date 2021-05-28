module alu(
  input         clk,
  input         reset,
  input  [15:0] alu_op,
  input  [31:0] alu_src1,
  input  [31:0] alu_src2,
  output [31:0] alu_result,
  output [31:0] alu_result_mul_div,
  output [63:0] alu_mul_res,
  output        complete,
  output        overflow
);

wire op_add;   //�ӷ�����
wire op_sub;   //��������
wire op_slt;   //�з��űȽϣ�С����λ
wire op_sltu;  //�޷��űȽϣ�С����λ
wire op_and;   //��λ��
wire op_nor;   //��λ���
wire op_or;    //��λ��
wire op_xor;   //��λ���
wire op_sll;   //�߼�����
wire op_srl;   //�߼�����
wire op_sra;   //��������
wire op_lui;   //���������ڸ߰벿��
wire op_mult;
wire op_multu;
wire op_div;
wire op_divu;

// control code decomposition
assign op_add  = alu_op[ 0];
assign op_sub  = alu_op[ 1];
assign op_slt  = alu_op[ 2];
assign op_sltu = alu_op[ 3];
assign op_and  = alu_op[ 4];
assign op_nor  = alu_op[ 5];
assign op_or   = alu_op[ 6];
assign op_xor  = alu_op[ 7];
assign op_sll  = alu_op[ 8];
assign op_srl  = alu_op[ 9];
assign op_sra  = alu_op[10];
assign op_lui  = alu_op[11];
assign op_mult = alu_op[12];
assign op_multu= alu_op[13];
assign op_div  = alu_op[14];
assign op_divu = alu_op[15];

wire [31:0] add_sub_result; 
wire [31:0] slt_result; 
wire [31:0] sltu_result;
wire [31:0] and_result;
wire [31:0] nor_result;
wire [31:0] or_result;
wire [31:0] xor_result;
wire [31:0] lui_result;
wire [31:0] sll_result; 
wire [63:0] sr64_result; 
wire [31:0] sr_result; 
wire [63:0] mult_result;
wire [63:0] div_result;

wire div_complete;

// 32-bit adder
wire [31:0] adder_a;
wire [31:0] adder_b;
wire        adder_cin;
wire [31:0] adder_result;
wire        adder_cout;
wire        adder_cout_31;

assign adder_a   = alu_src1;
assign adder_b   = (op_sub | op_slt | op_sltu) ? ~alu_src2 : alu_src2;
assign adder_cin = (op_sub | op_slt | op_sltu) ? 1'b1      : 1'b0;
assign {adder_cout_31, adder_result[30:0]} = adder_a[30:0] + adder_b[30:0] + adder_cin;
assign {adder_cout, adder_result[31]} = adder_a[31] + adder_b[31] + adder_cout_31;
assign overflow = adder_cout ^ adder_cout_31;

// ADD, SUB result
assign add_sub_result = adder_result;

// SLT result
assign slt_result[31:1] = 31'b0;
assign slt_result[0]    = (alu_src1[31] & ~alu_src2[31])
                        | ((alu_src1[31] ~^ alu_src2[31]) & adder_result[31]);

// SLTU result
assign sltu_result[31:1] = 31'b0;
assign sltu_result[0]    = ~adder_cout;

// bitwise operation
assign and_result = alu_src1 & alu_src2;
assign or_result  = alu_src1 | alu_src2;
assign nor_result = ~or_result;
assign xor_result = alu_src1 ^ alu_src2;
assign lui_result = {alu_src2[15:0], 16'b0};

// SLL result 
assign sll_result = alu_src2 << alu_src1[4:0];

// SRL, SRA result
assign sr64_result = {{32{op_sra & alu_src2[31]}}, alu_src2[31:0]} >> alu_src1[4:0];

assign sr_result   = sr64_result[31:0];

//MULT, MULTU
mul u_mul(
    .mul_clk    (clk              ),
    .resetn     (~reset           ),
    .mul_signed (op_mult          ),
    .x          (alu_src1         ),
    .y          (alu_src2         ),
    .result     (mult_result      )
    );

// DIV, DIVU result
reg div;

always @(posedge clk) begin
  if (reset) begin
    div <= 0;
  end else if (complete) begin
    div <= 0;
  end else if (op_divu | op_div) begin
    div <= 1;
  end
end

div u_div(
    .div_clk    (clk              ),
    .resetn     (~reset           ),
    .div        (div              ),
    .div_signed (op_div           ),
    .x          (alu_src1         ),
    .y          (alu_src2         ),
    .s          (div_result[63:32]),
    .r          (div_result[31:0] ),
    .complete   (div_complete     )
    );

// final result mux
assign alu_result = ({32{op_add|op_sub }}   & add_sub_result)
                  | ({32{op_slt        }}   & slt_result)
                  | ({32{op_sltu       }}   & sltu_result)
                  | ({32{op_and        }}   & and_result)
                  | ({32{op_nor        }}   & nor_result)
                  | ({32{op_or         }}   & or_result)
                  | ({32{op_xor        }}   & xor_result)
                  | ({32{op_lui        }}   & lui_result)
                  | ({32{op_sll        }}   & sll_result)
                  | ({32{op_srl|op_sra }}   & sr_result)
                  | ({32{op_mult|op_multu}} & mult_result[31:0])
                  | ({32{op_div|op_divu}}   & div_result[31:0]);

assign alu_result_mul_div = ({32{op_mult|op_multu}} & mult_result[63:32]) |
                            ({32{op_div|op_divu}} & div_result[63:32]);
assign alu_mul_res = mult_result;

assign complete = ~(op_div | op_divu) | div_complete;

endmodule
