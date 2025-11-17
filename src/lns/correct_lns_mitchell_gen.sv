module correct_lns_mitchell #(
    parameter N = 4,  // Parameter to define the bit-width of the operand
    parameter USE_COR = 1
) (
    input [N-2:0] frac,
    output [4*N/5:0] correction
);

/* verilator lint_off UNUSEDSIGNAL */


assign correction = '0;

endmodule
