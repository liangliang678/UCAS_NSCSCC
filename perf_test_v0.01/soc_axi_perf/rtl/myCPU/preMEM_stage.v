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
    input [63:0]                   pms_inst1_mul_res,
    input [63:0]                   pms_inst2_mul_res,
    //to ms
    output                           pms_to_ms_valid,
    output  [`PMS_TO_MS_BUS_WD -1:0] pms_to_ms_bus  ,

    //relevant bus
    output [`PMS_FORWARD_BUS_WD -1:0] pms_forward_bus,
    //clear stage
    output         clear_all                      ,
    output [31:0]  reflush_pc                     ,

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

    //output to pms
    input [31:0] inst1_c0_rdata    ,
    input [31:0] inst2_c0_rdata    ,
    input        has_int           ,
    input [31:0] pms_epc          

);

// preMEM 
reg         pms_valid;
wire        pms_ready_go;

reg [`ES_TO_PMS_BUS_WD -1:0] es_to_pms_bus_r;

wire        inst1_ready_go; //TODO
wire        inst2_ready_go;

assign pms_ready_go    = (inst1_ready_go & inst2_ready_go) | clear_all;
assign pms_allowin     = !pms_valid || pms_ready_go && ms_allowin;
assign pms_to_ms_valid = pms_valid && pms_ready_go && (~inst1_pms_except);

always @(posedge clk) begin
    if (reset) begin
        pms_valid <= 1'b0;
    end
    else if (pms_allowin) begin
        pms_valid <= es_to_pms_valid;
    end
    else if(inst1_pms_except)
        pms_valid <= 1'b0;    

    if (es_to_pms_valid && pms_allowin) begin
        es_to_pms_bus_r  <= es_to_pms_bus;
    end
end

assign inst1_ready_go = ~(inst1_load_op | inst1_mem_we) | (inst1_load_op | inst1_mem_we) & (inst1_data_cache_addr_ok | inst1_addr_ok_reg) | inst1_pms_except; //不访存 访存请求接受 有例外
assign inst2_ready_go = ~(inst2_load_op | inst2_mem_we) | (inst2_load_op | inst2_mem_we) & (inst2_data_cache_addr_ok | inst2_addr_ok_reg) | inst2_pms_except;

wire        inst1_refill;
wire [31:0] inst1_pc;
wire        inst1_pms_except;
wire [ 4:0] inst1_pms_exccode;
wire [31:0] inst1_pms_BadVAddr;
wire        inst1_pms_tlbp;
wire        inst1_pms_tlbr;
wire        inst1_pms_tlbwi;
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

wire        inst2_refill;
wire        inst2_valid;
wire [31:0] inst2_pc;
wire        inst2_pms_except;
wire [ 4:0] inst2_pms_exccode;
wire [31:0] inst2_pms_BadVAddr;
wire        inst2_pms_tlbp;
wire        inst2_pms_tlbr;
wire        inst2_pms_tlbwi;
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

wire        inst1_es_except;
wire [4:0]  inst1_es_exccode;
wire [31:0] inst1_es_BadVAddr;
wire        inst2_es_except;
wire [4:0]  inst2_es_exccode;
wire [31:0] inst2_es_BadVAddr;

assign {
        inst2_valid,
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
        pms_alu_inst2_div_res,
        inst2_gr_we,
        inst2_mem_we,
        inst2_dest,
        inst2_rs_value,
        inst2_rt_value,
        inst2_pc,
        pms_inst2_mem_addr,

        br_target,

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
        pms_alu_inst1_div_res,
        inst1_gr_we,
        inst1_mem_we,
        inst1_dest,
        inst1_rs_value,
        inst1_rt_value,
        inst1_pc,
        pms_inst1_mem_addr       
       } = es_to_pms_bus_r;

// exception
wire pms_inst2_valid;
assign pms_inst2_valid = inst2_valid & ~(inst1_pms_except | inst2_pms_except | inst1_pms_eret);

wire inst1_exception_adel, inst1_exception_ades;
wire inst2_exception_adel, inst2_exception_ades;
//TLB EXCEPTION IS NOT ADD HERE !!
assign inst1_exception_adel  = inst1_load_op && (inst1_sh_mem_res  && ~(pms_inst1_mem_addr[0] == 0) ||
                                                inst1_shu_mem_res && ~(pms_inst1_mem_addr[0] == 0) ||
                                                inst1_sw_mem_res  && ~(pms_inst1_mem_addr[1:0] == 0));

assign inst1_exception_ades  = inst1_mem_we  && (inst1_sh_mem_res  && ~(pms_inst1_mem_addr[0] == 0) ||
                                                inst1_shu_mem_res && ~(pms_inst1_mem_addr[0] == 0) ||
                                                inst1_sw_mem_res  && ~(pms_inst1_mem_addr[1:0] == 0));

assign inst2_exception_adel  = inst2_load_op && (inst2_sh_mem_res  && ~(pms_inst2_mem_addr[0] == 0) ||
                                                inst2_shu_mem_res && ~(pms_inst2_mem_addr[0] == 0) ||
                                                inst2_sw_mem_res  && ~(pms_inst2_mem_addr[1:0] == 0));

assign inst2_exception_ades  = inst2_mem_we  && (inst2_sh_mem_res  && ~(pms_inst2_mem_addr[0] == 0) ||
                                                inst2_shu_mem_res && ~(pms_inst2_mem_addr[0] == 0) ||
                                                inst2_sw_mem_res  && ~(pms_inst2_mem_addr[1:0] == 0));

assign inst1_pms_except = inst1_es_except | (inst1_exception_adel | inst1_exception_ades);
assign inst2_pms_except = inst2_es_except | (inst2_exception_adel | inst2_exception_ades);

assign inst1_pms_exccode = inst1_es_except ? inst1_es_exccode : 
                           inst1_exception_adel ? 5'h4 :
                           inst1_exception_ades ? 5'h5 : 5'h0;

assign inst2_pms_exccode = inst2_es_except ? inst2_es_exccode : 
                           inst2_exception_adel ? 5'h4 :
                           inst2_exception_ades ? 5'h5 : 5'h0;

assign inst1_pms_BadVAddr = inst1_es_except ? inst1_es_BadVAddr : inst1_VA;
assign inst2_pms_BadVAddr = inst2_es_except ? inst2_es_BadVAddr : inst2_VA;

wire [31:0] exception_1_refush_pc;
wire [31:0] exception_2_refush_pc;
assign exception_1_refush_pc = inst1_refill ? 32'hbfc00200 :
                               inst1_pms_except ? 32'hbfc00380 :
                               inst1_pms_eret ? pms_epc :
                               br_target;

assign exception_2_refush_pc = inst2_refill ? 32'hbfc00200 :
                               inst2_pms_except ? 32'hbfc00380 :
                               inst2_pms_eret ? pms_epc :
                               br_target;

assign reflush_pc = {32{inst1_pms_except | inst1_pms_eret}} & {exception_1_refush_pc} |
                    {32{inst2_pms_except | inst2_pms_eret}} & {exception_2_refush_pc} ;

assign clear_all = (inst2_pms_except | inst1_pms_except | inst1_pms_eret | inst2_pms_eret) & pms_valid;

// hi lo
reg [31:0] HI;
reg [31:0] LO;

wire [31:0] inst1_write_hi;
wire [31:0] inst1_write_lo;
wire [31:0] inst2_write_hi;
wire [31:0] inst2_write_lo;

assign inst1_write_hi = {32{inst1_hl_src_from_mul}} & {pms_inst1_mul_res[63:32]} |
                        {32{inst1_hl_src_from_div}} & {pms_alu_inst1_div_res[31:0]} |
                        {32{~inst1_hl_src_from_div & ~inst1_hl_src_from_mul & inst1_hi_we}} & {inst1_rs_value};

assign inst1_write_lo = {32{inst1_hl_src_from_mul}} & {pms_inst1_mul_res[31:0]} |
                        {32{inst1_hl_src_from_div}} & {pms_alu_inst1_div_res[63:32]} |
                        {32{~inst1_hl_src_from_div & ~inst1_hl_src_from_mul & inst1_lo_we}} & {inst1_rs_value};

assign inst2_write_hi = {32{inst2_hl_src_from_mul}} & {pms_inst2_mul_res[63:32]} |
                        {32{inst2_hl_src_from_div}} & {pms_alu_inst2_div_res[31:0]} |
                        {32{~inst2_hl_src_from_div & ~inst2_hl_src_from_mul & inst2_hi_we}} & {inst2_rs_value};

assign inst2_write_lo = {32{inst2_hl_src_from_mul}} & {pms_inst2_mul_res[31:0]} |
                        {32{inst2_hl_src_from_div}} & {pms_alu_inst2_div_res[63:32]} |
                        {32{~inst2_hl_src_from_div & ~inst2_hl_src_from_mul & inst2_lo_we}} & {inst2_rs_value};

always @(posedge clk) begin
    if(reset)
        HI <= 32'b0;
    else if(inst1_hi_we & inst2_hi_we & !inst1_pms_except & !inst2_pms_except)
        HI <= inst2_write_hi;
    else if(inst1_hi_we & inst2_hi_we & !inst1_pms_except & inst2_pms_except)
        HI <= inst1_write_hi;
    else if(inst1_hi_we & ~inst2_hi_we & !inst1_pms_except)
        HI <= inst1_write_hi;
    else if(~inst1_hi_we & inst2_hi_we & !(inst1_pms_except | inst1_pms_eret) & !inst2_pms_except)
        HI <= inst2_write_hi;
end

always @(posedge clk) begin
    if(reset)
        LO <= 32'b0;
    else if(inst1_lo_we & inst2_lo_we & !inst1_pms_except & !inst2_pms_except)
        LO <= inst2_write_lo;
    else if(inst1_lo_we & inst2_lo_we & !inst1_pms_except & inst2_pms_except)
        LO <= inst1_write_lo;
    else if(inst1_lo_we & ~inst2_lo_we & !inst1_pms_except)
        LO <= inst1_write_lo;
    else if(~inst1_lo_we & inst2_lo_we & !(inst1_pms_except | inst1_pms_eret) & !inst2_pms_except)
        LO <= inst2_write_lo;
end

// cp0
assign inst1_c0_wdata = inst1_rt_value;
assign inst1_c0_addr = inst1_cp0_addr;
assign inst1_mtc0_we = (inst1_cp0_we & ~((inst1_c0_addr == `CR_EPC) & inst2_pms_except));
assign inst2_c0_wdata = inst2_rt_value;
assign inst2_c0_addr = inst2_cp0_addr;
assign inst2_mtc0_we = (inst2_cp0_we & ~(inst1_pms_except | inst1_pms_eret));    

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

