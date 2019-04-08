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


import altera_xcvr_functions::*;

`timescale 1 ns / 1 ns

//***************************************************************************
// Module: alt_xcvr_reconfig_cpu_ram
//
// Description:
//    A simple single clock true dual-port RAM. 32-bit data width with byte enable signals
//
//
module alt_xcvr_reconfig_cpu_ram #(
    parameter DEPTH = 4096
) (
  input                             clk,
  // Port A
  input       [clogb2(DEPTH-1)-1:0] a_address,
  input                             a_write,
  input       [3:0]                 a_byteenable,
  input       [31:0]                a_writedata,
  output  reg [31:0]                a_readdata,
  
  // clock enable input of alt_sync_ram
  input                             ram_ce, 
  // Port B
  input       [clogb2(DEPTH-1)-1:0] b_address,
  input                             b_write,
  input       [3:0]                 b_byteenable,
  input       [31:0]                b_writedata,
  output  reg [31:0]                b_readdata
);

	altsyncram	altsyncram_component (
	  .clock0         (clk          ),
	  .wren_a         (a_write      ),
	  .address_b      (b_address    ),
	  .data_b         (b_writedata  ),
	  .wren_b         (b_write      ),
	  .address_a      (a_address    ),
	  .data_a         (a_writedata  ),
	  .q_a            (a_readdata   ),
	  .q_b            (b_readdata   ),
	  .aclr0          (1'b0         ),
	  .aclr1          (1'b0         ),
	  .addressstall_a (1'b0         ),
	  .addressstall_b (1'b0         ),
	  .byteena_a      (a_byteenable ),
	  .byteena_b      (b_byteenable ),
	  .clock1         (/*unused*/   ),
	  .clocken0       (ram_ce       ),
	  .clocken1       (1'b1         ),
	  .clocken2       (1'b1         ),
	  .clocken3       (1'b1         ),
	  .eccstatus      (/*unused*/   ),
	  .rden_a         (1'b1         ),
	  .rden_b         (1'b1         )
  );
	defparam
		altsyncram_component.address_reg_b = "CLOCK0",
		altsyncram_component.byteena_reg_b = "CLOCK0",
		altsyncram_component.byte_size = 8,
		altsyncram_component.clock_enable_input_a = "NORMAL",
		altsyncram_component.clock_enable_input_b = "NORMAL",
		altsyncram_component.clock_enable_output_a = "NORMAL",
		altsyncram_component.clock_enable_output_b = "NORMAL",
		altsyncram_component.indata_reg_b = "CLOCK0",
		altsyncram_component.init_file = "alt_xcvr_reconfig_cpu_ram.hex",
		altsyncram_component.intended_device_family = "Stratix V",
		altsyncram_component.lpm_type = "altsyncram",
		altsyncram_component.numwords_a = DEPTH,
		altsyncram_component.numwords_b = DEPTH,
		altsyncram_component.operation_mode = "BIDIR_DUAL_PORT",
		altsyncram_component.outdata_aclr_a = "NONE",
		altsyncram_component.outdata_aclr_b = "NONE",
		altsyncram_component.outdata_reg_a = "UNREGISTERED",
		altsyncram_component.outdata_reg_b = "UNREGISTERED",
		altsyncram_component.power_up_uninitialized = "FALSE",
		altsyncram_component.read_during_write_mode_mixed_ports = "OLD_DATA",
		altsyncram_component.read_during_write_mode_port_a = "NEW_DATA_NO_NBE_READ",
		altsyncram_component.read_during_write_mode_port_b = "NEW_DATA_NO_NBE_READ",
		altsyncram_component.widthad_a = clogb2(DEPTH-1),
		altsyncram_component.widthad_b = clogb2(DEPTH-1),
		altsyncram_component.width_a = 32,
		altsyncram_component.width_b = 32,
		altsyncram_component.width_byteena_a = 4,
		altsyncram_component.width_byteena_b = 4,
		altsyncram_component.wrcontrol_wraddress_reg_b = "CLOCK0";


/*
//reg [31:0]  ram [0:DEPTH-1];
(* ramstyle="no_rw_check" *)
logic [3:0][7:0] ram[0:DEPTH-1];

// Port A
always_ff @(posedge clk) begin
  // write
  if(a_write) begin
    if(a_byteenable[0]) ram[a_address][0] <= a_writedata[ 7: 0];
    if(a_byteenable[1]) ram[a_address][1] <= a_writedata[15: 8];
    if(a_byteenable[2]) ram[a_address][2] <= a_writedata[23:16];
    if(a_byteenable[3]) ram[a_address][3] <= a_writedata[31:24];
  end
  // read
  a_readdata  <= ram[a_address];
end

// Port B
always_ff @(posedge clk) begin
  // write
  if(b_write) begin
    if(b_byteenable[0]) ram[b_address][0] <= b_writedata[ 7: 0];
    if(b_byteenable[1]) ram[b_address][1] <= b_writedata[15: 8];
    if(b_byteenable[2]) ram[b_address][2] <= b_writedata[23:16];
    if(b_byteenable[3]) ram[b_address][3] <= b_writedata[31:24];
  end
  // read
  b_readdata  <= ram[b_address];
end
*/
endmodule
