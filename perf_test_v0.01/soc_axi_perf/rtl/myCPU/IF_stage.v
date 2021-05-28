`include "mycpu.h"

module if_stage(
    input                          clk            ,
    input                          reset          ,
    //allwoin
    input                          ds_allowin     ,
    //brbus
    input  [`BR_BUS_WD       -1:0] br_bus         ,
    //to ds
    output                         fs_to_ds_valid ,
    output [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus   ,
    // inst sram interface

    output        inst_sram_req,
    output        inst_sram_wr,
    output [ 1:0] inst_sram_size,
    output [ 3:0] inst_sram_wstrb,
    output [31:0] inst_sram_addr,
    output [31:0] inst_sram_wdata,
    input         inst_sram_addr_ok,
    input         inst_sram_data_ok,
    input  [31:0] inst_sram_rdata,

    //clear stage
    input         fs_ex,

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
    input         fs_cancel_in,
    input  [31:0] cancel_pc,  //actually pc of TLBR/TLBWI
    input         exception_is_tlb_refill_in
);
wire        fs_use_tlb;  //mapped addr

wire        preif_ready_go;

reg         fs_valid;
wire        fs_ready_go;
wire        fs_allowin;
wire        to_fs_valid;

wire [31:0] seq_pc;
wire [31:0] nextpc;

wire        preif_has_exception;
reg         preif_has_exception_r;

wire        fs_has_exception;
wire [ 4:0] fs_exception_type;

reg [31:0] received_inst;
reg [31:0] cancel_pc_r;
reg        inst_valid;
reg        fs_exception_handle;
reg        fs_go_exception_pc;
reg        fs_cancel_handle;
reg        fs_go_cancel_pc;
reg        fs_go_tlb_refill_pc;

