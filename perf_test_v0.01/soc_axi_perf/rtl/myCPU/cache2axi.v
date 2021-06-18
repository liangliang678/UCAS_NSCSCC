`define AR_IDLE          2'b01
`define AR_SEND_REQ      2'b10

`define W_IDLE           4'b0001
`define W_RECV_REQ       4'b0010
`define W_SEND_ADDR      4'b0100
`define W_SEND_DATA      4'b1000

`define B_IDLE           2'b01
`define B_RESP           2'b10

module cache2axi(
    input           clk,
    input           resetn,
    // inst cache interface - slave
    input           inst_rd_req,
    input   [  1:0] inst_rd_type,
    input   [ 31:0] inst_rd_addr,
    output          inst_rd_rdy,
    output          inst_ret_valid,
    output  [255:0] inst_ret_data,
    // for prefetcher
    output          inst_ret_half,
    // data cache interface - slave
    input           data_rd_req,
    input           data_rd_type,
    input   [ 31:0] data_rd_addr,
    input   [  2:0] data_rd_size,
    output          data_rd_rdy,
    output          data_ret_valid,
    output  [127:0] data_ret_data,

    input           data_wr_req,
    input           data_wr_type,
    input   [ 31:0] data_wr_addr,
    input   [  2:0] data_wr_size,
    input   [  3:0] data_wr_wstrb,
    input   [127:0] data_wr_data,
    output          data_wr_rdy,
    output          data_wr_ok,
    // axi interface - master
    // read request
    output [ 3:0] axi_arid,
    output [31:0] axi_araddr,
    output [ 7:0] axi_arlen,    // len = axi_arlen + 1 (words)
    output [ 2:0] axi_arsize,   // size = 2 ^ axi_arsize (bytes)
    output [ 1:0] axi_arburst,
    output [ 1:0] axi_arlock,
    output [ 3:0] axi_arcache,
    output [ 2:0] axi_arprot,
    output        axi_arvalid,
    input         axi_arready,
    // read response
    input  [ 3:0] axi_rid,
    input  [31:0] axi_rdata,
    input  [ 1:0] axi_rresp,
    input         axi_rlast,
    input         axi_rvalid,
    output        axi_rready,
    // write request
    output [ 3:0] axi_awid,
    output [31:0] axi_awaddr,
    output [ 7:0] axi_awlen,
    output [ 2:0] axi_awsize,
    output [ 1:0] axi_awburst,
    output [ 1:0] axi_awlock,
    output [ 3:0] axi_awcache,
    output [ 2:0] axi_awprot,
    output        axi_awvalid,
    input         axi_awready,
    // write data
    output [ 3:0] axi_wid,
    output [31:0] axi_wdata,
    output [ 3:0] axi_wstrb,
    output        axi_wlast,
    output        axi_wvalid,
    input         axi_wready,
    // write response
    input  [ 3:0] axi_bid,
    input  [ 1:0] axi_bresp,
    input         axi_bvalid,
    output        axi_bready
);

reg [1:0] ar_state;
reg [4:0] w_state;
reg [1:0] b_state;
reg [1:0] ar_next_state;
reg [4:0] w_next_state;
reg [1:0] b_next_state;

// AR
reg  [ 3:0] arid;
reg  [31:0] araddr;
reg  [ 7:0] arlen;
reg  [ 2:0] arsize;

