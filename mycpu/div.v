`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/10/14 15:29:55
// Design Name: 
// Module Name: divider
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


module div(
    input         div_clk,
    input         resetn,
    input         div,
    input         div_signed,
    input  [31:0] x,
    input  [31:0] y,
    output [31:0] s,
    output [31:0] r,
    output        complete,
    input         exception
    );

    reg [63:0] A;
    reg [32:0] B;
    reg [31:0] S;
    reg [5:0]  count;

    wire       start;

    wire       x_neg;
    wire       y_neg;
    wire       s_neg;
    wire       r_neg;

    wire [32:0] partial_sum;
    wire        partial_quotient;

    assign x_neg = x[31] & div_signed;
    assign y_neg = y[31] & div_signed;
    assign s_neg = x_neg ^ y_neg;
    assign r_neg = x_neg;

    assign start = (count == 0);
    assign complete = (count == 6'd33);

    always @(posedge div_clk) begin
        if (!resetn) begin
            count <= 0;
        end
        else if (exception)begin
            count <= 0;
        end
        else if (complete) begin
            count <= 0;
        end else if (div & start) begin
            count <= 1;
        end else if (~start) begin
            count <= count + 1;
        end
    end

    assign partial_sum      = A[63:31] + ~B[32:0] + 1;
    assign partial_quotient = ~partial_sum[32];

    always @(posedge div_clk) begin
        if (!resetn) begin
            B <= 0;
        end 
        else if (exception)begin
            B <= 0;
        end        
        else if(div & start) begin
            B <= y_neg ? {1'b0 , ~y + 1} : {1'b0 , y};
        end
    end

    always @(posedge div_clk) begin
        if (!resetn) begin
            A <= 0;
        end 
        else if (exception)begin
            A <= 0;
        end
        else if (div & start) begin
            A <= x_neg ? {32'b0, ~x + 1} : {32'b0, x};
        end else if (~start) begin
            A <= partial_quotient ? {partial_sum[31:0], A[30:0], 1'b0}:
                                    {A[62:0], 1'b0};
        end
    end

    always @(posedge div_clk) begin
        if (!resetn) begin
            S <= 0;
        end 
        else if (exception)begin
            S <= 0;
        end        
        else if (div & start) begin
            S <= 0;
        end else if (~start) begin
            S <= {S[30:0], partial_quotient};
        end
    end

    assign s = s_neg ? ~S + 1        : S;
    assign r = r_neg ? ~A[63:32] + 1 : A[63:32];

endmodule
