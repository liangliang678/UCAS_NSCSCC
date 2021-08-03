`include "mycpu.h"

module id_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          es_allowin    ,
    output                         ds_allowin    ,
    //from fs
    input                          fs_to_ds_valid,
    input  [ 4:0]                  fs_rf_raddr1  ,
    input  [ 4:0]                  fs_rf_raddr2  ,
    input  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus  ,
    //to es
    output                         ds_to_es_valid,
    output [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,

    //to prefs
    output [`BR_BUS_WD       -1:0] br_bus        ,

    //to fs
    output                         ds_branch     ,
    output [31:0]                  ds_to_fs_rf_rdata1,
    output [31:0]                  ds_to_fs_rf_rdata2,

    //to rf: for write back
    input  [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus  ,

    //relevant bus
    input  [`ES_FORWARD_BUS_WD -1:0] es_forward_bus,
    input  [`PMS_FORWARD_BUS_WD -1:0] pms_forward_bus,
    input  [`MS_FORWARD_BUS_WD -1:0] ms_forward_bus,
    input  [`WS_FORWARD_BUS_WD -1:0] ws_forward_bus,
    output [`DS_FORWARD_BUS_WD -1:0] ds_forward_bus,

    //handle interrupt
    input                          has_int       ,
    
    //clear stage
    input                          clear_all
);

reg         ds_valid;
wire        ds_ready_go;

reg  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus_r;

wire [31:0] inst1_pc;
wire [31:0] inst1_inst;
wire        inst1_fs_except;
wire [ 4:0] inst1_fs_exccode;
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

wire [31:0] inst2_pc;
wire [31:0] inst2_inst;
wire        inst2_fs_except;
wire [ 4:0] inst2_fs_exccode;
wire        inst2_refill;
wire        inst2_valid;

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

assign {inst2_valid,
        inst2_op,
        inst2_rs,
        inst2_rt,
        inst2_rd,
        inst2_sa,
        inst2_func,
        inst2_imm,
        inst2_jidx,
        inst2_op_d,
        inst2_rs_d,
        inst2_rt_d,
        inst2_rd_d,
        inst2_sa_d,
        inst2_func_d,

        inst2_refill,
        inst2_fs_except,
        inst2_fs_exccode,
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
        inst1_fs_except,
        inst1_fs_exccode,
        inst1_inst,
        inst1_pc
    } = fs_to_ds_bus_r;

wire        inst1_readygo;
wire        inst2_readygo;

wire        self_r1_relevant;
wire        self_r2_relevant;

wire        br_taken;
wire        br_leave;
wire [31:0] br_target;

wire        inst1_except;
wire [ 4:0] inst1_exccode;

wire        inst1_ds_except;
wire [ 4:0] inst1_ds_exccode;
wire        inst1_ds_tlbp;
wire        inst1_ds_tlbr;
wire        inst1_ds_tlbwi;
wire        inst1_ds_eret;
wire        inst1_bd;
wire        inst1_detect_overflow;
wire        inst1_cp0_op;
wire        inst1_cp0_we;
wire [ 7:0] inst1_cp0_addr;
wire [ 6:0] inst1_load_store_type;
wire        inst1_load_op;
wire        inst1_store_op;
wire        inst1_hi_op;
wire        inst1_lo_op;
wire        inst1_hi_we;
wire        inst1_lo_we;
wire        inst1_hl_src_from_mul;
wire        inst1_hl_src_from_div;
wire [15:0] inst1_alu_op;
wire        inst1_src1_is_sa;
wire        inst1_src1_is_pc;
wire        inst1_src2_is_imm;
wire        inst1_src2_is_imm16;
wire        inst1_src2_is_8;
wire        inst1_gr_we;
wire        inst1_mem_we;
wire [ 4:0] inst1_dest;
wire [31:0] inst1_rs_value;
wire [31:0] inst1_rt_value;

wire        inst1_branch_op;
wire        inst1_jump_op;


wire        inst2_except;
wire [ 4:0] inst2_exccode;

wire        inst2_ds_except;
wire [ 4:0] inst2_ds_exccode;
wire        inst2_ds_tlbp;
wire        inst2_ds_tlbr;
wire        inst2_ds_tlbwi;
wire        inst2_ds_eret;
wire        inst2_bd;
wire        inst2_detect_overflow;
wire        inst2_cp0_op;
wire        inst2_cp0_we;
wire [ 7:0] inst2_cp0_addr;
wire [ 6:0] inst2_load_store_type;
wire        inst2_load_op;
wire        inst2_store_op;
wire        inst2_hi_op;
wire        inst2_lo_op;
wire        inst2_hi_we;
wire        inst2_lo_we;
wire        inst2_hl_src_from_mul;
wire        inst2_hl_src_from_div;
wire [15:0] inst2_alu_op;
wire        inst2_src1_is_sa;
wire        inst2_src1_is_pc;
wire        inst2_src2_is_imm;
wire        inst2_src2_is_imm16;
wire        inst2_src2_is_8;
wire        inst2_gr_we;
wire        inst2_mem_we;
wire [ 4:0] inst2_dest;
wire [31:0] inst2_rs_value;
wire [31:0] inst2_rt_value;

assign inst1_bd = 1'b0;
assign inst2_bd = inst1_branch_op | inst1_jump_op;

assign ds_to_es_bus = {inst2_valid,
                       inst2_refill,
                       inst2_ds_except,
                       inst2_ds_exccode,
                       inst2_ds_tlbp,
                       inst2_ds_tlbr,
                       inst2_ds_tlbwi,
                       inst2_ds_eret,
                       inst2_bd,
                       inst2_detect_overflow,
                       inst2_cp0_op,
                       inst2_cp0_we,
                       inst2_cp0_addr,
                       inst2_load_store_type,
                       inst2_load_op,
                       inst2_hi_op,
                       inst2_lo_op,
                       inst2_hi_we,
                       inst2_lo_we,
                       inst2_hl_src_from_mul,
                       inst2_hl_src_from_div,
                       inst2_alu_op,
                       inst2_src1_is_sa,
                       inst2_src1_is_pc,
                       inst2_src2_is_imm,
                       inst2_src2_is_imm16,
                       inst2_src2_is_8,
                       inst2_gr_we,
                       inst2_mem_we,
                       inst2_dest,
                       inst2_imm,
                       inst2_rs_value,
                       inst2_rt_value,
                       inst2_pc,

                       br_target,
                       self_r1_relevant,
                       self_r2_relevant,

                       inst1_refill,
                       inst1_ds_except,
                       inst1_ds_exccode,
                       inst1_ds_tlbp,
                       inst1_ds_tlbr,
                       inst1_ds_tlbwi,
                       inst1_ds_eret,
                       inst1_bd,
                       inst1_detect_overflow,
                       inst1_cp0_op,
                       inst1_cp0_we,
                       inst1_cp0_addr,
                       inst1_load_store_type,
                       inst1_load_op,
                       inst1_hi_op,
                       inst1_lo_op,
                       inst1_hi_we,
                       inst1_lo_we,
                       inst1_hl_src_from_mul,
                       inst1_hl_src_from_div,
                       inst1_alu_op,
                       inst1_src1_is_sa,
                       inst1_src1_is_pc,
                       inst1_src2_is_imm,
                       inst1_src2_is_imm16,
                       inst1_src2_is_8,
                       inst1_gr_we,
                       inst1_mem_we,
                       inst1_dest,
                       inst1_imm,
                       inst1_rs_value,
                       inst1_rt_value,
                       inst1_pc
                      };

// ID stage
assign ds_ready_go    = inst1_readygo & inst2_readygo | clear_all;
assign ds_allowin     = !ds_valid || ds_ready_go && es_allowin;
assign ds_to_es_valid = ds_valid && ds_ready_go;

always @(posedge clk) begin
    if (reset) begin
        ds_valid <= 1'b0;
    end
    else if (clear_all) begin
        ds_valid <= 1'b0;
    end
    else if (ds_allowin) begin
        ds_valid <= fs_to_ds_valid;
    end

    if (fs_to_ds_valid && ds_allowin) begin
        fs_to_ds_bus_r <= fs_to_ds_bus;
    end
end

// regfile
wire        rf_we_01;
wire [ 4:0] rf_waddr_01;
wire [31:0] rf_wdata_01;
wire        rf_we_02;
wire [ 4:0] rf_waddr_02;
wire [31:0] rf_wdata_02;

wire [31:0] rf_rdata_01;
wire [31:0] rf_rdata_02;
wire [31:0] rf_rdata_03;
wire [31:0] rf_rdata_04;

assign {rf_we_02,
        rf_waddr_02,
        rf_wdata_02,
        rf_we_01,
        rf_waddr_01,
        rf_wdata_01
       } = ws_to_rf_bus;

regfile u_regfile(
    .clk       (clk      ),
    .raddr_01  (inst1_rs),
    .rdata_01  (rf_rdata_01),
    .raddr_02  (inst1_rt),
    .rdata_02  (rf_rdata_02),

    .raddr_03  (inst2_rs),
    .rdata_03  (rf_rdata_03),
    .raddr_04  (inst2_rt),
    .rdata_04  (rf_rdata_04),

    .raddr_05  (fs_rf_raddr1),
    .rdata_05  (ds_to_fs_rf_rdata1),
    .raddr_06  (fs_rf_raddr2),
    .rdata_06  (ds_to_fs_rf_rdata2),

    .we_01     (rf_we_01    ),
    .waddr_01  (rf_waddr_01 ),
    .wdata_01  (rf_wdata_01 ),
    .we_02     (rf_we_02    ),
    .waddr_02  (rf_waddr_02 ),
    .wdata_02  (rf_wdata_02 )
    );


// inst 1
wire        inst1_add;
wire        inst1_addi;
wire        inst1_addu;
wire        inst1_addiu;
wire        inst1_sub;
wire        inst1_subu;
wire        inst1_slti;
wire        inst1_sltiu;
wire        inst1_slt;
wire        inst1_sltu;
wire        inst1_and;
wire        inst1_andi;
wire        inst1_or;
wire        inst1_ori;
wire        inst1_xor;
wire        inst1_xori;
wire        inst1_nor;
wire        inst1_sll;
wire        inst1_sllv;
wire        inst1_srl;
wire        inst1_srlv;
wire        inst1_sra;
wire        inst1_srav;
wire        inst1_mult;
wire        inst1_multu;
wire        inst1_div;
wire        inst1_divu;
wire        inst1_mfhi;
wire        inst1_mflo;
wire        inst1_mthi;
wire        inst1_mtlo;
wire        inst1_lui;
wire        inst1_lw;
wire        inst1_lwl;
wire        inst1_lwr;
wire        inst1_lb;
wire        inst1_lbu;
wire        inst1_lh;
wire        inst1_lhu;
wire        inst1_sw;
wire        inst1_sb;
wire        inst1_sh;
wire        inst1_swl;
wire        inst1_swr;
wire        inst1_beq;
wire        inst1_bne;
wire        inst1_bgez;
wire        inst1_bgtz;
wire        inst1_blez;
wire        inst1_bltz;
wire        inst1_j;
wire        inst1_bltzal;
wire        inst1_bgezal; 
wire        inst1_jalr;
wire        inst1_jal;
wire        inst1_jr;
wire        inst1_mfc0;
wire        inst1_mtc0;
wire        inst1_eret;
wire        inst1_syscall;
wire        inst1_break;
wire        inst1_tlbp;
wire        inst1_tlbr;
wire        inst1_tlbwi;

assign inst1_add    = inst1_op_d[6'h00] & inst1_func_d[6'h20] & inst1_sa_d[5'h00];
assign inst1_addu   = inst1_op_d[6'h00] & inst1_func_d[6'h21] & inst1_sa_d[5'h00];
assign inst1_addi   = inst1_op_d[6'h08];
assign inst1_addiu  = inst1_op_d[6'h09];
assign inst1_sub    = inst1_op_d[6'h00] & inst1_func_d[6'h22] & inst1_sa_d[5'h00];
assign inst1_subu   = inst1_op_d[6'h00] & inst1_func_d[6'h23] & inst1_sa_d[5'h00];
assign inst1_slt    = inst1_op_d[6'h00] & inst1_func_d[6'h2a] & inst1_sa_d[5'h00];
assign inst1_sltu   = inst1_op_d[6'h00] & inst1_func_d[6'h2b] & inst1_sa_d[5'h00];
assign inst1_slti   = inst1_op_d[6'h0a];
assign inst1_sltiu  = inst1_op_d[6'h0b];

assign inst1_and    = inst1_op_d[6'h00] & inst1_func_d[6'h24] & inst1_sa_d[5'h00];
assign inst1_andi   = inst1_op_d[6'h0c];
assign inst1_or     = inst1_op_d[6'h00] & inst1_func_d[6'h25] & inst1_sa_d[5'h00];
assign inst1_ori    = inst1_op_d[6'h0d];
assign inst1_xor    = inst1_op_d[6'h00] & inst1_func_d[6'h26] & inst1_sa_d[5'h00];
assign inst1_xori   = inst1_op_d[6'h0e];
assign inst1_nor    = inst1_op_d[6'h00] & inst1_func_d[6'h27] & inst1_sa_d[5'h00];

assign inst1_sll    = inst1_op_d[6'h00] & inst1_func_d[6'h00] & inst1_rs_d[5'h00];
assign inst1_sllv   = inst1_op_d[6'h00] & inst1_func_d[6'h04] & inst1_sa_d[5'h00];
assign inst1_srl    = inst1_op_d[6'h00] & inst1_func_d[6'h02] & inst1_rs_d[5'h00];
assign inst1_srlv   = inst1_op_d[6'h00] & inst1_func_d[6'h06] & inst1_sa_d[5'h00];
assign inst1_sra    = inst1_op_d[6'h00] & inst1_func_d[6'h03] & inst1_rs_d[5'h00];
assign inst1_srav   = inst1_op_d[6'h00] & inst1_func_d[6'h07] & inst1_sa_d[5'h00];

assign inst1_mult   = inst1_op_d[6'h00] & inst1_func_d[6'h18] & inst1_rd_d[5'h00] & inst1_sa_d[5'h00];
assign inst1_multu  = inst1_op_d[6'h00] & inst1_func_d[6'h19] & inst1_rd_d[5'h00] & inst1_sa_d[5'h00];
assign inst1_div    = inst1_op_d[6'h00] & inst1_func_d[6'h1a] & inst1_rd_d[5'h00] & inst1_sa_d[5'h00];
assign inst1_divu   = inst1_op_d[6'h00] & inst1_func_d[6'h1b] & inst1_rd_d[5'h00] & inst1_sa_d[5'h00];
assign inst1_mfhi   = inst1_op_d[6'h00] & inst1_func_d[6'h10] & inst1_rs_d[5'h00] & inst1_rt_d[5'h00] & inst1_sa_d[5'h00];
assign inst1_mthi   = inst1_op_d[6'h00] & inst1_func_d[6'h11] & inst1_rt_d[5'h00] & inst1_rd_d[5'h00] & inst1_sa_d[5'h00];
assign inst1_mflo   = inst1_op_d[6'h00] & inst1_func_d[6'h12] & inst1_rs_d[5'h00] & inst1_rt_d[5'h00] & inst1_sa_d[5'h00];
assign inst1_mtlo   = inst1_op_d[6'h00] & inst1_func_d[6'h13] & inst1_rt_d[5'h00] & inst1_rd_d[5'h00] & inst1_sa_d[5'h00];

assign inst1_lui    = inst1_op_d[6'h0f] & inst1_rs_d[5'h00];

assign inst1_lb     = inst1_op_d[6'h20];
assign inst1_lh     = inst1_op_d[6'h21];
assign inst1_lw     = inst1_op_d[6'h23];
assign inst1_lbu    = inst1_op_d[6'h24];
assign inst1_lhu    = inst1_op_d[6'h25];
assign inst1_lwl    = inst1_op_d[6'h22];
assign inst1_lwr    = inst1_op_d[6'h26];
assign inst1_sb     = inst1_op_d[6'h28];
assign inst1_sh     = inst1_op_d[6'h29];
assign inst1_sw     = inst1_op_d[6'h2b];
assign inst1_swl    = inst1_op_d[6'h2a];
assign inst1_swr    = inst1_op_d[6'h2e];

assign inst1_beq    = inst1_op_d[6'h04];
assign inst1_bne    = inst1_op_d[6'h05];
assign inst1_bgez   = inst1_op_d[6'h01] & inst1_rt_d[5'h01];
assign inst1_bgtz   = inst1_op_d[6'h07] & inst1_rt_d[5'h00];
assign inst1_blez   = inst1_op_d[6'h06] & inst1_rt_d[5'h00];
assign inst1_bltz   = inst1_op_d[6'h01] & inst1_rt_d[5'h00];
assign inst1_j      = inst1_op_d[6'h02];
assign inst1_bltzal = inst1_op_d[6'h01] & inst1_rt_d[5'h10];
assign inst1_bgezal = inst1_op_d[6'h01] & inst1_rt_d[5'h11];
assign inst1_jalr   = inst1_op_d[6'h00] & inst1_rt_d[5'h00] & inst1_func_d[6'h09] & inst1_sa_d[5'h00];
assign inst1_jal    = inst1_op_d[6'h03];
assign inst1_jr     = inst1_op_d[6'h00] & inst1_func_d[6'h08] & inst1_rt_d[5'h00] & inst1_rd_d[5'h00] & inst1_sa_d[5'h00];

assign inst1_mfc0   = inst1_op_d[6'h10] & inst1_rs_d[5'h00] & inst1_sa_d[5'h00] & (inst1_inst[5: 3]==3'b0);
assign inst1_mtc0   = inst1_op_d[6'h10] & inst1_rs_d[5'h04] & inst1_sa_d[5'h00] & (inst1_inst[5: 3]==3'b0);
assign inst1_eret   = inst1_op_d[6'h10] & inst1_rs_d[5'h10] & inst1_rt_d[5'h00] & inst1_rd_d[5'h00] & inst1_sa_d[5'h00] & inst1_func_d[6'h18];
assign inst1_syscall= inst1_op_d[6'h00] & inst1_func_d[6'h0c];
assign inst1_break  = inst1_op_d[6'h00] & inst1_func_d[6'h0d];

assign inst1_tlbp   = inst1_op_d[6'h10] & inst1_func_d[6'h08] & inst1_rs_d[5'h10] & inst1_rt_d[5'h00] & inst1_rd_d[5'h00] & inst1_sa_d[5'h00];
assign inst1_tlbr   = inst1_op_d[6'h10] & inst1_func_d[6'h01] & inst1_rs_d[5'h10] & inst1_rt_d[5'h00] & inst1_rd_d[5'h00] & inst1_sa_d[5'h00];
assign inst1_tlbwi  = inst1_op_d[6'h10] & inst1_func_d[6'h02] & inst1_rs_d[5'h10] & inst1_rt_d[5'h00] & inst1_rd_d[5'h00] & inst1_sa_d[5'h00];


assign inst1_alu_op[ 0] = inst1_add | inst1_addu | inst1_addi | inst1_addiu | inst1_load_op | inst1_store_op | inst1_jal | inst1_bgezal | inst1_bltzal | inst1_jalr;
assign inst1_alu_op[ 1] = inst1_sub | inst1_subu;
assign inst1_alu_op[ 2] = inst1_slt | inst1_slti;
assign inst1_alu_op[ 3] = inst1_sltu | inst1_sltiu;
assign inst1_alu_op[ 4] = inst1_and | inst1_andi;
assign inst1_alu_op[ 5] = inst1_nor;
assign inst1_alu_op[ 6] = inst1_or | inst1_ori;
assign inst1_alu_op[ 7] = inst1_xor | inst1_xori;
assign inst1_alu_op[ 8] = inst1_sll | inst1_sllv;
assign inst1_alu_op[ 9] = inst1_srl | inst1_srlv;
assign inst1_alu_op[10] = inst1_sra | inst1_srav;
assign inst1_alu_op[11] = inst1_lui;
assign inst1_alu_op[12] = inst1_mult;
assign inst1_alu_op[13] = inst1_multu;
assign inst1_alu_op[14] = inst1_div;
assign inst1_alu_op[15] = inst1_divu;

assign inst1_ds_tlbp   = inst1_tlbp;
assign inst1_ds_tlbr   = inst1_tlbr;
assign inst1_ds_tlbwi  = inst1_tlbwi;
assign inst1_ds_eret   = inst1_eret;

assign inst1_load_op   = inst1_lb | inst1_lbu | inst1_lh | inst1_lhu | inst1_lw | inst1_lwl | inst1_lwr;
assign inst1_store_op  = inst1_sb | inst1_sh | inst1_sw | inst1_swl | inst1_swr;
assign inst1_hi_op     = inst1_mfhi;
assign inst1_lo_op     = inst1_mflo;
assign inst1_cp0_op    = inst1_mfc0;
assign inst1_branch_op = inst1_beq | inst1_bne | inst1_bgez | inst1_bgezal | inst1_bgtz | inst1_blez | inst1_bltz | inst1_bltzal;
assign inst1_jump_op   = inst1_j | inst1_jal | inst1_jalr | inst1_jr;

assign inst1_src1_is_sa   = inst1_sll | inst1_srl | inst1_sra;
assign inst1_src1_is_pc   = inst1_jal | inst1_bgezal | inst1_bltzal | inst1_jalr;
assign inst1_src2_is_imm  = inst1_addi | inst1_addiu | inst1_slti | inst1_sltiu | inst1_lui ;//| load_op | store_op;
assign inst1_src2_is_imm16= inst1_andi | inst1_ori | inst1_xori;
assign inst1_src2_is_8    = inst1_jal | inst1_bgezal | inst1_bltzal | inst1_jalr;

assign inst1_dst_is_r31   = inst1_jal | inst1_bgezal | inst1_bltzal | inst1_jalr;
assign inst1_dst_is_rt    = inst1_addi | inst1_addiu | inst1_slti | inst1_sltiu | inst1_andi | inst1_ori | inst1_xori | inst1_lui | inst1_load_op | inst1_mfc0;
assign inst1_gr_we        = ~inst1_store_op & ~inst1_beq & ~inst1_bne & ~inst1_bgez & ~inst1_bgtz & ~inst1_blez & ~inst1_bltz & ~inst1_jr & ~inst1_j & 
                            ~inst1_div & ~inst1_divu & ~inst1_mult & ~inst1_multu & ~inst1_mthi & ~inst1_mtlo & ~inst1_syscall & ~inst1_break & ~inst1_eret & 
                            ~inst1_mtc0 & ~inst1_tlbp & ~inst1_tlbr & ~inst1_tlbwi;
assign inst1_mem_we       = inst1_store_op;
assign inst1_hi_we        = inst1_div | inst1_divu | inst1_mult | inst1_multu | inst1_mthi;
assign inst1_lo_we        = inst1_div | inst1_divu | inst1_mult | inst1_multu | inst1_mtlo;
assign inst1_cp0_we       = inst1_mtc0;
assign inst1_hl_src_from_mul   = inst1_mult | inst1_multu;
assign inst1_hl_src_from_div   = inst1_div  | inst1_divu;
assign inst1_load_store_type   = {inst1_lb | inst1_sb,       //[b,bu,h,hu,w,wl,wr]
                                 inst1_lbu,
                                 inst1_lh | inst1_sh,
                                 inst1_lhu,
                                 inst1_lw | inst1_sw,
                                 inst1_lwl | inst1_swl,
                                 inst1_lwr | inst1_swr};
assign inst1_cp0_addr     = {inst1_rd[4:0], inst1_func[2:0]};
assign inst1_detect_overflow  = inst1_add | inst1_addi | inst1_sub;

assign inst1_dest         = inst1_dst_is_r31 ? 5'd31 :
                            inst1_dst_is_rt  ? inst1_rt : 
                                               inst1_rd;

//exception
wire inst1_ds_Sys;
wire inst1_ds_Bp;
wire inst1_ds_RI;
assign inst1_ds_Sys = inst1_syscall;
assign inst1_ds_Bp = inst1_break;
assign inst1_ds_RI = ~inst1_add & ~inst1_addu & ~inst1_addi & ~inst1_addiu & ~inst1_sub & ~inst1_subu &
                     ~inst1_slt & ~inst1_sltu & ~inst1_slti & ~inst1_sltiu &
                     ~inst1_and & ~inst1_andi & ~inst1_or & ~inst1_ori & ~inst1_xor & ~inst1_xori & ~inst1_nor &
                     ~inst1_sll & ~inst1_sllv & ~inst1_srl & ~inst1_srlv & ~inst1_sra & ~inst1_srav &
                     ~inst1_mult & ~inst1_multu & ~inst1_div & ~inst1_divu & ~inst1_mfhi & ~inst1_mthi & ~inst1_mflo & ~inst1_mtlo &
                     ~inst1_lui & ~inst1_lb & ~inst1_lh & ~inst1_lw & ~inst1_lbu & ~inst1_lhu & ~inst1_lwl & ~inst1_lwr &
                     ~inst1_sb & ~inst1_sh & ~inst1_sw & ~inst1_swl & ~inst1_swr &
                     ~inst1_beq & ~inst1_bne & ~inst1_bgez & ~inst1_bgtz & ~inst1_blez & ~inst1_bltz &
                     ~inst1_j & ~inst1_bltzal & ~inst1_bgezal & ~inst1_jalr & ~inst1_jal & ~inst1_jr &
                     ~inst1_mfc0 & ~inst1_mtc0 & ~inst1_eret & ~inst1_syscall & ~inst1_break &
                     ~inst1_tlbp & ~inst1_tlbr & ~inst1_tlbwi;

assign inst1_except  = inst1_ds_Sys | inst1_ds_Bp | inst1_ds_RI;
assign inst1_exccode = (inst1_ds_RI) ? 5'ha: 
                       (inst1_ds_Sys)? 5'h8: 
                       (inst1_ds_Bp) ? 5'h9: 
                                       5'h0;

assign inst1_ds_except  = has_int | inst1_fs_except | inst1_except;
assign inst1_ds_exccode = (has_int         ) ? 5'h0: 
                          (inst1_fs_except ) ? inst1_fs_exccode: 
                                               inst1_exccode;

//branch
wire        rs_eq_rt;
wire        rs_ge_z;
wire        rs_gt_z;

assign rs_eq_rt = (inst1_br_rs_value == inst1_br_rt_value);
assign rs_ge_z  = (inst1_br_rs_value[31] == 1'b0);
assign rs_gt_z  = (inst1_br_rs_value[31] == 1'b0) & (inst1_br_rs_value != 32'b0);

assign br_taken = (   inst1_beq    &&  rs_eq_rt
                   || inst1_bne    && !rs_eq_rt
                   || inst1_bgez   &&  rs_ge_z
                   || inst1_bgtz   &&  rs_gt_z
                   || inst1_blez   && !rs_gt_z
                   || inst1_bltz   && !rs_ge_z
                   || inst1_bltzal && !rs_ge_z
                   || inst1_bgezal &&  rs_ge_z
                   || inst1_j
                   || inst1_jal
                   || inst1_jr
                   || inst1_jalr
                  ) & ds_valid;
assign br_target = (inst1_beq || inst1_bne || inst1_bgez || inst1_bgtz || 
                    inst1_blez || inst1_bltz || inst1_bltzal || inst1_bgezal) ? (inst2_pc + {{14{inst1_imm[15]}}, inst1_imm[15:0], 2'b0}) :
                   (inst1_jr || inst1_jalr)                                   ? inst1_br_rs_value :
                    /*inst_jal || inst_j*/                                      {inst2_pc[31:28], inst1_jidx[25:0], 2'b0};

assign br_leave = br_taken; //& ds_to_es_valid & es_allowin;

assign br_bus = {br_leave, br_target};
assign ds_branch = br_leave;



// inst 2
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
wire        inst2_beq;
wire        inst2_bne;
wire        inst2_bgez;
wire        inst2_bgtz;
wire        inst2_blez;
wire        inst2_bltz;
wire        inst2_j;
wire        inst2_bltzal;
wire        inst2_bgezal; 
wire        inst2_jalr;
wire        inst2_jal;
wire        inst2_jr;
wire        inst2_mfc0;
wire        inst2_mtc0;
wire        inst2_eret;
wire        inst2_syscall;
wire        inst2_break;
wire        inst2_tlbp;
wire        inst2_tlbr;
wire        inst2_tlbwi;

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

assign inst2_lui    = inst2_op_d[6'h0f] & inst2_rs_d[5'h00];

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

assign inst2_beq    = inst2_op_d[6'h04];
assign inst2_bne    = inst2_op_d[6'h05];
assign inst2_bgez   = inst2_op_d[6'h01] & inst2_rt_d[5'h01];
assign inst2_bgtz   = inst2_op_d[6'h07] & inst2_rt_d[5'h00];
assign inst2_blez   = inst2_op_d[6'h06] & inst2_rt_d[5'h00];
assign inst2_bltz   = inst2_op_d[6'h01] & inst2_rt_d[5'h00];
assign inst2_j      = inst2_op_d[6'h02];
assign inst2_bltzal = inst2_op_d[6'h01] & inst2_rt_d[5'h10];
assign inst2_bgezal = inst2_op_d[6'h01] & inst2_rt_d[5'h11];
assign inst2_jalr   = inst2_op_d[6'h00] & inst2_rt_d[5'h00] & inst2_func_d[6'h09] & inst2_sa_d[5'h00];
assign inst2_jal    = inst2_op_d[6'h03];
assign inst2_jr     = inst2_op_d[6'h00] & inst2_func_d[6'h08] & inst2_rt_d[5'h00] & inst2_rd_d[5'h00] & inst2_sa_d[5'h00];

assign inst2_mfc0   = inst2_op_d[6'h10] & inst2_rs_d[5'h00] & inst2_sa_d[5'h00] & (inst2_inst[5: 3]==3'b0);
assign inst2_mtc0   = inst2_op_d[6'h10] & inst2_rs_d[5'h04] & inst2_sa_d[5'h00] & (inst2_inst[5: 3]==3'b0);
assign inst2_eret   = inst2_op_d[6'h10] & inst2_rs_d[5'h10] & inst2_rt_d[5'h00] & inst2_rd_d[5'h00] & inst2_sa_d[5'h00] & inst2_func_d[6'h18];
assign inst2_syscall= inst2_op_d[6'h00] & inst2_func_d[6'h0c];
assign inst2_break  = inst2_op_d[6'h00] & inst2_func_d[6'h0d];

assign inst2_tlbp   = inst2_op_d[6'h10] & inst2_func_d[6'h08] & inst2_rs_d[5'h10] & inst2_rt_d[5'h00] & inst2_rd_d[5'h00] & inst2_sa_d[5'h00];
assign inst2_tlbr   = inst2_op_d[6'h10] & inst2_func_d[6'h01] & inst2_rs_d[5'h10] & inst2_rt_d[5'h00] & inst2_rd_d[5'h00] & inst2_sa_d[5'h00];
assign inst2_tlbwi  = inst2_op_d[6'h10] & inst2_func_d[6'h02] & inst2_rs_d[5'h10] & inst2_rt_d[5'h00] & inst2_rd_d[5'h00] & inst2_sa_d[5'h00];


assign inst2_alu_op[ 0] = inst2_add | inst2_addu | inst2_addi | inst2_addiu | inst2_load_op | inst2_store_op | inst2_jal | inst2_bgezal | inst2_bltzal | inst2_jalr;
assign inst2_alu_op[ 1] = inst2_sub | inst2_subu;
assign inst2_alu_op[ 2] = inst2_slt | inst2_slti;
assign inst2_alu_op[ 3] = inst2_sltu | inst2_sltiu;
assign inst2_alu_op[ 4] = inst2_and | inst2_andi;
assign inst2_alu_op[ 5] = inst2_nor;
assign inst2_alu_op[ 6] = inst2_or | inst2_ori;
assign inst2_alu_op[ 7] = inst2_xor | inst2_xori;
assign inst2_alu_op[ 8] = inst2_sll | inst2_sllv;
assign inst2_alu_op[ 9] = inst2_srl | inst2_srlv;
assign inst2_alu_op[10] = inst2_sra | inst2_srav;
assign inst2_alu_op[11] = inst2_lui;
assign inst2_alu_op[12] = inst2_mult;
assign inst2_alu_op[13] = inst2_multu;
assign inst2_alu_op[14] = inst2_div;
assign inst2_alu_op[15] = inst2_divu;

assign inst2_ds_tlbp   = inst2_tlbp;
assign inst2_ds_tlbr   = inst2_tlbr;
assign inst2_ds_tlbwi  = inst2_tlbwi;
assign inst2_ds_eret   = inst2_eret;

assign inst2_load_op   = inst2_lb | inst2_lbu | inst2_lh | inst2_lhu | inst2_lw | inst2_lwl | inst2_lwr;
assign inst2_store_op  = inst2_sb | inst2_sh | inst2_sw | inst2_swl | inst2_swr;
assign inst2_hi_op     = inst2_mfhi;
assign inst2_lo_op     = inst2_mflo;
assign inst2_cp0_op    = inst2_mfc0;

assign inst2_src1_is_sa   = inst2_sll | inst2_srl | inst2_sra;
assign inst2_src1_is_pc   = inst2_jal | inst2_bgezal | inst2_bltzal | inst2_jalr;
assign inst2_src2_is_imm  = inst2_addi | inst2_addiu | inst2_slti | inst2_sltiu | inst2_lui ;//| load_op | store_op;
assign inst2_src2_is_imm16= inst2_andi | inst2_ori | inst2_xori;
assign inst2_src2_is_8    = inst2_jal | inst2_bgezal | inst2_bltzal | inst2_jalr;

assign inst2_dst_is_r31   = inst2_jal | inst2_bgezal | inst2_bltzal | inst2_jalr;
assign inst2_dst_is_rt    = inst2_addi | inst2_addiu | inst2_slti | inst2_sltiu | inst2_andi | inst2_ori | inst2_xori | inst2_lui | inst2_load_op | inst2_mfc0;
assign inst2_gr_we        = ~inst2_store_op & ~inst2_beq & ~inst2_bne & ~inst2_bgez & ~inst2_bgtz & ~inst2_blez & ~inst2_bltz & ~inst2_jr & ~inst2_j & 
                            ~inst2_div & ~inst2_divu & ~inst2_mult & ~inst2_multu & ~inst2_mthi & ~inst2_mtlo & ~inst2_syscall & ~inst2_break & ~inst2_eret & 
                            ~inst2_mtc0 & ~inst2_tlbp & ~inst2_tlbr & ~inst2_tlbwi;
assign inst2_mem_we       = inst2_store_op;
assign inst2_hi_we        = inst2_div | inst2_divu | inst2_mult | inst2_multu | inst2_mthi;
assign inst2_lo_we        = inst2_div | inst2_divu | inst2_mult | inst2_multu | inst2_mtlo;
assign inst2_cp0_we       = inst2_mtc0;
assign inst2_hl_src_from_mul   = inst2_mult | inst2_multu;
assign inst2_hl_src_from_div   = inst2_div  | inst2_divu;
assign inst2_load_store_type   = {inst2_lb | inst2_sb,       //[b,bu,h,hu,w,wl,wr]
                                 inst2_lbu,
                                 inst2_lh | inst2_sh,
                                 inst2_lhu,
                                 inst2_lw | inst2_sw,
                                 inst2_lwl | inst2_swl,
                                 inst2_lwr | inst2_swr};
assign inst2_cp0_addr     = {inst2_rd[4:0], inst2_func[2:0]};
assign inst2_detect_overflow  = inst2_add | inst2_addi | inst2_sub;

assign inst2_dest         = inst2_dst_is_r31 ? 5'd31 :
                            inst2_dst_is_rt  ? inst2_rt : 
                                               inst2_rd;

// exception
wire inst2_ds_Sys;
wire inst2_ds_Bp;
wire inst2_ds_RI;
assign inst2_ds_Sys = inst2_syscall;
assign inst2_ds_Bp = inst2_break;
assign inst2_ds_RI = ~inst2_add & ~inst2_addu & ~inst2_addi & ~inst2_addiu & ~inst2_sub & ~inst2_subu &
                     ~inst2_slt & ~inst2_sltu & ~inst2_slti & ~inst2_sltiu &
                     ~inst2_and & ~inst2_andi & ~inst2_or & ~inst2_ori & ~inst2_xor & ~inst2_xori & ~inst2_nor &
                     ~inst2_sll & ~inst2_sllv & ~inst2_srl & ~inst2_srlv & ~inst2_sra & ~inst2_srav &
                     ~inst2_mult & ~inst2_multu & ~inst2_div & ~inst2_divu & ~inst2_mfhi & ~inst2_mthi & ~inst2_mflo & ~inst2_mtlo &
                     ~inst2_lui & ~inst2_lb & ~inst2_lh & ~inst2_lw & ~inst2_lbu & ~inst2_lhu & ~inst2_lwl & ~inst2_lwr &
                     ~inst2_sb & ~inst2_sh & ~inst2_sw & ~inst2_swl & ~inst2_swr &
                     ~inst2_beq & ~inst2_bne & ~inst2_bgez & ~inst2_bgtz & ~inst2_blez & ~inst2_bltz &
                     ~inst2_j & ~inst2_bltzal & ~inst2_bgezal & ~inst2_jalr & ~inst2_jal & ~inst2_jr &
                     ~inst2_mfc0 & ~inst2_mtc0 & ~inst2_eret & ~inst2_syscall & ~inst2_break &
                     ~inst2_tlbp & ~inst2_tlbr & ~inst2_tlbwi;

assign inst2_except  = inst2_ds_Sys | inst2_ds_Bp | inst2_ds_RI;
assign inst2_exccode = (inst2_ds_RI) ? 5'ha: 
                       (inst2_ds_Sys)? 5'h8: 
                       (inst2_ds_Bp) ? 5'h9: 
                                       5'h0;

assign inst2_ds_except  = inst2_fs_except | inst2_except;
assign inst2_ds_exccode = //(has_int         ) ? 5'h0: 
                          (inst2_fs_except ) ? inst2_fs_exccode: 
                                               inst2_exccode;


//relevant & block
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

wire        inst1_r1_need;
wire        inst1_r2_need;
wire        inst1_es_inst1_r1_relevant;
wire        inst1_es_inst1_r2_relevant;
wire        inst1_es_inst2_r1_relevant;
wire        inst1_es_inst2_r2_relevant;
wire        inst1_pms_inst1_r1_relevant;
wire        inst1_pms_inst1_r2_relevant;
wire        inst1_pms_inst2_r1_relevant;
wire        inst1_pms_inst2_r2_relevant;
wire        inst1_ms_inst1_r1_relevant;
wire        inst1_ms_inst1_r2_relevant;
wire        inst1_ms_inst2_r1_relevant;
wire        inst1_ms_inst2_r2_relevant;
wire        inst1_ws_inst1_r1_relevant;
wire        inst1_ws_inst1_r2_relevant;
wire        inst1_ws_inst2_r1_relevant;
wire        inst1_ws_inst2_r2_relevant;

wire        inst2_r1_need;
wire        inst2_r2_need;
wire        inst2_es_inst1_r1_relevant;
wire        inst2_es_inst1_r2_relevant;
wire        inst2_es_inst2_r1_relevant;
wire        inst2_es_inst2_r2_relevant;
wire        inst2_pms_inst1_r1_relevant;
wire        inst2_pms_inst1_r2_relevant;
wire        inst2_pms_inst2_r1_relevant;
wire        inst2_pms_inst2_r2_relevant;
wire        inst2_ms_inst1_r1_relevant;
wire        inst2_ms_inst1_r2_relevant;
wire        inst2_ms_inst2_r1_relevant;
wire        inst2_ms_inst2_r2_relevant;
wire        inst2_ws_inst1_r1_relevant;
wire        inst2_ws_inst1_r2_relevant;
wire        inst2_ws_inst2_r1_relevant;
wire        inst2_ws_inst2_r2_relevant;

wire        inst1_es_block;
wire        inst1_pms_block;
wire        inst1_ms_block;

wire        inst2_es_block;
wire        inst2_pms_block;
wire        inst2_ms_block;

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

assign inst1_r1_need = inst1_addiu  || inst1_addi  || inst1_addu || inst1_add   || inst1_subu || inst1_sub  || 
                       inst1_and    || inst1_andi  || inst1_nor  || inst1_or    || inst1_ori  || inst1_xor  || inst1_xori || 
                       inst1_slt    || inst1_sltu  || inst1_slti || inst1_sltiu || inst1_sllv || inst1_srav || inst1_srlv || 
                       inst1_mult   || inst1_multu || inst1_div  || inst1_divu  || inst1_mthi || inst1_mtlo || 
                       inst1_beq    || inst1_bne   || inst1_bgez || inst1_bgtz  || inst1_blez || inst1_bltz || 
                       inst1_bltzal || inst1_bgezal|| inst1_jr   || inst1_jalr || 
                       inst1_lw     || inst1_lb    || inst1_lbu  || inst1_lh    || inst1_lhu  || inst1_lwl  || inst1_lwr || 
                       inst1_sw     || inst1_sb    || inst1_sh   || inst1_swl   || inst1_swr;
assign inst1_r2_need = inst1_add  || inst1_addu  || inst1_sub || inst1_subu || 
                       inst1_and  || inst1_nor   || inst1_or  || inst1_xor  || 
                       inst1_slt  || inst1_sltu  || inst1_sll || inst1_sra  || inst1_srl || inst1_sllv || inst1_srav || inst1_srlv || 
                       inst1_mult || inst1_multu || inst1_div || inst1_divu || 
                       inst1_beq  || inst1_bne   || inst1_lwl || inst1_lwr  ||
                       inst1_sw   || inst1_sb    || inst1_sh  || inst1_swl  || inst1_swr || inst1_mtc0;

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

assign inst1_es_inst1_r1_relevant  = ds_valid & inst1_r1_need & es_valid  & es_inst1_gr_we  & ~inst1_rs_d[5'h00] & (inst1_rs == es_inst1_dest);
assign inst1_es_inst2_r1_relevant  = ds_valid & inst1_r1_need & es_valid  & es_inst2_gr_we  & ~inst1_rs_d[5'h00] & (inst1_rs == es_inst2_dest);
assign inst1_pms_inst1_r1_relevant = ds_valid & inst1_r1_need & pms_valid & pms_inst1_gr_we & ~inst1_rs_d[5'h00] & (inst1_rs == pms_inst1_dest);
assign inst1_pms_inst2_r1_relevant = ds_valid & inst1_r1_need & pms_valid & pms_inst2_gr_we & ~inst1_rs_d[5'h00] & (inst1_rs == pms_inst2_dest);
assign inst1_ms_inst1_r1_relevant  = ds_valid & inst1_r1_need & ms_valid  & ms_inst1_gr_we  & ~inst1_rs_d[5'h00] & (inst1_rs == ms_inst1_dest);
assign inst1_ms_inst2_r1_relevant  = ds_valid & inst1_r1_need & ms_valid  & ms_inst2_gr_we  & ~inst1_rs_d[5'h00] & (inst1_rs == ms_inst2_dest);
assign inst1_ws_inst1_r1_relevant  = ds_valid & inst1_r1_need & ws_valid  & ws_inst1_gr_we  & ~inst1_rs_d[5'h00] & (inst1_rs == ws_inst1_dest);
assign inst1_ws_inst2_r1_relevant  = ds_valid & inst1_r1_need & ws_valid  & ws_inst2_gr_we  & ~inst1_rs_d[5'h00] & (inst1_rs == ws_inst2_dest);

assign inst1_es_inst1_r2_relevant  = ds_valid & inst1_r2_need & es_valid  & es_inst1_gr_we  & ~inst1_rt_d[5'h00] & (inst1_rt == es_inst1_dest);
assign inst1_es_inst2_r2_relevant  = ds_valid & inst1_r2_need & es_valid  & es_inst2_gr_we  & ~inst1_rt_d[5'h00] & (inst1_rt == es_inst2_dest);
assign inst1_pms_inst1_r2_relevant = ds_valid & inst1_r2_need & pms_valid & pms_inst1_gr_we & ~inst1_rt_d[5'h00] & (inst1_rt == pms_inst1_dest);
assign inst1_pms_inst2_r2_relevant = ds_valid & inst1_r2_need & pms_valid & pms_inst2_gr_we & ~inst1_rt_d[5'h00] & (inst1_rt == pms_inst2_dest);
assign inst1_ms_inst1_r2_relevant  = ds_valid & inst1_r2_need & ms_valid  & ms_inst1_gr_we  & ~inst1_rt_d[5'h00] & (inst1_rt == ms_inst1_dest);
assign inst1_ms_inst2_r2_relevant  = ds_valid & inst1_r2_need & ms_valid  & ms_inst2_gr_we  & ~inst1_rt_d[5'h00] & (inst1_rt == ms_inst2_dest);
assign inst1_ws_inst1_r2_relevant  = ds_valid & inst1_r2_need & ws_valid  & ws_inst1_gr_we  & ~inst1_rt_d[5'h00] & (inst1_rt == ws_inst1_dest);
assign inst1_ws_inst2_r2_relevant  = ds_valid & inst1_r2_need & ws_valid  & ws_inst2_gr_we  & ~inst1_rt_d[5'h00] & (inst1_rt == ws_inst2_dest);

assign inst2_es_inst1_r1_relevant  = ds_valid & inst2_r1_need & es_valid  & es_inst1_gr_we  & ~inst2_rs_d[5'h00] & (inst2_rs == es_inst1_dest);
assign inst2_es_inst2_r1_relevant  = ds_valid & inst2_r1_need & es_valid  & es_inst2_gr_we  & ~inst2_rs_d[5'h00] & (inst2_rs == es_inst2_dest);
assign inst2_pms_inst1_r1_relevant = ds_valid & inst2_r1_need & pms_valid & pms_inst1_gr_we & ~inst2_rs_d[5'h00] & (inst2_rs == pms_inst1_dest);
assign inst2_pms_inst2_r1_relevant = ds_valid & inst2_r1_need & pms_valid & pms_inst2_gr_we & ~inst2_rs_d[5'h00] & (inst2_rs == pms_inst2_dest);
assign inst2_ms_inst1_r1_relevant  = ds_valid & inst2_r1_need & ms_valid  & ms_inst1_gr_we  & ~inst2_rs_d[5'h00] & (inst2_rs == ms_inst1_dest);
assign inst2_ms_inst2_r1_relevant  = ds_valid & inst2_r1_need & ms_valid  & ms_inst2_gr_we  & ~inst2_rs_d[5'h00] & (inst2_rs == ms_inst2_dest);
assign inst2_ws_inst1_r1_relevant  = ds_valid & inst2_r1_need & ws_valid  & ws_inst1_gr_we  & ~inst2_rs_d[5'h00] & (inst2_rs == ws_inst1_dest);
assign inst2_ws_inst2_r1_relevant  = ds_valid & inst2_r1_need & ws_valid  & ws_inst2_gr_we  & ~inst2_rs_d[5'h00] & (inst2_rs == ws_inst2_dest);

assign inst2_es_inst1_r2_relevant  = ds_valid & inst2_r2_need & es_valid  & es_inst1_gr_we  & ~inst2_rt_d[5'h00] & (inst2_rt == es_inst1_dest);
assign inst2_es_inst2_r2_relevant  = ds_valid & inst2_r2_need & es_valid  & es_inst2_gr_we  & ~inst2_rt_d[5'h00] & (inst2_rt == es_inst2_dest);
assign inst2_pms_inst1_r2_relevant = ds_valid & inst2_r2_need & pms_valid & pms_inst1_gr_we & ~inst2_rt_d[5'h00] & (inst2_rt == pms_inst1_dest);
assign inst2_pms_inst2_r2_relevant = ds_valid & inst2_r2_need & pms_valid & pms_inst2_gr_we & ~inst2_rt_d[5'h00] & (inst2_rt == pms_inst2_dest);
assign inst2_ms_inst1_r2_relevant  = ds_valid & inst2_r2_need & ms_valid  & ms_inst1_gr_we  & ~inst2_rt_d[5'h00] & (inst2_rt == ms_inst1_dest);
assign inst2_ms_inst2_r2_relevant  = ds_valid & inst2_r2_need & ms_valid  & ms_inst2_gr_we  & ~inst2_rt_d[5'h00] & (inst2_rt == ms_inst2_dest);
assign inst2_ws_inst1_r2_relevant  = ds_valid & inst2_r2_need & ws_valid  & ws_inst1_gr_we  & ~inst2_rt_d[5'h00] & (inst2_rt == ws_inst1_dest);
assign inst2_ws_inst2_r2_relevant  = ds_valid & inst2_r2_need & ws_valid  & ws_inst2_gr_we  & ~inst2_rt_d[5'h00] & (inst2_rt == ws_inst2_dest);


assign inst1_es_block = inst1_es_inst1_r1_relevant & (es_inst1_mfhiloc0_load | ~es_inst1_res_valid) | inst1_es_inst2_r1_relevant & (es_inst2_mfhiloc0_load | ~es_inst2_res_valid) | 
                        inst1_es_inst1_r2_relevant & (es_inst1_mfhiloc0_load | ~es_inst1_res_valid) | inst1_es_inst2_r2_relevant & (es_inst2_mfhiloc0_load | ~es_inst2_res_valid);

assign inst1_pms_block = inst1_pms_inst1_r1_relevant & pms_inst1_load | inst1_pms_inst2_r1_relevant & pms_inst2_load | 
                         inst1_pms_inst1_r2_relevant & pms_inst1_load | inst1_pms_inst2_r2_relevant & pms_inst2_load;

assign inst1_ms_block = inst1_ms_inst1_r1_relevant & (ms_inst1_load & ~ms_inst1_res_valid) | inst1_ms_inst2_r1_relevant & (ms_inst2_load & ~ms_inst2_res_valid) | 
                        inst1_ms_inst1_r2_relevant & (ms_inst1_load & ~ms_inst1_res_valid) | inst1_ms_inst2_r2_relevant & (ms_inst2_load & ~ms_inst2_res_valid);

assign inst1_readygo = ~(inst1_es_block | inst1_pms_block | inst1_ms_block);

assign inst2_es_block = inst2_es_inst1_r1_relevant & (es_inst1_mfhiloc0_load | ~es_inst1_res_valid) | inst2_es_inst2_r1_relevant & (es_inst2_mfhiloc0_load | ~es_inst2_res_valid) | 
                        inst2_es_inst1_r2_relevant & (es_inst1_mfhiloc0_load | ~es_inst1_res_valid) | inst2_es_inst2_r2_relevant & (es_inst2_mfhiloc0_load | ~es_inst2_res_valid);

assign inst2_pms_block = inst2_pms_inst1_r1_relevant & pms_inst1_load | inst2_pms_inst2_r1_relevant & pms_inst2_load | 
                         inst2_pms_inst1_r2_relevant & pms_inst1_load | inst2_pms_inst2_r2_relevant & pms_inst2_load;

assign inst2_ms_block = inst2_ms_inst1_r1_relevant & (ms_inst1_load & ~ms_inst1_res_valid) | inst2_ms_inst2_r1_relevant & (ms_inst2_load & ~ms_inst2_res_valid) | 
                        inst2_ms_inst1_r2_relevant & (ms_inst1_load & ~ms_inst1_res_valid) | inst2_ms_inst2_r2_relevant & (ms_inst2_load & ~ms_inst2_res_valid);

assign inst2_readygo = ~(inst2_es_block | inst2_pms_block | inst2_ms_block);

assign inst1_rs_value = (inst1_es_inst2_r1_relevant ) ? es_inst2_result:
                        (inst1_es_inst1_r1_relevant ) ? es_inst1_result:
                        (inst1_pms_inst2_r1_relevant) ? pms_inst2_result:
                        (inst1_pms_inst1_r1_relevant) ? pms_inst1_result:
                        (inst1_ms_inst2_r1_relevant ) ? ms_inst2_result:
                        (inst1_ms_inst1_r1_relevant ) ? ms_inst1_result:
                        (inst1_ws_inst2_r1_relevant ) ? ws_inst2_result:
                        (inst1_ws_inst1_r1_relevant ) ? ws_inst1_result:
                                                        rf_rdata_01;
assign inst1_rt_value = (inst1_es_inst2_r2_relevant ) ? es_inst2_result:
                        (inst1_es_inst1_r2_relevant ) ? es_inst1_result:
                        (inst1_pms_inst2_r2_relevant) ? pms_inst2_result:
                        (inst1_pms_inst1_r2_relevant) ? pms_inst1_result:
                        (inst1_ms_inst2_r2_relevant ) ? ms_inst2_result:
                        (inst1_ms_inst1_r2_relevant ) ? ms_inst1_result:
                        (inst1_ws_inst2_r2_relevant ) ? ws_inst2_result:
                        (inst1_ws_inst1_r2_relevant ) ? ws_inst1_result:
                                                        rf_rdata_02;

assign inst2_rs_value = (inst2_es_inst2_r1_relevant ) ? es_inst2_result:
                        (inst2_es_inst1_r1_relevant ) ? es_inst1_result:
                        (inst2_pms_inst2_r1_relevant) ? pms_inst2_result:
                        (inst2_pms_inst1_r1_relevant) ? pms_inst1_result:
                        (inst2_ms_inst2_r1_relevant ) ? ms_inst2_result:
                        (inst2_ms_inst1_r1_relevant ) ? ms_inst1_result:
                        (inst2_ws_inst2_r1_relevant ) ? ws_inst2_result:
                        (inst2_ws_inst1_r1_relevant ) ? ws_inst1_result:
                                                        rf_rdata_03;
assign inst2_rt_value = (inst2_es_inst2_r2_relevant ) ? es_inst2_result:
                        (inst2_es_inst1_r2_relevant ) ? es_inst1_result:
                        (inst2_pms_inst2_r2_relevant) ? pms_inst2_result:
                        (inst2_pms_inst1_r2_relevant) ? pms_inst1_result:
                        (inst2_ms_inst2_r2_relevant ) ? ms_inst2_result:
                        (inst2_ms_inst1_r2_relevant ) ? ms_inst1_result:
                        (inst2_ws_inst2_r2_relevant ) ? ws_inst2_result:
                        (inst2_ws_inst1_r2_relevant ) ? ws_inst1_result:
                                                        rf_rdata_04;

// self relevant
assign self_r1_relevant = ds_valid & inst2_r1_need & inst1_gr_we & ~inst2_rs_d[5'h00] & (inst2_rs == inst1_dest);
assign self_r2_relevant = ds_valid & inst2_r2_need & inst1_gr_we & ~inst2_rt_d[5'h00] & (inst2_rt == inst1_dest);

// ds_forward_bus
assign ds_forward_bus = {ds_valid, 
                         inst1_gr_we, inst1_dest, 
                         inst2_gr_we, inst2_dest};

endmodule
