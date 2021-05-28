`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/11/11 18:31:56
// Design Name: 
// Module Name: bridge_axi_1x2_sram
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module bridge_axi_1x2_sram(
    input         clk,
    input         resetn,
    // inst sram interface - slave
    input         inst_sram_req,
    input         inst_sram_wr,
    input  [ 1:0] inst_sram_size,
    input  [31:0] inst_sram_addr,
    input  [ 3:0] inst_sram_wstrb,
    input  [31:0] inst_sram_wdata,
    output [31:0] inst_sram_rdata,
    output        inst_sram_addr_ok,
    output        inst_sram_data_ok,
    // data sram interface - slave
    input         data_sram_req,
    input         data_sram_wr,
    input  [ 1:0] data_sram_size,
    input  [31:0] data_sram_addr,
    input  [ 3:0] data_sram_wstrb,
    input  [31:0] data_sram_wdata,
    output [31:0] data_sram_rdata,
    output        data_sram_addr_ok,
    output        data_sram_data_ok,
    // axi interface - master
    // read request
    output [ 3:0] axi_arid,
    output [31:0] axi_araddr,
    output [ 7:0] axi_arlen,
    output [ 2:0] axi_arsize,
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
    
    reg         r_stall;
    reg         w_stall;

    // AR
    reg  [ 3:0] arid;
    reg  [31:0] araddr;
    reg  [ 2:0] arsize;

    assign axi_arid    = arid;
    assign axi_araddr  = araddr;
    assign axi_arlen   = 8'b0;
    assign axi_arsize  = arsize;
    assign axi_arburst = 2'b1;
    assign axi_arlock  = 2'b0;
    assign axi_arcache = 4'b0;
    assign axi_arprot  = 3'b0;
    assign axi_arvalid = ar_state[`AR_REQ];

    always @(posedge clk) begin
        if (!resetn) begin
            ar_state <= `S_AR_IDLE;
        end else begin
            ar_state <= ar_next_state; 
        end
    end

    always @(*) begin
        case(ar_state)
            `S_AR_IDLE:begin
                if (data_sram_req && ~data_sram_wr && ~r_stall) begin
                    ar_next_state = `S_AR_DATA_OK;
                end else if (inst_sram_req && ~inst_sram_wr && !(data_sram_req && ~data_sram_wr && ~data_sram_wr) && ~r_stall) begin
                    ar_next_state = `S_AR_INST_OK;
                end else begin
                    ar_next_state = `S_AR_IDLE;
                end
            end
            `S_AR_DATA_OK:begin
                if (data_sram_req && data_sram_addr_ok && ~data_sram_wr) begin
                    ar_next_state = `S_AR_REQ;
                end else begin
                    ar_next_state = `S_AR_IDLE;
                end
            end
            `S_AR_INST_OK:begin
                if (inst_sram_req && inst_sram_addr_ok) begin
                    ar_next_state = `S_AR_REQ;
                end else begin
                    ar_next_state = `S_AR_IDLE;
                end
            end
            `S_AR_REQ:begin
                if (axi_arvalid && axi_arready) begin
                    ar_next_state = `S_AR_IDLE;
                end else begin
                    ar_next_state = `S_AR_REQ;
                end
            end
        endcase
    end

    always @(posedge clk) begin
        if (!resetn) begin
            arid <= 4'b0;
        end else if (data_sram_req && data_sram_addr_ok && ~data_sram_wr) begin
            arid <= 4'b1;
        end else if (inst_sram_req && inst_sram_addr_ok) begin
            arid <= 4'b0;
        end
    end

    always @(posedge clk) begin
        if (!resetn) begin
            araddr <= 32'b0;
        end else if (data_sram_req && data_sram_addr_ok && ~data_sram_wr) begin
            araddr <= data_sram_addr;
        end else if (inst_sram_req && inst_sram_addr_ok) begin
            araddr <= inst_sram_addr;
        end
    end

    always @(posedge clk) begin
        if (!resetn) begin
            arsize <= 3'b0;
        end else if (data_sram_req && data_sram_addr_ok && ~data_sram_wr) begin
            arsize <= data_sram_size;
        end else if (inst_sram_req && inst_sram_addr_ok) begin
            arsize <= data_sram_size;
        end
    end

    // R
    reg  [31:0] rdata;

    assign axi_rready = r_state[`R_IDLE];

    always @(posedge clk) begin
        if (!resetn) begin
            r_state <= `S_R_IDLE;
        end else begin
            r_state <= r_next_state; 
        end
    end

    always @(*) begin
        case(r_state)
            `S_R_IDLE:begin
                if (axi_rready && axi_rvalid && axi_rid == 4'b0) begin
                    r_next_state = `S_R_INST_RESP;
                end else if (axi_rready && axi_rvalid && axi_rid == 4'b1) begin
                    r_next_state = `S_R_DATA_RESP;
                end else begin
                    r_next_state = `S_R_IDLE;
                end
            end
            `S_R_INST_RESP:begin
                r_next_state = `S_R_IDLE;
            end
            `S_R_DATA_RESP:begin
                r_next_state = `S_R_IDLE;
            end
        endcase
    end

    always @(posedge clk) begin
        if (!resetn) begin
            rdata <= 32'b0;
        end else if (axi_rready && axi_rvalid) begin
            rdata <= axi_rdata;
        end
    end
    
    // W
    reg  [31:0] awaddr;
    reg  [ 2:0] awsize;
    reg  [31:0] wdata;
    reg  [ 3:0] wstrb;

    assign axi_awid    = 4'b1;
    assign axi_awaddr  = awaddr;
    assign axi_awlen   = 8'b0;
    assign axi_awsize  = awsize;
    assign axi_awburst = 2'b1;
    assign axi_awlock  = 2'b0;
    assign axi_awcache = 4'b0;
    assign axi_awprot  = 3'b0;
    assign axi_awvalid = w_state[`W_REQ] | w_state[`W_ADDR_REQ];

    assign axi_wid     = 4'b1;
    assign axi_wdata   = wdata;
    assign axi_wstrb   = wstrb;
    assign axi_wlast   = 1'b1;
    assign axi_wvalid  = w_state[`W_REQ] | w_state[`W_DATA_REQ];

    always @(posedge clk) begin
        if (!resetn) begin
            w_state <= `S_W_IDLE;
        end else begin
            w_state <= w_next_state; 
        end
    end

    always @(*) begin
        case(w_state)
            `S_W_IDLE:begin
                if (data_sram_req && data_sram_wr && ~w_stall) begin
                    w_next_state = `S_W_REQ_OK;
                end else begin
                    w_next_state = `S_W_IDLE;
                end
            end
            `S_W_REQ_OK:begin
                if (data_sram_req && data_sram_addr_ok && data_sram_wr) begin
                    w_next_state = `S_W_REQ;
                end else begin
                    w_next_state = `S_W_IDLE;
                end
            end
            `S_W_REQ:begin
                if (axi_awvalid && axi_awready && axi_wvalid && axi_wready) begin
                    w_next_state = `S_W_IDLE;
                end else if (axi_awvalid && axi_awready && !(axi_wvalid && axi_wready)) begin
                    w_next_state = `S_W_DATA_REQ;
                end else if (axi_wvalid && axi_wready && !(axi_awvalid && axi_awready)) begin
                    w_next_state = `S_W_ADDR_REQ;
                end else begin
                    w_next_state = `S_W_REQ;
                end
            end
            `S_W_ADDR_REQ:begin
                if (axi_awvalid && axi_awready) begin
                    w_next_state = `S_W_IDLE;
                end else begin
                    w_next_state = `S_W_ADDR_REQ;
                end
            end
            `S_W_DATA_REQ:begin
                if (axi_wvalid && axi_wready) begin
                    w_next_state = `S_W_IDLE;
                end else begin
                    w_next_state = `S_W_DATA_REQ;
                end
            end
        endcase
    end

    always @(posedge clk) begin
        if (!resetn) begin
            awaddr <= 32'b0;
        end else if (data_sram_req && data_sram_addr_ok && data_sram_wr) begin
            awaddr <= data_sram_addr;
        end
    end

    always @(posedge clk) begin
        if (!resetn) begin
            awsize <= 3'b0;
        end else if (data_sram_req && data_sram_addr_ok && data_sram_wr) begin
            awsize <= data_sram_size;
        end
    end

    always @(posedge clk) begin
        if (!resetn) begin
            wstrb <= 4'b0;
        end else if (data_sram_req && data_sram_addr_ok && data_sram_wr) begin
            wstrb <= data_sram_wstrb;
        end
    end

    always @(posedge clk) begin
        if (!resetn) begin
            wdata <= 32'b0;
        end else if (data_sram_req && data_sram_addr_ok && data_sram_wr) begin
            wdata <= data_sram_wdata;
        end
    end

    // B
    assign axi_bready = b_state[`B_IDLE];

    always @(posedge clk) begin
        if (!resetn) begin
            b_state <= `S_B_IDLE;
        end else begin
            b_state <= b_next_state; 
        end
    end

    always @(*) begin
        case(b_state)
            `S_B_IDLE:begin
                if (axi_bready && axi_bvalid) begin
                    b_next_state = `S_B_RESP;
                end else begin
                    b_next_state = `S_B_IDLE;
                end
            end
            `S_B_RESP:begin
                b_next_state = `S_R_IDLE;
            end
        endcase
    end


    assign inst_sram_addr_ok = ar_state[`AR_INST_OK];
    assign inst_sram_data_ok = r_state[`R_INST_RESP];
    assign inst_sram_rdata   = rdata;

    assign data_sram_addr_ok = ar_state[`AR_DATA_OK] | w_state[`W_REQ_OK];
    assign data_sram_data_ok = r_state[`R_DATA_RESP] | b_state[`B_RESP];
    assign data_sram_rdata   = rdata;

    always @(posedge clk) begin
        if (!resetn) begin
            r_stall <= 1'b0;
        end else if (data_sram_req && data_sram_addr_ok && data_sram_wr) begin
            r_stall <= 1'b1;
        end else if (axi_bready && axi_bvalid) begin
            r_stall <= 1'b0;
        end
    end

    always @(posedge clk) begin
        if (!resetn) begin
            w_stall <= 1'b0;
        end else if (data_sram_req && data_sram_addr_ok && ~data_sram_wr) begin
            w_stall <= 1'b1;
        end else if (axi_rready && axi_rvalid && axi_rid == 4'b1) begin
            w_stall <= 1'b0;
        end
    end

/* data relevant
    reg  [ 3:0] tag;
    reg  [31:0] addr_buffer [3:0];
    wire        relevant_stall;
    reg  [ 1:0] data_req_way;
    reg  [ 1:0] data_ok_way;

    assign relevant_stall = (tag[0] && (axi_araddr == addr_buffer[0])) ||
                            (tag[1] && (axi_araddr == addr_buffer[1])) ||
                            (tag[2] && (axi_araddr == addr_buffer[2])) ||
                            (tag[3] && (axi_araddr == addr_buffer[3]));

    always @(posedge clk) begin
        if (!resetn) begin
            data_req_way <= 2'b0;
        end else if (w_state[`W_REQ_OK]) begin
            data_req_way <= data_req_way + 1;
        end
    end

    always @(posedge clk) begin
        if (!resetn) begin
            data_ok_way <= 2'b0;
        end else if (b_state[`B_RESP]) begin
            data_ok_way <= data_ok_way + 1;
        end
    end

    always @(posedge clk) begin
        if (!resetn) begin
            tag <= 4'b0;
        end else if (w_state[`W_REQ_OK]) begin
            tag[data_req_way]         <= 1'b1;
            addr_buffer[data_req_way] <= awaddr;
        end else if (b_state[`B_RESP]) begin
            tag[data_ok_way]          <= 1'b0;
        end
    end
*/

endmodule
