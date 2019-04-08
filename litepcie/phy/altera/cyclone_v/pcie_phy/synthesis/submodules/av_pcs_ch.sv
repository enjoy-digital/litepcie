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
// av_pcs_ch.sv
// automatically generated at 23:1:59, Fri Aug 26, 2011
//
//


// This module contains the following atoms:
// 	av_hssi_rx_pcs_pma_interface
// 	av_hssi_8g_rx_pcs
// 	av_hssi_8g_tx_pcs
// 	av_hssi_tx_pld_pcs_interface
// 	av_hssi_rx_pld_pcs_interface
// 	av_hssi_pipe_gen1_2
// 	av_hssi_common_pcs_pma_interface
// 	av_hssi_common_pld_pcs_interface
// 	av_hssi_tx_pcs_pma_interface

`timescale 1ps/1ps

module av_pcs_ch
	#(
		parameter enable_8g_rx = "true",
		parameter enable_8g_tx = "true",
		parameter enable_dyn_reconfig = "true",
		parameter enable_gen12_pipe = "true",
		parameter channel_number = 0,
		parameter enable_pma_direct_tx = "false",                    // (true,false) Enable, disable the PMA Direct path
	    parameter enable_pma_direct_rx = "false",                    // (true,false) Enable, disable the PMA Direct path			
		
		// parameters for av_hssi_8g_rx_pcs
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
		parameter pcs8g_rx_ctrl_plane_bonding_compensation = "<auto_single>", // dis_compensation|en_compensation
		parameter pcs8g_rx_ctrl_plane_bonding_consumption = "<auto_single>", // individual|bundled_master|bundled_slave_below|bundled_slave_above
		parameter pcs8g_rx_ctrl_plane_bonding_distribution = "<auto_single>", // master_chnl_distr|not_master_chnl_distr
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
		
		// parameters for av_hssi_8g_tx_pcs
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
		parameter pcs8g_tx_ctrl_plane_bonding_compensation = "<auto_single>", // dis_compensation|en_compensation
		parameter pcs8g_tx_ctrl_plane_bonding_consumption = "<auto_single>", // individual|bundled_master|bundled_slave_below|bundled_slave_above
		parameter pcs8g_tx_ctrl_plane_bonding_distribution = "<auto_single>", // master_chnl_distr|not_master_chnl_distr
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
		
		// parameters for av_hssi_common_pcs_pma_interface
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
		
		// parameters for av_hssi_common_pld_pcs_interface
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
		
		// parameters for av_hssi_pipe_gen1_2
		parameter pipe12_ctrl_plane_bonding_consumption = "individual", // individual|bundled_master|bundled_slave_below|bundled_slave_above
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
		
		// parameters for av_hssi_rx_pcs_pma_interface
		parameter rx_pcs_pma_if_clkslip_sel = "<auto_single>", // pld|slip_eight_g_pcs
		parameter rx_pcs_pma_if_prot_mode = "<auto_single>", // other_protocols|cpri_8g
		parameter rx_pcs_pma_if_selectpcs = "eight_g_pcs", // eight_g_pcs|default
		parameter rx_pcs_pma_if_use_default_base_address = "true", // false|true
		parameter rx_pcs_pma_if_user_base_address = 0, // 0..2047
		
		// parameters for av_hssi_rx_pld_pcs_interface
		parameter rx_pld_pcs_if_is_8g_0ppm = "false", // false|true
		parameter rx_pld_pcs_if_pcs_side_block_sel = "eight_g_pcs", // eight_g_pcs|default
		parameter rx_pld_pcs_if_pld_side_data_source = "pld", // hip|pld
		parameter rx_pld_pcs_if_use_default_base_address = "true", // false|true
		parameter rx_pld_pcs_if_user_base_address = 0, // 0..2047
		
		// parameters for av_hssi_tx_pcs_pma_interface
		parameter tx_pcs_pma_if_selectpcs = "eight_g_pcs", // eight_g_pcs|default
		parameter tx_pcs_pma_if_use_default_base_address = "true", // false|true
		parameter tx_pcs_pma_if_user_base_address = 0, // 0..2047
		
		// parameters for av_hssi_tx_pld_pcs_interface
		parameter tx_pld_pcs_if_is_8g_0ppm = "false", // false|true
		parameter tx_pld_pcs_if_pld_side_data_source = "pld", // hip|pld
		parameter tx_pld_pcs_if_use_default_base_address = "true", // false|true
		parameter tx_pld_pcs_if_user_base_address = 0 // 0..2047
	)
	(
		input wire		in_agg_align_status,
		input wire		in_agg_align_status_sync_0,
		input wire		in_agg_align_status_sync_0_top_or_bot,
		input wire		in_agg_align_status_top_or_bot,
		input wire		in_agg_cg_comp_rd_d_all,
		input wire		in_agg_cg_comp_rd_d_all_top_or_bot,
		input wire		in_agg_cg_comp_wr_all,
		input wire		in_agg_cg_comp_wr_all_top_or_bot,
		input wire		in_agg_del_cond_met_0,
		input wire		in_agg_del_cond_met_0_top_or_bot,
		input wire		in_agg_en_dskw_qd,
		input wire		in_agg_en_dskw_qd_top_or_bot,
		input wire		in_agg_en_dskw_rd_ptrs,
		input wire		in_agg_en_dskw_rd_ptrs_top_or_bot,
		input wire		in_agg_fifo_ovr_0,
		input wire		in_agg_fifo_ovr_0_top_or_bot,
		input wire		in_agg_fifo_rd_in_comp_0,
		input wire		in_agg_fifo_rd_in_comp_0_top_or_bot,
		input wire		in_agg_fifo_rst_rd_qd,
		input wire		in_agg_fifo_rst_rd_qd_top_or_bot,
		input wire		in_agg_insert_incomplete_0,
		input wire		in_agg_insert_incomplete_0_top_or_bot,
		input wire		in_agg_latency_comp_0,
		input wire		in_agg_latency_comp_0_top_or_bot,
		input wire		in_agg_rcvd_clk_agg,
		input wire		in_agg_rcvd_clk_agg_top_or_bot,
		input wire		in_agg_rx_control_rs,
		input wire		in_agg_rx_control_rs_top_or_bot,
		input wire	[7:0]	in_agg_rx_data_rs,
		input wire	[7:0]	in_agg_rx_data_rs_top_or_bot,
		input wire		in_agg_test_so_to_pld_in,
		input wire	[15:0]	in_agg_testbus,
		input wire		in_agg_tx_ctl_ts,
		input wire		in_agg_tx_ctl_ts_top_or_bot,
		input wire	[7:0]	in_agg_tx_data_ts,
		input wire	[7:0]	in_agg_tx_data_ts_top_or_bot,
		input wire	[10:0]	in_avmmaddress,
		input wire	[1:0]	in_avmmbyteen,
		input wire		in_avmmclk,
		input wire		in_avmmread,
		input wire		in_avmmrstn,
		input wire		in_avmmwrite,
		input wire	[15:0]	in_avmmwritedata,
		input wire		in_config_sel_in_chnl_down,
		input wire		in_config_sel_in_chnl_up,
		input wire	[37:0]	in_emsip_com_in,
		input wire	[12:0]	in_emsip_rx_special_in,
		input wire	[103:0]	in_emsip_tx_in,
		input wire	[12:0]	in_emsip_tx_special_in,
		input wire	[1:0]	in_fifo_select_in_chnl_down,
		input wire	[1:0]	in_fifo_select_in_chnl_up,
		input wire		in_pld_8g_a1a2_size,
		input wire		in_pld_8g_bitloc_rev_en,
		input wire		in_pld_8g_bitslip,
		input wire		in_pld_8g_byte_rev_en,
		input wire		in_pld_8g_bytordpld,
		input wire		in_pld_8g_cmpfifourst_n,
		input wire		in_pld_8g_encdt,
		input wire		in_pld_8g_phfifourst_rx_n,
		input wire		in_pld_8g_phfifourst_tx_n,
		input wire		in_pld_8g_pld_rx_clk,
		input wire		in_pld_8g_pld_tx_clk,
		input wire		in_pld_8g_polinv_rx,
		input wire		in_pld_8g_polinv_tx,
		input wire	[1:0]	in_pld_8g_powerdown,
		input wire		in_pld_8g_prbs_cid_en,
		input wire		in_pld_8g_rddisable_tx,
		input wire		in_pld_8g_rdenable_rmf,
		input wire		in_pld_8g_rdenable_rx,
		input wire		in_pld_8g_refclk_dig,
		input wire		in_pld_8g_refclk_dig2,
		input wire		in_pld_8g_rev_loopbk,
		input wire		in_pld_8g_rxpolarity,
		input wire		in_pld_8g_rxurstpcs_n,
		input wire	[4:0]	in_pld_8g_tx_boundary_sel,
		input wire	[3:0]	in_pld_8g_tx_data_valid,
		input wire		in_pld_8g_txdeemph,
		input wire		in_pld_8g_txdetectrxloopback,
		input wire		in_pld_8g_txelecidle,
		input wire	[2:0]	in_pld_8g_txmargin,
		input wire		in_pld_8g_txswing,
		input wire		in_pld_8g_txurstpcs_n,
		input wire		in_pld_8g_wrdisable_rx,
		input wire		in_pld_8g_wrenable_rmf,
		input wire		in_pld_8g_wrenable_tx,
		input wire		in_pld_agg_refclk_dig,
		input wire	[2:0]	in_pld_eidleinfersel,
		input wire		in_pld_ltr,
		input wire		in_pld_partial_reconfig_in,
		input wire		in_pld_pcs_pma_if_refclk_dig,
		input wire		in_pld_rate,
		input wire	[11:0]	in_pld_reserved_in,
		input wire		in_pld_rx_clk_slip_in,
		input wire		in_pld_rxpma_rstb_in,
		input wire		in_pld_scan_mode_n,
		input wire		in_pld_scan_shift_n,
		input wire		in_pld_sync_sm_en,
		input wire	[43:0]	in_pld_tx_data,
		input wire		in_pma_clklow_in,
		input wire		in_pma_fref_in,
		input wire		in_pma_hclk,
		input wire		in_pma_pcie_sw_done,
		input wire	[4:0]	in_pma_reserved_in,
		input wire	[19:0]	in_pma_rx_data,
		input wire		in_pma_rx_detect_valid,
		input wire		in_pma_rx_found,
		input wire		in_pma_rx_freq_tx_cmu_pll_lock_in,
		input wire		in_pma_rx_pll_phase_lock_in,
		input wire		in_pma_rx_pma_clk,
		input wire		in_pma_sigdet,
		input wire		in_pma_tx_pma_clk,
		input wire		in_reset_pc_ptrs_in_chnl_down,
		input wire		in_reset_pc_ptrs_in_chnl_up,
		input wire		in_reset_ppm_cntrs_in_chnl_down,
		input wire		in_reset_ppm_cntrs_in_chnl_up,
		input wire	[1:0]	in_rx_div_sync_in_chnl_down,
		input wire	[1:0]	in_rx_div_sync_in_chnl_up,
		input wire		in_rx_rd_enable_in_chnl_down,
		input wire		in_rx_rd_enable_in_chnl_up,
		input wire	[1:0]	in_rx_we_in_chnl_down,
		input wire	[1:0]	in_rx_we_in_chnl_up,
		input wire		in_rx_wr_enable_in_chnl_down,
		input wire		in_rx_wr_enable_in_chnl_up,
		input wire		in_speed_change_in_chnl_down,
		input wire		in_speed_change_in_chnl_up,
		input wire	[1:0]	in_tx_div_sync_in_chnl_down,
		input wire	[1:0]	in_tx_div_sync_in_chnl_up,
		input wire		in_tx_rd_enable_in_chnl_down,
		input wire		in_tx_rd_enable_in_chnl_up,
		input wire		in_tx_wr_enable_in_chnl_down,
		input wire		in_tx_wr_enable_in_chnl_up,
		output wire	[1:0]	out_agg_align_det_sync,
		output wire		out_agg_align_status_sync,
		output wire	[1:0]	out_agg_cg_comp_rd_d_out,
		output wire	[1:0]	out_agg_cg_comp_wr_out,
		output wire		out_agg_dec_ctl,
		output wire	[7:0]	out_agg_dec_data,
		output wire		out_agg_dec_data_valid,
		output wire		out_agg_del_cond_met_out,
		output wire		out_agg_fifo_ovr_out,
		output wire		out_agg_fifo_rd_out_comp,
		output wire		out_agg_insert_incomplete_out,
		output wire		out_agg_latency_comp_out,
		output wire	[1:0]	out_agg_rd_align,
		output wire		out_agg_rd_enable_sync,
		output wire		out_agg_refclk_dig,
		output wire	[1:0]	out_agg_running_disp,
		output wire		out_agg_rxpcs_rst,
		output wire		out_agg_scan_mode_n,
		output wire		out_agg_scan_shift_n,
		output wire		out_agg_sync_status,
		output wire		out_agg_tx_ctl_tc,
		output wire	[7:0]	out_agg_tx_data_tc,
		output wire		out_agg_txpcs_rst,
		output wire	[15:0]	out_avmmreaddata_com_pcs_pma_if,
		output wire	[15:0]	out_avmmreaddata_com_pld_pcs_if,
		output wire	[15:0]	out_avmmreaddata_pcs8g_rx,
		output wire	[15:0]	out_avmmreaddata_pcs8g_tx,
		output wire	[15:0]	out_avmmreaddata_pipe12,
		output wire	[15:0]	out_avmmreaddata_rx_pcs_pma_if,
		output wire	[15:0]	out_avmmreaddata_rx_pld_pcs_if,
		output wire	[15:0]	out_avmmreaddata_tx_pcs_pma_if,
		output wire	[15:0]	out_avmmreaddata_tx_pld_pcs_if,
		output wire		out_blockselect_com_pcs_pma_if,
		output wire		out_blockselect_com_pld_pcs_if,
		output wire		out_blockselect_pcs8g_rx,
		output wire		out_blockselect_pcs8g_tx,
		output wire		out_blockselect_pipe12,
		output wire		out_blockselect_rx_pcs_pma_if,
		output wire		out_blockselect_rx_pld_pcs_if,
		output wire		out_blockselect_tx_pcs_pma_if,
		output wire		out_blockselect_tx_pld_pcs_if,
		output wire		out_config_sel_out_chnl_down,
		output wire		out_config_sel_out_chnl_up,
		output wire	[2:0]	out_emsip_com_clk_out,
		output wire	[26:0]	out_emsip_com_out,
		output wire	[128:0]	out_emsip_rx_out,
		output wire	[15:0]	out_emsip_rx_special_out,
		output wire	[2:0]	out_emsip_tx_clk_out,
		output wire	[15:0]	out_emsip_tx_special_out,
		output wire	[1:0]	out_fifo_select_out_chnl_down,
		output wire	[1:0]	out_fifo_select_out_chnl_up,
		output wire	[3:0]	out_pld_8g_a1a2_k1k2_flag,
		output wire		out_pld_8g_align_status,
		output wire		out_pld_8g_bistdone,
		output wire		out_pld_8g_bisterr,
		output wire		out_pld_8g_byteord_flag,
		output wire		out_pld_8g_empty_rmf,
		output wire		out_pld_8g_empty_rx,
		output wire		out_pld_8g_empty_tx,
		output wire		out_pld_8g_full_rmf,
		output wire		out_pld_8g_full_rx,
		output wire		out_pld_8g_full_tx,
		output wire		out_pld_8g_phystatus,
		output wire		out_pld_8g_rlv_lt,
		output wire		out_pld_8g_rx_clk_out,
		output wire	[3:0]	out_pld_8g_rx_data_valid,
		output wire		out_pld_8g_rxelecidle,
		output wire	[2:0]	out_pld_8g_rxstatus,
		output wire		out_pld_8g_rxvalid,
		output wire		out_pld_8g_signal_detect_out,
		output wire		out_pld_8g_tx_clk_out,
		output wire	[4:0]	out_pld_8g_wa_boundary,
		output wire		out_pld_clklow,
		output wire		out_pld_fref,
		output wire	[10:0]	out_pld_reserved_out,
		output wire	[63:0]	out_pld_rx_data,
		output wire	[19:0]	out_pld_test_data,
		output wire		out_pld_test_si_to_agg_out,
		output wire	[11:0]	out_pma_current_coeff,
		output wire		out_pma_early_eios,
		output wire		out_pma_ltr,
		output wire		out_pma_nfrzdrv,
		output wire		out_pma_partial_reconfig,
		output wire		out_pma_pcie_switch,
		output wire		out_pma_ppm_lock,
		output wire	[4:0]	out_pma_reserved_out,
		output wire		out_pma_rx_clk_out,
		output wire		out_pma_rxclkslip,
		output wire		out_pma_rxpma_rstb,
		output wire		out_pma_tx_clk_out,
		output wire	[19:0]	out_pma_tx_data,
		output wire		out_pma_tx_elec_idle,
		output wire		out_pma_txdetectrx,
		output wire		out_reset_pc_ptrs_out_chnl_down,
		output wire		out_reset_pc_ptrs_out_chnl_up,
		output wire		out_reset_ppm_cntrs_out_chnl_down,
		output wire		out_reset_ppm_cntrs_out_chnl_up,
		output wire	[1:0]	out_rx_div_sync_out_chnl_down,
		output wire	[1:0]	out_rx_div_sync_out_chnl_up,
		output wire		out_rx_rd_enable_out_chnl_down,
		output wire		out_rx_rd_enable_out_chnl_up,
		output wire	[1:0]	out_rx_we_out_chnl_down,
		output wire	[1:0]	out_rx_we_out_chnl_up,
		output wire		out_rx_wr_enable_out_chnl_down,
		output wire		out_rx_wr_enable_out_chnl_up,
		output wire		out_speed_change_out_chnl_down,
		output wire		out_speed_change_out_chnl_up,
		output wire	[1:0]	out_tx_div_sync_out_chnl_down,
		output wire	[1:0]	out_tx_div_sync_out_chnl_up,
		output wire		out_tx_rd_enable_out_chnl_down,
		output wire		out_tx_rd_enable_out_chnl_up,
		output wire		out_tx_wr_enable_out_chnl_down,
		output wire		out_tx_wr_enable_out_chnl_up
	);
	//wire declarations
	
	// wires for module av_hssi_rx_pld_pcs_interface
	wire	[15:0]	w_rx_pld_pcs_if_avmmreaddata;
	wire		w_rx_pld_pcs_if_blockselect;
	wire	[63:0]	w_rx_pld_pcs_if_dataouttopld;
	wire	[128:0]	w_rx_pld_pcs_if_emsiprxout;
	wire	[15:0]	w_rx_pld_pcs_if_emsiprxspecialout;
	wire		w_rx_pld_pcs_if_pcs8ga1a2size;
	wire		w_rx_pld_pcs_if_pcs8gbitlocreven;
	wire		w_rx_pld_pcs_if_pcs8gbitslip;
	wire		w_rx_pld_pcs_if_pcs8gbytereven;
	wire		w_rx_pld_pcs_if_pcs8gbytordpld;
	wire		w_rx_pld_pcs_if_pcs8gcmpfifourst;
	wire		w_rx_pld_pcs_if_pcs8gencdt;
	wire		w_rx_pld_pcs_if_pcs8gphfifourstrx;
	wire		w_rx_pld_pcs_if_pcs8gpldrxclk;
	wire		w_rx_pld_pcs_if_pcs8gpolinvrx;
	wire		w_rx_pld_pcs_if_pcs8grdenablerx;
	wire		w_rx_pld_pcs_if_pcs8grxurstpcs;
	wire		w_rx_pld_pcs_if_pcs8gsyncsmenoutput;
	wire		w_rx_pld_pcs_if_pcs8gwrdisablerx;
	wire	[3:0]	w_rx_pld_pcs_if_pld8ga1a2k1k2flag;
	wire		w_rx_pld_pcs_if_pld8galignstatus;
	wire		w_rx_pld_pcs_if_pld8gbistdone;
	wire		w_rx_pld_pcs_if_pld8gbisterr;
	wire		w_rx_pld_pcs_if_pld8gbyteordflag;
	wire		w_rx_pld_pcs_if_pld8gemptyrmf;
	wire		w_rx_pld_pcs_if_pld8gemptyrx;
	wire		w_rx_pld_pcs_if_pld8gfullrmf;
	wire		w_rx_pld_pcs_if_pld8gfullrx;
	wire		w_rx_pld_pcs_if_pld8grlvlt;
	wire		w_rx_pld_pcs_if_pld8grxclkout;
	wire	[3:0]	w_rx_pld_pcs_if_pld8grxdatavalid;
	wire		w_rx_pld_pcs_if_pld8gsignaldetectout;
	wire	[4:0]	w_rx_pld_pcs_if_pld8gwaboundary;
	wire		w_rx_pld_pcs_if_pldrxclkslipout;
	wire		w_rx_pld_pcs_if_pldrxpmarstbout;
	
	// wires for module av_hssi_common_pcs_pma_interface
	wire	[1:0]	w_com_pcs_pma_if_aggaligndetsync;
	wire		w_com_pcs_pma_if_aggalignstatussync;
	wire	[1:0]	w_com_pcs_pma_if_aggcgcomprddout;
	wire	[1:0]	w_com_pcs_pma_if_aggcgcompwrout;
	wire		w_com_pcs_pma_if_aggdecctl;
	wire	[7:0]	w_com_pcs_pma_if_aggdecdata;
	wire		w_com_pcs_pma_if_aggdecdatavalid;
	wire		w_com_pcs_pma_if_aggdelcondmetout;
	wire		w_com_pcs_pma_if_aggfifoovrout;
	wire		w_com_pcs_pma_if_aggfifordoutcomp;
	wire		w_com_pcs_pma_if_agginsertincompleteout;
	wire		w_com_pcs_pma_if_agglatencycompout;
	wire	[1:0]	w_com_pcs_pma_if_aggrdalign;
	wire		w_com_pcs_pma_if_aggrdenablesync;
	wire		w_com_pcs_pma_if_aggrefclkdig;
	wire	[1:0]	w_com_pcs_pma_if_aggrunningdisp;
	wire		w_com_pcs_pma_if_aggrxpcsrst;
	wire		w_com_pcs_pma_if_aggscanmoden;
	wire		w_com_pcs_pma_if_aggscanshiftn;
	wire		w_com_pcs_pma_if_aggsyncstatus;
	wire		w_com_pcs_pma_if_aggtestsotopldout;
	wire		w_com_pcs_pma_if_aggtxctltc;
	wire	[7:0]	w_com_pcs_pma_if_aggtxdatatc;
	wire		w_com_pcs_pma_if_aggtxpcsrst;
	wire	[15:0]	w_com_pcs_pma_if_avmmreaddata;
	wire		w_com_pcs_pma_if_blockselect;
	wire		w_com_pcs_pma_if_freqlock;
	wire		w_com_pcs_pma_if_pcs8ggen2ngen1;
	wire		w_com_pcs_pma_if_pcs8gpmarxfound;
	wire		w_com_pcs_pma_if_pcs8gpowerstatetransitiondone;
	wire		w_com_pcs_pma_if_pcs8grxdetectvalid;
	wire		w_com_pcs_pma_if_pcsaggalignstatus;
	wire		w_com_pcs_pma_if_pcsaggalignstatussync0;
	wire		w_com_pcs_pma_if_pcsaggalignstatussync0toporbot;
	wire		w_com_pcs_pma_if_pcsaggalignstatustoporbot;
	wire		w_com_pcs_pma_if_pcsaggcgcomprddall;
	wire		w_com_pcs_pma_if_pcsaggcgcomprddalltoporbot;
	wire		w_com_pcs_pma_if_pcsaggcgcompwrall;
	wire		w_com_pcs_pma_if_pcsaggcgcompwralltoporbot;
	wire		w_com_pcs_pma_if_pcsaggdelcondmet0;
	wire		w_com_pcs_pma_if_pcsaggdelcondmet0toporbot;
	wire		w_com_pcs_pma_if_pcsaggendskwqd;
	wire		w_com_pcs_pma_if_pcsaggendskwqdtoporbot;
	wire		w_com_pcs_pma_if_pcsaggendskwrdptrs;
	wire		w_com_pcs_pma_if_pcsaggendskwrdptrstoporbot;
	wire		w_com_pcs_pma_if_pcsaggfifoovr0;
	wire		w_com_pcs_pma_if_pcsaggfifoovr0toporbot;
	wire		w_com_pcs_pma_if_pcsaggfifordincomp0;
	wire		w_com_pcs_pma_if_pcsaggfifordincomp0toporbot;
	wire		w_com_pcs_pma_if_pcsaggfiforstrdqd;
	wire		w_com_pcs_pma_if_pcsaggfiforstrdqdtoporbot;
	wire		w_com_pcs_pma_if_pcsagginsertincomplete0;
	wire		w_com_pcs_pma_if_pcsagginsertincomplete0toporbot;
	wire		w_com_pcs_pma_if_pcsagglatencycomp0;
	wire		w_com_pcs_pma_if_pcsagglatencycomp0toporbot;
	wire		w_com_pcs_pma_if_pcsaggrcvdclkagg;
	wire		w_com_pcs_pma_if_pcsaggrcvdclkaggtoporbot;
	wire		w_com_pcs_pma_if_pcsaggrxcontrolrs;
	wire		w_com_pcs_pma_if_pcsaggrxcontrolrstoporbot;
	wire	[7:0]	w_com_pcs_pma_if_pcsaggrxdatars;
	wire	[7:0]	w_com_pcs_pma_if_pcsaggrxdatarstoporbot;
	wire	[15:0]	w_com_pcs_pma_if_pcsaggtestbus;
	wire		w_com_pcs_pma_if_pcsaggtxctlts;
	wire		w_com_pcs_pma_if_pcsaggtxctltstoporbot;
	wire	[7:0]	w_com_pcs_pma_if_pcsaggtxdatats;
	wire	[7:0]	w_com_pcs_pma_if_pcsaggtxdatatstoporbot;
	wire		w_com_pcs_pma_if_pldhclkout;
	wire		w_com_pcs_pma_if_pldtestsitoaggout;
	wire		w_com_pcs_pma_if_pmaclklowout;
	wire	[17:0]	w_com_pcs_pma_if_pmacurrentcoeff;
	wire		w_com_pcs_pma_if_pmaearlyeios;
	wire		w_com_pcs_pma_if_pmafrefout;
	wire	[9:0]	w_com_pcs_pma_if_pmaiftestbus;
	wire		w_com_pcs_pma_if_pmaltr;
	wire		w_com_pcs_pma_if_pmanfrzdrv;
	wire		w_com_pcs_pma_if_pmapartialreconfig;
	wire	[1:0]	w_com_pcs_pma_if_pmapcieswitch;
	wire		w_com_pcs_pma_if_pmatxdetectrx;
	wire		w_com_pcs_pma_if_pmatxelecidle;
	
	// wires for module av_hssi_pipe_gen1_2
	wire	[15:0]	w_pipe12_avmmreaddata;
	wire		w_pipe12_blockselect;
	wire	[17:0]	w_pipe12_currentcoeff;
	wire		w_pipe12_phystatus;
	wire		w_pipe12_polinvrxint;
	wire		w_pipe12_revloopbk;
	wire		w_pipe12_rxelecidle;
	wire	[2:0]	w_pipe12_rxstatus;
	wire		w_pipe12_rxvalid;
	wire		w_pipe12_txdetectrx;
	wire		w_pipe12_txelecidleout;
	
	// wires for module av_hssi_8g_rx_pcs
	wire	[3:0]	w_pcs8g_rx_a1a2k1k2flag;
	wire		w_pcs8g_rx_aggrxpcsrst;
	wire	[1:0]	w_pcs8g_rx_aligndetsync;
	wire		w_pcs8g_rx_alignstatuspld;
	wire		w_pcs8g_rx_alignstatussync;
	wire	[15:0]	w_pcs8g_rx_avmmreaddata;
	wire		w_pcs8g_rx_bistdone;
	wire		w_pcs8g_rx_bisterr;
	wire		w_pcs8g_rx_blockselect;
	wire		w_pcs8g_rx_byteordflag;
	wire	[1:0]	w_pcs8g_rx_cgcomprddout;
	wire	[1:0]	w_pcs8g_rx_cgcompwrout;
	wire	[19:0]	w_pcs8g_rx_channeltestbusout;
	wire		w_pcs8g_rx_clocktopld;
	wire		w_pcs8g_rx_configseloutchnldown;
	wire		w_pcs8g_rx_configseloutchnlup;
	wire	[63:0]	w_pcs8g_rx_dataout;
	wire		w_pcs8g_rx_decoderctrl;
	wire	[7:0]	w_pcs8g_rx_decoderdata;
	wire		w_pcs8g_rx_decoderdatavalid;
	wire		w_pcs8g_rx_delcondmetout;
	wire		w_pcs8g_rx_disablepcfifobyteserdes;
	wire		w_pcs8g_rx_earlyeios;
	wire		w_pcs8g_rx_eidledetected;
	wire		w_pcs8g_rx_eidleexit;
	wire		w_pcs8g_rx_fifoovrout;
	wire		w_pcs8g_rx_fifordoutcomp;
	wire		w_pcs8g_rx_insertincompleteout;
	wire		w_pcs8g_rx_latencycompout;
	wire		w_pcs8g_rx_ltr;
	wire	[19:0]	w_pcs8g_rx_parallelrevloopback;
	wire		w_pcs8g_rx_pcfifoempty;
	wire		w_pcs8g_rx_pcfifofull;
	wire		w_pcs8g_rx_pcieswitch;
	wire		w_pcs8g_rx_phystatus;
	wire	[63:0]	w_pcs8g_rx_pipedata;
	wire	[1:0]	w_pcs8g_rx_rdalign;
	wire		w_pcs8g_rx_rdenableoutchnldown;
	wire		w_pcs8g_rx_rdenableoutchnlup;
	wire		w_pcs8g_rx_resetpcptrs;
	wire		w_pcs8g_rx_resetpcptrsinchnldownpipe;
	wire		w_pcs8g_rx_resetpcptrsinchnluppipe;
	wire		w_pcs8g_rx_resetpcptrsoutchnldown;
	wire		w_pcs8g_rx_resetpcptrsoutchnlup;
	wire		w_pcs8g_rx_resetppmcntrsoutchnldown;
	wire		w_pcs8g_rx_resetppmcntrsoutchnlup;
	wire		w_pcs8g_rx_resetppmcntrspcspma;
	wire		w_pcs8g_rx_rlvlt;
	wire		w_pcs8g_rx_rmfifoempty;
	wire		w_pcs8g_rx_rmfifofull;
	wire	[1:0]	w_pcs8g_rx_runningdisparity;
	wire		w_pcs8g_rx_rxclkslip;
	wire	[3:0]	w_pcs8g_rx_rxdatavalid;
	wire	[1:0]	w_pcs8g_rx_rxdivsyncoutchnldown;
	wire	[1:0]	w_pcs8g_rx_rxdivsyncoutchnlup;
	wire		w_pcs8g_rx_rxpipeclk;
	wire		w_pcs8g_rx_rxpipesoftreset;
	wire	[2:0]	w_pcs8g_rx_rxstatus;
	wire		w_pcs8g_rx_rxvalid;
	wire	[1:0]	w_pcs8g_rx_rxweoutchnldown;
	wire	[1:0]	w_pcs8g_rx_rxweoutchnlup;
	wire		w_pcs8g_rx_signaldetectout;
	wire		w_pcs8g_rx_speedchange;
	wire		w_pcs8g_rx_speedchangeinchnldownpipe;
	wire		w_pcs8g_rx_speedchangeinchnluppipe;
	wire		w_pcs8g_rx_speedchangeoutchnldown;
	wire		w_pcs8g_rx_speedchangeoutchnlup;
	wire		w_pcs8g_rx_syncstatus;
	wire	[4:0]	w_pcs8g_rx_wordalignboundary;
	wire		w_pcs8g_rx_wrenableoutchnldown;
	wire		w_pcs8g_rx_wrenableoutchnlup;
	
	// wires for module av_hssi_tx_pcs_pma_interface
	wire	[15:0]	w_tx_pcs_pma_if_avmmreaddata;
	wire		w_tx_pcs_pma_if_blockselect;
	wire		w_tx_pcs_pma_if_clockoutto8gpcs;
	wire	[79:0]	w_tx_pcs_pma_if_dataouttopma;
	wire		w_tx_pcs_pma_if_pmarxfreqtxcmuplllockout;
	wire		w_tx_pcs_pma_if_pmatxclkout;
	
	// wires for module av_hssi_rx_pcs_pma_interface
	wire	[15:0]	w_rx_pcs_pma_if_avmmreaddata;
	wire		w_rx_pcs_pma_if_blockselect;
	wire		w_rx_pcs_pma_if_clockoutto8gpcs;
	wire	[19:0]	w_rx_pcs_pma_if_dataoutto8gpcs;
	wire		w_rx_pcs_pma_if_pcs8gsigdetni;
	wire	[4:0]	w_rx_pcs_pma_if_pmareservedout;
	wire		w_rx_pcs_pma_if_pmarxclkout;
	wire		w_rx_pcs_pma_if_pmarxclkslip;
	wire		w_rx_pcs_pma_if_pmarxpllphaselockout;
	wire		w_rx_pcs_pma_if_pmarxpmarstb;
	
	// wires for module av_hssi_8g_tx_pcs
	wire		w_pcs8g_tx_aggtxpcsrst;
	wire	[15:0]	w_pcs8g_tx_avmmreaddata;
	wire		w_pcs8g_tx_blockselect;
	wire		w_pcs8g_tx_clkout;
	wire	[19:0]	w_pcs8g_tx_dataout;
	wire		w_pcs8g_tx_detectrxloopout;
	wire		w_pcs8g_tx_dynclkswitchn;
	wire	[1:0]	w_pcs8g_tx_fifoselectoutchnldown;
	wire	[1:0]	w_pcs8g_tx_fifoselectoutchnlup;
	wire	[2:0]	w_pcs8g_tx_grayelecidleinferselout;
	wire	[19:0]	w_pcs8g_tx_parallelfdbkout;
	wire		w_pcs8g_tx_phfifooverflow;
	wire		w_pcs8g_tx_phfifotxdeemph;
	wire	[2:0]	w_pcs8g_tx_phfifotxmargin;
	wire		w_pcs8g_tx_phfifotxswing;
	wire		w_pcs8g_tx_phfifounderflow;
	wire		w_pcs8g_tx_pipeenrevparallellpbkout;
	wire	[1:0]	w_pcs8g_tx_pipepowerdownout;
	wire		w_pcs8g_tx_polinvrxout;
	wire		w_pcs8g_tx_rdenableoutchnldown;
	wire		w_pcs8g_tx_rdenableoutchnlup;
	wire		w_pcs8g_tx_rdenablesync;
	wire		w_pcs8g_tx_refclkb;
	wire		w_pcs8g_tx_refclkbreset;
	wire		w_pcs8g_tx_rxpolarityout;
	wire	[19:0]	w_pcs8g_tx_txctrlplanetestbus;
	wire	[1:0]	w_pcs8g_tx_txdivsync;
	wire	[1:0]	w_pcs8g_tx_txdivsyncoutchnldown;
	wire	[1:0]	w_pcs8g_tx_txdivsyncoutchnlup;
	wire		w_pcs8g_tx_txpipeclk;
	wire		w_pcs8g_tx_txpipeelectidle;
	wire		w_pcs8g_tx_txpipesoftreset;
	wire	[19:0]	w_pcs8g_tx_txtestbus;
	wire		w_pcs8g_tx_wrenableoutchnldown;
	wire		w_pcs8g_tx_wrenableoutchnlup;
	wire		w_pcs8g_tx_xgmctrlenable;
	wire	[7:0]	w_pcs8g_tx_xgmdataout;
	
	// wires for module av_hssi_common_pld_pcs_interface
	wire	[15:0]	w_com_pld_pcs_if_avmmreaddata;
	wire		w_com_pld_pcs_if_blockselect;
	wire	[2:0]	w_com_pld_pcs_if_emsipcomclkout;
	wire	[26:0]	w_com_pld_pcs_if_emsipcomout;
	wire		w_com_pld_pcs_if_emsipenablediocsrrdydly;
	wire	[2:0]	w_com_pld_pcs_if_pcs8geidleinfersel;
	wire		w_com_pld_pcs_if_pcs8ghardreset;
	wire		w_com_pld_pcs_if_pcs8gltr;
	wire	[1:0]	w_com_pld_pcs_if_pcs8gpowerdown;
	wire		w_com_pld_pcs_if_pcs8gprbsciden;
	wire		w_com_pld_pcs_if_pcs8grate;
	wire		w_com_pld_pcs_if_pcs8grefclkdig;
	wire		w_com_pld_pcs_if_pcs8grefclkdig2;
	wire		w_com_pld_pcs_if_pcs8grxpolarity;
	wire		w_com_pld_pcs_if_pcs8gscanmoden;
	wire		w_com_pld_pcs_if_pcs8gtxdeemph;
	wire		w_com_pld_pcs_if_pcs8gtxdetectrxloopback;
	wire		w_com_pld_pcs_if_pcs8gtxelecidle;
	wire	[2:0]	w_com_pld_pcs_if_pcs8gtxmargin;
	wire		w_com_pld_pcs_if_pcs8gtxswing;
	wire		w_com_pld_pcs_if_pcsaggrefclkdig;
	wire		w_com_pld_pcs_if_pcsaggscanmoden;
	wire		w_com_pld_pcs_if_pcsaggscanshift;
	wire		w_com_pld_pcs_if_pcsaggtestsi;
	wire		w_com_pld_pcs_if_pcspcspmaifrefclkdig;
	wire		w_com_pld_pcs_if_pcspcspmaifscanmoden;
	wire		w_com_pld_pcs_if_pcspcspmaifscanshiftn;
	wire		w_com_pld_pcs_if_pcspmaifhardreset;
	wire		w_com_pld_pcs_if_pld8gphystatus;
	wire		w_com_pld_pcs_if_pld8grxelecidle;
	wire	[2:0]	w_com_pld_pcs_if_pld8grxstatus;
	wire		w_com_pld_pcs_if_pld8grxvalid;
	wire		w_com_pld_pcs_if_pldclklow;
	wire		w_com_pld_pcs_if_pldfref;
	wire		w_com_pld_pcs_if_pldnfrzdrv;
	wire		w_com_pld_pcs_if_pldpartialreconfigout;
	wire	[10:0]	w_com_pld_pcs_if_pldreservedout;
	wire	[19:0]	w_com_pld_pcs_if_pldtestdata;
	wire		w_com_pld_pcs_if_rstsel;
	wire		w_com_pld_pcs_if_usrrstsel;
	
	// wires for module av_hssi_tx_pld_pcs_interface
	wire	[15:0]	w_tx_pld_pcs_if_avmmreaddata;
	wire		w_tx_pld_pcs_if_blockselect;
	wire	[43:0]	w_tx_pld_pcs_if_dataoutto8gpcs;
	wire	[2:0]	w_tx_pld_pcs_if_emsippcstxclkout;
	wire	[15:0]	w_tx_pld_pcs_if_emsiptxspecialout;
	wire		w_tx_pld_pcs_if_pcs8gphfifoursttx;
	wire		w_tx_pld_pcs_if_pcs8gpldtxclk;
	wire		w_tx_pld_pcs_if_pcs8gpolinvtx;
	wire		w_tx_pld_pcs_if_pcs8grddisabletx;
	wire		w_tx_pld_pcs_if_pcs8grevloopbk;
	wire	[4:0]	w_tx_pld_pcs_if_pcs8gtxboundarysel;
	wire	[3:0]	w_tx_pld_pcs_if_pcs8gtxdatavalid;
	wire		w_tx_pld_pcs_if_pcs8gtxurstpcs;
	wire		w_tx_pld_pcs_if_pcs8gwrenabletx;
	wire		w_tx_pld_pcs_if_pld8gemptytx;
	wire		w_tx_pld_pcs_if_pld8gfulltx;
	wire		w_tx_pld_pcs_if_pld8gtxclkout;
	
	wire wirehack = &{ 1'b0,
								w_rx_pld_pcs_if_avmmreaddata,
								w_rx_pld_pcs_if_blockselect,
								w_rx_pld_pcs_if_dataouttopld,
								w_rx_pld_pcs_if_emsiprxout,
								w_rx_pld_pcs_if_emsiprxspecialout,
								w_rx_pld_pcs_if_pcs8ga1a2size,
								w_rx_pld_pcs_if_pcs8gbitlocreven,
								w_rx_pld_pcs_if_pcs8gbitslip,
								w_rx_pld_pcs_if_pcs8gbytereven,
								w_rx_pld_pcs_if_pcs8gbytordpld,
								w_rx_pld_pcs_if_pcs8gcmpfifourst,
								w_rx_pld_pcs_if_pcs8gencdt,
								w_rx_pld_pcs_if_pcs8gphfifourstrx,
								w_rx_pld_pcs_if_pcs8gpldrxclk,
								w_rx_pld_pcs_if_pcs8gpolinvrx,
								w_rx_pld_pcs_if_pcs8grdenablerx,
								w_rx_pld_pcs_if_pcs8grxurstpcs,
								w_rx_pld_pcs_if_pcs8gsyncsmenoutput,
								w_rx_pld_pcs_if_pcs8gwrdisablerx,
								w_rx_pld_pcs_if_pld8ga1a2k1k2flag,
								w_rx_pld_pcs_if_pld8galignstatus,
								w_rx_pld_pcs_if_pld8gbistdone,
								w_rx_pld_pcs_if_pld8gbisterr,
								w_rx_pld_pcs_if_pld8gbyteordflag,
								w_rx_pld_pcs_if_pld8gemptyrmf,
								w_rx_pld_pcs_if_pld8gemptyrx,
								w_rx_pld_pcs_if_pld8gfullrmf,
								w_rx_pld_pcs_if_pld8gfullrx,
								w_rx_pld_pcs_if_pld8grlvlt,
								w_rx_pld_pcs_if_pld8grxclkout,
								w_rx_pld_pcs_if_pld8grxdatavalid,
								w_rx_pld_pcs_if_pld8gsignaldetectout,
								w_rx_pld_pcs_if_pld8gwaboundary,
								w_rx_pld_pcs_if_pldrxclkslipout,
								w_rx_pld_pcs_if_pldrxpmarstbout,
								w_com_pcs_pma_if_aggaligndetsync,
								w_com_pcs_pma_if_aggalignstatussync,
								w_com_pcs_pma_if_aggcgcomprddout,
								w_com_pcs_pma_if_aggcgcompwrout,
								w_com_pcs_pma_if_aggdecctl,
								w_com_pcs_pma_if_aggdecdata,
								w_com_pcs_pma_if_aggdecdatavalid,
								w_com_pcs_pma_if_aggdelcondmetout,
								w_com_pcs_pma_if_aggfifoovrout,
								w_com_pcs_pma_if_aggfifordoutcomp,
								w_com_pcs_pma_if_agginsertincompleteout,
								w_com_pcs_pma_if_agglatencycompout,
								w_com_pcs_pma_if_aggrdalign,
								w_com_pcs_pma_if_aggrdenablesync,
								w_com_pcs_pma_if_aggrefclkdig,
								w_com_pcs_pma_if_aggrunningdisp,
								w_com_pcs_pma_if_aggrxpcsrst,
								w_com_pcs_pma_if_aggscanmoden,
								w_com_pcs_pma_if_aggscanshiftn,
								w_com_pcs_pma_if_aggsyncstatus,
								w_com_pcs_pma_if_aggtestsotopldout,
								w_com_pcs_pma_if_aggtxctltc,
								w_com_pcs_pma_if_aggtxdatatc,
								w_com_pcs_pma_if_aggtxpcsrst,
								w_com_pcs_pma_if_avmmreaddata,
								w_com_pcs_pma_if_blockselect,
								w_com_pcs_pma_if_freqlock,
								w_com_pcs_pma_if_pcs8ggen2ngen1,
								w_com_pcs_pma_if_pcs8gpmarxfound,
								w_com_pcs_pma_if_pcs8gpowerstatetransitiondone,
								w_com_pcs_pma_if_pcs8grxdetectvalid,
								w_com_pcs_pma_if_pcsaggalignstatus,
								w_com_pcs_pma_if_pcsaggalignstatussync0,
								w_com_pcs_pma_if_pcsaggalignstatussync0toporbot,
								w_com_pcs_pma_if_pcsaggalignstatustoporbot,
								w_com_pcs_pma_if_pcsaggcgcomprddall,
								w_com_pcs_pma_if_pcsaggcgcomprddalltoporbot,
								w_com_pcs_pma_if_pcsaggcgcompwrall,
								w_com_pcs_pma_if_pcsaggcgcompwralltoporbot,
								w_com_pcs_pma_if_pcsaggdelcondmet0,
								w_com_pcs_pma_if_pcsaggdelcondmet0toporbot,
								w_com_pcs_pma_if_pcsaggendskwqd,
								w_com_pcs_pma_if_pcsaggendskwqdtoporbot,
								w_com_pcs_pma_if_pcsaggendskwrdptrs,
								w_com_pcs_pma_if_pcsaggendskwrdptrstoporbot,
								w_com_pcs_pma_if_pcsaggfifoovr0,
								w_com_pcs_pma_if_pcsaggfifoovr0toporbot,
								w_com_pcs_pma_if_pcsaggfifordincomp0,
								w_com_pcs_pma_if_pcsaggfifordincomp0toporbot,
								w_com_pcs_pma_if_pcsaggfiforstrdqd,
								w_com_pcs_pma_if_pcsaggfiforstrdqdtoporbot,
								w_com_pcs_pma_if_pcsagginsertincomplete0,
								w_com_pcs_pma_if_pcsagginsertincomplete0toporbot,
								w_com_pcs_pma_if_pcsagglatencycomp0,
								w_com_pcs_pma_if_pcsagglatencycomp0toporbot,
								w_com_pcs_pma_if_pcsaggrcvdclkagg,
								w_com_pcs_pma_if_pcsaggrcvdclkaggtoporbot,
								w_com_pcs_pma_if_pcsaggrxcontrolrs,
								w_com_pcs_pma_if_pcsaggrxcontrolrstoporbot,
								w_com_pcs_pma_if_pcsaggrxdatars,
								w_com_pcs_pma_if_pcsaggrxdatarstoporbot,
								w_com_pcs_pma_if_pcsaggtestbus,
								w_com_pcs_pma_if_pcsaggtxctlts,
								w_com_pcs_pma_if_pcsaggtxctltstoporbot,
								w_com_pcs_pma_if_pcsaggtxdatats,
								w_com_pcs_pma_if_pcsaggtxdatatstoporbot,
								w_com_pcs_pma_if_pldhclkout,
								w_com_pcs_pma_if_pldtestsitoaggout,
								w_com_pcs_pma_if_pmaclklowout,
								w_com_pcs_pma_if_pmacurrentcoeff,
								w_com_pcs_pma_if_pmaearlyeios,
								w_com_pcs_pma_if_pmafrefout,
								w_com_pcs_pma_if_pmaiftestbus,
								w_com_pcs_pma_if_pmaltr,
								w_com_pcs_pma_if_pmanfrzdrv,
								w_com_pcs_pma_if_pmapartialreconfig,
								w_com_pcs_pma_if_pmapcieswitch,
								w_com_pcs_pma_if_pmatxdetectrx,
								w_com_pcs_pma_if_pmatxelecidle,
								w_pipe12_avmmreaddata,
								w_pipe12_blockselect,
								w_pipe12_currentcoeff,
								w_pipe12_phystatus,
								w_pipe12_polinvrxint,
								w_pipe12_revloopbk,
								w_pipe12_rxelecidle,
								w_pipe12_rxstatus,
								w_pipe12_rxvalid,
								w_pipe12_txdetectrx,
								w_pipe12_txelecidleout,
								w_pcs8g_rx_a1a2k1k2flag,
								w_pcs8g_rx_aggrxpcsrst,
								w_pcs8g_rx_aligndetsync,
								w_pcs8g_rx_alignstatuspld,
								w_pcs8g_rx_alignstatussync,
								w_pcs8g_rx_avmmreaddata,
								w_pcs8g_rx_bistdone,
								w_pcs8g_rx_bisterr,
								w_pcs8g_rx_blockselect,
								w_pcs8g_rx_byteordflag,
								w_pcs8g_rx_cgcomprddout,
								w_pcs8g_rx_cgcompwrout,
								w_pcs8g_rx_channeltestbusout,
								w_pcs8g_rx_clocktopld,
								w_pcs8g_rx_configseloutchnldown,
								w_pcs8g_rx_configseloutchnlup,
								w_pcs8g_rx_dataout,
								w_pcs8g_rx_decoderctrl,
								w_pcs8g_rx_decoderdata,
								w_pcs8g_rx_decoderdatavalid,
								w_pcs8g_rx_delcondmetout,
								w_pcs8g_rx_disablepcfifobyteserdes,
								w_pcs8g_rx_earlyeios,
								w_pcs8g_rx_eidledetected,
								w_pcs8g_rx_eidleexit,
								w_pcs8g_rx_fifoovrout,
								w_pcs8g_rx_fifordoutcomp,
								w_pcs8g_rx_insertincompleteout,
								w_pcs8g_rx_latencycompout,
								w_pcs8g_rx_ltr,
								w_pcs8g_rx_parallelrevloopback,
								w_pcs8g_rx_pcfifoempty,
								w_pcs8g_rx_pcfifofull,
								w_pcs8g_rx_pcieswitch,
								w_pcs8g_rx_phystatus,
								w_pcs8g_rx_pipedata,
								w_pcs8g_rx_rdalign,
								w_pcs8g_rx_rdenableoutchnldown,
								w_pcs8g_rx_rdenableoutchnlup,
								w_pcs8g_rx_resetpcptrs,
								w_pcs8g_rx_resetpcptrsinchnldownpipe,
								w_pcs8g_rx_resetpcptrsinchnluppipe,
								w_pcs8g_rx_resetpcptrsoutchnldown,
								w_pcs8g_rx_resetpcptrsoutchnlup,
								w_pcs8g_rx_resetppmcntrsoutchnldown,
								w_pcs8g_rx_resetppmcntrsoutchnlup,
								w_pcs8g_rx_resetppmcntrspcspma,
								w_pcs8g_rx_rlvlt,
								w_pcs8g_rx_rmfifoempty,
								w_pcs8g_rx_rmfifofull,
								w_pcs8g_rx_runningdisparity,
								w_pcs8g_rx_rxclkslip,
								w_pcs8g_rx_rxdatavalid,
								w_pcs8g_rx_rxdivsyncoutchnldown,
								w_pcs8g_rx_rxdivsyncoutchnlup,
								w_pcs8g_rx_rxpipeclk,
								w_pcs8g_rx_rxpipesoftreset,
								w_pcs8g_rx_rxstatus,
								w_pcs8g_rx_rxvalid,
								w_pcs8g_rx_rxweoutchnldown,
								w_pcs8g_rx_rxweoutchnlup,
								w_pcs8g_rx_signaldetectout,
								w_pcs8g_rx_speedchange,
								w_pcs8g_rx_speedchangeinchnldownpipe,
								w_pcs8g_rx_speedchangeinchnluppipe,
								w_pcs8g_rx_speedchangeoutchnldown,
								w_pcs8g_rx_speedchangeoutchnlup,
								w_pcs8g_rx_syncstatus,
								w_pcs8g_rx_wordalignboundary,
								w_pcs8g_rx_wrenableoutchnldown,
								w_pcs8g_rx_wrenableoutchnlup,
								w_tx_pcs_pma_if_avmmreaddata,
								w_tx_pcs_pma_if_blockselect,
								w_tx_pcs_pma_if_clockoutto8gpcs,
								w_tx_pcs_pma_if_dataouttopma,
								w_tx_pcs_pma_if_pmarxfreqtxcmuplllockout,
								w_tx_pcs_pma_if_pmatxclkout,
								w_rx_pcs_pma_if_avmmreaddata,
								w_rx_pcs_pma_if_blockselect,
								w_rx_pcs_pma_if_clockoutto8gpcs,
								w_rx_pcs_pma_if_dataoutto8gpcs,
								w_rx_pcs_pma_if_pcs8gsigdetni,
								w_rx_pcs_pma_if_pmareservedout,
								w_rx_pcs_pma_if_pmarxclkout,
								w_rx_pcs_pma_if_pmarxclkslip,
								w_rx_pcs_pma_if_pmarxpllphaselockout,
								w_rx_pcs_pma_if_pmarxpmarstb,
								w_pcs8g_tx_aggtxpcsrst,
								w_pcs8g_tx_avmmreaddata,
								w_pcs8g_tx_blockselect,
								w_pcs8g_tx_clkout,
								w_pcs8g_tx_dataout,
								w_pcs8g_tx_detectrxloopout,
								w_pcs8g_tx_dynclkswitchn,
								w_pcs8g_tx_fifoselectoutchnldown,
								w_pcs8g_tx_fifoselectoutchnlup,
								w_pcs8g_tx_grayelecidleinferselout,
								w_pcs8g_tx_parallelfdbkout,
								w_pcs8g_tx_phfifooverflow,
								w_pcs8g_tx_phfifotxdeemph,
								w_pcs8g_tx_phfifotxmargin,
								w_pcs8g_tx_phfifotxswing,
								w_pcs8g_tx_phfifounderflow,
								w_pcs8g_tx_pipeenrevparallellpbkout,
								w_pcs8g_tx_pipepowerdownout,
								w_pcs8g_tx_polinvrxout,
								w_pcs8g_tx_rdenableoutchnldown,
								w_pcs8g_tx_rdenableoutchnlup,
								w_pcs8g_tx_rdenablesync,
								w_pcs8g_tx_refclkb,
								w_pcs8g_tx_refclkbreset,
								w_pcs8g_tx_rxpolarityout,
								w_pcs8g_tx_txctrlplanetestbus,
								w_pcs8g_tx_txdivsync,
								w_pcs8g_tx_txdivsyncoutchnldown,
								w_pcs8g_tx_txdivsyncoutchnlup,
								w_pcs8g_tx_txpipeclk,
								w_pcs8g_tx_txpipeelectidle,
								w_pcs8g_tx_txpipesoftreset,
								w_pcs8g_tx_txtestbus,
								w_pcs8g_tx_wrenableoutchnldown,
								w_pcs8g_tx_wrenableoutchnlup,
								w_pcs8g_tx_xgmctrlenable,
								w_pcs8g_tx_xgmdataout,
								w_com_pld_pcs_if_avmmreaddata,
								w_com_pld_pcs_if_blockselect,
								w_com_pld_pcs_if_emsipcomclkout,
								w_com_pld_pcs_if_emsipcomout,
								w_com_pld_pcs_if_emsipenablediocsrrdydly,
								w_com_pld_pcs_if_pcs8geidleinfersel,
								w_com_pld_pcs_if_pcs8ghardreset,
								w_com_pld_pcs_if_pcs8gltr,
								w_com_pld_pcs_if_pcs8gpowerdown,
								w_com_pld_pcs_if_pcs8gprbsciden,
								w_com_pld_pcs_if_pcs8grate,
								w_com_pld_pcs_if_pcs8grefclkdig,
								w_com_pld_pcs_if_pcs8grefclkdig2,
								w_com_pld_pcs_if_pcs8grxpolarity,
								w_com_pld_pcs_if_pcs8gscanmoden,
								w_com_pld_pcs_if_pcs8gtxdeemph,
								w_com_pld_pcs_if_pcs8gtxdetectrxloopback,
								w_com_pld_pcs_if_pcs8gtxelecidle,
								w_com_pld_pcs_if_pcs8gtxmargin,
								w_com_pld_pcs_if_pcs8gtxswing,
								w_com_pld_pcs_if_pcsaggrefclkdig,
								w_com_pld_pcs_if_pcsaggscanmoden,
								w_com_pld_pcs_if_pcsaggscanshift,
								w_com_pld_pcs_if_pcsaggtestsi,
								w_com_pld_pcs_if_pcspcspmaifrefclkdig,
								w_com_pld_pcs_if_pcspcspmaifscanmoden,
								w_com_pld_pcs_if_pcspcspmaifscanshiftn,
								w_com_pld_pcs_if_pcspmaifhardreset,
								w_com_pld_pcs_if_pld8gphystatus,
								w_com_pld_pcs_if_pld8grxelecidle,
								w_com_pld_pcs_if_pld8grxstatus,
								w_com_pld_pcs_if_pld8grxvalid,
								w_com_pld_pcs_if_pldclklow,
								w_com_pld_pcs_if_pldfref,
								w_com_pld_pcs_if_pldnfrzdrv,
								w_com_pld_pcs_if_pldpartialreconfigout,
								w_com_pld_pcs_if_pldreservedout,
								w_com_pld_pcs_if_pldtestdata,
								w_com_pld_pcs_if_rstsel,
								w_com_pld_pcs_if_usrrstsel,
								w_tx_pld_pcs_if_avmmreaddata,
								w_tx_pld_pcs_if_blockselect,
								w_tx_pld_pcs_if_dataoutto8gpcs,
								w_tx_pld_pcs_if_emsippcstxclkout,
								w_tx_pld_pcs_if_emsiptxspecialout,
								w_tx_pld_pcs_if_pcs8gphfifoursttx,
								w_tx_pld_pcs_if_pcs8gpldtxclk,
								w_tx_pld_pcs_if_pcs8gpolinvtx,
								w_tx_pld_pcs_if_pcs8grddisabletx,
								w_tx_pld_pcs_if_pcs8grevloopbk,
								w_tx_pld_pcs_if_pcs8gtxboundarysel,
								w_tx_pld_pcs_if_pcs8gtxdatavalid,
								w_tx_pld_pcs_if_pcs8gtxurstpcs,
								w_tx_pld_pcs_if_pcs8gwrenabletx,
								w_tx_pld_pcs_if_pld8gemptytx,
								w_tx_pld_pcs_if_pld8gfulltx,
								w_tx_pld_pcs_if_pld8gtxclkout
						};
	
	generate
		
		//module instantiations
		
		// instantiating av_hssi_rx_pld_pcs_interface
		if ((enable_8g_rx == "true") || (enable_pma_direct_rx == "true") || (enable_dyn_reconfig == "true")) begin
			av_hssi_rx_pld_pcs_interface_rbc #(
				.is_8g_0ppm(rx_pld_pcs_if_is_8g_0ppm),
				.pcs_side_block_sel(rx_pld_pcs_if_pcs_side_block_sel),
				.pld_side_data_source(rx_pld_pcs_if_pld_side_data_source),
				.use_default_base_address(rx_pld_pcs_if_use_default_base_address),
				.user_base_address(rx_pld_pcs_if_user_base_address)
			) inst_av_hssi_rx_pld_pcs_interface (
				// OUTPUTS
				.avmmreaddata(w_rx_pld_pcs_if_avmmreaddata),
				.blockselect(w_rx_pld_pcs_if_blockselect),
				.dataouttopld(w_rx_pld_pcs_if_dataouttopld),
				.emsiprxout(w_rx_pld_pcs_if_emsiprxout),
				.emsiprxspecialout(w_rx_pld_pcs_if_emsiprxspecialout),
				.pcs8ga1a2size(w_rx_pld_pcs_if_pcs8ga1a2size),
				.pcs8gbitlocreven(w_rx_pld_pcs_if_pcs8gbitlocreven),
				.pcs8gbitslip(w_rx_pld_pcs_if_pcs8gbitslip),
				.pcs8gbytereven(w_rx_pld_pcs_if_pcs8gbytereven),
				.pcs8gbytordpld(w_rx_pld_pcs_if_pcs8gbytordpld),
				.pcs8gcmpfifourst(w_rx_pld_pcs_if_pcs8gcmpfifourst),
				.pcs8gencdt(w_rx_pld_pcs_if_pcs8gencdt),
				.pcs8gphfifourstrx(w_rx_pld_pcs_if_pcs8gphfifourstrx),
				.pcs8gpldrxclk(w_rx_pld_pcs_if_pcs8gpldrxclk),
				.pcs8gpolinvrx(w_rx_pld_pcs_if_pcs8gpolinvrx),
				.pcs8grdenablerx(w_rx_pld_pcs_if_pcs8grdenablerx),
				.pcs8grxurstpcs(w_rx_pld_pcs_if_pcs8grxurstpcs),
				.pcs8gsyncsmenoutput(w_rx_pld_pcs_if_pcs8gsyncsmenoutput),
				.pcs8gwrdisablerx(w_rx_pld_pcs_if_pcs8gwrdisablerx),
				.pld8ga1a2k1k2flag(w_rx_pld_pcs_if_pld8ga1a2k1k2flag),
				.pld8galignstatus(w_rx_pld_pcs_if_pld8galignstatus),
				.pld8gbistdone(w_rx_pld_pcs_if_pld8gbistdone),
				.pld8gbisterr(w_rx_pld_pcs_if_pld8gbisterr),
				.pld8gbyteordflag(w_rx_pld_pcs_if_pld8gbyteordflag),
				.pld8gemptyrmf(w_rx_pld_pcs_if_pld8gemptyrmf),
				.pld8gemptyrx(w_rx_pld_pcs_if_pld8gemptyrx),
				.pld8gfullrmf(w_rx_pld_pcs_if_pld8gfullrmf),
				.pld8gfullrx(w_rx_pld_pcs_if_pld8gfullrx),
				.pld8grlvlt(w_rx_pld_pcs_if_pld8grlvlt),
				.pld8grxclkout(w_rx_pld_pcs_if_pld8grxclkout),
				.pld8grxdatavalid(w_rx_pld_pcs_if_pld8grxdatavalid),
				.pld8gsignaldetectout(w_rx_pld_pcs_if_pld8gsignaldetectout),
				.pld8gwaboundary(w_rx_pld_pcs_if_pld8gwaboundary),
				.pldrxclkslipout(w_rx_pld_pcs_if_pldrxclkslipout),
				.pldrxpmarstbout(w_rx_pld_pcs_if_pldrxpmarstbout),
				// INPUTS
				.avmmaddress({in_avmmaddress[10], in_avmmaddress[9], in_avmmaddress[8], in_avmmaddress[7], in_avmmaddress[6], in_avmmaddress[5], in_avmmaddress[4], in_avmmaddress[3], in_avmmaddress[2], in_avmmaddress[1], in_avmmaddress[0]}),
				.avmmbyteen({in_avmmbyteen[1], in_avmmbyteen[0]}),
				.avmmclk(in_avmmclk),
				.avmmread(in_avmmread),
				.avmmrstn(in_avmmrstn),
				.avmmwrite(in_avmmwrite),
				.avmmwritedata({in_avmmwritedata[15], in_avmmwritedata[14], in_avmmwritedata[13], in_avmmwritedata[12], in_avmmwritedata[11], in_avmmwritedata[10], in_avmmwritedata[9], in_avmmwritedata[8], in_avmmwritedata[7], in_avmmwritedata[6], in_avmmwritedata[5], in_avmmwritedata[4], in_avmmwritedata[3], in_avmmwritedata[2], in_avmmwritedata[1], in_avmmwritedata[0]}),
				.clockinfrom8gpcs(w_pcs8g_rx_clocktopld),
				.datainfrom8gpcs({w_pcs8g_rx_dataout[63], w_pcs8g_rx_dataout[62], w_pcs8g_rx_dataout[61], w_pcs8g_rx_dataout[60], w_pcs8g_rx_dataout[59], w_pcs8g_rx_dataout[58], w_pcs8g_rx_dataout[57], w_pcs8g_rx_dataout[56], w_pcs8g_rx_dataout[55], w_pcs8g_rx_dataout[54], w_pcs8g_rx_dataout[53], w_pcs8g_rx_dataout[52], w_pcs8g_rx_dataout[51], w_pcs8g_rx_dataout[50], w_pcs8g_rx_dataout[49], w_pcs8g_rx_dataout[48], w_pcs8g_rx_dataout[47], w_pcs8g_rx_dataout[46], w_pcs8g_rx_dataout[45], w_pcs8g_rx_dataout[44], w_pcs8g_rx_dataout[43], w_pcs8g_rx_dataout[42], w_pcs8g_rx_dataout[41], w_pcs8g_rx_dataout[40], w_pcs8g_rx_dataout[39], w_pcs8g_rx_dataout[38], w_pcs8g_rx_dataout[37], w_pcs8g_rx_dataout[36], w_pcs8g_rx_dataout[35], w_pcs8g_rx_dataout[34], w_pcs8g_rx_dataout[33], w_pcs8g_rx_dataout[32], w_pcs8g_rx_dataout[31], w_pcs8g_rx_dataout[30], w_pcs8g_rx_dataout[29], w_pcs8g_rx_dataout[28], w_pcs8g_rx_dataout[27], w_pcs8g_rx_dataout[26], w_pcs8g_rx_dataout[25], w_pcs8g_rx_dataout[24], w_pcs8g_rx_dataout[23], w_pcs8g_rx_dataout[22], w_pcs8g_rx_dataout[21], w_pcs8g_rx_dataout[20], w_pcs8g_rx_dataout[19], w_pcs8g_rx_dataout[18], w_pcs8g_rx_dataout[17], w_pcs8g_rx_dataout[16], w_pcs8g_rx_dataout[15], w_pcs8g_rx_dataout[14], w_pcs8g_rx_dataout[13], w_pcs8g_rx_dataout[12], w_pcs8g_rx_dataout[11], w_pcs8g_rx_dataout[10], w_pcs8g_rx_dataout[9], w_pcs8g_rx_dataout[8], w_pcs8g_rx_dataout[7], w_pcs8g_rx_dataout[6], w_pcs8g_rx_dataout[5], w_pcs8g_rx_dataout[4], w_pcs8g_rx_dataout[3], w_pcs8g_rx_dataout[2], w_pcs8g_rx_dataout[1], w_pcs8g_rx_dataout[0]}),
				.emsipenablediocsrrdydly(w_com_pld_pcs_if_emsipenablediocsrrdydly),
				.emsiprxspecialin({in_emsip_rx_special_in[12], in_emsip_rx_special_in[11], in_emsip_rx_special_in[10], in_emsip_rx_special_in[9], in_emsip_rx_special_in[8], in_emsip_rx_special_in[7], in_emsip_rx_special_in[6], in_emsip_rx_special_in[5], in_emsip_rx_special_in[4], in_emsip_rx_special_in[3], in_emsip_rx_special_in[2], in_emsip_rx_special_in[1], in_emsip_rx_special_in[0]}),
				.pcs8ga1a2k1k2flag({w_pcs8g_rx_a1a2k1k2flag[3], w_pcs8g_rx_a1a2k1k2flag[2], w_pcs8g_rx_a1a2k1k2flag[1], w_pcs8g_rx_a1a2k1k2flag[0]}),
				.pcs8galignstatus(w_pcs8g_rx_alignstatuspld),
				.pcs8gbistdone(w_pcs8g_rx_bistdone),
				.pcs8gbisterr(w_pcs8g_rx_bisterr),
				.pcs8gbyteordflag(w_pcs8g_rx_byteordflag),
				.pcs8gemptyrmf(w_pcs8g_rx_rmfifoempty),
				.pcs8gemptyrx(w_pcs8g_rx_pcfifoempty),
				.pcs8gfullrmf(w_pcs8g_rx_rmfifofull),
				.pcs8gfullrx(w_pcs8g_rx_pcfifofull),
				.pcs8grlvlt(w_pcs8g_rx_rlvlt),
				.pcs8grxdatavalid({w_pcs8g_rx_rxdatavalid[3], w_pcs8g_rx_rxdatavalid[2], w_pcs8g_rx_rxdatavalid[1], w_pcs8g_rx_rxdatavalid[0]}),
				.pcs8gsignaldetectout(w_pcs8g_rx_signaldetectout),
				.pcs8gwaboundary({w_pcs8g_rx_wordalignboundary[4], w_pcs8g_rx_wordalignboundary[3], w_pcs8g_rx_wordalignboundary[2], w_pcs8g_rx_wordalignboundary[1], w_pcs8g_rx_wordalignboundary[0]}),
				.pld8ga1a2size(in_pld_8g_a1a2_size),
				.pld8gbitlocreven(in_pld_8g_bitloc_rev_en),
				.pld8gbitslip(in_pld_8g_bitslip),
				.pld8gbytereven(in_pld_8g_byte_rev_en),
				.pld8gbytordpld(in_pld_8g_bytordpld),
				.pld8gcmpfifourstn(in_pld_8g_cmpfifourst_n),
				.pld8gencdt(in_pld_8g_encdt),
				.pld8gphfifourstrxn(in_pld_8g_phfifourst_rx_n),
				.pld8gpldrxclk(in_pld_8g_pld_rx_clk),
				.pld8gpolinvrx(in_pld_8g_polinv_rx),
				.pld8grdenablermf(in_pld_8g_rdenable_rmf),
				.pld8grdenablerx(in_pld_8g_rdenable_rx),
				.pld8grxurstpcsn(in_pld_8g_rxurstpcs_n),
				.pld8gsyncsmeninput(in_pld_sync_sm_en),
				.pld8gwrdisablerx(in_pld_8g_wrdisable_rx),
				.pld8gwrenablermf(in_pld_8g_wrenable_rmf),
				.pldrxclkslipin(in_pld_rx_clk_slip_in),
				.pldrxpmarstbin(in_pld_rxpma_rstb_in),
				.pmarxplllock(w_rx_pcs_pma_if_pmarxpllphaselockout),
				.rstsel(w_com_pld_pcs_if_rstsel),
				.usrrstsel(w_com_pld_pcs_if_usrrstsel)
			);
		end // if generate
		else begin
				assign w_rx_pld_pcs_if_avmmreaddata[15:0] = 16'b0;
				assign w_rx_pld_pcs_if_blockselect = 1'b0;
				assign w_rx_pld_pcs_if_dataouttopld[63:0] = 64'b0;
				assign w_rx_pld_pcs_if_emsiprxout[128:0] = 129'b0;
				assign w_rx_pld_pcs_if_emsiprxspecialout[15:0] = 16'b0;
				assign w_rx_pld_pcs_if_pcs8ga1a2size = 1'b0;
				assign w_rx_pld_pcs_if_pcs8gbitlocreven = 1'b0;
				assign w_rx_pld_pcs_if_pcs8gbitslip = 1'b0;
				assign w_rx_pld_pcs_if_pcs8gbytereven = 1'b0;
				assign w_rx_pld_pcs_if_pcs8gbytordpld = 1'b0;
				assign w_rx_pld_pcs_if_pcs8gcmpfifourst = 1'b0;
				assign w_rx_pld_pcs_if_pcs8gencdt = 1'b0;
				assign w_rx_pld_pcs_if_pcs8gphfifourstrx = 1'b0;
				assign w_rx_pld_pcs_if_pcs8gpldrxclk = 1'b0;
				assign w_rx_pld_pcs_if_pcs8gpolinvrx = 1'b0;
				assign w_rx_pld_pcs_if_pcs8grdenablerx = 1'b0;
				assign w_rx_pld_pcs_if_pcs8grxurstpcs = 1'b0;
				assign w_rx_pld_pcs_if_pcs8gsyncsmenoutput = 1'b0;
				assign w_rx_pld_pcs_if_pcs8gwrdisablerx = 1'b0;
				assign w_rx_pld_pcs_if_pld8ga1a2k1k2flag[3:0] = 4'b0;
				assign w_rx_pld_pcs_if_pld8galignstatus = 1'b0;
				assign w_rx_pld_pcs_if_pld8gbistdone = 1'b0;
				assign w_rx_pld_pcs_if_pld8gbisterr = 1'b0;
				assign w_rx_pld_pcs_if_pld8gbyteordflag = 1'b0;
				assign w_rx_pld_pcs_if_pld8gemptyrmf = 1'b0;
				assign w_rx_pld_pcs_if_pld8gemptyrx = 1'b0;
				assign w_rx_pld_pcs_if_pld8gfullrmf = 1'b0;
				assign w_rx_pld_pcs_if_pld8gfullrx = 1'b0;
				assign w_rx_pld_pcs_if_pld8grlvlt = 1'b0;
				assign w_rx_pld_pcs_if_pld8grxclkout = 1'b0;
				assign w_rx_pld_pcs_if_pld8grxdatavalid[3:0] = 4'b0;
				assign w_rx_pld_pcs_if_pld8gsignaldetectout = 1'b0;
				assign w_rx_pld_pcs_if_pld8gwaboundary[4:0] = 5'b0;
				assign w_rx_pld_pcs_if_pldrxclkslipout = 1'b0;
				assign w_rx_pld_pcs_if_pldrxpmarstbout = 1'b0;
		end // if not generate
		
		// instantiating av_hssi_common_pcs_pma_interface
		if ((enable_8g_rx == "true") || (enable_pma_direct_rx == "true") || (enable_dyn_reconfig == "true")) begin
			av_hssi_common_pcs_pma_interface_rbc #(
				.auto_speed_ena(com_pcs_pma_if_auto_speed_ena),
				.force_freqdet(com_pcs_pma_if_force_freqdet),
				.func_mode(com_pcs_pma_if_func_mode),
				.pipe_if_g3pcs(com_pcs_pma_if_pipe_if_g3pcs),
				.pma_if_dft_en(com_pcs_pma_if_pma_if_dft_en),
				.pma_if_dft_val(com_pcs_pma_if_pma_if_dft_val),
				.ppm_cnt_rst(com_pcs_pma_if_ppm_cnt_rst),
				.ppm_deassert_early(com_pcs_pma_if_ppm_deassert_early),
				.ppm_gen1_2_cnt(com_pcs_pma_if_ppm_gen1_2_cnt),
				.ppm_post_eidle_delay(com_pcs_pma_if_ppm_post_eidle_delay),
				.ppmsel(com_pcs_pma_if_ppmsel),
				.prot_mode(com_pcs_pma_if_prot_mode),
				.selectpcs(com_pcs_pma_if_selectpcs),
				.sup_mode(com_pcs_pma_if_sup_mode),
				.use_default_base_address(com_pcs_pma_if_use_default_base_address),
				.user_base_address(com_pcs_pma_if_user_base_address)
			) inst_av_hssi_common_pcs_pma_interface (
				// OUTPUTS
				.aggaligndetsync(w_com_pcs_pma_if_aggaligndetsync),
				.aggalignstatussync(w_com_pcs_pma_if_aggalignstatussync),
				.aggcgcomprddout(w_com_pcs_pma_if_aggcgcomprddout),
				.aggcgcompwrout(w_com_pcs_pma_if_aggcgcompwrout),
				.aggdecctl(w_com_pcs_pma_if_aggdecctl),
				.aggdecdata(w_com_pcs_pma_if_aggdecdata),
				.aggdecdatavalid(w_com_pcs_pma_if_aggdecdatavalid),
				.aggdelcondmetout(w_com_pcs_pma_if_aggdelcondmetout),
				.aggfifoovrout(w_com_pcs_pma_if_aggfifoovrout),
				.aggfifordoutcomp(w_com_pcs_pma_if_aggfifordoutcomp),
				.agginsertincompleteout(w_com_pcs_pma_if_agginsertincompleteout),
				.agglatencycompout(w_com_pcs_pma_if_agglatencycompout),
				.aggrdalign(w_com_pcs_pma_if_aggrdalign),
				.aggrdenablesync(w_com_pcs_pma_if_aggrdenablesync),
				.aggrefclkdig(w_com_pcs_pma_if_aggrefclkdig),
				.aggrunningdisp(w_com_pcs_pma_if_aggrunningdisp),
				.aggrxpcsrst(w_com_pcs_pma_if_aggrxpcsrst),
				.aggscanmoden(w_com_pcs_pma_if_aggscanmoden),
				.aggscanshiftn(w_com_pcs_pma_if_aggscanshiftn),
				.aggsyncstatus(w_com_pcs_pma_if_aggsyncstatus),
				.aggtestsotopldout(w_com_pcs_pma_if_aggtestsotopldout),
				.aggtxctltc(w_com_pcs_pma_if_aggtxctltc),
				.aggtxdatatc(w_com_pcs_pma_if_aggtxdatatc),
				.aggtxpcsrst(w_com_pcs_pma_if_aggtxpcsrst),
				.avmmreaddata(w_com_pcs_pma_if_avmmreaddata),
				.blockselect(w_com_pcs_pma_if_blockselect),
				.freqlock(w_com_pcs_pma_if_freqlock),
				.pcs8ggen2ngen1(w_com_pcs_pma_if_pcs8ggen2ngen1),
				.pcs8gpmarxfound(w_com_pcs_pma_if_pcs8gpmarxfound),
				.pcs8gpowerstatetransitiondone(w_com_pcs_pma_if_pcs8gpowerstatetransitiondone),
				.pcs8grxdetectvalid(w_com_pcs_pma_if_pcs8grxdetectvalid),
				.pcsaggalignstatus(w_com_pcs_pma_if_pcsaggalignstatus),
				.pcsaggalignstatussync0(w_com_pcs_pma_if_pcsaggalignstatussync0),
				.pcsaggalignstatussync0toporbot(w_com_pcs_pma_if_pcsaggalignstatussync0toporbot),
				.pcsaggalignstatustoporbot(w_com_pcs_pma_if_pcsaggalignstatustoporbot),
				.pcsaggcgcomprddall(w_com_pcs_pma_if_pcsaggcgcomprddall),
				.pcsaggcgcomprddalltoporbot(w_com_pcs_pma_if_pcsaggcgcomprddalltoporbot),
				.pcsaggcgcompwrall(w_com_pcs_pma_if_pcsaggcgcompwrall),
				.pcsaggcgcompwralltoporbot(w_com_pcs_pma_if_pcsaggcgcompwralltoporbot),
				.pcsaggdelcondmet0(w_com_pcs_pma_if_pcsaggdelcondmet0),
				.pcsaggdelcondmet0toporbot(w_com_pcs_pma_if_pcsaggdelcondmet0toporbot),
				.pcsaggendskwqd(w_com_pcs_pma_if_pcsaggendskwqd),
				.pcsaggendskwqdtoporbot(w_com_pcs_pma_if_pcsaggendskwqdtoporbot),
				.pcsaggendskwrdptrs(w_com_pcs_pma_if_pcsaggendskwrdptrs),
				.pcsaggendskwrdptrstoporbot(w_com_pcs_pma_if_pcsaggendskwrdptrstoporbot),
				.pcsaggfifoovr0(w_com_pcs_pma_if_pcsaggfifoovr0),
				.pcsaggfifoovr0toporbot(w_com_pcs_pma_if_pcsaggfifoovr0toporbot),
				.pcsaggfifordincomp0(w_com_pcs_pma_if_pcsaggfifordincomp0),
				.pcsaggfifordincomp0toporbot(w_com_pcs_pma_if_pcsaggfifordincomp0toporbot),
				.pcsaggfiforstrdqd(w_com_pcs_pma_if_pcsaggfiforstrdqd),
				.pcsaggfiforstrdqdtoporbot(w_com_pcs_pma_if_pcsaggfiforstrdqdtoporbot),
				.pcsagginsertincomplete0(w_com_pcs_pma_if_pcsagginsertincomplete0),
				.pcsagginsertincomplete0toporbot(w_com_pcs_pma_if_pcsagginsertincomplete0toporbot),
				.pcsagglatencycomp0(w_com_pcs_pma_if_pcsagglatencycomp0),
				.pcsagglatencycomp0toporbot(w_com_pcs_pma_if_pcsagglatencycomp0toporbot),
				.pcsaggrcvdclkagg(w_com_pcs_pma_if_pcsaggrcvdclkagg),
				.pcsaggrcvdclkaggtoporbot(w_com_pcs_pma_if_pcsaggrcvdclkaggtoporbot),
				.pcsaggrxcontrolrs(w_com_pcs_pma_if_pcsaggrxcontrolrs),
				.pcsaggrxcontrolrstoporbot(w_com_pcs_pma_if_pcsaggrxcontrolrstoporbot),
				.pcsaggrxdatars(w_com_pcs_pma_if_pcsaggrxdatars),
				.pcsaggrxdatarstoporbot(w_com_pcs_pma_if_pcsaggrxdatarstoporbot),
				.pcsaggtestbus(w_com_pcs_pma_if_pcsaggtestbus),
				.pcsaggtxctlts(w_com_pcs_pma_if_pcsaggtxctlts),
				.pcsaggtxctltstoporbot(w_com_pcs_pma_if_pcsaggtxctltstoporbot),
				.pcsaggtxdatats(w_com_pcs_pma_if_pcsaggtxdatats),
				.pcsaggtxdatatstoporbot(w_com_pcs_pma_if_pcsaggtxdatatstoporbot),
				.pldhclkout(w_com_pcs_pma_if_pldhclkout),
				.pldtestsitoaggout(w_com_pcs_pma_if_pldtestsitoaggout),
				.pmaclklowout(w_com_pcs_pma_if_pmaclklowout),
				.pmacurrentcoeff(w_com_pcs_pma_if_pmacurrentcoeff),
				.pmaearlyeios(w_com_pcs_pma_if_pmaearlyeios),
				.pmafrefout(w_com_pcs_pma_if_pmafrefout),
				.pmaiftestbus(w_com_pcs_pma_if_pmaiftestbus),
				.pmaltr(w_com_pcs_pma_if_pmaltr),
				.pmanfrzdrv(w_com_pcs_pma_if_pmanfrzdrv),
				.pmapartialreconfig(w_com_pcs_pma_if_pmapartialreconfig),
				.pmapcieswitch(w_com_pcs_pma_if_pmapcieswitch),
				.pmatxdetectrx(w_com_pcs_pma_if_pmatxdetectrx),
				.pmatxelecidle(w_com_pcs_pma_if_pmatxelecidle),
				// INPUTS
				.aggalignstatus(in_agg_align_status),
				.aggalignstatussync0(in_agg_align_status_sync_0),
				.aggalignstatussync0toporbot(in_agg_align_status_sync_0_top_or_bot),
				.aggalignstatustoporbot(in_agg_align_status_top_or_bot),
				.aggcgcomprddall(in_agg_cg_comp_rd_d_all),
				.aggcgcomprddalltoporbot(in_agg_cg_comp_rd_d_all_top_or_bot),
				.aggcgcompwrall(in_agg_cg_comp_wr_all),
				.aggcgcompwralltoporbot(in_agg_cg_comp_wr_all_top_or_bot),
				.aggdelcondmet0(in_agg_del_cond_met_0),
				.aggdelcondmet0toporbot(in_agg_del_cond_met_0_top_or_bot),
				.aggendskwqd(in_agg_en_dskw_qd),
				.aggendskwqdtoporbot(in_agg_en_dskw_qd_top_or_bot),
				.aggendskwrdptrs(in_agg_en_dskw_rd_ptrs),
				.aggendskwrdptrstoporbot(in_agg_en_dskw_rd_ptrs_top_or_bot),
				.aggfifoovr0(in_agg_fifo_ovr_0),
				.aggfifoovr0toporbot(in_agg_fifo_ovr_0_top_or_bot),
				.aggfifordincomp0(in_agg_fifo_rd_in_comp_0),
				.aggfifordincomp0toporbot(in_agg_fifo_rd_in_comp_0_top_or_bot),
				.aggfiforstrdqd(in_agg_fifo_rst_rd_qd),
				.aggfiforstrdqdtoporbot(in_agg_fifo_rst_rd_qd_top_or_bot),
				.agginsertincomplete0(in_agg_insert_incomplete_0),
				.agginsertincomplete0toporbot(in_agg_insert_incomplete_0_top_or_bot),
				.agglatencycomp0(in_agg_latency_comp_0),
				.agglatencycomp0toporbot(in_agg_latency_comp_0_top_or_bot),
				.aggrcvdclkagg(in_agg_rcvd_clk_agg),
				.aggrcvdclkaggtoporbot(in_agg_rcvd_clk_agg_top_or_bot),
				.aggrxcontrolrs(in_agg_rx_control_rs),
				.aggrxcontrolrstoporbot(in_agg_rx_control_rs_top_or_bot),
				.aggrxdatars({in_agg_rx_data_rs[7], in_agg_rx_data_rs[6], in_agg_rx_data_rs[5], in_agg_rx_data_rs[4], in_agg_rx_data_rs[3], in_agg_rx_data_rs[2], in_agg_rx_data_rs[1], in_agg_rx_data_rs[0]}),
				.aggrxdatarstoporbot({in_agg_rx_data_rs_top_or_bot[7], in_agg_rx_data_rs_top_or_bot[6], in_agg_rx_data_rs_top_or_bot[5], in_agg_rx_data_rs_top_or_bot[4], in_agg_rx_data_rs_top_or_bot[3], in_agg_rx_data_rs_top_or_bot[2], in_agg_rx_data_rs_top_or_bot[1], in_agg_rx_data_rs_top_or_bot[0]}),
				.aggtestbus({in_agg_testbus[15], in_agg_testbus[14], in_agg_testbus[13], in_agg_testbus[12], in_agg_testbus[11], in_agg_testbus[10], in_agg_testbus[9], in_agg_testbus[8], in_agg_testbus[7], in_agg_testbus[6], in_agg_testbus[5], in_agg_testbus[4], in_agg_testbus[3], in_agg_testbus[2], in_agg_testbus[1], in_agg_testbus[0]}),
				.aggtestsotopldin(in_agg_test_so_to_pld_in),
				.aggtxctlts(in_agg_tx_ctl_ts),
				.aggtxctltstoporbot(in_agg_tx_ctl_ts_top_or_bot),
				.aggtxdatats({in_agg_tx_data_ts[7], in_agg_tx_data_ts[6], in_agg_tx_data_ts[5], in_agg_tx_data_ts[4], in_agg_tx_data_ts[3], in_agg_tx_data_ts[2], in_agg_tx_data_ts[1], in_agg_tx_data_ts[0]}),
				.aggtxdatatstoporbot({in_agg_tx_data_ts_top_or_bot[7], in_agg_tx_data_ts_top_or_bot[6], in_agg_tx_data_ts_top_or_bot[5], in_agg_tx_data_ts_top_or_bot[4], in_agg_tx_data_ts_top_or_bot[3], in_agg_tx_data_ts_top_or_bot[2], in_agg_tx_data_ts_top_or_bot[1], in_agg_tx_data_ts_top_or_bot[0]}),
				.avmmaddress({in_avmmaddress[10], in_avmmaddress[9], in_avmmaddress[8], in_avmmaddress[7], in_avmmaddress[6], in_avmmaddress[5], in_avmmaddress[4], in_avmmaddress[3], in_avmmaddress[2], in_avmmaddress[1], in_avmmaddress[0]}),
				.avmmbyteen({in_avmmbyteen[1], in_avmmbyteen[0]}),
				.avmmclk(in_avmmclk),
				.avmmread(in_avmmread),
				.avmmrstn(in_avmmrstn),
				.avmmwrite(in_avmmwrite),
				.avmmwritedata({in_avmmwritedata[15], in_avmmwritedata[14], in_avmmwritedata[13], in_avmmwritedata[12], in_avmmwritedata[11], in_avmmwritedata[10], in_avmmwritedata[9], in_avmmwritedata[8], in_avmmwritedata[7], in_avmmwritedata[6], in_avmmwritedata[5], in_avmmwritedata[4], in_avmmwritedata[3], in_avmmwritedata[2], in_avmmwritedata[1], in_avmmwritedata[0]}),
				.clklow(in_pma_clklow_in),
				.fref(in_pma_fref_in),
				.hardreset(w_com_pld_pcs_if_pcspmaifhardreset),
				.pcs8gearlyeios(w_pcs8g_rx_earlyeios),
				.pcs8geidleexit(w_pcs8g_rx_eidleexit),
				.pcs8gltrpma(w_pcs8g_rx_ltr),
				.pcs8gpcieswitch(w_pcs8g_rx_pcieswitch),
				.pcs8gpmacurrentcoeff({w_pipe12_currentcoeff[17], w_pipe12_currentcoeff[16], w_pipe12_currentcoeff[15], w_pipe12_currentcoeff[14], w_pipe12_currentcoeff[13], w_pipe12_currentcoeff[12], w_pipe12_currentcoeff[11], w_pipe12_currentcoeff[10], w_pipe12_currentcoeff[9], w_pipe12_currentcoeff[8], w_pipe12_currentcoeff[7], w_pipe12_currentcoeff[6], w_pipe12_currentcoeff[5], w_pipe12_currentcoeff[4], w_pipe12_currentcoeff[3], w_pipe12_currentcoeff[2], w_pipe12_currentcoeff[1], w_pipe12_currentcoeff[0]}),
				.pcs8gtxdetectrx(w_pipe12_txdetectrx),
				.pcs8gtxelecidle(w_pipe12_txelecidleout),
				.pcsaggaligndetsync({w_pcs8g_rx_aligndetsync[1], w_pcs8g_rx_aligndetsync[0]}),
				.pcsaggalignstatussync(w_pcs8g_rx_alignstatussync),
				.pcsaggcgcomprddout({w_pcs8g_rx_cgcomprddout[1], w_pcs8g_rx_cgcomprddout[0]}),
				.pcsaggcgcompwrout({w_pcs8g_rx_cgcompwrout[1], w_pcs8g_rx_cgcompwrout[0]}),
				.pcsaggdecctl(w_pcs8g_rx_decoderctrl),
				.pcsaggdecdata({w_pcs8g_rx_decoderdata[7], w_pcs8g_rx_decoderdata[6], w_pcs8g_rx_decoderdata[5], w_pcs8g_rx_decoderdata[4], w_pcs8g_rx_decoderdata[3], w_pcs8g_rx_decoderdata[2], w_pcs8g_rx_decoderdata[1], w_pcs8g_rx_decoderdata[0]}),
				.pcsaggdecdatavalid(w_pcs8g_rx_decoderdatavalid),
				.pcsaggdelcondmetout(w_pcs8g_rx_delcondmetout),
				.pcsaggfifoovrout(w_pcs8g_rx_fifoovrout),
				.pcsaggfifordoutcomp(w_pcs8g_rx_fifordoutcomp),
				.pcsagginsertincompleteout(w_pcs8g_rx_insertincompleteout),
				.pcsagglatencycompout(w_pcs8g_rx_latencycompout),
				.pcsaggrdalign({w_pcs8g_rx_rdalign[1], w_pcs8g_rx_rdalign[0]}),
				.pcsaggrdenablesync(w_pcs8g_tx_rdenablesync),
				.pcsaggrefclkdig(w_com_pld_pcs_if_pcsaggrefclkdig),
				.pcsaggrunningdisp({w_pcs8g_rx_runningdisparity[1], w_pcs8g_rx_runningdisparity[0]}),
				.pcsaggrxpcsrst(w_pcs8g_rx_aggrxpcsrst),
				.pcsaggscanmoden(w_com_pld_pcs_if_pcsaggscanmoden),
				.pcsaggscanshiftn(w_com_pld_pcs_if_pcsaggscanshift),
				.pcsaggsyncstatus(w_pcs8g_rx_syncstatus),
				.pcsaggtxctltc(w_pcs8g_tx_xgmctrlenable),
				.pcsaggtxdatatc({w_pcs8g_tx_xgmdataout[7], w_pcs8g_tx_xgmdataout[6], w_pcs8g_tx_xgmdataout[5], w_pcs8g_tx_xgmdataout[4], w_pcs8g_tx_xgmdataout[3], w_pcs8g_tx_xgmdataout[2], w_pcs8g_tx_xgmdataout[1], w_pcs8g_tx_xgmdataout[0]}),
				.pcsaggtxpcsrst(w_pcs8g_tx_aggtxpcsrst),
				.pcsrefclkdig(w_com_pld_pcs_if_pcspcspmaifrefclkdig),
				.pcsscanmoden(w_com_pld_pcs_if_pcspcspmaifscanmoden),
				.pcsscanshiftn(w_com_pld_pcs_if_pcspcspmaifscanshiftn),
				.pldnfrzdrv(w_com_pld_pcs_if_pldnfrzdrv),
				.pldpartialreconfig(w_com_pld_pcs_if_pldpartialreconfigout),
				.pldtestsitoaggin(w_com_pld_pcs_if_pcsaggtestsi),
				.pmahclk(in_pma_hclk),
				.pmapcieswdone({1'b0, in_pma_pcie_sw_done}),
				.pmarxdetectvalid(in_pma_rx_detect_valid),
				.pmarxfound(in_pma_rx_found),
				.pmarxpmarstb(w_rx_pcs_pma_if_pmarxpmarstb),
				.resetppmcntrs(w_pcs8g_rx_resetppmcntrspcspma)
			);
		end // if generate
		else begin
				assign w_com_pcs_pma_if_aggaligndetsync[1:0] = 2'b0;
				assign w_com_pcs_pma_if_aggalignstatussync = 1'b0;
				assign w_com_pcs_pma_if_aggcgcomprddout[1:0] = 2'b0;
				assign w_com_pcs_pma_if_aggcgcompwrout[1:0] = 2'b0;
				assign w_com_pcs_pma_if_aggdecctl = 1'b0;
				assign w_com_pcs_pma_if_aggdecdata[7:0] = 8'b0;
				assign w_com_pcs_pma_if_aggdecdatavalid = 1'b0;
				assign w_com_pcs_pma_if_aggdelcondmetout = 1'b0;
				assign w_com_pcs_pma_if_aggfifoovrout = 1'b0;
				assign w_com_pcs_pma_if_aggfifordoutcomp = 1'b0;
				assign w_com_pcs_pma_if_agginsertincompleteout = 1'b0;
				assign w_com_pcs_pma_if_agglatencycompout = 1'b0;
				assign w_com_pcs_pma_if_aggrdalign[1:0] = 2'b0;
				assign w_com_pcs_pma_if_aggrdenablesync = 1'b0;
				assign w_com_pcs_pma_if_aggrefclkdig = 1'b0;
				assign w_com_pcs_pma_if_aggrunningdisp[1:0] = 2'b0;
				assign w_com_pcs_pma_if_aggrxpcsrst = 1'b0;
				assign w_com_pcs_pma_if_aggscanmoden = 1'b0;
				assign w_com_pcs_pma_if_aggscanshiftn = 1'b0;
				assign w_com_pcs_pma_if_aggsyncstatus = 1'b0;
				assign w_com_pcs_pma_if_aggtestsotopldout = 1'b0;
				assign w_com_pcs_pma_if_aggtxctltc = 1'b0;
				assign w_com_pcs_pma_if_aggtxdatatc[7:0] = 8'b0;
				assign w_com_pcs_pma_if_aggtxpcsrst = 1'b0;
				assign w_com_pcs_pma_if_avmmreaddata[15:0] = 16'b0;
				assign w_com_pcs_pma_if_blockselect = 1'b0;
				assign w_com_pcs_pma_if_freqlock = 1'b0;
				assign w_com_pcs_pma_if_pcs8ggen2ngen1 = 1'b0;
				assign w_com_pcs_pma_if_pcs8gpmarxfound = 1'b0;
				assign w_com_pcs_pma_if_pcs8gpowerstatetransitiondone = 1'b0;
				assign w_com_pcs_pma_if_pcs8grxdetectvalid = 1'b0;
				assign w_com_pcs_pma_if_pcsaggalignstatus = 1'b0;
				assign w_com_pcs_pma_if_pcsaggalignstatussync0 = 1'b0;
				assign w_com_pcs_pma_if_pcsaggalignstatussync0toporbot = 1'b0;
				assign w_com_pcs_pma_if_pcsaggalignstatustoporbot = 1'b0;
				assign w_com_pcs_pma_if_pcsaggcgcomprddall = 1'b0;
				assign w_com_pcs_pma_if_pcsaggcgcomprddalltoporbot = 1'b0;
				assign w_com_pcs_pma_if_pcsaggcgcompwrall = 1'b0;
				assign w_com_pcs_pma_if_pcsaggcgcompwralltoporbot = 1'b0;
				assign w_com_pcs_pma_if_pcsaggdelcondmet0 = 1'b0;
				assign w_com_pcs_pma_if_pcsaggdelcondmet0toporbot = 1'b0;
				assign w_com_pcs_pma_if_pcsaggendskwqd = 1'b0;
				assign w_com_pcs_pma_if_pcsaggendskwqdtoporbot = 1'b0;
				assign w_com_pcs_pma_if_pcsaggendskwrdptrs = 1'b0;
				assign w_com_pcs_pma_if_pcsaggendskwrdptrstoporbot = 1'b0;
				assign w_com_pcs_pma_if_pcsaggfifoovr0 = 1'b0;
				assign w_com_pcs_pma_if_pcsaggfifoovr0toporbot = 1'b0;
				assign w_com_pcs_pma_if_pcsaggfifordincomp0 = 1'b0;
				assign w_com_pcs_pma_if_pcsaggfifordincomp0toporbot = 1'b0;
				assign w_com_pcs_pma_if_pcsaggfiforstrdqd = 1'b0;
				assign w_com_pcs_pma_if_pcsaggfiforstrdqdtoporbot = 1'b0;
				assign w_com_pcs_pma_if_pcsagginsertincomplete0 = 1'b0;
				assign w_com_pcs_pma_if_pcsagginsertincomplete0toporbot = 1'b0;
				assign w_com_pcs_pma_if_pcsagglatencycomp0 = 1'b0;
				assign w_com_pcs_pma_if_pcsagglatencycomp0toporbot = 1'b0;
				assign w_com_pcs_pma_if_pcsaggrcvdclkagg = 1'b0;
				assign w_com_pcs_pma_if_pcsaggrcvdclkaggtoporbot = 1'b0;
				assign w_com_pcs_pma_if_pcsaggrxcontrolrs = 1'b0;
				assign w_com_pcs_pma_if_pcsaggrxcontrolrstoporbot = 1'b0;
				assign w_com_pcs_pma_if_pcsaggrxdatars[7:0] = 8'b0;
				assign w_com_pcs_pma_if_pcsaggrxdatarstoporbot[7:0] = 8'b0;
				assign w_com_pcs_pma_if_pcsaggtestbus[15:0] = 16'b0;
				assign w_com_pcs_pma_if_pcsaggtxctlts = 1'b0;
				assign w_com_pcs_pma_if_pcsaggtxctltstoporbot = 1'b0;
				assign w_com_pcs_pma_if_pcsaggtxdatats[7:0] = 8'b0;
				assign w_com_pcs_pma_if_pcsaggtxdatatstoporbot[7:0] = 8'b0;
				assign w_com_pcs_pma_if_pldhclkout = 1'b0;
				assign w_com_pcs_pma_if_pldtestsitoaggout = 1'b0;
				assign w_com_pcs_pma_if_pmaclklowout = 1'b0;
				assign w_com_pcs_pma_if_pmacurrentcoeff[17:0] = 18'b0;
				assign w_com_pcs_pma_if_pmaearlyeios = 1'b0;
				assign w_com_pcs_pma_if_pmafrefout = 1'b0;
				assign w_com_pcs_pma_if_pmaiftestbus[9:0] = 10'b0;
				assign w_com_pcs_pma_if_pmaltr = 1'b0;
				assign w_com_pcs_pma_if_pmanfrzdrv = 1'b0;
				assign w_com_pcs_pma_if_pmapartialreconfig = 1'b0;
				assign w_com_pcs_pma_if_pmapcieswitch[1:0] = 2'b0;
				assign w_com_pcs_pma_if_pmatxdetectrx = 1'b0;
				assign w_com_pcs_pma_if_pmatxelecidle = 1'b0;
		end // if not generate
		
		// instantiating av_hssi_pipe_gen1_2
		if ((enable_dyn_reconfig == "true") || (enable_gen12_pipe == "true")) begin
			av_hssi_pipe_gen1_2_rbc #(
				.ctrl_plane_bonding_consumption(pipe12_ctrl_plane_bonding_consumption),
				.elec_idle_delay_val(pipe12_elec_idle_delay_val),
				.elecidle_delay(pipe12_elecidle_delay),
				.error_replace_pad(pipe12_error_replace_pad),
				.hip_mode(pipe12_hip_mode),
				.ind_error_reporting(pipe12_ind_error_reporting),
				.phy_status_delay(pipe12_phy_status_delay),
				.phystatus_delay_val(pipe12_phystatus_delay_val),
				.phystatus_rst_toggle(pipe12_phystatus_rst_toggle),
				.pipe_byte_de_serializer_en(pipe12_pipe_byte_de_serializer_en),
				.prot_mode(pipe12_prot_mode),
				.rpre_emph_a_val(pipe12_rpre_emph_a_val),
				.rpre_emph_b_val(pipe12_rpre_emph_b_val),
				.rpre_emph_c_val(pipe12_rpre_emph_c_val),
				.rpre_emph_d_val(pipe12_rpre_emph_d_val),
				.rpre_emph_e_val(pipe12_rpre_emph_e_val),
				.rpre_emph_settings(pipe12_rpre_emph_settings),
				.rvod_sel_a_val(pipe12_rvod_sel_a_val),
				.rvod_sel_b_val(pipe12_rvod_sel_b_val),
				.rvod_sel_c_val(pipe12_rvod_sel_c_val),
				.rvod_sel_d_val(pipe12_rvod_sel_d_val),
				.rvod_sel_e_val(pipe12_rvod_sel_e_val),
				.rvod_sel_settings(pipe12_rvod_sel_settings),
				.rx_pipe_enable(pipe12_rx_pipe_enable),
				.rxdetect_bypass(pipe12_rxdetect_bypass),
				.sup_mode(pipe12_sup_mode),
				.tx_pipe_enable(pipe12_tx_pipe_enable),
				.txswing(pipe12_txswing),
				.use_default_base_address(pipe12_use_default_base_address),
				.user_base_address(pipe12_user_base_address)
			) inst_av_hssi_pipe_gen1_2 (
				// OUTPUTS
				.avmmreaddata(w_pipe12_avmmreaddata),
				.blockselect(w_pipe12_blockselect),
				.currentcoeff(w_pipe12_currentcoeff),
				.phystatus(w_pipe12_phystatus),
				.polinvrxint(w_pipe12_polinvrxint),
				.revloopbk(w_pipe12_revloopbk),
				.rxelecidle(w_pipe12_rxelecidle),
				.rxstatus(w_pipe12_rxstatus),
				.rxvalid(w_pipe12_rxvalid),
				.txdetectrx(w_pipe12_txdetectrx),
				.txelecidleout(w_pipe12_txelecidleout),
				// INPUTS
				.avmmaddress({in_avmmaddress[10], in_avmmaddress[9], in_avmmaddress[8], in_avmmaddress[7], in_avmmaddress[6], in_avmmaddress[5], in_avmmaddress[4], in_avmmaddress[3], in_avmmaddress[2], in_avmmaddress[1], in_avmmaddress[0]}),
				.avmmbyteen({in_avmmbyteen[1], in_avmmbyteen[0]}),
				.avmmclk(in_avmmclk),
				.avmmread(in_avmmread),
				.avmmrstn(in_avmmrstn),
				.avmmwrite(in_avmmwrite),
				.avmmwritedata({in_avmmwritedata[15], in_avmmwritedata[14], in_avmmwritedata[13], in_avmmwritedata[12], in_avmmwritedata[11], in_avmmwritedata[10], in_avmmwritedata[9], in_avmmwritedata[8], in_avmmwritedata[7], in_avmmwritedata[6], in_avmmwritedata[5], in_avmmwritedata[4], in_avmmwritedata[3], in_avmmwritedata[2], in_avmmwritedata[1], in_avmmwritedata[0]}),
				.pcieswitch(w_pcs8g_rx_pcieswitch),
				.piperxclk(w_pcs8g_rx_rxpipeclk),
				.pipetxclk(w_pcs8g_tx_txpipeclk),
				.polinvrx(w_pcs8g_tx_polinvrxout),
				.powerdown({w_pcs8g_tx_pipepowerdownout[1], w_pcs8g_tx_pipepowerdownout[0]}),
				.powerstatetransitiondone(w_com_pcs_pma_if_pcs8gpowerstatetransitiondone),
				.powerstatetransitiondoneena(1'b0),
				.refclkb(w_pcs8g_tx_refclkb),
				.refclkbreset(w_pcs8g_tx_refclkbreset),
				.revloopback(w_pcs8g_tx_pipeenrevparallellpbkout),
				.rxd({w_pcs8g_rx_pipedata[63], w_pcs8g_rx_pipedata[62], w_pcs8g_rx_pipedata[61], w_pcs8g_rx_pipedata[60], w_pcs8g_rx_pipedata[59], w_pcs8g_rx_pipedata[58], w_pcs8g_rx_pipedata[57], w_pcs8g_rx_pipedata[56], w_pcs8g_rx_pipedata[55], w_pcs8g_rx_pipedata[54], w_pcs8g_rx_pipedata[53], w_pcs8g_rx_pipedata[52], w_pcs8g_rx_pipedata[51], w_pcs8g_rx_pipedata[50], w_pcs8g_rx_pipedata[49], w_pcs8g_rx_pipedata[48], w_pcs8g_rx_pipedata[47], w_pcs8g_rx_pipedata[46], w_pcs8g_rx_pipedata[45], w_pcs8g_rx_pipedata[44], w_pcs8g_rx_pipedata[43], w_pcs8g_rx_pipedata[42], w_pcs8g_rx_pipedata[41], w_pcs8g_rx_pipedata[40], w_pcs8g_rx_pipedata[39], w_pcs8g_rx_pipedata[38], w_pcs8g_rx_pipedata[37], w_pcs8g_rx_pipedata[36], w_pcs8g_rx_pipedata[35], w_pcs8g_rx_pipedata[34], w_pcs8g_rx_pipedata[33], w_pcs8g_rx_pipedata[32], w_pcs8g_rx_pipedata[31], w_pcs8g_rx_pipedata[30], w_pcs8g_rx_pipedata[29], w_pcs8g_rx_pipedata[28], w_pcs8g_rx_pipedata[27], w_pcs8g_rx_pipedata[26], w_pcs8g_rx_pipedata[25], w_pcs8g_rx_pipedata[24], w_pcs8g_rx_pipedata[23], w_pcs8g_rx_pipedata[22], w_pcs8g_rx_pipedata[21], w_pcs8g_rx_pipedata[20], w_pcs8g_rx_pipedata[19], w_pcs8g_rx_pipedata[18], w_pcs8g_rx_pipedata[17], w_pcs8g_rx_pipedata[16], w_pcs8g_rx_pipedata[15], w_pcs8g_rx_pipedata[14], w_pcs8g_rx_pipedata[13], w_pcs8g_rx_pipedata[12], w_pcs8g_rx_pipedata[11], w_pcs8g_rx_pipedata[10], w_pcs8g_rx_pipedata[9], w_pcs8g_rx_pipedata[8], w_pcs8g_rx_pipedata[7], w_pcs8g_rx_pipedata[6], w_pcs8g_rx_pipedata[5], w_pcs8g_rx_pipedata[4], w_pcs8g_rx_pipedata[3], w_pcs8g_rx_pipedata[2], w_pcs8g_rx_pipedata[1], w_pcs8g_rx_pipedata[0]}),
				.rxdetectvalid(w_com_pcs_pma_if_pcs8grxdetectvalid),
				.rxelectricalidle(w_pcs8g_rx_eidledetected),
				.rxfound(w_com_pcs_pma_if_pcs8gpmarxfound),
				.rxpipereset(w_pcs8g_rx_rxpipesoftreset),
				.rxpolarity(w_pcs8g_tx_rxpolarityout),
				.sigdetni(w_rx_pcs_pma_if_pcs8gsigdetni),
				.speedchange(w_pcs8g_rx_speedchange),
				.speedchangechnldown(w_pcs8g_rx_speedchangeinchnldownpipe),
				.speedchangechnlup(w_pcs8g_rx_speedchangeinchnluppipe),
				.txdch({w_tx_pld_pcs_if_dataoutto8gpcs[43], w_tx_pld_pcs_if_dataoutto8gpcs[42], w_tx_pld_pcs_if_dataoutto8gpcs[41], w_tx_pld_pcs_if_dataoutto8gpcs[40], w_tx_pld_pcs_if_dataoutto8gpcs[39], w_tx_pld_pcs_if_dataoutto8gpcs[38], w_tx_pld_pcs_if_dataoutto8gpcs[37], w_tx_pld_pcs_if_dataoutto8gpcs[36], w_tx_pld_pcs_if_dataoutto8gpcs[35], w_tx_pld_pcs_if_dataoutto8gpcs[34], w_tx_pld_pcs_if_dataoutto8gpcs[33], w_tx_pld_pcs_if_dataoutto8gpcs[32], w_tx_pld_pcs_if_dataoutto8gpcs[31], w_tx_pld_pcs_if_dataoutto8gpcs[30], w_tx_pld_pcs_if_dataoutto8gpcs[29], w_tx_pld_pcs_if_dataoutto8gpcs[28], w_tx_pld_pcs_if_dataoutto8gpcs[27], w_tx_pld_pcs_if_dataoutto8gpcs[26], w_tx_pld_pcs_if_dataoutto8gpcs[25], w_tx_pld_pcs_if_dataoutto8gpcs[24], w_tx_pld_pcs_if_dataoutto8gpcs[23], w_tx_pld_pcs_if_dataoutto8gpcs[22], w_tx_pld_pcs_if_dataoutto8gpcs[21], w_tx_pld_pcs_if_dataoutto8gpcs[20], w_tx_pld_pcs_if_dataoutto8gpcs[19], w_tx_pld_pcs_if_dataoutto8gpcs[18], w_tx_pld_pcs_if_dataoutto8gpcs[17], w_tx_pld_pcs_if_dataoutto8gpcs[16], w_tx_pld_pcs_if_dataoutto8gpcs[15], w_tx_pld_pcs_if_dataoutto8gpcs[14], w_tx_pld_pcs_if_dataoutto8gpcs[13], w_tx_pld_pcs_if_dataoutto8gpcs[12], w_tx_pld_pcs_if_dataoutto8gpcs[11], w_tx_pld_pcs_if_dataoutto8gpcs[10], w_tx_pld_pcs_if_dataoutto8gpcs[9], w_tx_pld_pcs_if_dataoutto8gpcs[8], w_tx_pld_pcs_if_dataoutto8gpcs[7], w_tx_pld_pcs_if_dataoutto8gpcs[6], w_tx_pld_pcs_if_dataoutto8gpcs[5], w_tx_pld_pcs_if_dataoutto8gpcs[4], w_tx_pld_pcs_if_dataoutto8gpcs[3], w_tx_pld_pcs_if_dataoutto8gpcs[2], w_tx_pld_pcs_if_dataoutto8gpcs[1], w_tx_pld_pcs_if_dataoutto8gpcs[0]}),
				.txdeemph(w_pcs8g_tx_phfifotxdeemph),
				.txdetectrxloopback(w_pcs8g_tx_detectrxloopout),
				.txelecidlecomp(w_pcs8g_tx_txpipeelectidle),
				.txelecidlein(w_com_pld_pcs_if_pcs8gtxelecidle),
				.txmargin({w_pcs8g_tx_phfifotxmargin[2], w_pcs8g_tx_phfifotxmargin[1], w_pcs8g_tx_phfifotxmargin[0]}),
				.txpipereset(w_pcs8g_tx_txpipesoftreset),
				.txswingport(w_pcs8g_tx_phfifotxswing)
			);
		end // if generate
		else begin
				assign w_pipe12_avmmreaddata[15:0] = 16'b0;
				assign w_pipe12_blockselect = 1'b0;
				assign w_pipe12_currentcoeff[17:0] = 18'b0;
				assign w_pipe12_phystatus = 1'b0;
				assign w_pipe12_polinvrxint = w_pcs8g_tx_polinvrxout;			// connected when av_hssi_pipe_gen1_2 is not instantiated
				assign w_pipe12_revloopbk = w_pcs8g_tx_pipeenrevparallellpbkout;	// connected when av_hssi_pipe_gen1_2 is not instantiated
				assign w_pipe12_rxelecidle = w_rx_pcs_pma_if_pcs8gsigdetni;		// connected when av_hssi_pipe_gen1_2 is not instantiated
				assign w_pipe12_rxstatus[2:0] = {1'b0,w_com_pcs_pma_if_pcs8grxdetectvalid,w_com_pcs_pma_if_pcs8gpmarxfound};	// connected when av_hssi_pipe_gen1_2 is not instantiated
				assign w_pipe12_rxvalid = 1'b0;       
				assign w_pipe12_txdetectrx = 1'b0;
				assign w_pipe12_txelecidleout = w_com_pld_pcs_if_pcs8gtxelecidle;	// connected when av_hssi_pipe_gen1_2 is not instantiated			
		end // if not generate
		
		// instantiating av_hssi_8g_rx_pcs
		if ((enable_8g_rx == "true") || (enable_dyn_reconfig == "true")) begin
			av_hssi_8g_rx_pcs_rbc #(
				.agg_block_sel(pcs8g_rx_agg_block_sel),
				.auto_error_replacement(pcs8g_rx_auto_error_replacement),
				.auto_speed_nego(pcs8g_rx_auto_speed_nego),
				.bist_ver(pcs8g_rx_bist_ver),
				.bist_ver_clr_flag(pcs8g_rx_bist_ver_clr_flag),
				.bit_reversal(pcs8g_rx_bit_reversal),
				.bo_pad(pcs8g_rx_bo_pad),
				.bo_pattern(pcs8g_rx_bo_pattern),
				.bypass_pipeline_reg(pcs8g_rx_bypass_pipeline_reg),
				.byte_deserializer(pcs8g_rx_byte_deserializer),
				.byte_order(pcs8g_rx_byte_order),
				.cdr_ctrl(pcs8g_rx_cdr_ctrl),
				.cdr_ctrl_rxvalid_mask(pcs8g_rx_cdr_ctrl_rxvalid_mask),
				.channel_number(channel_number),
				.cid_pattern(pcs8g_rx_cid_pattern),
				.cid_pattern_len(pcs8g_rx_cid_pattern_len),
				.clkcmp_pattern_n(pcs8g_rx_clkcmp_pattern_n),
				.clkcmp_pattern_p(pcs8g_rx_clkcmp_pattern_p),
				.clock_gate_bds_dec_asn(pcs8g_rx_clock_gate_bds_dec_asn),
				.clock_gate_bist(pcs8g_rx_clock_gate_bist),
				.clock_gate_byteorder(pcs8g_rx_clock_gate_byteorder),
				.clock_gate_cdr_eidle(pcs8g_rx_clock_gate_cdr_eidle),
				.clock_gate_dskw_rd(pcs8g_rx_clock_gate_dskw_rd),
				.clock_gate_dw_dskw_wr(pcs8g_rx_clock_gate_dw_dskw_wr),
				.clock_gate_dw_pc_wrclk(pcs8g_rx_clock_gate_dw_pc_wrclk),
				.clock_gate_dw_rm_rd(pcs8g_rx_clock_gate_dw_rm_rd),
				.clock_gate_dw_rm_wr(pcs8g_rx_clock_gate_dw_rm_wr),
				.clock_gate_dw_wa(pcs8g_rx_clock_gate_dw_wa),
				.clock_gate_pc_rdclk(pcs8g_rx_clock_gate_pc_rdclk),
				.clock_gate_prbs(pcs8g_rx_clock_gate_prbs),
				.clock_gate_sw_dskw_wr(pcs8g_rx_clock_gate_sw_dskw_wr),
				.clock_gate_sw_pc_wrclk(pcs8g_rx_clock_gate_sw_pc_wrclk),
				.clock_gate_sw_rm_rd(pcs8g_rx_clock_gate_sw_rm_rd),
				.clock_gate_sw_rm_wr(pcs8g_rx_clock_gate_sw_rm_wr),
				.clock_gate_sw_wa(pcs8g_rx_clock_gate_sw_wa),
				.comp_fifo_rst_pld_ctrl(pcs8g_rx_comp_fifo_rst_pld_ctrl),
				.ctrl_plane_bonding_compensation(pcs8g_rx_ctrl_plane_bonding_compensation),
				.ctrl_plane_bonding_consumption(pcs8g_rx_ctrl_plane_bonding_consumption),
				.ctrl_plane_bonding_distribution(pcs8g_rx_ctrl_plane_bonding_distribution),
				.deskew(pcs8g_rx_deskew),
				.deskew_pattern(pcs8g_rx_deskew_pattern),
				.deskew_prog_pattern_only(pcs8g_rx_deskew_prog_pattern_only),
				.dw_one_or_two_symbol_bo(pcs8g_rx_dw_one_or_two_symbol_bo),
				.eidle_entry_eios(pcs8g_rx_eidle_entry_eios),
				.eidle_entry_iei(pcs8g_rx_eidle_entry_iei),
				.eidle_entry_sd(pcs8g_rx_eidle_entry_sd),
				.eightb_tenb_decoder(pcs8g_rx_eightb_tenb_decoder),
				.eightbtenb_decoder_output_sel(pcs8g_rx_eightbtenb_decoder_output_sel),
				.err_flags_sel(pcs8g_rx_err_flags_sel),
				.fixed_pat_det(pcs8g_rx_fixed_pat_det),
				.fixed_pat_num(pcs8g_rx_fixed_pat_num),
				.force_signal_detect(pcs8g_rx_force_signal_detect),
				.hip_mode(pcs8g_rx_hip_mode),
				.ibm_invalid_code(pcs8g_rx_ibm_invalid_code),
				.invalid_code_flag_only(pcs8g_rx_invalid_code_flag_only),
				.mask_cnt(pcs8g_rx_mask_cnt),
				.pad_or_edb_error_replace(pcs8g_rx_pad_or_edb_error_replace),
				.pc_fifo_rst_pld_ctrl(pcs8g_rx_pc_fifo_rst_pld_ctrl),
				.pcs_bypass(pcs8g_rx_pcs_bypass),
				.phase_compensation_fifo(pcs8g_rx_phase_compensation_fifo),
				.pipe_if_enable(pcs8g_rx_pipe_if_enable),
				.pma_done_count(pcs8g_rx_pma_done_count),
				.pma_dw(pcs8g_rx_pma_dw),
				.polarity_inversion(pcs8g_rx_polarity_inversion),
				.polinv_8b10b_dec(pcs8g_rx_polinv_8b10b_dec),
				.prbs_ver(pcs8g_rx_prbs_ver),
				.prbs_ver_clr_flag(pcs8g_rx_prbs_ver_clr_flag),
				.prot_mode(pcs8g_rx_prot_mode),
				.rate_match(pcs8g_rx_rate_match),
				.re_bo_on_wa(pcs8g_rx_re_bo_on_wa),
				.runlength_check(pcs8g_rx_runlength_check),
				.runlength_val(pcs8g_rx_runlength_val),
				.rx_clk1(pcs8g_rx_rx_clk1),
				.rx_clk2(pcs8g_rx_rx_clk2),
				.rx_clk_free_running(pcs8g_rx_rx_clk_free_running),
				.rx_pcs_urst(pcs8g_rx_rx_pcs_urst),
				.rx_rcvd_clk(pcs8g_rx_rx_rcvd_clk),
				.rx_rd_clk(pcs8g_rx_rx_rd_clk),
				.rx_refclk(pcs8g_rx_rx_refclk),
				.rx_wr_clk(pcs8g_rx_rx_wr_clk),
				.sup_mode(pcs8g_rx_sup_mode),
				.symbol_swap(pcs8g_rx_symbol_swap),
				.test_bus_sel(pcs8g_rx_test_bus_sel),
				.test_mode(pcs8g_rx_test_mode),
				.tx_rx_parallel_loopback(pcs8g_rx_tx_rx_parallel_loopback),
				.use_default_base_address(pcs8g_rx_use_default_base_address),
				.user_base_address(pcs8g_rx_user_base_address),
				.wa_boundary_lock_ctrl(pcs8g_rx_wa_boundary_lock_ctrl),
				.wa_clk_slip_spacing(pcs8g_rx_wa_clk_slip_spacing),
				.wa_clk_slip_spacing_data(pcs8g_rx_wa_clk_slip_spacing_data),
				.wa_det_latency_sync_status_beh(pcs8g_rx_wa_det_latency_sync_status_beh),
				.wa_disp_err_flag(pcs8g_rx_wa_disp_err_flag),
				.wa_kchar(pcs8g_rx_wa_kchar),
				.wa_pd(pcs8g_rx_wa_pd),
				.wa_pd_data(pcs8g_rx_wa_pd_data),
				.wa_pd_polarity(pcs8g_rx_wa_pd_polarity),
				.wa_pld_controlled(pcs8g_rx_wa_pld_controlled),
				.wa_renumber_data(pcs8g_rx_wa_renumber_data),
				.wa_rgnumber_data(pcs8g_rx_wa_rgnumber_data),
				.wa_rknumber_data(pcs8g_rx_wa_rknumber_data),
				.wa_rosnumber_data(pcs8g_rx_wa_rosnumber_data),
				.wa_rvnumber_data(pcs8g_rx_wa_rvnumber_data),
				.wa_sync_sm_ctrl(pcs8g_rx_wa_sync_sm_ctrl),
				.wait_cnt(pcs8g_rx_wait_cnt)
			) inst_av_hssi_8g_rx_pcs (
				// OUTPUTS
				.a1a2k1k2flag(w_pcs8g_rx_a1a2k1k2flag),
				.aggrxpcsrst(w_pcs8g_rx_aggrxpcsrst),
				.aligndetsync(w_pcs8g_rx_aligndetsync),
				.alignstatuspld(w_pcs8g_rx_alignstatuspld),
				.alignstatussync(w_pcs8g_rx_alignstatussync),
				.avmmreaddata(w_pcs8g_rx_avmmreaddata),
				.bistdone(w_pcs8g_rx_bistdone),
				.bisterr(w_pcs8g_rx_bisterr),
				.blockselect(w_pcs8g_rx_blockselect),
				.byteordflag(w_pcs8g_rx_byteordflag),
				.cgcomprddout(w_pcs8g_rx_cgcomprddout),
				.cgcompwrout(w_pcs8g_rx_cgcompwrout),
				.channeltestbusout(w_pcs8g_rx_channeltestbusout),
				.clocktopld(w_pcs8g_rx_clocktopld),
				.configseloutchnldown(w_pcs8g_rx_configseloutchnldown),
				.configseloutchnlup(w_pcs8g_rx_configseloutchnlup),
				.dataout(w_pcs8g_rx_dataout),
				.decoderctrl(w_pcs8g_rx_decoderctrl),
				.decoderdata(w_pcs8g_rx_decoderdata),
				.decoderdatavalid(w_pcs8g_rx_decoderdatavalid),
				.delcondmetout(w_pcs8g_rx_delcondmetout),
				.disablepcfifobyteserdes(w_pcs8g_rx_disablepcfifobyteserdes),
				.earlyeios(w_pcs8g_rx_earlyeios),
				.eidledetected(w_pcs8g_rx_eidledetected),
				.eidleexit(w_pcs8g_rx_eidleexit),
				.fifoovrout(w_pcs8g_rx_fifoovrout),
				.fifordoutcomp(w_pcs8g_rx_fifordoutcomp),
				.insertincompleteout(w_pcs8g_rx_insertincompleteout),
				.latencycompout(w_pcs8g_rx_latencycompout),
				.ltr(w_pcs8g_rx_ltr),
				.parallelrevloopback(w_pcs8g_rx_parallelrevloopback),
				.pcfifoempty(w_pcs8g_rx_pcfifoempty),
				.pcfifofull(w_pcs8g_rx_pcfifofull),
				.pcieswitch(w_pcs8g_rx_pcieswitch),
				.phystatus(w_pcs8g_rx_phystatus),
				.pipedata(w_pcs8g_rx_pipedata),
				.rdalign(w_pcs8g_rx_rdalign),
				.rdenableoutchnldown(w_pcs8g_rx_rdenableoutchnldown),
				.rdenableoutchnlup(w_pcs8g_rx_rdenableoutchnlup),
				.resetpcptrs(w_pcs8g_rx_resetpcptrs),
				.resetpcptrsinchnldownpipe(w_pcs8g_rx_resetpcptrsinchnldownpipe),
				.resetpcptrsinchnluppipe(w_pcs8g_rx_resetpcptrsinchnluppipe),
				.resetpcptrsoutchnldown(w_pcs8g_rx_resetpcptrsoutchnldown),
				.resetpcptrsoutchnlup(w_pcs8g_rx_resetpcptrsoutchnlup),
				.resetppmcntrsoutchnldown(w_pcs8g_rx_resetppmcntrsoutchnldown),
				.resetppmcntrsoutchnlup(w_pcs8g_rx_resetppmcntrsoutchnlup),
				.resetppmcntrspcspma(w_pcs8g_rx_resetppmcntrspcspma),
				.rlvlt(w_pcs8g_rx_rlvlt),
				.rmfifoempty(w_pcs8g_rx_rmfifoempty),
				.rmfifofull(w_pcs8g_rx_rmfifofull),
				.runningdisparity(w_pcs8g_rx_runningdisparity),
				.rxclkslip(w_pcs8g_rx_rxclkslip),
				.rxdatavalid(w_pcs8g_rx_rxdatavalid),
				.rxdivsyncoutchnldown(w_pcs8g_rx_rxdivsyncoutchnldown),
				.rxdivsyncoutchnlup(w_pcs8g_rx_rxdivsyncoutchnlup),
				.rxpipeclk(w_pcs8g_rx_rxpipeclk),
				.rxpipesoftreset(w_pcs8g_rx_rxpipesoftreset),
				.rxstatus(w_pcs8g_rx_rxstatus),
				.rxvalid(w_pcs8g_rx_rxvalid),
				.rxweoutchnldown(w_pcs8g_rx_rxweoutchnldown),
				.rxweoutchnlup(w_pcs8g_rx_rxweoutchnlup),
				.signaldetectout(w_pcs8g_rx_signaldetectout),
				.speedchange(w_pcs8g_rx_speedchange),
				.speedchangeinchnldownpipe(w_pcs8g_rx_speedchangeinchnldownpipe),
				.speedchangeinchnluppipe(w_pcs8g_rx_speedchangeinchnluppipe),
				.speedchangeoutchnldown(w_pcs8g_rx_speedchangeoutchnldown),
				.speedchangeoutchnlup(w_pcs8g_rx_speedchangeoutchnlup),
				.syncstatus(w_pcs8g_rx_syncstatus),
				.wordalignboundary(w_pcs8g_rx_wordalignboundary),
				.wrenableoutchnldown(w_pcs8g_rx_wrenableoutchnldown),
				.wrenableoutchnlup(w_pcs8g_rx_wrenableoutchnlup),
				// INPUTS
				.a1a2size(w_rx_pld_pcs_if_pcs8ga1a2size),
				.aggtestbus({w_com_pcs_pma_if_pcsaggtestbus[15], w_com_pcs_pma_if_pcsaggtestbus[14], w_com_pcs_pma_if_pcsaggtestbus[13], w_com_pcs_pma_if_pcsaggtestbus[12], w_com_pcs_pma_if_pcsaggtestbus[11], w_com_pcs_pma_if_pcsaggtestbus[10], w_com_pcs_pma_if_pcsaggtestbus[9], w_com_pcs_pma_if_pcsaggtestbus[8], w_com_pcs_pma_if_pcsaggtestbus[7], w_com_pcs_pma_if_pcsaggtestbus[6], w_com_pcs_pma_if_pcsaggtestbus[5], w_com_pcs_pma_if_pcsaggtestbus[4], w_com_pcs_pma_if_pcsaggtestbus[3], w_com_pcs_pma_if_pcsaggtestbus[2], w_com_pcs_pma_if_pcsaggtestbus[1], w_com_pcs_pma_if_pcsaggtestbus[0]}),
				.alignstatus(w_com_pcs_pma_if_pcsaggalignstatus),
				.alignstatussync0(w_com_pcs_pma_if_pcsaggalignstatussync0),
				.alignstatussync0toporbot(w_com_pcs_pma_if_pcsaggalignstatussync0toporbot),
				.alignstatustoporbot(w_com_pcs_pma_if_pcsaggalignstatustoporbot),
				.avmmaddress({in_avmmaddress[10], in_avmmaddress[9], in_avmmaddress[8], in_avmmaddress[7], in_avmmaddress[6], in_avmmaddress[5], in_avmmaddress[4], in_avmmaddress[3], in_avmmaddress[2], in_avmmaddress[1], in_avmmaddress[0]}),
				.avmmbyteen({in_avmmbyteen[1], in_avmmbyteen[0]}),
				.avmmclk(in_avmmclk),
				.avmmread(in_avmmread),
				.avmmrstn(in_avmmrstn),
				.avmmwrite(in_avmmwrite),
				.avmmwritedata({in_avmmwritedata[15], in_avmmwritedata[14], in_avmmwritedata[13], in_avmmwritedata[12], in_avmmwritedata[11], in_avmmwritedata[10], in_avmmwritedata[9], in_avmmwritedata[8], in_avmmwritedata[7], in_avmmwritedata[6], in_avmmwritedata[5], in_avmmwritedata[4], in_avmmwritedata[3], in_avmmwritedata[2], in_avmmwritedata[1], in_avmmwritedata[0]}),
				.bitreversalenable(w_rx_pld_pcs_if_pcs8gbitlocreven),
				.bitslip(w_rx_pld_pcs_if_pcs8gbitslip),
				.byteorder(w_rx_pld_pcs_if_pcs8gbytordpld),
				.bytereversalenable(w_rx_pld_pcs_if_pcs8gbytereven),
				.cgcomprddall(w_com_pcs_pma_if_pcsaggcgcomprddall),
				.cgcomprddalltoporbot(w_com_pcs_pma_if_pcsaggcgcomprddalltoporbot),
				.cgcompwrall(w_com_pcs_pma_if_pcsaggcgcompwrall),
				.cgcompwralltoporbot(w_com_pcs_pma_if_pcsaggcgcompwralltoporbot),
				.configselinchnldown(in_config_sel_in_chnl_down),
				.configselinchnlup(in_config_sel_in_chnl_up),
				.ctrlfromaggblock(w_com_pcs_pma_if_pcsaggrxcontrolrs),
				.datafrinaggblock({w_com_pcs_pma_if_pcsaggrxdatars[7], w_com_pcs_pma_if_pcsaggrxdatars[6], w_com_pcs_pma_if_pcsaggrxdatars[5], w_com_pcs_pma_if_pcsaggrxdatars[4], w_com_pcs_pma_if_pcsaggrxdatars[3], w_com_pcs_pma_if_pcsaggrxdatars[2], w_com_pcs_pma_if_pcsaggrxdatars[1], w_com_pcs_pma_if_pcsaggrxdatars[0]}),
				.datain({w_rx_pcs_pma_if_dataoutto8gpcs[19], w_rx_pcs_pma_if_dataoutto8gpcs[18], w_rx_pcs_pma_if_dataoutto8gpcs[17], w_rx_pcs_pma_if_dataoutto8gpcs[16], w_rx_pcs_pma_if_dataoutto8gpcs[15], w_rx_pcs_pma_if_dataoutto8gpcs[14], w_rx_pcs_pma_if_dataoutto8gpcs[13], w_rx_pcs_pma_if_dataoutto8gpcs[12], w_rx_pcs_pma_if_dataoutto8gpcs[11], w_rx_pcs_pma_if_dataoutto8gpcs[10], w_rx_pcs_pma_if_dataoutto8gpcs[9], w_rx_pcs_pma_if_dataoutto8gpcs[8], w_rx_pcs_pma_if_dataoutto8gpcs[7], w_rx_pcs_pma_if_dataoutto8gpcs[6], w_rx_pcs_pma_if_dataoutto8gpcs[5], w_rx_pcs_pma_if_dataoutto8gpcs[4], w_rx_pcs_pma_if_dataoutto8gpcs[3], w_rx_pcs_pma_if_dataoutto8gpcs[2], w_rx_pcs_pma_if_dataoutto8gpcs[1], w_rx_pcs_pma_if_dataoutto8gpcs[0]}),
				.delcondmet0(w_com_pcs_pma_if_pcsaggdelcondmet0),
				.delcondmet0toporbot(w_com_pcs_pma_if_pcsaggdelcondmet0toporbot),
				.dynclkswitchn(w_pcs8g_tx_dynclkswitchn),
				.eidleinfersel({w_pcs8g_tx_grayelecidleinferselout[2], w_pcs8g_tx_grayelecidleinferselout[1], w_pcs8g_tx_grayelecidleinferselout[0]}),
				.enablecommadetect(w_rx_pld_pcs_if_pcs8gencdt),
				.endskwqd(w_com_pcs_pma_if_pcsaggendskwqd),
				.endskwqdtoporbot(w_com_pcs_pma_if_pcsaggendskwqdtoporbot),
				.endskwrdptrs(w_com_pcs_pma_if_pcsaggendskwrdptrs),
				.endskwrdptrstoporbot(w_com_pcs_pma_if_pcsaggendskwrdptrstoporbot),
				.fifoovr0(w_com_pcs_pma_if_pcsaggfifoovr0),
				.fifoovr0toporbot(w_com_pcs_pma_if_pcsaggfifoovr0toporbot),
				.fifordincomp0toporbot(w_com_pcs_pma_if_pcsaggfifordincomp0toporbot),
				.fiforstrdqd(w_com_pcs_pma_if_pcsaggfiforstrdqd),
				.fiforstrdqdtoporbot(w_com_pcs_pma_if_pcsaggfiforstrdqdtoporbot),
				.gen2ngen1(w_com_pcs_pma_if_pcs8ggen2ngen1),
				.hrdrst(w_com_pld_pcs_if_pcs8ghardreset),
				.insertincomplete0(w_com_pcs_pma_if_pcsagginsertincomplete0),
				.insertincomplete0toporbot(w_com_pcs_pma_if_pcsagginsertincomplete0toporbot),
				.latencycomp0(w_com_pcs_pma_if_pcsagglatencycomp0),
				.latencycomp0toporbot(w_com_pcs_pma_if_pcsagglatencycomp0toporbot),
				.parallelloopback({w_pcs8g_tx_parallelfdbkout[19], w_pcs8g_tx_parallelfdbkout[18], w_pcs8g_tx_parallelfdbkout[17], w_pcs8g_tx_parallelfdbkout[16], w_pcs8g_tx_parallelfdbkout[15], w_pcs8g_tx_parallelfdbkout[14], w_pcs8g_tx_parallelfdbkout[13], w_pcs8g_tx_parallelfdbkout[12], w_pcs8g_tx_parallelfdbkout[11], w_pcs8g_tx_parallelfdbkout[10], w_pcs8g_tx_parallelfdbkout[9], w_pcs8g_tx_parallelfdbkout[8], w_pcs8g_tx_parallelfdbkout[7], w_pcs8g_tx_parallelfdbkout[6], w_pcs8g_tx_parallelfdbkout[5], w_pcs8g_tx_parallelfdbkout[4], w_pcs8g_tx_parallelfdbkout[3], w_pcs8g_tx_parallelfdbkout[2], w_pcs8g_tx_parallelfdbkout[1], w_pcs8g_tx_parallelfdbkout[0]}),
				.pcfifordenable(w_rx_pld_pcs_if_pcs8grdenablerx),
				.phfifouserrst(w_rx_pld_pcs_if_pcs8gphfifourstrx),
				.phystatusinternal(w_pipe12_phystatus),
				.pipeloopbk(w_pipe12_revloopbk),
				.pldltr(w_com_pld_pcs_if_pcs8gltr),
				.pldrxclk(w_rx_pld_pcs_if_pcs8gpldrxclk),
				.polinvrx(w_pipe12_polinvrxint),
				.prbscidenable(w_com_pld_pcs_if_pcs8gprbsciden),
				.pxfifowrdisable(w_rx_pld_pcs_if_pcs8gwrdisablerx),
				.rateswitchcontrol(w_com_pld_pcs_if_pcs8grate),
				.rcvdclkagg(w_com_pcs_pma_if_pcsaggrcvdclkagg),
				.rcvdclkaggtoporbot(w_com_pcs_pma_if_pcsaggrcvdclkaggtoporbot),
				.rcvdclkpma(w_rx_pcs_pma_if_clockoutto8gpcs),
				.rdenableinchnldown(in_rx_rd_enable_in_chnl_down),
				.rdenableinchnlup(in_rx_rd_enable_in_chnl_up),
				.refclkdig(w_com_pld_pcs_if_pcs8grefclkdig),
				.refclkdig2(w_com_pld_pcs_if_pcs8grefclkdig2),
				.resetpcptrsinchnldown(in_reset_pc_ptrs_in_chnl_down),
				.resetpcptrsinchnlup(in_reset_pc_ptrs_in_chnl_up),
				.resetppmcntrsinchnldown(in_reset_ppm_cntrs_in_chnl_down),
				.resetppmcntrsinchnlup(in_reset_ppm_cntrs_in_chnl_up),
				.rmfifordincomp0(w_com_pcs_pma_if_pcsaggfifordincomp0),
				.rmfifouserrst(w_rx_pld_pcs_if_pcs8gcmpfifourst),
				.rxcontrolrstoporbot(w_com_pcs_pma_if_pcsaggrxcontrolrstoporbot),
				.rxdatarstoporbot({w_com_pcs_pma_if_pcsaggrxdatarstoporbot[7], w_com_pcs_pma_if_pcsaggrxdatarstoporbot[6], w_com_pcs_pma_if_pcsaggrxdatarstoporbot[5], w_com_pcs_pma_if_pcsaggrxdatarstoporbot[4], w_com_pcs_pma_if_pcsaggrxdatarstoporbot[3], w_com_pcs_pma_if_pcsaggrxdatarstoporbot[2], w_com_pcs_pma_if_pcsaggrxdatarstoporbot[1], w_com_pcs_pma_if_pcsaggrxdatarstoporbot[0]}),
				.rxdivsyncinchnldown({in_rx_div_sync_in_chnl_down[1], in_rx_div_sync_in_chnl_down[0]}),
				.rxdivsyncinchnlup({in_rx_div_sync_in_chnl_up[1], in_rx_div_sync_in_chnl_up[0]}),
				.rxpcsrst(w_rx_pld_pcs_if_pcs8grxurstpcs),
				.rxstatusinternal({w_pipe12_rxstatus[2], w_pipe12_rxstatus[1], w_pipe12_rxstatus[0]}),
				.rxvalidinternal(w_pipe12_rxvalid),
				.rxweinchnldown({in_rx_we_in_chnl_down[1], in_rx_we_in_chnl_down[0]}),
				.rxweinchnlup({in_rx_we_in_chnl_up[1], in_rx_we_in_chnl_up[0]}),
				.scanmode(w_com_pld_pcs_if_pcs8gscanmoden),
				.sigdetfrompma(w_rx_pcs_pma_if_pcs8gsigdetni),
				.speedchangeinchnldown(in_speed_change_in_chnl_down),
				.speedchangeinchnlup(in_speed_change_in_chnl_up),
				.syncsmen(w_rx_pld_pcs_if_pcs8gsyncsmenoutput),
				.txctrlplanetestbus({w_pcs8g_tx_txctrlplanetestbus[19], w_pcs8g_tx_txctrlplanetestbus[18], w_pcs8g_tx_txctrlplanetestbus[17], w_pcs8g_tx_txctrlplanetestbus[16], w_pcs8g_tx_txctrlplanetestbus[15], w_pcs8g_tx_txctrlplanetestbus[14], w_pcs8g_tx_txctrlplanetestbus[13], w_pcs8g_tx_txctrlplanetestbus[12], w_pcs8g_tx_txctrlplanetestbus[11], w_pcs8g_tx_txctrlplanetestbus[10], w_pcs8g_tx_txctrlplanetestbus[9], w_pcs8g_tx_txctrlplanetestbus[8], w_pcs8g_tx_txctrlplanetestbus[7], w_pcs8g_tx_txctrlplanetestbus[6], w_pcs8g_tx_txctrlplanetestbus[5], w_pcs8g_tx_txctrlplanetestbus[4], w_pcs8g_tx_txctrlplanetestbus[3], w_pcs8g_tx_txctrlplanetestbus[2], w_pcs8g_tx_txctrlplanetestbus[1], w_pcs8g_tx_txctrlplanetestbus[0]}),
				.txdivsync({w_pcs8g_tx_txdivsync[1], w_pcs8g_tx_txdivsync[0]}),
				.txpmaclk(w_tx_pcs_pma_if_clockoutto8gpcs),
				.txtestbus({w_pcs8g_tx_txtestbus[19], w_pcs8g_tx_txtestbus[18], w_pcs8g_tx_txtestbus[17], w_pcs8g_tx_txtestbus[16], w_pcs8g_tx_txtestbus[15], w_pcs8g_tx_txtestbus[14], w_pcs8g_tx_txtestbus[13], w_pcs8g_tx_txtestbus[12], w_pcs8g_tx_txtestbus[11], w_pcs8g_tx_txtestbus[10], w_pcs8g_tx_txtestbus[9], w_pcs8g_tx_txtestbus[8], w_pcs8g_tx_txtestbus[7], w_pcs8g_tx_txtestbus[6], w_pcs8g_tx_txtestbus[5], w_pcs8g_tx_txtestbus[4], w_pcs8g_tx_txtestbus[3], w_pcs8g_tx_txtestbus[2], w_pcs8g_tx_txtestbus[1], w_pcs8g_tx_txtestbus[0]}),
				.wrenableinchnldown(in_rx_wr_enable_in_chnl_down),
				.wrenableinchnlup(in_rx_wr_enable_in_chnl_up)
			);
		end // if generate
		else begin
				assign w_pcs8g_rx_a1a2k1k2flag[3:0] = 4'b0;
				assign w_pcs8g_rx_aggrxpcsrst = 1'b0;
				assign w_pcs8g_rx_aligndetsync[1:0] = 2'b0;
				assign w_pcs8g_rx_alignstatuspld = 1'b0;
				assign w_pcs8g_rx_alignstatussync = 1'b0;
				assign w_pcs8g_rx_avmmreaddata[15:0] = 16'b0;
				assign w_pcs8g_rx_bistdone = 1'b0;
				assign w_pcs8g_rx_bisterr = 1'b0;
				assign w_pcs8g_rx_blockselect = 1'b0;
				assign w_pcs8g_rx_byteordflag = 1'b0;
				assign w_pcs8g_rx_cgcomprddout[1:0] = 2'b0;
				assign w_pcs8g_rx_cgcompwrout[1:0] = 2'b0;
				assign w_pcs8g_rx_channeltestbusout[19:0] = 20'b0;
				assign w_pcs8g_rx_clocktopld = 1'b0;
				assign w_pcs8g_rx_configseloutchnldown = 1'b0;
				assign w_pcs8g_rx_configseloutchnlup = 1'b0;
				assign w_pcs8g_rx_dataout[63:0] = 64'b0;
				assign w_pcs8g_rx_decoderctrl = 1'b0;
				assign w_pcs8g_rx_decoderdata[7:0] = 8'b0;
				assign w_pcs8g_rx_decoderdatavalid = 1'b0;
				assign w_pcs8g_rx_delcondmetout = 1'b0;
				assign w_pcs8g_rx_disablepcfifobyteserdes = 1'b0;
				assign w_pcs8g_rx_earlyeios = 1'b0;
				assign w_pcs8g_rx_eidledetected = 1'b0;
				assign w_pcs8g_rx_eidleexit = 1'b0;
				assign w_pcs8g_rx_fifoovrout = 1'b0;
				assign w_pcs8g_rx_fifordoutcomp = 1'b0;
				assign w_pcs8g_rx_insertincompleteout = 1'b0;
				assign w_pcs8g_rx_latencycompout = 1'b0;
				assign w_pcs8g_rx_ltr = w_com_pld_pcs_if_pcs8gltr;// connected when av_hssi_8g_rx_pcs is not instantiated
				assign w_pcs8g_rx_parallelrevloopback[19:0] = 20'b0;
				assign w_pcs8g_rx_pcfifoempty = 1'b0;
				assign w_pcs8g_rx_pcfifofull = 1'b0;
				assign w_pcs8g_rx_pcieswitch = 1'b0;
				assign w_pcs8g_rx_phystatus = 1'b0;
				assign w_pcs8g_rx_pipedata[63:0] = 64'b0;
				assign w_pcs8g_rx_rdalign[1:0] = 2'b0;
				assign w_pcs8g_rx_rdenableoutchnldown = 1'b0;
				assign w_pcs8g_rx_rdenableoutchnlup = 1'b0;
				assign w_pcs8g_rx_resetpcptrs = 1'b0;
				assign w_pcs8g_rx_resetpcptrsinchnldownpipe = 1'b0;
				assign w_pcs8g_rx_resetpcptrsinchnluppipe = 1'b0;
				assign w_pcs8g_rx_resetpcptrsoutchnldown = 1'b0;
				assign w_pcs8g_rx_resetpcptrsoutchnlup = 1'b0;
				assign w_pcs8g_rx_resetppmcntrsoutchnldown = 1'b0;
				assign w_pcs8g_rx_resetppmcntrsoutchnlup = 1'b0;
				assign w_pcs8g_rx_resetppmcntrspcspma = 1'b0;
				assign w_pcs8g_rx_rlvlt = 1'b0;
				assign w_pcs8g_rx_rmfifoempty = 1'b0;
				assign w_pcs8g_rx_rmfifofull = 1'b0;
				assign w_pcs8g_rx_runningdisparity[1:0] = 2'b0;
				assign w_pcs8g_rx_rxclkslip = 1'b0;
				assign w_pcs8g_rx_rxdatavalid[3:0] = 4'b0;
				assign w_pcs8g_rx_rxdivsyncoutchnldown[1:0] = 2'b0;
				assign w_pcs8g_rx_rxdivsyncoutchnlup[1:0] = 2'b0;
				assign w_pcs8g_rx_rxpipeclk = 1'b0;
				assign w_pcs8g_rx_rxpipesoftreset = 1'b0;
				assign w_pcs8g_rx_rxstatus[2:0] = 3'b0;
				assign w_pcs8g_rx_rxvalid = 1'b0;
				assign w_pcs8g_rx_rxweoutchnldown[1:0] = 2'b0;
				assign w_pcs8g_rx_rxweoutchnlup[1:0] = 2'b0;
				assign w_pcs8g_rx_signaldetectout = 1'b0;
				assign w_pcs8g_rx_speedchange = 1'b0;
				assign w_pcs8g_rx_speedchangeinchnldownpipe = 1'b0;
				assign w_pcs8g_rx_speedchangeinchnluppipe = 1'b0;
				assign w_pcs8g_rx_speedchangeoutchnldown = 1'b0;
				assign w_pcs8g_rx_speedchangeoutchnlup = 1'b0;
				assign w_pcs8g_rx_syncstatus = 1'b0;
				assign w_pcs8g_rx_wordalignboundary[4:0] = 5'b0;
				assign w_pcs8g_rx_wrenableoutchnldown = 1'b0;
				assign w_pcs8g_rx_wrenableoutchnlup = 1'b0;
		end // if not generate
		
		// instantiating av_hssi_tx_pcs_pma_interface
		if ((enable_8g_tx == "true") || (enable_dyn_reconfig == "true")) begin
			av_hssi_tx_pcs_pma_interface_rbc #(
				.selectpcs(tx_pcs_pma_if_selectpcs),
				.use_default_base_address(tx_pcs_pma_if_use_default_base_address),
				.user_base_address(tx_pcs_pma_if_user_base_address)
			) inst_av_hssi_tx_pcs_pma_interface (
				// OUTPUTS
				.avmmreaddata(w_tx_pcs_pma_if_avmmreaddata),
				.blockselect(w_tx_pcs_pma_if_blockselect),
				.clockoutto8gpcs(w_tx_pcs_pma_if_clockoutto8gpcs),
				.dataouttopma(w_tx_pcs_pma_if_dataouttopma),
				.pmarxfreqtxcmuplllockout(w_tx_pcs_pma_if_pmarxfreqtxcmuplllockout),
				.pmatxclkout(w_tx_pcs_pma_if_pmatxclkout),
				// INPUTS
				.avmmaddress({in_avmmaddress[10], in_avmmaddress[9], in_avmmaddress[8], in_avmmaddress[7], in_avmmaddress[6], in_avmmaddress[5], in_avmmaddress[4], in_avmmaddress[3], in_avmmaddress[2], in_avmmaddress[1], in_avmmaddress[0]}),
				.avmmbyteen({in_avmmbyteen[1], in_avmmbyteen[0]}),
				.avmmclk(in_avmmclk),
				.avmmread(in_avmmread),
				.avmmrstn(in_avmmrstn),
				.avmmwrite(in_avmmwrite),
				.avmmwritedata({in_avmmwritedata[15], in_avmmwritedata[14], in_avmmwritedata[13], in_avmmwritedata[12], in_avmmwritedata[11], in_avmmwritedata[10], in_avmmwritedata[9], in_avmmwritedata[8], in_avmmwritedata[7], in_avmmwritedata[6], in_avmmwritedata[5], in_avmmwritedata[4], in_avmmwritedata[3], in_avmmwritedata[2], in_avmmwritedata[1], in_avmmwritedata[0]}),
				.clockinfrompma(in_pma_tx_pma_clk),
				.datainfrom8gpcs({w_pcs8g_tx_dataout[19], w_pcs8g_tx_dataout[18], w_pcs8g_tx_dataout[17], w_pcs8g_tx_dataout[16], w_pcs8g_tx_dataout[15], w_pcs8g_tx_dataout[14], w_pcs8g_tx_dataout[13], w_pcs8g_tx_dataout[12], w_pcs8g_tx_dataout[11], w_pcs8g_tx_dataout[10], w_pcs8g_tx_dataout[9], w_pcs8g_tx_dataout[8], w_pcs8g_tx_dataout[7], w_pcs8g_tx_dataout[6], w_pcs8g_tx_dataout[5], w_pcs8g_tx_dataout[4], w_pcs8g_tx_dataout[3], w_pcs8g_tx_dataout[2], w_pcs8g_tx_dataout[1], w_pcs8g_tx_dataout[0]}),
				.pcs8gtxclkiqout(w_pcs8g_tx_clkout),
				.pmarxfreqtxcmuplllockin(in_pma_rx_freq_tx_cmu_pll_lock_in)
			);
		end // if generate
		else begin
				assign w_tx_pcs_pma_if_avmmreaddata[15:0] = 16'b0;
				assign w_tx_pcs_pma_if_blockselect = 1'b0;
				assign w_tx_pcs_pma_if_clockoutto8gpcs = 1'b0;
				assign w_tx_pcs_pma_if_dataouttopma[79:0] = 80'b0;
				assign w_tx_pcs_pma_if_pmarxfreqtxcmuplllockout = 1'b0;
				assign w_tx_pcs_pma_if_pmatxclkout = 1'b0;
		end // if not generate
		
		// instantiating av_hssi_rx_pcs_pma_interface
		if ((enable_8g_rx == "true") || (enable_pma_direct_rx == "true") || (enable_dyn_reconfig == "true")) begin
			av_hssi_rx_pcs_pma_interface_rbc #(
				.clkslip_sel(rx_pcs_pma_if_clkslip_sel),
				.prot_mode(rx_pcs_pma_if_prot_mode),
				.selectpcs(rx_pcs_pma_if_selectpcs),
				.use_default_base_address(rx_pcs_pma_if_use_default_base_address),
				.user_base_address(rx_pcs_pma_if_user_base_address)
			) inst_av_hssi_rx_pcs_pma_interface (
				// OUTPUTS
				.avmmreaddata(w_rx_pcs_pma_if_avmmreaddata),
				.blockselect(w_rx_pcs_pma_if_blockselect),
				.clockoutto8gpcs(w_rx_pcs_pma_if_clockoutto8gpcs),
				.dataoutto8gpcs(w_rx_pcs_pma_if_dataoutto8gpcs),
				.pcs8gsigdetni(w_rx_pcs_pma_if_pcs8gsigdetni),
				.pmareservedout(w_rx_pcs_pma_if_pmareservedout),
				.pmarxclkout(w_rx_pcs_pma_if_pmarxclkout),
				.pmarxclkslip(w_rx_pcs_pma_if_pmarxclkslip),
				.pmarxpllphaselockout(w_rx_pcs_pma_if_pmarxpllphaselockout),
				.pmarxpmarstb(w_rx_pcs_pma_if_pmarxpmarstb),
				// INPUTS
				.avmmaddress({in_avmmaddress[10], in_avmmaddress[9], in_avmmaddress[8], in_avmmaddress[7], in_avmmaddress[6], in_avmmaddress[5], in_avmmaddress[4], in_avmmaddress[3], in_avmmaddress[2], in_avmmaddress[1], in_avmmaddress[0]}),
				.avmmbyteen({in_avmmbyteen[1], in_avmmbyteen[0]}),
				.avmmclk(in_avmmclk),
				.avmmread(in_avmmread),
				.avmmrstn(in_avmmrstn),
				.avmmwrite(in_avmmwrite),
				.avmmwritedata({in_avmmwritedata[15], in_avmmwritedata[14], in_avmmwritedata[13], in_avmmwritedata[12], in_avmmwritedata[11], in_avmmwritedata[10], in_avmmwritedata[9], in_avmmwritedata[8], in_avmmwritedata[7], in_avmmwritedata[6], in_avmmwritedata[5], in_avmmwritedata[4], in_avmmwritedata[3], in_avmmwritedata[2], in_avmmwritedata[1], in_avmmwritedata[0]}),
				.clockinfrompma(in_pma_rx_pma_clk),
				.datainfrompma({1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, 1'b0, in_pma_rx_data[19], in_pma_rx_data[18], in_pma_rx_data[17], in_pma_rx_data[16], in_pma_rx_data[15], in_pma_rx_data[14], in_pma_rx_data[13], in_pma_rx_data[12], in_pma_rx_data[11], in_pma_rx_data[10], in_pma_rx_data[9], in_pma_rx_data[8], in_pma_rx_data[7], in_pma_rx_data[6], in_pma_rx_data[5], in_pma_rx_data[4], in_pma_rx_data[3], in_pma_rx_data[2], in_pma_rx_data[1], in_pma_rx_data[0]}),
				.pcs8grxclkiqout(w_pcs8g_rx_clocktopld),
				.pcs8grxclkslip(w_pcs8g_rx_rxclkslip),
				.pldrxclkslip(w_rx_pld_pcs_if_pldrxclkslipout),
				.pldrxpmarstb(w_rx_pld_pcs_if_pldrxpmarstbout),
				.pmareservedin({in_pma_reserved_in[4], in_pma_reserved_in[3], in_pma_reserved_in[2], in_pma_reserved_in[1], in_pma_reserved_in[0]}),
				.pmarxpllphaselockin(in_pma_rx_pll_phase_lock_in),
				.pmasigdet(in_pma_sigdet)
			);
		end // if generate
		else begin
				assign w_rx_pcs_pma_if_avmmreaddata[15:0] = 16'b0;
				assign w_rx_pcs_pma_if_blockselect = 1'b0;
				assign w_rx_pcs_pma_if_clockoutto8gpcs = 1'b0;
				assign w_rx_pcs_pma_if_dataoutto8gpcs[19:0] = 20'b0;
				assign w_rx_pcs_pma_if_pcs8gsigdetni = 1'b0;
				assign w_rx_pcs_pma_if_pmareservedout[4:0] = 5'b0;
				assign w_rx_pcs_pma_if_pmarxclkout = 1'b0;
				assign w_rx_pcs_pma_if_pmarxclkslip = 1'b0;
				assign w_rx_pcs_pma_if_pmarxpllphaselockout = 1'b0;
				assign w_rx_pcs_pma_if_pmarxpmarstb = 1'b0;
		end // if not generate
		
		// instantiating av_hssi_8g_tx_pcs
		if ((enable_8g_tx == "true") || (enable_dyn_reconfig == "true")) begin
			av_hssi_8g_tx_pcs_rbc #(
				.agg_block_sel(pcs8g_tx_agg_block_sel),
				.auto_speed_nego_gen2(pcs8g_tx_auto_speed_nego_gen2),
				.bist_gen(pcs8g_tx_bist_gen),
				.bit_reversal(pcs8g_tx_bit_reversal),
				.bypass_pipeline_reg(pcs8g_tx_bypass_pipeline_reg),
				.byte_serializer(pcs8g_tx_byte_serializer),
				.channel_number(channel_number),
				.cid_pattern(pcs8g_tx_cid_pattern),
				.cid_pattern_len(pcs8g_tx_cid_pattern_len),
				.clock_gate_bist(pcs8g_tx_clock_gate_bist),
				.clock_gate_bs_enc(pcs8g_tx_clock_gate_bs_enc),
				.clock_gate_dw_fifowr(pcs8g_tx_clock_gate_dw_fifowr),
				.clock_gate_fiford(pcs8g_tx_clock_gate_fiford),
				.clock_gate_prbs(pcs8g_tx_clock_gate_prbs),
				.clock_gate_sw_fifowr(pcs8g_tx_clock_gate_sw_fifowr),
				.ctrl_plane_bonding_compensation(pcs8g_tx_ctrl_plane_bonding_compensation),
				.ctrl_plane_bonding_consumption(pcs8g_tx_ctrl_plane_bonding_consumption),
				.ctrl_plane_bonding_distribution(pcs8g_tx_ctrl_plane_bonding_distribution),
				.data_selection_8b10b_encoder_input(pcs8g_tx_data_selection_8b10b_encoder_input),
				.dynamic_clk_switch(pcs8g_tx_dynamic_clk_switch),
				.eightb_tenb_disp_ctrl(pcs8g_tx_eightb_tenb_disp_ctrl),
				.eightb_tenb_encoder(pcs8g_tx_eightb_tenb_encoder),
				.force_echar(pcs8g_tx_force_echar),
				.force_kchar(pcs8g_tx_force_kchar),
				.hip_mode(pcs8g_tx_hip_mode),
				.pcfifo_urst(pcs8g_tx_pcfifo_urst),
				.pcs_bypass(pcs8g_tx_pcs_bypass),
				.phase_compensation_fifo(pcs8g_tx_phase_compensation_fifo),
				.phfifo_write_clk_sel(pcs8g_tx_phfifo_write_clk_sel),
				.pma_dw(pcs8g_tx_pma_dw),
				.polarity_inversion(pcs8g_tx_polarity_inversion),
				.prbs_gen(pcs8g_tx_prbs_gen),
				.prot_mode(pcs8g_tx_prot_mode),
				.refclk_b_clk_sel(pcs8g_tx_refclk_b_clk_sel),
				.revloop_back_rm(pcs8g_tx_revloop_back_rm),
				.sup_mode(pcs8g_tx_sup_mode),
				.symbol_swap(pcs8g_tx_symbol_swap),
				.test_mode(pcs8g_tx_test_mode),
				.tx_bitslip(pcs8g_tx_tx_bitslip),
				.tx_compliance_controlled_disparity(pcs8g_tx_tx_compliance_controlled_disparity),
				.txclk_freerun(pcs8g_tx_txclk_freerun),
				.txpcs_urst(pcs8g_tx_txpcs_urst),
				.use_default_base_address(pcs8g_tx_use_default_base_address),
				.user_base_address(pcs8g_tx_user_base_address)
			) inst_av_hssi_8g_tx_pcs (
				// OUTPUTS
				.aggtxpcsrst(w_pcs8g_tx_aggtxpcsrst),
				.avmmreaddata(w_pcs8g_tx_avmmreaddata),
				.blockselect(w_pcs8g_tx_blockselect),
				.clkout(w_pcs8g_tx_clkout),
				.dataout(w_pcs8g_tx_dataout),
				.detectrxloopout(w_pcs8g_tx_detectrxloopout),
				.dynclkswitchn(w_pcs8g_tx_dynclkswitchn),
				.fifoselectoutchnldown(w_pcs8g_tx_fifoselectoutchnldown),
				.fifoselectoutchnlup(w_pcs8g_tx_fifoselectoutchnlup),
				.grayelecidleinferselout(w_pcs8g_tx_grayelecidleinferselout),
				.parallelfdbkout(w_pcs8g_tx_parallelfdbkout),
				.phfifooverflow(w_pcs8g_tx_phfifooverflow),
				.phfifotxdeemph(w_pcs8g_tx_phfifotxdeemph),
				.phfifotxmargin(w_pcs8g_tx_phfifotxmargin),
				.phfifotxswing(w_pcs8g_tx_phfifotxswing),
				.phfifounderflow(w_pcs8g_tx_phfifounderflow),
				.pipeenrevparallellpbkout(w_pcs8g_tx_pipeenrevparallellpbkout),
				.pipepowerdownout(w_pcs8g_tx_pipepowerdownout),
				.polinvrxout(w_pcs8g_tx_polinvrxout),
				.rdenableoutchnldown(w_pcs8g_tx_rdenableoutchnldown),
				.rdenableoutchnlup(w_pcs8g_tx_rdenableoutchnlup),
				.rdenablesync(w_pcs8g_tx_rdenablesync),
				.refclkb(w_pcs8g_tx_refclkb),
				.refclkbreset(w_pcs8g_tx_refclkbreset),
				.rxpolarityout(w_pcs8g_tx_rxpolarityout),
				.txctrlplanetestbus(w_pcs8g_tx_txctrlplanetestbus),
				.txdivsync(w_pcs8g_tx_txdivsync),
				.txdivsyncoutchnldown(w_pcs8g_tx_txdivsyncoutchnldown),
				.txdivsyncoutchnlup(w_pcs8g_tx_txdivsyncoutchnlup),
				.txpipeclk(w_pcs8g_tx_txpipeclk),
				.txpipeelectidle(w_pcs8g_tx_txpipeelectidle),
				.txpipesoftreset(w_pcs8g_tx_txpipesoftreset),
				.txtestbus(w_pcs8g_tx_txtestbus),
				.wrenableoutchnldown(w_pcs8g_tx_wrenableoutchnldown),
				.wrenableoutchnlup(w_pcs8g_tx_wrenableoutchnlup),
				.xgmctrlenable(w_pcs8g_tx_xgmctrlenable),
				.xgmdataout(w_pcs8g_tx_xgmdataout),
				// INPUTS
				.avmmaddress({in_avmmaddress[10], in_avmmaddress[9], in_avmmaddress[8], in_avmmaddress[7], in_avmmaddress[6], in_avmmaddress[5], in_avmmaddress[4], in_avmmaddress[3], in_avmmaddress[2], in_avmmaddress[1], in_avmmaddress[0]}),
				.avmmbyteen({in_avmmbyteen[1], in_avmmbyteen[0]}),
				.avmmclk(in_avmmclk),
				.avmmread(in_avmmread),
				.avmmrstn(in_avmmrstn),
				.avmmwrite(in_avmmwrite),
				.avmmwritedata({in_avmmwritedata[15], in_avmmwritedata[14], in_avmmwritedata[13], in_avmmwritedata[12], in_avmmwritedata[11], in_avmmwritedata[10], in_avmmwritedata[9], in_avmmwritedata[8], in_avmmwritedata[7], in_avmmwritedata[6], in_avmmwritedata[5], in_avmmwritedata[4], in_avmmwritedata[3], in_avmmwritedata[2], in_avmmwritedata[1], in_avmmwritedata[0]}),
				.bitslipboundaryselect({w_tx_pld_pcs_if_pcs8gtxboundarysel[4], w_tx_pld_pcs_if_pcs8gtxboundarysel[3], w_tx_pld_pcs_if_pcs8gtxboundarysel[2], w_tx_pld_pcs_if_pcs8gtxboundarysel[1], w_tx_pld_pcs_if_pcs8gtxboundarysel[0]}),
				.coreclk(w_tx_pld_pcs_if_pcs8gpldtxclk),
				.datain({w_tx_pld_pcs_if_dataoutto8gpcs[43], w_tx_pld_pcs_if_dataoutto8gpcs[42], w_tx_pld_pcs_if_dataoutto8gpcs[41], w_tx_pld_pcs_if_dataoutto8gpcs[40], w_tx_pld_pcs_if_dataoutto8gpcs[39], w_tx_pld_pcs_if_dataoutto8gpcs[38], w_tx_pld_pcs_if_dataoutto8gpcs[37], w_tx_pld_pcs_if_dataoutto8gpcs[36], w_tx_pld_pcs_if_dataoutto8gpcs[35], w_tx_pld_pcs_if_dataoutto8gpcs[34], w_tx_pld_pcs_if_dataoutto8gpcs[33], w_tx_pld_pcs_if_dataoutto8gpcs[32], w_tx_pld_pcs_if_dataoutto8gpcs[31], w_tx_pld_pcs_if_dataoutto8gpcs[30], w_tx_pld_pcs_if_dataoutto8gpcs[29], w_tx_pld_pcs_if_dataoutto8gpcs[28], w_tx_pld_pcs_if_dataoutto8gpcs[27], w_tx_pld_pcs_if_dataoutto8gpcs[26], w_tx_pld_pcs_if_dataoutto8gpcs[25], w_tx_pld_pcs_if_dataoutto8gpcs[24], w_tx_pld_pcs_if_dataoutto8gpcs[23], w_tx_pld_pcs_if_dataoutto8gpcs[22], w_tx_pld_pcs_if_dataoutto8gpcs[21], w_tx_pld_pcs_if_dataoutto8gpcs[20], w_tx_pld_pcs_if_dataoutto8gpcs[19], w_tx_pld_pcs_if_dataoutto8gpcs[18], w_tx_pld_pcs_if_dataoutto8gpcs[17], w_tx_pld_pcs_if_dataoutto8gpcs[16], w_tx_pld_pcs_if_dataoutto8gpcs[15], w_tx_pld_pcs_if_dataoutto8gpcs[14], w_tx_pld_pcs_if_dataoutto8gpcs[13], w_tx_pld_pcs_if_dataoutto8gpcs[12], w_tx_pld_pcs_if_dataoutto8gpcs[11], w_tx_pld_pcs_if_dataoutto8gpcs[10], w_tx_pld_pcs_if_dataoutto8gpcs[9], w_tx_pld_pcs_if_dataoutto8gpcs[8], w_tx_pld_pcs_if_dataoutto8gpcs[7], w_tx_pld_pcs_if_dataoutto8gpcs[6], w_tx_pld_pcs_if_dataoutto8gpcs[5], w_tx_pld_pcs_if_dataoutto8gpcs[4], w_tx_pld_pcs_if_dataoutto8gpcs[3], w_tx_pld_pcs_if_dataoutto8gpcs[2], w_tx_pld_pcs_if_dataoutto8gpcs[1], w_tx_pld_pcs_if_dataoutto8gpcs[0]}),
				.detectrxloopin(w_com_pld_pcs_if_pcs8gtxdetectrxloopback),
				.dispcbyte(w_pcs8g_rx_disablepcfifobyteserdes),
				.elecidleinfersel({w_com_pld_pcs_if_pcs8geidleinfersel[2], w_com_pld_pcs_if_pcs8geidleinfersel[1], w_com_pld_pcs_if_pcs8geidleinfersel[0]}),
				.enrevparallellpbk(w_pipe12_revloopbk),
				.fifoselectinchnldown({in_fifo_select_in_chnl_down[1], in_fifo_select_in_chnl_down[0]}),
				.fifoselectinchnlup({in_fifo_select_in_chnl_up[1], in_fifo_select_in_chnl_up[0]}),
				.hrdrst(w_com_pld_pcs_if_pcs8ghardreset),
				.invpol(w_tx_pld_pcs_if_pcs8gpolinvtx),
				.phfiforddisable(w_tx_pld_pcs_if_pcs8grddisabletx),
				.phfiforeset(w_tx_pld_pcs_if_pcs8gphfifoursttx),
				.phfifowrenable(w_tx_pld_pcs_if_pcs8gwrenabletx),
				.pipeenrevparallellpbkin(w_tx_pld_pcs_if_pcs8grevloopbk),
				.pipetxdeemph(w_com_pld_pcs_if_pcs8gtxdeemph),
				.pipetxmargin({w_com_pld_pcs_if_pcs8gtxmargin[2], w_com_pld_pcs_if_pcs8gtxmargin[1], w_com_pld_pcs_if_pcs8gtxmargin[0]}),
				.pipetxswing(w_com_pld_pcs_if_pcs8gtxswing),
				.polinvrxin(w_rx_pld_pcs_if_pcs8gpolinvrx),
				.powerdn({w_com_pld_pcs_if_pcs8gpowerdown[1], w_com_pld_pcs_if_pcs8gpowerdown[0]}),
				.prbscidenable(w_com_pld_pcs_if_pcs8gprbsciden),
				.rateswitch(w_com_pcs_pma_if_pcs8ggen2ngen1),
				.rdenableinchnldown(in_tx_rd_enable_in_chnl_down),
				.rdenableinchnlup(in_tx_rd_enable_in_chnl_up),
				.refclkdig(w_com_pld_pcs_if_pcs8grefclkdig),
				.resetpcptrs(w_pcs8g_rx_resetpcptrs),
				.resetpcptrsinchnldown(w_pcs8g_rx_resetpcptrsinchnldownpipe),
				.resetpcptrsinchnlup(w_pcs8g_rx_resetpcptrsinchnluppipe),
				.revparallellpbkdata({w_pcs8g_rx_parallelrevloopback[19], w_pcs8g_rx_parallelrevloopback[18], w_pcs8g_rx_parallelrevloopback[17], w_pcs8g_rx_parallelrevloopback[16], w_pcs8g_rx_parallelrevloopback[15], w_pcs8g_rx_parallelrevloopback[14], w_pcs8g_rx_parallelrevloopback[13], w_pcs8g_rx_parallelrevloopback[12], w_pcs8g_rx_parallelrevloopback[11], w_pcs8g_rx_parallelrevloopback[10], w_pcs8g_rx_parallelrevloopback[9], w_pcs8g_rx_parallelrevloopback[8], w_pcs8g_rx_parallelrevloopback[7], w_pcs8g_rx_parallelrevloopback[6], w_pcs8g_rx_parallelrevloopback[5], w_pcs8g_rx_parallelrevloopback[4], w_pcs8g_rx_parallelrevloopback[3], w_pcs8g_rx_parallelrevloopback[2], w_pcs8g_rx_parallelrevloopback[1], w_pcs8g_rx_parallelrevloopback[0]}),
				.rxpolarityin(w_com_pld_pcs_if_pcs8grxpolarity),
				.scanmode(w_com_pld_pcs_if_pcs8gscanmoden),
				.txdatavalid({w_tx_pld_pcs_if_pcs8gtxdatavalid[3], w_tx_pld_pcs_if_pcs8gtxdatavalid[2], w_tx_pld_pcs_if_pcs8gtxdatavalid[1], w_tx_pld_pcs_if_pcs8gtxdatavalid[0]}),
				.txdivsyncinchnldown({in_tx_div_sync_in_chnl_down[1], in_tx_div_sync_in_chnl_down[0]}),
				.txdivsyncinchnlup({in_tx_div_sync_in_chnl_up[1], in_tx_div_sync_in_chnl_up[0]}),
				.txpcsreset(w_tx_pld_pcs_if_pcs8gtxurstpcs),
				.txpmalocalclk(w_tx_pcs_pma_if_clockoutto8gpcs),
				.wrenableinchnldown(in_tx_wr_enable_in_chnl_down),
				.wrenableinchnlup(in_tx_wr_enable_in_chnl_up),
				.xgmctrl(w_com_pcs_pma_if_pcsaggtxctlts),
				.xgmctrltoporbottom(w_com_pcs_pma_if_pcsaggtxctltstoporbot),
				.xgmdatain({w_com_pcs_pma_if_pcsaggtxdatats[7], w_com_pcs_pma_if_pcsaggtxdatats[6], w_com_pcs_pma_if_pcsaggtxdatats[5], w_com_pcs_pma_if_pcsaggtxdatats[4], w_com_pcs_pma_if_pcsaggtxdatats[3], w_com_pcs_pma_if_pcsaggtxdatats[2], w_com_pcs_pma_if_pcsaggtxdatats[1], w_com_pcs_pma_if_pcsaggtxdatats[0]}),
				.xgmdataintoporbottom({w_com_pcs_pma_if_pcsaggtxdatatstoporbot[7], w_com_pcs_pma_if_pcsaggtxdatatstoporbot[6], w_com_pcs_pma_if_pcsaggtxdatatstoporbot[5], w_com_pcs_pma_if_pcsaggtxdatatstoporbot[4], w_com_pcs_pma_if_pcsaggtxdatatstoporbot[3], w_com_pcs_pma_if_pcsaggtxdatatstoporbot[2], w_com_pcs_pma_if_pcsaggtxdatatstoporbot[1], w_com_pcs_pma_if_pcsaggtxdatatstoporbot[0]})
			);
		end // if generate
		else begin
				assign w_pcs8g_tx_aggtxpcsrst = 1'b0;
				assign w_pcs8g_tx_avmmreaddata[15:0] = 16'b0;
				assign w_pcs8g_tx_blockselect = 1'b0;
				assign w_pcs8g_tx_clkout = 1'b0;
				assign w_pcs8g_tx_dataout[19:0] = 20'b0;
				assign w_pcs8g_tx_detectrxloopout = 1'b0;
				assign w_pcs8g_tx_dynclkswitchn = 1'b0;
				assign w_pcs8g_tx_fifoselectoutchnldown[1:0] = 2'b0;
				assign w_pcs8g_tx_fifoselectoutchnlup[1:0] = 2'b0;
				assign w_pcs8g_tx_grayelecidleinferselout[2:0] = 3'b0;
				assign w_pcs8g_tx_parallelfdbkout[19:0] = 20'b0;
				assign w_pcs8g_tx_phfifooverflow = 1'b0;
				assign w_pcs8g_tx_phfifotxdeemph = 1'b0;
				assign w_pcs8g_tx_phfifotxmargin[2:0] = 3'b0;
				assign w_pcs8g_tx_phfifotxswing = 1'b0;
				assign w_pcs8g_tx_phfifounderflow = 1'b0;
				assign w_pcs8g_tx_pipeenrevparallellpbkout = 1'b0;
				assign w_pcs8g_tx_pipepowerdownout[1:0] = 2'b0;
				assign w_pcs8g_tx_polinvrxout = w_rx_pld_pcs_if_pcs8gpolinvrx;// connected when av_hssi_8g_tx_pcs is not instantiated
				assign w_pcs8g_tx_rdenableoutchnldown = 1'b0;
				assign w_pcs8g_tx_rdenableoutchnlup = 1'b0;
				assign w_pcs8g_tx_rdenablesync = 1'b0;
				assign w_pcs8g_tx_refclkb = 1'b0;
				assign w_pcs8g_tx_refclkbreset = 1'b0;
				assign w_pcs8g_tx_rxpolarityout = 1'b0;
				assign w_pcs8g_tx_txctrlplanetestbus[19:0] = 20'b0;
				assign w_pcs8g_tx_txdivsync[1:0] = 2'b0;
				assign w_pcs8g_tx_txdivsyncoutchnldown[1:0] = 2'b0;
				assign w_pcs8g_tx_txdivsyncoutchnlup[1:0] = 2'b0;
				assign w_pcs8g_tx_txpipeclk = 1'b0;
				assign w_pcs8g_tx_txpipeelectidle = 1'b0;
				assign w_pcs8g_tx_txpipesoftreset = 1'b0;
				assign w_pcs8g_tx_txtestbus[19:0] = 20'b0;
				assign w_pcs8g_tx_wrenableoutchnldown = 1'b0;
				assign w_pcs8g_tx_wrenableoutchnlup = 1'b0;
				assign w_pcs8g_tx_xgmctrlenable = 1'b0;
				assign w_pcs8g_tx_xgmdataout[7:0] = 8'b0;
		end // if not generate
		
		// instantiating av_hssi_common_pld_pcs_interface
		if ((enable_8g_rx == "true") || (enable_pma_direct_rx == "true") || (enable_dyn_reconfig == "true")) begin
			av_hssi_common_pld_pcs_interface_rbc #(
				.hip_enable(com_pld_pcs_if_hip_enable),
				.hrdrstctrl_en_cfg(com_pld_pcs_if_hrdrstctrl_en_cfg),
				.hrdrstctrl_en_cfgusr(com_pld_pcs_if_hrdrstctrl_en_cfgusr),
				.pld_side_data_source(com_pld_pcs_if_pld_side_data_source),
				.pld_side_reserved_source0(com_pld_pcs_if_pld_side_reserved_source0),
				.pld_side_reserved_source1(com_pld_pcs_if_pld_side_reserved_source1),
				.pld_side_reserved_source10(com_pld_pcs_if_pld_side_reserved_source10),
				.pld_side_reserved_source11(com_pld_pcs_if_pld_side_reserved_source11),
				.pld_side_reserved_source2(com_pld_pcs_if_pld_side_reserved_source2),
				.pld_side_reserved_source3(com_pld_pcs_if_pld_side_reserved_source3),
				.pld_side_reserved_source4(com_pld_pcs_if_pld_side_reserved_source4),
				.pld_side_reserved_source5(com_pld_pcs_if_pld_side_reserved_source5),
				.pld_side_reserved_source6(com_pld_pcs_if_pld_side_reserved_source6),
				.pld_side_reserved_source7(com_pld_pcs_if_pld_side_reserved_source7),
				.pld_side_reserved_source8(com_pld_pcs_if_pld_side_reserved_source8),
				.pld_side_reserved_source9(com_pld_pcs_if_pld_side_reserved_source9),
				.testbus_sel(com_pld_pcs_if_testbus_sel),
				.use_default_base_address(com_pld_pcs_if_use_default_base_address),
				.user_base_address(com_pld_pcs_if_user_base_address),
				.usrmode_sel4rst(com_pld_pcs_if_usrmode_sel4rst)
			) inst_av_hssi_common_pld_pcs_interface (
				// OUTPUTS
				.avmmreaddata(w_com_pld_pcs_if_avmmreaddata),
				.blockselect(w_com_pld_pcs_if_blockselect),
				.emsipcomclkout(w_com_pld_pcs_if_emsipcomclkout),
				.emsipcomout(w_com_pld_pcs_if_emsipcomout),
				.emsipenablediocsrrdydly(w_com_pld_pcs_if_emsipenablediocsrrdydly),
				.pcs8geidleinfersel(w_com_pld_pcs_if_pcs8geidleinfersel),
				.pcs8ghardreset(w_com_pld_pcs_if_pcs8ghardreset),
				.pcs8gltr(w_com_pld_pcs_if_pcs8gltr),
				.pcs8gpowerdown(w_com_pld_pcs_if_pcs8gpowerdown),
				.pcs8gprbsciden(w_com_pld_pcs_if_pcs8gprbsciden),
				.pcs8grate(w_com_pld_pcs_if_pcs8grate),
				.pcs8grefclkdig(w_com_pld_pcs_if_pcs8grefclkdig),
				.pcs8grefclkdig2(w_com_pld_pcs_if_pcs8grefclkdig2),
				.pcs8grxpolarity(w_com_pld_pcs_if_pcs8grxpolarity),
				.pcs8gscanmoden(w_com_pld_pcs_if_pcs8gscanmoden),
				.pcs8gtxdeemph(w_com_pld_pcs_if_pcs8gtxdeemph),
				.pcs8gtxdetectrxloopback(w_com_pld_pcs_if_pcs8gtxdetectrxloopback),
				.pcs8gtxelecidle(w_com_pld_pcs_if_pcs8gtxelecidle),
				.pcs8gtxmargin(w_com_pld_pcs_if_pcs8gtxmargin),
				.pcs8gtxswing(w_com_pld_pcs_if_pcs8gtxswing),
				.pcsaggrefclkdig(w_com_pld_pcs_if_pcsaggrefclkdig),
				.pcsaggscanmoden(w_com_pld_pcs_if_pcsaggscanmoden),
				.pcsaggscanshift(w_com_pld_pcs_if_pcsaggscanshift),
				.pcsaggtestsi(w_com_pld_pcs_if_pcsaggtestsi),
				.pcspcspmaifrefclkdig(w_com_pld_pcs_if_pcspcspmaifrefclkdig),
				.pcspcspmaifscanmoden(w_com_pld_pcs_if_pcspcspmaifscanmoden),
				.pcspcspmaifscanshiftn(w_com_pld_pcs_if_pcspcspmaifscanshiftn),
				.pcspmaifhardreset(w_com_pld_pcs_if_pcspmaifhardreset),
				.pld8gphystatus(w_com_pld_pcs_if_pld8gphystatus),
				.pld8grxelecidle(w_com_pld_pcs_if_pld8grxelecidle),
				.pld8grxstatus(w_com_pld_pcs_if_pld8grxstatus),
				.pld8grxvalid(w_com_pld_pcs_if_pld8grxvalid),
				.pldclklow(w_com_pld_pcs_if_pldclklow),
				.pldfref(w_com_pld_pcs_if_pldfref),
				.pldnfrzdrv(w_com_pld_pcs_if_pldnfrzdrv),
				.pldpartialreconfigout(w_com_pld_pcs_if_pldpartialreconfigout),
				.pldreservedout(w_com_pld_pcs_if_pldreservedout),
				.pldtestdata(w_com_pld_pcs_if_pldtestdata),
				.rstsel(w_com_pld_pcs_if_rstsel),
				.usrrstsel(w_com_pld_pcs_if_usrrstsel),
				// INPUTS
				.avmmaddress({in_avmmaddress[10], in_avmmaddress[9], in_avmmaddress[8], in_avmmaddress[7], in_avmmaddress[6], in_avmmaddress[5], in_avmmaddress[4], in_avmmaddress[3], in_avmmaddress[2], in_avmmaddress[1], in_avmmaddress[0]}),
				.avmmbyteen({in_avmmbyteen[1], in_avmmbyteen[0]}),
				.avmmclk(in_avmmclk),
				.avmmread(in_avmmread),
				.avmmrstn(in_avmmrstn),
				.avmmwrite(in_avmmwrite),
				.avmmwritedata({in_avmmwritedata[15], in_avmmwritedata[14], in_avmmwritedata[13], in_avmmwritedata[12], in_avmmwritedata[11], in_avmmwritedata[10], in_avmmwritedata[9], in_avmmwritedata[8], in_avmmwritedata[7], in_avmmwritedata[6], in_avmmwritedata[5], in_avmmwritedata[4], in_avmmwritedata[3], in_avmmwritedata[2], in_avmmwritedata[1], in_avmmwritedata[0]}),
				.emsipcomin({in_emsip_com_in[37], in_emsip_com_in[36], in_emsip_com_in[35], in_emsip_com_in[34], in_emsip_com_in[33], in_emsip_com_in[32], in_emsip_com_in[31], in_emsip_com_in[30], in_emsip_com_in[29], in_emsip_com_in[28], in_emsip_com_in[27], in_emsip_com_in[26], in_emsip_com_in[25], in_emsip_com_in[24], in_emsip_com_in[23], in_emsip_com_in[22], in_emsip_com_in[21], in_emsip_com_in[20], in_emsip_com_in[19], in_emsip_com_in[18], in_emsip_com_in[17], in_emsip_com_in[16], in_emsip_com_in[15], in_emsip_com_in[14], in_emsip_com_in[13], in_emsip_com_in[12], in_emsip_com_in[11], in_emsip_com_in[10], in_emsip_com_in[9], in_emsip_com_in[8], in_emsip_com_in[7], in_emsip_com_in[6], in_emsip_com_in[5], in_emsip_com_in[4], in_emsip_com_in[3], in_emsip_com_in[2], in_emsip_com_in[1], in_emsip_com_in[0]}),
				.pcs8gchnltestbusout({w_pcs8g_rx_channeltestbusout[19], w_pcs8g_rx_channeltestbusout[18], w_pcs8g_rx_channeltestbusout[17], w_pcs8g_rx_channeltestbusout[16], w_pcs8g_rx_channeltestbusout[15], w_pcs8g_rx_channeltestbusout[14], w_pcs8g_rx_channeltestbusout[13], w_pcs8g_rx_channeltestbusout[12], w_pcs8g_rx_channeltestbusout[11], w_pcs8g_rx_channeltestbusout[10], w_pcs8g_rx_channeltestbusout[9], w_pcs8g_rx_channeltestbusout[8], w_pcs8g_rx_channeltestbusout[7], w_pcs8g_rx_channeltestbusout[6], w_pcs8g_rx_channeltestbusout[5], w_pcs8g_rx_channeltestbusout[4], w_pcs8g_rx_channeltestbusout[3], w_pcs8g_rx_channeltestbusout[2], w_pcs8g_rx_channeltestbusout[1], w_pcs8g_rx_channeltestbusout[0]}),
				.pcs8gphystatus(w_pcs8g_rx_phystatus),
				.pcs8grxelecidle(w_pipe12_rxelecidle),
				.pcs8grxstatus({w_pcs8g_rx_rxstatus[2], w_pcs8g_rx_rxstatus[1], w_pcs8g_rx_rxstatus[0]}),
				.pcs8grxvalid(w_pcs8g_rx_rxvalid),
				.pcsaggtestso(w_com_pcs_pma_if_aggtestsotopldout),
				.pcspmaiftestbusout({w_com_pcs_pma_if_pmaiftestbus[9], w_com_pcs_pma_if_pmaiftestbus[8], w_com_pcs_pma_if_pmaiftestbus[7], w_com_pcs_pma_if_pmaiftestbus[6], w_com_pcs_pma_if_pmaiftestbus[5], w_com_pcs_pma_if_pmaiftestbus[4], w_com_pcs_pma_if_pmaiftestbus[3], w_com_pcs_pma_if_pmaiftestbus[2], w_com_pcs_pma_if_pmaiftestbus[1], w_com_pcs_pma_if_pmaiftestbus[0]}),
				.pld8gpowerdown({in_pld_8g_powerdown[1], in_pld_8g_powerdown[0]}),
				.pld8gprbsciden(in_pld_8g_prbs_cid_en),
				.pld8grefclkdig(in_pld_8g_refclk_dig),
				.pld8grefclkdig2(in_pld_8g_refclk_dig2),
				.pld8grxpolarity(in_pld_8g_rxpolarity),
				.pld8gtxdeemph(in_pld_8g_txdeemph),
				.pld8gtxdetectrxloopback(in_pld_8g_txdetectrxloopback),
				.pld8gtxelecidle(in_pld_8g_txelecidle),
				.pld8gtxmargin({in_pld_8g_txmargin[2], in_pld_8g_txmargin[1], in_pld_8g_txmargin[0]}),
				.pld8gtxswing(in_pld_8g_txswing),
				.pldaggrefclkdig(in_pld_agg_refclk_dig),
				.pldeidleinfersel({in_pld_eidleinfersel[2], in_pld_eidleinfersel[1], in_pld_eidleinfersel[0]}),
				.pldhclkin(w_com_pcs_pma_if_pldhclkout),
				.pldltr(in_pld_ltr),
				.pldpartialreconfigin(in_pld_partial_reconfig_in),
				.pldpcspmaifrefclkdig(in_pld_pcs_pma_if_refclk_dig),
				.pldrate(in_pld_rate),
				.pldreservedin({in_pld_reserved_in[11], in_pld_reserved_in[10], in_pld_reserved_in[9], in_pld_reserved_in[8], in_pld_reserved_in[7], in_pld_reserved_in[6], in_pld_reserved_in[5], in_pld_reserved_in[4], in_pld_reserved_in[3], in_pld_reserved_in[2], in_pld_reserved_in[1], in_pld_reserved_in[0]}),
				.pldscanmoden(in_pld_scan_mode_n),
				.pldscanshiftn(in_pld_scan_shift_n),
				.pmaclklow(w_com_pcs_pma_if_pmaclklowout),
				.pmafref(w_com_pcs_pma_if_pmafrefout)
			);
		end // if generate
		else begin
				assign w_com_pld_pcs_if_avmmreaddata[15:0] = 16'b0;
				assign w_com_pld_pcs_if_blockselect = 1'b0;
				assign w_com_pld_pcs_if_emsipcomclkout[2:0] = 3'b0;
				assign w_com_pld_pcs_if_emsipcomout[26:0] = 27'b0;
				assign w_com_pld_pcs_if_emsipenablediocsrrdydly = 1'b0;
				assign w_com_pld_pcs_if_pcs8geidleinfersel[2:0] = 3'b0;
				assign w_com_pld_pcs_if_pcs8ghardreset = 1'b1; // Set to 1'b1 when av_hssi_common_pld_pcs_interface is not instantiated
				assign w_com_pld_pcs_if_pcs8gltr = 1'b0;
				assign w_com_pld_pcs_if_pcs8gpowerdown[1:0] = 2'b0;
				assign w_com_pld_pcs_if_pcs8gprbsciden = 1'b0;
				assign w_com_pld_pcs_if_pcs8grate = 1'b0;
				assign w_com_pld_pcs_if_pcs8grefclkdig = 1'b0;
				assign w_com_pld_pcs_if_pcs8grefclkdig2 = 1'b0;
				assign w_com_pld_pcs_if_pcs8grxpolarity = 1'b0;
				assign w_com_pld_pcs_if_pcs8gscanmoden = 1'b1; // Set to 1'b1 when av_hssi_common_pld_pcs_interface is not instantiated
				assign w_com_pld_pcs_if_pcs8gtxdeemph = 1'b0;
				assign w_com_pld_pcs_if_pcs8gtxdetectrxloopback = 1'b0;
				assign w_com_pld_pcs_if_pcs8gtxelecidle = 1'b0;
				assign w_com_pld_pcs_if_pcs8gtxmargin[2:0] = 3'b0;
				assign w_com_pld_pcs_if_pcs8gtxswing = 1'b0;
				assign w_com_pld_pcs_if_pcsaggrefclkdig = 1'b0;
				assign w_com_pld_pcs_if_pcsaggscanmoden = 1'b1; // Set to 1'b1 when av_hssi_common_pld_pcs_interface is not instantiated
				assign w_com_pld_pcs_if_pcsaggscanshift = 1'b0;
				assign w_com_pld_pcs_if_pcsaggtestsi = 1'b0;
				assign w_com_pld_pcs_if_pcspcspmaifrefclkdig = 1'b0;
				assign w_com_pld_pcs_if_pcspcspmaifscanmoden = 1'b1; // Set to 1'b1 when av_hssi_common_pld_pcs_interface is not instantiated
				assign w_com_pld_pcs_if_pcspcspmaifscanshiftn = 1'b0;
				assign w_com_pld_pcs_if_pcspmaifhardreset = 1'b1; // Set to 1'b1 when av_hssi_common_pld_pcs_interface is not instantiated
				assign w_com_pld_pcs_if_pld8gphystatus = 1'b0;
				assign w_com_pld_pcs_if_pld8grxelecidle = 1'b0;
				assign w_com_pld_pcs_if_pld8grxstatus[2:0] = 3'b0;
				assign w_com_pld_pcs_if_pld8grxvalid = 1'b0;
				assign w_com_pld_pcs_if_pldclklow = 1'b0;
				assign w_com_pld_pcs_if_pldfref = 1'b0;
				assign w_com_pld_pcs_if_pldnfrzdrv = 1'b0;
				assign w_com_pld_pcs_if_pldpartialreconfigout = 1'b0;
				assign w_com_pld_pcs_if_pldreservedout[10:0] = 11'b0;
				assign w_com_pld_pcs_if_pldtestdata[19:0] = 20'b0;
				assign w_com_pld_pcs_if_rstsel = 1'b0;
				assign w_com_pld_pcs_if_usrrstsel = 1'b1; // Set to 1'b1 when av_hssi_common_pld_pcs_interface is not instantiated
		end // if not generate
		
		// instantiating av_hssi_tx_pld_pcs_interface
		if ((enable_8g_tx == "true") || (enable_dyn_reconfig == "true")) begin
			av_hssi_tx_pld_pcs_interface_rbc #(
				.is_8g_0ppm(tx_pld_pcs_if_is_8g_0ppm),
				.pld_side_data_source(tx_pld_pcs_if_pld_side_data_source),
				.use_default_base_address(tx_pld_pcs_if_use_default_base_address),
				.user_base_address(tx_pld_pcs_if_user_base_address)
			) inst_av_hssi_tx_pld_pcs_interface (
				// OUTPUTS
				.avmmreaddata(w_tx_pld_pcs_if_avmmreaddata),
				.blockselect(w_tx_pld_pcs_if_blockselect),
				.dataoutto8gpcs(w_tx_pld_pcs_if_dataoutto8gpcs),
				.emsippcstxclkout(w_tx_pld_pcs_if_emsippcstxclkout),
				.emsiptxspecialout(w_tx_pld_pcs_if_emsiptxspecialout),
				.pcs8gphfifoursttx(w_tx_pld_pcs_if_pcs8gphfifoursttx),
				.pcs8gpldtxclk(w_tx_pld_pcs_if_pcs8gpldtxclk),
				.pcs8gpolinvtx(w_tx_pld_pcs_if_pcs8gpolinvtx),
				.pcs8grddisabletx(w_tx_pld_pcs_if_pcs8grddisabletx),
				.pcs8grevloopbk(w_tx_pld_pcs_if_pcs8grevloopbk),
				.pcs8gtxboundarysel(w_tx_pld_pcs_if_pcs8gtxboundarysel),
				.pcs8gtxdatavalid(w_tx_pld_pcs_if_pcs8gtxdatavalid),
				.pcs8gtxurstpcs(w_tx_pld_pcs_if_pcs8gtxurstpcs),
				.pcs8gwrenabletx(w_tx_pld_pcs_if_pcs8gwrenabletx),
				.pld8gemptytx(w_tx_pld_pcs_if_pld8gemptytx),
				.pld8gfulltx(w_tx_pld_pcs_if_pld8gfulltx),
				.pld8gtxclkout(w_tx_pld_pcs_if_pld8gtxclkout),
				// INPUTS
				.avmmaddress({in_avmmaddress[10], in_avmmaddress[9], in_avmmaddress[8], in_avmmaddress[7], in_avmmaddress[6], in_avmmaddress[5], in_avmmaddress[4], in_avmmaddress[3], in_avmmaddress[2], in_avmmaddress[1], in_avmmaddress[0]}),
				.avmmbyteen({in_avmmbyteen[1], in_avmmbyteen[0]}),
				.avmmclk(in_avmmclk),
				.avmmread(in_avmmread),
				.avmmrstn(in_avmmrstn),
				.avmmwrite(in_avmmwrite),
				.avmmwritedata({in_avmmwritedata[15], in_avmmwritedata[14], in_avmmwritedata[13], in_avmmwritedata[12], in_avmmwritedata[11], in_avmmwritedata[10], in_avmmwritedata[9], in_avmmwritedata[8], in_avmmwritedata[7], in_avmmwritedata[6], in_avmmwritedata[5], in_avmmwritedata[4], in_avmmwritedata[3], in_avmmwritedata[2], in_avmmwritedata[1], in_avmmwritedata[0]}),
				.clockinfrom8gpcs(w_pcs8g_tx_clkout),
				.datainfrompld({in_pld_tx_data[43], in_pld_tx_data[42], in_pld_tx_data[41], in_pld_tx_data[40], in_pld_tx_data[39], in_pld_tx_data[38], in_pld_tx_data[37], in_pld_tx_data[36], in_pld_tx_data[35], in_pld_tx_data[34], in_pld_tx_data[33], in_pld_tx_data[32], in_pld_tx_data[31], in_pld_tx_data[30], in_pld_tx_data[29], in_pld_tx_data[28], in_pld_tx_data[27], in_pld_tx_data[26], in_pld_tx_data[25], in_pld_tx_data[24], in_pld_tx_data[23], in_pld_tx_data[22], in_pld_tx_data[21], in_pld_tx_data[20], in_pld_tx_data[19], in_pld_tx_data[18], in_pld_tx_data[17], in_pld_tx_data[16], in_pld_tx_data[15], in_pld_tx_data[14], in_pld_tx_data[13], in_pld_tx_data[12], in_pld_tx_data[11], in_pld_tx_data[10], in_pld_tx_data[9], in_pld_tx_data[8], in_pld_tx_data[7], in_pld_tx_data[6], in_pld_tx_data[5], in_pld_tx_data[4], in_pld_tx_data[3], in_pld_tx_data[2], in_pld_tx_data[1], in_pld_tx_data[0]}),
				.emsipenablediocsrrdydly(w_com_pld_pcs_if_emsipenablediocsrrdydly),
				.emsiptxin({in_emsip_tx_in[103], in_emsip_tx_in[102], in_emsip_tx_in[101], in_emsip_tx_in[100], in_emsip_tx_in[99], in_emsip_tx_in[98], in_emsip_tx_in[97], in_emsip_tx_in[96], in_emsip_tx_in[95], in_emsip_tx_in[94], in_emsip_tx_in[93], in_emsip_tx_in[92], in_emsip_tx_in[91], in_emsip_tx_in[90], in_emsip_tx_in[89], in_emsip_tx_in[88], in_emsip_tx_in[87], in_emsip_tx_in[86], in_emsip_tx_in[85], in_emsip_tx_in[84], in_emsip_tx_in[83], in_emsip_tx_in[82], in_emsip_tx_in[81], in_emsip_tx_in[80], in_emsip_tx_in[79], in_emsip_tx_in[78], in_emsip_tx_in[77], in_emsip_tx_in[76], in_emsip_tx_in[75], in_emsip_tx_in[74], in_emsip_tx_in[73], in_emsip_tx_in[72], in_emsip_tx_in[71], in_emsip_tx_in[70], in_emsip_tx_in[69], in_emsip_tx_in[68], in_emsip_tx_in[67], in_emsip_tx_in[66], in_emsip_tx_in[65], in_emsip_tx_in[64], in_emsip_tx_in[63], in_emsip_tx_in[62], in_emsip_tx_in[61], in_emsip_tx_in[60], in_emsip_tx_in[59], in_emsip_tx_in[58], in_emsip_tx_in[57], in_emsip_tx_in[56], in_emsip_tx_in[55], in_emsip_tx_in[54], in_emsip_tx_in[53], in_emsip_tx_in[52], in_emsip_tx_in[51], in_emsip_tx_in[50], in_emsip_tx_in[49], in_emsip_tx_in[48], in_emsip_tx_in[47], in_emsip_tx_in[46], in_emsip_tx_in[45], in_emsip_tx_in[44], in_emsip_tx_in[43], in_emsip_tx_in[42], in_emsip_tx_in[41], in_emsip_tx_in[40], in_emsip_tx_in[39], in_emsip_tx_in[38], in_emsip_tx_in[37], in_emsip_tx_in[36], in_emsip_tx_in[35], in_emsip_tx_in[34], in_emsip_tx_in[33], in_emsip_tx_in[32], in_emsip_tx_in[31], in_emsip_tx_in[30], in_emsip_tx_in[29], in_emsip_tx_in[28], in_emsip_tx_in[27], in_emsip_tx_in[26], in_emsip_tx_in[25], in_emsip_tx_in[24], in_emsip_tx_in[23], in_emsip_tx_in[22], in_emsip_tx_in[21], in_emsip_tx_in[20], in_emsip_tx_in[19], in_emsip_tx_in[18], in_emsip_tx_in[17], in_emsip_tx_in[16], in_emsip_tx_in[15], in_emsip_tx_in[14], in_emsip_tx_in[13], in_emsip_tx_in[12], in_emsip_tx_in[11], in_emsip_tx_in[10], in_emsip_tx_in[9], in_emsip_tx_in[8], in_emsip_tx_in[7], in_emsip_tx_in[6], in_emsip_tx_in[5], in_emsip_tx_in[4], in_emsip_tx_in[3], in_emsip_tx_in[2], in_emsip_tx_in[1], in_emsip_tx_in[0]}),
				.emsiptxspecialin({in_emsip_tx_special_in[12], in_emsip_tx_special_in[11], in_emsip_tx_special_in[10], in_emsip_tx_special_in[9], in_emsip_tx_special_in[8], in_emsip_tx_special_in[7], in_emsip_tx_special_in[6], in_emsip_tx_special_in[5], in_emsip_tx_special_in[4], in_emsip_tx_special_in[3], in_emsip_tx_special_in[2], in_emsip_tx_special_in[1], in_emsip_tx_special_in[0]}),
				.pcs8gemptytx(w_pcs8g_tx_phfifounderflow),
				.pcs8gfulltx(w_pcs8g_tx_phfifooverflow),
				.pld8gphfifoursttxn(in_pld_8g_phfifourst_tx_n),
				.pld8gpldtxclk(in_pld_8g_pld_tx_clk),
				.pld8gpolinvtx(in_pld_8g_polinv_tx),
				.pld8grddisabletx(in_pld_8g_rddisable_tx),
				.pld8grevloopbk(in_pld_8g_rev_loopbk),
				.pld8gtxboundarysel({in_pld_8g_tx_boundary_sel[4], in_pld_8g_tx_boundary_sel[3], in_pld_8g_tx_boundary_sel[2], in_pld_8g_tx_boundary_sel[1], in_pld_8g_tx_boundary_sel[0]}),
				.pld8gtxdatavalid({in_pld_8g_tx_data_valid[3], in_pld_8g_tx_data_valid[2], in_pld_8g_tx_data_valid[1], in_pld_8g_tx_data_valid[0]}),
				.pld8gtxurstpcsn(in_pld_8g_txurstpcs_n),
				.pld8gwrenabletx(in_pld_8g_wrenable_tx),
				.pmatxcmuplllock(w_tx_pcs_pma_if_pmarxfreqtxcmuplllockout),
				.rstsel(w_com_pld_pcs_if_rstsel),
				.usrrstsel(w_com_pld_pcs_if_usrrstsel)
			);
		end // if generate
		else begin
				assign w_tx_pld_pcs_if_avmmreaddata[15:0] = 16'b0;
				assign w_tx_pld_pcs_if_blockselect = 1'b0;
				assign w_tx_pld_pcs_if_dataoutto8gpcs[43:0] = 44'b0;
				assign w_tx_pld_pcs_if_emsippcstxclkout[2:0] = 3'b0;
				assign w_tx_pld_pcs_if_emsiptxspecialout[15:0] = 16'b0;
				assign w_tx_pld_pcs_if_pcs8gphfifoursttx = 1'b0;
				assign w_tx_pld_pcs_if_pcs8gpldtxclk = 1'b0;
				assign w_tx_pld_pcs_if_pcs8gpolinvtx = 1'b0;
				assign w_tx_pld_pcs_if_pcs8grddisabletx = 1'b0;
				assign w_tx_pld_pcs_if_pcs8grevloopbk = 1'b0;
				assign w_tx_pld_pcs_if_pcs8gtxboundarysel[4:0] = 5'b0;
				assign w_tx_pld_pcs_if_pcs8gtxdatavalid[3:0] = 4'b0;
				assign w_tx_pld_pcs_if_pcs8gtxurstpcs = 1'b0;
				assign w_tx_pld_pcs_if_pcs8gwrenabletx = 1'b0;
				assign w_tx_pld_pcs_if_pld8gemptytx = 1'b0;
				assign w_tx_pld_pcs_if_pld8gfulltx = 1'b0;
				assign w_tx_pld_pcs_if_pld8gtxclkout = 1'b0;
		end // if not generate
		
		//output assignments
		assign out_agg_align_det_sync = {w_com_pcs_pma_if_aggaligndetsync[1], w_com_pcs_pma_if_aggaligndetsync[0]};
		assign out_agg_align_status_sync = w_com_pcs_pma_if_aggalignstatussync;
		assign out_agg_cg_comp_rd_d_out = {w_com_pcs_pma_if_aggcgcomprddout[1], w_com_pcs_pma_if_aggcgcomprddout[0]};
		assign out_agg_cg_comp_wr_out = {w_com_pcs_pma_if_aggcgcompwrout[1], w_com_pcs_pma_if_aggcgcompwrout[0]};
		assign out_agg_dec_ctl = w_com_pcs_pma_if_aggdecctl;
		assign out_agg_dec_data = {w_com_pcs_pma_if_aggdecdata[7], w_com_pcs_pma_if_aggdecdata[6], w_com_pcs_pma_if_aggdecdata[5], w_com_pcs_pma_if_aggdecdata[4], w_com_pcs_pma_if_aggdecdata[3], w_com_pcs_pma_if_aggdecdata[2], w_com_pcs_pma_if_aggdecdata[1], w_com_pcs_pma_if_aggdecdata[0]};
		assign out_agg_dec_data_valid = w_com_pcs_pma_if_aggdecdatavalid;
		assign out_agg_del_cond_met_out = w_com_pcs_pma_if_aggdelcondmetout;
		assign out_agg_fifo_ovr_out = w_com_pcs_pma_if_aggfifoovrout;
		assign out_agg_fifo_rd_out_comp = w_com_pcs_pma_if_aggfifordoutcomp;
		assign out_agg_insert_incomplete_out = w_com_pcs_pma_if_agginsertincompleteout;
		assign out_agg_latency_comp_out = w_com_pcs_pma_if_agglatencycompout;
		assign out_agg_rd_align = {w_com_pcs_pma_if_aggrdalign[1], w_com_pcs_pma_if_aggrdalign[0]};
		assign out_agg_rd_enable_sync = w_com_pcs_pma_if_aggrdenablesync;
		assign out_agg_refclk_dig = w_com_pcs_pma_if_aggrefclkdig;
		assign out_agg_running_disp = {w_com_pcs_pma_if_aggrunningdisp[1], w_com_pcs_pma_if_aggrunningdisp[0]};
		assign out_agg_rxpcs_rst = w_com_pcs_pma_if_aggrxpcsrst;
		assign out_agg_scan_mode_n = w_com_pcs_pma_if_aggscanmoden;
		assign out_agg_scan_shift_n = w_com_pcs_pma_if_aggscanshiftn;
		assign out_agg_sync_status = w_com_pcs_pma_if_aggsyncstatus;
		assign out_agg_tx_ctl_tc = w_com_pcs_pma_if_aggtxctltc;
		assign out_agg_tx_data_tc = {w_com_pcs_pma_if_aggtxdatatc[7], w_com_pcs_pma_if_aggtxdatatc[6], w_com_pcs_pma_if_aggtxdatatc[5], w_com_pcs_pma_if_aggtxdatatc[4], w_com_pcs_pma_if_aggtxdatatc[3], w_com_pcs_pma_if_aggtxdatatc[2], w_com_pcs_pma_if_aggtxdatatc[1], w_com_pcs_pma_if_aggtxdatatc[0]};
		assign out_agg_txpcs_rst = w_com_pcs_pma_if_aggtxpcsrst;
		assign out_avmmreaddata_com_pcs_pma_if = {w_com_pcs_pma_if_avmmreaddata[15], w_com_pcs_pma_if_avmmreaddata[14], w_com_pcs_pma_if_avmmreaddata[13], w_com_pcs_pma_if_avmmreaddata[12], w_com_pcs_pma_if_avmmreaddata[11], w_com_pcs_pma_if_avmmreaddata[10], w_com_pcs_pma_if_avmmreaddata[9], w_com_pcs_pma_if_avmmreaddata[8], w_com_pcs_pma_if_avmmreaddata[7], w_com_pcs_pma_if_avmmreaddata[6], w_com_pcs_pma_if_avmmreaddata[5], w_com_pcs_pma_if_avmmreaddata[4], w_com_pcs_pma_if_avmmreaddata[3], w_com_pcs_pma_if_avmmreaddata[2], w_com_pcs_pma_if_avmmreaddata[1], w_com_pcs_pma_if_avmmreaddata[0]};
		assign out_avmmreaddata_com_pld_pcs_if = {w_com_pld_pcs_if_avmmreaddata[15], w_com_pld_pcs_if_avmmreaddata[14], w_com_pld_pcs_if_avmmreaddata[13], w_com_pld_pcs_if_avmmreaddata[12], w_com_pld_pcs_if_avmmreaddata[11], w_com_pld_pcs_if_avmmreaddata[10], w_com_pld_pcs_if_avmmreaddata[9], w_com_pld_pcs_if_avmmreaddata[8], w_com_pld_pcs_if_avmmreaddata[7], w_com_pld_pcs_if_avmmreaddata[6], w_com_pld_pcs_if_avmmreaddata[5], w_com_pld_pcs_if_avmmreaddata[4], w_com_pld_pcs_if_avmmreaddata[3], w_com_pld_pcs_if_avmmreaddata[2], w_com_pld_pcs_if_avmmreaddata[1], w_com_pld_pcs_if_avmmreaddata[0]};
		assign out_avmmreaddata_pcs8g_rx = {w_pcs8g_rx_avmmreaddata[15], w_pcs8g_rx_avmmreaddata[14], w_pcs8g_rx_avmmreaddata[13], w_pcs8g_rx_avmmreaddata[12], w_pcs8g_rx_avmmreaddata[11], w_pcs8g_rx_avmmreaddata[10], w_pcs8g_rx_avmmreaddata[9], w_pcs8g_rx_avmmreaddata[8], w_pcs8g_rx_avmmreaddata[7], w_pcs8g_rx_avmmreaddata[6], w_pcs8g_rx_avmmreaddata[5], w_pcs8g_rx_avmmreaddata[4], w_pcs8g_rx_avmmreaddata[3], w_pcs8g_rx_avmmreaddata[2], w_pcs8g_rx_avmmreaddata[1], w_pcs8g_rx_avmmreaddata[0]};
		assign out_avmmreaddata_pcs8g_tx = {w_pcs8g_tx_avmmreaddata[15], w_pcs8g_tx_avmmreaddata[14], w_pcs8g_tx_avmmreaddata[13], w_pcs8g_tx_avmmreaddata[12], w_pcs8g_tx_avmmreaddata[11], w_pcs8g_tx_avmmreaddata[10], w_pcs8g_tx_avmmreaddata[9], w_pcs8g_tx_avmmreaddata[8], w_pcs8g_tx_avmmreaddata[7], w_pcs8g_tx_avmmreaddata[6], w_pcs8g_tx_avmmreaddata[5], w_pcs8g_tx_avmmreaddata[4], w_pcs8g_tx_avmmreaddata[3], w_pcs8g_tx_avmmreaddata[2], w_pcs8g_tx_avmmreaddata[1], w_pcs8g_tx_avmmreaddata[0]};
		assign out_avmmreaddata_pipe12 = {w_pipe12_avmmreaddata[15], w_pipe12_avmmreaddata[14], w_pipe12_avmmreaddata[13], w_pipe12_avmmreaddata[12], w_pipe12_avmmreaddata[11], w_pipe12_avmmreaddata[10], w_pipe12_avmmreaddata[9], w_pipe12_avmmreaddata[8], w_pipe12_avmmreaddata[7], w_pipe12_avmmreaddata[6], w_pipe12_avmmreaddata[5], w_pipe12_avmmreaddata[4], w_pipe12_avmmreaddata[3], w_pipe12_avmmreaddata[2], w_pipe12_avmmreaddata[1], w_pipe12_avmmreaddata[0]};
		assign out_avmmreaddata_rx_pcs_pma_if = {w_rx_pcs_pma_if_avmmreaddata[15], w_rx_pcs_pma_if_avmmreaddata[14], w_rx_pcs_pma_if_avmmreaddata[13], w_rx_pcs_pma_if_avmmreaddata[12], w_rx_pcs_pma_if_avmmreaddata[11], w_rx_pcs_pma_if_avmmreaddata[10], w_rx_pcs_pma_if_avmmreaddata[9], w_rx_pcs_pma_if_avmmreaddata[8], w_rx_pcs_pma_if_avmmreaddata[7], w_rx_pcs_pma_if_avmmreaddata[6], w_rx_pcs_pma_if_avmmreaddata[5], w_rx_pcs_pma_if_avmmreaddata[4], w_rx_pcs_pma_if_avmmreaddata[3], w_rx_pcs_pma_if_avmmreaddata[2], w_rx_pcs_pma_if_avmmreaddata[1], w_rx_pcs_pma_if_avmmreaddata[0]};
		assign out_avmmreaddata_rx_pld_pcs_if = {w_rx_pld_pcs_if_avmmreaddata[15], w_rx_pld_pcs_if_avmmreaddata[14], w_rx_pld_pcs_if_avmmreaddata[13], w_rx_pld_pcs_if_avmmreaddata[12], w_rx_pld_pcs_if_avmmreaddata[11], w_rx_pld_pcs_if_avmmreaddata[10], w_rx_pld_pcs_if_avmmreaddata[9], w_rx_pld_pcs_if_avmmreaddata[8], w_rx_pld_pcs_if_avmmreaddata[7], w_rx_pld_pcs_if_avmmreaddata[6], w_rx_pld_pcs_if_avmmreaddata[5], w_rx_pld_pcs_if_avmmreaddata[4], w_rx_pld_pcs_if_avmmreaddata[3], w_rx_pld_pcs_if_avmmreaddata[2], w_rx_pld_pcs_if_avmmreaddata[1], w_rx_pld_pcs_if_avmmreaddata[0]};
		assign out_avmmreaddata_tx_pcs_pma_if = {w_tx_pcs_pma_if_avmmreaddata[15], w_tx_pcs_pma_if_avmmreaddata[14], w_tx_pcs_pma_if_avmmreaddata[13], w_tx_pcs_pma_if_avmmreaddata[12], w_tx_pcs_pma_if_avmmreaddata[11], w_tx_pcs_pma_if_avmmreaddata[10], w_tx_pcs_pma_if_avmmreaddata[9], w_tx_pcs_pma_if_avmmreaddata[8], w_tx_pcs_pma_if_avmmreaddata[7], w_tx_pcs_pma_if_avmmreaddata[6], w_tx_pcs_pma_if_avmmreaddata[5], w_tx_pcs_pma_if_avmmreaddata[4], w_tx_pcs_pma_if_avmmreaddata[3], w_tx_pcs_pma_if_avmmreaddata[2], w_tx_pcs_pma_if_avmmreaddata[1], w_tx_pcs_pma_if_avmmreaddata[0]};
		assign out_avmmreaddata_tx_pld_pcs_if = {w_tx_pld_pcs_if_avmmreaddata[15], w_tx_pld_pcs_if_avmmreaddata[14], w_tx_pld_pcs_if_avmmreaddata[13], w_tx_pld_pcs_if_avmmreaddata[12], w_tx_pld_pcs_if_avmmreaddata[11], w_tx_pld_pcs_if_avmmreaddata[10], w_tx_pld_pcs_if_avmmreaddata[9], w_tx_pld_pcs_if_avmmreaddata[8], w_tx_pld_pcs_if_avmmreaddata[7], w_tx_pld_pcs_if_avmmreaddata[6], w_tx_pld_pcs_if_avmmreaddata[5], w_tx_pld_pcs_if_avmmreaddata[4], w_tx_pld_pcs_if_avmmreaddata[3], w_tx_pld_pcs_if_avmmreaddata[2], w_tx_pld_pcs_if_avmmreaddata[1], w_tx_pld_pcs_if_avmmreaddata[0]};
		assign out_blockselect_com_pcs_pma_if = w_com_pcs_pma_if_blockselect;
		assign out_blockselect_com_pld_pcs_if = w_com_pld_pcs_if_blockselect;
		assign out_blockselect_pcs8g_rx = w_pcs8g_rx_blockselect;
		assign out_blockselect_pcs8g_tx = w_pcs8g_tx_blockselect;
		assign out_blockselect_pipe12 = w_pipe12_blockselect;
		assign out_blockselect_rx_pcs_pma_if = w_rx_pcs_pma_if_blockselect;
		assign out_blockselect_rx_pld_pcs_if = w_rx_pld_pcs_if_blockselect;
		assign out_blockselect_tx_pcs_pma_if = w_tx_pcs_pma_if_blockselect;
		assign out_blockselect_tx_pld_pcs_if = w_tx_pld_pcs_if_blockselect;
		assign out_config_sel_out_chnl_down = w_pcs8g_rx_configseloutchnldown;
		assign out_config_sel_out_chnl_up = w_pcs8g_rx_configseloutchnlup;
		assign out_emsip_com_clk_out = {w_com_pld_pcs_if_emsipcomclkout[2], w_com_pld_pcs_if_emsipcomclkout[1], w_com_pld_pcs_if_emsipcomclkout[0]};
		assign out_emsip_com_out = {w_com_pld_pcs_if_emsipcomout[26], w_com_pld_pcs_if_emsipcomout[25], w_com_pld_pcs_if_emsipcomout[24], w_com_pld_pcs_if_emsipcomout[23], w_com_pld_pcs_if_emsipcomout[22], w_com_pld_pcs_if_emsipcomout[21], w_com_pld_pcs_if_emsipcomout[20], w_com_pld_pcs_if_emsipcomout[19], w_com_pld_pcs_if_emsipcomout[18], w_com_pld_pcs_if_emsipcomout[17], w_com_pld_pcs_if_emsipcomout[16], w_com_pld_pcs_if_emsipcomout[15], w_com_pld_pcs_if_emsipcomout[14], w_com_pld_pcs_if_emsipcomout[13], w_com_pld_pcs_if_emsipcomout[12], w_com_pld_pcs_if_emsipcomout[11], w_com_pld_pcs_if_emsipcomout[10], w_com_pld_pcs_if_emsipcomout[9], w_com_pld_pcs_if_emsipcomout[8], w_com_pld_pcs_if_emsipcomout[7], w_com_pld_pcs_if_emsipcomout[6], w_com_pld_pcs_if_emsipcomout[5], w_com_pld_pcs_if_emsipcomout[4], w_com_pld_pcs_if_emsipcomout[3], w_com_pld_pcs_if_emsipcomout[2], w_com_pld_pcs_if_emsipcomout[1], w_com_pld_pcs_if_emsipcomout[0]};
		assign out_emsip_rx_out = {w_rx_pld_pcs_if_emsiprxout[128], w_rx_pld_pcs_if_emsiprxout[127], w_rx_pld_pcs_if_emsiprxout[126], w_rx_pld_pcs_if_emsiprxout[125], w_rx_pld_pcs_if_emsiprxout[124], w_rx_pld_pcs_if_emsiprxout[123], w_rx_pld_pcs_if_emsiprxout[122], w_rx_pld_pcs_if_emsiprxout[121], w_rx_pld_pcs_if_emsiprxout[120], w_rx_pld_pcs_if_emsiprxout[119], w_rx_pld_pcs_if_emsiprxout[118], w_rx_pld_pcs_if_emsiprxout[117], w_rx_pld_pcs_if_emsiprxout[116], w_rx_pld_pcs_if_emsiprxout[115], w_rx_pld_pcs_if_emsiprxout[114], w_rx_pld_pcs_if_emsiprxout[113], w_rx_pld_pcs_if_emsiprxout[112], w_rx_pld_pcs_if_emsiprxout[111], w_rx_pld_pcs_if_emsiprxout[110], w_rx_pld_pcs_if_emsiprxout[109], w_rx_pld_pcs_if_emsiprxout[108], w_rx_pld_pcs_if_emsiprxout[107], w_rx_pld_pcs_if_emsiprxout[106], w_rx_pld_pcs_if_emsiprxout[105], w_rx_pld_pcs_if_emsiprxout[104], w_rx_pld_pcs_if_emsiprxout[103], w_rx_pld_pcs_if_emsiprxout[102], w_rx_pld_pcs_if_emsiprxout[101], w_rx_pld_pcs_if_emsiprxout[100], w_rx_pld_pcs_if_emsiprxout[99], w_rx_pld_pcs_if_emsiprxout[98], w_rx_pld_pcs_if_emsiprxout[97], w_rx_pld_pcs_if_emsiprxout[96], w_rx_pld_pcs_if_emsiprxout[95], w_rx_pld_pcs_if_emsiprxout[94], w_rx_pld_pcs_if_emsiprxout[93], w_rx_pld_pcs_if_emsiprxout[92], w_rx_pld_pcs_if_emsiprxout[91], w_rx_pld_pcs_if_emsiprxout[90], w_rx_pld_pcs_if_emsiprxout[89], w_rx_pld_pcs_if_emsiprxout[88], w_rx_pld_pcs_if_emsiprxout[87], w_rx_pld_pcs_if_emsiprxout[86], w_rx_pld_pcs_if_emsiprxout[85], w_rx_pld_pcs_if_emsiprxout[84], w_rx_pld_pcs_if_emsiprxout[83], w_rx_pld_pcs_if_emsiprxout[82], w_rx_pld_pcs_if_emsiprxout[81], w_rx_pld_pcs_if_emsiprxout[80], w_rx_pld_pcs_if_emsiprxout[79], w_rx_pld_pcs_if_emsiprxout[78], w_rx_pld_pcs_if_emsiprxout[77], w_rx_pld_pcs_if_emsiprxout[76], w_rx_pld_pcs_if_emsiprxout[75], w_rx_pld_pcs_if_emsiprxout[74], w_rx_pld_pcs_if_emsiprxout[73], w_rx_pld_pcs_if_emsiprxout[72], w_rx_pld_pcs_if_emsiprxout[71], w_rx_pld_pcs_if_emsiprxout[70], w_rx_pld_pcs_if_emsiprxout[69], w_rx_pld_pcs_if_emsiprxout[68], w_rx_pld_pcs_if_emsiprxout[67], w_rx_pld_pcs_if_emsiprxout[66], w_rx_pld_pcs_if_emsiprxout[65], w_rx_pld_pcs_if_emsiprxout[64], w_rx_pld_pcs_if_emsiprxout[63], w_rx_pld_pcs_if_emsiprxout[62], w_rx_pld_pcs_if_emsiprxout[61], w_rx_pld_pcs_if_emsiprxout[60], w_rx_pld_pcs_if_emsiprxout[59], w_rx_pld_pcs_if_emsiprxout[58], w_rx_pld_pcs_if_emsiprxout[57], w_rx_pld_pcs_if_emsiprxout[56], w_rx_pld_pcs_if_emsiprxout[55], w_rx_pld_pcs_if_emsiprxout[54], w_rx_pld_pcs_if_emsiprxout[53], w_rx_pld_pcs_if_emsiprxout[52], w_rx_pld_pcs_if_emsiprxout[51], w_rx_pld_pcs_if_emsiprxout[50], w_rx_pld_pcs_if_emsiprxout[49], w_rx_pld_pcs_if_emsiprxout[48], w_rx_pld_pcs_if_emsiprxout[47], w_rx_pld_pcs_if_emsiprxout[46], w_rx_pld_pcs_if_emsiprxout[45], w_rx_pld_pcs_if_emsiprxout[44], w_rx_pld_pcs_if_emsiprxout[43], w_rx_pld_pcs_if_emsiprxout[42], w_rx_pld_pcs_if_emsiprxout[41], w_rx_pld_pcs_if_emsiprxout[40], w_rx_pld_pcs_if_emsiprxout[39], w_rx_pld_pcs_if_emsiprxout[38], w_rx_pld_pcs_if_emsiprxout[37], w_rx_pld_pcs_if_emsiprxout[36], w_rx_pld_pcs_if_emsiprxout[35], w_rx_pld_pcs_if_emsiprxout[34], w_rx_pld_pcs_if_emsiprxout[33], w_rx_pld_pcs_if_emsiprxout[32], w_rx_pld_pcs_if_emsiprxout[31], w_rx_pld_pcs_if_emsiprxout[30], w_rx_pld_pcs_if_emsiprxout[29], w_rx_pld_pcs_if_emsiprxout[28], w_rx_pld_pcs_if_emsiprxout[27], w_rx_pld_pcs_if_emsiprxout[26], w_rx_pld_pcs_if_emsiprxout[25], w_rx_pld_pcs_if_emsiprxout[24], w_rx_pld_pcs_if_emsiprxout[23], w_rx_pld_pcs_if_emsiprxout[22], w_rx_pld_pcs_if_emsiprxout[21], w_rx_pld_pcs_if_emsiprxout[20], w_rx_pld_pcs_if_emsiprxout[19], w_rx_pld_pcs_if_emsiprxout[18], w_rx_pld_pcs_if_emsiprxout[17], w_rx_pld_pcs_if_emsiprxout[16], w_rx_pld_pcs_if_emsiprxout[15], w_rx_pld_pcs_if_emsiprxout[14], w_rx_pld_pcs_if_emsiprxout[13], w_rx_pld_pcs_if_emsiprxout[12], w_rx_pld_pcs_if_emsiprxout[11], w_rx_pld_pcs_if_emsiprxout[10], w_rx_pld_pcs_if_emsiprxout[9], w_rx_pld_pcs_if_emsiprxout[8], w_rx_pld_pcs_if_emsiprxout[7], w_rx_pld_pcs_if_emsiprxout[6], w_rx_pld_pcs_if_emsiprxout[5], w_rx_pld_pcs_if_emsiprxout[4], w_rx_pld_pcs_if_emsiprxout[3], w_rx_pld_pcs_if_emsiprxout[2], w_rx_pld_pcs_if_emsiprxout[1], w_rx_pld_pcs_if_emsiprxout[0]};
		assign out_emsip_rx_special_out = {w_rx_pld_pcs_if_emsiprxspecialout[15], w_rx_pld_pcs_if_emsiprxspecialout[14], w_rx_pld_pcs_if_emsiprxspecialout[13], w_rx_pld_pcs_if_emsiprxspecialout[12], w_rx_pld_pcs_if_emsiprxspecialout[11], w_rx_pld_pcs_if_emsiprxspecialout[10], w_rx_pld_pcs_if_emsiprxspecialout[9], w_rx_pld_pcs_if_emsiprxspecialout[8], w_rx_pld_pcs_if_emsiprxspecialout[7], w_rx_pld_pcs_if_emsiprxspecialout[6], w_rx_pld_pcs_if_emsiprxspecialout[5], w_rx_pld_pcs_if_emsiprxspecialout[4], w_rx_pld_pcs_if_emsiprxspecialout[3], w_rx_pld_pcs_if_emsiprxspecialout[2], w_rx_pld_pcs_if_emsiprxspecialout[1], w_rx_pld_pcs_if_emsiprxspecialout[0]};
		assign out_emsip_tx_clk_out = {w_tx_pld_pcs_if_emsippcstxclkout[2], w_tx_pld_pcs_if_emsippcstxclkout[1], w_tx_pld_pcs_if_emsippcstxclkout[0]};
		assign out_emsip_tx_special_out = {w_tx_pld_pcs_if_emsiptxspecialout[15], w_tx_pld_pcs_if_emsiptxspecialout[14], w_tx_pld_pcs_if_emsiptxspecialout[13], w_tx_pld_pcs_if_emsiptxspecialout[12], w_tx_pld_pcs_if_emsiptxspecialout[11], w_tx_pld_pcs_if_emsiptxspecialout[10], w_tx_pld_pcs_if_emsiptxspecialout[9], w_tx_pld_pcs_if_emsiptxspecialout[8], w_tx_pld_pcs_if_emsiptxspecialout[7], w_tx_pld_pcs_if_emsiptxspecialout[6], w_tx_pld_pcs_if_emsiptxspecialout[5], w_tx_pld_pcs_if_emsiptxspecialout[4], w_tx_pld_pcs_if_emsiptxspecialout[3], w_tx_pld_pcs_if_emsiptxspecialout[2], w_tx_pld_pcs_if_emsiptxspecialout[1], w_tx_pld_pcs_if_emsiptxspecialout[0]};
		assign out_fifo_select_out_chnl_down = {w_pcs8g_tx_fifoselectoutchnldown[1], w_pcs8g_tx_fifoselectoutchnldown[0]};
		assign out_fifo_select_out_chnl_up = {w_pcs8g_tx_fifoselectoutchnlup[1], w_pcs8g_tx_fifoselectoutchnlup[0]};
		assign out_pld_8g_a1a2_k1k2_flag = {w_rx_pld_pcs_if_pld8ga1a2k1k2flag[3], w_rx_pld_pcs_if_pld8ga1a2k1k2flag[2], w_rx_pld_pcs_if_pld8ga1a2k1k2flag[1], w_rx_pld_pcs_if_pld8ga1a2k1k2flag[0]};
		assign out_pld_8g_align_status = w_rx_pld_pcs_if_pld8galignstatus;
		assign out_pld_8g_bistdone = w_rx_pld_pcs_if_pld8gbistdone;
		assign out_pld_8g_bisterr = w_rx_pld_pcs_if_pld8gbisterr;
		assign out_pld_8g_byteord_flag = w_rx_pld_pcs_if_pld8gbyteordflag;
		assign out_pld_8g_empty_rmf = w_rx_pld_pcs_if_pld8gemptyrmf;
		assign out_pld_8g_empty_rx = w_rx_pld_pcs_if_pld8gemptyrx;
		assign out_pld_8g_empty_tx = w_tx_pld_pcs_if_pld8gemptytx;
		assign out_pld_8g_full_rmf = w_rx_pld_pcs_if_pld8gfullrmf;
		assign out_pld_8g_full_rx = w_rx_pld_pcs_if_pld8gfullrx;
		assign out_pld_8g_full_tx = w_tx_pld_pcs_if_pld8gfulltx;
		assign out_pld_8g_phystatus = w_com_pld_pcs_if_pld8gphystatus;
		assign out_pld_8g_rlv_lt = w_rx_pld_pcs_if_pld8grlvlt;
		assign out_pld_8g_rx_clk_out = w_rx_pld_pcs_if_pld8grxclkout;
		assign out_pld_8g_rx_data_valid = {w_rx_pld_pcs_if_pld8grxdatavalid[3], w_rx_pld_pcs_if_pld8grxdatavalid[2], w_rx_pld_pcs_if_pld8grxdatavalid[1], w_rx_pld_pcs_if_pld8grxdatavalid[0]};
		assign out_pld_8g_rxelecidle = w_com_pld_pcs_if_pld8grxelecidle;
		assign out_pld_8g_rxstatus = {w_com_pld_pcs_if_pld8grxstatus[2], w_com_pld_pcs_if_pld8grxstatus[1], w_com_pld_pcs_if_pld8grxstatus[0]};
		assign out_pld_8g_rxvalid = w_com_pld_pcs_if_pld8grxvalid;
		assign out_pld_8g_signal_detect_out = w_rx_pld_pcs_if_pld8gsignaldetectout;
		assign out_pld_8g_tx_clk_out = w_tx_pld_pcs_if_pld8gtxclkout;
		assign out_pld_8g_wa_boundary = {w_rx_pld_pcs_if_pld8gwaboundary[4], w_rx_pld_pcs_if_pld8gwaboundary[3], w_rx_pld_pcs_if_pld8gwaboundary[2], w_rx_pld_pcs_if_pld8gwaboundary[1], w_rx_pld_pcs_if_pld8gwaboundary[0]};
		assign out_pld_clklow = w_com_pld_pcs_if_pldclklow;
		assign out_pld_fref = w_com_pld_pcs_if_pldfref;
		assign out_pld_reserved_out = {w_com_pld_pcs_if_pldreservedout[10], w_com_pld_pcs_if_pldreservedout[9], w_com_pld_pcs_if_pldreservedout[8], w_com_pld_pcs_if_pldreservedout[7], w_com_pld_pcs_if_pldreservedout[6], w_com_pld_pcs_if_pldreservedout[5], w_com_pld_pcs_if_pldreservedout[4], w_com_pld_pcs_if_pldreservedout[3], w_com_pld_pcs_if_pldreservedout[2], w_com_pld_pcs_if_pldreservedout[1], w_com_pld_pcs_if_pldreservedout[0]};
		assign out_pld_rx_data = {w_rx_pld_pcs_if_dataouttopld[63], w_rx_pld_pcs_if_dataouttopld[62], w_rx_pld_pcs_if_dataouttopld[61], w_rx_pld_pcs_if_dataouttopld[60], w_rx_pld_pcs_if_dataouttopld[59], w_rx_pld_pcs_if_dataouttopld[58], w_rx_pld_pcs_if_dataouttopld[57], w_rx_pld_pcs_if_dataouttopld[56], w_rx_pld_pcs_if_dataouttopld[55], w_rx_pld_pcs_if_dataouttopld[54], w_rx_pld_pcs_if_dataouttopld[53], w_rx_pld_pcs_if_dataouttopld[52], w_rx_pld_pcs_if_dataouttopld[51], w_rx_pld_pcs_if_dataouttopld[50], w_rx_pld_pcs_if_dataouttopld[49], w_rx_pld_pcs_if_dataouttopld[48], w_rx_pld_pcs_if_dataouttopld[47], w_rx_pld_pcs_if_dataouttopld[46], w_rx_pld_pcs_if_dataouttopld[45], w_rx_pld_pcs_if_dataouttopld[44], w_rx_pld_pcs_if_dataouttopld[43], w_rx_pld_pcs_if_dataouttopld[42], w_rx_pld_pcs_if_dataouttopld[41], w_rx_pld_pcs_if_dataouttopld[40], w_rx_pld_pcs_if_dataouttopld[39], w_rx_pld_pcs_if_dataouttopld[38], w_rx_pld_pcs_if_dataouttopld[37], w_rx_pld_pcs_if_dataouttopld[36], w_rx_pld_pcs_if_dataouttopld[35], w_rx_pld_pcs_if_dataouttopld[34], w_rx_pld_pcs_if_dataouttopld[33], w_rx_pld_pcs_if_dataouttopld[32], w_rx_pld_pcs_if_dataouttopld[31], w_rx_pld_pcs_if_dataouttopld[30], w_rx_pld_pcs_if_dataouttopld[29], w_rx_pld_pcs_if_dataouttopld[28], w_rx_pld_pcs_if_dataouttopld[27], w_rx_pld_pcs_if_dataouttopld[26], w_rx_pld_pcs_if_dataouttopld[25], w_rx_pld_pcs_if_dataouttopld[24], w_rx_pld_pcs_if_dataouttopld[23], w_rx_pld_pcs_if_dataouttopld[22], w_rx_pld_pcs_if_dataouttopld[21], w_rx_pld_pcs_if_dataouttopld[20], w_rx_pld_pcs_if_dataouttopld[19], w_rx_pld_pcs_if_dataouttopld[18], w_rx_pld_pcs_if_dataouttopld[17], w_rx_pld_pcs_if_dataouttopld[16], w_rx_pld_pcs_if_dataouttopld[15], w_rx_pld_pcs_if_dataouttopld[14], w_rx_pld_pcs_if_dataouttopld[13], w_rx_pld_pcs_if_dataouttopld[12], w_rx_pld_pcs_if_dataouttopld[11], w_rx_pld_pcs_if_dataouttopld[10], w_rx_pld_pcs_if_dataouttopld[9], w_rx_pld_pcs_if_dataouttopld[8], w_rx_pld_pcs_if_dataouttopld[7], w_rx_pld_pcs_if_dataouttopld[6], w_rx_pld_pcs_if_dataouttopld[5], w_rx_pld_pcs_if_dataouttopld[4], w_rx_pld_pcs_if_dataouttopld[3], w_rx_pld_pcs_if_dataouttopld[2], w_rx_pld_pcs_if_dataouttopld[1], w_rx_pld_pcs_if_dataouttopld[0]};
		assign out_pld_test_data = {w_com_pld_pcs_if_pldtestdata[19], w_com_pld_pcs_if_pldtestdata[18], w_com_pld_pcs_if_pldtestdata[17], w_com_pld_pcs_if_pldtestdata[16], w_com_pld_pcs_if_pldtestdata[15], w_com_pld_pcs_if_pldtestdata[14], w_com_pld_pcs_if_pldtestdata[13], w_com_pld_pcs_if_pldtestdata[12], w_com_pld_pcs_if_pldtestdata[11], w_com_pld_pcs_if_pldtestdata[10], w_com_pld_pcs_if_pldtestdata[9], w_com_pld_pcs_if_pldtestdata[8], w_com_pld_pcs_if_pldtestdata[7], w_com_pld_pcs_if_pldtestdata[6], w_com_pld_pcs_if_pldtestdata[5], w_com_pld_pcs_if_pldtestdata[4], w_com_pld_pcs_if_pldtestdata[3], w_com_pld_pcs_if_pldtestdata[2], w_com_pld_pcs_if_pldtestdata[1], w_com_pld_pcs_if_pldtestdata[0]};
		assign out_pld_test_si_to_agg_out = w_com_pcs_pma_if_pldtestsitoaggout;
		assign out_pma_current_coeff = {w_com_pcs_pma_if_pmacurrentcoeff[17], w_com_pcs_pma_if_pmacurrentcoeff[16], w_com_pcs_pma_if_pmacurrentcoeff[15], w_com_pcs_pma_if_pmacurrentcoeff[14], w_com_pcs_pma_if_pmacurrentcoeff[13], w_com_pcs_pma_if_pmacurrentcoeff[12], w_com_pcs_pma_if_pmacurrentcoeff[11], w_com_pcs_pma_if_pmacurrentcoeff[10], w_com_pcs_pma_if_pmacurrentcoeff[9], w_com_pcs_pma_if_pmacurrentcoeff[8], w_com_pcs_pma_if_pmacurrentcoeff[7], w_com_pcs_pma_if_pmacurrentcoeff[6]};
		assign out_pma_early_eios = w_com_pcs_pma_if_pmaearlyeios;
		assign out_pma_ltr = w_com_pcs_pma_if_pmaltr;
		assign out_pma_nfrzdrv = w_com_pcs_pma_if_pmanfrzdrv;
		assign out_pma_partial_reconfig = w_com_pcs_pma_if_pmapartialreconfig;
		assign out_pma_pcie_switch = w_com_pcs_pma_if_pmapcieswitch[0];
		assign out_pma_ppm_lock = w_com_pcs_pma_if_freqlock;
		assign out_pma_reserved_out = {w_rx_pcs_pma_if_pmareservedout[4], w_rx_pcs_pma_if_pmareservedout[3], w_rx_pcs_pma_if_pmareservedout[2], w_rx_pcs_pma_if_pmareservedout[1], w_rx_pcs_pma_if_pmareservedout[0]};
		assign out_pma_rx_clk_out = w_rx_pcs_pma_if_pmarxclkout;
		assign out_pma_rxclkslip = w_rx_pcs_pma_if_pmarxclkslip;
		assign out_pma_rxpma_rstb = w_rx_pcs_pma_if_pmarxpmarstb;
		assign out_pma_tx_clk_out = w_tx_pcs_pma_if_pmatxclkout;
		assign out_pma_tx_data = {w_tx_pcs_pma_if_dataouttopma[19], w_tx_pcs_pma_if_dataouttopma[18], w_tx_pcs_pma_if_dataouttopma[17], w_tx_pcs_pma_if_dataouttopma[16], w_tx_pcs_pma_if_dataouttopma[15], w_tx_pcs_pma_if_dataouttopma[14], w_tx_pcs_pma_if_dataouttopma[13], w_tx_pcs_pma_if_dataouttopma[12], w_tx_pcs_pma_if_dataouttopma[11], w_tx_pcs_pma_if_dataouttopma[10], w_tx_pcs_pma_if_dataouttopma[9], w_tx_pcs_pma_if_dataouttopma[8], w_tx_pcs_pma_if_dataouttopma[7], w_tx_pcs_pma_if_dataouttopma[6], w_tx_pcs_pma_if_dataouttopma[5], w_tx_pcs_pma_if_dataouttopma[4], w_tx_pcs_pma_if_dataouttopma[3], w_tx_pcs_pma_if_dataouttopma[2], w_tx_pcs_pma_if_dataouttopma[1], w_tx_pcs_pma_if_dataouttopma[0]};
		assign out_pma_tx_elec_idle = w_com_pcs_pma_if_pmatxelecidle;
		assign out_pma_txdetectrx = w_com_pcs_pma_if_pmatxdetectrx;
		assign out_reset_pc_ptrs_out_chnl_down = w_pcs8g_rx_resetpcptrsoutchnldown;
		assign out_reset_pc_ptrs_out_chnl_up = w_pcs8g_rx_resetpcptrsoutchnlup;
		assign out_reset_ppm_cntrs_out_chnl_down = w_pcs8g_rx_resetppmcntrsoutchnldown;
		assign out_reset_ppm_cntrs_out_chnl_up = w_pcs8g_rx_resetppmcntrsoutchnlup;
		assign out_rx_div_sync_out_chnl_down = {w_pcs8g_rx_rxdivsyncoutchnldown[1], w_pcs8g_rx_rxdivsyncoutchnldown[0]};
		assign out_rx_div_sync_out_chnl_up = {w_pcs8g_rx_rxdivsyncoutchnlup[1], w_pcs8g_rx_rxdivsyncoutchnlup[0]};
		assign out_rx_rd_enable_out_chnl_down = w_pcs8g_rx_rdenableoutchnldown;
		assign out_rx_rd_enable_out_chnl_up = w_pcs8g_rx_rdenableoutchnlup;
		assign out_rx_we_out_chnl_down = {w_pcs8g_rx_rxweoutchnldown[1], w_pcs8g_rx_rxweoutchnldown[0]};
		assign out_rx_we_out_chnl_up = {w_pcs8g_rx_rxweoutchnlup[1], w_pcs8g_rx_rxweoutchnlup[0]};
		assign out_rx_wr_enable_out_chnl_down = w_pcs8g_rx_wrenableoutchnldown;
		assign out_rx_wr_enable_out_chnl_up = w_pcs8g_rx_wrenableoutchnlup;
		assign out_speed_change_out_chnl_down = w_pcs8g_rx_speedchangeoutchnldown;
		assign out_speed_change_out_chnl_up = w_pcs8g_rx_speedchangeoutchnlup;
		assign out_tx_div_sync_out_chnl_down = {w_pcs8g_tx_txdivsyncoutchnldown[1], w_pcs8g_tx_txdivsyncoutchnldown[0]};
		assign out_tx_div_sync_out_chnl_up = {w_pcs8g_tx_txdivsyncoutchnlup[1], w_pcs8g_tx_txdivsyncoutchnlup[0]};
		assign out_tx_rd_enable_out_chnl_down = w_pcs8g_tx_rdenableoutchnldown;
		assign out_tx_rd_enable_out_chnl_up = w_pcs8g_tx_rdenableoutchnlup;
		assign out_tx_wr_enable_out_chnl_down = w_pcs8g_tx_wrenableoutchnldown;
		assign out_tx_wr_enable_out_chnl_up = w_pcs8g_tx_wrenableoutchnlup | wirehack;
	endgenerate
endmodule
