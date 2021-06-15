`define  IDLE    5'b00001
`define  LOOKUP  5'b00010
`define  MISS    5'b00100
`define  REPLACE 5'b01000
`define  REFILL  5'b10000
`define  WIDLE   2'b01
`define  WRITE   2'b10

module dcache(
    input           clk,
    input           resetn,

    // Cache and CPU
    input           valid,
    input           op,
    input           uncache,
    input  [ 19:0]  tag,
    input  [  7:0]  index,
    input  [  3:0]  offset,
    input  [  1:0]  size,
    input  [  3:0]  wstrb,
    input  [ 31:0]  wdata,

    output          addr_ok,
    output          data_ok,
    output [ 31:0]  rdata,

    // Cache and AXI
    output          rd_req,
    output          rd_type,
    output [ 31:0]  rd_addr,
    output [  2:0]  rd_size,
    input           rd_rdy,
    input           ret_valid,
    input  [127:0]  ret_data,

    output          wr_req,
    output          wr_type,
    output [ 31:0]  wr_addr,
    output [  2:0]  wr_size,
    output [  3:0]  wr_wstrb,
    output [127:0]  wr_data,
    input           wr_rdy,
    input           wr_ok
);

wire        tagv_way0_en;
wire        tagv_way1_en;
wire        tagv_way0_we;
wire        tagv_way1_we;
wire [ 7:0] tagv_addr;
wire [20:0] tagv_way0_din;
wire [20:0] tagv_way1_din;
wire [20:0] tagv_way0_dout;
wire [20:0] tagv_way1_dout;

wire        data_way0_bank0_en;
wire        data_way0_bank1_en;
wire        data_way0_bank2_en;
wire        data_way0_bank3_en;
wire        data_way1_bank0_en;
wire        data_way1_bank1_en;
wire        data_way1_bank2_en;
wire        data_way1_bank3_en;
wire [ 3:0] data_way0_bank0_we;
wire [ 3:0] data_way0_bank1_we;
wire [ 3:0] data_way0_bank2_we;
wire [ 3:0] data_way0_bank3_we;
wire [ 3:0] data_way1_bank0_we;
wire [ 3:0] data_way1_bank1_we;
wire [ 3:0] data_way1_bank2_we;
wire [ 3:0] data_way1_bank3_we;
wire [ 7:0] data_addr;
wire [31:0] data_way0_bank0_din;
wire [31:0] data_way0_bank1_din;
wire [31:0] data_way0_bank2_din;
wire [31:0] data_way0_bank3_din;
wire [31:0] data_way1_bank0_din;
wire [31:0] data_way1_bank1_din;
wire [31:0] data_way1_bank2_din;
wire [31:0] data_way1_bank3_din;
wire [31:0] data_way0_bank0_dout;
wire [31:0] data_way0_bank1_dout;
wire [31:0] data_way0_bank2_dout;
wire [31:0] data_way0_bank3_dout;
wire [31:0] data_way1_bank0_dout;
wire [31:0] data_way1_bank1_dout;
wire [31:0] data_way1_bank2_dout;
wire [31:0] data_way1_bank3_dout;

reg D_Way0 [255:0];
reg D_Way1 [255:0];

TagV_RAM TagV_RAM_Way0(
    .clka   (clk           ),
    .addra  (tagv_addr     ),
    .ena    (tagv_way0_en  ),
    .wea    (tagv_way0_we  ),
    .dina   (tagv_way0_din ),
    .douta  (tagv_way0_dout)
);
TagV_RAM TagV_RAM_Way1(
    .clka   (clk           ),
    .addra  (tagv_addr     ),
    .ena    (tagv_way1_en  ),
    .wea    (tagv_way1_we  ),
    .dina   (tagv_way1_din ),
    .douta  (tagv_way1_dout)
);
Data_RAM Data_RAM_Way0_Bank0(
    .clka   (clk                 ),
    .addra  (data_addr           ),
    .ena    (data_way0_bank0_en  ),
    .wea    (data_way0_bank0_we  ),
    .dina   (data_way0_bank0_din ),
    .douta  (data_way0_bank0_dout)
);
Data_RAM Data_RAM_Way0_Bank1(
    .clka   (clk                 ),
    .addra  (data_addr           ),
    .ena    (data_way0_bank1_en  ),
    .wea    (data_way0_bank1_we  ),
    .dina   (data_way0_bank1_din ),
    .douta  (data_way0_bank1_dout)
);
Data_RAM Data_RAM_Way0_Bank2(
    .clka   (clk                 ),
    .addra  (data_addr           ),
    .ena    (data_way0_bank2_en  ),
    .wea    (data_way0_bank2_we  ),
    .dina   (data_way0_bank2_din ),
    .douta  (data_way0_bank2_dout)
);
Data_RAM Data_RAM_Way0_Bank3(
    .clka   (clk                 ),
    .addra  (data_addr           ),
    .ena    (data_way0_bank3_en  ),
    .wea    (data_way0_bank3_we  ),
    .dina   (data_way0_bank3_din ),
    .douta  (data_way0_bank3_dout)
);
Data_RAM Data_RAM_Way1_Bank0(
    .clka   (clk                 ),
    .addra  (data_addr           ),
    .ena    (data_way1_bank0_en  ),
    .wea    (data_way1_bank0_we  ),
    .dina   (data_way1_bank0_din ),
    .douta  (data_way1_bank0_dout)
);
Data_RAM Data_RAM_Way1_Bank1(
    .clka   (clk                 ),
    .addra  (data_addr           ),
    .ena    (data_way1_bank1_en  ),
    .wea    (data_way1_bank1_we  ),
    .dina   (data_way1_bank1_din ),
    .douta  (data_way1_bank1_dout)
);
Data_RAM Data_RAM_Way1_Bank2(
    .clka   (clk                 ),
    .addra  (data_addr           ),
    .ena    (data_way1_bank2_en  ),
    .wea    (data_way1_bank2_we  ),
    .dina   (data_way1_bank2_din ),
    .douta  (data_way1_bank2_dout)
);
Data_RAM Data_RAM_Way1_Bank3(
    .clka   (clk                 ),
    .addra  (data_addr           ),
    .ena    (data_way1_bank3_en  ),
    .wea    (data_way1_bank3_we  ),
    .dina   (data_way1_bank3_din ),
    .douta  (data_way1_bank3_dout)
);

genvar i0;
generate for (i0=0; i0<256; i0=i0+1) begin :gen_for_D_Way0
    always @(posedge clk) begin
        if (!resetn) begin
            D_Way0[i0] <= 1'b0;
        end
        else if (wstate == `WRITE && !wb_hit_way && i0 == wb_index) begin
            D_Way0[i0] <= 1'b1;
        end
        else if (state == `REFILL && ret_valid && !rp_way && i0 == rb_index) begin
            D_Way0[i0] <= rb_op;
        end
    end
end endgenerate

genvar i1;
generate for (i1=0; i1<256; i1=i1+1) begin :gen_for_D_Way1
    always @(posedge clk) begin
        if (!resetn) begin
            D_Way1[i1] <= 1'b0;
        end
        else if (wstate == `WRITE && wb_hit_way && i1 == wb_index) begin
            D_Way1[i1] <= 1'b1;
        end
        else if (state == `REFILL && ret_valid && rp_way && i1 == rb_index) begin
            D_Way1[i1] <= rb_op;
        end
    end
end endgenerate

assign tagv_way0_en = (valid && addr_ok) || (state == `REFILL && ret_valid && !rp_way && !rb_uncache);
assign tagv_way1_en = (valid && addr_ok) || (state == `REFILL && ret_valid &&  rp_way && !rb_uncache);
assign tagv_way0_we = (state == `REFILL && ret_valid && !rp_way && !rb_uncache);
assign tagv_way1_we = (state == `REFILL && ret_valid &&  rp_way && !rb_uncache);
assign tagv_way0_din = {1'b1, rb_tag};
assign tagv_way1_din = {1'b1, rb_tag};
assign tagv_addr = (valid && addr_ok) ? index : 
                   (state == `REFILL && ret_valid && !rb_uncache) ? rb_index : 8'b0;

