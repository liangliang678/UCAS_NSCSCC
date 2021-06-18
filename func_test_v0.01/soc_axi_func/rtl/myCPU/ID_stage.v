`include "mycpu.h"

module id_stage(
    input                          clk           ,
    input                          reset         ,
    //allowin
    input                          es_allowin    ,
    output                         ds_allowin    ,
    //from fs
    input                          fs_to_ds_valid,
    input  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus  ,
    //to es
    output                         ds_to_es_valid,
    output [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus  ,
    //to fs
    output [`BR_BUS_WD       -1:0] br_bus        ,
    //to rf: for write back
    input  [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus  ,
    //data relevant
    input  [`STALL_ES_BUS_WD -1:0] stall_es_bus  ,
    input  [`STALL_MS_BUS_WD -1:0] stall_ms_bus  ,
    input  [`STALL_WS_BUS_WD -1:0] stall_ws_bus  ,
    //handle exception
    input  [31:0]                  ds_epc        ,
    input                          has_int       ,
    
    //clear stage
    input                          ds_ex         ,
    input                          ds_cancel_in ,
    input                          ds_eret_in
);

reg         ds_valid   ;
wire        ds_ready_go;

reg  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus_r;

wire [31:0] ds_badvaddr      ;
wire        fs_has_exception ;
wire [ 4:0] fs_exception_type;
wire        exception_syscall;
wire        exception_break;
wire        exception_reserve;
wire        exception_int;
wire        ds_eret;      //eret in ID, Exl -> 0

wire [31:0] ds_inst;
wire [31:0] ds_pc  ;
wire        exception_is_tlb_refill;
wire        ds_reflush;

assign {exception_is_tlb_refill, //102:102
        ds_badvaddr      ,  //101:70
        fs_has_exception ,  //69:69
        fs_exception_type,  //68:64
        ds_inst          ,  //63:32
        ds_pc               //31:0
        } = fs_to_ds_bus_r;

wire        rf_we   ;
wire [ 4:0] rf_waddr;
wire [31:0] rf_wdata;
assign {rf_we   ,  //37:37
        rf_waddr,  //36:32
        rf_wdata   //31:0
       } = ws_to_rf_bus;

wire        br_valid;
wire        br_taken;
wire [31:0] br_target;
wire        br_stall;
wire        br_likely;

wire        es_data_sram_req;
wire [ 7:0] es_cp0_addr;
wire        es_cp0_we;
wire [31:0] es_wdata;
wire        es_res_from_wb;
wire        es_res_from_mem;
wire        es_gr_we;
wire [ 4:0]  es_dest;

wire        ms_data_sram_data_ok;
wire [ 7:0] ms_cp0_addr;
wire        ms_cp0_we;
wire [31:0] ms_wdata;
wire        ms_res_from_wb;
wire        ms_non_mem_res;
wire        ms_gr_we;
wire [ 4:0] ms_dest;

wire [ 7:0] ws_cp0_addr;
wire        ws_cp0_we;
wire [31:0] ws_wdata;
wire        ws_res_from_wb;
wire        ws_gr_we;
wire [ 4:0] ws_dest;

assign {es_data_sram_req, //49:49
        es_cp0_addr    ,  //48:41
        es_cp0_we      ,  //40:40
        es_wdata       ,  //39:8
        es_res_from_wb ,  //7:7
        es_res_from_mem,  //6:6
        es_gr_we       ,  //5:5
        es_dest           //4:0
       } = stall_es_bus;
assign {ms_data_sram_data_ok,//49:49
        ms_cp0_addr    ,  //48:41
        ms_cp0_we      ,  //40:40
        ms_wdata       ,  //39:8
        ms_res_from_wb ,  //7:7
        ms_non_mem_res ,  //6:6
        ms_gr_we       ,  //5:5
        ms_dest           //4:0
       } = stall_ms_bus;
assign {ws_cp0_addr    ,  //47:40
        ws_cp0_we      ,  //39:39
        ws_wdata       ,  //38:7
        ws_res_from_wb ,  //6:6
        ws_gr_we       ,  //5:5
        ws_dest           //4:0
       } = stall_ws_bus;

reg wait_data_sram;
always @(posedge clk) begin
    if(reset)
        wait_data_sram <= 1'b0;
    else if(es_data_sram_req)                  
        wait_data_sram <= 1'b1;
    else if(ms_data_sram_data_ok)
        wait_data_sram <= 1'b0;
end

wire        ds_tlbp;
wire        ds_tlbr;
wire        ds_tlbwi;
wire [15:0] alu_op;
wire        load_op;
wire        store_op;
wire        hi_op;
wire        lo_op;
wire        cp0_op;  //mfc0
wire        branch_op;
wire        jump_op;
wire        alu_signed;
wire        src1_is_sa;
wire        src1_is_pc;
wire        src2_is_imm;
wire        src2_is_imm16;
wire        src2_is_8;
wire        res_from_mem;
wire        gr_we;
wire        mem_we;
wire        hi_we;
wire        lo_we;
wire        cp0_we;  //mtc0
wire        hl_src_from_mul;
wire        hl_src_from_div;
wire [ 4:0] dest;
wire [15:0] imm;
wire [31:0] rs_value;
wire [31:0] rt_value;
wire [ 7:0] cp0_addr;

wire [ 5:0] op;
wire [ 4:0] rs;
wire [ 4:0] rt;
wire [ 4:0] rd;
wire [ 4:0] sa;
wire [ 5:0] func;
wire [25:0] jidx;
wire [63:0] op_d;
wire [31:0] rs_d;
wire [31:0] rt_d;
wire [31:0] rd_d;
wire [31:0] sa_d;
wire [63:0] func_d;

wire        inst_add;
wire        inst_addu;
wire        inst_sub;
wire        inst_subu;
wire        inst_slt;
wire        inst_sltu;
wire        inst_and;
wire        inst_or;
wire        inst_xor;
wire        inst_nor;
wire        inst_sll;
wire        inst_srl;
wire        inst_sra;
wire        inst_sllv;
wire        inst_srlv;
wire        inst_srav;
wire        inst_mult;
wire        inst_multu;
wire        inst_div;
wire        inst_divu;
wire        inst_mfhi;
wire        inst_mflo;
wire        inst_mthi;
wire        inst_mtlo;
wire        inst_addi;
wire        inst_addiu;
wire        inst_slti;
wire        inst_sltiu;
wire        inst_lui;
wire        inst_andi;
wire        inst_ori;
wire        inst_xori;
wire        inst_lb;
wire        inst_lbu;
wire        inst_lh;
wire        inst_lhu;
wire        inst_lw;
wire        inst_lwl;
wire        inst_lwr;
wire        inst_sb;
wire        inst_sh;
wire        inst_sw;
wire        inst_swl;
wire        inst_swr;
wire        inst_beq;
wire        inst_bne;
wire        inst_bgez;
wire        inst_bgtz;
wire        inst_blez;
wire        inst_bltz;
wire        inst_j;
wire        inst_bltzal;
wire        inst_bgezal;
wire        inst_jal;
wire        inst_jr;
wire        inst_jalr;
wire        inst_syscall;
wire        inst_break;
wire        inst_eret;
wire        inst_mtc0;
wire        inst_mfc0;
wire        inst_reserve;
wire        inst_tlbp;
wire        inst_tlbr;
wire        inst_tlbwi;

wire        dst_is_r31;  
wire        dst_is_rt;   

wire        read_rs_rt;
wire        read_rs;
wire        read_rt;

wire [ 4:0] rf_raddr1;
wire [31:0] rf_rdata1;
wire [ 4:0] rf_raddr2;
wire [31:0] rf_rdata2;

wire        rs_eq_rt;
wire        rs_lt_zero;
wire        rs_gt_zero;
wire        rs_le_zero;
wire        rs_ge_zero;

wire [ 6:0] load_store_type;

wire        relevant_stall;
wire        mfc0_relevent;
wire        rs_eq_zero;
wire        rt_eq_zero;
wire        rs_eq_es;
wire        rs_eq_ms;
wire        rs_eq_ws;
wire        rt_eq_es;
wire        rt_eq_ms;
wire        rt_eq_ws;

wire        ds_has_exception;
wire [ 4:0] ds_exception_type;

reg         ds_was_br_or_jp; // to judge delay slot inst
wire        ds_bd;           // is delay slot inst

assign br_bus       = {br_valid,br_taken,br_target,br_stall};

assign ds_to_es_bus = {exception_is_tlb_refill, //208:208
                       ds_tlbp          ,  //207:207
                       ds_tlbr          ,  //206:206
                       ds_tlbwi         ,  //205:205
                       ds_eret          ,  //204:204
                       ds_badvaddr      ,  //203:172
                       ds_bd            ,  //171:171
                       alu_signed       ,  //170:170
                       ds_has_exception ,  //169:169
                       ds_exception_type,  //168:164
                       cp0_op           ,  //163:163
                       cp0_we           ,  //162:162
                       cp0_addr         ,  //161:154
                       load_store_type  ,  //153:147
                       hi_we            ,  //146:146
                       lo_we            ,  //145:145
                       hl_src_from_mul  ,  //144:144
                       hl_src_from_div  ,  //143:143
                       alu_op           ,  //142:127
                       load_op          ,  //126:126
                       hi_op            ,  //125:125
                       lo_op            ,  //124:124
                       src1_is_sa       ,  //123:123
                       src1_is_pc       ,  //122:122
                       src2_is_imm      ,  //121:121
                       src2_is_imm16    ,  //120:120
                       src2_is_8        ,  //119:119
                       gr_we            ,  //118:118
                       mem_we           ,  //117:117
                       dest             ,  //116:112
                       imm              ,  //111:96
                       rs_value         ,  //95 :64
                       rt_value         ,  //63 :32
                       ds_pc               //31 :0
                      };

assign ds_ready_go    = ~(relevant_stall | ((wait_data_sram | es_data_sram_req))) | ~ds_valid;   //wait data sram to make sure forward data is right
                                                                                                 //but ... stop because of LOAD/STORE will make ds_to_es_valid 0 and if ID inst is syscall 
assign ds_allowin     = !ds_valid || ds_ready_go && es_allowin;                                  //will make valid 0 and syscall just kills itself. All die here
assign ds_to_es_valid = ds_valid && ds_ready_go;

assign ds_reflush = ds_ex | ds_cancel_in | ds_eret_in;
always @(posedge clk) begin
    if (reset) begin
        ds_valid <= 1'b0;
    end                                                                                    
    else if (ds_ex || ds_cancel_in || ds_eret_in)
        ds_valid <= 1'b0;
    else if (ds_allowin) begin
        ds_valid <= fs_to_ds_valid;
    end
    
    if (fs_to_ds_valid && ds_allowin) begin
        fs_to_ds_bus_r <= fs_to_ds_bus;
    end
end

assign op   = ds_inst[31:26];
assign rs   = ds_inst[25:21];
assign rt   = ds_inst[20:16];
assign rd   = ds_inst[15:11];
assign sa   = ds_inst[10: 6];
assign func = ds_inst[ 5: 0];
assign imm  = ds_inst[15: 0];
assign jidx = ds_inst[25: 0];

decoder_6_64 u_dec0(.in(op  ), .out(op_d  ));
decoder_6_64 u_dec1(.in(func), .out(func_d));
decoder_5_32 u_dec2(.in(rs  ), .out(rs_d  ));
decoder_5_32 u_dec3(.in(rt  ), .out(rt_d  ));
decoder_5_32 u_dec4(.in(rd  ), .out(rd_d  ));
decoder_5_32 u_dec5(.in(sa  ), .out(sa_d  ));

assign inst_add    = op_d[6'h00] & func_d[6'h20] & sa_d[5'h00];
assign inst_addu   = op_d[6'h00] & func_d[6'h21] & sa_d[5'h00];
assign inst_sub    = op_d[6'h00] & func_d[6'h22] & sa_d[5'h00];
assign inst_subu   = op_d[6'h00] & func_d[6'h23] & sa_d[5'h00];
assign inst_slt    = op_d[6'h00] & func_d[6'h2a] & sa_d[5'h00];
assign inst_sltu   = op_d[6'h00] & func_d[6'h2b] & sa_d[5'h00];
assign inst_and    = op_d[6'h00] & func_d[6'h24] & sa_d[5'h00];
assign inst_or     = op_d[6'h00] & func_d[6'h25] & sa_d[5'h00];
assign inst_xor    = op_d[6'h00] & func_d[6'h26] & sa_d[5'h00];
assign inst_nor    = op_d[6'h00] & func_d[6'h27] & sa_d[5'h00];
assign inst_sll    = op_d[6'h00] & func_d[6'h00] & rs_d[5'h00];
assign inst_srl    = op_d[6'h00] & func_d[6'h02] & rs_d[5'h00];
assign inst_sra    = op_d[6'h00] & func_d[6'h03] & rs_d[5'h00];
assign inst_sllv   = op_d[6'h00] & func_d[6'h04] & sa_d[5'h00];
assign inst_srlv   = op_d[6'h00] & func_d[6'h06] & sa_d[5'h00];
assign inst_srav   = op_d[6'h00] & func_d[6'h07] & sa_d[5'h00];
assign inst_mult   = op_d[6'h00] & func_d[6'h18] & rd_d[5'h00] & sa_d[5'h00];
assign inst_multu  = op_d[6'h00] & func_d[6'h19] & rd_d[5'h00] & sa_d[5'h00];
assign inst_div    = op_d[6'h00] & func_d[6'h1a] & rd_d[5'h00] & sa_d[5'h00];
assign inst_divu   = op_d[6'h00] & func_d[6'h1b] & rd_d[5'h00] & sa_d[5'h00];
assign inst_mfhi   = op_d[6'h00] & func_d[6'h10] & rs_d[5'h00] & rt_d[5'h00] & sa_d[5'h00];
assign inst_mflo   = op_d[6'h00] & func_d[6'h12] & rs_d[5'h00] & rt_d[5'h00] & sa_d[5'h00];
assign inst_mthi   = op_d[6'h00] & func_d[6'h11] & rd_d[5'h00] & rt_d[5'h00] & sa_d[5'h00];
assign inst_mtlo   = op_d[6'h00] & func_d[6'h13] & rd_d[5'h00] & rt_d[5'h00] & sa_d[5'h00];
assign inst_addi   = op_d[6'h08];
assign inst_addiu  = op_d[6'h09];
assign inst_slti   = op_d[6'h0a];
assign inst_sltiu  = op_d[6'h0b];
assign inst_lui    = op_d[6'h0f] & rs_d[5'h00];
assign inst_andi   = op_d[6'h0c];
assign inst_ori    = op_d[6'h0d];
assign inst_xori   = op_d[6'h0e];
assign inst_lb     = op_d[6'h20];
assign inst_lbu    = op_d[6'h24];
assign inst_lh     = op_d[6'h21];
assign inst_lhu    = op_d[6'h25];
assign inst_lw     = op_d[6'h23];
assign inst_lwl    = op_d[6'h22];
assign inst_lwr    = op_d[6'h26];
assign inst_sb     = op_d[6'h28];
assign inst_sh     = op_d[6'h29];
assign inst_sw     = op_d[6'h2b];
assign inst_swl    = op_d[6'h2a];
assign inst_swr    = op_d[6'h2e];
assign inst_beq    = op_d[6'h04];
assign inst_bne    = op_d[6'h05];
assign inst_bgez   = op_d[6'h01] & rt_d[5'h01];
assign inst_bgtz   = op_d[6'h07] & rt_d[5'h00];
assign inst_blez   = op_d[6'h06] & rt_d[5'h00];
assign inst_bltz   = op_d[6'h01] & rt_d[5'h00];
assign inst_j      = op_d[6'h02];
assign inst_bltzal = op_d[6'h01] & rt_d[5'h10];
assign inst_bgezal = op_d[6'h01] & rt_d[5'h11];
assign inst_jal    = op_d[6'h03];
assign inst_jr     = op_d[6'h00] & func_d[6'h08] & rt_d[5'h00] & rd_d[5'h00] & sa_d[5'h00];
assign inst_jalr   = op_d[6'h00] & func_d[6'h09] & rt_d[5'h00] & sa_d[5'h00];
assign inst_syscall= op_d[6'h00] & func_d[6'h0c];
assign inst_break  = op_d[6'h00] & func_d[6'h0d];
assign inst_eret   = op_d[6'h10] & func_d[6'h18] & rs_d[5'h10] & rt_d[5'h00] & rd_d[5'h00] & sa_d[5'h00];
assign inst_tlbp   = op_d[6'h10] & func_d[6'h08] & rs_d[5'h10] & rt_d[5'h00] & rd_d[5'h00] & sa_d[5'h00];
assign inst_tlbr   = op_d[6'h10] & func_d[6'h01] & rs_d[5'h10] & rt_d[5'h00] & rd_d[5'h00] & sa_d[5'h00];
assign inst_tlbwi  = op_d[6'h10] & func_d[6'h02] & rs_d[5'h10] & rt_d[5'h00] & rd_d[5'h00] & sa_d[5'h00];
assign inst_mtc0   = op_d[6'h10] & rs_d[5'h04]   & ~func[5]    & ~func[4]    & ~func[3];
assign inst_mfc0   = op_d[6'h10] & rs_d[5'h00]   & ~func[5]    & ~func[4]    & ~func[3];
assign inst_reserve= ~(inst_add || inst_addu || inst_sub || inst_subu || inst_slt || inst_sltu || inst_and || inst_or || inst_xor || inst_nor ||
                       inst_sll || inst_srl || inst_sra || inst_sllv || inst_srlv || inst_srav || inst_mult || inst_multu || inst_div || inst_divu ||
                       inst_mfhi || inst_mflo || inst_mthi || inst_mtlo || inst_addi || inst_addiu || inst_slti || inst_sltiu || inst_lui || inst_andi ||
                       inst_ori || inst_xori || inst_lb || inst_lbu || inst_lh || inst_lhu || inst_lw || inst_lwl || inst_lwr || inst_sb || inst_sh ||
                       inst_sw || inst_swl || inst_swr || inst_beq || inst_bne || inst_bgez || inst_bgtz || inst_blez || inst_bltz || inst_j ||
                       inst_bltzal || inst_bgezal || inst_jal || inst_jr || inst_jalr || inst_syscall || inst_break || inst_eret || inst_mtc0 || inst_mfc0 ||
                       inst_tlbp || inst_tlbr || inst_tlbwi);

assign alu_op[ 0] = inst_add | inst_addu | inst_addi | inst_addiu | load_op | store_op | inst_jal | inst_bgezal | inst_bltzal | inst_jalr;
assign alu_op[ 1] = inst_sub | inst_subu;
assign alu_op[ 2] = inst_slt | inst_slti;
assign alu_op[ 3] = inst_sltu | inst_sltiu;
assign alu_op[ 4] = inst_and | inst_andi;
assign alu_op[ 5] = inst_nor;
assign alu_op[ 6] = inst_or | inst_ori;
assign alu_op[ 7] = inst_xor | inst_xori;
assign alu_op[ 8] = inst_sll | inst_sllv;
assign alu_op[ 9] = inst_srl | inst_srlv;
assign alu_op[10] = inst_sra | inst_srav;
assign alu_op[11] = inst_lui;
assign alu_op[12] = inst_mult;
assign alu_op[13] = inst_multu;
assign alu_op[14] = inst_div;
assign alu_op[15] = inst_divu;

assign ds_tlbp   = inst_tlbp;
assign ds_tlbr   = inst_tlbr;
assign ds_tlbwi  = inst_tlbwi;

assign load_op   = inst_lb | inst_lbu | inst_lh | inst_lhu | inst_lw | inst_lwl | inst_lwr;
assign store_op  = inst_sb | inst_sh | inst_sw | inst_swl | inst_swr;
assign hi_op     = inst_mfhi;
assign lo_op     = inst_mflo;
assign cp0_op    = inst_mfc0;
assign branch_op = inst_beq | inst_bne | inst_bgez | inst_bgezal | inst_bgtz | inst_blez | inst_bltz | inst_bltzal;
assign jump_op   = inst_j | inst_jal | inst_jalr | inst_jr;

assign alu_signed   = inst_add | inst_addi | inst_sub | inst_slt | inst_mult | inst_div;
assign src1_is_sa   = inst_sll | inst_srl | inst_sra;
assign src1_is_pc   = inst_jal | inst_bgezal | inst_bltzal | inst_jalr;
assign src2_is_imm  = inst_addi | inst_addiu | inst_slti | inst_sltiu | inst_lui ;//| load_op | store_op;
assign src2_is_imm16= inst_andi | inst_ori | inst_xori;
assign src2_is_8    = inst_jal | inst_bgezal | inst_bltzal | inst_jalr;
assign res_from_mem = load_op;
assign dst_is_r31   = inst_jal | inst_bgezal | inst_bltzal | inst_jalr;
assign dst_is_rt    = inst_addi | inst_addiu | inst_slti | inst_sltiu | inst_andi | inst_ori | inst_xori | inst_lui | load_op | inst_mfc0;
assign gr_we        = ~store_op & ~inst_beq & ~inst_bne & ~inst_bgez & ~inst_bgtz & ~inst_blez & ~inst_bltz & ~inst_jr & ~inst_j & ~inst_div & ~inst_divu & ~inst_mult & ~inst_multu & ~inst_mthi & ~inst_mtlo & ~inst_syscall & ~inst_break & ~inst_eret & ~inst_mtc0 & ~inst_tlbp & ~inst_tlbr & ~inst_tlbwi;
assign mem_we       = store_op;
assign hi_we        = inst_div | inst_divu | inst_mult | inst_multu | inst_mthi;
assign lo_we        = inst_div | inst_divu | inst_mult | inst_multu | inst_mtlo;
assign cp0_we       = inst_mtc0;
assign hl_src_from_mul   = inst_mult | inst_multu;
assign hl_src_from_div   = inst_div  | inst_divu;
assign load_store_type   = {inst_lb | inst_sb,       //[b,bu,h,hu,w,wl,wr]
                            inst_lbu,
                            inst_lh | inst_sh,
                            inst_lhu,
                            inst_lw | inst_sw,
                            inst_lwl | inst_swl,
                            inst_lwr | inst_swr};
assign cp0_addr     = {rd[4:0], func[2:0]};

assign read_rs_rt   = inst_add | inst_addu | inst_sub | inst_subu | inst_slt | inst_sltu | inst_div | inst_divu | inst_mult | inst_multu | inst_and | inst_or | inst_xor | inst_nor | inst_sllv | inst_srav | inst_srlv | inst_beq | inst_bne;
assign read_rs      = read_rs_rt | inst_addi | inst_addiu | inst_slti | inst_sltiu | inst_andi | inst_ori | inst_xori | inst_jr | inst_jalr | load_op | store_op | inst_bgez | inst_blez | inst_bltz | inst_bgezal | inst_bltzal | inst_mthi | inst_mtlo | inst_mtc0;  //store and load need read rf[base]==rs
assign read_rt      = read_rs_rt | inst_sll | inst_srl | inst_sra | store_op | inst_lwl | inst_lwr | inst_mtc0;

assign dest         = dst_is_r31 ? 5'd31 :
                      dst_is_rt  ? rt    : 
                                   rd;

assign rf_raddr1 = rs;
assign rf_raddr2 = rt;
regfile u_regfile(
    .clk    (clk      ),
    .raddr1 (rf_raddr1),
    .rdata1 (rf_rdata1),
    .raddr2 (rf_raddr2),
    .rdata2 (rf_rdata2),
    .we     (rf_we    ),
    .waddr  (rf_waddr ),
    .wdata  (rf_wdata )
    );

assign rs_value = //es_gr_we & rs_eq_es ? es_wdata :
                  ms_gr_we & rs_eq_ms & ms_non_mem_res ? ms_wdata :
                  ws_gr_we & rs_eq_ws ? ws_wdata :
                  rf_rdata1;
assign rt_value = //es_gr_we & rt_eq_es ? es_wdata :
                  ms_gr_we & rt_eq_ms & ms_non_mem_res ? ms_wdata :
                  ws_gr_we & rt_eq_ws ? ws_wdata :
                  rf_rdata2;

assign rs_eq_rt   = (rs_value == rt_value);
assign rs_lt_zero = rs_value[31];
assign rs_gt_zero = ~rs_le_zero;
assign rs_le_zero = rs_lt_zero | rs_value == 0;
assign rs_ge_zero = ~rs_lt_zero;

assign br_valid = ds_ready_go && es_allowin && ds_valid && br_taken;
assign br_taken = (   inst_beq    &&  rs_eq_rt
                   || inst_bne    && !rs_eq_rt
                   || inst_bgez   &&  rs_ge_zero
                   || inst_bgezal &&  rs_ge_zero
                   || inst_bgtz   &&  rs_gt_zero
                   || inst_blez   &&  rs_le_zero
                   || inst_bltz   &&  rs_lt_zero
                   || inst_bltzal &&  rs_lt_zero
                   || inst_j
                   || inst_jal
                   || inst_jr
                   || inst_jalr
                  ) && ds_valid && ~ds_reflush && ds_ready_go;   
assign br_target = 
                   (branch_op)             ? (ds_pc + {{14{imm[15]}}, imm[15:0], 2'b0} + 3'b100) :
                   (inst_jr  || inst_jalr) ? rs_value :
                  /*inst_jal || inst_j*/     {ds_pc[31:28], jidx[25:0], 2'b0};

assign rs_eq_zero = (rs == 0);
assign rt_eq_zero = (rt == 0);

assign rs_eq_es = (rs == es_dest) & ~rs_eq_zero;
assign rs_eq_ms = (rs == ms_dest) & ~rs_eq_zero;
assign rs_eq_ws = (rs == ws_dest) & ~rs_eq_zero;
assign rt_eq_es = (rt == es_dest) & ~rt_eq_zero;
assign rt_eq_ms = (rt == ms_dest) & ~rt_eq_zero;
assign rt_eq_ws = (rt == ws_dest) & ~rt_eq_zero;
assign relevant_stall = read_rs & ms_gr_we & rs_eq_ms & ~ms_non_mem_res |
                        read_rt & ms_gr_we & rt_eq_ms & ~ms_non_mem_res |
                        read_rs & es_gr_we & rs_eq_es | //& es_res_from_mem |
                        read_rt & es_gr_we & rt_eq_es | //& es_res_from_mem |
                        mfc0_relevent;
assign br_stall = ~ds_ready_go ;

assign exception_syscall = inst_syscall;
assign exception_break   = inst_break;
assign exception_reserve = inst_reserve;
assign exception_int     = has_int;
assign ds_has_exception  = exception_syscall || exception_break || exception_reserve || exception_int || fs_has_exception;

assign ds_exception_type = (exception_int     ) ? 5'h0 :
                           (fs_has_exception  ) ? fs_exception_type :
                           (exception_reserve ) ? 5'ha :
                           (exception_syscall ) ? 5'h8 :
                         /*(exception_break   )*/ 5'h9 ;

assign mfc0_relevent = read_rt & es_gr_we & rt_eq_es & es_res_from_wb |
                       read_rt & ms_gr_we & rt_eq_ms & ms_res_from_wb |
                       read_rt & ws_gr_we & rt_eq_ws & ws_res_from_wb |
                       read_rs & es_gr_we & rs_eq_es & es_res_from_wb |
                       read_rs & ms_gr_we & rs_eq_ms & ms_res_from_wb |
                       read_rs & ws_gr_we & rs_eq_ws & ws_res_from_wb;

always@(posedge clk)
begin
  if(reset)
    ds_was_br_or_jp <= 1'b0;
  else  
    ds_was_br_or_jp <= (branch_op | jump_op);
end

assign ds_bd = (ds_was_br_or_jp == 1'b1);
assign ds_eret = inst_eret;

endmodule
