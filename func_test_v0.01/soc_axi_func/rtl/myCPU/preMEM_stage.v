`include "mycpu.h"

module premem_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          ms_allowin    ,
    output                         pms_allowin   ,
    //from es
    input                          es_to_pms_valid,
    input [`ES_TO_PMS_BUS_WD -1:0] es_to_pms_bus  ,
    input [63:0]                   pms_mul_res,
    
    //to ms
    output                           pms_to_ms_valid,
    output  [`PMS_TO_MS_BUS_WD -1:0] pms_to_ms_bus  ,

    //relevant bus
    output [`PMS_FORWARD_BUS_WD -1:0] pms_forward_bus,
    //clear stage
    output         clear_all                      ,
    output [31:0]  reflush_pc                     ,

    //TLB
    // write port
    output         we,
    output  [ 3:0] w_index,
    output  [11:0] w_mask,
    output  [18:0] w_vpn2,
    output  [ 7:0] w_asid,
    output         w_g,
    output  [19:0] w_pfn0, 
    output  [ 2:0] w_c0,
    output         w_d0,
    output         w_v0,
    output  [19:0] w_pfn1,
    output  [ 2:0] w_c1,
    output         w_d1,
    output         w_v1, 
    // read port
    output  [ 3:0] r_index,
    input   [18:0] r_vpn2,
    input   [ 7:0] r_asid,
    input          r_g,
    input   [19:0] r_pfn0,
    input   [ 2:0] r_c0,
    input          r_d0,
    input          r_v0,
    input   [19:0] r_pfn1,
    input   [ 2:0] r_c1,
    input          r_d1,
    input          r_v1,

    //cp0
    //signals of mtc0, from pms
    output  [31:0] inst1_c0_wdata    ,
    output  [ 7:0] inst1_c0_addr     ,
    output         inst1_mtc0_we     ,
    output  [31:0] inst2_c0_wdata    ,
    output  [ 7:0] inst2_c0_addr     ,
    output         inst2_mtc0_we     ,    
    //signals of the exception, from pms, only one inst
    output         pms_ex       , //has exception
    output  [ 4:0] ex_type     , //type of exception
    output         pms_bd       , //is delay slot
    output  [31:0] pms_pc       , //pc
    output  [31:0] pms_badvaddr , //bad vaddr
    output         pms_eret        , //is eret
    output  [ 1:0] pms_except_ce    ,

    //output to pms
    input [31:0] inst1_c0_rdata    ,
    input [31:0] inst2_c0_rdata    ,
    input        has_int           ,
    input [31:0] pms_epc           ,

    //for TLB
    input [31:0] cp0_index   ,
    input [31:0] cp0_entryhi ,
    input [31:0] cp0_entrylo0,
    input [31:0] cp0_entrylo1,
    input [11:0] c0_mask,
    input [31:0] c0_status,
    input [31:0] c0_cause,

    //TLBR\TLBP to CP0
    output        is_TLBR      ,
    output [77:0] TLB_rdata    ,
    output        is_TLBP      ,
    output        is_TLBWR     ,
    output        index_write_p,
    output [ 3:0] index_write_index,
    input  [ 3:0] c0_random_random,

    output       pms_mtc0_index   

);

// preMEM 
reg         pms_valid;
wire        pms_ready_go;

