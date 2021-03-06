module cp0(
    input         cp0_clk     ,
    input         reset       ,
    //signals of mtc0, from pms
    input  [31:0] inst1_c0_wdata    ,
    input  [ 7:0] inst1_c0_addr     ,
    input         inst1_mtc0_we     ,
    input  [31:0] inst2_c0_wdata    ,
    input  [ 7:0] inst2_c0_addr     ,
    input         inst2_mtc0_we     ,    
    //signals of the exception, from pms, only one inst
    input         pms_ex       , //has exception
    input  [ 4:0] ex_type     , //type of exception
    input         pms_bd       , //is delay slot
    input  [31:0] pms_pc       , //pc
    input  [31:0] pms_badvaddr , //bad vaddr
    input         pms_eret        , //is eret
    input  [ 1:0] except_ce       ,     

    //output to pms
    output [31:0] inst1_c0_rdata    ,
    output [31:0] inst2_c0_rdata    ,
    output        has_int           ,
    output [31:0] epc_res           ,

    input  [ 5:0] ext_int_in        ,

    //for TLB
    output [31:0] cp0_index   ,
    output [31:0] cp0_entryhi ,
    output [31:0] cp0_entrylo0,
    output [31:0] cp0_entrylo1,
    output [2: 0] c0_config_k0,
    output [11:0] c0_mask,
    output [3: 0] c0_random_random,
    output [31:0] c0_status,
    output [31:0] c0_cause,
    output reg [31:0] c0_taglo,
    //TLBR\TLBP to CP0
    input        is_TLBR      ,
    input [77:0] TLB_rdata    ,
    input [11:0] TLBR_mask    ,     //TODO
    input        is_TLBP      ,
    input        is_TLBWR     ,     
    input        index_write_p,
    input [ 3:0] index_write_index    
);

//              -> rd    sel
//CAUSE   13 0  -> 01101 000
//STATUS  12 0  -> 01100 000
//EPC     14 0  -> 01110 000
//COUNT    9 0  -> 01001 000
//COMPARE 11 0  -> 01011 000
//BADADDR  8 0  -> 01000 000

//EntryHi 10 0  -> 01010 000
//EntryLo0 2 0  -> 00010 000
//EntryLo1 3 0  -> 00011 000
//Index    0 0  -> 00000 000

//Random   1 0  -> 00001 000
//Context  4 0  -> 00100 000
//PageMask 5 0  -> 00101 000
//Wired    6 0  -> 00110 000
//PrID    15 0  -> 01111 000 
//Config0 16 0  -> 10000 000
//Config1 16 1  -> 10000 001
//TagLo   28 0  -> 11100 000

localparam     CR_STATUS  = 8'b01100000;
localparam     CR_CAUSE   = 8'b01101000;
localparam     CR_EPC     = 8'b01110000;
localparam     CR_COUNT   = 8'b01001000;
localparam     CR_COMPARE = 8'b01011000;
localparam     CR_BADADDR = 8'b01000000;

localparam     CR_ENTRYHI  = 8'b01010000;
localparam     CR_ENTRYLO0 = 8'b00010000;
localparam     CR_ENTRYLO1 = 8'b00011000;
localparam     CR_INDEX    = 8'b00000000;

localparam     CR_RANDOM   = 8'b00001000;
localparam     CR_CONTEXT  = 8'b00100000;
localparam     CR_PAGEMASK = 8'b00101000;
localparam     CR_WIRED    = 8'b00110000;
localparam     CR_PRID     = 8'b01111000;
localparam     CR_CONFIG0  = 8'b10000000;
localparam     CR_CONFIG1  = 8'b10000001;
localparam     CR_TagLo    = 8'b11100000;

wire [4:0] wb_excode;
assign wb_excode = ex_type;

wire count_eq_compare;


//STATUS
reg        c0_status_cu0;
reg        c0_status_bev;
reg [ 7:0] c0_status_im;
reg        c0_status_um;
reg        c0_status_exl;
reg        c0_status_ie;

