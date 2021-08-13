`include "mycpu.h"

module mem_stage(
    input                           clk            ,
    input                           reset          ,
    //allowin
    output                          ms_allowin     ,
    //from pms
    input                           pms_to_ms_valid,
    input  [`PMS_TO_MS_BUS_WD -1:0] pms_to_ms_bus  ,

    //to rf: for write back
    output [`WS_TO_RF_BUS_WD -1:0]   ms_to_rf_bus  ,

    //data relevant
    output [`MS_FORWARD_BUS_WD -1:0] ms_forward_bus,

    //from data-sram
    input         data_cache_data_ok_01,
    input  [31:0] data_cache_rdata_01,
    input         data_cache_data_ok_02,
    input  [31:0] data_cache_rdata_02,

    //trace debug interface
    output [31:0] debug_wb_pc     ,
    output [ 3:0] debug_wb_rf_wen ,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
);

reg         ms_valid;
wire        ms_ready_go;

reg  [`PMS_TO_MS_BUS_WD -1:0] pms_to_ms_bus_r;

wire [ 6:0] inst1_load_store_type;
wire [ 1:0] inst1_load_store_offset;
wire        inst1_res_from_mem;
wire        inst1_mem_we;
wire        inst1_gr_we;
wire [ 4:0] inst1_dest;
wire [31:0] inst1_rt_value;
wire [31:0] inst1_alu_result;
wire [31:0] inst1_pc;

wire        inst2_valid;
wire [ 6:0] inst2_load_store_type;
wire [ 1:0] inst2_load_store_offset;
wire        inst2_res_from_mem;
wire        inst2_mem_we;
wire        inst2_gr_we;
wire [ 4:0] inst2_dest;
wire [31:0] inst2_rt_value;
wire [31:0] inst2_alu_result;
wire [31:0] inst2_pc;

assign {inst2_valid,
        inst2_load_store_type,
        inst2_load_store_offset,
        inst2_res_from_mem,
        inst2_mem_we,
        inst2_gr_we,
        inst2_dest,
        inst2_rt_value,
        inst2_alu_result,
        inst2_pc,

        inst1_load_store_type,
        inst1_load_store_offset,
        inst1_res_from_mem,
        inst1_mem_we,
        inst1_gr_we,
        inst1_dest,
        inst1_rt_value,
        inst1_alu_result,
        inst1_pc
        } = pms_to_ms_bus_r;

wire [31:0] inst1_mem_result;
wire [31:0] inst1_final_result;
wire [31:0] inst2_mem_result;
wire [31:0] inst2_final_result;

wire        inst1_ready_go;
wire        inst2_ready_go;

assign ms_ready_go    = inst1_ready_go & inst2_ready_go;
assign ms_allowin     = !ms_valid || ms_ready_go;

always @(posedge clk) begin
    if (reset) begin
        ms_valid <= 1'b0;
    end
    else if (ms_allowin) begin
        ms_valid <= pms_to_ms_valid;
    end

    if (pms_to_ms_valid && ms_allowin) begin
        pms_to_ms_bus_r  <= pms_to_ms_bus;
    end
end

// inst 1
wire inst1_align_off_0;
wire inst1_align_off_1;
wire inst1_align_off_2;
wire inst1_align_off_3;

assign inst1_align_off_0 = ~inst1_load_store_offset[1] & ~inst1_load_store_offset[0];
assign inst1_align_off_1 = ~inst1_load_store_offset[1] &  inst1_load_store_offset[0];
assign inst1_align_off_2 =  inst1_load_store_offset[1] & ~inst1_load_store_offset[0];
assign inst1_align_off_3 =  inst1_load_store_offset[1] &  inst1_load_store_offset[0];

wire inst1_lb_mem_res;
wire inst1_lbu_mem_res;
wire inst1_lh_mem_res;
wire inst1_lhu_mem_res;
wire inst1_lw_mem_res;
wire inst1_lwl_mem_res;
wire inst1_lwr_mem_res;

assign {inst1_lb_mem_res  ,  //6
        inst1_lbu_mem_res ,  //5
        inst1_lh_mem_res  ,  //4
        inst1_lhu_mem_res ,  //3
        inst1_lw_mem_res  ,  //2
        inst1_lwl_mem_res ,  //1
        inst1_lwr_mem_res    //0
        } = inst1_load_store_type;

//reg [31:0] inst1_mem_result_reg;
reg        inst1_mem_ok;

assign inst1_mem_result = {32{inst1_lb_mem_res  & inst1_align_off_0}} & { {24{data_cache_rdata_01[ 7]}}, data_cache_rdata_01[ 7: 0] } |  //lb
                          {32{inst1_lb_mem_res  & inst1_align_off_1}} & { {24{data_cache_rdata_01[15]}}, data_cache_rdata_01[15: 8] } |
                          {32{inst1_lb_mem_res  & inst1_align_off_2}} & { {24{data_cache_rdata_01[23]}}, data_cache_rdata_01[23:16] } |
                          {32{inst1_lb_mem_res  & inst1_align_off_3}} & { {24{data_cache_rdata_01[31]}}, data_cache_rdata_01[31:24] } |
                          {32{inst1_lbu_mem_res & inst1_align_off_0}} & { 24'b0, data_cache_rdata_01[ 7: 0] } |                      //lbu
                          {32{inst1_lbu_mem_res & inst1_align_off_1}} & { 24'b0, data_cache_rdata_01[15: 8] } |
                          {32{inst1_lbu_mem_res & inst1_align_off_2}} & { 24'b0, data_cache_rdata_01[23:16] } |
                          {32{inst1_lbu_mem_res & inst1_align_off_3}} & { 24'b0, data_cache_rdata_01[31:24] } |
                          {32{inst1_lh_mem_res  & (inst1_align_off_0 | inst1_align_off_1)}} & { {16{data_cache_rdata_01[15]}}, data_cache_rdata_01[15: 0] } |   //lh
                          {32{inst1_lh_mem_res  & (inst1_align_off_2 | inst1_align_off_3)}} & { {16{data_cache_rdata_01[31]}}, data_cache_rdata_01[31:16] } |
                          {32{inst1_lhu_mem_res & (inst1_align_off_0 | inst1_align_off_1)}} & { 16'b0, data_cache_rdata_01[15: 0] } |                       //lhu
                          {32{inst1_lhu_mem_res & (inst1_align_off_2 | inst1_align_off_3)}} & { 16'b0, data_cache_rdata_01[31:16] } |      
                          {32{inst1_lw_mem_res}} & data_cache_rdata_01 |                                                                                //lw
                          {32{inst1_lwl_mem_res & inst1_align_off_0}} & { data_cache_rdata_01[ 7: 0], inst1_rt_value[23: 0] } |                              //lwl
                          {32{inst1_lwl_mem_res & inst1_align_off_1}} & { data_cache_rdata_01[15: 0], inst1_rt_value[15: 0] } |
                          {32{inst1_lwl_mem_res & inst1_align_off_2}} & { data_cache_rdata_01[23: 0], inst1_rt_value[ 7: 0] } |
                          {32{inst1_lwl_mem_res & inst1_align_off_3}} & data_cache_rdata_01 |
                          {32{inst1_lwr_mem_res & inst1_align_off_0}} & data_cache_rdata_01 |                                                             //lwr
                          {32{inst1_lwr_mem_res & inst1_align_off_1}} & { inst1_rt_value[31:24], data_cache_rdata_01[31: 8] } |
                          {32{inst1_lwr_mem_res & inst1_align_off_2}} & { inst1_rt_value[31:16], data_cache_rdata_01[31:16] } |
                          {32{inst1_lwr_mem_res & inst1_align_off_3}} & { inst1_rt_value[31: 8], data_cache_rdata_01[31:24] };

always @(posedge clk) begin
    if (reset) begin
        inst1_mem_ok <= 1'b0;
    end
    else if (pms_to_ms_valid && ms_allowin) begin
        inst1_mem_ok <= 1'b0;
    end
    else if (data_cache_data_ok_01 & ~ms_ready_go) begin
        inst1_mem_ok <= 1'b1;
    end

    /*if (inst1_res_from_mem & data_cache_data_ok_01 & (~ms_ready_go | ~ws_allowin)) begin
        inst1_mem_result_reg  <= inst1_mem_result;
    end*/
end

assign inst1_final_result = {32{inst1_res_from_mem}} & inst1_mem_result | {32{~inst1_res_from_mem}} & inst1_alu_result;

assign inst1_ready_go = ~(inst1_res_from_mem | inst1_mem_we) | data_cache_data_ok_01 | inst1_mem_ok;

// inst 2
wire inst2_align_off_0;
wire inst2_align_off_1;
wire inst2_align_off_2;
wire inst2_align_off_3;

assign inst2_align_off_0 = ~inst2_load_store_offset[1] & ~inst2_load_store_offset[0];
assign inst2_align_off_1 = ~inst2_load_store_offset[1] &  inst2_load_store_offset[0];
assign inst2_align_off_2 =  inst2_load_store_offset[1] & ~inst2_load_store_offset[0];
assign inst2_align_off_3 =  inst2_load_store_offset[1] &  inst2_load_store_offset[0];

wire inst2_lb_mem_res;
wire inst2_lbu_mem_res;
wire inst2_lh_mem_res;
wire inst2_lhu_mem_res;
wire inst2_lw_mem_res;
wire inst2_lwl_mem_res;
wire inst2_lwr_mem_res;

assign {inst2_lb_mem_res  ,  //6
        inst2_lbu_mem_res ,  //5
        inst2_lh_mem_res  ,  //4
        inst2_lhu_mem_res ,  //3
        inst2_lw_mem_res  ,  //2
        inst2_lwl_mem_res ,  //1
        inst2_lwr_mem_res    //0
        } = inst2_load_store_type;

//reg [31:0] inst2_mem_result_reg;
reg        inst2_mem_ok;

assign inst2_mem_result = {32{inst2_lb_mem_res  & inst2_align_off_0}} & { {24{data_cache_rdata_02[ 7]}}, data_cache_rdata_02[ 7: 0] } |  //lb
                          {32{inst2_lb_mem_res  & inst2_align_off_1}} & { {24{data_cache_rdata_02[15]}}, data_cache_rdata_02[15: 8] } |
                          {32{inst2_lb_mem_res  & inst2_align_off_2}} & { {24{data_cache_rdata_02[23]}}, data_cache_rdata_02[23:16] } |
                          {32{inst2_lb_mem_res  & inst2_align_off_3}} & { {24{data_cache_rdata_02[31]}}, data_cache_rdata_02[31:24] } |
                          {32{inst2_lbu_mem_res & inst2_align_off_0}} & { 24'b0, data_cache_rdata_02[ 7: 0] } |                      //lbu
                          {32{inst2_lbu_mem_res & inst2_align_off_1}} & { 24'b0, data_cache_rdata_02[15: 8] } |
                          {32{inst2_lbu_mem_res & inst2_align_off_2}} & { 24'b0, data_cache_rdata_02[23:16] } |
                          {32{inst2_lbu_mem_res & inst2_align_off_3}} & { 24'b0, data_cache_rdata_02[31:24] } |
                          {32{inst2_lh_mem_res  & (inst2_align_off_0 | inst2_align_off_1)}} & { {16{data_cache_rdata_02[15]}}, data_cache_rdata_02[15: 0] } |   //lh
                          {32{inst2_lh_mem_res  & (inst2_align_off_2 | inst2_align_off_3)}} & { {16{data_cache_rdata_02[31]}}, data_cache_rdata_02[31:16] } |
                          {32{inst2_lhu_mem_res & (inst2_align_off_0 | inst2_align_off_1)}} & { 16'b0, data_cache_rdata_02[15: 0] } |                       //lhu
                          {32{inst2_lhu_mem_res & (inst2_align_off_2 | inst2_align_off_3)}} & { 16'b0, data_cache_rdata_02[31:16] } |      
                          {32{inst2_lw_mem_res}} & data_cache_rdata_02 |                                                                                //lw
                          {32{inst2_lwl_mem_res & inst2_align_off_0}} & { data_cache_rdata_02[ 7: 0], inst2_rt_value[23: 0] } |                              //lwl
                          {32{inst2_lwl_mem_res & inst2_align_off_1}} & { data_cache_rdata_02[15: 0], inst2_rt_value[15: 0] } |
                          {32{inst2_lwl_mem_res & inst2_align_off_2}} & { data_cache_rdata_02[23: 0], inst2_rt_value[ 7: 0] } |
                          {32{inst2_lwl_mem_res & inst2_align_off_3}} & data_cache_rdata_02 |
                          {32{inst2_lwr_mem_res & inst2_align_off_0}} & data_cache_rdata_02 |                                                             //lwr
                          {32{inst2_lwr_mem_res & inst2_align_off_1}} & { inst2_rt_value[31:24], data_cache_rdata_02[31: 8] } |
                          {32{inst2_lwr_mem_res & inst2_align_off_2}} & { inst2_rt_value[31:16], data_cache_rdata_02[31:16] } |
                          {32{inst2_lwr_mem_res & inst2_align_off_3}} & { inst2_rt_value[31: 8], data_cache_rdata_02[31:24] };

always @(posedge clk) begin
    if (reset) begin
        inst2_mem_ok <= 1'b0;
    end
    else if (pms_to_ms_valid && ms_allowin) begin
        inst2_mem_ok <= 1'b0;
    end
    else if (data_cache_data_ok_02 & ~ms_ready_go) begin
        inst2_mem_ok <= 1'b1;
    end

    /*if (inst2_res_from_mem & data_cache_data_ok_02 & (~ms_ready_go | ~ws_allowin)) begin
        inst2_mem_result_reg  <= inst2_mem_result;
    end*/
end

assign inst2_final_result = {32{inst2_res_from_mem}} & inst2_mem_result | {32{~inst2_res_from_mem}} & inst2_alu_result;

assign inst2_ready_go = ~(inst2_res_from_mem | inst2_mem_we) | data_cache_data_ok_02 | inst2_mem_ok | ~inst2_valid;

// regfile
wire        rf_we_01;
wire [ 4:0] rf_waddr_01;
wire [31:0] rf_wdata_01;
wire        rf_we_02;
wire [ 4:0] rf_waddr_02;
wire [31:0] rf_wdata_02;

wire        inst1_write;
wire        inst2_write;
wire        double_write;
wire        write_same_reg;

assign ms_to_rf_bus = {rf_we_02, rf_waddr_02, rf_wdata_02, 
                       rf_we_01, rf_waddr_01, rf_wdata_01 };

assign inst1_write = ms_valid & inst1_gr_we;
assign inst2_write = ms_valid & inst2_gr_we & inst2_valid;

assign rf_we_01    = inst1_write;
assign rf_waddr_01 = inst1_dest;
assign rf_wdata_01 = inst1_final_result;
assign rf_we_02    = inst2_write;
assign rf_waddr_02 = inst2_dest;
assign rf_wdata_02 = inst2_final_result;

assign debug_wb_pc       = inst1_pc;
assign debug_wb_rf_wen   = {4{inst1_write}};
assign debug_wb_rf_wnum  = inst1_dest;
assign debug_wb_rf_wdata = inst1_final_result;


// ms_forward_bus
assign ms_forward_bus = {ms_valid, //ms_to_ws_valid, 
                         inst1_ready_go, inst1_res_from_mem, inst1_gr_we, inst1_dest, inst1_final_result, 
                         inst2_ready_go, inst2_res_from_mem, inst2_gr_we, inst2_dest, inst2_final_result };

endmodule
