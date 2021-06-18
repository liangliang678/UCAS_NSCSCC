`include "mycpu.h"

module preif_stage(
    input                          clk            ,
    input                          reset          ,
    //allwoin
    input                          fs_allowin     ,   
    //brbus
    input  [`BR_BUS_WD       -1:0] br_bus         ,
    //to fs
    output                         to_fs_valid    ,
    output [`PF_TO_FS_BUS_WD -1:0] preif_to_fs_bus,
    input                          fs_has_inst    ,

    // inst cache interface
    output           inst_cache_valid,
    output           inst_cache_uncache,
    output  [ 19:0]  inst_cache_tag,
    output  [  7:0]  inst_cache_index,
    output  [  3:0]  inst_cache_offset,
    input            inst_cache_addr_ok,

    //TLB search port 0
    output [18:0] s0_vpn2,
    output        s0_odd_page,
    output [ 7:0] s0_asid,
    input         s0_found,
    input  [ 3:0] s0_index,
    input  [19:0] s0_pfn,
    input  [ 2:0] s0_c,
    input         s0_d,
    input         s0_v,

    input  [31:0] cp0_entryhi,

    //clear stage
    input         pfs_ex,

    //reflush
    input         pfs_cancel_in,
    input         pfs_eret_in,
    input  [31:0] reflush_pc, 
    input         tlb_write
);
wire [31:0] inst_addr;
wire        fs_use_tlb;  //mapped addr

wire        preif_ready_go;

wire [31:0] seq_pc;
wire [31:0] nextpc;
reg  [31:0] fs_pc;

wire        preif_tlb_exception;

wire        pfs_has_exception;
wire [ 4:0] pfs_exception_type;
wire        exception_adel;
wire        pfs_exception_tlb_refill;
wire        pfs_exception_tlb_invalid;
wire [31:0] pfs_badvaddr;
wire        exception_is_tlb_refill;

wire pfs_reflush;
reg pfs_go_reflush_pc;

reg  [`BR_BUS_WD-1:0] br_bus_r;

wire         br_valid;                 //means brance inst is ID -> EXE...   
wire         br_taken;
wire [ 31:0] br_target, br_target_r;
wire         br_stall;

wire         delay_slot_in_preif;
reg          delay_slot_in_preif_r;
reg          br_target_in_preif_r;                                  //br_target_in_preif_r   MEANS    br target in preif, nothing to do with how long it has been in preif...
reg [31:0] reflush_pc_r;

assign delay_slot_in_preif = br_taken & ~fs_has_inst;                   //delay_slot_in_preif   MEANS    delay slot inst has been in PREIF for more than one clk
                                                                        //                               branch inst in ID , no inst in IF, indicates delay slot didnt go to IF but stay in PREIF...
always @(posedge clk) begin                                             
    if(reset)
        delay_slot_in_preif_r <= 1'b0;
    else if(preif_ready_go && fs_allowin)                            //delay slot go to IF
        delay_slot_in_preif_r <= 1'b0;
    else if(delay_slot_in_preif)
        delay_slot_in_preif_r <= 1'b1;
end

always @(posedge clk) begin
    if(reset)
        br_target_in_preif_r <= 1'b0;
    else if(pfs_reflush || pfs_go_reflush_pc)
        br_target_in_preif_r <= 1'b0;
    //when daley slot go to IF, br target in preif     OR      branch inst in ID and delay slot in IF, but branch target still waiting 
    else if(((delay_slot_in_preif || delay_slot_in_preif_r) && preif_ready_go && fs_allowin) || (br_taken && fs_has_inst && !preif_ready_go))
        br_target_in_preif_r <= 1'b1;
    else if(preif_ready_go && fs_allowin)                            //br target go to IF
        br_target_in_preif_r <= 1'b0;
end

assign {br_valid,br_taken,br_target,br_stall} = br_bus;

always @(posedge clk) begin
    if(reset)
        br_bus_r[32:0] <= 33'b0;
    else if(br_taken)
        br_bus_r[32:0] <= br_bus[32:0];

    if(reset)
        br_bus_r[34:33] <= 2'b0;
    else if(pfs_ex)                      //do not use br_target when exception comes
        br_bus_r[33] <= 1'b0;           //br_taken_r
    else if(pfs_cancel_in) 
        br_bus_r[33] <= 1'b0; 
    else if(br_taken)
        br_bus_r[33] <= br_taken;
end

assign br_target_r = br_bus_r[32:1];

assign pfs_reflush = pfs_ex | pfs_cancel_in | pfs_eret_in;

always @(posedge clk) begin                                
    if (reset) begin
        pfs_go_reflush_pc <= 1'b0;
    end 
    else if (pfs_ex || pfs_cancel_in || pfs_eret_in) begin
        pfs_go_reflush_pc <= 1'b1;
    end
    else if(inst_cache_valid && inst_cache_addr_ok) begin      
        pfs_go_reflush_pc <= 1'b0;
    end
end