reg [`ES_TO_PMS_BUS_WD -1:0] es_to_pms_bus_r;

wire        inst1_ready_go; 
wire        inst2_ready_go;

assign pms_ready_go    = (inst1_ready_go & inst2_ready_go) | clear_all;
assign pms_allowin     = !pms_valid || pms_ready_go && ms_allowin;
assign pms_to_ms_valid = (pms_valid & pms_ready_go) & ~(inst1_pms_except | inst1_pms_eret);

always @(posedge clk) begin
    if (reset) begin
        pms_valid <= 1'b0;
    end
    else if(clear_all & ((inst1_pms_except | inst1_pms_eret) | (inst2_pms_except | inst2_pms_eret) & pms_ready_go & pms_ready_go)) begin
        pms_valid <= 1'b0;         
    end
    else if (pms_allowin) begin
        pms_valid <= es_to_pms_valid;
    end

    if (es_to_pms_valid && pms_allowin) begin
        es_to_pms_bus_r  <= es_to_pms_bus;
    end
end

assign inst1_ready_go = 1'b1;
assign inst2_ready_go = 1'b1;

wire        inst1_mul;
wire        inst1_refill;
wire [31:0] inst1_pc;
wire        inst1_pms_except;
wire [ 4:0] inst1_pms_exccode;
wire [31:0] inst1_pms_BadVAddr;
wire        inst1_pms_tlbp;
wire        inst1_pms_tlbr;
wire        inst1_pms_tlbwi;
wire        inst1_pms_tlbwr;
wire        inst1_pms_eret;
wire        inst1_bd;
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
wire [31:0] pms_alu_inst1_result;
wire [63:0] pms_alu_inst1_div_res;
wire        inst1_gr_we;
wire        inst1_mem_we;
wire [ 4:0] inst1_dest;
wire [31:0] inst1_rs_value;
wire [31:0] inst1_rt_value;
wire [31:0] pms_inst1_mem_addr;

wire        inst2_mul;
wire        inst2_refill;
wire        inst2_valid;
wire [31:0] inst2_pc;
wire        inst2_pms_except;
wire [ 4:0] inst2_pms_exccode;
wire [31:0] inst2_pms_BadVAddr;
wire        inst2_pms_tlbp;
wire        inst2_pms_tlbr;
wire        inst2_pms_tlbwi;
wire        inst2_pms_tlbwr;
wire        inst2_pms_eret;
wire        inst2_bd;
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
wire [31:0] pms_alu_inst2_result;
wire [63:0] pms_alu_inst2_div_res;
wire        inst2_gr_we;
wire        inst2_mem_we;
wire [ 4:0] inst2_dest;
wire [31:0] inst2_rs_value;
wire [31:0] inst2_rt_value;
wire [31:0] pms_inst2_mem_addr;

wire [31:0] br_target;

wire [1:0] inst2_load_store_offset;
wire [1:0] inst1_load_store_offset;

wire        inst1_s1_found;
wire [ 3:0] inst1_s1_index;
wire        inst2_s1_found;
wire [ 3:0] inst2_s1_index;

wire        inst1_es_except;
wire [4:0]  inst1_es_exccode;
wire [31:0] inst1_es_BadVAddr;
wire        inst2_es_except;
wire [4:0]  inst2_es_exccode;
wire [31:0] inst2_es_BadVAddr;

wire [63:0] pms_alu_div_res;

assign {inst1_pms_tlbwr,
        inst2_pms_tlbwr,
        inst2_valid,
        inst2_s1_found,
        inst2_s1_index,
        inst2_mul,
        inst2_refill,
        inst2_es_except,
        inst2_es_exccode,
        inst2_es_BadVAddr,
        inst2_pms_tlbp,
        inst2_pms_tlbr,
        inst2_pms_tlbwi,
        inst2_pms_eret,
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
        pms_alu_inst2_result,
        inst2_gr_we,
        inst2_mem_we,
        inst2_dest,
        inst2_rs_value,
        inst2_rt_value,
        inst2_pc,
        pms_inst2_mem_addr,
        inst2_load_store_offset,

        br_target,
        pms_alu_div_res,

        inst1_s1_found,
        inst1_s1_index,
        inst1_mul,
        inst1_refill,
        inst1_es_except,
        inst1_es_exccode,
        inst1_es_BadVAddr,
        inst1_pms_tlbp,
        inst1_pms_tlbr,
        inst1_pms_tlbwi,
        inst1_pms_eret,
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
        pms_alu_inst1_result,
        inst1_gr_we,
        inst1_mem_we,
        inst1_dest,
        inst1_rs_value,
        inst1_rt_value,
        inst1_pc,
        pms_inst1_mem_addr, 
        inst1_load_store_offset      
       } = es_to_pms_bus_r;

// exception
assign inst1_pms_except = inst1_es_except;
assign inst2_pms_except = inst2_es_except;

assign inst1_pms_exccode = inst1_es_exccode;                   
assign inst2_pms_exccode = inst2_es_exccode;
                      

assign inst1_pms_BadVAddr = inst1_es_BadVAddr;
assign inst2_pms_BadVAddr = inst2_es_BadVAddr;


wire [31:0] exception_1_refush_pc;
wire [31:0] exception_2_refush_pc;

wire [31:0] reflush_pc_miss;
wire [31:0] reflush_pc_intr;
wire [31:0] reflush_pc_other;

assign reflush_pc_miss = {32{!c0_status[22] && !c0_status[1]}} & 32'h80000000 |
                         {32{!c0_status[22] &&  c0_status[1]}} & 32'h80000180 |
                         {32{ c0_status[22] && !c0_status[1]}} & 32'hbfc00200 |
                         {32{ c0_status[22] &&  c0_status[1]}} & 32'hbfc00380 ;

assign reflush_pc_intr = {32{!c0_status[22] && !c0_cause[23]}} & 32'h8000_0180 |
                         {32{!c0_status[22] &&  c0_cause[23]}} & 32'h8000_0200 |
                         {32{ c0_status[22] && !c0_cause[23]}} & 32'hbfc0_0380 |
                         {32{ c0_status[22] &&  c0_cause[23]}} & 32'hbfc0_0400 ;

assign reflush_pc_other = {32{!c0_status[22]}} & 32'h8000_0180 |
                          {32{ c0_status[22]}} & 32'hbfc0_0380 ;


assign exception_1_refush_pc = inst1_refill ? reflush_pc_miss :
                               (inst1_pms_except & inst1_pms_exccode == 0) ? reflush_pc_intr :
                               inst1_pms_eret ? pms_epc :
                               reflush_pc_other;

assign exception_2_refush_pc = inst2_refill ? reflush_pc_miss :
                               (inst2_pms_except & inst2_pms_exccode == 0) ? reflush_pc_intr :
                               inst2_pms_eret ? pms_epc :
                               reflush_pc_other;

assign reflush_pc = {32{inst1_pms_except | inst1_pms_eret}} & {exception_1_refush_pc} |
                    {32{inst2_pms_except | inst2_pms_eret}} & {exception_2_refush_pc} ;

assign clear_all = (inst2_pms_except | inst1_pms_except | inst1_pms_eret | inst2_pms_eret) & pms_valid;

// hi lo
reg [31:0] HI;
reg [31:0] LO;

reg  mul_res_save_done;
wire [31:0] lo32_for_mul;
reg  [31:0] lo32_for_mul_save;
reg  lo32_for_mul_save_done;

wire [31:0] inst1_write_hi;
wire [31:0] inst1_write_lo;
wire [31:0] inst2_write_hi;
wire [31:0] inst2_write_lo;

always@(posedge clk)begin
    if(reset)
        lo32_for_mul_save <= 32'b0;
    else if(pms_valid & (inst1_mul | inst2_mul) & ~inst1_pms_except) 
        lo32_for_mul_save <= pms_mul_res[31:0];
end

always @(posedge clk) begin
    if(reset)
        lo32_for_mul_save_done <= 1'b0;
    else if(pms_to_ms_valid && ms_allowin)
        lo32_for_mul_save_done <= 1'b0;
    else if(pms_valid & (inst1_mul | inst2_mul) & ~inst1_pms_except)
        lo32_for_mul_save_done <= 1'b1;
end

assign lo32_for_mul = ~lo32_for_mul_save_done ? pms_mul_res[31:0] : lo32_for_mul_save;

assign inst1_write_hi = {32{inst1_hl_src_from_mul}} & {pms_mul_res[63:32]} |
                        {32{inst1_hl_src_from_div}} & {pms_alu_div_res[31:0]} |
                        {32{~inst1_hl_src_from_div & ~inst1_hl_src_from_mul & inst1_hi_we}} & {inst1_rs_value};

assign inst1_write_lo = {32{inst1_hl_src_from_mul}} & {pms_mul_res[31:0]} |
                        {32{inst1_hl_src_from_div}} & {pms_alu_div_res[63:32]} |
                        {32{~inst1_hl_src_from_div & ~inst1_hl_src_from_mul & inst1_lo_we}} & {inst1_rs_value};

assign inst2_write_hi = {32{inst2_hl_src_from_mul}} & {pms_mul_res[63:32]} |
                        {32{inst2_hl_src_from_div}} & {pms_alu_div_res[31:0]} |
                        {32{~inst2_hl_src_from_div & ~inst2_hl_src_from_mul & inst2_hi_we}} & {inst2_rs_value};

assign inst2_write_lo = {32{inst2_hl_src_from_mul}} & {pms_mul_res[31:0]} |
                        {32{inst2_hl_src_from_div}} & {pms_alu_div_res[63:32]} |
                        {32{~inst2_hl_src_from_div & ~inst2_hl_src_from_mul & inst2_lo_we}} & {inst2_rs_value};

always @(posedge clk) begin
    if(reset)
        mul_res_save_done <= 1'b0; 
    else if(pms_to_ms_valid && ms_allowin)
        mul_res_save_done <= 1'b0; 
    else if(pms_valid & ((inst1_hi_we & inst1_lo_we) | (inst2_hi_we & inst2_lo_we)) & ~inst1_pms_except)
        mul_res_save_done <= 1'b1; 
    
end

always @(posedge clk) begin
    if(reset)
        HI <= 32'b0;
    else if(inst2_valid & pms_valid & ~mul_res_save_done & inst1_hi_we & inst2_hi_we & !inst1_pms_except & !inst2_pms_except)
        HI <= inst2_write_hi;
    else if(pms_valid & ~mul_res_save_done & inst1_hi_we & inst2_hi_we & !inst1_pms_except & inst2_pms_except)
        HI <= inst1_write_hi;
    else if(pms_valid & ~mul_res_save_done & inst1_hi_we & ~inst2_hi_we & !inst1_pms_except)
        HI <= inst1_write_hi;
    else if(inst2_valid & pms_valid & ~mul_res_save_done & ~inst1_hi_we & inst2_hi_we & !(inst1_pms_except | inst1_pms_eret) & !inst2_pms_except)
        HI <= inst2_write_hi;
end

always @(posedge clk) begin
    if(reset)
        LO <= 32'b0;
    else if(inst2_valid & pms_valid & ~mul_res_save_done & inst1_lo_we & inst2_lo_we & !inst1_pms_except & !inst2_pms_except)
        LO <= inst2_write_lo;
    else if(pms_valid & ~mul_res_save_done & inst1_lo_we & inst2_lo_we & !inst1_pms_except & inst2_pms_except)
        LO <= inst1_write_lo;
    else if(pms_valid & ~mul_res_save_done & inst1_lo_we & ~inst2_lo_we & !inst1_pms_except)
        LO <= inst1_write_lo;
    else if(inst2_valid & pms_valid & ~mul_res_save_done & ~inst1_lo_we & inst2_lo_we & !(inst1_pms_except | inst1_pms_eret) & !inst2_pms_except)
        LO <= inst2_write_lo;
end

// cp0
assign inst1_c0_wdata = inst1_rt_value;
assign inst1_c0_addr = inst1_cp0_addr;
assign inst1_mtc0_we = (pms_valid & inst1_cp0_we & ~((inst1_c0_addr == `CR_EPC) & inst2_pms_except));
assign inst2_c0_wdata = inst2_rt_value;
assign inst2_c0_addr = inst2_cp0_addr;
assign inst2_mtc0_we = (inst2_valid & pms_valid & inst2_cp0_we & ~(inst1_pms_except | inst1_pms_eret));    

