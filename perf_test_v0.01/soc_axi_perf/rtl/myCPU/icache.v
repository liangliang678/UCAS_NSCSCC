`define  IDLE    6'b000001
`define  LOOKUP  6'b000010
`define  REPLACE 6'b000100
`define  REFILL  6'b001000
`define  UREQ    6'b010000
`define  URESP   6'b100000

module icache(
    input           clk,
    input           resetn,
    // Cache and CPU
    input           valid,
    input           uncache,
    input  [ 19:0]  tag,
    input  [  6:0]  index,
    input  [  4:0]  offset,
    output          addr_ok,
    output          data_ok,
    output [ 255:0] rdata,
    output [   3:0] rnum,
    // Cache and AXI
    output          rd_req,
    output          rd_type,
    output [ 31:0]  rd_addr,
    input           rd_rdy,
    input           ret_valid,
    input  [255:0]  ret_data
);

// RAM
wire        tag_way0_en;
wire        tag_way1_en;
wire        tag_way0_we;
wire        tag_way1_we;
wire [ 6:0] tag_addr;
wire [19:0] tag_din;
wire [19:0] tag_way0_dout;
wire [19:0] tag_way1_dout;

wire         data_way0_en;
wire         data_way1_en;
wire         data_way0_we;
wire         data_way1_we;
wire [ 6:0]  data_addr;
wire [255:0] data_din;
wire [255:0] data_way0_dout;
wire [255:0] data_way1_dout;

Tag_RAM_8 Tag_RAM_8_Way0(
    .clka   (clk          ),
    .addra  (tag_addr     ),
    .ena    (tag_way0_en  ),
    .wea    (tag_way0_we  ),
    .dina   (tag_din      ),
    .douta  (tag_way0_dout)
);
Tag_RAM_8 Tag_RAM_8_Way1(
    .clka   (clk          ),
    .addra  (tag_addr     ),
    .ena    (tag_way1_en  ),
    .wea    (tag_way1_we  ),
    .dina   (tag_din      ),
    .douta  (tag_way1_dout)
);

Data_RAM_Single Data_RAM_Way0(
    .clka   (clk           ),
    .addra  (data_addr     ),
    .ena    (data_way0_en  ),
    .wea    (data_way0_we  ),
    .dina   (data_din      ),
    .douta  (data_way0_dout)
);
Data_RAM_Single Data_RAM_Way1(
    .clka   (clk           ),
    .addra  (data_addr     ),
    .ena    (data_way1_en  ),
    .wea    (data_way1_we  ),
    .dina   (data_din      ),
    .douta  (data_way1_dout)
);

reg V_Way0 [127:0];
reg V_Way1 [127:0];

// RAM Port
assign tag_way0_en = (valid && !uncache && addr_ok) || 
                     (state[3] && ret_valid && !rp_way);
assign tag_way1_en = (valid && !uncache && addr_ok) || 
                     (state[3] && ret_valid &&  rp_way);
assign tag_way0_we = (state[3] && ret_valid && !rp_way);
assign tag_way1_we = (state[3] && ret_valid &&  rp_way);
assign tag_din = rb_tag;
assign tag_addr = (state[3]) ? rb_index : index;

assign data_way0_en = (valid && !uncache && addr_ok) ||
                      (state[3] && ret_valid && !rp_way);
assign data_way1_en = (valid && !uncache && addr_ok) ||
                      (state[3] && ret_valid &&  rp_way);                             
assign data_way0_we = (state[3] && ret_valid && !rp_way);
assign data_way1_we = (state[3] && ret_valid &&  rp_way);
assign data_din = ret_data;
assign data_addr = (state[3]) ? rb_index : index;

genvar i0;
generate for (i0=0; i0<128; i0=i0+1) begin :gen_for_V_Way0
    always @(posedge clk) begin
        if (!resetn) begin
            V_Way0[i0] <= 1'b0;
        end
        else if (state[3] && ret_valid && !rp_way && rb_index == i0) begin
            V_Way0[i0] <= 1'b1;
        end
    end
end endgenerate
genvar i1;
generate for (i1=0; i1<128; i1=i1+1) begin :gen_for_V_Way1
    always @(posedge clk) begin
        if (!resetn) begin
            V_Way1[i1] <= 1'b0;
        end
        else if (state[3] && ret_valid &&  rp_way && rb_index == i1) begin
            V_Way1[i1] <= 1'b1;
        end
    end
end endgenerate

// Request Buffer
(* max_fanout = 50 *)reg  [19:0] rb_tag;
(* max_fanout = 50 *)reg  [ 6:0] rb_index;
(* max_fanout = 50 *)reg  [ 4:0] rb_offset;

always @(posedge clk) begin
    if (valid && addr_ok) begin
        rb_tag     <= tag;
        rb_index   <= index;
        rb_offset  <= offset;
    end
end

// Tag Compare
wire         way0_hit;
wire         way1_hit;
wire         cache_hit;

