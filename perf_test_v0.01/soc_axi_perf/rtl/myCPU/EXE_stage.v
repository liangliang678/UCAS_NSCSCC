`include "mycpu.h"

module exe_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          pms_allowin    ,
    output                         es_allowin    ,
    //from ds
    input                          ds_to_es_valid,
    input  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    //to pms
    output                         es_to_pms_valid,
    output [`ES_TO_PMS_BUS_WD -1:0] es_to_pms_bus  ,
    // output [63:0]                  es_inst1_mul_res,
    // output [63:0]                  es_inst2_mul_res,
    output [63:0]                  es_mul_res,

    //relevant bus
    output [`ES_FORWARD_BUS_WD -1:0] es_forward_bus,
  
    //clear stage
    input         clear_all
);

reg         es_valid;
wire        es_ready_go;

reg  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus_r;

wire [15:0] inst1_imm;
wire        inst1_refill;
wire [31:0] inst1_pc;
wire        inst1_ds_except;
wire [ 4:0] inst1_ds_exccode;
wire        inst1_es_tlbp;
wire        inst1_es_tlbr;
wire        inst1_es_tlbwi;
wire        inst1_es_eret;
wire        inst1_bd;
wire        inst1_detect_overflow;
wire        inst1_cp0_op;
wire        inst1_cp0_we;
wire [ 7:0] inst1_cp0_addr;
wire [ 6:0] inst1_load_store_type;
wire        inst1_load_op;
wire        inst1_store_op;
wire        inst1_hi_op;
wire        inst1_lo_op;
wire        inst1_hi_we;
wire        inst1_lo_we;
wire        inst1_hl_src_from_mul;
wire        inst1_hl_src_from_div;
wire [15:0] inst1_alu_op;
wire        inst1_src1_is_sa;
wire        inst1_src1_is_pc;
wire        inst1_src2_is_imm;
wire        inst1_src2_is_imm16;
wire        inst1_src2_is_8;
wire        inst1_gr_we;
wire        inst1_mem_we;
wire [ 4:0] inst1_dest;
wire [31:0] inst1_rs_value;
wire [31:0] inst1_rt_value;

wire [15:0] inst2_imm;
wire        inst2_refill;
wire        inst2_valid;
wire [31:0] inst2_pc;
wire        inst2_ds_except;
wire [ 4:0] inst2_ds_exccode;
wire        inst2_es_tlbp;
wire        inst2_es_tlbr;
wire        inst2_es_tlbwi;
wire        inst2_es_eret;
wire        inst2_bd;
wire        inst2_detect_overflow;
wire        inst2_cp0_op;
wire        inst2_cp0_we;
wire [ 7:0] inst2_cp0_addr;
wire [ 6:0] inst2_load_store_type;
wire        inst2_load_op;
wire        inst2_store_op;
wire        inst2_hi_op;
wire        inst2_lo_op;
wire        inst2_hi_we;
wire        inst2_lo_we;
wire        inst2_hl_src_from_mul;
wire        inst2_hl_src_from_div;
wire [15:0] inst2_alu_op;
wire        inst2_src1_is_sa;
wire        inst2_src1_is_pc;
wire        inst2_src2_is_imm;
wire        inst2_src2_is_imm16;
wire        inst2_src2_is_8;
wire        inst2_gr_we;
wire        inst2_mem_we;
wire [ 4:0] inst2_dest;
wire [31:0] inst2_rs_value;
wire [31:0] inst2_rt_value;

wire        self_r1_relevant;
wire        self_r2_relevant;
wire [31:0] br_target;

wire [31:0] inst2_rs_update_value;
wire [31:0] inst2_rt_update_value;


assign {inst2_valid,
        inst2_refill,
        inst2_ds_except,
        inst2_ds_exccode,
        inst2_es_tlbp,
        inst2_es_tlbr,
        inst2_es_tlbwi,
        inst2_es_eret,
        inst2_bd,
        inst2_detect_overflow,
        inst2_cp0_op,
        inst2_cp0_we,
        inst2_cp0_addr,
        inst2_load_store_type,
        inst2_load_op,
        inst2_hi_op,
        inst2_lo_op,
        inst2_hi_we,
        inst2_lo_we,
        inst2_hl_src_from_mul,
        inst2_hl_src_from_div,
        inst2_alu_op,
        inst2_src1_is_sa,
        inst2_src1_is_pc,
        inst2_src2_is_imm,
        inst2_src2_is_imm16,
        inst2_src2_is_8,
        inst2_gr_we,
        inst2_mem_we,
        inst2_dest,
        inst2_imm,
        inst2_rs_value,
        inst2_rt_value,
        inst2_pc,

        br_target,
        self_r1_relevant,
        self_r2_relevant,

        inst1_refill,
        inst1_ds_except,
        inst1_ds_exccode,
        inst1_es_tlbp,
        inst1_es_tlbr,
        inst1_es_tlbwi,
        inst1_es_eret,
        inst1_bd,
        inst1_detect_overflow,
        inst1_cp0_op,
        inst1_cp0_we,
        inst1_cp0_addr,
        inst1_load_store_type,
        inst1_load_op,
        inst1_hi_op,
        inst1_lo_op,
        inst1_hi_we,
        inst1_lo_we,
        inst1_hl_src_from_mul,
        inst1_hl_src_from_div,
        inst1_alu_op,
        inst1_src1_is_sa,
        inst1_src1_is_pc,
        inst1_src2_is_imm,
        inst1_src2_is_imm16,
        inst1_src2_is_8,
        inst1_gr_we,
        inst1_mem_we,
        inst1_dest,
        inst1_imm,
        inst1_rs_value,
        inst1_rt_value,
        inst1_pc
        } = ds_to_es_bus_r;

// EXE stage
wire        inst1_readygo;
wire        inst2_readygo;

assign es_ready_go    = (inst1_readygo & inst2_readygo) | clear_all;
assign es_allowin     = !es_valid || es_ready_go && pms_allowin;
assign es_to_pms_valid = es_valid && es_ready_go;

always @(posedge clk) begin
    if (reset) begin
        es_valid <= 1'b0;
    end
    else if (clear_all) begin
        es_valid <= 1'b0;
    end
    else if (es_allowin) begin
        es_valid <= ds_to_es_valid;
    end

    if (ds_to_es_valid && es_allowin) begin
        ds_to_es_bus_r <= ds_to_es_bus;
    end
end

//alu
wire [31:0] es_alu_inst1_src1   ;
wire [31:0] es_alu_inst1_src2   ;
wire [31:0] es_alu_inst1_result ;
// wire [63:0] es_alu_inst1_div_res;
// wire [63:0] es_alu_inst1_mul_res;
// wire        es_alu_inst1_complete ;
wire        es_alu_inst1_overflow;

wire [31:0] es_alu_inst2_src1   ;
wire [31:0] es_alu_inst2_src2   ;
wire [31:0] es_alu_inst2_result ;
// wire [63:0] es_alu_inst2_div_res;
// wire [63:0] es_alu_inst2_mul_res;
// wire        es_alu_inst2_complete ;
wire        es_alu_inst2_overflow;

wire [63:0] es_alu_div_res;
wire [63:0] es_alu_mul_res;
//wire        es_alu_complete;

reg  [31:0] es_alu_inst2_rs;
reg  [31:0] es_alu_inst2_rt;

wire [31:0] es_inst1_mem_addr;
wire [31:0] es_inst2_mem_addr;

wire [31:0] es_inst2_mem_addr_adder;

always @(posedge clk) begin
    if(reset)
        es_alu_inst2_rs <= 32'b0;
    else if(self_r1_relevant)
        es_alu_inst2_rs <= es_alu_inst1_result;
end

always @(posedge clk) begin
    if(reset)
        es_alu_inst2_rt <= 32'b0;
    else if(self_r2_relevant)
        es_alu_inst2_rt <= es_alu_inst1_result;
end

assign es_alu_inst1_src1 = inst1_src1_is_sa  ? {27'b0, inst1_imm[10:6]} :
                           inst1_src1_is_pc  ? inst1_pc :
                                               inst1_rs_value ;
assign es_alu_inst1_src2 = inst1_src2_is_imm   ? {{16{inst1_imm[15]}}, inst1_imm[15:0]} :
                           inst1_src2_is_imm16 ? {16'b0, inst1_imm[15:0]} :
                           inst1_src2_is_8     ? 32'd8 :
                                                 inst1_rt_value;

assign es_alu_inst2_src1 = inst2_src1_is_sa  ? {27'b0, inst2_imm[10:6]} :
                           inst2_src1_is_pc  ? inst2_pc :
                           self_r1_relevant  ? es_alu_inst2_rs :
                                               inst2_rs_value ;
assign es_alu_inst2_src2 = inst2_src2_is_imm   ? {{16{inst2_imm[15]}}, inst2_imm[15:0]} :
                           inst2_src2_is_imm16 ? {16'b0, inst2_imm[15:0]} : 
                           inst2_src2_is_8     ? 32'd8 :
                           self_r2_relevant    ? es_alu_inst2_rt :
                                                 inst2_rt_value;

assign es_inst2_mem_addr_adder = self_r1_relevant ? es_alu_inst2_rs : inst2_rs_value;

assign es_inst1_mem_addr = inst1_rs_value + {{16{inst1_imm[15]}}, inst1_imm[15:0]} ;
assign es_inst2_mem_addr = es_inst2_mem_addr_adder + {{16{inst2_imm[15]}}, inst2_imm[15:0]} ;

alu u_alu_inst1(
    .clk                (clk                  ),
    .reset              (reset                ),
    .alu_op             (inst1_alu_op         ),
    .alu_src1           (es_alu_inst1_src1    ),
    .alu_src2           (es_alu_inst1_src2    ),
    .alu_result         (es_alu_inst1_result  ),
    //.alu_div_res        (es_alu_inst1_div_res ),
    //.alu_mul_res        (es_alu_inst1_mul_res ),
    //.complete           (es_alu_inst1_complete),
    .overflow           (es_alu_inst1_overflow)
    //.exception          (clear_all            )
    );

alu u_alu_inst2(
    .clk                (clk                  ),
    .reset              (reset                ),
    .alu_op             (inst2_alu_op         ),
    .alu_src1           (es_alu_inst2_src1    ),
    .alu_src2           (es_alu_inst2_src2    ),
    .alu_result         (es_alu_inst2_result  ),
    //.alu_div_res        (es_alu_inst2_div_res ),
    //.alu_mul_res        (es_alu_inst2_mul_res ),
    //.complete           (es_alu_inst2_complete),
    .overflow           (es_alu_inst2_overflow)
    //.exception          (clear_all            )
    );

wire op_mult;
wire op_multu;
assign op_mult = inst2_alu_op[12] | inst1_alu_op[12];
assign op_multu = inst2_alu_op[13] | inst1_alu_op[13];

wire op_div;
wire op_divu;
assign op_div  = inst2_alu_op[14] | inst1_alu_op[14];
assign op_divu = inst2_alu_op[15] | inst1_alu_op[15];

wire [31:0] mul_src1;
wire [31:0] mul_src2;
wire [31:0] div_src1;
wire [31:0] div_src2;

assign mul_src1 = (inst1_alu_op[12] | inst1_alu_op[13]) ? es_alu_inst1_src1 : 
                  (inst2_alu_op[12] | inst2_alu_op[13]) ? es_alu_inst2_src1 : 32'b0;

assign mul_src2 = (inst1_alu_op[12] | inst1_alu_op[13]) ? es_alu_inst1_src2 : 
                  (inst2_alu_op[12] | inst2_alu_op[13]) ? es_alu_inst2_src2 : 32'b0;          

assign div_src1 = (inst1_alu_op[14] | inst1_alu_op[15]) ? es_alu_inst1_src1 : 
                  (inst2_alu_op[14] | inst2_alu_op[15]) ? es_alu_inst2_src1 : 32'b1; 

assign div_src2 = (inst1_alu_op[14] | inst1_alu_op[15]) ? es_alu_inst1_src2 : 
                  (inst2_alu_op[14] | inst2_alu_op[15]) ? es_alu_inst2_src2 : 32'b1;   

mul u_mul(
    .mul_clk    (clk              ),
    .resetn     (~reset           ),
    .mul_signed (op_mult          ),
    .x          (mul_src1         ),
    .y          (mul_src2         ),
    .result     (es_alu_mul_res   )
    );

// DIV, DIVU result
reg div;

wire div_complete;
wire complete;

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
    .x          (div_src1         ),
    .y          (div_src2         ),
    .s          (es_alu_div_res[63:32]),
    .r          (es_alu_div_res[31:0] ),
    .complete   (div_complete  ),
    .exception  (clear_all        )
    );

assign complete = ~(op_div | op_divu) | div_complete;

assign es_mul_res = es_alu_mul_res;

// assign es_inst1_mul_res = es_alu_inst1_mul_res;
// assign es_inst2_mul_res = es_alu_inst2_mul_res;

//self stall control
reg self_relevant_stall;
always @(posedge clk) begin
    if(reset)
        self_relevant_stall <= 1'b0;
    else if ((self_r1_relevant | self_r2_relevant) & es_valid & ~self_relevant_stall)
        self_relevant_stall <= 1'b1;
    else if (self_relevant_stall)
        self_relevant_stall <= 1'b0;
end

assign inst1_readygo = ~(inst1_alu_op[14] | inst1_alu_op[15]) | (div_complete);
assign inst2_readygo = ~(inst2_alu_op[14] | inst2_alu_op[15]) & ~(self_r1_relevant | self_r2_relevant) | 
                        (inst2_alu_op[14] | inst2_alu_op[15]) & (div_complete) | 
                       ~(inst2_alu_op[14] | inst2_alu_op[15]) & (self_r1_relevant | self_r2_relevant) & self_relevant_stall;

//exception
wire        inst1_es_except;
wire        inst2_es_except;
wire [ 4:0] inst1_es_exccode;
wire [ 4:0] inst2_es_exccode;
wire        inst1_es_Ov;
wire        inst2_es_Ov;
wire [31:0] inst1_es_BadVAddr;
wire [31:0] inst2_es_BadVAddr;

assign inst1_es_Ov = inst1_detect_overflow & es_alu_inst1_overflow;
assign inst2_es_Ov = inst2_detect_overflow & es_alu_inst2_overflow;

assign inst1_es_except = inst1_ds_except | inst1_es_Ov;
assign inst2_es_except = inst2_ds_except | inst2_es_Ov;

assign inst1_es_exccode = inst1_ds_except ? inst1_ds_exccode : 
                          inst1_es_Ov ? 5'hc : 5'b0;
assign inst2_es_exccode = inst2_ds_except ? inst2_ds_exccode : 
                          inst2_es_Ov ? 5'hc : 5'b0;

assign inst1_es_BadVAddr = inst1_ds_except ? inst1_pc : es_inst1_mem_addr;
assign inst2_es_BadVAddr = inst2_ds_except ? inst2_pc : es_inst2_mem_addr;


//forward bus
assign es_forward_bus = {es_valid, //es_to_pms_valid,
                        inst1_readygo, inst1_hi_op | inst1_lo_op | inst1_cp0_op | inst1_load_op, inst1_gr_we, inst1_dest, es_alu_inst1_result, 
                        inst2_readygo, inst2_hi_op | inst2_lo_op | inst2_cp0_op | inst2_load_op, inst2_gr_we, inst2_dest, es_alu_inst2_result };

// assign {es_valid, es_res_valid, 
//         es_inst1_mfhilo, es_inst1_mfc0, es_inst1_load, es_inst1_gr_we, es_inst1_dest, es_inst1_result, 
//         es_inst2_mfhilo, es_inst2_mfc0, es_inst2_load, es_inst2_gr_we, es_inst2_dest, es_inst2_result } = es_forward_bus;

// data bus to pms
assign inst2_rs_update_value = self_r1_relevant ? es_alu_inst1_result : inst2_rs_value;
assign inst2_rt_update_value = self_r2_relevant ? es_alu_inst1_result : inst2_rt_value;

assign es_to_pms_bus = {
                        inst2_valid,
                        inst2_refill,
                        inst2_es_except,
                        inst2_es_exccode,
                        inst2_es_BadVAddr,
                        inst2_es_tlbp,
                        inst2_es_tlbr,
                        inst2_es_tlbwi,
                        inst2_es_eret,
                        inst2_bd,
                        inst2_cp0_op,
                        inst2_cp0_we,
                        inst2_cp0_addr,
                        inst2_load_store_type,
                        inst2_load_op,
                        inst2_hi_op,
                        inst2_lo_op,
                        inst2_hi_we,
                        inst2_lo_we,
                        inst2_hl_src_from_mul,
                        inst2_hl_src_from_div,
                        es_alu_inst2_result,
                        //es_alu_inst2_div_res,
                        inst2_gr_we,
                        inst2_mem_we,
                        inst2_dest,
                        inst2_rs_update_value,// inst2_rs_value,
                        inst2_rt_update_value,// inst2_rt_value,
                        inst2_pc,
                        es_inst2_mem_addr,

                        br_target,
                        es_alu_div_res,

                        inst1_refill,
                        inst1_es_except,
                        inst1_es_exccode,
                        inst1_es_BadVAddr,
                        inst1_es_tlbp,
                        inst1_es_tlbr,
                        inst1_es_tlbwi,
                        inst1_es_eret,
                        inst1_bd,
                        inst1_cp0_op,
                        inst1_cp0_we,
                        inst1_cp0_addr,
                        inst1_load_store_type,
                        inst1_load_op,
                        inst1_hi_op,
                        inst1_lo_op,
                        inst1_hi_we,
                        inst1_lo_we,
                        inst1_hl_src_from_mul,
                        inst1_hl_src_from_div,
                        es_alu_inst1_result,
                        //es_alu_inst1_div_res,
                        inst1_gr_we,
                        inst1_mem_we,
                        inst1_dest,
                        inst1_rs_value,
                        inst1_rt_value,
                        inst1_pc,
                        es_inst1_mem_addr                        
                       };
endmodule