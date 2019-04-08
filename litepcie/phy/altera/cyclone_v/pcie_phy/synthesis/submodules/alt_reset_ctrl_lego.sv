// (C) 2001-2018 Intel Corporation. All rights reserved.
// Your use of Intel Corporation's design tools, logic functions and other 
// software and tools, and its AMPP partner logic functions, and any output 
// files from any of the foregoing (including device programming or simulation 
// files), and any associated documentation or information are expressly subject 
// to the terms and conditions of the Intel Program License Subscription 
// Agreement, Intel FPGA IP License Agreement, or other applicable 
// license agreement, including, without limitation, that your use is for the 
// sole purpose of programming logic devices manufactured by Intel and sold by 
// Intel or its authorized distributors.  Please refer to the applicable 
// agreement for further details.


// 
// Reset controller building block. 
//
// Handles a single reset stage.  Can be daisy-chained with other blocks for purely sequential resets.
// Options include reset pulse length in clock cycles, and a counter for sdone stability checking.
//
//	$Header$
//

`timescale 1 ns / 1 ns

module	alt_reset_ctrl_lego
#(
	parameter	reset_hold_til_rdone = 0,	// 1 means reset stays high until rdone arrives
											// 0 means fixed pulse length, defined by reset_hold_cycles
	parameter	reset_hold_cycles = 1,	// reset pulse length in clock cycles
	parameter	sdone_delay_cycles = 0,	// optional delay from rdone received til sdone sent to next block
	parameter	rdone_is_edge_sensitive = 0	// default is level sensitive rdone
)
(
	// clocks and PLLs
	input	wire	clock,
	input	wire	start,
	input	tri0	aclr,	// active-high asynchronous reset
	output	wire	reset,
	input	tri0	rdone,	// reset done signal
	output	reg 	sdone	// sequence done for this lego
);
	localparam max_precision = 32;	// VCS requires this declaration outside the function
	function integer ceil_log2;
		input [max_precision-1:0] input_num;
		integer i;
		reg [max_precision-1:0] try_result;
		begin
			i = 0;
			try_result = 1;
			while ((try_result << i) < input_num && i < max_precision)
				i = i + 1;
			ceil_log2 = i;
		end
	endfunction

	// How many bits are needed for 'reset_hold_cycles' counter?
	localparam rhc_bits = ceil_log2(reset_hold_cycles);
	localparam rhc_load_constant = (1 << rhc_bits) | (reset_hold_cycles-1);
	// How many bits are needed for 'sdone_delay_cycles' counter?
	localparam sdc_bits = ceil_log2(sdone_delay_cycles);
	localparam sdc_load_constant = (1 << sdc_bits)
		| ((rdone_is_edge_sensitive == 1 && sdone_delay_cycles > 1) ? sdone_delay_cycles-2 : sdone_delay_cycles-1);
	localparam sdone_stable_cycles = (sdone_delay_cycles > 1 ? sdone_delay_cycles+1 : 0);
	
	wire spulse;	// synchronous detection of 'start' 0-to-1 transition
	wire rhold;
	wire timed_reset_in_progress;
	wire rinit_next; // combinatorial input to rinit DFF
	wire rdonei;	// internal selector between rdone and rdsave (rdone_is_edge_sensitive==1)
	wire rdpulse;	// synchronous detection of 'rdone' 0-to-1 transition, when rdone_is_edge_sensitive==1

	reg  zstart = 0;	// delayed value of 'start' input, used for detection of 0-to-1 transition
	reg  rinit = 0;		// state bit that indicates sequence is in progress

	initial begin
		sdone = 0;	// 1 indicates sequence is done
	end


	// 'start' input, detect 0-to-1 transition that triggers sequence
	assign spulse = start & ~zstart;
	always @(posedge clock or posedge aclr)
		if (aclr == 1'b1)
			zstart <= 0;
		else
			zstart <= start;

	// rinit state bit, triggered by spulse, waits while rhold = 1
	assign rinit_next = spulse | (rinit & (rhold | ~rdonei | rdpulse)) | timed_reset_in_progress;
	always @(posedge clock or posedge aclr)
		if (aclr == 1'b1)
			rinit <= 0;
		else
			rinit <= rinit_next;

	// optional internal 'rdone' generation logic, if rdone_is_edge_sensitive==1
	generate
	if (rdone_is_edge_sensitive == 0) begin
		assign rdpulse = 0;
		assign rdonei = rdone;
	end
	else begin
		// instantiate synchronous edge-detection logic for rdone
		reg  zrdone = 0;	// for edge-sensitive rdone, detect 0-to-1 transition synchronously
		reg  rdsave = 0;	// for edge-sensitive rdone, use this as internal rdone
		always @(posedge clock or posedge aclr) begin
			if (aclr == 1'b1) begin
				zrdone <= 0;
				rdsave <= 0;
			end
			else begin
				zrdone <= rdone;	// previous value of rdone for synchronous edge detection
				rdsave <= ~spulse & (rdpulse | rdsave);
			end
		end
		assign rdpulse = rdone & ~zrdone;
		assign rdonei = rdsave;
	end
	endgenerate

	// rhold depends on sdone_delay_cycles and rdone_is_edge_sensitive
	generate
	if (sdone_delay_cycles == 0 || (sdone_delay_cycles == 1 && rdone_is_edge_sensitive == 1))
		assign rhold = ~rdonei;	// sdone_delay_cycles=0
	else begin
		// declare only when needed to avoid Quartus synthesis warnings
		reg  [sdc_bits:0] rhold_reg = 0; // for sdone_delay_cycles > 0
		if (sdone_delay_cycles == 1) begin
			always @(posedge clock or posedge aclr) begin
				if (aclr == 1'b1)
					rhold_reg <= 0;
				else
					rhold_reg <= ~(rinit & rdonei);
			end
			assign rhold = rhold_reg[0];	// sdone_delay_cycles=1
		end
		else begin
			// need to count cycles to make sure rdone is stable
			always @(posedge clock or posedge aclr)
			begin
				if (aclr == 1'b1)
					rhold_reg <= 0;
				else if ((rinit & rdonei & ~rdpulse) == 0)
				  // keep load value until rinit & rdone both high, and no new rdone pulses
					rhold_reg <= sdc_load_constant[sdc_bits:0];
				else
					rhold_reg <= rhold_reg - 1'b1;
			end
			assign rhold = rhold_reg[sdc_bits];	// sdone_delay_cycles > 1
		end
	end
	endgenerate
		
	// sdone state bit indicates that reset sequence completed.  Clear again on 'start'
	always @(posedge clock or posedge aclr)
		if (aclr == 1'b1)
			sdone <= 0;
		else
			sdone <= ~spulse & (sdone | (rinit & ~rinit_next));

	// reset pulse generation logic depends on 2 parameters
	generate
	if (reset_hold_til_rdone == 1) begin
		assign reset = rinit;
		assign timed_reset_in_progress = 0;
	end
	else if (reset_hold_cycles < 1) begin	// 0 is legal, but catch negative (illegal) values too
		assign reset = spulse;
		assign timed_reset_in_progress = 0;
	end
	else begin
		// declare only when needed to avoid Quartus synthesis warnings
		reg  [rhc_bits:0] zspulse = 0;	// bits for reset pulse if fixed length
		assign timed_reset_in_progress = zspulse[rhc_bits];
		assign reset = zspulse[rhc_bits];
		
		if (reset_hold_cycles == 1)
			// a single-cycle reset pulse needs 1 register
			always @(posedge clock or posedge aclr)
				if (aclr == 1'b1)
					zspulse <= 0;
				else
					zspulse <= spulse;
		else begin
			// multi-cycle reset pulse needs a counter
			always @(posedge clock or posedge aclr)
			begin
				if (aclr == 1'b1)
					zspulse <= 0;
				else if (spulse == 1)
					zspulse <= rhc_load_constant[rhc_bits:0];
				else if (zspulse[rhc_bits] == 1)
					zspulse <= zspulse - 1'b1;
			end
		end
	end
	endgenerate

//	generate
//	  case (reset_hold_til_rdone)
//	    0 : m1 U1 (a, b, c);
//	    2 : m2 U1 (a, b, c);
//	    default : m3 U1 (a, b, c);
//	  endcase
//	endgenerate

	// general assertions
	//synopsys translate_off
	// vlog/vcs/ncverilog:  +define+ALTERA_XCVR_ASSERTIONS
`ifdef ALTERA_XCVR_ASSERTIONS
		// when rdone is edge sensitive, last rdone +ve edge triggers sdone +ve edge,
		// 'sdone_delay_cycles' later. "##1 1" is an always-true cycle to match $rise(sdone)
		sequence rdone_last_edge;
			@(posedge clock) $rose(rdone) ##1 !$rose(rdone) [*sdone_delay_cycles] ##1 1;
		endsequence

		// when rdone is level sensitive, stable rdone for 'sdone_delay_cycles' consecutive cycles
		// triggers sdone +ve edge. "##1 1" is an always-true cycle to match $rise(sdone)
		sequence rdone_stable_level;
			@(posedge clock) rdone [*(sdone_delay_cycles+1)] ##1 1;
		endsequence

