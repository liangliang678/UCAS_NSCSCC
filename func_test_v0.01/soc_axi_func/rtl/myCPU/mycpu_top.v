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

wire         ds_allowin;
wire         es_allowin;
wire         ms_allowin;
wire         ws_allowin;
wire         fs_to_ds_valid;
wire         ds_to_es_valid;
wire         es_to_ms_valid;
wire         ms_to_ws_valid;
wire [`FS_TO_DS_BUS_WD -1:0] fs_to_ds_bus;
wire [`DS_TO_ES_BUS_WD -1:0] ds_to_es_bus;
wire [`ES_TO_MS_BUS_WD -1:0] es_to_ms_bus;
wire [`MS_TO_WS_BUS_WD -1:0] ms_to_ws_bus;
wire [`WS_TO_RF_BUS_WD -1:0] ws_to_rf_bus;
wire [`BR_BUS_WD       -1:0] br_bus;
wire [`STALL_ES_BUS_WD -1:0] stall_es_bus;
wire [`STALL_MS_BUS_WD -1:0] stall_ms_bus;
wire [`STALL_WS_BUS_WD -1:0] stall_ws_bus;

wire [63:0]  mul_res;

//handle exception
wire [31:0]  epc;

wire [31:0]  c0_wdata;       
wire [7:0]   c0_addr;        
wire         mtc0_we;       

wire         ex_begin;          
wire [13:0]  ex_type;        
wire         wb_bd;    
wire [31:0]  wb_pc; 
wire [31:0]  wb_badvaddr; 
wire         eret;
wire         es_ex;

wire [31:0]  c0_rdata;
wire         has_int;

//TLB related
wire [31:0]  cp0_index;
wire [31:0]  cp0_entryhi;
wire [31:0]  cp0_entrylo0;
wire [31:0]  cp0_entrylo1;

//cache
wire           inst_cache_valid;
wire           inst_cache_uncache;
wire  [ 19:0]  inst_cache_tag;
wire  [  7:0]  inst_cache_index;
wire  [  3:0]  inst_cache_offset;
wire           inst_cache_addr_ok;
wire           inst_cache_data_ok;
wire [ 31:0]   inst_cache_rdata;

wire          inst_cache_rd_req;
wire [  2:0]  inst_cache_rd_type;
wire [ 31:0]  inst_cache_rd_addr;
wire          inst_cache_rd_rdy;
wire          inst_cache_ret_valid;
wire  [127:0] inst_cache_ret_data;

wire           data_cache_valid;
wire           data_cache_op;
wire           data_cache_uncache;
wire  [ 19:0]  data_cache_tag;
wire  [  7:0]  data_cache_index;
wire  [  3:0]  data_cache_offset;
wire  [  3:0]  data_cache_wstrb;
wire  [ 31:0]  data_cache_wdata;
wire           data_cache_addr_ok;
wire           data_cache_data_ok;
wire [ 31:0]   data_cache_rdata;

wire          data_cache_rd_req;
wire [  2:0]  data_cache_rd_type;
wire [ 31:0]  data_cache_rd_addr;
wire          data_cache_rd_rdy;
wire          data_cache_ret_valid;
wire  [127:0] data_cache_ret_data;
wire          data_cache_wr_req;
wire [  2:0]  data_cache_wr_type;
wire [ 31:0]  data_cache_wr_addr;
wire [  3:0]  data_cache_wr_wstrb;
wire [127:0]  data_cache_wr_data;
wire          data_cache_wr_rdy;

// TLB
    // search port 0
wire [18:0] s0_vpn2;
wire        s0_odd_age;
wire [ 7:0] s0_asid;
wire        s0_found;
wire [ 3:0] s0_index;
wire [19:0] s0_pfn;
wire [ 2:0] s0_c;
wire        s0_d;
wire        s0_v; 
    // search port 1
wire [18:0] s1_vpn2;
wire        s1_odd_page;
wire [ 7:0] s1_asid;
wire        s1_found;
wire [ 3:0] s1_index;
wire [19:0] s1_pfn;
wire [ 2:0] s1_c;
wire        s1_d;
wire        s1_v; 
    // write port
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
    // read port
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

//TLBR\TLBP to CP0
wire        is_TLBR;
wire [77:0] TLB_rdata;
wire        is_TLBP;
wire        index_write_p;
wire [ 3:0] index_write_index;

wire        mem_mtc0_index;
wire        wb_mtc0_index;

wire        cancel_to_all;
wire [31:0] cancel_pc;
wire        exception_is_tlb_refill;
// IF stage
if_stage if_stage(
    .clk            (aclk            ),
    .reset          (reset          ),
    //allowin
    .ds_allowin     (ds_allowin     ),
    //brbus
    .br_bus         (br_bus         ),
    //outputs
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    // inst cache interface
    .inst_cache_valid       (inst_cache_valid   ),
    .inst_cache_uncache     (inst_cache_uncache ),
    .inst_cache_tag         (inst_cache_tag     ),
    .inst_cache_index       (inst_cache_index   ),
    .inst_cache_offset      (inst_cache_offset  ),
    .inst_cache_addr_ok     (inst_cache_addr_ok ),
    .inst_cache_data_ok     (inst_cache_data_ok ),
    .inst_cache_rdata       (inst_cache_rdata   ),

    .fs_ex          (ex_begin       ),

    //TLB search port 0
    .s0_vpn2          (s0_vpn2      ),
    .s0_odd_page      (s0_odd_page  ),
    .s0_asid          (s0_asid      ),
    .s0_found         (s0_found     ),
    .s0_index         (s0_index     ),
    .s0_pfn           (s0_pfn       ),
    .s0_c             (s0_c         ),
    .s0_d             (s0_d         ),
    .s0_v             (s0_v         ),

    .cp0_entryhi    (cp0_entryhi    ),
    .fs_cancel_in   (cancel_to_all  ),
    .cancel_pc      (cancel_pc      ),
    .exception_is_tlb_refill_in(exception_is_tlb_refill)
);
// ID stage
id_stage id_stage(
    .clk            (aclk           ),
    .reset          (reset          ),
    //allowin
    .es_allowin     (es_allowin     ),
    .ds_allowin     (ds_allowin     ),
    //from fs
    .fs_to_ds_valid (fs_to_ds_valid ),
    .fs_to_ds_bus   (fs_to_ds_bus   ),
    //to es
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_to_es_bus   (ds_to_es_bus   ),
    //to fs
    .br_bus         (br_bus         ),
    //to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus   ),
    //data relevant
    .stall_es_bus   (stall_es_bus   ),
    .stall_ms_bus   (stall_ms_bus   ),
    .stall_ws_bus   (stall_ws_bus   ),
    //handle exception
    .ds_epc         (epc            ),
    .ds_ex          (ex_begin       ),
    .has_int        (has_int        ),
    .es_exception_appear_in(es_ex   ),
    .ds_cancel_in   (cancel_to_all  )
);
// EXE stage
exe_stage exe_stage(
    .clk            (aclk            ),
    .reset          (reset          ),
    //allowin
    .ms_allowin     (ms_allowin     ),
    .es_allowin     (es_allowin     ),
    //from ds
    .ds_to_es_valid (ds_to_es_valid ),
    .ds_to_es_bus   (ds_to_es_bus   ),
    //to ms
    .es_to_ms_valid (es_to_ms_valid ),
    .es_to_ms_bus   (es_to_ms_bus   ),
    // data cache interface
    .data_cache_valid  (data_cache_valid   ),
    .data_cache_op     (data_cache_op      ),
    .data_cache_uncache(data_cache_uncache ),
    .data_cache_tag    (data_cache_tag     ),
    .data_cache_index  (data_cache_index   ),
    .data_cache_offset (data_cache_offset  ),
    .data_cache_wstrb  (data_cache_wstrb   ),
    .data_cache_wdata  (data_cache_wdata   ),
    .data_cache_addr_ok(data_cache_addr_ok ),


    //multiper result
    .mul_res        (mul_res        ),
    //data relevant
    .stall_es_bus   (stall_es_bus   ),
    .es_ex          (ex_begin       ),
    .es_exception_appear_out(es_ex  ),

    //TLB search port 1
    .s1_vpn2          (s1_vpn2      ),
    .s1_odd_page      (s1_odd_page  ),
    .s1_asid          (s1_asid      ),
    .s1_found         (s1_found     ),
    .s1_index         (s1_index     ),
    .s1_pfn           (s1_pfn       ),
    .s1_c             (s1_c         ),
    .s1_d             (s1_d         ),
    .s1_v             (s1_v         ),

    .cp0_entryhi    (cp0_entryhi    ),
    .mem_mtc0_index (mem_mtc0_index ),
    .wb_mtc0_index  (wb_mtc0_index  ),
    .es_cancel_in   (cancel_to_all  )
);
// MEM stage
mem_stage mem_stage(
    .clk            (aclk            ),
    .reset          (reset          ),
    //allowin
    .ws_allowin     (ws_allowin     ),
    .ms_allowin     (ms_allowin     ),
    //from es
    .es_to_ms_valid (es_to_ms_valid ),
    .es_to_ms_bus   (es_to_ms_bus   ),
    //multiper result
    .mul_res        (mul_res        ),
    //to ws
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    //from data cache
    .data_cache_data_ok(data_cache_data_ok),
    .data_cache_rdata  (data_cache_rdata  ),

    //data relevant
    .stall_ms_bus   (stall_ms_bus   ),
    .ms_ex          (ex_begin       ),

    .mem_mtc0_index (mem_mtc0_index ),
    .ms_cancel_in   (cancel_to_all  )
);
// WB stage
wb_stage wb_stage(
    .clk            (aclk            ),
    .reset          (reset          ),
    //allowin
    .ws_allowin     (ws_allowin     ),
    //from ms
    .ms_to_ws_valid (ms_to_ws_valid ),
    .ms_to_ws_bus   (ms_to_ws_bus   ),
    //to rf: for write back
    .ws_to_rf_bus   (ws_to_rf_bus   ),
    //trace debug interface
    .debug_wb_pc      (debug_wb_pc      ),
    .debug_wb_rf_wen  (debug_wb_rf_wen  ),
    .debug_wb_rf_wnum (debug_wb_rf_wnum ),
    .debug_wb_rf_wdata(debug_wb_rf_wdata),
    //data relevant
    .stall_ws_bus   (stall_ws_bus   ),
    //handle exception
    .c0_wdata       (c0_wdata       ),
    .c0_addr        (c0_addr        ),
    .mtc0_we        (mtc0_we        ),

    .wb_ex          (ex_begin       ),       //has exception
    .ex_type        (ex_type        ),       //type of exception
    .wb_bd          (wb_bd          ),       //is delay slot
    .wb_pc          (wb_pc          ),       //pc
    .wb_badvaddr    (wb_badvaddr    ),       //bad vaddr
    .wb_eret        (eret           ),

    .has_int        (has_int        ),
    .c0_rdata       (c0_rdata       ),

    //TLB write port
    .we               (we           ),
    .w_index          (w_index      ),
    .w_vpn2           (w_vpn2       ),
    .w_asid           (w_asid       ),
    .w_g              (w_g          ),
    .w_pfn0           (w_pfn0       ), 
    .w_c0             (w_c0         ),
    .w_d0             (w_d0         ),
    .w_v0             (w_v0         ),
    .w_pfn1           (w_pfn1       ),
    .w_c1             (w_c1         ),
    .w_d1             (w_d1         ),
    .w_v1             (w_v1         ), 
    //TLB read port
    .r_index          (r_index      ),
    .r_vpn2           (r_vpn2       ),
    .r_asid           (r_asid       ),
    .r_g              (r_g          ),
    .r_pfn0           (r_pfn0       ),
    .r_c0             (r_c0         ),
    .r_d0             (r_d0         ),
    .r_v0             (r_v0         ),
    .r_pfn1           (r_pfn1       ),
    .r_c1             (r_c1         ),                
    .r_d1             (r_d1         ),
    .r_v1             (r_v1         ),

    //TLB CP0 REG
    .cp0_index      (cp0_index      ),
    .cp0_entryhi    (cp0_entryhi    ),
    .cp0_entrylo0   (cp0_entrylo0   ),
    .cp0_entrylo1   (cp0_entrylo1   ),

    //TLBR to CP0
    .is_TLBR            (is_TLBR),
    .TLB_rdata          (TLB_rdata),
    .is_TLBP            (is_TLBP),
    .index_write_p      (index_write_p),
    .index_write_index  (index_write_index),

    .wb_mtc0_index      (wb_mtc0_index),
    .wb_cancel_to_all   (cancel_to_all),
    .cancel_pc          (cancel_pc    ),
    .exception_is_tlb_refill(exception_is_tlb_refill)
);

//cp0 registers
cp0 cp0(
    .cp0_clk        (aclk           ),
    .reset          (reset          ), 

    .c0_wdata       (c0_wdata       ),
    .c0_addr        (c0_addr        ),
    .mtc0_we        (mtc0_we        ),

    .wb_ex          (ex_begin       ),
    .ex_type        (ex_type        ),
    .wb_bd          (wb_bd          ),
    .wb_pc          (wb_pc          ),
    .wb_badvaddr    (wb_badvaddr    ),

    .eret           (eret        ),

    .c0_rdata       (c0_rdata       ),
    .has_int        (has_int        ),
    .ds_epc         (epc            ),

    .cp0_index      (cp0_index      ),
    .cp0_entryhi    (cp0_entryhi    ),
    .cp0_entrylo0   (cp0_entrylo0   ),
    .cp0_entrylo1   (cp0_entrylo1   ),

    .is_TLBR            (is_TLBR          ),
    .TLB_rdata          (TLB_rdata        ),
    .is_TLBP            (is_TLBP          ),
    .index_write_p      (index_write_p    ),
    .index_write_index  (index_write_index)    
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

    .rd_req     (inst_cache_rd_req   ),
    .rd_type    (inst_cache_rd_type  ),
    .rd_addr    (inst_cache_rd_addr  ),
    .rd_rdy     (inst_cache_rd_rdy   ),
    .ret_valid  (inst_cache_ret_valid),
    .ret_data   (inst_cache_ret_data )
);

dcache dcache(
    .clk        (aclk   ),
    .resetn     (aresetn),

    .valid      (data_cache_valid    ),
    .op         (data_cache_op       ),
    .uncache    (data_cache_uncache  ),
    .tag        (data_cache_tag      ),
    .index      (data_cache_index    ),
    .offset     (data_cache_offset   ),
    .wstrb      (data_cache_wstrb    ),
    .wdata      (data_cache_wdata    ),
    .addr_ok    (data_cache_addr_ok  ),
    .data_ok    (data_cache_data_ok  ),
    .rdata      (data_cache_rdata    ),

    .rd_req     (data_cache_rd_req   ),
    .rd_type    (data_cache_rd_type  ),
    .rd_addr    (data_cache_rd_addr  ),
    .rd_rdy     (data_cache_rd_rdy   ),
    .ret_valid  (data_cache_ret_valid),
    .ret_data   (data_cache_ret_data ),

    .wr_req     (data_cache_wr_req   ),
    .wr_type    (data_cache_wr_type  ),
    .wr_addr    (data_cache_wr_addr  ),
    .wr_wstrb   (data_cache_wr_wstrb ),
    .wr_data    (data_cache_wr_data  ),
    .wr_rdy     (data_cache_wr_rdy   )
);


// cache to axi
cache2axi cache2axi(
    .clk              (aclk            ),
    .resetn           (aresetn         ),

    .inst_rd_req        (inst_cache_rd_req    ),
    .inst_rd_type       (inst_cache_rd_type   ),
    .inst_rd_addr       (inst_cache_rd_addr   ),
    .inst_rd_rdy        (inst_cache_rd_rdy    ),
    .inst_ret_valid     (inst_cache_ret_valid ),
    .inst_ret_data      (inst_cache_ret_data  ),


    .data_rd_req        (data_cache_rd_req    ),
    .data_rd_type       (data_cache_rd_type   ),
    .data_rd_addr       (data_cache_rd_addr   ),
    .data_rd_rdy        (data_cache_rd_rdy    ),
    .data_ret_valid     (data_cache_ret_valid ),
    .data_ret_data      (data_cache_ret_data  ),
    .data_wr_req        (data_cache_wr_req    ),
    .data_wr_type       (data_cache_wr_type   ),
    .data_wr_addr       (data_cache_wr_addr   ),
    .data_wr_wstrb      (data_cache_wr_wstrb  ),
    .data_wr_data       (data_cache_wr_data   ),
    .data_wr_rdy        (data_cache_wr_rdy    ),

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

//TLB
tlb tlb(
    .clk              (aclk         ), 
    .reset            (reset        ),
    // search port 0
    .s0_vpn2          (s0_vpn2      ),
    .s0_odd_page      (s0_odd_page  ),
    .s0_asid          (s0_asid      ),
    .s0_found         (s0_found     ),
    .s0_index         (s0_index     ),
    .s0_pfn           (s0_pfn       ),
    .s0_c             (s0_c         ),
    .s0_d             (s0_d         ),
    .s0_v             (s0_v         ), 
    // search port 1
    .s1_vpn2          (s1_vpn2      ),
    .s1_odd_page      (s1_odd_page  ),
    .s1_asid          (s1_asid      ),
    .s1_found         (s1_found     ),
    .s1_index         (s1_index     ),
    .s1_pfn           (s1_pfn       ),
    .s1_c             (s1_c         ),
    .s1_d             (s1_d         ),
    .s1_v             (s1_v         ), 
    // write port
    .we               (we           ),
    .w_index          (w_index      ),
    .w_vpn2           (w_vpn2       ),
    .w_asid           (w_asid       ),
    .w_g              (w_g          ),
    .w_pfn0           (w_pfn0       ), 
    .w_c0             (w_c0         ),
    .w_d0             (w_d0         ),
    .w_v0             (w_v0         ),
    .w_pfn1           (w_pfn1       ),
    .w_c1             (w_c1         ),
    .w_d1             (w_d1         ),
    .w_v1             (w_v1         ), 
    // read port
    .r_index          (r_index      ),
    .r_vpn2           (r_vpn2       ),
    .r_asid           (r_asid       ),
    .r_g              (r_g          ),
    .r_pfn0           (r_pfn0       ),
    .r_c0             (r_c0         ),
    .r_d0             (r_d0         ),
    .r_v0             (r_v0         ),
    .r_pfn1           (r_pfn1       ),
    .r_c1             (r_c1         ),                
    .r_d1             (r_d1         ),
    .r_v1             (r_v1         )
);

endmodule