assign data_way0_bank0_en = (valid && addr_ok) || 
                            (wstate == `WRITE && wb_offset[3:2] == 2'b00 && !wb_hit_way) || 
                            (state == `REFILL && ret_valid && !rp_way && !rb_uncache);
assign data_way0_bank1_en = (valid && addr_ok) || 
                            (wstate == `WRITE && wb_offset[3:2] == 2'b01 && !wb_hit_way) || 
                            (state == `REFILL && ret_valid && !rp_way && !rb_uncache);
assign data_way0_bank2_en = (valid && addr_ok) || 
                            (wstate == `WRITE && wb_offset[3:2] == 2'b10 && !wb_hit_way) || 
                            (state == `REFILL && ret_valid && !rp_way && !rb_uncache);
assign data_way0_bank3_en = (valid && addr_ok) || 
                            (wstate == `WRITE && wb_offset[3:2] == 2'b11 && !wb_hit_way) || 
                            (state == `REFILL && ret_valid && !rp_way && !rb_uncache);
assign data_way1_bank0_en = (valid && addr_ok) || 
                            (wstate == `WRITE && wb_offset[3:2] == 2'b00 && wb_hit_way) || 
                            (state == `REFILL && ret_valid && rp_way && !rb_uncache);
assign data_way1_bank1_en = (valid && addr_ok) || 
                            (wstate == `WRITE && wb_offset[3:2] == 2'b01 && wb_hit_way) || 
                            (state == `REFILL && ret_valid && rp_way && !rb_uncache);
