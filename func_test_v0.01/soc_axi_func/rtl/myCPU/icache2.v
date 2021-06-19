`define  IDLE    6'b000001
`define  LOOKUP  6'b000010
`define  REPLACE 6'b000100
`define  REFILL  6'b001000
`define  UREQ    6'b010000
`define  URESP   6'b100000

module icache2(
    input           clk,
    input           resetn,
    // Cache and CPU
    input           valid,
    input           uncache,
    input  [ 19:0]  tag,
    input  [  7:0]  index,
    input  [  3:0]  offset,
    output          addr_ok,
    output          data_ok,
    output [ 127:0] rdata,
    output [   1:0] rnum,
    // Cache and AXI
    output          rd_req,
    output          rd_type,
    output [ 31:0]  rd_addr,
    input           rd_rdy,
    input           ret_valid,
    input  [127:0]  ret_data
);

// RAM
wire        tag_way0_en;
wire        tag_way1_en;
wire        tag_way2_en;
wire        tag_way3_en;
wire        tag_way0_we;
wire        tag_way1_we;
wire        tag_way2_we;
wire        tag_way3_we;
wire [ 7:0] tag_addr;
wire [19:0] tag_way0_din;
wire [19:0] tag_way1_din;
wire [19:0] tag_way2_din;
wire [19:0] tag_way3_din;
wire [19:0] tag_way0_dout;
wire [19:0] tag_way1_dout;
wire [19:0] tag_way2_dout;
wire [19:0] tag_way3_dout;

