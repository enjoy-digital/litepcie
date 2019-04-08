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


// Verilog RBC parameter resolution wrapper for arriav_hssi_rx_pld_pcs_interface
//

`timescale 1 ns / 1 ps

module av_hssi_rx_pld_pcs_interface_rbc #(
	// unconstrained parameters

	// extra unconstrained parameters found in atom map
	parameter avmm_group_channel_index = 0,	// 0..2
	parameter is_8g_0ppm = "false",	// false, true
	parameter pcs_side_block_sel = "eight_g_pcs",	// default, eight_g_pcs
	parameter pld_side_data_source = "pld",	// hip, pld
	parameter use_default_base_address = "true",	// false, true
	parameter user_base_address = 0	// 0..2047

	// constrained parameters
) (
	// ports
	output wire         	asynchdatain,
	input  wire   [10:0]	avmmaddress,
	input  wire    [1:0]	avmmbyteen,
	input  wire         	avmmclk,
	input  wire         	avmmread,
	output wire   [15:0]	avmmreaddata,
	input  wire         	avmmrstn,
	input  wire         	avmmwrite,
	input  wire   [15:0]	avmmwritedata,
	output wire         	blockselect,
	input  wire         	clockinfrom8gpcs,
	input  wire   [63:0]	datainfrom8gpcs,
	output wire   [63:0]	dataouttopld,
	input  wire         	emsipenablediocsrrdydly,
	output wire  [128:0]	emsiprxout,
	input  wire   [12:0]	emsiprxspecialin,
	output wire   [15:0]	emsiprxspecialout,
	input  wire    [3:0]	pcs8ga1a2k1k2flag,
	output wire         	pcs8ga1a2size,
	input  wire         	pcs8galignstatus,
	input  wire         	pcs8gbistdone,
	input  wire         	pcs8gbisterr,
	output wire         	pcs8gbitlocreven,
	output wire         	pcs8gbitslip,
	input  wire         	pcs8gbyteordflag,
	output wire         	pcs8gbytereven,
	output wire         	pcs8gbytordpld,
	output wire         	pcs8gcmpfifourst,
	input  wire         	pcs8gemptyrmf,
	input  wire         	pcs8gemptyrx,
	output wire         	pcs8gencdt,
	input  wire         	pcs8gfullrmf,
	input  wire         	pcs8gfullrx,
	output wire         	pcs8gphfifourstrx,
	output wire         	pcs8gpldrxclk,
	output wire         	pcs8gpolinvrx,
	output wire         	pcs8grdenablermf,
	output wire         	pcs8grdenablerx,
	input  wire         	pcs8grlvlt,
	input  wire    [3:0]	pcs8grxdatavalid,
	output wire         	pcs8grxurstpcs,
	input  wire         	pcs8gsignaldetectout,
	output wire         	pcs8gsyncsmenoutput,
	input  wire    [4:0]	pcs8gwaboundary,
	output wire         	pcs8gwrdisablerx,
	output wire         	pcs8gwrenablermf,
	output wire    [3:0]	pld8ga1a2k1k2flag,
	input  wire         	pld8ga1a2size,
	output wire         	pld8galignstatus,
	output wire         	pld8gbistdone,
	output wire         	pld8gbisterr,
	input  wire         	pld8gbitlocreven,
	input  wire         	pld8gbitslip,
	output wire         	pld8gbyteordflag,
	input  wire         	pld8gbytereven,
	input  wire         	pld8gbytordpld,
	input  wire         	pld8gcmpfifourstn,
	output wire         	pld8gemptyrmf,
	output wire         	pld8gemptyrx,
	input  wire         	pld8gencdt,
	output wire         	pld8gfullrmf,
	output wire         	pld8gfullrx,
	input  wire         	pld8gphfifourstrxn,
	input  wire         	pld8gpldrxclk,
	input  wire         	pld8gpolinvrx,
	input  wire         	pld8grdenablermf,
	input  wire         	pld8grdenablerx,
	output wire         	pld8grlvlt,
	output wire         	pld8grxclkout,
	output wire    [3:0]	pld8grxdatavalid,
	input  wire         	pld8grxurstpcsn,
	output wire         	pld8gsignaldetectout,
	input  wire         	pld8gsyncsmeninput,
	output wire    [4:0]	pld8gwaboundary,
	input  wire         	pld8gwrdisablerx,
	input  wire         	pld8gwrenablermf,
	input  wire         	pldrxclkslipin,
	output wire         	pldrxclkslipout,
	input  wire         	pldrxpmarstbin,
	output wire         	pldrxpmarstbout,
	input  wire         	pmarxplllock,
	output wire         	reset,
	input  wire         	rstsel,
	input  wire         	usrrstsel
);
	import altera_xcvr_functions::*;

	// is_8g_0ppm external parameter (no RBC)
	localparam rbc_all_is_8g_0ppm = "(false,true)";
	localparam rbc_any_is_8g_0ppm = "false";
	localparam fnl_is_8g_0ppm = (is_8g_0ppm == "<auto_any>" || is_8g_0ppm == "<auto_single>") ? rbc_any_is_8g_0ppm : is_8g_0ppm;

	// pcs_side_block_sel external parameter (no RBC)
	localparam rbc_all_pcs_side_block_sel = "(default,eight_g_pcs)";
	localparam rbc_any_pcs_side_block_sel = "eight_g_pcs";
	localparam fnl_pcs_side_block_sel = (pcs_side_block_sel == "<auto_any>" || pcs_side_block_sel == "<auto_single>") ? rbc_any_pcs_side_block_sel : pcs_side_block_sel;

	// pld_side_data_source external parameter (no RBC)
	localparam rbc_all_pld_side_data_source = "(hip,pld)";
	localparam rbc_any_pld_side_data_source = "pld";
	localparam fnl_pld_side_data_source = (pld_side_data_source == "<auto_any>" || pld_side_data_source == "<auto_single>") ? rbc_any_pld_side_data_source : pld_side_data_source;

	// use_default_base_address external parameter (no RBC)
	localparam rbc_all_use_default_base_address = "(false,true)";
	localparam rbc_any_use_default_base_address = "true";
	localparam fnl_use_default_base_address = (use_default_base_address == "<auto_any>" || use_default_base_address == "<auto_single>") ? rbc_any_use_default_base_address : use_default_base_address;

	// Validate input parameters against known values or RBC values
	initial begin
		//$display("is_8g_0ppm = orig: '%s', any:'%s', all:'%s', final: '%s'", is_8g_0ppm, rbc_any_is_8g_0ppm, rbc_all_is_8g_0ppm, fnl_is_8g_0ppm);
		if (!is_in_legal_set(is_8g_0ppm, rbc_all_is_8g_0ppm)) begin
			$display("Critical Warning: parameter 'is_8g_0ppm' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", is_8g_0ppm, rbc_all_is_8g_0ppm, fnl_is_8g_0ppm);
		end
		//$display("pcs_side_block_sel = orig: '%s', any:'%s', all:'%s', final: '%s'", pcs_side_block_sel, rbc_any_pcs_side_block_sel, rbc_all_pcs_side_block_sel, fnl_pcs_side_block_sel);
		if (!is_in_legal_set(pcs_side_block_sel, rbc_all_pcs_side_block_sel)) begin
			$display("Critical Warning: parameter 'pcs_side_block_sel' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", pcs_side_block_sel, rbc_all_pcs_side_block_sel, fnl_pcs_side_block_sel);
		end
		//$display("pld_side_data_source = orig: '%s', any:'%s', all:'%s', final: '%s'", pld_side_data_source, rbc_any_pld_side_data_source, rbc_all_pld_side_data_source, fnl_pld_side_data_source);
		if (!is_in_legal_set(pld_side_data_source, rbc_all_pld_side_data_source)) begin
			$display("Critical Warning: parameter 'pld_side_data_source' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", pld_side_data_source, rbc_all_pld_side_data_source, fnl_pld_side_data_source);
		end
		//$display("use_default_base_address = orig: '%s', any:'%s', all:'%s', final: '%s'", use_default_base_address, rbc_any_use_default_base_address, rbc_all_use_default_base_address, fnl_use_default_base_address);
		if (!is_in_legal_set(use_default_base_address, rbc_all_use_default_base_address)) begin
			$display("Critical Warning: parameter 'use_default_base_address' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", use_default_base_address, rbc_all_use_default_base_address, fnl_use_default_base_address);
		end
	end

	arriav_hssi_rx_pld_pcs_interface #(
		.avmm_group_channel_index(avmm_group_channel_index),
		.is_8g_0ppm(fnl_is_8g_0ppm),
		.pcs_side_block_sel(fnl_pcs_side_block_sel),
		.pld_side_data_source(fnl_pld_side_data_source),
		.use_default_base_address(fnl_use_default_base_address),
		.user_base_address(user_base_address)
	) wys (
		// ports
		.asynchdatain(asynchdatain),
		.avmmaddress(avmmaddress),
		.avmmbyteen(avmmbyteen),
		.avmmclk(avmmclk),
		.avmmread(avmmread),
		.avmmreaddata(avmmreaddata),
		.avmmrstn(avmmrstn),
		.avmmwrite(avmmwrite),
		.avmmwritedata(avmmwritedata),
		.blockselect(blockselect),
		.clockinfrom8gpcs(clockinfrom8gpcs),
		.datainfrom8gpcs(datainfrom8gpcs),
		.dataouttopld(dataouttopld),
		.emsipenablediocsrrdydly(emsipenablediocsrrdydly),
		.emsiprxout(emsiprxout),
		.emsiprxspecialin(emsiprxspecialin),
		.emsiprxspecialout(emsiprxspecialout),
		.pcs8ga1a2k1k2flag(pcs8ga1a2k1k2flag),
		.pcs8ga1a2size(pcs8ga1a2size),
		.pcs8galignstatus(pcs8galignstatus),
		.pcs8gbistdone(pcs8gbistdone),
		.pcs8gbisterr(pcs8gbisterr),
		.pcs8gbitlocreven(pcs8gbitlocreven),
		.pcs8gbitslip(pcs8gbitslip),
		.pcs8gbyteordflag(pcs8gbyteordflag),
		.pcs8gbytereven(pcs8gbytereven),
		.pcs8gbytordpld(pcs8gbytordpld),
		.pcs8gcmpfifourst(pcs8gcmpfifourst),
		.pcs8gemptyrmf(pcs8gemptyrmf),
		.pcs8gemptyrx(pcs8gemptyrx),
		.pcs8gencdt(pcs8gencdt),
		.pcs8gfullrmf(pcs8gfullrmf),
		.pcs8gfullrx(pcs8gfullrx),
		.pcs8gphfifourstrx(pcs8gphfifourstrx),
		.pcs8gpldrxclk(pcs8gpldrxclk),
		.pcs8gpolinvrx(pcs8gpolinvrx),
		.pcs8grdenablermf(pcs8grdenablermf),
		.pcs8grdenablerx(pcs8grdenablerx),
		.pcs8grlvlt(pcs8grlvlt),
		.pcs8grxdatavalid(pcs8grxdatavalid),
		.pcs8grxurstpcs(pcs8grxurstpcs),
		.pcs8gsignaldetectout(pcs8gsignaldetectout),
		.pcs8gsyncsmenoutput(pcs8gsyncsmenoutput),
		.pcs8gwaboundary(pcs8gwaboundary),
		.pcs8gwrdisablerx(pcs8gwrdisablerx),
		.pcs8gwrenablermf(pcs8gwrenablermf),
		.pld8ga1a2k1k2flag(pld8ga1a2k1k2flag),
		.pld8ga1a2size(pld8ga1a2size),
		.pld8galignstatus(pld8galignstatus),
		.pld8gbistdone(pld8gbistdone),
		.pld8gbisterr(pld8gbisterr),
		.pld8gbitlocreven(pld8gbitlocreven),
		.pld8gbitslip(pld8gbitslip),
		.pld8gbyteordflag(pld8gbyteordflag),
		.pld8gbytereven(pld8gbytereven),
		.pld8gbytordpld(pld8gbytordpld),
		.pld8gcmpfifourstn(pld8gcmpfifourstn),
		.pld8gemptyrmf(pld8gemptyrmf),
		.pld8gemptyrx(pld8gemptyrx),
		.pld8gencdt(pld8gencdt),
		.pld8gfullrmf(pld8gfullrmf),
		.pld8gfullrx(pld8gfullrx),
		.pld8gphfifourstrxn(pld8gphfifourstrxn),
		.pld8gpldrxclk(pld8gpldrxclk),
		.pld8gpolinvrx(pld8gpolinvrx),
		.pld8grdenablermf(pld8grdenablermf),
		.pld8grdenablerx(pld8grdenablerx),
		.pld8grlvlt(pld8grlvlt),
		.pld8grxclkout(pld8grxclkout),
		.pld8grxdatavalid(pld8grxdatavalid),
		.pld8grxurstpcsn(pld8grxurstpcsn),
		.pld8gsignaldetectout(pld8gsignaldetectout),
		.pld8gsyncsmeninput(pld8gsyncsmeninput),
		.pld8gwaboundary(pld8gwaboundary),
		.pld8gwrdisablerx(pld8gwrdisablerx),
		.pld8gwrenablermf(pld8gwrenablermf),
		.pldrxclkslipin(pldrxclkslipin),
		.pldrxclkslipout(pldrxclkslipout),
		.pldrxpmarstbin(pldrxpmarstbin),
		.pldrxpmarstbout(pldrxpmarstbout),
		.pmarxplllock(pmarxplllock),
		.reset(reset),
		.rstsel(rstsel),
		.usrrstsel(usrrstsel)
	);
endmodule
