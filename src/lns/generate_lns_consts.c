#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <stdint.h>

void print_hex_to_string(char *out_string, unsigned int value_to_write, unsigned int num_bits){
    out_string[0] = '\0';
    //printf("i=%d\n",(num_bits/4));
    for(int i=(num_bits+3)/4-1, j=0; i>=0; i--, j++){
        unsigned int digit_to_write = value_to_write >> (i*4);
        digit_to_write &= 0xF;
        //printf("Digit %X\n",digit_to_write);
        sprintf(out_string + j,"%1X",digit_to_write);
    }

}


int main(int argc, char **argv){

    ////// INT TO LNS CONVERSION

    /*
initial begin
    $display("INT TO LNS");
    for(int i=0; i<M2M; i++) begin
        log_value = $ln(1.0+i/$itor(M2M))/$ln(2); // log_2(1+m)
        corresponding_int = $rtoi($ceil(log_value*N2N));
        value_to_write = corresponding_int - i*2;
        values[i] = value_to_write[R:0];
        $display("Input: %b Log value: %f Corresponding int: %b Value to write: %b",i[M:0],log_value,corresponding_int[M:0],values[i]);
    end
end
    */

    if(argc<2){
        printf("Error. Missing N value\n");
        return 1;
    }else if(argc == 3){
        unsigned int N = atoi(argv[1]) > 8 ? 8 : atoi(argv[1]);
        unsigned int M = N-1;
        unsigned int R = 4*N/5 + 1;
        FILE *fptr;
        fptr = fopen("./correct_lns_mitchell_gen.sv", "w");
        fprintf(fptr,"\
module correct_lns_mitchell #(\n\
    parameter N = %d,  // Parameter to define the bit-width of the operand\n\
    parameter USE_COR = 1\n\
) (\n\
    input [N-2:0] frac,\n\
    output [4*N/5:0] correction\n\
);\n\
\n\
/* verilator lint_off UNUSEDSIGNAL */\n\n", N);
        fprintf(fptr, "\nassign correction = '0;\n");
        fprintf(fptr, "\nendmodule\n");
        fclose(fptr);

        fptr = fopen("./correct_lns_inv_mitchell_gen.sv", "w");

        N *= 2;
        M = N-1;
        R = 4*N/5 + 1;

        fprintf(fptr,"\
module correct_lns_inv_mitchell #(\n\
    parameter N = %d,  // Parameter to define the bit-width of the operand\n\
    parameter USE_COR = 1\n\
) (\n\
    input [N-1:0] frac,\n\
    output [4*N/5:0] correction\n\
);\n\
\n\
/* verilator lint_off UNUSEDSIGNAL */\n\n", N);
        fprintf(fptr, "\nassign correction = '0;\n");
        fprintf(fptr, "\nendmodule\n");
        fclose(fptr);
        return 0;
    }





    FILE *fptr;
    fptr = fopen("./correct_lns_mitchell_gen.sv", "w");

    unsigned int N = atoi(argv[1]) > 8 ? 8 : atoi(argv[1]);
    unsigned int M = N-1;
    unsigned int N2N = 1 << N;
    unsigned int M2M = 1 << M;
    unsigned int R = 4*N/5 + 1;


    printf("Generating INT TO LNS\n");

    fprintf(fptr,"\
module correct_lns_mitchell #(\n\
    parameter N = %d,  // Parameter to define the bit-width of the operand\n\
    parameter USE_COR = 1\n\
) (\n\
    input [N-2:0] frac,\n\
    output [4*N/5:0] correction\n\
);\n\
\n\
/* verilator lint_off UNUSEDSIGNAL */\n\
\n\
logic [%d:0] values [%ld:0];\n\n", N, R-1, (1<<M)-1);


    for(int i=0; i<M2M; i++){
        double log_value = log2(1.0+((double)i)/((double)M2M));
        //unsigned long corresponding_int = (unsigned long)ceil(log_value*N2N);
        unsigned long corresponding_int = atoi(argv[1]) > 8 ? (unsigned long)floor(log_value*N2N) : (unsigned long)ceil(log_value*N2N);
        unsigned long value_to_write = corresponding_int - i*2;
        if(value_to_write >= (1<<R)) printf("Overflow at %f => %d\n",i/(double)M2M, value_to_write);
        value_to_write &= ((1<<R)-1);
        char string_print[10];
        print_hex_to_string(string_print, value_to_write, R);
        //printf("Input: %X Log value: %f Corresponding int: %X Value to write: %s\n", i, log_value, corresponding_int, string_print);
        fprintf(fptr, "assign values[% 6d] = %d'h%s;\n", i, R, string_print);
    }
    fprintf(fptr, "\nassign correction = USE_COR ? values[frac] : '0;\n");
    fprintf(fptr, "\nendmodule\n");
    fclose(fptr);

    ////// INT TO LNS CONVERSION

    /*
initial begin
    $display("LNS to INT");
    for(int i=0; i<N2N; i++) begin
        exp_value = 2.0**(i/$itor(N2N))-1; // 2^(m)
        corresponding_int = $rtoi($floor(exp_value*N2N));
        value_to_write = i-corresponding_int;
        values[i] = value_to_write[R:0];
        $display("Input: %b Exp value: %f Corresponding int: %b Value to write: %b",i[M:0],exp_value,corresponding_int[M:0],values[i]);
    end
end
    */

    fptr = fopen("./correct_lns_inv_mitchell_gen.sv", "w");

    N *= 2;
    M = N-1;
    N2N = 1 << N;
    M2M = 1 << M;
    R = 4*N/5 + 1;

    printf("Generating LNS TO INT\n");
    
    fprintf(fptr,"\
module correct_lns_inv_mitchell #(\n\
    parameter N = %d,  // Parameter to define the bit-width of the operand\n\
    parameter USE_COR = 1\n\
) (\n\
    input [N-1:0] frac,\n\
    output [4*N/5:0] correction\n\
);\n\
\n\
/* verilator lint_off UNUSEDSIGNAL */\n\
\n\
logic [%d:0] values [%ld:0];\n\n", N, R-1, (1<<N)-1);

    for(int i=0; i<N2N; i++){
        double exp_value = exp2((double)i/(double)N2N) - 1.0;
        //unsigned long corresponding_int = (unsigned long)(exp_value*N2N);
        unsigned long corresponding_int = atoi(argv[1]) > 8 ? (unsigned long)ceil(exp_value*N2N) : (unsigned long)(exp_value*N2N);
        unsigned long value_to_write = i-corresponding_int;
        value_to_write &= ((1<<R)-1);
        if(value_to_write >= (1<<R)) printf("Overflow at %f => %d\n",i/(double)M2M, value_to_write);
        char string_print[10];
        print_hex_to_string(string_print, value_to_write, R);
        //printf("Input: %X Exp value: %f Corresponding int: %X Value to write: %s\n", i, exp_value, corresponding_int, string_print);
        fprintf(fptr, "assign values[% 7d] = %d'h%s;\n", i, R, string_print);
    }
    fprintf(fptr, "\nassign correction = USE_COR ? values[frac] : '0;\n");
    fprintf(fptr, "\nendmodule\n");
    fclose(fptr);

    return 0;
}