// -----------------------------------------------------------------------------
// File Name: qmn_to_lns.sv
// Description: 
//   This module converts an unsigned fractional integer number to its
//   correspondent in Logarithmic Number System (LNS). The module is
//   parameterized to support different bit widths. The equation is:
//
//      log2(a) = log2(2^k*(1+m)) = k + log2(1+m) ~= k + m,
//
//   where a is expressed in M.N (int.frac)
// 
//   Key Features:
//     - Parameterized bit-width (default M=3, N=4)
//     - Synchronous reset and clocked output
//     - Fractional integer output
//     - Optionally takes a look-up correction table to improve accuary
//       (The table can be of up to 8 bits)
// 
// Ports:
//   Inputs:
//     clk  - Clock signal
//     rst  - Synchronous reset signal
//     a    - N-bit input operand
// 
//   Outputs:
//     b_int  - integer part of result
//     b_frac - fractional part of result
// 
// Author: Gustavo Magalhaes
// Date: 15.11.2025
// -----------------------------------------------------------------------------

module qmn_to_lns #(
    parameter M = 3,
    parameter N = 4,  // Parameter to define the bit-width of the operand
    parameter USE_COR = 1,
    parameter USE_REG = 0, // 0 or 1
    localparam W = M+N
) (
    input logic clk,                       // Clock input
    input logic rst,                       // Asynchronous reset input
    input logic [W-1:0] a,          // Input operand
    output logic [$clog2(W):0] b_int,    // Integer part of output
    output logic [W-1:0] b_frac,           // Fractional part of output
    //output logic is_negative,              // declares number
    output logic is_zero                   // if input is 0, raise signal
);

localparam int W_COR = W>8 ? 8 : W;
localparam int COR_LENGTH = 4*W_COR/5;

// Function to get MSB index of the input value
// It's the k in log2(a) = k + log(1+m)
function logic [$clog2(W)-1:0] get_msb_ind(input logic [W-1:0] value);
    logic[$clog2(W)-1:0] msb_index;
    begin
        //if(value == '0) return '0; // overflow
        msb_index = '0;
        for (int i = W-1; i >= 0; i--) begin
            if (value[i]) begin
                msb_index = i[$clog2(W)-1:0]; // Update MSB index when a '1' is found
                break;         // Exit loop after finding the MSB
            end
        end
        return msb_index; // correct for the position of the binary point
    end
endfunction

// Function to provide approximation to m in log2(a) = k + log2(1+m) ~= k + m
function logic [W-2:0] mitchell_approx(input logic [W-2:0] value, input logic [$clog2(W)-1:0] msb);
    logic [W-2:0] normalized_value;
    begin
        normalized_value = '0;
        normalized_value = value << (W-1-msb);      // Normalize by shifting MSB to position W-1
        return //(value == '0) ? '0 : // overflow
                normalized_value[W-2:0];   // Take lower N-2 bits as fractional part
    end
endfunction

logic [W-2:0] the_frac;
logic [W_COR-2:0] frac_cor;
logic [COR_LENGTH:0] cor;
logic [$clog2(W)-1:0] the_int;
logic [W-1:0] a_abs;

assign a_abs = a;//a[W-1] ? (~a + 1) : a;
assign the_int = get_msb_ind(a_abs);
assign the_frac = mitchell_approx(a_abs[W-2:0], the_int);
assign frac_cor = the_frac >> (W-W_COR);
if(USE_COR) correct_lns_mitchell #(.N(W_COR), .USE_COR(USE_COR)) lns_cor (.frac(frac_cor), .correction(cor));

logic [$clog2(W):0] k;
logic [W-1:0] m;
logic will_be_zero;
//logic will_be_negative;

// Assign values to results
always_comb begin
    k = '0;
    m = '0;
    will_be_zero = (a == '0);
    //will_be_negative = 0; //THIS IS UNSIGNED VERSION (a[W-1] == 1'b1);
    if (~will_be_zero) begin
        k = the_int-N;
        m = {the_frac,1'b0};
        if(USE_COR) m += W>8 ? {{(W_COR-1-COR_LENGTH){1'b0}},cor,{(W-W_COR){1'b0}}}
                             : {{(W-1-COR_LENGTH){1'b0}},cor}; // TODO: add other approximations here to compare
    end
end

// Register the result before sending it to output
if(USE_REG) begin
    always_ff @(posedge clk or posedge rst) begin
        if(rst) begin
            b_int <= '0;
            b_frac <= '0;
            is_zero <= '0;
            //is_negative <= '0;
        end else begin
            b_int <= k;
            b_frac <= m;
            is_zero <= will_be_zero;
            //is_negative <= will_be_negative;
        end
    end
end else begin
    assign b_int = k;
    assign b_frac = m;
    assign is_zero = will_be_zero;
    //assign is_negative = will_be_negative;
end

endmodule
