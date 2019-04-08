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



`timescale 1 ps / 1 ps
module alt_xcvr_reconfig_analog #(
	parameter device_family = "Stratix V"
)
(

input wire reconfig_clk,        // this will be the reconfig clk
input wire reset,

//avalon MM slave
input wire [2:0] analog_reconfig_address,             // MM address
input wire [31:0] analog_reconfig_writedata,
input wire analog_reconfig_write,
input wire analog_reconfig_read,

//output MM slave
output wire [31:0] analog_reconfig_readdata,      // from MM
output wire analog_reconfig_waitrequest,
//output wire analog_reconfig_error,
output wire analog_reconfig_done,
  
// input from base_reconfig
input wire analog_reconfig_irq_from_base,
input wire analog_reconfig_waitrequest_from_base,
  
  
// output to base_reconfig
// Avalon MM Master
output wire [2:0] analog_reconfig_address_base,   // 3 bit MM
output wire [31:0] analog_reconfig_writedata_base,  
output wire analog_reconfig_write_base,                         // start write to GXB
output wire analog_reconfig_read_base,                          // start read from GXB

// input from base reconfig
input wire [31:0] analog_reconfig_readdata_base,         // data from read command
 output wire arb_req,
 input wire arb_grant
);

//parameter device_family = "StratixIV";      // or ArriaII


generate
    //Deepak - added namespace support for CIVGX and AII GX
    if((device_family == "Stratix IV") || (device_family == "Arria II") || (device_family == "Cyclone IV GX") || (device_family == "Arria II GX") || (device_family == "Arria II GZ") || (device_family == "HardCopy IV"))
      begin
	 wire [4:0] w_tgx_analog_reconfig_address_base;	 
        alt_xcvr_reconfig_analog_tgx reconfig_analog_tgx(
            .reconfig_clk(reconfig_clk),
            .reset(reset),
            .analog_reconfig_address(analog_reconfig_address),
            .analog_reconfig_writedata(analog_reconfig_writedata),
            .analog_reconfig_write(analog_reconfig_write),
            .analog_reconfig_read(analog_reconfig_read),
            .analog_reconfig_readdata(analog_reconfig_readdata),
            .analog_reconfig_waitrequest(analog_reconfig_waitrequest),
            .analog_reconfig_done(analog_reconfig_done),
            .analog_reconfig_irq_from_base(analog_reconfig_irq_from_base),
            .analog_reconfig_waitrequest_from_base(analog_reconfig_waitrequest_from_base),
            .analog_reconfig_address_base(analog_reconfig_address_base),
            .analog_reconfig_writedata_base(analog_reconfig_writedata_base),  
            .analog_reconfig_write_base(analog_reconfig_write_base),
            .analog_reconfig_read_base(analog_reconfig_read_base),
            .analog_reconfig_readdata_base(analog_reconfig_readdata_base)
        );
       assign analog_reconfig_address_base = w_tgx_analog_reconfig_address_base[4:2];
       assign arb_req = 1'b0 & arb_grant;	// not currently used in S4 architecture
    end
    else if((device_family == "Stratix V") || (device_family == "Arria V GZ"))
    begin
        alt_xcvr_reconfig_analog_sv reconfig_analog_sv(
            .reconfig_clk(reconfig_clk),
            .reset(reset),
            .analog_reconfig_address(analog_reconfig_address),
            .analog_reconfig_writedata(analog_reconfig_writedata),
            .analog_reconfig_write(analog_reconfig_write),
            .analog_reconfig_read(analog_reconfig_read),
            .analog_reconfig_readdata(analog_reconfig_readdata),
            .analog_reconfig_waitrequest(analog_reconfig_waitrequest),
            .analog_reconfig_done(analog_reconfig_done),
            .analog_reconfig_irq_from_base(analog_reconfig_irq_from_base),
            .analog_reconfig_waitrequest_from_base(analog_reconfig_waitrequest_from_base),
            .analog_reconfig_address_base(analog_reconfig_address_base),
            .analog_reconfig_writedata_base(analog_reconfig_writedata_base),  
            .analog_reconfig_write_base(analog_reconfig_write_base),
            .analog_reconfig_read_base(analog_reconfig_read_base),
            .analog_reconfig_readdata_base(analog_reconfig_readdata_base),
	    .arb_req(arb_req),
	    .arb_grant(arb_grant)					       
						       
        );
    end
    else if(device_family == "Arria V")
    begin
        alt_xcvr_reconfig_analog_av reconfig_analog_av(
            .reconfig_clk(reconfig_clk),
            .reset(reset),
            .analog_reconfig_address(analog_reconfig_address),
            .analog_reconfig_writedata(analog_reconfig_writedata),
            .analog_reconfig_write(analog_reconfig_write),
            .analog_reconfig_read(analog_reconfig_read),
            .analog_reconfig_readdata(analog_reconfig_readdata),
            .analog_reconfig_waitrequest(analog_reconfig_waitrequest),
            .analog_reconfig_done(analog_reconfig_done),
            .analog_reconfig_irq_from_base(analog_reconfig_irq_from_base),
            .analog_reconfig_waitrequest_from_base(analog_reconfig_waitrequest_from_base),
            .analog_reconfig_address_base(analog_reconfig_address_base),
            .analog_reconfig_writedata_base(analog_reconfig_writedata_base),  
            .analog_reconfig_write_base(analog_reconfig_write_base),
            .analog_reconfig_read_base(analog_reconfig_read_base),
            .analog_reconfig_readdata_base(analog_reconfig_readdata_base),
	    .arb_req(arb_req),
	    .arb_grant(arb_grant)					       
						       
        );
    end	
    else if(device_family == "Cyclone V")
    begin
        alt_xcvr_reconfig_analog_av reconfig_analog_cv(
            .reconfig_clk(reconfig_clk),
            .reset(reset),
            .analog_reconfig_address(analog_reconfig_address),
            .analog_reconfig_writedata(analog_reconfig_writedata),
            .analog_reconfig_write(analog_reconfig_write),
            .analog_reconfig_read(analog_reconfig_read),
            .analog_reconfig_readdata(analog_reconfig_readdata),
            .analog_reconfig_waitrequest(analog_reconfig_waitrequest),
            .analog_reconfig_done(analog_reconfig_done),
            .analog_reconfig_irq_from_base(analog_reconfig_irq_from_base),
            .analog_reconfig_waitrequest_from_base(analog_reconfig_waitrequest_from_base),
            .analog_reconfig_address_base(analog_reconfig_address_base),
            .analog_reconfig_writedata_base(analog_reconfig_writedata_base),  
            .analog_reconfig_write_base(analog_reconfig_write_base),
            .analog_reconfig_read_base(analog_reconfig_read_base),
            .analog_reconfig_readdata_base(analog_reconfig_readdata_base),
	    .arb_req(arb_req),
	    .arb_grant(arb_grant)					       
						       
        );
    end
    else
    begin
        assign analog_reconfig_readdata = 32'd0;
        assign analog_reconfig_waitrequest = 1'd0;
        assign analog_reconfig_done = 1'd1;
        assign analog_reconfig_address_base = 3'd0;
        assign analog_reconfig_writedata_base = 32'd0;
        assign analog_reconfig_write_base = 1'd0;
        assign analog_reconfig_read_base = 1'd0;
        assign arb_req = 1'd0;
    end

endgenerate


endmodule
