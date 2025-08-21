`define TB_NAME tb_fp4_mult

`timescale	1ns/1ns
module `TB_NAME;

localparam EXP_BITS = 2;
localparam MAN_BITS = 1;
localparam real MAX_VALUE = 6;

string input_file_path = "fp4_mult_input.txt";

localparam WIDTH = EXP_BITS+MAN_BITS+1;
localparam BIAS = 2**(EXP_BITS-1)-1;
localparam MAX_VALUE_INT = $rtoi(MAX_VALUE*(2**MAN_BITS));
localparam MAX_VALUE_INT_BITS = $clog2(MAX_VALUE_INT);


logic clk_i, rst_ni;
logic in_valid_i, in_ready_o, flush_i;

logic [1:0][WIDTH-1:0] operands_i;

logic [WIDTH-1:0] result_o;
logic [4:0] status_o;

logic out_valid_o, out_ready_i, busy_o;


fp4_mult dut (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .operands_i(operands_i),
    .in_valid_i(in_valid_i),
    .in_ready_o(in_ready_o),
    .flush_i(flush_i),
    .result_o(result_o),
    .status_o(status_o),
    .out_valid_o(out_valid_o),
    .out_ready_i(out_ready_i),
    .busy_o(busy_o)
);

function automatic string get_bit_string(
    input logic [WIDTH-1:0] fp_value
);
    return $sformatf("%b_%b_%b", fp_value[WIDTH-1], fp_value[WIDTH-2:MAN_BITS], fp_value[MAN_BITS-1:0]);
endfunction

function automatic real get_real_value (
    input logic [WIDTH-1:0] fp_value
);
    real my_value=0;
    logic sign = fp_value[WIDTH-1];
    logic [EXP_BITS-1:0] exp = fp_value[WIDTH-2:MAN_BITS];
    logic [MAN_BITS-1:0] man = fp_value[MAN_BITS-1:0];
    //$display("\n%b\n",{(fp_value[4:3]!=0 ? {1'b1} : {1'b0}) ,fp_value[2:0]});
    if(exp!='0) begin // normal
        my_value = $itor({{1'b1},man})*$itor(2**(exp))/$itor(2**(BIAS+MAN_BITS)); // exp_bias+M
    end else begin // subnormal
        my_value = $itor({{1'b0},man})/$itor(2**(BIAS+MAN_BITS-1)); // exp_bias+M-1
    end
    my_value = my_value * ( sign ? (-1.0) : (1.0) );
    return my_value;
endfunction

function automatic logic [WIDTH-1:0] get_fp_value (
    input real real_value
);
    logic [WIDTH-1:0] fp_value;
    logic value_neg = real_value<0;
    real abs_real_value = value_neg ? -real_value : real_value;
    logic [31:0] int_value = $rtoi(abs_real_value*(2**(BIAS+MAN_BITS-1)));
    int msb_pos = -1;
    int exp, man;
    logic [EXP_BITS-1:0] exp_bits;
    logic [MAN_BITS-1:0] man_bits;

    // overflow
    if (int_value > MAX_VALUE_INT) begin // max_value*8
        return {value_neg,{(WIDTH-1){1'b1}}};
    end
    // zero
    else if (int_value[MAX_VALUE_INT_BITS-1:0] == '0) begin
        return {value_neg,{(WIDTH-1){1'b0}}};
    end

    // find MSB position
    for (int i=31; i>=0; i--) begin
        if(int_value[i]) begin
            msb_pos = i;
            break;
        end
    end
    
    // subnormal case
    if(msb_pos<MAN_BITS) begin
        exp_bits = '0;
        man_bits = int_value[MAN_BITS-1:0];
    // normal case
    end else begin
        exp = msb_pos - MAN_BITS +1; // exp position - MAN_BITS + 1 (the last being the position of the leading 1)
        exp_bits = exp;
        man = int_value >> (msb_pos-MAN_BITS); 
        man_bits = man[MAN_BITS-1:0];
    end
    fp_value = {value_neg, exp_bits, man_bits};

    return fp_value;
endfunction

real a, b, c_exp, c_real;
assign c_real = get_real_value(result_o);

logic [WIDTH-1:0] a_fp, b_fp, c_fp_exp;
int NUM_PIPE_REGS = dut.multiplier.NumPipeRegs;

task test_mult;
    $display("Test %g * %g", a, b);
    @(negedge clk_i);
    a_fp = get_fp_value(a);
    b_fp = get_fp_value(b);
    c_exp = a*b;
    operands_i[0] = a_fp;
    operands_i[1] = b_fp;
    out_ready_i = '1;
    flush_i = '0;
    in_valid_i = '1;
    if(NUM_PIPE_REGS != '0) @(posedge out_valid_o); else @(negedge clk_i);
    $display("%s * %s = %s", get_bit_string(operands_i[0]), get_bit_string(operands_i[1]), get_bit_string(result_o));
    $display("%g * %g = %g", get_real_value(operands_i[0]), get_real_value(operands_i[1]), c_real);
    $display("flags:%b", status_o);
    
    if(c_real==c_exp) begin
        $display("Result OK\n");
    end else begin
        $display("Difference: %g - %g = %g\n", c_real, c_exp, c_real-c_exp);
    end
    
    out_ready_i = '1;
    in_valid_i = '0;
    if(NUM_PIPE_REGS != '0) begin
        @(negedge clk_i)
        flush_i = '1;
        out_ready_i = '0;
    end
endtask






localparam int NUM_TESTS = 2**(2*(EXP_BITS+MAN_BITS)+2);
logic [3*WIDTH-1:0] testvec [0:NUM_TESTS-1];

initial begin
    $readmemb(input_file_path, testvec);
end


logic [0:2][WIDTH-1:0]fp_values;
task test_out;
    for (int i = 0; i<NUM_TESTS; i=i+1) begin
        @(negedge clk_i);
        fp_values = testvec[i];
        operands_i[0] = fp_values[0];
        operands_i[1] = fp_values[1];
        a = get_real_value(operands_i[0]);
        b = get_real_value(operands_i[1]);
        a_fp = operands_i[0];
        b_fp = operands_i[1];
        c_fp_exp = fp_values[2];
        c_exp = get_real_value(fp_values[2]);

        out_ready_i = '1;
        flush_i = '0;
        in_valid_i = '1;
        if(NUM_PIPE_REGS != '0) @(posedge out_valid_o); else @(negedge clk_i);
        $display("%s * %s = %s", get_bit_string(operands_i[0]), get_bit_string(operands_i[1]), get_bit_string(result_o));
        $display("%g * %g = %g", get_real_value(operands_i[0]), get_real_value(operands_i[1]), c_real);
        $display("flags:%b", status_o);
        
        if(result_o==c_fp_exp) begin
            $display("Result OK\n");
        end else begin
            $display("Difference: %g - %g = %g\n", c_real, c_exp, c_real-c_exp);
        end
        
        out_ready_i = '1;
        in_valid_i = '0;
        if(NUM_PIPE_REGS != '0) begin
            @(negedge clk_i)
            flush_i = '1;
            out_ready_i = '0;
        end
    end
endtask




// generate VCD waveform file
initial begin
    $dumpfile("waveform.vcd"); // Name of the VCD file
    $dumpvars(0, `TB_NAME); // Dump all variables in this module