wire        data_way0_bank0_en;
wire        data_way0_bank1_en;
wire        data_way0_bank2_en;
wire        data_way0_bank3_en;
wire        data_way1_bank0_en;
wire        data_way1_bank1_en;
wire        data_way1_bank2_en;
wire        data_way1_bank3_en;
wire        data_way2_bank0_en;
wire        data_way2_bank1_en;
wire        data_way2_bank2_en;
wire        data_way2_bank3_en;
wire        data_way3_bank0_en;
wire        data_way3_bank1_en;
wire        data_way3_bank2_en;
wire        data_way3_bank3_en;
wire [ 3:0] data_way0_bank0_we;
wire [ 3:0] data_way0_bank1_we;
wire [ 3:0] data_way0_bank2_we;
wire [ 3:0] data_way0_bank3_we;
wire [ 3:0] data_way1_bank0_we;
wire [ 3:0] data_way1_bank1_we;
wire [ 3:0] data_way1_bank2_we;
wire [ 3:0] data_way1_bank3_we;
wire [ 3:0] data_way2_bank0_we;
wire [ 3:0] data_way2_bank1_we;
wire [ 3:0] data_way2_bank2_we;
wire [ 3:0] data_way2_bank3_we;
wire [ 3:0] data_way3_bank0_we;
wire [ 3:0] data_way3_bank1_we;
wire [ 3:0] data_way3_bank2_we;
wire [ 3:0] data_way3_bank3_we;
wire [ 7:0] data_addr;
wire [31:0] data_way0_bank0_din;
wire [31:0] data_way0_bank1_din;
wire [31:0] data_way0_bank2_din;
wire [31:0] data_way0_bank3_din;
wire [31:0] data_way1_bank0_din;
wire [31:0] data_way1_bank1_din;
wire [31:0] data_way1_bank2_din;
wire [31:0] data_way1_bank3_din;
wire [31:0] data_way2_bank0_din;
wire [31:0] data_way2_bank1_din;
wire [31:0] data_way2_bank2_din;
wire [31:0] data_way2_bank3_din;
wire [31:0] data_way3_bank0_din;
wire [31:0] data_way3_bank1_din;
wire [31:0] data_way3_bank2_din;
wire [31:0] data_way3_bank3_din;
wire [31:0] data_way0_bank0_dout;
wire [31:0] data_way0_bank1_dout;
wire [31:0] data_way0_bank2_dout;
wire [31:0] data_way0_bank3_dout;
wire [31:0] data_way1_bank0_dout;
wire [31:0] data_way1_bank1_dout;
wire [31:0] data_way1_bank2_dout;
wire [31:0] data_way1_bank3_dout;
wire [31:0] data_way2_bank0_dout;
wire [31:0] data_way2_bank1_dout;
wire [31:0] data_way2_bank2_dout;
wire [31:0] data_way2_bank3_dout;
wire [31:0] data_way3_bank0_dout;
wire [31:0] data_way3_bank1_dout;
wire [31:0] data_way3_bank2_dout;
wire [31:0] data_way3_bank3_dout;

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
Tag_RAM Tag_RAM_Way2(
    .clka   (clk          ),
    .addra  (tag_addr     ),
    .ena    (tag_way2_en  ),
    .wea    (tag_way2_we  ),
    .dina   (tag_way2_din ),
    .douta  (tag_way2_dout)
);
Tag_RAM Tag_RAM_Way3(
    .clka   (clk          ),
    .addra  (tag_addr     ),
    .ena    (tag_way3_en  ),
    .wea    (tag_way3_we  ),
    .dina   (tag_way3_din ),
    .douta  (tag_way3_dout)
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
Data_RAM Data_RAM_Way2_Bank0(
    .clka   (clk                 ),
    .addra  (data_addr           ),
    .ena    (data_way2_bank0_en  ),
    .wea    (data_way2_bank0_we  ),
    .dina   (data_way2_bank0_din ),
    .douta  (data_way2_bank0_dout)
);
Data_RAM Data_RAM_Way2_Bank1(
    .clka   (clk                 ),
    .addra  (data_addr           ),
    .ena    (data_way2_bank1_en  ),
    .wea    (data_way2_bank1_we  ),
    .dina   (data_way2_bank1_din ),
    .douta  (data_way2_bank1_dout)
);
Data_RAM Data_RAM_Way2_Bank2(
    .clka   (clk                 ),
    .addra  (data_addr           ),
    .ena    (data_way2_bank2_en  ),
    .wea    (data_way2_bank2_we  ),
    .dina   (data_way2_bank2_din ),
    .douta  (data_way2_bank2_dout)
);
Data_RAM Data_RAM_Way2_Bank3(
    .clka   (clk                 ),
    .addra  (data_addr           ),
    .ena    (data_way2_bank3_en  ),
    .wea    (data_way2_bank3_we  ),
    .dina   (data_way2_bank3_din ),
    .douta  (data_way2_bank3_dout)
);
Data_RAM Data_RAM_Way3_Bank0(
    .clka   (clk                 ),
    .addra  (data_addr           ),
    .ena    (data_way3_bank0_en  ),
    .wea    (data_way3_bank0_we  ),
    .dina   (data_way3_bank0_din ),
    .douta  (data_way3_bank0_dout)
);
Data_RAM Data_RAM_Way3_Bank1(
    .clka   (clk                 ),
    .addra  (data_addr           ),
    .ena    (data_way3_bank1_en  ),
    .wea    (data_way3_bank1_we  ),
    .dina   (data_way3_bank1_din ),
    .douta  (data_way3_bank1_dout)
);
Data_RAM Data_RAM_Way3_Bank2(
    .clka   (clk                 ),
    .addra  (data_addr           ),
    .ena    (data_way3_bank2_en  ),
    .wea    (data_way3_bank2_we  ),
    .dina   (data_way3_bank2_din ),
    .douta  (data_way3_bank2_dout)
);
Data_RAM Data_RAM_Way3_Bank3(
    .clka   (clk                 ),
    .addra  (data_addr           ),
    .ena    (data_way3_bank3_en  ),
    .wea    (data_way3_bank3_we  ),
    .dina   (data_way3_bank3_din ),
    .douta  (data_way3_bank3_dout)
);

reg V_Way0 [255:0];
reg V_Way1 [255:0];
reg V_Way2 [255:0];
reg V_Way3 [255:0];

// RAM Port
assign tag_way0_en = (valid && !uncache && addr_ok) || 
                     (state == `REFILL && ret_valid && rp_way == 2'b00);
assign tag_way1_en = (valid && !uncache && addr_ok) || 
                     (state == `REFILL && ret_valid && rp_way == 2'b01);
assign tag_way2_en = (valid && !uncache && addr_ok) || 
                     (state == `REFILL && ret_valid && rp_way == 2'b10);
assign tag_way3_en = (valid && !uncache && addr_ok) || 
                     (state == `REFILL && ret_valid && rp_way == 2'b11);
assign tag_way0_we = (state == `REFILL && ret_valid && rp_way == 2'b00);
assign tag_way1_we = (state == `REFILL && ret_valid && rp_way == 2'b01);
assign tag_way2_we = (state == `REFILL && ret_valid && rp_way == 2'b10);
assign tag_way3_we = (state == `REFILL && ret_valid && rp_way == 2'b11);
assign tag_way0_din = rb_tag;
assign tag_way1_din = rb_tag;
assign tag_way2_din = rb_tag;
assign tag_way3_din = rb_tag;
assign tag_addr = (valid && !uncache && addr_ok)  ? index : 
                   (state == `REFILL && ret_valid) ? rb_index : 8'b0;

assign data_way0_bank0_en = (valid && !uncache && addr_ok) ||
                            (state == `REFILL && ret_valid && rp_way == 2'b00);
assign data_way0_bank1_en = (valid && !uncache && addr_ok) ||
                            (state == `REFILL && ret_valid && rp_way == 2'b00);
assign data_way0_bank2_en = (valid && !uncache && addr_ok) ||
                            (state == `REFILL && ret_valid && rp_way == 2'b00);
assign data_way0_bank3_en = (valid && !uncache && addr_ok) ||
                            (state == `REFILL && ret_valid && rp_way == 2'b00);
assign data_way1_bank0_en = (valid && !uncache && addr_ok) ||
                            (state == `REFILL && ret_valid && rp_way == 2'b01);
assign data_way1_bank1_en = (valid && !uncache && addr_ok) ||
                            (state == `REFILL && ret_valid && rp_way == 2'b01);
assign data_way1_bank2_en = (valid && !uncache && addr_ok) ||
                            (state == `REFILL && ret_valid && rp_way == 2'b01);
assign data_way1_bank3_en = (valid && !uncache && addr_ok) ||
                            (state == `REFILL && ret_valid && rp_way == 2'b01);
assign data_way2_bank0_en = (valid && !uncache && addr_ok) ||
                            (state == `REFILL && ret_valid && rp_way == 2'b10);
assign data_way2_bank1_en = (valid && !uncache && addr_ok) ||
                            (state == `REFILL && ret_valid && rp_way == 2'b10);
assign data_way2_bank2_en = (valid && !uncache && addr_ok) ||
                            (state == `REFILL && ret_valid && rp_way == 2'b10);
assign data_way2_bank3_en = (valid && !uncache && addr_ok) ||
                            (state == `REFILL && ret_valid && rp_way == 2'b10);
assign data_way3_bank0_en = (valid && !uncache && addr_ok) ||
                            (state == `REFILL && ret_valid && rp_way == 2'b11);
assign data_way3_bank1_en = (valid && !uncache && addr_ok) ||
                            (state == `REFILL && ret_valid && rp_way == 2'b11);
assign data_way3_bank2_en = (valid && !uncache && addr_ok) ||
                            (state == `REFILL && ret_valid && rp_way == 2'b11);
assign data_way3_bank3_en = (valid && !uncache && addr_ok) ||
                            (state == `REFILL && ret_valid && rp_way == 2'b11);
assign data_way0_bank0_we = (state == `REFILL && ret_valid && rp_way == 2'b00) ? 4'b1111 : 4'b0000;
assign data_way0_bank1_we = (state == `REFILL && ret_valid && rp_way == 2'b00) ? 4'b1111 : 4'b0000;
assign data_way0_bank2_we = (state == `REFILL && ret_valid && rp_way == 2'b00) ? 4'b1111 : 4'b0000;
assign data_way0_bank3_we = (state == `REFILL && ret_valid && rp_way == 2'b00) ? 4'b1111 : 4'b0000;
assign data_way1_bank0_we = (state == `REFILL && ret_valid && rp_way == 2'b01) ? 4'b1111 : 4'b0000;
assign data_way1_bank1_we = (state == `REFILL && ret_valid && rp_way == 2'b01) ? 4'b1111 : 4'b0000;
assign data_way1_bank2_we = (state == `REFILL && ret_valid && rp_way == 2'b01) ? 4'b1111 : 4'b0000;
assign data_way1_bank3_we = (state == `REFILL && ret_valid && rp_way == 2'b01) ? 4'b1111 : 4'b0000;
assign data_way2_bank0_we = (state == `REFILL && ret_valid && rp_way == 2'b10) ? 4'b1111 : 4'b0000;
assign data_way2_bank1_we = (state == `REFILL && ret_valid && rp_way == 2'b10) ? 4'b1111 : 4'b0000;
assign data_way2_bank2_we = (state == `REFILL && ret_valid && rp_way == 2'b10) ? 4'b1111 : 4'b0000;
assign data_way2_bank3_we = (state == `REFILL && ret_valid && rp_way == 2'b10) ? 4'b1111 : 4'b0000;
assign data_way3_bank0_we = (state == `REFILL && ret_valid && rp_way == 2'b11) ? 4'b1111 : 4'b0000;
assign data_way3_bank1_we = (state == `REFILL && ret_valid && rp_way == 2'b11) ? 4'b1111 : 4'b0000;
assign data_way3_bank2_we = (state == `REFILL && ret_valid && rp_way == 2'b11) ? 4'b1111 : 4'b0000;
assign data_way3_bank3_we = (state == `REFILL && ret_valid && rp_way == 2'b11) ? 4'b1111 : 4'b0000;
assign data_way0_bank0_din = rd_way_data_bank0;
assign data_way0_bank1_din = rd_way_data_bank1;
assign data_way0_bank2_din = rd_way_data_bank2;
assign data_way0_bank3_din = rd_way_data_bank3;
assign data_way1_bank0_din = rd_way_data_bank0;
assign data_way1_bank1_din = rd_way_data_bank1;
assign data_way1_bank2_din = rd_way_data_bank2;
assign data_way1_bank3_din = rd_way_data_bank3;
assign data_way2_bank0_din = rd_way_data_bank0;
assign data_way2_bank1_din = rd_way_data_bank1;
assign data_way2_bank2_din = rd_way_data_bank2;
assign data_way2_bank3_din = rd_way_data_bank3;
assign data_way3_bank0_din = rd_way_data_bank0;
assign data_way3_bank1_din = rd_way_data_bank1;
assign data_way3_bank2_din = rd_way_data_bank2;
assign data_way3_bank3_din = rd_way_data_bank3;
assign data_addr = (valid && !uncache && addr_ok)  ? index : 
                   (state == `REFILL && ret_valid) ? rb_index : 8'b0;

genvar i0;
generate for (i0=0; i0<256; i0=i0+1) begin :gen_for_V_Way0
    always @(posedge clk) begin
        if (!resetn) begin
            V_Way0[i0] <= 1'b0;
        end
        else if (state == `REFILL && ret_valid && rp_way == 2'b00 && rb_index == i0) begin
            V_Way0[i0] <= 1'b1;
        end
    end
end endgenerate
genvar i1;
generate for (i1=0; i1<256; i1=i1+1) begin :gen_for_V_Way1
    always @(posedge clk) begin
        if (!resetn) begin
            V_Way1[i1] <= 1'b0;
        end
        else if (state == `REFILL && ret_valid && rp_way == 2'b01 && rb_index == i1) begin
            V_Way1[i1] <= 1'b1;
        end
    end
end endgenerate
genvar i2;
generate for (i2=0; i2<256; i2=i2+1) begin :gen_for_V_Way2
    always @(posedge clk) begin
        if (!resetn) begin
            V_Way2[i2] <= 1'b0;
        end
        else if (state == `REFILL && ret_valid && rp_way == 2'b10 && rb_index == i2) begin
            V_Way2[i2] <= 1'b1;
        end
    end
end endgenerate
genvar i3;
generate for (i3=0; i3<256; i3=i3+1) begin :gen_for_V_Way3
    always @(posedge clk) begin
        if (!resetn) begin
            V_Way3[i3] <= 1'b0;
        end
        else if (state == `REFILL && ret_valid && rp_way == 2'b11 && rb_index == i3) begin
            V_Way3[i3] <= 1'b1;
        end
    end
end endgenerate

// Request Buffer
reg  [ 19:0] rb_tag;
reg  [  7:0] rb_index;
reg  [  3:0] rb_offset;

wire         way0_v;
wire         way1_v;
wire         way2_v;
wire         way3_v;
wire [ 19:0] way0_tag;
wire [ 19:0] way1_tag;
wire [ 19:0] way2_tag;
wire [ 19:0] way3_tag;
wire [127:0] way0_data;
wire [127:0] way1_data;
wire [127:0] way2_data;
wire [127:0] way3_data;

always @(posedge clk) begin
    if (valid && addr_ok) begin
        rb_index   <= index;
        rb_tag     <= tag;
        rb_offset  <= offset;
    end
end

assign way0_v = V_Way0[rb_index];
assign way1_v = V_Way1[rb_index];
assign way2_v = V_Way2[rb_index];
assign way3_v = V_Way3[rb_index];
assign way0_tag = tag_way0_dout[19:0];
assign way1_tag = tag_way1_dout[19:0];
assign way2_tag = tag_way2_dout[19:0];
assign way3_tag = tag_way3_dout[19:0];
assign way0_data = {data_way0_bank3_dout, data_way0_bank2_dout, data_way0_bank1_dout, data_way0_bank0_dout};
assign way1_data = {data_way1_bank3_dout, data_way1_bank2_dout, data_way1_bank1_dout, data_way1_bank0_dout};
assign way2_data = {data_way2_bank3_dout, data_way2_bank2_dout, data_way2_bank1_dout, data_way2_bank0_dout};
assign way3_data = {data_way3_bank3_dout, data_way3_bank2_dout, data_way3_bank1_dout, data_way3_bank0_dout};

// Tag Compare
wire         way0_hit;
wire         way1_hit;
wire         way2_hit;
wire         way3_hit;
wire         cache_hit;

assign way0_hit = way0_v && (way0_tag == rb_tag);
assign way1_hit = way1_v && (way1_tag == rb_tag);
assign way2_hit = way2_v && (way2_tag == rb_tag);
assign way3_hit = way3_v && (way3_tag == rb_tag);
assign cache_hit = (way0_hit || way1_hit || way2_hit || way3_hit);

// Data Select
wire [127:0] load_res;
assign load_res = {128{way0_hit}} & way0_data |
                  {128{way1_hit}} & way1_data |
                  {128{way2_hit}} & way2_data |
                  {128{way3_hit}} & way3_data;

// PLRU
reg [255:0] way0_mru;
reg [255:0] way1_mru;
reg [255:0] way2_mru;
reg [255:0] way3_mru;
reg [1:0] rp_way;

genvar i;
generate for (i=0; i<256; i=i+1) begin :gen_for_mru
    always @(posedge clk) begin
        if (!resetn) begin
            way0_mru[i] <= 1'b0;
            way1_mru[i] <= 1'b0;
            way2_mru[i] <= 1'b0;
            way3_mru[i] <= 1'b0;
        end
        else if (state == `LOOKUP && way0_hit && rb_index == i) begin
            way0_mru[i] <= 1'b1;
            if(way1_mru[i] && way2_mru[i] && way3_mru[i]) begin
                way1_mru[i] <= 1'b0;
                way2_mru[i] <= 1'b0;
                way3_mru[i] <= 1'b0;
            end
        end
        else if (state == `LOOKUP && way1_hit && rb_index == i) begin
            way1_mru[i] <= 1'b1;
            if(way0_mru[i] && way2_mru[i] && way3_mru[i]) begin
                way0_mru[i] <= 1'b0;
                way2_mru[i] <= 1'b0;
                way3_mru[i] <= 1'b0;
            end
        end
        else if (state == `LOOKUP && way2_hit && rb_index == i) begin
            way2_mru[i] <= 1'b1;
            if(way0_mru[i] && way1_mru[i] && way3_mru[i]) begin
                way0_mru[i] <= 1'b0;
                way1_mru[i] <= 1'b0;
                way3_mru[i] <= 1'b0;
            end
        end
        else if (state == `LOOKUP && way3_hit && rb_index == i) begin
            way3_mru[i] <= 1'b1;
            if(way0_mru[i] && way1_mru[i] && way2_mru[i]) begin
                way0_mru[i] <= 1'b0;
                way1_mru[i] <= 1'b0;
                way2_mru[i] <= 1'b0;
            end
        end
        else if (state == `REPLACE && rp_way == 2'b00 && rb_index == i) begin
            way0_mru[i] <= 1'b1;
            if(way1_mru[i] && way2_mru[i] && way3_mru[i]) begin
                way1_mru[i] <= 1'b0;
                way2_mru[i] <= 1'b0;
                way3_mru[i] <= 1'b0;
            end
        end
        else if (state == `REPLACE && rp_way == 2'b01 && rb_index == i) begin
            way1_mru[i] <= 1'b1;
            if(way0_mru[i] && way2_mru[i] && way3_mru[i]) begin
                way0_mru[i] <= 1'b0;
                way2_mru[i] <= 1'b0;
                way3_mru[i] <= 1'b0;
            end
        end
        else if (state == `REPLACE && rp_way == 2'b10 && rb_index == i) begin
            way2_mru[i] <= 1'b1;
            if(way0_mru[i] && way1_mru[i] && way3_mru[i]) begin
                way0_mru[i] <= 1'b0;
                way1_mru[i] <= 1'b0;
                way3_mru[i] <= 1'b0;
            end
        end
        else if (state == `REPLACE && rp_way == 2'b11 && rb_index == i) begin
            way3_mru[i] <= 1'b1;
            if(way0_mru[i] && way1_mru[i] && way2_mru[i]) begin
                way0_mru[i] <= 1'b0;
                way1_mru[i] <= 1'b0;
                way2_mru[i] <= 1'b0;
            end
        end
    end
end endgenerate

always @(posedge clk) begin
    if (!resetn) begin
        rp_way <= 1'b0;
    end
    else if (state == `LOOKUP && !cache_hit) begin
        if(!way0_mru[rb_index]) begin
            rp_way <= 2'b00;
        end
        else if(!way1_mru[rb_index]) begin
            rp_way <= 2'b01;
        end
        else if(!way2_mru[rb_index]) begin
            rp_way <= 2'b10;
        end
        else if(!way3_mru[rb_index]) begin
            rp_way <= 2'b11;
        end
    end
end

// Miss Buffer
wire [ 31:0] rd_way_data_bank0;
wire [ 31:0] rd_way_data_bank1;
wire [ 31:0] rd_way_data_bank2;
wire [ 31:0] rd_way_data_bank3;

assign rd_way_data_bank0 = ret_data[ 31: 0];
assign rd_way_data_bank1 = ret_data[ 63:32];
assign rd_way_data_bank2 = ret_data[ 95:64];
assign rd_way_data_bank3 = ret_data[127:96];

// Output
assign addr_ok = ((state == `IDLE || (state == `LOOKUP && cache_hit)) && valid);
assign data_ok = (state == `LOOKUP) && cache_hit || 
                 (state == `REFILL) && ret_valid ||
                 (state == `URESP)  && ret_valid;
assign rdata = {128{(state == `LOOKUP) && cache_hit}} & (load_res >> (rb_offset << 5)) | 
               {128{(state == `REFILL) && ret_valid}} & (ret_data >> (rb_offset << 5)) | 
               {128{(state == `URESP)  && ret_valid}} & {96'b0, ret_data[31:0]}; 
assign rnum = (state == `URESP) ? 2'b0 : ~rb_offset;

assign rd_req  = (state == `UREQ) || (state == `REPLACE);
assign rd_type = (state == `UREQ) ? 1'b0 : 1'b1;
assign rd_addr = (state == `UREQ) ? {rb_tag, rb_index, rb_offset} : {rb_tag, rb_index, 4'b0};

// Main FSM
reg [5:0] state;
reg [5:0] next_state;

always @(posedge clk) begin
    if (!resetn) begin
        state <= `IDLE;
    end
    else begin
        state <= next_state;
    end
end
always @(*) begin
	case(state)
	`IDLE:
        if (valid && uncache && addr_ok) begin
            next_state = `UREQ;
        end
		else if (valid && !uncache && addr_ok) begin
			next_state = `LOOKUP;
		end
		else begin
			next_state = `IDLE;
		end
	`LOOKUP:
        if (cache_hit && (valid && !uncache && addr_ok)) begin
			next_state = `LOOKUP;
		end
        else if (cache_hit && (valid && uncache && addr_ok)) begin
			next_state = `UREQ;
		end
        else if (cache_hit && !(valid && addr_ok)) begin
			next_state = `IDLE;
		end
		else begin
			next_state = `REPLACE;
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
    `UREQ:
        if (rd_rdy && rd_req) begin
            next_state = `URESP;
        end
        else begin
            next_state = `UREQ;
        end
    `URESP:
        if (ret_valid) begin
            next_state = `IDLE;
        end
        else begin
            next_state = `URESP;
        end
	default:
		next_state = `IDLE;
	endcase
end

endmodule
