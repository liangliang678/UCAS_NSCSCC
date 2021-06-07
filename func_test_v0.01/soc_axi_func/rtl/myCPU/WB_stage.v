`include "mycpu.h"

module wb_stage(
    input                           clk           ,
    input                           reset         ,
    //allowin
    output                          ws_allowin    ,
    //from ms
    input                           ms_to_ws_valid,
    input  [`MS_TO_WS_BUS_WD -1:0]  ms_to_ws_bus  ,
    //to rf: for write back
    output [`WS_TO_RF_BUS_WD -1:0]  ws_to_rf_bus  ,
    //trace debug interface
    output [31:0] debug_wb_pc     ,
    output [ 3:0] debug_wb_rf_wen ,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata,
    //data relevant
    output [`STALL_WS_BUS_WD -1:0] stall_ws_bus,

    //handle exception
    output [31:0] c0_wdata,
    output [ 7:0] c0_addr,
    output        mtc0_we,

    output        wb_ex,       //has exception
    output [ 4:0] ex_type,     //type of exception
    output        wb_bd,       //is delay slot
    output [31:0] wb_pc,       //pc
    output [31:0] wb_badvaddr, //bad vaddr
    output        wb_eret,

    input         has_int,
    input  [31:0] c0_rdata,

    //TLB write port
    output         we,
    output  [ 3:0] w_index,
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
    //TLB read port
    output [ 3:0] r_index,
    input  [18:0] r_vpn2,
    input  [ 7:0] r_asid,
    input         r_g,
    input  [19:0] r_pfn0,
    input  [ 2:0] r_c0,
    input         r_d0,
    input         r_v0,
    input  [19:0] r_pfn1,
    input  [ 2:0] r_c1,
    input         r_d1,
    input         r_v1,

    //TLB CP0 REG
    input  [31:0] cp0_index,
    input  [31:0] cp0_entryhi,
    input  [31:0] cp0_entrylo0,
    input  [31:0] cp0_entrylo1,

    //TLBR\TLBP to CP0
    output        is_TLBR,
    output [77:0] TLB_rdata,
    output        is_TLBP,
    output        index_write_p,
    output [ 3:0] index_write_index,

    output        wb_mtc0_index,

    output        wb_cancel_to_all,
    output [31:0] cancel_pc,
    output        exception_is_tlb_refill
);

reg         ws_valid;
wire        ws_ready_go;

reg [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus_r;
wire [ 3:0] ws_s1_index   ;
wire        ws_s1_found   ;
wire        ws_tlbp       ;
wire        ws_tlbr       ;
wire        ws_tlbwi      ;
wire        ws_eret       ;
wire [31:0] ws_badvaddr   ;
wire        ws_bd         ;
wire        ms_has_exception;
wire [ 4:0] ms_exception_type;
wire        ws_cp0_op     ;
wire        ws_cp0_we     ;
wire [ 7:0] ws_cp0_addr   ;
wire [ 1:0] ws_load_store_offset;
wire        ws_gr_we;
wire [ 4:0] ws_dest;
wire        ws_res_from_wb;
wire [31:0] ws_final_result;
wire [31:0] ws_pc;

assign {exception_is_tlb_refill,//139:139
        ws_s1_index         ,  //138:135
        ws_s1_found         ,  //134:134
        ws_tlbp             ,  //133:133
        ws_tlbr             ,  //132:132
        ws_tlbwi            ,  //131:131
        ws_eret             ,  //130:130
        ws_badvaddr         ,  //129:98
        ws_bd               ,  //97:97
        ms_has_exception    ,  //96:96
        ms_exception_type   ,  //95:82
        ws_cp0_op           ,  //81:81
        ws_cp0_we           ,  //80:80
        ws_cp0_addr         ,  //79:72
        ws_load_store_offset,  //71:70
        ws_gr_we            ,  //69:69
        ws_dest             ,  //68:64
        ws_final_result     ,  //63:32
        ws_pc                  //31:0
       } = ms_to_ws_bus_r;

assign ws_res_from_wb = ws_cp0_op;//mfc0

wire        rf_we;
wire [4 :0] rf_waddr;
wire [31:0] rf_wdata;
assign ws_to_rf_bus = {rf_we   ,  //37:37
                       rf_waddr,  //36:32
                       rf_wdata   //31:0
                      };

assign ws_ready_go = 1'b1;
assign ws_allowin  = !ws_valid || ws_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ws_valid <= 1'b0;
    end
    else if (wb_ex) begin
        ws_valid <= 1'b0;
    end
    else if (ws_allowin) begin
        ws_valid <= ms_to_ws_valid;
    end

    if (ms_to_ws_valid && ws_allowin) begin
        ms_to_ws_bus_r <= ms_to_ws_bus;
    end
end

wire        ws_has_exception;
wire [ 4:0] ws_exception_type;

assign rf_we    = ws_gr_we && ws_valid && !ws_has_exception;
assign rf_waddr = ws_dest;
assign rf_wdata = ws_cp0_op ? c0_rdata : ws_final_result;

// debug info generate
assign debug_wb_pc       = ws_pc;
assign debug_wb_rf_wen   = {4{rf_we}};
assign debug_wb_rf_wnum  = ws_dest;
assign debug_wb_rf_wdata = rf_wdata;

assign stall_ws_bus = {ws_cp0_addr,           //47:40
                       ws_cp0_we && ws_valid, //39:39
                       rf_wdata            ,  //38:7
                       ws_res_from_wb      ,  //6:6
                       ws_gr_we && ws_valid,  //5:5
                       ws_dest                //4:0
                      };

assign ws_has_exception   = ws_valid && ms_has_exception;
assign ws_exception_type  = ms_exception_type;

assign c0_addr              = ws_cp0_addr;
assign c0_wdata             = ws_final_result;
assign mtc0_we              = ws_valid && ws_cp0_we && !ws_has_exception;
assign wb_ex                = ws_has_exception;
assign ex_type              = ws_exception_type;
assign wb_bd                = ws_bd;
assign wb_pc                = ws_pc;
assign wb_badvaddr          = ws_badvaddr;
assign wb_eret              = ws_eret;

//TLB CP0 REG
assign is_TLBR              = ws_tlbr;
assign TLB_rdata            = {r_vpn2, r_asid, r_g, r_pfn0, r_c0, r_d0, r_v0, r_pfn1, r_c1, r_d1, r_v1};
assign is_TLBP              = ws_tlbp;
assign index_write_p        = ~ws_s1_found;
assign index_write_index    = ws_s1_index;

//TLB write port
assign we      = ws_tlbwi;
assign w_index = cp0_index[3:0];
assign w_vpn2  = cp0_entryhi[31:13];
assign w_asid  = cp0_entryhi[ 7:0];
assign w_g     = cp0_entrylo0[0] & cp0_entrylo1[0];
assign w_pfn0  = cp0_entrylo0[25:6];
assign w_c0    = cp0_entrylo0[ 5:3];
assign w_d0    = cp0_entrylo0[2];
assign w_v0    = cp0_entrylo0[1];
assign w_pfn1  = cp0_entrylo1[25:6]; 
assign w_c1    = cp0_entrylo1[ 5:3];
assign w_d1    = cp0_entrylo1[2];
assign w_v1    = cp0_entrylo1[1];
//TLB read port
assign r_index = cp0_index[3:0];

assign wb_mtc0_index = mtc0_we & (ws_cp0_addr == 8'b00000000); //mtc0 write cp0_index

assign wb_cancel_to_all = ws_valid & (ws_tlbr | ws_tlbwi );
assign cancel_pc = ws_pc;
endmodule
