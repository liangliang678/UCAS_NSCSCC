`define AR_IDLE          4'b0001
`define AR_RECV_INST     4'b0010
`define AR_RECV_DATA     4'b0100
`define AR_SEND_REQ      4'b1000

`define R_IDLE           3'b001
`define R_INST_RESP      3'b010
`define R_DATA_RESP      3'b100

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
    input   [  2:0] inst_rd_type,
    input   [ 31:0] inst_rd_addr,
    output          inst_rd_rdy,
    output          inst_ret_valid,
    output  [127:0] inst_ret_data,
    // data cache interface - slave
    input           data_rd_req,
    input   [  2:0] data_rd_type,
    input   [ 31:0] data_rd_addr,
    output          data_rd_rdy,
    output          data_ret_valid,
    output  [127:0] data_ret_data,

    input           data_wr_req,
    input   [  2:0] data_wr_type,
    input   [ 31:0] data_wr_addr,
    input   [  3:0] data_wr_wstrb,
    input   [127:0] data_wr_data,
    output          data_wr_rdy,
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

    reg    [ 3:0] ar_state;
    reg    [ 2:0] r_state;
    reg    [ 4:0] w_state;
    reg    [ 1:0] b_state;
    reg    [ 3:0] ar_next_state;
    reg    [ 2:0] r_next_state;
    reg    [ 4:0] w_next_state;
    reg    [ 1:0] b_next_state;
    
    // 为避免RAW，读写不能并行
    reg         r_stall;
    reg         w_stall;

    always @(posedge clk) begin
        if (!resetn) begin
            r_stall <= 1'b0;
        end else if (data_wr_req && data_wr_rdy) begin
            r_stall <= 1'b1;
        end else if (axi_bready && axi_bvalid) begin
            r_stall <= 1'b0;
        end
    end

    always @(posedge clk) begin
        if (!resetn) begin
            w_stall <= 1'b0;
        end else if (data_rd_req && data_rd_rdy) begin
            w_stall <= 1'b1;
        end else if (axi_rready && axi_rvalid && axi_rid == 4'b1) begin
            w_stall <= 1'b0;
        end
    end

    // AR
    reg  [ 3:0] arid;
    reg  [31:0] araddr;
    reg  [ 7:0] arlen;

    assign axi_arid    = arid;
    assign axi_araddr  = araddr;
    assign axi_arlen   = arlen;
    assign axi_arsize  = 3'd2;
    assign axi_arburst = 2'b1;
    assign axi_arlock  = 2'b0;
    assign axi_arcache = 4'b0;
    assign axi_arprot  = 3'b0;
    assign axi_arvalid = (ar_state == `AR_SEND_REQ);

    always @(posedge clk) begin
        if (!resetn) begin
            ar_state <= `AR_IDLE;
        end else begin
            ar_state <= ar_next_state; 
        end
    end

    always @(*) begin
        case(ar_state)
            `AR_IDLE:
                if (data_rd_req && data_rd_rdy && ~r_stall) begin
                    ar_next_state = `AR_RECV_DATA;
                end else if (inst_rd_req && inst_rd_rdy && ~r_stall) begin
                    ar_next_state = `AR_RECV_INST;
                end else begin
                    ar_next_state = `AR_IDLE;
                end
            `AR_RECV_DATA:
                ar_next_state = `AR_SEND_REQ;
            `AR_RECV_INST:
                ar_next_state = `AR_SEND_REQ;
            `AR_SEND_REQ:
                if (axi_arvalid && axi_arready) begin
                    ar_next_state = `AR_IDLE;
                end else begin
                    ar_next_state = `AR_SEND_REQ;
                end
        endcase
    end

    always @(posedge clk) begin
        if (!resetn) begin
            arid <= 4'b0;
        end else if (data_rd_req && data_rd_rdy) begin
            arid <= 4'b1;
        end else if (inst_rd_req && inst_rd_rdy) begin
            arid <= 4'b0;
        end
    end

    always @(posedge clk) begin
        if (!resetn) begin
            araddr <= 32'b0;
        end else if (data_rd_req && data_rd_rdy) begin
            araddr <= data_rd_addr;
        end else if (inst_rd_req && inst_rd_rdy) begin
            araddr <= inst_rd_addr;
        end
    end

    always @(posedge clk) begin
        if (!resetn) begin
            arlen <= 4'b0;
        end else if (data_rd_req && data_rd_rdy) begin
            if (data_rd_type == 3'b010)
                arlen <= 4'd0;
            else if (data_rd_type == 3'b100)
                arlen <= 4'd3;
        end else if (inst_rd_req && inst_rd_rdy) begin
            if (inst_rd_type == 3'b010)
                arlen <= 4'd0;
            else if (inst_rd_type == 3'b100)
                arlen <= 4'd3;
        end
    end

    // R
    reg [127:0] rdata;
    reg [  1:0] rcount;

    assign axi_rready = 1'b1;

    always @(posedge clk) begin
        if (!resetn) begin
            r_state <= `R_IDLE;
        end else begin
            r_state <= r_next_state; 
        end
    end

    always @(*) begin
        case(r_state)
            `R_IDLE:
                if (axi_rready && axi_rvalid && axi_rid == 4'b0) begin
                    r_next_state = `R_INST_RESP;
                end else if (axi_rready && axi_rvalid && axi_rid == 4'b1) begin
                    r_next_state = `R_DATA_RESP;
                end else begin
                    r_next_state = `R_IDLE;
                end
            `R_INST_RESP:
                if (axi_rready && axi_rvalid && axi_rlast) begin
                    r_next_state = `R_IDLE;
                end else begin
                    r_next_state = `R_INST_RESP;
                end
            `R_DATA_RESP:
                if (axi_rready && axi_rvalid && axi_rlast) begin
                    r_next_state = `R_IDLE;
                end else begin
                    r_next_state = `R_DATA_RESP;
                end
        endcase
    end

    always @(posedge clk) begin
        if (!resetn) begin
            rcount <= 2'b0;
        end else if (r_state == `R_IDLE) begin
            rcount <= 2'b0;
        end else if (axi_rready && axi_rvalid) begin
            rcount <= rcount + 2'b1;
        end
    end

    always @(posedge clk) begin
        if (!resetn) begin
            rdata <= 128'b0;
        end else if (axi_rready && axi_rvalid) begin
            rdata[rcount*32 +: 32] <= axi_rdata;
        end
    end

    // to cache
    reg to_icache_valid;
    reg to_dcache_valid;
    always @(posedge clk) begin
        if (!resetn) begin
            to_icache_valid <= 1'b0;
        end
        else if ((r_state == `R_INST_RESP) && axi_rready && axi_rvalid && axi_rlast) begin
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
        else if ((r_state == `R_DATA_RESP) && axi_rready && axi_rvalid && axi_rlast) begin
            to_dcache_valid <= 1'b1;
        end
        else if (to_dcache_valid == 1'b1) begin
            to_dcache_valid <= 1'b0;
        end
    end
    assign inst_rd_rdy = (r_state == `R_IDLE);
    assign data_rd_rdy = (r_state == `R_IDLE);
    assign inst_ret_valid = to_icache_valid;
    assign data_ret_valid = to_icache_valid;
    assign inst_ret_data = rdata;
    assign data_ret_data = rdata;
    
    // W
    reg  [31:0] awaddr;
    reg  [ 7:0] awlen;
    reg  [31:0] wdata;
    reg  [ 3:0] wstrb;

    reg  [ 1:0] wcount;
    reg [127:0] cache_data;

    assign axi_awid    = 4'b1;
    assign axi_awaddr  = awaddr;
    assign axi_awlen   = awlen;
    assign axi_awsize  = 3'd2;
    assign axi_awburst = 2'b1;
    assign axi_awlock  = 2'b0;
    assign axi_awcache = 4'b0;
    assign axi_awprot  = 3'b0;
    assign axi_awvalid = (w_state == `W_SEND_ADDR);

    assign axi_wid     = 4'b1;
    assign axi_wdata   = wdata;
    assign axi_wstrb   = wstrb;
    assign axi_wlast   = (w_state == `W_SEND_DATA) && (awlen == wcount);
    assign axi_awvalid = (w_state == `W_SEND_DATA);

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
            if (data_wr_type == 3'b010)
                awlen <= 8'd0;
            else if (data_wr_type == 3'b100)
                awlen <= 8'd3;
        end
    end

    always @(posedge clk) begin
        if (!resetn) begin
            wdata <= 128'b0;
        end else if (axi_rready && axi_rvalid) begin
            wdata <= cache_data[wcount*32 +: 32];
        end
    end

    always @(posedge clk) begin
        if (!resetn) begin
            wstrb <= 4'b0;
        end else if (data_wr_req && data_wr_rdy) begin
            if (data_wr_type == 3'b010)
                wstrb <= data_wr_wstrb;
            else if (data_wr_type == 3'b100)
                wstrb <= 4'b1111;
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

endmodule
