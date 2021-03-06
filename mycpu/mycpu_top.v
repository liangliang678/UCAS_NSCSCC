module mycpu_top(
    input  [ 5:0] ext_int,

    input         aclk,
    input         aresetn,
    
    output [ 3:0] arid,
    output [31:0] araddr,
    output [ 7:0] arlen,
    output [ 2:0] arsize,
    output [ 1:0] arburst,
    output [ 1:0] arlock,
    output [ 3:0] arcache,
    output [ 2:0] arprot,
    output        arvalid,
    input         arready,
    // read response
    input  [ 3:0] rid,
    input  [31:0] rdata,
    input  [ 1:0] rresp,
    input         rlast,
    input         rvalid,
    output        rready,
    // write request
    output [ 3:0] awid,
    output [31:0] awaddr,
    output [ 7:0] awlen,
    output [ 2:0] awsize,
    output [ 1:0] awburst,
    output [ 1:0] awlock,
    output [ 3:0] awcache,
    output [ 2:0] awprot,
    output        awvalid,
    input         awready,
    // write data
    output [ 3:0] wid,
    output [31:0] wdata,
    output [ 3:0] wstrb,
    output        wlast,
    output        wvalid,
    input         wready,
    // write response
    input  [ 3:0] bid,
    input  [ 1:0] bresp,
    input         bvalid,
    output        bready,

    // trace debug interface
    output [31:0] debug_wb_pc,
    output [ 3:0] debug_wb_rf_wen,
    output [ 4:0] debug_wb_rf_wnum,
    output [31:0] debug_wb_rf_wdata
);
reg         reset;
always @(posedge aclk) reset <= ~aresetn;

wire         clear_all;
wire [31:0]  reflush_pc;

wire         fs_allowin;
wire         ds_allowin;
wire         es_allowin;
wire         pms_allowin;
wire         ms_allowin;
wire         ws_allowin;
wire         to_fs_valid;
wire         fs_to_ds_valid;
wire         ds_to_es_valid;
wire         es_to_pms_valid;
wire         pms_to_ms_valid;
wire         ms_to_ws_valid;
 
wire [ 4:0]  fs_rf_raddr1;
wire [ 4:0]  fs_rf_raddr2;
wire [31:0]  ds_rf_rdata1;
wire [31:0]  ds_rf_rdata2;
wire         ds_branch;

