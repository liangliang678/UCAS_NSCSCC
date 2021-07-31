`include "mycpu.h"

`define WAIT_PREIF       4'b0001
`define RECV_INST        4'b0010
`define RECV_NO_INST     4'b0100
`define CLEAR_ALL        4'b1000

module if_stage(
    input                          clk,
    input                          reset,

    //preIF
    input                          to_fs_valid,
    output                         fs_allowin,
    input                          fs_no_inst_wait,
    input  [`PF_TO_FS_BUS_WD -1:0] preif_to_fs_bus,
    output [ 5:0]                  fs_to_preif_offset,
    //allwoin
    input                          ds_allowin,
    input                          ds_branch,
    input  [31:0]                  ds_rf_rdata1,
    input  [31:0]                  ds_rf_rdata2,
    //to ds
    output                         fs_to_ds_valid,
    output [ 4:0]                  fs_rf_raddr1,
    output [ 4:0]                  fs_rf_raddr2,
    output [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus,

    //relevant bus
    input  [`DS_FORWARD_BUS_WD -1:0] ds_forward_bus,
    input  [`ES_FORWARD_BUS_WD -1:0] es_forward_bus,
    input  [`PMS_FORWARD_BUS_WD -1:0] pms_forward_bus,
    input  [`MS_FORWARD_BUS_WD -1:0] ms_forward_bus,
    input  [`WS_FORWARD_BUS_WD -1:0] ws_forward_bus,

    //icache output
    input                          inst_cache_data_ok,
    input [   3:0]                 inst_cache_data_num,
    input [ 255:0]                 inst_cache_rdata,

    //clear stage
    input                          clear_all
);

reg  [`PF_TO_FS_BUS_WD -1:0] preif_to_fs_bus_r;
wire        fs_ready_go;
wire        fs_inst1_readygo;

wire [31:0] fs_pc;
wire        fs_except;
wire [ 4:0] fs_exccode;
wire        fs_refill;

reg  [ 31:0] fifo_inst    [15:0];
reg  [ 31:0] fifo_pc      [15:0];
reg          fifo_except  [15:0];
reg  [  4:0] fifo_exccode [15:0];
reg          fifo_refill  [15:0];

reg  [ 3:0] head;
reg  [ 3:0] tail;

wire        fifo_empty;
wire        fifo_full;
wire        fifo_allowin;
wire        fifo_readygo;
wire [ 4:0] fifo_sub;

reg  [ 3:0] fs_state;

always @(posedge clk)begin
    if(to_fs_valid && fs_allowin)
        preif_to_fs_bus_r <= preif_to_fs_bus; 
end

assign {fs_refill,
        fs_except,
        fs_exccode,
        fs_pc
       } = preif_to_fs_bus_r;

wire [31:0] inst1_pc;
wire [31:0] inst1_inst;
wire        inst1_except;
wire [ 4:0] inst1_exccode;
wire        inst1_refill;

wire [ 5:0] inst1_op;
wire [ 4:0] inst1_rs;
wire [ 4:0] inst1_rt;
wire [ 4:0] inst1_rd;
wire [ 4:0] inst1_sa;
wire [ 5:0] inst1_func;
wire [15:0] inst1_imm;
wire [25:0] inst1_jidx;

wire [63:0] inst1_op_d;
wire [31:0] inst1_rs_d;
wire [31:0] inst1_rt_d;
wire [31:0] inst1_rd_d;
wire [31:0] inst1_sa_d;
wire [63:0] inst1_func_d;

wire [31:0] inst1_br_rs_value;
wire [31:0] inst1_br_rt_value;

wire        inst1_br;
wire        inst2_br;

wire        self_relevant;
wire        single_shoot;

wire [31:0] inst2_pc;
wire [31:0] inst2_inst;
wire        inst2_except;
wire [ 4:0] inst2_exccode;
wire        inst2_refill;
wire        inst2_valid;

wire [ 5:0] inst2_op_final;
wire [ 4:0] inst2_rs_final;
wire [ 4:0] inst2_rt_final;
wire [ 4:0] inst2_rd_final;
wire [ 4:0] inst2_sa_final;
wire [ 5:0] inst2_func_final;
wire [15:0] inst2_imm_final;
wire [25:0] inst2_jidx_final;

wire [63:0] inst2_op_d_final;
wire [31:0] inst2_rs_d_final;
wire [31:0] inst2_rt_d_final;
wire [31:0] inst2_rd_d_final;
wire [31:0] inst2_sa_d_final;
wire [63:0] inst2_func_d_final;

assign fs_to_ds_bus = { inst2_valid,

                        inst2_op_final,
                        inst2_rs_final,
                        inst2_rt_final,
                        inst2_rd_final,
                        inst2_sa_final,
                        inst2_func_final,
                        inst2_imm_final,
                        inst2_jidx_final,
                        inst2_op_d_final,
                        inst2_rs_d_final,
                        inst2_rt_d_final,
                        inst2_rd_d_final,
                        inst2_sa_d_final,
                        inst2_func_d_final,

                        inst2_refill,
                        inst2_except,
                        inst2_exccode,
                        inst2_inst,
                        inst2_pc,

                        inst1_br_rs_value,
                        inst1_br_rt_value,

                        inst1_op,
                        inst1_rs,
                        inst1_rt,
                        inst1_rd,
                        inst1_sa,
                        inst1_func,
                        inst1_imm,
                        inst1_jidx,
                        inst1_op_d,
                        inst1_rs_d,
                        inst1_rt_d,
                        inst1_rd_d,
                        inst1_sa_d,
                        inst1_func_d,

                        inst1_refill,
                        inst1_except,
                        inst1_exccode,
                        inst1_inst,
                        inst1_pc
                      };

// IF stage
assign fs_ready_go = fifo_readygo & fs_inst1_readygo;

assign fs_allowin     = (fs_state == `WAIT_PREIF) & fifo_allowin;
assign fs_to_ds_valid =  ~((fs_state == `CLEAR_ALL) | clear_all | ds_branch) & fs_ready_go;

