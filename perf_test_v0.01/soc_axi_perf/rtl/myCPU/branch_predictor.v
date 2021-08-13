module branch_predictor(
	input         clk,
	input         rst,

	input         branch,
	input         branch_res,
    input         branch_fail,
	input  [7: 0] branch_addr,
    input  [7: 0] branch_target,

    input  [7: 0] bp_addr,
	output        bp_res,
    output        bp_valid,
    output [7: 0] bp_target
);

    localparam STAKEN = 2'b11;
	localparam WTAKEN = 2'b10;
	localparam WNOTAKEN = 2'b01;
	localparam SNOTAKEN = 2'b00;

    reg [5:0] BHR;
	reg [1:0] PHT [63:0];

    reg [7:0] PHT_ADDR [255:0];
    reg PHT_ADDR_Valid [255:0];

    genvar i;
    generate for (i=0; i<256; i=i+1) begin : gen_for_reg
        always @(posedge clk) begin
            if(rst) begin
                PHT_ADDR_Valid[i] <= 1'b0;
            end
            else begin
                if(branch & branch_fail & (i == branch_addr)) begin
			        PHT_ADDR_Valid[i] <= 1'b1;
		        end
            end

		    if(branch & branch_fail & (i == branch_addr)) begin
			    PHT_ADDR[i] <= branch_target;
		    end
	    end
    end endgenerate

    assign bp_target = PHT_ADDR[bp_addr];
    assign bp_valid  = PHT_ADDR_Valid[bp_addr];

	assign bp_res = PHT[BHR][1];

    always @(posedge clk) begin
		if(rst) begin
            PHT[0] <= SNOTAKEN;
            PHT[1] <= WNOTAKEN;
            PHT[2] <= WNOTAKEN;
            PHT[3] <= STAKEN;
            PHT[4] <= SNOTAKEN;
            PHT[5] <= WTAKEN;
            PHT[6] <= WTAKEN;
            PHT[7] <= STAKEN;
            PHT[8] <= SNOTAKEN;
            PHT[9] <= WNOTAKEN;
            PHT[10] <= WNOTAKEN;
            PHT[11] <= STAKEN;
            PHT[12] <= SNOTAKEN;
            PHT[13] <= WTAKEN;
            PHT[14] <= WTAKEN;
            PHT[15] <= STAKEN;
            PHT[16] <= SNOTAKEN;
            PHT[17] <= WNOTAKEN;
            PHT[18] <= WNOTAKEN;
            PHT[19] <= STAKEN;
            PHT[20] <= SNOTAKEN;
            PHT[21] <= WTAKEN;
            PHT[22] <= WTAKEN;
            PHT[23] <= STAKEN;
            PHT[24] <= SNOTAKEN;
            PHT[25] <= WNOTAKEN;
            PHT[26] <= WNOTAKEN;
            PHT[27] <= STAKEN;
            PHT[28] <= SNOTAKEN;
            PHT[29] <= WTAKEN;
            PHT[30] <= WTAKEN;
            PHT[31] <= STAKEN;
            PHT[32] <= SNOTAKEN;
            PHT[33] <= WNOTAKEN;
            PHT[34] <= WNOTAKEN;
            PHT[35] <= STAKEN;
            PHT[36] <= SNOTAKEN;
            PHT[37] <= WTAKEN;
            PHT[38] <= WTAKEN;
            PHT[39] <= STAKEN;
            PHT[40] <= SNOTAKEN;
            PHT[41] <= WNOTAKEN;
            PHT[42] <= WNOTAKEN;
            PHT[43] <= STAKEN;
            PHT[44] <= SNOTAKEN;
            PHT[45] <= WTAKEN;
            PHT[46] <= WTAKEN;
            PHT[47] <= STAKEN;
            PHT[48] <= SNOTAKEN;
            PHT[49] <= WNOTAKEN;
            PHT[50] <= WNOTAKEN;
            PHT[51] <= WTAKEN;
            PHT[52] <= SNOTAKEN;
            PHT[53] <= WTAKEN;
            PHT[54] <= WTAKEN;
            PHT[55] <= STAKEN;
            PHT[56] <= SNOTAKEN;
            PHT[57] <= WNOTAKEN;
            PHT[58] <= WNOTAKEN;
            PHT[59] <= STAKEN;
            PHT[60] <= SNOTAKEN;
            PHT[61] <= WTAKEN;
            PHT[62] <= WTAKEN;
            PHT[63] <= STAKEN;
		end
		else begin
		    if(branch) begin
				case(PHT[BHR])
				STAKEN: begin
					if(branch_res)
						PHT[BHR] <= STAKEN;
					else
						PHT[BHR] <= WTAKEN;
				end
				WTAKEN: begin
					if(branch_res)
						PHT[BHR] <= STAKEN;
					else
						PHT[BHR] <= WNOTAKEN;
				end
				WNOTAKEN: begin
					if(branch_res)
						PHT[BHR] <= WTAKEN;
					else
						PHT[BHR] <= SNOTAKEN;
				end
				SNOTAKEN: begin
					if(branch_res)
						PHT[BHR] <= WNOTAKEN;
					else
						PHT[BHR] <= SNOTAKEN;
				end
				endcase
			end
		end
	end

    always @(posedge clk) begin
		if(rst)
			BHR <= 6'b0;
		else begin
			if(branch) begin
				BHR <= {BHR[4:0], branch_res};
			end
		end
	end

endmodule