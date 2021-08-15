`define  IDLE    14'b00000000000001
`define  PRELOOK 14'b00000000000010
`define  LOOKUP  14'b00000000000100
`define  MISS    14'b00000000001000
`define  REPLACE 14'b00000000010000
`define  REFILL  14'b00000000100000
`define  URREQ   14'b00000001000000
`define  URRESP  14'b00000010000000
`define  UWREQ   14'b00000100000000
`define  UWRESP  14'b00001000000000
`define  ILOOK   14'b00010000000000
`define  IWB0    14'b00100000000000
`define  IWB1    14'b01000000000000
`define  ICLEAR  14'b10000000000000

`define  WIDLE   2'b01
`define  WRITE   2'b10

module dcache2(
    input           clk,
    input           resetn,
    // Cache and CPU Interface1
    input           valid1,
    input           op1,
    input           uncache1,
    input  [ 19:0]  tag1,
    input  [  6:0]  index1,
    input  [  4:0]  offset1,
    input  [  1:0]  size1,
    input  [  3:0]  wstrb1,
    input  [ 31:0]  wdata1,
    output          addr_ok1,
    output          data_ok1,
    output [ 31:0]  rdata1,
    // Cache and CPU Interface2
    input           valid2,
    input           op2,
    input           uncache2,
    input  [ 19:0]  tag2,
    input  [  6:0]  index2,
    input  [  4:0]  offset2,
    input  [  1:0]  size2,
    input  [  3:0]  wstrb2,
    input  [ 31:0]  wdata2,
    output          addr_ok2,
    output          data_ok2,
    output [ 31:0]  rdata2,
    // Cache and CPU Inst
    input           cache_inst_valid,
    input  [  2:0]  cache_inst_op,
    input  [ 31:0]  cache_inst_addr,
    input  [ 20:0]  cache_inst_tag,
    input           cache_inst_v,
    input           cache_inst_d,
    output          cache_inst_ok,
    // Cache and AXI
    output          rd_req,
    output          rd_type,
    output [ 31:0]  rd_addr,
    output [  2:0]  rd_size,
    input           rd_rdy,
    input           ret_valid,
    input  [255:0]  ret_data,

    output          wr_req,
    output          wr_type,
    output [ 31:0]  wr_addr,
    output [  2:0]  wr_size,
    output [  3:0]  wr_wstrb,
    output [255:0]  wr_data,
    input           wr_rdy,
    input           wr_ok
);

// RAM
wire        tag_way0_en;
wire        tag_way1_en;
wire        tag_way0_we;
wire        tag_way1_we;
wire [ 6:0] tag_addr;
wire [19:0] tag_way0_din;
wire [19:0] tag_way1_din;
wire [19:0] tag_way0_dout;
wire [19:0] tag_way1_dout;

wire [ 3:0] data_way0_bank0_we;
wire [ 3:0] data_way0_bank1_we;
wire [ 3:0] data_way0_bank2_we;
wire [ 3:0] data_way0_bank3_we;
wire [ 3:0] data_way0_bank4_we;
wire [ 3:0] data_way0_bank5_we;
wire [ 3:0] data_way0_bank6_we;
wire [ 3:0] data_way0_bank7_we;
wire [ 3:0] data_way1_bank0_we;
wire [ 3:0] data_way1_bank1_we;
wire [ 3:0] data_way1_bank2_we;
wire [ 3:0] data_way1_bank3_we;
wire [ 3:0] data_way1_bank4_we;
wire [ 3:0] data_way1_bank5_we;
wire [ 3:0] data_way1_bank6_we;
wire [ 3:0] data_way1_bank7_we;

wire [31:0] data_bank0_din;
wire [31:0] data_bank1_din;
wire [31:0] data_bank2_din;
wire [31:0] data_bank3_din;
wire [31:0] data_bank4_din;
wire [31:0] data_bank5_din;
wire [31:0] data_bank6_din;
wire [31:0] data_bank7_din;

wire         data_way0_en;
wire         data_way1_en;
wire [ 31:0] data_way0_we;
wire [ 31:0] data_way1_we;
wire [  6:0] data_addr;
wire [255:0] data_din;
wire [255:0] data_way0_dout;
wire [255:0] data_way1_dout;

Tag_RAM_8 Tag_RAM_Way0(
    .clka   (clk          ),
    .addra  (tag_addr     ),
    .ena    (tag_way0_en  ),
    .wea    (tag_way0_we  ),
    .dina   (tag_way0_din ),
    .douta  (tag_way0_dout)
);
Tag_RAM_8 Tag_RAM_Way1(
    .clka   (clk          ),
    .addra  (tag_addr     ),
    .ena    (tag_way1_en  ),
    .wea    (tag_way1_we  ),
    .dina   (tag_way1_din ),
    .douta  (tag_way1_dout)
);
Data_RAM_8 Data_RAM_Way0(
    .clka   (clk           ),
    .addra  (data_addr     ),
    .ena    (data_way0_en  ),
    .wea    (data_way0_we  ),
    .dina   (data_din      ),
    .douta  (data_way0_dout)
);
Data_RAM_8 Data_RAM_Way1(
    .clka   (clk           ),
    .addra  (data_addr     ),
    .ena    (data_way1_en  ),
    .wea    (data_way1_we  ),
    .dina   (data_din      ),
    .douta  (data_way1_dout)
);

reg D_Way0 [127:0];
reg D_Way1 [127:0];
reg V_Way0 [127:0];
reg V_Way1 [127:0];

// RAM Port
assign tag_way0_en = cache_inst_valid ||
                     (valid1 && !uncache1 && addr_ok1) ||
                     (valid2 && !uncache2 && addr_ok2) ||
                     (data_ok1_raw && dual_req && !rb_uncache2 && wstate[0]) ||
                     (state[1] && wstate[0]) ||
                     (state[5] && ret_valid && !rp_way);
assign tag_way1_en = cache_inst_valid ||
                     (valid1 && !uncache1 && addr_ok1) ||
                     (valid2 && !uncache2 && addr_ok2) ||
                     (data_ok1_raw && dual_req && !rb_uncache2 && wstate[0]) ||
                     (state[1] && wstate[0]) ||
                     (state[5] && ret_valid &&  rp_way);
assign tag_way0_we = (state[5] && ret_valid && !rp_way) ||
                     state[10] && cache_inst_op == 3'b010 && !cache_inst_addr[12];
assign tag_way1_we = (state[5] && ret_valid &&  rp_way) ||
                     state[10] && cache_inst_op == 3'b010 &&  cache_inst_addr[12];
assign tag_way0_din = state[10] ? cache_inst_tag : 
                      rb_valid[0] ? rb_tag1 : rb_tag2;
assign tag_way1_din = state[10] ? cache_inst_tag : 
                      rb_valid[0] ? rb_tag1 : rb_tag2;
assign tag_addr = cache_inst_valid                   ? cache_inst_addr[11:5] :
                  (valid1 && !uncache1 && addr_ok1)  ? index1 : 
                  (valid2 && !uncache2 && addr_ok2)  ? index2 : 
                  (state[5] && ret_valid && rb_valid[0]) ? rb_index1 : rb_index2;

assign data_way0_en = cache_inst_valid ||
                      (valid1 && !uncache1 && addr_ok1) || 
                      (valid2 && !uncache2 && addr_ok2) || 
                      (data_ok1_raw && dual_req && !rb_uncache2 && wstate[0]) ||
                      (state[1] && wstate[0]) ||
                      (state[5] && ret_valid && !rp_way) ||
                      (wstate[1] && !wb_hit_way);
assign data_way1_en = cache_inst_valid ||
                      (valid1 && !uncache1 && addr_ok1) || 
                      (valid2 && !uncache2 && addr_ok2) || 
                      (data_ok1_raw && dual_req && !rb_uncache2 && wstate[0]) ||
                      (state[1] && wstate[0]) ||
                      (state[5] && ret_valid &&  rp_way) ||
                      (wstate[1] && wb_hit_way);

