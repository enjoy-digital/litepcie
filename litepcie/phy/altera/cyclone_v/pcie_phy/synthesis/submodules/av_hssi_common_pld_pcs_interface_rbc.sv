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


// Verilog RBC parameter resolution wrapper for arriav_hssi_common_pld_pcs_interface
//

`timescale 1 ns / 1 ps

module av_hssi_common_pld_pcs_interface_rbc #(
	// unconstrained parameters

	// extra unconstrained parameters found in atom map
	parameter avmm_group_channel_index = 0,	// 0..2
	parameter hip_enable = "hip_disable",	// hip_disable, hip_enable
	parameter hrdrstctrl_en_cfg = "hrst_dis_cfg",	// hrst_dis_cfg, hrst_en_cfg
	parameter hrdrstctrl_en_cfgusr = "hrst_dis_cfgusr",	// hrst_dis_cfgusr, hrst_en_cfgusr
	parameter pld_side_data_source = "pld",	// hip, pld
	parameter pld_side_reserved_source0 = "pld_res0",	// hip_res0, pld_res0
	parameter pld_side_reserved_source1 = "pld_res1",	// hip_res1, pld_res1
	parameter pld_side_reserved_source10 = "pld_res10",	// hip_res10, pld_res10
	parameter pld_side_reserved_source11 = "pld_res11",	// hip_res11, pld_res11
	parameter pld_side_reserved_source2 = "pld_res2",	// hip_res2, pld_res2
	parameter pld_side_reserved_source3 = "pld_res3",	// hip_res3, pld_res3
	parameter pld_side_reserved_source4 = "pld_res4",	// hip_res4, pld_res4
	parameter pld_side_reserved_source5 = "pld_res5",	// hip_res5, pld_res5
	parameter pld_side_reserved_source6 = "pld_res6",	// hip_res6, pld_res6
	parameter pld_side_reserved_source7 = "pld_res7",	// hip_res7, pld_res7
	parameter pld_side_reserved_source8 = "pld_res8",	// hip_res8, pld_res8
	parameter pld_side_reserved_source9 = "pld_res9",	// hip_res9, pld_res9
	parameter testbus_sel = "eight_g_pcs",	// eight_g_pcs, pma_if
	parameter use_default_base_address = "true",	// false, true
	parameter user_base_address = 0,	// 0..2047
	parameter usrmode_sel4rst = "usermode"	// last_frz, usermode

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
	output wire    [2:0]	emsipcomclkout,
	input  wire   [37:0]	emsipcomin,
	output wire   [26:0]	emsipcomout,
	output wire         	emsipenablediocsrrdydly,
	input  wire   [19:0]	pcs8gchnltestbusout,
	output wire    [2:0]	pcs8geidleinfersel,
	output wire         	pcs8ghardreset,
	output wire         	pcs8gltr,
	input  wire         	pcs8gphystatus,
	output wire    [3:0]	pcs8gpldextrain,
	input  wire    [2:0]	pcs8gpldextraout,
	output wire    [1:0]	pcs8gpowerdown,
	output wire         	pcs8gprbsciden,
	output wire         	pcs8grate,
	output wire         	pcs8grefclkdig,
	output wire         	pcs8grefclkdig2,
	input  wire         	pcs8grxelecidle,
	output wire         	pcs8grxpolarity,
	input  wire    [2:0]	pcs8grxstatus,
	input  wire         	pcs8grxvalid,
	output wire         	pcs8gscanmoden,
	output wire         	pcs8gscanshift,
	output wire    [5:0]	pcs8gtestsi,
	input  wire    [5:0]	pcs8gtestso,
	output wire         	pcs8gtxdeemph,
	output wire         	pcs8gtxdetectrxloopback,
	output wire         	pcs8gtxelecidle,
	output wire    [2:0]	pcs8gtxmargin,
	output wire         	pcs8gtxswing,
	output wire         	pcsaggrefclkdig,
	output wire         	pcsaggscanmoden,
	output wire         	pcsaggscanshift,
	output wire         	pcsaggtestsi,
	input  wire         	pcsaggtestso,
	output wire         	pcspcspmaifrefclkdig,
	output wire         	pcspcspmaifscanmoden,
	output wire         	pcspcspmaifscanshiftn,
	output wire         	pcspmaifhardreset,
	input  wire    [9:0]	pcspmaiftestbusout,
	output wire         	pcspmaiftestsi,
	input  wire         	pcspmaiftestso,
	output wire         	pld8gphystatus,
	input  wire    [1:0]	pld8gpowerdown,
	input  wire         	pld8gprbsciden,
	input  wire         	pld8grefclkdig,
	input  wire         	pld8grefclkdig2,
	output wire         	pld8grxelecidle,
	input  wire         	pld8grxpolarity,
	output wire    [2:0]	pld8grxstatus,
	output wire         	pld8grxvalid,
	input  wire         	pld8gtxdeemph,
	input  wire         	pld8gtxdetectrxloopback,
	input  wire         	pld8gtxelecidle,
	input  wire    [2:0]	pld8gtxmargin,
	input  wire         	pld8gtxswing,
	input  wire         	pldaggrefclkdig,
	output wire         	pldclklow,
	input  wire    [2:0]	pldeidleinfersel,
	output wire         	pldfref,
	input  wire         	pldhclkin,
	input  wire         	pldltr,
	output wire         	pldnfrzdrv,
	input  wire         	pldpartialreconfigin,
	output wire         	pldpartialreconfigout,
	input  wire         	pldpcspmaifrefclkdig,
	input  wire         	pldrate,
	input  wire   [11:0]	pldreservedin,
	output wire   [10:0]	pldreservedout,
	input  wire         	pldscanmoden,
	input  wire         	pldscanshiftn,
	output wire   [19:0]	pldtestdata,
	input  wire         	pmaclklow,
	input  wire         	pmafref,
	output wire         	rstsel,
	output wire         	usrrstsel
);
	import altera_xcvr_functions::*;

	// hip_enable external parameter (no RBC)
	localparam rbc_all_hip_enable = "(hip_disable,hip_enable)";
	localparam rbc_any_hip_enable = "hip_disable";
	localparam fnl_hip_enable = (hip_enable == "<auto_any>" || hip_enable == "<auto_single>") ? rbc_any_hip_enable : hip_enable;

	// hrdrstctrl_en_cfg external parameter (no RBC)
	localparam rbc_all_hrdrstctrl_en_cfg = "(hrst_dis_cfg,hrst_en_cfg)";
	localparam rbc_any_hrdrstctrl_en_cfg = "hrst_dis_cfg";
	localparam fnl_hrdrstctrl_en_cfg = (hrdrstctrl_en_cfg == "<auto_any>" || hrdrstctrl_en_cfg == "<auto_single>") ? rbc_any_hrdrstctrl_en_cfg : hrdrstctrl_en_cfg;

	// hrdrstctrl_en_cfgusr external parameter (no RBC)
	localparam rbc_all_hrdrstctrl_en_cfgusr = "(hrst_dis_cfgusr,hrst_en_cfgusr)";
	localparam rbc_any_hrdrstctrl_en_cfgusr = "hrst_dis_cfgusr";
	localparam fnl_hrdrstctrl_en_cfgusr = (hrdrstctrl_en_cfgusr == "<auto_any>" || hrdrstctrl_en_cfgusr == "<auto_single>") ? rbc_any_hrdrstctrl_en_cfgusr : hrdrstctrl_en_cfgusr;

	// pld_side_data_source external parameter (no RBC)
	localparam rbc_all_pld_side_data_source = "(hip,pld)";
	localparam rbc_any_pld_side_data_source = "pld";
	localparam fnl_pld_side_data_source = (pld_side_data_source == "<auto_any>" || pld_side_data_source == "<auto_single>") ? rbc_any_pld_side_data_source : pld_side_data_source;

	// pld_side_reserved_source0 external parameter (no RBC)
	localparam rbc_all_pld_side_reserved_source0 = "(hip_res0,pld_res0)";
	localparam rbc_any_pld_side_reserved_source0 = "pld_res0";
	localparam fnl_pld_side_reserved_source0 = (pld_side_reserved_source0 == "<auto_any>" || pld_side_reserved_source0 == "<auto_single>") ? rbc_any_pld_side_reserved_source0 : pld_side_reserved_source0;

	// pld_side_reserved_source1 external parameter (no RBC)
	localparam rbc_all_pld_side_reserved_source1 = "(hip_res1,pld_res1)";
	localparam rbc_any_pld_side_reserved_source1 = "pld_res1";
	localparam fnl_pld_side_reserved_source1 = (pld_side_reserved_source1 == "<auto_any>" || pld_side_reserved_source1 == "<auto_single>") ? rbc_any_pld_side_reserved_source1 : pld_side_reserved_source1;

	// pld_side_reserved_source10 external parameter (no RBC)
	localparam rbc_all_pld_side_reserved_source10 = "(hip_res10,pld_res10)";
	localparam rbc_any_pld_side_reserved_source10 = "pld_res10";
	localparam fnl_pld_side_reserved_source10 = (pld_side_reserved_source10 == "<auto_any>" || pld_side_reserved_source10 == "<auto_single>") ? rbc_any_pld_side_reserved_source10 : pld_side_reserved_source10;

	// pld_side_reserved_source11 external parameter (no RBC)
	localparam rbc_all_pld_side_reserved_source11 = "(hip_res11,pld_res11)";
	localparam rbc_any_pld_side_reserved_source11 = "pld_res11";
	localparam fnl_pld_side_reserved_source11 = (pld_side_reserved_source11 == "<auto_any>" || pld_side_reserved_source11 == "<auto_single>") ? rbc_any_pld_side_reserved_source11 : pld_side_reserved_source11;

	// pld_side_reserved_source2 external parameter (no RBC)
	localparam rbc_all_pld_side_reserved_source2 = "(hip_res2,pld_res2)";
	localparam rbc_any_pld_side_reserved_source2 = "pld_res2";
	localparam fnl_pld_side_reserved_source2 = (pld_side_reserved_source2 == "<auto_any>" || pld_side_reserved_source2 == "<auto_single>") ? rbc_any_pld_side_reserved_source2 : pld_side_reserved_source2;

	// pld_side_reserved_source3 external parameter (no RBC)
	localparam rbc_all_pld_side_reserved_source3 = "(hip_res3,pld_res3)";
	localparam rbc_any_pld_side_reserved_source3 = "pld_res3";
	localparam fnl_pld_side_reserved_source3 = (pld_side_reserved_source3 == "<auto_any>" || pld_side_reserved_source3 == "<auto_single>") ? rbc_any_pld_side_reserved_source3 : pld_side_reserved_source3;

	// pld_side_reserved_source4 external parameter (no RBC)
	localparam rbc_all_pld_side_reserved_source4 = "(hip_res4,pld_res4)";
	localparam rbc_any_pld_side_reserved_source4 = "pld_res4";
	localparam fnl_pld_side_reserved_source4 = (pld_side_reserved_source4 == "<auto_any>" || pld_side_reserved_source4 == "<auto_single>") ? rbc_any_pld_side_reserved_source4 : pld_side_reserved_source4;

	// pld_side_reserved_source5 external parameter (no RBC)
	localparam rbc_all_pld_side_reserved_source5 = "(hip_res5,pld_res5)";
	localparam rbc_any_pld_side_reserved_source5 = "pld_res5";
	localparam fnl_pld_side_reserved_source5 = (pld_side_reserved_source5 == "<auto_any>" || pld_side_reserved_source5 == "<auto_single>") ? rbc_any_pld_side_reserved_source5 : pld_side_reserved_source5;

	// pld_side_reserved_source6 external parameter (no RBC)
	localparam rbc_all_pld_side_reserved_source6 = "(hip_res6,pld_res6)";
	localparam rbc_any_pld_side_reserved_source6 = "pld_res6";
	localparam fnl_pld_side_reserved_source6 = (pld_side_reserved_source6 == "<auto_any>" || pld_side_reserved_source6 == "<auto_single>") ? rbc_any_pld_side_reserved_source6 : pld_side_reserved_source6;

	// pld_side_reserved_source7 external parameter (no RBC)
	localparam rbc_all_pld_side_reserved_source7 = "(hip_res7,pld_res7)";
	localparam rbc_any_pld_side_reserved_source7 = "pld_res7";
	localparam fnl_pld_side_reserved_source7 = (pld_side_reserved_source7 == "<auto_any>" || pld_side_reserved_source7 == "<auto_single>") ? rbc_any_pld_side_reserved_source7 : pld_side_reserved_source7;

	// pld_side_reserved_source8 external parameter (no RBC)
	localparam rbc_all_pld_side_reserved_source8 = "(hip_res8,pld_res8)";
	localparam rbc_any_pld_side_reserved_source8 = "pld_res8";
	localparam fnl_pld_side_reserved_source8 = (pld_side_reserved_source8 == "<auto_any>" || pld_side_reserved_source8 == "<auto_single>") ? rbc_any_pld_side_reserved_source8 : pld_side_reserved_source8;

	// pld_side_reserved_source9 external parameter (no RBC)
	localparam rbc_all_pld_side_reserved_source9 = "(hip_res9,pld_res9)";
	localparam rbc_any_pld_side_reserved_source9 = "pld_res9";
	localparam fnl_pld_side_reserved_source9 = (pld_side_reserved_source9 == "<auto_any>" || pld_side_reserved_source9 == "<auto_single>") ? rbc_any_pld_side_reserved_source9 : pld_side_reserved_source9;

	// testbus_sel external parameter (no RBC)
	localparam rbc_all_testbus_sel = "(eight_g_pcs,pma_if)";
	localparam rbc_any_testbus_sel = "eight_g_pcs";
	localparam fnl_testbus_sel = (testbus_sel == "<auto_any>" || testbus_sel == "<auto_single>") ? rbc_any_testbus_sel : testbus_sel;

	// use_default_base_address external parameter (no RBC)
	localparam rbc_all_use_default_base_address = "(false,true)";
	localparam rbc_any_use_default_base_address = "true";
	localparam fnl_use_default_base_address = (use_default_base_address == "<auto_any>" || use_default_base_address == "<auto_single>") ? rbc_any_use_default_base_address : use_default_base_address;

	// usrmode_sel4rst external parameter (no RBC)
	localparam rbc_all_usrmode_sel4rst = "(last_frz,usermode)";
	localparam rbc_any_usrmode_sel4rst = "usermode";
	localparam fnl_usrmode_sel4rst = (usrmode_sel4rst == "<auto_any>" || usrmode_sel4rst == "<auto_single>") ? rbc_any_usrmode_sel4rst : usrmode_sel4rst;

	// Validate input parameters against known values or RBC values
	initial begin
		//$display("hip_enable = orig: '%s', any:'%s', all:'%s', final: '%s'", hip_enable, rbc_any_hip_enable, rbc_all_hip_enable, fnl_hip_enable);
		if (!is_in_legal_set(hip_enable, rbc_all_hip_enable)) begin
			$display("Critical Warning: parameter 'hip_enable' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", hip_enable, rbc_all_hip_enable, fnl_hip_enable);
		end
		//$display("hrdrstctrl_en_cfg = orig: '%s', any:'%s', all:'%s', final: '%s'", hrdrstctrl_en_cfg, rbc_any_hrdrstctrl_en_cfg, rbc_all_hrdrstctrl_en_cfg, fnl_hrdrstctrl_en_cfg);
		if (!is_in_legal_set(hrdrstctrl_en_cfg, rbc_all_hrdrstctrl_en_cfg)) begin
			$display("Critical Warning: parameter 'hrdrstctrl_en_cfg' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", hrdrstctrl_en_cfg, rbc_all_hrdrstctrl_en_cfg, fnl_hrdrstctrl_en_cfg);
		end
		//$display("hrdrstctrl_en_cfgusr = orig: '%s', any:'%s', all:'%s', final: '%s'", hrdrstctrl_en_cfgusr, rbc_any_hrdrstctrl_en_cfgusr, rbc_all_hrdrstctrl_en_cfgusr, fnl_hrdrstctrl_en_cfgusr);
		if (!is_in_legal_set(hrdrstctrl_en_cfgusr, rbc_all_hrdrstctrl_en_cfgusr)) begin
			$display("Critical Warning: parameter 'hrdrstctrl_en_cfgusr' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", hrdrstctrl_en_cfgusr, rbc_all_hrdrstctrl_en_cfgusr, fnl_hrdrstctrl_en_cfgusr);
		end
		//$display("pld_side_data_source = orig: '%s', any:'%s', all:'%s', final: '%s'", pld_side_data_source, rbc_any_pld_side_data_source, rbc_all_pld_side_data_source, fnl_pld_side_data_source);
		if (!is_in_legal_set(pld_side_data_source, rbc_all_pld_side_data_source)) begin
			$display("Critical Warning: parameter 'pld_side_data_source' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", pld_side_data_source, rbc_all_pld_side_data_source, fnl_pld_side_data_source);
		end
		//$display("pld_side_reserved_source0 = orig: '%s', any:'%s', all:'%s', final: '%s'", pld_side_reserved_source0, rbc_any_pld_side_reserved_source0, rbc_all_pld_side_reserved_source0, fnl_pld_side_reserved_source0);
		if (!is_in_legal_set(pld_side_reserved_source0, rbc_all_pld_side_reserved_source0)) begin
			$display("Critical Warning: parameter 'pld_side_reserved_source0' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", pld_side_reserved_source0, rbc_all_pld_side_reserved_source0, fnl_pld_side_reserved_source0);
		end
		//$display("pld_side_reserved_source1 = orig: '%s', any:'%s', all:'%s', final: '%s'", pld_side_reserved_source1, rbc_any_pld_side_reserved_source1, rbc_all_pld_side_reserved_source1, fnl_pld_side_reserved_source1);
		if (!is_in_legal_set(pld_side_reserved_source1, rbc_all_pld_side_reserved_source1)) begin
			$display("Critical Warning: parameter 'pld_side_reserved_source1' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", pld_side_reserved_source1, rbc_all_pld_side_reserved_source1, fnl_pld_side_reserved_source1);
		end
		//$display("pld_side_reserved_source10 = orig: '%s', any:'%s', all:'%s', final: '%s'", pld_side_reserved_source10, rbc_any_pld_side_reserved_source10, rbc_all_pld_side_reserved_source10, fnl_pld_side_reserved_source10);
		if (!is_in_legal_set(pld_side_reserved_source10, rbc_all_pld_side_reserved_source10)) begin
			$display("Critical Warning: parameter 'pld_side_reserved_source10' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", pld_side_reserved_source10, rbc_all_pld_side_reserved_source10, fnl_pld_side_reserved_source10);
		end
		//$display("pld_side_reserved_source11 = orig: '%s', any:'%s', all:'%s', final: '%s'", pld_side_reserved_source11, rbc_any_pld_side_reserved_source11, rbc_all_pld_side_reserved_source11, fnl_pld_side_reserved_source11);
		if (!is_in_legal_set(pld_side_reserved_source11, rbc_all_pld_side_reserved_source11)) begin
			$display("Critical Warning: parameter 'pld_side_reserved_source11' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", pld_side_reserved_source11, rbc_all_pld_side_reserved_source11, fnl_pld_side_reserved_source11);
		end
		//$display("pld_side_reserved_source2 = orig: '%s', any:'%s', all:'%s', final: '%s'", pld_side_reserved_source2, rbc_any_pld_side_reserved_source2, rbc_all_pld_side_reserved_source2, fnl_pld_side_reserved_source2);
		if (!is_in_legal_set(pld_side_reserved_source2, rbc_all_pld_side_reserved_source2)) begin
			$display("Critical Warning: parameter 'pld_side_reserved_source2' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", pld_side_reserved_source2, rbc_all_pld_side_reserved_source2, fnl_pld_side_reserved_source2);
		end
		//$display("pld_side_reserved_source3 = orig: '%s', any:'%s', all:'%s', final: '%s'", pld_side_reserved_source3, rbc_any_pld_side_reserved_source3, rbc_all_pld_side_reserved_source3, fnl_pld_side_reserved_source3);
		if (!is_in_legal_set(pld_side_reserved_source3, rbc_all_pld_side_reserved_source3)) begin
			$display("Critical Warning: parameter 'pld_side_reserved_source3' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", pld_side_reserved_source3, rbc_all_pld_side_reserved_source3, fnl_pld_side_reserved_source3);
		end
		//$display("pld_side_reserved_source4 = orig: '%s', any:'%s', all:'%s', final: '%s'", pld_side_reserved_source4, rbc_any_pld_side_reserved_source4, rbc_all_pld_side_reserved_source4, fnl_pld_side_reserved_source4);
		if (!is_in_legal_set(pld_side_reserved_source4, rbc_all_pld_side_reserved_source4)) begin
			$display("Critical Warning: parameter 'pld_side_reserved_source4' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", pld_side_reserved_source4, rbc_all_pld_side_reserved_source4, fnl_pld_side_reserved_source4);
		end
		//$display("pld_side_reserved_source5 = orig: '%s', any:'%s', all:'%s', final: '%s'", pld_side_reserved_source5, rbc_any_pld_side_reserved_source5, rbc_all_pld_side_reserved_source5, fnl_pld_side_reserved_source5);
		if (!is_in_legal_set(pld_side_reserved_source5, rbc_all_pld_side_reserved_source5)) begin
			$display("Critical Warning: parameter 'pld_side_reserved_source5' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", pld_side_reserved_source5, rbc_all_pld_side_reserved_source5, fnl_pld_side_reserved_source5);
		end
		//$display("pld_side_reserved_source6 = orig: '%s', any:'%s', all:'%s', final: '%s'", pld_side_reserved_source6, rbc_any_pld_side_reserved_source6, rbc_all_pld_side_reserved_source6, fnl_pld_side_reserved_source6);
		if (!is_in_legal_set(pld_side_reserved_source6, rbc_all_pld_side_reserved_source6)) begin
			$display("Critical Warning: parameter 'pld_side_reserved_source6' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", pld_side_reserved_source6, rbc_all_pld_side_reserved_source6, fnl_pld_side_reserved_source6);
		end
		//$display("pld_side_reserved_source7 = orig: '%s', any:'%s', all:'%s', final: '%s'", pld_side_reserved_source7, rbc_any_pld_side_reserved_source7, rbc_all_pld_side_reserved_source7, fnl_pld_side_reserved_source7);
		if (!is_in_legal_set(pld_side_reserved_source7, rbc_all_pld_side_reserved_source7)) begin
			$display("Critical Warning: parameter 'pld_side_reserved_source7' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", pld_side_reserved_source7, rbc_all_pld_side_reserved_source7, fnl_pld_side_reserved_source7);
		end
		//$display("pld_side_reserved_source8 = orig: '%s', any:'%s', all:'%s', final: '%s'", pld_side_reserved_source8, rbc_any_pld_side_reserved_source8, rbc_all_pld_side_reserved_source8, fnl_pld_side_reserved_source8);
		if (!is_in_legal_set(pld_side_reserved_source8, rbc_all_pld_side_reserved_source8)) begin
			$display("Critical Warning: parameter 'pld_side_reserved_source8' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", pld_side_reserved_source8, rbc_all_pld_side_reserved_source8, fnl_pld_side_reserved_source8);
		end
		//$display("pld_side_reserved_source9 = orig: '%s', any:'%s', all:'%s', final: '%s'", pld_side_reserved_source9, rbc_any_pld_side_reserved_source9, rbc_all_pld_side_reserved_source9, fnl_pld_side_reserved_source9);
		if (!is_in_legal_set(pld_side_reserved_source9, rbc_all_pld_side_reserved_source9)) begin
			$display("Critical Warning: parameter 'pld_side_reserved_source9' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", pld_side_reserved_source9, rbc_all_pld_side_reserved_source9, fnl_pld_side_reserved_source9);
		end
		//$display("testbus_sel = orig: '%s', any:'%s', all:'%s', final: '%s'", testbus_sel, rbc_any_testbus_sel, rbc_all_testbus_sel, fnl_testbus_sel);
		if (!is_in_legal_set(testbus_sel, rbc_all_testbus_sel)) begin
			$display("Critical Warning: parameter 'testbus_sel' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", testbus_sel, rbc_all_testbus_sel, fnl_testbus_sel);
		end
		//$display("use_default_base_address = orig: '%s', any:'%s', all:'%s', final: '%s'", use_default_base_address, rbc_any_use_default_base_address, rbc_all_use_default_base_address, fnl_use_default_base_address);
		if (!is_in_legal_set(use_default_base_address, rbc_all_use_default_base_address)) begin
			$display("Critical Warning: parameter 'use_default_base_address' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", use_default_base_address, rbc_all_use_default_base_address, fnl_use_default_base_address);
		end
		//$display("usrmode_sel4rst = orig: '%s', any:'%s', all:'%s', final: '%s'", usrmode_sel4rst, rbc_any_usrmode_sel4rst, rbc_all_usrmode_sel4rst, fnl_usrmode_sel4rst);
		if (!is_in_legal_set(usrmode_sel4rst, rbc_all_usrmode_sel4rst)) begin
			$display("Critical Warning: parameter 'usrmode_sel4rst' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", usrmode_sel4rst, rbc_all_usrmode_sel4rst, fnl_usrmode_sel4rst);
		end
	end

	arriav_hssi_common_pld_pcs_interface #(
		.avmm_group_channel_index(avmm_group_channel_index),
		.hip_enable(fnl_hip_enable),
		.hrdrstctrl_en_cfg(fnl_hrdrstctrl_en_cfg),
		.hrdrstctrl_en_cfgusr(fnl_hrdrstctrl_en_cfgusr),
		.pld_side_data_source(fnl_pld_side_data_source),
		.pld_side_reserved_source0(fnl_pld_side_reserved_source0),
		.pld_side_reserved_source1(fnl_pld_side_reserved_source1),
		.pld_side_reserved_source10(fnl_pld_side_reserved_source10),
		.pld_side_reserved_source11(fnl_pld_side_reserved_source11),
		.pld_side_reserved_source2(fnl_pld_side_reserved_source2),
		.pld_side_reserved_source3(fnl_pld_side_reserved_source3),
		.pld_side_reserved_source4(fnl_pld_side_reserved_source4),
		.pld_side_reserved_source5(fnl_pld_side_reserved_source5),
		.pld_side_reserved_source6(fnl_pld_side_reserved_source6),
		.pld_side_reserved_source7(fnl_pld_side_reserved_source7),
		.pld_side_reserved_source8(fnl_pld_side_reserved_source8),
		.pld_side_reserved_source9(fnl_pld_side_reserved_source9),
		.testbus_sel(fnl_testbus_sel),
		.use_default_base_address(fnl_use_default_base_address),
		.user_base_address(user_base_address),
		.usrmode_sel4rst(fnl_usrmode_sel4rst)
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
		.emsipcomclkout(emsipcomclkout),
		.emsipcomin(emsipcomin),
		.emsipcomout(emsipcomout),
		.emsipenablediocsrrdydly(emsipenablediocsrrdydly),
		.pcs8gchnltestbusout(pcs8gchnltestbusout),
		.pcs8geidleinfersel(pcs8geidleinfersel),
		.pcs8ghardreset(pcs8ghardreset),
		.pcs8gltr(pcs8gltr),
		.pcs8gphystatus(pcs8gphystatus),
		.pcs8gpldextrain(pcs8gpldextrain),
		.pcs8gpldextraout(pcs8gpldextraout),
		.pcs8gpowerdown(pcs8gpowerdown),
		.pcs8gprbsciden(pcs8gprbsciden),
		.pcs8grate(pcs8grate),
		.pcs8grefclkdig(pcs8grefclkdig),
		.pcs8grefclkdig2(pcs8grefclkdig2),
		.pcs8grxelecidle(pcs8grxelecidle),
		.pcs8grxpolarity(pcs8grxpolarity),
		.pcs8grxstatus(pcs8grxstatus),
		.pcs8grxvalid(pcs8grxvalid),
		.pcs8gscanmoden(pcs8gscanmoden),
		.pcs8gscanshift(pcs8gscanshift),
		.pcs8gtestsi(pcs8gtestsi),
		.pcs8gtestso(pcs8gtestso),
		.pcs8gtxdeemph(pcs8gtxdeemph),
		.pcs8gtxdetectrxloopback(pcs8gtxdetectrxloopback),
		.pcs8gtxelecidle(pcs8gtxelecidle),
		.pcs8gtxmargin(pcs8gtxmargin),
		.pcs8gtxswing(pcs8gtxswing),
		.pcsaggrefclkdig(pcsaggrefclkdig),
		.pcsaggscanmoden(pcsaggscanmoden),
		.pcsaggscanshift(pcsaggscanshift),
		.pcsaggtestsi(pcsaggtestsi),
		.pcsaggtestso(pcsaggtestso),
		.pcspcspmaifrefclkdig(pcspcspmaifrefclkdig),
		.pcspcspmaifscanmoden(pcspcspmaifscanmoden),
		.pcspcspmaifscanshiftn(pcspcspmaifscanshiftn),
		.pcspmaifhardreset(pcspmaifhardreset),
		.pcspmaiftestbusout(pcspmaiftestbusout),
		.pcspmaiftestsi(pcspmaiftestsi),
		.pcspmaiftestso(pcspmaiftestso),
		.pld8gphystatus(pld8gphystatus),
		.pld8gpowerdown(pld8gpowerdown),
		.pld8gprbsciden(pld8gprbsciden),
		.pld8grefclkdig(pld8grefclkdig),
		.pld8grefclkdig2(pld8grefclkdig2),
		.pld8grxelecidle(pld8grxelecidle),
		.pld8grxpolarity(pld8grxpolarity),
		.pld8grxstatus(pld8grxstatus),
		.pld8grxvalid(pld8grxvalid),
		.pld8gtxdeemph(pld8gtxdeemph),
		.pld8gtxdetectrxloopback(pld8gtxdetectrxloopback),
		.pld8gtxelecidle(pld8gtxelecidle),
		.pld8gtxmargin(pld8gtxmargin),
		.pld8gtxswing(pld8gtxswing),
		.pldaggrefclkdig(pldaggrefclkdig),
		.pldclklow(pldclklow),
		.pldeidleinfersel(pldeidleinfersel),
		.pldfref(pldfref),
		.pldhclkin(pldhclkin),
		.pldltr(pldltr),
		.pldnfrzdrv(pldnfrzdrv),
		.pldpartialreconfigin(pldpartialreconfigin),
		.pldpartialreconfigout(pldpartialreconfigout),
		.pldpcspmaifrefclkdig(pldpcspmaifrefclkdig),
		.pldrate(pldrate),
		.pldreservedin(pldreservedin),
		.pldreservedout(pldreservedout),
		.pldscanmoden(pldscanmoden),
		.pldscanshiftn(pldscanshiftn),
		.pldtestdata(pldtestdata),
		.pmaclklow(pmaclklow),
		.pmafref(pmafref),
		.rstsel(rstsel),
		.usrrstsel(usrrstsel)
	);
endmodule