wire cp0_RAW;
assign cp0_RAW = (inst1_cp0_addr == inst2_cp0_addr) & inst1_cp0_we & inst2_cp0_op & (~inst1_pms_except & ~inst2_pms_except);

//signals of the exception, from pms, only one inst
assign pms_ex = inst1_pms_except | inst2_pms_except; //has exception
assign ex_type = inst1_pms_except ? inst1_pms_exccode :
                 inst2_pms_except ? inst2_pms_exccode : 5'b0;//type of exception
assign pms_bd = inst1_pms_except ? inst1_bd :
                inst2_pms_except ? inst2_bd : 1'b0; //is delay slot
assign pms_pc = inst1_pms_except ? inst1_pc :
                inst2_pms_except ? inst2_pc : 32'b0;//pc
assign pms_badvaddr = inst1_pms_except ? inst1_pms_BadVAddr :
                      inst2_pms_except ? inst2_pms_BadVAddr : 32'b0;//bad vaddr
assign pms_eret = (inst1_pms_eret | inst2_pms_eret); //is eret
assign pms_except_ce = 2'b1 & {2{(pms_ex & ((inst1_pms_exccode == 5'hb)||(inst2_pms_exccode == 5'hb)))}};

//TLB

assign is_TLBR              = inst1_pms_tlbr;
assign TLB_rdata            = {r_vpn2, r_asid, r_g, r_pfn0, r_c0,r_d0,r_v0, r_pfn1, r_c1, r_d1, r_v1};
assign is_TLBP              = inst1_pms_tlbp;
assign is_TLBWR             = inst1_pms_tlbwr;
assign index_write_p        = ~inst1_s1_found;
assign index_write_index    = inst1_s1_index;

assign we = inst1_pms_tlbwi | inst1_pms_tlbwr;
assign w_mask = c0_mask;
assign w_index = inst1_pms_tlbwr ? c0_random_random : cp0_index[3:0];
assign w_vpn2 = cp0_entryhi[31:13];
assign w_asid = cp0_entryhi[7:0];
assign w_g = cp0_entrylo0[0] & cp0_entrylo1[0];
assign w_pfn0 = cp0_entrylo0[25:6];
assign w_c0 = cp0_entrylo0[5:3];
assign w_d0 = cp0_entrylo0[2];
assign w_v0 = cp0_entrylo0[1];
assign w_pfn1 = cp0_entrylo1[25:6];
assign w_c1 = cp0_entrylo1[5:3];
assign w_d1 = cp0_entrylo1[2];
assign w_v1 = cp0_entrylo1[1];
assign r_index = cp0_index[3:0];

assign pms_mtc0_index = inst1_mtc0_we & (inst1_cp0_addr == 8'h0) |
                        inst2_mtc0_we & (inst2_cp0_addr == 8'h0) ; 

// data bus
assign pms_to_ms_bus = {
        inst2_valid,
        inst2_load_store_type,
        inst2_load_store_offset,
        inst2_load_op,
        inst2_mem_we,
        inst2_gr_we,
        inst2_dest,
        inst2_rt_value,
        pms_inst2_result,
        inst2_pc,

        inst1_load_store_type,
        inst1_load_store_offset,
        inst1_load_op,
        inst1_mem_we,
        inst1_gr_we,
        inst1_dest,
        inst1_rt_value,
        pms_inst1_result,
        inst1_pc
    };

// forward bus
wire [31:0] pms_inst1_result;
wire [31:0] pms_inst2_result;
wire [31:0] pms_inst1_cal_result;
wire [31:0] pms_inst2_cal_result;

wire [31:0] inst2_cp0_res_update;
wire [31:0] pms_inst2_cp0_final_res;

wire [31:0] reg_hi_res;
wire [31:0] reg_lo_res;

assign reg_hi_res = (inst1_hi_we & ~mul_res_save_done) ? inst1_write_hi : HI;
assign reg_lo_res = (inst1_lo_we & ~mul_res_save_done) ? inst1_write_lo : LO;

assign pms_inst1_cal_result = {32{inst1_hi_op}} & {HI} |
                              {32{inst1_lo_op}} & {LO} |
                              {32{~inst1_lo_op & ~inst1_hi_op}} & {pms_alu_inst1_result};

assign pms_inst2_cal_result = {32{inst2_hi_op}} & {reg_hi_res} |
                              {32{inst2_lo_op}} & {reg_lo_res} |
                              {32{~inst2_lo_op & ~inst2_hi_op}} & {pms_alu_inst2_result};

assign inst2_cp0_res_update = {32{(inst2_cp0_addr == `CR_EPC)}} & inst1_rt_value |
                              {32{(inst2_cp0_addr == `CR_COUNT)}} & inst1_rt_value |
                              {32{(inst2_cp0_addr == `CR_COMPARE)}} & inst1_rt_value |
                              {32{(inst2_cp0_addr == `CR_CAUSE)}} & {inst2_c0_rdata[31:10], inst1_rt_value[9:8], inst2_c0_rdata[7:0]} |
                              {32{(inst2_cp0_addr == `CR_STATUS)}} & {inst2_c0_rdata[31:16], inst1_rt_value[15:8], inst2_c0_rdata[7:2], inst1_rt_value[1:0]} |
                              {32{(inst2_cp0_addr == `CR_ENTRYHI)}} & {inst1_rt_value[31:13], inst2_c0_rdata[12:8], inst1_rt_value[7:0]} |
                              {32{(inst2_cp0_addr == `CR_INDEX)}} & {inst2_c0_rdata[31:4], inst1_rt_value[3:0]} |
                              {32{(inst2_cp0_addr == `CR_ENTRYLO0)}} & {inst2_c0_rdata[31:26],inst1_rt_value[25:0]} |
                              {32{(inst2_cp0_addr == `CR_ENTRYLO1)}} & {inst2_c0_rdata[31:26],inst1_rt_value[25:0]} ;

assign pms_inst2_cp0_final_res = cp0_RAW ? inst2_cp0_res_update : inst2_c0_rdata;

assign pms_inst1_result = inst1_cp0_op ? inst1_c0_rdata : 
                             inst1_mul ? lo32_for_mul : pms_inst1_cal_result;
assign pms_inst2_result = inst2_cp0_op ? pms_inst2_cp0_final_res : 
                             inst2_mul ? lo32_for_mul : pms_inst2_cal_result;

assign pms_forward_bus = {
    pms_valid,
    inst1_load_op, inst1_gr_we, inst1_dest, pms_inst1_result,
    inst2_load_op, inst2_gr_we & inst2_valid, inst2_dest, pms_inst2_result
};
// assign {pms_valid, 
//         pms_inst1_load, pms_inst1_gr_we, pms_inst1_dest, pms_inst1_result, 
//         pms_inst2_load, pms_inst2_gr_we, pms_inst2_dest, pms_inst2_result } = pms_forward_bus;
endmodule