`define  IDLE    9'b000000001
`define  LOOKUP  9'b000000010
`define  MISS    9'b000000100
`define  REPLACE 9'b000001000
`define  REFILL  9'b000010000
`define  URREQ   9'b000100000
`define  URRESP  9'b001000000
`define  UWREQ   9'b010000000
`define  UWRESP  9'b100000000

`define  WIDLE   2'b01
`define  WRITE   2'b10

module dcache(
    input           clk,
    input           resetn,
    // Cache and CPU Way1
    input           valid1,
    input           op1,
    input           uncache1,
    input  [ 19:0]  tag1,
    input  [  7:0]  index1,
    input  [  3:0]  offset1,
    input  [  1:0]  size1,
    input  [  3:0]  wstrb1,
    input  [ 31:0]  wdata1,
    output          addr_ok1,
    output          data_ok1,
    output [ 31:0]  rdata1,
    // Cache and CPU Way2
    input           valid2,
    input           op2,
    input           uncache2,
    input  [ 19:0]  tag2,
    input  [  7:0]  index2,
    input  [  3:0]  offset2,
    input  [  1:0]  size2,
    input  [  3:0]  wstrb2,
    input  [ 31:0]  wdata2,
    output          addr_ok2,
    output          data_ok2,
    output [ 31:0]  rdata2,
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

// RAM
wire        tag_way0_en;
wire        tag_way1_en;
wire        tag_way0_we;
wire        tag_way1_we;
wire [ 7:0] tag_addr;
wire [19:0] tag_way0_din;
wire [19:0] tag_way1_din;
wire [19:0] tag_way0_dout;
wire [19:0] tag_way1_dout;

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

Tag_RAM Tag_RAM_Way0(
    .clka   (clk          ),
    .addra  (tag_addr     ),
    .ena    (tag_way0_en  ),
    .wea    (tag_way0_we  ),
    .dina   (tag_way0_din ),
    .douta  (tag_way0_dout)
);
Tag_RAM Tag_RAM_Way1(
    .clka   (clk          ),
    .addra  (tag_addr     ),
    .ena    (tag_way1_en  ),
    .wea    (tag_way1_we  ),
    .dina   (tag_way1_din ),
    .douta  (tag_way1_dout)
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

reg D_Way0 [255:0];
reg D_Way1 [255:0];
reg V_Way0 [255:0];
reg V_Way1 [255:0];

// RAM Port
assign tag_way0_en = (_1_cache_req && addr_ok1) ||
                     (_2_cache_req && addr_ok2) ||
                     (state == `REFILL && ret_valid && !rp_way);