assign data_way1_bank2_en = (valid && addr_ok) || 
                            (wstate == `WRITE && wb_offset[3:2] == 2'b10 && wb_hit_way) || 
                            (state == `REFILL && ret_valid && rp_way && !rb_uncache);
assign data_way1_bank3_en = (valid && addr_ok) || 
                            (wstate == `WRITE && wb_offset[3:2] == 2'b11 && wb_hit_way) || 
                            (state == `REFILL && ret_valid && rp_way && !rb_uncache);
assign data_way0_bank0_we = (wstate == `WRITE) ? wb_wstrb : (state == `REFILL && ret_valid && !rp_way && !rb_uncache) ? 4'b1111 : 4'b0000;
assign data_way0_bank1_we = (wstate == `WRITE) ? wb_wstrb : (state == `REFILL && ret_valid && !rp_way && !rb_uncache) ? 4'b1111 : 4'b0000;
assign data_way0_bank2_we = (wstate == `WRITE) ? wb_wstrb : (state == `REFILL && ret_valid && !rp_way && !rb_uncache) ? 4'b1111 : 4'b0000;
assign data_way0_bank3_we = (wstate == `WRITE) ? wb_wstrb : (state == `REFILL && ret_valid && !rp_way && !rb_uncache) ? 4'b1111 : 4'b0000;
assign data_way1_bank0_we = (wstate == `WRITE) ? wb_wstrb : (state == `REFILL && ret_valid &&  rp_way && !rb_uncache) ? 4'b1111 : 4'b0000;
assign data_way1_bank1_we = (wstate == `WRITE) ? wb_wstrb : (state == `REFILL && ret_valid &&  rp_way && !rb_uncache) ? 4'b1111 : 4'b0000;
assign data_way1_bank2_we = (wstate == `WRITE) ? wb_wstrb : (state == `REFILL && ret_valid &&  rp_way && !rb_uncache) ? 4'b1111 : 4'b0000;
assign data_way1_bank3_we = (wstate == `WRITE) ? wb_wstrb : (state == `REFILL && ret_valid &&  rp_way && !rb_uncache) ? 4'b1111 : 4'b0000;
assign data_way0_bank0_din = (wstate == `WRITE) ? wb_wdata : (state == `REFILL) ? rd_way_wdata_bank0 : 32'b0;
assign data_way0_bank1_din = (wstate == `WRITE) ? wb_wdata : (state == `REFILL) ? rd_way_wdata_bank1 : 32'b0;
assign data_way0_bank2_din = (wstate == `WRITE) ? wb_wdata : (state == `REFILL) ? rd_way_wdata_bank2 : 32'b0;
assign data_way0_bank3_din = (wstate == `WRITE) ? wb_wdata : (state == `REFILL) ? rd_way_wdata_bank3 : 32'b0;
assign data_way1_bank0_din = (wstate == `WRITE) ? wb_wdata : (state == `REFILL) ? rd_way_wdata_bank0 : 32'b0;
assign data_way1_bank1_din = (wstate == `WRITE) ? wb_wdata : (state == `REFILL) ? rd_way_wdata_bank1 : 32'b0;
assign data_way1_bank2_din = (wstate == `WRITE) ? wb_wdata : (state == `REFILL) ? rd_way_wdata_bank2 : 32'b0;
assign data_way1_bank3_din = (wstate == `WRITE) ? wb_wdata : (state == `REFILL) ? rd_way_wdata_bank3 : 32'b0;
assign data_addr = (wstate == `WRITE) ? wb_index : 
                   (valid && addr_ok) ? index : 
                   (state == `REFILL && ret_valid && !rb_uncache) ? rb_index : 8'b0;

