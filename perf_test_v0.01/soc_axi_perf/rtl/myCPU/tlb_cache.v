module tlb_cache
(
    input         reset,
    input         clk,
    
    input         s_found,
    input  [19:0] s_pfn,
    input         s_d,
    input         s_v,

    input  [31:0] inst_VA,
    output        inst_tlb_req_en,
    input         inst_addr_ok,
    input         inst_tlb_exception,
    input         inst_use_tlb,

    input          tlb_write,

    output [19 :0] inst_pfn,
    output         inst_tlb_v,
    output         inst_tlb_d,
    output         inst_tlb_found
);

reg [1 :0] state;
reg [1 :0] nextstate;
reg [18:0] vpn2;
reg odd_page;
//reg [7 :0] asid;
reg [19 :0] pfn;
reg tlb_v;
reg tlb_d;
reg tlb_found;
reg tlb_valid;

wire tlb_hit;
assign tlb_hit = tlb_valid & (inst_VA[31:13] == vpn2) & (inst_VA[12] == odd_page);

always @(posedge clk) begin
    if(reset)   state <= 2'd0;
    else state <= nextstate;
end


always @(*) begin
    case(state) 
    2'b00:  nextstate = (!tlb_hit & inst_use_tlb) ? 2'b01 : 2'b00;
    2'b01:  nextstate = 2'b10;
    2'b10:  nextstate = (inst_addr_ok|inst_tlb_exception) ? 2'b00 : 2'b10;
    default:nextstate = 2'b00;
    endcase
end

always @(posedge clk)
begin
    if(reset) tlb_valid <= 1'b0;
    else if (tlb_write) tlb_valid <= 1'b0;
    else if (state == 2'b01) tlb_valid <= 1'b1;
end

always @(posedge clk)
begin
    if(reset) 
    begin
        vpn2 <= 19'd0;
        odd_page <= 1'b0;
        //asid <= 8'b0;
        pfn <= 20'b0;
        tlb_d <= 1'b0;
        tlb_v <= 1'b0 ;
        tlb_found <= 1'b0;
    end
    else if(state == 2'b01)
    begin
        vpn2 <= inst_VA[31:13];
        odd_page <= inst_VA[12];
        //asid <= cp0_entryhi[7:0];
        pfn <= s_pfn;
        tlb_v <= s_v;
        tlb_d <= s_d;
        tlb_found <= s_found;
    end
end

assign inst_pfn = pfn;
assign inst_tlb_v = tlb_v;
assign inst_tlb_d = tlb_d;
assign inst_tlb_found = tlb_found;


assign inst_tlb_req_en = ((tlb_hit | !inst_use_tlb) & (state == 2'b00)) | (state == 2'b10);

endmodule