// mem
assign inst2_load_store_offset = pms_inst2_mem_addr[1:0];
assign inst1_load_store_offset = pms_inst1_mem_addr[1:0];

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

assign inst2_data_cache_wdata = {32{inst2_sb_mem_res}} & {4{inst2_rt_value[ 7:0]}} |
                                {32{inst2_sh_mem_res}} & {2{inst2_rt_value[15:0]}} |
                                {32{inst2_sw_mem_res}} & {inst2_rt_value} |
                                {32{inst2_swl_mem_res & inst2_mem_align_off_0}} & {24'b0, inst2_rt_value[31:24]} |
                                {32{inst2_swl_mem_res & inst2_mem_align_off_1}} & {16'b0, inst2_rt_value[31:16]} |
                                {32{inst2_swl_mem_res & inst2_mem_align_off_2}} & { 8'b0, inst2_rt_value[31: 8]} |
                                {32{inst2_swl_mem_res & inst2_mem_align_off_3}} & inst2_rt_value |
                                {32{inst2_swr_mem_res & inst2_mem_align_off_0}} & inst2_rt_value |
                                {32{inst2_swr_mem_res & inst2_mem_align_off_1}} & {inst2_rt_value[23: 0], 8'b0} |
                                {32{inst2_swr_mem_res & inst2_mem_align_off_2}} & {inst2_rt_value[15: 0],16'b0} |
                                {32{inst2_swr_mem_res & inst2_mem_align_off_3}} & {inst2_rt_value[ 7: 0],24'b0} ;

wire [31:0] inst1_data_addr;
wire [31:0] inst2_data_addr;
wire [31:0] inst1_VA;
wire [31:0] inst2_VA;

reg inst1_addr_ok_reg;
reg inst2_addr_ok_reg;

always@(posedge clk) begin
    if(reset) begin
        inst1_addr_ok_reg <= 1'b0;
    end
    else if(pms_to_ms_valid && ms_allowin)
        inst1_addr_ok_reg <= 1'b0;
    else if(inst1_data_cache_addr_ok)
        inst1_addr_ok_reg <= 1'b1;
end

always@(posedge clk) begin
    if(reset) begin
        inst2_addr_ok_reg <= 1'b0;
    end
    else if(pms_to_ms_valid && ms_allowin)
        inst2_addr_ok_reg <= 1'b0;
    else if(inst2_data_cache_addr_ok)
        inst2_addr_ok_reg <= 1'b1;
end

assign inst1_VA = inst1_swl_mem_res ? {pms_inst1_mem_addr[31:2], 2'b0} : pms_inst1_mem_addr;
assign inst2_VA = inst2_swl_mem_res ? {pms_inst2_mem_addr[31:2], 2'b0} : pms_inst2_mem_addr;
assign inst1_data_addr = {3'b0, inst1_VA[28:0]};
assign inst2_data_addr = {3'b0, inst2_VA[28:0]};


assign inst1_data_cache_valid = (inst1_load_op | inst1_mem_we) & ms_allowin & pms_valid & ~inst1_pms_except & ~inst1_addr_ok_reg;
assign inst1_data_cache_op = inst1_mem_we & pms_valid & ~inst1_pms_except;
assign inst1_data_cache_uncache = inst1_VA[31] && ~inst1_VA[30] && inst1_VA[29];
assign inst1_data_cache_tag = inst1_data_addr[31:12];
assign inst1_data_cache_index = inst1_data_addr[11:4];
assign inst1_data_cache_offset = inst1_data_addr[3:0];
assign inst1_data_cache_wstrb = (inst1_mem_we & pms_valid & ~inst1_pms_except) ? inst1_write_strb : 4'h0;

wire mem_RAW;
assign mem_RAW = (inst1_VA[31:2] == inst2_VA[31:2]) & inst1_mem_we & inst2_load_op & ~inst1_pms_except & ~inst2_pms_except;

assign inst2_data_cache_valid = (inst2_load_op | inst2_mem_we) & ms_allowin & pms_valid & ~(inst1_pms_except | inst1_pms_eret) & ~inst2_pms_except & ~inst2_addr_ok_reg;
assign inst2_data_cache_op = inst2_mem_we & pms_valid & ~inst1_pms_except & ~inst2_pms_except;
assign inst2_data_cache_uncache = inst2_VA[31] && ~inst2_VA[30] && inst2_VA[29];
assign inst2_data_cache_tag = inst2_data_addr[31:12];
assign inst2_data_cache_index = inst2_data_addr[11:4];
assign inst2_data_cache_offset = inst2_data_addr[3:0];
assign inst2_data_cache_wstrb = (inst2_mem_we & pms_valid & ~inst1_pms_except & ~inst2_pms_except) ? inst2_write_strb : 4'h0;


// data bus
assign pms_to_ms_bus = {
        pms_inst2_valid,
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

assign reg_hi_res = inst1_hi_we ? inst1_write_hi : HI;
assign reg_lo_res = inst1_lo_we ? inst1_write_lo : LO;

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

assign pms_inst1_result = inst1_cp0_op ? inst1_c0_rdata : pms_inst1_cal_result;
assign pms_inst2_result = inst2_cp0_op ? pms_inst2_cp0_final_res : pms_inst2_cal_result;

assign pms_forward_bus = {
    pms_valid,
    inst1_load_op, inst1_gr_we, inst1_dest, pms_inst1_result,
    inst2_load_op, inst2_gr_we, inst2_dest, pms_inst2_result
};
// assign {pms_valid, 
//         pms_inst1_load, pms_inst1_gr_we, pms_inst1_dest, pms_inst1_result, 
//         pms_inst2_load, pms_inst2_gr_we, pms_inst2_dest, pms_inst2_result } = pms_forward_bus;
endmodule