module regfile(
    input         clk,
    // READ PORT 1
    input  [ 4:0] raddr_01,
    output [31:0] rdata_01,
    // READ PORT 2
    input  [ 4:0] raddr_02,
    output [31:0] rdata_02,
    // READ PORT 3
    input  [ 4:0] raddr_03,
    output [31:0] rdata_03,
    // READ PORT 4
    input  [ 4:0] raddr_04,
    output [31:0] rdata_04,
    // READ PORT 5
    input  [ 4:0] raddr_05,
    output [31:0] rdata_05,
    // READ PORT 6
    input  [ 4:0] raddr_06,
    output [31:0] rdata_06,
    
    // WRITE PORT 1
    input         we_01,       //write enable, HIGH valid
    input  [ 4:0] waddr_01,
    input  [31:0] wdata_01,
    // WRITE PORT 2
    input         we_02,       //write enable, HIGH valid
    input  [ 4:0] waddr_02,
    input  [31:0] wdata_02
);

reg [31:0] rf[31:0];

//WRITE
// always @(posedge clk) begin
//     if (we_01) rf[waddr_01]<= wdata_01;
//     if (we_02) rf[waddr_02]<= wdata_02;
// end
always @(posedge clk) begin
    if ((waddr_02 == 5'h0) & we_02) rf[0]<= wdata_02;
    else if((waddr_01 == 5'h0) & we_01) rf[0]<= wdata_01;
end

always @(posedge clk) begin
    if ((waddr_02 == 5'h1) & we_02) rf[1]<= wdata_02;
    else if((waddr_01 == 5'h1) & we_01) rf[1]<= wdata_01;
end

always @(posedge clk) begin
    if ((waddr_02 == 5'h2) & we_02) rf[2]<= wdata_02;
    else if((waddr_01 == 5'h2) & we_01) rf[2]<= wdata_01;
end

always @(posedge clk) begin
    if ((waddr_02 == 5'h3) & we_02) rf[3]<= wdata_02;
    else if((waddr_01 == 5'h3) & we_01) rf[3]<= wdata_01;
end

always @(posedge clk) begin
    if ((waddr_02 == 5'h4) & we_02) rf[4]<= wdata_02;
    else if((waddr_01 == 5'h4) & we_01) rf[4]<= wdata_01;
end

always @(posedge clk) begin
    if ((waddr_02 == 5'h5) & we_02) rf[5]<= wdata_02;
    else if((waddr_01 == 5'h5) & we_01) rf[5]<= wdata_01;
end

always @(posedge clk) begin
    if ((waddr_02 == 5'h6) & we_02) rf[6]<= wdata_02;
    else if((waddr_01 == 5'h6) & we_01) rf[6]<= wdata_01;
end

always @(posedge clk) begin
    if ((waddr_02 == 5'h7) & we_02) rf[7]<= wdata_02;
    else if((waddr_01 == 5'h7) & we_01) rf[7]<= wdata_01;
end

always @(posedge clk) begin
    if ((waddr_02 == 5'h8) & we_02) rf[8]<= wdata_02;
    else if((waddr_01 == 5'h8) & we_01) rf[8]<= wdata_01;
end

always @(posedge clk) begin
    if ((waddr_02 == 5'h9) & we_02) rf[9]<= wdata_02;
    else if((waddr_01 == 5'h9) & we_01) rf[9]<= wdata_01;
end

always @(posedge clk) begin
    if ((waddr_02 == 5'ha) & we_02) rf[10]<= wdata_02;
    else if((waddr_01 == 5'ha) & we_01) rf[10]<= wdata_01;
end

always @(posedge clk) begin
    if ((waddr_02 == 5'hb) & we_02) rf[11]<= wdata_02;
    else if((waddr_01 == 5'hb) & we_01) rf[11]<= wdata_01;
end

always @(posedge clk) begin
    if ((waddr_02 == 5'hc) & we_02) rf[12]<= wdata_02;
    else if((waddr_01 == 5'hc) & we_01) rf[12]<= wdata_01;
end

always @(posedge clk) begin
    if ((waddr_02 == 5'hd) & we_02) rf[13]<= wdata_02;
    else if((waddr_01 == 5'hd) & we_01) rf[13]<= wdata_01;
end

always @(posedge clk) begin
    if ((waddr_02 == 5'he) & we_02) rf[14]<= wdata_02;
    else if((waddr_01 == 5'he) & we_01) rf[14]<= wdata_01;
end

always @(posedge clk) begin
    if ((waddr_02 == 5'hf) & we_02) rf[15]<= wdata_02;
    else if((waddr_01 == 5'hf) & we_01) rf[15]<= wdata_01;
end

always @(posedge clk) begin
    if ((waddr_02 == 5'h10) & we_02) rf[16]<= wdata_02;
    else if((waddr_01 == 5'h10) & we_01) rf[16]<= wdata_01;
end

always @(posedge clk) begin
    if ((waddr_02 == 5'h11) & we_02) rf[17]<= wdata_02;
    else if((waddr_01 == 5'h11) & we_01) rf[17]<= wdata_01;
end

always @(posedge clk) begin
    if ((waddr_02 == 5'h12) & we_02) rf[18]<= wdata_02;
    else if((waddr_01 == 5'h12) & we_01) rf[18]<= wdata_01;
end

always @(posedge clk) begin
    if ((waddr_02 == 5'h13) & we_02) rf[19]<= wdata_02;
    else if((waddr_01 == 5'h13) & we_01) rf[19]<= wdata_01;
end

always @(posedge clk) begin
    if ((waddr_02 == 5'h14) & we_02) rf[20]<= wdata_02;
    else if((waddr_01 == 5'h14) & we_01) rf[20]<= wdata_01;
end

always @(posedge clk) begin
    if ((waddr_02 == 5'h15) & we_02) rf[21]<= wdata_02;
    else if((waddr_01 == 5'h15) & we_01) rf[21]<= wdata_01;
end

always @(posedge clk) begin
    if ((waddr_02 == 5'h16) & we_02) rf[22]<= wdata_02;
    else if((waddr_01 == 5'h16) & we_01) rf[22]<= wdata_01;
end

always @(posedge clk) begin
    if ((waddr_02 == 5'h17) & we_02) rf[23]<= wdata_02;
    else if((waddr_01 == 5'h17) & we_01) rf[23]<= wdata_01;
end

always @(posedge clk) begin
    if ((waddr_02 == 5'h18) & we_02) rf[24]<= wdata_02;
    else if((waddr_01 == 5'h18) & we_01) rf[24]<= wdata_01;
end

always @(posedge clk) begin
    if ((waddr_02 == 5'h19) & we_02) rf[25]<= wdata_02;
    else if((waddr_01 == 5'h19) & we_01) rf[25]<= wdata_01;
end

always @(posedge clk) begin
    if ((waddr_02 == 5'h1a) & we_02) rf[26]<= wdata_02;
    else if((waddr_01 == 5'h1a) & we_01) rf[26]<= wdata_01;
end

always @(posedge clk) begin
    if ((waddr_02 == 5'h1b) & we_02) rf[27]<= wdata_02;
    else if((waddr_01 == 5'h1b) & we_01) rf[27]<= wdata_01;
end

always @(posedge clk) begin
    if ((waddr_02 == 5'h1c) & we_02) rf[28]<= wdata_02;
    else if((waddr_01 == 5'h1c) & we_01) rf[28]<= wdata_01;
end

always @(posedge clk) begin
    if ((waddr_02 == 5'h1d) & we_02) rf[29]<= wdata_02;
    else if((waddr_01 == 5'h1d) & we_01) rf[29]<= wdata_01;
end

always @(posedge clk) begin
    if ((waddr_02 == 5'h1e) & we_02) rf[30]<= wdata_02;
    else if((waddr_01 == 5'h1e) & we_01) rf[30]<= wdata_01;
end

always @(posedge clk) begin
    if ((waddr_02 == 5'h1f) & we_02) rf[31]<= wdata_02;
    else if((waddr_01 == 5'h1f) & we_01) rf[31]<= wdata_01;
end


//READ OUT 1
assign rdata_01 = (raddr_01 == 5'b0) ? 32'b0 : rf[raddr_01];

//READ OUT 2
assign rdata_02 = (raddr_02 == 5'b0) ? 32'b0 : rf[raddr_02];

//READ OUT 3
assign rdata_03 = (raddr_03 == 5'b0) ? 32'b0 : rf[raddr_03];

//READ OUT 4
assign rdata_04 = (raddr_04 == 5'b0) ? 32'b0 : rf[raddr_04];

//READ OUT 5
assign rdata_05 = (raddr_05 == 5'b0) ? 32'b0 : rf[raddr_05];

//READ OUT 6
assign rdata_06 = (raddr_06 == 5'b0) ? 32'b0 : rf[raddr_06];

endmodule