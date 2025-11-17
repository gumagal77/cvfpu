// -----------------------------------------------------------------------------
// File Name: lns_to_qmn.sv
// Description: 
//   This module converts an unsigned fractional integer number from its 
//   correspondent in Logarithmic Number System (LNS). The module is 
//   parameterized to support different bit widths. The equation is:
//
//      log2(a) = log2(2^k*(1+m)) = k + log2(1+m) ~= k + m,
//
//   where a is in the format M.N (int.frac)
// 
//   Key Features:
//     - Parameterized bit-width (default M=3, N=4)
//     - Synchronous reset and clocked output
//     - Fractional integer output
//     - Optionally takes a look-up correction table to improve accuary
//       (The table can be of up to 16 bits)
// 
// Ports:
//   Inputs:
//     clk  - Clock signal
//     rst  - Synchronous reset signal
//     b_int  - integer part of input
//     b_frac - fractional part of input
// 
//   Outputs:
//     a    - N-bit input ouput
// 
// Author: Gustavo Magalhaes
// Date: 15.11.2025
// -----------------------------------------------------------------------------

module lns_to_qmn #(
    parameter M = 3,
    parameter N = 4,  // Parameter to define the bit-width of the operand
    parameter USE_COR = 1,
    parameter USE_REG = 0, // 0 or 1
    localparam W=M+N
) (
    input logic clk,                       // Clock input
    input logic rst,                       // Asynchronous reset input
    input logic [$clog2(W):0] a_int,     // Integer part of output
    input logic [W-1:0] a_frac,            // Fractional part of output
    //input is_negative,
    input logic is_zero,                   // if input is 0, raise signal
    output logic signed [W-1:0] b          // Input operand
);

localparam int W_COR = W>16 ? 16 : W;
localparam int COR_LENGTH = 4*W_COR/5;

logic [COR_LENGTH:0] cor;
logic [W_COR-1:0] frac_cor;
assign frac_cor = W>8 ? a_frac >> (W-W_COR) : a_frac;
if(USE_COR) correct_lns_inv_mitchell #(.N(W_COR), .USE_COR(USE_COR)) lns_cor (.frac(frac_cor), .correction(cor));

// Function to get 2^value
function logic [W-1:0] exp_2(input logic [$clog2(W):0] value);
    logic [W-1:0] output_value;
    begin
        output_value = {{(W-1){1'b0}},1'b1}; // init at 1
        return output_value << (value + N);// : (output_value << ( N-value_neg ) ); // right shift
    end
endfunction

// Function to provide 2^m in log2(a) = k + log2(1+m) ~= k + m
function logic [W-1:0] inv_mitchell_approx(input logic [W-1:0] value, input logic [$clog2(W):0] msb, input logic [COR_LENGTH:0] cor);
    logic [W-1:0] output_value;
    begin
        output_value = value; // get input value
        if(USE_COR) output_value = W>16 ? output_value - {{(W_COR-1-COR_LENGTH){1'b0}},cor,{(W-W_COR){1'b0}}}
                                        : output_value - {{(W-1-COR_LENGTH){1'b0}},cor};
        output_value = (output_value >> (M - msb)) + ((W>16 && USE_COR==1) ? output_value[M-msb-1] : 0); // shift it to appropriate value
        return output_value;
    end
endfunction

logic [W-1:0] result, exp_part, inv_mitch_part;
assign exp_part = exp_2(a_int);
assign inv_mitch_part = inv_mitchell_approx(a_frac, a_int, cor);

// Assign value to result
always_comb begin
    if (is_zero) begin
        result = '0;
    end else begin
        result = exp_part + inv_mitch_part; // TODO: add other approximations here to compare
        //result = is_negative ? (~result + 1) : result;
    end
end

// Register the result before sending it to output
if(USE_REG) begin
    always_ff @(posedge clk or posedge rst) begin
        if(rst) begin
            b <= '0;
        end else begin
            b <= result;
        end
    end
end else begin
    assign b = result;
end

endmodule
