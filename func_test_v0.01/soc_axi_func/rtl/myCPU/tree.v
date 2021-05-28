module tree(
    input [16:0] in,
    input [13:0] cin,

    output[13:0] cout,
    output c_to_plus, 
    output s_to_plus
);

wire n0, n1, n2, n3, n4, n5, n6, n7, n8, n9, n10, n11, n12, n13;

assign {cout[0], n0} = in[16] + in[15] + in[14];
assign {cout[1], n1} = in[13] + in[12] + in[11];
assign {cout[2], n2} = in[10] + in[9] + in[8];
assign {cout[3], n3} = in[7] + in[6] + in[5];
assign {cout[4], n4} = in[4] + in[3] + in[2];

assign {cout[5], n5} = n0 + n1 + n2;
assign {cout[6], n6} = n3 + n4 + in[1];
assign {cout[7], n7} = in[0] + cin[0] + cin[1];
assign {cout[8], n8} = cin[2] + cin[3] + cin[4];

assign {cout[9], n9} = n5 + n6 + n7;
assign {cout[10], n10} = n8 + cin[5] + cin[6];

assign {cout[11], n11} = n9 + n10 + cin[7];
assign {cout[12], n12} = cin[8] + cin[9] + cin[10];

assign {cout[13], n13} = n11 + n12 + cin[11];

assign {c_to_plus, s_to_plus} = n13 + cin[12] + cin[13];

endmodule