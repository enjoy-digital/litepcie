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


// Verilog RBC parameter resolution wrapper for arriav_hssi_pipe_gen1_2
//

`timescale 1 ns / 1 ps

module av_hssi_pipe_gen1_2_rbc #(
	// unconstrained parameters
	parameter prot_mode = "<auto_single>",	// basic, disabled_prot_mode, pipe_g1, pipe_g2, srio_2p1

	// extra unconstrained parameters found in atom map
	parameter avmm_group_channel_index = 0,	// 0..2
	parameter ctrl_plane_bonding_consumption = "individual",	// bundled_master, bundled_slave_above, bundled_slave_below, individual
	parameter elec_idle_delay_val = 3'b0,	// 3
	parameter elecidle_delay = "elec_idle_delay",	// elec_idle_delay
	parameter phy_status_delay = "phystatus_delay",	// phystatus_delay
	parameter phystatus_delay_val = 3'b0,	// 3
	parameter rpre_emph_a_val = 6'b0,	// 6
	parameter rpre_emph_b_val = 6'b0,	// 6
	parameter rpre_emph_c_val = 6'b0,	// 6
	parameter rpre_emph_d_val = 6'b0,	// 6
	parameter rpre_emph_e_val = 6'b0,	// 6
	parameter rpre_emph_settings = 6'b0,	// 6
	parameter rvod_sel_a_val = 6'b0,	// 6
	parameter rvod_sel_b_val = 6'b0,	// 6
	parameter rvod_sel_c_val = 6'b0,	// 6
	parameter rvod_sel_d_val = 6'b0,	// 6
	parameter rvod_sel_e_val = 6'b0,	// 6
	parameter rvod_sel_settings = 6'b0,	// 6
	parameter sup_mode = "user_mode",	// engineering_mode, user_mode
	parameter use_default_base_address = "true",	// false, true
	parameter user_base_address = 0,	// 0..2047

	// constrained parameters
	parameter hip_mode = "<auto_single>",	// dis_hip, en_hip
	parameter tx_pipe_enable = "<auto_single>",	// dis_pipe_tx, en_pipe_tx
	parameter rx_pipe_enable = "<auto_single>",	// dis_pipe_rx, en_pipe_rx
	parameter pipe_byte_de_serializer_en = "<auto_single>",	// dis_bds, dont_care_bds, en_bds_by_2
	parameter txswing = "<auto_single>",	// dis_txswing, en_txswing
	parameter rxdetect_bypass = "<auto_single>",	// dis_rxdetect_bypass, en_rxdetect_bypass
	parameter error_replace_pad = "<auto_single>",	// replace_edb, replace_pad
	parameter ind_error_reporting = "<auto_single>",	// dis_ind_error_reporting, en_ind_error_reporting
	parameter phystatus_rst_toggle = "<auto_single>"	// dis_phystatus_rst_toggle, en_phystatus_rst_toggle
) (
	// ports
	input  wire   [10:0]	avmmaddress,
	input  wire    [1:0]	avmmbyteen,
	input  wire         	avmmclk,
	input  wire         	avmmread,
	output wire   [15:0]	avmmreaddata,
	input  wire         	avmmrstn,
	input  wire         	avmmwrite,
	input  wire   [15:0]	avmmwritedata,
	output wire         	blockselect,
	output wire   [17:0]	currentcoeff,
	input  wire         	pcieswitch,
	output wire         	phystatus,
	input  wire         	piperxclk,
	input  wire         	pipetxclk,
	input  wire         	polinvrx,
	output wire         	polinvrxint,
	input  wire    [1:0]	powerdown,
	input  wire         	powerstatetransitiondone,
	input  wire         	powerstatetransitiondoneena,
	input  wire         	refclkb,
	input  wire         	refclkbreset,
	input  wire         	revloopback,
	output wire         	revloopbk,
	input  wire         	revloopbkpcsgen3,
	input  wire   [63:0]	rxd,
	output wire   [63:0]	rxdch,
	input  wire         	rxdetectvalid,
	output wire         	rxelecidle,
	input  wire         	rxelectricalidle,
	output wire         	rxelectricalidleout,
	input  wire         	rxfound,
	input  wire         	rxpipereset,
	input  wire         	rxpolarity,
	output wire    [2:0]	rxstatus,
	output wire         	rxvalid,
	input  wire         	sigdetni,
	input  wire         	speedchange,
	input  wire         	speedchangechnldown,
	input  wire         	speedchangechnlup,
	output wire         	speedchangeout,
	output wire   [43:0]	txd,
	input  wire   [43:0]	txdch,
	input  wire         	txdeemph,
	output wire         	txdetectrx,
	input  wire         	txdetectrxloopback,
	input  wire         	txelecidlecomp,
	input  wire         	txelecidlein,
	output wire         	txelecidleout,
	input  wire    [2:0]	txmargin,
	input  wire         	txpipereset,
	input  wire         	txswingport
);
	import altera_xcvr_functions::*;

	// prot_mode external parameter (no RBC)
	localparam rbc_all_prot_mode = "(basic,disabled_prot_mode,pipe_g1,pipe_g2,srio_2p1)";
	localparam rbc_any_prot_mode = "pipe_g1";
	localparam fnl_prot_mode = (prot_mode == "<auto_any>" || prot_mode == "<auto_single>") ? rbc_any_prot_mode : prot_mode;

	// ctrl_plane_bonding_consumption external parameter (no RBC)
	localparam rbc_all_ctrl_plane_bonding_consumption = "(bundled_master,bundled_slave_above,bundled_slave_below,individual)";
	localparam rbc_any_ctrl_plane_bonding_consumption = "individual";
	localparam fnl_ctrl_plane_bonding_consumption = (ctrl_plane_bonding_consumption == "<auto_any>" || ctrl_plane_bonding_consumption == "<auto_single>") ? rbc_any_ctrl_plane_bonding_consumption : ctrl_plane_bonding_consumption;

	// sup_mode external parameter (no RBC)
	localparam rbc_all_sup_mode = "(engineering_mode,user_mode)";
	localparam rbc_any_sup_mode = "user_mode";
	localparam fnl_sup_mode = (sup_mode == "<auto_any>" || sup_mode == "<auto_single>") ? rbc_any_sup_mode : sup_mode;

	// use_default_base_address external parameter (no RBC)
	localparam rbc_all_use_default_base_address = "(false,true)";
	localparam rbc_any_use_default_base_address = "true";
	localparam fnl_use_default_base_address = (use_default_base_address == "<auto_any>" || use_default_base_address == "<auto_single>") ? rbc_any_use_default_base_address : use_default_base_address;

	// hip_mode, RBC-validated
	localparam rbc_all_hip_mode = ((fnl_prot_mode == "pipe_g1") || (fnl_prot_mode == "pipe_g2")) ? ("(dis_hip,en_hip)") : "dis_hip";
	localparam rbc_any_hip_mode = ((fnl_prot_mode == "pipe_g1") || (fnl_prot_mode == "pipe_g2")) ? ("dis_hip") : "dis_hip";
	localparam fnl_hip_mode = (hip_mode == "<auto_any>" || hip_mode == "<auto_single>") ? rbc_any_hip_mode : hip_mode;

	// tx_pipe_enable, RBC-validated
	localparam rbc_all_tx_pipe_enable = ( (fnl_prot_mode == "pipe_g1") || (fnl_prot_mode == "pipe_g2") ) ? ("en_pipe_tx") : "dis_pipe_tx";
	localparam rbc_any_tx_pipe_enable = ( (fnl_prot_mode == "pipe_g1") || (fnl_prot_mode == "pipe_g2") ) ? ("en_pipe_tx") : "dis_pipe_tx";
	localparam fnl_tx_pipe_enable = (tx_pipe_enable == "<auto_any>" || tx_pipe_enable == "<auto_single>") ? rbc_any_tx_pipe_enable : tx_pipe_enable;

	// rx_pipe_enable, RBC-validated
	localparam rbc_all_rx_pipe_enable = ( (fnl_prot_mode == "pipe_g1") || (fnl_prot_mode == "pipe_g2") ) ? ("en_pipe_rx") : "dis_pipe_rx";
	localparam rbc_any_rx_pipe_enable = ( (fnl_prot_mode == "pipe_g1") || (fnl_prot_mode == "pipe_g2") ) ? ("en_pipe_rx") : "dis_pipe_rx";
	localparam fnl_rx_pipe_enable = (rx_pipe_enable == "<auto_any>" || rx_pipe_enable == "<auto_single>") ? rbc_any_rx_pipe_enable : rx_pipe_enable;

	// pipe_byte_de_serializer_en, RBC-validated
	localparam rbc_all_pipe_byte_de_serializer_en = ((fnl_rx_pipe_enable == "en_pipe_rx") && (fnl_hip_mode != "en_hip")) ? ("(dis_bds,en_bds_by_2)")
		 : ((fnl_rx_pipe_enable == "en_pipe_rx") && (fnl_hip_mode == "en_hip")) ? ("dis_bds") : "dont_care_bds";
	localparam rbc_any_pipe_byte_de_serializer_en = ((fnl_rx_pipe_enable == "en_pipe_rx") && (fnl_hip_mode != "en_hip")) ? ("dis_bds")
		 : ((fnl_rx_pipe_enable == "en_pipe_rx") && (fnl_hip_mode == "en_hip")) ? ("dis_bds") : "dont_care_bds";
	localparam fnl_pipe_byte_de_serializer_en = (pipe_byte_de_serializer_en == "<auto_any>" || pipe_byte_de_serializer_en == "<auto_single>") ? rbc_any_pipe_byte_de_serializer_en : pipe_byte_de_serializer_en;

	// txswing, RBC-validated
	localparam rbc_all_txswing = (fnl_rx_pipe_enable == "en_pipe_rx") ? ("(en_txswing,dis_txswing)") : "dis_txswing";
	localparam rbc_any_txswing = (fnl_rx_pipe_enable == "en_pipe_rx") ? ("dis_txswing") : "dis_txswing";
	localparam fnl_txswing = (txswing == "<auto_any>" || txswing == "<auto_single>") ? rbc_any_txswing : txswing;

	// rxdetect_bypass, RBC-validated
	localparam rbc_all_rxdetect_bypass = (fnl_rx_pipe_enable == "en_pipe_rx") ? ("(dis_rxdetect_bypass,en_rxdetect_bypass)") : "dis_rxdetect_bypass";
	localparam rbc_any_rxdetect_bypass = (fnl_rx_pipe_enable == "en_pipe_rx") ? ("dis_rxdetect_bypass") : "dis_rxdetect_bypass";
	localparam fnl_rxdetect_bypass = (rxdetect_bypass == "<auto_any>" || rxdetect_bypass == "<auto_single>") ? rbc_any_rxdetect_bypass : rxdetect_bypass;

	// error_replace_pad, RBC-validated
	localparam rbc_all_error_replace_pad = "replace_edb";
	localparam rbc_any_error_replace_pad = "replace_edb";
	localparam fnl_error_replace_pad = (error_replace_pad == "<auto_any>" || error_replace_pad == "<auto_single>") ? rbc_any_error_replace_pad : error_replace_pad;

	// ind_error_reporting, RBC-validated
	localparam rbc_all_ind_error_reporting = (fnl_rx_pipe_enable == "en_pipe_rx") ? ("(en_ind_error_reporting,dis_ind_error_reporting)") : "dis_ind_error_reporting";
	localparam rbc_any_ind_error_reporting = (fnl_rx_pipe_enable == "en_pipe_rx") ? ("dis_ind_error_reporting") : "dis_ind_error_reporting";
	localparam fnl_ind_error_reporting = (ind_error_reporting == "<auto_any>" || ind_error_reporting == "<auto_single>") ? rbc_any_ind_error_reporting : ind_error_reporting;

	// phystatus_rst_toggle, RBC-validated
	localparam rbc_all_phystatus_rst_toggle = "dis_phystatus_rst_toggle";
	localparam rbc_any_phystatus_rst_toggle = "dis_phystatus_rst_toggle";
	localparam fnl_phystatus_rst_toggle = (phystatus_rst_toggle == "<auto_any>" || phystatus_rst_toggle == "<auto_single>") ? rbc_any_phystatus_rst_toggle : phystatus_rst_toggle;

	// Validate input parameters against known values or RBC values
	initial begin
		//$display("prot_mode = orig: '%s', any:'%s', all:'%s', final: '%s'", prot_mode, rbc_any_prot_mode, rbc_all_prot_mode, fnl_prot_mode);
		if (!is_in_legal_set(prot_mode, rbc_all_prot_mode)) begin
			$display("Critical Warning: parameter 'prot_mode' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", prot_mode, rbc_all_prot_mode, fnl_prot_mode);
		end
		//$display("ctrl_plane_bonding_consumption = orig: '%s', any:'%s', all:'%s', final: '%s'", ctrl_plane_bonding_consumption, rbc_any_ctrl_plane_bonding_consumption, rbc_all_ctrl_plane_bonding_consumption, fnl_ctrl_plane_bonding_consumption);
		if (!is_in_legal_set(ctrl_plane_bonding_consumption, rbc_all_ctrl_plane_bonding_consumption)) begin
			$display("Critical Warning: parameter 'ctrl_plane_bonding_consumption' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", ctrl_plane_bonding_consumption, rbc_all_ctrl_plane_bonding_consumption, fnl_ctrl_plane_bonding_consumption);
		end
		//$display("sup_mode = orig: '%s', any:'%s', all:'%s', final: '%s'", sup_mode, rbc_any_sup_mode, rbc_all_sup_mode, fnl_sup_mode);
		if (!is_in_legal_set(sup_mode, rbc_all_sup_mode)) begin
			$display("Critical Warning: parameter 'sup_mode' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", sup_mode, rbc_all_sup_mode, fnl_sup_mode);
		end
		//$display("use_default_base_address = orig: '%s', any:'%s', all:'%s', final: '%s'", use_default_base_address, rbc_any_use_default_base_address, rbc_all_use_default_base_address, fnl_use_default_base_address);
		if (!is_in_legal_set(use_default_base_address, rbc_all_use_default_base_address)) begin
			$display("Critical Warning: parameter 'use_default_base_address' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", use_default_base_address, rbc_all_use_default_base_address, fnl_use_default_base_address);
		end
		//$display("hip_mode = orig: '%s', any:'%s', all:'%s', final: '%s'", hip_mode, rbc_any_hip_mode, rbc_all_hip_mode, fnl_hip_mode);
		if (!is_in_legal_set(hip_mode, rbc_all_hip_mode)) begin
			$display("Critical Warning: parameter 'hip_mode' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", hip_mode, rbc_all_hip_mode, fnl_hip_mode);
		end
		//$display("tx_pipe_enable = orig: '%s', any:'%s', all:'%s', final: '%s'", tx_pipe_enable, rbc_any_tx_pipe_enable, rbc_all_tx_pipe_enable, fnl_tx_pipe_enable);
		if (!is_in_legal_set(tx_pipe_enable, rbc_all_tx_pipe_enable)) begin
			$display("Critical Warning: parameter 'tx_pipe_enable' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", tx_pipe_enable, rbc_all_tx_pipe_enable, fnl_tx_pipe_enable);
		end
		//$display("rx_pipe_enable = orig: '%s', any:'%s', all:'%s', final: '%s'", rx_pipe_enable, rbc_any_rx_pipe_enable, rbc_all_rx_pipe_enable, fnl_rx_pipe_enable);
		if (!is_in_legal_set(rx_pipe_enable, rbc_all_rx_pipe_enable)) begin
			$display("Critical Warning: parameter 'rx_pipe_enable' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", rx_pipe_enable, rbc_all_rx_pipe_enable, fnl_rx_pipe_enable);
		end
		//$display("pipe_byte_de_serializer_en = orig: '%s', any:'%s', all:'%s', final: '%s'", pipe_byte_de_serializer_en, rbc_any_pipe_byte_de_serializer_en, rbc_all_pipe_byte_de_serializer_en, fnl_pipe_byte_de_serializer_en);
		if (!is_in_legal_set(pipe_byte_de_serializer_en, rbc_all_pipe_byte_de_serializer_en)) begin
			$display("Critical Warning: parameter 'pipe_byte_de_serializer_en' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", pipe_byte_de_serializer_en, rbc_all_pipe_byte_de_serializer_en, fnl_pipe_byte_de_serializer_en);
		end
		//$display("txswing = orig: '%s', any:'%s', all:'%s', final: '%s'", txswing, rbc_any_txswing, rbc_all_txswing, fnl_txswing);
		if (!is_in_legal_set(txswing, rbc_all_txswing)) begin
			$display("Critical Warning: parameter 'txswing' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", txswing, rbc_all_txswing, fnl_txswing);
		end
		//$display("rxdetect_bypass = orig: '%s', any:'%s', all:'%s', final: '%s'", rxdetect_bypass, rbc_any_rxdetect_bypass, rbc_all_rxdetect_bypass, fnl_rxdetect_bypass);
		if (!is_in_legal_set(rxdetect_bypass, rbc_all_rxdetect_bypass)) begin
			$display("Critical Warning: parameter 'rxdetect_bypass' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", rxdetect_bypass, rbc_all_rxdetect_bypass, fnl_rxdetect_bypass);
		end
		//$display("error_replace_pad = orig: '%s', any:'%s', all:'%s', final: '%s'", error_replace_pad, rbc_any_error_replace_pad, rbc_all_error_replace_pad, fnl_error_replace_pad);
		if (!is_in_legal_set(error_replace_pad, rbc_all_error_replace_pad)) begin
			$display("Critical Warning: parameter 'error_replace_pad' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", error_replace_pad, rbc_all_error_replace_pad, fnl_error_replace_pad);
		end
		//$display("ind_error_reporting = orig: '%s', any:'%s', all:'%s', final: '%s'", ind_error_reporting, rbc_any_ind_error_reporting, rbc_all_ind_error_reporting, fnl_ind_error_reporting);
		if (!is_in_legal_set(ind_error_reporting, rbc_all_ind_error_reporting)) begin
			$display("Critical Warning: parameter 'ind_error_reporting' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", ind_error_reporting, rbc_all_ind_error_reporting, fnl_ind_error_reporting);
		end
		//$display("phystatus_rst_toggle = orig: '%s', any:'%s', all:'%s', final: '%s'", phystatus_rst_toggle, rbc_any_phystatus_rst_toggle, rbc_all_phystatus_rst_toggle, fnl_phystatus_rst_toggle);
		if (!is_in_legal_set(phystatus_rst_toggle, rbc_all_phystatus_rst_toggle)) begin
			$display("Critical Warning: parameter 'phystatus_rst_toggle' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", phystatus_rst_toggle, rbc_all_phystatus_rst_toggle, fnl_phystatus_rst_toggle);
		end
	end

	arriav_hssi_pipe_gen1_2 #(
		.prot_mode(fnl_prot_mode),
		.avmm_group_channel_index(avmm_group_channel_index),
		.ctrl_plane_bonding_consumption(fnl_ctrl_plane_bonding_consumption),
		.elec_idle_delay_val(elec_idle_delay_val),
		.elecidle_delay(elecidle_delay),
		.phy_status_delay(phy_status_delay),
		.phystatus_delay_val(phystatus_delay_val),
		.rpre_emph_a_val(rpre_emph_a_val),
		.rpre_emph_b_val(rpre_emph_b_val),
		.rpre_emph_c_val(rpre_emph_c_val),
		.rpre_emph_d_val(rpre_emph_d_val),
		.rpre_emph_e_val(rpre_emph_e_val),
		.rpre_emph_settings(rpre_emph_settings),
		.rvod_sel_a_val(rvod_sel_a_val),
		.rvod_sel_b_val(rvod_sel_b_val),
		.rvod_sel_c_val(rvod_sel_c_val),
		.rvod_sel_d_val(rvod_sel_d_val),
		.rvod_sel_e_val(rvod_sel_e_val),
		.rvod_sel_settings(rvod_sel_settings),
		.sup_mode(fnl_sup_mode),
		.use_default_base_address(fnl_use_default_base_address),
		.user_base_address(user_base_address),
		.hip_mode(fnl_hip_mode),
		.tx_pipe_enable(fnl_tx_pipe_enable),
		.rx_pipe_enable(fnl_rx_pipe_enable),
		.pipe_byte_de_serializer_en(fnl_pipe_byte_de_serializer_en),
		.txswing(fnl_txswing),
		.rxdetect_bypass(fnl_rxdetect_bypass),
		.error_replace_pad(fnl_error_replace_pad),
		.ind_error_reporting(fnl_ind_error_reporting),
		.phystatus_rst_toggle(fnl_phystatus_rst_toggle)
	) wys (
		// ports
		.avmmaddress(avmmaddress),
		.avmmbyteen(avmmbyteen),
		.avmmclk(avmmclk),
		.avmmread(avmmread),
		.avmmreaddata(avmmreaddata),
		.avmmrstn(avmmrstn),
		.avmmwrite(avmmwrite),
		.avmmwritedata(avmmwritedata),
		.blockselect(blockselect),
		.currentcoeff(currentcoeff),
		.pcieswitch(pcieswitch),
		.phystatus(phystatus),
		.piperxclk(piperxclk),
		.pipetxclk(pipetxclk),
		.polinvrx(polinvrx),
		.polinvrxint(polinvrxint),
		.powerdown(powerdown),
		.powerstatetransitiondone(powerstatetransitiondone),
		.powerstatetransitiondoneena(powerstatetransitiondoneena),
		.refclkb(refclkb),
		.refclkbreset(refclkbreset),
		.revloopback(revloopback),
		.revloopbk(revloopbk),
		.revloopbkpcsgen3(revloopbkpcsgen3),
		.rxd(rxd),
		.rxdch(rxdch),
		.rxdetectvalid(rxdetectvalid),
		.rxelecidle(rxelecidle),
		.rxelectricalidle(rxelectricalidle),
		.rxelectricalidleout(rxelectricalidleout),
		.rxfound(rxfound),
		.rxpipereset(rxpipereset),
		.rxpolarity(rxpolarity),
		.rxstatus(rxstatus),
		.rxvalid(rxvalid),
		.sigdetni(sigdetni),
		.speedchange(speedchange),
		.speedchangechnldown(speedchangechnldown),
		.speedchangechnlup(speedchangechnlup),
		.speedchangeout(speedchangeout),
		.txd(txd),
		.txdch(txdch),
		.txdeemph(txdeemph),
		.txdetectrx(txdetectrx),
		.txdetectrxloopback(txdetectrxloopback),
		.txelecidlecomp(txelecidlecomp),
		.txelecidlein(txelecidlein),
		.txelecidleout(txelecidleout),
		.txmargin(txmargin),
		.txpipereset(txpipereset),
		.txswingport(txswingport)
	);
endmodule