always @(posedge clk) begin
    if (reset) begin
        fs_state <= `WAIT_PREIF;
    end
    else begin
        case(fs_state)
        `WAIT_PREIF: begin
            if (to_fs_valid && fs_allowin && (clear_all || ds_branch)) begin
                //fs_state <= `CLEAR_ALL;
                fs_state <= `RECV_INST;
            end
            else if (to_fs_valid && fs_allowin && !fs_no_inst_wait) begin
                fs_state <= `RECV_INST;
            end
            else if(to_fs_valid && fs_allowin && fs_no_inst_wait) begin
                fs_state <= `RECV_NO_INST;
            end
            else begin
                fs_state <= `WAIT_PREIF;
            end
        end
        `RECV_INST: begin
            if (inst_cache_data_ok) begin
                fs_state <= `WAIT_PREIF;
            end
            else if (clear_all || ds_branch) begin
                fs_state <= `CLEAR_ALL;
            end
            else begin
                fs_state <= `RECV_INST;
            end
        end
        `RECV_NO_INST: begin
            fs_state <= `WAIT_PREIF;
        end
        `CLEAR_ALL: begin
            if (inst_cache_data_ok) begin
                fs_state <= `WAIT_PREIF;
            end
            else begin
                fs_state <= `CLEAR_ALL;
            end
        end
        default:
		    fs_state <= `WAIT_PREIF;
	    endcase
    end
end

wire [3:0] head_1;
wire [3:0] tail_1;
wire [3:0] tail_2;
wire [3:0] tail_3;
wire [3:0] tail_4;
wire [3:0] tail_5;
wire [3:0] tail_6;
wire [3:0] tail_7;
wire [31:0] fs_pc_4;
wire [31:0] fs_pc_8;
wire [31:0] fs_pc_12;
wire [31:0] fs_pc_16;
wire [31:0] fs_pc_20;
wire [31:0] fs_pc_24;
wire [31:0] fs_pc_28;

assign head_1 = head + 4'd1;
assign tail_1 = tail + 4'd1;
assign tail_2 = tail + 4'd2;
assign tail_3 = tail + 4'd3;
assign tail_4 = tail + 4'd4;
assign tail_5 = tail + 4'd5;
assign tail_6 = tail + 4'd6;
assign tail_7 = tail + 4'd7;

assign fs_pc_4  = fs_pc + 5'd4;
assign fs_pc_8  = fs_pc + 5'd8;
assign fs_pc_12 = fs_pc + 5'd12;
assign fs_pc_16 = fs_pc + 5'd16;
assign fs_pc_20 = fs_pc + 5'd20;
assign fs_pc_24 = fs_pc + 5'd24;
assign fs_pc_28 = fs_pc + 5'd28;

always @(posedge clk) begin
    if (reset) begin
        tail <= 4'b0;
    end
    else begin
        if (clear_all || ds_branch) begin
            tail <= 4'b0;
        end
        else if (fs_state == `RECV_INST && inst_cache_data_ok) begin
            tail <= tail + inst_cache_data_num;
        end
        else if (fs_state == `RECV_NO_INST) begin
            tail <= tail_2;
        end
    end
end

always @(posedge clk) begin
    if (reset) begin
        head <= 4'b0;
    end
    else begin
        if (clear_all || ds_branch) begin
            head <= 4'b0;
        end
        else if (fs_to_ds_valid && ds_allowin) begin
            if (single_shoot) begin
                head <= head + 4'd1;
            end
            else begin
                head <= head + 4'd2;
            end
        end
    end
end

