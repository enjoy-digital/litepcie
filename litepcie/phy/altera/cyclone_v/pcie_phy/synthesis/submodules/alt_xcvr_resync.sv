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


// Module: alt_xcvr_resync
//
// Description:
//  A general purpose resynchronization module.
//  
//  Parameters:
//    SYNC_CHAIN_LENGTH
//      - Specifies the length of the synchronizer chain for metastability
//        retiming.
//    WIDTH
//      - Specifies the number of bits you want to synchronize. Controls the width of the
//        d and q ports.
//    SLOW_CLOCK - USE WITH CAUTION. 
//      - Leaving this setting at its default will create a standard resynch circuit that
//        merely passes the input data through a chain of flip-flops. This setting assumes
//        that the input data has a pulse width longer than one clock cycle sufficient to
//        satisfy setup and hold requirements on at least one clock edge.
//      - By setting this to 1 (USE CAUTION) you are creating an asynchronous
//        circuit that will capture the input data regardless of the pulse width and 
//        its relationship to the clock. However it is more difficult to apply static
//        timing constraints as it ties the data input to the clock input of the flop.
//        This implementation assumes the data rate is slow enough
//    INIT_VALUE
//      - Specifies the initial values of the synchronization registers.
//
// Apply embedded false path timing constraint
(* altera_attribute  = "-name SDC_STATEMENT \"set regs [get_registers -nowarn *alt_xcvr_resync*sync_r[0]]; if {[llength [query_collection -report -all $regs]] > 0} {set_false_path -to $regs}\"" *)

`timescale 1ps/1ps 

module alt_xcvr_resync #(
    parameter SYNC_CHAIN_LENGTH = 2,  // Number of flip-flops for retiming. Must be >1
    parameter WIDTH             = 1,  // Number of bits to resync
    parameter SLOW_CLOCK        = 0,  // See description above
    parameter INIT_VALUE        = 0
  ) (
  input   wire              clk,
  input   wire              reset,
  input   wire  [WIDTH-1:0] d,
  output  wire  [WIDTH-1:0] q
  );

localparam  INT_LEN       = (SYNC_CHAIN_LENGTH > 1) ? SYNC_CHAIN_LENGTH : 2;
localparam  [INT_LEN-1:0] L_INIT_VALUE = (INIT_VALUE == 1) ? {INT_LEN{1'b1}} : {INT_LEN{1'b0}};

genvar ig;

// Generate a synchronizer chain for each bit
generate begin
  for(ig=0;ig<WIDTH;ig=ig+1) begin : resync_chains
    wire                d_in;   // Input to sychronization chain.
    (* altera_attribute  = "disable_da_rule=D103" *)
    reg   [INT_LEN-1:0] sync_r = L_INIT_VALUE;

    assign  q[ig]   = sync_r[INT_LEN-1]; // Output signal

    always @(posedge clk or posedge reset)
      if(reset)
        sync_r  <= L_INIT_VALUE;
      else
        sync_r  <= {sync_r[INT_LEN-2:0],d_in};

    // Generate asynchronous capture circuit if specified.
    if(SLOW_CLOCK == 0) begin
      assign  d_in = d[ig];
    end else begin
      wire  d_clk;
      reg   d_r = L_INIT_VALUE[0];
      wire  clr_n;

      assign  d_clk = d[ig];
      assign  d_in  = d_r;
      assign  clr_n = ~q[ig] | d_clk; // Clear when output is logic 1 and input is logic 0

      // Asynchronously latch the input signal.
      always @(posedge d_clk or negedge clr_n)
        if(!clr_n)      d_r <= 1'b0;
        else if(d_clk)  d_r <= 1'b1;
    end // SLOW_CLOCK
  end // for loop
end // generate
endgenerate

endmodule