wire  [`BR_BUS_WD       -1:0] br_bus;
wire  [`PF_TO_FS_BUS_WD -1:0] preif_to_fs_bus;
wire  [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus;
wire  [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus;
wire  [`ES_TO_PMS_BUS_WD -1:0] es_to_pms_bus;
wire  [`PMS_TO_MS_BUS_WD -1:0] pms_to_ms_bus;
wire  [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus;
wire  [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus;

wire  [`DS_FORWARD_BUS_WD -1:0] ds_forward_bus;
wire  [`ES_FORWARD_BUS_WD -1:0] es_forward_bus;
wire  [`PMS_FORWARD_BUS_WD -1:0] pms_forward_bus;
wire  [`MS_FORWARD_BUS_WD -1:0] ms_forward_bus;
wire  [`WS_FORWARD_BUS_WD -1:0] ws_forward_bus;

wire         fs_no_inst_wait;
wire [ 5:0]  inst_offset;

// cache
wire           inst_cache_valid;
wire           inst_cache_uncache;
wire  [ 19:0]  inst_cache_tag;
wire  [  6:0]  inst_cache_index;
wire  [  4:0]  inst_cache_offset;
wire           inst_cache_addr_ok;
wire           inst_cache_data_ok;
wire [255:0]   inst_cache_rdata;
wire [  3:0]   inst_cache_data_num;
wire           inst_cache_rd_req;
wire           inst_cache_rd_type;
wire [ 31:0]   inst_cache_rd_addr;
wire           inst_cache_rd_rdy;
wire           inst_cache_ret_valid;
wire  [255:0]  inst_cache_ret_data;

//mul
wire [63:0]    es_inst1_mul_res;
wire [63:0]    es_inst2_mul_res;
wire [63:0]    es_mul_res;

//cache related
wire           inst1_data_cache_valid;
wire           inst1_data_cache_op;
wire           inst1_data_cache_uncache;
wire  [ 19:0]  inst1_data_cache_tag;
wire  [  6:0]  inst1_data_cache_index;
wire  [  4:0]  inst1_data_cache_offset;
wire  [  1:0]  inst1_data_cache_size;
wire  [  3:0]  inst1_data_cache_wstrb;
wire  [ 31:0]  inst1_data_cache_wdata;
wire           inst1_data_cache_addr_ok;
wire           data_cache_data_ok_01;
wire [ 31:0]   data_cache_rdata_01;

wire           inst2_data_cache_valid;
wire           inst2_data_cache_op;
wire           inst2_data_cache_uncache;
wire  [ 19:0]  inst2_data_cache_tag;
wire  [  6:0]  inst2_data_cache_index;
wire  [  4:0]  inst2_data_cache_offset;
wire  [  1:0]  inst2_data_cache_size;
wire  [  3:0]  inst2_data_cache_wstrb;
wire  [ 31:0]  inst2_data_cache_wdata;
wire           inst2_data_cache_addr_ok;
wire           data_cache_data_ok_02;
wire [ 31:0]   data_cache_rdata_02;

wire          data_cache_rd_req;
wire          data_cache_rd_type;
wire [ 31:0]  data_cache_rd_addr;
wire [  2:0]  data_cache_rd_size;
wire          data_cache_rd_rdy;
wire          data_cache_ret_valid;
wire  [255:0] data_cache_ret_data;
wire          data_cache_wr_req;
wire          data_cache_wr_type;
wire [ 31:0]  data_cache_wr_addr;
wire [  2:0]  data_cache_wr_size;
wire [  3:0]  data_cache_wr_wstrb;
wire [255:0]  data_cache_wr_data;
wire          data_cache_wr_rdy;
wire          data_cache_wr_ok;


//cp0
wire  [31:0] inst1_c0_wdata    ;
wire  [ 7:0] inst1_c0_addr     ;
wire         inst1_mtc0_we     ;
wire  [31:0] inst2_c0_wdata    ;
wire  [ 7:0] inst2_c0_addr     ;
wire         inst2_mtc0_we     ;
//signals of the exception, from pms, only one inst
wire         pms_ex           ; //has exception
wire  [ 4:0] ex_type          ; //type of exception
wire         pms_bd           ; //is delay slot
wire  [31:0] pms_pc           ; //pc
wire  [31:0] pms_badvaddr     ; //bad vaddr
wire         pms_eret         ; //is eret   
wire [31:0] inst1_c0_rdata    ;
wire [31:0] inst2_c0_rdata    ;
wire        has_int           ;
wire [31:0] pms_epc           ;

//axi
wire          axi_rd_req;
wire [  1:0]  axi_rd_type;
wire [ 31:0]  axi_rd_addr;
wire          axi_rd_rdy;
wire          axi_ret_valid;
wire [511:0]  axi_ret_data;
wire          axi_ret_half;


wire [31:0] cp0_index;
wire [31:0] cp0_entryhi;
wire [31:0] cp0_entrylo0;
wire [31:0] cp0_entrylo1;
wire [2 :0] c0_config_k0;
wire [11:0] c0_mask;
wire [3:0]  c0_random_random;
wire [31:0] c0_status;
wire [31:0] c0_cause;
wire [31:0] c0_taglo;
wire        is_TLBR;
wire [77:0] TLB_rdata;
wire        is_TLBP;
wire        is_TLBWR;
wire        index_write_p;
wire [ 3:0] index_write_index;
wire [ 1:0] except_ce;


//TLB
wire [18:0] s0_vpn2;
wire        s0_odd_age;
wire [ 7:0] s0_asid;
wire        s0_found;
wire [ 3:0] s0_index;
wire [19:0] s0_pfn;
wire [ 2:0] s0_c;
wire        s0_d;
wire        s0_v;

wire [18:0] s1_vpn2;
wire        s1_odd_page;
wire [ 7:0] s1_asid;
wire        s1_found;
wire [ 3:0] s1_index;
wire [19:0] s1_pfn;
wire [ 2:0] s1_c;
wire        s1_d;
wire        s1_v; 

wire [18:0] s2_vpn2;
wire        s2_odd_page;
wire [ 7:0] s2_asid;
wire        s2_found;
wire [ 3:0] s2_index;
wire [19:0] s2_pfn;
wire [ 2:0] s2_c;
wire        s2_d;
wire        s2_v; 

//TLB write port
wire [11:0] w_mask;
wire        we;
wire [ 3:0] w_index;
wire [18:0] w_vpn2;
wire [ 7:0] w_asid;
wire        w_g;
wire [19:0] w_pfn0;
wire [ 2:0] w_c0;
wire        w_d0;
wire        w_v0;
wire [19:0] w_pfn1;
wire [ 2:0] w_c1;
wire        w_d1;
wire        w_v1; 
//TLB read port
wire [11:0] r_mask;
wire [ 3:0] r_index;
wire [18:0] r_vpn2;
wire [ 7:0] r_asid;
wire        r_g;
wire [19:0] r_pfn0;
wire [ 2:0] r_c0;
wire        r_d0;
wire        r_v0;
wire [19:0] r_pfn1;
wire [ 2:0] r_c1;
wire        r_d1;
wire        r_v1;

wire        icache_inst_valid;
wire [ 2:0] icache_inst_op;
wire [31:0] icache_inst_addr;
wire        icache_inst_ok;

wire [19:0] icache_inst_tag;
wire        icache_inst_v;

wire        dcache_inst_valid;
wire [ 2:0] dcache_inst_op;
wire [31:0] dcache_inst_addr;
wire        dcache_inst_ok;

wire [19:0] dcache_inst_tag;
wire        dcache_inst_v;
wire        dcache_inst_d;

wire        pms_mtc0_index;

preif_stage preif_stage(
    .clk                 (aclk),
    .reset               (reset),
    //allwoin
    .fs_allowin          (fs_allowin),   
    //brbus
    .br_bus              (br_bus),

    //fs
    .to_fs_valid         (to_fs_valid),
    .preif_to_fs_bus     (preif_to_fs_bus),
    .fs_no_inst_wait     (fs_no_inst_wait),
    .inst_offset         (inst_offset),//0~16

    // inst cache interface
    .inst_cache_valid     (inst_cache_valid),
    .inst_cache_uncache   (inst_cache_uncache),
    .inst_cache_tag       (inst_cache_tag),
    .inst_cache_index     (inst_cache_index),
    .inst_cache_offset    (inst_cache_offset),
    .inst_cache_addr_ok   (inst_cache_addr_ok),

    //TLB search port 0
    .s0_vpn2              (s0_vpn2),
    .s0_c                 (s0_c),
    .s0_odd_page          (s0_odd_page),
    .s0_asid              (s0_asid),
    .s0_found             (s0_found),
    .s0_pfn               (s0_pfn),
    .s0_d                 (s0_d),
    .s0_v                 (s0_v),
    .tlb_write            (we),
    .cp0_entryhi          (cp0_entryhi),

    //reflush
    .pfs_reflush        (clear_all),
    .reflush_pc         (reflush_pc)
);  

if_stage if_stage(
    .clk                   (aclk),
    .reset                 (reset),

    //preIF
    .to_fs_valid           (to_fs_valid),
    .fs_allowin            (fs_allowin),
    .fs_no_inst_wait       (fs_no_inst_wait),
    .preif_to_fs_bus       (preif_to_fs_bus),
    .fs_to_preif_offset    (inst_offset),
    //allwoin
    .ds_allowin            (ds_allowin),
    .ds_branch             (ds_branch),
    .ds_rf_rdata1          (ds_rf_rdata1),
    .ds_rf_rdata2          (ds_rf_rdata2),
    //to ds
    .fs_to_ds_valid        (fs_to_ds_valid),
    .fs_rf_raddr1          (fs_rf_raddr1),
    .fs_rf_raddr2          (fs_rf_raddr2),
    .fs_to_ds_bus          (fs_to_ds_bus),

    //relevant bus
    .ds_forward_bus        (ds_forward_bus),
    .es_forward_bus        (es_forward_bus),
    .pms_forward_bus       (pms_forward_bus),
    .ms_forward_bus        (ms_forward_bus),
    .ws_forward_bus        (ws_forward_bus),

    //icache output
    .inst_cache_data_ok       (inst_cache_data_ok),
    .inst_cache_data_num      (inst_cache_data_num),
    .inst_cache_rdata         (inst_cache_rdata),

    //clear stage
    .clear_all             (clear_all)
);
id_stage id_stage(
    .clk                    (aclk),
    .reset                  (reset),
    //allowin
    .es_allowin             (es_allowin),
    .ds_allowin             (ds_allowin),
    //from fs
    .fs_to_ds_valid         (fs_to_ds_valid),
    .fs_rf_raddr1           (fs_rf_raddr1),
    .fs_rf_raddr2           (fs_rf_raddr2),
    .fs_to_ds_bus           (fs_to_ds_bus),
    //to es
    .ds_to_es_valid         (ds_to_es_valid),
    .ds_to_es_bus           (ds_to_es_bus  ),

    //to prefs
    .br_bus                 (br_bus),

    //to fs
    .ds_branch              (ds_branch),
    .ds_to_fs_rf_rdata1     (ds_rf_rdata1),
    .ds_to_fs_rf_rdata2     (ds_rf_rdata2),

    //to rf: for write back
    .ws_to_rf_bus           (ws_to_rf_bus ),

    //relevant bus
    .es_forward_bus         (es_forward_bus),
    .pms_forward_bus        (pms_forward_bus),
    .ms_forward_bus         (ms_forward_bus),
    .ws_forward_bus         (ws_forward_bus),
    .ds_forward_bus         (ds_forward_bus),

    //handle interrupt
    .has_int                (has_int       ),
    
    //clear stage
    .clear_all              (clear_all     )
);

exe_stage exe_stage(
    .clk                    (aclk),
    .reset                  (reset),
    //allowin
    .pms_allowin            (pms_allowin),
    .es_allowin             (es_allowin),
    //from ds
    .ds_to_es_valid         (ds_to_es_valid),
    .ds_to_es_bus           (ds_to_es_bus  ),
    //to pms
    .es_to_pms_valid        (es_to_pms_valid),
    .es_to_pms_bus          (es_to_pms_bus  ),
    .es_mul_res             (es_mul_res     ),


    // data cache interface
    .inst1_data_cache_valid     (inst1_data_cache_valid),
    .inst1_data_cache_op        (inst1_data_cache_op),
    .inst1_data_cache_uncache   (inst1_data_cache_uncache),
    .inst1_data_cache_tag       (inst1_data_cache_tag),
    .inst1_data_cache_index     (inst1_data_cache_index),
    .inst1_data_cache_offset    (inst1_data_cache_offset),
    .inst1_data_cache_size      (inst1_data_cache_size), 
    .inst1_data_cache_wstrb     (inst1_data_cache_wstrb),
    .inst1_data_cache_wdata     (inst1_data_cache_wdata),
    .inst1_data_cache_addr_ok   (inst1_data_cache_addr_ok),

    .inst2_data_cache_valid     (inst2_data_cache_valid),
    .inst2_data_cache_op        (inst2_data_cache_op),
    .inst2_data_cache_uncache   (inst2_data_cache_uncache),
    .inst2_data_cache_tag       (inst2_data_cache_tag),
    .inst2_data_cache_index     (inst2_data_cache_index),
    .inst2_data_cache_offset    (inst2_data_cache_offset),
    .inst2_data_cache_size      (inst2_data_cache_size), 
    .inst2_data_cache_wstrb     (inst2_data_cache_wstrb),
    .inst2_data_cache_wdata     (inst2_data_cache_wdata),
    .inst2_data_cache_addr_ok   (inst2_data_cache_addr_ok),

    .icache_inst_valid   (icache_inst_valid),
    .icache_inst_op      (icache_inst_op),
    .icache_inst_addr    (icache_inst_addr),
    .icache_inst_tag     (icache_inst_tag),
    .icache_inst_v       (icache_inst_v),
    .icache_inst_ok      (icache_inst_ok),

    .dcache_inst_valid   (dcache_inst_valid),
    .dcache_inst_op      (dcache_inst_op),
    .dcache_inst_addr    (dcache_inst_addr),
    .dcache_inst_tag     (dcache_inst_tag),
    .dcache_inst_v       (dcache_inst_v),
    .dcache_inst_d       (dcache_inst_d),
    .dcache_inst_ok      (dcache_inst_ok),

    //TLB
    .s1_vpn2                    (s1_vpn2),
    .s1_odd_page                (s1_odd_page),
    .s1_asid                    (s1_asid),
    .s1_found                   (s1_found),
    .s1_pfn                     (s1_pfn),
    .s1_index                   (s1_index),
    .s1_c                       (s1_c),
    .s1_d                       (s1_d),
    .s1_v                       (s1_v),

    .s2_vpn2                    (s2_vpn2),
    .s2_odd_page                (s2_odd_page),
    .s2_asid                    (s2_asid),
    .s2_found                   (s2_found),
    .s2_pfn                     (s2_pfn),
    .s2_index                   (s2_index),
    .s2_c                       (s2_c),
    .s2_d                       (s2_d),
    .s2_v                       (s2_v),

    .tlb_write                  (we),
    .cp0_entryhi                (cp0_entryhi),
    .pms_mtc0_index             (pms_mtc0_index),
    .c0_config_k0               (c0_config_k0),
    .c0_taglo                   (c0_taglo),
    //relevant bus
    .es_forward_bus             (es_forward_bus),
  
    //clear stage
    .clear_all                  (clear_all)
);

premem_stage premem_stage(
    .clk                        (aclk),
    .reset                      (reset),
    //allowin
    .ms_allowin                 (ms_allowin),
    .pms_allowin                (pms_allowin),
    //from es
    .es_to_pms_valid            (es_to_pms_valid),
    .es_to_pms_bus              (es_to_pms_bus),
    .pms_mul_res                (es_mul_res),
    //to ms
    .pms_to_ms_valid            (pms_to_ms_valid),
    .pms_to_ms_bus              (pms_to_ms_bus),

    //relevant bus
    .pms_forward_bus            (pms_forward_bus),
    //clear stage
    .clear_all                  (clear_all),
    .reflush_pc                 (reflush_pc),

    //TLB
    // write port
    .we                         (we),
    .w_mask (w_mask),
    .w_index                    (w_index),
    .w_vpn2                     (w_vpn2),
    .w_asid                     (w_asid),
    .w_g                        (w_g),
    .w_pfn0                     (w_pfn0),
    .w_c0                       (w_c0),
    .w_d0                       (w_d0),
    .w_v0                       (w_v0),
    .w_pfn1                     (w_pfn1),
    .w_c1                       (w_c1),
    .w_d1                       (w_d1),
    .w_v1                       (w_v1), 
    // read port
    .r_index                    (r_index),
    .r_vpn2                     (r_vpn2),
    .r_asid                     (r_asid),
    .r_g                        (r_g),
    .r_pfn0                     (r_pfn0),
    .r_c0                       (r_c0),
    .r_d0                       (r_d0),
    .r_v0                       (r_v0),
    .r_pfn1                     (r_pfn1),
    .r_c1                       (r_c1),
    .r_d1                       (r_d1),
    .r_v1                       (r_v1),

    //cp0
    //signals of mtc0, from pms
    .inst1_c0_wdata             (inst1_c0_wdata),
    .inst1_c0_addr              (inst1_c0_addr),
    .inst1_mtc0_we              (inst1_mtc0_we),
    .inst2_c0_wdata             (inst2_c0_wdata),
    .inst2_c0_addr              (inst2_c0_addr),
    .inst2_mtc0_we              (inst2_mtc0_we),    
    //signals of the exception, from pms, only one inst
    .pms_ex                     (pms_ex), //has exception
    .ex_type                    (ex_type), //type of exception
    .pms_bd                     (pms_bd), //is delay slot
    .pms_pc                     (pms_pc), //pc
    .pms_badvaddr               (pms_badvaddr), //bad vaddr
    .pms_eret                   (pms_eret), //is eret
    .pms_except_ce              (except_ce),//exception:cpu

    //output to pms
    .inst1_c0_rdata             (inst1_c0_rdata),
    .inst2_c0_rdata             (inst2_c0_rdata),
    .has_int                    (has_int),
    .pms_epc                    (pms_epc),

    //for TLB
    .cp0_index                  (cp0_index),
    .cp0_entryhi                (cp0_entryhi),
    .cp0_entrylo0               (cp0_entrylo0),
    .cp0_entrylo1               (cp0_entrylo1),
    .c0_mask                    (c0_mask),
    .c0_status                  (c0_status),
    .c0_cause                   (c0_cause),
    //TLBR\TLBP to CP0
    .is_TLBR                    (is_TLBR),
    .TLB_rdata                  (TLB_rdata),
    .is_TLBP                    (is_TLBP),
    .is_TLBWR                   (is_TLBWR),
    .index_write_p              (index_write_p),
    .index_write_index          (index_write_index),
    .c0_random_random           (c0_random_random),

    .pms_mtc0_index             (pms_mtc0_index)

);

cp0 cp0(
    .cp0_clk     (aclk)     ,
    .reset       (reset)    ,
    //signals of mtc0, from pms
    .inst1_c0_wdata             (inst1_c0_wdata),
    .inst1_c0_addr              (inst1_c0_addr),
    .inst1_mtc0_we              (inst1_mtc0_we),
    .inst2_c0_wdata             (inst2_c0_wdata),
    .inst2_c0_addr              (inst2_c0_addr),
    .inst2_mtc0_we              (inst2_mtc0_we),    
    //signals of the exception, from pms, only one inst
    .pms_ex                     (pms_ex), //has exception
    .ex_type                    (ex_type), //type of exception
    .pms_bd                     (pms_bd), //is delay slot
    .pms_pc                     (pms_pc), //pc
    .pms_badvaddr               (pms_badvaddr), //bad vaddr
    .pms_eret                   (pms_eret), //is eret
    .except_ce                  (except_ce),//exception:cpu

    //output to pms
    .inst1_c0_rdata             (inst1_c0_rdata),
    .inst2_c0_rdata             (inst2_c0_rdata),
    .has_int                    (has_int),
    .epc_res                    (pms_epc),
    .ext_int_in                 (ext_int),

    //for TLB
    .cp0_index                  (cp0_index),
    .cp0_entryhi                (cp0_entryhi),
    .cp0_entrylo0               (cp0_entrylo0),
    .cp0_entrylo1               (cp0_entrylo1),
    .c0_config_k0               (c0_config_k0),
    .c0_mask                    (c0_mask),
    .c0_random_random           (c0_random_random),
    .c0_status                  (c0_status),
    .c0_cause                   (c0_cause),
    .c0_taglo                   (c0_taglo),
    //TLBR\TLBP to CP0
    .TLBR_mask                  (r_mask),
    .is_TLBR                    (is_TLBR),
    .TLB_rdata                  (TLB_rdata),
    .is_TLBP                    (is_TLBP),
    .is_TLBWR                   (is_TLBWR),
    .index_write_p              (index_write_p),
    .index_write_index          (index_write_index)
);

mem_stage mem_stage(
    .clk            (aclk           ),
    .reset          (reset          ),
    //allowin
    .ws_allowin     (ws_allowin     ),
    .ms_allowin     (ms_allowin     ),
    //from es
    .pms_to_ms_valid (pms_to_ms_valid ),
    .pms_to_ms_bus   (pms_to_ms_bus   ),
    //to ws
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    
    //data relevant
    .ms_forward_bus (ms_forward_bus),

    //from data-sram
    .data_cache_data_ok_01(data_cache_data_ok_01),
    .data_cache_rdata_01(data_cache_rdata_01),
    .data_cache_data_ok_02(data_cache_data_ok_02),
    .data_cache_rdata_02(data_cache_rdata_02)
);

wb_stage wb_stage(
    .clk           (aclk)  ,
    .reset         (reset) ,
    //allowin
    .ws_allowin    (ws_allowin),
    //from ms
    .ms_to_ws_valid (ms_to_ws_valid),
    .ms_to_ws_bus   (ms_to_ws_bus)  ,

    //to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus)  ,

    //relevant bus
    .ws_forward_bus (ws_forward_bus),

    //trace debug interface
    .debug_wb_pc     (debug_wb_pc),
    .debug_wb_rf_wen (debug_wb_rf_wen),
    .debug_wb_rf_wnum(debug_wb_rf_wnum),
    .debug_wb_rf_wdata(debug_wb_rf_wdata)
);


icache icache(
    .clk        (aclk   ),
    .resetn     (aresetn),

    .valid      (inst_cache_valid    ),
    .uncache    (inst_cache_uncache  ),
    .tag        (inst_cache_tag      ),
    .index      (inst_cache_index    ),
    .offset     (inst_cache_offset   ),
    .addr_ok    (inst_cache_addr_ok  ),
    .data_ok    (inst_cache_data_ok  ),
    .rdata      (inst_cache_rdata    ),
    .rnum       (inst_cache_data_num),

    .cache_inst_valid   (icache_inst_valid),
    .cache_inst_op      (icache_inst_op),
    .cache_inst_addr    (icache_inst_addr),
    .cache_inst_tag     (icache_inst_tag),
    .cache_inst_v       (icache_inst_v),
    .cache_inst_ok      (icache_inst_ok),

    .rd_req     (inst_cache_rd_req   ),
    .rd_type    (inst_cache_rd_type  ),
    .rd_addr    (inst_cache_rd_addr  ),
    .rd_rdy     (inst_cache_rd_rdy   ),
    .ret_valid  (inst_cache_ret_valid),
    .ret_data   (inst_cache_ret_data )
);

prefetcher prefetcher(
    .clk              (aclk            ),
    .resetn           (aresetn         ),
    // Dcache
    .cache_rd_req     (inst_cache_rd_req   ),
    .cache_rd_type    (inst_cache_rd_type  ),
    .cache_rd_addr    (inst_cache_rd_addr  ),
    .cache_rd_rdy     (inst_cache_rd_rdy   ),
    .cache_ret_valid  (inst_cache_ret_valid),
    .cache_ret_data   (inst_cache_ret_data ),
    // AXI
    .axi_rd_req        (axi_rd_req    ),
    .axi_rd_type       (axi_rd_type   ),
    .axi_rd_addr       (axi_rd_addr   ),
    .axi_rd_rdy        (axi_rd_rdy    ),
    .axi_ret_valid     (axi_ret_valid ),
    .axi_ret_data      (axi_ret_data  ),
    .axi_ret_half      (axi_ret_half  )
);
dcache dcache(
    .clk        (aclk   ),
    .resetn     (aresetn),

    .valid1      (inst1_data_cache_valid    ),
    .op1         (inst1_data_cache_op       ),
    .uncache1    (inst1_data_cache_uncache  ),
    .tag1        (inst1_data_cache_tag      ),
    .index1      (inst1_data_cache_index    ),
    .offset1     (inst1_data_cache_offset   ),
    .size1       (inst1_data_cache_size     ),
    .wstrb1      (inst1_data_cache_wstrb    ),
    .wdata1      (inst1_data_cache_wdata    ),
    .addr_ok1    (inst1_data_cache_addr_ok  ),
    .data_ok1    (data_cache_data_ok_01  ),
    .rdata1      (data_cache_rdata_01    ),
    .valid2      (inst2_data_cache_valid    ),
    .op2         (inst2_data_cache_op       ),
    .uncache2    (inst2_data_cache_uncache  ),
    .tag2        (inst2_data_cache_tag      ),
    .index2      (inst2_data_cache_index    ),
    .offset2     (inst2_data_cache_offset   ),
    .size2       (inst2_data_cache_size     ),
    .wstrb2      (inst2_data_cache_wstrb    ),
    .wdata2      (inst2_data_cache_wdata    ),
    .addr_ok2    (inst2_data_cache_addr_ok  ),
    .data_ok2    (data_cache_data_ok_02  ),
    .rdata2      (data_cache_rdata_02    ),

    .cache_inst_valid   (dcache_inst_valid),
    .cache_inst_op      (dcache_inst_op),
    .cache_inst_addr    (dcache_inst_addr),
    .cache_inst_tag     (dcache_inst_tag),
    .cache_inst_v       (dcache_inst_v),
    .cache_inst_d       (dcache_inst_d),
    .cache_inst_ok      (dcache_inst_ok),

    .rd_req     (data_cache_rd_req   ),
    .rd_type    (data_cache_rd_type  ),
    .rd_addr    (data_cache_rd_addr  ),
    .rd_size    (data_cache_rd_size  ),
    .rd_rdy     (data_cache_rd_rdy   ),
    .ret_valid  (data_cache_ret_valid),
    .ret_data   (data_cache_ret_data ),

    .wr_req     (data_cache_wr_req   ),
    .wr_type    (data_cache_wr_type  ),
    .wr_addr    (data_cache_wr_addr  ),
    .wr_size    (data_cache_wr_size  ),
    .wr_wstrb   (data_cache_wr_wstrb ),
    .wr_data    (data_cache_wr_data  ),
    .wr_rdy     (data_cache_wr_rdy   ),
    .wr_ok      (data_cache_wr_ok    )
);

// cache to axi
cache2axi cache2axi(
    .clk              (aclk            ),
    .resetn           (aresetn         ),

    .inst_rd_req        (axi_rd_req    ),
    .inst_rd_type       (axi_rd_type   ),
    .inst_rd_addr       (axi_rd_addr   ),
    .inst_rd_rdy        (axi_rd_rdy    ),
    .inst_ret_valid     (axi_ret_valid ),
    .inst_ret_data      (axi_ret_data  ),
    .inst_ret_half      (axi_ret_half  ),

    .data_rd_req        (data_cache_rd_req    ),
    .data_rd_type       (data_cache_rd_type   ),
    .data_rd_addr       (data_cache_rd_addr   ),
    .data_rd_size       (data_cache_rd_size   ),
    .data_rd_rdy        (data_cache_rd_rdy    ),
    .data_ret_valid     (data_cache_ret_valid ),
    .data_ret_data      (data_cache_ret_data  ),
    .data_wr_req        (data_cache_wr_req    ),
    .data_wr_type       (data_cache_wr_type   ),
    .data_wr_addr       (data_cache_wr_addr   ),
    .data_wr_size       (data_cache_wr_size   ),
    .data_wr_wstrb      (data_cache_wr_wstrb  ),
    .data_wr_data       (data_cache_wr_data   ),
    .data_wr_rdy        (data_cache_wr_rdy    ),
    .data_wr_ok         (data_cache_wr_ok     ),

    .axi_arid         (arid      ),
    .axi_araddr       (araddr    ),
    .axi_arlen        (arlen     ),
    .axi_arsize       (arsize    ),
    .axi_arburst      (arburst   ),
    .axi_arlock       (arlock    ),
    .axi_arcache      (arcache   ),
    .axi_arprot       (arprot    ),
    .axi_arvalid      (arvalid   ),
    .axi_arready      (arready   ),
                
    .axi_rid          (rid       ),
    .axi_rdata        (rdata     ),
    .axi_rresp        (rresp     ),
    .axi_rlast        (rlast     ),
    .axi_rvalid       (rvalid    ),
    .axi_rready       (rready    ),
               
    .axi_awid         (awid      ),
    .axi_awaddr       (awaddr    ),
    .axi_awlen        (awlen     ),
    .axi_awsize       (awsize    ),
    .axi_awburst      (awburst   ),
    .axi_awlock       (awlock    ),
    .axi_awcache      (awcache   ),
    .axi_awprot       (awprot    ),
    .axi_awvalid      (awvalid   ),
    .axi_awready      (awready   ),
    
    .axi_wid          (wid       ),
    .axi_wdata        (wdata     ),
    .axi_wstrb        (wstrb     ),
    .axi_wlast        (wlast     ),
    .axi_wvalid       (wvalid    ),
    .axi_wready       (wready    ),
    
    .axi_bid          (bid       ),
    .axi_bresp        (bresp     ),
    .axi_bvalid       (bvalid    ),
    .axi_bready       (bready    )
);

tlb tlb(
    .clk              (aclk), 
    .reset            (reset),
    // search port 0
    .s0_vpn2          (s0_vpn2),
    .s0_odd_page      (s0_odd_page),
    .s0_asid          (s0_asid),
    .s0_found         (s0_found),
    .s0_index         (s0_index),
    .s0_pfn           (s0_pfn),
    .s0_c             (s0_c),
    .s0_d             (s0_d),
    .s0_v             (s0_v), 
    // search port 1
    .s1_vpn2          (s1_vpn2),
    .s1_odd_page      (s1_odd_page),
    .s1_asid          (s1_asid),
    .s1_found         (s1_found),
    .s1_index         (s1_index),
    .s1_pfn           (s1_pfn),
    .s1_c             (s1_c),
    .s1_d             (s1_d),
    .s1_v             (s1_v), 
    // search port 2
    .s2_vpn2          (s2_vpn2),
    .s2_odd_page      (s2_odd_page),
    .s2_asid          (s2_asid),
    .s2_found         (s2_found),
    .s2_index         (s2_index),
    .s2_pfn           (s2_pfn),
    .s2_c             (s2_c),
    .s2_d             (s2_d),
    .s2_v             (s2_v), 
    // write port
    .we               (we),
    .w_mask           (w_mask),
    .w_index          (w_index),
    .w_vpn2           (w_vpn2),
    .w_asid           (w_asid),
    .w_g              (w_g),
    .w_pfn0           (w_pfn0),         
    .w_c0             (w_c0),
    .w_d0             (w_d0),
    .w_v0             (w_v0),
    .w_pfn1           (w_pfn1),
    .w_c1             (w_c1),
    .w_d1             (w_d1),
    .w_v1             (w_v1), 
    // read port
    .r_mask           (r_mask),
    .r_index          (r_index),
    .r_vpn2           (r_vpn2),
    .r_asid           (r_asid),
    .r_g              (r_g),
    .r_pfn0           (r_pfn0),
    .r_c0             (r_c0),
    .r_d0             (r_d0),
    .r_v0             (r_v0),
    .r_pfn1           (r_pfn1),
    .r_c1             (r_c1),
    .r_d1             (r_d1),
    .r_v1             (r_v1)

);

endmodule