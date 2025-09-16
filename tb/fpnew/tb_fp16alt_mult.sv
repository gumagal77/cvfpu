`define TB_NAME tb_fp16alt_mult

`timescale	1ns/1ns
module `TB_NAME;

localparam EXP_BITS = 8;
localparam MAN_BITS = 7;
localparam real INF_VALUE = 170141183460469231731687303715884105728;

string input_file_path = "fp16alt_mult_input.txt";

localparam WIDTH = EXP_BITS+MAN_BITS+1;
localparam BIAS = 2**(EXP_BITS-1)-1;
localparam logic [63:0] INF_VALUE_INT = $rtoi(INF_VALUE*(2**(BIAS+MAN_BITS-1)));
localparam MAX_VALUE_INT_BITS = $clog2(INF_VALUE_INT);


logic clk_i, rst_ni;
logic in_valid_i, in_ready_o, flush_i;

logic [WIDTH-1:0] a_i;
logic [WIDTH-1:0] b_i;

logic [WIDTH-1:0] result_o;
logic [4:0] status_o;

logic out_valid_o, out_ready_i, busy_o;


fp16alt_mult dut (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    .a_i(a_i),
    .b_i(b_i),
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
    string output_string;
    if(fp_value[WIDTH-2:MAN_BITS] == '1) begin
        if(fp_value[MAN_BITS-1:0] == '0) begin
            output_string = fp_value[WIDTH-1] ? "-inf" : "inf";
        end else begin
            output_string = fp_value[WIDTH-1] ? "-nan" : "nan";
        end
    end else begin
        output_string = $sformatf("%b_%b_%b", fp_value[WIDTH-1], fp_value[WIDTH-2:MAN_BITS], fp_value[MAN_BITS-1:0]);
    end
    return output_string;
endfunction



function automatic real get_real_value (
    input logic [WIDTH-1:0] fp_value
);
    // Get fields from input
    logic sign = fp_value[WIDTH-1];
    logic [EXP_BITS-1:0] exp = fp_value[WIDTH-2:MAN_BITS];
    logic [MAN_BITS-1:0] man = fp_value[MAN_BITS-1:0];
    // Output value to be converted to FP64 (real)
    logic [63:0] value_to_real = '0;
    
    // Get signal
    value_to_real[63] = sign;
    
    // If input is zero
    if (fp_value[WIDTH-2:0] == '0) return sign ? -0 : 0;
    
    // If input is subnormal, find position of MSB and shift the mantissa to eliminate the leading 1 (will not be subnormal at FP64)
    else if (exp == '0) begin
        int msb_id=0;
        for (int i=MAN_BITS-1; i>=0; i--) begin
            if(man[i]) begin
                msb_id = i;
                //$display("msb_id: %d", msb_id);
                break;
            end
        end
        value_to_real[62:52] = 1023 - BIAS - MAN_BITS + msb_id + 1;
        value_to_real[51:51-MAN_BITS+1] = man << (MAN_BITS - msb_id);
    end
    
    // If input is normal or inf/NaN, scale the exponent and conserve the mantissa
    else begin
        value_to_real[62:52] = $signed({1'b0,exp}) - BIAS + 1023;
        value_to_real[51:51-MAN_BITS+1] = man;
    end
    
    return $bitstoreal(value_to_real); // covert the value to real
endfunction



function automatic logic [WIDTH-1:0] get_fp_value (
    input real real_value
);
    // Get FP64 representation
    logic [63:0] value_bits = $realtobits(real_value);
    // Get fields of this representation
    logic value_neg = value_bits[63];
    logic [10:0] the_exp = value_bits[62:52];
    logic [MAN_BITS-1:0] the_man = value_bits[51:51-MAN_BITS+1];
    
    // Get other auxiliary values
    int int_the_exp = $signed({1'b0,the_exp})-1023; // Actual exponent unbiased
    logic [MAN_BITS:0] the_man_subn = {1'b1,the_man}; // mantissa for subnormal 
    //$display("The exp int: %d", int_the_exp);

    // Output fields
    logic [EXP_BITS-1:0] exp_bits;
    logic [MAN_BITS-1:0] man_bits;

    // If input is smaller than smallest value possible in our representation (underflow), return zero
    if(int_the_exp < -BIAS-MAN_BITS) begin  
        //$display("%f is underflow", real_value);
        exp_bits = '0;
        man_bits = '0;
    // If value is subnormal at target FP and the leading 1 should not be at MSB of mantissa, shift mantissa
    end else if (int_the_exp < -BIAS) begin // subnormal shifted
        exp_bits = '0;
        man_bits = the_man_subn >> (-BIAS-int_the_exp+1);
        //$display("%f is subnormal shifted and the man is: %b   with shift of %d", real_value, the_man_subn, -BIAS-int_the_exp);
    // If value is subnormal at target FP and the leading 1 should be at MSB of mantissa, conserve mantissa with leading 1
    end else if (int_the_exp == -BIAS) begin
        //$display("%f is subnormal exactly", real_value);
        exp_bits = '0;
        man_bits = the_man_subn[MAN_BITS:1];
    // If value is normal at target FP, conserve mantissa and calculate the exponent
    end else if (int_the_exp <= BIAS) begin
        //$display("%f is normal", real_value);
        exp_bits = int_the_exp + BIAS;
        man_bits = the_man;
    // If value is bigger than bigger value at target FP, return inf
    end else begin // inf
        //$display("%f is inf", real_value);
        exp_bits = '1;
        man_bits = '0;
    end; 
    
    //$display("Generated FP: %s", get_bit_string({value_neg, exp_bits, man_bits}));
    return {value_neg, exp_bits, man_bits};

endfunction



real a, b, c_exp, c_real;
assign c_real = get_real_value(result_o);

logic [WIDTH-1:0] a_fp, b_fp, c_fp_exp;
int NUM_PIPE_REGS = dut.multiplier.NumPipeRegs;

task test_mult;
    $display("Test %g * %g", a, b);
    @(negedge clk_i);
    c_exp = a*b;
    a_i = get_fp_value(a);
    b_i = get_fp_value(b);
    out_ready_i = '1;
    flush_i = '0;
    in_valid_i = '1;
    if(NUM_PIPE_REGS != '0) @(posedge out_valid_o); else @(negedge clk_i);
    $display("%s * %s = %s", get_bit_string(a_i), get_bit_string(b_i), get_bit_string(result_o));
    $display("%g * %g = %g", get_real_value(a_i), get_real_value(b_i), c_real);
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






localparam int NUM_TESTS = 40;  // number of lines in input
logic [3*WIDTH-1:0] testvec [0:NUM_TESTS-1];

initial begin
    $readmemb(input_file_path, testvec);
end


logic [0:2][WIDTH-1:0]fp_values;
task test_out;
    for (int i = 0; i<NUM_TESTS; i=i+1) begin
        @(negedge clk_i);
        fp_values = testvec[i];
        a_i = fp_values[0];
        b_i = fp_values[1];
        a = get_real_value(a_i);
        b = get_real_value(b_i);
        a_fp = a_i;
        b_fp = b_i;
        c_fp_exp = fp_values[2];
        //c_exp = get_real_value(c_fp_exp);
        c_exp = get_real_value(fp_values[2]);

        out_ready_i = '1;
        flush_i = '0;
        in_valid_i = '1;
        if(NUM_PIPE_REGS != '0) @(posedge out_valid_o); else @(negedge clk_i);
        $display("%s * %s = %s", get_bit_string(a_i), get_bit_string(b_i), get_bit_string(result_o));
        $display("%g * %g = %g", get_real_value(a_i), get_real_value(b_i), c_real);
        $display("flags:%b", status_o);
        
        if(result_o==c_fp_exp) begin
            $display("Result OK\n");
        end else if(result_o[WIDTH-2:MAN_BITS]!='1) begin
            $display("Difference: %g - %g = %g\n", c_real, c_exp, c_real-c_exp);
        end else begin
            $display("Inf or Nan detected. Result: %s  Expected: %s\n",get_bit_string(result_o),get_bit_string(c_fp_exp));
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