always @(posedge cp0_clk) begin
    if (reset) begin
        c0_status_cu0 <= 1'b0;        
    end    
    else if(inst2_mtc0_we && inst2_c0_addr == CR_STATUS) begin
        c0_status_cu0 <= inst2_c0_wdata[28];
    end
    else if(inst1_mtc0_we && inst1_c0_addr == CR_STATUS) begin
        c0_status_cu0 <= inst1_c0_wdata[28];
    end
end

always @(posedge cp0_clk) begin
    if (reset) begin
        c0_status_bev <= 1'b1;        
    end
    else if(inst2_mtc0_we && inst2_c0_addr == CR_STATUS) begin
        c0_status_bev <= inst2_c0_wdata[22];
    end
    else if(inst1_mtc0_we && inst1_c0_addr == CR_STATUS) begin
        c0_status_bev <= inst1_c0_wdata[22];
    end
end

always @(posedge cp0_clk) begin
    if (inst2_mtc0_we && inst2_c0_addr == CR_STATUS) begin
        c0_status_im  <= inst2_c0_wdata[15: 8];
    end
    else if (inst1_mtc0_we && inst1_c0_addr == CR_STATUS) begin
        c0_status_im  <= inst1_c0_wdata[15: 8];
    end
end

always @(posedge cp0_clk) begin
    if (reset) begin
        c0_status_um <= 1'b0;        
    end    
    else if(inst2_mtc0_we && inst2_c0_addr == CR_STATUS) begin
        c0_status_um <= inst2_c0_wdata[4];
    end
    else if(inst1_mtc0_we && inst1_c0_addr == CR_STATUS) begin
        c0_status_um <= inst1_c0_wdata[4];
    end
end

always @(posedge cp0_clk) begin
    if (reset) begin
        c0_status_exl <= 1'b0;
    end
    else if (pms_ex) begin
        c0_status_exl <= 1'b1;
    end
    else if (pms_eret) begin
        c0_status_exl <= 1'b0;
    end
    else if (inst2_mtc0_we && inst2_c0_addr == CR_STATUS) begin
        c0_status_exl <= inst2_c0_wdata[1];
    end     
    else if (inst1_mtc0_we && inst1_c0_addr == CR_STATUS) begin
        c0_status_exl <= inst1_c0_wdata[1];
    end    
end

always @(posedge cp0_clk) begin
    if (reset)
        c0_status_ie <= 1'b0;
    else if (inst2_mtc0_we && inst2_c0_addr == CR_STATUS)
        c0_status_ie <= inst2_c0_wdata[0];        
    else if (inst1_mtc0_we && inst1_c0_addr == CR_STATUS)
        c0_status_ie <= inst1_c0_wdata[0];
end

