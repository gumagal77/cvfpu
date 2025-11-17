// -----------------------------------------------------------------------------
// File Name: mult_qmn_lns.sv
// Description: 
//   This module converts two signed QM.N numbers to the correspondent
//   Logarithmic Number System (LNS) representation and performas multiplication
//   by adding the logarithms, and then converts back to QM.N. The module is
//   parameterized to support different bit widths. The equation is:
//
//      a * b = c <=> log(a) + log(b) = log(c)
// 
//   Key Features:
//     - Parameterized bit-width (default N=8)
//     - Synchronous reset and clocked output
//     - Fractional integer output
//     - Optionally takes a look-up correction table to improve accuary
//       (The tables can be of up to 8 and 16 bits)
// 
// Ports:
//   Inputs:
//     clk  - Clock signal
//     rst  - Synchronous reset signal
//     a    - N-bit input first operand
//     b    - N-bit input second operand
// 
//   Output:
//     c    - product of input operands
// 
// Author: Gustavo Magalhaes
// Date: 15.11.2025
// -----------------------------------------------------------------------------

module mult_qmn_lns #(
    parameter M = 8,
    parameter N = 8,  // Parameter to define the bit-width of the operand
    parameter USE_COR = 1,
    parameter NUM_REGS = 0, // 0, 1 or 2
    localparam W = M+N
)(
    input logic clk,                       // Clock input
    input logic rst,                       // Asynchronous reset input
    input logic [W-1:0] a,
    input logic [W-1:0] b,
    output logic [2*W-1:0] c // for same width of inputs, use c[M*2*N-1:N]
);

if(NUM_REGS<0 || NUM_REGS>2) $error("NUM_REGS should be 0, 1 or 2, and not %d", NUM_REGS);

// Intermediate variables for int to LNS conversion
logic [$clog2(W):0] a_lns_int, b_lns_int;
logic [W-1:0] a_lns_frac, b_lns_frac;
//logic a_is_negative, b_is_negative;
logic a_is_zero, b_is_zero;

// Convert int into LNS values
qmn_to_lns #(.M(M),.N(N),
             .USE_COR(USE_COR),
             .USE_REG(NUM_REGS>=1)) a_to_lns (.clk(clk), .rst(rst), .a(a), // inputs
                                              .b_int(a_lns_int), .b_frac(a_lns_frac), .is_zero(a_is_zero)); //.is_negative(a_is_negative), ; // outputs
qmn_to_lns #(.M(M),.N(N),
             .USE_COR(USE_COR),
             .USE_REG(NUM_REGS>=1)) b_to_lns (.clk(clk), .rst(rst), .a(b), // inputs
                                              .b_int(b_lns_int), .b_frac(b_lns_frac), .is_zero(b_is_zero)); //.is_negative(b_is_negative),  // outputs

// Variables for summation
logic [$clog2(W)+W:0] a_lns, b_lns;
assign a_lns = (a_is_zero) ? '0 : {a_lns_int,a_lns_frac};
assign b_lns = (b_is_zero) ? '0 : {b_lns_int,b_lns_frac};

// Perfom sum of logs (multiplication)
logic [$clog2(W)+W+1:0] c_lns;
logic c_is_zero;
assign c_is_zero = a_is_zero || b_is_zero;
assign c_lns = (c_is_zero) ? '0 : a_lns + b_lns;

logic [$clog2(W)+1:0] c_lns_int;
logic [2*W-1:0] c_lns_frac, c_prod;
assign c_lns_int = c_lns[$clog2(W)+W+1:W];
assign c_lns_frac = {c_lns[W-1:0],{(W){1'b0}}};
lns_to_qmn #(.M(2*M), .N(2*N), .USE_COR(USE_COR),
             .USE_REG(NUM_REGS==2)) c_to_int (.clk(clk), .rst(rst), .a_int(c_lns_int), .a_frac(c_lns_frac), .is_zero(c_is_zero), //.is_negative(a_is_negative ^ b_is_negative),  // inputs
                                              .b(c_prod)); // outputs

assign c = c_prod;


endmodule
