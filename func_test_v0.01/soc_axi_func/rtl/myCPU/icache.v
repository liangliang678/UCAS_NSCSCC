`define  IDLE    4'b0001
`define  LOOKUP  4'b0010
`define  REPLACE 4'b0100
`define  REFILL  4'b1000

module icache(
    input           clk_g,
    input           resetn,

    // Cache and CPU
    input           valid,
    input           uncache,
    input  [ 19:0]  tag,
    input  [  7:0]  index,
    input  [  3:0]  offset,

    output          addr_ok,
    output          data_ok,
    output [ 31:0]  rdata,

    // Cache and AXI
    output          rd_req,
    output [  2:0]  rd_type,
    output [ 31:0]  rd_addr,
    input           rd_rdy,
    input           ret_valid,
    input  [127:0]  ret_data,
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

TagV_RAM TagV_RAM_Way0(
    .clka   (clk_g         ),
    .addra  (tagv_addr     ),
    .ena    (tagv_way0_en  ),
    .wea    (tagv_way0_we  ),
    .dina   (tagv_way0_din ),
    .douta  (tagv_way0_dout)
);
TagV_RAM TagV_RAM_Way1(
    .clka   (clk_g         ),
    .addra  (tagv_addr     ),
    .ena    (tagv_way1_en  ),
    .wea    (tagv_way1_we  ),
    .dina   (tagv_way1_din ),
    .douta  (tagv_way1_dout)
);
Data_RAM Data_RAM_Way0_Bank0(
    .clka   (clk_g               ),
    .addra  (data_addr           ),
    .ena    (data_way0_bank0_en  ),
    .wea    (data_way0_bank0_we  ),
    .dina   (data_way0_bank0_din ),
    .douta  (data_way0_bank0_dout)
);
Data_RAM Data_RAM_Way0_Bank1(
    .clka   (clk_g               ),
    .addra  (data_addr           ),
    .ena    (data_way0_bank1_en  ),
    .wea    (data_way0_bank1_we  ),
    .dina   (data_way0_bank1_din ),
    .douta  (data_way0_bank1_dout)
);
Data_RAM Data_RAM_Way0_Bank2(
    .clka   (clk_g               ),
    .addra  (data_addr           ),
    .ena    (data_way0_bank2_en  ),
    .wea    (data_way0_bank2_we  ),
    .dina   (data_way0_bank2_din ),
    .douta  (data_way0_bank2_dout)
);
Data_RAM Data_RAM_Way0_Bank3(
    .clka   (clk_g               ),
    .addra  (data_addr           ),
    .ena    (data_way0_bank3_en  ),
    .wea    (data_way0_bank3_we  ),
    .dina   (data_way0_bank3_din ),
    .douta  (data_way0_bank3_dout)
);
Data_RAM Data_RAM_Way1_Bank0(
    .clka   (clk_g               ),
    .addra  (data_addr           ),
    .ena    (data_way1_bank0_en  ),
    .wea    (data_way1_bank0_we  ),
    .dina   (data_way1_bank0_din ),
    .douta  (data_way1_bank0_dout)
);
Data_RAM Data_RAM_Way1_Bank1(
    .clka   (clk_g               ),
    .addra  (data_addr           ),
    .ena    (data_way1_bank1_en  ),
    .wea    (data_way1_bank1_we  ),
    .dina   (data_way1_bank1_din ),
    .douta  (data_way1_bank1_dout)
);
Data_RAM Data_RAM_Way1_Bank2(
    .clka   (clk_g               ),
    .addra  (data_addr           ),
    .ena    (data_way1_bank2_en  ),
    .wea    (data_way1_bank2_we  ),
    .dina   (data_way1_bank2_din ),
    .douta  (data_way1_bank2_dout)
);
Data_RAM Data_RAM_Way1_Bank3(
    .clka   (clk_g               ),
    .addra  (data_addr           ),
    .ena    (data_way1_bank3_en  ),
    .wea    (data_way1_bank3_we  ),
    .dina   (data_way1_bank3_din ),
    .douta  (data_way1_bank3_dout)
);

assign tagv_way0_en = (state == `IDLE && valid && addr_ok) || (state == `REFILL && recv_end && !rp_way);
assign tagv_way1_en = (state == `IDLE && valid && addr_ok) || (state == `REFILL && recv_end &&  rp_way);
assign tagv_way0_we = (state == `REFILL && recv_end && !rp_way) ? 1'b1 : 1'b0;
assign tagv_way1_we = (state == `REFILL && recv_end &&  rp_way) ? 1'b1 : 1'b0;
assign tagv_way0_din = {1'b1, rb_tag};
assign tagv_way1_din = {1'b1, rb_tag};
assign tagv_addr = (state == `IDLE && valid && addr_ok) ? index : 
                   (state == `REFILL && recv_end) ? rb_index : 8'b0;

assign data_way0_bank0_en = (state == `IDLE && valid && addr_ok) || 
                            (wstate == `WRITE && wb_offset[3:2] == 2'b00 && !wb_hit_way) || 
                            (state == `REFILL && recv_end && !rp_way);
assign data_way0_bank1_en = (state == `IDLE && valid && addr_ok) || 
                            (wstate == `WRITE && wb_offset[3:2] == 2'b01 && !wb_hit_way) || 
                            (state == `REFILL && recv_end && !rp_way);
assign data_way0_bank2_en = (state == `IDLE && valid && addr_ok) || 
                            (wstate == `WRITE && wb_offset[3:2] == 2'b10 && !wb_hit_way) || 
                            (state == `REFILL && recv_end && !rp_way);
assign data_way0_bank3_en = (state == `IDLE && valid && addr_ok) || 
                            (wstate == `WRITE && wb_offset[3:2] == 2'b11 && !wb_hit_way) || 
                            (state == `REFILL && recv_end && !rp_way);
assign data_way1_bank0_en = (state == `IDLE && valid && addr_ok) || 
                            (wstate == `WRITE && wb_offset[3:2] == 2'b00 && wb_hit_way) || 
                            (state == `REFILL && recv_end && rp_way);
assign data_way1_bank1_en = (state == `IDLE && valid && addr_ok) || 
                            (wstate == `WRITE && wb_offset[3:2] == 2'b01 && wb_hit_way) || 
                            (state == `REFILL && recv_end && rp_way);
assign data_way1_bank2_en = (state == `IDLE && valid && addr_ok) || 
                            (wstate == `WRITE && wb_offset[3:2] == 2'b10 && wb_hit_way) || 
                            (state == `REFILL && recv_end && rp_way);
assign data_way1_bank3_en = (state == `IDLE && valid && addr_ok) || 
                            (wstate == `WRITE && wb_offset[3:2] == 2'b11 && wb_hit_way) || 
                            (state == `REFILL && recv_end && rp_way);
assign data_way0_bank0_we = (wstate == `WRITE) ? wb_wstrb : (state == `REFILL && !rb_uncache) ? 4'b1111 : 4'b0000;
assign data_way0_bank1_we = (wstate == `WRITE) ? wb_wstrb : (state == `REFILL && !rb_uncache) ? 4'b1111 : 4'b0000;
assign data_way0_bank2_we = (wstate == `WRITE) ? wb_wstrb : (state == `REFILL && !rb_uncache) ? 4'b1111 : 4'b0000;
assign data_way0_bank3_we = (wstate == `WRITE) ? wb_wstrb : (state == `REFILL && !rb_uncache) ? 4'b1111 : 4'b0000;
assign data_way1_bank0_we = (wstate == `WRITE) ? wb_wstrb : (state == `REFILL && !rb_uncache) ? 4'b1111 : 4'b0000;
assign data_way1_bank1_we = (wstate == `WRITE) ? wb_wstrb : (state == `REFILL && !rb_uncache) ? 4'b1111 : 4'b0000;
assign data_way1_bank2_we = (wstate == `WRITE) ? wb_wstrb : (state == `REFILL && !rb_uncache) ? 4'b1111 : 4'b0000;
assign data_way1_bank3_we = (wstate == `WRITE) ? wb_wstrb : (state == `REFILL && !rb_uncache) ? 4'b1111 : 4'b0000;
assign data_way0_bank0_din = (wstate == `WRITE) ? wb_wdata : (state == `REFILL) ? rd_way_data_bank0 : 32'b0;
assign data_way0_bank1_din = (wstate == `WRITE) ? wb_wdata : (state == `REFILL) ? rd_way_data_bank1 : 32'b0;
assign data_way0_bank2_din = (wstate == `WRITE) ? wb_wdata : (state == `REFILL) ? rd_way_data_bank2 : 32'b0;
assign data_way0_bank3_din = (wstate == `WRITE) ? wb_wdata : (state == `REFILL) ? rd_way_data_bank3 : 32'b0;
assign data_way1_bank0_din = (wstate == `WRITE) ? wb_wdata : (state == `REFILL) ? rd_way_data_bank0 : 32'b0;
assign data_way1_bank1_din = (wstate == `WRITE) ? wb_wdata : (state == `REFILL) ? rd_way_data_bank1 : 32'b0;
assign data_way1_bank2_din = (wstate == `WRITE) ? wb_wdata : (state == `REFILL) ? rd_way_data_bank2 : 32'b0;
assign data_way1_bank3_din = (wstate == `WRITE) ? wb_wdata : (state == `REFILL) ? rd_way_data_bank3 : 32'b0;

assign data_addr = (wstate == `WRITE) ? wb_index : 
                   (state == `IDLE && valid && addr_ok) ? index : 
                   (state == `REFILL) ? rb_index : 8'b0;


// Request Buffer
reg          rb_uncache;
reg  [ 19:0] rb_tag;
reg  [  7:0] rb_index;
reg  [  3:0] rb_offset;

wire         way0_v;
wire         way1_v;
wire [ 19:0] way0_tag;
wire [ 19:0] way1_tag;
wire [127:0] way0_data;
wire [127:0] way1_data;

always @(posedge clk_g) begin
    if (valid && addr_ok) begin
        rb_uncache <= uncache;
        rb_index   <= index;
        rb_tag     <= tag;
        rb_offset  <= offset;
    end
end

assign addr_ok = (state == `IDLE) && valid;

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
assign data_ok = (state == `LOOKUP) && cache_hit || (state == `REFILL);

// Data Select
wire [ 31:0] way0_load_word;
wire [ 31:0] way1_load_word;
wire [ 31:0] load_res;

assign way0_load_word = way0_data[rb_offset[3:2]*32 +: 32];
assign way1_load_word = way1_data[rb_offset[3:2]*32 +: 32];
assign load_res = {32{way0_hit}} & way0_load_word |
                  {32{way1_hit}} & way1_load_word;
assign rdata = {32{(state == `LOOKUP) && cache_hit}} & load_res | 
               {32{(state == `REFILL)}} & rd_way_rdata;

// LFSR
reg        feedback;
reg [ 7:0] LFSR;
reg [ 7:0] LFSR_next;
reg        rp_way;

always @(posedge clk_g) begin
    if (!resetn) begin
        LFSR <= 8'b0000_0000;
    end
    else begin
        LFSR <= LFSR_next;
    end
end
always @(*) begin
    feedback = LFSR[7] ^ (~|LFSR[6:0]);
    LFSR_next[7] = LFSR[6];
    LFSR_next[6] = LFSR[5];
    LFSR_next[5] = LFSR[4];
    LFSR_next[4] = LFSR[3] ^ feedback;
    LFSR_next[3] = LFSR[2] ^ feedback;
    LFSR_next[2] = LFSR[1] ^ feedback;
    LFSR_next[1] = LFSR[0];
    LFSR_next[0] = feedback;
end
always @(posedge clk_g) begin
    if (!resetn) begin
        rp_way <= 1'b0;
    end
    else if (state == `IDLE) begin
        rp_way <= LFSR[0];
    end
end

// Miss Buffer
reg  [127:0] rd_way_data;
wire [ 31:0] rd_way_data_bank0;
wire [ 31:0] rd_way_data_bank1;
wire [ 31:0] rd_way_data_bank2;
wire [ 31:0] rd_way_data_bank3;
wire [ 31:0] rd_way_rdata;

assign rd_req = (state == `REFILL);
assign rd_type = rb_uncache ? 3'b010 : 3'b100;
assign rd_addr = rb_uncache ? {rb_tag, rb_index, rb_offset} : {rb_tag, rb_index, 4'b0};

always @(posedge clk_g) begin
	if (state == `REFILL && ret_valid) begin
		rd_way_data <= ret_data;
	end
end

assign rd_way_data_bank0 = rd_way_data[31:0];
assign rd_way_data_bank1 = rd_way_data[63:32];
assign rd_way_data_bank2 = rd_way_data[95:64];
assign rd_way_data_bank3 = rd_way_data[127:96];
assign rd_way_rdata = {32{rb_uncache}} & rd_way_data_bank0 | 
                      {32{!rb_uncache && rb_offset[3:2] == 2'b00}} & rd_way_data_bank0 | 
                      {32{!rb_uncache && rb_offset[3:2] == 2'b01}} & rd_way_data_bank1 | 
                      {32{!rb_uncache && rb_offset[3:2] == 2'b10}} & rd_way_data_bank2 | 
                      {32{!rb_uncache && rb_offset[3:2] == 2'b11}} & rd_way_data_bank3;


// Main FSM
reg  [  3:0] state;
reg  [  3:0] next_state;

always @(posedge clk_g) begin
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
		if (valid && addr_ok) begin
			next_state = `LOOKUP;
		end
		else begin
			next_state = `IDLE;
		end
	`LOOKUP:
        if (cache_hit) begin
			next_state = `IDLE;
		end
		else begin
			next_state = `REPLACE;
		end
    `REPLACE:
        if (rd_rdy) begin
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
	default:
		next_state = `IDLE;
	endcase
end