// Request Buffer
reg          rb_op;
reg          rb_uncache;   
reg  [ 19:0] rb_tag;
reg  [  7:0] rb_index;
reg  [  3:0] rb_offset;
reg  [  1:0] rb_size;
reg  [  3:0] rb_wstrb;
reg  [ 31:0] rb_wdata;

wire         way0_v;
wire         way1_v;
wire         way0_d;
wire         way1_d;
wire [ 19:0] way0_tag;
wire [ 19:0] way1_tag;
wire [127:0] way0_data;
wire [127:0] way1_data;

always @(posedge clk) begin
    if (valid && addr_ok) begin
        rb_op     <= op;
        rb_uncache<= uncache;
        rb_tag    <= tag;
        rb_index  <= index;      
        rb_offset <= offset;
        rb_size   <= size;
        rb_wstrb  <= wstrb;
        rb_wdata  <= wdata;
    end
end

wire req_raw;
assign req_raw = (wstate == `WRITE) && (index == wb_index) && (offset == wb_offset);
assign addr_ok = (state == `IDLE || (state == `LOOKUP && cache_hit)) && valid && !req_raw;

assign way0_d = D_Way0[rb_index];
assign way1_d = D_Way1[rb_index];
assign way0_v = tagv_way0_dout[20];
assign way1_v = tagv_way1_dout[20];
assign way0_tag = tagv_way0_dout[19:0];
assign way1_tag = tagv_way1_dout[19:0];
assign way0_data = {data_way0_bank3_dout, data_way0_bank2_dout, data_way0_bank1_dout, data_way0_bank0_dout};
assign way1_data = {data_way1_bank3_dout, data_way1_bank2_dout, data_way1_bank1_dout, data_way1_bank0_dout};

// Tag Compare
wire         way0_hit;
wire         way1_hit;
wire         cache_hit;

assign way0_hit = way0_v && (way0_tag == rb_tag);
assign way1_hit = way1_v && (way1_tag == rb_tag);
assign cache_hit = rb_uncache ? 0 : (way0_hit || way1_hit);
assign data_ok = (state == `LOOKUP) && cache_hit || (state == `REFILL) && ret_valid || 
                 (state == `REFILL) && rb_uncache && rb_op && uncache_write_go; // TODO: uncache w

// Data Select
wire [ 31:0] way0_load_word;
wire [ 31:0] way1_load_word;
wire [ 31:0] load_res;

assign way0_load_word = way0_data[rb_offset[3:2]*32 +: 32];
assign way1_load_word = way1_data[rb_offset[3:2]*32 +: 32];
assign load_res = {32{way0_hit}} & way0_load_word |
                  {32{way1_hit}} & way1_load_word;
assign rdata = {32{(state == `LOOKUP) && cache_hit}} & load_res | 
               {32{(state == `REFILL) && ret_valid}} & rd_way_rdata;

// NRU
reg last_hit [255:0];
reg rp_way;

genvar i;
generate for (i=0; i<256; i=i+1) begin :gen_for_hit
    always @(posedge clk) begin
        if (!resetn) begin
            last_hit[i] <= 1'b0;
        end
        else if (state == `LOOKUP && way0_hit && rb_index == i) begin
            last_hit[i] <= 1'b0;
        end
        else if (state == `LOOKUP && way1_hit && rb_index == i) begin
            last_hit[i] <= 1'b1;
        end
    end
end endgenerate

always @(posedge clk) begin
    if (!resetn) begin
        rp_way <= 1'b0;
    end
    else if (state == `LOOKUP && !cache_hit) begin
        if (!way0_v) begin
            rp_way <= 1'b0;
        end
        else if (!way1_v) begin
            rp_way <= 1'b1;
        end
        else if(!way0_d && way1_d) begin
            rp_way <= 1'b0;
        end
        else if(way0_d && !way1_d) begin
            rp_way <= 1'b1;
        end
        else begin
            if(last_hit[rb_index] == 1'b0) begin
                rp_way <= 1'b1;
            end
            else if(last_hit[rb_index] == 1'b1) begin
                rp_way <= 1'b0;
            end
        end
    end
end

// Miss Buffer
reg         way0_v_r;
reg         way1_v_r;
reg         way0_d_r;
reg         way1_d_r;
reg [ 19:0] way0_tag_r;
reg [ 19:0] way1_tag_r;
reg [127:0] way0_data_r;
reg [127:0] way1_data_r;

wire         rp_way_v;
wire         rp_way_d;
wire [ 19:0] rp_way_tag;
wire [127:0] rp_way_data;

always @(posedge clk) begin
    if ((state == `LOOKUP) && !cache_hit) begin
        way0_v_r <= way0_v;
        way1_v_r <= way1_v;
        way0_d_r <= way0_d;
        way1_d_r <= way1_d;
        way0_tag_r <= way0_tag;
        way1_tag_r <= way1_tag;
        way0_data_r <= way0_data;
        way1_data_r <= way1_data;
    end
