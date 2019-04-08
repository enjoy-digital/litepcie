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
module alt_xcvr_reconfig_offset_cancellation
#(
	parameter device_family = "StratixV",
    parameter number_of_reconfig_interfaces = 1
)
(
    input wire reconfig_clk,        // this will be the reconfig clk
    input wire reset,

    //avalon MM slave
    input wire [2:0]  offset_cancellation_address,             // MM address
    input wire [31:0] offset_cancellation_writedata,
    input wire offset_cancellation_write,
    input wire offset_cancellation_read,

    //output MM slave
    output wire [31:0] offset_cancellation_readdata,      // from MM

    output wire offset_cancellation_done,

    // input from base_reconfig
    input wire offset_cancellation_irq_from_base,
    input wire offset_cancellation_waitrequest_from_base,
    output wire offset_cancellation_waitrequest,

    // output to base_reconfig
    // Avalon MM Master
    output wire [2:0] offset_cancellation_address_base,   // 3 bit MM
    output wire [31:0] offset_cancellation_writedata_base,
    output wire offset_cancellation_write_base,                         // start write to GXB
    output wire offset_cancellation_read_base,                          // start read from GXB

    // input from base reconfig
    input wire [31:0] offset_cancellation_readdata_base,         // data from read command

    // Avalon ST
    input wire [number_of_reconfig_interfaces*16 - 1 : 0] testbus_data,

	// external connect to switch fabric: request basic access from arbiter
	output wire arb_req,
	input  wire arb_grant

);

import altera_xcvr_functions::*;
localparam is_s4 = has_s4_style_hssi(device_family);
localparam is_s5 = has_s5_style_hssi(device_family);
localparam is_a5 = has_a5_style_hssi(device_family);
localparam is_c5 = has_c5_style_hssi(device_family);

generate
    //Deepak - Namespace support for AII GX and CIVGX
    if(is_s4)
    begin
        wire [4:0] w_tgx_offset_cancellation_address_base;
        alt_xcvr_reconfig_offset_cancellation_tgx
        #(
    	    .device_family(device_family),
            .number_of_reconfig_interfaces(number_of_reconfig_interfaces)
        ) offset_cancellation_tgx
        (
            .reconfig_clk(reconfig_clk),
            .reset(reset),
            .offset_cancellation_address(offset_cancellation_address),
            .offset_cancellation_writedata(offset_cancellation_writedata),
            .offset_cancellation_write(offset_cancellation_write),
            .offset_cancellation_read(offset_cancellation_read),
            .offset_cancellation_readdata(offset_cancellation_readdata),
            .offset_cancellation_done(offset_cancellation_done),
            .offset_cancellation_irq_from_base(offset_cancellation_irq_from_base),
            .offset_cancellation_waitrequest_from_base(offset_cancellation_waitrequest_from_base),
            .offset_cancellation_waitrequest(offset_cancellation_waitrequest),
            .offset_cancellation_address_base(w_tgx_offset_cancellation_address_base),
            .offset_cancellation_writedata_base(offset_cancellation_writedata_base),
            .offset_cancellation_write_base(offset_cancellation_write_base),
            .offset_cancellation_read_base(offset_cancellation_read_base),
            .offset_cancellation_readdata_base(offset_cancellation_readdata_base),
            .testbus_data(testbus_data)
        );
        assign offset_cancellation_address_base = w_tgx_offset_cancellation_address_base[4:2];
        assign arb_req = 1'b0 & arb_grant;	// not currently used in S4 architecture
    end
    else if (is_s5)
    begin
        alt_xcvr_reconfig_offset_cancellation_sv
        #(
    	    .device_family(device_family),
            .number_of_reconfig_interfaces(number_of_reconfig_interfaces)
        ) offset_cancellation_sv
        (
            .reconfig_clk(reconfig_clk),
            .reset(reset),
            .offset_cancellation_address(offset_cancellation_address),
            .offset_cancellation_writedata(offset_cancellation_writedata),
            .offset_cancellation_write(offset_cancellation_write),
            .offset_cancellation_read(offset_cancellation_read),
            .offset_cancellation_readdata(offset_cancellation_readdata),
            .offset_cancellation_done(offset_cancellation_done),
            .offset_cancellation_irq_from_base(offset_cancellation_irq_from_base),
            .offset_cancellation_waitrequest_from_base(offset_cancellation_waitrequest_from_base),
            .offset_cancellation_waitrequest(offset_cancellation_waitrequest),
            .offset_cancellation_address_base(offset_cancellation_address_base),
            .offset_cancellation_writedata_base(offset_cancellation_writedata_base),
            .offset_cancellation_write_base(offset_cancellation_write_base),
            .offset_cancellation_read_base(offset_cancellation_read_base),
            .offset_cancellation_readdata_base(offset_cancellation_readdata_base),
            .testbus_data(testbus_data[7:0]), // testbus data is now provided on a per-channel basis from the 'B' - only need the lower 8 bits
            .arb_req(arb_req),
            .arb_grant(arb_grant)
        );
    end
    else if (is_a5 || is_c5)
    begin
        alt_xcvr_reconfig_offset_cancellation_av
        #(
    	    .device_family(device_family),
            .number_of_reconfig_interfaces(number_of_reconfig_interfaces)
        ) offset_cancellation_av
        (
            .reconfig_clk(reconfig_clk),
            .reset(reset),
            .offset_cancellation_address(offset_cancellation_address),
            .offset_cancellation_writedata(offset_cancellation_writedata),
            .offset_cancellation_write(offset_cancellation_write),
            .offset_cancellation_read(offset_cancellation_read),
            .offset_cancellation_readdata(offset_cancellation_readdata),
            .offset_cancellation_done(offset_cancellation_done),
            .offset_cancellation_irq_from_base(offset_cancellation_irq_from_base),
            .offset_cancellation_waitrequest_from_base(offset_cancellation_waitrequest_from_base),
            .offset_cancellation_waitrequest(offset_cancellation_waitrequest),
            .offset_cancellation_address_base(offset_cancellation_address_base),
            .offset_cancellation_writedata_base(offset_cancellation_writedata_base),
            .offset_cancellation_write_base(offset_cancellation_write_base),
            .offset_cancellation_read_base(offset_cancellation_read_base),
            .offset_cancellation_readdata_base(offset_cancellation_readdata_base),
            .testbus_data(testbus_data[7:0]), // testbus data is now provided on a per-channel basis from the 'B' - only need the lower 8 bits
            .arb_req(arb_req),
            .arb_grant(arb_grant)
        );
    end
    else
    begin
        assign offset_cancellation_readdata = 32'd0;
        assign offset_cancellation_done = 1'd0;
        assign offset_cancellation_waitrequest = 1'd0;
        assign offset_cancellation_address_base = 3'd0;
        assign offset_cancellation_writedata_base = 32'd0;
        assign offset_cancellation_write_base = 1'd0;
        assign offset_cancellation_read_base = 1'd0;
        assign arb_req = 1'd0;
    end
    


endgenerate

endmodule


