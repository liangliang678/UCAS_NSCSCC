`include "mycpu.h"

module preif_stage(
    input                          clk            ,
    input                          reset          ,
    //allwoin
    input                          fs_allowin     ,   
    //brbus
    input  [`BR_BUS_WD       -1:0] br_bus         ,

    //fs
    output                         to_fs_valid    ,
    output [`PF_TO_FS_BUS_WD -1:0] preif_to_fs_bus,
    output                         fs_no_inst_wait,
    input  [ 5:0]                   inst_offset    ,//0~16

    // inst cache interface
    output           inst_cache_valid,
    output           inst_cache_uncache,
    output  [ 19:0]  inst_cache_tag,
    output  [  6:0]  inst_cache_index,
    output  [  4:0]  inst_cache_offset,
    input            inst_cache_addr_ok,

    // //TLB search port 0
    output [18:0] s0_vpn2,
    output        s0_odd_page,
    output [ 7:0] s0_asid,
    input         s0_found,
    input  [19:0] s0_pfn,
    input   [2:0] s0_c,
    input         s0_d,
    input         s0_v,
    input         tlb_write,
    input  [31:0] cp0_entryhi,

    //reflush
    input  pfs_reflush,
    input  [31:0] reflush_pc

);
wire [31:0] inst_addr;
wire        fs_use_tlb;  //mapped addr

wire        preif_ready_go;

wire [31:0] seq_pc;
wire [31:0] nextpc;
(* max_fanout = 10 *)reg  [31:0] fs_pc;

wire        preif_tlb_exception;
wire        pfs_has_exception;
wire [ 4:0] pfs_exception_type;
wire        exception_adel;
wire        pfs_exception_tlb_refill;
wire        pfs_exception_tlb_invalid;
wire [31:0] pfs_badvaddr;
wire        exception_is_tlb_refill;

(* max_fanout = 10 *)reg  [`BR_BUS_WD-1:0] br_bus_r;


wire         br_take_branch, br_taken_r;
wire [ 31:0] br_target, br_target_r;
wire         br_stall;

reg pfs_go_reflush_pc;
reg [31:0] reflush_pc_r;


// handle branch/jump

assign {
        br_take_branch,       //32:32
        br_target           //31:0
       } = br_bus;

always @(posedge clk) begin
    if(reset)
        br_bus_r[32:0] <= 33'b0;
    else if(pfs_reflush | preif_ready_go)   //例外 或�?? 跳转地址访问已经接受了，标记为无�?
        br_bus_r[32] <= 1'b0;                                 
    else if(br_take_branch)
        br_bus_r[32:0] <= br_bus[32:0];
end

assign br_target_r = br_bus_r[31:0];
assign br_taken_r = br_bus_r[32];


always @(posedge clk) begin                                
    if (reset) begin
        pfs_go_reflush_pc <= 1'b0;
    end 
    else if (pfs_reflush) begin
        pfs_go_reflush_pc <= 1'b1;
    end
    else if(inst_cache_valid && inst_cache_addr_ok) begin      
        pfs_go_reflush_pc <= 1'b0;
    end
end

always @(posedge clk) begin                              //we need a register to hold reflush pc
    if(reset) begin
        reflush_pc_r <= 32'b0;
    end
    else if(pfs_reflush) begin
        reflush_pc_r <= reflush_pc;
    end
end

// pre-IF stage
assign preif_ready_go = (inst_cache_valid & inst_cache_addr_ok) | fs_no_inst_wait & fs_allowin;  //请求接受 或�?? 不发请求（有例外�?
assign to_fs_valid    = ~reset & preif_ready_go;
assign seq_pc         = fs_pc + inst_offset;
assign nextpc         = (pfs_reflush ) ? reflush_pc : 
                        (pfs_go_reflush_pc) ? reflush_pc_r :
                        (br_take_branch) ? br_target :                         
                        (br_taken_r) ? br_target_r : 
                        seq_pc;                                         //if delay slot in preif, go pc+4

always @(posedge clk) begin
    if (reset) begin
        fs_pc <= 32'hbfbffffc;  //trick: to make nextpc be 0xbfc00000 during reset 
    end
    else if (to_fs_valid && fs_allowin) begin
        fs_pc <= nextpc;
    end
end

//有例外就不发请求
assign fs_no_inst_wait = pfs_has_exception; 


// // inst TLB
// reg [1 :0] state;
// reg [1 :0] nextstate;
// reg [18:0] vpn2;
// reg odd_page;
// reg [7 :0] asid;
// reg [19 :0] pfn;
// (* max_fanout = 10 *)reg tlb_v;
// (* max_fanout = 10 *)reg tlb_found;
// reg tlb_valid;

