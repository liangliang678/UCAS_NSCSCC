`include "mycpu.h"

module exe_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          ms_allowin    ,
    output                         es_allowin    ,
    //from ds
    input                          ds_to_es_valid,
    input  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    //to ms
    output                         es_to_ms_valid,
    output [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus  ,
    // data cache interface
    output           data_cache_valid,
    output           data_cache_op,
    output           data_cache_uncache,
    output  [ 19:0]  data_cache_tag,
    output  [  7:0]  data_cache_index,
    output  [  3:0]  data_cache_offset,
    output  [  3:0]  data_cache_wstrb,
    output  [ 31:0]  data_cache_wdata,
    input            data_cache_addr_ok,

    // output [ 1:0] data_sram_size, ?

    //multiper
    output [63:0] mul_res,
    //data relevant
    output [`STALL_ES_BUS_WD -1:0] stall_es_bus,

    //clear stage
    input                          es_ex,
    output                         es_exception_appear_out,

    //TLB search port 1
    output [18:0] s1_vpn2,
    output        s1_odd_page,
    output [ 7:0] s1_asid,
    input         s1_found,
    input  [ 3:0] s1_index,
    input  [19:0] s1_pfn,
    input  [ 2:0] s1_c,
    input         s1_d,
    input         s1_v,

    input  [31:0] cp0_entryhi,

    input         wb_mtc0_index,
    input         mem_mtc0_index,
    input         es_cancel_in
);

wire [31:0] data_addr     ;  
wire        es_use_tlb    ;
wire [31:0] es_VA         ;

reg         es_valid      ;
wire        es_ready_go   ;

wire        complete      ;
wire        int_overflow  ;


reg  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus_r;
wire        es_tlbp       ;
wire        es_tlbr       ;
wire        es_tlbwi      ;
wire        es_eret       ;
wire [31:0] es_badvaddr_temp   ;
wire [31:0] es_badvaddr   ;
wire        es_bd         ;
wire        es_alu_signed ;
wire        ds_has_exception;
wire [13:0] ds_exception_type;
wire        es_cp0_op     ;
wire        es_cp0_we     ;
wire [ 7:0] es_cp0_addr   ;
wire [ 6:0] es_load_store_type;
wire        es_hi_we      ;
wire        es_lo_we      ;
wire        es_hl_src_from_mul;
wire        es_hl_src_from_div;
wire        es_hi_op      ;
wire        es_lo_op      ;
wire [15:0] es_alu_op     ;
wire        es_load_op    ;
wire        es_src1_is_sa ;  
wire        es_src1_is_pc ;
wire        es_src2_is_imm;
wire        es_src2_is_imm16;
wire        es_src2_is_8  ;
wire        es_gr_we      ;
wire        es_mem_we     ;
wire [ 4:0] es_dest       ;
wire        es_res_from_wb;
wire [15:0] es_imm        ;
wire [31:0] es_rs_value   ;
wire [31:0] es_rt_value   ;
wire [31:0] es_pc         ;
wire        exception_is_tlb_refill;
wire        exception_is_tlb_refill_temp;

assign {exception_is_tlb_refill_temp,//217:217
        es_tlbp             ,  //216:216
        es_tlbr             ,  //215:215
        es_tlbwi            ,  //214:214
        es_eret             ,  //213:213
        es_badvaddr_temp    ,  //212:181
        es_bd               ,  //180:180
        es_alu_signed       ,  //179:179
        ds_has_exception    ,  //178:178
        ds_exception_type   ,  //177:164
        es_cp0_op           ,  //163:163
        es_cp0_we           ,  //162:162
        es_cp0_addr         ,  //161:154
        es_load_store_type  ,  //153:147
        es_hi_we            ,  //146:146
        es_lo_we            ,  //145:145
        es_hl_src_from_mul  ,  //144:144
        es_hl_src_from_div  ,  //143:143
        es_alu_op           ,  //142:127
        es_load_op          ,  //126:126
        es_hi_op            ,  //125:125
        es_lo_op            ,  //124:124
        es_src1_is_sa       ,  //123:123
        es_src1_is_pc       ,  //122:122
        es_src2_is_imm      ,  //121:121
        es_src2_is_imm16    ,  //120:120
        es_src2_is_8        ,  //119:119
        es_gr_we            ,  //118:118
        es_mem_we           ,  //117:117
        es_dest             ,  //116:112
        es_imm              ,  //111:96
        es_rs_value         ,  //95 :64
        es_rt_value         ,  //63 :32
        es_pc                  //31 :0
       } = ds_to_es_bus_r;