reg  [`BR_BUS_WD-1:0] br_bus_r;
reg                   br_bus_r_valid;
wire         br_valid, br_valid_r;  //means brance inst is ID -> EXE...     br_valid_r is useless and not used here
wire         br_taken, br_taken_r;
wire [ 31:0] br_target, br_target_r;
wire         br_stall, br_stall_r;

wire         delay_slot_in_preif;
reg          delay_slot_in_preif_r;
assign delay_slot_in_preif = br_taken & ~fs_valid;                   //delay_slot_in_preif   MEANS    delay slot inst has been in PREIF for more than one clk
always @(posedge clk) begin                                          //                               branch inst in ID , no inst in IF, indicates delay slot didnt go to IF but stay in PREIF...
    if(reset)
        delay_slot_in_preif_r <= 1'b0;
    else if(preif_ready_go & fs_allowin)                            //delay slot go to IF
        delay_slot_in_preif_r <= 1'b0;
    else if(delay_slot_in_preif)
        delay_slot_in_preif_r <= 1'b1;
end

reg          br_target_in_preif_r;                                  //br_target_in_preif_r   MEANS    br target in preif, nothing to do with how long it has been in preif...
always @(posedge clk) begin
    if(reset)
        br_target_in_preif_r <= 1'b0;
    else if(fs_ex | fs_go_exception_pc)                            //exception so, ignore br_target... 
        br_target_in_preif_r <= 1'b0;
    else if(fs_cancel_in | fs_go_cancel_pc)   
        br_target_in_preif_r <= 1'b0;                             //when daley slot go to IF, br target in preif     OR      branch inst in ID and delay slot in IF, but branch target still waiting 
    else if(((delay_slot_in_preif | delay_slot_in_preif_r) & preif_ready_go & fs_allowin) | (br_taken & fs_valid & ~preif_ready_go))
        br_target_in_preif_r <= 1'b1;
    else if(preif_ready_go & fs_allowin)                            //br target go to IF
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
    else if(fs_ex)                      //do not use br_target when exception comes
        br_bus_r[33] <= 1'b0;           //br_taken_r
    else if(fs_cancel_in) 
        br_bus_r[33] <= 1'b0; 
    else if(br_taken)
        br_bus_r[33] <= br_taken;
end

always @(posedge clk) begin
    if(reset)
        br_bus_r_valid <= 1'b0;
    else if(~(delay_slot_in_preif_r | delay_slot_in_preif) & preif_ready_go & fs_allowin)   //br_target from preif to IF, so do not need br_target
        br_bus_r_valid <= 1'b0;
    else if(br_valid)
        br_bus_r_valid <= 1'b1;
end
assign {br_valid_r,br_taken_r,br_target_r,br_stall_r} = br_bus_r;

wire [31:0] fs_inst;
reg  [31:0] fs_pc;

wire        exception_adel;
wire        fs_exception_tlb_refill;
wire        fs_exception_tlb_invalid;
wire [31:0] fs_badvaddr;
wire        exception_is_tlb_refill;

assign fs_to_ds_bus = {exception_is_tlb_refill, //102:102
                       fs_badvaddr      ,  //101:70
                       fs_has_exception ,  //69:69
                       fs_exception_type,  //68:64
                       fs_inst          ,  //63:32
                       fs_pc               //31:0
                       };

always @(posedge clk) begin                                //we need a register to hold nextpc=380 when exception comes
    if (reset) begin
        fs_go_exception_pc <= 1'b0;
    end 
    else if (fs_ex) begin
        fs_go_exception_pc <= 1'b1;
    end
    else if(inst_sram_req & inst_sram_addr_ok) begin       //read request accepted, no need to hold nextpc=380 now
        fs_go_exception_pc <= 1'b0;
    end
end

always @(posedge clk) begin                                
    if (reset) begin
        fs_go_cancel_pc <= 1'b0;
    end 
    else if (fs_cancel_in) begin
        fs_go_cancel_pc <= 1'b1;
    end
    else if(inst_sram_req & inst_sram_addr_ok) begin      
        fs_go_cancel_pc <= 1'b0;
    end
end

always @(posedge clk) begin                                
    if (reset) begin
        fs_go_tlb_refill_pc <= 1'b0;
    end 
    else if (fs_ex & exception_is_tlb_refill_in) begin
        fs_go_tlb_refill_pc <= 1'b1;
    end
    else if(inst_sram_req & inst_sram_addr_ok) begin      
        fs_go_tlb_refill_pc <= 1'b0;
    end
end

// pre-IF stage
assign preif_ready_go = (~br_stall) && (inst_sram_req & inst_sram_addr_ok);  //read request accepted
assign to_fs_valid    = ~reset && preif_ready_go;
assign seq_pc         = fs_pc + 3'h4;
assign nextpc         = ((fs_ex & exception_is_tlb_refill_in) | (fs_go_tlb_refill_pc)) ? 32'hbfc00200 :
                        (fs_ex | fs_go_exception_pc) ? 32'hbfc00380 :               // exception entrance may stall...
                        fs_cancel_in ? (cancel_pc + 3'b100) :
                        fs_go_cancel_pc ? (cancel_pc_r + 3'b100) :
                        (br_taken & fs_valid) ? br_target :                         // branch inst in ID, delay slot in IF, br target in preif waiting for addr_ok
                        //(br_taken_r & br_bus_r_valid & fs_valid) ? br_target_r :  // branch inst gone 
                        //((br_taken) && ~(~fs_valid && (br_valid))) ? br_target :           // WRONG!!! what if branch stay in ID and delay slot in preIF?
                        //((br_taken_r & br_bus_r_valid) && ~(~fs_valid && (br_bus_r_valid))) ? br_target_r :  
                        (br_target_in_preif_r) ? br_target_r : 
                        seq_pc;                                         //if delay slot in preif, go pc+4

// IF stage


assign fs_ready_go    = ~(fs_exception_handle | fs_cancel_handle)  &&       //exception
                       (inst_sram_data_ok || inst_valid);                   //receive read data
                       //~((br_valid || br_bus_r_valid) && ~preif_ready_go);  //branch delay slot
                       //~((br_bus_r_valid) && ~preif_ready_go);
assign fs_allowin     = !fs_valid || fs_ready_go && ds_allowin;
assign fs_to_ds_valid =  fs_valid && fs_ready_go;

always @(posedge clk) begin                              //we need a register to hold read data from inst sram...
    if(reset) begin
        received_inst <= 32'b0;
    end
    else if(inst_sram_data_ok) begin
        received_inst <= inst_sram_rdata;
    end
end

always @(posedge clk) begin                              //we need a register to hold cancel pc
    if(reset) begin
        cancel_pc_r <= 32'b0;
    end
    else if(fs_cancel_in) begin
        cancel_pc_r <= cancel_pc;
    end
end

always @(posedge clk) begin                             //and a register to indicate whether inst in register received_inst is valid or not
    if(reset) begin
        inst_valid <= 1'b0;
    end
    else if (fs_ex | fs_exception_handle)               //problem occurs when exception comes but read request already accepted, which means we will receive an inst before the inst of 380
        inst_valid <= 1'b0;                             //do not use it , because we are going to use inst from 380 
    else if (fs_cancel_in | fs_cancel_handle)               
        inst_valid <= 1'b0;  
    else if(fs_ready_go && ds_allowin) begin
        inst_valid <= 1'b0;
    end
    else if(inst_sram_data_ok) begin
        inst_valid <= 1'b1;
    end    
end

always @(posedge clk) begin                             //this register is to handle the same problem as mentioned above.... but only itself didnt handle it.         copied from handbook
    if (reset) begin                                    //make fs_ready_go 0 when this register is 1
        fs_exception_handle <= 1'b0;
    end 
    else if (fs_ex) begin
        if(to_fs_valid || ((~fs_allowin) && (~fs_ready_go))) begin   //conditions when the problem occurs 
            fs_exception_handle <= 1'b1;
        end
    end 
    else if (inst_sram_data_ok) begin
        fs_exception_handle <= 1'b0;
    end
end

always @(posedge clk) begin                              
    if (reset) begin                                    
        fs_cancel_handle <= 1'b0;
    end 
    else if (fs_cancel_in) begin
        if(to_fs_valid || ((~fs_allowin) && (~fs_ready_go))) begin   
            fs_cancel_handle <= 1'b1;
        end
    end 
    else if (inst_sram_data_ok) begin
        fs_cancel_handle <= 1'b0;
    end
end

always @(posedge clk) begin
    if (reset) begin
        fs_valid <= 1'b0;
    end
    else if (fs_ex) begin
        fs_valid <= 1'b0;
    end
    else if (fs_cancel_in) begin
        fs_valid <= 1'b0;
    end
    else if (fs_allowin) begin
        fs_valid <= to_fs_valid;
    end

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

assign fs_use_tlb = ~(nextpc[31] && ~nextpc[30]);

assign inst_sram_req     = fs_allowin && ~reset && (~fs_ex) && (~br_stall);  //to_fs_valid && fs_allowin;
assign inst_sram_wr      = 1'b0;
assign inst_sram_size    = 2'b10;
assign inst_sram_wstrb   = 4'h0;

assign inst_sram_addr    = fs_use_tlb ? {s0_pfn, nextpc[11:0]} : {3'b0, nextpc[28:0]};  //TODO: what if tlb didnt hit? which addr to use?

assign inst_sram_wdata   = 32'b0;

assign fs_inst           = inst_sram_data_ok       ?  inst_sram_rdata :
                          (inst_valid & fs_valid   ?  received_inst : 32'b0);

assign preif_has_exception  = fs_exception_tlb_refill || fs_exception_tlb_invalid;

always @(posedge clk) begin
    if (reset) begin
        preif_has_exception_r <= 0;
    end
    if (preif_ready_go & fs_allowin) begin
        preif_has_exception_r <= preif_has_exception;
    end
end

assign exception_adel    = ~(seq_pc[1:0] == 0);
assign fs_exception_tlb_refill = ~s0_found & fs_use_tlb;
assign fs_exception_tlb_invalid = s0_found & ~s0_v & fs_use_tlb;
assign fs_has_exception  = exception_adel | preif_has_exception_r;
assign fs_exception_type = exception_adel ?        5'h4 :
                           preif_has_exception_r ? 5'h2 : 
                                                   5'h9 ;

assign fs_badvaddr = exception_adel ? seq_pc - 3'h4 : 
                     (fs_exception_tlb_refill || fs_exception_tlb_invalid) ? nextpc : 32'b0 ;

assign exception_is_tlb_refill = fs_exception_tlb_refill;

endmodule