// wire tlb_hit;
// assign tlb_hit = tlb_valid & (nextpc[31:13] == vpn2) & (nextpc[12] == odd_page);

// always @(posedge clk) begin
//     if(reset)   state <= 2'd0;
//     else state <= nextstate;
// end

// always @(*) begin
//     case(state) 
//     2'b00:  nextstate = ( tlb_hit | !fs_use_tlb | br_stall) ? 2'b00 : 2'b01;// tlb hit or kseg01 or br uncomplete 
//     2'b01:  nextstate = 2'b10;
//     2'b10:  nextstate = inst_cache_addr_ok ? 2'b00 : 2'b10;
//     default:nextstate = 2'b00;
//     endcase
// end

// always @(posedge clk)
// begin
//     if(reset) tlb_valid <= 1'b0;
//     else if (tlb_write) tlb_valid <= 1'b0;
//     else if (state == 2'b01) tlb_valid <= 1'b1;
// end

// always @(posedge clk)
// begin
//     if(reset) 
//     begin
//         vpn2 <= 19'd0;
//         odd_page <= 1'b0;
//         asid <= 8'b0;
//         pfn <= 20'b0;
//         tlb_v <= 1'b0 ;
//         tlb_found <= 1'b0;
//     end
//     else if(state == 2'b01)
//     begin
//         vpn2 <= nextpc[31:13];
//         odd_page <= nextpc[12];
//         asid <= cp0_entryhi[7:0];
//         pfn <= s0_pfn;
//         tlb_v <= s0_v;
//         tlb_found <= s0_found;
//     end
// end

assign fs_use_tlb = ~(nextpc[31] & ~nextpc[30]);

wire          tlb_req_en;
wire          tlb_found;
wire   [19:0] tlb_pfn;
wire   [ 3:0] tlb_index;
wire   [2 :0] tlb_c;
wire          tlb_d;
wire          tlb_v;

tlb_cache inst_tlb_cache(
    .reset          (reset),
    .clk            (clk),

    .s_found        (s0_found),
    .s_pfn          (s0_pfn),
    .s_d            (s0_d),
    .s_v            (s0_v),
    .s_c            (s0_c),

    .inst_VA        (nextpc),
    .inst_tlb_req_en(tlb_req_en),
    .inst_addr_ok   (inst_cache_addr_ok),
    .inst_tlb_exception(preif_tlb_exception),
    .inst_use_tlb   (fs_use_tlb),
    .cp0_entryhi                (cp0_entryhi),

    .tlb_write      (tlb_write),
    .inst_pfn       (tlb_pfn),
    .inst_tlb_index (tlb_index),
    .inst_tlb_c     (tlb_c),
    .inst_tlb_v     (tlb_v),
    .inst_tlb_d     (tlb_d),
    .inst_tlb_found (tlb_found)

);
assign s0_vpn2 = nextpc[31:13];
assign s0_odd_page = nextpc[12];
assign s0_asid = cp0_entryhi[7:0];

//cache valid
assign inst_cache_valid     = fs_allowin & ~reset & ~fs_no_inst_wait & tlb_req_en;  
//[tag,index,offset] 20:8:4
assign inst_addr    = fs_use_tlb ? {3'b0, tlb_pfn[16:0], nextpc[11:0]} : {3'b0, nextpc[28:0]};
assign inst_cache_tag   = inst_addr[31:12];
assign inst_cache_index = inst_addr[11: 5];
assign inst_cache_offset= inst_addr[ 4: 0];
//kseg 1
// 1: uncached; 0: cached
assign inst_cache_uncache = nextpc[31] & ~nextpc[30] & nextpc[29];

// preIF exception

assign exception_adel    = ~(nextpc[1:0] == 0);
assign pfs_exception_tlb_refill = ~tlb_found & fs_use_tlb & tlb_req_en;
assign pfs_exception_tlb_invalid = tlb_found & ~tlb_v & fs_use_tlb & tlb_req_en;
assign preif_tlb_exception  = pfs_exception_tlb_refill | pfs_exception_tlb_invalid;
assign pfs_has_exception  = exception_adel | preif_tlb_exception;

assign pfs_exception_type = exception_adel ?        5'h4 :
                            preif_tlb_exception ?   5'h2 : 
                                                    5'h9 ;

assign pfs_badvaddr = nextpc;
assign exception_is_tlb_refill = pfs_exception_tlb_refill;

// preIF to fs bus
assign preif_to_fs_bus = {  exception_is_tlb_refill,        //38:38
                            pfs_has_exception,              //37:37
                            pfs_exception_type,             //36:32
                            nextpc                          //31:0
                         };

endmodule