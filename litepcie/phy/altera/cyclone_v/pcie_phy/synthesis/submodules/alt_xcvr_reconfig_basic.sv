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



`timescale 1 ns / 1 ps

module alt_xcvr_reconfig_basic #(
    parameter basic_ifs = 1,    // post-merge, allow multiple basic interfaces
    parameter native_ifs = 1,   // number of native reconfig interfaces
    parameter device_family = "Stratix V",
    parameter physical_channel_mapping = ""
) (
    // avalon clock interface
    input wire reconfig_clk,
    input wire reset,
    input wire lif_is_active,

    // avalon MM, "basic" interface
    input wire [basic_ifs   -1:0] basic_reconfig_write,
    input wire [basic_ifs   -1:0] basic_reconfig_read,
    input wire [basic_ifs*32-1:0] basic_reconfig_writedata,
    input wire [basic_ifs*3 -1:0] basic_reconfig_address,     // address to MM described below
    
    output reg  [basic_ifs*32-1:0] basic_reconfig_readdata,
    output wire [basic_ifs   -1:0] basic_reconfig_waitrequest,
    //output reg [basic_ifs-1:0] basic_reconfig_irq,    // interrupt to Master

    // native testbus interfaces: to logical interface:
    output wire [basic_ifs*8 -1:0] lch_testbus, // testbus from native reconfig, for selected channel
    output wire [basic_ifs*24-1:0] pch_testbus, // testbus from native reconfig, for entire triplet
    output wire                    lch_atbout,   // voltage comparator output from native reconfig, for selected channel

        // gate soft-IPs from running by holding off logical mutex until interface select is done
        output wire ifsel_notdone,

    // bundled reconfig buses
//  input  wire reconfig_busy, // input from reconfig master blocks, to forward through the bundles
    input  wire oc_cal_busy,
    input  wire tx_cal_busy,
    input  wire rx_cal_busy,
    output wire [altera_xcvr_functions::get_reconfig_to_width(device_family,native_ifs) -1:0] reconfig_to_xcvr, // all inputs from reconfig block to native xcvr reconfig ports
    input  wire [altera_xcvr_functions::get_reconfig_from_width(device_family,native_ifs)-1:0] reconfig_from_xcvr // all input s from native xcvr reconfig ports to reconfig block
);
    import altera_xcvr_functions::*;

    localparam  is_s5 = has_s5_style_hssi(device_family);
    localparam  is_a5 = has_a5_style_hssi(device_family);
    localparam  is_c5 = has_c5_style_hssi(device_family);

    // Conditional generation of sub-instances
    generate
    
    // s5 => sv_xcvr_reconfig_basic
    if ( is_s5 ) begin
        sv_xcvr_reconfig_basic #(
            .basic_ifs(basic_ifs),
            .native_ifs(native_ifs),
            .physical_channel_mapping(physical_channel_mapping)
        ) s5 (
            .reconfig_clk(reconfig_clk),
            .reset(reset),
            .lif_is_active(lif_is_active),
            .basic_reconfig_write(basic_reconfig_write),
            .basic_reconfig_read(basic_reconfig_read),
            .basic_reconfig_writedata(basic_reconfig_writedata),
            .basic_reconfig_address(basic_reconfig_address),
            .basic_reconfig_readdata(basic_reconfig_readdata),
            .basic_reconfig_waitrequest(basic_reconfig_waitrequest),
            .lch_testbus(lch_testbus),
            .pch_testbus(pch_testbus),
            .ifsel_notdone(ifsel_notdone),
            .oc_cal_busy(oc_cal_busy),
            .tx_cal_busy(tx_cal_busy),
            .rx_cal_busy(rx_cal_busy),
            .reconfig_to_xcvr(reconfig_to_xcvr),
            .reconfig_from_xcvr(reconfig_from_xcvr)
        );
    assign lch_atbout = 1'b0;
    end
    else if (is_a5 || is_c5) begin
        av_xcvr_reconfig_basic #(
            .basic_ifs(basic_ifs),
            .native_ifs(native_ifs),
            .physical_channel_mapping(physical_channel_mapping)
        ) a5 (
            .reconfig_clk(reconfig_clk),
            .reset(reset),
            .lif_is_active(lif_is_active),
            .basic_reconfig_write(basic_reconfig_write),
            .basic_reconfig_read(basic_reconfig_read),
            .basic_reconfig_writedata(basic_reconfig_writedata),
            .basic_reconfig_address(basic_reconfig_address),
            .basic_reconfig_readdata(basic_reconfig_readdata),
            .basic_reconfig_waitrequest(basic_reconfig_waitrequest),
            .lch_testbus(lch_testbus),
            .pch_testbus(pch_testbus),
	    .atbout(lch_atbout),
            .ifsel_notdone(ifsel_notdone),
            .oc_cal_busy(oc_cal_busy),
            .tx_cal_busy(tx_cal_busy),
            .rx_cal_busy(rx_cal_busy),
            .reconfig_to_xcvr(reconfig_to_xcvr),
            .reconfig_from_xcvr(reconfig_from_xcvr)
        );
    end
    // default case when family did not match known strings
    else begin
        initial begin
            $display("Critical Warning: device_family value, '%s', is not supported", current_device_family(device_family));
        end
    end

    endgenerate

endmodule
