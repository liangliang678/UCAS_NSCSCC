`define IDLE          2'b01
`define HIT           2'b10

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
    output          axi_rd_type,
    output  [ 31:0] axi_rd_addr,
    input           axi_rd_rdy,
    input           axi_ret_valid,
    input   [255:0] axi_ret_data
);

// Buffer
reg [127:0] buffer;
reg [ 31:0] addr;
reg         valid;

always @(posedge clk) begin
    if(!resetn) begin
        addr <= 32'b0;
    end
    else if (axi_rd_req && axi_rd_rdy) begin
        addr <= axi_rd_addr + 32'd16;
    end
end

always @(posedge clk) begin
    if(!resetn) begin
        buffer <= 127'b0;
    end
    else if (axi_ret_valid) begin
        buffer <= axi_ret_data[255:128];
    end
end

always @(posedge clk) begin
    if(!resetn) begin
        valid <= 1'b0;
    end
    else if (axi_rd_req && axi_rd_rdy) begin
        valid <= 1'b0;
    end
    else if (axi_ret_valid) begin
        valid <= 1'b1;
    end
end

wire buffer_hit;
assign buffer_hit = cache_rd_req && (cache_rd_addr == addr);

// FSM
reg [1:0] state;
reg [1:0] next_state;

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
        if (buffer_hit) begin
            next_state = `HIT;
        end
		else begin
			next_state = `IDLE;
		end
	`HIT:
        if (valid) begin
			next_state = `IDLE;
		end
        else begin
			next_state = `HIT;
		end
	default:
		next_state = `IDLE;
	endcase
end

assign axi_rd_req = buffer_hit ? 1'b0 : cache_rd_req;
assign axi_rd_type = cache_rd_type;
assign axi_rd_addr = cache_rd_addr;
assign cache_rd_rdy = buffer_hit ? 1'b1 : axi_rd_rdy;
assign cache_ret_valid = (state == `HIT) ? valid : axi_ret_valid;
assign cache_ret_data = (state == `HIT) ? buffer : axi_ret_data[127:0];
    
endmodule