// pre-IF stage
assign preif_ready_go = (inst_cache_valid & inst_cache_addr_ok);  //read request accepted
assign to_fs_valid    = ~reset & preif_ready_go;
assign seq_pc         = fs_pc + 3'h4;
assign nextpc         = (pfs_reflush ) ? reflush_pc : 
                        (pfs_go_reflush_pc) ? reflush_pc_r :
                        (br_taken && fs_has_inst) ? br_target :                         // branch inst in ID, delay slot in IF, br target in preif waiting for addr_ok  
                        (br_target_in_preif_r) ? br_target_r : 
                        seq_pc;                                         //if delay slot in preif, go pc+4

always @(posedge clk) begin                              //we need a register to hold reflush pc
    if(reset) begin
        reflush_pc_r <= 32'b0;
    end
    else if(pfs_reflush) begin
        reflush_pc_r <= reflush_pc;
    end
end

always @(posedge clk) begin
    if (reset) begin
        fs_pc <= 32'hbfbffffc;  //trick: to make nextpc be 0xbfc00000 during reset 
    end
    else if (to_fs_valid && fs_allowin) begin
        fs_pc <= nextpc;
    end
end

reg [1 :0] state;
reg [1 :0] nextstate;
reg [18:0] vpn2;
reg odd_page;
reg [7 :0] asid;
reg [19 :0] pfn;
(* max_fanout = 30 *)reg tlb_v;
reg tlb_found;
reg tlb_valid;

wire tlb_hit;
assign tlb_hit = tlb_valid & (nextpc[31:13] == vpn2) & (nextpc[12] == odd_page);

always @(posedge clk) begin
    if(reset)   state <= 2'd0;
    else state <= nextstate;
end

always @(*) begin
    case(state) 
    2'b00:  nextstate = ( tlb_hit | !fs_use_tlb | br_stall) ? 2'b00 : 2'b01;// tlb hit or kseg01 or br uncomplete 
    2'b01:  nextstate = 2'b10;
    2'b10:  nextstate = inst_cache_addr_ok ? 2'b00 : 2'b10;
    default:nextstate = 2'b00;
    endcase
end

always @(posedge clk)
begin
    if(reset) tlb_valid <= 1'b0;
    else if (tlb_write) tlb_valid <= 1'b0;
    else if (state == 2'b01) tlb_valid <= 1'b1;
end

always @(posedge clk)
begin
    if(reset) 
    begin
        vpn2 <= 19'd0;
        odd_page <= 1'b0;
        asid <= 8'b0;
        pfn <= 20'b0;
        tlb_v <= 1'b0 ;
        tlb_found <= 1'b0;
    end
    else if(state == 2'b01)
    begin
        vpn2 <= nextpc[31:13];
        odd_page <= nextpc[12];
        asid <= cp0_entryhi[7:0];
        pfn <= s0_pfn;
        tlb_v <= s0_v;
        tlb_found <= s0_found;
    end
end

wire tlb_req_en;
assign tlb_req_en = ((tlb_hit | !fs_use_tlb) & (state == 2'b00)) | (state == 2'b10);

assign s0_vpn2 = nextpc[31:13];
assign s0_odd_page = nextpc[12];
assign s0_asid = cp0_entryhi[7:0];

assign fs_use_tlb = ~(nextpc[31] & ~nextpc[30]);

//cache valid
assign inst_cache_valid     = fs_allowin & ~reset & (~pfs_ex) & (~br_stall) & tlb_req_en;  //to_fs_valid && fs_allowin;
//[tag,index,offset] 20:8:4
assign inst_addr    = fs_use_tlb ? {3'b0,pfn[16:0], nextpc[11:0]} : {3'b0, nextpc[28:0]};
assign inst_cache_tag   = inst_addr[31:12];
assign inst_cache_index = inst_addr[11: 4];
assign inst_cache_offset= inst_addr[ 3: 0];
//kseg 1
// 1: uncached; 0: cached
assign inst_cache_uncache = nextpc[31] & ~nextpc[30] & nextpc[29];

assign preif_tlb_exception  = pfs_exception_tlb_refill | pfs_exception_tlb_invalid;
assign exception_adel    = ~(nextpc[1:0] == 0);
assign pfs_exception_tlb_refill = ~tlb_found & fs_use_tlb & (state == 2'b10);
assign pfs_exception_tlb_invalid = tlb_found & ~tlb_v & fs_use_tlb & (state == 2'b10);
assign pfs_has_exception  = exception_adel | preif_tlb_exception;

assign pfs_exception_type = exception_adel ?        5'h4 :
                           preif_tlb_exception ?   5'h2 : 
                                                   5'h9 ;

assign pfs_badvaddr = nextpc;
assign exception_is_tlb_refill = pfs_exception_tlb_refill;

assign preif_to_fs_bus = {  exception_is_tlb_refill,        //70:70
                            pfs_badvaddr,                   //69:38
                            pfs_has_exception,              //37:37
                            pfs_exception_type,             //36:32
                            nextpc                          //31:0
                         };

endmodule