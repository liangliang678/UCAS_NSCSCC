`define IDLE          6'b000001
`define HIT           6'b000010
`define BAD           6'b000100
`define MISS          6'b001000
`define FILL          6'b010000
`define UNCACHE       6'b100000

module prefetcher0 (
    input           clk,
    input           resetn,
    // Dcache
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

assign axi_rd_req = cache_rd_req;
assign axi_rd_type = {1'b0, cache_rd_type};
assign axi_rd_addr = cache_rd_addr;
assign cache_rd_rdy = axi_rd_rdy;
assign cache_ret_valid = axi_ret_valid;
assign cache_ret_data = axi_ret_data[255:0];
    
endmodule
