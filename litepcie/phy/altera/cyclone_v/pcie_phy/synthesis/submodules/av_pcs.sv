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


//
//              ALTERA CORPORATION
//
// av_pcs.sv
// automatically generated at 23:1:59, Fri Aug 26, 2011
//
//


`timescale 1ps/1ps


module av_pcs
	#(
	//PARAM_LIST_START
		parameter bonded_lanes = 1,
		parameter bonding_master_ch = 0,
		parameter enable_8g_rx = "true",
		parameter enable_8g_tx = "true",
		parameter enable_dyn_reconfig = "true",
		parameter enable_gen12_pipe = "true",
		parameter channel_number = 0,
		
		// Adding new parameter for PMA Direct
	        parameter enable_pma_direct_tx = "false",                    // (true,false) Enable, disable the PMA Direct path
	        parameter enable_pma_direct_rx = "false",                    // (true,false) Enable, disable the PMA Direct path			
		
		// parameters for arriav_hssi_8g_rx_pcs
		parameter pcs8g_rx_agg_block_sel = "<auto_single>", // same_smrt_pack|other_smrt_pack
		parameter pcs8g_rx_auto_error_replacement = "<auto_single>", // dis_err_replace|en_err_replace
		parameter pcs8g_rx_auto_speed_nego = "<auto_single>", // dis_asn|en_asn_g2_freq_scal
		parameter pcs8g_rx_bist_ver = "<auto_single>", // dis_bist|incremental|cjpat|crpat
		parameter pcs8g_rx_bist_ver_clr_flag = "<auto_single>", // dis_bist_clr_flag|en_bist_clr_flag
		parameter pcs8g_rx_bit_reversal = "<auto_single>", // dis_bit_reversal|en_bit_reversal
		parameter pcs8g_rx_bo_pad = 10'b0,
		parameter pcs8g_rx_bo_pattern = 20'b0,
		parameter pcs8g_rx_bypass_pipeline_reg = "<auto_single>", // dis_bypass_pipeline|en_bypass_pipeline
		parameter pcs8g_rx_byte_deserializer = "<auto_single>", // dis_bds|en_bds_by_2|en_bds_by_2_det
		parameter pcs8g_rx_byte_order = "<auto_single>", // dis_bo|en_pcs_ctrl_eight_bit_bo|en_pcs_ctrl_nine_bit_bo|en_pcs_ctrl_ten_bit_bo|en_pld_ctrl_eight_bit_bo|en_pld_ctrl_nine_bit_bo|en_pld_ctrl_ten_bit_bo
		parameter pcs8g_rx_cdr_ctrl = "<auto_single>", // dis_cdr_ctrl|en_cdr_ctrl|en_cdr_ctrl_w_cid
		parameter pcs8g_rx_cdr_ctrl_rxvalid_mask = "<auto_single>", // dis_rxvalid_mask|en_rxvalid_mask
		parameter pcs8g_rx_cid_pattern = "<auto_single>", // cid_pattern_0|cid_pattern_1
		parameter pcs8g_rx_cid_pattern_len = 8'b0,
		parameter pcs8g_rx_clkcmp_pattern_n = 20'b0,
		parameter pcs8g_rx_clkcmp_pattern_p = 20'b0,
		parameter pcs8g_rx_clock_gate_bds_dec_asn = "<auto_single>", // dis_bds_dec_asn_clk_gating|en_bds_dec_asn_clk_gating
		parameter pcs8g_rx_clock_gate_bist = "<auto_single>", // dis_bist_clk_gating|en_bist_clk_gating
		parameter pcs8g_rx_clock_gate_byteorder = "<auto_single>", // dis_byteorder_clk_gating|en_byteorder_clk_gating
		parameter pcs8g_rx_clock_gate_cdr_eidle = "<auto_single>", // dis_cdr_eidle_clk_gating|en_cdr_eidle_clk_gating
		parameter pcs8g_rx_clock_gate_dskw_rd = "<auto_single>", // dis_dskw_rdclk_gating|en_dskw_rdclk_gating
		parameter pcs8g_rx_clock_gate_dw_dskw_wr = "<auto_single>", // dis_dw_dskw_wrclk_gating|en_dw_dskw_wrclk_gating
		parameter pcs8g_rx_clock_gate_dw_pc_wrclk = "<auto_single>", // dis_dw_pc_wrclk_gating|en_dw_pc_wrclk_gating
		parameter pcs8g_rx_clock_gate_dw_rm_rd = "<auto_single>", // dis_dw_rm_rdclk_gating|en_dw_rm_rdclk_gating
		parameter pcs8g_rx_clock_gate_dw_rm_wr = "<auto_single>", // dis_dw_rm_wrclk_gating|en_dw_rm_wrclk_gating
		parameter pcs8g_rx_clock_gate_dw_wa = "<auto_single>", // dis_dw_wa_clk_gating|en_dw_wa_clk_gating
		parameter pcs8g_rx_clock_gate_pc_rdclk = "<auto_single>", // dis_pc_rdclk_gating|en_pc_rdclk_gating
		parameter pcs8g_rx_clock_gate_prbs = "<auto_single>", // dis_prbs_clk_gating|en_prbs_clk_gating
		parameter pcs8g_rx_clock_gate_sw_dskw_wr = "<auto_single>", // dis_sw_dskw_wrclk_gating|en_sw_dskw_wrclk_gating
		parameter pcs8g_rx_clock_gate_sw_pc_wrclk = "<auto_single>", // dis_sw_pc_wrclk_gating|en_sw_pc_wrclk_gating
		parameter pcs8g_rx_clock_gate_sw_rm_rd = "<auto_single>", // dis_sw_rm_rdclk_gating|en_sw_rm_rdclk_gating
		parameter pcs8g_rx_clock_gate_sw_rm_wr = "<auto_single>", // dis_sw_rm_wrclk_gating|en_sw_rm_wrclk_gating
		parameter pcs8g_rx_clock_gate_sw_wa = "<auto_single>", // dis_sw_wa_clk_gating|en_sw_wa_clk_gating
		parameter pcs8g_rx_comp_fifo_rst_pld_ctrl = "<auto_single>", // dis_comp_fifo_rst_pld_ctrl|en_comp_fifo_rst_pld_ctrl
		// BONDING_PARAM: parameter pcs8g_rx_ctrl_plane_bonding_compensation = "<auto_single>", // dis_compensation|en_compensation
		// BONDING_PARAM: parameter pcs8g_rx_ctrl_plane_bonding_consumption = "<auto_single>", // individual|bundled_master|bundled_slave_below|bundled_slave_above
		// BONDING_PARAM: parameter pcs8g_rx_ctrl_plane_bonding_distribution = "<auto_single>", // master_chnl_distr|not_master_chnl_distr
		parameter pcs8g_rx_deskew = "<auto_single>", // dis_deskew|en_srio_v2p1|en_xaui
		parameter pcs8g_rx_deskew_pattern = 10'b1101101000,
		parameter pcs8g_rx_deskew_prog_pattern_only = "<auto_single>", // dis_deskew_prog_pat_only|en_deskew_prog_pat_only
		parameter pcs8g_rx_dw_one_or_two_symbol_bo = "<auto_single>", // donot_care_one_two_bo|one_symbol_bo|two_symbol_bo_eight_bit|two_symbol_bo_nine_bit|two_symbol_bo_ten_bit
		parameter pcs8g_rx_eidle_entry_eios = "<auto_single>", // dis_eidle_eios|en_eidle_eios
		parameter pcs8g_rx_eidle_entry_iei = "<auto_single>", // dis_eidle_iei|en_eidle_iei
		parameter pcs8g_rx_eidle_entry_sd = "<auto_single>", // dis_eidle_sd|en_eidle_sd
		parameter pcs8g_rx_eightb_tenb_decoder = "<auto_single>", // dis_8b10b|en_8b10b_ibm|en_8b10b_sgx
		parameter pcs8g_rx_eightbtenb_decoder_output_sel = "<auto_single>", // data_8b10b_decoder|data_xaui_sm
		parameter pcs8g_rx_err_flags_sel = "<auto_single>", // err_flags_wa|err_flags_8b10b
		parameter pcs8g_rx_fixed_pat_det = "<auto_single>", // dis_fixed_patdet|en_fixed_patdet
		parameter pcs8g_rx_fixed_pat_num = 4'b1111,
		parameter pcs8g_rx_force_signal_detect = "<auto_single>", // en_force_signal_detect|dis_force_signal_detect
		parameter pcs8g_rx_hip_mode = "<auto_single>", // dis_hip|en_hip
		parameter pcs8g_rx_ibm_invalid_code = "<auto_single>", // dis_ibm_invalid_code|en_ibm_invalid_code
		parameter pcs8g_rx_invalid_code_flag_only = "<auto_single>", // dis_invalid_code_only|en_invalid_code_only
		parameter pcs8g_rx_mask_cnt = 10'h3ff,
		parameter pcs8g_rx_pad_or_edb_error_replace = "<auto_single>", // replace_edb|replace_pad|replace_edb_dynamic
		parameter pcs8g_rx_pc_fifo_rst_pld_ctrl = "<auto_single>", // dis_pc_fifo_rst_pld_ctrl|en_pc_fifo_rst_pld_ctrl
		parameter pcs8g_rx_pcs_bypass = "<auto_single>", // dis_pcs_bypass|en_pcs_bypass
		parameter pcs8g_rx_phase_compensation_fifo = "<auto_single>", // low_latency|normal_latency|register_fifo|pld_ctrl_low_latency|pld_ctrl_normal_latency
		parameter pcs8g_rx_pipe_if_enable = "<auto_single>", // dis_pipe_rx|en_pipe_rx
		parameter pcs8g_rx_pma_done_count = 18'b0,
		parameter pcs8g_rx_pma_dw = "<auto_single>", // eight_bit|ten_bit|sixteen_bit|twenty_bit
		parameter pcs8g_rx_polarity_inversion = "<auto_single>", // dis_pol_inv|en_pol_inv
		parameter pcs8g_rx_polinv_8b10b_dec = "<auto_single>", // dis_polinv_8b10b_dec|en_polinv_8b10b_dec
		parameter pcs8g_rx_prbs_ver = "<auto_single>", // dis_prbs|prbs_7_sw|prbs_7_dw|prbs_8|prbs_10|prbs_23_sw|prbs_23_dw|prbs_15|prbs_31|prbs_hf_sw|prbs_hf_dw|prbs_lf_sw|prbs_lf_dw|prbs_mf_sw|prbs_mf_dw
		parameter pcs8g_rx_prbs_ver_clr_flag = "<auto_single>", // dis_prbs_clr_flag|en_prbs_clr_flag
		parameter pcs8g_rx_prot_mode = "<auto_single>", // pipe_g1|pipe_g2|cpri|cpri_rx_tx|gige|xaui|srio_2p1|test|basic|disabled_prot_mode
		parameter pcs8g_rx_rate_match = "<auto_single>", // dis_rm|xaui_rm|gige_rm|pipe_rm|pipe_rm_0ppm|sw_basic_rm|srio_v2p1_rm|srio_v2p1_rm_0ppm|dw_basic_rm
		parameter pcs8g_rx_re_bo_on_wa = "<auto_single>", // dis_re_bo_on_wa|en_re_bo_on_wa
		parameter pcs8g_rx_runlength_check = "<auto_single>", // dis_runlength|en_runlength_sw|en_runlength_dw
		parameter pcs8g_rx_runlength_val = 6'b0,
		parameter pcs8g_rx_rx_clk1 = "<auto_single>", // rcvd_clk_clk1|tx_pma_clock_clk1|rcvd_clk_agg_clk1|rcvd_clk_agg_top_or_bottom_clk1
		parameter pcs8g_rx_rx_clk2 = "<auto_single>", // rcvd_clk_clk2|tx_pma_clock_clk2|refclk_dig2_clk2
		parameter pcs8g_rx_rx_clk_free_running = "<auto_single>", // dis_rx_clk_free_run|en_rx_clk_free_run
		parameter pcs8g_rx_rx_pcs_urst = "<auto_single>", // dis_rx_pcs_urst|en_rx_pcs_urst
		parameter pcs8g_rx_rx_rcvd_clk = "<auto_single>", // rcvd_clk_rcvd_clk|tx_pma_clock_rcvd_clk
		parameter pcs8g_rx_rx_rd_clk = "<auto_single>", // pld_rx_clk|rx_clk
		parameter pcs8g_rx_rx_refclk = "<auto_single>", // dis_refclk_sel|en_refclk_sel
		parameter pcs8g_rx_rx_wr_clk = "<auto_single>", // rx_clk2_div_1_2_4|txfifo_rd_clk
		parameter pcs8g_rx_sup_mode = "<auto_single>", // user_mode|engineering_mode
		parameter pcs8g_rx_symbol_swap = "<auto_single>", // dis_symbol_swap|en_symbol_swap
		parameter pcs8g_rx_test_bus_sel = "<auto_single>", // prbs_bist_testbus|tx_testbus|tx_ctrl_plane_testbus|wa_testbus|deskew_testbus|rm_testbus|rx_ctrl_testbus|pcie_ctrl_testbus|rx_ctrl_plane_testbus|agg_testbus
		parameter pcs8g_rx_test_mode = "<auto_single>", // dont_care_test|prbs|bist
		parameter pcs8g_rx_tx_rx_parallel_loopback = "<auto_single>", // dis_plpbk|en_plpbk
		parameter pcs8g_rx_use_default_base_address = "true", // false|true
		parameter pcs8g_rx_user_base_address = 0, // 0..2047
		parameter pcs8g_rx_wa_boundary_lock_ctrl = "<auto_single>", // bit_slip|sync_sm|deterministic_latency|auto_align_pld_ctrl
		parameter pcs8g_rx_wa_clk_slip_spacing = "<auto_single>", // min_clk_slip_spacing|user_programmable_clk_slip_spacing
		parameter pcs8g_rx_wa_clk_slip_spacing_data = 10'b10000,
		parameter pcs8g_rx_wa_det_latency_sync_status_beh = "<auto_single>", // assert_sync_status_imm|assert_sync_status_non_imm|dont_care_assert_sync
		parameter pcs8g_rx_wa_disp_err_flag = "<auto_single>", // dis_disp_err_flag|en_disp_err_flag
		parameter pcs8g_rx_wa_kchar = "<auto_single>", // dis_kchar|en_kchar
		parameter pcs8g_rx_wa_pd = "<auto_single>", // dont_care_wa_pd_0|dont_care_wa_pd_1|wa_pd_7|wa_pd_10|wa_pd_20|wa_pd_40|wa_pd_8_sw|wa_pd_8_dw|wa_pd_16_sw|wa_pd_16_dw|wa_pd_32|wa_pd_fixed_7_k28p5|wa_pd_fixed_10_k28p5|wa_pd_fixed_16_a1a2_sw|wa_pd_fixed_16_a1a2_dw|wa_pd_fixed_32_a1a1a2a2|prbs15_fixed_wa_pd_16_sw|prbs15_fixed_wa_pd_16_dw|prbs15_fixed_wa_pd_20_dw|prbs31_fixed_wa_pd_16_sw|prbs31_fixed_wa_pd_16_dw|prbs31_fixed_wa_pd_10_sw|prbs31_fixed_wa_pd_40_dw|prbs8_fixed_wa|prbs10_fixed_wa|prbs7_fixed_wa_pd_16_sw|prbs7_fixed_wa_pd_16_dw|prbs7_fixed_wa_pd_20_dw|prbs23_fixed_wa_pd_16_sw|prbs23_fixed_wa_pd_32_dw|prbs23_fixed_wa_pd_40_dw
		parameter pcs8g_rx_wa_pd_data = 40'b0,
		parameter pcs8g_rx_wa_pd_polarity = "<auto_single>", // dis_pd_both_pol|en_pd_both_pol|dont_care_both_pol
		parameter pcs8g_rx_wa_pld_controlled = "<auto_single>", // dis_pld_ctrl|pld_ctrl_sw|rising_edge_sensitive_dw|level_sensitive_dw
		parameter pcs8g_rx_wa_renumber_data = 6'b0,
		parameter pcs8g_rx_wa_rgnumber_data = 8'b0,
		parameter pcs8g_rx_wa_rknumber_data = 8'b0,
		parameter pcs8g_rx_wa_rosnumber_data = 2'b0,
		parameter pcs8g_rx_wa_rvnumber_data = 13'b0,
		parameter pcs8g_rx_wa_sync_sm_ctrl = "<auto_single>", // gige_sync_sm|pipe_sync_sm|xaui_sync_sm|srio1p3_sync_sm|srio2p1_sync_sm|sw_basic_sync_sm|dw_basic_sync_sm|fibre_channel_sync_sm
		parameter pcs8g_rx_wait_cnt = 8'b0,
		
		// parameters for arriav_hssi_8g_tx_pcs
		parameter pcs8g_tx_agg_block_sel = "<auto_single>", // same_smrt_pack|other_smrt_pack
		parameter pcs8g_tx_auto_speed_nego_gen2 = "<auto_single>", // dis_asn_g2|en_asn_g2_freq_scal
		parameter pcs8g_tx_bist_gen = "<auto_single>", // dis_bist|incremental|cjpat|crpat
		parameter pcs8g_tx_bit_reversal = "<auto_single>", // dis_bit_reversal|en_bit_reversal
		parameter pcs8g_tx_bypass_pipeline_reg = "<auto_single>", // dis_bypass_pipeline|en_bypass_pipeline
		parameter pcs8g_tx_byte_serializer = "<auto_single>", // dis_bs|en_bs_by_2
		parameter pcs8g_tx_cid_pattern = "<auto_single>", // cid_pattern_0|cid_pattern_1
		parameter pcs8g_tx_cid_pattern_len = 8'b0,
		parameter pcs8g_tx_clock_gate_bist = "<auto_single>", // dis_bist_clk_gating|en_bist_clk_gating
		parameter pcs8g_tx_clock_gate_bs_enc = "<auto_single>", // dis_bs_enc_clk_gating|en_bs_enc_clk_gating
		parameter pcs8g_tx_clock_gate_dw_fifowr = "<auto_single>", // dis_dw_fifowr_clk_gating|en_dw_fifowr_clk_gating
		parameter pcs8g_tx_clock_gate_fiford = "<auto_single>", // dis_fiford_clk_gating|en_fiford_clk_gating
		parameter pcs8g_tx_clock_gate_prbs = "<auto_single>", // dis_prbs_clk_gating|en_prbs_clk_gating
		parameter pcs8g_tx_clock_gate_sw_fifowr = "<auto_single>", // dis_sw_fifowr_clk_gating|en_sw_fifowr_clk_gating
		// BONDING_PARAM: parameter pcs8g_tx_ctrl_plane_bonding_compensation = "<auto_single>", // dis_compensation|en_compensation
		// BONDING_PARAM: parameter pcs8g_tx_ctrl_plane_bonding_consumption = "<auto_single>", // individual|bundled_master|bundled_slave_below|bundled_slave_above
		// BONDING_PARAM: parameter pcs8g_tx_ctrl_plane_bonding_distribution = "<auto_single>", // master_chnl_distr|not_master_chnl_distr
		parameter pcs8g_tx_data_selection_8b10b_encoder_input = "<auto_single>", // normal_data_path|xaui_sm|gige_idle_conversion
		parameter pcs8g_tx_dynamic_clk_switch = "<auto_single>", // dis_dyn_clk_switch|en_dyn_clk_switch
		parameter pcs8g_tx_eightb_tenb_disp_ctrl = "<auto_single>", // dis_disp_ctrl|en_disp_ctrl|en_ib_disp_ctrl
		parameter pcs8g_tx_eightb_tenb_encoder = "<auto_single>", // dis_8b10b|en_8b10b_ibm|en_8b10b_sgx
		parameter pcs8g_tx_force_echar = "<auto_single>", // dis_force_echar|en_force_echar
		parameter pcs8g_tx_force_kchar = "<auto_single>", // dis_force_kchar|en_force_kchar
		parameter pcs8g_tx_hip_mode = "<auto_single>", // dis_hip|en_hip
		parameter pcs8g_tx_pcfifo_urst = "<auto_single>", // dis_pcfifourst|en_pcfifourst
		parameter pcs8g_tx_pcs_bypass = "<auto_single>", // dis_pcs_bypass|en_pcs_bypass
		parameter pcs8g_tx_phase_compensation_fifo = "<auto_single>", // low_latency|normal_latency|register_fifo|pld_ctrl_low_latency|pld_ctrl_normal_latency
		parameter pcs8g_tx_phfifo_write_clk_sel = "<auto_single>", // pld_tx_clk|tx_clk
		parameter pcs8g_tx_pma_dw = "<auto_single>", // eight_bit|ten_bit|sixteen_bit|twenty_bit
		parameter pcs8g_tx_polarity_inversion = "<auto_single>", // dis_polinv|enable_polinv
		parameter pcs8g_tx_prbs_gen = "<auto_single>", // dis_prbs|prbs_7_sw|prbs_7_dw|prbs_8|prbs_10|prbs_23_sw|prbs_23_dw|prbs_15|prbs_31|prbs_hf_sw|prbs_hf_dw|prbs_lf_sw|prbs_lf_dw|prbs_mf_sw|prbs_mf_dw
		parameter pcs8g_tx_prot_mode = "<auto_single>", // pipe_g1|pipe_g2|cpri|cpri_rx_tx|gige|xaui|srio_2p1|test|basic|disabled_prot_mode
		parameter pcs8g_tx_refclk_b_clk_sel = "<auto_single>", // tx_pma_clock|refclk_dig
		parameter pcs8g_tx_revloop_back_rm = "<auto_single>", // dis_rev_loopback_rx_rm|en_rev_loopback_rx_rm
		parameter pcs8g_tx_sup_mode = "<auto_single>", // user_mode|engineering_mode
		parameter pcs8g_tx_symbol_swap = "<auto_single>", // dis_symbol_swap|en_symbol_swap
		parameter pcs8g_tx_test_mode = "<auto_single>", // dont_care_test|prbs|bist
		parameter pcs8g_tx_tx_bitslip = "<auto_single>", // dis_tx_bitslip|en_tx_bitslip
		parameter pcs8g_tx_tx_compliance_controlled_disparity = "<auto_single>", // dis_txcompliance|en_txcompliance_pipe2p0
		parameter pcs8g_tx_txclk_freerun = "<auto_single>", // dis_freerun_tx|en_freerun_tx
		parameter pcs8g_tx_txpcs_urst = "<auto_single>", // dis_txpcs_urst|en_txpcs_urst
		parameter pcs8g_tx_use_default_base_address = "true", // false|true
		parameter pcs8g_tx_user_base_address = 0, // 0..2047
		
		// parameters for arriav_hssi_common_pcs_pma_interface
		parameter com_pcs_pma_if_auto_speed_ena = "<auto_single>", // dis_auto_speed_ena|en_auto_speed_ena
		parameter com_pcs_pma_if_force_freqdet = "<auto_single>", // force_freqdet_dis|force1_freqdet_en|force0_freqdet_en
		parameter com_pcs_pma_if_func_mode = "<auto_single>", // disable|hrdrstctrl_cmu|eightg_only_pld|eightg_only_hip|pma_direct
		parameter com_pcs_pma_if_pipe_if_g3pcs = "<auto_single>", // pipe_if_8gpcs
		parameter com_pcs_pma_if_pma_if_dft_en = "dft_dis", // dft_dis
		parameter com_pcs_pma_if_pma_if_dft_val = "dft_0", // dft_0
		parameter com_pcs_pma_if_ppm_cnt_rst = "<auto_single>", // ppm_cnt_rst_dis|ppm_cnt_rst_en
		parameter com_pcs_pma_if_ppm_deassert_early = "<auto_single>", // deassert_early_dis|deassert_early_en
		parameter com_pcs_pma_if_ppm_gen1_2_cnt = "<auto_single>", // cnt_32k|cnt_64k
		parameter com_pcs_pma_if_ppm_post_eidle_delay = "<auto_single>", // cnt_200_cycles|cnt_400_cycles
		parameter com_pcs_pma_if_ppmsel = "<auto_single>", // ppmsel_default|ppmsel_1000|ppmsel_500|ppmsel_300|ppmsel_250|ppmsel_200|ppmsel_125|ppmsel_100|ppmsel_62p5|ppm_other
		parameter com_pcs_pma_if_prot_mode = "<auto_single>", // disabled_prot_mode|pipe_g1|pipe_g2|other_protocols
		parameter com_pcs_pma_if_selectpcs = "<auto_single>", // eight_g_pcs
		parameter com_pcs_pma_if_sup_mode = "<auto_single>", // user_mode|engineering_mode
		parameter com_pcs_pma_if_use_default_base_address = "true", // false|true
		parameter com_pcs_pma_if_user_base_address = 0, // 0..2047
		
		// parameters for arriav_hssi_common_pld_pcs_interface
		parameter com_pld_pcs_if_hip_enable = "hip_disable", // hip_disable|hip_enable
		parameter com_pld_pcs_if_hrdrstctrl_en_cfg = "hrst_dis_cfg", // hrst_dis_cfg|hrst_en_cfg
		parameter com_pld_pcs_if_hrdrstctrl_en_cfgusr = "hrst_dis_cfgusr", // hrst_dis_cfgusr|hrst_en_cfgusr
		parameter com_pld_pcs_if_pld_side_data_source = "pld", // hip|pld
		parameter com_pld_pcs_if_pld_side_reserved_source0 = "pld_res0", // pld_res0|hip_res0
		parameter com_pld_pcs_if_pld_side_reserved_source1 = "pld_res1", // pld_res1|hip_res1
		parameter com_pld_pcs_if_pld_side_reserved_source10 = "pld_res10", // pld_res10|hip_res10
		parameter com_pld_pcs_if_pld_side_reserved_source11 = "pld_res11", // pld_res11|hip_res11
		parameter com_pld_pcs_if_pld_side_reserved_source2 = "pld_res2", // pld_res2|hip_res2
		parameter com_pld_pcs_if_pld_side_reserved_source3 = "pld_res3", // pld_res3|hip_res3
		parameter com_pld_pcs_if_pld_side_reserved_source4 = "pld_res4", // pld_res4|hip_res4
		parameter com_pld_pcs_if_pld_side_reserved_source5 = "pld_res5", // pld_res5|hip_res5
		parameter com_pld_pcs_if_pld_side_reserved_source6 = "pld_res6", // pld_res6|hip_res6
		parameter com_pld_pcs_if_pld_side_reserved_source7 = "pld_res7", // pld_res7|hip_res7
		parameter com_pld_pcs_if_pld_side_reserved_source8 = "pld_res8", // pld_res8|hip_res8
		parameter com_pld_pcs_if_pld_side_reserved_source9 = "pld_res9", // pld_res9|hip_res9
		parameter com_pld_pcs_if_testbus_sel = "eight_g_pcs", // eight_g_pcs|pma_if
		parameter com_pld_pcs_if_use_default_base_address = "true", // false|true
		parameter com_pld_pcs_if_user_base_address = 0, // 0..2047
		parameter com_pld_pcs_if_usrmode_sel4rst = "usermode", // usermode|last_frz
		
		// parameters for arriav_hssi_pipe_gen1_2
		// BONDING_PARAM: parameter pipe12_ctrl_plane_bonding_consumption = "individual", // individual|bundled_master|bundled_slave_below|bundled_slave_above
		parameter pipe12_elec_idle_delay_val = 3'b0,
		parameter pipe12_elecidle_delay = "elec_idle_delay", // elec_idle_delay
		parameter pipe12_error_replace_pad = "<auto_single>", // replace_edb|replace_pad
		parameter pipe12_hip_mode = "<auto_single>", // dis_hip|en_hip
		parameter pipe12_ind_error_reporting = "<auto_single>", // dis_ind_error_reporting|en_ind_error_reporting
		parameter pipe12_phy_status_delay = "phystatus_delay", // phystatus_delay
		parameter pipe12_phystatus_delay_val = 3'b0,
		parameter pipe12_phystatus_rst_toggle = "<auto_single>", // dis_phystatus_rst_toggle|en_phystatus_rst_toggle
		parameter pipe12_pipe_byte_de_serializer_en = "<auto_single>", // dis_bds|en_bds_by_2|dont_care_bds
		parameter pipe12_prot_mode = "<auto_single>", // pipe_g1|pipe_g2|srio_2p1|basic|disabled_prot_mode
		parameter pipe12_rpre_emph_a_val = 6'b0,
		parameter pipe12_rpre_emph_b_val = 6'b0,
		parameter pipe12_rpre_emph_c_val = 6'b0,
		parameter pipe12_rpre_emph_d_val = 6'b0,
		parameter pipe12_rpre_emph_e_val = 6'b0,
		parameter pipe12_rpre_emph_settings = 6'b0,
		parameter pipe12_rvod_sel_a_val = 6'b0,
		parameter pipe12_rvod_sel_b_val = 6'b0,
		parameter pipe12_rvod_sel_c_val = 6'b0,
		parameter pipe12_rvod_sel_d_val = 6'b0,
		parameter pipe12_rvod_sel_e_val = 6'b0,
		parameter pipe12_rvod_sel_settings = 6'b0,
		parameter pipe12_rx_pipe_enable = "<auto_single>", // dis_pipe_rx|en_pipe_rx
		parameter pipe12_rxdetect_bypass = "<auto_single>", // dis_rxdetect_bypass|en_rxdetect_bypass
		parameter pipe12_sup_mode = "user_mode", // user_mode|engineering_mode
		parameter pipe12_tx_pipe_enable = "<auto_single>", // dis_pipe_tx|en_pipe_tx
		parameter pipe12_txswing = "<auto_single>", // dis_txswing|en_txswing
		parameter pipe12_use_default_base_address = "true", // false|true
		parameter pipe12_user_base_address = 0, // 0..2047
		
		// parameters for arriav_hssi_rx_pcs_pma_interface
		parameter rx_pcs_pma_if_clkslip_sel = "<auto_single>", // pld|slip_eight_g_pcs
		parameter rx_pcs_pma_if_prot_mode = "<auto_single>", // other_protocols|cpri_8g
		parameter rx_pcs_pma_if_selectpcs = "eight_g_pcs", // eight_g_pcs|default
		parameter rx_pcs_pma_if_use_default_base_address = "true", // false|true
		parameter rx_pcs_pma_if_user_base_address = 0, // 0..2047
		
		// parameters for arriav_hssi_rx_pld_pcs_interface
		parameter rx_pld_pcs_if_is_8g_0ppm = "false", // false|true
		parameter rx_pld_pcs_if_pcs_side_block_sel = "eight_g_pcs", // eight_g_pcs|default
		parameter rx_pld_pcs_if_pld_side_data_source = "pld", // hip|pld
		parameter rx_pld_pcs_if_use_default_base_address = "true", // false|true
		parameter rx_pld_pcs_if_user_base_address = 0, // 0..2047
		
		// parameters for arriav_hssi_tx_pcs_pma_interface
		parameter tx_pcs_pma_if_selectpcs = "eight_g_pcs", // eight_g_pcs|default
		parameter tx_pcs_pma_if_use_default_base_address = "true", // false|true
		parameter tx_pcs_pma_if_user_base_address = 0, // 0..2047
		
		// parameters for arriav_hssi_tx_pld_pcs_interface
		parameter tx_pld_pcs_if_is_8g_0ppm = "false", // false|true
		parameter tx_pld_pcs_if_pld_side_data_source = "pld", // hip|pld
		parameter tx_pld_pcs_if_use_default_base_address = "true", // false|true
		parameter tx_pld_pcs_if_user_base_address = 0 // 0..2047
	//PARAM_LIST_END
	)
	(
	//PORT_LIST_START
		input wire	[bonded_lanes - 1:0]	in_agg_align_status,
		input wire	[bonded_lanes - 1:0]	in_agg_align_status_sync_0,
		input wire	[bonded_lanes - 1:0]	in_agg_align_status_sync_0_top_or_bot,
		input wire	[bonded_lanes - 1:0]	in_agg_align_status_top_or_bot,
		input wire	[bonded_lanes - 1:0]	in_agg_cg_comp_rd_d_all,
		input wire	[bonded_lanes - 1:0]	in_agg_cg_comp_rd_d_all_top_or_bot,
		input wire	[bonded_lanes - 1:0]	in_agg_cg_comp_wr_all,
		input wire	[bonded_lanes - 1:0]	in_agg_cg_comp_wr_all_top_or_bot,
		input wire	[bonded_lanes - 1:0]	in_agg_del_cond_met_0,
		input wire	[bonded_lanes - 1:0]	in_agg_del_cond_met_0_top_or_bot,
		input wire	[bonded_lanes - 1:0]	in_agg_en_dskw_qd,
		input wire	[bonded_lanes - 1:0]	in_agg_en_dskw_qd_top_or_bot,
		input wire	[bonded_lanes - 1:0]	in_agg_en_dskw_rd_ptrs,
		input wire	[bonded_lanes - 1:0]	in_agg_en_dskw_rd_ptrs_top_or_bot,
		input wire	[bonded_lanes - 1:0]	in_agg_fifo_ovr_0,
		input wire	[bonded_lanes - 1:0]	in_agg_fifo_ovr_0_top_or_bot,
		input wire	[bonded_lanes - 1:0]	in_agg_fifo_rd_in_comp_0,
		input wire	[bonded_lanes - 1:0]	in_agg_fifo_rd_in_comp_0_top_or_bot,
		input wire	[bonded_lanes - 1:0]	in_agg_fifo_rst_rd_qd,
		input wire	[bonded_lanes - 1:0]	in_agg_fifo_rst_rd_qd_top_or_bot,
		input wire	[bonded_lanes - 1:0]	in_agg_insert_incomplete_0,
		input wire	[bonded_lanes - 1:0]	in_agg_insert_incomplete_0_top_or_bot,
		input wire	[bonded_lanes - 1:0]	in_agg_latency_comp_0,
		input wire	[bonded_lanes - 1:0]	in_agg_latency_comp_0_top_or_bot,
		input wire	[bonded_lanes - 1:0]	in_agg_rcvd_clk_agg,
		input wire	[bonded_lanes - 1:0]	in_agg_rcvd_clk_agg_top_or_bot,
		input wire	[bonded_lanes - 1:0]	in_agg_rx_control_rs,
		input wire	[bonded_lanes - 1:0]	in_agg_rx_control_rs_top_or_bot,
		input wire	[bonded_lanes * 8 - 1 : 0]	in_agg_rx_data_rs,
		input wire	[bonded_lanes * 8 - 1 : 0]	in_agg_rx_data_rs_top_or_bot,
		input wire	[bonded_lanes - 1:0]	in_agg_test_so_to_pld_in,
		input wire	[bonded_lanes * 16 - 1 : 0]	in_agg_testbus,
		input wire	[bonded_lanes - 1:0]	in_agg_tx_ctl_ts,
		input wire	[bonded_lanes - 1:0]	in_agg_tx_ctl_ts_top_or_bot,
		input wire	[bonded_lanes * 8 - 1 : 0]	in_agg_tx_data_ts,
		input wire	[bonded_lanes * 8 - 1 : 0]	in_agg_tx_data_ts_top_or_bot,
		input wire	[bonded_lanes * 11 - 1 : 0]	in_avmmaddress,
		input wire	[bonded_lanes * 2 - 1 : 0]	in_avmmbyteen,
		input wire	[bonded_lanes - 1:0]	in_avmmclk,
		input wire	[bonded_lanes - 1:0]	in_avmmread,
		input wire	[bonded_lanes - 1:0]	in_avmmrstn,
		input wire	[bonded_lanes - 1:0]	in_avmmwrite,
		input wire	[bonded_lanes * 16 - 1 : 0]	in_avmmwritedata,
		input wire	[bonded_lanes * 38 - 1 : 0]	in_emsip_com_in,
		input wire	[bonded_lanes * 13 - 1 : 0]	in_emsip_rx_special_in,
		input wire	[bonded_lanes * 104 - 1 : 0]	in_emsip_tx_in,
		input wire	[bonded_lanes * 13 - 1 : 0]	in_emsip_tx_special_in,
		input wire	[bonded_lanes - 1:0]	in_pld_8g_a1a2_size,
		input wire	[bonded_lanes - 1:0]	in_pld_8g_bitloc_rev_en,
		input wire	[bonded_lanes - 1:0]	in_pld_8g_bitslip,
		input wire	[bonded_lanes - 1:0]	in_pld_8g_byte_rev_en,
		input wire	[bonded_lanes - 1:0]	in_pld_8g_bytordpld,
		input wire	[bonded_lanes - 1:0]	in_pld_8g_cmpfifourst_n,
		input wire	[bonded_lanes - 1:0]	in_pld_8g_encdt,
		input wire	[bonded_lanes - 1:0]	in_pld_8g_phfifourst_rx_n,
		input wire	[bonded_lanes - 1:0]	in_pld_8g_phfifourst_tx_n,
		input wire	[bonded_lanes - 1:0]	in_pld_8g_pld_rx_clk,
		input wire	[bonded_lanes - 1:0]	in_pld_8g_pld_tx_clk,
		input wire	[bonded_lanes - 1:0]	in_pld_8g_polinv_rx,
		input wire	[bonded_lanes - 1:0]	in_pld_8g_polinv_tx,
		input wire	[bonded_lanes * 2 - 1 : 0]	in_pld_8g_powerdown,
		input wire	[bonded_lanes - 1:0]	in_pld_8g_prbs_cid_en,
		input wire	[bonded_lanes - 1:0]	in_pld_8g_rddisable_tx,
		input wire	[bonded_lanes - 1:0]	in_pld_8g_rdenable_rmf,
		input wire	[bonded_lanes - 1:0]	in_pld_8g_rdenable_rx,
		input wire	[bonded_lanes - 1:0]	in_pld_8g_refclk_dig,
		input wire	[bonded_lanes - 1:0]	in_pld_8g_refclk_dig2,
		input wire	[bonded_lanes - 1:0]	in_pld_8g_rev_loopbk,
		input wire	[bonded_lanes - 1:0]	in_pld_8g_rxpolarity,
		input wire	[bonded_lanes - 1:0]	in_pld_8g_rxurstpcs_n,
		input wire	[bonded_lanes * 5 - 1 : 0]	in_pld_8g_tx_boundary_sel,
		input wire	[bonded_lanes * 4 - 1 : 0]	in_pld_8g_tx_data_valid,
		input wire	[bonded_lanes - 1:0]	in_pld_8g_txdeemph,
		input wire	[bonded_lanes - 1:0]	in_pld_8g_txdetectrxloopback,
		input wire	[bonded_lanes - 1:0]	in_pld_8g_txelecidle,
		input wire	[bonded_lanes * 3 - 1 : 0]	in_pld_8g_txmargin,
		input wire	[bonded_lanes - 1:0]	in_pld_8g_txswing,
		input wire	[bonded_lanes - 1:0]	in_pld_8g_txurstpcs_n,
		input wire	[bonded_lanes - 1:0]	in_pld_8g_wrdisable_rx,
		input wire	[bonded_lanes - 1:0]	in_pld_8g_wrenable_rmf,
		input wire	[bonded_lanes - 1:0]	in_pld_8g_wrenable_tx,
		input wire	[bonded_lanes - 1:0]	in_pld_agg_refclk_dig,
		input wire	[bonded_lanes * 3 - 1 : 0]	in_pld_eidleinfersel,
		input wire	[bonded_lanes - 1:0]	in_pld_ltr,
		input wire	[bonded_lanes - 1:0]	in_pld_partial_reconfig_in,
		input wire	[bonded_lanes - 1:0]	in_pld_pcs_pma_if_refclk_dig,
		input wire	[bonded_lanes - 1:0]	in_pld_rate,
		input wire	[bonded_lanes * 12 - 1 : 0]	in_pld_reserved_in,
		input wire	[bonded_lanes - 1:0]	in_pld_rx_clk_slip_in,
		input wire	[bonded_lanes - 1:0]	in_pld_rxpma_rstb_in,
		input wire	[bonded_lanes - 1:0]	in_pld_scan_mode_n,
		input wire	[bonded_lanes - 1:0]	in_pld_scan_shift_n,
		input wire	[bonded_lanes - 1:0]	in_pld_sync_sm_en,
		input wire	[bonded_lanes * 44 - 1 : 0]	in_pld_tx_data,
		input wire	[bonded_lanes - 1:0]	in_pma_clklow_in,
		input wire	[bonded_lanes - 1:0]	in_pma_fref_in,
		input wire	[bonded_lanes - 1:0]	in_pma_hclk,
		input wire	[bonded_lanes - 1:0]	in_pma_pcie_sw_done,
		input wire	[bonded_lanes * 5 - 1 : 0]	in_pma_reserved_in,
		input wire	[bonded_lanes * 20 - 1 : 0]	in_pma_rx_data,
		input wire	[bonded_lanes - 1:0]	in_pma_rx_detect_valid,
		input wire	[bonded_lanes - 1:0]	in_pma_rx_found,
		input wire	[bonded_lanes - 1:0]	in_pma_rx_freq_tx_cmu_pll_lock_in,
		input wire	[bonded_lanes - 1:0]	in_pma_rx_pll_phase_lock_in,
		input wire	[bonded_lanes - 1:0]	in_pma_rx_pma_clk,
		input wire	[bonded_lanes - 1:0]	in_pma_sigdet,
		input wire	[bonded_lanes - 1:0]	in_pma_tx_pma_clk,
		output wire	[bonded_lanes * 2 - 1 : 0]	out_agg_align_det_sync,
		output wire	[bonded_lanes - 1:0]	out_agg_align_status_sync,
		output wire	[bonded_lanes * 2 - 1 : 0]	out_agg_cg_comp_rd_d_out,
		output wire	[bonded_lanes * 2 - 1 : 0]	out_agg_cg_comp_wr_out,
		output wire	[bonded_lanes - 1:0]	out_agg_dec_ctl,
		output wire	[bonded_lanes * 8 - 1 : 0]	out_agg_dec_data,
		output wire	[bonded_lanes - 1:0]	out_agg_dec_data_valid,
		output wire	[bonded_lanes - 1:0]	out_agg_del_cond_met_out,
		output wire	[bonded_lanes - 1:0]	out_agg_fifo_ovr_out,
		output wire	[bonded_lanes - 1:0]	out_agg_fifo_rd_out_comp,
		output wire	[bonded_lanes - 1:0]	out_agg_insert_incomplete_out,
		output wire	[bonded_lanes - 1:0]	out_agg_latency_comp_out,
		output wire	[bonded_lanes * 2 - 1 : 0]	out_agg_rd_align,
		output wire	[bonded_lanes - 1:0]	out_agg_rd_enable_sync,
		output wire	[bonded_lanes - 1:0]	out_agg_refclk_dig,
		output wire	[bonded_lanes * 2 - 1 : 0]	out_agg_running_disp,
		output wire	[bonded_lanes - 1:0]	out_agg_rxpcs_rst,
		output wire	[bonded_lanes - 1:0]	out_agg_scan_mode_n,
		output wire	[bonded_lanes - 1:0]	out_agg_scan_shift_n,
		output wire	[bonded_lanes - 1:0]	out_agg_sync_status,
		output wire	[bonded_lanes - 1:0]	out_agg_tx_ctl_tc,
		output wire	[bonded_lanes * 8 - 1 : 0]	out_agg_tx_data_tc,
		output wire	[bonded_lanes - 1:0]	out_agg_txpcs_rst,
		output wire	[bonded_lanes * 16 - 1 : 0]	out_avmmreaddata_com_pcs_pma_if,
		output wire	[bonded_lanes * 16 - 1 : 0]	out_avmmreaddata_com_pld_pcs_if,
		output wire	[bonded_lanes * 16 - 1 : 0]	out_avmmreaddata_pcs8g_rx,
		output wire	[bonded_lanes * 16 - 1 : 0]	out_avmmreaddata_pcs8g_tx,
		output wire	[bonded_lanes * 16 - 1 : 0]	out_avmmreaddata_pipe12,
		output wire	[bonded_lanes * 16 - 1 : 0]	out_avmmreaddata_rx_pcs_pma_if,
		output wire	[bonded_lanes * 16 - 1 : 0]	out_avmmreaddata_rx_pld_pcs_if,
		output wire	[bonded_lanes * 16 - 1 : 0]	out_avmmreaddata_tx_pcs_pma_if,
		output wire	[bonded_lanes * 16 - 1 : 0]	out_avmmreaddata_tx_pld_pcs_if,
		output wire	[bonded_lanes - 1:0]	out_blockselect_com_pcs_pma_if,
		output wire	[bonded_lanes - 1:0]	out_blockselect_com_pld_pcs_if,
		output wire	[bonded_lanes - 1:0]	out_blockselect_pcs8g_rx,
		output wire	[bonded_lanes - 1:0]	out_blockselect_pcs8g_tx,
		output wire	[bonded_lanes - 1:0]	out_blockselect_pipe12,
		output wire	[bonded_lanes - 1:0]	out_blockselect_rx_pcs_pma_if,
		output wire	[bonded_lanes - 1:0]	out_blockselect_rx_pld_pcs_if,
		output wire	[bonded_lanes - 1:0]	out_blockselect_tx_pcs_pma_if,
		output wire	[bonded_lanes - 1:0]	out_blockselect_tx_pld_pcs_if,
		output wire	[bonded_lanes * 3 - 1 : 0]	out_emsip_com_clk_out,
		output wire	[bonded_lanes * 27 - 1 : 0]	out_emsip_com_out,
		output wire	[bonded_lanes * 129 - 1 : 0]	out_emsip_rx_out,
		output wire	[bonded_lanes * 16 - 1 : 0]	out_emsip_rx_special_out,
		output wire	[bonded_lanes * 3 - 1 : 0]	out_emsip_tx_clk_out,
		output wire	[bonded_lanes * 16 - 1 : 0]	out_emsip_tx_special_out,
		output wire	[bonded_lanes * 4 - 1 : 0]	out_pld_8g_a1a2_k1k2_flag,
		output wire	[bonded_lanes - 1:0]	out_pld_8g_align_status,
		output wire	[bonded_lanes - 1:0]	out_pld_8g_bistdone,
		output wire	[bonded_lanes - 1:0]	out_pld_8g_bisterr,
		output wire	[bonded_lanes - 1:0]	out_pld_8g_byteord_flag,
		output wire	[bonded_lanes - 1:0]	out_pld_8g_empty_rmf,
		output wire	[bonded_lanes - 1:0]	out_pld_8g_empty_rx,
		output wire	[bonded_lanes - 1:0]	out_pld_8g_empty_tx,
		output wire	[bonded_lanes - 1:0]	out_pld_8g_full_rmf,
		output wire	[bonded_lanes - 1:0]	out_pld_8g_full_rx,
		output wire	[bonded_lanes - 1:0]	out_pld_8g_full_tx,
		output wire	[bonded_lanes - 1:0]	out_pld_8g_phystatus,
		output wire	[bonded_lanes - 1:0]	out_pld_8g_rlv_lt,
		output wire	[bonded_lanes - 1:0]	out_pld_8g_rx_clk_out,
		output wire	[bonded_lanes * 4 - 1 : 0]	out_pld_8g_rx_data_valid,
		output wire	[bonded_lanes - 1:0]	out_pld_8g_rxelecidle,
		output wire	[bonded_lanes * 3 - 1 : 0]	out_pld_8g_rxstatus,
		output wire	[bonded_lanes - 1:0]	out_pld_8g_rxvalid,
		output wire	[bonded_lanes - 1:0]	out_pld_8g_signal_detect_out,
		output wire	[bonded_lanes - 1:0]	out_pld_8g_tx_clk_out,
		output wire	[bonded_lanes * 5 - 1 : 0]	out_pld_8g_wa_boundary,
		output wire	[bonded_lanes - 1:0]	out_pld_clklow,
		output wire	[bonded_lanes - 1:0]	out_pld_fref,
		output wire	[bonded_lanes * 11 - 1 : 0]	out_pld_reserved_out,
		output wire	[bonded_lanes * 64 - 1 : 0]	out_pld_rx_data,
		output wire	[bonded_lanes * 20 - 1 : 0]	out_pld_test_data,
		output wire	[bonded_lanes - 1:0]	out_pld_test_si_to_agg_out,
		output wire	[bonded_lanes * 12 - 1 : 0]	out_pma_current_coeff,
		output wire	[bonded_lanes - 1:0]	out_pma_early_eios,
		output wire	[bonded_lanes - 1:0]	out_pma_ltr,
		output wire	[bonded_lanes - 1:0]	out_pma_nfrzdrv,
		output wire	[bonded_lanes - 1:0]	out_pma_partial_reconfig,
		output wire	[bonded_lanes - 1:0]	out_pma_pcie_switch,
		output wire	[bonded_lanes - 1:0]	out_pma_ppm_lock,
		output wire	[bonded_lanes * 5 - 1 : 0]	out_pma_reserved_out,
		output wire	[bonded_lanes - 1:0]	out_pma_rx_clk_out,
		output wire	[bonded_lanes - 1:0]	out_pma_rxclkslip,
		output wire	[bonded_lanes - 1:0]	out_pma_rxpma_rstb,
		output wire	[bonded_lanes - 1:0]	out_pma_tx_clk_out,
		output wire	[bonded_lanes * 20 - 1 : 0]	out_pma_tx_data,
		output wire	[bonded_lanes - 1:0]	out_pma_tx_elec_idle,
		output wire	[bonded_lanes - 1:0]	out_pma_txdetectrx
	//PORT_LIST_END
	);
	//wire declarations for bonded connections
	
	// module arriav_hssi_8g_rx_pcs
	wire [(bonded_lanes + 2)- 1:0] w_pcs8g_rx_wrenableoutchnlup;
	wire [(bonded_lanes + 2)- 1:0] w_pcs8g_rx_rdenableoutchnlup;
	wire [(bonded_lanes + 2) * 2 - 1 : 0] w_pcs8g_rx_rxdivsyncoutchnlup;
	wire [(bonded_lanes + 2)- 1:0] w_pcs8g_rx_resetppmcntrsoutchnlup;
	wire [(bonded_lanes + 2)- 1:0] w_pcs8g_rx_configseloutchnlup;
	wire [(bonded_lanes + 2)- 1:0] w_pcs8g_rx_speedchangeoutchnlup;
	wire [(bonded_lanes + 2) * 2 - 1 : 0] w_pcs8g_rx_rxweoutchnlup;
	wire [(bonded_lanes + 2)- 1:0] w_pcs8g_rx_resetpcptrsoutchnlup;
	wire [(bonded_lanes + 2)- 1:0] w_pcs8g_rx_speedchangeoutchnldown;
	wire [(bonded_lanes + 2) * 2 - 1 : 0] w_pcs8g_rx_rxweoutchnldown;
	wire [(bonded_lanes + 2)- 1:0] w_pcs8g_rx_wrenableoutchnldown;
	wire [(bonded_lanes + 2) * 2 - 1 : 0] w_pcs8g_rx_rxdivsyncoutchnldown;
	wire [(bonded_lanes + 2)- 1:0] w_pcs8g_rx_resetppmcntrsoutchnldown;
	wire [(bonded_lanes + 2)- 1:0] w_pcs8g_rx_resetpcptrsoutchnldown;
	wire [(bonded_lanes + 2)- 1:0] w_pcs8g_rx_rdenableoutchnldown;
	wire [(bonded_lanes + 2)- 1:0] w_pcs8g_rx_configseloutchnldown;
	
	// module arriav_hssi_8g_tx_pcs
	wire [(bonded_lanes + 2)- 1:0] w_pcs8g_tx_wrenableoutchnlup;
	wire [(bonded_lanes + 2)- 1:0] w_pcs8g_tx_rdenableoutchnlup;
	wire [(bonded_lanes + 2) * 2 - 1 : 0] w_pcs8g_tx_txdivsyncoutchnlup;
	wire [(bonded_lanes + 2) * 2 - 1 : 0] w_pcs8g_tx_fifoselectoutchnlup;
	wire [(bonded_lanes + 2) * 2 - 1 : 0] w_pcs8g_tx_fifoselectoutchnldown;
	wire [(bonded_lanes + 2)- 1:0] w_pcs8g_tx_wrenableoutchnldown;
	wire [(bonded_lanes + 2) * 2 - 1 : 0] w_pcs8g_tx_txdivsyncoutchnldown;
	wire [(bonded_lanes + 2)- 1:0] w_pcs8g_tx_rdenableoutchnldown;
	
	
	// instantiation of av_pcs_ch
	genvar i;
	generate
	for (i=0; i < bonded_lanes; i = i + 1)
	begin:ch
		av_pcs_ch #(
			// parameters
			.enable_8g_rx (enable_8g_rx),
			.enable_8g_tx (enable_8g_tx),
			.enable_dyn_reconfig (enable_dyn_reconfig),
			.enable_gen12_pipe (enable_gen12_pipe),
			.channel_number (i),
			.enable_pma_direct_tx (enable_pma_direct_tx),
			.enable_pma_direct_rx (enable_pma_direct_rx),	
			
			// parameters for arriav_hssi_8g_rx_pcs
			.pcs8g_rx_agg_block_sel(pcs8g_rx_agg_block_sel),
			.pcs8g_rx_auto_error_replacement(pcs8g_rx_auto_error_replacement),
			.pcs8g_rx_auto_speed_nego(pcs8g_rx_auto_speed_nego),
			.pcs8g_rx_bist_ver(pcs8g_rx_bist_ver),
			.pcs8g_rx_bist_ver_clr_flag(pcs8g_rx_bist_ver_clr_flag),
			.pcs8g_rx_bit_reversal(pcs8g_rx_bit_reversal),
			.pcs8g_rx_bo_pad(pcs8g_rx_bo_pad),
			.pcs8g_rx_bo_pattern(pcs8g_rx_bo_pattern),
			.pcs8g_rx_bypass_pipeline_reg(pcs8g_rx_bypass_pipeline_reg),
			.pcs8g_rx_byte_deserializer(pcs8g_rx_byte_deserializer),
			.pcs8g_rx_byte_order(pcs8g_rx_byte_order),
			.pcs8g_rx_cdr_ctrl(pcs8g_rx_cdr_ctrl),
			.pcs8g_rx_cdr_ctrl_rxvalid_mask(pcs8g_rx_cdr_ctrl_rxvalid_mask),
			.pcs8g_rx_cid_pattern(pcs8g_rx_cid_pattern),
			.pcs8g_rx_cid_pattern_len(pcs8g_rx_cid_pattern_len),
			.pcs8g_rx_clkcmp_pattern_n(pcs8g_rx_clkcmp_pattern_n),
			.pcs8g_rx_clkcmp_pattern_p(pcs8g_rx_clkcmp_pattern_p),
			.pcs8g_rx_clock_gate_bds_dec_asn(pcs8g_rx_clock_gate_bds_dec_asn),
			.pcs8g_rx_clock_gate_bist(pcs8g_rx_clock_gate_bist),
			.pcs8g_rx_clock_gate_byteorder(pcs8g_rx_clock_gate_byteorder),
			.pcs8g_rx_clock_gate_cdr_eidle(pcs8g_rx_clock_gate_cdr_eidle),
			.pcs8g_rx_clock_gate_dskw_rd(pcs8g_rx_clock_gate_dskw_rd),
			.pcs8g_rx_clock_gate_dw_dskw_wr(pcs8g_rx_clock_gate_dw_dskw_wr),
			.pcs8g_rx_clock_gate_dw_pc_wrclk(pcs8g_rx_clock_gate_dw_pc_wrclk),
			.pcs8g_rx_clock_gate_dw_rm_rd(pcs8g_rx_clock_gate_dw_rm_rd),
			.pcs8g_rx_clock_gate_dw_rm_wr(pcs8g_rx_clock_gate_dw_rm_wr),
			.pcs8g_rx_clock_gate_dw_wa(pcs8g_rx_clock_gate_dw_wa),
			.pcs8g_rx_clock_gate_pc_rdclk(pcs8g_rx_clock_gate_pc_rdclk),
			.pcs8g_rx_clock_gate_prbs(pcs8g_rx_clock_gate_prbs),
			.pcs8g_rx_clock_gate_sw_dskw_wr(pcs8g_rx_clock_gate_sw_dskw_wr),
			.pcs8g_rx_clock_gate_sw_pc_wrclk(pcs8g_rx_clock_gate_sw_pc_wrclk),
			.pcs8g_rx_clock_gate_sw_rm_rd(pcs8g_rx_clock_gate_sw_rm_rd),
			.pcs8g_rx_clock_gate_sw_rm_wr(pcs8g_rx_clock_gate_sw_rm_wr),
			.pcs8g_rx_clock_gate_sw_wa(pcs8g_rx_clock_gate_sw_wa),
			.pcs8g_rx_comp_fifo_rst_pld_ctrl(pcs8g_rx_comp_fifo_rst_pld_ctrl),
			.pcs8g_rx_ctrl_plane_bonding_compensation(
((pcs8g_rx_prot_mode!="pipe_g1")&& (pcs8g_rx_prot_mode!="pipe_g2")&& (pcs8g_rx_prot_mode!="pipe_g3")&& (pcs8g_rx_prot_mode!="xaui"))? "dis_compensation" :
(pcs8g_rx_byte_deserializer=="en_bds_by_4") ? "en_compensation" :
 "dis_compensation"
),
			.pcs8g_rx_ctrl_plane_bonding_consumption(
((pcs8g_rx_prot_mode!="pipe_g1")&& (pcs8g_rx_prot_mode!="pipe_g2")&& (pcs8g_rx_prot_mode!="pipe_g3")&& (pcs8g_rx_prot_mode!="xaui"))? "individual" :
(bonded_lanes==1)? "individual":
(i==bonding_master_ch)? "bundled_master":
(i < bonding_master_ch)? "bundled_slave_below":
"bundled_slave_above"
),
			.pcs8g_rx_ctrl_plane_bonding_distribution(
((pcs8g_rx_prot_mode!="pipe_g1")&& (pcs8g_rx_prot_mode!="pipe_g2")&& (pcs8g_rx_prot_mode!="pipe_g3")&& (pcs8g_rx_prot_mode!="xaui"))? "not_master_chnl_distr" :
(bonded_lanes==1)? "not_master_chnl_distr":
 (i==bonding_master_ch)? "master_chnl_distr":
"not_master_chnl_distr"
),
			.pcs8g_rx_deskew(pcs8g_rx_deskew),
			.pcs8g_rx_deskew_pattern(pcs8g_rx_deskew_pattern),
			.pcs8g_rx_deskew_prog_pattern_only(pcs8g_rx_deskew_prog_pattern_only),
			.pcs8g_rx_dw_one_or_two_symbol_bo(pcs8g_rx_dw_one_or_two_symbol_bo),
			.pcs8g_rx_eidle_entry_eios(pcs8g_rx_eidle_entry_eios),
			.pcs8g_rx_eidle_entry_iei(pcs8g_rx_eidle_entry_iei),
			.pcs8g_rx_eidle_entry_sd(pcs8g_rx_eidle_entry_sd),
			.pcs8g_rx_eightb_tenb_decoder(pcs8g_rx_eightb_tenb_decoder),
			.pcs8g_rx_eightbtenb_decoder_output_sel(pcs8g_rx_eightbtenb_decoder_output_sel),
			.pcs8g_rx_err_flags_sel(pcs8g_rx_err_flags_sel),
			.pcs8g_rx_fixed_pat_det(pcs8g_rx_fixed_pat_det),
			.pcs8g_rx_fixed_pat_num(pcs8g_rx_fixed_pat_num),
			.pcs8g_rx_force_signal_detect(pcs8g_rx_force_signal_detect),
			.pcs8g_rx_hip_mode(pcs8g_rx_hip_mode),
			.pcs8g_rx_ibm_invalid_code(pcs8g_rx_ibm_invalid_code),
			.pcs8g_rx_invalid_code_flag_only(pcs8g_rx_invalid_code_flag_only),
			.pcs8g_rx_mask_cnt(pcs8g_rx_mask_cnt),
			.pcs8g_rx_pad_or_edb_error_replace(pcs8g_rx_pad_or_edb_error_replace),
			.pcs8g_rx_pc_fifo_rst_pld_ctrl(pcs8g_rx_pc_fifo_rst_pld_ctrl),
			.pcs8g_rx_pcs_bypass(pcs8g_rx_pcs_bypass),
			.pcs8g_rx_phase_compensation_fifo(pcs8g_rx_phase_compensation_fifo),
			.pcs8g_rx_pipe_if_enable(pcs8g_rx_pipe_if_enable),
			.pcs8g_rx_pma_done_count(pcs8g_rx_pma_done_count),
			.pcs8g_rx_pma_dw(pcs8g_rx_pma_dw),
			.pcs8g_rx_polarity_inversion(pcs8g_rx_polarity_inversion),
			.pcs8g_rx_polinv_8b10b_dec(pcs8g_rx_polinv_8b10b_dec),
			.pcs8g_rx_prbs_ver(pcs8g_rx_prbs_ver),
			.pcs8g_rx_prbs_ver_clr_flag(pcs8g_rx_prbs_ver_clr_flag),
			.pcs8g_rx_prot_mode(pcs8g_rx_prot_mode),
			.pcs8g_rx_rate_match(pcs8g_rx_rate_match),
			.pcs8g_rx_re_bo_on_wa(pcs8g_rx_re_bo_on_wa),
			.pcs8g_rx_runlength_check(pcs8g_rx_runlength_check),
			.pcs8g_rx_runlength_val(pcs8g_rx_runlength_val),
			.pcs8g_rx_rx_clk1(pcs8g_rx_rx_clk1),
			.pcs8g_rx_rx_clk2(pcs8g_rx_rx_clk2),
			.pcs8g_rx_rx_clk_free_running(pcs8g_rx_rx_clk_free_running),
			.pcs8g_rx_rx_pcs_urst(pcs8g_rx_rx_pcs_urst),
			.pcs8g_rx_rx_rcvd_clk(pcs8g_rx_rx_rcvd_clk),
			.pcs8g_rx_rx_rd_clk(pcs8g_rx_rx_rd_clk),
			.pcs8g_rx_rx_refclk(pcs8g_rx_rx_refclk),
			.pcs8g_rx_rx_wr_clk(pcs8g_rx_rx_wr_clk),
			.pcs8g_rx_sup_mode(pcs8g_rx_sup_mode),
			.pcs8g_rx_symbol_swap(pcs8g_rx_symbol_swap),
			.pcs8g_rx_test_bus_sel(pcs8g_rx_test_bus_sel),
			.pcs8g_rx_test_mode(pcs8g_rx_test_mode),
			.pcs8g_rx_tx_rx_parallel_loopback(pcs8g_rx_tx_rx_parallel_loopback),
			.pcs8g_rx_use_default_base_address(pcs8g_rx_use_default_base_address),
			.pcs8g_rx_user_base_address(pcs8g_rx_user_base_address),
			.pcs8g_rx_wa_boundary_lock_ctrl(pcs8g_rx_wa_boundary_lock_ctrl),
			.pcs8g_rx_wa_clk_slip_spacing(pcs8g_rx_wa_clk_slip_spacing),
			.pcs8g_rx_wa_clk_slip_spacing_data(pcs8g_rx_wa_clk_slip_spacing_data),
			.pcs8g_rx_wa_det_latency_sync_status_beh(pcs8g_rx_wa_det_latency_sync_status_beh),
			.pcs8g_rx_wa_disp_err_flag(pcs8g_rx_wa_disp_err_flag),
			.pcs8g_rx_wa_kchar(pcs8g_rx_wa_kchar),
			.pcs8g_rx_wa_pd(pcs8g_rx_wa_pd),
			.pcs8g_rx_wa_pd_data(pcs8g_rx_wa_pd_data),
			.pcs8g_rx_wa_pd_polarity(pcs8g_rx_wa_pd_polarity),
			.pcs8g_rx_wa_pld_controlled(pcs8g_rx_wa_pld_controlled),
			.pcs8g_rx_wa_renumber_data(pcs8g_rx_wa_renumber_data),
			.pcs8g_rx_wa_rgnumber_data(pcs8g_rx_wa_rgnumber_data),
			.pcs8g_rx_wa_rknumber_data(pcs8g_rx_wa_rknumber_data),
			.pcs8g_rx_wa_rosnumber_data(pcs8g_rx_wa_rosnumber_data),
			.pcs8g_rx_wa_rvnumber_data(pcs8g_rx_wa_rvnumber_data),
			.pcs8g_rx_wa_sync_sm_ctrl(pcs8g_rx_wa_sync_sm_ctrl),
			.pcs8g_rx_wait_cnt(pcs8g_rx_wait_cnt),
			
			// parameters for arriav_hssi_8g_tx_pcs
			.pcs8g_tx_agg_block_sel(pcs8g_tx_agg_block_sel),
			.pcs8g_tx_auto_speed_nego_gen2(pcs8g_tx_auto_speed_nego_gen2),
			.pcs8g_tx_bist_gen(pcs8g_tx_bist_gen),
			.pcs8g_tx_bit_reversal(pcs8g_tx_bit_reversal),
			.pcs8g_tx_bypass_pipeline_reg(pcs8g_tx_bypass_pipeline_reg),
			.pcs8g_tx_byte_serializer(pcs8g_tx_byte_serializer),
			.pcs8g_tx_cid_pattern(pcs8g_tx_cid_pattern),
			.pcs8g_tx_cid_pattern_len(pcs8g_tx_cid_pattern_len),
			.pcs8g_tx_clock_gate_bist(pcs8g_tx_clock_gate_bist),
			.pcs8g_tx_clock_gate_bs_enc(pcs8g_tx_clock_gate_bs_enc),
			.pcs8g_tx_clock_gate_dw_fifowr(pcs8g_tx_clock_gate_dw_fifowr),
			.pcs8g_tx_clock_gate_fiford(pcs8g_tx_clock_gate_fiford),
			.pcs8g_tx_clock_gate_prbs(pcs8g_tx_clock_gate_prbs),
			.pcs8g_tx_clock_gate_sw_fifowr(pcs8g_tx_clock_gate_sw_fifowr),
			.pcs8g_tx_ctrl_plane_bonding_compensation(
(pcs8g_rx_byte_deserializer=="en_bds_by_4") ? "en_compensation" : "dis_compensation"
),
			.pcs8g_tx_ctrl_plane_bonding_consumption(
(bonded_lanes==1)? "individual":
(i==bonding_master_ch)? "bundled_master":
(i<bonding_master_ch)? "bundled_slave_below":
"bundled_slave_above"
),
			.pcs8g_tx_ctrl_plane_bonding_distribution(
(bonded_lanes==1)? "not_master_chnl_distr" :
(i==bonding_master_ch)? "master_chnl_distr" :
"not_master_chnl_distr"
),
			.pcs8g_tx_data_selection_8b10b_encoder_input(pcs8g_tx_data_selection_8b10b_encoder_input),
			.pcs8g_tx_dynamic_clk_switch(pcs8g_tx_dynamic_clk_switch),
			.pcs8g_tx_eightb_tenb_disp_ctrl(pcs8g_tx_eightb_tenb_disp_ctrl),
			.pcs8g_tx_eightb_tenb_encoder(pcs8g_tx_eightb_tenb_encoder),
			.pcs8g_tx_force_echar(pcs8g_tx_force_echar),
			.pcs8g_tx_force_kchar(pcs8g_tx_force_kchar),
			.pcs8g_tx_hip_mode(pcs8g_tx_hip_mode),
			.pcs8g_tx_pcfifo_urst(pcs8g_tx_pcfifo_urst),
			.pcs8g_tx_pcs_bypass(pcs8g_tx_pcs_bypass),
			.pcs8g_tx_phase_compensation_fifo(pcs8g_tx_phase_compensation_fifo),
			.pcs8g_tx_phfifo_write_clk_sel(pcs8g_tx_phfifo_write_clk_sel),
			.pcs8g_tx_pma_dw(pcs8g_tx_pma_dw),
			.pcs8g_tx_polarity_inversion(pcs8g_tx_polarity_inversion),
			.pcs8g_tx_prbs_gen(pcs8g_tx_prbs_gen),
			.pcs8g_tx_prot_mode(pcs8g_tx_prot_mode),
			.pcs8g_tx_refclk_b_clk_sel(pcs8g_tx_refclk_b_clk_sel),
			.pcs8g_tx_revloop_back_rm(pcs8g_tx_revloop_back_rm),
			.pcs8g_tx_sup_mode(pcs8g_tx_sup_mode),
			.pcs8g_tx_symbol_swap(pcs8g_tx_symbol_swap),
			.pcs8g_tx_test_mode(pcs8g_tx_test_mode),
			.pcs8g_tx_tx_bitslip(pcs8g_tx_tx_bitslip),
			.pcs8g_tx_tx_compliance_controlled_disparity(pcs8g_tx_tx_compliance_controlled_disparity),
			.pcs8g_tx_txclk_freerun(pcs8g_tx_txclk_freerun),
			.pcs8g_tx_txpcs_urst(pcs8g_tx_txpcs_urst),
			.pcs8g_tx_use_default_base_address(pcs8g_tx_use_default_base_address),
			.pcs8g_tx_user_base_address(pcs8g_tx_user_base_address),
			
			// parameters for arriav_hssi_common_pcs_pma_interface
			.com_pcs_pma_if_auto_speed_ena(com_pcs_pma_if_auto_speed_ena),
			.com_pcs_pma_if_force_freqdet(com_pcs_pma_if_force_freqdet),
			.com_pcs_pma_if_func_mode(com_pcs_pma_if_func_mode),
			.com_pcs_pma_if_pipe_if_g3pcs(com_pcs_pma_if_pipe_if_g3pcs),
			.com_pcs_pma_if_pma_if_dft_en(com_pcs_pma_if_pma_if_dft_en),
			.com_pcs_pma_if_pma_if_dft_val(com_pcs_pma_if_pma_if_dft_val),
			.com_pcs_pma_if_ppm_cnt_rst(com_pcs_pma_if_ppm_cnt_rst),
			.com_pcs_pma_if_ppm_deassert_early(com_pcs_pma_if_ppm_deassert_early),
			.com_pcs_pma_if_ppm_gen1_2_cnt(com_pcs_pma_if_ppm_gen1_2_cnt),
			.com_pcs_pma_if_ppm_post_eidle_delay(com_pcs_pma_if_ppm_post_eidle_delay),
			.com_pcs_pma_if_ppmsel(com_pcs_pma_if_ppmsel),
			.com_pcs_pma_if_prot_mode(com_pcs_pma_if_prot_mode),
			.com_pcs_pma_if_selectpcs(com_pcs_pma_if_selectpcs),
			.com_pcs_pma_if_sup_mode(com_pcs_pma_if_sup_mode),
			.com_pcs_pma_if_use_default_base_address(com_pcs_pma_if_use_default_base_address),
			.com_pcs_pma_if_user_base_address(com_pcs_pma_if_user_base_address),
			
			// parameters for arriav_hssi_common_pld_pcs_interface
			.com_pld_pcs_if_hip_enable(com_pld_pcs_if_hip_enable),
			.com_pld_pcs_if_hrdrstctrl_en_cfg(com_pld_pcs_if_hrdrstctrl_en_cfg),
			.com_pld_pcs_if_hrdrstctrl_en_cfgusr(com_pld_pcs_if_hrdrstctrl_en_cfgusr),
			.com_pld_pcs_if_pld_side_data_source(com_pld_pcs_if_pld_side_data_source),
			.com_pld_pcs_if_pld_side_reserved_source0(com_pld_pcs_if_pld_side_reserved_source0),
			.com_pld_pcs_if_pld_side_reserved_source1(com_pld_pcs_if_pld_side_reserved_source1),
			.com_pld_pcs_if_pld_side_reserved_source10(com_pld_pcs_if_pld_side_reserved_source10),
			.com_pld_pcs_if_pld_side_reserved_source11(com_pld_pcs_if_pld_side_reserved_source11),
			.com_pld_pcs_if_pld_side_reserved_source2(com_pld_pcs_if_pld_side_reserved_source2),
			.com_pld_pcs_if_pld_side_reserved_source3(com_pld_pcs_if_pld_side_reserved_source3),
			.com_pld_pcs_if_pld_side_reserved_source4(com_pld_pcs_if_pld_side_reserved_source4),
			.com_pld_pcs_if_pld_side_reserved_source5(com_pld_pcs_if_pld_side_reserved_source5),
			.com_pld_pcs_if_pld_side_reserved_source6(com_pld_pcs_if_pld_side_reserved_source6),
			.com_pld_pcs_if_pld_side_reserved_source7(com_pld_pcs_if_pld_side_reserved_source7),
			.com_pld_pcs_if_pld_side_reserved_source8(com_pld_pcs_if_pld_side_reserved_source8),
			.com_pld_pcs_if_pld_side_reserved_source9(com_pld_pcs_if_pld_side_reserved_source9),
			.com_pld_pcs_if_testbus_sel(com_pld_pcs_if_testbus_sel),
			.com_pld_pcs_if_use_default_base_address(com_pld_pcs_if_use_default_base_address),
			.com_pld_pcs_if_user_base_address(com_pld_pcs_if_user_base_address),
			.com_pld_pcs_if_usrmode_sel4rst(com_pld_pcs_if_usrmode_sel4rst),
			
			// parameters for arriav_hssi_pipe_gen1_2
			.pipe12_ctrl_plane_bonding_consumption(
((pcs8g_rx_prot_mode!="pipe_g1")&& (pcs8g_rx_prot_mode!="pipe_g2")&& (pcs8g_rx_prot_mode!="xaui"))? "individual" :
(bonded_lanes==1)? "individual":
(i==bonding_master_ch)? "bundled_master":
(i<bonding_master_ch)? "bundled_slave_below":
"bundled_slave_above"
),
			.pipe12_elec_idle_delay_val(pipe12_elec_idle_delay_val),
			.pipe12_elecidle_delay(pipe12_elecidle_delay),
			.pipe12_error_replace_pad(pipe12_error_replace_pad),
			.pipe12_hip_mode(pipe12_hip_mode),
			.pipe12_ind_error_reporting(pipe12_ind_error_reporting),
			.pipe12_phy_status_delay(pipe12_phy_status_delay),
			.pipe12_phystatus_delay_val(pipe12_phystatus_delay_val),
			.pipe12_phystatus_rst_toggle(pipe12_phystatus_rst_toggle),
			.pipe12_pipe_byte_de_serializer_en(pipe12_pipe_byte_de_serializer_en),
			.pipe12_prot_mode(pipe12_prot_mode),
			.pipe12_rpre_emph_a_val(pipe12_rpre_emph_a_val),
			.pipe12_rpre_emph_b_val(pipe12_rpre_emph_b_val),
			.pipe12_rpre_emph_c_val(pipe12_rpre_emph_c_val),
			.pipe12_rpre_emph_d_val(pipe12_rpre_emph_d_val),
			.pipe12_rpre_emph_e_val(pipe12_rpre_emph_e_val),
			.pipe12_rpre_emph_settings(pipe12_rpre_emph_settings),
			.pipe12_rvod_sel_a_val(pipe12_rvod_sel_a_val),
			.pipe12_rvod_sel_b_val(pipe12_rvod_sel_b_val),
			.pipe12_rvod_sel_c_val(pipe12_rvod_sel_c_val),
			.pipe12_rvod_sel_d_val(pipe12_rvod_sel_d_val),
			.pipe12_rvod_sel_e_val(pipe12_rvod_sel_e_val),
			.pipe12_rvod_sel_settings(pipe12_rvod_sel_settings),
			.pipe12_rx_pipe_enable(pipe12_rx_pipe_enable),
			.pipe12_rxdetect_bypass(pipe12_rxdetect_bypass),
			.pipe12_sup_mode(pipe12_sup_mode),
			.pipe12_tx_pipe_enable(pipe12_tx_pipe_enable),
			.pipe12_txswing(pipe12_txswing),
			.pipe12_use_default_base_address(pipe12_use_default_base_address),
			.pipe12_user_base_address(pipe12_user_base_address),
			
			// parameters for arriav_hssi_rx_pcs_pma_interface
			.rx_pcs_pma_if_clkslip_sel(rx_pcs_pma_if_clkslip_sel),
			.rx_pcs_pma_if_prot_mode(rx_pcs_pma_if_prot_mode),
			.rx_pcs_pma_if_selectpcs(rx_pcs_pma_if_selectpcs),
			.rx_pcs_pma_if_use_default_base_address(rx_pcs_pma_if_use_default_base_address),
			.rx_pcs_pma_if_user_base_address(rx_pcs_pma_if_user_base_address),
			
			// parameters for arriav_hssi_rx_pld_pcs_interface
			.rx_pld_pcs_if_is_8g_0ppm(rx_pld_pcs_if_is_8g_0ppm),
			.rx_pld_pcs_if_pcs_side_block_sel(rx_pld_pcs_if_pcs_side_block_sel),
			.rx_pld_pcs_if_pld_side_data_source(rx_pld_pcs_if_pld_side_data_source),
			.rx_pld_pcs_if_use_default_base_address(rx_pld_pcs_if_use_default_base_address),
			.rx_pld_pcs_if_user_base_address(rx_pld_pcs_if_user_base_address),
			
			// parameters for arriav_hssi_tx_pcs_pma_interface
			.tx_pcs_pma_if_selectpcs(tx_pcs_pma_if_selectpcs),
			.tx_pcs_pma_if_use_default_base_address(tx_pcs_pma_if_use_default_base_address),
			.tx_pcs_pma_if_user_base_address(tx_pcs_pma_if_user_base_address),
			
			// parameters for arriav_hssi_tx_pld_pcs_interface
			.tx_pld_pcs_if_is_8g_0ppm(tx_pld_pcs_if_is_8g_0ppm),
			.tx_pld_pcs_if_pld_side_data_source(tx_pld_pcs_if_pld_side_data_source),
			.tx_pld_pcs_if_use_default_base_address(tx_pld_pcs_if_use_default_base_address),
			.tx_pld_pcs_if_user_base_address(tx_pld_pcs_if_user_base_address)
		) inst_av_pcs_ch (
			// ports
			.in_agg_align_status(in_agg_align_status[i]),
			.in_agg_align_status_sync_0(in_agg_align_status_sync_0[i]),
			.in_agg_align_status_sync_0_top_or_bot(in_agg_align_status_sync_0_top_or_bot[i]),
			.in_agg_align_status_top_or_bot(in_agg_align_status_top_or_bot[i]),
			.in_agg_cg_comp_rd_d_all(in_agg_cg_comp_rd_d_all[i]),
			.in_agg_cg_comp_rd_d_all_top_or_bot(in_agg_cg_comp_rd_d_all_top_or_bot[i]),
			.in_agg_cg_comp_wr_all(in_agg_cg_comp_wr_all[i]),
			.in_agg_cg_comp_wr_all_top_or_bot(in_agg_cg_comp_wr_all_top_or_bot[i]),
			.in_agg_del_cond_met_0(in_agg_del_cond_met_0[i]),
			.in_agg_del_cond_met_0_top_or_bot(in_agg_del_cond_met_0_top_or_bot[i]),
			.in_agg_en_dskw_qd(in_agg_en_dskw_qd[i]),
			.in_agg_en_dskw_qd_top_or_bot(in_agg_en_dskw_qd_top_or_bot[i]),
			.in_agg_en_dskw_rd_ptrs(in_agg_en_dskw_rd_ptrs[i]),
			.in_agg_en_dskw_rd_ptrs_top_or_bot(in_agg_en_dskw_rd_ptrs_top_or_bot[i]),
			.in_agg_fifo_ovr_0(in_agg_fifo_ovr_0[i]),
			.in_agg_fifo_ovr_0_top_or_bot(in_agg_fifo_ovr_0_top_or_bot[i]),
			.in_agg_fifo_rd_in_comp_0(in_agg_fifo_rd_in_comp_0[i]),
			.in_agg_fifo_rd_in_comp_0_top_or_bot(in_agg_fifo_rd_in_comp_0_top_or_bot[i]),
			.in_agg_fifo_rst_rd_qd(in_agg_fifo_rst_rd_qd[i]),
			.in_agg_fifo_rst_rd_qd_top_or_bot(in_agg_fifo_rst_rd_qd_top_or_bot[i]),
			.in_agg_insert_incomplete_0(in_agg_insert_incomplete_0[i]),
			.in_agg_insert_incomplete_0_top_or_bot(in_agg_insert_incomplete_0_top_or_bot[i]),
			.in_agg_latency_comp_0(in_agg_latency_comp_0[i]),
			.in_agg_latency_comp_0_top_or_bot(in_agg_latency_comp_0_top_or_bot[i]),
			.in_agg_rcvd_clk_agg(in_agg_rcvd_clk_agg[i]),
			.in_agg_rcvd_clk_agg_top_or_bot(in_agg_rcvd_clk_agg_top_or_bot[i]),
			.in_agg_rx_control_rs(in_agg_rx_control_rs[i]),
			.in_agg_rx_control_rs_top_or_bot(in_agg_rx_control_rs_top_or_bot[i]),
			.in_agg_rx_data_rs(in_agg_rx_data_rs[(i + 1) * 8 - 1 : i * 8]),
			.in_agg_rx_data_rs_top_or_bot(in_agg_rx_data_rs_top_or_bot[(i + 1) * 8 - 1 : i * 8]),
			.in_agg_test_so_to_pld_in(in_agg_test_so_to_pld_in[i]),
			.in_agg_testbus(in_agg_testbus[(i + 1) * 16 - 1 : i * 16]),
			.in_agg_tx_ctl_ts(in_agg_tx_ctl_ts[i]),
			.in_agg_tx_ctl_ts_top_or_bot(in_agg_tx_ctl_ts_top_or_bot[i]),
			.in_agg_tx_data_ts(in_agg_tx_data_ts[(i + 1) * 8 - 1 : i * 8]),
			.in_agg_tx_data_ts_top_or_bot(in_agg_tx_data_ts_top_or_bot[(i + 1) * 8 - 1 : i * 8]),
			.in_avmmaddress(in_avmmaddress[(i + 1) * 11 - 1 : i * 11]),
			.in_avmmbyteen(in_avmmbyteen[(i + 1) * 2 - 1 : i * 2]),
			.in_avmmclk(in_avmmclk[i]),
			.in_avmmread(in_avmmread[i]),
			.in_avmmrstn(in_avmmrstn[i]),
			.in_avmmwrite(in_avmmwrite[i]),
			.in_avmmwritedata(in_avmmwritedata[(i + 1) * 16 - 1 : i * 16]),
			.in_config_sel_in_chnl_down(w_pcs8g_rx_configseloutchnlup[i + 0]),
			.in_config_sel_in_chnl_up(w_pcs8g_rx_configseloutchnldown[i + 2]),
			.in_emsip_com_in(in_emsip_com_in[(i + 1) * 38 - 1 : i * 38]),
			.in_emsip_rx_special_in(in_emsip_rx_special_in[(i + 1) * 13 - 1 : i * 13]),
			.in_emsip_tx_in(in_emsip_tx_in[(i + 1) * 104 - 1 : i * 104]),
			.in_emsip_tx_special_in(in_emsip_tx_special_in[(i + 1) * 13 - 1 : i * 13]),
			.in_fifo_select_in_chnl_down(w_pcs8g_tx_fifoselectoutchnlup[(i + 1) * 2 - 1 : (i + 0) * 2]),
			.in_fifo_select_in_chnl_up(w_pcs8g_tx_fifoselectoutchnldown[(i + 3) * 2 - 1 : (i + 2) * 2]),
			.in_pld_8g_a1a2_size(in_pld_8g_a1a2_size[i]),
			.in_pld_8g_bitloc_rev_en(in_pld_8g_bitloc_rev_en[i]),
			.in_pld_8g_bitslip(in_pld_8g_bitslip[i]),
			.in_pld_8g_byte_rev_en(in_pld_8g_byte_rev_en[i]),
			.in_pld_8g_bytordpld(in_pld_8g_bytordpld[i]),
			.in_pld_8g_cmpfifourst_n(in_pld_8g_cmpfifourst_n[i]),
			.in_pld_8g_encdt(in_pld_8g_encdt[i]),
			.in_pld_8g_phfifourst_rx_n(in_pld_8g_phfifourst_rx_n[i]),
			.in_pld_8g_phfifourst_tx_n(in_pld_8g_phfifourst_tx_n[i]),
			.in_pld_8g_pld_rx_clk(in_pld_8g_pld_rx_clk[i]),
			.in_pld_8g_pld_tx_clk(in_pld_8g_pld_tx_clk[i]),
			.in_pld_8g_polinv_rx(in_pld_8g_polinv_rx[i]),
			.in_pld_8g_polinv_tx(in_pld_8g_polinv_tx[i]),
			.in_pld_8g_powerdown(in_pld_8g_powerdown[(i + 1) * 2 - 1 : i * 2]),
			.in_pld_8g_prbs_cid_en(in_pld_8g_prbs_cid_en[i]),
			.in_pld_8g_rddisable_tx(in_pld_8g_rddisable_tx[i]),
			.in_pld_8g_rdenable_rmf(in_pld_8g_rdenable_rmf[i]),
			.in_pld_8g_rdenable_rx(in_pld_8g_rdenable_rx[i]),
			.in_pld_8g_refclk_dig(in_pld_8g_refclk_dig[i]),
			.in_pld_8g_refclk_dig2(in_pld_8g_refclk_dig2[i]),
			.in_pld_8g_rev_loopbk(in_pld_8g_rev_loopbk[i]),
			.in_pld_8g_rxpolarity(in_pld_8g_rxpolarity[i]),
			.in_pld_8g_rxurstpcs_n(in_pld_8g_rxurstpcs_n[i]),
			.in_pld_8g_tx_boundary_sel(in_pld_8g_tx_boundary_sel[(i + 1) * 5 - 1 : i * 5]),
			.in_pld_8g_tx_data_valid(in_pld_8g_tx_data_valid[(i + 1) * 4 - 1 : i * 4]),
			.in_pld_8g_txdeemph(in_pld_8g_txdeemph[i]),
			.in_pld_8g_txdetectrxloopback(in_pld_8g_txdetectrxloopback[i]),
			.in_pld_8g_txelecidle(in_pld_8g_txelecidle[i]),
			.in_pld_8g_txmargin(in_pld_8g_txmargin[(i + 1) * 3 - 1 : i * 3]),
			.in_pld_8g_txswing(in_pld_8g_txswing[i]),
			.in_pld_8g_txurstpcs_n(in_pld_8g_txurstpcs_n[i]),
			.in_pld_8g_wrdisable_rx(in_pld_8g_wrdisable_rx[i]),
			.in_pld_8g_wrenable_rmf(in_pld_8g_wrenable_rmf[i]),
			.in_pld_8g_wrenable_tx(in_pld_8g_wrenable_tx[i]),
			.in_pld_agg_refclk_dig(in_pld_agg_refclk_dig[i]),
			.in_pld_eidleinfersel(in_pld_eidleinfersel[(i + 1) * 3 - 1 : i * 3]),
			.in_pld_ltr(in_pld_ltr[i]),
			.in_pld_partial_reconfig_in(in_pld_partial_reconfig_in[i]),
			.in_pld_pcs_pma_if_refclk_dig(in_pld_pcs_pma_if_refclk_dig[i]),
			.in_pld_rate(in_pld_rate[i]),
			.in_pld_reserved_in(in_pld_reserved_in[(i + 1) * 12 - 1 : i * 12]),
			.in_pld_rx_clk_slip_in(in_pld_rx_clk_slip_in[i]),
			.in_pld_rxpma_rstb_in(in_pld_rxpma_rstb_in[i]),
			.in_pld_scan_mode_n(in_pld_scan_mode_n[i]),
			.in_pld_scan_shift_n(in_pld_scan_shift_n[i]),
			.in_pld_sync_sm_en(in_pld_sync_sm_en[i]),
			.in_pld_tx_data(in_pld_tx_data[(i + 1) * 44 - 1 : i * 44]),
			.in_pma_clklow_in(in_pma_clklow_in[i]),
			.in_pma_fref_in(in_pma_fref_in[i]),
			.in_pma_hclk(in_pma_hclk[i]),
			.in_pma_pcie_sw_done(in_pma_pcie_sw_done[i]),
			.in_pma_reserved_in(in_pma_reserved_in[(i + 1) * 5 - 1 : i * 5]),
			.in_pma_rx_data(in_pma_rx_data[(i + 1) * 20 - 1 : i * 20]),
			.in_pma_rx_detect_valid(in_pma_rx_detect_valid[i]),
			.in_pma_rx_found(in_pma_rx_found[i]),
			.in_pma_rx_freq_tx_cmu_pll_lock_in(in_pma_rx_freq_tx_cmu_pll_lock_in[i]),
			.in_pma_rx_pll_phase_lock_in(in_pma_rx_pll_phase_lock_in[i]),
			.in_pma_rx_pma_clk(in_pma_rx_pma_clk[i]),
			.in_pma_sigdet(in_pma_sigdet[i]),
			.in_pma_tx_pma_clk(in_pma_tx_pma_clk[i]),
			.in_reset_pc_ptrs_in_chnl_down(w_pcs8g_rx_resetpcptrsoutchnlup[i + 0]),
			.in_reset_pc_ptrs_in_chnl_up(w_pcs8g_rx_resetpcptrsoutchnldown[i + 2]),
			.in_reset_ppm_cntrs_in_chnl_down(w_pcs8g_rx_resetppmcntrsoutchnlup[i + 0]),
			.in_reset_ppm_cntrs_in_chnl_up(w_pcs8g_rx_resetppmcntrsoutchnldown[i + 2]),
			.in_rx_div_sync_in_chnl_down(w_pcs8g_rx_rxdivsyncoutchnlup[(i + 1) * 2 - 1 : (i + 0) * 2]),
			.in_rx_div_sync_in_chnl_up(w_pcs8g_rx_rxdivsyncoutchnldown[(i + 3) * 2 - 1 : (i + 2) * 2]),
			.in_rx_rd_enable_in_chnl_down(w_pcs8g_rx_rdenableoutchnlup[i + 0]),
			.in_rx_rd_enable_in_chnl_up(w_pcs8g_rx_rdenableoutchnldown[i + 2]),
			.in_rx_we_in_chnl_down(w_pcs8g_rx_rxweoutchnlup[(i + 1) * 2 - 1 : (i + 0) * 2]),
			.in_rx_we_in_chnl_up(w_pcs8g_rx_rxweoutchnldown[(i + 3) * 2 - 1 : (i + 2) * 2]),
			.in_rx_wr_enable_in_chnl_down(w_pcs8g_rx_wrenableoutchnlup[i + 0]),
			.in_rx_wr_enable_in_chnl_up(w_pcs8g_rx_wrenableoutchnldown[i + 2]),
			.in_speed_change_in_chnl_down(w_pcs8g_rx_speedchangeoutchnlup[i + 0]),
			.in_speed_change_in_chnl_up(w_pcs8g_rx_speedchangeoutchnldown[i + 2]),
			.in_tx_div_sync_in_chnl_down(w_pcs8g_tx_txdivsyncoutchnlup[(i + 1) * 2 - 1 : (i + 0) * 2]),
			.in_tx_div_sync_in_chnl_up(w_pcs8g_tx_txdivsyncoutchnldown[(i + 3) * 2 - 1 : (i + 2) * 2]),
			.in_tx_rd_enable_in_chnl_down(w_pcs8g_tx_rdenableoutchnlup[i + 0]),
			.in_tx_rd_enable_in_chnl_up(w_pcs8g_tx_rdenableoutchnldown[i + 2]),
			.in_tx_wr_enable_in_chnl_down(w_pcs8g_tx_wrenableoutchnlup[i + 0]),
			.in_tx_wr_enable_in_chnl_up(w_pcs8g_tx_wrenableoutchnldown[i + 2]),
			.out_agg_align_det_sync(out_agg_align_det_sync[(i + 1) * 2 - 1 : i * 2]),
			.out_agg_align_status_sync(out_agg_align_status_sync[i]),
			.out_agg_cg_comp_rd_d_out(out_agg_cg_comp_rd_d_out[(i + 1) * 2 - 1 : i * 2]),
			.out_agg_cg_comp_wr_out(out_agg_cg_comp_wr_out[(i + 1) * 2 - 1 : i * 2]),
			.out_agg_dec_ctl(out_agg_dec_ctl[i]),
			.out_agg_dec_data(out_agg_dec_data[(i + 1) * 8 - 1 : i * 8]),
			.out_agg_dec_data_valid(out_agg_dec_data_valid[i]),
			.out_agg_del_cond_met_out(out_agg_del_cond_met_out[i]),
			.out_agg_fifo_ovr_out(out_agg_fifo_ovr_out[i]),
			.out_agg_fifo_rd_out_comp(out_agg_fifo_rd_out_comp[i]),
			.out_agg_insert_incomplete_out(out_agg_insert_incomplete_out[i]),
			.out_agg_latency_comp_out(out_agg_latency_comp_out[i]),
			.out_agg_rd_align(out_agg_rd_align[(i + 1) * 2 - 1 : i * 2]),
			.out_agg_rd_enable_sync(out_agg_rd_enable_sync[i]),
			.out_agg_refclk_dig(out_agg_refclk_dig[i]),
			.out_agg_running_disp(out_agg_running_disp[(i + 1) * 2 - 1 : i * 2]),
			.out_agg_rxpcs_rst(out_agg_rxpcs_rst[i]),
			.out_agg_scan_mode_n(out_agg_scan_mode_n[i]),
			.out_agg_scan_shift_n(out_agg_scan_shift_n[i]),
			.out_agg_sync_status(out_agg_sync_status[i]),
			.out_agg_tx_ctl_tc(out_agg_tx_ctl_tc[i]),
			.out_agg_tx_data_tc(out_agg_tx_data_tc[(i + 1) * 8 - 1 : i * 8]),
			.out_agg_txpcs_rst(out_agg_txpcs_rst[i]),
			.out_avmmreaddata_com_pcs_pma_if(out_avmmreaddata_com_pcs_pma_if[(i + 1) * 16 - 1 : i * 16]),
			.out_avmmreaddata_com_pld_pcs_if(out_avmmreaddata_com_pld_pcs_if[(i + 1) * 16 - 1 : i * 16]),
			.out_avmmreaddata_pcs8g_rx(out_avmmreaddata_pcs8g_rx[(i + 1) * 16 - 1 : i * 16]),
			.out_avmmreaddata_pcs8g_tx(out_avmmreaddata_pcs8g_tx[(i + 1) * 16 - 1 : i * 16]),
			.out_avmmreaddata_pipe12(out_avmmreaddata_pipe12[(i + 1) * 16 - 1 : i * 16]),
			.out_avmmreaddata_rx_pcs_pma_if(out_avmmreaddata_rx_pcs_pma_if[(i + 1) * 16 - 1 : i * 16]),
			.out_avmmreaddata_rx_pld_pcs_if(out_avmmreaddata_rx_pld_pcs_if[(i + 1) * 16 - 1 : i * 16]),
			.out_avmmreaddata_tx_pcs_pma_if(out_avmmreaddata_tx_pcs_pma_if[(i + 1) * 16 - 1 : i * 16]),
			.out_avmmreaddata_tx_pld_pcs_if(out_avmmreaddata_tx_pld_pcs_if[(i + 1) * 16 - 1 : i * 16]),
			.out_blockselect_com_pcs_pma_if(out_blockselect_com_pcs_pma_if[i]),
			.out_blockselect_com_pld_pcs_if(out_blockselect_com_pld_pcs_if[i]),
			.out_blockselect_pcs8g_rx(out_blockselect_pcs8g_rx[i]),
			.out_blockselect_pcs8g_tx(out_blockselect_pcs8g_tx[i]),
			.out_blockselect_pipe12(out_blockselect_pipe12[i]),
			.out_blockselect_rx_pcs_pma_if(out_blockselect_rx_pcs_pma_if[i]),
			.out_blockselect_rx_pld_pcs_if(out_blockselect_rx_pld_pcs_if[i]),
			.out_blockselect_tx_pcs_pma_if(out_blockselect_tx_pcs_pma_if[i]),
			.out_blockselect_tx_pld_pcs_if(out_blockselect_tx_pld_pcs_if[i]),
			.out_config_sel_out_chnl_down(w_pcs8g_rx_configseloutchnldown[i + 1]),
			.out_config_sel_out_chnl_up(w_pcs8g_rx_configseloutchnlup[i + 1]),
			.out_emsip_com_clk_out(out_emsip_com_clk_out[(i + 1) * 3 - 1 : i * 3]),
			.out_emsip_com_out(out_emsip_com_out[(i + 1) * 27 - 1 : i * 27]),
			.out_emsip_rx_out(out_emsip_rx_out[(i + 1) * 129 - 1 : i * 129]),
			.out_emsip_rx_special_out(out_emsip_rx_special_out[(i + 1) * 16 - 1 : i * 16]),
			.out_emsip_tx_clk_out(out_emsip_tx_clk_out[(i + 1) * 3 - 1 : i * 3]),
			.out_emsip_tx_special_out(out_emsip_tx_special_out[(i + 1) * 16 - 1 : i * 16]),
			.out_fifo_select_out_chnl_down(w_pcs8g_tx_fifoselectoutchnldown[(i + 2) * 2 - 1 : (i + 1) * 2]),
			.out_fifo_select_out_chnl_up(w_pcs8g_tx_fifoselectoutchnlup[(i + 2) * 2 - 1 : (i + 1) * 2]),
			.out_pld_8g_a1a2_k1k2_flag(out_pld_8g_a1a2_k1k2_flag[(i + 1) * 4 - 1 : i * 4]),
			.out_pld_8g_align_status(out_pld_8g_align_status[i]),
			.out_pld_8g_bistdone(out_pld_8g_bistdone[i]),
			.out_pld_8g_bisterr(out_pld_8g_bisterr[i]),
			.out_pld_8g_byteord_flag(out_pld_8g_byteord_flag[i]),
			.out_pld_8g_empty_rmf(out_pld_8g_empty_rmf[i]),
			.out_pld_8g_empty_rx(out_pld_8g_empty_rx[i]),
			.out_pld_8g_empty_tx(out_pld_8g_empty_tx[i]),
			.out_pld_8g_full_rmf(out_pld_8g_full_rmf[i]),
			.out_pld_8g_full_rx(out_pld_8g_full_rx[i]),
			.out_pld_8g_full_tx(out_pld_8g_full_tx[i]),
			.out_pld_8g_phystatus(out_pld_8g_phystatus[i]),
			.out_pld_8g_rlv_lt(out_pld_8g_rlv_lt[i]),
			.out_pld_8g_rx_clk_out(out_pld_8g_rx_clk_out[i]),
			.out_pld_8g_rx_data_valid(out_pld_8g_rx_data_valid[(i + 1) * 4 - 1 : i * 4]),
			.out_pld_8g_rxelecidle(out_pld_8g_rxelecidle[i]),
			.out_pld_8g_rxstatus(out_pld_8g_rxstatus[(i + 1) * 3 - 1 : i * 3]),
			.out_pld_8g_rxvalid(out_pld_8g_rxvalid[i]),
			.out_pld_8g_signal_detect_out(out_pld_8g_signal_detect_out[i]),
			.out_pld_8g_tx_clk_out(out_pld_8g_tx_clk_out[i]),
			.out_pld_8g_wa_boundary(out_pld_8g_wa_boundary[(i + 1) * 5 - 1 : i * 5]),
			.out_pld_clklow(out_pld_clklow[i]),
			.out_pld_fref(out_pld_fref[i]),
			.out_pld_reserved_out(out_pld_reserved_out[(i + 1) * 11 - 1 : i * 11]),
			.out_pld_rx_data(out_pld_rx_data[(i + 1) * 64 - 1 : i * 64]),
			.out_pld_test_data(out_pld_test_data[(i + 1) * 20 - 1 : i * 20]),
			.out_pld_test_si_to_agg_out(out_pld_test_si_to_agg_out[i]),
			.out_pma_current_coeff(out_pma_current_coeff[(i + 1) * 12 - 1 : i * 12]),
			.out_pma_early_eios(out_pma_early_eios[i]),
			.out_pma_ltr(out_pma_ltr[i]),
			.out_pma_nfrzdrv(out_pma_nfrzdrv[i]),
			.out_pma_partial_reconfig(out_pma_partial_reconfig[i]),
			.out_pma_pcie_switch(out_pma_pcie_switch[i]),
			.out_pma_ppm_lock(out_pma_ppm_lock[i]),
			.out_pma_reserved_out(out_pma_reserved_out[(i + 1) * 5 - 1 : i * 5]),
			.out_pma_rx_clk_out(out_pma_rx_clk_out[i]),
			.out_pma_rxclkslip(out_pma_rxclkslip[i]),
			.out_pma_rxpma_rstb(out_pma_rxpma_rstb[i]),
			.out_pma_tx_clk_out(out_pma_tx_clk_out[i]),
			.out_pma_tx_data(out_pma_tx_data[(i + 1) * 20 - 1 : i * 20]),
			.out_pma_tx_elec_idle(out_pma_tx_elec_idle[i]),
			.out_pma_txdetectrx(out_pma_txdetectrx[i]),
			.out_reset_pc_ptrs_out_chnl_down(w_pcs8g_rx_resetpcptrsoutchnldown[i + 1]),
			.out_reset_pc_ptrs_out_chnl_up(w_pcs8g_rx_resetpcptrsoutchnlup[i + 1]),
			.out_reset_ppm_cntrs_out_chnl_down(w_pcs8g_rx_resetppmcntrsoutchnldown[i + 1]),
			.out_reset_ppm_cntrs_out_chnl_up(w_pcs8g_rx_resetppmcntrsoutchnlup[i + 1]),
			.out_rx_div_sync_out_chnl_down(w_pcs8g_rx_rxdivsyncoutchnldown[(i + 2) * 2 - 1 : (i + 1) * 2]),
			.out_rx_div_sync_out_chnl_up(w_pcs8g_rx_rxdivsyncoutchnlup[(i + 2) * 2 - 1 : (i + 1) * 2]),
			.out_rx_rd_enable_out_chnl_down(w_pcs8g_rx_rdenableoutchnldown[i + 1]),
			.out_rx_rd_enable_out_chnl_up(w_pcs8g_rx_rdenableoutchnlup[i + 1]),
			.out_rx_we_out_chnl_down(w_pcs8g_rx_rxweoutchnldown[(i + 2) * 2 - 1 : (i + 1) * 2]),
			.out_rx_we_out_chnl_up(w_pcs8g_rx_rxweoutchnlup[(i + 2) * 2 - 1 : (i + 1) * 2]),
			.out_rx_wr_enable_out_chnl_down(w_pcs8g_rx_wrenableoutchnldown[i + 1]),
			.out_rx_wr_enable_out_chnl_up(w_pcs8g_rx_wrenableoutchnlup[i + 1]),
			.out_speed_change_out_chnl_down(w_pcs8g_rx_speedchangeoutchnldown[i + 1]),
			.out_speed_change_out_chnl_up(w_pcs8g_rx_speedchangeoutchnlup[i + 1]),
			.out_tx_div_sync_out_chnl_down(w_pcs8g_tx_txdivsyncoutchnldown[(i + 2) * 2 - 1 : (i + 1) * 2]),
			.out_tx_div_sync_out_chnl_up(w_pcs8g_tx_txdivsyncoutchnlup[(i + 2) * 2 - 1 : (i + 1) * 2]),
			.out_tx_rd_enable_out_chnl_down(w_pcs8g_tx_rdenableoutchnldown[i + 1]),
			.out_tx_rd_enable_out_chnl_up(w_pcs8g_tx_rdenableoutchnlup[i + 1]),
			.out_tx_wr_enable_out_chnl_down(w_pcs8g_tx_wrenableoutchnldown[i + 1]),
			.out_tx_wr_enable_out_chnl_up(w_pcs8g_tx_wrenableoutchnlup[i + 1])
		);
	end
	endgenerate
	
	// Tie-off bonding control-plane input signals for SpyGlass warnings.
         assign w_pcs8g_rx_rxdivsyncoutchnlup[1:0] = 2'b00;                  
         assign w_pcs8g_rx_rxdivsyncoutchnldown[(bonded_lanes + 2) * 2 - 1 : (bonded_lanes + 2) * 2 - 2] = 2'b00;         
         assign w_pcs8g_rx_rxweoutchnlup[1:0] = 2'b00;         
         assign w_pcs8g_rx_rxweoutchnldown[(bonded_lanes + 2) * 2 - 1 : (bonded_lanes + 2) * 2 - 2] = 2'b00;         
         assign w_pcs8g_tx_txdivsyncoutchnlup[1:0] = 2'b00;         
         assign w_pcs8g_tx_txdivsyncoutchnldown[(bonded_lanes + 2) * 2 - 1 : (bonded_lanes + 2) * 2 - 2] = 2'b00;
         assign w_pcs8g_tx_fifoselectoutchnlup[1:0] = 2'b00;
         assign w_pcs8g_tx_fifoselectoutchnldown[(bonded_lanes + 2) * 2 - 1 : (bonded_lanes + 2) * 2 - 2] = 2'b00;

         assign w_pcs8g_rx_configseloutchnlup[0] = 1'b0;
         assign w_pcs8g_rx_configseloutchnldown[bonded_lanes+1]= 1'b0;
         assign w_pcs8g_rx_resetpcptrsoutchnlup[0] = 1'b0;
         assign w_pcs8g_rx_resetpcptrsoutchnldown[bonded_lanes+1]= 1'b0;
         assign w_pcs8g_rx_resetppmcntrsoutchnlup[0] = 1'b0;
         assign w_pcs8g_rx_resetppmcntrsoutchnldown[bonded_lanes+1]= 1'b0;
         assign w_pcs8g_rx_rdenableoutchnlup[0] = 1'b0;
         assign w_pcs8g_rx_rdenableoutchnldown[bonded_lanes+1]= 1'b0;
         assign w_pcs8g_rx_wrenableoutchnlup[0] = 1'b0;
         assign w_pcs8g_rx_wrenableoutchnldown[bonded_lanes+1]= 1'b0;
         assign w_pcs8g_rx_speedchangeoutchnlup[0] = 1'b0;
         assign w_pcs8g_rx_speedchangeoutchnldown[bonded_lanes+1]= 1'b0;
         assign w_pcs8g_tx_rdenableoutchnlup[0] = 1'b0;
         assign w_pcs8g_tx_rdenableoutchnldown[bonded_lanes+1]= 1'b0;
         assign w_pcs8g_tx_wrenableoutchnlup[0] = 1'b0;
         assign w_pcs8g_tx_wrenableoutchnldown[bonded_lanes+1]= 1'b0;
endmodule
