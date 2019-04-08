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


// Verilog RBC parameter resolution wrapper for arriav_hssi_8g_tx_pcs
//

`timescale 1 ns / 1 ps

module av_hssi_8g_tx_pcs_rbc #(
	// unconstrained parameters
	parameter prot_mode = "<auto_single>",	// basic, cpri, cpri_rx_tx, disabled_prot_mode, gige, pipe_g1, pipe_g2, srio_2p1, test, xaui
	parameter sup_mode = "<auto_single>",	// engineering_mode, user_mode

	// extra unconstrained parameters found in atom map
	parameter avmm_group_channel_index = 0,	// 0..2
	parameter channel_number = 0,	// 0..65
	parameter cid_pattern_len = 8'b0,	// 8
	parameter use_default_base_address = "true",	// false, true
	parameter user_base_address = 0,	// 0..2047

	// constrained parameters
	parameter test_mode = "<auto_single>",	// bist, dont_care_test, prbs
	parameter hip_mode = "<auto_single>",	// dis_hip, en_hip
	parameter pma_dw = "<auto_single>",	// eight_bit, sixteen_bit, ten_bit, twenty_bit
	parameter pcs_bypass = "<auto_single>",	// dis_pcs_bypass, en_pcs_bypass
	parameter phase_compensation_fifo = "<auto_single>",	// low_latency, normal_latency, pld_ctrl_low_latency, pld_ctrl_normal_latency, register_fifo
	parameter tx_compliance_controlled_disparity = "<auto_single>",	// dis_txcompliance, en_txcompliance_pipe2p0
	parameter force_kchar = "<auto_single>",	// dis_force_kchar, en_force_kchar
	parameter force_echar = "<auto_single>",	// dis_force_echar, en_force_echar
	parameter byte_serializer = "<auto_single>",	// dis_bs, en_bs_by_2
	parameter data_selection_8b10b_encoder_input = "<auto_single>",	// gige_idle_conversion, normal_data_path, xaui_sm
	parameter eightb_tenb_disp_ctrl = "<auto_single>",	// dis_disp_ctrl, en_disp_ctrl, en_ib_disp_ctrl
	parameter eightb_tenb_encoder = "<auto_single>",	// dis_8b10b, en_8b10b_ibm, en_8b10b_sgx
	parameter prbs_gen = "<auto_single>",	// dis_prbs, prbs_10, prbs_15, prbs_23_dw, prbs_23_sw, prbs_31, prbs_7_dw, prbs_7_sw, prbs_8, prbs_hf_dw, prbs_hf_sw, prbs_lf_dw, prbs_lf_sw, prbs_mf_dw, prbs_mf_sw
	parameter cid_pattern = "<auto_single>",	// cid_pattern_0, cid_pattern_1
	parameter bist_gen = "<auto_single>",	// cjpat, crpat, dis_bist, incremental
	parameter bit_reversal = "<auto_single>",	// dis_bit_reversal, en_bit_reversal
	parameter symbol_swap = "<auto_single>",	// dis_symbol_swap, en_symbol_swap
	parameter polarity_inversion = "<auto_single>",	// dis_polinv, enable_polinv
	parameter tx_bitslip = "<auto_single>",	// dis_tx_bitslip, en_tx_bitslip
	parameter ctrl_plane_bonding_consumption = "<auto_single>",	// bundled_master, bundled_slave_above, bundled_slave_below, individual
	parameter agg_block_sel = "<auto_single>",	// other_smrt_pack, same_smrt_pack
	parameter ctrl_plane_bonding_distribution = "<auto_single>",	// master_chnl_distr, not_master_chnl_distr
	parameter ctrl_plane_bonding_compensation = "<auto_single>",	// dis_compensation, en_compensation
	parameter bypass_pipeline_reg = "<auto_single>",	// dis_bypass_pipeline, en_bypass_pipeline
	parameter clock_gate_bs_enc = "<auto_single>",	// dis_bs_enc_clk_gating, en_bs_enc_clk_gating
	parameter clock_gate_prbs = "<auto_single>",	// dis_prbs_clk_gating, en_prbs_clk_gating
	parameter clock_gate_bist = "<auto_single>",	// dis_bist_clk_gating, en_bist_clk_gating
	parameter clock_gate_sw_fifowr = "<auto_single>",	// dis_sw_fifowr_clk_gating, en_sw_fifowr_clk_gating
	parameter clock_gate_dw_fifowr = "<auto_single>",	// dis_dw_fifowr_clk_gating, en_dw_fifowr_clk_gating
	parameter clock_gate_fiford = "<auto_single>",	// dis_fiford_clk_gating, en_fiford_clk_gating
	parameter revloop_back_rm = "<auto_single>",	// dis_rev_loopback_rx_rm, en_rev_loopback_rx_rm
	parameter phfifo_write_clk_sel = "<auto_single>",	// pld_tx_clk, tx_clk
	parameter refclk_b_clk_sel = "<auto_single>",	// refclk_dig, tx_pma_clock
	parameter dynamic_clk_switch = "<auto_single>",	// dis_dyn_clk_switch, en_dyn_clk_switch
	parameter auto_speed_nego_gen2 = "<auto_single>",	// dis_asn_g2, en_asn_g2_freq_scal
	parameter txclk_freerun = "<auto_single>",	// dis_freerun_tx, en_freerun_tx
	parameter pcfifo_urst = "<auto_single>",	// dis_pcfifourst, en_pcfifourst
	parameter txpcs_urst = "<auto_single>"	// dis_txpcs_urst, en_txpcs_urst
) (
	// ports
	output wire         	aggtxpcsrst,
	input  wire   [10:0]	avmmaddress,
	input  wire    [1:0]	avmmbyteen,
	input  wire         	avmmclk,
	input  wire         	avmmread,
	output wire   [15:0]	avmmreaddata,
	input  wire         	avmmrstn,
	input  wire         	avmmwrite,
	input  wire   [15:0]	avmmwritedata,
	input  wire    [4:0]	bitslipboundaryselect,
	output wire         	blockselect,
	output wire         	clkout,
	input  wire         	coreclk,
	input  wire   [43:0]	datain,
	output wire   [19:0]	dataout,
	input  wire         	detectrxloopin,
	output wire         	detectrxloopout,
	input  wire         	dispcbyte,
	output wire         	dynclkswitchn,
	input  wire    [2:0]	elecidleinfersel,
	input  wire         	enrevparallellpbk,
	input  wire    [1:0]	fifoselectinchnldown,
	input  wire    [1:0]	fifoselectinchnlup,
	output wire    [1:0]	fifoselectoutchnldown,
	output wire    [1:0]	fifoselectoutchnlup,
	output wire    [2:0]	grayelecidleinferselout,
	input  wire         	hrdrst,
	input  wire         	invpol,
	output wire         	observablebyteserdesclock,
	output wire   [19:0]	parallelfdbkout,
	output wire         	phfifooverflow,
	input  wire         	phfiforddisable,
	input  wire         	phfiforeset,
	output wire         	phfifotxdeemph,
	output wire    [2:0]	phfifotxmargin,
	output wire         	phfifotxswing,
	output wire         	phfifounderflow,
	input  wire         	phfifowrenable,
	input  wire         	pipeenrevparallellpbkin,
	output wire         	pipeenrevparallellpbkout,
	output wire    [1:0]	pipepowerdownout,
	input  wire         	pipetxdeemph,
	input  wire    [2:0]	pipetxmargin,
	input  wire         	pipetxswing,
	input  wire         	polinvrxin,
	output wire         	polinvrxout,
	input  wire    [1:0]	powerdn,
	input  wire         	prbscidenable,
	input  wire         	rateswitch,
	input  wire         	rdenableinchnldown,
	input  wire         	rdenableinchnlup,
	output wire         	rdenableoutchnldown,
	output wire         	rdenableoutchnlup,
	output wire         	rdenablesync,
	output wire         	refclkb,
	output wire         	refclkbreset,
	input  wire         	refclkdig,
	input  wire         	resetpcptrs,
	input  wire         	resetpcptrsinchnldown,
	input  wire         	resetpcptrsinchnlup,
	input  wire   [19:0]	revparallellpbkdata,
	input  wire         	rxpolarityin,
	output wire         	rxpolarityout,
	input  wire         	scanmode,
	output wire         	syncdatain,
	input  wire    [3:0]	txblkstart,
	output wire    [3:0]	txblkstartout,
	output wire         	txcomplianceout,
	output wire   [19:0]	txctrlplanetestbus,
	output wire    [3:0]	txdatakouttogen3,
	output wire   [31:0]	txdataouttogen3,
	input  wire    [3:0]	txdatavalid,
	output wire    [3:0]	txdatavalidouttogen3,
	output wire    [1:0]	txdivsync,
	input  wire    [1:0]	txdivsyncinchnldown,
	input  wire    [1:0]	txdivsyncinchnlup,
	output wire    [1:0]	txdivsyncoutchnldown,
	output wire    [1:0]	txdivsyncoutchnlup,
	output wire         	txelecidleout,
	input  wire         	txpcsreset,
	output wire         	txpipeclk,
	output wire         	txpipeelectidle,
	output wire         	txpipesoftreset,
	input  wire         	txpmalocalclk,
	input  wire    [1:0]	txsynchdr,
	output wire    [1:0]	txsynchdrout,
	output wire   [19:0]	txtestbus,
	input  wire         	wrenableinchnldown,
	input  wire         	wrenableinchnlup,
	output wire         	wrenableoutchnldown,
	output wire         	wrenableoutchnlup,
	input  wire         	xgmctrl,
	output wire         	xgmctrlenable,
	input  wire         	xgmctrltoporbottom,
	input  wire    [7:0]	xgmdatain,
	input  wire    [7:0]	xgmdataintoporbottom,
	output wire    [7:0]	xgmdataout
);
	import altera_xcvr_functions::*;

	// prot_mode external parameter (no RBC)
	localparam rbc_all_prot_mode = "(basic,cpri,cpri_rx_tx,disabled_prot_mode,gige,pipe_g1,pipe_g2,srio_2p1,test,xaui)";
	localparam rbc_any_prot_mode = "basic";
	localparam fnl_prot_mode = (prot_mode == "<auto_any>" || prot_mode == "<auto_single>") ? rbc_any_prot_mode : prot_mode;

	// sup_mode external parameter (no RBC)
	localparam rbc_all_sup_mode = "(engineering_mode,user_mode)";
	localparam rbc_any_sup_mode = "user_mode";
	localparam fnl_sup_mode = (sup_mode == "<auto_any>" || sup_mode == "<auto_single>") ? rbc_any_sup_mode : sup_mode;

	// use_default_base_address external parameter (no RBC)
	localparam rbc_all_use_default_base_address = "(false,true)";
	localparam rbc_any_use_default_base_address = "true";
	localparam fnl_use_default_base_address = (use_default_base_address == "<auto_any>" || use_default_base_address == "<auto_single>") ? rbc_any_use_default_base_address : use_default_base_address;

	// test_mode, RBC-validated
	localparam rbc_all_test_mode = (fnl_prot_mode != "test") ? ("dont_care_test") : "(prbs,bist)";
	localparam rbc_any_test_mode = (fnl_prot_mode != "test") ? ("dont_care_test") : "prbs";
	localparam fnl_test_mode = (test_mode == "<auto_any>" || test_mode == "<auto_single>") ? rbc_any_test_mode : test_mode;

	// hip_mode, RBC-validated
	localparam rbc_all_hip_mode = (fnl_prot_mode == "pipe_g1" || fnl_prot_mode == "pipe_g2" ) ? ("(dis_hip,en_hip)") : "dis_hip";
	localparam rbc_any_hip_mode = (fnl_prot_mode == "pipe_g1" || fnl_prot_mode == "pipe_g2" ) ? ("dis_hip") : "dis_hip";
	localparam fnl_hip_mode = (hip_mode == "<auto_any>" || hip_mode == "<auto_single>") ? rbc_any_hip_mode : hip_mode;

	// pma_dw, RBC-validated
	localparam rbc_all_pma_dw = ( fnl_prot_mode == "srio_2p1" ) ? ("twenty_bit")
		 : ( (fnl_prot_mode == "basic") || (fnl_test_mode == "prbs") ) ? ("(eight_bit,ten_bit,sixteen_bit,twenty_bit)")
			 : ( (fnl_test_mode == "bist" ) || ( fnl_prot_mode == "cpri")  ||  (fnl_prot_mode == "cpri_rx_tx")) ? ("(ten_bit,twenty_bit)") : "ten_bit";
	localparam rbc_any_pma_dw = ( fnl_prot_mode == "srio_2p1" ) ? ("twenty_bit")
		 : ( (fnl_prot_mode == "basic") || (fnl_test_mode == "prbs") ) ? ("eight_bit")
			 : ( (fnl_test_mode == "bist" ) || ( fnl_prot_mode == "cpri")  ||  (fnl_prot_mode == "cpri_rx_tx")) ? ("ten_bit") : "ten_bit";
	localparam fnl_pma_dw = (pma_dw == "<auto_any>" || pma_dw == "<auto_single>") ? rbc_any_pma_dw : pma_dw;

	// pcs_bypass, RBC-validated
	localparam rbc_all_pcs_bypass = ((fnl_prot_mode == "basic") ||  (fnl_prot_mode == "cpri_rx_tx")) ? ("(dis_pcs_bypass,en_pcs_bypass)") : "dis_pcs_bypass";
	localparam rbc_any_pcs_bypass = ((fnl_prot_mode == "basic") ||  (fnl_prot_mode == "cpri_rx_tx")) ? ("dis_pcs_bypass") : "dis_pcs_bypass";
	localparam fnl_pcs_bypass = (pcs_bypass == "<auto_any>" || pcs_bypass == "<auto_single>") ? rbc_any_pcs_bypass : pcs_bypass;

	// phase_compensation_fifo, RBC-validated
	localparam rbc_all_phase_compensation_fifo = (fnl_prot_mode == "cpri" || fnl_prot_mode == "cpri_rx_tx" || fnl_hip_mode == "en_hip"  ) ? ("register_fifo")
		 : ( (fnl_prot_mode == "basic")  || (fnl_prot_mode == "gige") ) ? ("(low_latency,register_fifo)") : "low_latency";
	localparam rbc_any_phase_compensation_fifo = (fnl_prot_mode == "cpri" || fnl_prot_mode == "cpri_rx_tx" || fnl_hip_mode == "en_hip"  ) ? ("register_fifo")
		 : ( (fnl_prot_mode == "basic")  || (fnl_prot_mode == "gige") ) ? ("low_latency") : "low_latency";
	localparam fnl_phase_compensation_fifo = (phase_compensation_fifo == "<auto_any>" || phase_compensation_fifo == "<auto_single>") ? rbc_any_phase_compensation_fifo : phase_compensation_fifo;

	// tx_compliance_controlled_disparity, RBC-validated
	localparam rbc_all_tx_compliance_controlled_disparity = ((fnl_prot_mode == "pipe_g1") || (fnl_prot_mode == "pipe_g2")) ? ("en_txcompliance_pipe2p0") : "dis_txcompliance";
	localparam rbc_any_tx_compliance_controlled_disparity = ((fnl_prot_mode == "pipe_g1") || (fnl_prot_mode == "pipe_g2")) ? ("en_txcompliance_pipe2p0") : "dis_txcompliance";
	localparam fnl_tx_compliance_controlled_disparity = (tx_compliance_controlled_disparity == "<auto_any>" || tx_compliance_controlled_disparity == "<auto_single>") ? rbc_any_tx_compliance_controlled_disparity : tx_compliance_controlled_disparity;

	// force_kchar, RBC-validated
	localparam rbc_all_force_kchar = "dis_force_kchar";
	localparam rbc_any_force_kchar = "dis_force_kchar";
	localparam fnl_force_kchar = (force_kchar == "<auto_any>" || force_kchar == "<auto_single>") ? rbc_any_force_kchar : force_kchar;

	// force_echar, RBC-validated
	localparam rbc_all_force_echar = "dis_force_echar";
	localparam rbc_any_force_echar = "dis_force_echar";
	localparam fnl_force_echar = (force_echar == "<auto_any>" || force_echar == "<auto_single>") ? rbc_any_force_echar : force_echar;

	// byte_serializer, RBC-validated
	localparam rbc_all_byte_serializer = (  (fnl_test_mode == "prbs") || (fnl_test_mode == "bist" && fnl_pma_dw == "twenty_bit")   || (fnl_prot_mode == "disabled_prot_mode") || (fnl_hip_mode == "en_hip")  ) ? ("dis_bs")
		 : ( (fnl_prot_mode == "xaui") || (fnl_test_mode == "bist" && fnl_pma_dw == "ten_bit" ) || ( fnl_prot_mode == "pipe_g2"  ) ) ? ("en_bs_by_2") : "(dis_bs,en_bs_by_2)";
	localparam rbc_any_byte_serializer = (  (fnl_test_mode == "prbs") || (fnl_test_mode == "bist" && fnl_pma_dw == "twenty_bit")   || (fnl_prot_mode == "disabled_prot_mode") || (fnl_hip_mode == "en_hip")  ) ? ("dis_bs")
		 : ( (fnl_prot_mode == "xaui") || (fnl_test_mode == "bist" && fnl_pma_dw == "ten_bit" ) || ( fnl_prot_mode == "pipe_g2"  ) ) ? ("en_bs_by_2") : "dis_bs";
	localparam fnl_byte_serializer = (byte_serializer == "<auto_any>" || byte_serializer == "<auto_single>") ? rbc_any_byte_serializer : byte_serializer;

	// data_selection_8b10b_encoder_input, RBC-validated
	localparam rbc_all_data_selection_8b10b_encoder_input = (fnl_prot_mode == "gige") ? ("gige_idle_conversion")
		 : (fnl_prot_mode == "xaui") ? ("xaui_sm") : "normal_data_path";
	localparam rbc_any_data_selection_8b10b_encoder_input = (fnl_prot_mode == "gige") ? ("gige_idle_conversion")
		 : (fnl_prot_mode == "xaui") ? ("xaui_sm") : "normal_data_path";
	localparam fnl_data_selection_8b10b_encoder_input = (data_selection_8b10b_encoder_input == "<auto_any>" || data_selection_8b10b_encoder_input == "<auto_single>") ? rbc_any_data_selection_8b10b_encoder_input : data_selection_8b10b_encoder_input;

	// eightb_tenb_disp_ctrl, RBC-validated
	localparam rbc_all_eightb_tenb_disp_ctrl = ( fnl_prot_mode == "basic") ? ("(dis_disp_ctrl,en_disp_ctrl)")
		 : (fnl_prot_mode == "pipe_g1" || fnl_prot_mode == "pipe_g2" ) ? ("en_disp_ctrl") : "dis_disp_ctrl";
	localparam rbc_any_eightb_tenb_disp_ctrl = ( fnl_prot_mode == "basic") ? ("dis_disp_ctrl")
		 : (fnl_prot_mode == "pipe_g1" || fnl_prot_mode == "pipe_g2" ) ? ("en_disp_ctrl") : "dis_disp_ctrl";
	localparam fnl_eightb_tenb_disp_ctrl = (eightb_tenb_disp_ctrl == "<auto_any>" || eightb_tenb_disp_ctrl == "<auto_single>") ? rbc_any_eightb_tenb_disp_ctrl : eightb_tenb_disp_ctrl;

	// eightb_tenb_encoder, RBC-validated
	localparam rbc_all_eightb_tenb_encoder = (  (fnl_pma_dw == "eight_bit")  || (fnl_pma_dw == "sixteen_bit") || (fnl_pcs_bypass == "en_pcs_bypass")  || (fnl_test_mode == "prbs")   ) ? ("dis_8b10b")
		 : (((fnl_prot_mode == "basic" ) &&  (fnl_pcs_bypass == "dis_pcs_bypass") && (fnl_sup_mode == "user_mode")) || fnl_prot_mode == "cpri" || fnl_prot_mode == "cpri_rx_tx" ) ? ("(dis_8b10b,en_8b10b_ibm)")
			 : ( (fnl_prot_mode == "basic" ) &&  (fnl_pcs_bypass == "dis_pcs_bypass") && (fnl_sup_mode == "engineering_mode") ) ? ("(dis_8b10b,en_8b10b_ibm,en_8b10b_sgx)") : "en_8b10b_ibm";
	localparam rbc_any_eightb_tenb_encoder = (  (fnl_pma_dw == "eight_bit")  || (fnl_pma_dw == "sixteen_bit") || (fnl_pcs_bypass == "en_pcs_bypass")  || (fnl_test_mode == "prbs")   ) ? ("dis_8b10b")
		 : (((fnl_prot_mode == "basic" ) &&  (fnl_pcs_bypass == "dis_pcs_bypass") && (fnl_sup_mode == "user_mode")) || fnl_prot_mode == "cpri" || fnl_prot_mode == "cpri_rx_tx" ) ? ("dis_8b10b")
			 : ( (fnl_prot_mode == "basic" ) &&  (fnl_pcs_bypass == "dis_pcs_bypass") && (fnl_sup_mode == "engineering_mode") ) ? ("dis_8b10b") : "en_8b10b_ibm";
	localparam fnl_eightb_tenb_encoder = (eightb_tenb_encoder == "<auto_any>" || eightb_tenb_encoder == "<auto_single>") ? rbc_any_eightb_tenb_encoder : eightb_tenb_encoder;

	// prbs_gen, RBC-validated
	localparam rbc_all_prbs_gen = ( fnl_test_mode == "prbs") ?
		(
			(fnl_pma_dw == "eight_bit") ? ("(prbs_7_sw,prbs_8,prbs_23_sw,prbs_hf_sw,prbs_15,prbs_31)")
			 : (fnl_pma_dw == "ten_bit") ? ("(prbs_10,prbs_hf_sw,prbs_lf_sw,prbs_15,prbs_31)")
				 : (fnl_pma_dw == "sixteen_bit") ? ("(prbs_7_dw,prbs_23_dw,prbs_hf_dw,prbs_15,prbs_31)") : "(prbs_7_dw,prbs_23_dw,prbs_hf_dw,prbs_lf_dw,prbs_15,prbs_31)"
		) : "dis_prbs";
	localparam rbc_any_prbs_gen = ( fnl_test_mode == "prbs") ?
		(
			(fnl_pma_dw == "eight_bit") ? ("prbs_7_sw")
			 : (fnl_pma_dw == "ten_bit") ? ("prbs_10")
				 : (fnl_pma_dw == "sixteen_bit") ? ("prbs_7_dw") : "prbs_7_dw"
		) : "dis_prbs";
	localparam fnl_prbs_gen = (prbs_gen == "<auto_any>" || prbs_gen == "<auto_single>") ? rbc_any_prbs_gen : prbs_gen;

	// cid_pattern, RBC-validated
	localparam rbc_all_cid_pattern = (fnl_prbs_gen == "prbs_8" ) ? ("(cid_pattern_0,cid_pattern_1)") : "cid_pattern_0";
	localparam rbc_any_cid_pattern = (fnl_prbs_gen == "prbs_8" ) ? ("cid_pattern_0") : "cid_pattern_0";
	localparam fnl_cid_pattern = (cid_pattern == "<auto_any>" || cid_pattern == "<auto_single>") ? rbc_any_cid_pattern : cid_pattern;

	// bist_gen, RBC-validated
	localparam rbc_all_bist_gen = ( (fnl_test_mode == "bist") && (fnl_sup_mode == "user_mode") ) ? ("incremental")
		 : ( (fnl_test_mode == "bist") && (fnl_sup_mode == "engineering_mode") ) ? ("(cjpat,crpat)") : "dis_bist";
	localparam rbc_any_bist_gen = ( (fnl_test_mode == "bist") && (fnl_sup_mode == "user_mode") ) ? ("incremental")
		 : ( (fnl_test_mode == "bist") && (fnl_sup_mode == "engineering_mode") ) ? ("cjpat") : "dis_bist";
	localparam fnl_bist_gen = (bist_gen == "<auto_any>" || bist_gen == "<auto_single>") ? rbc_any_bist_gen : bist_gen;

	// bit_reversal, RBC-validated
	localparam rbc_all_bit_reversal = (fnl_prot_mode == "pipe_g1" || fnl_prot_mode == "pipe_g2" || fnl_prot_mode == "cpri" || fnl_prot_mode == "cpri_rx_tx" || fnl_prot_mode == "gige" || fnl_prot_mode == "xaui" || fnl_prot_mode == "srio_2p1" || fnl_prot_mode == "test" ) ? ("dis_bit_reversal")
		 : (fnl_prot_mode == "basic") ? ("(dis_bit_reversal,en_bit_reversal)") : "dis_bit_reversal";
	localparam rbc_any_bit_reversal = (fnl_prot_mode == "pipe_g1" || fnl_prot_mode == "pipe_g2" || fnl_prot_mode == "cpri" || fnl_prot_mode == "cpri_rx_tx" || fnl_prot_mode == "gige" || fnl_prot_mode == "xaui" || fnl_prot_mode == "srio_2p1" || fnl_prot_mode == "test" ) ? ("dis_bit_reversal")
		 : (fnl_prot_mode == "basic") ? ("dis_bit_reversal") : "dis_bit_reversal";
	localparam fnl_bit_reversal = (bit_reversal == "<auto_any>" || bit_reversal == "<auto_single>") ? rbc_any_bit_reversal : bit_reversal;

	// symbol_swap, RBC-validated
	localparam rbc_all_symbol_swap = ((fnl_prot_mode == "basic") && (fnl_pma_dw == "sixteen_bit" || fnl_pma_dw == "twenty_bit")) ? ("(dis_symbol_swap,en_symbol_swap)") : "dis_symbol_swap";
	localparam rbc_any_symbol_swap = ((fnl_prot_mode == "basic") && (fnl_pma_dw == "sixteen_bit" || fnl_pma_dw == "twenty_bit")) ? ("dis_symbol_swap") : "dis_symbol_swap";
	localparam fnl_symbol_swap = (symbol_swap == "<auto_any>" || symbol_swap == "<auto_single>") ? rbc_any_symbol_swap : symbol_swap;

	// polarity_inversion, RBC-validated
	localparam rbc_all_polarity_inversion = (fnl_prot_mode == "disabled_prot_mode") ? ("dis_polinv")
		 : (fnl_prot_mode == "test") ?
			(
				( (fnl_test_mode == "prbs") && (fnl_prbs_gen == "prbs_31")) ? ("(dis_polinv,enable_polinv)") : "dis_polinv"
			) : "(dis_polinv,enable_polinv)";
	localparam rbc_any_polarity_inversion = (fnl_prot_mode == "disabled_prot_mode") ? ("dis_polinv")
		 : (fnl_prot_mode == "test") ?
			(
				( (fnl_test_mode == "prbs") && (fnl_prbs_gen == "prbs_31")) ? ("dis_polinv") : "dis_polinv"
			) : "dis_polinv";
	localparam fnl_polarity_inversion = (polarity_inversion == "<auto_any>" || polarity_inversion == "<auto_single>") ? rbc_any_polarity_inversion : polarity_inversion;

	// tx_bitslip, RBC-validated
	localparam rbc_all_tx_bitslip = (fnl_prot_mode == "cpri_rx_tx") ? ("en_tx_bitslip")
		 : (fnl_prot_mode == "pipe_g1" || fnl_prot_mode == "pipe_g2" || fnl_prot_mode == "gige" || fnl_prot_mode == "xaui" || fnl_prot_mode == "test") ? ("dis_tx_bitslip")
			 : ( (fnl_prot_mode == "basic") || (fnl_prot_mode == "srio_2p1") || (fnl_prot_mode == "cpri") ) ? ("(en_tx_bitslip,dis_tx_bitslip)") : "dis_tx_bitslip";
	localparam rbc_any_tx_bitslip = (fnl_prot_mode == "cpri_rx_tx") ? ("en_tx_bitslip")
		 : (fnl_prot_mode == "pipe_g1" || fnl_prot_mode == "pipe_g2" || fnl_prot_mode == "gige" || fnl_prot_mode == "xaui" || fnl_prot_mode == "test") ? ("dis_tx_bitslip")
			 : ( (fnl_prot_mode == "basic") || (fnl_prot_mode == "srio_2p1") || (fnl_prot_mode == "cpri") ) ? ("dis_tx_bitslip") : "dis_tx_bitslip";
	localparam fnl_tx_bitslip = (tx_bitslip == "<auto_any>" || tx_bitslip == "<auto_single>") ? rbc_any_tx_bitslip : tx_bitslip;

	// ctrl_plane_bonding_consumption, RBC-validated
	localparam rbc_all_ctrl_plane_bonding_consumption = ( (fnl_prot_mode == "test") || (fnl_prot_mode == "gige") ||  (fnl_prot_mode == "disabled_prot_mode")  ) ? ("individual")
		 : (fnl_prot_mode == "xaui") ? ("(bundled_master,bundled_slave_below,bundled_slave_above)") : "(individual,bundled_master,bundled_slave_below,bundled_slave_above)";
	localparam rbc_any_ctrl_plane_bonding_consumption = ( (fnl_prot_mode == "test") || (fnl_prot_mode == "gige") ||  (fnl_prot_mode == "disabled_prot_mode")  ) ? ("individual")
		 : (fnl_prot_mode == "xaui") ? ("bundled_master") : "individual";
	localparam fnl_ctrl_plane_bonding_consumption = (ctrl_plane_bonding_consumption == "<auto_any>" || ctrl_plane_bonding_consumption == "<auto_single>") ? rbc_any_ctrl_plane_bonding_consumption : ctrl_plane_bonding_consumption;

	// agg_block_sel, RBC-validated
	localparam rbc_all_agg_block_sel = ( (fnl_prot_mode == "xaui") || ( (fnl_prot_mode == "srio_2p1") && (fnl_ctrl_plane_bonding_consumption != "individual")) ) ? ("(same_smrt_pack,other_smrt_pack)") : "same_smrt_pack";
	localparam rbc_any_agg_block_sel = ( (fnl_prot_mode == "xaui") || ( (fnl_prot_mode == "srio_2p1") && (fnl_ctrl_plane_bonding_consumption != "individual")) ) ? ("same_smrt_pack") : "same_smrt_pack";
	localparam fnl_agg_block_sel = (agg_block_sel == "<auto_any>" || agg_block_sel == "<auto_single>") ? rbc_any_agg_block_sel : agg_block_sel;

	// ctrl_plane_bonding_distribution, RBC-validated
	localparam rbc_all_ctrl_plane_bonding_distribution = (fnl_ctrl_plane_bonding_consumption == "bundled_master") ? ("master_chnl_distr") : "not_master_chnl_distr";
	localparam rbc_any_ctrl_plane_bonding_distribution = (fnl_ctrl_plane_bonding_consumption == "bundled_master") ? ("master_chnl_distr") : "not_master_chnl_distr";
	localparam fnl_ctrl_plane_bonding_distribution = (ctrl_plane_bonding_distribution == "<auto_any>" || ctrl_plane_bonding_distribution == "<auto_single>") ? rbc_any_ctrl_plane_bonding_distribution : ctrl_plane_bonding_distribution;

	// ctrl_plane_bonding_compensation, RBC-validated
	localparam rbc_all_ctrl_plane_bonding_compensation = "dis_compensation";
	localparam rbc_any_ctrl_plane_bonding_compensation = "dis_compensation";
	localparam fnl_ctrl_plane_bonding_compensation = (ctrl_plane_bonding_compensation == "<auto_any>" || ctrl_plane_bonding_compensation == "<auto_single>") ? rbc_any_ctrl_plane_bonding_compensation : ctrl_plane_bonding_compensation;

	// bypass_pipeline_reg, RBC-validated
	localparam rbc_all_bypass_pipeline_reg = "dis_bypass_pipeline";
	localparam rbc_any_bypass_pipeline_reg = "dis_bypass_pipeline";
	localparam fnl_bypass_pipeline_reg = (bypass_pipeline_reg == "<auto_any>" || bypass_pipeline_reg == "<auto_single>") ? rbc_any_bypass_pipeline_reg : bypass_pipeline_reg;

	// clock_gate_bs_enc, RBC-validated
	localparam rbc_all_clock_gate_bs_enc = (fnl_prot_mode == "disabled_prot_mode") ? ("en_bs_enc_clk_gating") : "dis_bs_enc_clk_gating";
	localparam rbc_any_clock_gate_bs_enc = (fnl_prot_mode == "disabled_prot_mode") ? ("en_bs_enc_clk_gating") : "dis_bs_enc_clk_gating";
	localparam fnl_clock_gate_bs_enc = (clock_gate_bs_enc == "<auto_any>" || clock_gate_bs_enc == "<auto_single>") ? rbc_any_clock_gate_bs_enc : clock_gate_bs_enc;

	// clock_gate_prbs, RBC-validated
	localparam rbc_all_clock_gate_prbs = (fnl_test_mode != "prbs" ) ? ("en_prbs_clk_gating") : "dis_prbs_clk_gating";
	localparam rbc_any_clock_gate_prbs = (fnl_test_mode != "prbs" ) ? ("en_prbs_clk_gating") : "dis_prbs_clk_gating";
	localparam fnl_clock_gate_prbs = (clock_gate_prbs == "<auto_any>" || clock_gate_prbs == "<auto_single>") ? rbc_any_clock_gate_prbs : clock_gate_prbs;

	// clock_gate_bist, RBC-validated
	localparam rbc_all_clock_gate_bist = (fnl_test_mode != "bist" ) ? ("en_bist_clk_gating") : "dis_bist_clk_gating";
	localparam rbc_any_clock_gate_bist = (fnl_test_mode != "bist" ) ? ("en_bist_clk_gating") : "dis_bist_clk_gating";
	localparam fnl_clock_gate_bist = (clock_gate_bist == "<auto_any>" || clock_gate_bist == "<auto_single>") ? rbc_any_clock_gate_bist : clock_gate_bist;

	// clock_gate_sw_fifowr, RBC-validated
	localparam rbc_all_clock_gate_sw_fifowr = ( (fnl_prot_mode == "disabled_prot_mode") ||((fnl_phase_compensation_fifo == "register_fifo") && (fnl_hip_mode == "dis_hip")) ) ? ("en_sw_fifowr_clk_gating") : "dis_sw_fifowr_clk_gating";
	localparam rbc_any_clock_gate_sw_fifowr = ( (fnl_prot_mode == "disabled_prot_mode") ||((fnl_phase_compensation_fifo == "register_fifo") && (fnl_hip_mode == "dis_hip")) ) ? ("en_sw_fifowr_clk_gating") : "dis_sw_fifowr_clk_gating";
	localparam fnl_clock_gate_sw_fifowr = (clock_gate_sw_fifowr == "<auto_any>" || clock_gate_sw_fifowr == "<auto_single>") ? rbc_any_clock_gate_sw_fifowr : clock_gate_sw_fifowr;

	// clock_gate_dw_fifowr, RBC-validated
	localparam rbc_all_clock_gate_dw_fifowr = ( (fnl_prot_mode == "disabled_prot_mode") || (fnl_phase_compensation_fifo == "register_fifo") || (fnl_pma_dw == "ten_bit") || (fnl_pma_dw == "eight_bit") ) ? ("en_dw_fifowr_clk_gating") : "dis_dw_fifowr_clk_gating";
	localparam rbc_any_clock_gate_dw_fifowr = ( (fnl_prot_mode == "disabled_prot_mode") || (fnl_phase_compensation_fifo == "register_fifo") || (fnl_pma_dw == "ten_bit") || (fnl_pma_dw == "eight_bit") ) ? ("en_dw_fifowr_clk_gating") : "dis_dw_fifowr_clk_gating";
	localparam fnl_clock_gate_dw_fifowr = (clock_gate_dw_fifowr == "<auto_any>" || clock_gate_dw_fifowr == "<auto_single>") ? rbc_any_clock_gate_dw_fifowr : clock_gate_dw_fifowr;

	// clock_gate_fiford, RBC-validated
	localparam rbc_all_clock_gate_fiford = (fnl_prot_mode == "disabled_prot_mode") ? ("en_fiford_clk_gating") : "dis_fiford_clk_gating";
	localparam rbc_any_clock_gate_fiford = (fnl_prot_mode == "disabled_prot_mode") ? ("en_fiford_clk_gating") : "dis_fiford_clk_gating";
	localparam fnl_clock_gate_fiford = (clock_gate_fiford == "<auto_any>" || clock_gate_fiford == "<auto_single>") ? rbc_any_clock_gate_fiford : clock_gate_fiford;

	// revloop_back_rm, RBC-validated
	localparam rbc_all_revloop_back_rm = ((fnl_prot_mode == "pipe_g1") || (fnl_prot_mode == "pipe_g2")) ? ("en_rev_loopback_rx_rm") : "dis_rev_loopback_rx_rm";
	localparam rbc_any_revloop_back_rm = ((fnl_prot_mode == "pipe_g1") || (fnl_prot_mode == "pipe_g2")) ? ("en_rev_loopback_rx_rm") : "dis_rev_loopback_rx_rm";
	localparam fnl_revloop_back_rm = (revloop_back_rm == "<auto_any>" || revloop_back_rm == "<auto_single>") ? rbc_any_revloop_back_rm : revloop_back_rm;

	// phfifo_write_clk_sel, RBC-validated
	localparam rbc_all_phfifo_write_clk_sel = ((fnl_prot_mode == "test") || (fnl_phase_compensation_fifo == "register_fifo") ) ? ("tx_clk") : "pld_tx_clk";
	localparam rbc_any_phfifo_write_clk_sel = ((fnl_prot_mode == "test") || (fnl_phase_compensation_fifo == "register_fifo") ) ? ("tx_clk") : "pld_tx_clk";
	localparam fnl_phfifo_write_clk_sel = (phfifo_write_clk_sel == "<auto_any>" || phfifo_write_clk_sel == "<auto_single>") ? rbc_any_phfifo_write_clk_sel : phfifo_write_clk_sel;

	// refclk_b_clk_sel, RBC-validated
	localparam rbc_all_refclk_b_clk_sel = (fnl_sup_mode == "engineering_mode") ? ("(refclk_dig,tx_pma_clock)") : "tx_pma_clock";
	localparam rbc_any_refclk_b_clk_sel = (fnl_sup_mode == "engineering_mode") ? ("tx_pma_clock") : "tx_pma_clock";
	localparam fnl_refclk_b_clk_sel = (refclk_b_clk_sel == "<auto_any>" || refclk_b_clk_sel == "<auto_single>") ? rbc_any_refclk_b_clk_sel : refclk_b_clk_sel;

	// dynamic_clk_switch, RBC-validated
	localparam rbc_all_dynamic_clk_switch = "dis_dyn_clk_switch";
	localparam rbc_any_dynamic_clk_switch = "dis_dyn_clk_switch";
	localparam fnl_dynamic_clk_switch = (dynamic_clk_switch == "<auto_any>" || dynamic_clk_switch == "<auto_single>") ? rbc_any_dynamic_clk_switch : dynamic_clk_switch;

	// auto_speed_nego_gen2, RBC-validated
	localparam rbc_all_auto_speed_nego_gen2 = ( (fnl_prot_mode == "pipe_g2" ) && ( (fnl_ctrl_plane_bonding_consumption == "individual") || (fnl_ctrl_plane_bonding_consumption == "bundled_master")) ) ? ("en_asn_g2_freq_scal") : "dis_asn_g2";
	localparam rbc_any_auto_speed_nego_gen2 = ( (fnl_prot_mode == "pipe_g2" ) && ( (fnl_ctrl_plane_bonding_consumption == "individual") || (fnl_ctrl_plane_bonding_consumption == "bundled_master")) ) ? ("en_asn_g2_freq_scal") : "dis_asn_g2";
	localparam fnl_auto_speed_nego_gen2 = (auto_speed_nego_gen2 == "<auto_any>" || auto_speed_nego_gen2 == "<auto_single>") ? rbc_any_auto_speed_nego_gen2 : auto_speed_nego_gen2;

	// txclk_freerun, RBC-validated
	localparam rbc_all_txclk_freerun = "en_freerun_tx";
	localparam rbc_any_txclk_freerun = "en_freerun_tx";
	localparam fnl_txclk_freerun = (txclk_freerun == "<auto_any>" || txclk_freerun == "<auto_single>") ? rbc_any_txclk_freerun : txclk_freerun;

	// pcfifo_urst, RBC-validated
	localparam rbc_all_pcfifo_urst = "dis_pcfifourst";
	localparam rbc_any_pcfifo_urst = "dis_pcfifourst";
	localparam fnl_pcfifo_urst = (pcfifo_urst == "<auto_any>" || pcfifo_urst == "<auto_single>") ? rbc_any_pcfifo_urst : pcfifo_urst;

	// txpcs_urst, RBC-validated
	localparam rbc_all_txpcs_urst = "en_txpcs_urst";
	localparam rbc_any_txpcs_urst = "en_txpcs_urst";
	localparam fnl_txpcs_urst = (txpcs_urst == "<auto_any>" || txpcs_urst == "<auto_single>") ? rbc_any_txpcs_urst : txpcs_urst;

	// Validate input parameters against known values or RBC values
	initial begin
		//$display("prot_mode = orig: '%s', any:'%s', all:'%s', final: '%s'", prot_mode, rbc_any_prot_mode, rbc_all_prot_mode, fnl_prot_mode);
		if (!is_in_legal_set(prot_mode, rbc_all_prot_mode)) begin
			$display("Critical Warning: parameter 'prot_mode' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", prot_mode, rbc_all_prot_mode, fnl_prot_mode);
		end
		//$display("sup_mode = orig: '%s', any:'%s', all:'%s', final: '%s'", sup_mode, rbc_any_sup_mode, rbc_all_sup_mode, fnl_sup_mode);
		if (!is_in_legal_set(sup_mode, rbc_all_sup_mode)) begin
			$display("Critical Warning: parameter 'sup_mode' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", sup_mode, rbc_all_sup_mode, fnl_sup_mode);
		end
		//$display("use_default_base_address = orig: '%s', any:'%s', all:'%s', final: '%s'", use_default_base_address, rbc_any_use_default_base_address, rbc_all_use_default_base_address, fnl_use_default_base_address);
		if (!is_in_legal_set(use_default_base_address, rbc_all_use_default_base_address)) begin
			$display("Critical Warning: parameter 'use_default_base_address' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", use_default_base_address, rbc_all_use_default_base_address, fnl_use_default_base_address);
		end
		//$display("test_mode = orig: '%s', any:'%s', all:'%s', final: '%s'", test_mode, rbc_any_test_mode, rbc_all_test_mode, fnl_test_mode);
		if (!is_in_legal_set(test_mode, rbc_all_test_mode)) begin
			$display("Critical Warning: parameter 'test_mode' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", test_mode, rbc_all_test_mode, fnl_test_mode);
		end
		//$display("hip_mode = orig: '%s', any:'%s', all:'%s', final: '%s'", hip_mode, rbc_any_hip_mode, rbc_all_hip_mode, fnl_hip_mode);
		if (!is_in_legal_set(hip_mode, rbc_all_hip_mode)) begin
			$display("Critical Warning: parameter 'hip_mode' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", hip_mode, rbc_all_hip_mode, fnl_hip_mode);
		end
		//$display("pma_dw = orig: '%s', any:'%s', all:'%s', final: '%s'", pma_dw, rbc_any_pma_dw, rbc_all_pma_dw, fnl_pma_dw);
		if (!is_in_legal_set(pma_dw, rbc_all_pma_dw)) begin
			$display("Critical Warning: parameter 'pma_dw' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", pma_dw, rbc_all_pma_dw, fnl_pma_dw);
		end
		//$display("pcs_bypass = orig: '%s', any:'%s', all:'%s', final: '%s'", pcs_bypass, rbc_any_pcs_bypass, rbc_all_pcs_bypass, fnl_pcs_bypass);
		if (!is_in_legal_set(pcs_bypass, rbc_all_pcs_bypass)) begin
			$display("Critical Warning: parameter 'pcs_bypass' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", pcs_bypass, rbc_all_pcs_bypass, fnl_pcs_bypass);
		end
		//$display("phase_compensation_fifo = orig: '%s', any:'%s', all:'%s', final: '%s'", phase_compensation_fifo, rbc_any_phase_compensation_fifo, rbc_all_phase_compensation_fifo, fnl_phase_compensation_fifo);
		if (!is_in_legal_set(phase_compensation_fifo, rbc_all_phase_compensation_fifo)) begin
			$display("Critical Warning: parameter 'phase_compensation_fifo' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", phase_compensation_fifo, rbc_all_phase_compensation_fifo, fnl_phase_compensation_fifo);
		end
		//$display("tx_compliance_controlled_disparity = orig: '%s', any:'%s', all:'%s', final: '%s'", tx_compliance_controlled_disparity, rbc_any_tx_compliance_controlled_disparity, rbc_all_tx_compliance_controlled_disparity, fnl_tx_compliance_controlled_disparity);
		if (!is_in_legal_set(tx_compliance_controlled_disparity, rbc_all_tx_compliance_controlled_disparity)) begin
			$display("Critical Warning: parameter 'tx_compliance_controlled_disparity' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", tx_compliance_controlled_disparity, rbc_all_tx_compliance_controlled_disparity, fnl_tx_compliance_controlled_disparity);
		end
		//$display("force_kchar = orig: '%s', any:'%s', all:'%s', final: '%s'", force_kchar, rbc_any_force_kchar, rbc_all_force_kchar, fnl_force_kchar);
		if (!is_in_legal_set(force_kchar, rbc_all_force_kchar)) begin
			$display("Critical Warning: parameter 'force_kchar' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", force_kchar, rbc_all_force_kchar, fnl_force_kchar);
		end
		//$display("force_echar = orig: '%s', any:'%s', all:'%s', final: '%s'", force_echar, rbc_any_force_echar, rbc_all_force_echar, fnl_force_echar);
		if (!is_in_legal_set(force_echar, rbc_all_force_echar)) begin
			$display("Critical Warning: parameter 'force_echar' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", force_echar, rbc_all_force_echar, fnl_force_echar);
		end
		//$display("byte_serializer = orig: '%s', any:'%s', all:'%s', final: '%s'", byte_serializer, rbc_any_byte_serializer, rbc_all_byte_serializer, fnl_byte_serializer);
		if (!is_in_legal_set(byte_serializer, rbc_all_byte_serializer)) begin
			$display("Critical Warning: parameter 'byte_serializer' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", byte_serializer, rbc_all_byte_serializer, fnl_byte_serializer);
		end
		//$display("data_selection_8b10b_encoder_input = orig: '%s', any:'%s', all:'%s', final: '%s'", data_selection_8b10b_encoder_input, rbc_any_data_selection_8b10b_encoder_input, rbc_all_data_selection_8b10b_encoder_input, fnl_data_selection_8b10b_encoder_input);
		if (!is_in_legal_set(data_selection_8b10b_encoder_input, rbc_all_data_selection_8b10b_encoder_input)) begin
			$display("Critical Warning: parameter 'data_selection_8b10b_encoder_input' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", data_selection_8b10b_encoder_input, rbc_all_data_selection_8b10b_encoder_input, fnl_data_selection_8b10b_encoder_input);
		end
		//$display("eightb_tenb_disp_ctrl = orig: '%s', any:'%s', all:'%s', final: '%s'", eightb_tenb_disp_ctrl, rbc_any_eightb_tenb_disp_ctrl, rbc_all_eightb_tenb_disp_ctrl, fnl_eightb_tenb_disp_ctrl);
		if (!is_in_legal_set(eightb_tenb_disp_ctrl, rbc_all_eightb_tenb_disp_ctrl)) begin
			$display("Critical Warning: parameter 'eightb_tenb_disp_ctrl' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", eightb_tenb_disp_ctrl, rbc_all_eightb_tenb_disp_ctrl, fnl_eightb_tenb_disp_ctrl);
		end
		//$display("eightb_tenb_encoder = orig: '%s', any:'%s', all:'%s', final: '%s'", eightb_tenb_encoder, rbc_any_eightb_tenb_encoder, rbc_all_eightb_tenb_encoder, fnl_eightb_tenb_encoder);
		if (!is_in_legal_set(eightb_tenb_encoder, rbc_all_eightb_tenb_encoder)) begin
			$display("Critical Warning: parameter 'eightb_tenb_encoder' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", eightb_tenb_encoder, rbc_all_eightb_tenb_encoder, fnl_eightb_tenb_encoder);
		end
		//$display("prbs_gen = orig: '%s', any:'%s', all:'%s', final: '%s'", prbs_gen, rbc_any_prbs_gen, rbc_all_prbs_gen, fnl_prbs_gen);
		if (!is_in_legal_set(prbs_gen, rbc_all_prbs_gen)) begin
			$display("Critical Warning: parameter 'prbs_gen' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", prbs_gen, rbc_all_prbs_gen, fnl_prbs_gen);
		end
		//$display("cid_pattern = orig: '%s', any:'%s', all:'%s', final: '%s'", cid_pattern, rbc_any_cid_pattern, rbc_all_cid_pattern, fnl_cid_pattern);
		if (!is_in_legal_set(cid_pattern, rbc_all_cid_pattern)) begin
			$display("Critical Warning: parameter 'cid_pattern' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", cid_pattern, rbc_all_cid_pattern, fnl_cid_pattern);
		end
		//$display("bist_gen = orig: '%s', any:'%s', all:'%s', final: '%s'", bist_gen, rbc_any_bist_gen, rbc_all_bist_gen, fnl_bist_gen);
		if (!is_in_legal_set(bist_gen, rbc_all_bist_gen)) begin
			$display("Critical Warning: parameter 'bist_gen' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", bist_gen, rbc_all_bist_gen, fnl_bist_gen);
		end
		//$display("bit_reversal = orig: '%s', any:'%s', all:'%s', final: '%s'", bit_reversal, rbc_any_bit_reversal, rbc_all_bit_reversal, fnl_bit_reversal);
		if (!is_in_legal_set(bit_reversal, rbc_all_bit_reversal)) begin
			$display("Critical Warning: parameter 'bit_reversal' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", bit_reversal, rbc_all_bit_reversal, fnl_bit_reversal);
		end
		//$display("symbol_swap = orig: '%s', any:'%s', all:'%s', final: '%s'", symbol_swap, rbc_any_symbol_swap, rbc_all_symbol_swap, fnl_symbol_swap);
		if (!is_in_legal_set(symbol_swap, rbc_all_symbol_swap)) begin
			$display("Critical Warning: parameter 'symbol_swap' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", symbol_swap, rbc_all_symbol_swap, fnl_symbol_swap);
		end
		//$display("polarity_inversion = orig: '%s', any:'%s', all:'%s', final: '%s'", polarity_inversion, rbc_any_polarity_inversion, rbc_all_polarity_inversion, fnl_polarity_inversion);
		if (!is_in_legal_set(polarity_inversion, rbc_all_polarity_inversion)) begin
			$display("Critical Warning: parameter 'polarity_inversion' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", polarity_inversion, rbc_all_polarity_inversion, fnl_polarity_inversion);
		end
		//$display("tx_bitslip = orig: '%s', any:'%s', all:'%s', final: '%s'", tx_bitslip, rbc_any_tx_bitslip, rbc_all_tx_bitslip, fnl_tx_bitslip);
		if (!is_in_legal_set(tx_bitslip, rbc_all_tx_bitslip)) begin
			$display("Critical Warning: parameter 'tx_bitslip' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", tx_bitslip, rbc_all_tx_bitslip, fnl_tx_bitslip);
		end
		//$display("ctrl_plane_bonding_consumption = orig: '%s', any:'%s', all:'%s', final: '%s'", ctrl_plane_bonding_consumption, rbc_any_ctrl_plane_bonding_consumption, rbc_all_ctrl_plane_bonding_consumption, fnl_ctrl_plane_bonding_consumption);
		if (!is_in_legal_set(ctrl_plane_bonding_consumption, rbc_all_ctrl_plane_bonding_consumption)) begin
			$display("Critical Warning: parameter 'ctrl_plane_bonding_consumption' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", ctrl_plane_bonding_consumption, rbc_all_ctrl_plane_bonding_consumption, fnl_ctrl_plane_bonding_consumption);
		end
		//$display("agg_block_sel = orig: '%s', any:'%s', all:'%s', final: '%s'", agg_block_sel, rbc_any_agg_block_sel, rbc_all_agg_block_sel, fnl_agg_block_sel);
		if (!is_in_legal_set(agg_block_sel, rbc_all_agg_block_sel)) begin
			$display("Critical Warning: parameter 'agg_block_sel' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", agg_block_sel, rbc_all_agg_block_sel, fnl_agg_block_sel);
		end
		//$display("ctrl_plane_bonding_distribution = orig: '%s', any:'%s', all:'%s', final: '%s'", ctrl_plane_bonding_distribution, rbc_any_ctrl_plane_bonding_distribution, rbc_all_ctrl_plane_bonding_distribution, fnl_ctrl_plane_bonding_distribution);
		if (!is_in_legal_set(ctrl_plane_bonding_distribution, rbc_all_ctrl_plane_bonding_distribution)) begin
			$display("Critical Warning: parameter 'ctrl_plane_bonding_distribution' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", ctrl_plane_bonding_distribution, rbc_all_ctrl_plane_bonding_distribution, fnl_ctrl_plane_bonding_distribution);
		end
		//$display("ctrl_plane_bonding_compensation = orig: '%s', any:'%s', all:'%s', final: '%s'", ctrl_plane_bonding_compensation, rbc_any_ctrl_plane_bonding_compensation, rbc_all_ctrl_plane_bonding_compensation, fnl_ctrl_plane_bonding_compensation);
		if (!is_in_legal_set(ctrl_plane_bonding_compensation, rbc_all_ctrl_plane_bonding_compensation)) begin
			$display("Critical Warning: parameter 'ctrl_plane_bonding_compensation' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", ctrl_plane_bonding_compensation, rbc_all_ctrl_plane_bonding_compensation, fnl_ctrl_plane_bonding_compensation);
		end
		//$display("bypass_pipeline_reg = orig: '%s', any:'%s', all:'%s', final: '%s'", bypass_pipeline_reg, rbc_any_bypass_pipeline_reg, rbc_all_bypass_pipeline_reg, fnl_bypass_pipeline_reg);
		if (!is_in_legal_set(bypass_pipeline_reg, rbc_all_bypass_pipeline_reg)) begin
			$display("Critical Warning: parameter 'bypass_pipeline_reg' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", bypass_pipeline_reg, rbc_all_bypass_pipeline_reg, fnl_bypass_pipeline_reg);
		end
		//$display("clock_gate_bs_enc = orig: '%s', any:'%s', all:'%s', final: '%s'", clock_gate_bs_enc, rbc_any_clock_gate_bs_enc, rbc_all_clock_gate_bs_enc, fnl_clock_gate_bs_enc);
		if (!is_in_legal_set(clock_gate_bs_enc, rbc_all_clock_gate_bs_enc)) begin
			$display("Critical Warning: parameter 'clock_gate_bs_enc' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", clock_gate_bs_enc, rbc_all_clock_gate_bs_enc, fnl_clock_gate_bs_enc);
		end
		//$display("clock_gate_prbs = orig: '%s', any:'%s', all:'%s', final: '%s'", clock_gate_prbs, rbc_any_clock_gate_prbs, rbc_all_clock_gate_prbs, fnl_clock_gate_prbs);
		if (!is_in_legal_set(clock_gate_prbs, rbc_all_clock_gate_prbs)) begin
			$display("Critical Warning: parameter 'clock_gate_prbs' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", clock_gate_prbs, rbc_all_clock_gate_prbs, fnl_clock_gate_prbs);
		end
		//$display("clock_gate_bist = orig: '%s', any:'%s', all:'%s', final: '%s'", clock_gate_bist, rbc_any_clock_gate_bist, rbc_all_clock_gate_bist, fnl_clock_gate_bist);
		if (!is_in_legal_set(clock_gate_bist, rbc_all_clock_gate_bist)) begin
			$display("Critical Warning: parameter 'clock_gate_bist' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", clock_gate_bist, rbc_all_clock_gate_bist, fnl_clock_gate_bist);
		end
		//$display("clock_gate_sw_fifowr = orig: '%s', any:'%s', all:'%s', final: '%s'", clock_gate_sw_fifowr, rbc_any_clock_gate_sw_fifowr, rbc_all_clock_gate_sw_fifowr, fnl_clock_gate_sw_fifowr);
		if (!is_in_legal_set(clock_gate_sw_fifowr, rbc_all_clock_gate_sw_fifowr)) begin
			$display("Critical Warning: parameter 'clock_gate_sw_fifowr' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", clock_gate_sw_fifowr, rbc_all_clock_gate_sw_fifowr, fnl_clock_gate_sw_fifowr);
		end
		//$display("clock_gate_dw_fifowr = orig: '%s', any:'%s', all:'%s', final: '%s'", clock_gate_dw_fifowr, rbc_any_clock_gate_dw_fifowr, rbc_all_clock_gate_dw_fifowr, fnl_clock_gate_dw_fifowr);
		if (!is_in_legal_set(clock_gate_dw_fifowr, rbc_all_clock_gate_dw_fifowr)) begin
			$display("Critical Warning: parameter 'clock_gate_dw_fifowr' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", clock_gate_dw_fifowr, rbc_all_clock_gate_dw_fifowr, fnl_clock_gate_dw_fifowr);
		end
		//$display("clock_gate_fiford = orig: '%s', any:'%s', all:'%s', final: '%s'", clock_gate_fiford, rbc_any_clock_gate_fiford, rbc_all_clock_gate_fiford, fnl_clock_gate_fiford);
		if (!is_in_legal_set(clock_gate_fiford, rbc_all_clock_gate_fiford)) begin
			$display("Critical Warning: parameter 'clock_gate_fiford' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", clock_gate_fiford, rbc_all_clock_gate_fiford, fnl_clock_gate_fiford);
		end
		//$display("revloop_back_rm = orig: '%s', any:'%s', all:'%s', final: '%s'", revloop_back_rm, rbc_any_revloop_back_rm, rbc_all_revloop_back_rm, fnl_revloop_back_rm);
		if (!is_in_legal_set(revloop_back_rm, rbc_all_revloop_back_rm)) begin
			$display("Critical Warning: parameter 'revloop_back_rm' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", revloop_back_rm, rbc_all_revloop_back_rm, fnl_revloop_back_rm);
		end
		//$display("phfifo_write_clk_sel = orig: '%s', any:'%s', all:'%s', final: '%s'", phfifo_write_clk_sel, rbc_any_phfifo_write_clk_sel, rbc_all_phfifo_write_clk_sel, fnl_phfifo_write_clk_sel);
		if (!is_in_legal_set(phfifo_write_clk_sel, rbc_all_phfifo_write_clk_sel)) begin
			$display("Critical Warning: parameter 'phfifo_write_clk_sel' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", phfifo_write_clk_sel, rbc_all_phfifo_write_clk_sel, fnl_phfifo_write_clk_sel);
		end
		//$display("refclk_b_clk_sel = orig: '%s', any:'%s', all:'%s', final: '%s'", refclk_b_clk_sel, rbc_any_refclk_b_clk_sel, rbc_all_refclk_b_clk_sel, fnl_refclk_b_clk_sel);
		if (!is_in_legal_set(refclk_b_clk_sel, rbc_all_refclk_b_clk_sel)) begin
			$display("Critical Warning: parameter 'refclk_b_clk_sel' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", refclk_b_clk_sel, rbc_all_refclk_b_clk_sel, fnl_refclk_b_clk_sel);
		end
		//$display("dynamic_clk_switch = orig: '%s', any:'%s', all:'%s', final: '%s'", dynamic_clk_switch, rbc_any_dynamic_clk_switch, rbc_all_dynamic_clk_switch, fnl_dynamic_clk_switch);
		if (!is_in_legal_set(dynamic_clk_switch, rbc_all_dynamic_clk_switch)) begin
			$display("Critical Warning: parameter 'dynamic_clk_switch' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", dynamic_clk_switch, rbc_all_dynamic_clk_switch, fnl_dynamic_clk_switch);
		end
		//$display("auto_speed_nego_gen2 = orig: '%s', any:'%s', all:'%s', final: '%s'", auto_speed_nego_gen2, rbc_any_auto_speed_nego_gen2, rbc_all_auto_speed_nego_gen2, fnl_auto_speed_nego_gen2);
		if (!is_in_legal_set(auto_speed_nego_gen2, rbc_all_auto_speed_nego_gen2)) begin
			$display("Critical Warning: parameter 'auto_speed_nego_gen2' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", auto_speed_nego_gen2, rbc_all_auto_speed_nego_gen2, fnl_auto_speed_nego_gen2);
		end
		//$display("txclk_freerun = orig: '%s', any:'%s', all:'%s', final: '%s'", txclk_freerun, rbc_any_txclk_freerun, rbc_all_txclk_freerun, fnl_txclk_freerun);
		if (!is_in_legal_set(txclk_freerun, rbc_all_txclk_freerun)) begin
			$display("Critical Warning: parameter 'txclk_freerun' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", txclk_freerun, rbc_all_txclk_freerun, fnl_txclk_freerun);
		end
		//$display("pcfifo_urst = orig: '%s', any:'%s', all:'%s', final: '%s'", pcfifo_urst, rbc_any_pcfifo_urst, rbc_all_pcfifo_urst, fnl_pcfifo_urst);
		if (!is_in_legal_set(pcfifo_urst, rbc_all_pcfifo_urst)) begin
			$display("Critical Warning: parameter 'pcfifo_urst' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", pcfifo_urst, rbc_all_pcfifo_urst, fnl_pcfifo_urst);
		end
		//$display("txpcs_urst = orig: '%s', any:'%s', all:'%s', final: '%s'", txpcs_urst, rbc_any_txpcs_urst, rbc_all_txpcs_urst, fnl_txpcs_urst);
		if (!is_in_legal_set(txpcs_urst, rbc_all_txpcs_urst)) begin
			$display("Critical Warning: parameter 'txpcs_urst' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", txpcs_urst, rbc_all_txpcs_urst, fnl_txpcs_urst);
		end
	end

	arriav_hssi_8g_tx_pcs #(
		.prot_mode(fnl_prot_mode),
		.sup_mode(fnl_sup_mode),
		.avmm_group_channel_index(avmm_group_channel_index),
		.channel_number(channel_number),
		.cid_pattern_len(cid_pattern_len),
		.use_default_base_address(fnl_use_default_base_address),
		.user_base_address(user_base_address),
		.test_mode(fnl_test_mode),
		.hip_mode(fnl_hip_mode),
		.pma_dw(fnl_pma_dw),
		.pcs_bypass(fnl_pcs_bypass),
		.phase_compensation_fifo(fnl_phase_compensation_fifo),
		.tx_compliance_controlled_disparity(fnl_tx_compliance_controlled_disparity),
		.force_kchar(fnl_force_kchar),
		.force_echar(fnl_force_echar),
		.byte_serializer(fnl_byte_serializer),
		.data_selection_8b10b_encoder_input(fnl_data_selection_8b10b_encoder_input),
		.eightb_tenb_disp_ctrl(fnl_eightb_tenb_disp_ctrl),
		.eightb_tenb_encoder(fnl_eightb_tenb_encoder),
		.prbs_gen(fnl_prbs_gen),
		.cid_pattern(fnl_cid_pattern),
		.bist_gen(fnl_bist_gen),
		.bit_reversal(fnl_bit_reversal),
		.symbol_swap(fnl_symbol_swap),
		.polarity_inversion(fnl_polarity_inversion),
		.tx_bitslip(fnl_tx_bitslip),
		.ctrl_plane_bonding_consumption(fnl_ctrl_plane_bonding_consumption),
		.agg_block_sel(fnl_agg_block_sel),
		.ctrl_plane_bonding_distribution(fnl_ctrl_plane_bonding_distribution),
		.ctrl_plane_bonding_compensation(fnl_ctrl_plane_bonding_compensation),
		.bypass_pipeline_reg(fnl_bypass_pipeline_reg),
		.clock_gate_bs_enc(fnl_clock_gate_bs_enc),
		.clock_gate_prbs(fnl_clock_gate_prbs),
		.clock_gate_bist(fnl_clock_gate_bist),
		.clock_gate_sw_fifowr(fnl_clock_gate_sw_fifowr),
		.clock_gate_dw_fifowr(fnl_clock_gate_dw_fifowr),
		.clock_gate_fiford(fnl_clock_gate_fiford),
		.revloop_back_rm(fnl_revloop_back_rm),
		.phfifo_write_clk_sel(fnl_phfifo_write_clk_sel),
		.refclk_b_clk_sel(fnl_refclk_b_clk_sel),
		.dynamic_clk_switch(fnl_dynamic_clk_switch),
		.auto_speed_nego_gen2(fnl_auto_speed_nego_gen2),
		.txclk_freerun(fnl_txclk_freerun),
		.pcfifo_urst(fnl_pcfifo_urst),
		.txpcs_urst(fnl_txpcs_urst)
	) wys (
		// ports
		.aggtxpcsrst(aggtxpcsrst),
		.avmmaddress(avmmaddress),
		.avmmbyteen(avmmbyteen),
		.avmmclk(avmmclk),
		.avmmread(avmmread),
		.avmmreaddata(avmmreaddata),
		.avmmrstn(avmmrstn),
		.avmmwrite(avmmwrite),
		.avmmwritedata(avmmwritedata),
		.bitslipboundaryselect(bitslipboundaryselect),
		.blockselect(blockselect),
		.clkout(clkout),
		.coreclk(coreclk),
		.datain(datain),
		.dataout(dataout),
		.detectrxloopin(detectrxloopin),
		.detectrxloopout(detectrxloopout),
		.dispcbyte(dispcbyte),
		.dynclkswitchn(dynclkswitchn),
		.elecidleinfersel(elecidleinfersel),
		.enrevparallellpbk(enrevparallellpbk),
		.fifoselectinchnldown(fifoselectinchnldown),
		.fifoselectinchnlup(fifoselectinchnlup),
		.fifoselectoutchnldown(fifoselectoutchnldown),
		.fifoselectoutchnlup(fifoselectoutchnlup),
		.grayelecidleinferselout(grayelecidleinferselout),
		.hrdrst(hrdrst),
		.invpol(invpol),
		.observablebyteserdesclock(observablebyteserdesclock),
		.parallelfdbkout(parallelfdbkout),
		.phfifooverflow(phfifooverflow),
		.phfiforddisable(phfiforddisable),
		.phfiforeset(phfiforeset),
		.phfifotxdeemph(phfifotxdeemph),
		.phfifotxmargin(phfifotxmargin),
		.phfifotxswing(phfifotxswing),
		.phfifounderflow(phfifounderflow),
		.phfifowrenable(phfifowrenable),
		.pipeenrevparallellpbkin(pipeenrevparallellpbkin),
		.pipeenrevparallellpbkout(pipeenrevparallellpbkout),
		.pipepowerdownout(pipepowerdownout),
		.pipetxdeemph(pipetxdeemph),
		.pipetxmargin(pipetxmargin),
		.pipetxswing(pipetxswing),
		.polinvrxin(polinvrxin),
		.polinvrxout(polinvrxout),
		.powerdn(powerdn),
		.prbscidenable(prbscidenable),
		.rateswitch(rateswitch),
		.rdenableinchnldown(rdenableinchnldown),
		.rdenableinchnlup(rdenableinchnlup),
		.rdenableoutchnldown(rdenableoutchnldown),
		.rdenableoutchnlup(rdenableoutchnlup),
		.rdenablesync(rdenablesync),
		.refclkb(refclkb),
		.refclkbreset(refclkbreset),
		.refclkdig(refclkdig),
		.resetpcptrs(resetpcptrs),
		.resetpcptrsinchnldown(resetpcptrsinchnldown),
		.resetpcptrsinchnlup(resetpcptrsinchnlup),
		.revparallellpbkdata(revparallellpbkdata),
		.rxpolarityin(rxpolarityin),
		.rxpolarityout(rxpolarityout),
		.scanmode(scanmode),
		.syncdatain(syncdatain),
		.txblkstart(txblkstart),
		.txblkstartout(txblkstartout),
		.txcomplianceout(txcomplianceout),
		.txctrlplanetestbus(txctrlplanetestbus),
		.txdatakouttogen3(txdatakouttogen3),
		.txdataouttogen3(txdataouttogen3),
		.txdatavalid(txdatavalid),
		.txdatavalidouttogen3(txdatavalidouttogen3),
		.txdivsync(txdivsync),
		.txdivsyncinchnldown(txdivsyncinchnldown),
		.txdivsyncinchnlup(txdivsyncinchnlup),
		.txdivsyncoutchnldown(txdivsyncoutchnldown),
		.txdivsyncoutchnlup(txdivsyncoutchnlup),
		.txelecidleout(txelecidleout),
		.txpcsreset(txpcsreset),
		.txpipeclk(txpipeclk),
		.txpipeelectidle(txpipeelectidle),
		.txpipesoftreset(txpipesoftreset),
		.txpmalocalclk(txpmalocalclk),
		.txsynchdr(txsynchdr),
		.txsynchdrout(txsynchdrout),
		.txtestbus(txtestbus),
		.wrenableinchnldown(wrenableinchnldown),
		.wrenableinchnlup(wrenableinchnlup),
		.wrenableoutchnldown(wrenableoutchnldown),
		.wrenableoutchnlup(wrenableoutchnlup),
		.xgmctrl(xgmctrl),
		.xgmctrlenable(xgmctrlenable),
		.xgmctrltoporbottom(xgmctrltoporbottom),
		.xgmdatain(xgmdatain),
		.xgmdataintoporbottom(xgmdataintoporbottom),
		.xgmdataout(xgmdataout)
	);
endmodule
