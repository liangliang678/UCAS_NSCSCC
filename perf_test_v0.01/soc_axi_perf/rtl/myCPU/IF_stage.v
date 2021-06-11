`include "mycpu.h"

module if_stage(
    input                          clk            ,
    input                          reset          ,

    //preIF
    input                          to_fs_valid    ,
    output                         fs_has_inst    ,
    output                         fs_allowin     ,
    input  [`PF_TO_FS_BUS_WD -1:0] preif_to_fs_bus,
    //allwoin
    input                          ds_allowin     ,
    //to ds
    output                         fs_to_ds_valid ,
    output [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus   ,

    // input         inst_sram_data_ok,
    // input  [31:0] inst_sram_rdata,

    //icache output
    input            inst_cache_data_ok,
    input [ 31:0]    inst_cache_rdata,

    //clear stage
    input         fs_ex,
    //reflush
    input         fs_cancel_in
);

reg  [`PF_TO_FS_BUS_WD -1:0] preif_to_fs_bus_r;
reg         fs_valid;
wire        fs_ready_go;

wire [31:0] fs_pc;
wire        fs_has_exception;
wire [ 4:0] fs_exception_type;
wire [31:0] fs_badvaddr;
wire        exception_is_tlb_refill;

reg [31:0] received_inst;
reg        inst_valid;
reg        fs_exception_handle;
reg        fs_cancel_handle;

wire [31:0] fs_inst;

always @(posedge clk)begin
    if(to_fs_valid && fs_allowin)
        preif_to_fs_bus_r <= preif_to_fs_bus; 
end

assign {exception_is_tlb_refill,
        fs_badvaddr,
        fs_has_exception,
        fs_exception_type,
        fs_pc
       } = preif_to_fs_bus_r;

assign fs_to_ds_bus = {exception_is_tlb_refill, //111:111
                       fs_badvaddr      ,  //110:79
                       fs_has_exception ,  //78:78
                       fs_exception_type,  //77:64
                       fs_inst          ,  //63:32
                       fs_pc               //31:0
                       };

// IF stage
assign fs_ready_go  = ~(fs_exception_handle | fs_cancel_handle)  &       //exception
                       (inst_cache_data_ok | inst_valid);                   //receive read data

assign fs_allowin     = ~fs_valid | fs_ready_go & ds_allowin;
assign fs_to_ds_valid =  fs_valid & fs_ready_go;

always @(posedge clk) begin
    if (reset) begin
        fs_valid <= 1'b0;
    end
    else if (fs_ex || fs_cancel_in) begin
        fs_valid <= 1'b0;
    end
    else if (fs_allowin) begin
        fs_valid <= to_fs_valid;
    end
end

assign fs_has_inst = fs_valid;

always @(posedge clk) begin                              //we need a register to hold read data from inst sram...
    if(reset) begin
        received_inst <= 32'b0;
    end
    else if(inst_cache_data_ok) begin
        received_inst <= inst_cache_rdata;
    end
end

always @(posedge clk) begin                             //and a register to indicate whether inst in register received_inst is valid or not
    if(reset) begin
        inst_valid <= 1'b0;
    end
    else if (fs_ex || fs_exception_handle)               //problem occurs when exception comes but read request already accepted, which means we will receive an inst before the inst of 380
        inst_valid <= 1'b0;                             //do not use it , because we are going to use inst from 380 
    else if (fs_cancel_in || fs_cancel_handle)               
        inst_valid <= 1'b0;  
    else if(fs_ready_go && ds_allowin) begin
        inst_valid <= 1'b0;
    end
    else if(inst_cache_data_ok) begin
        inst_valid <= 1'b1;
    end    
end

always @(posedge clk) begin                             //this register is to handle the same problem as mentioned above.... but only itself didnt handle it.         copied from handbook
    if (reset) begin                                    //make fs_ready_go 0 when this register is 1
        fs_exception_handle <= 1'b0;
    end 
    else if (fs_ex) begin
        if(to_fs_valid || ((!fs_allowin) && (!fs_ready_go))) begin   //conditions when the problem occurs 
            fs_exception_handle <= 1'b1;
        end
    end 
    else if (inst_cache_data_ok) begin
        fs_exception_handle <= 1'b0;
    end
end

always @(posedge clk) begin                              
    if (reset) begin                                    
        fs_cancel_handle <= 1'b0;
    end 
    else if (fs_cancel_in) begin
        if(to_fs_valid || ((!fs_allowin) && (!fs_ready_go))) begin   
            fs_cancel_handle <= 1'b1;
        end
    end 
    else if (inst_cache_data_ok) begin
        fs_cancel_handle <= 1'b0;
    end
end

assign fs_inst           = inst_cache_data_ok       ?  inst_cache_rdata :
                          (inst_valid & fs_valid   ?  received_inst : 32'b0);

endmodule