assign way0_hit = V_Way0[rb_index] & (tag_way0_dout == rb_tag);
assign way1_hit = V_Way1[rb_index] & (tag_way1_dout == rb_tag);
assign cache_hit = (way0_hit | way1_hit);

// Data Select
wire [255:0] load_res;
assign load_res = {256{way0_hit}} & data_way0_dout |
                  {256{way1_hit}} & data_way1_dout;

// PLRU
reg [127:0] way0_mru;
reg [127:0] way1_mru;
reg rp_way;

genvar i;
generate for (i=0; i<128; i=i+1) begin :gen_for_mru
    always @(posedge clk) begin
        if (!resetn) begin
            way0_mru[i] <= 1'b0;
            way1_mru[i] <= 1'b0;
        end
        else if (state[1] && way0_hit && rb_index == i) begin
            way0_mru[i] <= 1'b1;
            if(way1_mru[i]) begin
                way1_mru[i] <= 1'b0;
            end
        end
        else if (state[1] && way1_hit && rb_index == i) begin
            way1_mru[i] <= 1'b1;
            if(way0_mru[i]) begin
                way0_mru[i] <= 1'b0;
            end
        end
        else if (state[2] && !rp_way && rb_index == i) begin
            way0_mru[i] <= 1'b1;
            if(way1_mru[i]) begin
                way1_mru[i] <= 1'b0;
            end
        end
        else if (state[2] &&  rp_way && rb_index == i) begin
            way1_mru[i] <= 1'b1;
            if(way0_mru[i]) begin
                way0_mru[i] <= 1'b0;
            end
        end
    end
end endgenerate

always @(posedge clk) begin
    if (!resetn) begin
        rp_way <= 1'b0;
    end
    else if (state[1] && !cache_hit) begin
        if(!way0_mru[rb_index]) begin
            rp_way <= 1'b0;
        end
        else if(!way1_mru[rb_index]) begin
            rp_way <= 1'b1;
        end
    end
end

// Output
wire [255:0] load_res_final;
wire [255:0] ret_data_final;
assign load_res_final = {256{rb_offset[4:2] == 3'b000}} & load_res |
                        {256{rb_offset[4:2] == 3'b001}} & { 32'b0, load_res[255:32]} |
                        {256{rb_offset[4:2] == 3'b010}} & { 64'b0, load_res[255:64]} |
                        {256{rb_offset[4:2] == 3'b011}} & { 96'b0, load_res[255:96]} |
                        {256{rb_offset[4:2] == 3'b100}} & {128'b0, load_res[255:128]} |
                        {256{rb_offset[4:2] == 3'b101}} & {160'b0, load_res[255:160]} |
                        {256{rb_offset[4:2] == 3'b110}} & {192'b0, load_res[255:192]} |
                        {256{rb_offset[4:2] == 3'b111}} & {224'b0, load_res[255:224]};
assign ret_data_final = {256{rb_offset[4:2] == 3'b000}} & ret_data |
                        {256{rb_offset[4:2] == 3'b001}} & { 32'b0, ret_data[255:32]} |
                        {256{rb_offset[4:2] == 3'b010}} & { 64'b0, ret_data[255:64]} |
                        {256{rb_offset[4:2] == 3'b011}} & { 96'b0, ret_data[255:96]} |
                        {256{rb_offset[4:2] == 3'b100}} & {128'b0, ret_data[255:128]} |
                        {256{rb_offset[4:2] == 3'b101}} & {160'b0, ret_data[255:160]} |
                        {256{rb_offset[4:2] == 3'b110}} & {192'b0, ret_data[255:192]} |
                        {256{rb_offset[4:2] == 3'b111}} & {224'b0, ret_data[255:224]};

assign addr_ok = (state[0] || (state[1] && cache_hit) || (state[5] && ret_valid));
assign data_ok = (state[1]) && cache_hit || 
                 (state[3]) && ret_valid ||
                 (state[5]) && ret_valid;
assign rdata = ({256{state[1]}} & load_res_final) | 
               ({256{state[3]}} & ret_data_final) | 
               ({256{state[5]}} & {224'b0, ret_data[31:0]}); 
assign rnum = (state[5]) ? 4'b1 : {1'b0, ~(rb_offset[4:2])} + 4'b1;

assign rd_req  = (state[4]) || (state[2]);
assign rd_type = (state[4]) ? 1'b0 : 1'b1;  // 0 for uncache; 1 for cache line
assign rd_addr = (state[4]) ? {rb_tag, rb_index, rb_offset} : {rb_tag, rb_index, 5'b0};

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
        if (ret_valid && (valid && !uncache && addr_ok)) begin
			next_state = `LOOKUP;
		end
        else if (ret_valid && (valid && uncache && addr_ok)) begin
			next_state = `UREQ;
		end
        else if (ret_valid && !(valid && addr_ok)) begin
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
