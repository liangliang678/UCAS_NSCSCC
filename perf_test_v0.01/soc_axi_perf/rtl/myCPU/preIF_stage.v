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
    input  [31:0] cancel_pc,  //actually pc of TLBR/TLBWI
    input         exception_is_tlb_refill_in
);
wire [31:0] inst_addr;
wire        fs_use_tlb;  //mapped addr

wire        preif_ready_go;

wire [31:0] seq_pc;
wire [31:0] nextpc;
reg  [31:0] fs_pc;

wire        preif_has_exception;
// reg         preif_has_exception_r;

wire        pfs_has_exception;
wire [ 4:0] pfs_exception_type;
wire        exception_adel;
wire        pfs_exception_tlb_refill;
wire        pfs_exception_tlb_invalid;
wire [31:0] pfs_badvaddr;
wire        exception_is_tlb_refill;

reg [31:0] cancel_pc_r;
reg        pfs_go_exception_pc;
reg        pfs_go_cancel_pc;
reg        pfs_go_tlb_refill_pc;

reg  [`BR_BUS_WD-1:0] br_bus_r;

wire         br_valid;                 //means brance inst is ID -> EXE...   
wire         br_taken;
wire [ 31:0] br_target, br_target_r;
wire         br_stall;

wire         delay_slot_in_preif;
reg          delay_slot_in_preif_r;
reg          br_target_in_preif_r;                                  //br_target_in_preif_r   MEANS    br target in preif, nothing to do with how long it has been in preif...

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
    else if(pfs_ex || pfs_go_exception_pc)                            //exception so, ignore br_target... 
        br_target_in_preif_r <= 1'b0;
    else if(pfs_cancel_in || pfs_go_cancel_pc)   
        br_target_in_preif_r <= 1'b0;                             //when daley slot go to IF, br target in preif     OR      branch inst in ID and delay slot in IF, but branch target still waiting 
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


always @(posedge clk) begin                                //we need a register to hold nextpc=380 when exception comes
    if (reset) begin
        pfs_go_exception_pc <= 1'b0;
    end 
    else if (pfs_ex) begin
        pfs_go_exception_pc <= 1'b1;
    end
    else if(inst_cache_valid && inst_cache_addr_ok) begin       //read request accepted, no need to hold nextpc=380 now
        pfs_go_exception_pc <= 1'b0;
    end
end

always @(posedge clk) begin                                
    if (reset) begin
        pfs_go_cancel_pc <= 1'b0;
    end 
    else if (pfs_cancel_in) begin
        pfs_go_cancel_pc <= 1'b1;
    end
    else if(inst_cache_valid && inst_cache_addr_ok) begin      
        pfs_go_cancel_pc <= 1'b0;
    end
end

always @(posedge clk) begin                                
    if (reset) begin
        pfs_go_tlb_refill_pc <= 1'b0;
    end 
    else if (pfs_ex && exception_is_tlb_refill_in) begin
        pfs_go_tlb_refill_pc <= 1'b1;
    end
    else if(inst_cache_valid && inst_cache_addr_ok) begin      
        pfs_go_tlb_refill_pc <= 1'b0;
    end
end

// pre-IF stage
assign preif_ready_go = (inst_cache_valid & inst_cache_addr_ok);  //read request accepted
assign to_fs_valid    = ~reset & preif_ready_go;
assign seq_pc         = fs_pc + 3'h4;
assign nextpc         = ((pfs_ex && exception_is_tlb_refill_in) || (pfs_go_tlb_refill_pc)) ? 32'hbfc00200 :
                        (pfs_ex || pfs_go_exception_pc) ? 32'hbfc00380 :               // exception entrance may stall...
                        pfs_cancel_in ? (cancel_pc + 3'b100) :
                        pfs_go_cancel_pc ? (cancel_pc_r + 3'b100) :
                        (br_taken && fs_has_inst) ? br_target :                         // branch inst in ID, delay slot in IF, br target in preif waiting for addr_ok  
                        (br_target_in_preif_r) ? br_target_r : 
                        seq_pc;                                         //if delay slot in preif, go pc+4

always @(posedge clk) begin                              //we need a register to hold cancel pc
    if(reset) begin
        cancel_pc_r <= 32'b0;
    end
    else if(pfs_cancel_in) begin
        cancel_pc_r <= cancel_pc;
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

assign s0_vpn2 = nextpc[31:13];
assign s0_odd_page = nextpc[12];
assign s0_asid = cp0_entryhi[7:0];

assign fs_use_tlb = ~(nextpc[31] & ~nextpc[30]);

//cache valid
assign inst_cache_valid     = fs_allowin & ~reset & (~pfs_ex) & (~br_stall);  //to_fs_valid && fs_allowin;
//[tag,index,offset] 20:8:4
assign inst_addr    = fs_use_tlb ? {s0_pfn, nextpc[11:0]} : {3'b0, nextpc[28:0]};  
assign inst_cache_tag   = inst_addr[31:12];
assign inst_cache_index = inst_addr[11: 4];
assign inst_cache_offset= inst_addr[ 3: 0];
//kseg 1
// 1: uncached; 0: cached
assign inst_cache_uncache = nextpc[31] & ~nextpc[30] & nextpc[29];

assign preif_has_exception  = pfs_exception_tlb_refill || pfs_exception_tlb_invalid;

// always @(posedge clk) begin
//     if (reset) begin
//         preif_has_exception_r <= 0;
//     end
//     if (preif_ready_go & fs_allowin) begin
//         preif_has_exception_r <= preif_has_exception;
//     end
// end

//assign exception_adel    = ~(seq_pc[1:0] == 0);
assign exception_adel    = ~(nextpc[1:0] == 0);
assign pfs_exception_tlb_refill = ~s0_found & fs_use_tlb;
assign pfs_exception_tlb_invalid = s0_found & ~s0_v & fs_use_tlb;
assign pfs_has_exception  = exception_adel | preif_has_exception;

assign pfs_exception_type = exception_adel ?        5'h4 :
                           preif_has_exception ?   5'h2 : 
                                                   5'h9 ;

//assign fs_badvaddr = exception_adel ? seq_pc - 3'h4 : 
assign pfs_badvaddr = exception_adel ? nextpc : 
                     (pfs_exception_tlb_refill || pfs_exception_tlb_invalid) ? nextpc : 32'b0 ;

assign exception_is_tlb_refill = pfs_exception_tlb_refill;

assign preif_to_fs_bus = {  exception_is_tlb_refill,
                            pfs_badvaddr,
                            pfs_has_exception,
                            pfs_exception_type,
                            nextpc
                         };


endmodule