assign data_way0_bank0_we = (wstate[1] && !wb_hit_way) ? ({4{wb_valid[1] & (wb_offset2[4:2] == 3'b000)}} & wb_wstrb2) |
                                                         ({4{wb_valid[0] & (wb_offset1[4:2] == 3'b000)}} & wb_wstrb1) :
                            (state[5] && ret_valid && !rp_way) ? 4'b1111 : 4'b0000;
assign data_way0_bank1_we = (wstate[1] && !wb_hit_way) ? ({4{wb_valid[1] & (wb_offset2[4:2] == 3'b001)}} & wb_wstrb2) |
                                                         ({4{wb_valid[0] & (wb_offset1[4:2] == 3'b001)}} & wb_wstrb1) :
                            (state[5] && ret_valid && !rp_way) ? 4'b1111 : 4'b0000;
assign data_way0_bank2_we = (wstate[1] && !wb_hit_way) ? ({4{wb_valid[1] & (wb_offset2[4:2] == 3'b010)}} & wb_wstrb2) |
                                                         ({4{wb_valid[0] & (wb_offset1[4:2] == 3'b010)}} & wb_wstrb1) :
                            (state[5] && ret_valid && !rp_way) ? 4'b1111 : 4'b0000;
assign data_way0_bank3_we = (wstate[1] && !wb_hit_way) ? ({4{wb_valid[1] & (wb_offset2[4:2] == 3'b011)}} & wb_wstrb2) |
                                                         ({4{wb_valid[0] & (wb_offset1[4:2] == 3'b011)}} & wb_wstrb1) :
                            (state[5] && ret_valid && !rp_way) ? 4'b1111 : 4'b0000;
assign data_way0_bank4_we = (wstate[1] && !wb_hit_way) ? ({4{wb_valid[1] & (wb_offset2[4:2] == 3'b100)}} & wb_wstrb2) |
                                                         ({4{wb_valid[0] & (wb_offset1[4:2] == 3'b100)}} & wb_wstrb1) :
                            (state[5] && ret_valid && !rp_way) ? 4'b1111 : 4'b0000;
assign data_way0_bank5_we = (wstate[1] && !wb_hit_way) ? ({4{wb_valid[1] & (wb_offset2[4:2] == 3'b101)}} & wb_wstrb2) |
                                                         ({4{wb_valid[0] & (wb_offset1[4:2] == 3'b101)}} & wb_wstrb1) :
                            (state[5] && ret_valid && !rp_way) ? 4'b1111 : 4'b0000;
assign data_way0_bank6_we = (wstate[1] && !wb_hit_way) ? ({4{wb_valid[1] & (wb_offset2[4:2] == 3'b110)}} & wb_wstrb2) |
                                                         ({4{wb_valid[0] & (wb_offset1[4:2] == 3'b110)}} & wb_wstrb1) :
                            (state[5] && ret_valid && !rp_way) ? 4'b1111 : 4'b0000;
assign data_way0_bank7_we = (wstate[1] && !wb_hit_way) ? ({4{wb_valid[1] & (wb_offset2[4:2] == 3'b111)}} & wb_wstrb2) |
                                                         ({4{wb_valid[0] & (wb_offset1[4:2] == 3'b111)}} & wb_wstrb1) :
                            (state[5] && ret_valid && !rp_way) ? 4'b1111 : 4'b0000;
assign data_way1_bank0_we = (wstate[1] &&  wb_hit_way) ? ({4{wb_valid[1] & (wb_offset2[4:2] == 3'b000)}} & wb_wstrb2) |
                                                         ({4{wb_valid[0] & (wb_offset1[4:2] == 3'b000)}} & wb_wstrb1) :
                            (state[5] && ret_valid &&  rp_way) ? 4'b1111 : 4'b0000;
assign data_way1_bank1_we = (wstate[1] &&  wb_hit_way) ? ({4{wb_valid[1] & (wb_offset2[4:2] == 3'b001)}} & wb_wstrb2) |
                                                         ({4{wb_valid[0] & (wb_offset1[4:2] == 3'b001)}} & wb_wstrb1) :
                            (state[5] && ret_valid &&  rp_way) ? 4'b1111 : 4'b0000;
assign data_way1_bank2_we = (wstate[1] &&  wb_hit_way) ? ({4{wb_valid[1] & (wb_offset2[4:2] == 3'b010)}} & wb_wstrb2) |
                                                         ({4{wb_valid[0] & (wb_offset1[4:2] == 3'b010)}} & wb_wstrb1) :
                            (state[5] && ret_valid &&  rp_way) ? 4'b1111 : 4'b0000;
assign data_way1_bank3_we = (wstate[1] &&  wb_hit_way) ? ({4{wb_valid[1] & (wb_offset2[4:2] == 3'b011)}} & wb_wstrb2) |
                                                         ({4{wb_valid[0] & (wb_offset1[4:2] == 3'b011)}} & wb_wstrb1) :
                            (state[5] && ret_valid &&  rp_way) ? 4'b1111 : 4'b0000;
assign data_way1_bank4_we = (wstate[1] &&  wb_hit_way) ? ({4{wb_valid[1] & (wb_offset2[4:2] == 3'b100)}} & wb_wstrb2) |
                                                         ({4{wb_valid[0] & (wb_offset1[4:2] == 3'b100)}} & wb_wstrb1) :
                            (state[5] && ret_valid &&  rp_way) ? 4'b1111 : 4'b0000;
assign data_way1_bank5_we = (wstate[1] &&  wb_hit_way) ? ({4{wb_valid[1] & (wb_offset2[4:2] == 3'b101)}} & wb_wstrb2) |
                                                         ({4{wb_valid[0] & (wb_offset1[4:2] == 3'b101)}} & wb_wstrb1) :
                            (state[5] && ret_valid &&  rp_way) ? 4'b1111 : 4'b0000;
assign data_way1_bank6_we = (wstate[1] &&  wb_hit_way) ? ({4{wb_valid[1] & (wb_offset2[4:2] == 3'b110)}} & wb_wstrb2) |
                                                         ({4{wb_valid[0] & (wb_offset1[4:2] == 3'b110)}} & wb_wstrb1) :
                            (state[5] && ret_valid &&  rp_way) ? 4'b1111 : 4'b0000;
assign data_way1_bank7_we = (wstate[1] &&  wb_hit_way) ? ({4{wb_valid[1] & (wb_offset2[4:2] == 3'b111)}} & wb_wstrb2) |
                                                         ({4{wb_valid[0] & (wb_offset1[4:2] == 3'b111)}} & wb_wstrb1) :
                            (state[5] && ret_valid &&  rp_way) ? 4'b1111 : 4'b0000;
assign data_way0_we = {data_way0_bank7_we, data_way0_bank6_we, data_way0_bank5_we, data_way0_bank4_we, 
                       data_way0_bank3_we, data_way0_bank2_we, data_way0_bank1_we, data_way0_bank0_we};
assign data_way1_we = {data_way1_bank7_we, data_way1_bank6_we, data_way1_bank5_we, data_way1_bank4_we, 
                       data_way1_bank3_we, data_way1_bank2_we, data_way1_bank1_we, data_way1_bank0_we};

assign data_bank0_din = wstate[1] ?
                        {(wb_valid[1] & wb_wstrb2[3] & (wb_offset2[4:2] == 3'b000)) ? wb_wdata2[31:24] : wb_wdata1[31:24],
                         (wb_valid[1] & wb_wstrb2[2] & (wb_offset2[4:2] == 3'b000)) ? wb_wdata2[23:16] : wb_wdata1[23:16],
                         (wb_valid[1] & wb_wstrb2[1] & (wb_offset2[4:2] == 3'b000)) ? wb_wdata2[15: 8] : wb_wdata1[15: 8],
                         (wb_valid[1] & wb_wstrb2[0] & (wb_offset2[4:2] == 3'b000)) ? wb_wdata2[ 7: 0] : wb_wdata1[ 7: 0]}
                        : rd_way_wdata_bank0;
assign data_bank1_din = wstate[1] ?
                        {(wb_valid[1] & wb_wstrb2[3] & (wb_offset2[4:2] == 3'b001)) ? wb_wdata2[31:24] : wb_wdata1[31:24],
                         (wb_valid[1] & wb_wstrb2[2] & (wb_offset2[4:2] == 3'b001)) ? wb_wdata2[23:16] : wb_wdata1[23:16],
                         (wb_valid[1] & wb_wstrb2[1] & (wb_offset2[4:2] == 3'b001)) ? wb_wdata2[15: 8] : wb_wdata1[15: 8],
                         (wb_valid[1] & wb_wstrb2[0] & (wb_offset2[4:2] == 3'b001)) ? wb_wdata2[ 7: 0] : wb_wdata1[ 7: 0]}
                        : rd_way_wdata_bank1;
assign data_bank2_din = wstate[1] ?
                        {(wb_valid[1] & wb_wstrb2[3] & (wb_offset2[4:2] == 3'b010)) ? wb_wdata2[31:24] : wb_wdata1[31:24],
                         (wb_valid[1] & wb_wstrb2[2] & (wb_offset2[4:2] == 3'b010)) ? wb_wdata2[23:16] : wb_wdata1[23:16],
                         (wb_valid[1] & wb_wstrb2[1] & (wb_offset2[4:2] == 3'b010)) ? wb_wdata2[15: 8] : wb_wdata1[15: 8],
                         (wb_valid[1] & wb_wstrb2[0] & (wb_offset2[4:2] == 3'b010)) ? wb_wdata2[ 7: 0] : wb_wdata1[ 7: 0]}
                        : rd_way_wdata_bank2;
assign data_bank3_din = wstate[1] ?
                        {(wb_valid[1] & wb_wstrb2[3] & (wb_offset2[4:2] == 3'b011)) ? wb_wdata2[31:24] : wb_wdata1[31:24],
                         (wb_valid[1] & wb_wstrb2[2] & (wb_offset2[4:2] == 3'b011)) ? wb_wdata2[23:16] : wb_wdata1[23:16],
                         (wb_valid[1] & wb_wstrb2[1] & (wb_offset2[4:2] == 3'b011)) ? wb_wdata2[15: 8] : wb_wdata1[15: 8],
                         (wb_valid[1] & wb_wstrb2[0] & (wb_offset2[4:2] == 3'b011)) ? wb_wdata2[ 7: 0] : wb_wdata1[ 7: 0]}
                        : rd_way_wdata_bank3;
assign data_bank4_din = wstate[1] ?
                        {(wb_valid[1] & wb_wstrb2[3] & (wb_offset2[4:2] == 3'b100)) ? wb_wdata2[31:24] : wb_wdata1[31:24],
                         (wb_valid[1] & wb_wstrb2[2] & (wb_offset2[4:2] == 3'b100)) ? wb_wdata2[23:16] : wb_wdata1[23:16],
                         (wb_valid[1] & wb_wstrb2[1] & (wb_offset2[4:2] == 3'b100)) ? wb_wdata2[15: 8] : wb_wdata1[15: 8],
                         (wb_valid[1] & wb_wstrb2[0] & (wb_offset2[4:2] == 3'b100)) ? wb_wdata2[ 7: 0] : wb_wdata1[ 7: 0]}
                        : rd_way_wdata_bank4;
assign data_bank5_din = wstate[1] ?
                        {(wb_valid[1] & wb_wstrb2[3] & (wb_offset2[4:2] == 3'b101)) ? wb_wdata2[31:24] : wb_wdata1[31:24],
                         (wb_valid[1] & wb_wstrb2[2] & (wb_offset2[4:2] == 3'b101)) ? wb_wdata2[23:16] : wb_wdata1[23:16],
                         (wb_valid[1] & wb_wstrb2[1] & (wb_offset2[4:2] == 3'b101)) ? wb_wdata2[15: 8] : wb_wdata1[15: 8],
                         (wb_valid[1] & wb_wstrb2[0] & (wb_offset2[4:2] == 3'b101)) ? wb_wdata2[ 7: 0] : wb_wdata1[ 7: 0]}
                        : rd_way_wdata_bank5;
assign data_bank6_din = wstate[1] ?
                        {(wb_valid[1] & wb_wstrb2[3] & (wb_offset2[4:2] == 3'b110)) ? wb_wdata2[31:24] : wb_wdata1[31:24],
                         (wb_valid[1] & wb_wstrb2[2] & (wb_offset2[4:2] == 3'b110)) ? wb_wdata2[23:16] : wb_wdata1[23:16],
                         (wb_valid[1] & wb_wstrb2[1] & (wb_offset2[4:2] == 3'b110)) ? wb_wdata2[15: 8] : wb_wdata1[15: 8],
                         (wb_valid[1] & wb_wstrb2[0] & (wb_offset2[4:2] == 3'b110)) ? wb_wdata2[ 7: 0] : wb_wdata1[ 7: 0]}
                        : rd_way_wdata_bank6;
assign data_bank7_din = wstate[1] ?
                        {(wb_valid[1] & wb_wstrb2[3] & (wb_offset2[4:2] == 3'b111)) ? wb_wdata2[31:24] : wb_wdata1[31:24],
                         (wb_valid[1] & wb_wstrb2[2] & (wb_offset2[4:2] == 3'b111)) ? wb_wdata2[23:16] : wb_wdata1[23:16],
                         (wb_valid[1] & wb_wstrb2[1] & (wb_offset2[4:2] == 3'b111)) ? wb_wdata2[15: 8] : wb_wdata1[15: 8],
                         (wb_valid[1] & wb_wstrb2[0] & (wb_offset2[4:2] == 3'b111)) ? wb_wdata2[ 7: 0] : wb_wdata1[ 7: 0]}
                        : rd_way_wdata_bank7;
assign data_din = {data_bank7_din, data_bank6_din, data_bank5_din, data_bank4_din,
                   data_bank3_din, data_bank2_din, data_bank1_din, data_bank0_din};

assign data_addr = cache_inst_valid                   ? cache_inst_addr[11:5] :
                   wstate[1]                          ? wb_index : 
                   (valid1 && !uncache1 && addr_ok1)  ? index1 : 
                   (valid2 && !uncache2 && addr_ok2)  ? index2 :
                   (state[5] && ret_valid && rb_valid[0]) ? rb_index1 : rb_index2;

genvar id0;
generate for (id0=0; id0<128; id0=id0+1) begin :gen_for_D_Way0
    always @(posedge clk) begin
        if (!resetn) begin
            D_Way0[id0] <= 1'b0;
        end
        else if (wstate[1] && !wb_hit_way && id0 == wb_index) begin
            D_Way0[id0] <= 1'b1;
        end
        else if (state[5] && ret_valid && !rp_way && rb_valid[0] && id0 == rb_index1) begin
            D_Way0[id0] <= rb_op1;
        end
        else if (state[5] && ret_valid && !rp_way && rb_valid[1] && id0 == rb_index2) begin
            D_Way0[id0] <= rb_op2;
        end
        else if (state[13] && id0 == cache_inst_addr[11:5] && clear_way[0] && cache_inst_op != 3'b010) begin
            D_Way0[id0] <= 1'b0;
        end
        else if (state[13] && id0 == cache_inst_addr[11:5] && clear_way[0] && cache_inst_op == 3'b010) begin
            D_Way0[id0] <= cache_inst_d;
        end
    end
end endgenerate
genvar id1;
generate for (id1=0; id1<128; id1=id1+1) begin :gen_for_D_Way1
    always @(posedge clk) begin
        if (!resetn) begin
            D_Way1[id1] <= 1'b0;
        end
        else if (wstate[1] && wb_hit_way && id1 == wb_index) begin
            D_Way1[id1] <= 1'b1;
        end
        else if (state[5] && ret_valid && rp_way && rb_valid[0] && id1 == rb_index1) begin
            D_Way1[id1] <= rb_op1;
        end
        else if (state[5] && ret_valid && rp_way && rb_valid[1] && id1 == rb_index2) begin
            D_Way1[id1] <= rb_op2;
        end
        else if (state[13] && id1 == cache_inst_addr[11:5] && clear_way[1] && cache_inst_op != 3'b010) begin
            D_Way1[id1] <= 1'b0;
        end
        else if (state[13] && id1 == cache_inst_addr[11:5] && clear_way[1] && cache_inst_op == 3'b010) begin
            D_Way1[id1] <= cache_inst_d;
        end
    end
end endgenerate

genvar iv0;
generate for (iv0=0; iv0<128; iv0=iv0+1) begin :gen_for_V_Way0
    always @(posedge clk) begin
        if (!resetn) begin
            V_Way0[iv0] <= 1'b0;
        end
        else if (state[5] && ret_valid && !rp_way && rb_valid[0] && rb_index1 == iv0) begin
            V_Way0[iv0] <= 1'b1;
        end
        else if (state[5] && ret_valid && !rp_way && rb_valid[1] && rb_index2 == iv0) begin
            V_Way0[iv0] <= 1'b1;
        end
        else if (state[13] && iv0 == cache_inst_addr[11:5] && clear_way[0] && cache_inst_op != 3'b010) begin
            V_Way0[iv0] <= 1'b0;
        end
        else if (state[13] && iv0 == cache_inst_addr[11:5] && clear_way[0] && cache_inst_op == 3'b010) begin
            V_Way0[iv0] <= cache_inst_v;
        end
    end
end endgenerate
genvar iv1;
generate for (iv1=0; iv1<128; iv1=iv1+1) begin :gen_for_V_Way1
    always @(posedge clk) begin
        if (!resetn) begin
            V_Way1[iv1] <= 1'b0;
        end
        else if (state[5] && ret_valid && rp_way && rb_valid[0] && rb_index1 == iv1) begin
            V_Way1[iv1] <= 1'b1;
        end
        else if (state[5] && ret_valid && rp_way && rb_valid[1] && rb_index2 == iv1) begin
            V_Way1[iv1] <= 1'b1;
        end
        else if (state[13] && iv1 == cache_inst_addr[11:5] && clear_way[1] && cache_inst_op != 3'b010) begin
            V_Way1[iv1] <= 1'b0;
        end
        else if (state[13] && iv1 == cache_inst_addr[11:5] && clear_way[1] && cache_inst_op == 3'b010) begin
            V_Way1[iv1] <= cache_inst_v;
        end
    end
end endgenerate

// Request Buffer
reg [1:0] rb_recv;
always @(posedge clk) begin
    if(!resetn) begin
        rb_recv[0] <= 1'b0;
    end
    else if(valid1 && addr_ok1) begin
        rb_recv[0] <= 1'b1;
    end
    else if(data_ok1_raw) begin
        rb_recv[0] <= 1'b0;
    end
end
always @(posedge clk) begin
    if(!resetn) begin
        rb_recv[1] <= 1'b0;
    end
    else if(valid2 && addr_ok2) begin
        rb_recv[1] <= 1'b1;
    end
    else if(data_ok2_raw) begin
        rb_recv[1] <= 1'b0;
    end
end

wire req_same_line;
wire req_read_write;
assign req_same_line = (rb_index1 == rb_index2) && (rb_tag1 == rb_tag2) && !rb_uncache1 && !rb_uncache2;
assign req_read_write = (rb_op1 != rb_op2);

wire [1:0] rb_valid;
assign rb_valid[0] = rb_recv[0];
assign rb_valid[1] = rb_recv[1] && (!rb_recv[0] || req_same_line && !req_read_write);

wire dual_req;
assign dual_req = rb_recv[0] && rb_recv[1] && !(req_same_line && !req_read_write);

reg          rb_op1;
reg          rb_uncache1;
reg  [ 19:0] rb_tag1;
reg  [  6:0] rb_index1;
reg  [  4:0] rb_offset1;
reg  [  1:0] rb_size1;
reg  [  3:0] rb_wstrb1;
reg  [ 31:0] rb_wdata1;

reg          rb_op2;
reg          rb_uncache2;
reg  [ 19:0] rb_tag2;
reg  [  6:0] rb_index2;
reg  [  4:0] rb_offset2;
reg  [  1:0] rb_size2;
reg  [  3:0] rb_wstrb2;
reg  [ 31:0] rb_wdata2;

always @(posedge clk) begin
    if (valid1 && addr_ok1) begin
        rb_op1     <= op1;
        rb_uncache1<= uncache1;
        rb_tag1    <= tag1;
        rb_index1  <= index1;      
        rb_offset1 <= offset1;
        rb_size1   <= size1;
        rb_wstrb1  <= wstrb1;
        rb_wdata1  <= wdata1;
    end
end

always @(posedge clk) begin
    if (valid2 && addr_ok2) begin
        rb_op2     <= op2;
        rb_uncache2<= uncache2;
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
wire [255:0] way0_data;
wire [255:0] way1_data;

assign way0_v = rb_valid[0] ? V_Way0[rb_index1] : V_Way0[rb_index2];
assign way1_v = rb_valid[0] ? V_Way1[rb_index1] : V_Way1[rb_index2];
assign way0_d = rb_valid[0] ? D_Way0[rb_index1] : D_Way0[rb_index2];
assign way1_d = rb_valid[0] ? D_Way1[rb_index1] : D_Way1[rb_index2];
assign way0_tag = tag_way0_dout;
assign way1_tag = tag_way1_dout;
assign way0_data = data_way0_dout;
assign way1_data = data_way1_dout;

// Tag Compare
wire         way0_hit1;
wire         way1_hit1;
wire         cache_hit1;
wire         cache_miss1;
wire         way0_hit2;
wire         way1_hit2;
wire         cache_hit2;
wire         cache_miss2;
wire         way0_hit;
wire         way1_hit;
wire         cache_hit;

assign way0_hit1 = way0_v && (way0_tag == rb_tag1);
assign way1_hit1 = way1_v && (way1_tag == rb_tag1);
assign cache_hit1 = rb_valid[0] && (way0_hit1 || way1_hit1);
assign cache_miss1 = rb_valid[0] && !way0_hit1 && !way1_hit1;

assign way0_hit2 = way0_v && (way0_tag == rb_tag2);
assign way1_hit2 = way1_v && (way1_tag == rb_tag2);
assign cache_hit2 = rb_valid[1] && (way0_hit2 || way1_hit2);
assign cache_miss2 = rb_valid[1] && !way0_hit2 && !way1_hit2;

assign way0_hit = (rb_valid[0] & way0_hit1) | (rb_valid[1] & way0_hit2);
assign way1_hit = (rb_valid[0] & way1_hit1) | (rb_valid[1] & way1_hit2);
assign cache_hit = way0_hit || way1_hit;

// Data Select
wire [ 31:0] way0_load_word1;
wire [ 31:0] way1_load_word1;
wire [ 31:0] load_res1;
wire [ 31:0] way0_load_word2;
wire [ 31:0] way1_load_word2;
wire [ 31:0] load_res2;

assign way0_load_word1 = way0_data[rb_offset1[4:2]*32 +: 32];
assign way1_load_word1 = way1_data[rb_offset1[4:2]*32 +: 32];
assign load_res1 = {32{way0_hit1}} & way0_load_word1 |
                   {32{way1_hit1}} & way1_load_word1;
assign way0_load_word2 = way0_data[rb_offset2[4:2]*32 +: 32];
assign way1_load_word2 = way1_data[rb_offset2[4:2]*32 +: 32];
assign load_res2 = {32{way0_hit2}} & way0_load_word2 |
                   {32{way1_hit2}} & way1_load_word2;

// NRU
reg last_hit [127:0];
reg rp_way;

genvar i;
generate for (i=0; i<128; i=i+1) begin :gen_for_hit
    always @(posedge clk) begin
        if (!resetn) begin
            last_hit[i] <= 1'b0;
        end
        else if (state[2] && way0_hit && rb_valid[0] && rb_index1 == i) begin
            last_hit[i] <= 1'b0;
        end
        else if (state[2] && way0_hit && rb_valid[1] && rb_index2 == i) begin
            last_hit[i] <= 1'b0;
        end
        else if (state[2] && way1_hit && rb_valid[0] && rb_index1 == i) begin
            last_hit[i] <= 1'b1;
        end
        else if (state[2] && way1_hit && rb_valid[1] && rb_index2 == i) begin
            last_hit[i] <= 1'b1;
        end
    end
end endgenerate

always @(posedge clk) begin
    if (!resetn) begin
        rp_way <= 1'b0;
    end
    else if (state[2] && (cache_miss1 || cache_miss2)) begin
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
reg [255:0] way0_data_r;
reg [255:0] way1_data_r;

wire         rp_way_v;
wire         rp_way_d;
wire [ 19:0] rp_way_tag;
wire [255:0] rp_way_data;

always @(posedge clk) begin
    if ((state[2]) && (cache_miss1 || cache_miss2)) begin
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
wire [ 31:0] rd_way_data_bank4;
wire [ 31:0] rd_way_data_bank5;
wire [ 31:0] rd_way_data_bank6;
wire [ 31:0] rd_way_data_bank7;
wire [ 31:0] rd_way_wdata_bank0;
wire [ 31:0] rd_way_wdata_bank1;
wire [ 31:0] rd_way_wdata_bank2;
wire [ 31:0] rd_way_wdata_bank3;
wire [ 31:0] rd_way_wdata_bank4;
wire [ 31:0] rd_way_wdata_bank5;
wire [ 31:0] rd_way_wdata_bank6;
wire [ 31:0] rd_way_wdata_bank7;
wire [ 31:0] rd_way_rdata1;
wire [ 31:0] rd_way_rdata2;

assign rd_way_data_bank0 = ret_data[ 31:  0];
assign rd_way_data_bank1 = ret_data[ 63: 32];
assign rd_way_data_bank2 = ret_data[ 95: 64];
assign rd_way_data_bank3 = ret_data[127: 96];
assign rd_way_data_bank4 = ret_data[159:128];
assign rd_way_data_bank5 = ret_data[191:160];
assign rd_way_data_bank6 = ret_data[223:192];
assign rd_way_data_bank7 = ret_data[255:224];
assign rd_way_wdata_bank0[ 7: 0] = (rb_valid[1] && rb_op2 && rb_offset2[4:2] == 3'b000 && rb_wstrb2[0]) ? rb_wdata2[ 7: 0] :
                                   (rb_valid[0] && rb_op1 && rb_offset1[4:2] == 3'b000 && rb_wstrb1[0]) ? rb_wdata1[ 7: 0] : rd_way_data_bank0[ 7: 0];
assign rd_way_wdata_bank0[15: 8] = (rb_valid[1] && rb_op2 && rb_offset2[4:2] == 3'b000 && rb_wstrb2[1]) ? rb_wdata2[15: 8] :
                                   (rb_valid[0] && rb_op1 && rb_offset1[4:2] == 3'b000 && rb_wstrb1[1]) ? rb_wdata1[15: 8] : rd_way_data_bank0[15: 8];
assign rd_way_wdata_bank0[23:16] = (rb_valid[1] && rb_op2 && rb_offset2[4:2] == 3'b000 && rb_wstrb2[2]) ? rb_wdata2[23:16] :
                                   (rb_valid[0] && rb_op1 && rb_offset1[4:2] == 3'b000 && rb_wstrb1[2]) ? rb_wdata1[23:16] : rd_way_data_bank0[23:16];
assign rd_way_wdata_bank0[31:24] = (rb_valid[1] && rb_op2 && rb_offset2[4:2] == 3'b000 && rb_wstrb2[3]) ? rb_wdata2[31:24] :
                                   (rb_valid[0] && rb_op1 && rb_offset1[4:2] == 3'b000 && rb_wstrb1[3]) ? rb_wdata1[31:24] : rd_way_data_bank0[31:24];
assign rd_way_wdata_bank1[ 7: 0] = (rb_valid[1] && rb_op2 && rb_offset2[4:2] == 3'b001 && rb_wstrb2[0]) ? rb_wdata2[ 7: 0] :
                                   (rb_valid[0] && rb_op1 && rb_offset1[4:2] == 3'b001 && rb_wstrb1[0]) ? rb_wdata1[ 7: 0] : rd_way_data_bank1[ 7: 0];
assign rd_way_wdata_bank1[15: 8] = (rb_valid[1] && rb_op2 && rb_offset2[4:2] == 3'b001 && rb_wstrb2[1]) ? rb_wdata2[15: 8] :
                                   (rb_valid[0] && rb_op1 && rb_offset1[4:2] == 3'b001 && rb_wstrb1[1]) ? rb_wdata1[15: 8] : rd_way_data_bank1[15: 8];
assign rd_way_wdata_bank1[23:16] = (rb_valid[1] && rb_op2 && rb_offset2[4:2] == 3'b001 && rb_wstrb2[2]) ? rb_wdata2[23:16] :
                                   (rb_valid[0] && rb_op1 && rb_offset1[4:2] == 3'b001 && rb_wstrb1[2]) ? rb_wdata1[23:16] : rd_way_data_bank1[23:16];
assign rd_way_wdata_bank1[31:24] = (rb_valid[1] && rb_op2 && rb_offset2[4:2] == 3'b001 && rb_wstrb2[3]) ? rb_wdata2[31:24] :
                                   (rb_valid[0] && rb_op1 && rb_offset1[4:2] == 3'b001 && rb_wstrb1[3]) ? rb_wdata1[31:24] : rd_way_data_bank1[31:24];
assign rd_way_wdata_bank2[ 7: 0] = (rb_valid[1] && rb_op2 && rb_offset2[4:2] == 3'b010 && rb_wstrb2[0]) ? rb_wdata2[ 7: 0] :
                                   (rb_valid[0] && rb_op1 && rb_offset1[4:2] == 3'b010 && rb_wstrb1[0]) ? rb_wdata1[ 7: 0] : rd_way_data_bank2[ 7: 0];
assign rd_way_wdata_bank2[15: 8] = (rb_valid[1] && rb_op2 && rb_offset2[4:2] == 3'b010 && rb_wstrb2[1]) ? rb_wdata2[15: 8] :
                                   (rb_valid[0] && rb_op1 && rb_offset1[4:2] == 3'b010 && rb_wstrb1[1]) ? rb_wdata1[15: 8] : rd_way_data_bank2[15: 8];
assign rd_way_wdata_bank2[23:16] = (rb_valid[1] && rb_op2 && rb_offset2[4:2] == 3'b010 && rb_wstrb2[2]) ? rb_wdata2[23:16] :
                                   (rb_valid[0] && rb_op1 && rb_offset1[4:2] == 3'b010 && rb_wstrb1[2]) ? rb_wdata1[23:16] : rd_way_data_bank2[23:16];
assign rd_way_wdata_bank2[31:24] = (rb_valid[1] && rb_op2 && rb_offset2[4:2] == 3'b010 && rb_wstrb2[3]) ? rb_wdata2[31:24] :
                                   (rb_valid[0] && rb_op1 && rb_offset1[4:2] == 3'b010 && rb_wstrb1[3]) ? rb_wdata1[31:24] : rd_way_data_bank2[31:24];
assign rd_way_wdata_bank3[ 7: 0] = (rb_valid[1] && rb_op2 && rb_offset2[4:2] == 3'b011 && rb_wstrb2[0]) ? rb_wdata2[ 7: 0] :
                                   (rb_valid[0] && rb_op1 && rb_offset1[4:2] == 3'b011 && rb_wstrb1[0]) ? rb_wdata1[ 7: 0] : rd_way_data_bank3[ 7: 0];
assign rd_way_wdata_bank3[15: 8] = (rb_valid[1] && rb_op2 && rb_offset2[4:2] == 3'b011 && rb_wstrb2[1]) ? rb_wdata2[15: 8] :
                                   (rb_valid[0] && rb_op1 && rb_offset1[4:2] == 3'b011 && rb_wstrb1[1]) ? rb_wdata1[15: 8] : rd_way_data_bank3[15: 8];
assign rd_way_wdata_bank3[23:16] = (rb_valid[1] && rb_op2 && rb_offset2[4:2] == 3'b011 && rb_wstrb2[2]) ? rb_wdata2[23:16] :
                                   (rb_valid[0] && rb_op1 && rb_offset1[4:2] == 3'b011 && rb_wstrb1[2]) ? rb_wdata1[23:16] : rd_way_data_bank3[23:16];
assign rd_way_wdata_bank3[31:24] = (rb_valid[1] && rb_op2 && rb_offset2[4:2] == 3'b011 && rb_wstrb2[3]) ? rb_wdata2[31:24] :
                                   (rb_valid[0] && rb_op1 && rb_offset1[4:2] == 3'b011 && rb_wstrb1[3]) ? rb_wdata1[31:24] : rd_way_data_bank3[31:24];
assign rd_way_wdata_bank4[ 7: 0] = (rb_valid[1] && rb_op2 && rb_offset2[4:2] == 3'b100 && rb_wstrb2[0]) ? rb_wdata2[ 7: 0] :
                                   (rb_valid[0] && rb_op1 && rb_offset1[4:2] == 3'b100 && rb_wstrb1[0]) ? rb_wdata1[ 7: 0] : rd_way_data_bank4[ 7: 0];
assign rd_way_wdata_bank4[15: 8] = (rb_valid[1] && rb_op2 && rb_offset2[4:2] == 3'b100 && rb_wstrb2[1]) ? rb_wdata2[15: 8] :
                                   (rb_valid[0] && rb_op1 && rb_offset1[4:2] == 3'b100 && rb_wstrb1[1]) ? rb_wdata1[15: 8] : rd_way_data_bank4[15: 8];
assign rd_way_wdata_bank4[23:16] = (rb_valid[1] && rb_op2 && rb_offset2[4:2] == 3'b100 && rb_wstrb2[2]) ? rb_wdata2[23:16] :
                                   (rb_valid[0] && rb_op1 && rb_offset1[4:2] == 3'b100 && rb_wstrb1[2]) ? rb_wdata1[23:16] : rd_way_data_bank4[23:16];
assign rd_way_wdata_bank4[31:24] = (rb_valid[1] && rb_op2 && rb_offset2[4:2] == 3'b100 && rb_wstrb2[3]) ? rb_wdata2[31:24] :
                                   (rb_valid[0] && rb_op1 && rb_offset1[4:2] == 3'b100 && rb_wstrb1[3]) ? rb_wdata1[31:24] : rd_way_data_bank4[31:24];
assign rd_way_wdata_bank5[ 7: 0] = (rb_valid[1] && rb_op2 && rb_offset2[4:2] == 3'b101 && rb_wstrb2[0]) ? rb_wdata2[ 7: 0] :
                                   (rb_valid[0] && rb_op1 && rb_offset1[4:2] == 3'b101 && rb_wstrb1[0]) ? rb_wdata1[ 7: 0] : rd_way_data_bank5[ 7: 0];
assign rd_way_wdata_bank5[15: 8] = (rb_valid[1] && rb_op2 && rb_offset2[4:2] == 3'b101 && rb_wstrb2[1]) ? rb_wdata2[15: 8] :
                                   (rb_valid[0] && rb_op1 && rb_offset1[4:2] == 3'b101 && rb_wstrb1[1]) ? rb_wdata1[15: 8] : rd_way_data_bank5[15: 8];
assign rd_way_wdata_bank5[23:16] = (rb_valid[1] && rb_op2 && rb_offset2[4:2] == 3'b101 && rb_wstrb2[2]) ? rb_wdata2[23:16] :
                                   (rb_valid[0] && rb_op1 && rb_offset1[4:2] == 3'b101 && rb_wstrb1[2]) ? rb_wdata1[23:16] : rd_way_data_bank5[23:16];
assign rd_way_wdata_bank5[31:24] = (rb_valid[1] && rb_op2 && rb_offset2[4:2] == 3'b101 && rb_wstrb2[3]) ? rb_wdata2[31:24] :
                                   (rb_valid[0] && rb_op1 && rb_offset1[4:2] == 3'b101 && rb_wstrb1[3]) ? rb_wdata1[31:24] : rd_way_data_bank5[31:24];
assign rd_way_wdata_bank6[ 7: 0] = (rb_valid[1] && rb_op2 && rb_offset2[4:2] == 3'b110 && rb_wstrb2[0]) ? rb_wdata2[ 7: 0] :
                                   (rb_valid[0] && rb_op1 && rb_offset1[4:2] == 3'b110 && rb_wstrb1[0]) ? rb_wdata1[ 7: 0] : rd_way_data_bank6[ 7: 0];
assign rd_way_wdata_bank6[15: 8] = (rb_valid[1] && rb_op2 && rb_offset2[4:2] == 3'b110 && rb_wstrb2[1]) ? rb_wdata2[15: 8] :
                                   (rb_valid[0] && rb_op1 && rb_offset1[4:2] == 3'b110 && rb_wstrb1[1]) ? rb_wdata1[15: 8] : rd_way_data_bank6[15: 8];
assign rd_way_wdata_bank6[23:16] = (rb_valid[1] && rb_op2 && rb_offset2[4:2] == 3'b110 && rb_wstrb2[2]) ? rb_wdata2[23:16] :
                                   (rb_valid[0] && rb_op1 && rb_offset1[4:2] == 3'b110 && rb_wstrb1[2]) ? rb_wdata1[23:16] : rd_way_data_bank6[23:16];
assign rd_way_wdata_bank6[31:24] = (rb_valid[1] && rb_op2 && rb_offset2[4:2] == 3'b110 && rb_wstrb2[3]) ? rb_wdata2[31:24] :
                                   (rb_valid[0] && rb_op1 && rb_offset1[4:2] == 3'b110 && rb_wstrb1[3]) ? rb_wdata1[31:24] : rd_way_data_bank6[31:24];
assign rd_way_wdata_bank7[ 7: 0] = (rb_valid[1] && rb_op2 && rb_offset2[4:2] == 3'b111 && rb_wstrb2[0]) ? rb_wdata2[ 7: 0] :
                                   (rb_valid[0] && rb_op1 && rb_offset1[4:2] == 3'b111 && rb_wstrb1[0]) ? rb_wdata1[ 7: 0] : rd_way_data_bank7[ 7: 0];
assign rd_way_wdata_bank7[15: 8] = (rb_valid[1] && rb_op2 && rb_offset2[4:2] == 3'b111 && rb_wstrb2[1]) ? rb_wdata2[15: 8] :
                                   (rb_valid[0] && rb_op1 && rb_offset1[4:2] == 3'b111 && rb_wstrb1[1]) ? rb_wdata1[15: 8] : rd_way_data_bank7[15: 8];
assign rd_way_wdata_bank7[23:16] = (rb_valid[1] && rb_op2 && rb_offset2[4:2] == 3'b111 && rb_wstrb2[2]) ? rb_wdata2[23:16] :
                                   (rb_valid[0] && rb_op1 && rb_offset1[4:2] == 3'b111 && rb_wstrb1[2]) ? rb_wdata1[23:16] : rd_way_data_bank7[23:16];
assign rd_way_wdata_bank7[31:24] = (rb_valid[1] && rb_op2 && rb_offset2[4:2] == 3'b111 && rb_wstrb2[3]) ? rb_wdata2[31:24] :
                                   (rb_valid[0] && rb_op1 && rb_offset1[4:2] == 3'b111 && rb_wstrb1[3]) ? rb_wdata1[31:24] : rd_way_data_bank7[31:24];

assign rd_way_rdata1 = {32{rb_offset1[4:2] == 3'b000}} & rd_way_data_bank0 | 
                       {32{rb_offset1[4:2] == 3'b001}} & rd_way_data_bank1 | 
                       {32{rb_offset1[4:2] == 3'b010}} & rd_way_data_bank2 | 
                       {32{rb_offset1[4:2] == 3'b011}} & rd_way_data_bank3 |
                       {32{rb_offset1[4:2] == 3'b100}} & rd_way_data_bank4 | 
                       {32{rb_offset1[4:2] == 3'b101}} & rd_way_data_bank5 | 
                       {32{rb_offset1[4:2] == 3'b110}} & rd_way_data_bank6 | 
                       {32{rb_offset1[4:2] == 3'b111}} & rd_way_data_bank7;
assign rd_way_rdata2 = {32{rb_offset2[4:2] == 3'b000}} & rd_way_data_bank0 | 
                       {32{rb_offset2[4:2] == 3'b001}} & rd_way_data_bank1 | 
                       {32{rb_offset2[4:2] == 3'b010}} & rd_way_data_bank2 | 
                       {32{rb_offset2[4:2] == 3'b011}} & rd_way_data_bank3 |
                       {32{rb_offset2[4:2] == 3'b100}} & rd_way_data_bank4 | 
                       {32{rb_offset2[4:2] == 3'b101}} & rd_way_data_bank5 | 
                       {32{rb_offset2[4:2] == 3'b110}} & rd_way_data_bank6 | 
                       {32{rb_offset2[4:2] == 3'b111}} & rd_way_data_bank7;

// AXI Write Buffer
reg        pending_valid[31:0];
reg [4:0] pending_start;
reg [4:0] pending_end;

genvar ip;
generate for (ip=0; ip<32; ip=ip+1) begin :gen_for_valid
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
        pending_end <= 5'b0;
    end
    else if (wr_req && wr_rdy) begin
        pending_end <= pending_end + 5'b1;
    end
end

always @(posedge clk) begin
    if (!resetn) begin
        pending_start <= 5'b0;
    end
    else if (wr_ok) begin
        pending_start <= pending_start + 5'b1;
    end
end

wire uncache_read_stall;
wire uncache_write_go;
assign uncache_read_stall = (pending_end != pending_start);
assign uncache_write_go = ((pending_end + 5'b1) != pending_start);

// Result Buffer
wire data_ok1_raw;
wire data_ok2_raw;
wire [31:0] rdata1_raw;
wire [31:0] rdata2_raw;
assign data_ok1_raw = (state[2]) && cache_hit1 ||
                      (state[5]) && rb_valid[0] && ret_valid || 
                      (state[7]) && rb_valid[0] && ret_valid ||
                      (state[9]) && rb_valid[0] && uncache_write_go;
assign data_ok2_raw = (state[2]) && cache_hit2 ||
                      (state[5]) && rb_valid[1] && ret_valid || 
                      (state[7]) && rb_valid[1] && ret_valid ||
                      (state[9]) && rb_valid[1] && uncache_write_go;

assign rdata1_raw = {32{state[2]}} & load_res1  | 
                    {32{state[5]}} & rd_way_rdata1 |
                    {32{state[7]}} & ret_data[31:0];
assign rdata2_raw = {32{state[2]}} & load_res2  | 
                    {32{state[5]}} & rd_way_rdata2 |
                    {32{state[7]}} & ret_data[31:0];
reg data_ok1_r;
reg data_ok2_r;
reg [31:0] rdata1_r;
reg [31:0] rdata2_r;
always @(posedge clk) begin
    if (!resetn) begin
        data_ok1_r <= 1'b0;
    end
    else if (data_ok1_raw) begin
        data_ok1_r <= 1'b1;
    end
    else if (data_ok1) begin
        data_ok1_r <= 1'b0;
    end
end
always @(posedge clk) begin
    if (!resetn) begin
        data_ok2_r <= 1'b0;
    end
    else if (data_ok2_raw) begin
        data_ok2_r <= 1'b1;
    end
    else if (data_ok2) begin
        data_ok2_r <= 1'b0;
    end
end

always @(posedge clk) begin
    if (!resetn) begin
        rdata1_r <= 32'b0;
    end
    else if (data_ok1_raw) begin
        rdata1_r <= rdata1_raw;
    end
end
always @(posedge clk) begin
    if (!resetn) begin
        rdata2_r <= 32'b0;
    end
    else if (data_ok2_raw) begin
        rdata2_r <= rdata2_raw;
    end
end

// Cache Inst
reg [255:0] way0_data_for_inst;
reg [255:0] way1_data_for_inst;
reg [ 20:0] way0_tag_for_inst;
reg [ 20:0] way1_tag_for_inst;
always @(posedge clk) begin
    if (!resetn) begin
        way0_data_for_inst <= 256'b0;
        way1_data_for_inst <= 256'b0;
        way0_tag_for_inst <= 20'b0;
        way1_tag_for_inst <= 20'b0;
    end
    else if (state[10]) begin
        way0_data_for_inst <= data_way0_dout;
        way1_data_for_inst <= data_way1_dout;
        way0_tag_for_inst <= tag_way0_dout;
        way1_tag_for_inst <= tag_way1_dout;
    end
end

wire way0_hit_for_inst;
wire way1_hit_for_inst;
assign way0_hit_for_inst = V_Way0[cache_inst_addr[11:5]] && (tag_way0_dout == cache_inst_addr[31:12]);
assign way1_hit_for_inst = V_Way1[cache_inst_addr[11:5]] && (tag_way1_dout == cache_inst_addr[31:12]);

reg [1:0] clear_way;
always @(posedge clk) begin
    if (!resetn) begin
        clear_way <= 2'b0;
    end
    else if (cache_inst_op == 3'b000 && !cache_inst_addr[12]) begin
        clear_way <= 2'b01;
    end
    else if (cache_inst_op == 3'b000 &&  cache_inst_addr[12]) begin
        clear_way <= 2'b10;
    end
    else if (cache_inst_op == 3'b010 && !cache_inst_addr[12]) begin
        clear_way <= 2'b01;
    end
    else if (cache_inst_op == 3'b010 &&  cache_inst_addr[12]) begin
        clear_way <= 2'b10;
    end
    else if (cache_inst_op == 3'b100 && way0_hit_for_inst) begin
        clear_way <= 2'b01;
    end
    else if (cache_inst_op == 3'b100 && way1_hit_for_inst) begin
        clear_way <= 2'b10;
    end
    else if (cache_inst_op == 3'b101 && way0_hit_for_inst) begin
        clear_way <= 2'b01;
    end
    else if (cache_inst_op == 3'b101 && way1_hit_for_inst) begin
        clear_way <= 2'b10;
    end
end

// Output
assign addr_ok1 = (state[0] || (state[2] && cache_hit) || (state[7] && ret_valid) || (state[9] && uncache_write_go)) &&
                  !dual_req && wstate[0] && !wait_write1 && !wait_write2 && !cache_inst_valid;
assign addr_ok2 = (state[0] || (state[2] && cache_hit) || (state[7] && ret_valid) || (state[9] && uncache_write_go)) &&
                  !dual_req && wstate[0] && !wait_write1 && !wait_write2 && !cache_inst_valid;
assign data_ok1 = data_ok1_r;
assign data_ok2 = data_ok2_r;
assign rdata1 = rdata1_r;
assign rdata2 = rdata2_r;
assign cache_inst_ok = state[13];

assign wr_req   = (state[3] && write_back) || state[8] ||
                  state[11] && D_Way0[cache_inst_addr[11:5]] && V_Way0[cache_inst_addr[11:5]] ||
                  state[12] && D_Way1[cache_inst_addr[11:5]] && V_Way1[cache_inst_addr[11:5]];
assign wr_type  = state[8] ? 1'b0 : 1'b1;         // 0 for uncache; 1 for cache line
assign wr_addr  = state[11] ? {way0_tag_for_inst, cache_inst_addr[11:5], 5'b0} :
                  state[12] ? {way1_tag_for_inst, cache_inst_addr[11:5], 5'b0} :
                  (state[8] && rb_valid[0]) ? {rb_tag1, rb_index1, rb_offset1} :
                  (state[8] && rb_valid[1]) ? {rb_tag2, rb_index2, rb_offset2} :
                  rb_valid[0] ? {rp_way_tag, rb_index1, 5'b0} : {rp_way_tag, rb_index2, 5'b0};
assign wr_size  = (state[8] && rb_valid[0]) ? {1'b0, rb_size1} :
                  (state[8] && rb_valid[1]) ? {1'b0, rb_size2} : 3'd2;
assign wr_wstrb = (state[8] && rb_valid[0]) ? rb_wstrb1 :
                  (state[8] && rb_valid[1]) ? rb_wstrb2 : 4'b1111;
assign wr_data  = state[11] ? way0_data_for_inst :
                  state[12] ? way1_data_for_inst :
                  (state[8] && rb_valid[0]) ? {224'b0, rb_wdata1} :
                  (state[8] && rb_valid[1]) ? {224'b0, rb_wdata2} : rp_way_data;

assign rd_req  = state[4] || (state[6] && !uncache_read_stall);
assign rd_type = state[6] ? 1'b0 : 1'b1;        // 0 for uncache; 1 for cache line
assign rd_addr = (state[6] && rb_valid[0]) ? {rb_tag1, rb_index1, rb_offset1} :
                 (state[6] && rb_valid[1]) ? {rb_tag2, rb_index2, rb_offset2} : 
                 rb_valid[0] ? {rb_tag1, rb_index1, 5'b0} : {rb_tag2, rb_index2, 5'b0};
assign rd_size = (state[6] && rb_valid[0]) ? {1'b0, rb_size1} :
                 (state[6] && rb_valid[1]) ? {1'b0, rb_size2} : 3'd2;

// Main FSM
reg [13:0] state;
reg [13:0] next_state;

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
        if (cache_inst_valid && wstate[0]) begin
            next_state = `ILOOK;
        end
		else if (valid1 && uncache1 && addr_ok1) begin
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
        else if (valid1 && !uncache1 && addr_ok1 || valid2 && !uncache2 && addr_ok2) begin
			next_state = `LOOKUP;
		end
        
		else begin
			next_state = `IDLE;
		end
    `PRELOOK:
        if(wstate[0]) begin
            next_state = `LOOKUP;
        end
        else begin
            next_state = `PRELOOK;
        end
	`LOOKUP:
        if (cache_hit && dual_req) begin
            if(rb_uncache2 && rb_op2 == 1'b0) begin
                next_state = `URREQ;
            end
            else if(rb_uncache2 && rb_op2 == 1'b1) begin
                next_state = `UWREQ;
            end
            else if (!rb_uncache2 && wstate[1]) begin
                next_state = `PRELOOK;
            end
            else if (!rb_uncache2 && self_raw) begin
                next_state = `PRELOOK;
            end
            else begin
                next_state = `LOOKUP;
            end
        end
        else if (cache_hit && (valid1 && !uncache1 && addr_ok1 || valid2 && !uncache2 && addr_ok2)) begin
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
        else if (cache_hit) begin
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
        if (ret_valid && dual_req) begin
            if(rb_uncache2 && rb_op2 == 1'b0) begin
                next_state = `URREQ;
            end
            else if(rb_uncache2 && rb_op2 == 1'b1) begin
                next_state = `UWREQ;
            end
            else begin
                next_state = `PRELOOK;
            end
        end
        else if (ret_valid && !dual_req) begin
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
        if (ret_valid && dual_req) begin
            if(rb_uncache2 && rb_op2 == 1'b0) begin
                next_state = `URREQ;
            end
            else if(rb_uncache2 && rb_op2 == 1'b1) begin
                next_state = `UWREQ;
            end
            else if (!rb_uncache2 && wstate[1]) begin
                next_state = `PRELOOK;
            end
            else begin
                next_state = `LOOKUP;
            end
        end
        else if (ret_valid && (valid1 && !uncache1 && addr_ok1 || valid2 && !uncache2 && addr_ok2)) begin
			next_state = `LOOKUP;
		end
        else if (ret_valid && (valid1 && uncache1 && addr_ok1)) begin
			if (op1 == 1'b0) begin
                next_state = `URREQ;
            end
            else begin
                next_state = `UWREQ;
            end
		end
        else if (ret_valid && (valid2 && uncache2 && addr_ok2)) begin
			if (op2 == 1'b0) begin
                next_state = `URREQ;
            end
            else begin
                next_state = `UWREQ;
            end
		end
        else if (ret_valid) begin
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
        if (uncache_write_go && dual_req) begin
            if(rb_uncache2 && rb_op2 == 1'b0) begin
                next_state = `URREQ;
            end
            else if(rb_uncache2 && rb_op2 == 1'b1) begin
                next_state = `UWREQ;
            end
            else if (!rb_uncache2 && wstate[1]) begin
                next_state = `PRELOOK;
            end
            else begin
                next_state = `LOOKUP;
            end
        end
        else if (uncache_write_go && (valid1 && !uncache1 && addr_ok1 || valid2 && !uncache2 && addr_ok2)) begin
			next_state = `LOOKUP;
		end
        else if (uncache_write_go && (valid1 && uncache1 && addr_ok1)) begin
			if (op1 == 1'b0) begin
                next_state = `URREQ;
            end
            else begin
                next_state = `UWREQ;
            end
		end
        else if (uncache_write_go && (valid2 && uncache2 && addr_ok2)) begin
			if (op2 == 1'b0) begin
                next_state = `URREQ;
            end
            else begin
                next_state = `UWREQ;
            end
		end
        else if (uncache_write_go) begin
			next_state = `IDLE;
		end
        else begin
            next_state = `UWRESP;
        end
    `ILOOK:
        if (cache_inst_op == 3'b000) begin // Index Writeback Invalid
            if (!cache_inst_addr[12]) begin
                next_state = `IWB0;
            end
            else begin
                next_state = `IWB1;
            end
        end
        else if (cache_inst_op == 3'b010) begin // Index Store Tag
            next_state = `ICLEAR;
        end
        else if (cache_inst_op == 3'b100) begin // Index Store Tag
            next_state = `ICLEAR;
        end
        else if (cache_inst_op == 3'b101) begin // Hit Writeback Invalidate
            if (way0_hit_for_inst) begin
                next_state = `IWB0;
            end
            else if (way1_hit_for_inst) begin
                next_state = `IWB1;
            end
            else begin
                next_state = `IDLE;
            end
        end
        else begin
            next_state = `IDLE;
        end
    `IWB0:
        if (!D_Way0[cache_inst_addr[11:5]] || !V_Way0[cache_inst_addr[11:5]]) begin
            next_state = `ICLEAR;
        end
        else if (wr_req && wr_rdy) begin
            next_state = `ICLEAR;
        end
        else begin
            next_state = `IWB0;
        end
    `IWB1:
        if (!D_Way1[cache_inst_addr[11:5]] || !V_Way1[cache_inst_addr[11:5]]) begin
            next_state = `ICLEAR;
        end
        else if (wr_req && wr_rdy) begin
            next_state = `ICLEAR;
        end
        else begin
            next_state = `IWB1;
        end
    `ICLEAR:
        next_state = `IDLE;
	default:
		next_state = `IDLE;
	endcase
end

// Write Buffer
reg          wb_hit_way;
reg  [  6:0] wb_index;
reg  [  4:0] wb_offset1;
reg  [  3:0] wb_wstrb1;
reg  [ 31:0] wb_wdata1;
reg  [  4:0] wb_offset2;
reg  [  3:0] wb_wstrb2;
reg  [ 31:0] wb_wdata2;
reg  [  1:0] wb_valid;

always @(posedge clk) begin
    if (state[2] && (cache_hit1 && rb_op1 && rb_valid[0] || cache_hit2 && rb_op2 && rb_valid[1])) begin
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
    if(!resetn) begin
        wb_valid <= 2'b00;
    end
    else if (state[2] && cache_hit1 && rb_op1 && cache_hit2 && rb_op2) begin
        wb_valid <= 2'b11;
    end
    else if (state[2] && cache_hit1 && rb_op1) begin
        wb_valid <= 2'b01;
    end
    else if (state[2] && cache_hit2 && rb_op2) begin
        wb_valid <= 2'b10;
    end
end

wire wait_write1;
wire wait_write2;
assign wait_write1 = state[2] && rb_valid[0] && rb_op1 && ({rb_index1, rb_offset1} == {index1, offset1}) ||
                     state[2] && rb_valid[1] && rb_op2 && ({rb_index2, rb_offset2} == {index1, offset1});
assign wait_write2 = state[2] && rb_valid[0] && rb_op1 && ({rb_index1, rb_offset1} == {index2, offset2}) ||
                     state[2] && rb_valid[1] && rb_op2 && ({rb_index2, rb_offset2} == {index2, offset2});

wire self_raw;
assign self_raw = dual_req && ({rb_index1, rb_offset1} == {rb_index2, rb_offset2});

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
		if (state[2] && cache_hit1 && rb_op1) begin
			next_wstate = `WRITE;
		end
        else if (state[2] && cache_hit2 && rb_op2) begin
			next_wstate = `WRITE;
		end
		else begin
			next_wstate = `WIDLE;
		end
	`WRITE:
        if (state[2] && cache_hit1 && rb_op1) begin
			next_wstate = `WRITE;
		end
        else if (state[2] && cache_hit2 && rb_op2) begin
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
