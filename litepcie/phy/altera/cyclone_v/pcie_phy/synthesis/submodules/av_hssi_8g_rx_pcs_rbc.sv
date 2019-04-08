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


// Verilog RBC parameter resolution wrapper for arriav_hssi_8g_rx_pcs
//

`timescale 1 ns / 1 ps

module av_hssi_8g_rx_pcs_rbc #(
	// unconstrained parameters
	parameter prot_mode = "<auto_single>",	// basic, cpri, cpri_rx_tx, disabled_prot_mode, gige, pipe_g1, pipe_g2, srio_2p1, test, xaui
	parameter sup_mode = "<auto_single>",	// engineering_mode, user_mode

	// extra unconstrained parameters found in atom map
	parameter avmm_group_channel_index = 0,	// 0..2
	parameter bo_pad = 10'b0,	// 10
	parameter bo_pattern = 20'b0,	// 20
	parameter channel_number = 0,	// 0..65
	parameter cid_pattern_len = 8'b0,	// 8
	parameter clkcmp_pattern_n = 20'b0,	// 20
	parameter clkcmp_pattern_p = 20'b0,	// 20
	parameter deskew_pattern = 10'b1101101000,	// 10
	parameter fixed_pat_num = 4'b1111,	// 4
	parameter mask_cnt = 10'h3ff,	// 10
	parameter pma_done_count = 18'b0,	// 18
	parameter runlength_val = 6'b0,	// 6
	parameter use_default_base_address = "true",	// false, true
	parameter user_base_address = 0,	// 0..2047
	parameter wa_clk_slip_spacing_data = 10'b10000,	// 10
	parameter wa_pd_data = 40'b0,	// 40
	parameter wa_renumber_data = 6'b0,	// 6
	parameter wa_rgnumber_data = 8'b0,	// 8
	parameter wa_rknumber_data = 8'b0,	// 8
	parameter wa_rosnumber_data = 2'b0,	// 2
	parameter wa_rvnumber_data = 13'b0,	// 13
	parameter wait_cnt = 8'b0,	// 8

	// constrained parameters
	parameter test_mode = "<auto_single>",	// bist, dont_care_test, prbs
	parameter hip_mode = "<auto_single>",	// dis_hip, en_hip
	parameter pcs_bypass = "<auto_single>",	// dis_pcs_bypass, en_pcs_bypass
	parameter pma_dw = "<auto_single>",	// eight_bit, sixteen_bit, ten_bit, twenty_bit
	parameter pipe_if_enable = "<auto_single>",	// dis_pipe_rx, en_pipe_rx
	parameter prbs_ver = "<auto_single>",	// dis_prbs, prbs_10, prbs_15, prbs_23_dw, prbs_23_sw, prbs_31, prbs_7_dw, prbs_7_sw, prbs_8, prbs_hf_dw, prbs_hf_sw, prbs_lf_dw, prbs_lf_sw, prbs_mf_dw, prbs_mf_sw
	parameter wa_boundary_lock_ctrl = "<auto_single>",	// auto_align_pld_ctrl, bit_slip, deterministic_latency, sync_sm
	parameter wa_pld_controlled = "<auto_single>",	// dis_pld_ctrl, level_sensitive_dw, pld_ctrl_sw, rising_edge_sensitive_dw
	parameter wa_pd_polarity = "<auto_single>",	// dis_pd_both_pol, dont_care_both_pol, en_pd_both_pol
	parameter wa_pd = "<auto_single>",	// dont_care_wa_pd_0, dont_care_wa_pd_1, prbs10_fixed_wa, prbs15_fixed_wa_pd_16_dw, prbs15_fixed_wa_pd_16_sw, prbs15_fixed_wa_pd_20_dw, prbs23_fixed_wa_pd_16_sw, prbs23_fixed_wa_pd_32_dw, prbs23_fixed_wa_pd_40_dw, prbs31_fixed_wa_pd_10_sw, prbs31_fixed_wa_pd_16_dw, prbs31_fixed_wa_pd_16_sw, prbs31_fixed_wa_pd_40_dw, prbs7_fixed_wa_pd_16_dw, prbs7_fixed_wa_pd_16_sw, prbs7_fixed_wa_pd_20_dw, prbs8_fixed_wa, wa_pd_10, wa_pd_16_dw, wa_pd_16_sw, wa_pd_20, wa_pd_32, wa_pd_40, wa_pd_7, wa_pd_8_dw, wa_pd_8_sw, wa_pd_fixed_10_k28p5, wa_pd_fixed_16_a1a2_dw, wa_pd_fixed_16_a1a2_sw, wa_pd_fixed_32_a1a1a2a2, wa_pd_fixed_7_k28p5
	parameter wa_sync_sm_ctrl = "<auto_single>",	// dw_basic_sync_sm, fibre_channel_sync_sm, gige_sync_sm, pipe_sync_sm, srio1p3_sync_sm, srio2p1_sync_sm, sw_basic_sync_sm, xaui_sync_sm
	parameter wa_kchar = "<auto_single>",	// dis_kchar, en_kchar
	parameter fixed_pat_det = "<auto_single>",	// dis_fixed_patdet, en_fixed_patdet
	parameter ibm_invalid_code = "<auto_single>",	// dis_ibm_invalid_code, en_ibm_invalid_code
	parameter force_signal_detect = "<auto_single>",	// dis_force_signal_detect, en_force_signal_detect
	parameter wa_det_latency_sync_status_beh = "<auto_single>",	// assert_sync_status_imm, assert_sync_status_non_imm, dont_care_assert_sync
	parameter wa_clk_slip_spacing = "<auto_single>",	// min_clk_slip_spacing, user_programmable_clk_slip_spacing
	parameter eightb_tenb_decoder = "<auto_single>",	// dis_8b10b, en_8b10b_ibm, en_8b10b_sgx
	parameter wa_disp_err_flag = "<auto_single>",	// dis_disp_err_flag, en_disp_err_flag
	parameter polarity_inversion = "<auto_single>",	// dis_pol_inv, en_pol_inv
	parameter bit_reversal = "<auto_single>",	// dis_bit_reversal, en_bit_reversal
	parameter symbol_swap = "<auto_single>",	// dis_symbol_swap, en_symbol_swap
	parameter runlength_check = "<auto_single>",	// dis_runlength, en_runlength_dw, en_runlength_sw
	parameter ctrl_plane_bonding_consumption = "<auto_single>",	// bundled_master, bundled_slave_above, bundled_slave_below, individual
	parameter deskew = "<auto_single>",	// dis_deskew, en_srio_v2p1, en_xaui
	parameter deskew_prog_pattern_only = "<auto_single>",	// dis_deskew_prog_pat_only, en_deskew_prog_pat_only
	parameter rate_match = "<auto_single>",	// dis_rm, dw_basic_rm, gige_rm, pipe_rm, pipe_rm_0ppm, srio_v2p1_rm, srio_v2p1_rm_0ppm, sw_basic_rm, xaui_rm
	parameter err_flags_sel = "<auto_single>",	// err_flags_8b10b, err_flags_wa
	parameter polinv_8b10b_dec = "<auto_single>",	// dis_polinv_8b10b_dec, en_polinv_8b10b_dec
	parameter eightbtenb_decoder_output_sel = "<auto_single>",	// data_8b10b_decoder, data_xaui_sm
	parameter invalid_code_flag_only = "<auto_single>",	// dis_invalid_code_only, en_invalid_code_only
	parameter auto_error_replacement = "<auto_single>",	// dis_err_replace, en_err_replace
	parameter pad_or_edb_error_replace = "<auto_single>",	// replace_edb, replace_edb_dynamic, replace_pad
	parameter byte_deserializer = "<auto_single>",	// dis_bds, en_bds_by_2, en_bds_by_2_det
	parameter byte_order = "<auto_single>",	// dis_bo, en_pcs_ctrl_eight_bit_bo, en_pcs_ctrl_nine_bit_bo, en_pcs_ctrl_ten_bit_bo, en_pld_ctrl_eight_bit_bo, en_pld_ctrl_nine_bit_bo, en_pld_ctrl_ten_bit_bo
	parameter dw_one_or_two_symbol_bo = "<auto_single>",	// donot_care_one_two_bo, one_symbol_bo, two_symbol_bo_eight_bit, two_symbol_bo_nine_bit, two_symbol_bo_ten_bit
	parameter re_bo_on_wa = "<auto_single>",	// dis_re_bo_on_wa, en_re_bo_on_wa
	parameter phase_compensation_fifo = "<auto_single>",	// low_latency, normal_latency, pld_ctrl_low_latency, pld_ctrl_normal_latency, register_fifo
	parameter tx_rx_parallel_loopback = "<auto_single>",	// dis_plpbk, en_plpbk
	parameter prbs_ver_clr_flag = "<auto_single>",	// dis_prbs_clr_flag, en_prbs_clr_flag
	parameter cid_pattern = "<auto_single>",	// cid_pattern_0, cid_pattern_1
	parameter bist_ver = "<auto_single>",	// cjpat, crpat, dis_bist, incremental
	parameter bist_ver_clr_flag = "<auto_single>",	// dis_bist_clr_flag, en_bist_clr_flag
	parameter cdr_ctrl = "<auto_single>",	// dis_cdr_ctrl, en_cdr_ctrl, en_cdr_ctrl_w_cid
	parameter cdr_ctrl_rxvalid_mask = "<auto_single>",	// dis_rxvalid_mask, en_rxvalid_mask
	parameter auto_speed_nego = "<auto_single>",	// dis_asn, en_asn_g2_freq_scal
	parameter eidle_entry_iei = "<auto_single>",	// dis_eidle_iei, en_eidle_iei
	parameter eidle_entry_sd = "<auto_single>",	// dis_eidle_sd, en_eidle_sd
	parameter eidle_entry_eios = "<auto_single>",	// dis_eidle_eios, en_eidle_eios
	parameter ctrl_plane_bonding_distribution = "<auto_single>",	// master_chnl_distr, not_master_chnl_distr
	parameter ctrl_plane_bonding_compensation = "<auto_single>",	// dis_compensation, en_compensation
	parameter bypass_pipeline_reg = "<auto_single>",	// dis_bypass_pipeline, en_bypass_pipeline
	parameter rx_refclk = "<auto_single>",	// dis_refclk_sel, en_refclk_sel
	parameter rx_rcvd_clk = "<auto_single>",	// rcvd_clk_rcvd_clk, tx_pma_clock_rcvd_clk
	parameter agg_block_sel = "<auto_single>",	// other_smrt_pack, same_smrt_pack
	parameter rx_clk1 = "<auto_single>",	// rcvd_clk_agg_clk1, rcvd_clk_agg_top_or_bottom_clk1, rcvd_clk_clk1, tx_pma_clock_clk1
	parameter rx_clk2 = "<auto_single>",	// rcvd_clk_clk2, refclk_dig2_clk2, tx_pma_clock_clk2
	parameter rx_wr_clk = "<auto_single>",	// rx_clk2_div_1_2_4, txfifo_rd_clk
	parameter rx_rd_clk = "<auto_single>",	// pld_rx_clk, rx_clk
	parameter clock_gate_bist = "<auto_single>",	// dis_bist_clk_gating, en_bist_clk_gating
	parameter clock_gate_sw_wa = "<auto_single>",	// dis_sw_wa_clk_gating, en_sw_wa_clk_gating
	parameter clock_gate_dw_wa = "<auto_single>",	// dis_dw_wa_clk_gating, en_dw_wa_clk_gating
	parameter clock_gate_sw_dskw_wr = "<auto_single>",	// dis_sw_dskw_wrclk_gating, en_sw_dskw_wrclk_gating
	parameter clock_gate_dw_dskw_wr = "<auto_single>",	// dis_dw_dskw_wrclk_gating, en_dw_dskw_wrclk_gating
	parameter clock_gate_prbs = "<auto_single>",	// dis_prbs_clk_gating, en_prbs_clk_gating
	parameter clock_gate_cdr_eidle = "<auto_single>",	// dis_cdr_eidle_clk_gating, en_cdr_eidle_clk_gating
	parameter clock_gate_dskw_rd = "<auto_single>",	// dis_dskw_rdclk_gating, en_dskw_rdclk_gating
	parameter clock_gate_sw_rm_wr = "<auto_single>",	// dis_sw_rm_wrclk_gating, en_sw_rm_wrclk_gating
	parameter clock_gate_sw_rm_rd = "<auto_single>",	// dis_sw_rm_rdclk_gating, en_sw_rm_rdclk_gating
	parameter clock_gate_dw_rm_rd = "<auto_single>",	// dis_dw_rm_rdclk_gating, en_dw_rm_rdclk_gating
	parameter clock_gate_dw_rm_wr = "<auto_single>",	// dis_dw_rm_wrclk_gating, en_dw_rm_wrclk_gating
	parameter clock_gate_bds_dec_asn = "<auto_single>",	// dis_bds_dec_asn_clk_gating, en_bds_dec_asn_clk_gating
	parameter clock_gate_byteorder = "<auto_single>",	// dis_byteorder_clk_gating, en_byteorder_clk_gating
	parameter clock_gate_sw_pc_wrclk = "<auto_single>",	// dis_sw_pc_wrclk_gating, en_sw_pc_wrclk_gating
	parameter clock_gate_dw_pc_wrclk = "<auto_single>",	// dis_dw_pc_wrclk_gating, en_dw_pc_wrclk_gating
	parameter clock_gate_pc_rdclk = "<auto_single>",	// dis_pc_rdclk_gating, en_pc_rdclk_gating
	parameter rx_pcs_urst = "<auto_single>",	// dis_rx_pcs_urst, en_rx_pcs_urst
	parameter rx_clk_free_running = "<auto_single>",	// dis_rx_clk_free_run, en_rx_clk_free_run
	parameter comp_fifo_rst_pld_ctrl = "<auto_single>",	// dis_comp_fifo_rst_pld_ctrl, en_comp_fifo_rst_pld_ctrl
	parameter pc_fifo_rst_pld_ctrl = "<auto_single>",	// dis_pc_fifo_rst_pld_ctrl, en_pc_fifo_rst_pld_ctrl
	parameter test_bus_sel = "<auto_single>"	// agg_testbus, deskew_testbus, pcie_ctrl_testbus, prbs_bist_testbus, rm_testbus, rx_ctrl_plane_testbus, rx_ctrl_testbus, tx_ctrl_plane_testbus, tx_testbus, wa_testbus
) (
	// ports
	output wire    [3:0]	a1a2k1k2flag,
	input  wire         	a1a2size,
	output wire         	aggrxpcsrst,
	input  wire   [15:0]	aggtestbus,
	output wire    [1:0]	aligndetsync,
	input  wire         	alignstatus,
	output wire         	alignstatuspld,
	output wire         	alignstatussync,
	input  wire         	alignstatussync0,
	input  wire         	alignstatussync0toporbot,
	input  wire         	alignstatustoporbot,
	input  wire   [10:0]	avmmaddress,
	input  wire    [1:0]	avmmbyteen,
	input  wire         	avmmclk,
	input  wire         	avmmread,
	output wire   [15:0]	avmmreaddata,
	input  wire         	avmmrstn,
	input  wire         	avmmwrite,
	input  wire   [15:0]	avmmwritedata,
	output wire         	bistdone,
	output wire         	bisterr,
	input  wire         	bitreversalenable,
	input  wire         	bitslip,
	output wire         	blockselect,
	input  wire         	byteorder,
	output wire         	byteordflag,
	input  wire         	bytereversalenable,
	input  wire         	cgcomprddall,
	input  wire         	cgcomprddalltoporbot,
	output wire    [1:0]	cgcomprddout,
	input  wire         	cgcompwrall,
	input  wire         	cgcompwralltoporbot,
	output wire    [1:0]	cgcompwrout,
	output wire   [19:0]	channeltestbusout,
	output wire         	clocktopld,
	input  wire         	configselinchnldown,
	input  wire         	configselinchnlup,
	output wire         	configseloutchnldown,
	output wire         	configseloutchnlup,
	input  wire         	ctrlfromaggblock,
	input  wire    [7:0]	datafrinaggblock,
	input  wire   [19:0]	datain,
	output wire   [63:0]	dataout,
	output wire         	decoderctrl,
	output wire    [7:0]	decoderdata,
	output wire         	decoderdatavalid,
	input  wire         	delcondmet0,
	input  wire         	delcondmet0toporbot,
	output wire         	delcondmetout,
	output wire         	disablepcfifobyteserdes,
	input  wire         	dynclkswitchn,
	output wire         	earlyeios,
	output wire         	eidledetected,
	output wire         	eidleexit,
	input  wire    [2:0]	eidleinfersel,
	input  wire         	enablecommadetect,
	input  wire         	endskwqd,
	input  wire         	endskwqdtoporbot,
	input  wire         	endskwrdptrs,
	input  wire         	endskwrdptrstoporbot,
	output wire    [1:0]	errctrl,
	output wire   [15:0]	errdata,
	input  wire         	fifoovr0,
	input  wire         	fifoovr0toporbot,
	output wire         	fifoovrout,
	input  wire         	fifordincomp0toporbot,
	output wire         	fifordoutcomp,
	input  wire         	fiforstrdqd,
	input  wire         	fiforstrdqdtoporbot,
	input  wire         	gen2ngen1,
	input  wire         	hrdrst,
	input  wire         	insertincomplete0,
	input  wire         	insertincomplete0toporbot,
	output wire         	insertincompleteout,
	input  wire         	latencycomp0,
	input  wire         	latencycomp0toporbot,
	output wire         	latencycompout,
	output wire         	ltr,
	output wire         	observablebyteserdesclock,
	input  wire   [19:0]	parallelloopback,
	output wire   [19:0]	parallelrevloopback,
	output wire         	pcfifoempty,
	output wire         	pcfifofull,
	input  wire         	pcfifordenable,
	output wire         	pcieswitch,
	input  wire         	phfifouserrst,
	output wire         	phystatus,
	input  wire         	phystatusinternal,
	input  wire         	phystatuspcsgen3,
	output wire   [63:0]	pipedata,
	input  wire         	pipeloopbk,
	input  wire         	pldltr,
	input  wire         	pldrxclk,
	input  wire         	polinvrx,
	input  wire         	prbscidenable,
	output wire         	prbsdone,
	output wire         	prbserrlt,
	input  wire         	pxfifowrdisable,
	input  wire         	rateswitchcontrol,
	input  wire         	rcvdclkagg,
	input  wire         	rcvdclkaggtoporbot,
	input  wire         	rcvdclkpma,
	output wire    [1:0]	rdalign,
	input  wire         	rdenableinchnldown,
	input  wire         	rdenableinchnlup,
	output wire         	rdenableoutchnldown,
	output wire         	rdenableoutchnlup,
	input  wire         	refclkdig,
	input  wire         	refclkdig2,
	output wire         	resetpcptrs,
	input  wire         	resetpcptrsinchnldown,
	output wire         	resetpcptrsinchnldownpipe,
	input  wire         	resetpcptrsinchnlup,
	output wire         	resetpcptrsinchnluppipe,
	output wire         	resetpcptrsoutchnldown,
	output wire         	resetpcptrsoutchnlup,
	input  wire         	resetppmcntrsinchnldown,
	input  wire         	resetppmcntrsinchnlup,
	output wire         	resetppmcntrsoutchnldown,
	output wire         	resetppmcntrsoutchnlup,
	output wire         	resetppmcntrspcspma,
	output wire         	rlvlt,
	output wire         	rmfifoempty,
	output wire         	rmfifofull,
	output wire         	rmfifopartialempty,
	output wire         	rmfifopartialfull,
	input  wire         	rmfifordincomp0,
	input  wire         	rmfiforeadenable,
	input  wire         	rmfifouserrst,
	input  wire         	rmfifowriteenable,
	output wire         	runlengthviolation,
	output wire    [1:0]	runningdisparity,
	output wire    [3:0]	rxblkstart,
	output wire         	rxclkslip,
	input  wire         	rxcontrolrstoporbot,
	input  wire    [7:0]	rxdatarstoporbot,
	output wire    [3:0]	rxdatavalid,
	input  wire    [1:0]	rxdivsyncinchnldown,
	input  wire    [1:0]	rxdivsyncinchnlup,
	output wire    [1:0]	rxdivsyncoutchnldown,
	output wire    [1:0]	rxdivsyncoutchnlup,
	input  wire         	rxpcsrst,
	output wire         	rxpipeclk,
	output wire         	rxpipesoftreset,
	output wire    [2:0]	rxstatus,
	input  wire    [2:0]	rxstatusinternal,
	output wire    [1:0]	rxsynchdr,
	input  wire    [1:0]	rxsynchdrpcsgen3,
	output wire         	rxvalid,
	input  wire         	rxvalidinternal,
	input  wire    [1:0]	rxweinchnldown,
	input  wire    [1:0]	rxweinchnlup,
	output wire    [1:0]	rxweoutchnldown,
	output wire    [1:0]	rxweoutchnlup,
	input  wire         	scanmode,
	output wire         	selftestdone,
	output wire         	selftesterr,
	input  wire         	sigdetfrompma,
	output wire         	signaldetectout,
	output wire         	speedchange,
	input  wire         	speedchangeinchnldown,
	output wire         	speedchangeinchnldownpipe,
	input  wire         	speedchangeinchnlup,
	output wire         	speedchangeinchnluppipe,
	output wire         	speedchangeoutchnldown,
	output wire         	speedchangeoutchnlup,
	output wire         	syncdatain,
	input  wire         	syncsmen,
	output wire         	syncstatus,
	input  wire   [19:0]	txctrlplanetestbus,
	input  wire    [1:0]	txdivsync,
	input  wire         	txpmaclk,
	input  wire   [19:0]	txtestbus,
	output wire    [4:0]	wordalignboundary,
	input  wire         	wrenableinchnldown,
	input  wire         	wrenableinchnlup,
	output wire         	wrenableoutchnldown,
	output wire         	wrenableoutchnlup
);
	import altera_xcvr_functions::*;

	// prot_mode external parameter (no RBC)
	localparam rbc_all_prot_mode = "(basic,cpri,cpri_rx_tx,disabled_prot_mode,gige,pipe_g1,pipe_g2,srio_2p1,test,xaui)";
	localparam rbc_any_prot_mode = "gige";
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
	localparam rbc_all_test_mode = (fnl_prot_mode == "test") ? ("(prbs,bist)") : "dont_care_test";
	localparam rbc_any_test_mode = (fnl_prot_mode == "test") ? ("prbs") : "dont_care_test";
	localparam fnl_test_mode = (test_mode == "<auto_any>" || test_mode == "<auto_single>") ? rbc_any_test_mode : test_mode;

	// hip_mode, RBC-validated
	localparam rbc_all_hip_mode = (fnl_prot_mode == "pipe_g1" || fnl_prot_mode == "pipe_g2" ) ? ("(dis_hip,en_hip)") : "dis_hip";
	localparam rbc_any_hip_mode = (fnl_prot_mode == "pipe_g1" || fnl_prot_mode == "pipe_g2" ) ? ("dis_hip") : "dis_hip";
	localparam fnl_hip_mode = (hip_mode == "<auto_any>" || hip_mode == "<auto_single>") ? rbc_any_hip_mode : hip_mode;

	// pcs_bypass, RBC-validated
	localparam rbc_all_pcs_bypass = ((fnl_prot_mode == "basic" ) || (fnl_prot_mode == "cpri_rx_tx") ) ? ("(dis_pcs_bypass,en_pcs_bypass)") : "dis_pcs_bypass";
	localparam rbc_any_pcs_bypass = ((fnl_prot_mode == "basic" ) || (fnl_prot_mode == "cpri_rx_tx") ) ? ("dis_pcs_bypass") : "dis_pcs_bypass";
	localparam fnl_pcs_bypass = (pcs_bypass == "<auto_any>" || pcs_bypass == "<auto_single>") ? rbc_any_pcs_bypass : pcs_bypass;

	// pma_dw, RBC-validated
	localparam rbc_all_pma_dw = ( fnl_prot_mode == "srio_2p1" ) ? ("twenty_bit")
		 : ( (fnl_prot_mode == "basic") || (fnl_test_mode == "prbs") ) ? ("(eight_bit,ten_bit,sixteen_bit,twenty_bit)")
			 : ( (fnl_test_mode == "bist" ) || ( fnl_prot_mode == "cpri")  ||  (fnl_prot_mode == "cpri_rx_tx")) ? ("(ten_bit,twenty_bit)") : "ten_bit";
	localparam rbc_any_pma_dw = ( fnl_prot_mode == "srio_2p1" ) ? ("twenty_bit")
		 : ( (fnl_prot_mode == "basic") || (fnl_test_mode == "prbs") ) ? ("eight_bit")
			 : ( (fnl_test_mode == "bist" ) || ( fnl_prot_mode == "cpri")  ||  (fnl_prot_mode == "cpri_rx_tx")) ? ("ten_bit") : "ten_bit";
	localparam fnl_pma_dw = (pma_dw == "<auto_any>" || pma_dw == "<auto_single>") ? rbc_any_pma_dw : pma_dw;

	// pipe_if_enable, RBC-validated
	localparam rbc_all_pipe_if_enable = ( (fnl_prot_mode == "pipe_g1" ) || (fnl_prot_mode == "pipe_g2" )) ? ("en_pipe_rx") : "dis_pipe_rx";
	localparam rbc_any_pipe_if_enable = ( (fnl_prot_mode == "pipe_g1" ) || (fnl_prot_mode == "pipe_g2" )) ? ("en_pipe_rx") : "dis_pipe_rx";
	localparam fnl_pipe_if_enable = (pipe_if_enable == "<auto_any>" || pipe_if_enable == "<auto_single>") ? rbc_any_pipe_if_enable : pipe_if_enable;

	// prbs_ver, RBC-validated
	localparam rbc_all_prbs_ver = ( fnl_test_mode == "prbs") ?
		(
			(fnl_pma_dw == "eight_bit") ? ("(prbs_7_sw,prbs_8,prbs_23_sw,prbs_hf_sw,prbs_15,prbs_31)")
			 : (fnl_pma_dw == "ten_bit") ? ("(prbs_10,prbs_hf_sw,prbs_lf_sw,prbs_15,prbs_31)")
				 : (fnl_pma_dw == "sixteen_bit") ? ("(prbs_7_dw,prbs_23_dw,prbs_hf_dw,prbs_15,prbs_31)") : "(prbs_7_dw,prbs_23_dw,prbs_hf_dw,prbs_lf_dw,prbs_15,prbs_31)"
		) : "dis_prbs";
	localparam rbc_any_prbs_ver = ( fnl_test_mode == "prbs") ?
		(
			(fnl_pma_dw == "eight_bit") ? ("prbs_7_sw")
			 : (fnl_pma_dw == "ten_bit") ? ("prbs_10")
				 : (fnl_pma_dw == "sixteen_bit") ? ("prbs_7_dw") : "prbs_7_dw"
		) : "dis_prbs";
	localparam fnl_prbs_ver = (prbs_ver == "<auto_any>" || prbs_ver == "<auto_single>") ? rbc_any_prbs_ver : prbs_ver;

	// wa_boundary_lock_ctrl, RBC-validated
	localparam rbc_all_wa_boundary_lock_ctrl = ((fnl_pcs_bypass == "dis_pcs_bypass") &&  ( fnl_pma_dw == "eight_bit"  || fnl_pma_dw == "sixteen_bit" || fnl_pma_dw == "twenty_bit")   &&  ( fnl_prot_mode == "basic") ) ? ("(bit_slip,auto_align_pld_ctrl)")
		 : ( (fnl_pcs_bypass == "dis_pcs_bypass") &&  ( fnl_prot_mode == "basic") ) ? ("(bit_slip,sync_sm,auto_align_pld_ctrl)")
			 : ( (fnl_pcs_bypass == "en_pcs_bypass") || (fnl_prbs_ver == "prbs_lf_sw" ) || (fnl_prbs_ver == "prbs_hf_sw" ) || (fnl_prbs_ver == "prbs_lf_dw" ) || (fnl_prbs_ver == "prbs_hf_dw" )     ) ? ("bit_slip")
				 : (fnl_prot_mode == "cpri") ? ("deterministic_latency")
					 : ( fnl_prot_mode == "cpri_rx_tx"  || ( fnl_test_mode == "bist"  && fnl_pma_dw == "twenty_bit" ) ||  ( fnl_test_mode == "prbs" )  ) ? ("auto_align_pld_ctrl") : "sync_sm";
	localparam rbc_any_wa_boundary_lock_ctrl = ((fnl_pcs_bypass == "dis_pcs_bypass") &&  ( fnl_pma_dw == "eight_bit"  || fnl_pma_dw == "sixteen_bit" || fnl_pma_dw == "twenty_bit")   &&  ( fnl_prot_mode == "basic") ) ? ("bit_slip")
		 : ( (fnl_pcs_bypass == "dis_pcs_bypass") &&  ( fnl_prot_mode == "basic") ) ? ("bit_slip")
			 : ( (fnl_pcs_bypass == "en_pcs_bypass") || (fnl_prbs_ver == "prbs_lf_sw" ) || (fnl_prbs_ver == "prbs_hf_sw" ) || (fnl_prbs_ver == "prbs_lf_dw" ) || (fnl_prbs_ver == "prbs_hf_dw" )     ) ? ("bit_slip")
				 : (fnl_prot_mode == "cpri") ? ("deterministic_latency")
					 : ( fnl_prot_mode == "cpri_rx_tx"  || ( fnl_test_mode == "bist"  && fnl_pma_dw == "twenty_bit" ) ||  ( fnl_test_mode == "prbs" )  ) ? ("auto_align_pld_ctrl") : "sync_sm";
	localparam fnl_wa_boundary_lock_ctrl = (wa_boundary_lock_ctrl == "<auto_any>" || wa_boundary_lock_ctrl == "<auto_single>") ? rbc_any_wa_boundary_lock_ctrl : wa_boundary_lock_ctrl;

	// wa_pld_controlled, RBC-validated
	localparam rbc_all_wa_pld_controlled = ( fnl_wa_boundary_lock_ctrl == "sync_sm" || fnl_wa_boundary_lock_ctrl == "deterministic_latency"  ) ? ("dis_pld_ctrl")
		 : ( fnl_pma_dw == "eight_bit"  || fnl_pma_dw == "ten_bit") ? ("pld_ctrl_sw") : "rising_edge_sensitive_dw";
	localparam rbc_any_wa_pld_controlled = ( fnl_wa_boundary_lock_ctrl == "sync_sm" || fnl_wa_boundary_lock_ctrl == "deterministic_latency"  ) ? ("dis_pld_ctrl")
		 : ( fnl_pma_dw == "eight_bit"  || fnl_pma_dw == "ten_bit") ? ("pld_ctrl_sw") : "rising_edge_sensitive_dw";
	localparam fnl_wa_pld_controlled = (wa_pld_controlled == "<auto_any>" || wa_pld_controlled == "<auto_single>") ? rbc_any_wa_pld_controlled : wa_pld_controlled;

	// wa_pd_polarity, RBC-validated
	localparam rbc_all_wa_pd_polarity = (  fnl_pma_dw == "eight_bit"  || fnl_pma_dw == "ten_bit" ) ? ("dont_care_both_pol")
		 : ( (fnl_pma_dw == "sixteen_bit")  || (fnl_test_mode == "prbs")      ) ? ("dis_pd_both_pol") : "en_pd_both_pol";
	localparam rbc_any_wa_pd_polarity = (  fnl_pma_dw == "eight_bit"  || fnl_pma_dw == "ten_bit" ) ? ("dont_care_both_pol")
		 : ( (fnl_pma_dw == "sixteen_bit")  || (fnl_test_mode == "prbs")      ) ? ("dis_pd_both_pol") : "en_pd_both_pol";
	localparam fnl_wa_pd_polarity = (wa_pd_polarity == "<auto_any>" || wa_pd_polarity == "<auto_single>") ? rbc_any_wa_pd_polarity : wa_pd_polarity;

	// wa_pd, RBC-validated
	localparam rbc_all_wa_pd = ( fnl_wa_boundary_lock_ctrl != "bit_slip" ) ?
		(
			(fnl_prot_mode == "gige" || fnl_prot_mode == "xaui" || fnl_prot_mode == "srio_2p1" ) ? ("(wa_pd_fixed_7_k28p5,wa_pd_fixed_10_k28p5)")
			 : ( fnl_prot_mode == "basic"  ) ?
				(
					(fnl_pma_dw == "eight_bit") ? ("(wa_pd_8_sw,wa_pd_16_sw,wa_pd_fixed_16_a1a2_sw)")
					 : (fnl_pma_dw == "ten_bit") ? ("(wa_pd_7,wa_pd_10,wa_pd_fixed_7_k28p5,wa_pd_fixed_10_k28p5)")
						 : (fnl_pma_dw == "sixteen_bit") ? ("(wa_pd_8_dw,wa_pd_16_dw,wa_pd_32,wa_pd_fixed_16_a1a2_dw,wa_pd_fixed_32_a1a1a2a2)")
							 : ( fnl_wa_boundary_lock_ctrl != "sync_sm" ) ? ("(wa_pd_7,wa_pd_10,wa_pd_20,wa_pd_40,wa_pd_fixed_7_k28p5,wa_pd_fixed_10_k28p5)") : "(wa_pd_7,wa_pd_10,wa_pd_20,wa_pd_fixed_7_k28p5,wa_pd_fixed_10_k28p5)"
				)
				 : ( fnl_test_mode == "prbs"  ) ?
					(
						( fnl_prbs_ver == "prbs_7_sw" ) ? ("prbs7_fixed_wa_pd_16_sw")
						 : ( (fnl_prbs_ver == "prbs_7_dw") && ( fnl_pma_dw == "sixteen_bit" ) ) ? ("prbs7_fixed_wa_pd_16_dw")
							 : ( (fnl_prbs_ver == "prbs_7_dw") && ( fnl_pma_dw == "twenty_bit" ) ) ? ("prbs7_fixed_wa_pd_20_dw")
								 : ( fnl_prbs_ver == "prbs_23_sw" ) ? ("prbs23_fixed_wa_pd_16_sw")
									 : ( (fnl_prbs_ver == "prbs_23_dw") && ( fnl_pma_dw == "sixteen_bit" ) ) ? ("prbs23_fixed_wa_pd_32_dw")
										 : ( (fnl_prbs_ver == "prbs_23_dw") && ( fnl_pma_dw == "twenty_bit" ) ) ? ("prbs23_fixed_wa_pd_40_dw")
											 : ( (fnl_prbs_ver == "prbs_15" ) &&  ( fnl_pma_dw == "eight_bit" ) ) ? ("prbs15_fixed_wa_pd_16_sw")
												 : ( (fnl_prbs_ver == "prbs_15" ) && ( fnl_pma_dw == "sixteen_bit" ) ) ? ("prbs15_fixed_wa_pd_16_dw")
													 : ( (fnl_prbs_ver == "prbs_15" ) && ( fnl_pma_dw == "twenty_bit" ) ) ? ("prbs15_fixed_wa_pd_20_dw")
														 : ( (fnl_prbs_ver == "prbs_31" ) &&  ( fnl_pma_dw == "eight_bit" ) ) ? ("prbs31_fixed_wa_pd_16_sw")
															 : ( (fnl_prbs_ver == "prbs_31" ) &&  ( fnl_pma_dw == "ten_bit" ) ) ? ("prbs31_fixed_wa_pd_10_sw")
																 : ( (fnl_prbs_ver == "prbs_31" ) &&  ( fnl_pma_dw == "sixteen_bit" ) ) ? ("prbs31_fixed_wa_pd_16_dw")
																	 : ( (fnl_prbs_ver == "prbs_31" ) &&  ( fnl_pma_dw == "twenty_bit" ) ) ? ("prbs31_fixed_wa_pd_40_dw")
																		 : (fnl_prbs_ver == "prbs_8" ) ? ("prbs8_fixed_wa")
																			 : (fnl_prbs_ver == "prbs_10" ) ? ("prbs10_fixed_wa") : "dont_care_wa_pd_0"
					)
					 : ( fnl_test_mode == "bist"  ) ? ("wa_pd_fixed_10_k28p5") : "wa_pd_fixed_10_k28p5"
		)
		 : (fnl_pma_dw == "sixteen_bit") ? ("dont_care_wa_pd_1") : "dont_care_wa_pd_0";
	localparam rbc_any_wa_pd = ( fnl_wa_boundary_lock_ctrl != "bit_slip" ) ?
		(
			(fnl_prot_mode == "gige" || fnl_prot_mode == "xaui" || fnl_prot_mode == "srio_2p1" ) ? ("wa_pd_fixed_7_k28p5")
			 : ( fnl_prot_mode == "basic"  ) ?
				(
					(fnl_pma_dw == "eight_bit") ? ("wa_pd_8_sw")
					 : (fnl_pma_dw == "ten_bit") ? ("wa_pd_10")
						 : (fnl_pma_dw == "sixteen_bit") ? ("wa_pd_8_dw")
							 : ( fnl_wa_boundary_lock_ctrl != "sync_sm" ) ? ("wa_pd_10") : "wa_pd_10"
				)
				 : ( fnl_test_mode == "prbs"  ) ?
					(
						( fnl_prbs_ver == "prbs_7_sw" ) ? ("prbs7_fixed_wa_pd_16_sw")
						 : ( (fnl_prbs_ver == "prbs_7_dw") && ( fnl_pma_dw == "sixteen_bit" ) ) ? ("prbs7_fixed_wa_pd_16_dw")
							 : ( (fnl_prbs_ver == "prbs_7_dw") && ( fnl_pma_dw == "twenty_bit" ) ) ? ("prbs7_fixed_wa_pd_20_dw")
								 : ( fnl_prbs_ver == "prbs_23_sw" ) ? ("prbs23_fixed_wa_pd_16_sw")
									 : ( (fnl_prbs_ver == "prbs_23_dw") && ( fnl_pma_dw == "sixteen_bit" ) ) ? ("prbs23_fixed_wa_pd_32_dw")
										 : ( (fnl_prbs_ver == "prbs_23_dw") && ( fnl_pma_dw == "twenty_bit" ) ) ? ("prbs23_fixed_wa_pd_40_dw")
											 : ( (fnl_prbs_ver == "prbs_15" ) &&  ( fnl_pma_dw == "eight_bit" ) ) ? ("prbs15_fixed_wa_pd_16_sw")
												 : ( (fnl_prbs_ver == "prbs_15" ) && ( fnl_pma_dw == "sixteen_bit" ) ) ? ("prbs15_fixed_wa_pd_16_dw")
													 : ( (fnl_prbs_ver == "prbs_15" ) && ( fnl_pma_dw == "twenty_bit" ) ) ? ("prbs15_fixed_wa_pd_20_dw")
														 : ( (fnl_prbs_ver == "prbs_31" ) &&  ( fnl_pma_dw == "eight_bit" ) ) ? ("prbs31_fixed_wa_pd_16_sw")
															 : ( (fnl_prbs_ver == "prbs_31" ) &&  ( fnl_pma_dw == "ten_bit" ) ) ? ("prbs31_fixed_wa_pd_10_sw")
																 : ( (fnl_prbs_ver == "prbs_31" ) &&  ( fnl_pma_dw == "sixteen_bit" ) ) ? ("prbs31_fixed_wa_pd_16_dw")
																	 : ( (fnl_prbs_ver == "prbs_31" ) &&  ( fnl_pma_dw == "twenty_bit" ) ) ? ("prbs31_fixed_wa_pd_40_dw")
																		 : (fnl_prbs_ver == "prbs_8" ) ? ("prbs8_fixed_wa")
																			 : (fnl_prbs_ver == "prbs_10" ) ? ("prbs10_fixed_wa") : "dont_care_wa_pd_0"
					)
					 : ( fnl_test_mode == "bist"  ) ? ("wa_pd_fixed_10_k28p5") : "wa_pd_fixed_10_k28p5"
		)
		 : (fnl_pma_dw == "sixteen_bit") ? ("dont_care_wa_pd_1") : "dont_care_wa_pd_0";
	localparam fnl_wa_pd = (wa_pd == "<auto_any>" || wa_pd == "<auto_single>") ? rbc_any_wa_pd : wa_pd;

	// wa_sync_sm_ctrl, RBC-validated
	localparam rbc_all_wa_sync_sm_ctrl = ( fnl_wa_boundary_lock_ctrl == "sync_sm" ) ?
		(
			(fnl_prot_mode == "gige") ? ("gige_sync_sm")
			 : (fnl_prot_mode == "xaui") ? ("xaui_sync_sm")
				 : (fnl_prot_mode == "srio_2p1") ? ("srio2p1_sync_sm")
					 : (fnl_prot_mode == "pipe_g1" || fnl_prot_mode == "pipe_g2" ) ? ("pipe_sync_sm")
						 : (fnl_test_mode == "bist") ? ("sw_basic_sync_sm")
							 : ( (fnl_prot_mode == "basic") && ( fnl_pma_dw == "ten_bit") ) ? ("sw_basic_sync_sm")
								 : ( (fnl_prot_mode == "basic") && ( fnl_pma_dw == "twenty_bit") ) ? ("(dw_basic_sync_sm,srio2p1_sync_sm)") : "gige_sync_sm"
		) : "gige_sync_sm";
	localparam rbc_any_wa_sync_sm_ctrl = ( fnl_wa_boundary_lock_ctrl == "sync_sm" ) ?
		(
			(fnl_prot_mode == "gige") ? ("gige_sync_sm")
			 : (fnl_prot_mode == "xaui") ? ("xaui_sync_sm")
				 : (fnl_prot_mode == "srio_2p1") ? ("srio2p1_sync_sm")
					 : (fnl_prot_mode == "pipe_g1" || fnl_prot_mode == "pipe_g2" ) ? ("pipe_sync_sm")
						 : (fnl_test_mode == "bist") ? ("sw_basic_sync_sm")
							 : ( (fnl_prot_mode == "basic") && ( fnl_pma_dw == "ten_bit") ) ? ("sw_basic_sync_sm")
								 : ( (fnl_prot_mode == "basic") && ( fnl_pma_dw == "twenty_bit") ) ? ("dw_basic_sync_sm") : "gige_sync_sm"
		) : "gige_sync_sm";
	localparam fnl_wa_sync_sm_ctrl = (wa_sync_sm_ctrl == "<auto_any>" || wa_sync_sm_ctrl == "<auto_single>") ? rbc_any_wa_sync_sm_ctrl : wa_sync_sm_ctrl;

	// wa_kchar, RBC-validated
	localparam rbc_all_wa_kchar = "dis_kchar";
	localparam rbc_any_wa_kchar = "dis_kchar";
	localparam fnl_wa_kchar = (wa_kchar == "<auto_any>" || wa_kchar == "<auto_single>") ? rbc_any_wa_kchar : wa_kchar;

	// fixed_pat_det, RBC-validated
	localparam rbc_all_fixed_pat_det = ( (fnl_prot_mode == "pipe_g1") || (fnl_prot_mode == "pipe_g2")) ?
		(
			(fnl_sup_mode == "engineering_mode") ? ("(dis_fixed_patdet,en_fixed_patdet)") : "dis_fixed_patdet"
		) : "dis_fixed_patdet";
	localparam rbc_any_fixed_pat_det = ( (fnl_prot_mode == "pipe_g1") || (fnl_prot_mode == "pipe_g2")) ?
		(
			(fnl_sup_mode == "engineering_mode") ? ("dis_fixed_patdet") : "dis_fixed_patdet"
		) : "dis_fixed_patdet";
	localparam fnl_fixed_pat_det = (fixed_pat_det == "<auto_any>" || fixed_pat_det == "<auto_single>") ? rbc_any_fixed_pat_det : fixed_pat_det;

	// ibm_invalid_code, RBC-validated
	localparam rbc_all_ibm_invalid_code = "dis_ibm_invalid_code";
	localparam rbc_any_ibm_invalid_code = "dis_ibm_invalid_code";
	localparam fnl_ibm_invalid_code = (ibm_invalid_code == "<auto_any>" || ibm_invalid_code == "<auto_single>") ? rbc_any_ibm_invalid_code : ibm_invalid_code;

	// force_signal_detect, RBC-validated
	localparam rbc_all_force_signal_detect = "en_force_signal_detect";
	localparam rbc_any_force_signal_detect = "en_force_signal_detect";
	localparam fnl_force_signal_detect = (force_signal_detect == "<auto_any>" || force_signal_detect == "<auto_single>") ? rbc_any_force_signal_detect : force_signal_detect;

	// wa_det_latency_sync_status_beh, RBC-validated
	localparam rbc_all_wa_det_latency_sync_status_beh = (fnl_prot_mode == "cpri") ? ("(assert_sync_status_imm,assert_sync_status_non_imm)") : "dont_care_assert_sync";
	localparam rbc_any_wa_det_latency_sync_status_beh = (fnl_prot_mode == "cpri") ? ("assert_sync_status_non_imm") : "dont_care_assert_sync";
	localparam fnl_wa_det_latency_sync_status_beh = (wa_det_latency_sync_status_beh == "<auto_any>" || wa_det_latency_sync_status_beh == "<auto_single>") ? rbc_any_wa_det_latency_sync_status_beh : wa_det_latency_sync_status_beh;

	// wa_clk_slip_spacing, RBC-validated
	localparam rbc_all_wa_clk_slip_spacing = (fnl_prot_mode == "cpri") ? ("(min_clk_slip_spacing,user_programmable_clk_slip_spacing)") : "min_clk_slip_spacing";
	localparam rbc_any_wa_clk_slip_spacing = (fnl_prot_mode == "cpri") ? ("min_clk_slip_spacing") : "min_clk_slip_spacing";
	localparam fnl_wa_clk_slip_spacing = (wa_clk_slip_spacing == "<auto_any>" || wa_clk_slip_spacing == "<auto_single>") ? rbc_any_wa_clk_slip_spacing : wa_clk_slip_spacing;

	// eightb_tenb_decoder, RBC-validated
	localparam rbc_all_eightb_tenb_decoder = (  (fnl_pma_dw == "eight_bit")  || (fnl_pma_dw == "sixteen_bit") || (fnl_pcs_bypass == "en_pcs_bypass")  || (fnl_test_mode == "prbs")   ) ? ("dis_8b10b")
		 : (fnl_prot_mode == "basic" || fnl_prot_mode == "cpri" || fnl_prot_mode == "cpri_rx_tx") ? ("(dis_8b10b,en_8b10b_ibm)") : "en_8b10b_ibm";
	localparam rbc_any_eightb_tenb_decoder = (  (fnl_pma_dw == "eight_bit")  || (fnl_pma_dw == "sixteen_bit") || (fnl_pcs_bypass == "en_pcs_bypass")  || (fnl_test_mode == "prbs")   ) ? ("dis_8b10b")
		 : (fnl_prot_mode == "basic" || fnl_prot_mode == "cpri" || fnl_prot_mode == "cpri_rx_tx") ? ("dis_8b10b") : "en_8b10b_ibm";
	localparam fnl_eightb_tenb_decoder = (eightb_tenb_decoder == "<auto_any>" || eightb_tenb_decoder == "<auto_single>") ? rbc_any_eightb_tenb_decoder : eightb_tenb_decoder;

	// wa_disp_err_flag, RBC-validated
	localparam rbc_all_wa_disp_err_flag = ( (fnl_prot_mode == "basic" ) && (fnl_eightb_tenb_decoder == "en_8b10b_ibm") ) ? ("(dis_disp_err_flag,en_disp_err_flag)")
		 : (fnl_eightb_tenb_decoder == "dis_8b10b" ) ? ("dis_disp_err_flag") : "en_disp_err_flag";
	localparam rbc_any_wa_disp_err_flag = ( (fnl_prot_mode == "basic" ) && (fnl_eightb_tenb_decoder == "en_8b10b_ibm") ) ? ("dis_disp_err_flag")
		 : (fnl_eightb_tenb_decoder == "dis_8b10b" ) ? ("dis_disp_err_flag") : "en_disp_err_flag";
	localparam fnl_wa_disp_err_flag = (wa_disp_err_flag == "<auto_any>" || wa_disp_err_flag == "<auto_single>") ? rbc_any_wa_disp_err_flag : wa_disp_err_flag;

	// polarity_inversion, RBC-validated
	localparam rbc_all_polarity_inversion = ( (fnl_prot_mode == "disabled_prot_mode") ||  (fnl_prot_mode == "pipe_g1") || (fnl_prot_mode == "pipe_g2")) ? ("dis_pol_inv")
		 : (fnl_prot_mode == "test") ?
			(
				( (fnl_test_mode == "prbs") && (fnl_prbs_ver == "prbs_31")) ? ("(dis_pol_inv,en_pol_inv)") : "dis_pol_inv"
			) : "(dis_pol_inv,en_pol_inv)";
	localparam rbc_any_polarity_inversion = ( (fnl_prot_mode == "disabled_prot_mode") ||  (fnl_prot_mode == "pipe_g1") || (fnl_prot_mode == "pipe_g2")) ? ("dis_pol_inv")
		 : (fnl_prot_mode == "test") ?
			(
				( (fnl_test_mode == "prbs") && (fnl_prbs_ver == "prbs_31")) ? ("dis_pol_inv") : "dis_pol_inv"
			) : "dis_pol_inv";
	localparam fnl_polarity_inversion = (polarity_inversion == "<auto_any>" || polarity_inversion == "<auto_single>") ? rbc_any_polarity_inversion : polarity_inversion;

	// bit_reversal, RBC-validated
	localparam rbc_all_bit_reversal = (fnl_prot_mode == "basic" ) ? ("(dis_bit_reversal,en_bit_reversal)") : "dis_bit_reversal";
	localparam rbc_any_bit_reversal = (fnl_prot_mode == "basic" ) ? ("dis_bit_reversal") : "dis_bit_reversal";
	localparam fnl_bit_reversal = (bit_reversal == "<auto_any>" || bit_reversal == "<auto_single>") ? rbc_any_bit_reversal : bit_reversal;

	// symbol_swap, RBC-validated
	localparam rbc_all_symbol_swap = (fnl_prot_mode == "basic"  && (fnl_pma_dw == "sixteen_bit"  || fnl_pma_dw == "twenty_bit") ) ? ("(dis_symbol_swap,en_symbol_swap)") : "dis_symbol_swap";
	localparam rbc_any_symbol_swap = (fnl_prot_mode == "basic"  && (fnl_pma_dw == "sixteen_bit"  || fnl_pma_dw == "twenty_bit") ) ? ("dis_symbol_swap") : "dis_symbol_swap";
	localparam fnl_symbol_swap = (symbol_swap == "<auto_any>" || symbol_swap == "<auto_single>") ? rbc_any_symbol_swap : symbol_swap;

	// runlength_check, RBC-validated
	localparam rbc_all_runlength_check = ((fnl_pma_dw == "ten_bit") || (fnl_pma_dw == "eight_bit") ) ? ("en_runlength_sw") : "en_runlength_dw";
	localparam rbc_any_runlength_check = ((fnl_pma_dw == "ten_bit") || (fnl_pma_dw == "eight_bit") ) ? ("en_runlength_sw") : "en_runlength_dw";
	localparam fnl_runlength_check = (runlength_check == "<auto_any>" || runlength_check == "<auto_single>") ? rbc_any_runlength_check : runlength_check;

	// ctrl_plane_bonding_consumption, RBC-validated
	localparam rbc_all_ctrl_plane_bonding_consumption = ( (fnl_prot_mode == "test") || (fnl_prot_mode == "basic") || (fnl_prot_mode == "cpri") || (fnl_prot_mode == "cpri_rx_tx") || (fnl_prot_mode == "gige") ||  (fnl_prot_mode == "disabled_prot_mode")  ) ? ("individual")
		 : (fnl_prot_mode == "xaui") ? ("(bundled_master,bundled_slave_below,bundled_slave_above)") : "(individual,bundled_master,bundled_slave_below,bundled_slave_above)";
	localparam rbc_any_ctrl_plane_bonding_consumption = ( (fnl_prot_mode == "test") || (fnl_prot_mode == "basic") || (fnl_prot_mode == "cpri") || (fnl_prot_mode == "cpri_rx_tx") || (fnl_prot_mode == "gige") ||  (fnl_prot_mode == "disabled_prot_mode")  ) ? ("individual")
		 : (fnl_prot_mode == "xaui") ? ("bundled_master") : "individual";
	localparam fnl_ctrl_plane_bonding_consumption = (ctrl_plane_bonding_consumption == "<auto_any>" || ctrl_plane_bonding_consumption == "<auto_single>") ? rbc_any_ctrl_plane_bonding_consumption : ctrl_plane_bonding_consumption;

	// deskew, RBC-validated
	localparam rbc_all_deskew = ( (fnl_prot_mode == "srio_2p1") && (fnl_ctrl_plane_bonding_consumption != "individual") ) ? ("en_srio_v2p1")
		 : (fnl_prot_mode == "xaui") ? ("en_xaui") : "dis_deskew";
	localparam rbc_any_deskew = ( (fnl_prot_mode == "srio_2p1") && (fnl_ctrl_plane_bonding_consumption != "individual") ) ? ("en_srio_v2p1")
		 : (fnl_prot_mode == "xaui") ? ("en_xaui") : "dis_deskew";
	localparam fnl_deskew = (deskew == "<auto_any>" || deskew == "<auto_single>") ? rbc_any_deskew : deskew;

	// deskew_prog_pattern_only, RBC-validated
	localparam rbc_all_deskew_prog_pattern_only = "dis_deskew_prog_pat_only";
	localparam rbc_any_deskew_prog_pattern_only = "dis_deskew_prog_pat_only";
	localparam fnl_deskew_prog_pattern_only = (deskew_prog_pattern_only == "<auto_any>" || deskew_prog_pattern_only == "<auto_single>") ? rbc_any_deskew_prog_pattern_only : deskew_prog_pattern_only;

	// rate_match, RBC-validated
	localparam rbc_all_rate_match = (fnl_prot_mode == "gige") ? ("(dis_rm,gige_rm)")
		 : (fnl_prot_mode == "xaui") ? ("xaui_rm")
			 : ( (fnl_prot_mode == "pipe_g1") || (fnl_prot_mode == "pipe_g2")) ? ("(pipe_rm,pipe_rm_0ppm)")
				 : (fnl_prot_mode == "srio_2p1") ? ("(srio_v2p1_rm,srio_v2p1_rm_0ppm)")
					 : ( (fnl_prot_mode == "basic") && (fnl_pma_dw == "ten_bit") && (fnl_wa_boundary_lock_ctrl == "sync_sm") && (fnl_pcs_bypass == "dis_pcs_bypass") ) ? ("(dis_rm,sw_basic_rm)")
						 : ( (fnl_prot_mode == "basic") && (fnl_pma_dw == "twenty_bit")  && (fnl_wa_boundary_lock_ctrl == "auto_align_pld_ctrl") && (fnl_pcs_bypass == "dis_pcs_bypass")  ) ? ("(dis_rm,dw_basic_rm)") : "dis_rm";
	localparam rbc_any_rate_match = (fnl_prot_mode == "gige") ? ("dis_rm")
		 : (fnl_prot_mode == "xaui") ? ("xaui_rm")
			 : ( (fnl_prot_mode == "pipe_g1") || (fnl_prot_mode == "pipe_g2")) ? ("pipe_rm")
				 : (fnl_prot_mode == "srio_2p1") ? ("srio_v2p1_rm")
					 : ( (fnl_prot_mode == "basic") && (fnl_pma_dw == "ten_bit") && (fnl_wa_boundary_lock_ctrl == "sync_sm") && (fnl_pcs_bypass == "dis_pcs_bypass") ) ? ("dis_rm")
						 : ( (fnl_prot_mode == "basic") && (fnl_pma_dw == "twenty_bit")  && (fnl_wa_boundary_lock_ctrl == "auto_align_pld_ctrl") && (fnl_pcs_bypass == "dis_pcs_bypass")  ) ? ("dis_rm") : "dis_rm";
	localparam fnl_rate_match = (rate_match == "<auto_any>" || rate_match == "<auto_single>") ? rbc_any_rate_match : rate_match;

	// err_flags_sel, RBC-validated
	localparam rbc_all_err_flags_sel = ( (fnl_prot_mode == "basic") && (fnl_eightb_tenb_decoder == "en_8b10b_ibm")    ) ? ("(err_flags_wa,err_flags_8b10b)") : "err_flags_wa";
	localparam rbc_any_err_flags_sel = ( (fnl_prot_mode == "basic") && (fnl_eightb_tenb_decoder == "en_8b10b_ibm")    ) ? ("err_flags_wa") : "err_flags_wa";
	localparam fnl_err_flags_sel = (err_flags_sel == "<auto_any>" || err_flags_sel == "<auto_single>") ? rbc_any_err_flags_sel : err_flags_sel;

	// polinv_8b10b_dec, RBC-validated
	localparam rbc_all_polinv_8b10b_dec = ((fnl_prot_mode == "pipe_g1") || (fnl_prot_mode == "pipe_g2")) ? ("en_polinv_8b10b_dec") : "dis_polinv_8b10b_dec";
	localparam rbc_any_polinv_8b10b_dec = ((fnl_prot_mode == "pipe_g1") || (fnl_prot_mode == "pipe_g2")) ? ("en_polinv_8b10b_dec") : "dis_polinv_8b10b_dec";
	localparam fnl_polinv_8b10b_dec = (polinv_8b10b_dec == "<auto_any>" || polinv_8b10b_dec == "<auto_single>") ? rbc_any_polinv_8b10b_dec : polinv_8b10b_dec;

	// eightbtenb_decoder_output_sel, RBC-validated
	localparam rbc_all_eightbtenb_decoder_output_sel = (fnl_prot_mode == "xaui") ? ("data_xaui_sm") : "data_8b10b_decoder";
	localparam rbc_any_eightbtenb_decoder_output_sel = (fnl_prot_mode == "xaui") ? ("data_xaui_sm") : "data_8b10b_decoder";
	localparam fnl_eightbtenb_decoder_output_sel = (eightbtenb_decoder_output_sel == "<auto_any>" || eightbtenb_decoder_output_sel == "<auto_single>") ? rbc_any_eightbtenb_decoder_output_sel : eightbtenb_decoder_output_sel;

	// invalid_code_flag_only, RBC-validated
	localparam rbc_all_invalid_code_flag_only = ( (fnl_prot_mode == "pipe_g1")  || (fnl_prot_mode == "pipe_g2") ) ? ("(dis_invalid_code_only,en_invalid_code_only)") : "dis_invalid_code_only";
	localparam rbc_any_invalid_code_flag_only = ( (fnl_prot_mode == "pipe_g1")  || (fnl_prot_mode == "pipe_g2") ) ? ("dis_invalid_code_only") : "dis_invalid_code_only";
	localparam fnl_invalid_code_flag_only = (invalid_code_flag_only == "<auto_any>" || invalid_code_flag_only == "<auto_single>") ? rbc_any_invalid_code_flag_only : invalid_code_flag_only;

	// auto_error_replacement, RBC-validated
	localparam rbc_all_auto_error_replacement = ((fnl_prot_mode == "basic") && (fnl_eightb_tenb_decoder == "en_8b10b_ibm") && ( (fnl_pma_dw == "ten_bit" &&  fnl_wa_boundary_lock_ctrl == "sync_sm") || (fnl_pma_dw == "twenty_bit" &&  fnl_wa_boundary_lock_ctrl == "auto_align_pld_ctrl"))   ) ? ("(dis_err_replace,en_err_replace)")
		 : ( (fnl_prot_mode == "pipe_g1")  || (fnl_prot_mode == "pipe_g2") ) ? ("en_err_replace") : "dis_err_replace";
	localparam rbc_any_auto_error_replacement = ((fnl_prot_mode == "basic") && (fnl_eightb_tenb_decoder == "en_8b10b_ibm") && ( (fnl_pma_dw == "ten_bit" &&  fnl_wa_boundary_lock_ctrl == "sync_sm") || (fnl_pma_dw == "twenty_bit" &&  fnl_wa_boundary_lock_ctrl == "auto_align_pld_ctrl"))   ) ? ("dis_err_replace")
		 : ( (fnl_prot_mode == "pipe_g1")  || (fnl_prot_mode == "pipe_g2") ) ? ("en_err_replace") : "dis_err_replace";
	localparam fnl_auto_error_replacement = (auto_error_replacement == "<auto_any>" || auto_error_replacement == "<auto_single>") ? rbc_any_auto_error_replacement : auto_error_replacement;

	// pad_or_edb_error_replace, RBC-validated
	localparam rbc_all_pad_or_edb_error_replace = ( (fnl_prot_mode == "pipe_g1")  || (fnl_prot_mode == "pipe_g2") ) ? ("replace_edb_dynamic") : "replace_edb";
	localparam rbc_any_pad_or_edb_error_replace = ( (fnl_prot_mode == "pipe_g1")  || (fnl_prot_mode == "pipe_g2") ) ? ("replace_edb_dynamic") : "replace_edb";
	localparam fnl_pad_or_edb_error_replace = (pad_or_edb_error_replace == "<auto_any>" || pad_or_edb_error_replace == "<auto_single>") ? rbc_any_pad_or_edb_error_replace : pad_or_edb_error_replace;

	// byte_deserializer, RBC-validated
	localparam rbc_all_byte_deserializer = ( fnl_prot_mode == "cpri"  ) ? ("(dis_bds,en_bds_by_2)")
		 : (  (fnl_test_mode == "prbs") || (fnl_test_mode == "bist" && fnl_pma_dw == "twenty_bit") ||  (fnl_prot_mode == "disabled_prot_mode") || (fnl_hip_mode == "en_hip") ) ? ("dis_bds")
			 : ( (fnl_prot_mode == "xaui") || (fnl_test_mode == "bist" && fnl_pma_dw == "ten_bit" ) || ( fnl_prot_mode == "pipe_g2" )) ? ("en_bds_by_2") : "(dis_bds,en_bds_by_2)";
	localparam rbc_any_byte_deserializer = ( fnl_prot_mode == "cpri"  ) ? ("dis_bds")
		 : (  (fnl_test_mode == "prbs") || (fnl_test_mode == "bist" && fnl_pma_dw == "twenty_bit") ||  (fnl_prot_mode == "disabled_prot_mode") || (fnl_hip_mode == "en_hip") ) ? ("dis_bds")
			 : ( (fnl_prot_mode == "xaui") || (fnl_test_mode == "bist" && fnl_pma_dw == "ten_bit" ) || ( fnl_prot_mode == "pipe_g2" )) ? ("en_bds_by_2") : "dis_bds";
	localparam fnl_byte_deserializer = (byte_deserializer == "<auto_any>" || byte_deserializer == "<auto_single>") ? rbc_any_byte_deserializer : byte_deserializer;

	// byte_order, RBC-validated
	localparam rbc_all_byte_order = ( ( fnl_byte_deserializer == "en_bds_by_2"  ) && (fnl_pcs_bypass == "dis_pcs_bypass") && (fnl_wa_boundary_lock_ctrl != "deterministic_latency"  )    ) ?
		(
			(fnl_prot_mode == "basic") ?
			(
				( (fnl_pma_dw == "eight_bit") || (fnl_pma_dw == "sixteen_bit") ) ?
				(
					(fnl_wa_boundary_lock_ctrl == "bit_slip"  ) ? ("(dis_bo,en_pld_ctrl_eight_bit_bo)") : "(dis_bo,en_pcs_ctrl_eight_bit_bo,en_pld_ctrl_eight_bit_bo)"
				)
				 : ( ( (fnl_pma_dw == "ten_bit") || (fnl_pma_dw == "twenty_bit") ) && (fnl_eightb_tenb_decoder == "en_8b10b_ibm")  ) ?
					(
						(fnl_wa_boundary_lock_ctrl == "bit_slip"  ) ? ("(dis_bo,en_pld_ctrl_nine_bit_bo)") : "(dis_bo,en_pcs_ctrl_nine_bit_bo,en_pld_ctrl_nine_bit_bo)"
					)
					 : (fnl_wa_boundary_lock_ctrl == "bit_slip"  ) ? ("(dis_bo,en_pld_ctrl_ten_bit_bo)") : "(dis_bo,en_pcs_ctrl_ten_bit_bo,en_pld_ctrl_ten_bit_bo)"
			)
			 : ( (fnl_test_mode == "bist") && (fnl_pma_dw == "ten_bit") ) ? ("en_pcs_ctrl_nine_bit_bo") : "dis_bo"
		) : "dis_bo";
	localparam rbc_any_byte_order = ( ( fnl_byte_deserializer == "en_bds_by_2"  ) && (fnl_pcs_bypass == "dis_pcs_bypass") && (fnl_wa_boundary_lock_ctrl != "deterministic_latency"  )    ) ?
		(
			(fnl_prot_mode == "basic") ?
			(
				( (fnl_pma_dw == "eight_bit") || (fnl_pma_dw == "sixteen_bit") ) ?
				(
					(fnl_wa_boundary_lock_ctrl == "bit_slip"  ) ? ("dis_bo") : "dis_bo"
				)
				 : ( ( (fnl_pma_dw == "ten_bit") || (fnl_pma_dw == "twenty_bit") ) && (fnl_eightb_tenb_decoder == "en_8b10b_ibm")  ) ?
					(
						(fnl_wa_boundary_lock_ctrl == "bit_slip"  ) ? ("dis_bo") : "dis_bo"
					)
					 : (fnl_wa_boundary_lock_ctrl == "bit_slip"  ) ? ("dis_bo") : "dis_bo"
			)
			 : ( (fnl_test_mode == "bist") && (fnl_pma_dw == "ten_bit") ) ? ("en_pcs_ctrl_nine_bit_bo") : "dis_bo"
		) : "dis_bo";
	localparam fnl_byte_order = (byte_order == "<auto_any>" || byte_order == "<auto_single>") ? rbc_any_byte_order : byte_order;

	// dw_one_or_two_symbol_bo, RBC-validated
	localparam rbc_all_dw_one_or_two_symbol_bo = ( (fnl_pma_dw == "sixteen_bit")  && ( (fnl_byte_order != "dis_bo"  )   )  ) ? ("(one_symbol_bo,two_symbol_bo_eight_bit)")
		 : ( (fnl_pma_dw == "twenty_bit")  && ( (fnl_byte_order == "en_pcs_ctrl_nine_bit_bo" ) || (fnl_byte_order == "en_pld_ctrl_nine_bit_bo" )   )  ) ? ("(one_symbol_bo,two_symbol_bo_nine_bit)")
			 : ( (fnl_pma_dw == "twenty_bit")  && ( (fnl_byte_order == "en_pcs_ctrl_ten_bit_bo" ) || (fnl_byte_order == "en_pld_ctrl_ten_bit_bo" )   )  ) ? ("(one_symbol_bo,two_symbol_bo_ten_bit)") : "donot_care_one_two_bo";
	localparam rbc_any_dw_one_or_two_symbol_bo = ( (fnl_pma_dw == "sixteen_bit")  && ( (fnl_byte_order != "dis_bo"  )   )  ) ? ("one_symbol_bo")
		 : ( (fnl_pma_dw == "twenty_bit")  && ( (fnl_byte_order == "en_pcs_ctrl_nine_bit_bo" ) || (fnl_byte_order == "en_pld_ctrl_nine_bit_bo" )   )  ) ? ("one_symbol_bo")
			 : ( (fnl_pma_dw == "twenty_bit")  && ( (fnl_byte_order == "en_pcs_ctrl_ten_bit_bo" ) || (fnl_byte_order == "en_pld_ctrl_ten_bit_bo" )   )  ) ? ("one_symbol_bo") : "donot_care_one_two_bo";
	localparam fnl_dw_one_or_two_symbol_bo = (dw_one_or_two_symbol_bo == "<auto_any>" || dw_one_or_two_symbol_bo == "<auto_single>") ? rbc_any_dw_one_or_two_symbol_bo : dw_one_or_two_symbol_bo;

	// re_bo_on_wa, RBC-validated
	localparam rbc_all_re_bo_on_wa = "dis_re_bo_on_wa";
	localparam rbc_any_re_bo_on_wa = "dis_re_bo_on_wa";
	localparam fnl_re_bo_on_wa = (re_bo_on_wa == "<auto_any>" || re_bo_on_wa == "<auto_single>") ? rbc_any_re_bo_on_wa : re_bo_on_wa;

	// phase_compensation_fifo, RBC-validated
	localparam rbc_all_phase_compensation_fifo = (fnl_prot_mode == "cpri" || fnl_prot_mode == "cpri_rx_tx" || fnl_hip_mode == "en_hip"  ) ? ("register_fifo")
		 : ( (fnl_prot_mode == "basic")  || (fnl_prot_mode == "gige") ) ? ("(low_latency,register_fifo)") : "low_latency";
	localparam rbc_any_phase_compensation_fifo = (fnl_prot_mode == "cpri" || fnl_prot_mode == "cpri_rx_tx" || fnl_hip_mode == "en_hip"  ) ? ("register_fifo")
		 : ( (fnl_prot_mode == "basic")  || (fnl_prot_mode == "gige") ) ? ("low_latency") : "low_latency";
	localparam fnl_phase_compensation_fifo = (phase_compensation_fifo == "<auto_any>" || phase_compensation_fifo == "<auto_single>") ? rbc_any_phase_compensation_fifo : phase_compensation_fifo;

	// tx_rx_parallel_loopback, RBC-validated
	localparam rbc_all_tx_rx_parallel_loopback = (  (fnl_sup_mode == "engineering_mode" ) &&  (fnl_ctrl_plane_bonding_consumption == "individual") ) ? ("(dis_plpbk,en_plpbk)")
		 : (fnl_test_mode == "bist") ? ("en_plpbk") : "dis_plpbk";
	localparam rbc_any_tx_rx_parallel_loopback = (  (fnl_sup_mode == "engineering_mode" ) &&  (fnl_ctrl_plane_bonding_consumption == "individual") ) ? ("dis_plpbk")
		 : (fnl_test_mode == "bist") ? ("en_plpbk") : "dis_plpbk";
	localparam fnl_tx_rx_parallel_loopback = (tx_rx_parallel_loopback == "<auto_any>" || tx_rx_parallel_loopback == "<auto_single>") ? rbc_any_tx_rx_parallel_loopback : tx_rx_parallel_loopback;

	// prbs_ver_clr_flag, RBC-validated
	localparam rbc_all_prbs_ver_clr_flag = ( fnl_test_mode == "prbs") ? ("(dis_prbs_clr_flag,en_prbs_clr_flag)") : "dis_prbs_clr_flag";
	localparam rbc_any_prbs_ver_clr_flag = ( fnl_test_mode == "prbs") ? ("dis_prbs_clr_flag") : "dis_prbs_clr_flag";
	localparam fnl_prbs_ver_clr_flag = (prbs_ver_clr_flag == "<auto_any>" || prbs_ver_clr_flag == "<auto_single>") ? rbc_any_prbs_ver_clr_flag : prbs_ver_clr_flag;

	// cid_pattern, RBC-validated
	localparam rbc_all_cid_pattern = (fnl_prbs_ver == "prbs_8" ) ? ("(cid_pattern_0,cid_pattern_1)") : "cid_pattern_0";
	localparam rbc_any_cid_pattern = (fnl_prbs_ver == "prbs_8" ) ? ("cid_pattern_0") : "cid_pattern_0";
	localparam fnl_cid_pattern = (cid_pattern == "<auto_any>" || cid_pattern == "<auto_single>") ? rbc_any_cid_pattern : cid_pattern;

	// bist_ver, RBC-validated
	localparam rbc_all_bist_ver = ( (fnl_test_mode == "bist") && (fnl_sup_mode == "user_mode") ) ? ("incremental")
		 : ( (fnl_test_mode == "bist") && (fnl_sup_mode == "engineering_mode") ) ? ("(cjpat,crpat)") : "dis_bist";
	localparam rbc_any_bist_ver = ( (fnl_test_mode == "bist") && (fnl_sup_mode == "user_mode") ) ? ("incremental")
		 : ( (fnl_test_mode == "bist") && (fnl_sup_mode == "engineering_mode") ) ? ("cjpat") : "dis_bist";
	localparam fnl_bist_ver = (bist_ver == "<auto_any>" || bist_ver == "<auto_single>") ? rbc_any_bist_ver : bist_ver;

	// bist_ver_clr_flag, RBC-validated
	localparam rbc_all_bist_ver_clr_flag = ( fnl_test_mode == "bist") ? ("(dis_bist_clr_flag,en_bist_clr_flag)") : "dis_bist_clr_flag";
	localparam rbc_any_bist_ver_clr_flag = ( fnl_test_mode == "bist") ? ("dis_bist_clr_flag") : "dis_bist_clr_flag";
	localparam fnl_bist_ver_clr_flag = (bist_ver_clr_flag == "<auto_any>" || bist_ver_clr_flag == "<auto_single>") ? rbc_any_bist_ver_clr_flag : bist_ver_clr_flag;

	// cdr_ctrl, RBC-validated
	localparam rbc_all_cdr_ctrl = ((fnl_prot_mode == "pipe_g1") || (fnl_prot_mode == "pipe_g2" ) ) ? ("(dis_cdr_ctrl,en_cdr_ctrl,en_cdr_ctrl_w_cid)") : "dis_cdr_ctrl";
	localparam rbc_any_cdr_ctrl = ((fnl_prot_mode == "pipe_g1") || (fnl_prot_mode == "pipe_g2" ) ) ? ("dis_cdr_ctrl") : "dis_cdr_ctrl";
	localparam fnl_cdr_ctrl = (cdr_ctrl == "<auto_any>" || cdr_ctrl == "<auto_single>") ? rbc_any_cdr_ctrl : cdr_ctrl;

	// cdr_ctrl_rxvalid_mask, RBC-validated
	localparam rbc_all_cdr_ctrl_rxvalid_mask = ((fnl_prot_mode == "pipe_g1") || (fnl_prot_mode == "pipe_g2" ) ) ? ("(dis_rxvalid_mask,en_rxvalid_mask)") : "dis_rxvalid_mask";
	localparam rbc_any_cdr_ctrl_rxvalid_mask = ((fnl_prot_mode == "pipe_g1") || (fnl_prot_mode == "pipe_g2" ) ) ? ("dis_rxvalid_mask") : "dis_rxvalid_mask";
	localparam fnl_cdr_ctrl_rxvalid_mask = (cdr_ctrl_rxvalid_mask == "<auto_any>" || cdr_ctrl_rxvalid_mask == "<auto_single>") ? rbc_any_cdr_ctrl_rxvalid_mask : cdr_ctrl_rxvalid_mask;

	// auto_speed_nego, RBC-validated
	localparam rbc_all_auto_speed_nego = ( (fnl_prot_mode == "pipe_g2" ) && ( (fnl_ctrl_plane_bonding_consumption == "individual") || (fnl_ctrl_plane_bonding_consumption == "bundled_master")) ) ? ("en_asn_g2_freq_scal") : "dis_asn";
	localparam rbc_any_auto_speed_nego = ( (fnl_prot_mode == "pipe_g2" ) && ( (fnl_ctrl_plane_bonding_consumption == "individual") || (fnl_ctrl_plane_bonding_consumption == "bundled_master")) ) ? ("en_asn_g2_freq_scal") : "dis_asn";
	localparam fnl_auto_speed_nego = (auto_speed_nego == "<auto_any>" || auto_speed_nego == "<auto_single>") ? rbc_any_auto_speed_nego : auto_speed_nego;

	// eidle_entry_iei, RBC-validated
	localparam rbc_all_eidle_entry_iei = ((fnl_prot_mode == "pipe_g1")  || (fnl_prot_mode == "pipe_g2") ) ? ("(dis_eidle_iei,en_eidle_iei)") : "dis_eidle_iei";
	localparam rbc_any_eidle_entry_iei = ((fnl_prot_mode == "pipe_g1")  || (fnl_prot_mode == "pipe_g2") ) ? ("dis_eidle_iei") : "dis_eidle_iei";
	localparam fnl_eidle_entry_iei = (eidle_entry_iei == "<auto_any>" || eidle_entry_iei == "<auto_single>") ? rbc_any_eidle_entry_iei : eidle_entry_iei;

	// eidle_entry_sd, RBC-validated
	localparam rbc_all_eidle_entry_sd = ( fnl_eidle_entry_iei == "en_eidle_iei") ? ("(dis_eidle_sd,en_eidle_sd)") : "dis_eidle_sd";
	localparam rbc_any_eidle_entry_sd = ( fnl_eidle_entry_iei == "en_eidle_iei") ? ("dis_eidle_sd") : "dis_eidle_sd";
	localparam fnl_eidle_entry_sd = (eidle_entry_sd == "<auto_any>" || eidle_entry_sd == "<auto_single>") ? rbc_any_eidle_entry_sd : eidle_entry_sd;

	// eidle_entry_eios, RBC-validated
	localparam rbc_all_eidle_entry_eios = ((fnl_prot_mode == "pipe_g1")  ||  (fnl_prot_mode == "pipe_g2") ) ? ("(dis_eidle_eios,en_eidle_eios)") : "dis_eidle_eios";
	localparam rbc_any_eidle_entry_eios = ((fnl_prot_mode == "pipe_g1")  ||  (fnl_prot_mode == "pipe_g2") ) ? ("dis_eidle_eios") : "dis_eidle_eios";
	localparam fnl_eidle_entry_eios = (eidle_entry_eios == "<auto_any>" || eidle_entry_eios == "<auto_single>") ? rbc_any_eidle_entry_eios : eidle_entry_eios;

	// ctrl_plane_bonding_distribution, RBC-validated
	localparam rbc_all_ctrl_plane_bonding_distribution = ( fnl_ctrl_plane_bonding_consumption == "bundled_master") ? ("master_chnl_distr") : "not_master_chnl_distr";
	localparam rbc_any_ctrl_plane_bonding_distribution = ( fnl_ctrl_plane_bonding_consumption == "bundled_master") ? ("master_chnl_distr") : "not_master_chnl_distr";
	localparam fnl_ctrl_plane_bonding_distribution = (ctrl_plane_bonding_distribution == "<auto_any>" || ctrl_plane_bonding_distribution == "<auto_single>") ? rbc_any_ctrl_plane_bonding_distribution : ctrl_plane_bonding_distribution;

	// ctrl_plane_bonding_compensation, RBC-validated
	localparam rbc_all_ctrl_plane_bonding_compensation = "dis_compensation";
	localparam rbc_any_ctrl_plane_bonding_compensation = "dis_compensation";
	localparam fnl_ctrl_plane_bonding_compensation = (ctrl_plane_bonding_compensation == "<auto_any>" || ctrl_plane_bonding_compensation == "<auto_single>") ? rbc_any_ctrl_plane_bonding_compensation : ctrl_plane_bonding_compensation;

	// bypass_pipeline_reg, RBC-validated
	localparam rbc_all_bypass_pipeline_reg = "dis_bypass_pipeline";
	localparam rbc_any_bypass_pipeline_reg = "dis_bypass_pipeline";
	localparam fnl_bypass_pipeline_reg = (bypass_pipeline_reg == "<auto_any>" || bypass_pipeline_reg == "<auto_single>") ? rbc_any_bypass_pipeline_reg : bypass_pipeline_reg;

	// rx_refclk, RBC-validated
	localparam rbc_all_rx_refclk = (fnl_sup_mode == "engineering_mode") ? ("(dis_refclk_sel,en_refclk_sel)") : "dis_refclk_sel";
	localparam rbc_any_rx_refclk = (fnl_sup_mode == "engineering_mode") ? ("dis_refclk_sel") : "dis_refclk_sel";
	localparam fnl_rx_refclk = (rx_refclk == "<auto_any>" || rx_refclk == "<auto_single>") ? rbc_any_rx_refclk : rx_refclk;

	// rx_rcvd_clk, RBC-validated
	localparam rbc_all_rx_rcvd_clk = (fnl_tx_rx_parallel_loopback == "en_plpbk") ? ("tx_pma_clock_rcvd_clk") : "rcvd_clk_rcvd_clk";
	localparam rbc_any_rx_rcvd_clk = (fnl_tx_rx_parallel_loopback == "en_plpbk") ? ("tx_pma_clock_rcvd_clk") : "rcvd_clk_rcvd_clk";
	localparam fnl_rx_rcvd_clk = (rx_rcvd_clk == "<auto_any>" || rx_rcvd_clk == "<auto_single>") ? rbc_any_rx_rcvd_clk : rx_rcvd_clk;

	// agg_block_sel, RBC-validated
	localparam rbc_all_agg_block_sel = ( (fnl_prot_mode == "xaui") || ( (fnl_prot_mode == "srio_2p1") && (fnl_ctrl_plane_bonding_consumption != "individual") ) ) ? ("(same_smrt_pack,other_smrt_pack)") : "same_smrt_pack";
	localparam rbc_any_agg_block_sel = ( (fnl_prot_mode == "xaui") || ( (fnl_prot_mode == "srio_2p1") && (fnl_ctrl_plane_bonding_consumption != "individual") ) ) ? ("same_smrt_pack") : "same_smrt_pack";
	localparam fnl_agg_block_sel = (agg_block_sel == "<auto_any>" || agg_block_sel == "<auto_single>") ? rbc_any_agg_block_sel : agg_block_sel;

	// rx_clk1, RBC-validated
	localparam rbc_all_rx_clk1 = (fnl_tx_rx_parallel_loopback == "en_plpbk") ? ("tx_pma_clock_clk1")
		 : (fnl_deskew == "dis_deskew") ? ("rcvd_clk_clk1")
			 : (fnl_agg_block_sel == "same_smrt_pack") ? ("rcvd_clk_agg_clk1") : "rcvd_clk_agg_top_or_bottom_clk1";
	localparam rbc_any_rx_clk1 = (fnl_tx_rx_parallel_loopback == "en_plpbk") ? ("tx_pma_clock_clk1")
		 : (fnl_deskew == "dis_deskew") ? ("rcvd_clk_clk1")
			 : (fnl_agg_block_sel == "same_smrt_pack") ? ("rcvd_clk_agg_clk1") : "rcvd_clk_agg_top_or_bottom_clk1";
	localparam fnl_rx_clk1 = (rx_clk1 == "<auto_any>" || rx_clk1 == "<auto_single>") ? rbc_any_rx_clk1 : rx_clk1;

	// rx_clk2, RBC-validated
	localparam rbc_all_rx_clk2 = ( (fnl_sup_mode == "engineering_mode")  &&  (fnl_rate_match == "dis_rm")) ? ("rcvd_clk_clk2")
		 : ( (fnl_sup_mode == "engineering_mode")  &&  (fnl_rate_match != "dis_rm")) ? ("(tx_pma_clock_clk2,refclk_dig2_clk2)")
			 : ( (fnl_tx_rx_parallel_loopback == "en_plpbk") || (fnl_rate_match != "dis_rm") ) ? ("tx_pma_clock_clk2") : "rcvd_clk_clk2";
	localparam rbc_any_rx_clk2 = ( (fnl_sup_mode == "engineering_mode")  &&  (fnl_rate_match == "dis_rm")) ? ("rcvd_clk_clk2")
		 : ( (fnl_sup_mode == "engineering_mode")  &&  (fnl_rate_match != "dis_rm")) ? ("tx_pma_clock_clk2")
			 : ( (fnl_tx_rx_parallel_loopback == "en_plpbk") || (fnl_rate_match != "dis_rm") ) ? ("tx_pma_clock_clk2") : "rcvd_clk_clk2";
	localparam fnl_rx_clk2 = (rx_clk2 == "<auto_any>" || rx_clk2 == "<auto_single>") ? rbc_any_rx_clk2 : rx_clk2;

	// rx_wr_clk, RBC-validated
	localparam rbc_all_rx_wr_clk = ( fnl_hip_mode == "en_hip" ) ? ("txfifo_rd_clk") : "rx_clk2_div_1_2_4";
	localparam rbc_any_rx_wr_clk = ( fnl_hip_mode == "en_hip" ) ? ("txfifo_rd_clk") : "rx_clk2_div_1_2_4";
	localparam fnl_rx_wr_clk = (rx_wr_clk == "<auto_any>" || rx_wr_clk == "<auto_single>") ? rbc_any_rx_wr_clk : rx_wr_clk;

	// rx_rd_clk, RBC-validated
	localparam rbc_all_rx_rd_clk = ( fnl_phase_compensation_fifo == "register_fifo"  ||  fnl_test_mode == "bist"   ) ? ("rx_clk") : "pld_rx_clk";
	localparam rbc_any_rx_rd_clk = ( fnl_phase_compensation_fifo == "register_fifo"  ||  fnl_test_mode == "bist"   ) ? ("rx_clk") : "pld_rx_clk";
	localparam fnl_rx_rd_clk = (rx_rd_clk == "<auto_any>" || rx_rd_clk == "<auto_single>") ? rbc_any_rx_rd_clk : rx_rd_clk;

	// clock_gate_bist, RBC-validated
	localparam rbc_all_clock_gate_bist = (fnl_test_mode != "bist" ) ? ("en_bist_clk_gating") : "dis_bist_clk_gating";
	localparam rbc_any_clock_gate_bist = (fnl_test_mode != "bist" ) ? ("en_bist_clk_gating") : "dis_bist_clk_gating";
	localparam fnl_clock_gate_bist = (clock_gate_bist == "<auto_any>" || clock_gate_bist == "<auto_single>") ? rbc_any_clock_gate_bist : clock_gate_bist;

	// clock_gate_sw_wa, RBC-validated
	localparam rbc_all_clock_gate_sw_wa = (fnl_prot_mode == "disabled_prot_mode" ) ? ("en_sw_wa_clk_gating") : "dis_sw_wa_clk_gating";
	localparam rbc_any_clock_gate_sw_wa = (fnl_prot_mode == "disabled_prot_mode" ) ? ("en_sw_wa_clk_gating") : "dis_sw_wa_clk_gating";
	localparam fnl_clock_gate_sw_wa = (clock_gate_sw_wa == "<auto_any>" || clock_gate_sw_wa == "<auto_single>") ? rbc_any_clock_gate_sw_wa : clock_gate_sw_wa;

	// clock_gate_dw_wa, RBC-validated
	localparam rbc_all_clock_gate_dw_wa = ((fnl_pma_dw == "eight_bit") || (fnl_pma_dw == "ten_bit")) ? ("en_dw_wa_clk_gating") : "dis_dw_wa_clk_gating";
	localparam rbc_any_clock_gate_dw_wa = ((fnl_pma_dw == "eight_bit") || (fnl_pma_dw == "ten_bit")) ? ("en_dw_wa_clk_gating") : "dis_dw_wa_clk_gating";
	localparam fnl_clock_gate_dw_wa = (clock_gate_dw_wa == "<auto_any>" || clock_gate_dw_wa == "<auto_single>") ? rbc_any_clock_gate_dw_wa : clock_gate_dw_wa;

	// clock_gate_sw_dskw_wr, RBC-validated
	localparam rbc_all_clock_gate_sw_dskw_wr = (fnl_deskew == "dis_deskew"  ) ? ("en_sw_dskw_wrclk_gating") : "dis_sw_dskw_wrclk_gating";
	localparam rbc_any_clock_gate_sw_dskw_wr = (fnl_deskew == "dis_deskew"  ) ? ("en_sw_dskw_wrclk_gating") : "dis_sw_dskw_wrclk_gating";
	localparam fnl_clock_gate_sw_dskw_wr = (clock_gate_sw_dskw_wr == "<auto_any>" || clock_gate_sw_dskw_wr == "<auto_single>") ? rbc_any_clock_gate_sw_dskw_wr : clock_gate_sw_dskw_wr;

	// clock_gate_dw_dskw_wr, RBC-validated
	localparam rbc_all_clock_gate_dw_dskw_wr = (fnl_deskew != "en_srio_v2p1") ? ("en_dw_dskw_wrclk_gating") : "dis_dw_dskw_wrclk_gating";
	localparam rbc_any_clock_gate_dw_dskw_wr = (fnl_deskew != "en_srio_v2p1") ? ("en_dw_dskw_wrclk_gating") : "dis_dw_dskw_wrclk_gating";
	localparam fnl_clock_gate_dw_dskw_wr = (clock_gate_dw_dskw_wr == "<auto_any>" || clock_gate_dw_dskw_wr == "<auto_single>") ? rbc_any_clock_gate_dw_dskw_wr : clock_gate_dw_dskw_wr;

	// clock_gate_prbs, RBC-validated
	localparam rbc_all_clock_gate_prbs = (fnl_test_mode != "prbs" ) ? ("en_prbs_clk_gating") : "dis_prbs_clk_gating";
	localparam rbc_any_clock_gate_prbs = (fnl_test_mode != "prbs" ) ? ("en_prbs_clk_gating") : "dis_prbs_clk_gating";
	localparam fnl_clock_gate_prbs = (clock_gate_prbs == "<auto_any>" || clock_gate_prbs == "<auto_single>") ? rbc_any_clock_gate_prbs : clock_gate_prbs;

	// clock_gate_cdr_eidle, RBC-validated
	localparam rbc_all_clock_gate_cdr_eidle = ((fnl_prot_mode != "pipe_g1" ) && (fnl_prot_mode != "pipe_g2")) ? ("en_cdr_eidle_clk_gating") : "dis_cdr_eidle_clk_gating";
	localparam rbc_any_clock_gate_cdr_eidle = ((fnl_prot_mode != "pipe_g1" ) && (fnl_prot_mode != "pipe_g2")) ? ("en_cdr_eidle_clk_gating") : "dis_cdr_eidle_clk_gating";
	localparam fnl_clock_gate_cdr_eidle = (clock_gate_cdr_eidle == "<auto_any>" || clock_gate_cdr_eidle == "<auto_single>") ? rbc_any_clock_gate_cdr_eidle : clock_gate_cdr_eidle;

	// clock_gate_dskw_rd, RBC-validated
	localparam rbc_all_clock_gate_dskw_rd = (fnl_deskew == "dis_deskew") ? ("en_dskw_rdclk_gating") : "dis_dskw_rdclk_gating";
	localparam rbc_any_clock_gate_dskw_rd = (fnl_deskew == "dis_deskew") ? ("en_dskw_rdclk_gating") : "dis_dskw_rdclk_gating";
	localparam fnl_clock_gate_dskw_rd = (clock_gate_dskw_rd == "<auto_any>" || clock_gate_dskw_rd == "<auto_single>") ? rbc_any_clock_gate_dskw_rd : clock_gate_dskw_rd;

	// clock_gate_sw_rm_wr, RBC-validated
	localparam rbc_all_clock_gate_sw_rm_wr = (fnl_rate_match == "dis_rm" ) ? ("en_sw_rm_wrclk_gating") : "dis_sw_rm_wrclk_gating";
	localparam rbc_any_clock_gate_sw_rm_wr = (fnl_rate_match == "dis_rm" ) ? ("en_sw_rm_wrclk_gating") : "dis_sw_rm_wrclk_gating";
	localparam fnl_clock_gate_sw_rm_wr = (clock_gate_sw_rm_wr == "<auto_any>" || clock_gate_sw_rm_wr == "<auto_single>") ? rbc_any_clock_gate_sw_rm_wr : clock_gate_sw_rm_wr;

	// clock_gate_sw_rm_rd, RBC-validated
	localparam rbc_all_clock_gate_sw_rm_rd = (fnl_rate_match == "dis_rm" ) ? ("en_sw_rm_rdclk_gating") : "dis_sw_rm_rdclk_gating";
	localparam rbc_any_clock_gate_sw_rm_rd = (fnl_rate_match == "dis_rm" ) ? ("en_sw_rm_rdclk_gating") : "dis_sw_rm_rdclk_gating";
	localparam fnl_clock_gate_sw_rm_rd = (clock_gate_sw_rm_rd == "<auto_any>" || clock_gate_sw_rm_rd == "<auto_single>") ? rbc_any_clock_gate_sw_rm_rd : clock_gate_sw_rm_rd;

	// clock_gate_dw_rm_rd, RBC-validated
	localparam rbc_all_clock_gate_dw_rm_rd = ((fnl_rate_match != "dw_basic_rm") && (fnl_rate_match != "srio_v2p1_rm") && (fnl_rate_match != "srio_v2p1_rm_0ppm")) ? ("en_dw_rm_rdclk_gating") : "dis_dw_rm_rdclk_gating";
	localparam rbc_any_clock_gate_dw_rm_rd = ((fnl_rate_match != "dw_basic_rm") && (fnl_rate_match != "srio_v2p1_rm") && (fnl_rate_match != "srio_v2p1_rm_0ppm")) ? ("en_dw_rm_rdclk_gating") : "dis_dw_rm_rdclk_gating";
	localparam fnl_clock_gate_dw_rm_rd = (clock_gate_dw_rm_rd == "<auto_any>" || clock_gate_dw_rm_rd == "<auto_single>") ? rbc_any_clock_gate_dw_rm_rd : clock_gate_dw_rm_rd;

	// clock_gate_dw_rm_wr, RBC-validated
	localparam rbc_all_clock_gate_dw_rm_wr = ((fnl_rate_match != "dw_basic_rm") && (fnl_rate_match != "srio_v2p1_rm") && (fnl_rate_match != "srio_v2p1_rm_0ppm")) ? ("en_dw_rm_wrclk_gating") : "dis_dw_rm_wrclk_gating";
	localparam rbc_any_clock_gate_dw_rm_wr = ((fnl_rate_match != "dw_basic_rm") && (fnl_rate_match != "srio_v2p1_rm") && (fnl_rate_match != "srio_v2p1_rm_0ppm")) ? ("en_dw_rm_wrclk_gating") : "dis_dw_rm_wrclk_gating";
	localparam fnl_clock_gate_dw_rm_wr = (clock_gate_dw_rm_wr == "<auto_any>" || clock_gate_dw_rm_wr == "<auto_single>") ? rbc_any_clock_gate_dw_rm_wr : clock_gate_dw_rm_wr;

	// clock_gate_bds_dec_asn, RBC-validated
	localparam rbc_all_clock_gate_bds_dec_asn = (fnl_prot_mode == "disabled_prot_mode" ) ? ("en_bds_dec_asn_clk_gating") : "dis_bds_dec_asn_clk_gating";
	localparam rbc_any_clock_gate_bds_dec_asn = (fnl_prot_mode == "disabled_prot_mode" ) ? ("en_bds_dec_asn_clk_gating") : "dis_bds_dec_asn_clk_gating";
	localparam fnl_clock_gate_bds_dec_asn = (clock_gate_bds_dec_asn == "<auto_any>" || clock_gate_bds_dec_asn == "<auto_single>") ? rbc_any_clock_gate_bds_dec_asn : clock_gate_bds_dec_asn;

	// clock_gate_byteorder, RBC-validated
	localparam rbc_all_clock_gate_byteorder = ( (fnl_prot_mode == "disabled_prot_mode" ) || (fnl_pcs_bypass == "en_pcs_bypass") ) ? ("en_byteorder_clk_gating") : "dis_byteorder_clk_gating";
	localparam rbc_any_clock_gate_byteorder = ( (fnl_prot_mode == "disabled_prot_mode" ) || (fnl_pcs_bypass == "en_pcs_bypass") ) ? ("en_byteorder_clk_gating") : "dis_byteorder_clk_gating";
	localparam fnl_clock_gate_byteorder = (clock_gate_byteorder == "<auto_any>" || clock_gate_byteorder == "<auto_single>") ? rbc_any_clock_gate_byteorder : clock_gate_byteorder;

	// clock_gate_sw_pc_wrclk, RBC-validated
	localparam rbc_all_clock_gate_sw_pc_wrclk = (fnl_prot_mode == "disabled_prot_mode") ? ("en_sw_pc_wrclk_gating") : "dis_sw_pc_wrclk_gating";
	localparam rbc_any_clock_gate_sw_pc_wrclk = (fnl_prot_mode == "disabled_prot_mode") ? ("en_sw_pc_wrclk_gating") : "dis_sw_pc_wrclk_gating";
	localparam fnl_clock_gate_sw_pc_wrclk = (clock_gate_sw_pc_wrclk == "<auto_any>" || clock_gate_sw_pc_wrclk == "<auto_single>") ? rbc_any_clock_gate_sw_pc_wrclk : clock_gate_sw_pc_wrclk;

	// clock_gate_dw_pc_wrclk, RBC-validated
	localparam rbc_all_clock_gate_dw_pc_wrclk = ( (fnl_prot_mode == "disabled_prot_mode") || (fnl_phase_compensation_fifo == "register_fifo") || (fnl_pma_dw == "ten_bit") || (fnl_pma_dw == "eight_bit") ) ? ("en_dw_pc_wrclk_gating") : "dis_dw_pc_wrclk_gating";
	localparam rbc_any_clock_gate_dw_pc_wrclk = ( (fnl_prot_mode == "disabled_prot_mode") || (fnl_phase_compensation_fifo == "register_fifo") || (fnl_pma_dw == "ten_bit") || (fnl_pma_dw == "eight_bit") ) ? ("en_dw_pc_wrclk_gating") : "dis_dw_pc_wrclk_gating";
	localparam fnl_clock_gate_dw_pc_wrclk = (clock_gate_dw_pc_wrclk == "<auto_any>" || clock_gate_dw_pc_wrclk == "<auto_single>") ? rbc_any_clock_gate_dw_pc_wrclk : clock_gate_dw_pc_wrclk;

	// clock_gate_pc_rdclk, RBC-validated
	localparam rbc_all_clock_gate_pc_rdclk = (fnl_prot_mode == "disabled_prot_mode") ? ("en_pc_rdclk_gating") : "dis_pc_rdclk_gating";
	localparam rbc_any_clock_gate_pc_rdclk = (fnl_prot_mode == "disabled_prot_mode") ? ("en_pc_rdclk_gating") : "dis_pc_rdclk_gating";
	localparam fnl_clock_gate_pc_rdclk = (clock_gate_pc_rdclk == "<auto_any>" || clock_gate_pc_rdclk == "<auto_single>") ? rbc_any_clock_gate_pc_rdclk : clock_gate_pc_rdclk;

	// rx_pcs_urst, RBC-validated
	localparam rbc_all_rx_pcs_urst = "en_rx_pcs_urst";
	localparam rbc_any_rx_pcs_urst = "en_rx_pcs_urst";
	localparam fnl_rx_pcs_urst = (rx_pcs_urst == "<auto_any>" || rx_pcs_urst == "<auto_single>") ? rbc_any_rx_pcs_urst : rx_pcs_urst;

	// rx_clk_free_running, RBC-validated
	localparam rbc_all_rx_clk_free_running = "en_rx_clk_free_run";
	localparam rbc_any_rx_clk_free_running = "en_rx_clk_free_run";
	localparam fnl_rx_clk_free_running = (rx_clk_free_running == "<auto_any>" || rx_clk_free_running == "<auto_single>") ? rbc_any_rx_clk_free_running : rx_clk_free_running;

	// comp_fifo_rst_pld_ctrl, RBC-validated
	localparam rbc_all_comp_fifo_rst_pld_ctrl = "dis_comp_fifo_rst_pld_ctrl";
	localparam rbc_any_comp_fifo_rst_pld_ctrl = "dis_comp_fifo_rst_pld_ctrl";
	localparam fnl_comp_fifo_rst_pld_ctrl = (comp_fifo_rst_pld_ctrl == "<auto_any>" || comp_fifo_rst_pld_ctrl == "<auto_single>") ? rbc_any_comp_fifo_rst_pld_ctrl : comp_fifo_rst_pld_ctrl;

	// pc_fifo_rst_pld_ctrl, RBC-validated
	localparam rbc_all_pc_fifo_rst_pld_ctrl = "dis_pc_fifo_rst_pld_ctrl";
	localparam rbc_any_pc_fifo_rst_pld_ctrl = "dis_pc_fifo_rst_pld_ctrl";
	localparam fnl_pc_fifo_rst_pld_ctrl = (pc_fifo_rst_pld_ctrl == "<auto_any>" || pc_fifo_rst_pld_ctrl == "<auto_single>") ? rbc_any_pc_fifo_rst_pld_ctrl : pc_fifo_rst_pld_ctrl;

	// test_bus_sel, RBC-validated
	localparam rbc_all_test_bus_sel = (fnl_sup_mode == "user_mode") ? ("tx_testbus") : "(agg_testbus,deskew_testbus,pcie_ctrl_testbus,prbs_bist_testbus,rm_testbus,rx_ctrl_plane_testbus,rx_ctrl_testbus,tx_ctrl_plane_testbus,tx_testbus,wa_testbus)";
	localparam rbc_any_test_bus_sel = (fnl_sup_mode == "user_mode") ? ("tx_testbus") : "prbs_bist_testbus";
	localparam fnl_test_bus_sel = (test_bus_sel == "<auto_any>" || test_bus_sel == "<auto_single>") ? rbc_any_test_bus_sel : test_bus_sel;

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
		//$display("pcs_bypass = orig: '%s', any:'%s', all:'%s', final: '%s'", pcs_bypass, rbc_any_pcs_bypass, rbc_all_pcs_bypass, fnl_pcs_bypass);
		if (!is_in_legal_set(pcs_bypass, rbc_all_pcs_bypass)) begin
			$display("Critical Warning: parameter 'pcs_bypass' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", pcs_bypass, rbc_all_pcs_bypass, fnl_pcs_bypass);
		end
		//$display("pma_dw = orig: '%s', any:'%s', all:'%s', final: '%s'", pma_dw, rbc_any_pma_dw, rbc_all_pma_dw, fnl_pma_dw);
		if (!is_in_legal_set(pma_dw, rbc_all_pma_dw)) begin
			$display("Critical Warning: parameter 'pma_dw' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", pma_dw, rbc_all_pma_dw, fnl_pma_dw);
		end
		//$display("pipe_if_enable = orig: '%s', any:'%s', all:'%s', final: '%s'", pipe_if_enable, rbc_any_pipe_if_enable, rbc_all_pipe_if_enable, fnl_pipe_if_enable);
		if (!is_in_legal_set(pipe_if_enable, rbc_all_pipe_if_enable)) begin
			$display("Critical Warning: parameter 'pipe_if_enable' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", pipe_if_enable, rbc_all_pipe_if_enable, fnl_pipe_if_enable);
		end
		//$display("prbs_ver = orig: '%s', any:'%s', all:'%s', final: '%s'", prbs_ver, rbc_any_prbs_ver, rbc_all_prbs_ver, fnl_prbs_ver);
		if (!is_in_legal_set(prbs_ver, rbc_all_prbs_ver)) begin
			$display("Critical Warning: parameter 'prbs_ver' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", prbs_ver, rbc_all_prbs_ver, fnl_prbs_ver);
		end
		//$display("wa_boundary_lock_ctrl = orig: '%s', any:'%s', all:'%s', final: '%s'", wa_boundary_lock_ctrl, rbc_any_wa_boundary_lock_ctrl, rbc_all_wa_boundary_lock_ctrl, fnl_wa_boundary_lock_ctrl);
		if (!is_in_legal_set(wa_boundary_lock_ctrl, rbc_all_wa_boundary_lock_ctrl)) begin
			$display("Critical Warning: parameter 'wa_boundary_lock_ctrl' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", wa_boundary_lock_ctrl, rbc_all_wa_boundary_lock_ctrl, fnl_wa_boundary_lock_ctrl);
		end
		//$display("wa_pld_controlled = orig: '%s', any:'%s', all:'%s', final: '%s'", wa_pld_controlled, rbc_any_wa_pld_controlled, rbc_all_wa_pld_controlled, fnl_wa_pld_controlled);
		if (!is_in_legal_set(wa_pld_controlled, rbc_all_wa_pld_controlled)) begin
			$display("Critical Warning: parameter 'wa_pld_controlled' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", wa_pld_controlled, rbc_all_wa_pld_controlled, fnl_wa_pld_controlled);
		end
		//$display("wa_pd_polarity = orig: '%s', any:'%s', all:'%s', final: '%s'", wa_pd_polarity, rbc_any_wa_pd_polarity, rbc_all_wa_pd_polarity, fnl_wa_pd_polarity);
		if (!is_in_legal_set(wa_pd_polarity, rbc_all_wa_pd_polarity)) begin
			$display("Critical Warning: parameter 'wa_pd_polarity' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", wa_pd_polarity, rbc_all_wa_pd_polarity, fnl_wa_pd_polarity);
		end
		//$display("wa_pd = orig: '%s', any:'%s', all:'%s', final: '%s'", wa_pd, rbc_any_wa_pd, rbc_all_wa_pd, fnl_wa_pd);
		if (!is_in_legal_set(wa_pd, rbc_all_wa_pd)) begin
			$display("Critical Warning: parameter 'wa_pd' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", wa_pd, rbc_all_wa_pd, fnl_wa_pd);
		end
		//$display("wa_sync_sm_ctrl = orig: '%s', any:'%s', all:'%s', final: '%s'", wa_sync_sm_ctrl, rbc_any_wa_sync_sm_ctrl, rbc_all_wa_sync_sm_ctrl, fnl_wa_sync_sm_ctrl);
		if (!is_in_legal_set(wa_sync_sm_ctrl, rbc_all_wa_sync_sm_ctrl)) begin
			$display("Critical Warning: parameter 'wa_sync_sm_ctrl' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", wa_sync_sm_ctrl, rbc_all_wa_sync_sm_ctrl, fnl_wa_sync_sm_ctrl);
		end
		//$display("wa_kchar = orig: '%s', any:'%s', all:'%s', final: '%s'", wa_kchar, rbc_any_wa_kchar, rbc_all_wa_kchar, fnl_wa_kchar);
		if (!is_in_legal_set(wa_kchar, rbc_all_wa_kchar)) begin
			$display("Critical Warning: parameter 'wa_kchar' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", wa_kchar, rbc_all_wa_kchar, fnl_wa_kchar);
		end
		//$display("fixed_pat_det = orig: '%s', any:'%s', all:'%s', final: '%s'", fixed_pat_det, rbc_any_fixed_pat_det, rbc_all_fixed_pat_det, fnl_fixed_pat_det);
		if (!is_in_legal_set(fixed_pat_det, rbc_all_fixed_pat_det)) begin
			$display("Critical Warning: parameter 'fixed_pat_det' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", fixed_pat_det, rbc_all_fixed_pat_det, fnl_fixed_pat_det);
		end
		//$display("ibm_invalid_code = orig: '%s', any:'%s', all:'%s', final: '%s'", ibm_invalid_code, rbc_any_ibm_invalid_code, rbc_all_ibm_invalid_code, fnl_ibm_invalid_code);
		if (!is_in_legal_set(ibm_invalid_code, rbc_all_ibm_invalid_code)) begin
			$display("Critical Warning: parameter 'ibm_invalid_code' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", ibm_invalid_code, rbc_all_ibm_invalid_code, fnl_ibm_invalid_code);
		end
		//$display("force_signal_detect = orig: '%s', any:'%s', all:'%s', final: '%s'", force_signal_detect, rbc_any_force_signal_detect, rbc_all_force_signal_detect, fnl_force_signal_detect);
		if (!is_in_legal_set(force_signal_detect, rbc_all_force_signal_detect)) begin
			$display("Critical Warning: parameter 'force_signal_detect' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", force_signal_detect, rbc_all_force_signal_detect, fnl_force_signal_detect);
		end
		//$display("wa_det_latency_sync_status_beh = orig: '%s', any:'%s', all:'%s', final: '%s'", wa_det_latency_sync_status_beh, rbc_any_wa_det_latency_sync_status_beh, rbc_all_wa_det_latency_sync_status_beh, fnl_wa_det_latency_sync_status_beh);
		if (!is_in_legal_set(wa_det_latency_sync_status_beh, rbc_all_wa_det_latency_sync_status_beh)) begin
			$display("Critical Warning: parameter 'wa_det_latency_sync_status_beh' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", wa_det_latency_sync_status_beh, rbc_all_wa_det_latency_sync_status_beh, fnl_wa_det_latency_sync_status_beh);
		end
		//$display("wa_clk_slip_spacing = orig: '%s', any:'%s', all:'%s', final: '%s'", wa_clk_slip_spacing, rbc_any_wa_clk_slip_spacing, rbc_all_wa_clk_slip_spacing, fnl_wa_clk_slip_spacing);
		if (!is_in_legal_set(wa_clk_slip_spacing, rbc_all_wa_clk_slip_spacing)) begin
			$display("Critical Warning: parameter 'wa_clk_slip_spacing' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", wa_clk_slip_spacing, rbc_all_wa_clk_slip_spacing, fnl_wa_clk_slip_spacing);
		end
		//$display("eightb_tenb_decoder = orig: '%s', any:'%s', all:'%s', final: '%s'", eightb_tenb_decoder, rbc_any_eightb_tenb_decoder, rbc_all_eightb_tenb_decoder, fnl_eightb_tenb_decoder);
		if (!is_in_legal_set(eightb_tenb_decoder, rbc_all_eightb_tenb_decoder)) begin
			$display("Critical Warning: parameter 'eightb_tenb_decoder' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", eightb_tenb_decoder, rbc_all_eightb_tenb_decoder, fnl_eightb_tenb_decoder);
		end
		//$display("wa_disp_err_flag = orig: '%s', any:'%s', all:'%s', final: '%s'", wa_disp_err_flag, rbc_any_wa_disp_err_flag, rbc_all_wa_disp_err_flag, fnl_wa_disp_err_flag);
		if (!is_in_legal_set(wa_disp_err_flag, rbc_all_wa_disp_err_flag)) begin
			$display("Critical Warning: parameter 'wa_disp_err_flag' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", wa_disp_err_flag, rbc_all_wa_disp_err_flag, fnl_wa_disp_err_flag);
		end
		//$display("polarity_inversion = orig: '%s', any:'%s', all:'%s', final: '%s'", polarity_inversion, rbc_any_polarity_inversion, rbc_all_polarity_inversion, fnl_polarity_inversion);
		if (!is_in_legal_set(polarity_inversion, rbc_all_polarity_inversion)) begin
			$display("Critical Warning: parameter 'polarity_inversion' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", polarity_inversion, rbc_all_polarity_inversion, fnl_polarity_inversion);
		end
		//$display("bit_reversal = orig: '%s', any:'%s', all:'%s', final: '%s'", bit_reversal, rbc_any_bit_reversal, rbc_all_bit_reversal, fnl_bit_reversal);
		if (!is_in_legal_set(bit_reversal, rbc_all_bit_reversal)) begin
			$display("Critical Warning: parameter 'bit_reversal' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", bit_reversal, rbc_all_bit_reversal, fnl_bit_reversal);
		end
		//$display("symbol_swap = orig: '%s', any:'%s', all:'%s', final: '%s'", symbol_swap, rbc_any_symbol_swap, rbc_all_symbol_swap, fnl_symbol_swap);
		if (!is_in_legal_set(symbol_swap, rbc_all_symbol_swap)) begin
			$display("Critical Warning: parameter 'symbol_swap' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", symbol_swap, rbc_all_symbol_swap, fnl_symbol_swap);
		end
		//$display("runlength_check = orig: '%s', any:'%s', all:'%s', final: '%s'", runlength_check, rbc_any_runlength_check, rbc_all_runlength_check, fnl_runlength_check);
		if (!is_in_legal_set(runlength_check, rbc_all_runlength_check)) begin
			$display("Critical Warning: parameter 'runlength_check' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", runlength_check, rbc_all_runlength_check, fnl_runlength_check);
		end
		//$display("ctrl_plane_bonding_consumption = orig: '%s', any:'%s', all:'%s', final: '%s'", ctrl_plane_bonding_consumption, rbc_any_ctrl_plane_bonding_consumption, rbc_all_ctrl_plane_bonding_consumption, fnl_ctrl_plane_bonding_consumption);
		if (!is_in_legal_set(ctrl_plane_bonding_consumption, rbc_all_ctrl_plane_bonding_consumption)) begin
			$display("Critical Warning: parameter 'ctrl_plane_bonding_consumption' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", ctrl_plane_bonding_consumption, rbc_all_ctrl_plane_bonding_consumption, fnl_ctrl_plane_bonding_consumption);
		end
		//$display("deskew = orig: '%s', any:'%s', all:'%s', final: '%s'", deskew, rbc_any_deskew, rbc_all_deskew, fnl_deskew);
		if (!is_in_legal_set(deskew, rbc_all_deskew)) begin
			$display("Critical Warning: parameter 'deskew' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", deskew, rbc_all_deskew, fnl_deskew);
		end
		//$display("deskew_prog_pattern_only = orig: '%s', any:'%s', all:'%s', final: '%s'", deskew_prog_pattern_only, rbc_any_deskew_prog_pattern_only, rbc_all_deskew_prog_pattern_only, fnl_deskew_prog_pattern_only);
		if (!is_in_legal_set(deskew_prog_pattern_only, rbc_all_deskew_prog_pattern_only)) begin
			$display("Critical Warning: parameter 'deskew_prog_pattern_only' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", deskew_prog_pattern_only, rbc_all_deskew_prog_pattern_only, fnl_deskew_prog_pattern_only);
		end
		//$display("rate_match = orig: '%s', any:'%s', all:'%s', final: '%s'", rate_match, rbc_any_rate_match, rbc_all_rate_match, fnl_rate_match);
		if (!is_in_legal_set(rate_match, rbc_all_rate_match)) begin
			$display("Critical Warning: parameter 'rate_match' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", rate_match, rbc_all_rate_match, fnl_rate_match);
		end
		//$display("err_flags_sel = orig: '%s', any:'%s', all:'%s', final: '%s'", err_flags_sel, rbc_any_err_flags_sel, rbc_all_err_flags_sel, fnl_err_flags_sel);
		if (!is_in_legal_set(err_flags_sel, rbc_all_err_flags_sel)) begin
			$display("Critical Warning: parameter 'err_flags_sel' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", err_flags_sel, rbc_all_err_flags_sel, fnl_err_flags_sel);
		end
		//$display("polinv_8b10b_dec = orig: '%s', any:'%s', all:'%s', final: '%s'", polinv_8b10b_dec, rbc_any_polinv_8b10b_dec, rbc_all_polinv_8b10b_dec, fnl_polinv_8b10b_dec);
		if (!is_in_legal_set(polinv_8b10b_dec, rbc_all_polinv_8b10b_dec)) begin
			$display("Critical Warning: parameter 'polinv_8b10b_dec' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", polinv_8b10b_dec, rbc_all_polinv_8b10b_dec, fnl_polinv_8b10b_dec);
		end
		//$display("eightbtenb_decoder_output_sel = orig: '%s', any:'%s', all:'%s', final: '%s'", eightbtenb_decoder_output_sel, rbc_any_eightbtenb_decoder_output_sel, rbc_all_eightbtenb_decoder_output_sel, fnl_eightbtenb_decoder_output_sel);
		if (!is_in_legal_set(eightbtenb_decoder_output_sel, rbc_all_eightbtenb_decoder_output_sel)) begin
			$display("Critical Warning: parameter 'eightbtenb_decoder_output_sel' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", eightbtenb_decoder_output_sel, rbc_all_eightbtenb_decoder_output_sel, fnl_eightbtenb_decoder_output_sel);
		end
		//$display("invalid_code_flag_only = orig: '%s', any:'%s', all:'%s', final: '%s'", invalid_code_flag_only, rbc_any_invalid_code_flag_only, rbc_all_invalid_code_flag_only, fnl_invalid_code_flag_only);
		if (!is_in_legal_set(invalid_code_flag_only, rbc_all_invalid_code_flag_only)) begin
			$display("Critical Warning: parameter 'invalid_code_flag_only' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", invalid_code_flag_only, rbc_all_invalid_code_flag_only, fnl_invalid_code_flag_only);
		end
		//$display("auto_error_replacement = orig: '%s', any:'%s', all:'%s', final: '%s'", auto_error_replacement, rbc_any_auto_error_replacement, rbc_all_auto_error_replacement, fnl_auto_error_replacement);
		if (!is_in_legal_set(auto_error_replacement, rbc_all_auto_error_replacement)) begin
			$display("Critical Warning: parameter 'auto_error_replacement' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", auto_error_replacement, rbc_all_auto_error_replacement, fnl_auto_error_replacement);
		end
		//$display("pad_or_edb_error_replace = orig: '%s', any:'%s', all:'%s', final: '%s'", pad_or_edb_error_replace, rbc_any_pad_or_edb_error_replace, rbc_all_pad_or_edb_error_replace, fnl_pad_or_edb_error_replace);
		if (!is_in_legal_set(pad_or_edb_error_replace, rbc_all_pad_or_edb_error_replace)) begin
			$display("Critical Warning: parameter 'pad_or_edb_error_replace' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", pad_or_edb_error_replace, rbc_all_pad_or_edb_error_replace, fnl_pad_or_edb_error_replace);
		end
		//$display("byte_deserializer = orig: '%s', any:'%s', all:'%s', final: '%s'", byte_deserializer, rbc_any_byte_deserializer, rbc_all_byte_deserializer, fnl_byte_deserializer);
		if (!is_in_legal_set(byte_deserializer, rbc_all_byte_deserializer)) begin
			$display("Critical Warning: parameter 'byte_deserializer' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", byte_deserializer, rbc_all_byte_deserializer, fnl_byte_deserializer);
		end
		//$display("byte_order = orig: '%s', any:'%s', all:'%s', final: '%s'", byte_order, rbc_any_byte_order, rbc_all_byte_order, fnl_byte_order);
		if (!is_in_legal_set(byte_order, rbc_all_byte_order)) begin
			$display("Critical Warning: parameter 'byte_order' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", byte_order, rbc_all_byte_order, fnl_byte_order);
		end
		//$display("dw_one_or_two_symbol_bo = orig: '%s', any:'%s', all:'%s', final: '%s'", dw_one_or_two_symbol_bo, rbc_any_dw_one_or_two_symbol_bo, rbc_all_dw_one_or_two_symbol_bo, fnl_dw_one_or_two_symbol_bo);
		if (!is_in_legal_set(dw_one_or_two_symbol_bo, rbc_all_dw_one_or_two_symbol_bo)) begin
			$display("Critical Warning: parameter 'dw_one_or_two_symbol_bo' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", dw_one_or_two_symbol_bo, rbc_all_dw_one_or_two_symbol_bo, fnl_dw_one_or_two_symbol_bo);
		end
		//$display("re_bo_on_wa = orig: '%s', any:'%s', all:'%s', final: '%s'", re_bo_on_wa, rbc_any_re_bo_on_wa, rbc_all_re_bo_on_wa, fnl_re_bo_on_wa);
		if (!is_in_legal_set(re_bo_on_wa, rbc_all_re_bo_on_wa)) begin
			$display("Critical Warning: parameter 're_bo_on_wa' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", re_bo_on_wa, rbc_all_re_bo_on_wa, fnl_re_bo_on_wa);
		end
		//$display("phase_compensation_fifo = orig: '%s', any:'%s', all:'%s', final: '%s'", phase_compensation_fifo, rbc_any_phase_compensation_fifo, rbc_all_phase_compensation_fifo, fnl_phase_compensation_fifo);
		if (!is_in_legal_set(phase_compensation_fifo, rbc_all_phase_compensation_fifo)) begin
			$display("Critical Warning: parameter 'phase_compensation_fifo' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", phase_compensation_fifo, rbc_all_phase_compensation_fifo, fnl_phase_compensation_fifo);
		end
		//$display("tx_rx_parallel_loopback = orig: '%s', any:'%s', all:'%s', final: '%s'", tx_rx_parallel_loopback, rbc_any_tx_rx_parallel_loopback, rbc_all_tx_rx_parallel_loopback, fnl_tx_rx_parallel_loopback);
		if (!is_in_legal_set(tx_rx_parallel_loopback, rbc_all_tx_rx_parallel_loopback)) begin
			$display("Critical Warning: parameter 'tx_rx_parallel_loopback' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", tx_rx_parallel_loopback, rbc_all_tx_rx_parallel_loopback, fnl_tx_rx_parallel_loopback);
		end
		//$display("prbs_ver_clr_flag = orig: '%s', any:'%s', all:'%s', final: '%s'", prbs_ver_clr_flag, rbc_any_prbs_ver_clr_flag, rbc_all_prbs_ver_clr_flag, fnl_prbs_ver_clr_flag);
		if (!is_in_legal_set(prbs_ver_clr_flag, rbc_all_prbs_ver_clr_flag)) begin
			$display("Critical Warning: parameter 'prbs_ver_clr_flag' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", prbs_ver_clr_flag, rbc_all_prbs_ver_clr_flag, fnl_prbs_ver_clr_flag);
		end
		//$display("cid_pattern = orig: '%s', any:'%s', all:'%s', final: '%s'", cid_pattern, rbc_any_cid_pattern, rbc_all_cid_pattern, fnl_cid_pattern);
		if (!is_in_legal_set(cid_pattern, rbc_all_cid_pattern)) begin
			$display("Critical Warning: parameter 'cid_pattern' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", cid_pattern, rbc_all_cid_pattern, fnl_cid_pattern);
		end
		//$display("bist_ver = orig: '%s', any:'%s', all:'%s', final: '%s'", bist_ver, rbc_any_bist_ver, rbc_all_bist_ver, fnl_bist_ver);
		if (!is_in_legal_set(bist_ver, rbc_all_bist_ver)) begin
			$display("Critical Warning: parameter 'bist_ver' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", bist_ver, rbc_all_bist_ver, fnl_bist_ver);
		end
		//$display("bist_ver_clr_flag = orig: '%s', any:'%s', all:'%s', final: '%s'", bist_ver_clr_flag, rbc_any_bist_ver_clr_flag, rbc_all_bist_ver_clr_flag, fnl_bist_ver_clr_flag);
		if (!is_in_legal_set(bist_ver_clr_flag, rbc_all_bist_ver_clr_flag)) begin
			$display("Critical Warning: parameter 'bist_ver_clr_flag' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", bist_ver_clr_flag, rbc_all_bist_ver_clr_flag, fnl_bist_ver_clr_flag);
		end
		//$display("cdr_ctrl = orig: '%s', any:'%s', all:'%s', final: '%s'", cdr_ctrl, rbc_any_cdr_ctrl, rbc_all_cdr_ctrl, fnl_cdr_ctrl);
		if (!is_in_legal_set(cdr_ctrl, rbc_all_cdr_ctrl)) begin
			$display("Critical Warning: parameter 'cdr_ctrl' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", cdr_ctrl, rbc_all_cdr_ctrl, fnl_cdr_ctrl);
		end
		//$display("cdr_ctrl_rxvalid_mask = orig: '%s', any:'%s', all:'%s', final: '%s'", cdr_ctrl_rxvalid_mask, rbc_any_cdr_ctrl_rxvalid_mask, rbc_all_cdr_ctrl_rxvalid_mask, fnl_cdr_ctrl_rxvalid_mask);
		if (!is_in_legal_set(cdr_ctrl_rxvalid_mask, rbc_all_cdr_ctrl_rxvalid_mask)) begin
			$display("Critical Warning: parameter 'cdr_ctrl_rxvalid_mask' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", cdr_ctrl_rxvalid_mask, rbc_all_cdr_ctrl_rxvalid_mask, fnl_cdr_ctrl_rxvalid_mask);
		end
		//$display("auto_speed_nego = orig: '%s', any:'%s', all:'%s', final: '%s'", auto_speed_nego, rbc_any_auto_speed_nego, rbc_all_auto_speed_nego, fnl_auto_speed_nego);
		if (!is_in_legal_set(auto_speed_nego, rbc_all_auto_speed_nego)) begin
			$display("Critical Warning: parameter 'auto_speed_nego' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", auto_speed_nego, rbc_all_auto_speed_nego, fnl_auto_speed_nego);
		end
		//$display("eidle_entry_iei = orig: '%s', any:'%s', all:'%s', final: '%s'", eidle_entry_iei, rbc_any_eidle_entry_iei, rbc_all_eidle_entry_iei, fnl_eidle_entry_iei);
		if (!is_in_legal_set(eidle_entry_iei, rbc_all_eidle_entry_iei)) begin
			$display("Critical Warning: parameter 'eidle_entry_iei' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", eidle_entry_iei, rbc_all_eidle_entry_iei, fnl_eidle_entry_iei);
		end
		//$display("eidle_entry_sd = orig: '%s', any:'%s', all:'%s', final: '%s'", eidle_entry_sd, rbc_any_eidle_entry_sd, rbc_all_eidle_entry_sd, fnl_eidle_entry_sd);
		if (!is_in_legal_set(eidle_entry_sd, rbc_all_eidle_entry_sd)) begin
			$display("Critical Warning: parameter 'eidle_entry_sd' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", eidle_entry_sd, rbc_all_eidle_entry_sd, fnl_eidle_entry_sd);
		end
		//$display("eidle_entry_eios = orig: '%s', any:'%s', all:'%s', final: '%s'", eidle_entry_eios, rbc_any_eidle_entry_eios, rbc_all_eidle_entry_eios, fnl_eidle_entry_eios);
		if (!is_in_legal_set(eidle_entry_eios, rbc_all_eidle_entry_eios)) begin
			$display("Critical Warning: parameter 'eidle_entry_eios' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", eidle_entry_eios, rbc_all_eidle_entry_eios, fnl_eidle_entry_eios);
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
		//$display("rx_refclk = orig: '%s', any:'%s', all:'%s', final: '%s'", rx_refclk, rbc_any_rx_refclk, rbc_all_rx_refclk, fnl_rx_refclk);
		if (!is_in_legal_set(rx_refclk, rbc_all_rx_refclk)) begin
			$display("Critical Warning: parameter 'rx_refclk' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", rx_refclk, rbc_all_rx_refclk, fnl_rx_refclk);
		end
		//$display("rx_rcvd_clk = orig: '%s', any:'%s', all:'%s', final: '%s'", rx_rcvd_clk, rbc_any_rx_rcvd_clk, rbc_all_rx_rcvd_clk, fnl_rx_rcvd_clk);
		if (!is_in_legal_set(rx_rcvd_clk, rbc_all_rx_rcvd_clk)) begin
			$display("Critical Warning: parameter 'rx_rcvd_clk' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", rx_rcvd_clk, rbc_all_rx_rcvd_clk, fnl_rx_rcvd_clk);
		end
		//$display("agg_block_sel = orig: '%s', any:'%s', all:'%s', final: '%s'", agg_block_sel, rbc_any_agg_block_sel, rbc_all_agg_block_sel, fnl_agg_block_sel);
		if (!is_in_legal_set(agg_block_sel, rbc_all_agg_block_sel)) begin
			$display("Critical Warning: parameter 'agg_block_sel' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", agg_block_sel, rbc_all_agg_block_sel, fnl_agg_block_sel);
		end
		//$display("rx_clk1 = orig: '%s', any:'%s', all:'%s', final: '%s'", rx_clk1, rbc_any_rx_clk1, rbc_all_rx_clk1, fnl_rx_clk1);
		if (!is_in_legal_set(rx_clk1, rbc_all_rx_clk1)) begin
			$display("Critical Warning: parameter 'rx_clk1' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", rx_clk1, rbc_all_rx_clk1, fnl_rx_clk1);
		end
		//$display("rx_clk2 = orig: '%s', any:'%s', all:'%s', final: '%s'", rx_clk2, rbc_any_rx_clk2, rbc_all_rx_clk2, fnl_rx_clk2);
		if (!is_in_legal_set(rx_clk2, rbc_all_rx_clk2)) begin
			$display("Critical Warning: parameter 'rx_clk2' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", rx_clk2, rbc_all_rx_clk2, fnl_rx_clk2);
		end
		//$display("rx_wr_clk = orig: '%s', any:'%s', all:'%s', final: '%s'", rx_wr_clk, rbc_any_rx_wr_clk, rbc_all_rx_wr_clk, fnl_rx_wr_clk);
		if (!is_in_legal_set(rx_wr_clk, rbc_all_rx_wr_clk)) begin
			$display("Critical Warning: parameter 'rx_wr_clk' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", rx_wr_clk, rbc_all_rx_wr_clk, fnl_rx_wr_clk);
		end
		//$display("rx_rd_clk = orig: '%s', any:'%s', all:'%s', final: '%s'", rx_rd_clk, rbc_any_rx_rd_clk, rbc_all_rx_rd_clk, fnl_rx_rd_clk);
		if (!is_in_legal_set(rx_rd_clk, rbc_all_rx_rd_clk)) begin
			$display("Critical Warning: parameter 'rx_rd_clk' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", rx_rd_clk, rbc_all_rx_rd_clk, fnl_rx_rd_clk);
		end
		//$display("clock_gate_bist = orig: '%s', any:'%s', all:'%s', final: '%s'", clock_gate_bist, rbc_any_clock_gate_bist, rbc_all_clock_gate_bist, fnl_clock_gate_bist);
		if (!is_in_legal_set(clock_gate_bist, rbc_all_clock_gate_bist)) begin
			$display("Critical Warning: parameter 'clock_gate_bist' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", clock_gate_bist, rbc_all_clock_gate_bist, fnl_clock_gate_bist);
		end
		//$display("clock_gate_sw_wa = orig: '%s', any:'%s', all:'%s', final: '%s'", clock_gate_sw_wa, rbc_any_clock_gate_sw_wa, rbc_all_clock_gate_sw_wa, fnl_clock_gate_sw_wa);
		if (!is_in_legal_set(clock_gate_sw_wa, rbc_all_clock_gate_sw_wa)) begin
			$display("Critical Warning: parameter 'clock_gate_sw_wa' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", clock_gate_sw_wa, rbc_all_clock_gate_sw_wa, fnl_clock_gate_sw_wa);
		end
		//$display("clock_gate_dw_wa = orig: '%s', any:'%s', all:'%s', final: '%s'", clock_gate_dw_wa, rbc_any_clock_gate_dw_wa, rbc_all_clock_gate_dw_wa, fnl_clock_gate_dw_wa);
		if (!is_in_legal_set(clock_gate_dw_wa, rbc_all_clock_gate_dw_wa)) begin
			$display("Critical Warning: parameter 'clock_gate_dw_wa' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", clock_gate_dw_wa, rbc_all_clock_gate_dw_wa, fnl_clock_gate_dw_wa);
		end
		//$display("clock_gate_sw_dskw_wr = orig: '%s', any:'%s', all:'%s', final: '%s'", clock_gate_sw_dskw_wr, rbc_any_clock_gate_sw_dskw_wr, rbc_all_clock_gate_sw_dskw_wr, fnl_clock_gate_sw_dskw_wr);
		if (!is_in_legal_set(clock_gate_sw_dskw_wr, rbc_all_clock_gate_sw_dskw_wr)) begin
			$display("Critical Warning: parameter 'clock_gate_sw_dskw_wr' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", clock_gate_sw_dskw_wr, rbc_all_clock_gate_sw_dskw_wr, fnl_clock_gate_sw_dskw_wr);
		end
		//$display("clock_gate_dw_dskw_wr = orig: '%s', any:'%s', all:'%s', final: '%s'", clock_gate_dw_dskw_wr, rbc_any_clock_gate_dw_dskw_wr, rbc_all_clock_gate_dw_dskw_wr, fnl_clock_gate_dw_dskw_wr);
		if (!is_in_legal_set(clock_gate_dw_dskw_wr, rbc_all_clock_gate_dw_dskw_wr)) begin
			$display("Critical Warning: parameter 'clock_gate_dw_dskw_wr' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", clock_gate_dw_dskw_wr, rbc_all_clock_gate_dw_dskw_wr, fnl_clock_gate_dw_dskw_wr);
		end
		//$display("clock_gate_prbs = orig: '%s', any:'%s', all:'%s', final: '%s'", clock_gate_prbs, rbc_any_clock_gate_prbs, rbc_all_clock_gate_prbs, fnl_clock_gate_prbs);
		if (!is_in_legal_set(clock_gate_prbs, rbc_all_clock_gate_prbs)) begin
			$display("Critical Warning: parameter 'clock_gate_prbs' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", clock_gate_prbs, rbc_all_clock_gate_prbs, fnl_clock_gate_prbs);
		end
		//$display("clock_gate_cdr_eidle = orig: '%s', any:'%s', all:'%s', final: '%s'", clock_gate_cdr_eidle, rbc_any_clock_gate_cdr_eidle, rbc_all_clock_gate_cdr_eidle, fnl_clock_gate_cdr_eidle);
		if (!is_in_legal_set(clock_gate_cdr_eidle, rbc_all_clock_gate_cdr_eidle)) begin
			$display("Critical Warning: parameter 'clock_gate_cdr_eidle' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", clock_gate_cdr_eidle, rbc_all_clock_gate_cdr_eidle, fnl_clock_gate_cdr_eidle);
		end
		//$display("clock_gate_dskw_rd = orig: '%s', any:'%s', all:'%s', final: '%s'", clock_gate_dskw_rd, rbc_any_clock_gate_dskw_rd, rbc_all_clock_gate_dskw_rd, fnl_clock_gate_dskw_rd);
		if (!is_in_legal_set(clock_gate_dskw_rd, rbc_all_clock_gate_dskw_rd)) begin
			$display("Critical Warning: parameter 'clock_gate_dskw_rd' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", clock_gate_dskw_rd, rbc_all_clock_gate_dskw_rd, fnl_clock_gate_dskw_rd);
		end
		//$display("clock_gate_sw_rm_wr = orig: '%s', any:'%s', all:'%s', final: '%s'", clock_gate_sw_rm_wr, rbc_any_clock_gate_sw_rm_wr, rbc_all_clock_gate_sw_rm_wr, fnl_clock_gate_sw_rm_wr);
		if (!is_in_legal_set(clock_gate_sw_rm_wr, rbc_all_clock_gate_sw_rm_wr)) begin
			$display("Critical Warning: parameter 'clock_gate_sw_rm_wr' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", clock_gate_sw_rm_wr, rbc_all_clock_gate_sw_rm_wr, fnl_clock_gate_sw_rm_wr);
		end
		//$display("clock_gate_sw_rm_rd = orig: '%s', any:'%s', all:'%s', final: '%s'", clock_gate_sw_rm_rd, rbc_any_clock_gate_sw_rm_rd, rbc_all_clock_gate_sw_rm_rd, fnl_clock_gate_sw_rm_rd);
		if (!is_in_legal_set(clock_gate_sw_rm_rd, rbc_all_clock_gate_sw_rm_rd)) begin
			$display("Critical Warning: parameter 'clock_gate_sw_rm_rd' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", clock_gate_sw_rm_rd, rbc_all_clock_gate_sw_rm_rd, fnl_clock_gate_sw_rm_rd);
		end
		//$display("clock_gate_dw_rm_rd = orig: '%s', any:'%s', all:'%s', final: '%s'", clock_gate_dw_rm_rd, rbc_any_clock_gate_dw_rm_rd, rbc_all_clock_gate_dw_rm_rd, fnl_clock_gate_dw_rm_rd);
		if (!is_in_legal_set(clock_gate_dw_rm_rd, rbc_all_clock_gate_dw_rm_rd)) begin
			$display("Critical Warning: parameter 'clock_gate_dw_rm_rd' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", clock_gate_dw_rm_rd, rbc_all_clock_gate_dw_rm_rd, fnl_clock_gate_dw_rm_rd);
		end
		//$display("clock_gate_dw_rm_wr = orig: '%s', any:'%s', all:'%s', final: '%s'", clock_gate_dw_rm_wr, rbc_any_clock_gate_dw_rm_wr, rbc_all_clock_gate_dw_rm_wr, fnl_clock_gate_dw_rm_wr);
		if (!is_in_legal_set(clock_gate_dw_rm_wr, rbc_all_clock_gate_dw_rm_wr)) begin
			$display("Critical Warning: parameter 'clock_gate_dw_rm_wr' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", clock_gate_dw_rm_wr, rbc_all_clock_gate_dw_rm_wr, fnl_clock_gate_dw_rm_wr);
		end
		//$display("clock_gate_bds_dec_asn = orig: '%s', any:'%s', all:'%s', final: '%s'", clock_gate_bds_dec_asn, rbc_any_clock_gate_bds_dec_asn, rbc_all_clock_gate_bds_dec_asn, fnl_clock_gate_bds_dec_asn);
		if (!is_in_legal_set(clock_gate_bds_dec_asn, rbc_all_clock_gate_bds_dec_asn)) begin
			$display("Critical Warning: parameter 'clock_gate_bds_dec_asn' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", clock_gate_bds_dec_asn, rbc_all_clock_gate_bds_dec_asn, fnl_clock_gate_bds_dec_asn);
		end
		//$display("clock_gate_byteorder = orig: '%s', any:'%s', all:'%s', final: '%s'", clock_gate_byteorder, rbc_any_clock_gate_byteorder, rbc_all_clock_gate_byteorder, fnl_clock_gate_byteorder);
		if (!is_in_legal_set(clock_gate_byteorder, rbc_all_clock_gate_byteorder)) begin
			$display("Critical Warning: parameter 'clock_gate_byteorder' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", clock_gate_byteorder, rbc_all_clock_gate_byteorder, fnl_clock_gate_byteorder);
		end
		//$display("clock_gate_sw_pc_wrclk = orig: '%s', any:'%s', all:'%s', final: '%s'", clock_gate_sw_pc_wrclk, rbc_any_clock_gate_sw_pc_wrclk, rbc_all_clock_gate_sw_pc_wrclk, fnl_clock_gate_sw_pc_wrclk);
		if (!is_in_legal_set(clock_gate_sw_pc_wrclk, rbc_all_clock_gate_sw_pc_wrclk)) begin
			$display("Critical Warning: parameter 'clock_gate_sw_pc_wrclk' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", clock_gate_sw_pc_wrclk, rbc_all_clock_gate_sw_pc_wrclk, fnl_clock_gate_sw_pc_wrclk);
		end
		//$display("clock_gate_dw_pc_wrclk = orig: '%s', any:'%s', all:'%s', final: '%s'", clock_gate_dw_pc_wrclk, rbc_any_clock_gate_dw_pc_wrclk, rbc_all_clock_gate_dw_pc_wrclk, fnl_clock_gate_dw_pc_wrclk);
		if (!is_in_legal_set(clock_gate_dw_pc_wrclk, rbc_all_clock_gate_dw_pc_wrclk)) begin
			$display("Critical Warning: parameter 'clock_gate_dw_pc_wrclk' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", clock_gate_dw_pc_wrclk, rbc_all_clock_gate_dw_pc_wrclk, fnl_clock_gate_dw_pc_wrclk);
		end
		//$display("clock_gate_pc_rdclk = orig: '%s', any:'%s', all:'%s', final: '%s'", clock_gate_pc_rdclk, rbc_any_clock_gate_pc_rdclk, rbc_all_clock_gate_pc_rdclk, fnl_clock_gate_pc_rdclk);
		if (!is_in_legal_set(clock_gate_pc_rdclk, rbc_all_clock_gate_pc_rdclk)) begin
			$display("Critical Warning: parameter 'clock_gate_pc_rdclk' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", clock_gate_pc_rdclk, rbc_all_clock_gate_pc_rdclk, fnl_clock_gate_pc_rdclk);
		end
		//$display("rx_pcs_urst = orig: '%s', any:'%s', all:'%s', final: '%s'", rx_pcs_urst, rbc_any_rx_pcs_urst, rbc_all_rx_pcs_urst, fnl_rx_pcs_urst);
		if (!is_in_legal_set(rx_pcs_urst, rbc_all_rx_pcs_urst)) begin
			$display("Critical Warning: parameter 'rx_pcs_urst' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", rx_pcs_urst, rbc_all_rx_pcs_urst, fnl_rx_pcs_urst);
		end
		//$display("rx_clk_free_running = orig: '%s', any:'%s', all:'%s', final: '%s'", rx_clk_free_running, rbc_any_rx_clk_free_running, rbc_all_rx_clk_free_running, fnl_rx_clk_free_running);
		if (!is_in_legal_set(rx_clk_free_running, rbc_all_rx_clk_free_running)) begin
			$display("Critical Warning: parameter 'rx_clk_free_running' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", rx_clk_free_running, rbc_all_rx_clk_free_running, fnl_rx_clk_free_running);
		end
		//$display("comp_fifo_rst_pld_ctrl = orig: '%s', any:'%s', all:'%s', final: '%s'", comp_fifo_rst_pld_ctrl, rbc_any_comp_fifo_rst_pld_ctrl, rbc_all_comp_fifo_rst_pld_ctrl, fnl_comp_fifo_rst_pld_ctrl);
		if (!is_in_legal_set(comp_fifo_rst_pld_ctrl, rbc_all_comp_fifo_rst_pld_ctrl)) begin
			$display("Critical Warning: parameter 'comp_fifo_rst_pld_ctrl' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", comp_fifo_rst_pld_ctrl, rbc_all_comp_fifo_rst_pld_ctrl, fnl_comp_fifo_rst_pld_ctrl);
		end
		//$display("pc_fifo_rst_pld_ctrl = orig: '%s', any:'%s', all:'%s', final: '%s'", pc_fifo_rst_pld_ctrl, rbc_any_pc_fifo_rst_pld_ctrl, rbc_all_pc_fifo_rst_pld_ctrl, fnl_pc_fifo_rst_pld_ctrl);
		if (!is_in_legal_set(pc_fifo_rst_pld_ctrl, rbc_all_pc_fifo_rst_pld_ctrl)) begin
			$display("Critical Warning: parameter 'pc_fifo_rst_pld_ctrl' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", pc_fifo_rst_pld_ctrl, rbc_all_pc_fifo_rst_pld_ctrl, fnl_pc_fifo_rst_pld_ctrl);
		end
		//$display("test_bus_sel = orig: '%s', any:'%s', all:'%s', final: '%s'", test_bus_sel, rbc_any_test_bus_sel, rbc_all_test_bus_sel, fnl_test_bus_sel);
		if (!is_in_legal_set(test_bus_sel, rbc_all_test_bus_sel)) begin
			$display("Critical Warning: parameter 'test_bus_sel' of instance '%m' has illegal value '%s' assigned to it.  Valid parameter values are: '%s'.  Using value '%s'", test_bus_sel, rbc_all_test_bus_sel, fnl_test_bus_sel);
		end
	end

	arriav_hssi_8g_rx_pcs #(
		.prot_mode(fnl_prot_mode),
		.sup_mode(fnl_sup_mode),
		.avmm_group_channel_index(avmm_group_channel_index),
		.bo_pad(bo_pad),
		.bo_pattern(bo_pattern),
		.channel_number(channel_number),
		.cid_pattern_len(cid_pattern_len),
		.clkcmp_pattern_n(clkcmp_pattern_n),
		.clkcmp_pattern_p(clkcmp_pattern_p),
		.deskew_pattern(deskew_pattern),
		.fixed_pat_num(fixed_pat_num),
		.mask_cnt(mask_cnt),
		.pma_done_count(pma_done_count),
		.runlength_val(runlength_val),
		.use_default_base_address(fnl_use_default_base_address),
		.user_base_address(user_base_address),
		.wa_clk_slip_spacing_data(wa_clk_slip_spacing_data),
		.wa_pd_data(wa_pd_data),
		.wa_renumber_data(wa_renumber_data),
		.wa_rgnumber_data(wa_rgnumber_data),
		.wa_rknumber_data(wa_rknumber_data),
		.wa_rosnumber_data(wa_rosnumber_data),
		.wa_rvnumber_data(wa_rvnumber_data),
		.wait_cnt(wait_cnt),
		.test_mode(fnl_test_mode),
		.hip_mode(fnl_hip_mode),
		.pcs_bypass(fnl_pcs_bypass),
		.pma_dw(fnl_pma_dw),
		.pipe_if_enable(fnl_pipe_if_enable),
		.prbs_ver(fnl_prbs_ver),
		.wa_boundary_lock_ctrl(fnl_wa_boundary_lock_ctrl),
		.wa_pld_controlled(fnl_wa_pld_controlled),
		.wa_pd_polarity(fnl_wa_pd_polarity),
		.wa_pd(fnl_wa_pd),
		.wa_sync_sm_ctrl(fnl_wa_sync_sm_ctrl),
		.wa_kchar(fnl_wa_kchar),
		.fixed_pat_det(fnl_fixed_pat_det),
		.ibm_invalid_code(fnl_ibm_invalid_code),
		.force_signal_detect(fnl_force_signal_detect),
		.wa_det_latency_sync_status_beh(fnl_wa_det_latency_sync_status_beh),
		.wa_clk_slip_spacing(fnl_wa_clk_slip_spacing),
		.eightb_tenb_decoder(fnl_eightb_tenb_decoder),
		.wa_disp_err_flag(fnl_wa_disp_err_flag),
		.polarity_inversion(fnl_polarity_inversion),
		.bit_reversal(fnl_bit_reversal),
		.symbol_swap(fnl_symbol_swap),
		.runlength_check(fnl_runlength_check),
		.ctrl_plane_bonding_consumption(fnl_ctrl_plane_bonding_consumption),
		.deskew(fnl_deskew),
		.deskew_prog_pattern_only(fnl_deskew_prog_pattern_only),
		.rate_match(fnl_rate_match),
		.err_flags_sel(fnl_err_flags_sel),
		.polinv_8b10b_dec(fnl_polinv_8b10b_dec),
		.eightbtenb_decoder_output_sel(fnl_eightbtenb_decoder_output_sel),
		.invalid_code_flag_only(fnl_invalid_code_flag_only),
		.auto_error_replacement(fnl_auto_error_replacement),
		.pad_or_edb_error_replace(fnl_pad_or_edb_error_replace),
		.byte_deserializer(fnl_byte_deserializer),
		.byte_order(fnl_byte_order),
		.dw_one_or_two_symbol_bo(fnl_dw_one_or_two_symbol_bo),
		.re_bo_on_wa(fnl_re_bo_on_wa),
		.phase_compensation_fifo(fnl_phase_compensation_fifo),
		.tx_rx_parallel_loopback(fnl_tx_rx_parallel_loopback),
		.prbs_ver_clr_flag(fnl_prbs_ver_clr_flag),
		.cid_pattern(fnl_cid_pattern),
		.bist_ver(fnl_bist_ver),
		.bist_ver_clr_flag(fnl_bist_ver_clr_flag),
		.cdr_ctrl(fnl_cdr_ctrl),
		.cdr_ctrl_rxvalid_mask(fnl_cdr_ctrl_rxvalid_mask),
		.auto_speed_nego(fnl_auto_speed_nego),
		.eidle_entry_iei(fnl_eidle_entry_iei),
		.eidle_entry_sd(fnl_eidle_entry_sd),
		.eidle_entry_eios(fnl_eidle_entry_eios),
		.ctrl_plane_bonding_distribution(fnl_ctrl_plane_bonding_distribution),
		.ctrl_plane_bonding_compensation(fnl_ctrl_plane_bonding_compensation),
		.bypass_pipeline_reg(fnl_bypass_pipeline_reg),
		.rx_refclk(fnl_rx_refclk),
		.rx_rcvd_clk(fnl_rx_rcvd_clk),
		.agg_block_sel(fnl_agg_block_sel),
		.rx_clk1(fnl_rx_clk1),
		.rx_clk2(fnl_rx_clk2),
		.rx_wr_clk(fnl_rx_wr_clk),
		.rx_rd_clk(fnl_rx_rd_clk),
		.clock_gate_bist(fnl_clock_gate_bist),
		.clock_gate_sw_wa(fnl_clock_gate_sw_wa),
		.clock_gate_dw_wa(fnl_clock_gate_dw_wa),
		.clock_gate_sw_dskw_wr(fnl_clock_gate_sw_dskw_wr),
		.clock_gate_dw_dskw_wr(fnl_clock_gate_dw_dskw_wr),
		.clock_gate_prbs(fnl_clock_gate_prbs),
		.clock_gate_cdr_eidle(fnl_clock_gate_cdr_eidle),
		.clock_gate_dskw_rd(fnl_clock_gate_dskw_rd),
		.clock_gate_sw_rm_wr(fnl_clock_gate_sw_rm_wr),
		.clock_gate_sw_rm_rd(fnl_clock_gate_sw_rm_rd),
		.clock_gate_dw_rm_rd(fnl_clock_gate_dw_rm_rd),
		.clock_gate_dw_rm_wr(fnl_clock_gate_dw_rm_wr),
		.clock_gate_bds_dec_asn(fnl_clock_gate_bds_dec_asn),
		.clock_gate_byteorder(fnl_clock_gate_byteorder),
		.clock_gate_sw_pc_wrclk(fnl_clock_gate_sw_pc_wrclk),
		.clock_gate_dw_pc_wrclk(fnl_clock_gate_dw_pc_wrclk),
		.clock_gate_pc_rdclk(fnl_clock_gate_pc_rdclk),
		.rx_pcs_urst(fnl_rx_pcs_urst),
		.rx_clk_free_running(fnl_rx_clk_free_running),
		.comp_fifo_rst_pld_ctrl(fnl_comp_fifo_rst_pld_ctrl),
		.pc_fifo_rst_pld_ctrl(fnl_pc_fifo_rst_pld_ctrl),
		.test_bus_sel(fnl_test_bus_sel)
	) wys (
		// ports
		.a1a2k1k2flag(a1a2k1k2flag),
		.a1a2size(a1a2size),
		.aggrxpcsrst(aggrxpcsrst),
		.aggtestbus(aggtestbus),
		.aligndetsync(aligndetsync),
		.alignstatus(alignstatus),
		.alignstatuspld(alignstatuspld),
		.alignstatussync(alignstatussync),
		.alignstatussync0(alignstatussync0),
		.alignstatussync0toporbot(alignstatussync0toporbot),
		.alignstatustoporbot(alignstatustoporbot),
		.avmmaddress(avmmaddress),
		.avmmbyteen(avmmbyteen),
		.avmmclk(avmmclk),
		.avmmread(avmmread),
		.avmmreaddata(avmmreaddata),
		.avmmrstn(avmmrstn),
		.avmmwrite(avmmwrite),
		.avmmwritedata(avmmwritedata),
		.bistdone(bistdone),
		.bisterr(bisterr),
		.bitreversalenable(bitreversalenable),
		.bitslip(bitslip),
		.blockselect(blockselect),
		.byteorder(byteorder),
		.byteordflag(byteordflag),
		.bytereversalenable(bytereversalenable),
		.cgcomprddall(cgcomprddall),
		.cgcomprddalltoporbot(cgcomprddalltoporbot),
		.cgcomprddout(cgcomprddout),
		.cgcompwrall(cgcompwrall),
		.cgcompwralltoporbot(cgcompwralltoporbot),
		.cgcompwrout(cgcompwrout),
		.channeltestbusout(channeltestbusout),
		.clocktopld(clocktopld),
		.configselinchnldown(configselinchnldown),
		.configselinchnlup(configselinchnlup),
		.configseloutchnldown(configseloutchnldown),
		.configseloutchnlup(configseloutchnlup),
		.ctrlfromaggblock(ctrlfromaggblock),
		.datafrinaggblock(datafrinaggblock),
		.datain(datain),
		.dataout(dataout),
		.decoderctrl(decoderctrl),
		.decoderdata(decoderdata),
		.decoderdatavalid(decoderdatavalid),
		.delcondmet0(delcondmet0),
		.delcondmet0toporbot(delcondmet0toporbot),
		.delcondmetout(delcondmetout),
		.disablepcfifobyteserdes(disablepcfifobyteserdes),
		.dynclkswitchn(dynclkswitchn),
		.earlyeios(earlyeios),
		.eidledetected(eidledetected),
		.eidleexit(eidleexit),
		.eidleinfersel(eidleinfersel),
		.enablecommadetect(enablecommadetect),
		.endskwqd(endskwqd),
		.endskwqdtoporbot(endskwqdtoporbot),
		.endskwrdptrs(endskwrdptrs),
		.endskwrdptrstoporbot(endskwrdptrstoporbot),
		.errctrl(errctrl),
		.errdata(errdata),
		.fifoovr0(fifoovr0),
		.fifoovr0toporbot(fifoovr0toporbot),
		.fifoovrout(fifoovrout),
		.fifordincomp0toporbot(fifordincomp0toporbot),
		.fifordoutcomp(fifordoutcomp),
		.fiforstrdqd(fiforstrdqd),
		.fiforstrdqdtoporbot(fiforstrdqdtoporbot),
		.gen2ngen1(gen2ngen1),
		.hrdrst(hrdrst),
		.insertincomplete0(insertincomplete0),
		.insertincomplete0toporbot(insertincomplete0toporbot),
		.insertincompleteout(insertincompleteout),
		.latencycomp0(latencycomp0),
		.latencycomp0toporbot(latencycomp0toporbot),
		.latencycompout(latencycompout),
		.ltr(ltr),
		.observablebyteserdesclock(observablebyteserdesclock),
		.parallelloopback(parallelloopback),
		.parallelrevloopback(parallelrevloopback),
		.pcfifoempty(pcfifoempty),
		.pcfifofull(pcfifofull),
		.pcfifordenable(pcfifordenable),
		.pcieswitch(pcieswitch),
		.phfifouserrst(phfifouserrst),
		.phystatus(phystatus),
		.phystatusinternal(phystatusinternal),
		.phystatuspcsgen3(phystatuspcsgen3),
		.pipedata(pipedata),
		.pipeloopbk(pipeloopbk),
		.pldltr(pldltr),
		.pldrxclk(pldrxclk),
		.polinvrx(polinvrx),
		.prbscidenable(prbscidenable),
		.prbsdone(prbsdone),
		.prbserrlt(prbserrlt),
		.pxfifowrdisable(pxfifowrdisable),
		.rateswitchcontrol(rateswitchcontrol),
		.rcvdclkagg(rcvdclkagg),
		.rcvdclkaggtoporbot(rcvdclkaggtoporbot),
		.rcvdclkpma(rcvdclkpma),
		.rdalign(rdalign),
		.rdenableinchnldown(rdenableinchnldown),
		.rdenableinchnlup(rdenableinchnlup),
		.rdenableoutchnldown(rdenableoutchnldown),
		.rdenableoutchnlup(rdenableoutchnlup),
		.refclkdig(refclkdig),
		.refclkdig2(refclkdig2),
		.resetpcptrs(resetpcptrs),
		.resetpcptrsinchnldown(resetpcptrsinchnldown),
		.resetpcptrsinchnldownpipe(resetpcptrsinchnldownpipe),
		.resetpcptrsinchnlup(resetpcptrsinchnlup),
		.resetpcptrsinchnluppipe(resetpcptrsinchnluppipe),
		.resetpcptrsoutchnldown(resetpcptrsoutchnldown),
		.resetpcptrsoutchnlup(resetpcptrsoutchnlup),
		.resetppmcntrsinchnldown(resetppmcntrsinchnldown),
		.resetppmcntrsinchnlup(resetppmcntrsinchnlup),
		.resetppmcntrsoutchnldown(resetppmcntrsoutchnldown),
		.resetppmcntrsoutchnlup(resetppmcntrsoutchnlup),
		.resetppmcntrspcspma(resetppmcntrspcspma),
		.rlvlt(rlvlt),
		.rmfifoempty(rmfifoempty),
		.rmfifofull(rmfifofull),
		.rmfifopartialempty(rmfifopartialempty),
		.rmfifopartialfull(rmfifopartialfull),
		.rmfifordincomp0(rmfifordincomp0),
		.rmfiforeadenable(rmfiforeadenable),
		.rmfifouserrst(rmfifouserrst),
		.rmfifowriteenable(rmfifowriteenable),
		.runlengthviolation(runlengthviolation),
		.runningdisparity(runningdisparity),
		.rxblkstart(rxblkstart),
		.rxclkslip(rxclkslip),
		.rxcontrolrstoporbot(rxcontrolrstoporbot),
		.rxdatarstoporbot(rxdatarstoporbot),
		.rxdatavalid(rxdatavalid),
		.rxdivsyncinchnldown(rxdivsyncinchnldown),
		.rxdivsyncinchnlup(rxdivsyncinchnlup),
		.rxdivsyncoutchnldown(rxdivsyncoutchnldown),
		.rxdivsyncoutchnlup(rxdivsyncoutchnlup),
		.rxpcsrst(rxpcsrst),
		.rxpipeclk(rxpipeclk),
		.rxpipesoftreset(rxpipesoftreset),
		.rxstatus(rxstatus),
		.rxstatusinternal(rxstatusinternal),
		.rxsynchdr(rxsynchdr),
		.rxsynchdrpcsgen3(rxsynchdrpcsgen3),
		.rxvalid(rxvalid),
		.rxvalidinternal(rxvalidinternal),
		.rxweinchnldown(rxweinchnldown),
		.rxweinchnlup(rxweinchnlup),
		.rxweoutchnldown(rxweoutchnldown),
		.rxweoutchnlup(rxweoutchnlup),
		.scanmode(scanmode),
		.selftestdone(selftestdone),
		.selftesterr(selftesterr),
		.sigdetfrompma(sigdetfrompma),
		.signaldetectout(signaldetectout),
		.speedchange(speedchange),
		.speedchangeinchnldown(speedchangeinchnldown),
		.speedchangeinchnldownpipe(speedchangeinchnldownpipe),
		.speedchangeinchnlup(speedchangeinchnlup),
		.speedchangeinchnluppipe(speedchangeinchnluppipe),
		.speedchangeoutchnldown(speedchangeoutchnldown),
		.speedchangeoutchnlup(speedchangeoutchnlup),
		.syncdatain(syncdatain),
		.syncsmen(syncsmen),
		.syncstatus(syncstatus),
		.txctrlplanetestbus(txctrlplanetestbus),
		.txdivsync(txdivsync),
		.txpmaclk(txpmaclk),
		.txtestbus(txtestbus),
		.wordalignboundary(wordalignboundary),
		.wrenableinchnldown(wrenableinchnldown),
		.wrenableinchnlup(wrenableinchnlup),
		.wrenableoutchnldown(wrenableoutchnldown),
		.wrenableoutchnlup(wrenableoutchnlup)
	);
endmodule
