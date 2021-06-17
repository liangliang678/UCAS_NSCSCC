`include "mycpu.h"

module mem_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          ws_allowin    ,
    output                         ms_allowin    ,
    //from es
    input                          es_to_ms_valid,
    input  [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    //multiper res
    input  [63                 :0] mul_res    ,                 
    //to ws
    output                         ms_to_ws_valid,
    output [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus  ,
    //from data-sram

    input         data_cache_data_ok,
    input  [31:0] data_cache_rdata,  

    //data relevant
    output [`STALL_MS_BUS_WD -1:0] stall_ms_bus,

    //clear stage
    input         ms_ex,
    output        ms_has_reflush_to_es,
    output        mem_mtc0_index,
    input         ms_cancel_in,
    input         ms_eret_in
);

reg  [31:0] HI;
reg  [31:0] LO;

reg         ms_valid;
wire        ms_ready_go;

reg  [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus_r;
wire [ 3:0] ms_s1_index   ;
wire        ms_s1_found   ;
wire        ms_tlbp       ;
wire        ms_tlbr       ;
wire        ms_tlbwi      ;
wire        ms_mem_we     ;
wire        ms_eret       ;
wire [31:0] ms_badvaddr   ;
wire        ms_bd         ;
wire        es_has_exception;
wire [ 4:0] es_exception_type;
wire        ms_cp0_op     ;
wire        ms_cp0_we     ;
wire [ 7:0] ms_cp0_addr   ;
wire [ 6:0] ms_load_store_type;
wire [ 1:0] ms_load_store_offset;
wire [31:0] ms_rs_value;
wire [31:0] ms_rt_value;
wire        ms_hi_we;
wire        ms_lo_we;
wire        ms_hl_src_from_mul;
wire        ms_hl_src_from_div;
wire [63:0] ms_alu_div_res;
wire        ms_res_from_hi;
wire        ms_res_from_lo;
wire        ms_res_from_mem;
wire        ms_gr_we;
wire [ 4:0] ms_dest;
wire        ms_res_from_wb;
wire [31:0] ms_alu_result;
wire [31:0] ms_pc;
wire        exception_is_tlb_refill;
assign {exception_is_tlb_refill, //273:273
        ms_s1_index           ,  //272:269
        ms_s1_found           ,  //268:268
        ms_tlbp               ,  //267:267
        ms_tlbr               ,  //266:266
        ms_tlbwi              ,  //265:265
        ms_mem_we             ,  //264:264
        ms_eret               ,  //263:263
        ms_badvaddr           ,  //262:231
        ms_bd                 ,  //230:230
        es_has_exception      ,  //229:229
        es_exception_type     ,  //228:224
        ms_cp0_op             ,  //223:223
        ms_cp0_we             ,  //222:222
        ms_cp0_addr           ,  //221:214
        ms_load_store_type    ,  //213:207
        ms_load_store_offset  ,  //206:205
        ms_rt_value           ,  //204:173
        ms_rs_value           ,  //172:141
        ms_hi_we              ,  //140:140
        ms_lo_we              ,  //139:139
        ms_hl_src_from_mul    ,  //138:138
        ms_hl_src_from_div    ,  //137:137
        ms_alu_div_res        ,  //136:73
        ms_res_from_mem       ,  //72:72
        ms_res_from_hi        ,  //71:71
        ms_res_from_lo        ,  //70:70
        ms_gr_we              ,  //69:69
        ms_dest               ,  //68:64
        ms_alu_result         ,  //63:32
        ms_pc                    //31:0
        } = es_to_ms_bus_r;
assign ms_res_from_wb = ms_cp0_op;

wire [31:0] mem_result;
wire [31:0] ms_final_result;

wire        ms_has_exception;
wire [ 4:0] ms_exception_type;

assign ms_to_ws_bus = {exception_is_tlb_refill,//130:130
                       ms_s1_index         ,  //129:126
                       ms_s1_found         ,  //125:125
                       ms_tlbp             ,  //124:124
                       ms_tlbr             ,  //123:123
                       ms_tlbwi            ,  //122:122
                       ms_eret             ,  //121:121
                       ms_badvaddr         ,  //120:89
                       ms_bd               ,  //88:88
                       ms_has_exception    ,  //87:87
                       ms_exception_type   ,  //86:82
                       ms_cp0_op           ,  //81:81
                       ms_cp0_we           ,  //80:80
                       ms_cp0_addr         ,  //79:72
                       ms_load_store_offset,  //71:70
                       ms_gr_we            ,  //69:69
                       ms_dest             ,  //68:64
                       ms_final_result     ,  //63:32
                       ms_pc                  //31:0
                      };

assign ms_ready_go    = (~(ms_res_from_mem | ms_mem_we)) | data_cache_data_ok | ms_has_exception;//1'b1;
assign ms_allowin     = !ms_valid || ms_ready_go && ws_allowin;
assign ms_to_ws_valid = ms_valid && ms_ready_go;

wire ms_disable;
assign ms_disable = ms_ex || ms_cancel_in || ms_eret_in || ms_has_exception || ms_tlbr || ms_tlbwi;

always @(posedge clk) begin
    if (reset) begin
        ms_valid <= 1'b0;
    end
    else if (ms_ex || ms_cancel_in || ms_eret_in)
        ms_valid <= 1'b0;
    else if (ms_allowin) begin
        ms_valid <= es_to_ms_valid;
    end

    if (es_to_ms_valid && ms_allowin) begin
        es_to_ms_bus_r  <= es_to_ms_bus;
    end
end


wire mem_align_off_0;
wire mem_align_off_1;
wire mem_align_off_2;
wire mem_align_off_3;

assign mem_align_off_0 = (ms_load_store_offset == 2'b00);
assign mem_align_off_1 = (ms_load_store_offset == 2'b01);
assign mem_align_off_2 = (ms_load_store_offset == 2'b10);
assign mem_align_off_3 = (ms_load_store_offset == 2'b11);

wire lb_mem_res;
wire lbu_mem_res;
wire lh_mem_res;
wire lhu_mem_res;
wire lw_mem_res;
wire lwl_mem_res;
wire lwr_mem_res;

assign {
        lb_mem_res  ,  //6
        lbu_mem_res ,  //5
        lh_mem_res  ,  //4
        lhu_mem_res ,  //3
        lw_mem_res  ,  //2
        lwl_mem_res ,  //1
        lwr_mem_res    //0
        } = ms_load_store_type;

assign mem_result = {32{lb_mem_res  & mem_align_off_0}} & { {24{data_cache_rdata[ 7]}}, data_cache_rdata[ 7: 0] } |  //lb
                    {32{lb_mem_res  & mem_align_off_1}} & { {24{data_cache_rdata[15]}}, data_cache_rdata[15: 8] } |
                    {32{lb_mem_res  & mem_align_off_2}} & { {24{data_cache_rdata[23]}}, data_cache_rdata[23:16] } |
                    {32{lb_mem_res  & mem_align_off_3}} & { {24{data_cache_rdata[31]}}, data_cache_rdata[31:24] } |
                    {32{lbu_mem_res & mem_align_off_0}} & { 24'b0, data_cache_rdata[ 7: 0] } |                      //lbu
                    {32{lbu_mem_res & mem_align_off_1}} & { 24'b0, data_cache_rdata[15: 8] } |
                    {32{lbu_mem_res & mem_align_off_2}} & { 24'b0, data_cache_rdata[23:16] } |
                    {32{lbu_mem_res & mem_align_off_3}} & { 24'b0, data_cache_rdata[31:24] } |
                    {32{lh_mem_res  & (mem_align_off_0 | mem_align_off_1)}} & { {16{data_cache_rdata[15]}}, data_cache_rdata[15: 0] } |   //lh
                    {32{lh_mem_res  & (mem_align_off_2 | mem_align_off_3)}} & { {16{data_cache_rdata[31]}}, data_cache_rdata[31:16] } |
                    {32{lhu_mem_res & (mem_align_off_0 | mem_align_off_1)}} & { 16'b0, data_cache_rdata[15: 0] } |                       //lhu
                    {32{lhu_mem_res & (mem_align_off_2 | mem_align_off_3)}} & { 16'b0, data_cache_rdata[31:16] } |      
                    {32{lw_mem_res}} & data_cache_rdata |                                                                                //lw
                    {32{lwl_mem_res & mem_align_off_0}} & { data_cache_rdata[ 7: 0], ms_rt_value[23: 0] } |                              //lwl
                    {32{lwl_mem_res & mem_align_off_1}} & { data_cache_rdata[15: 0], ms_rt_value[15: 0] } |
                    {32{lwl_mem_res & mem_align_off_2}} & { data_cache_rdata[23: 0], ms_rt_value[ 7: 0] } |
                    {32{lwl_mem_res & mem_align_off_3}} & data_cache_rdata |
                    {32{lwr_mem_res & mem_align_off_0}} & data_cache_rdata |                                                             //lwr
                    {32{lwr_mem_res & mem_align_off_1}} & { ms_rt_value[31:24], data_cache_rdata[31: 8] } |
                    {32{lwr_mem_res & mem_align_off_2}} & { ms_rt_value[31:16], data_cache_rdata[31:16] } |
                    {32{lwr_mem_res & mem_align_off_3}} & { ms_rt_value[31: 8], data_cache_rdata[31:24] };


assign ms_final_result = ms_res_from_mem ? mem_result :
                         ms_res_from_hi  ? HI :
                         ms_res_from_lo  ? LO :
                         ms_cp0_we       ? ms_rt_value :
                                           ms_alu_result;

always @(posedge clk) begin
    if (reset) begin
        HI <= 0;
    end else if (ms_hi_we && ms_valid && !ms_disable) begin
        HI <= ms_hl_src_from_mul ? mul_res[63:32]:
              ms_hl_src_from_div ? ms_alu_div_res[31: 0]:
                                   ms_rs_value;
    end
end

always @(posedge clk) begin
    if (reset) begin
        LO <= 0;
    end else if (ms_lo_we && ms_valid && !ms_disable) begin
        LO <= ms_hl_src_from_mul ? mul_res[31: 0]:
              ms_hl_src_from_div ? ms_alu_div_res[63:32]: 
                                   ms_rs_value;
    end
end

assign stall_ms_bus = {data_cache_data_ok,     //48:48
                       ms_cp0_addr,           //47:40
                       ms_cp0_we && ms_to_ws_valid, //39:39
                       ms_final_result     ,  //38:7
                       ms_res_from_wb      ,  //6:6
                       ms_gr_we && ms_to_ws_valid,  //5:5
                       ms_dest                //4:0
                      };

assign ms_has_exception     = es_has_exception;
assign ms_exception_type    = es_exception_type;

assign mem_mtc0_index       = ms_cp0_we & ms_to_ws_valid & (ms_cp0_addr == 8'b00000000); //mtc0 write cp0_index
assign ms_has_reflush_to_es = (ms_has_exception | ms_eret | ms_tlbr | ms_tlbwi) & ms_valid;

endmodule
