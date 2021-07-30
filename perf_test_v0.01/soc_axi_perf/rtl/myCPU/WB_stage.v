`include "mycpu.h"

module wb_stage(
    input                            clk           ,
    input                            reset         ,
    //allowin
    output                           ws_allowin    ,
    //from ms
    input                            ms_to_ws_valid,
    input  [`MS_TO_WS_BUS_WD -1:0]   ms_to_ws_bus  ,

    //to rf: for write back
    output [`WS_TO_RF_BUS_WD -1:0]   ws_to_rf_bus  ,

    //relevant bus
    output [`WS_FORWARD_BUS_WD -1:0] ws_forward_bus,

    //trace debug interface
    output [31:0] debug_wb_pc     ,
    output [ 3:0] debug_wb_rf_wen ,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
);

reg         ws_valid;
wire        ws_ready_go;

reg [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus_r;

wire        inst2_valid;
wire [31:0] inst2_pc;
wire        inst2_gr_we;
wire [ 4:0] inst2_dest;
wire [31:0] inst2_final_result;
wire [31:0] inst1_pc;
wire        inst1_gr_we;
wire [ 4:0] inst1_dest;
wire [31:0] inst1_final_result;

reg         double_write_wait;
wire        inst1_write;
wire        inst2_write;
wire        double_write;
wire        write_same_reg;

assign {inst2_valid,
        inst2_gr_we,
        inst2_dest,
        inst2_final_result,
        inst2_pc,

        inst1_gr_we,
        inst1_dest,
        inst1_final_result,
        inst1_pc
       } = ms_to_ws_bus_r;

assign ws_ready_go = ~double_write | double_write & double_write_wait;
assign ws_allowin  = !ws_valid || ws_ready_go;
always @(posedge clk) begin
    if (reset) begin
        ws_valid <= 1'b0;
    end
    else if (ws_allowin) begin
        ws_valid <= ms_to_ws_valid;
    end

    if (ms_to_ws_valid && ws_allowin) begin
        ms_to_ws_bus_r <= ms_to_ws_bus;
    end
end

wire        rf_we_01;
wire [ 4:0] rf_waddr_01;
wire [31:0] rf_wdata_01;
wire        rf_we_02;
wire [ 4:0] rf_waddr_02;
wire [31:0] rf_wdata_02;

assign ws_to_rf_bus = {rf_we_02, rf_waddr_02, rf_wdata_02, 
                       rf_we_01, rf_waddr_01, rf_wdata_01 };

assign inst1_write = ws_valid & inst1_gr_we;
assign inst2_write = ws_valid & inst2_gr_we & inst2_valid;
assign double_write = inst1_write & inst2_write;
assign write_same_reg = double_write & (inst2_dest == inst1_dest);

always @(posedge clk) begin
    if (reset) begin
        double_write_wait <= 1'b0;
    end
    else if (double_write & double_write_wait == 1'b0) begin
        double_write_wait <= 1'b1;
    end
    else if (double_write_wait == 1'b1) begin
        double_write_wait <= 1'b0;
    end
end

//assign rf_we_01    = inst1_write | inst2_write;
//assign rf_waddr_01 = {5{double_write & ~double_write_wait | ~double_write & inst1_write}} & inst1_dest | 
                     //{5{double_write & double_write_wait  | ~double_write & inst2_write}} & inst2_dest;

//assign rf_wdata_01 = {32{double_write & ~double_write_wait | ~double_write & inst1_write}} & inst1_final_result | 
                     //{32{double_write & double_write_wait  | ~double_write & inst2_write}} & inst2_final_result;

//assign rf_we_02    = 1'b0;
//assign rf_waddr_02 = 5'b0;
//assign rf_wdata_02 = 32'b0;

assign rf_we_01    = inst1_write;
assign rf_waddr_01 = inst1_dest;
assign rf_wdata_01 = write_same_reg ? inst2_final_result : inst1_final_result;
assign rf_we_02    = write_same_reg ? 1'b0 : inst2_write;
assign rf_waddr_02 = inst2_dest;
assign rf_wdata_02 = inst2_final_result;

// debug info generate
assign debug_wb_pc       = {32{double_write & ~double_write_wait | ~double_write & inst1_write}} & inst1_pc | 
                           {32{double_write & double_write_wait  | ~double_write & inst2_write}} & inst2_pc;
assign debug_wb_rf_wen   = {4{rf_we_01}};
assign debug_wb_rf_wnum  = rf_waddr_01;
assign debug_wb_rf_wdata = rf_wdata_01;

// ws_forward_bus
assign ws_forward_bus = { ws_valid, 
                          inst1_gr_we, inst1_dest, inst1_final_result, 
                          inst2_gr_we, inst2_dest, inst2_final_result };

endmodule
