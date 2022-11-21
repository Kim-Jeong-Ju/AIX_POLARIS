`timescale 1ns / 1ps



module test_logic(
input [31:0] a,
input [31:0] b,
output [31:0] sum,
output [31:0] difference,
output [31:0] bitwiseAnd,
output [31:0] bitwiseOr,
output [31:0] bitwiseXor,
output [31:0] bitwiseXNor
);
assign sum = a+b;
assign difference = a-b;
assign bitwiseAnd = a & b;
assign bitwiseOr = a | b;
assign bitwiseXor = a ^ b;
assign bitwiseXNor = a ~^ b;
endmodule