assign axi_arid    = arid;
assign axi_araddr  = araddr;
assign axi_arlen   = arlen;
assign axi_arsize  = arsize;
assign axi_arburst = 2'b1;
assign axi_arlock  = 2'b0;
assign axi_arcache = 4'b0;
assign axi_arprot  = 3'b0;
assign axi_arvalid = (ar_state == `AR_SEND_REQ);

always @(posedge clk) begin
    if (!resetn) begin
        ar_state <= `AR_IDLE;
    end
    else begin
        ar_state <= ar_next_state; 
    end
end
always @(*) begin
    case(ar_state)
    `AR_IDLE:
        if (data_rd_req && data_rd_rdy) begin
            ar_next_state = `AR_SEND_REQ;
        end
        else if (inst_rd_req && inst_rd_rdy) begin
            ar_next_state = `AR_SEND_REQ;
        end
        else begin
            ar_next_state = `AR_IDLE;
        end
    `AR_SEND_REQ:
        if (axi_arvalid && axi_arready) begin
            ar_next_state = `AR_IDLE;
        end 
        else begin
            ar_next_state = `AR_SEND_REQ;
        end
    default:
        ar_next_state = `AR_IDLE;
    endcase
end

always @(posedge clk) begin
    if (!resetn) begin
        arid <= 4'b0;
    end 
    else if (data_rd_req && data_rd_rdy) begin
        arid <= 4'b1;
    end 
    else if (inst_rd_req && inst_rd_rdy) begin
        arid <= 4'b0;
    end
end

always @(posedge clk) begin
    if (!resetn) begin
        araddr <= 32'b0;
    end 
    else if (data_rd_req && data_rd_rdy) begin
        araddr <= data_rd_addr;
    end 
    else if (inst_rd_req && inst_rd_rdy) begin
        araddr <= inst_rd_addr;
    end
end

always @(posedge clk) begin
    if (!resetn) begin
        arlen <= 4'b0;
    end 
    else if (data_rd_req && data_rd_rdy) begin
        if (data_rd_type == 1'b0)
            arlen <= 4'd0;
        else if (data_rd_type == 1'b1)
            arlen <= 4'd3;
    end 
    else if (inst_rd_req && inst_rd_rdy) begin
        if (inst_rd_type == 2'b00)
            arlen <= 4'd0;
        else if (inst_rd_type == 2'b01)
            arlen <= 4'd3;
        else if (inst_rd_type == 2'b10)
            arlen <= 4'd7;
    end
end

always @(posedge clk) begin
    if (!resetn) begin
        arsize <= 3'b0;
    end 
    else if (data_rd_req && data_rd_rdy) begin
        arsize <= data_rd_size;
    end 
    else if (inst_rd_req && inst_rd_rdy) begin
        arsize <= 3'd2;
    end
end

assign inst_rd_rdy = (ar_state == `AR_IDLE);
assign data_rd_rdy = (ar_state == `AR_IDLE);

// R
reg [127:0] data_rdata;
reg [  1:0] data_rcount;
reg [255:0] inst_rdata;
reg [  2:0] inst_rcount;

assign axi_rready = 1'b1;

always @(posedge clk) begin
    if (!resetn) begin
        data_rcount <= 2'b0;
    end 
    else if (axi_rready && axi_rvalid && axi_rid == 1'b1) begin
        if (axi_rlast) begin
            data_rcount <= 2'b0;
        end
        else begin
            data_rcount <= data_rcount + 2'b1;
        end
    end
end

always @(posedge clk) begin
    if (!resetn) begin
        data_rdata <= 128'b0;
    end 
    else if (axi_rready && axi_rvalid && axi_rid == 1'b1) begin
        data_rdata[data_rcount*32 +: 32] <= axi_rdata;
    end
end

always @(posedge clk) begin
    if (!resetn) begin
        inst_rcount <= 2'b0;
    end 
    else if (axi_rready && axi_rvalid && axi_rid == 1'b0) begin
        if (axi_rlast) begin
            inst_rcount <= 2'b0;
        end
        else begin
            inst_rcount <= inst_rcount + 2'b1;
        end
    end
end

always @(posedge clk) begin
    if (!resetn) begin
        inst_rdata <= 128'b0;
    end 
    else if (axi_rready && axi_rvalid && axi_rid == 1'b0) begin
        inst_rdata[inst_rcount*32 +: 32] <= axi_rdata;
    end
end

// to cache
reg to_icache_valid;
reg to_dcache_valid;
reg to_icache_half;
always @(posedge clk) begin
    if (!resetn) begin
        to_icache_valid <= 1'b0;
    end
    else if (axi_rready && axi_rvalid && axi_rlast && axi_rid == 4'b0) begin
        to_icache_valid <= 1'b1;
    end
    else if (to_icache_valid == 1'b1) begin
        to_icache_valid <= 1'b0;
    end
end 
always @(posedge clk) begin
    if (!resetn) begin
        to_dcache_valid <= 1'b0;
    end
    else if (axi_rready && axi_rvalid && axi_rlast && axi_rid == 4'b1) begin
        to_dcache_valid <= 1'b1;
    end
    else if (to_dcache_valid == 1'b1) begin
        to_dcache_valid <= 1'b0;
    end
end
always @(posedge clk) begin
    if (!resetn) begin
        to_icache_half <= 1'b0;
    end
    else if (axi_rready && axi_rvalid && inst_rcount == 3'd4 && axi_rid == 4'b0) begin
        to_icache_half <= 1'b1;
    end
    else if (to_icache_half == 1'b1) begin
        to_icache_half <= 1'b0;
    end
end 

assign inst_ret_valid = to_icache_valid;
assign data_ret_valid = to_dcache_valid;
assign inst_ret_half = to_icache_half;
assign inst_ret_data = inst_rdata;
assign data_ret_data = data_rdata;

// W
reg  [31:0] awaddr;
reg  [ 7:0] awlen;
reg  [ 2:0] awsize;
reg  [ 3:0] wstrb;

reg  [ 1:0] wcount;
reg [127:0] cache_data;

assign axi_awid    = 4'b1;
assign axi_awaddr  = awaddr;
assign axi_awlen   = awlen;
assign axi_awsize  = awsize;
assign axi_awburst = 2'b1;
assign axi_awlock  = 2'b0;
assign axi_awcache = 4'b0;
assign axi_awprot  = 3'b0;
assign axi_awvalid = (w_state == `W_SEND_ADDR);

assign axi_wid     = 4'b1;
assign axi_wdata   = cache_data[wcount*32 +: 32];
assign axi_wstrb   = wstrb;
assign axi_wlast   = (w_state == `W_SEND_DATA) && (awlen == wcount);
assign axi_wvalid  = (w_state == `W_SEND_DATA);

always @(posedge clk) begin
    if (!resetn) begin
        w_state <= `W_IDLE;
    end else begin
        w_state <= w_next_state; 
    end
end

always @(*) begin
    case(w_state)
        `W_IDLE:
            if (data_wr_req && data_wr_rdy) begin
                w_next_state = `W_RECV_REQ;
            end else begin
                w_next_state = `W_IDLE;
            end
        `W_RECV_REQ:
            w_next_state = `W_SEND_ADDR;
        `W_SEND_ADDR:
            if (axi_awvalid && axi_awready) begin
                w_next_state = `W_SEND_DATA;
            end else begin
                w_next_state = `W_SEND_ADDR;
            end
        `W_SEND_DATA:
            if (axi_wvalid && axi_wready && axi_wlast) begin
                w_next_state = `W_IDLE;
            end else begin
                w_next_state = `W_SEND_DATA;
            end
    endcase
end

always @(posedge clk) begin
    if (!resetn) begin
        awaddr <= 32'b0;
    end else if (data_wr_req && data_wr_rdy) begin
        awaddr <= data_wr_addr;
    end
end

always @(posedge clk) begin
    if (!resetn) begin
        awlen <= 8'b0;
    end else if (data_wr_req && data_wr_rdy) begin
        if (data_wr_type == 1'b0)
            awlen <= 8'd0;
        else if (data_wr_type == 1'b1)
            awlen <= 8'd3;
    end
end

always @(posedge clk) begin
    if (!resetn) begin
        wstrb <= 4'b0;
    end else if (data_wr_req && data_wr_rdy) begin
        if (data_wr_type == 1'b0)
            wstrb <= data_wr_wstrb;
        else if (data_wr_type == 1'b1)
            wstrb <= 4'b1111;
    end
end

always @(posedge clk) begin
    if (!resetn) begin
        awsize <= 3'b0;
    end else if (data_wr_req && data_wr_rdy) begin
        if (data_wr_type == 1'b0)
            awsize <= data_wr_size;
        else if (data_wr_type == 1'b1)
            awsize <= 3'd2;
    end
end

always @(posedge clk) begin
    if (data_wr_req && data_wr_rdy) begin
        cache_data <= data_wr_data;
    end
end

always @(posedge clk) begin
    if (!resetn) begin
        wcount <= 2'b0;
    end else if (w_state == `W_IDLE) begin
        wcount <= 2'b0;
    end else if (axi_wvalid && axi_wready) begin
        wcount <= wcount + 2'b1;
    end
end

// B
assign axi_bready = (b_state == `B_IDLE);

always @(posedge clk) begin
    if (!resetn) begin
        b_state <= `B_IDLE;
    end else begin
        b_state <= b_next_state; 
    end
end

always @(*) begin
    case(b_state)
        `B_IDLE:
            if (axi_bready && axi_bvalid) begin
                b_next_state = `B_RESP;
            end else begin
                b_next_state = `B_IDLE;
            end
        `B_RESP:
            b_next_state = `B_IDLE;
    endcase
end

// to cache
assign data_wr_rdy = (w_state == `W_IDLE);
assign data_wr_ok = (b_state == `B_RESP);

endmodule