assign es_res_from_wb = es_cp0_op;

wire [31:0] es_alu_src1   ;
wire [31:0] es_alu_src2   ;
wire [31:0] es_alu_result ;
wire [31:0] es_alu_result_mul_div;
wire [15:0] alu_op        ;

wire        es_res_from_mem;
wire        es_res_from_hi;
wire        es_res_from_lo;

wire [ 1:0] es_load_store_offset;

wire [ 3:0] write_strb;
wire [31:0] mem_write_data;

wire mem_align_off_0;
wire mem_align_off_1;
wire mem_align_off_2;
wire mem_align_off_3;

assign mem_align_off_0 = (es_load_store_offset == 2'b00);
assign mem_align_off_1 = (es_load_store_offset == 2'b01);
assign mem_align_off_2 = (es_load_store_offset == 2'b10);
assign mem_align_off_3 = (es_load_store_offset == 2'b11);

wire sb_mem_res;
wire sbu_mem_res;
wire sh_mem_res;
wire shu_mem_res;
wire sw_mem_res;
wire swl_mem_res;
wire swr_mem_res;

assign sb_mem_res  = es_load_store_type[6];
assign sbu_mem_res = es_load_store_type[5];
assign sh_mem_res  = es_load_store_type[4];
assign shu_mem_res = es_load_store_type[3];
assign sw_mem_res  = es_load_store_type[2];
assign swl_mem_res = es_load_store_type[1];
assign swr_mem_res = es_load_store_type[0];


assign es_res_from_mem = es_load_op;
assign es_res_from_hi  = es_hi_op;
assign es_res_from_lo  = es_lo_op;


wire        es_has_exception;
wire [13:0] es_exception_type;
wire        exception_adel;
wire        exception_ades;
wire        exception_int_overflow;
wire        es_exception_tlb_refill;
wire        es_exception_tlb_invalid;
wire        es_exception_modified;
reg         es_exception_appear;

reg         es_cancel;

assign es_to_ms_bus = {exception_is_tlb_refill, //250:250
                       s1_index              ,  //249:246
                       s1_found              ,  //245:245
                       es_tlbp               ,  //244:244
                       es_tlbr               ,  //243:243
                       es_tlbwi              ,  //242:242
                       es_mem_we             ,  //241:241
                       es_eret               ,  //240:240
                       es_badvaddr           ,  //239:208
                       es_bd                 ,  //207:207
                       es_has_exception      ,  //206:206
                       es_exception_type     ,  //205:192
                       es_cp0_op             ,  //191:191
                       es_cp0_we             ,  //190:190
                       es_cp0_addr           ,  //189:182
                       es_load_store_type    ,  //181:175
                       es_load_store_offset  ,  //174:173
                       es_rt_value           ,  //172:141
                       es_rs_value           ,  //140:109
                       es_hi_we              ,  //108:108
                       es_lo_we              ,  //107:107
                       es_hl_src_from_mul    ,  //106:106
                       es_hl_src_from_div    ,  //105:105
                       es_alu_result_mul_div ,  //104:73
                       es_res_from_mem       ,  //72:72
                       es_res_from_hi        ,  //71:71
                       es_res_from_lo        ,  //70:70
                       es_gr_we              ,  //69:69
                       es_dest               ,  //68:64
                       es_alu_result         ,  //63:32
                       es_pc                    //31:0
                      };

assign es_ready_go = ~( ((es_alu_op[14] | es_alu_op[15]) & ~complete) |                                                 //div not complete 
                        (!es_has_exception & (es_res_from_mem | es_mem_we) & ~(data_cache_valid & data_cache_addr_ok)) |    //wait for data sram  
                        ((wb_mtc0_index | mem_mtc0_index) & es_tlbp & es_valid)                                         //MEM/WB mtc0 write index and EXE is TLBP  
                      );          
                         
assign es_allowin     = !es_valid || es_ready_go && ms_allowin;
assign es_to_ms_valid =  es_valid && es_ready_go;
always @(posedge clk) begin
    if (reset) begin
        es_valid <= 1'b0;
    end
    else if (es_has_exception & es_valid & ms_allowin & es_ready_go| es_exception_appear)  // add es_ready_go
        es_valid <= 1'b0;
    else if ((es_valid && ms_allowin && es_ready_go && (~es_has_exception) && (es_tlbr | es_tlbwi)) | es_cancel)
        es_valid <= 1'b0;
    else if (es_allowin) begin
        es_valid <= ds_to_es_valid;
    end

    if (ds_to_es_valid && es_allowin) begin
        ds_to_es_bus_r <= ds_to_es_bus;
    end
end

always @(posedge clk) begin
    if (reset) begin
        es_exception_appear <= 0;
    end else if (ms_allowin && es_has_exception && es_valid && es_ready_go) begin  // add es_ready_go
        es_exception_appear <= 1;
    end else if (es_ex) begin
        es_exception_appear <= 0;
    end
end

always @(posedge clk) begin
    if(reset)
        es_cancel <= 1'b0;
    else if(es_valid && ms_allowin && es_ready_go && (~es_has_exception) && (es_tlbr | es_tlbwi)) 
        es_cancel <= 1'b1;
    else if(es_cancel_in)
        es_cancel <= 1'b0;
end

assign es_exception_appear_out = es_exception_appear;

assign alu_op      = es_alu_op & {16{es_valid}};
assign es_alu_src1 = es_src1_is_sa  ? {27'b0, es_imm[10:6]} : 
                     es_src1_is_pc  ? es_pc[31:0] :
                                      es_rs_value;
assign es_alu_src2 = es_src2_is_imm   ? {{16{es_imm[15]}}, es_imm[15:0]} :
                     es_src2_is_imm16 ? {16'b0, es_imm[15:0]} :
                     es_src2_is_8     ? 32'd8 :
                                      es_rt_value;

alu u_alu(
    .clk                (clk                  ),
    .reset              (reset                ),
    .alu_op             (alu_op               ),
    .alu_src1           (es_alu_src1          ),
    .alu_src2           (es_alu_src2          ),
    .alu_result         (es_alu_result        ),
    .alu_result_mul_div (es_alu_result_mul_div),
    .alu_mul_res        (mul_res              ),
    .complete           (complete             ),
    .overflow           (int_overflow         )
    );

assign es_load_store_offset = es_alu_result[1:0];

assign write_strb = {4{sb_mem_res & mem_align_off_0}} & 4'b0001 |                           //sb
                    {4{sb_mem_res & mem_align_off_1}} & 4'b0010 |
                    {4{sb_mem_res & mem_align_off_2}} & 4'b0100 |
                    {4{sb_mem_res & mem_align_off_3}} & 4'b1000 |
                    {4{sh_mem_res & (mem_align_off_0 | mem_align_off_1)}} & 4'b0011 |       //sh
                    {4{sh_mem_res & (mem_align_off_2 | mem_align_off_3)}} & 4'b1100 |
                    {4{sw_mem_res}} & 4'b1111 |                                             //sw
                    {4{swl_mem_res & mem_align_off_0}} & 4'b0001 |                          //swl
                    {4{swl_mem_res & mem_align_off_1}} & 4'b0011 |
                    {4{swl_mem_res & mem_align_off_2}} & 4'b0111 |
                    {4{swl_mem_res & mem_align_off_3}} & 4'b1111 |
                    {4{swr_mem_res & mem_align_off_0}} & 4'b1111 |                          //swr
                    {4{swr_mem_res & mem_align_off_1}} & 4'b1110 |
                    {4{swr_mem_res & mem_align_off_2}} & 4'b1100 |
                    {4{swr_mem_res & mem_align_off_3}} & 4'b1000 ;
                    
assign data_sram_size = {2{sw_mem_res}} & 2'b10 |                                          //sw,lw
                        {2{(sh_mem_res | shu_mem_res) & (mem_align_off_0 | mem_align_off_1)}} & 2'b01 |   //sh lh lhu             //wrong in handbook
                        {2{(sh_mem_res | shu_mem_res) & (mem_align_off_2 | mem_align_off_3)}} & 2'b01 |
                        {2{(sb_mem_res | sbu_mem_res) & (mem_align_off_0)}} & 2'b00 |      //sb  lb  lbu
                        {2{(sb_mem_res | sbu_mem_res) & (mem_align_off_1)}} & 2'b00 |
                        {2{(sb_mem_res | sbu_mem_res) & (mem_align_off_2)}} & 2'b00 |
                        {2{(sb_mem_res | sbu_mem_res) & (mem_align_off_3)}} & 2'b00 |
                        {2{(swl_mem_res ) & (mem_align_off_0)}} & 2'b00 |                  //swl  lwl
                        {2{(swl_mem_res ) & (mem_align_off_1)}} & 2'b01 |
                        {2{(swl_mem_res ) & (mem_align_off_2)}} & 2'b10 |
                        {2{(swl_mem_res ) & (mem_align_off_3)}} & 2'b10 |
                        {2{(swr_mem_res ) & (mem_align_off_0)}} & 2'b10 |                  //swr  lwr
                        {2{(swr_mem_res ) & (mem_align_off_1)}} & 2'b10 |
                        {2{(swr_mem_res ) & (mem_align_off_2)}} & 2'b01 |
                        {2{(swr_mem_res ) & (mem_align_off_3)}} & 2'b00 ;

assign mem_write_data = {32{sb_mem_res}} & {4{es_rt_value[ 7:0]}} |
                        {32{sh_mem_res}} & {2{es_rt_value[15:0]}} |
                        {32{sw_mem_res}} & {es_rt_value} |
                        {32{swl_mem_res & mem_align_off_0}} & {24'b0, es_rt_value[31:24]} |
                        {32{swl_mem_res & mem_align_off_1}} & {16'b0, es_rt_value[31:16]} |
                        {32{swl_mem_res & mem_align_off_2}} & { 8'b0, es_rt_value[31: 8]} |
                        {32{swl_mem_res & mem_align_off_3}} & es_rt_value |
                        {32{swr_mem_res & mem_align_off_0}} & es_rt_value |
                        {32{swr_mem_res & mem_align_off_1}} & {es_rt_value[23: 0], 8'b0} |
                        {32{swr_mem_res & mem_align_off_2}} & {es_rt_value[15: 0],16'b0} |
                        {32{swr_mem_res & mem_align_off_3}} & {es_rt_value[ 7: 0],24'b0} ;

assign es_VA = (swl_mem_res) ? {es_alu_result[31:2], 2'b0} : es_alu_result;

assign s1_vpn2 = es_tlbp ? cp0_entryhi[31:13] : es_VA[31:13];
assign s1_odd_page = es_tlbp ? 1'b0 : es_VA[12];
assign s1_asid = cp0_entryhi[7:0];

assign es_use_tlb = ~(es_VA[31] && ~es_VA[30]) && es_valid && (es_res_from_mem | es_mem_we);


assign data_cache_valid   = (es_res_from_mem | es_mem_we) & ms_allowin & es_valid & ~es_has_exception;        //only enable when LOAD/STORE
assign data_cache_wstrb = (es_mem_we && es_valid && !es_has_exception) ? write_strb : 4'h0;   
assign data_cache_op    = (es_mem_we && es_valid && !es_has_exception);                                   

assign data_addr  = es_use_tlb ? {s1_pfn, es_VA[11:0]} : {3'b0, es_VA[28:0]};
assign data_cache_tag    = data_addr[31:12];
assign data_cache_index  = data_addr[11: 4];
assign data_cache_offset = data_addr[ 3: 0];
assign data_cache_wdata = mem_write_data;

//kseg 1
// 1: uncached; 0: cached
assign data_cache_uncache = es_VA[31] && ~es_VA[30] && es_VA[29];


assign stall_es_bus = { data_cache_valid,                                            //49:49
                        es_cp0_addr,                                              //48:41
                       (es_cp0_we && es_valid),                                   //40:40
                        es_alu_result,                                            //39:8
                        es_res_from_wb,                                           //7:7
                       (es_res_from_mem || es_res_from_lo || es_res_from_hi),     //6:6
                       (es_gr_we && es_valid),                                    //5:5
                        es_dest                                                   //4:0
                      };

assign exception_adel         = es_load_op && (sh_mem_res  && ~(es_alu_result[0] == 0) ||
                                               shu_mem_res && ~(es_alu_result[0] == 0) ||
                                               sw_mem_res  && ~(es_alu_result[1:0] == 0));
assign exception_ades         = es_mem_we  && (sh_mem_res  && ~(es_alu_result[0] == 0) ||
                                               shu_mem_res && ~(es_alu_result[0] == 0) ||
                                               sw_mem_res  && ~(es_alu_result[1:0] == 0));

assign exception_int_overflow = int_overflow && es_alu_signed && (es_alu_op[0] || es_alu_op[1]);
assign es_exception_tlb_refill = ~s1_found & es_use_tlb;
assign es_exception_tlb_invalid = s1_found & ~s1_v & es_use_tlb;
assign es_exception_modified = es_mem_we & s1_found & s1_v & ~s1_d & es_use_tlb;
assign es_has_exception       = es_exception_modified || es_exception_tlb_invalid || es_exception_tlb_refill || exception_adel || exception_ades || exception_int_overflow || ds_has_exception;

// assign es_exception_type      = (ds_has_exception      ) ? ds_exception_type :
//                                 ((es_exception_tlb_invalid || es_exception_tlb_refill) & es_mem_we) ? 5'h3 :         //store
//                                 ((es_exception_tlb_invalid || es_exception_tlb_refill) & es_res_from_mem) ? 5'h2 :   //load
//                                 ((es_exception_tlb_invalid || es_exception_tlb_refill) & es_tlbp) ? 5'h2 :          //tlbp
//                                 (es_exception_modified) ? 5'h1 :
//                                 (exception_int_overflow) ? 5'hc : 
//                                 (exception_adel        ) ? 5'h4 :
//                               /*(exception_ades        )*/ 5'h5 ;
assign es_exception_type[0]   = ds_exception_type[0];
assign es_exception_type[1]   = ds_exception_type[1];
assign es_exception_type[2]   = ds_exception_type[2];
assign es_exception_type[3]   = ds_exception_type[3];
assign es_exception_type[4]   = ds_exception_type[4];
assign es_exception_type[5]   = (exception_int_overflow) ? 1'b1 : ds_exception_type[5];
assign es_exception_type[6]   = ds_exception_type[6];
assign es_exception_type[7]   = ds_exception_type[7];
assign es_exception_type[8]   = ds_exception_type[8];
assign es_exception_type[9]   = (exception_adel) ? 1'b1 : ds_exception_type[9];
assign es_exception_type[10]  = (exception_ades) ? 1'b1 : ds_exception_type[10];
assign es_exception_type[11]  = ((es_exception_tlb_invalid | es_exception_tlb_refill) & (es_tlbp | es_res_from_mem)) ? 1'b1 : ds_exception_type[11];
assign es_exception_type[12]  = ((es_exception_tlb_invalid | es_exception_tlb_refill) & es_mem_we) ? 1'b1 : ds_exception_type[12];
assign es_exception_type[13]  = (es_exception_modified) ? 1'b1 : ds_exception_type[13];

assign es_badvaddr            = //(ds_exception_type[2]) ? es_badvaddr_temp :  //tlb refill in IF, dont change
                                ((es_exception_tlb_invalid || es_exception_tlb_refill) & (es_mem_we | es_res_from_mem)) ? es_VA :  //load or store
                                (es_exception_modified) ? es_VA :
                                ((es_exception_tlb_invalid || es_exception_tlb_refill) & es_tlbp) ? {s1_vpn2, s1_odd_page, 12'b0} : // tlbp
                                (es_badvaddr_temp == 32'b0) ? es_alu_result : 
                                es_badvaddr_temp;

assign exception_is_tlb_refill = exception_is_tlb_refill_temp || es_exception_tlb_refill;

endmodule
