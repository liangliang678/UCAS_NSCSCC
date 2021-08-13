`define IDLE          6'b000001
`define HIT           6'b000010
`define MISS          6'b000100
`define BAD           6'b001000
`define FILL          6'b010000
`define UNCACHE       6'b100000

module prefetcher1 (
    input           clk,
    input           resetn,
    // icache
    input           cache_rd_req,
    input           cache_rd_type,
    input   [ 31:0] cache_rd_addr,
    output          cache_rd_rdy,
    output          cache_ret_valid,
    output  [255:0] cache_ret_data,
    // AXI
    output          axi_rd_req,
    output  [  1:0] axi_rd_type,
    output  [ 31:0] axi_rd_addr,
    input           axi_rd_rdy,
    input           axi_ret_valid,
    input   [511:0] axi_ret_data,
    input           axi_ret_half
);

// Buffer
reg [ 31:0] req_addr;
reg [255:0] buffer;
reg [ 31:0] addr;

always @(posedge clk) begin
    if(!resetn) begin
        req_addr <= 32'b0;
    end
    else if (axi_rd_req && axi_rd_rdy && buffer_hit) begin
        req_addr <= axi_rd_addr;
    end
    else if (axi_rd_req && axi_rd_rdy && buffer_miss) begin
        req_addr <= axi_rd_addr + 32'd32;
    end
    else if (axi_rd_req && axi_rd_rdy && bad_fill) begin
        req_addr <= axi_rd_addr + 32'd32;
    end
end

always @(posedge clk) begin
    if(!resetn) begin
        buffer <= 256'b0;
    end
    else if (state[4] && axi_ret_valid) begin
        buffer <= axi_ret_data[511:256];
    end
    else if (state[1] && axi_ret_valid) begin
        buffer <= axi_ret_data[255:0];
    end
end

always @(posedge clk) begin
    if(!resetn) begin
        addr <= 32'b0;
    end
    else if (state[4] && axi_ret_valid) begin
        addr <= req_addr;
    end
    else if (state[1] && axi_ret_valid) begin
        addr <= req_addr;
    end
end

// Control
wire buffer_hit;
wire buffer_miss;
wire uncache_req;

assign buffer_hit  = cache_rd_req &&  cache_rd_type && (cache_rd_addr == addr);
assign buffer_miss = cache_rd_req &&  cache_rd_type && (cache_rd_addr != addr);
assign uncache_req = cache_rd_req && !cache_rd_type;

wire bad_fill;
reg bad_fill_r;
assign bad_fill = state[1] && cache_rd_req && cache_rd_type && (cache_rd_addr != req_addr);
always @(posedge clk) begin
    if (!resetn) begin
        bad_fill_r <= 1'b0;
    end
    else if (bad_fill && !axi_rd_rdy) begin
        bad_fill_r <= 1'b1;
    end
    else if (bad_fill_r && axi_rd_rdy) begin
        bad_fill_r <= 1'b0;
    end
end

// Return
reg [255:0] ret_data;
reg         ret_valid;

always @(posedge clk) begin
    if(!resetn) begin
        ret_data <= 256'b0;
    end
    else if (buffer_hit && axi_rd_req && axi_rd_rdy) begin
        ret_data <= buffer;
    end
end

always @(posedge clk) begin
    if(!resetn) begin
        ret_valid <= 1'b0;
    end
    else if (buffer_hit && axi_rd_req && axi_rd_rdy) begin
        ret_valid <= 1'b1;
    end
    else if (ret_valid) begin
        ret_valid <= 1'b0;
    end
end

assign axi_rd_req  = state[0] && cache_rd_req || bad_fill || bad_fill_r;
assign axi_rd_type = (buffer_miss || bad_fill || bad_fill_r) ? 2'b10 : {1'b0, cache_rd_type};   // 2 for double cache line
assign axi_rd_addr = buffer_hit ? (cache_rd_addr + 32'd32) : cache_rd_addr;
assign cache_rd_rdy    = (state[0] || bad_fill || bad_fill_r) && axi_rd_rdy;
assign cache_ret_valid = state[1] && ret_valid    ||
                         state[2] && axi_ret_half ||
                         state[5] && axi_ret_valid;
assign cache_ret_data  = state[1] ? ret_data : axi_ret_data[255:0];

// FSM
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
        if (uncache_req && axi_rd_req && axi_rd_rdy) begin
            next_state = `UNCACHE;
        end
        else if (buffer_hit && axi_rd_req && axi_rd_rdy) begin
            next_state = `HIT;
        end
        else if (buffer_miss && axi_rd_req && axi_rd_rdy) begin
            next_state = `MISS;
        end
		else begin
			next_state = `IDLE;
		end
	`HIT:
        if (axi_ret_valid && bad_fill) begin
			next_state = `MISS;
		end
        else if (axi_ret_valid && !bad_fill) begin
			next_state = `IDLE;
		end
        else if (!axi_ret_valid && bad_fill) begin
            next_state = `BAD;
        end
        else begin
			next_state = `HIT;
		end
    `MISS:
        if (axi_ret_half) begin
            next_state = `FILL;
        end
        else begin
            next_state = `MISS;
        end
    `BAD:
        if (axi_ret_valid) begin
            next_state = `MISS;
        end
        else begin
            next_state = `BAD;
        end
    `FILL:
        if (axi_ret_valid) begin
            next_state = `IDLE;
        end
        else begin
            next_state = `FILL;
        end
    `UNCACHE:
        if (axi_ret_valid) begin
            next_state = `IDLE;
        end
        else begin
            next_state = `UNCACHE;
        end
	default:
		next_state = `IDLE;
	endcase
end
    
endmodule
