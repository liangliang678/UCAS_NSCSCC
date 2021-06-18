`define IDLE          5'b00001
`define HIT           5'b00010
`define MISS          5'b00100
`define FILL          5'b01000
`define UNCACHE       5'b10000

module prefetcher (
    input           clk,
    input           resetn,
    // Dcache
    input           cache_rd_req,
    input           cache_rd_type,
    input   [ 31:0] cache_rd_addr,
    output          cache_rd_rdy,
    output          cache_ret_valid,
    output  [127:0] cache_ret_data,
    // AXI
    output          axi_rd_req,
    output  [  1:0] axi_rd_type,
    output  [ 31:0] axi_rd_addr,
    input           axi_rd_rdy,
    input           axi_ret_valid,
    input   [255:0] axi_ret_data,
    input           axi_ret_half
);

// Buffer
reg [127:0] buffer;
reg [ 31:0] addr;
reg [ 31:0] req_addr;

always @(posedge clk) begin
    if(!resetn) begin
        req_addr <= 32'b0;
    end
    else if (axi_rd_req && axi_rd_rdy && buffer_hit) begin
        req_addr <= axi_rd_addr;
    end
    else if (axi_rd_req && axi_rd_rdy && buffer_miss) begin
        req_addr <= axi_rd_addr + 32'd16;
    end
end

always @(posedge clk) begin
    if(!resetn) begin
        buffer <= 127'b0;
    end
    else if ((state == `FILL) && axi_ret_valid) begin
        buffer <= axi_ret_data[255:128];
    end
    else if ((state == `HIT) && axi_ret_valid) begin
        buffer <= axi_ret_data[127:0];
    end
end

always @(posedge clk) begin
    if(!resetn) begin
        addr <= 32'b0;
    end
    else if ((state == `FILL) && axi_ret_valid) begin
        addr <= req_addr;
    end
    else if ((state == `HIT) && axi_ret_valid) begin
        addr <= req_addr;
    end
end

wire buffer_hit;
wire buffer_miss;
wire uncache_req;
assign buffer_hit  = cache_rd_req && (cache_rd_type == 1'b1) && (cache_rd_addr == addr);
assign buffer_miss = cache_rd_req && (cache_rd_type == 1'b1) && (cache_rd_addr != addr);
assign uncache_req = cache_rd_req && (cache_rd_type == 1'b0);

reg [127:0] ret_data;
reg         ret_valid;

always @(posedge clk) begin
    if(!resetn) begin
        ret_data <= 127'b0;
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
    else if (ret_valid == 1'b1) begin
        ret_valid <= 1'b0;
    end
end

assign axi_rd_req = (state == `IDLE) && cache_rd_req;
assign axi_rd_type = buffer_miss ? 2'b10 : {1'b0, cache_rd_type};
assign axi_rd_addr = buffer_hit ? (cache_rd_addr + 32'd16) :cache_rd_addr;
assign cache_rd_rdy = (state == `IDLE) && axi_rd_rdy;
assign cache_ret_valid = (state == `HIT)     && ret_valid    ||
                         (state == `MISS)    && axi_ret_half ||
                         (state == `UNCACHE) && axi_ret_valid;
assign cache_ret_data = (state == `HIT) ? ret_data : axi_ret_data[127:0];

// FSM
reg [4:0] state;
reg [4:0] next_state;

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
        if (axi_ret_valid) begin
			next_state = `IDLE;
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