end
assign rp_way_v    = rp_way ? way1_v_r    : way0_v_r;
assign rp_way_d    = rp_way ? way1_d_r    : way0_d_r;
assign rp_way_tag  = rp_way ? way1_tag_r  : way0_tag_r;
assign rp_way_data = rp_way ? way1_data_r : way0_data_r;

wire write_back;
assign write_back = !rb_uncache && rp_way_d && rp_way_v;

assign wr_req = (state == `MISS) && (write_back || (rb_uncache && rb_op));
assign wr_type = rb_uncache ? 1'b0 : 1'b1;
assign wr_addr = rb_uncache ? {rb_tag, rb_index, rb_offset} : {rp_way_tag, rb_index, 4'b0};
assign wr_size = rb_uncache ? {1'b0, rb_size} : 3'd2;
assign wr_wstrb = rb_uncache ? rb_wstrb : 4'b1111;
assign wr_data = rb_uncache ? {96'b0, rb_wdata} : rp_way_data;

wire [ 31:0] rd_way_data_bank0;
wire [ 31:0] rd_way_data_bank1;
wire [ 31:0] rd_way_data_bank2;
wire [ 31:0] rd_way_data_bank3;
wire [ 31:0] rd_way_wdata_bank0;
wire [ 31:0] rd_way_wdata_bank1;
wire [ 31:0] rd_way_wdata_bank2;
wire [ 31:0] rd_way_wdata_bank3;
wire [ 31:0] rd_way_rdata;

assign rd_req = (state == `REPLACE) && !(rb_uncache && rb_op) && !(rb_uncache && uncache_read_stall);
assign rd_type = rb_uncache ? 1'b0 : 1'b1;
assign rd_addr = rb_uncache ? {rb_tag, rb_index, rb_offset} : {rb_tag, rb_index, 4'b0};
assign rd_size = rb_uncache ? {1'b0, rb_size} : 3'd2;

assign rd_way_data_bank0 = ret_data[31:0];
assign rd_way_data_bank1 = ret_data[63:32];
assign rd_way_data_bank2 = ret_data[95:64];
assign rd_way_data_bank3 = ret_data[127:96];
assign rd_way_wdata_bank0[ 7: 0] = (rb_op && rb_offset[3:2] == 2'b00 && rb_wstrb[0]) ? rb_wdata[ 7: 0] : rd_way_data_bank0[ 7: 0];
assign rd_way_wdata_bank0[15: 8] = (rb_op && rb_offset[3:2] == 2'b00 && rb_wstrb[1]) ? rb_wdata[15: 8] : rd_way_data_bank0[15: 8];
assign rd_way_wdata_bank0[23:16] = (rb_op && rb_offset[3:2] == 2'b00 && rb_wstrb[2]) ? rb_wdata[23:16] : rd_way_data_bank0[23:16];
assign rd_way_wdata_bank0[31:24] = (rb_op && rb_offset[3:2] == 2'b00 && rb_wstrb[3]) ? rb_wdata[31:24] : rd_way_data_bank0[31:24];
assign rd_way_wdata_bank1[ 7: 0] = (rb_op && rb_offset[3:2] == 2'b01 && rb_wstrb[0]) ? rb_wdata[ 7: 0] : rd_way_data_bank1[ 7: 0];
assign rd_way_wdata_bank1[15: 8] = (rb_op && rb_offset[3:2] == 2'b01 && rb_wstrb[1]) ? rb_wdata[15: 8] : rd_way_data_bank1[15: 8];
assign rd_way_wdata_bank1[23:16] = (rb_op && rb_offset[3:2] == 2'b01 && rb_wstrb[2]) ? rb_wdata[23:16] : rd_way_data_bank1[23:16];
assign rd_way_wdata_bank1[31:24] = (rb_op && rb_offset[3:2] == 2'b01 && rb_wstrb[3]) ? rb_wdata[31:24] : rd_way_data_bank1[31:24];
assign rd_way_wdata_bank2[ 7: 0] = (rb_op && rb_offset[3:2] == 2'b10 && rb_wstrb[0]) ? rb_wdata[ 7: 0] : rd_way_data_bank2[ 7: 0];
assign rd_way_wdata_bank2[15: 8] = (rb_op && rb_offset[3:2] == 2'b10 && rb_wstrb[1]) ? rb_wdata[15: 8] : rd_way_data_bank2[15: 8];
assign rd_way_wdata_bank2[23:16] = (rb_op && rb_offset[3:2] == 2'b10 && rb_wstrb[2]) ? rb_wdata[23:16] : rd_way_data_bank2[23:16];
assign rd_way_wdata_bank2[31:24] = (rb_op && rb_offset[3:2] == 2'b10 && rb_wstrb[3]) ? rb_wdata[31:24] : rd_way_data_bank2[31:24];
assign rd_way_wdata_bank3[ 7: 0] = (rb_op && rb_offset[3:2] == 2'b11 && rb_wstrb[0]) ? rb_wdata[ 7: 0] : rd_way_data_bank3[ 7: 0];
assign rd_way_wdata_bank3[15: 8] = (rb_op && rb_offset[3:2] == 2'b11 && rb_wstrb[1]) ? rb_wdata[15: 8] : rd_way_data_bank3[15: 8];
assign rd_way_wdata_bank3[23:16] = (rb_op && rb_offset[3:2] == 2'b11 && rb_wstrb[2]) ? rb_wdata[23:16] : rd_way_data_bank3[23:16];
assign rd_way_wdata_bank3[31:24] = (rb_op && rb_offset[3:2] == 2'b11 && rb_wstrb[3]) ? rb_wdata[31:24] : rd_way_data_bank3[31:24];
assign rd_way_rdata = {32{rb_uncache}} & rd_way_data_bank0 | 
                      {32{!rb_uncache && rb_offset[3:2] == 2'b00}} & rd_way_data_bank0 | 
                      {32{!rb_uncache && rb_offset[3:2] == 2'b01}} & rd_way_data_bank1 | 
                      {32{!rb_uncache && rb_offset[3:2] == 2'b10}} & rd_way_data_bank2 | 
                      {32{!rb_uncache && rb_offset[3:2] == 2'b11}} & rd_way_data_bank3;

// AXI Write Buffer
reg [31:0] pending_addr [7:0];
reg        pending_type [7:0];
reg        pending_valid[7:0];
reg [2:0] pending_start;
reg [2:0] pending_end;

genvar ip;
generate for (ip=0; ip<256; ip=ip+1) begin :gen_for_valid
    always @(posedge clk) begin
        if (!resetn) begin
            pending_valid[ip] <= 0;
        end
        else if (wr_req && wr_rdy && (ip == pending_end + 3'b1)) begin
            pending_valid[ip] <= 1'b1;
        end
        else if (wr_ok && (ip == pending_start + 3'b1)) begin
            pending_valid[ip] <= 1'b0;
        end
    end
end endgenerate

always @(posedge clk) begin
    if (!resetn) begin
        pending_end <= 3'b0;
    end
    else if (wr_req && wr_rdy) begin
        pending_addr[pending_end + 3'b1] <= wr_addr;
        pending_type[pending_end + 3'b1] <= wr_type; 
        pending_end <= pending_end + 3'b1;
    end
end

always @(posedge clk) begin
    if (!resetn) begin
        pending_start <= 3'b0;
    end
    else if (wr_ok) begin
        pending_start <= pending_start + 3'b1;
    end
end

wire uncache_write_go;
wire uncache_read_stall;

assign uncache_write_go = ((pending_end + 3'b1) != pending_start);

wire [2:0] match;
genvar im;
generate for (im=0; im<256; im=im+1) begin :gen_for_match
    assign match[im] = ({rb_tag, rb_index, rb_offset} == pending_addr[im]) && 
                       (pending_type[im] == 1'b0) &&
                       (pending_valid[im] == 1'b1);
end endgenerate
assign uncache_read_stall = |match;


// Main FSM
reg  [4:0] state;
reg  [4:0] next_state;

always @(posedge clk) begin
    if (!resetn) begin
        state <= `IDLE;
    end
    else begin
        state <= next_state;
    end
end
always@(*) begin
	case(state)
	`IDLE:
		if (valid && addr_ok) begin
			next_state = `LOOKUP;
		end
		else begin
			next_state = `IDLE;
		end
	`LOOKUP:
        if (cache_hit && !(valid && addr_ok)) begin
			next_state = `IDLE;
		end
        else if (cache_hit && valid && addr_ok) begin
			next_state = `LOOKUP;
		end
		else begin
			next_state = `MISS;
		end
    `MISS:
        if (!write_back && !(rb_uncache && rb_op)) begin
			next_state = `REPLACE;
		end
        else if (wr_rdy && wr_req) begin
            next_state = `REPLACE;
        end
		else begin
			next_state = `MISS;
		end
    `REPLACE:
        if (rb_uncache && rb_op) begin
			next_state = `REFILL;
		end
        else if (rd_rdy && rd_req) begin
            next_state = `REFILL;
        end
		else begin
			next_state = `REPLACE;
		end
    `REFILL:
        if (rb_uncache && rb_op && uncache_write_go) begin
            next_state = `IDLE;
        end
        else if (ret_valid) begin
            next_state = `IDLE;
        end
        else begin
            next_state = `REFILL;
        end
	default:
		next_state = `IDLE;
	endcase
end

// Write Buffer
reg          wb_hit_way;
reg  [  7:0] wb_index;
reg  [  3:0] wb_offset;
reg  [  3:0] wb_wstrb;
reg  [ 31:0] wb_wdata;

always @(posedge clk) begin
    if ((state == `LOOKUP) && cache_hit && (rb_op == 1'b1)) begin
        wb_hit_way <= way1_hit ? 1'b1 : 1'b0;
        wb_index   <= rb_index;
        wb_offset  <= rb_offset;
        wb_wstrb   <= rb_wstrb;
        wb_wdata   <= rb_wdata;
    end
end

// Write FSM
reg  [1:0] wstate;
reg  [1:0] next_wstate;

always @(posedge clk) begin
    if (!resetn) begin
        wstate <= `WIDLE;
    end
    else begin
        wstate <= next_wstate;
    end
end
always@(*) begin
	case(wstate)
	`WIDLE:
		if ((state == `LOOKUP) && cache_hit && (rb_op == 1'b1)) begin
			next_wstate = `WRITE;
		end
		else begin
			next_wstate = `WIDLE;
		end
	`WRITE:
        if ((state == `LOOKUP) && cache_hit && (rb_op == 1'b1)) begin
			next_wstate = `WRITE;
		end
		else begin
			next_wstate = `WIDLE;
		end
	default:
		next_wstate = `WIDLE;
	endcase
end

endmodule