assign tag_way1_en = (_1_cache_req && addr_ok1) ||
                     (_2_cache_req && addr_ok2) ||
                     (state == `REFILL && ret_valid &&  rp_way);
assign tag_way0_we = (state == `REFILL && ret_valid && !rp_way);
assign tag_way1_we = (state == `REFILL && ret_valid &&  rp_way);
assign tag_way0_din = rb_valid[0] ? rb_tag1 :
                      rb_valid[1] ? rb_tag2 : 20'b0;
assign tag_way1_din = rb_valid[0] ? rb_tag1 :
                      rb_valid[1] ? rb_tag2 : 20'b0;
assign tag_addr = (_1_cache_req && addr_ok1)  ? index1 : 
                  (_2_cache_req && addr_ok2)  ? index2 : 
                  (state == `REFILL && ret_valid && rb_valid[0]) ? rb_index1 :
                  (state == `REFILL && ret_valid && rb_valid[1]) ? rb_index2 : 8'b0;

assign data_way0_bank0_en = (_1_cache_req && addr_ok1) || 
                            (_2_cache_req && addr_ok2) || 
                            (wstate == `WRITE && wb_valid[0] && wb_offset1[3:2] == 2'b00 && !wb_hit_way) || 
                            (wstate == `WRITE && wb_valid[1] && wb_offset2[3:2] == 2'b00 && !wb_hit_way) || 
                            (state == `REFILL && ret_valid && !rp_way);
assign data_way0_bank1_en = (_1_cache_req && addr_ok1) || 
                            (_2_cache_req && addr_ok2) || 
                            (wstate == `WRITE && wb_valid[0] && wb_offset1[3:2] == 2'b01 && !wb_hit_way) || 
                            (wstate == `WRITE && wb_valid[1] && wb_offset2[3:2] == 2'b01 && !wb_hit_way) || 
                            (state == `REFILL && ret_valid && !rp_way);
assign data_way0_bank2_en = (_1_cache_req && addr_ok1) || 
                            (_2_cache_req && addr_ok2) || 
                            (wstate == `WRITE && wb_valid[0] && wb_offset1[3:2] == 2'b10 && !wb_hit_way) || 
                            (wstate == `WRITE && wb_valid[1] && wb_offset2[3:2] == 2'b10 && !wb_hit_way) || 
                            (state == `REFILL && ret_valid && !rp_way);
assign data_way0_bank3_en = (_1_cache_req && addr_ok1) || 
                            (_2_cache_req && addr_ok2) || 
                            (wstate == `WRITE && wb_valid[0] && wb_offset1[3:2] == 2'b11 && !wb_hit_way) || 
                            (wstate == `WRITE && wb_valid[1] && wb_offset2[3:2] == 2'b11 && !wb_hit_way) || 
                            (state == `REFILL && ret_valid && !rp_way);
assign data_way1_bank0_en = (_1_cache_req && addr_ok1) || 
                            (_2_cache_req && addr_ok2) || 
                            (wstate == `WRITE && wb_valid[0] && wb_offset1[3:2] == 2'b00 &&  wb_hit_way) || 
                            (wstate == `WRITE && wb_valid[1] && wb_offset2[3:2] == 2'b00 &&  wb_hit_way) || 
                            (state == `REFILL && ret_valid &&  rp_way);
assign data_way1_bank1_en = (_1_cache_req && addr_ok1) || 
                            (_2_cache_req && addr_ok2) || 
                            (wstate == `WRITE && wb_valid[0] && wb_offset1[3:2] == 2'b01 &&  wb_hit_way) || 
                            (wstate == `WRITE && wb_valid[1] && wb_offset2[3:2] == 2'b01 &&  wb_hit_way) || 
                            (state == `REFILL && ret_valid &&  rp_way);
assign data_way1_bank2_en = (_1_cache_req && addr_ok1) || 
                            (_2_cache_req && addr_ok2) || 
                            (wstate == `WRITE && wb_valid[0] && wb_offset1[3:2] == 2'b10 &&  wb_hit_way) || 
                            (wstate == `WRITE && wb_valid[1] && wb_offset1[3:2] == 2'b10 &&  wb_hit_way) || 
                            (state == `REFILL && ret_valid &&  rp_way);
assign data_way1_bank3_en = (_1_cache_req && addr_ok1) || 
                            (_2_cache_req && addr_ok2) || 
                            (wstate == `WRITE && wb_valid[0] && wb_offset1[3:2] == 2'b11 &&  wb_hit_way) || 
                            (wstate == `WRITE && wb_valid[1] && wb_offset2[3:2] == 2'b11 &&  wb_hit_way) || 
                            (state == `REFILL && ret_valid &&  rp_way);

assign data_way0_bank0_we = (wstate == `WRITE && wb_valid[1] && wb_offset2[3:2] == 2'b00) ? wb_wstrb2 :
                            (wstate == `WRITE && wb_valid[0] && wb_offset1[3:2] == 2'b00) ? wb_wstrb1 :
                            (state == `REFILL && ret_valid && !rp_way) ? 4'b1111 : 4'b0000;
assign data_way0_bank1_we = (wstate == `WRITE && wb_valid[1] && wb_offset2[3:2] == 2'b01) ? wb_wstrb2 :
                            (wstate == `WRITE && wb_valid[0] && wb_offset1[3:2] == 2'b01) ? wb_wstrb1 :
                            (state == `REFILL && ret_valid && !rp_way) ? 4'b1111 : 4'b0000;
assign data_way0_bank2_we = (wstate == `WRITE && wb_valid[1] && wb_offset2[3:2] == 2'b10) ? wb_wstrb2 :
                            (wstate == `WRITE && wb_valid[0] && wb_offset1[3:2] == 2'b10) ? wb_wstrb1 :
                            (state == `REFILL && ret_valid && !rp_way) ? 4'b1111 : 4'b0000;
assign data_way0_bank3_we = (wstate == `WRITE && wb_valid[1] && wb_offset2[3:2] == 2'b11) ? wb_wstrb2 :
                            (wstate == `WRITE && wb_valid[0] && wb_offset1[3:2] == 2'b11) ? wb_wstrb1 :
                            (state == `REFILL && ret_valid && !rp_way) ? 4'b1111 : 4'b0000;
assign data_way1_bank0_we = (wstate == `WRITE && wb_valid[1] && wb_offset2[3:2] == 2'b00) ? wb_wstrb2 :
                            (wstate == `WRITE && wb_valid[0] && wb_offset1[3:2] == 2'b00) ? wb_wstrb1 :
                            (state == `REFILL && ret_valid &&  rp_way) ? 4'b1111 : 4'b0000;
assign data_way1_bank1_we = (wstate == `WRITE && wb_valid[1] && wb_offset2[3:2] == 2'b01) ? wb_wstrb2 :
                            (wstate == `WRITE && wb_valid[0] && wb_offset1[3:2] == 2'b01) ? wb_wstrb1 :
                            (state == `REFILL && ret_valid &&  rp_way) ? 4'b1111 : 4'b0000;
assign data_way1_bank2_we = (wstate == `WRITE && wb_valid[1] && wb_offset2[3:2] == 2'b10) ? wb_wstrb2 :
                            (wstate == `WRITE && wb_valid[0] && wb_offset1[3:2] == 2'b10) ? wb_wstrb1 :
                            (state == `REFILL && ret_valid &&  rp_way) ? 4'b1111 : 4'b0000;
assign data_way1_bank3_we = (wstate == `WRITE && wb_valid[1] && wb_offset2[3:2] == 2'b11) ? wb_wstrb2 :
                            (wstate == `WRITE && wb_valid[0] && wb_offset1[3:2] == 2'b11) ? wb_wstrb1 :
                            (state == `REFILL && ret_valid &&  rp_way) ? 4'b1111 : 4'b0000;

assign data_way0_bank0_din = (wstate == `WRITE && wb_valid[1] && wb_offset2[3:2] == 2'b00) ? wb_wdata2 :
                             (wstate == `WRITE && wb_valid[0] && wb_offset1[3:2] == 2'b00) ? wb_wdata1 :
                             (state == `REFILL) ? rd_way_wdata_bank0 : 32'b0;
assign data_way0_bank1_din = (wstate == `WRITE && wb_valid[1] && wb_offset2[3:2] == 2'b01) ? wb_wdata2 :
                             (wstate == `WRITE && wb_valid[0] && wb_offset1[3:2] == 2'b01) ? wb_wdata1 :
                             (state == `REFILL) ? rd_way_wdata_bank1 : 32'b0;
assign data_way0_bank2_din = (wstate == `WRITE && wb_valid[1] && wb_offset2[3:2] == 2'b10) ? wb_wdata2 :
                             (wstate == `WRITE && wb_valid[0] && wb_offset1[3:2] == 2'b10) ? wb_wdata1 :
                             (state == `REFILL) ? rd_way_wdata_bank2 : 32'b0;
assign data_way0_bank3_din = (wstate == `WRITE && wb_valid[1] && wb_offset2[3:2] == 2'b11) ? wb_wdata2 :
                             (wstate == `WRITE && wb_valid[0] && wb_offset1[3:2] == 2'b11) ? wb_wdata1 :
                             (state == `REFILL) ? rd_way_wdata_bank3 : 32'b0;
assign data_way1_bank0_din = (wstate == `WRITE && wb_valid[1] && wb_offset2[3:2] == 2'b00) ? wb_wdata2 :
                             (wstate == `WRITE && wb_valid[0] && wb_offset1[3:2] == 2'b00) ? wb_wdata1 :
                             (state == `REFILL) ? rd_way_wdata_bank0 : 32'b0;
assign data_way1_bank1_din = (wstate == `WRITE && wb_valid[1] && wb_offset2[3:2] == 2'b01) ? wb_wdata2 :
                             (wstate == `WRITE && wb_valid[0] && wb_offset1[3:2] == 2'b01) ? wb_wdata1 :
                             (state == `REFILL) ? rd_way_wdata_bank1 : 32'b0;
assign data_way1_bank2_din = (wstate == `WRITE && wb_valid[1] && wb_offset2[3:2] == 2'b10) ? wb_wdata2 :
                             (wstate == `WRITE && wb_valid[0] && wb_offset1[3:2] == 2'b10) ? wb_wdata1 :
                             (state == `REFILL) ? rd_way_wdata_bank2 : 32'b0;
assign data_way1_bank3_din = (wstate == `WRITE && wb_valid[1] && wb_offset2[3:2] == 2'b11) ? wb_wdata2 :
                             (wstate == `WRITE && wb_valid[0] && wb_offset1[3:2] == 2'b11) ? wb_wdata1 :
                             (state == `REFILL) ? rd_way_wdata_bank3 : 32'b0;

assign data_addr = (wstate == `WRITE)          ? wb_index : 
                   (_1_cache_req && addr_ok1)  ? index1 : 
                   (_2_cache_req && addr_ok2)  ? index2 : 
                   (state == `REFILL && ret_valid && rb_valid[0]) ? rb_index1 :
                   (state == `REFILL && ret_valid && rb_valid[1]) ? rb_index2 : 8'b0;

genvar i0;
generate for (i0=0; i0<256; i0=i0+1) begin :gen_for_D_Way0
    always @(posedge clk) begin
        if (!resetn) begin
            D_Way0[i0] <= 1'b0;
        end
        else if (wstate == `WRITE && !wb_hit_way && i0 == wb_index) begin
            D_Way0[i0] <= 1'b1;
        end
        else if (state == `REFILL && ret_valid && !rp_way && rb_valid[0] && i0 == rb_index1) begin
            D_Way0[i0] <= rb_op1;
        end
        else if (state == `REFILL && ret_valid && !rp_way && rb_valid[1] && i0 == rb_index2) begin
            D_Way0[i0] <= rb_op2;
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
        else if (state == `REFILL && ret_valid && rp_way && rb_valid[0] && i1 == rb_index1) begin
            D_Way0[i1] <= rb_op1;
        end
        else if (state == `REFILL && ret_valid && rp_way && rb_valid[1] && i1 == rb_index2) begin
            D_Way0[i1] <= rb_op2;
        end
    end
end endgenerate

genvar iv0;
generate for (iv0=0; iv0<256; iv0=iv0+1) begin :gen_for_V_Way0
    always @(posedge clk) begin
        if (!resetn) begin
            V_Way0[iv0] <= 1'b0;
        end
        else if (state == `REFILL && ret_valid && rp_way == 1'b0 && rb_valid[0] && rb_index1 == iv0) begin
            V_Way0[iv0] <= 1'b1;
        end
        else if (state == `REFILL && ret_valid && rp_way == 1'b0 && rb_valid[1] && rb_index2 == iv0) begin
            V_Way0[iv0] <= 1'b1;
        end
    end
end endgenerate
genvar iv1;
generate for (iv1=0; iv1<256; iv1=iv1+1) begin :gen_for_V_Way1
    always @(posedge clk) begin
        if (!resetn) begin
            V_Way1[iv1] <= 1'b0;
        end
        else if (state == `REFILL && ret_valid && rp_way == 1'b1 && rb_valid[0] && rb_index1 == iv1) begin
            V_Way0[iv1] <= 1'b1;
        end
        else if (state == `REFILL && ret_valid && rp_way == 1'b1 && rb_valid[1] && rb_index2 == iv1) begin
            V_Way0[iv1] <= 1'b1;
        end
    end
end endgenerate

// Request Buffer
wire _1_cache_req;
wire _2_cache_req;
wire req_same_line;
wire req_read_write;
wire _1_req_raw;
wire _2_req_raw;

assign _1_cache_req = valid1 && !uncache1;
assign _2_cache_req = valid2 && !uncache2;
assign req_same_line = _1_cache_req && _2_cache_req && (index1 == index2) && (tag1 == tag2);
assign req_read_write = _1_cache_req && _2_cache_req && (op1 != op2);
assign _1_req_raw = (wstate == `WRITE) && (index1 == wb_index);
assign _2_req_raw = (wstate == `WRITE) && (index2 == wb_index) ;

reg [1:0] rb_valid;
reg uncache_way;
always @(posedge clk) begin
    if(!resetn) begin
        rb_valid <= 2'b00;
    end
    else if(_1_cache_req && addr_ok1 && _2_cache_req && addr_ok2) begin
        rb_valid <= 2'b11;
    end
    else if(_1_cache_req && addr_ok1) begin
        rb_valid <= 2'b01;
    end
    else if(_2_cache_req && addr_ok2) begin
        rb_valid <= 2'b10;
    end
end
always @(posedge clk) begin
    if(!resetn) begin
        uncache_way <= 1'b0;
    end
    else if(valid1 && uncache1 && addr_ok1) begin
        uncache_way <= 1'b0;
    end
    else if(valid2 && uncache2 && addr_ok2) begin
        uncache_way <= 1'b1;
    end
end

reg          rb_op1;
reg  [ 19:0] rb_tag1;
reg  [  7:0] rb_index1;
reg  [  3:0] rb_offset1;
reg  [  1:0] rb_size1;
reg  [  3:0] rb_wstrb1;
reg  [ 31:0] rb_wdata1;
reg          rb_op2;
reg  [ 19:0] rb_tag2;
reg  [  7:0] rb_index2;
reg  [  3:0] rb_offset2;
reg  [  1:0] rb_size2;
reg  [  3:0] rb_wstrb2;
reg  [ 31:0] rb_wdata2;

always @(posedge clk) begin
    if (_1_cache_req && addr_ok1) begin
        rb_op1     <= op1;
        rb_tag1    <= tag1;
        rb_index1  <= index1;      
        rb_offset1 <= offset1;
        rb_size1   <= size1;
        rb_wstrb1  <= wstrb1;
        rb_wdata1  <= wdata1;
    end
end

always @(posedge clk) begin
    if (_2_cache_req && addr_ok2) begin
        rb_op2     <= op2;
        rb_tag2    <= tag2;
        rb_index2  <= index2;      
        rb_offset2 <= offset2;
        rb_size2   <= size2;
        rb_wstrb2  <= wstrb2;
        rb_wdata2  <= wdata2;
    end
end

wire         way0_v;
wire         way1_v;
wire         way0_d;
wire         way1_d;
wire [ 19:0] way0_tag;
wire [ 19:0] way1_tag;
wire [127:0] way0_data;
wire [127:0] way1_data;

assign way0_d = rb_valid[0] ? D_Way0[rb_index1] : D_Way0[rb_index2];
assign way1_d = rb_valid[0] ? D_Way1[rb_index1] : D_Way1[rb_index2];
assign way0_v = rb_valid[0] ? V_Way0[rb_index1] : V_Way0[rb_index2];
assign way1_v = rb_valid[0] ? V_Way1[rb_index1] : V_Way1[rb_index2];
assign way0_tag = tag_way0_dout;
assign way1_tag = tag_way1_dout;
assign way0_data = {data_way0_bank3_dout, data_way0_bank2_dout, data_way0_bank1_dout, data_way0_bank0_dout};
assign way1_data = {data_way1_bank3_dout, data_way1_bank2_dout, data_way1_bank1_dout, data_way1_bank0_dout};

// Tag Compare
wire         _1_way0_hit;
wire         _1_way1_hit;
wire         _1_cache_hit;
wire         _1_cache_miss;
wire         _2_way0_hit;
wire         _2_way1_hit;
wire         _2_cache_hit;
wire         _2_cache_miss;
wire         way0_hit;
wire         way1_hit;
wire         cache_hit;

assign _1_way0_hit = rb_valid[0] && way0_v && (way0_tag == rb_tag1);
assign _1_way1_hit = rb_valid[0] && way1_v && (way1_tag == rb_tag1);
assign _1_cache_hit = (_1_way0_hit || _1_way1_hit);
assign _1_cache_miss = rb_valid[0] && !_1_cache_hit;

assign _2_way0_hit = rb_valid[1] && way0_v && (way0_tag == rb_tag2);
assign _2_way1_hit = rb_valid[1] && way1_v && (way1_tag == rb_tag2);
assign _2_cache_hit = (_2_way0_hit || _2_way1_hit);
assign _2_cache_miss = rb_valid[1] && !_2_cache_hit;

assign way0_hit = (rb_valid[0] ? _1_way0_hit : 1'b1) && (rb_valid[1] ? _2_way0_hit : 1'b1);
assign way1_hit = (rb_valid[0] ? _1_way1_hit : 1'b1) && (rb_valid[1] ? _2_way1_hit : 1'b1);
assign cache_hit = way0_hit || way1_hit;

// Data Select
wire [ 31:0] _1_way0_load_word;
wire [ 31:0] _1_way1_load_word;
wire [ 31:0] _1_load_res;
wire [ 31:0] _2_way0_load_word;
wire [ 31:0] _2_way1_load_word;
wire [ 31:0] _2_load_res;

assign _1_way0_load_word = way0_data[rb_offset1[3:2]*32 +: 32];
assign _1_way1_load_word = way1_data[rb_offset1[3:2]*32 +: 32];
assign _1_load_res = {32{_1_way0_hit}} & _1_way0_load_word |
                     {32{_1_way1_hit}} & _1_way1_load_word;
assign _2_way0_load_word = way0_data[rb_offset2[3:2]*32 +: 32];
assign _2_way1_load_word = way1_data[rb_offset2[3:2]*32 +: 32];
assign _2_load_res = {32{_2_way0_hit}} & _2_way0_load_word |
                     {32{_2_way1_hit}} & _2_way1_load_word;

// NRU
reg last_hit [255:0];
reg rp_way;

genvar i;
generate for (i=0; i<256; i=i+1) begin :gen_for_hit
    always @(posedge clk) begin
        if (!resetn) begin
            last_hit[i] <= 1'b0;
        end
        else if (state == `LOOKUP && way0_hit && rb_valid[0] && rb_index1 == i) begin
            last_hit[i] <= 1'b0;
        end
        else if (state == `LOOKUP && way0_hit && rb_valid[1] && rb_index2 == i) begin
            last_hit[i] <= 1'b0;
        end
        else if (state == `LOOKUP && way1_hit && rb_valid[0] && rb_index1 == i) begin
            last_hit[i] <= 1'b1;
        end
        else if (state == `LOOKUP && way1_hit && rb_valid[1] && rb_index2 == i) begin
            last_hit[i] <= 1'b1;
        end
    end
end endgenerate

always @(posedge clk) begin
    if (!resetn) begin
        rp_way <= 1'b0;
    end
    else if (state == `LOOKUP && (_1_cache_miss || _2_cache_miss)) begin
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
            if(rb_valid[0] && last_hit[rb_index1] == 1'b0) begin
                rp_way <= 1'b1;
            end
            else if(rb_valid[1] && last_hit[rb_index2] == 1'b0) begin
                rp_way <= 1'b1;
            end
            else if(rb_valid[0] && last_hit[rb_index1] == 1'b1) begin
                rp_way <= 1'b0;
            end
            else if(rb_valid[1] && last_hit[rb_index2] == 1'b1) begin
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
    if ((state == `LOOKUP) && (!_1_cache_hit || !_2_cache_hit)) begin
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
assign write_back = rp_way_d && rp_way_v;

wire [ 31:0] rd_way_data_bank0;
wire [ 31:0] rd_way_data_bank1;
wire [ 31:0] rd_way_data_bank2;
wire [ 31:0] rd_way_data_bank3;
wire [ 31:0] rd_way_wdata_bank0;
wire [ 31:0] rd_way_wdata_bank1;
wire [ 31:0] rd_way_wdata_bank2;
wire [ 31:0] rd_way_wdata_bank3;
wire [ 31:0] _1_rd_way_rdata;
wire [ 31:0] _2_rd_way_rdata;

assign rd_way_data_bank0 = ret_data[ 31: 0];
assign rd_way_data_bank1 = ret_data[ 63:32];
assign rd_way_data_bank2 = ret_data[ 95:64];
assign rd_way_data_bank3 = ret_data[127:96];
assign rd_way_wdata_bank0[ 7: 0] = (rb_op2 && rb_offset2[3:2] == 2'b00 && rb_wstrb2[0]) ? rb_wdata2[ 7: 0] :
                                   (rb_op1 && rb_offset1[3:2] == 2'b00 && rb_wstrb1[0]) ? rb_wdata1[ 7: 0] : rd_way_data_bank0[ 7: 0];
assign rd_way_wdata_bank0[15: 8] = (rb_op2 && rb_offset2[3:2] == 2'b00 && rb_wstrb2[1]) ? rb_wdata2[15: 8] :
                                   (rb_op1 && rb_offset1[3:2] == 2'b00 && rb_wstrb1[1]) ? rb_wdata1[15: 8] : rd_way_data_bank0[15: 8];
assign rd_way_wdata_bank0[23:16] = (rb_op2 && rb_offset2[3:2] == 2'b00 && rb_wstrb2[2]) ? rb_wdata2[23:16] :
                                   (rb_op1 && rb_offset1[3:2] == 2'b00 && rb_wstrb1[2]) ? rb_wdata1[23:16] : rd_way_data_bank0[23:16];
assign rd_way_wdata_bank0[31:24] = (rb_op2 && rb_offset2[3:2] == 2'b00 && rb_wstrb2[3]) ? rb_wdata2[31:24] :
                                   (rb_op1 && rb_offset1[3:2] == 2'b00 && rb_wstrb1[3]) ? rb_wdata1[31:24] : rd_way_data_bank0[31:24];
assign rd_way_wdata_bank1[ 7: 0] = (rb_op2 && rb_offset2[3:2] == 2'b01 && rb_wstrb2[0]) ? rb_wdata2[ 7: 0] :
                                   (rb_op1 && rb_offset1[3:2] == 2'b01 && rb_wstrb1[0]) ? rb_wdata1[ 7: 0] : rd_way_data_bank1[ 7: 0];
assign rd_way_wdata_bank1[15: 8] = (rb_op2 && rb_offset2[3:2] == 2'b01 && rb_wstrb2[1]) ? rb_wdata2[15: 8] :
                                   (rb_op1 && rb_offset1[3:2] == 2'b01 && rb_wstrb1[1]) ? rb_wdata1[15: 8] : rd_way_data_bank1[15: 8];
assign rd_way_wdata_bank1[23:16] = (rb_op2 && rb_offset2[3:2] == 2'b01 && rb_wstrb2[2]) ? rb_wdata2[23:16] :
                                   (rb_op1 && rb_offset1[3:2] == 2'b01 && rb_wstrb1[2]) ? rb_wdata1[23:16] : rd_way_data_bank1[23:16];
assign rd_way_wdata_bank1[31:24] = (rb_op2 && rb_offset2[3:2] == 2'b01 && rb_wstrb2[3]) ? rb_wdata2[31:24] :
                                   (rb_op1 && rb_offset1[3:2] == 2'b01 && rb_wstrb1[3]) ? rb_wdata1[31:24] : rd_way_data_bank1[31:24];
assign rd_way_wdata_bank2[ 7: 0] = (rb_op2 && rb_offset2[3:2] == 2'b10 && rb_wstrb2[0]) ? rb_wdata2[ 7: 0] :
                                   (rb_op1 && rb_offset1[3:2] == 2'b10 && rb_wstrb1[0]) ? rb_wdata1[ 7: 0] : rd_way_data_bank2[ 7: 0];
assign rd_way_wdata_bank2[15: 8] = (rb_op2 && rb_offset2[3:2] == 2'b10 && rb_wstrb2[1]) ? rb_wdata2[15: 8] :
                                   (rb_op1 && rb_offset1[3:2] == 2'b10 && rb_wstrb1[1]) ? rb_wdata1[15: 8] : rd_way_data_bank2[15: 8];
assign rd_way_wdata_bank2[23:16] = (rb_op2 && rb_offset2[3:2] == 2'b10 && rb_wstrb2[2]) ? rb_wdata2[23:16] :
                                   (rb_op1 && rb_offset1[3:2] == 2'b10 && rb_wstrb1[2]) ? rb_wdata1[23:16] : rd_way_data_bank2[23:16];
assign rd_way_wdata_bank2[31:24] = (rb_op2 && rb_offset2[3:2] == 2'b10 && rb_wstrb2[3]) ? rb_wdata2[31:24] :
                                   (rb_op1 && rb_offset1[3:2] == 2'b10 && rb_wstrb1[3]) ? rb_wdata1[31:24] : rd_way_data_bank2[31:24];
assign rd_way_wdata_bank3[ 7: 0] = (rb_op2 && rb_offset2[3:2] == 2'b11 && rb_wstrb2[0]) ? rb_wdata2[ 7: 0] :
                                   (rb_op1 && rb_offset1[3:2] == 2'b11 && rb_wstrb1[0]) ? rb_wdata1[ 7: 0] : rd_way_data_bank3[ 7: 0];
assign rd_way_wdata_bank3[15: 8] = (rb_op2 && rb_offset2[3:2] == 2'b11 && rb_wstrb2[1]) ? rb_wdata2[15: 8] :
                                   (rb_op1 && rb_offset1[3:2] == 2'b11 && rb_wstrb1[1]) ? rb_wdata1[15: 8] : rd_way_data_bank3[15: 8];
assign rd_way_wdata_bank3[23:16] = (rb_op2 && rb_offset2[3:2] == 2'b11 && rb_wstrb2[2]) ? rb_wdata2[23:16] :
                                   (rb_op1 && rb_offset1[3:2] == 2'b11 && rb_wstrb1[2]) ? rb_wdata1[23:16] : rd_way_data_bank3[23:16];
assign rd_way_wdata_bank3[31:24] = (rb_op2 && rb_offset2[3:2] == 2'b11 && rb_wstrb2[3]) ? rb_wdata2[31:24] :
                                   (rb_op1 && rb_offset1[3:2] == 2'b11 && rb_wstrb1[3]) ? rb_wdata1[31:24] : rd_way_data_bank3[31:24];
assign _1_rd_way_rdata = {32{rb_offset1[3:2] == 2'b00}} & rd_way_data_bank0 | 
                         {32{rb_offset1[3:2] == 2'b01}} & rd_way_data_bank1 | 
                         {32{rb_offset1[3:2] == 2'b10}} & rd_way_data_bank2 | 
                         {32{rb_offset1[3:2] == 2'b11}} & rd_way_data_bank3;
assign _2_rd_way_rdata = {32{rb_offset2[3:2] == 2'b00}} & rd_way_data_bank0 | 
                         {32{rb_offset2[3:2] == 2'b01}} & rd_way_data_bank1 | 
                         {32{rb_offset2[3:2] == 2'b10}} & rd_way_data_bank2 | 
                         {32{rb_offset2[3:2] == 2'b11}} & rd_way_data_bank3;

// AXI Write Buffer
reg [31:0] pending_addr [7:0];
reg        pending_type [7:0];
reg        pending_valid[7:0];
reg [2:0] pending_start;
reg [2:0] pending_end;

genvar ip;
generate for (ip=0; ip<8; ip=ip+1) begin :gen_for_valid
    always @(posedge clk) begin
        if (!resetn) begin
            pending_valid[ip] <= 0;
        end
        else if (wr_req && wr_rdy && (ip == pending_end)) begin
            pending_valid[ip] <= 1'b1;
        end
        else if (wr_ok && (ip == pending_start)) begin
            pending_valid[ip] <= 1'b0;
        end
    end
end endgenerate

always @(posedge clk) begin
    if (!resetn) begin
        pending_end <= 3'b0;
    end
    else if (wr_req && wr_rdy) begin
        pending_addr[pending_end] <= wr_addr;
        pending_type[pending_end] <= wr_type; 
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

wire uncache_read_stall;
wire uncache_write_go;

wire [7:0] match;
wire [31:0] addr;
assign addr = (uncache_way == 1'b0) ? {rb_tag1, rb_index1, rb_offset1} : {rb_tag2, rb_index2, rb_offset2};
genvar im;
generate for (im=0; im<8; im=im+1) begin :gen_for_match
    assign match[im] = (addr == pending_addr[im]) && 
                       (pending_type[im] == 1'b0) &&
                       (pending_valid[im] == 1'b1);
end endgenerate
assign uncache_read_stall = |match;
assign uncache_write_go = !((pending_end + 3'b1) == pending_start);

// Output
assign addr_ok1 = (state == `IDLE || (state == `LOOKUP && cache_hit)) && _1_cache_req;
assign addr_ok2 = (state == `IDLE || (state == `LOOKUP && cache_hit)) && _2_cache_req &&
                  (!_1_cache_req || req_same_line && !req_read_write);
assign data_ok1 = (state == `LOOKUP) && _1_cache_hit ||
                  (state == `REFILL) && ret_valid || 
                  (state == `URRESP) && ret_valid ||
                  (state == `UWRESP) && uncache_write_go;
assign data_ok2 = (state == `LOOKUP) && _2_cache_hit ||
                  (state == `REFILL) && ret_valid || 
                  (state == `URRESP) && ret_valid ||
                  (state == `UWRESP) && uncache_write_go;
assign rdata1 = {32{(state == `LOOKUP) && _1_cache_hit}} & _1_load_res  | 
                {32{(state == `REFILL) && ret_valid}} & _1_rd_way_rdata |
                {32{(state == `URRESP) && ret_valid}} & ret_data[31:0];
assign rdata2 = {32{(state == `LOOKUP) && _2_cache_hit}} & _2_load_res  | 
                {32{(state == `REFILL) && ret_valid}} & _2_rd_way_rdata |
                {32{(state == `URRESP) && ret_valid}} & ret_data[31:0];

assign wr_req   = (state == `MISS && write_back) || 
                  (state == `UWREQ);
assign wr_type  = (state == `UWREQ) ? 1'b0 : 1'b1;
assign wr_addr  = (state == `UWREQ && uncache_way == 1'b0) ? {rb_tag1, rb_index1, rb_offset1} :
                  (state == `UWREQ && uncache_way == 1'b1) ? {rb_tag2, rb_index2, rb_offset2} : {rp_way_tag, rb_index1, 4'b0};
assign wr_size  = (state == `UWREQ && uncache_way == 1'b0) ? {1'b0, rb_size1} :
                  (state == `UWREQ && uncache_way == 1'b1) ? {1'b0, rb_size2} : 3'd2;
assign wr_wstrb = (state == `UWREQ && uncache_way == 1'b0) ? rb_wstrb1 :
                  (state == `UWREQ && uncache_way == 1'b1) ? rb_wstrb2 : 4'b1111;
assign wr_data  = (state == `UWREQ && uncache_way == 1'b0) ? {96'b0, rb_wdata1} :
                  (state == `UWREQ && uncache_way == 1'b1) ? {96'b0, rb_wdata2} : rp_way_data;

assign rd_req  = (state == `REPLACE) || (state == `URREQ && !uncache_read_stall);
assign rd_type = (state == `URREQ) ? 1'b0 : 1'b1;
assign rd_addr = (state == `URREQ && uncache_way == 1'b0) ? {rb_tag1, rb_index1, rb_offset1} :
                 (state == `URREQ && uncache_way == 1'b1) ? {rb_tag2, rb_index2, rb_offset2} : 
                 rb_valid[0] ? {rb_tag1, rb_index1, 4'b0} : {rb_tag2, rb_index2, 4'b0};
assign rd_size = (state == `URREQ && uncache_way == 1'b0) ? {1'b0, rb_size1} :
                 (state == `URREQ && uncache_way == 1'b1) ? {1'b0, rb_size2} : 3'd2;

// Main FSM
reg  [8:0] state;
reg  [8:0] next_state;

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
		if (valid1 && uncache1 && addr_ok1) begin
			if (op1 == 1'b0) begin
                next_state = `URREQ;
            end
            else begin
                next_state = `UWREQ;
            end
		end
        else if (valid2 && uncache2 && addr_ok2) begin
			if (op2 == 1'b0) begin
                next_state = `URREQ;
            end
            else begin
                next_state = `UWREQ;
            end
		end
        else if (_1_cache_req && addr_ok1 || _2_cache_req && addr_ok2) begin
			next_state = `LOOKUP;
		end
		else begin
			next_state = `IDLE;
		end
	`LOOKUP:
        if (cache_hit && (_1_cache_req && addr_ok1 || _2_cache_req && addr_ok2)) begin
			next_state = `LOOKUP;
		end
        else if (cache_hit && (valid1 && uncache1 && addr_ok1)) begin
			if (op1 == 1'b0) begin
                next_state = `URREQ;
            end
            else begin
                next_state = `UWREQ;
            end
		end
        else if (cache_hit && (valid2 && uncache2 && addr_ok2)) begin
			if (op2 == 1'b0) begin
                next_state = `URREQ;
            end
            else begin
                next_state = `UWREQ;
            end
		end
        else if (cache_hit && !(valid1 && addr_ok1) && !(valid2 && addr_ok2)) begin
			next_state = `IDLE;
		end
		else begin
			next_state = `MISS;
		end
    `MISS:
        if (!write_back) begin
			next_state = `REPLACE;
		end
        else if (wr_rdy && wr_req) begin
            next_state = `REPLACE;
        end
		else begin
			next_state = `MISS;
		end
    `REPLACE:
        if (rd_rdy && rd_req) begin
            next_state = `REFILL;
        end
		else begin
			next_state = `REPLACE;
		end
    `REFILL:
        if (ret_valid) begin
            next_state = `IDLE;
        end
        else begin
            next_state = `REFILL;
        end
    `URREQ:
        if (rd_rdy && rd_req) begin
            next_state = `URRESP;
        end
        else begin
            next_state = `URREQ;
        end
    `URRESP:
        if (ret_valid) begin
            next_state = `IDLE;
        end
        else begin
            next_state = `URRESP;
        end
    `UWREQ:
        if (wr_rdy && wr_req) begin
            next_state = `UWRESP;
        end
        else begin
            next_state = `UWREQ;
        end
    `UWRESP:
        if (uncache_write_go) begin
            next_state = `IDLE;
        end
        else begin
            next_state = `UWRESP;
        end
	default:
		next_state = `IDLE;
	endcase
end

// Write Buffer
reg          wb_hit_way;
reg  [  7:0] wb_index;
reg  [  3:0] wb_offset1;
reg  [  3:0] wb_wstrb1;
reg  [ 31:0] wb_wdata1;
reg  [  3:0] wb_offset2;
reg  [  3:0] wb_wstrb2;
reg  [ 31:0] wb_wdata2;
reg  [  1:0] wb_valid;

always @(posedge clk) begin
    if ((state == `LOOKUP) && (_1_cache_hit && rb_op1 == 1'b1 && rb_valid[0] || _2_cache_hit && rb_op2 == 1'b1 && rb_valid[1])) begin
        if(rb_valid[0]) begin
            wb_index   <= rb_index1;
        end
        else if(rb_valid[1]) begin
            wb_index   <= rb_index2;
        end
        wb_hit_way <= way1_hit ? 1'b1 : 1'b0;
        wb_offset1 <= rb_offset1;
        wb_wstrb1  <= rb_wstrb1;
        wb_wdata1  <= rb_wdata1;
        wb_offset2 <= rb_offset2;
        wb_wstrb2  <= rb_wstrb2;
        wb_wdata2  <= rb_wdata2;
    end
end
always @(posedge clk) begin
    if(resetn) begin
        wb_valid <= 2'b00;
    end
    else if ((state == `LOOKUP) && _1_cache_hit && (rb_op1 == 1'b1) && _2_cache_hit && (rb_op2 == 1'b1)) begin
        wb_valid <= 2'b11;
    end
    else if ((state == `LOOKUP) && _1_cache_hit && (rb_op1 == 1'b1)) begin
        wb_valid <= 2'b01;
    end
    else if ((state == `LOOKUP) && _2_cache_hit && (rb_op2 == 1'b1)) begin
        wb_valid <= 2'b10;
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
		if ((state == `LOOKUP) && _1_cache_hit && (rb_op1 == 1'b1)) begin
			next_wstate = `WRITE;
		end
        else if ((state == `LOOKUP) && _2_cache_hit && (rb_op2 == 1'b1)) begin
			next_wstate = `WRITE;
		end
		else begin
			next_wstate = `WIDLE;
		end
	`WRITE:
        if ((state == `LOOKUP) && _1_cache_hit && (rb_op1 == 1'b1)) begin
			next_wstate = `WRITE;
		end
        else if ((state == `LOOKUP) && _2_cache_hit && (rb_op2 == 1'b1)) begin
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