assign c0_status = {3'b0, c0_status_cu0, 5'b0, c0_status_bev, 6'b0, c0_status_im, 3'b0, c0_status_um, 2'b0, c0_status_exl, c0_status_ie};

//CAUSE
reg        c0_cause_bd;
reg        c0_cause_ti;
reg [ 1:0] c0_cause_ce;
reg        c0_cause_iv;
reg [ 7:0] c0_cause_ip;
reg [ 4:0] c0_cause_excode;

always @(posedge cp0_clk) begin
    if (reset)
        c0_cause_bd <= 1'b0;
    else if (pms_ex && !c0_status_exl)
        c0_cause_bd <= pms_bd;
end

always @(posedge cp0_clk) begin
    if (reset)
        c0_cause_ti <= 1'b0;
    else if (inst2_mtc0_we && inst2_c0_addr == CR_COMPARE)
        c0_cause_ti <= 1'b0;   
    else if (inst1_mtc0_we && inst1_c0_addr == CR_COMPARE)
        c0_cause_ti <= 1'b0;
    else if (count_eq_compare)
        c0_cause_ti <= 1'b1;
end

always @(posedge cp0_clk) begin
    if (reset)
        c0_cause_ce <= 2'b0;
    else if (pms_ex)
        c0_cause_ce <= except_ce;
end

always @(posedge cp0_clk) begin
    if (reset)
        c0_cause_iv <= 1'b0;
    else if (inst2_mtc0_we && inst2_c0_addr == CR_COMPARE)
        c0_cause_iv <= inst2_c0_wdata[23];
    else if (inst1_mtc0_we && inst1_c0_addr == CR_COMPARE)
        c0_cause_iv <= inst1_c0_wdata[23];
end

always @(posedge cp0_clk) begin
    if (reset)
        c0_cause_ip[7:2] <= 6'b0;
    else begin
        c0_cause_ip[7]   <= ext_int_in[5] | c0_cause_ti;
        c0_cause_ip[6:2] <= ext_int_in[4:0];
    end
end

always @(posedge cp0_clk) begin
    if (reset)
        c0_cause_ip[1:0] <= 2'b0;
    else if (inst2_mtc0_we && inst2_c0_addr == CR_CAUSE)
        c0_cause_ip[1:0] <= inst2_c0_wdata[9:8];        
    else if (inst1_mtc0_we && inst1_c0_addr == CR_CAUSE)
        c0_cause_ip[1:0] <= inst1_c0_wdata[9:8];
end

always @(posedge cp0_clk) begin
    if (reset)
        c0_cause_excode <= 5'b0;
    else if (pms_ex)
        c0_cause_excode <= wb_excode;
end

assign c0_cause = {c0_cause_bd, c0_cause_ti, c0_cause_ce, 4'b0, c0_cause_iv, 7'b0, c0_cause_ip[7:0], 1'b0, c0_cause_excode, 2'b0};

//EPC
reg [31:0] c0_epc;
always @(posedge cp0_clk) begin
    if (reset)
        c0_epc <= 32'b0;
    else if (pms_ex && !c0_status_exl)
        c0_epc <= pms_bd ? pms_pc - 3'h4 : pms_pc;
    else if (inst2_mtc0_we && inst2_c0_addr == CR_EPC)
        c0_epc <= inst2_c0_wdata;
    else if (inst1_mtc0_we && inst1_c0_addr == CR_EPC)
        c0_epc <= inst1_c0_wdata;
end

//BadVAddr
reg [31:0] c0_badvaddr;
always @(posedge cp0_clk) begin
    if (reset)
        c0_badvaddr <= 32'b0;
    else if (pms_ex && (wb_excode == 5'h1 || wb_excode == 5'h2 || 
                       wb_excode == 5'h3 || wb_excode == 5'h4 || wb_excode == 5'h5))  
        c0_badvaddr <= pms_badvaddr;
end

//COUNT
reg tick;
reg [31:0] c0_count;
always @(posedge cp0_clk) begin
    if (reset) 
        tick <= 1'b0;
    else 
        tick <= ~tick;
    if (inst2_mtc0_we && inst2_c0_addr == CR_COUNT)
        c0_count <= inst2_c0_wdata;
    else if (inst1_mtc0_we && inst1_c0_addr == CR_COUNT)
        c0_count <= inst1_c0_wdata;
    else if (tick)
        c0_count <= c0_count + 1'b1;
end

//COMPARE
reg [31:0] c0_compare;
always @(posedge cp0_clk) begin
    if (inst2_mtc0_we && inst2_c0_addr == CR_COMPARE)
        c0_compare <= inst2_c0_wdata;
    else if (inst1_mtc0_we && inst1_c0_addr == CR_COMPARE)
        c0_compare <= inst1_c0_wdata;
end

assign count_eq_compare = (c0_compare == c0_count) && (c0_compare != 32'b0);
assign has_int = ((c0_cause_ip[7:0] & c0_status_im[7:0]) != 8'h00) && c0_status_ie == 1'b1 && c0_status_exl == 1'b0;                                                       
assign epc_res = c0_epc;

//INDEX
reg        c0_index_p;
reg [ 3:0] c0_index_index;

always @(posedge cp0_clk)begin
    if (reset)
        c0_index_p <= 1'b0;
    else if(is_TLBP)
        c0_index_p <= index_write_p;
end

always @(posedge cp0_clk)begin
    if (reset)
        c0_index_index <= 4'b0;
    else if (inst2_mtc0_we && inst2_c0_addr == CR_INDEX)
        c0_index_index <= inst2_c0_wdata[3:0];
    else if (inst1_mtc0_we && inst1_c0_addr == CR_INDEX)
        c0_index_index <= inst1_c0_wdata[3:0];
    else if(is_TLBP)
        c0_index_index <= index_write_index;
end

assign cp0_index = {c0_index_p, 27'b0, c0_index_index};

//ENTRYLO0
reg [19:0] c0_PFN0;
reg [ 2:0] c0_C0;
reg        c0_D0;
reg        c0_V0;
reg        c0_G0;

always @(posedge cp0_clk)begin
    if (reset)
        c0_PFN0 <= 20'b0;
    else if (inst2_mtc0_we && inst2_c0_addr == CR_ENTRYLO0)
        c0_PFN0 <= inst2_c0_wdata[25:6];
    else if (inst1_mtc0_we && inst1_c0_addr == CR_ENTRYLO0)
        c0_PFN0 <= inst1_c0_wdata[25:6];
    else if(is_TLBR)
        c0_PFN0 <= TLB_rdata[49:30];
end

always @(posedge cp0_clk)begin
    if (reset)
        c0_C0 <= 3'b0;
    else if (inst2_mtc0_we && inst2_c0_addr == CR_ENTRYLO0)
        c0_C0 <= inst2_c0_wdata[ 5:3];
    else if (inst1_mtc0_we && inst1_c0_addr == CR_ENTRYLO0)
        c0_C0 <= inst1_c0_wdata[ 5:3];
    else if(is_TLBR)
        c0_C0 <= TLB_rdata[29:27];
end

always @(posedge cp0_clk)begin
    if (reset)
        c0_D0 <= 1'b0;
    else if (inst2_mtc0_we && inst2_c0_addr == CR_ENTRYLO0)
        c0_D0 <= inst2_c0_wdata[2];
    else if (inst1_mtc0_we && inst1_c0_addr == CR_ENTRYLO0)
        c0_D0 <= inst1_c0_wdata[2];
    else if(is_TLBR)
        c0_D0 <= TLB_rdata[26];
end

always @(posedge cp0_clk)begin
    if (reset)
        c0_V0 <= 1'b0;
    else if (inst2_mtc0_we && inst2_c0_addr == CR_ENTRYLO0)
        c0_V0 <= inst2_c0_wdata[1];
    else if (inst1_mtc0_we && inst1_c0_addr == CR_ENTRYLO0)
        c0_V0 <= inst1_c0_wdata[1];
    else if(is_TLBR)
        c0_V0 <= TLB_rdata[25]; 
end

always @(posedge cp0_clk)begin
    if (reset)
        c0_G0 <= 1'b0;
    else if (inst2_mtc0_we && inst2_c0_addr == CR_ENTRYLO0)
        c0_G0 <= inst2_c0_wdata[0];
    else if (inst1_mtc0_we && inst1_c0_addr == CR_ENTRYLO0)
        c0_G0 <= inst1_c0_wdata[0];
    else if(is_TLBR)
        c0_G0 <= TLB_rdata[50];          
end

assign cp0_entrylo0 = {6'b0, c0_PFN0, c0_C0, c0_D0, c0_V0, c0_G0};

//ENTRYLO1
reg [19:0] c0_PFN1;
reg [ 2:0] c0_C1;
reg        c0_D1;
reg        c0_V1;
reg        c0_G1;

always @(posedge cp0_clk)begin
    if (reset)
        c0_PFN1 <= 20'b0;
    else if (inst2_mtc0_we && inst2_c0_addr == CR_ENTRYLO1)
        c0_PFN1 <= inst2_c0_wdata[25:6];
    else if (inst1_mtc0_we && inst1_c0_addr == CR_ENTRYLO1)
        c0_PFN1 <= inst1_c0_wdata[25:6];
    else if(is_TLBR)
        c0_PFN1 <= TLB_rdata[24:5];
end

always @(posedge cp0_clk)begin
    if (reset)
        c0_C1 <= 3'b0;
    else if (inst2_mtc0_we && inst2_c0_addr == CR_ENTRYLO1)
        c0_C1 <= inst2_c0_wdata[ 5:3];
    else if (inst1_mtc0_we && inst1_c0_addr == CR_ENTRYLO1)
        c0_C1 <= inst1_c0_wdata[ 5:3];
    else if(is_TLBR)
        c0_C1 <= TLB_rdata[ 4:2];        
end

always @(posedge cp0_clk)begin
    if (reset)
        c0_D1 <= 1'b0;
    else if (inst2_mtc0_we && inst2_c0_addr == CR_ENTRYLO1)
        c0_D1 <= inst2_c0_wdata[2];
    else if (inst1_mtc0_we && inst1_c0_addr == CR_ENTRYLO1)
        c0_D1 <= inst1_c0_wdata[2];
    else if(is_TLBR)
        c0_D1 <= TLB_rdata[1];  
end

always @(posedge cp0_clk)begin
    if (reset)
        c0_V1 <= 1'b0;
    else if (inst2_mtc0_we && inst2_c0_addr == CR_ENTRYLO1)
        c0_V1 <= inst2_c0_wdata[1];
    else if (inst1_mtc0_we && inst1_c0_addr == CR_ENTRYLO1)
        c0_V1 <= inst1_c0_wdata[1];
    else if(is_TLBR)
        c0_V1 <= TLB_rdata[0];  
end

always @(posedge cp0_clk)begin
    if (reset)
        c0_G1 <= 1'b0;
    else if (inst2_mtc0_we && inst2_c0_addr == CR_ENTRYLO1)
        c0_G1 <= inst2_c0_wdata[0];
    else if (inst1_mtc0_we && inst1_c0_addr == CR_ENTRYLO1)
        c0_G1 <= inst1_c0_wdata[0];
    else if(is_TLBR)
        c0_G1 <= TLB_rdata[50];  
end

assign cp0_entrylo1 = {6'b0, c0_PFN1, c0_C1, c0_D1, c0_V1, c0_G1};

//ENTRYHI
reg [18:0] c0_VPN2; 
reg [ 7:0] c0_ASID;

always @(posedge cp0_clk)begin
    if (reset)
        c0_VPN2 <= 19'b0;
    else if (inst2_mtc0_we && inst2_c0_addr == CR_ENTRYHI)
        c0_VPN2 <= inst2_c0_wdata[31:13];
    else if (inst1_mtc0_we && inst1_c0_addr == CR_ENTRYHI)
        c0_VPN2 <= inst1_c0_wdata[31:13];
    else if(pms_ex && (wb_excode == 5'h1 || wb_excode == 5'h2 || wb_excode == 5'h3))
        c0_VPN2 <= pms_badvaddr[31:13];
    else if(is_TLBR)
        c0_VPN2 <= TLB_rdata[77:59];
end

always @(posedge cp0_clk)begin
    if (reset)
        c0_ASID <= 8'b0;
    else if (inst2_mtc0_we && inst2_c0_addr == CR_ENTRYHI)
        c0_ASID <= inst2_c0_wdata[ 7:0];
    else if (inst1_mtc0_we && inst1_c0_addr == CR_ENTRYHI)
        c0_ASID <= inst1_c0_wdata[ 7:0];
    else if(is_TLBR)
        c0_ASID <= TLB_rdata[58:51];
end

assign cp0_entryhi = {c0_VPN2, 5'b0, c0_ASID};


//CONTEXT
reg [8:0] c0_context_ptebase;
reg [18:0] c0_context_badvpn2;

always @(posedge cp0_clk) begin
    // PTEBase
    if(inst2_mtc0_we && inst2_c0_addr == CR_CONTEXT) 
        c0_context_ptebase <= inst2_c0_wdata[31:23];
    else if(inst1_mtc0_we && inst1_c0_addr == CR_CONTEXT)
        c0_context_ptebase <= inst1_c0_wdata[31:23];
end

always @(posedge cp0_clk) begin
    // BadVPN2
    if (pms_ex && (wb_excode == 5'h1 || wb_excode == 5'h2 || wb_excode == 5'h3)) 
        c0_context_badvpn2 <= pms_badvaddr[31:13];    
end

//WIRED
reg [3:0] c0_wired_wired;

always @(posedge cp0_clk) begin
    // Wired
    if (reset) 
        c0_wired_wired <= 4'b0;
    else if (inst2_mtc0_we && inst2_c0_addr == CR_WIRED) 
        c0_wired_wired <= inst2_c0_wdata[3:0];
    else if (inst1_mtc0_we && inst1_c0_addr == CR_WIRED) 
        c0_wired_wired <= inst1_c0_wdata[3:0];    
end

//RANDOM
reg [3:0] c0_random_random;

wire [3:0] next_random = c0_random_random + 1'b1;
always @(posedge cp0_clk) begin
    // Random
    if (reset) 
        c0_random_random <= 4'b1111;
    else if (is_TLBWR) 
        c0_random_random <= (next_random < c0_wired_wired) ? c0_wired_wired : next_random;
end

//PAGEMASK
reg [11:0] c0_mask;

always @(posedge cp0_clk) begin
    /*if(reset)//DEBUG
        c0_mask <= 12'd0;
    else if(is_TLBR)*/
    if (is_TLBR)
        c0_mask <= TLBR_mask;
    else if(inst2_mtc0_we && inst2_c0_addr == CR_PAGEMASK) 
        c0_mask <= inst2_c0_wdata[24:13];
    else if(inst1_mtc0_we && inst1_c0_addr == CR_PAGEMASK) 
        c0_mask <= inst1_c0_wdata[24:13];
end

//CONFIG0
reg [2:0] c0_config_k0;

always @(posedge cp0_clk) begin
    if(reset)
        c0_config_k0 <= 3'd3;
    else if(inst2_mtc0_we && inst2_c0_addr == CR_CONFIG0) 
        c0_config_k0 <= inst2_c0_wdata[2:0];
    else if(inst1_mtc0_we && inst1_c0_addr == CR_CONFIG0) 
        c0_config_k0 <= inst1_c0_wdata[2:0];
end

//TagLo

always @(posedge cp0_clk) begin
    if (inst2_mtc0_we && inst2_c0_addr == CR_TagLo) 
        c0_taglo <= inst2_c0_wdata;
    else if (inst1_mtc0_we && inst1_c0_addr == CR_TagLo) 
        c0_taglo <= inst1_c0_wdata;
end

assign inst1_c0_rdata = {32{(inst1_c0_addr == CR_EPC)}} & c0_epc |
                        {32{(inst1_c0_addr == CR_COUNT)}} & c0_count |
                        {32{(inst1_c0_addr == CR_BADADDR)}} & c0_badvaddr |
                        {32{(inst1_c0_addr == CR_CAUSE)}} & {c0_cause_bd, c0_cause_ti, c0_cause_ce, 4'b0, c0_cause_iv, 7'b0, c0_cause_ip[7:0], 1'b0, c0_cause_excode, 2'b0} |
                        {32{(inst1_c0_addr == CR_STATUS)}} & {3'b0, c0_status_cu0, 5'b0, c0_status_bev, 6'b0, c0_status_im, 3'b0, c0_status_um, 2'b0, c0_status_exl, c0_status_ie} |
                        {32{(inst1_c0_addr == CR_ENTRYHI)}} & {c0_VPN2, 5'b0, c0_ASID} |
                        {32{(inst1_c0_addr == CR_INDEX)}} & {c0_index_p, 27'b0, c0_index_index} |
                        {32{(inst1_c0_addr == CR_ENTRYLO0)}} & {6'b0, c0_PFN0, c0_C0, c0_D0, c0_V0, c0_G0} |
                        {32{(inst1_c0_addr == CR_ENTRYLO1)}} & {6'b0, c0_PFN1, c0_C1, c0_D1, c0_V1, c0_G1} |
                        {32{(inst1_c0_addr == CR_PRID)}} & {32'h00004220} |
                        {32{(inst1_c0_addr == CR_CONTEXT)}} & {c0_context_ptebase, c0_context_badvpn2, 4'b0} |
                        {32{(inst1_c0_addr == CR_RANDOM)}} & {28'b0, c0_random_random} |
                        {32{(inst1_c0_addr == CR_WIRED)}} & {28'b0, c0_wired_wired} |
                        {32{(inst1_c0_addr == CR_PAGEMASK)}} & {8'b0, c0_mask, 13'b0} |
                        {32{(inst1_c0_addr == CR_CONFIG0)}} & {1'b1, 21'b0, 3'b1, 4'b0, c0_config_k0} |
                        {32{(inst1_c0_addr == CR_CONFIG1)}} & {1'b0, 6'd15, 3'd1, 3'd4, 3'd1, 3'd1, 3'd4, 3'd1, 7'b0} |
                        {32{(inst1_c0_addr == CR_TagLo)}} & c0_taglo;

assign inst2_c0_rdata = {32{(inst2_c0_addr == CR_EPC)}} & c0_epc |
                        {32{(inst2_c0_addr == CR_COUNT)}} & c0_count |
                        {32{(inst2_c0_addr == CR_BADADDR)}} & c0_badvaddr |
                        {32{(inst2_c0_addr == CR_CAUSE)}} & {c0_cause_bd, c0_cause_ti, c0_cause_ce, 4'b0, c0_cause_iv, 7'b0, c0_cause_ip[7:0], 1'b0, c0_cause_excode, 2'b0} |
                        {32{(inst2_c0_addr == CR_STATUS)}} & {3'b0, c0_status_cu0, 5'b0, c0_status_bev, 6'b0, c0_status_im, 3'b0, c0_status_um, 2'b0, c0_status_exl, c0_status_ie} |
                        {32{(inst2_c0_addr == CR_ENTRYHI)}} & {c0_VPN2, 5'b0, c0_ASID} |
                        {32{(inst2_c0_addr == CR_INDEX)}} & {c0_index_p, 27'b0, c0_index_index} |
                        {32{(inst2_c0_addr == CR_ENTRYLO0)}} & {6'b0, c0_PFN0, c0_C0, c0_D0, c0_V0, c0_G0} |
                        {32{(inst2_c0_addr == CR_ENTRYLO1)}} & {6'b0, c0_PFN1, c0_C1, c0_D1, c0_V1, c0_G1} |
                        {32{(inst2_c0_addr == CR_PRID)}} & {32'h00004220} |
                        {32{(inst2_c0_addr == CR_CONTEXT)}} & {c0_context_ptebase, c0_context_badvpn2, 4'b0} |
                        {32{(inst2_c0_addr == CR_RANDOM)}} & {28'b0, c0_random_random} |
                        {32{(inst2_c0_addr == CR_WIRED)}} & {28'b0, c0_wired_wired} |
                        {32{(inst2_c0_addr == CR_PAGEMASK)}} & {8'b0, c0_mask, 13'b0} |
                        {32{(inst2_c0_addr == CR_CONFIG0)}} & {1'b1, 21'b0, 3'b1, 4'b0, c0_config_k0} |
                        {32{(inst2_c0_addr == CR_CONFIG1)}} & {1'b0, 6'd15, 3'd1, 3'd4, 3'd1, 3'd1, 3'd4, 3'd1, 7'b0} |
                        {32{(inst2_c0_addr == CR_TagLo)}} & c0_taglo;
endmodule