// Most assertions aren't valid when 'aclr' is active
//`define assert_awake(arg)	assert property (disable iff (aclr) arg )
	always @(aclr)
		if (aclr) $assertkill;
		else $asserton;

	generate
	always @(posedge clock) begin
		// A rising edge on start will result in reset high within 1 clock cycle
		assert property ($rose(start & ~aclr) |-> ##[0:1] reset);
		// A rising edge on reset will result in sdone low within 1 clock cycle
		assert property ($rose(reset) |-> ##[0:1] !sdone);

		// assertions for optional behavior: reset pulse length options
		if (reset_hold_til_rdone == 0 && reset_hold_cycles > 1)
			// Verify fixed-length reset pulse option
			assert property ($rose(reset) |-> reset [*reset_hold_cycles] ##1 !reset)
			else $error("Reset pulse length should be %d", reset_hold_cycles);
		if (reset_hold_til_rdone == 0 && reset_hold_cycles == 1)
			// Verify fixed 1-length reset pulse option
			assert property ($rose(reset) |=> !reset);
		if (reset_hold_til_rdone == 0 && reset_hold_cycles == 0)
			// Verify minimal-length reset pulse option, which mirrors 'start' edge detection
			assert property ($rose(start & ~aclr) |-> reset ##1 !reset);
		if (reset_hold_til_rdone == 1) begin
			// with hold-til-rdone, reset should not deassert until after rdone asserts, then deassert immediately
			assert property ($rose(reset) && !rdone |=> $stable(reset) [*0:$] ##1 (reset && rdone) ##1 !reset);
			assert property ($rose(reset) && rdone ##1 rdone [*sdone_delay_cycles] |=> !reset); // rdone was already high
			//assert property ($rose(reset) && !rdone |-> ##[0:$] rdone ##1 !reset);
		end

		// assertions for optional behavior: sdone delay options and rdone edge sensitive option
		if (rdone_is_edge_sensitive == 1)
			// rdone edge-sensitive option only has an effect when sdone_delay_cycles > 0
			assert property ($rose(sdone) |-> rdone_last_edge.ended);
		if (rdone_is_edge_sensitive == 0)
			// rdone defaults to level-sensitive
			assert property ($rose(sdone) |-> (rdone_stable_level.ended or $past($fell(reset),1)));
	end
	endgenerate
`endif // ALTERA_XCVR_ASSERTIONS
	//synopsys translate_on
endmodule
