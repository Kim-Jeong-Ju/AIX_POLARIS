`timescale 1ns / 1ps
module mul(
input clk, 
input [7:0] w, 
input [7:0] x, 
output[15:0] y
);
    
wire [17:0] dsp_A, dsp_B;
wire [47:0] dsp_P;

assign dsp_A = w[7]? {10'b11_1111_1111, w} : {10'b00_0000_0000, w};
assign dsp_B = x[7]? {10'b11_1111_1111, x} : {10'b00_0000_0000, x};
assign y = dsp_P[15:0];

xbip_dsp48_macro_0 u_dsp(.CLK(clk), .A(dsp_A), .B(dsp_B), .C(48'b0), .P(dsp_P));
endmodule