end

// Clock generation
initial begin
    clk_i = 0;
    forever #5ns clk_i = ~clk_i; // Clock period = 10 time units
end

// main flow
initial begin
    $display("Starting Testbench for FP adder\n");
    
    rst_ni = 0; #10ns;  // Assert reset // @suppress "Multiple statements on this line. Split the statements over multiple lines to improve readability."
    rst_ni = 1;       // Deassert reset

    #5ns
    
    a = 3.5;
    b = 4;
    test_mult;

    a = 3.5;
    b = 4.5;
    test_mult;

    a = 0;
    b = -0;
    test_mult;
    
    a = 1;
    b = 2;
    test_mult;
    
    a = 0.125;
    b = 0.125;
    test_mult;
    
    a = -0.25;
    b = 0.25;
    test_mult;

    a = -0.25;
    b = 2.25;
    test_mult;
    
    
    $display("Test: %g is %s", 4.5, get_bit_string(get_fp_value(4.5)));
    $display("Test: %g is %s", 1, get_bit_string(get_fp_value(1)));
    $display("Test: %g is %s", -0.75, get_bit_string(get_fp_value(-0.75)));
    $display("Test: %g is %s", 7.5, get_bit_string(get_fp_value(7.5)));
    $display("Test: %g is %s", -8.5, get_bit_string(get_fp_value(-8.5)));

    test_out;

    $finish;

end


    
endmodule
