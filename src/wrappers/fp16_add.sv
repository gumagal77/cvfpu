localparam WIDTH = 16;

module fp16_add (
	input logic                               clk_i,
  	input logic                               rst_ni,
	// Input signals
  	input logic [WIDTH-1:0] a_i, b_i, // 2 operands of 6 bits
	  // Input Handshake
	input  logic                              in_valid_i,
	output logic                              in_ready_o,
	input  logic                              flush_i,
	// Output signals
	output logic [WIDTH-1:0]                        result_o,
  	output logic [4:0]                status_o,
	// Output handshake
	output logic                              out_valid_o,
	input  logic                              out_ready_i,
	// Indication of valid data in flight
  	output logic                              busy_o
);

/*
localparam fpnew_pkg::fpu_features_t fpu_f = '{
    Width:         6,
    EnableVectors: 1'b0,
    EnableNanBox:  1'b0,
    FpFmtMask:     9'b000000_100,
    IntFmtMask:    4'b0000
  };

localparam fpnew_pkg::fpu_implementation_t fpu_impl = '{
    PipeRegs:   '{default: '{default: 1}},
    UnitTypes:  '{'{default: fpnew_pkg::PARALLEL}, // ADDMUL
                  '{default: fpnew_pkg::DISABLED},   // DIVSQRT
                  '{default: fpnew_pkg::DISABLED}, // NONCOMP
                  '{default: fpnew_pkg::DISABLED},   // CONV
                  '{default: fpnew_pkg::DISABLED},  // DOTP
                  '{default: fpnew_pkg::DISABLED}},  // MXDOTP
    PipeConfig: fpnew_pkg::DISTRIBUTED
  };
*/
fpnew_pkg::status_t status;

fpnew_fma_mini #(.FpFormat(fpnew_pkg::FP16), .NumPipeRegs(0), .PipeConfig(fpnew_pkg::BEFORE)) adder 
           (.clk_i, .rst_ni, .operands_i({b_i,a_i,{(WIDTH){1'd0}}}),
		    .rnd_mode_i(fpnew_pkg::RMM), // round to nearest, tie to even
			.op_i(fpnew_pkg::ADD),
			.op_mod_i('0),
			.in_valid_i, .in_ready_o, .flush_i, //input handshake
			.result_o, .status_o(status), // output data
			.out_valid_o, .out_ready_i, .busy_o); // output handshake

always_comb begin
		status_o[4] = status.NV;
		status_o[3] = status.DZ;
		status_o[2] = status.OF;
		status_o[1] = status.UF;
		status_o[0] = status.NX;	
end



endmodule