assign fifo_empty = (head == tail);
assign fifo_sub = {1'b1, head} - {1'b0, tail};
assign fifo_full = (fifo_sub[3:0] == 4'b0001);
assign fifo_allowin = (fifo_sub[3] == 1'b1) & (fifo_sub[2:0] != 3'b0) | fifo_empty;
assign fifo_readygo = (fifo_sub[3:0] != 4'b1111) & ~fifo_empty;

reg [5:0] pc_offset;

always @(posedge clk) begin
    if (reset) begin
        pc_offset <= 6'd4;
    end
    else begin
        if (clear_all || ds_branch) begin
            pc_offset <= 6'd4;
        end
        else if (fs_state == `RECV_INST && inst_cache_data_ok) begin
            pc_offset <= {inst_cache_data_num, 2'b00};
        end
    end
end

assign fs_to_preif_offset = pc_offset;

always @(posedge clk) begin
    if (fs_state == `RECV_INST && inst_cache_data_ok && !(clear_all || ds_branch)) begin
        case (inst_cache_data_num)
        4'd1: begin
            fifo_inst[tail]      <= inst_cache_rdata[ 31:  0];
            fifo_pc[tail]        <= fs_pc;
            fifo_except[tail]    <= fs_except;
            fifo_exccode[tail]   <= fs_exccode;
            fifo_refill[tail]    <= fs_refill;
        end
        4'd2: begin
            fifo_inst[tail]      <= inst_cache_rdata[ 31:  0];
            fifo_inst[tail_1]    <= inst_cache_rdata[ 63: 32];

            fifo_pc[tail]        <= fs_pc;
            fifo_pc[tail_1]      <= fs_pc_4;

            fifo_except[tail]    <= fs_except;
            fifo_except[tail_1]  <= fs_except;

            fifo_exccode[tail]   <= fs_exccode;
            fifo_exccode[tail_1] <= fs_exccode;

            fifo_refill[tail]    <= fs_refill;
            fifo_refill[tail_1]  <= fs_refill;
        end
        4'd3: begin
            fifo_inst[tail]      <= inst_cache_rdata[ 31:  0];
            fifo_inst[tail_1]    <= inst_cache_rdata[ 63: 32];
            fifo_inst[tail_2]    <= inst_cache_rdata[ 95: 64];

            fifo_pc[tail]        <= fs_pc;
            fifo_pc[tail_1]      <= fs_pc_4;
            fifo_pc[tail_2]      <= fs_pc_8;

            fifo_except[tail]    <= fs_except;
            fifo_except[tail_1]  <= fs_except;
            fifo_except[tail_2]  <= fs_except;

            fifo_exccode[tail]   <= fs_exccode;
            fifo_exccode[tail_1] <= fs_exccode;
            fifo_exccode[tail_2] <= fs_exccode;

            fifo_refill[tail]    <= fs_refill;
            fifo_refill[tail_1]  <= fs_refill;
            fifo_refill[tail_2]  <= fs_refill;
        end
        4'd4: begin
            fifo_inst[tail]      <= inst_cache_rdata[ 31:  0];
            fifo_inst[tail_1]    <= inst_cache_rdata[ 63: 32];
            fifo_inst[tail_2]    <= inst_cache_rdata[ 95: 64];
            fifo_inst[tail_3]    <= inst_cache_rdata[127: 96];

            fifo_pc[tail]        <= fs_pc;
            fifo_pc[tail_1]      <= fs_pc_4;
            fifo_pc[tail_2]      <= fs_pc_8;
            fifo_pc[tail_3]      <= fs_pc_12;

            fifo_except[tail]    <= fs_except;
            fifo_except[tail_1]  <= fs_except;
            fifo_except[tail_2]  <= fs_except;
            fifo_except[tail_3]  <= fs_except;

            fifo_exccode[tail]   <= fs_exccode;
            fifo_exccode[tail_1] <= fs_exccode;
            fifo_exccode[tail_2] <= fs_exccode;
            fifo_exccode[tail_3] <= fs_exccode;

            fifo_refill[tail]    <= fs_refill;
            fifo_refill[tail_1]  <= fs_refill;
            fifo_refill[tail_2]  <= fs_refill;
            fifo_refill[tail_3]  <= fs_refill;
        end
        4'd5: begin
            fifo_inst[tail]      <= inst_cache_rdata[ 31:  0];
            fifo_inst[tail_1]    <= inst_cache_rdata[ 63: 32];
            fifo_inst[tail_2]    <= inst_cache_rdata[ 95: 64];
            fifo_inst[tail_3]    <= inst_cache_rdata[127: 96];
            fifo_inst[tail_4]    <= inst_cache_rdata[159:128];

            fifo_pc[tail]        <= fs_pc;
            fifo_pc[tail_1]      <= fs_pc_4;
            fifo_pc[tail_2]      <= fs_pc_8;
            fifo_pc[tail_3]      <= fs_pc_12;
            fifo_pc[tail_4]      <= fs_pc_16;

            fifo_except[tail]    <= fs_except;
            fifo_except[tail_1]  <= fs_except;
            fifo_except[tail_2]  <= fs_except;
            fifo_except[tail_3]  <= fs_except;
            fifo_except[tail_4]  <= fs_except;

            fifo_exccode[tail]   <= fs_exccode;
            fifo_exccode[tail_1] <= fs_exccode;
            fifo_exccode[tail_2] <= fs_exccode;
            fifo_exccode[tail_3] <= fs_exccode;
            fifo_exccode[tail_4] <= fs_exccode;

            fifo_refill[tail]    <= fs_refill;
            fifo_refill[tail_1]  <= fs_refill;
            fifo_refill[tail_2]  <= fs_refill;
            fifo_refill[tail_3]  <= fs_refill;
            fifo_refill[tail_4]  <= fs_refill;
        end
        4'd6: begin
            fifo_inst[tail]      <= inst_cache_rdata[ 31:  0];
            fifo_inst[tail_1]    <= inst_cache_rdata[ 63: 32];
            fifo_inst[tail_2]    <= inst_cache_rdata[ 95: 64];
            fifo_inst[tail_3]    <= inst_cache_rdata[127: 96];
            fifo_inst[tail_4]    <= inst_cache_rdata[159:128];
            fifo_inst[tail_5]    <= inst_cache_rdata[191:160];

            fifo_pc[tail]        <= fs_pc;
            fifo_pc[tail_1]      <= fs_pc_4;
            fifo_pc[tail_2]      <= fs_pc_8;
            fifo_pc[tail_3]      <= fs_pc_12;
            fifo_pc[tail_4]      <= fs_pc_16;
            fifo_pc[tail_5]      <= fs_pc_20;

            fifo_except[tail]    <= fs_except;
            fifo_except[tail_1]  <= fs_except;
            fifo_except[tail_2]  <= fs_except;
            fifo_except[tail_3]  <= fs_except;
            fifo_except[tail_4]  <= fs_except;
            fifo_except[tail_5]  <= fs_except;

            fifo_exccode[tail]   <= fs_exccode;
            fifo_exccode[tail_1] <= fs_exccode;
            fifo_exccode[tail_2] <= fs_exccode;
            fifo_exccode[tail_3] <= fs_exccode;
            fifo_exccode[tail_4] <= fs_exccode;
            fifo_exccode[tail_5] <= fs_exccode;

            fifo_refill[tail]    <= fs_refill;
            fifo_refill[tail_1]  <= fs_refill;
            fifo_refill[tail_2]  <= fs_refill;
            fifo_refill[tail_3]  <= fs_refill;
            fifo_refill[tail_4]  <= fs_refill;
            fifo_refill[tail_5]  <= fs_refill;
        end
        4'd7: begin
            fifo_inst[tail]      <= inst_cache_rdata[ 31:  0];
            fifo_inst[tail_1]    <= inst_cache_rdata[ 63: 32];
            fifo_inst[tail_2]    <= inst_cache_rdata[ 95: 64];
            fifo_inst[tail_3]    <= inst_cache_rdata[127: 96];
            fifo_inst[tail_4]    <= inst_cache_rdata[159:128];
            fifo_inst[tail_5]    <= inst_cache_rdata[191:160];
            fifo_inst[tail_6]    <= inst_cache_rdata[223:192];

            fifo_pc[tail]        <= fs_pc;
            fifo_pc[tail_1]      <= fs_pc_4;
            fifo_pc[tail_2]      <= fs_pc_8;
            fifo_pc[tail_3]      <= fs_pc_12;
            fifo_pc[tail_4]      <= fs_pc_16;
            fifo_pc[tail_5]      <= fs_pc_20;
            fifo_pc[tail_6]      <= fs_pc_24;

            fifo_except[tail]    <= fs_except;
            fifo_except[tail_1]  <= fs_except;
            fifo_except[tail_2]  <= fs_except;
            fifo_except[tail_3]  <= fs_except;
            fifo_except[tail_4]  <= fs_except;
            fifo_except[tail_5]  <= fs_except;
            fifo_except[tail_6]  <= fs_except;

            fifo_exccode[tail]   <= fs_exccode;
            fifo_exccode[tail_1] <= fs_exccode;
            fifo_exccode[tail_2] <= fs_exccode;
            fifo_exccode[tail_3] <= fs_exccode;
            fifo_exccode[tail_4] <= fs_exccode;
            fifo_exccode[tail_5] <= fs_exccode;
            fifo_exccode[tail_6] <= fs_exccode;

            fifo_refill[tail]    <= fs_refill;
            fifo_refill[tail_1]  <= fs_refill;
            fifo_refill[tail_2]  <= fs_refill;
            fifo_refill[tail_3]  <= fs_refill;
            fifo_refill[tail_4]  <= fs_refill;
            fifo_refill[tail_5]  <= fs_refill;
            fifo_refill[tail_6]  <= fs_refill;
        end
        4'd8: begin
            fifo_inst[tail]      <= inst_cache_rdata[ 31:  0];
            fifo_inst[tail_1]    <= inst_cache_rdata[ 63: 32];
            fifo_inst[tail_2]    <= inst_cache_rdata[ 95: 64];
            fifo_inst[tail_3]    <= inst_cache_rdata[127: 96];
            fifo_inst[tail_4]    <= inst_cache_rdata[159:128];
            fifo_inst[tail_5]    <= inst_cache_rdata[191:160];
            fifo_inst[tail_6]    <= inst_cache_rdata[223:192];
            fifo_inst[tail_7]    <= inst_cache_rdata[255:224];

            fifo_pc[tail]        <= fs_pc;
            fifo_pc[tail_1]      <= fs_pc_4;
            fifo_pc[tail_2]      <= fs_pc_8;
            fifo_pc[tail_3]      <= fs_pc_12;
            fifo_pc[tail_4]      <= fs_pc_16;
            fifo_pc[tail_5]      <= fs_pc_20;
            fifo_pc[tail_6]      <= fs_pc_24;
            fifo_pc[tail_7]      <= fs_pc_28;

            fifo_except[tail]    <= fs_except;
            fifo_except[tail_1]  <= fs_except;
            fifo_except[tail_2]  <= fs_except;
            fifo_except[tail_3]  <= fs_except;
            fifo_except[tail_4]  <= fs_except;
            fifo_except[tail_5]  <= fs_except;
            fifo_except[tail_6]  <= fs_except;
            fifo_except[tail_7]  <= fs_except;

            fifo_exccode[tail]   <= fs_exccode;
            fifo_exccode[tail_1] <= fs_exccode;
            fifo_exccode[tail_2] <= fs_exccode;
            fifo_exccode[tail_3] <= fs_exccode;
            fifo_exccode[tail_4] <= fs_exccode;
            fifo_exccode[tail_5] <= fs_exccode;
            fifo_exccode[tail_6] <= fs_exccode;
            fifo_exccode[tail_7] <= fs_exccode;

            fifo_refill[tail]    <= fs_refill;
            fifo_refill[tail_1]  <= fs_refill;
            fifo_refill[tail_2]  <= fs_refill;
            fifo_refill[tail_3]  <= fs_refill;
            fifo_refill[tail_4]  <= fs_refill;
            fifo_refill[tail_5]  <= fs_refill;
            fifo_refill[tail_6]  <= fs_refill;
            fifo_refill[tail_7]  <= fs_refill;
        end
        endcase
    end
    if (fs_state == `RECV_NO_INST && !(clear_all || ds_branch)) begin
        fifo_inst[tail]       <= 32'b0;
        fifo_pc[tail]         <= fs_pc;
        fifo_except[tail]     <= fs_except;
        fifo_exccode[tail]    <= fs_exccode;
        fifo_refill[tail]     <= fs_refill;

        fifo_inst[tail_1]     <= 32'b0;
        fifo_pc[tail_1]       <= fs_pc_4;
        fifo_except[tail_1]   <= fs_except;
        fifo_exccode[tail_1]  <= fs_exccode;
        fifo_refill[tail_1]   <= fs_refill;
    end
end

wire [31:0] fs_inst1;
wire [31:0] fs_inst2;

assign fs_inst1 = fifo_inst[head];
assign fs_inst2 = fifo_inst[head_1];

// inst 1
wire        inst1_beq;
wire        inst1_bne;
wire        inst1_bgez;
wire        inst1_bgtz;
wire        inst1_blez;
wire        inst1_bltz;
wire        inst1_j;
wire        inst1_bltzal;
wire        inst1_bgezal;
wire        inst1_jal;
wire        inst1_jr;
wire        inst1_jalr;

wire        inst1_lw;
wire        inst1_lwl;
wire        inst1_lwr;
wire        inst1_lb;
wire        inst1_lbu;
wire        inst1_lh;
wire        inst1_lhu;
wire        inst1_mfc0;
wire        inst1_mfhi;
wire        inst1_mflo;

wire        inst1_load_mfc0hilo;
wire [ 4:0] inst1_dest;

assign inst1_op   = fs_inst1[31:26];
assign inst1_rs   = fs_inst1[25:21];
assign inst1_rt   = fs_inst1[20:16];
assign inst1_rd   = fs_inst1[15:11];
assign inst1_sa   = fs_inst1[10: 6];
assign inst1_func = fs_inst1[ 5: 0];
assign inst1_imm  = fs_inst1[15: 0];
assign inst1_jidx = fs_inst1[25: 0];

decoder_6_64 u_dec0(.in(inst1_op  ), .out(inst1_op_d  ));
decoder_6_64 u_dec1(.in(inst1_func), .out(inst1_func_d));
decoder_5_32 u_dec2(.in(inst1_rs  ), .out(inst1_rs_d  ));
decoder_5_32 u_dec3(.in(inst1_rt  ), .out(inst1_rt_d  ));
decoder_5_32 u_dec4(.in(inst1_rd  ), .out(inst1_rd_d  ));
decoder_5_32 u_dec5(.in(inst1_sa  ), .out(inst1_sa_d  ));

assign inst1_beq    = inst1_op_d[6'h04];
assign inst1_bne    = inst1_op_d[6'h05];
assign inst1_bgez   = inst1_op_d[6'h01] & inst1_rt_d[5'h01];
assign inst1_bgtz   = inst1_op_d[6'h07] & inst1_rt_d[5'h00];
assign inst1_blez   = inst1_op_d[6'h06] & inst1_rt_d[5'h00];
assign inst1_bltz   = inst1_op_d[6'h01] & inst1_rt_d[5'h00];
assign inst1_j      = inst1_op_d[6'h02];
assign inst1_bltzal = inst1_op_d[6'h01] & inst1_rt_d[5'h10];
assign inst1_bgezal = inst1_op_d[6'h01] & inst1_rt_d[5'h11];
assign inst1_jal    = inst1_op_d[6'h03];
assign inst1_jr     = inst1_op_d[6'h00] & inst1_func_d[6'h08] & inst1_rt_d[5'h00] & inst1_rd_d[5'h00] & inst1_sa_d[5'h00];
assign inst1_jalr   = inst1_op_d[6'h00] & inst1_func_d[6'h09] & inst1_rt_d[5'h00] & inst1_sa_d[5'h00];

assign inst1_lb     = inst1_op_d[6'h20];
assign inst1_lh     = inst1_op_d[6'h21];
assign inst1_lw     = inst1_op_d[6'h23];
assign inst1_lbu    = inst1_op_d[6'h24];
assign inst1_lhu    = inst1_op_d[6'h25];
assign inst1_lwl    = inst1_op_d[6'h22];
assign inst1_lwr    = inst1_op_d[6'h26];

assign inst1_mfc0   = inst1_op_d[6'h10] & inst1_rs_d[5'h00] & inst1_sa_d[5'h00] & (fs_inst1[5: 3]==3'b0);
assign inst1_mfhi   = inst1_op_d[6'h00] & inst1_func_d[6'h10] & inst1_rs_d[5'h00] & inst1_rt_d[5'h00] & inst1_sa_d[5'h00];
assign inst1_mflo   = inst1_op_d[6'h00] & inst1_func_d[6'h12] & inst1_rs_d[5'h00] & inst1_rt_d[5'h00] & inst1_sa_d[5'h00];

assign inst1_load_mfc0hilo = inst1_lb | inst1_lbu | inst1_lh | inst1_lhu | inst1_lw | inst1_lwl | inst1_lwr | inst1_mfc0 | inst1_mfhi | inst1_mflo;
assign inst1_br = inst1_beq | inst1_bne | inst1_bgez | inst1_bgezal | inst1_bgtz | inst1_blez | inst1_bltz | inst1_bltzal | inst1_j | inst1_jal | inst1_jalr | inst1_jr;

assign inst1_dest = {5{inst1_mfhi | inst1_mflo}} & inst1_rd | {5{~(inst1_mfhi | inst1_mflo)}} & inst1_rt;

assign inst1_pc       = fifo_pc[head];
assign inst1_inst     = fs_inst1;
assign inst1_except   = fifo_except[head];
assign inst1_exccode  = fifo_exccode[head];
assign inst1_refill   = fifo_refill[head];

//relevant & block
wire        ds_valid;
wire        ds_inst1_gr_we;
wire [ 4:0] ds_inst1_dest;
wire        ds_inst2_gr_we;
wire [ 4:0] ds_inst2_dest;

wire        es_valid;
wire        es_inst1_res_valid;
wire        es_inst1_mfhiloc0_load;
wire        es_inst1_gr_we;
wire [ 4:0] es_inst1_dest;
wire [31:0] es_inst1_result;
wire        es_inst2_res_valid;
wire        es_inst2_mfhiloc0_load;
wire        es_inst2_gr_we;
wire [ 4:0] es_inst2_dest;
wire [31:0] es_inst2_result;

wire        pms_valid;
wire        pms_inst1_load;
wire        pms_inst1_gr_we;
wire [ 4:0] pms_inst1_dest;
wire [31:0] pms_inst1_result;
wire        pms_inst2_load;
wire        pms_inst2_gr_we;
wire [ 4:0] pms_inst2_dest;
wire [31:0] pms_inst2_result;

wire        ms_valid;
wire        ms_inst1_res_valid;
wire        ms_inst1_load;
wire        ms_inst1_gr_we;
wire [ 4:0] ms_inst1_dest;
wire [31:0] ms_inst1_result;
wire        ms_inst2_res_valid;
wire        ms_inst2_load;
wire        ms_inst2_gr_we;
wire [ 4:0] ms_inst2_dest;
wire [31:0] ms_inst2_result;

wire        ws_valid;
wire        ws_inst1_gr_we;
wire [ 4:0] ws_inst1_dest;
wire [31:0] ws_inst1_result;
wire        ws_inst2_gr_we;
wire [ 4:0] ws_inst2_dest;
wire [31:0] ws_inst2_result;

wire        r1_need;
wire        r2_need;
wire        ds_inst1_r1_relevant;
wire        ds_inst1_r2_relevant;
wire        ds_inst2_r1_relevant;
wire        ds_inst2_r2_relevant;
wire        es_inst1_r1_relevant;
wire        es_inst1_r2_relevant;
wire        es_inst2_r1_relevant;
wire        es_inst2_r2_relevant;
wire        pms_inst1_r1_relevant;
wire        pms_inst1_r2_relevant;
wire        pms_inst2_r1_relevant;
wire        pms_inst2_r2_relevant;
wire        ms_inst1_r1_relevant;
wire        ms_inst1_r2_relevant;
wire        ms_inst2_r1_relevant;
wire        ms_inst2_r2_relevant;
wire        ws_inst1_r1_relevant;
wire        ws_inst1_r2_relevant;
wire        ws_inst2_r1_relevant;
wire        ws_inst2_r2_relevant;

wire        ds_block;
wire        es_block;
wire        pms_block;
wire        ms_block;

assign {ds_valid, 
        ds_inst1_gr_we, ds_inst1_dest, 
        ds_inst2_gr_we, ds_inst2_dest} = ds_forward_bus;

assign {es_valid, //es_res_valid, 
        es_inst1_res_valid, es_inst1_mfhiloc0_load, es_inst1_gr_we, es_inst1_dest, es_inst1_result, 
        es_inst2_res_valid, es_inst2_mfhiloc0_load, es_inst2_gr_we, es_inst2_dest, es_inst2_result } = es_forward_bus;

assign {pms_valid, 
        pms_inst1_load, pms_inst1_gr_we, pms_inst1_dest, pms_inst1_result, 
        pms_inst2_load, pms_inst2_gr_we, pms_inst2_dest, pms_inst2_result } = pms_forward_bus;

assign {ms_valid, //ms_res_valid, 
        ms_inst1_res_valid, ms_inst1_load, ms_inst1_gr_we, ms_inst1_dest, ms_inst1_result, 
        ms_inst2_res_valid, ms_inst2_load, ms_inst2_gr_we, ms_inst2_dest, ms_inst2_result } = ms_forward_bus;

assign {ws_valid, 
        ws_inst1_gr_we, ws_inst1_dest, ws_inst1_result, 
        ws_inst2_gr_we, ws_inst2_dest, ws_inst2_result } = ws_forward_bus;

assign r1_need = inst1_beq    | inst1_bne    | inst1_bgez | inst1_bgtz  | inst1_blez | inst1_bltz | 
                 inst1_bltzal | inst1_bgezal | inst1_jr   | inst1_jalr;
assign r2_need = inst1_beq  | inst1_bne;

assign ds_inst1_r1_relevant = ~fifo_empty & r1_need & ds_valid & ds_inst1_gr_we & ~inst1_rs_d[5'h00] & (inst1_rs == ds_inst1_dest);
assign ds_inst2_r1_relevant = ~fifo_empty & r1_need & ds_valid & ds_inst2_gr_we & ~inst1_rs_d[5'h00] & (inst1_rs == ds_inst2_dest);
assign es_inst1_r1_relevant = ~fifo_empty & r1_need & es_valid & es_inst1_gr_we & ~inst1_rs_d[5'h00] & (inst1_rs == es_inst1_dest);
assign es_inst2_r1_relevant = ~fifo_empty & r1_need & es_valid & es_inst2_gr_we & ~inst1_rs_d[5'h00] & (inst1_rs == es_inst2_dest);
assign pms_inst1_r1_relevant = ~fifo_empty & r1_need & pms_valid & pms_inst1_gr_we & ~inst1_rs_d[5'h00] & (inst1_rs == pms_inst1_dest);
assign pms_inst2_r1_relevant = ~fifo_empty & r1_need & pms_valid & pms_inst2_gr_we & ~inst1_rs_d[5'h00] & (inst1_rs == pms_inst2_dest);
assign ms_inst1_r1_relevant = ~fifo_empty & r1_need & ms_valid & ms_inst1_gr_we & ~inst1_rs_d[5'h00] & (inst1_rs == ms_inst1_dest);
assign ms_inst2_r1_relevant = ~fifo_empty & r1_need & ms_valid & ms_inst2_gr_we & ~inst1_rs_d[5'h00] & (inst1_rs == ms_inst2_dest);
assign ws_inst1_r1_relevant = ~fifo_empty & r1_need & ws_valid & ws_inst1_gr_we & ~inst1_rs_d[5'h00] & (inst1_rs == ws_inst1_dest);
assign ws_inst2_r1_relevant = ~fifo_empty & r1_need & ws_valid & ws_inst2_gr_we & ~inst1_rs_d[5'h00] & (inst1_rs == ws_inst2_dest);

assign ds_inst1_r2_relevant = ~fifo_empty & r2_need & ds_valid & ds_inst1_gr_we & ~inst1_rt_d[5'h00] & (inst1_rt == ds_inst1_dest);
assign ds_inst2_r2_relevant = ~fifo_empty & r2_need & ds_valid & ds_inst2_gr_we & ~inst1_rt_d[5'h00] & (inst1_rt == ds_inst2_dest);
assign es_inst1_r2_relevant = ~fifo_empty & r2_need & es_valid & es_inst1_gr_we & ~inst1_rt_d[5'h00] & (inst1_rt == es_inst1_dest);
assign es_inst2_r2_relevant = ~fifo_empty & r2_need & es_valid & es_inst2_gr_we & ~inst1_rt_d[5'h00] & (inst1_rt == es_inst2_dest);
assign pms_inst1_r2_relevant = ~fifo_empty & r2_need & pms_valid & pms_inst1_gr_we & ~inst1_rt_d[5'h00] & (inst1_rt == pms_inst1_dest);
assign pms_inst2_r2_relevant = ~fifo_empty & r2_need & pms_valid & pms_inst2_gr_we & ~inst1_rt_d[5'h00] & (inst1_rt == pms_inst2_dest);
assign ms_inst1_r2_relevant = ~fifo_empty & r2_need & ms_valid & ms_inst1_gr_we & ~inst1_rt_d[5'h00] & (inst1_rt == ms_inst1_dest);
assign ms_inst2_r2_relevant = ~fifo_empty & r2_need & ms_valid & ms_inst2_gr_we & ~inst1_rt_d[5'h00] & (inst1_rt == ms_inst2_dest);
assign ws_inst1_r2_relevant = ~fifo_empty & r2_need & ws_valid & ws_inst1_gr_we & ~inst1_rt_d[5'h00] & (inst1_rt == ws_inst1_dest);
assign ws_inst2_r2_relevant = ~fifo_empty & r2_need & ws_valid & ws_inst2_gr_we & ~inst1_rt_d[5'h00] & (inst1_rt == ws_inst2_dest);

assign ds_block = ds_inst1_r1_relevant | ds_inst2_r1_relevant | ds_inst1_r2_relevant | ds_inst2_r2_relevant;

assign es_block = es_inst1_r1_relevant & (es_inst1_mfhiloc0_load | ~es_inst1_res_valid) | es_inst2_r1_relevant & (es_inst2_mfhiloc0_load | ~es_inst2_res_valid) | 
                  es_inst1_r2_relevant & (es_inst1_mfhiloc0_load | ~es_inst1_res_valid) | es_inst2_r2_relevant & (es_inst2_mfhiloc0_load | ~es_inst2_res_valid);

assign pms_block = pms_inst1_r1_relevant & pms_inst1_load | pms_inst2_r1_relevant & pms_inst2_load | 
                   pms_inst1_r2_relevant & pms_inst1_load | pms_inst2_r2_relevant & pms_inst2_load;

assign ms_block = ms_inst1_r1_relevant & (ms_inst1_load & ~ms_inst1_res_valid) | ms_inst2_r1_relevant & (ms_inst2_load & ~ms_inst2_res_valid) | 
                  ms_inst1_r2_relevant & (ms_inst1_load & ~ms_inst1_res_valid) | ms_inst2_r2_relevant & (ms_inst2_load & ~ms_inst2_res_valid);

assign fs_inst1_readygo = ~inst1_br | inst1_br & ~(ds_block | es_block | pms_block | ms_block);

assign fs_rf_raddr1 = inst1_rs;
assign fs_rf_raddr2 = inst1_rt;

assign inst1_br_rs_value = (es_inst2_r1_relevant) ? es_inst2_result:
                           (es_inst1_r1_relevant) ? es_inst1_result:
                           (pms_inst2_r1_relevant) ? pms_inst2_result:
                           (pms_inst1_r1_relevant) ? pms_inst1_result:
                           (ms_inst2_r1_relevant) ? ms_inst2_result:
                           (ms_inst1_r1_relevant) ? ms_inst1_result:
                           (ws_inst2_r1_relevant) ? ws_inst2_result:
                           (ws_inst1_r1_relevant) ? ws_inst1_result:
                                                    ds_rf_rdata1;
assign inst1_br_rt_value = (es_inst2_r2_relevant) ? es_inst2_result:
                           (es_inst1_r2_relevant) ? es_inst1_result:
                           (pms_inst2_r2_relevant) ? pms_inst2_result:
                           (pms_inst1_r2_relevant) ? pms_inst1_result:
                           (ms_inst2_r2_relevant) ? ms_inst2_result:
                           (ms_inst1_r2_relevant) ? ms_inst1_result:
                           (ws_inst2_r2_relevant) ? ws_inst2_result:
                           (ws_inst1_r2_relevant) ? ws_inst1_result:
                                                    ds_rf_rdata2;


// inst 2
wire [ 5:0] inst2_op;
wire [ 4:0] inst2_rs;
wire [ 4:0] inst2_rt;
wire [ 4:0] inst2_rd;
wire [ 4:0] inst2_sa;
wire [ 5:0] inst2_func;
wire [15:0] inst2_imm;
wire [25:0] inst2_jidx;

wire [63:0] inst2_op_d;
wire [31:0] inst2_rs_d;
wire [31:0] inst2_rt_d;
wire [31:0] inst2_rd_d;
wire [31:0] inst2_sa_d;
wire [63:0] inst2_func_d;

wire        inst2_beq;
wire        inst2_bne;
wire        inst2_bgez;
wire        inst2_bgtz;
wire        inst2_blez;
wire        inst2_bltz;
wire        inst2_j;
wire        inst2_bltzal;
wire        inst2_bgezal;
wire        inst2_jal;
wire        inst2_jr;
wire        inst2_jalr;

wire        inst2_add;
wire        inst2_addi;
wire        inst2_addu;
wire        inst2_addiu;
wire        inst2_sub;
wire        inst2_subu;
wire        inst2_slti;
wire        inst2_sltiu;
wire        inst2_slt;
wire        inst2_sltu;
wire        inst2_and;
wire        inst2_andi;
wire        inst2_or;
wire        inst2_ori;
wire        inst2_xor;
wire        inst2_xori;
wire        inst2_nor;
wire        inst2_sll;
wire        inst2_sllv;
wire        inst2_srl;
wire        inst2_srlv;
wire        inst2_sra;
wire        inst2_srav;
wire        inst2_mult;
wire        inst2_multu;
wire        inst2_div;
wire        inst2_divu;
wire        inst2_mfhi;
wire        inst2_mflo;
wire        inst2_mthi;
wire        inst2_mtlo;
wire        inst2_lui;
wire        inst2_lw;
wire        inst2_lwl;
wire        inst2_lwr;
wire        inst2_lb;
wire        inst2_lbu;
wire        inst2_lh;
wire        inst2_lhu;
wire        inst2_sw;
wire        inst2_sb;
wire        inst2_sh;
wire        inst2_swl;
wire        inst2_swr;
wire        inst2_mfc0;
wire        inst2_mtc0;

assign inst2_op   = fs_inst2[31:26];
assign inst2_rs   = fs_inst2[25:21];
assign inst2_rt   = fs_inst2[20:16];
assign inst2_rd   = fs_inst2[15:11];
assign inst2_sa   = fs_inst2[10: 6];
assign inst2_func = fs_inst2[ 5: 0];
assign inst2_imm  = fs_inst2[15: 0];
assign inst2_jidx = fs_inst2[25: 0];

decoder_6_64 u_dec10(.in(inst2_op  ), .out(inst2_op_d  ));
decoder_6_64 u_dec11(.in(inst2_func), .out(inst2_func_d));
decoder_5_32 u_dec12(.in(inst2_rs  ), .out(inst2_rs_d  ));
decoder_5_32 u_dec13(.in(inst2_rt  ), .out(inst2_rt_d  ));
decoder_5_32 u_dec14(.in(inst2_rd  ), .out(inst2_rd_d  ));
decoder_5_32 u_dec15(.in(inst2_sa  ), .out(inst2_sa_d  ));

assign inst2_beq    = inst2_op_d[6'h04];
assign inst2_bne    = inst2_op_d[6'h05];
assign inst2_bgez   = inst2_op_d[6'h01] & inst2_rt_d[5'h01];
assign inst2_bgtz   = inst2_op_d[6'h07] & inst2_rt_d[5'h00];
assign inst2_blez   = inst2_op_d[6'h06] & inst2_rt_d[5'h00];
assign inst2_bltz   = inst2_op_d[6'h01] & inst2_rt_d[5'h00];
assign inst2_j      = inst2_op_d[6'h02];
assign inst2_bltzal = inst2_op_d[6'h01] & inst2_rt_d[5'h10];
assign inst2_bgezal = inst2_op_d[6'h01] & inst2_rt_d[5'h11];
assign inst2_jal    = inst2_op_d[6'h03];
assign inst2_jr     = inst2_op_d[6'h00] & inst2_func_d[6'h08] & inst2_rt_d[5'h00] & inst2_rd_d[5'h00] & inst2_sa_d[5'h00];
assign inst2_jalr   = inst2_op_d[6'h00] & inst2_func_d[6'h09] & inst2_rt_d[5'h00] & inst2_sa_d[5'h00];

assign inst2_add    = inst2_op_d[6'h00] & inst2_func_d[6'h20] & inst2_sa_d[5'h00];
assign inst2_addu   = inst2_op_d[6'h00] & inst2_func_d[6'h21] & inst2_sa_d[5'h00];
assign inst2_addi   = inst2_op_d[6'h08];
assign inst2_addiu  = inst2_op_d[6'h09];
assign inst2_sub    = inst2_op_d[6'h00] & inst2_func_d[6'h22] & inst2_sa_d[5'h00];
assign inst2_subu   = inst2_op_d[6'h00] & inst2_func_d[6'h23] & inst2_sa_d[5'h00];
assign inst2_slt    = inst2_op_d[6'h00] & inst2_func_d[6'h2a] & inst2_sa_d[5'h00];
assign inst2_sltu   = inst2_op_d[6'h00] & inst2_func_d[6'h2b] & inst2_sa_d[5'h00];
assign inst2_slti   = inst2_op_d[6'h0a];
assign inst2_sltiu  = inst2_op_d[6'h0b];

assign inst2_and    = inst2_op_d[6'h00] & inst2_func_d[6'h24] & inst2_sa_d[5'h00];
assign inst2_andi   = inst2_op_d[6'h0c];
assign inst2_or     = inst2_op_d[6'h00] & inst2_func_d[6'h25] & inst2_sa_d[5'h00];
assign inst2_ori    = inst2_op_d[6'h0d];
assign inst2_xor    = inst2_op_d[6'h00] & inst2_func_d[6'h26] & inst2_sa_d[5'h00];
assign inst2_xori   = inst2_op_d[6'h0e];
assign inst2_nor    = inst2_op_d[6'h00] & inst2_func_d[6'h27] & inst2_sa_d[5'h00];

assign inst2_sll    = inst2_op_d[6'h00] & inst2_func_d[6'h00] & inst2_rs_d[5'h00];
assign inst2_sllv   = inst2_op_d[6'h00] & inst2_func_d[6'h04] & inst2_sa_d[5'h00];
assign inst2_srl    = inst2_op_d[6'h00] & inst2_func_d[6'h02] & inst2_rs_d[5'h00];
assign inst2_srlv   = inst2_op_d[6'h00] & inst2_func_d[6'h06] & inst2_sa_d[5'h00];
assign inst2_sra    = inst2_op_d[6'h00] & inst2_func_d[6'h03] & inst2_rs_d[5'h00];
assign inst2_srav   = inst2_op_d[6'h00] & inst2_func_d[6'h07] & inst2_sa_d[5'h00];

assign inst2_mult   = inst2_op_d[6'h00] & inst2_func_d[6'h18] & inst2_rd_d[5'h00] & inst2_sa_d[5'h00];
assign inst2_multu  = inst2_op_d[6'h00] & inst2_func_d[6'h19] & inst2_rd_d[5'h00] & inst2_sa_d[5'h00];
assign inst2_div    = inst2_op_d[6'h00] & inst2_func_d[6'h1a] & inst2_rd_d[5'h00] & inst2_sa_d[5'h00];
assign inst2_divu   = inst2_op_d[6'h00] & inst2_func_d[6'h1b] & inst2_rd_d[5'h00] & inst2_sa_d[5'h00];
assign inst2_mfhi   = inst2_op_d[6'h00] & inst2_func_d[6'h10] & inst2_rs_d[5'h00] & inst2_rt_d[5'h00] & inst2_sa_d[5'h00];
assign inst2_mthi   = inst2_op_d[6'h00] & inst2_func_d[6'h11] & inst2_rt_d[5'h00] & inst2_rd_d[5'h00] & inst2_sa_d[5'h00];
assign inst2_mflo   = inst2_op_d[6'h00] & inst2_func_d[6'h12] & inst2_rs_d[5'h00] & inst2_rt_d[5'h00] & inst2_sa_d[5'h00];
assign inst2_mtlo   = inst2_op_d[6'h00] & inst2_func_d[6'h13] & inst2_rt_d[5'h00] & inst2_rd_d[5'h00] & inst2_sa_d[5'h00];

assign inst2_lb     = inst2_op_d[6'h20];
assign inst2_lh     = inst2_op_d[6'h21];
assign inst2_lw     = inst2_op_d[6'h23];
assign inst2_lbu    = inst2_op_d[6'h24];
assign inst2_lhu    = inst2_op_d[6'h25];
assign inst2_lwl    = inst2_op_d[6'h22];
assign inst2_lwr    = inst2_op_d[6'h26];
assign inst2_sb     = inst2_op_d[6'h28];
assign inst2_sh     = inst2_op_d[6'h29];
assign inst2_sw     = inst2_op_d[6'h2b];
assign inst2_swl    = inst2_op_d[6'h2a];
assign inst2_swr    = inst2_op_d[6'h2e];

assign inst2_mfc0   = inst2_op_d[6'h10] & inst2_rs_d[5'h00] & inst2_sa_d[5'h00] & (fs_inst2[5: 3]==3'b0);
assign inst2_mtc0   = inst2_op_d[6'h10] & inst2_rs_d[5'h04] & inst2_sa_d[5'h00] & (fs_inst2[5: 3]==3'b0);


assign inst2_br = inst2_beq | inst2_bne | inst2_bgez | inst2_bgezal | inst2_bgtz | inst2_blez | inst2_bltz | inst2_bltzal | inst2_j | inst2_jal | inst2_jalr | inst2_jr;

assign inst2_valid = ~single_shoot;

assign inst2_op_final   = inst2_op   & {6{inst2_valid}};
assign inst2_rs_final   = inst2_rs   & {5{inst2_valid}};
assign inst2_rt_final   = inst2_rt   & {5{inst2_valid}};
assign inst2_rd_final   = inst2_rd   & {5{inst2_valid}};
assign inst2_sa_final   = inst2_sa   & {5{inst2_valid}};
assign inst2_func_final = inst2_func & {6{inst2_valid}};
assign inst2_imm_final  = inst2_imm  & {16{inst2_valid}};
assign inst2_jidx_final = inst2_jidx & {26{inst2_valid}};

//assign inst2_op_d_final   = inst2_op_d   & {64{inst2_valid}};
//assign inst2_func_d_final = inst2_func_d & {64{inst2_valid}};
//assign inst2_rs_d_final   = inst2_rs_d   & {32{inst2_valid}};
//assign inst2_rt_d_final   = inst2_rt_d   & {32{inst2_valid}};
//assign inst2_rd_d_final   = inst2_rd_d   & {32{inst2_valid}};
//assign inst2_sa_d_final   = inst2_sa_d   & {32{inst2_valid}};

assign inst2_op_d_final   = inst2_valid ? inst2_op_d : 64'd1;
assign inst2_func_d_final = inst2_valid ? inst2_func_d : 64'd1;
assign inst2_rs_d_final   = inst2_valid ? inst2_rs_d : 32'd1;
assign inst2_rt_d_final   = inst2_valid ? inst2_rt_d : 32'd1;
assign inst2_rd_d_final   = inst2_valid ? inst2_rd_d : 32'd1;
assign inst2_sa_d_final   = inst2_valid ? inst2_sa_d : 32'd1;

assign inst2_pc       = fifo_pc[head_1];
assign inst2_inst     = fs_inst2 & {32{inst2_valid}};
assign inst2_except   = fifo_except[head_1]  & inst2_valid;
assign inst2_exccode  = fifo_exccode[head_1] & {5{inst2_valid}};
assign inst2_refill   = fifo_refill[head_1]  & inst2_valid;

// self relevant
wire  inst2_r1_need;
wire  inst2_r2_need;
wire  inst2_r1_relevant;
wire  inst2_r2_relevant;

assign inst2_r1_need = inst2_addiu  || inst2_addi  || inst2_addu || inst2_add   || inst2_subu || inst2_sub  || 
                       inst2_and    || inst2_andi  || inst2_nor  || inst2_or    || inst2_ori  || inst2_xor  || inst2_xori || 
                       inst2_slt    || inst2_sltu  || inst2_slti || inst2_sltiu || inst2_sllv || inst2_srav || inst2_srlv || 
                       inst2_mult   || inst2_multu || inst2_div  || inst2_divu  || inst2_mthi || inst2_mtlo || 
                       inst2_beq    || inst2_bne   || inst2_bgez || inst2_bgtz  || inst2_blez || inst2_bltz || 
                       inst2_bltzal || inst2_bgezal|| inst2_jr   || inst2_jalr || 
                       inst2_lw     || inst2_lb    || inst2_lbu  || inst2_lh    || inst2_lhu  || inst2_lwl  || inst2_lwr || 
                       inst2_sw     || inst2_sb    || inst2_sh   || inst2_swl   || inst2_swr;
assign inst2_r2_need = inst2_add  || inst2_addu  || inst2_sub || inst2_subu || 
                       inst2_and  || inst2_nor   || inst2_or  || inst2_xor  || 
                       inst2_slt  || inst2_sltu  || inst2_sll || inst2_sra  || inst2_srl || inst2_sllv || inst2_srav || inst2_srlv || 
                       inst2_mult || inst2_multu || inst2_div || inst2_divu || 
                       inst2_beq  || inst2_bne   || inst2_lwl || inst2_lwr  ||
                       inst2_sw   || inst2_sb    || inst2_sh  || inst2_swl  || inst2_swr || inst2_mtc0;

assign inst2_r1_relevant = inst2_r1_need & inst1_load_mfc0hilo & ~inst2_rs_d[5'h00] & (inst2_rs == inst1_dest);
assign inst2_r2_relevant = inst2_r2_need & inst1_load_mfc0hilo & ~inst2_rt_d[5'h00] & (inst2_rt == inst1_dest);

assign self_relevant = inst2_r1_relevant | inst2_r2_relevant;
assign single_shoot = self_relevant | inst2_br;


endmodule