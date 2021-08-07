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

    // data cache interface
    output           inst1_data_cache_valid,
    output           inst1_data_cache_op,
    output           inst1_data_cache_uncache,
    output  [ 19:0]  inst1_data_cache_tag,
    output  [  7:0]  inst1_data_cache_index,
    output  [  3:0]  inst1_data_cache_offset,
    output  [  1:0]  inst1_data_cache_size, 
    output  [  3:0]  inst1_data_cache_wstrb,
    output  [ 31:0]  inst1_data_cache_wdata,
    input            inst1_data_cache_addr_ok,

    output           inst2_data_cache_valid,
    output           inst2_data_cache_op,
    output           inst2_data_cache_uncache,
    output  [ 19:0]  inst2_data_cache_tag,
    output  [  7:0]  inst2_data_cache_index,
    output  [  3:0]  inst2_data_cache_offset,
    output  [  1:0]  inst2_data_cache_size, 
    output  [  3:0]  inst2_data_cache_wstrb,
    output  [ 31:0]  inst2_data_cache_wdata,
    input            inst2_data_cache_addr_ok,

    //relevant bus
    output [`ES_FORWARD_BUS_WD -1:0] es_forward_bus,
  
    //clear stage
    input         clear_all
);

reg         es_valid;
wire        es_ready_go;

reg  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus_r;

wire [15:0] inst1_imm;
wire        inst1_mul;
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
wire        inst2_mul;
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


assign {inst2_valid,       //390
        inst2_mul,          //389
        inst2_refill,       //388
        inst2_ds_except,    //387
        inst2_ds_exccode,   //382:386
        inst2_es_tlbp,      //381
        inst2_es_tlbr,      //380
        inst2_es_tlbwi,     //379
        inst2_es_eret,      //378
        inst2_bd,           //377
        inst2_detect_overflow,//376
        inst2_cp0_op,       //375
        inst2_cp0_we,       //374
        inst2_cp0_addr,     //366:373
        inst2_load_store_type,//359:365
        inst2_load_op,      //358
        inst2_hi_op,        //357
        inst2_lo_op,        //356
        inst2_hi_we,        //355
        inst2_lo_we,        //354
        inst2_hl_src_from_mul,//353
        inst2_hl_src_from_div,//352
        inst2_alu_op,       //336:351
        inst2_src1_is_sa,   //335
        inst2_src1_is_pc,   //334
        inst2_src2_is_imm,  //333
        inst2_src2_is_imm16,//332
        inst2_src2_is_8,    //331
        inst2_gr_we,        //330
        inst2_mem_we,       //329
        inst2_dest,         //324:328
        inst2_imm,          //308:323
        inst2_rs_value,     //276:307
        inst2_rt_value,     //244:275
        inst2_pc,           //212:243

        br_target,          //180:211
        self_r1_relevant,   //179
        self_r2_relevant,   //178

        inst1_mul,          //177
        inst1_refill,       //176
        inst1_ds_except,    //175
        inst1_ds_exccode,   //170:174
        inst1_es_tlbp,      //169
        inst1_es_tlbr,      //168
        inst1_es_tlbwi,     //167
        inst1_es_eret,      //166
        inst1_bd,           //165
        inst1_detect_overflow,//164
        inst1_cp0_op,       //163
        inst1_cp0_we,       //162
        inst1_cp0_addr,     //154:161
        inst1_load_store_type,//147:153
        inst1_load_op,      //146
        inst1_hi_op,        //145
        inst1_lo_op,        //144
        inst1_hi_we,        //143
        inst1_lo_we,        //142
        inst1_hl_src_from_mul,//141
        inst1_hl_src_from_div,//140
        inst1_alu_op,       //124:139
        inst1_src1_is_sa,   //123
        inst1_src1_is_pc,   //122
        inst1_src2_is_imm,  //121
        inst1_src2_is_imm16,//120
        inst1_src2_is_8,    //119
        inst1_gr_we,        //118
        inst1_mem_we,       //117
        inst1_dest,         //112:116
        inst1_imm,          //96:111
        inst1_rs_value,     //64:95
        inst1_rt_value,     //32:63
        inst1_pc            //0:31
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

assign es_inst2_mem_addr_adder = {32{self_r1_relevant}}  & es_alu_inst2_rs |
                                  {32{~self_r1_relevant}} & inst2_rs_value;

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

wire inst1_div_readygo;
wire inst2_div_readygo;
wire inst1_mem_readygo;
wire inst2_mem_readygo;

assign inst1_mem_readygo = ~(inst1_load_op | inst1_mem_we) | (inst1_load_op | inst1_mem_we) & (inst1_data_cache_addr_ok) | inst1_es_except; //不访�??? 访存请求接受 有例�???
assign inst2_mem_readygo = ~(inst2_load_op | inst2_mem_we) | (inst2_load_op | inst2_mem_we) & (inst2_data_cache_addr_ok) | (inst1_es_except | inst1_es_eret | inst2_es_except);

assign inst1_div_readygo = ~(inst1_alu_op[14] | inst1_alu_op[15]) | (div_complete);

assign inst2_div_readygo = ~(inst2_alu_op[14] | inst2_alu_op[15]) & ~(self_r1_relevant | self_r2_relevant) | 
                            (inst2_alu_op[14] | inst2_alu_op[15]) & (div_complete) | 
                           ~(inst2_alu_op[14] | inst2_alu_op[15]) & (self_r1_relevant | self_r2_relevant) & self_relevant_stall;

assign inst1_readygo = inst1_div_readygo & inst1_mem_readygo;
assign inst2_readygo = inst2_div_readygo & inst2_mem_readygo;


//forward bus
assign es_forward_bus = {es_valid, //es_to_pms_valid,
                        inst1_readygo, inst1_hi_op | inst1_lo_op | inst1_cp0_op | inst1_load_op | inst1_mul, inst1_gr_we, inst1_dest, es_alu_inst1_result, 
                        inst2_readygo, inst2_hi_op | inst2_lo_op | inst2_cp0_op | inst2_load_op | inst2_mul, inst2_gr_we, inst2_dest, es_alu_inst2_result };

// assign {es_valid, es_res_valid, 
//         es_inst1_mfhilo, es_inst1_mfc0, es_inst1_load, es_inst1_gr_we, es_inst1_dest, es_inst1_result, 
//         es_inst2_mfhilo, es_inst2_mfc0, es_inst2_load, es_inst2_gr_we, es_inst2_dest, es_inst2_result } = es_forward_bus;

// data bus to pms
assign inst2_rs_update_value = self_r1_relevant ? es_alu_inst1_result : inst2_rs_value;
assign inst2_rt_update_value = self_r2_relevant ? es_alu_inst1_result : inst2_rt_value;

assign es_to_pms_bus = {
                        es_inst2_valid,             //572
                        inst2_mul,                  //571
                        inst2_refill,               //570
                        inst2_es_except,            //569   
                        inst2_es_exccode,           //564:568
                        inst2_es_BadVAddr,          //532:563
                        inst2_es_tlbp,              //531
                        inst2_es_tlbr,              //530
                        inst2_es_tlbwi,             //529
                        inst2_es_eret,              //528
                        inst2_bd,                   //527
                        inst2_cp0_op,               //526
                        inst2_cp0_we,               //525
                        inst2_cp0_addr,             //517:524
                        inst2_load_store_type,      //510:516
                        inst2_load_op,              //509
                        inst2_hi_op,                //508
                        inst2_lo_op,                //507
                        inst2_hi_we,                //506
                        inst2_lo_we,                //505
                        inst2_hl_src_from_mul,      //504
                        inst2_hl_src_from_div,      //503
                        es_alu_inst2_result,        //471:502
                        //es_alu_inst2_div_res,
                        inst2_gr_we,                //470
                        inst2_mem_we,               //469
                        inst2_dest,                 //464:468
                        inst2_rs_update_value,      //432:463
                        inst2_rt_update_value,      //400:431
                        inst2_pc,                   //368:399
                        es_inst2_mem_addr,          //336:367
                        inst2_load_store_offset,    //334:335

                        br_target,                  //302:333
                        es_alu_div_res,             //238:301

                        inst1_mul,                  //237
                        inst1_refill,               //236
                        inst1_es_except,            //235
                        inst1_es_exccode,           //230:234
                        inst1_es_BadVAddr,          //198:229
                        inst1_es_tlbp,              //197
                        inst1_es_tlbr,              //196
                        inst1_es_tlbwi,             //195
                        inst1_es_eret,              //194
                        inst1_bd,                   //193
                        inst1_cp0_op,               //192
                        inst1_cp0_we,               //191
                        inst1_cp0_addr,             //183:190
                        inst1_load_store_type,      //176:182
                        inst1_load_op,              //175
                        inst1_hi_op,                //174
                        inst1_lo_op,                //173
                        inst1_hi_we,                //172
                        inst1_lo_we,                //171
                        inst1_hl_src_from_mul,      //170
                        inst1_hl_src_from_div,      //169
                        es_alu_inst1_result,        //137:168
                        //es_alu_inst1_div_res,
                        inst1_gr_we,                //136
                        inst1_mem_we,               //135
                        inst1_dest,                 //130:134
                        inst1_rs_value,             //98:129
                        inst1_rt_value,             //66:97
                        inst1_pc,                   //34:65
                        es_inst1_mem_addr,          //2:33
                        inst1_load_store_offset     //0:1                 
                       };


// mem
wire [1:0] inst2_load_store_offset;
wire [1:0] inst1_load_store_offset;


assign inst2_load_store_offset = es_inst2_mem_addr[1:0];
assign inst1_load_store_offset = es_inst1_mem_addr[1:0];

wire inst1_mem_align_off_0, inst2_mem_align_off_0;
wire inst1_mem_align_off_1, inst2_mem_align_off_1;
wire inst1_mem_align_off_2, inst2_mem_align_off_2;
wire inst1_mem_align_off_3, inst2_mem_align_off_3;

assign inst1_mem_align_off_0 = (inst1_load_store_offset == 2'b00);
assign inst1_mem_align_off_1 = (inst1_load_store_offset == 2'b01);
assign inst1_mem_align_off_2 = (inst1_load_store_offset == 2'b10);
assign inst1_mem_align_off_3 = (inst1_load_store_offset == 2'b11);

assign inst2_mem_align_off_0 = (inst2_load_store_offset == 2'b00);
assign inst2_mem_align_off_1 = (inst2_load_store_offset == 2'b01);
assign inst2_mem_align_off_2 = (inst2_load_store_offset == 2'b10);
assign inst2_mem_align_off_3 = (inst2_load_store_offset == 2'b11);

wire inst1_sb_mem_res,  inst2_sb_mem_res;
wire inst1_sbu_mem_res, inst2_sbu_mem_res;
wire inst1_sh_mem_res,  inst2_sh_mem_res;
wire inst1_shu_mem_res, inst2_shu_mem_res;
wire inst1_sw_mem_res,  inst2_sw_mem_res;
wire inst1_swl_mem_res, inst2_swl_mem_res;
wire inst1_swr_mem_res, inst2_swr_mem_res;

assign inst1_sb_mem_res = inst1_load_store_type[6];
assign inst1_sbu_mem_res = inst1_load_store_type[5];
assign inst1_sh_mem_res = inst1_load_store_type[4];
assign inst1_shu_mem_res = inst1_load_store_type[3];
assign inst1_sw_mem_res = inst1_load_store_type[2];
assign inst1_swl_mem_res = inst1_load_store_type[1];
assign inst1_swr_mem_res = inst1_load_store_type[0];

assign inst2_sb_mem_res = inst2_load_store_type[6];
assign inst2_sbu_mem_res = inst2_load_store_type[5];
assign inst2_sh_mem_res = inst2_load_store_type[4];
assign inst2_shu_mem_res = inst2_load_store_type[3];
assign inst2_sw_mem_res = inst2_load_store_type[2];
assign inst2_swl_mem_res = inst2_load_store_type[1];
assign inst2_swr_mem_res = inst2_load_store_type[0];

wire [3:0] inst1_write_strb;
wire [3:0] inst2_write_strb;

assign inst1_write_strb = {4{inst1_sb_mem_res & inst1_mem_align_off_0}} & 4'b0001 |                           //sb
                          {4{inst1_sb_mem_res & inst1_mem_align_off_1}} & 4'b0010 |
                          {4{inst1_sb_mem_res & inst1_mem_align_off_2}} & 4'b0100 |
                          {4{inst1_sb_mem_res & inst1_mem_align_off_3}} & 4'b1000 |
                          {4{inst1_sh_mem_res & (inst1_mem_align_off_0 | inst1_mem_align_off_1)}} & 4'b0011 |       //sh
                          {4{inst1_sh_mem_res & (inst1_mem_align_off_2 | inst1_mem_align_off_3)}} & 4'b1100 |
                          {4{inst1_sw_mem_res}} & 4'b1111 |                                             //sw
                          {4{inst1_swl_mem_res & inst1_mem_align_off_0}} & 4'b0001 |                          //swl
                          {4{inst1_swl_mem_res & inst1_mem_align_off_1}} & 4'b0011 |
                          {4{inst1_swl_mem_res & inst1_mem_align_off_2}} & 4'b0111 |
                          {4{inst1_swl_mem_res & inst1_mem_align_off_3}} & 4'b1111 |
                          {4{inst1_swr_mem_res & inst1_mem_align_off_0}} & 4'b1111 |                          //swr
                          {4{inst1_swr_mem_res & inst1_mem_align_off_1}} & 4'b1110 |
                          {4{inst1_swr_mem_res & inst1_mem_align_off_2}} & 4'b1100 |
                          {4{inst1_swr_mem_res & inst1_mem_align_off_3}} & 4'b1000 ;

assign inst2_write_strb = {4{inst2_sb_mem_res & inst2_mem_align_off_0}} & 4'b0001 |                           //sb
                          {4{inst2_sb_mem_res & inst2_mem_align_off_1}} & 4'b0010 |
                          {4{inst2_sb_mem_res & inst2_mem_align_off_2}} & 4'b0100 |
                          {4{inst2_sb_mem_res & inst2_mem_align_off_3}} & 4'b1000 |
                          {4{inst2_sh_mem_res & (inst2_mem_align_off_0 | inst2_mem_align_off_1)}} & 4'b0011 |       //sh
                          {4{inst2_sh_mem_res & (inst2_mem_align_off_2 | inst2_mem_align_off_3)}} & 4'b1100 |
                          {4{inst2_sw_mem_res}} & 4'b1111 |                                             //sw
                          {4{inst2_swl_mem_res & inst2_mem_align_off_0}} & 4'b0001 |                          //swl
                          {4{inst2_swl_mem_res & inst2_mem_align_off_1}} & 4'b0011 |
                          {4{inst2_swl_mem_res & inst2_mem_align_off_2}} & 4'b0111 |
                          {4{inst2_swl_mem_res & inst2_mem_align_off_3}} & 4'b1111 |
                          {4{inst2_swr_mem_res & inst2_mem_align_off_0}} & 4'b1111 |                          //swr
                          {4{inst2_swr_mem_res & inst2_mem_align_off_1}} & 4'b1110 |
                          {4{inst2_swr_mem_res & inst2_mem_align_off_2}} & 4'b1100 |
                          {4{inst2_swr_mem_res & inst2_mem_align_off_3}} & 4'b1000 ;

assign inst1_data_cache_size = {2{inst1_sw_mem_res}} & 2'b10 |                                          //sw,lw
                               {2{(inst1_sh_mem_res | inst1_shu_mem_res) & (inst1_mem_align_off_0 | inst1_mem_align_off_1)}} & 2'b01 |   //sh lh lhu             //wrong in handbook
                               {2{(inst1_sh_mem_res | inst1_shu_mem_res) & (inst1_mem_align_off_2 | inst1_mem_align_off_3)}} & 2'b01 |
                               {2{(inst1_sb_mem_res | inst1_sbu_mem_res) & (inst1_mem_align_off_0)}} & 2'b00 |      //sb  lb  lbu
                               {2{(inst1_sb_mem_res | inst1_sbu_mem_res) & (inst1_mem_align_off_1)}} & 2'b00 |
                               {2{(inst1_sb_mem_res | inst1_sbu_mem_res) & (inst1_mem_align_off_2)}} & 2'b00 |
                               {2{(inst1_sb_mem_res | inst1_sbu_mem_res) & (inst1_mem_align_off_3)}} & 2'b00 |
                               {2{(inst1_swl_mem_res ) & (inst1_mem_align_off_0)}} & 2'b00 |                  //swl  lwl
                               {2{(inst1_swl_mem_res ) & (inst1_mem_align_off_1)}} & 2'b01 |
                               {2{(inst1_swl_mem_res ) & (inst1_mem_align_off_2)}} & 2'b10 |
                               {2{(inst1_swl_mem_res ) & (inst1_mem_align_off_3)}} & 2'b10 |
                               {2{(inst1_swr_mem_res ) & (inst1_mem_align_off_0)}} & 2'b10 |                  //swr  lwr
                               {2{(inst1_swr_mem_res ) & (inst1_mem_align_off_1)}} & 2'b10 |
                               {2{(inst1_swr_mem_res ) & (inst1_mem_align_off_2)}} & 2'b01 |
                               {2{(inst1_swr_mem_res ) & (inst1_mem_align_off_3)}} & 2'b00 ;

assign inst2_data_cache_size = {2{inst2_sw_mem_res}} & 2'b10 |                                          //sw,lw
                               {2{(inst2_sh_mem_res | inst2_shu_mem_res) & (inst2_mem_align_off_0 | inst2_mem_align_off_1)}} & 2'b01 |   //sh lh lhu             //wrong in handbook
                               {2{(inst2_sh_mem_res | inst2_shu_mem_res) & (inst2_mem_align_off_2 | inst2_mem_align_off_3)}} & 2'b01 |
                               {2{(inst2_sb_mem_res | inst2_sbu_mem_res) & (inst2_mem_align_off_0)}} & 2'b00 |      //sb  lb  lbu
                               {2{(inst2_sb_mem_res | inst2_sbu_mem_res) & (inst2_mem_align_off_1)}} & 2'b00 |
                               {2{(inst2_sb_mem_res | inst2_sbu_mem_res) & (inst2_mem_align_off_2)}} & 2'b00 |
                               {2{(inst2_sb_mem_res | inst2_sbu_mem_res) & (inst2_mem_align_off_3)}} & 2'b00 |
                               {2{(inst2_swl_mem_res ) & (inst2_mem_align_off_0)}} & 2'b00 |                  //swl  lwl
                               {2{(inst2_swl_mem_res ) & (inst2_mem_align_off_1)}} & 2'b01 |
                               {2{(inst2_swl_mem_res ) & (inst2_mem_align_off_2)}} & 2'b10 |
                               {2{(inst2_swl_mem_res ) & (inst2_mem_align_off_3)}} & 2'b10 |
                               {2{(inst2_swr_mem_res ) & (inst2_mem_align_off_0)}} & 2'b10 |                  //swr  lwr
                               {2{(inst2_swr_mem_res ) & (inst2_mem_align_off_1)}} & 2'b10 |
                               {2{(inst2_swr_mem_res ) & (inst2_mem_align_off_2)}} & 2'b01 |
                               {2{(inst2_swr_mem_res ) & (inst2_mem_align_off_3)}} & 2'b00 ;

assign inst1_data_cache_wdata = {32{inst1_sb_mem_res}} & {4{inst1_rt_value[ 7:0]}} |
                                {32{inst1_sh_mem_res}} & {2{inst1_rt_value[15:0]}} |
                                {32{inst1_sw_mem_res}} & {inst1_rt_value} |
                                {32{inst1_swl_mem_res & inst1_mem_align_off_0}} & {24'b0, inst1_rt_value[31:24]} |
                                {32{inst1_swl_mem_res & inst1_mem_align_off_1}} & {16'b0, inst1_rt_value[31:16]} |
                                {32{inst1_swl_mem_res & inst1_mem_align_off_2}} & { 8'b0, inst1_rt_value[31: 8]} |
                                {32{inst1_swl_mem_res & inst1_mem_align_off_3}} & inst1_rt_value |
                                {32{inst1_swr_mem_res & inst1_mem_align_off_0}} & inst1_rt_value |
                                {32{inst1_swr_mem_res & inst1_mem_align_off_1}} & {inst1_rt_value[23: 0], 8'b0} |
                                {32{inst1_swr_mem_res & inst1_mem_align_off_2}} & {inst1_rt_value[15: 0],16'b0} |
                                {32{inst1_swr_mem_res & inst1_mem_align_off_3}} & {inst1_rt_value[ 7: 0],24'b0} ;

assign inst2_data_cache_wdata = {32{inst2_sb_mem_res}} & {4{inst2_rt_update_value[ 7:0]}} |
                                {32{inst2_sh_mem_res}} & {2{inst2_rt_update_value[15:0]}} |
                                {32{inst2_sw_mem_res}} & {inst2_rt_update_value} |
                                {32{inst2_swl_mem_res & inst2_mem_align_off_0}} & {24'b0, inst2_rt_update_value[31:24]} |
                                {32{inst2_swl_mem_res & inst2_mem_align_off_1}} & {16'b0, inst2_rt_update_value[31:16]} |
                                {32{inst2_swl_mem_res & inst2_mem_align_off_2}} & { 8'b0, inst2_rt_update_value[31: 8]} |
                                {32{inst2_swl_mem_res & inst2_mem_align_off_3}} & inst2_rt_update_value |
                                {32{inst2_swr_mem_res & inst2_mem_align_off_0}} & inst2_rt_update_value |
                                {32{inst2_swr_mem_res & inst2_mem_align_off_1}} & {inst2_rt_update_value[23: 0], 8'b0} |
                                {32{inst2_swr_mem_res & inst2_mem_align_off_2}} & {inst2_rt_update_value[15: 0],16'b0} |
                                {32{inst2_swr_mem_res & inst2_mem_align_off_3}} & {inst2_rt_update_value[ 7: 0],24'b0} ;

wire [31:0] inst1_data_addr;
wire [31:0] inst2_data_addr;
wire [31:0] inst1_VA;
wire [31:0] inst2_VA;

//reg inst1_addr_ok_reg;
//reg inst2_addr_ok_reg;

//always@(posedge clk) begin
//    if(reset) begin
//        inst1_addr_ok_reg <= 1'b0;
//    end
//    else if(es_to_pms_valid && pms_allowin)
//        inst1_addr_ok_reg <= 1'b0;
//    else if(inst1_data_cache_addr_ok)
//        inst1_addr_ok_reg <= 1'b1;
//end

//always@(posedge clk) begin
//    if(reset) begin
//        inst2_addr_ok_reg <= 1'b0;
//    end
//    else if(es_to_pms_valid && pms_allowin)
//        inst2_addr_ok_reg <= 1'b0;
//    else if(inst2_data_cache_addr_ok)
//        inst2_addr_ok_reg <= 1'b1;
//end

assign inst1_VA = inst1_swl_mem_res ? {es_inst1_mem_addr[31:2], 2'b0} : es_inst1_mem_addr;
assign inst2_VA = inst2_swl_mem_res ? {es_inst2_mem_addr[31:2], 2'b0} : es_inst2_mem_addr;
assign inst1_data_addr = {3'b0, inst1_VA[28:0]};
assign inst2_data_addr = {3'b0, inst2_VA[28:0]};


assign inst1_data_cache_valid = (inst1_load_op | inst1_mem_we) & es_valid & ~inst1_es_except & (inst2_load_op | inst2_mem_we | inst2_div_readygo);
assign inst1_data_cache_op = inst1_mem_we;
assign inst1_data_cache_uncache = inst1_VA[31] && ~inst1_VA[30] && inst1_VA[29];
assign inst1_data_cache_tag = inst1_data_addr[31:12];
assign inst1_data_cache_index = inst1_data_addr[11:4];
assign inst1_data_cache_offset = inst1_data_addr[3:0];
assign inst1_data_cache_wstrb = (inst1_mem_we & es_valid & ~inst1_es_except) ? inst1_write_strb : 4'h0;

// wire mem_RAW;
// assign mem_RAW = (inst1_VA[31:2] == inst2_VA[31:2]) & inst1_mem_we & inst2_load_op & ~inst1_es_except & ~inst2_es_except;

assign inst2_data_cache_valid = (inst2_load_op | inst2_mem_we) & es_valid & ~(inst1_es_except | inst1_es_eret) & ~inst2_es_except & (inst1_load_op | inst1_mem_we | (~(self_r1_relevant | self_r2_relevant) | ((self_r1_relevant | self_r2_relevant) & self_relevant_stall)) | inst1_div_readygo);
assign inst2_data_cache_op = inst2_mem_we;
assign inst2_data_cache_uncache = inst2_VA[31] && ~inst2_VA[30] && inst2_VA[29];
assign inst2_data_cache_tag = inst2_data_addr[31:12];
assign inst2_data_cache_index = inst2_data_addr[11:4];
assign inst2_data_cache_offset = inst2_data_addr[3:0];
assign inst2_data_cache_wstrb = (inst2_mem_we & es_valid & ~inst1_es_except & ~inst2_es_except) ? inst2_write_strb : 4'h0;

// exception
wire es_inst2_valid;
assign es_inst2_valid = inst2_valid & ~(inst1_es_except | inst2_es_except | inst1_es_eret);

wire inst1_exception_adel, inst1_exception_ades;
wire inst2_exception_adel, inst2_exception_ades;
//TLB EXCEPTION IS NOT ADD HERE !!
assign inst1_exception_adel  = inst1_load_op && (inst1_sh_mem_res  && ~(es_inst1_mem_addr[0] == 0) ||
                                                inst1_shu_mem_res && ~(es_inst1_mem_addr[0] == 0) ||
                                                inst1_sw_mem_res  && ~(es_inst1_mem_addr[1:0] == 0));

assign inst1_exception_ades  = inst1_mem_we  && (inst1_sh_mem_res  && ~(es_inst1_mem_addr[0] == 0) ||
                                                inst1_shu_mem_res && ~(es_inst1_mem_addr[0] == 0) ||
                                                inst1_sw_mem_res  && ~(es_inst1_mem_addr[1:0] == 0));

assign inst2_exception_adel  = inst2_load_op && (inst2_sh_mem_res  && ~(es_inst2_mem_addr[0] == 0) ||
                                                inst2_shu_mem_res && ~(es_inst2_mem_addr[0] == 0) ||
                                                inst2_sw_mem_res  && ~(es_inst2_mem_addr[1:0] == 0));

assign inst2_exception_ades  = inst2_mem_we  && (inst2_sh_mem_res  && ~(es_inst2_mem_addr[0] == 0) ||
                                                inst2_shu_mem_res && ~(es_inst2_mem_addr[0] == 0) ||
                                                inst2_sw_mem_res  && ~(es_inst2_mem_addr[1:0] == 0));

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

assign inst1_es_except = inst1_ds_except | inst1_es_Ov | (inst1_exception_adel | inst1_exception_ades);
assign inst2_es_except = inst2_ds_except | inst2_es_Ov | (inst2_exception_adel | inst2_exception_ades);

assign inst1_es_exccode = inst1_ds_except ? inst1_ds_exccode : 
                          inst1_es_Ov ? 5'hc : 
                          inst1_exception_adel ? 5'h4 :
                          inst1_exception_ades ? 5'h5 : 5'h0;

assign inst2_es_exccode = inst2_ds_except ? inst2_ds_exccode : 
                          inst2_es_Ov ? 5'hc : 
                          inst2_exception_adel ? 5'h4 :
                          inst2_exception_ades ? 5'h5 : 5'h0;

assign inst1_es_BadVAddr = inst1_ds_except ? inst1_pc : inst1_VA;
assign inst2_es_BadVAddr = inst2_ds_except ? inst2_pc : inst2_VA;


// assign inst1_pms_except = inst1_es_except | (inst1_exception_adel | inst1_exception_ades);
// assign inst2_pms_except = inst2_es_except | (inst2_exception_adel | inst2_exception_ades);

// assign inst1_pms_exccode = inst1_es_except ? inst1_es_exccode : 
//                            inst1_exception_adel ? 5'h4 :
//                            inst1_exception_ades ? 5'h5 : 5'h0;

// assign inst2_pms_exccode = inst2_es_except ? inst2_es_exccode : 
//                            inst2_exception_adel ? 5'h4 :
//                            inst2_exception_ades ? 5'h5 : 5'h0;

// assign inst1_pms_BadVAddr = inst1_es_except ? inst1_es_BadVAddr : inst1_VA;
// assign inst2_pms_BadVAddr = inst2_es_except ? inst2_es_BadVAddr : inst2_VA;



endmodule