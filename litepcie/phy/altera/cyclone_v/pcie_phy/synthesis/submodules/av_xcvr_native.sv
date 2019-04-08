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


`timescale 1ps/1ps
import altera_xcvr_functions::*;

module av_xcvr_native #(
        parameter device_family                  = "Arria V",
    // av_pma parameters
        parameter rx_enable                      = 1,                   // (1,0) Enable or disable reciever PMA
        parameter tx_enable                      = 1,                   // (1,0) Enable or disable transmitter PMA
        parameter bonding_master_ch              = 0,                   // Indicates which channel is master
        parameter pma_bonding_master             = "0",                 // (List i.e. "0,3,..."), Indicates which channels is master
        parameter bonding_master_only            = "-1",                // Indicates bonding_master_channel is MASTER_ONLY
        parameter channel_number                 = 0,                   //
        parameter plls                           = 1,                   // (1+) Number of high-speed serial clocks from TX plls (tx_ser_clk)
        parameter pll_sel                        = 0,                   // (0 - plls-1) // Which PLL clock to use
        parameter pma_prot_mode                  = "basic",             // (basic,cpri,cpri_rx_tx,disabled_prot_mode,gige, pipe_g1,pipe_g2,srio_2p1,test,xaui)
        parameter pma_mode                       = 8,                   // (8,10,16,20,32,40,64,80) Serialization factor
		parameter base_data_rate                 = "1250000000 bps",    // Base data rate for CGB
        parameter pma_data_rate                  = "1250000000 bps",    // Serial data rate in bits-per-second
        parameter cdr_reconfig                   = 0,                   // 1-Enable CDR reconfiguration, 0-Disable CDR reconfiguration
        parameter cdr_reference_clock_frequency  = "100 Mhz",
	parameter cdr_refclk_cnt                 = 1,                   // # of CDR reference clocks
        parameter cdr_refclk_sel                 = 0,                   // Initial CDR reference clock selection
        parameter deser_enable_bit_slip          = "false",
        parameter auto_negotiation               = "<auto_single>",     // ("true","false") PCIe Auto-Negotiation (Gen1,2,3)
        parameter tx_clk_div                     = 1,                   // (1,2,4,8)
        parameter pcie_rst                       = "normal_reset",
        parameter fref_vco_bypass                = "NORMAL_OPERATION",
        parameter sd_on                          = 16,
        parameter pdb_sd                         = "true",
        parameter pma_bonding_mode               = "x1",                // valid value "x1", "xN"
	parameter external_master_cgb            = 0,

    // av_pcs parameters
        parameter enable_8g_rx                   = "true",
        parameter enable_8g_tx                   = "true",
        parameter enable_dyn_reconfig            = "true",
        parameter enable_gen12_pipe              = "true",
 
    // Adding new parameter for PMA Direct
        parameter enable_pma_direct_rx           = "false",             // (true,false) Enable, disable the PMA Direct path
        parameter enable_pma_direct_tx           = "false",             // (true,false) Enable, disable the PMA Direct path
    // parameters for arriav_hssi_8g_rx_pcs
        parameter pcs8g_rx_agg_block_sel         = "<auto_single>",     // same_smrt_pack|other_smrt_pack
        parameter pcs8g_rx_auto_error_replacement = "<auto_single>",    // dis_err_replace|en_err_replace
        parameter pcs8g_rx_auto_speed_nego       = "<auto_single>",     // dis_asn|en_asn_g2_freq_scal
        parameter pcs8g_rx_bist_ver              = "<auto_single>",     // dis_bist|incremental|cjpat|crpat
        parameter pcs8g_rx_bist_ver_clr_flag     = "<auto_single>",     // dis_bist_clr_flag|en_bist_clr_flag
        parameter pcs8g_rx_bit_reversal          = "<auto_single>",     // dis_bit_reversal|en_bit_reversal
        parameter pcs8g_rx_bo_pad                = 10'b0,
        parameter pcs8g_rx_bo_pattern            = 20'b0,
        parameter pcs8g_rx_bypass_pipeline_reg   = "<auto_single>",     // dis_bypass_pipeline|en_bypass_pipeline
        parameter pcs8g_rx_byte_deserializer     = "<auto_single>",     // dis_bds|en_bds_by_2|en_bds_by_2_det
        parameter pcs8g_rx_byte_order            = "<auto_single>",     // dis_bo|en_pcs_ctrl_eight_bit_bo|en_pcs_ctrl_nine_bit_bo|en_pcs_ctrl_ten_bit_bo|en_pld_ctrl_eight_bit_bo|en_pld_ctrl_nine_bit_bo|en_pld_ctrl_ten_bit_bo
        parameter pcs8g_rx_cdr_ctrl              = "<auto_single>",     // dis_cdr_ctrl|en_cdr_ctrl|en_cdr_ctrl_w_cid
        parameter pcs8g_rx_cdr_ctrl_rxvalid_mask = "<auto_single>",     // dis_rxvalid_mask|en_rxvalid_mask
        parameter pcs8g_rx_cid_pattern           = "<auto_single>",     // cid_pattern_0|cid_pattern_1
        parameter pcs8g_rx_cid_pattern_len       = 8'b0,
        parameter pcs8g_rx_clkcmp_pattern_n      = 20'b0,
        parameter pcs8g_rx_clkcmp_pattern_p      = 20'b0,
        parameter pcs8g_rx_clock_gate_bds_dec_asn = "<auto_single>",    // dis_bds_dec_asn_clk_gating|en_bds_dec_asn_clk_gating
        parameter pcs8g_rx_clock_gate_bist       = "<auto_single>",     // dis_bist_clk_gating|en_bist_clk_gating
        parameter pcs8g_rx_clock_gate_byteorder  = "<auto_single>",     // dis_byteorder_clk_gating|en_byteorder_clk_gating
        parameter pcs8g_rx_clock_gate_cdr_eidle  = "<auto_single>",     // dis_cdr_eidle_clk_gating|en_cdr_eidle_clk_gating
        parameter pcs8g_rx_clock_gate_dskw_rd    = "<auto_single>",     // dis_dskw_rdclk_gating|en_dskw_rdclk_gating
        parameter pcs8g_rx_clock_gate_dw_dskw_wr = "<auto_single>",     // dis_dw_dskw_wrclk_gating|en_dw_dskw_wrclk_gating
        parameter pcs8g_rx_clock_gate_dw_pc_wrclk = "<auto_single>",    // dis_dw_pc_wrclk_gating|en_dw_pc_wrclk_gating
        parameter pcs8g_rx_clock_gate_dw_rm_rd   = "<auto_single>",     // dis_dw_rm_rdclk_gating|en_dw_rm_rdclk_gating
        parameter pcs8g_rx_clock_gate_dw_rm_wr   = "<auto_single>",     // dis_dw_rm_wrclk_gating|en_dw_rm_wrclk_gating
        parameter pcs8g_rx_clock_gate_dw_wa      = "<auto_single>",     // dis_dw_wa_clk_gating|en_dw_wa_clk_gating
        parameter pcs8g_rx_clock_gate_pc_rdclk   = "<auto_single>",     // dis_pc_rdclk_gating|en_pc_rdclk_gating
        parameter pcs8g_rx_clock_gate_prbs       = "<auto_single>",     // dis_prbs_clk_gating|en_prbs_clk_gating
        parameter pcs8g_rx_clock_gate_sw_dskw_wr = "<auto_single>",     // dis_sw_dskw_wrclk_gating|en_sw_dskw_wrclk_gating
        parameter pcs8g_rx_clock_gate_sw_pc_wrclk = "<auto_single>",    // dis_sw_pc_wrclk_gating|en_sw_pc_wrclk_gating
        parameter pcs8g_rx_clock_gate_sw_rm_rd   = "<auto_single>",     // dis_sw_rm_rdclk_gating|en_sw_rm_rdclk_gating
        parameter pcs8g_rx_clock_gate_sw_rm_wr   = "<auto_single>",     // dis_sw_rm_wrclk_gating|en_sw_rm_wrclk_gating
        parameter pcs8g_rx_clock_gate_sw_wa      = "<auto_single>",     // dis_sw_wa_clk_gating|en_sw_wa_clk_gating
        parameter pcs8g_rx_comp_fifo_rst_pld_ctrl = "<auto_single>",    // dis_comp_fifo_rst_pld_ctrl|en_comp_fifo_rst_pld_ctrl
        parameter pcs8g_rx_deskew                = "<auto_single>",     // dis_deskew|en_srio_v2p1|en_xaui
        parameter pcs8g_rx_deskew_pattern        = 10'b1101101000,
        parameter pcs8g_rx_deskew_prog_pattern_only = "<auto_single>",  // dis_deskew_prog_pat_only|en_deskew_prog_pat_only
        parameter pcs8g_rx_dw_one_or_two_symbol_bo = "<auto_single>",   // donot_care_one_two_bo|one_symbol_bo|two_symbol_bo_eight_bit|two_symbol_bo_nine_bit|two_symbol_bo_ten_bit
        parameter pcs8g_rx_eidle_entry_eios      = "<auto_single>",     // dis_eidle_eios|en_eidle_eios
        parameter pcs8g_rx_eidle_entry_iei       = "<auto_single>",     // dis_eidle_iei|en_eidle_iei
        parameter pcs8g_rx_eidle_entry_sd        = "<auto_single>",     // dis_eidle_sd|en_eidle_sd
        parameter pcs8g_rx_eightb_tenb_decoder   = "<auto_single>",     // dis_8b10b|en_8b10b_ibm|en_8b10b_sgx
        parameter pcs8g_rx_eightbtenb_decoder_output_sel = "<auto_single>",// data_8b10b_decoder|data_xaui_sm
        parameter pcs8g_rx_err_flags_sel         = "<auto_single>",     // err_flags_wa|err_flags_8b10b
        parameter pcs8g_rx_fixed_pat_det         = "<auto_single>",     // dis_fixed_patdet|en_fixed_patdet
        parameter pcs8g_rx_fixed_pat_num         = 4'b1111,
        parameter pcs8g_rx_force_signal_detect   = "<auto_single>",     // en_force_signal_detect|dis_force_signal_detect
        parameter pcs8g_rx_hip_mode              = "<auto_single>",     // dis_hip|en_hip
        parameter pcs8g_rx_ibm_invalid_code      = "<auto_single>",     // dis_ibm_invalid_code|en_ibm_invalid_code
        parameter pcs8g_rx_invalid_code_flag_only = "<auto_single>",    // dis_invalid_code_only|en_invalid_code_only
        parameter pcs8g_rx_mask_cnt              = 10'h3ff,
        parameter pcs8g_rx_pad_or_edb_error_replace = "<auto_single>",  // replace_edb|replace_pad|replace_edb_dynamic
        parameter pcs8g_rx_pc_fifo_rst_pld_ctrl  = "<auto_single>",     // dis_pc_fifo_rst_pld_ctrl|en_pc_fifo_rst_pld_ctrl
        parameter pcs8g_rx_pcs_bypass            = "<auto_single>",     // dis_pcs_bypass|en_pcs_bypass
        parameter pcs8g_rx_phase_compensation_fifo = "<auto_single>",   // low_latency|normal_latency|register_fifo|pld_ctrl_low_latency|pld_ctrl_normal_latency
        parameter pcs8g_rx_pipe_if_enable        = "<auto_single>",     // dis_pipe_rx|en_pipe_rx
        parameter pcs8g_rx_pma_done_count        = 18'b0,
        parameter pcs8g_rx_pma_dw                = "<auto_single>",     // eight_bit|ten_bit|sixteen_bit|twenty_bit
        parameter pcs8g_rx_polarity_inversion    = "<auto_single>",     // dis_pol_inv|en_pol_inv
        parameter pcs8g_rx_polinv_8b10b_dec      = "<auto_single>",     // dis_polinv_8b10b_dec|en_polinv_8b10b_dec
        parameter pcs8g_rx_prbs_ver              = "<auto_single>",     // dis_prbs|prbs_7_sw|prbs_7_dw|prbs_8|prbs_10|prbs_23_sw|prbs_23_dw|prbs_15|prbs_31|prbs_hf_sw|prbs_hf_dw|prbs_lf_sw|prbs_lf_dw|prbs_mf_sw|prbs_mf_dw
        parameter pcs8g_rx_prbs_ver_clr_flag     = "<auto_single>",     // dis_prbs_clr_flag|en_prbs_clr_flag
        parameter pcs8g_rx_prot_mode             = "<auto_single>",     // pipe_g1|pipe_g2|cpri|cpri_rx_tx|gige|xaui|srio_2p1|test|basic|disabled_prot_mode
        parameter pcs8g_rx_rate_match            = "<auto_single>",     // dis_rm|xaui_rm|gige_rm|pipe_rm|pipe_rm_0ppm|sw_basic_rm|srio_v2p1_rm|srio_v2p1_rm_0ppm|dw_basic_rm
        parameter pcs8g_rx_re_bo_on_wa           = "<auto_single>",     // dis_re_bo_on_wa|en_re_bo_on_wa
        parameter pcs8g_rx_runlength_check       = "<auto_single>",     // dis_runlength|en_runlength_sw|en_runlength_dw
        parameter pcs8g_rx_runlength_val         = 6'b0,
        parameter pcs8g_rx_rx_clk1               = "<auto_single>",     // rcvd_clk_clk1|tx_pma_clock_clk1|rcvd_clk_agg_clk1|rcvd_clk_agg_top_or_bottom_clk1
        parameter pcs8g_rx_rx_clk2               = "<auto_single>",     // rcvd_clk_clk2|tx_pma_clock_clk2|refclk_dig2_clk2
        parameter pcs8g_rx_rx_clk_free_running   = "<auto_single>",     // dis_rx_clk_free_run|en_rx_clk_free_run
        parameter pcs8g_rx_rx_pcs_urst           = "<auto_single>",     // dis_rx_pcs_urst|en_rx_pcs_urst
        parameter pcs8g_rx_rx_rcvd_clk           = "<auto_single>",     // rcvd_clk_rcvd_clk|tx_pma_clock_rcvd_clk
        parameter pcs8g_rx_rx_rd_clk             = "<auto_single>",     // pld_rx_clk|rx_clk
        parameter pcs8g_rx_rx_refclk             = "<auto_single>",     // dis_refclk_sel|en_refclk_sel
        parameter pcs8g_rx_rx_wr_clk             = "<auto_single>",     // rx_clk2_div_1_2_4|txfifo_rd_clk
        parameter pcs8g_rx_sup_mode              = "<auto_single>",     // user_mode|engineering_mode
        parameter pcs8g_rx_symbol_swap           = "<auto_single>",     // dis_symbol_swap|en_symbol_swap
        parameter pcs8g_rx_test_bus_sel          = "<auto_single>",     // prbs_bist_testbus|tx_testbus|tx_ctrl_plane_testbus|wa_testbus|deskew_testbus|rm_testbus|rx_ctrl_testbus|pcie_ctrl_testbus|rx_ctrl_plane_testbus|agg_testbus
        parameter pcs8g_rx_test_mode             = "<auto_single>",     // dont_care_test|prbs|bist
        parameter pcs8g_rx_tx_rx_parallel_loopback = "<auto_single>",   // dis_plpbk|en_plpbk
        parameter pcs8g_rx_use_default_base_address = "true",           // false|true
        parameter pcs8g_rx_user_base_address     = 0,                   // 0..2047
        parameter pcs8g_rx_wa_boundary_lock_ctrl = "<auto_single>",     // bit_slip|sync_sm|deterministic_latency|auto_align_pld_ctrl
        parameter pcs8g_rx_wa_clk_slip_spacing   = "<auto_single>",     // min_clk_slip_spacing|user_programmable_clk_slip_spacing
        parameter pcs8g_rx_wa_clk_slip_spacing_data = 10'b10000,
        parameter pcs8g_rx_wa_det_latency_sync_status_beh = "<auto_single>",// assert_sync_status_imm|assert_sync_status_non_imm|dont_care_assert_sync
        parameter pcs8g_rx_wa_disp_err_flag      = "<auto_single>",     // dis_disp_err_flag|en_disp_err_flag
        parameter pcs8g_rx_wa_kchar              = "<auto_single>",     // dis_kchar|en_kchar
        parameter pcs8g_rx_wa_pd                 = "<auto_single>",     // dont_care_wa_pd_0|dont_care_wa_pd_1|wa_pd_7|wa_pd_10|wa_pd_20|wa_pd_40|wa_pd_8_sw|wa_pd_8_dw|wa_pd_16_sw|wa_pd_16_dw|wa_pd_32|wa_pd_fixed_7_k28p5|wa_pd_fixed_10_k28p5|wa_pd_fixed_16_a1a2_sw|wa_pd_fixed_16_a1a2_dw|wa_pd_fixed_32_a1a1a2a2|prbs15_fixed_wa_pd_16_sw|prbs15_fixed_wa_pd_16_dw|prbs15_fixed_wa_pd_20_dw|prbs31_fixed_wa_pd_16_sw|prbs31_fixed_wa_pd_16_dw|prbs31_fixed_wa_pd_10_sw|prbs31_fixed_wa_pd_40_dw|prbs8_fixed_wa|prbs10_fixed_wa|prbs7_fixed_wa_pd_16_sw|prbs7_fixed_wa_pd_16_dw|prbs7_fixed_wa_pd_20_dw|prbs23_fixed_wa_pd_16_sw|prbs23_fixed_wa_pd_32_dw|prbs23_fixed_wa_pd_40_dw
        parameter pcs8g_rx_wa_pd_data            = 40'b0,
        parameter pcs8g_rx_wa_pd_polarity        = "<auto_single>",     // dis_pd_both_pol|en_pd_both_pol|dont_care_both_pol
        parameter pcs8g_rx_wa_pld_controlled     = "<auto_single>",     // dis_pld_ctrl|pld_ctrl_sw|rising_edge_sensitive_dw|level_sensitive_dw
        parameter pcs8g_rx_wa_renumber_data      = 6'b0,
        parameter pcs8g_rx_wa_rgnumber_data      = 8'b0,
        parameter pcs8g_rx_wa_rknumber_data      = 8'b0,
        parameter pcs8g_rx_wa_rosnumber_data     = 2'b0,
        parameter pcs8g_rx_wa_rvnumber_data      = 13'b0,
        parameter pcs8g_rx_wa_sync_sm_ctrl       = "<auto_single>",     // gige_sync_sm|pipe_sync_sm|xaui_sync_sm|srio1p3_sync_sm|srio2p1_sync_sm|sw_basic_sync_sm|dw_basic_sync_sm|fibre_channel_sync_sm
        parameter pcs8g_rx_wait_cnt              = 8'b0,
    // parameters for arriav_hssi_8g_tx_pcs
        parameter pcs8g_tx_agg_block_sel         = "<auto_single>",     // same_smrt_pack|other_smrt_pack
        parameter pcs8g_tx_auto_speed_nego_gen2  = "<auto_single>",     // dis_asn_g2|en_asn_g2_freq_scal
        parameter pcs8g_tx_bist_gen              = "<auto_single>",     // dis_bist|incremental|cjpat|crpat
        parameter pcs8g_tx_bit_reversal          = "<auto_single>",     // dis_bit_reversal|en_bit_reversal
        parameter pcs8g_tx_bypass_pipeline_reg   = "<auto_single>",     // dis_bypass_pipeline|en_bypass_pipeline
        parameter pcs8g_tx_byte_serializer       = "<auto_single>",     // dis_bs|en_bs_by_2
        parameter pcs8g_tx_cid_pattern           = "<auto_single>",     // cid_pattern_0|cid_pattern_1
        parameter pcs8g_tx_cid_pattern_len       = 8'b0,
        parameter pcs8g_tx_clock_gate_bist       = "<auto_single>",     // dis_bist_clk_gating|en_bist_clk_gating
        parameter pcs8g_tx_clock_gate_bs_enc     = "<auto_single>",     // dis_bs_enc_clk_gating|en_bs_enc_clk_gating
        parameter pcs8g_tx_clock_gate_dw_fifowr  = "<auto_single>",     // dis_dw_fifowr_clk_gating|en_dw_fifowr_clk_gating
        parameter pcs8g_tx_clock_gate_fiford     = "<auto_single>",     // dis_fiford_clk_gating|en_fiford_clk_gating
        parameter pcs8g_tx_clock_gate_prbs       = "<auto_single>",     // dis_prbs_clk_gating|en_prbs_clk_gating
        parameter pcs8g_tx_clock_gate_sw_fifowr  = "<auto_single>",     // dis_sw_fifowr_clk_gating|en_sw_fifowr_clk_gating
        parameter pcs8g_tx_data_selection_8b10b_encoder_input = "<auto_single>",// normal_data_path|xaui_sm|gige_idle_conversion
        parameter pcs8g_tx_dynamic_clk_switch    = "<auto_single>",     // dis_dyn_clk_switch|en_dyn_clk_switch
        parameter pcs8g_tx_eightb_tenb_disp_ctrl = "<auto_single>",     // dis_disp_ctrl|en_disp_ctrl|en_ib_disp_ctrl
        parameter pcs8g_tx_eightb_tenb_encoder   = "<auto_single>",     // dis_8b10b|en_8b10b_ibm|en_8b10b_sgx
        parameter pcs8g_tx_force_echar           = "<auto_single>",     // dis_force_echar|en_force_echar
        parameter pcs8g_tx_force_kchar           = "<auto_single>",     // dis_force_kchar|en_force_kchar
        parameter pcs8g_tx_hip_mode              = "<auto_single>",     // dis_hip|en_hip
        parameter pcs8g_tx_pcfifo_urst           = "<auto_single>",     // dis_pcfifourst|en_pcfifourst
        parameter pcs8g_tx_pcs_bypass            = "<auto_single>",     // dis_pcs_bypass|en_pcs_bypass
        parameter pcs8g_tx_phase_compensation_fifo = "<auto_single>",   // low_latency|normal_latency|register_fifo|pld_ctrl_low_latency|pld_ctrl_normal_latency
        parameter pcs8g_tx_phfifo_write_clk_sel  = "<auto_single>",     // pld_tx_clk|tx_clk
        parameter pcs8g_tx_pma_dw                = "<auto_single>",     // eight_bit|ten_bit|sixteen_bit|twenty_bit
        parameter pcs8g_tx_polarity_inversion    = "<auto_single>",     // dis_polinv|enable_polinv
        parameter pcs8g_tx_prbs_gen              = "<auto_single>",     // dis_prbs|prbs_7_sw|prbs_7_dw|prbs_8|prbs_10|prbs_23_sw|prbs_23_dw|prbs_15|prbs_31|prbs_hf_sw|prbs_hf_dw|prbs_lf_sw|prbs_lf_dw|prbs_mf_sw|prbs_mf_dw
        parameter pcs8g_tx_prot_mode             = "<auto_single>",     // pipe_g1|pipe_g2|cpri|cpri_rx_tx|gige|xaui|srio_2p1|test|basic|disabled_prot_mode
        parameter pcs8g_tx_refclk_b_clk_sel      = "<auto_single>",     // tx_pma_clock|refclk_dig
        parameter pcs8g_tx_revloop_back_rm       = "<auto_single>",     // dis_rev_loopback_rx_rm|en_rev_loopback_rx_rm
        parameter pcs8g_tx_sup_mode              = "<auto_single>",     // user_mode|engineering_mode
        parameter pcs8g_tx_symbol_swap           = "<auto_single>",     // dis_symbol_swap|en_symbol_swap
        parameter pcs8g_tx_test_mode             = "<auto_single>",     // dont_care_test|prbs|bist
        parameter pcs8g_tx_tx_bitslip            = "<auto_single>",     // dis_tx_bitslip|en_tx_bitslip
        parameter pcs8g_tx_tx_compliance_controlled_disparity = "<auto_single>",// dis_txcompliance|en_txcompliance_pipe2p0
        parameter pcs8g_tx_txclk_freerun         = "<auto_single>",     // dis_freerun_tx|en_freerun_tx
        parameter pcs8g_tx_txpcs_urst            = "<auto_single>",     // dis_txpcs_urst|en_txpcs_urst
        parameter pcs8g_tx_use_default_base_address = "true",           // false|true
        parameter pcs8g_tx_user_base_address     = 0,                   // 0..2047
    // parameters for arriav_hssi_common_pcs_pma_interface
        parameter com_pcs_pma_if_auto_speed_ena  = "<auto_single>",     // dis_auto_speed_ena|en_auto_speed_ena
        parameter com_pcs_pma_if_force_freqdet   = "<auto_single>",     // force_freqdet_dis|force1_freqdet_en|force0_freqdet_en
        parameter com_pcs_pma_if_func_mode       = "<auto_single>",     // disable|hrdrstctrl_cmu|eightg_only_pld|eightg_only_hip|pma_direct
        parameter com_pcs_pma_if_pipe_if_g3pcs   = "<auto_single>",     // pipe_if_8gpcs
        parameter com_pcs_pma_if_pma_if_dft_en   = "dft_dis",           // dft_dis
        parameter com_pcs_pma_if_pma_if_dft_val  = "dft_0",             // dft_0
        parameter com_pcs_pma_if_ppm_cnt_rst     = "<auto_single>",     // ppm_cnt_rst_dis|ppm_cnt_rst_en
        parameter com_pcs_pma_if_ppm_deassert_early = "<auto_single>",  // deassert_early_dis|deassert_early_en
        parameter com_pcs_pma_if_ppm_gen1_2_cnt  = "<auto_single>",     // cnt_32k|cnt_64k
        parameter com_pcs_pma_if_ppm_post_eidle_delay = "<auto_single>",// cnt_200_cycles|cnt_400_cycles
        parameter com_pcs_pma_if_ppmsel          = "<auto_single>",     // ppmsel_default|ppmsel_1000|ppmsel_500|ppmsel_300|ppmsel_250|ppmsel_200|ppmsel_125|ppmsel_100|ppmsel_62p5|ppm_other
        parameter com_pcs_pma_if_prot_mode       = "<auto_single>",     // disabled_prot_mode|pipe_g1|pipe_g2|other_protocols
        parameter com_pcs_pma_if_selectpcs       = "<auto_single>",     // eight_g_pcs
        parameter com_pcs_pma_if_sup_mode        = "<auto_single>",     // user_mode|engineering_mode
        parameter com_pcs_pma_if_use_default_base_address = "true",     // false|true
        parameter com_pcs_pma_if_user_base_address = 0,                 // 0..2047
    // parameters for arriav_hssi_common_pld_pcs_interface
        parameter com_pld_pcs_if_hip_enable      = "hip_disable",       // hip_disable|hip_enable
        parameter com_pld_pcs_if_hrdrstctrl_en_cfg = "hrst_dis_cfg",    // hrst_dis_cfg|hrst_en_cfg
        parameter com_pld_pcs_if_hrdrstctrl_en_cfgusr = "hrst_dis_cfgusr",// hrst_dis_cfgusr|hrst_en_cfgusr
        parameter com_pld_pcs_if_pld_side_data_source = "pld",          // hip|pld
        parameter com_pld_pcs_if_pld_side_reserved_source0 = "pld_res0",// pld_res0|hip_res0
        parameter com_pld_pcs_if_pld_side_reserved_source1 = "pld_res1",// pld_res1|hip_res1
        parameter com_pld_pcs_if_pld_side_reserved_source10 = "pld_res10",// pld_res10|hip_res10
        parameter com_pld_pcs_if_pld_side_reserved_source11 = "pld_res11",// pld_res11|hip_res11
        parameter com_pld_pcs_if_pld_side_reserved_source2 = "pld_res2",// pld_res2|hip_res2
        parameter com_pld_pcs_if_pld_side_reserved_source3 = "pld_res3",// pld_res3|hip_res3
        parameter com_pld_pcs_if_pld_side_reserved_source4 = "pld_res4",// pld_res4|hip_res4
        parameter com_pld_pcs_if_pld_side_reserved_source5 = "pld_res5",// pld_res5|hip_res5
        parameter com_pld_pcs_if_pld_side_reserved_source6 = "pld_res6",// pld_res6|hip_res6
        parameter com_pld_pcs_if_pld_side_reserved_source7 = "pld_res7",// pld_res7|hip_res7
        parameter com_pld_pcs_if_pld_side_reserved_source8 = "pld_res8",// pld_res8|hip_res8
        parameter com_pld_pcs_if_pld_side_reserved_source9 = "pld_res9",// pld_res9|hip_res9
        parameter com_pld_pcs_if_testbus_sel     = "eight_g_pcs",       // eight_g_pcs|pma_if
        parameter com_pld_pcs_if_use_default_base_address = "true",     // false|true
        parameter com_pld_pcs_if_user_base_address = 0,                 // 0..2047
        parameter com_pld_pcs_if_usrmode_sel4rst = "usermode",          // usermode|last_frz
    // parameters for arriav_hssi_pipe_gen1_2
        parameter pipe12_elec_idle_delay_val     = 3'b0,
        parameter pipe12_elecidle_delay          = "elec_idle_delay",   // elec_idle_delay
        parameter pipe12_error_replace_pad       = "<auto_single>",     // replace_edb|replace_pad
        parameter pipe12_hip_mode                = "<auto_single>",     // dis_hip|en_hip
        parameter pipe12_ind_error_reporting     = "<auto_single>",     // dis_ind_error_reporting|en_ind_error_reporting
        parameter pipe12_phy_status_delay        = "phystatus_delay",   // phystatus_delay
        parameter pipe12_phystatus_delay_val     = 3'b0,
        parameter pipe12_phystatus_rst_toggle    = "<auto_single>",     // dis_phystatus_rst_toggle|en_phystatus_rst_toggle
        parameter pipe12_pipe_byte_de_serializer_en = "<auto_single>",  // dis_bds|en_bds_by_2|dont_care_bds
        parameter pipe12_prot_mode               = "<auto_single>",     // pipe_g1|pipe_g2|srio_2p1|basic|disabled_prot_mode
        parameter pipe12_rpre_emph_a_val         = 6'b0,
        parameter pipe12_rpre_emph_b_val         = 6'b0,
        parameter pipe12_rpre_emph_c_val         = 6'b0,
        parameter pipe12_rpre_emph_d_val         = 6'b0,
        parameter pipe12_rpre_emph_e_val         = 6'b0,
        parameter pipe12_rpre_emph_settings      = 6'b0,
        parameter pipe12_rvod_sel_a_val          = 6'b0,
        parameter pipe12_rvod_sel_b_val          = 6'b0,
        parameter pipe12_rvod_sel_c_val          = 6'b0,
        parameter pipe12_rvod_sel_d_val          = 6'b0,
        parameter pipe12_rvod_sel_e_val          = 6'b0,
        parameter pipe12_rvod_sel_settings       = 6'b0,
        parameter pipe12_rx_pipe_enable          = "<auto_single>",     // dis_pipe_rx|en_pipe_rx
        parameter pipe12_rxdetect_bypass         = "<auto_single>",     // dis_rxdetect_bypass|en_rxdetect_bypass
        parameter pipe12_sup_mode                = "user_mode",         // user_mode|engineering_mode
        parameter pipe12_tx_pipe_enable          = "<auto_single>",     // dis_pipe_tx|en_pipe_tx
        parameter pipe12_txswing                 = "<auto_single>",     // dis_txswing|en_txswing
        parameter pipe12_use_default_base_address = "true",             // false|true
        parameter pipe12_user_base_address       = 0,                   // 0..2047
    // parameters for arriav_hssi_rx_pcs_pma_interface
        parameter rx_pcs_pma_if_clkslip_sel      = "<auto_single>",     // pld|slip_eight_g_pcs
        parameter rx_pcs_pma_if_prot_mode        = "<auto_single>",     // other_protocols|cpri_8g
        parameter rx_pcs_pma_if_selectpcs        = "eight_g_pcs",       // eight_g_pcs|default
        parameter rx_pcs_pma_if_use_default_base_address = "true",      // false|true
        parameter rx_pcs_pma_if_user_base_address = 0,                  // 0..2047
    // parameters for arriav_hssi_rx_pld_pcs_interface
        parameter rx_pld_pcs_if_is_8g_0ppm       = "false",             // false|true
        parameter rx_pld_pcs_if_pcs_side_block_sel = "eight_g_pcs",     // eight_g_pcs|default
        parameter rx_pld_pcs_if_pld_side_data_source = "pld",           // hip|pld
        parameter rx_pld_pcs_if_use_default_base_address = "true",      // false|true
        parameter rx_pld_pcs_if_user_base_address = 0,                  // 0..2047
    // parameters for arriav_hssi_tx_pcs_pma_interface
        parameter tx_pcs_pma_if_selectpcs        = "eight_g_pcs",       // eight_g_pcs|default
        parameter tx_pcs_pma_if_use_default_base_address = "true",      // false|true
        parameter tx_pcs_pma_if_user_base_address = 0,                  // 0..2047
    // parameters for arriav_hssi_tx_pld_pcs_interface
        parameter tx_pld_pcs_if_is_8g_0ppm       = "false",             // false|true
        parameter tx_pld_pcs_if_pld_side_data_source = "pld",           // hip|pld
        parameter tx_pld_pcs_if_use_default_base_address = "true",      // false|true
        parameter tx_pld_pcs_if_user_base_address = 0,                  // 0..2047

    // av_xcvr_avmm parameters
        parameter bonded_lanes                   = 1,                   // Number of lanes
        parameter pma_reserved_ch                = "-1",                // Indicates which channels are reserved
    // PMA enables
    // PCS enables
    // Services requests
        parameter request_dcd                    = 1,                   // Request Duty Cycle Distortion correction at startup
        parameter request_vrc                    = 0,                    // Request Voltage Regulator Calibration at startup
        parameter request_offset                 = 1,                    // Request RX Offset Cancellation at startup - defaults to enabled, only PCIE w/HIP should unset this
         // CvP IOCSR control - cvp_update
        parameter cvp_en_iocsr                   = "false" // valid values = "true", "false"
  )(

  // av_pma ports
  // TX/RX ports
  // RX ports
  input   wire  [bonded_lanes - 1 : 0]          rx_datain,                      // RX serial data input
  input   wire  [bonded_lanes*cdr_refclk_cnt-1:0]         rx_cdr_ref_clk,       // Reference clock for CDR
  input   wire  [bonded_lanes - 1 : 0]          rx_ltd,                         // Force lock-to-data stream
  output  wire  [bonded_lanes - 1 : 0]          rx_clkdivrx,                    // RX parallel clock output
  output  wire  [bonded_lanes*80-1: 0]          rx_dataout,  // RX parallel data output
  output  wire  [bonded_lanes - 1 : 0]          rx_is_lockedtodata,             // Indicates lock to incoming data rate
  output  wire  [bonded_lanes - 1 : 0]          rx_is_lockedtoref,              // Indicates lock to reference clock
  output  wire  [bonded_lanes - 1 : 0]          out_pcs_signal_ok,
  // TX ports
  //input port for buf
  input   wire                                  tx_rxdetclk,                    // Clock for detection of downstream receiver (125MHz ?)
  //output port for buf
  output  wire  [bonded_lanes - 1 : 0]          tx_dataout,                     // TX serial data output
  //input ports for ser
  input   wire                                  tx_rstn,                        // TODO - Examine resets
  //output ports for ser
  output  wire  [bonded_lanes - 1 : 0]          tx_clkdivtx,                    // TX parallel clock output
  //input ports for cgb
  input   wire  [bonded_lanes*plls-1:0]         tx_ser_clk,                     // High-speed serial clock(s) from PLL
  input   wire                                  tx_pcsrstn,
  input   wire                                  tx_fref,
  input   wire  [bonded_lanes*plls-1:0]         tx_rstn_cgb_master,
  input   wire  [bonded_lanes - 1 : 0]          tx_cpulsein,
  input   wire  [bonded_lanes - 1 : 0]          tx_hclkin,
  input   wire  [bonded_lanes - 1 : 0]          tx_lfclkin,
  input   wire  [bonded_lanes*3-1 : 0]          tx_pclkin,         
  //output ports for cgb
  // AVMM ports

  // av_pcs ports
  input   wire  [bonded_lanes - 1:0]            in_agg_align_status,
  input   wire  [bonded_lanes - 1:0]            in_agg_align_status_sync_0,
  input   wire  [bonded_lanes - 1:0]            in_agg_align_status_sync_0_top_or_bot,
  input   wire  [bonded_lanes - 1:0]            in_agg_align_status_top_or_bot,
  input   wire  [bonded_lanes - 1:0]            in_agg_cg_comp_rd_d_all,
  input   wire  [bonded_lanes - 1:0]            in_agg_cg_comp_rd_d_all_top_or_bot,
  input   wire  [bonded_lanes - 1:0]            in_agg_cg_comp_wr_all,
  input   wire  [bonded_lanes - 1:0]            in_agg_cg_comp_wr_all_top_or_bot,
  input   wire  [bonded_lanes - 1:0]            in_agg_del_cond_met_0,
  input   wire  [bonded_lanes - 1:0]            in_agg_del_cond_met_0_top_or_bot,
  input   wire  [bonded_lanes - 1:0]            in_agg_en_dskw_qd,
  input   wire  [bonded_lanes - 1:0]            in_agg_en_dskw_qd_top_or_bot,
  input   wire  [bonded_lanes - 1:0]            in_agg_en_dskw_rd_ptrs,
  input   wire  [bonded_lanes - 1:0]            in_agg_en_dskw_rd_ptrs_top_or_bot,
  input   wire  [bonded_lanes - 1:0]            in_agg_fifo_ovr_0,
  input   wire  [bonded_lanes - 1:0]            in_agg_fifo_ovr_0_top_or_bot,
  input   wire  [bonded_lanes - 1:0]            in_agg_fifo_rd_in_comp_0,
  input   wire  [bonded_lanes - 1:0]            in_agg_fifo_rd_in_comp_0_top_or_bot,
  input   wire  [bonded_lanes - 1:0]            in_agg_fifo_rst_rd_qd,
  input   wire  [bonded_lanes - 1:0]            in_agg_fifo_rst_rd_qd_top_or_bot,
  input   wire  [bonded_lanes - 1:0]            in_agg_insert_incomplete_0,
  input   wire  [bonded_lanes - 1:0]            in_agg_insert_incomplete_0_top_or_bot,
  input   wire  [bonded_lanes - 1:0]            in_agg_latency_comp_0,
  input   wire  [bonded_lanes - 1:0]            in_agg_latency_comp_0_top_or_bot,
  input   wire  [bonded_lanes - 1:0]            in_agg_rcvd_clk_agg,
  input   wire  [bonded_lanes - 1:0]            in_agg_rcvd_clk_agg_top_or_bot,
  input   wire  [bonded_lanes - 1:0]            in_agg_rx_control_rs,
  input   wire  [bonded_lanes - 1:0]            in_agg_rx_control_rs_top_or_bot,
  input   wire  [bonded_lanes * 8 - 1 : 0]      in_agg_rx_data_rs,
  input   wire  [bonded_lanes * 8 - 1 : 0]      in_agg_rx_data_rs_top_or_bot,
  input   wire  [bonded_lanes - 1:0]            in_agg_test_so_to_pld_in,
  input   wire  [bonded_lanes * 16 - 1 : 0]     in_agg_testbus,
  input   wire  [bonded_lanes - 1:0]            in_agg_tx_ctl_ts,
  input   wire  [bonded_lanes - 1:0]            in_agg_tx_ctl_ts_top_or_bot,
  input   wire  [bonded_lanes * 8 - 1 : 0]      in_agg_tx_data_ts,
  input   wire  [bonded_lanes * 8 - 1 : 0]      in_agg_tx_data_ts_top_or_bot,
  input   wire  [bonded_lanes * 38 - 1 : 0]     in_emsip_com_in,
  input   wire  [bonded_lanes * 13 - 1 : 0]     in_emsip_rx_special_in,
  input   wire  [bonded_lanes * 104 - 1 : 0]    in_emsip_tx_in,
  input   wire  [bonded_lanes * 13 - 1 : 0]     in_emsip_tx_special_in,
  input   wire  [bonded_lanes - 1:0]            in_pld_8g_a1a2_size,
  input   wire  [bonded_lanes - 1:0]            in_pld_8g_bitloc_rev_en,
  input   wire  [bonded_lanes - 1:0]            in_pld_8g_bitslip,
  input   wire  [bonded_lanes - 1:0]            in_pld_8g_byte_rev_en,
  input   wire  [bonded_lanes - 1:0]            in_pld_8g_bytordpld,
  input   wire  [bonded_lanes - 1:0]            in_pld_8g_cmpfifourst_n,
  input   wire  [bonded_lanes - 1:0]            in_pld_8g_encdt,
  input   wire  [bonded_lanes - 1:0]            in_pld_8g_phfifourst_rx_n,
  input   wire  [bonded_lanes - 1:0]            in_pld_8g_phfifourst_tx_n,
  input   wire  [bonded_lanes - 1:0]            in_pld_8g_pld_tx_clk,
  input   wire  [bonded_lanes - 1:0]            in_pld_8g_polinv_rx,
  input   wire  [bonded_lanes - 1:0]            in_pld_8g_polinv_tx,
  input   wire  [bonded_lanes * 2 - 1 : 0]      in_pld_8g_powerdown,
  input   wire  [bonded_lanes - 1:0]            in_pld_8g_prbs_cid_en,
  input   wire  [bonded_lanes - 1:0]            in_pld_8g_rddisable_tx,
  input   wire  [bonded_lanes - 1:0]            in_pld_8g_rdenable_rmf,
  input   wire  [bonded_lanes - 1:0]            in_pld_8g_rdenable_rx,
  input   wire  [bonded_lanes - 1:0]            in_pld_8g_refclk_dig,
  input   wire  [bonded_lanes - 1:0]            in_pld_8g_refclk_dig2,
  input   wire  [bonded_lanes - 1:0]            in_pld_8g_rev_loopbk,
  input   wire  [bonded_lanes - 1:0]            in_pld_8g_rxpolarity,
  input   wire  [bonded_lanes * 5 - 1 : 0]      in_pld_8g_tx_boundary_sel,
  input   wire  [bonded_lanes * 4 - 1 : 0]      in_pld_8g_tx_data_valid,
  input   wire  [bonded_lanes - 1:0]            in_pld_8g_txdeemph,
  input   wire  [bonded_lanes - 1:0]            in_pld_8g_txdetectrxloopback,
  input   wire  [bonded_lanes - 1:0]            in_pld_8g_txelecidle,
  input   wire  [bonded_lanes * 3 - 1 : 0]      in_pld_8g_txmargin,
  input   wire  [bonded_lanes - 1:0]            in_pld_8g_txswing,
  input   wire  [bonded_lanes - 1:0]            in_pld_8g_wrdisable_rx,
  input   wire  [bonded_lanes - 1:0]            in_pld_8g_wrenable_rmf,
  input   wire  [bonded_lanes - 1:0]            in_pld_8g_wrenable_tx,
  input   wire  [bonded_lanes - 1:0]            in_pld_agg_refclk_dig,
  input   wire  [bonded_lanes * 3 - 1 : 0]      in_pld_eidleinfersel,
  input   wire  [bonded_lanes - 1:0]            in_pld_ltr,
  input   wire  [bonded_lanes - 1:0]            in_pld_partial_reconfig_in,
  input   wire  [bonded_lanes - 1:0]            in_pld_pcs_pma_if_refclk_dig,
  input   wire  [bonded_lanes - 1:0]            in_pld_rate,
  input   wire  [bonded_lanes * 12 - 1 : 0]     in_pld_reserved_in,
  input   wire  [bonded_lanes - 1:0]            in_pld_rx_clk_slip_in,
  input   wire  [bonded_lanes - 1:0]            in_pld_scan_mode_n,
  input   wire  [bonded_lanes - 1:0]            in_pld_scan_shift_n,
  input   wire  [bonded_lanes - 1:0]            in_pld_sync_sm_en,
  input   wire  [bonded_lanes * 44 - 1 : 0]     in_pld_tx_data,
  input   wire  [bonded_lanes * 80 - 1 : 0]     in_pld_tx_pma_data,
  input   wire  [bonded_lanes - 1:0]            in_pma_hclk,
  input   wire  [bonded_lanes * 5 - 1 : 0]      in_pma_reserved_in,
  input   wire  [bonded_lanes - 1:0]            in_pma_rx_freq_tx_cmu_pll_lock_in,
  output  wire  [bonded_lanes * 2 - 1 : 0]      out_agg_align_det_sync,
  output  wire  [bonded_lanes - 1:0]            out_agg_align_status_sync,
  output  wire  [bonded_lanes * 2 - 1 : 0]      out_agg_cg_comp_rd_d_out,
  output  wire  [bonded_lanes * 2 - 1 : 0]      out_agg_cg_comp_wr_out,
  output  wire  [bonded_lanes - 1:0]            out_agg_dec_ctl,
  output  wire  [bonded_lanes * 8 - 1 : 0]      out_agg_dec_data,
  output  wire  [bonded_lanes - 1:0]            out_agg_dec_data_valid,
  output  wire  [bonded_lanes - 1:0]            out_agg_del_cond_met_out,
  output  wire  [bonded_lanes - 1:0]            out_agg_fifo_ovr_out,
  output  wire  [bonded_lanes - 1:0]            out_agg_fifo_rd_out_comp,
  output  wire  [bonded_lanes - 1:0]            out_agg_insert_incomplete_out,
  output  wire  [bonded_lanes - 1:0]            out_agg_latency_comp_out,
  output  wire  [bonded_lanes * 2 - 1 : 0]      out_agg_rd_align,
  output  wire  [bonded_lanes - 1:0]            out_agg_rd_enable_sync,
  output  wire  [bonded_lanes - 1:0]            out_agg_refclk_dig,
  output  wire  [bonded_lanes * 2 - 1 : 0]      out_agg_running_disp,
  output  wire  [bonded_lanes - 1:0]            out_agg_rxpcs_rst,
  output  wire  [bonded_lanes - 1:0]            out_agg_scan_mode_n,
  output  wire  [bonded_lanes - 1:0]            out_agg_scan_shift_n,
  output  wire  [bonded_lanes - 1:0]            out_agg_sync_status,
  output  wire  [bonded_lanes - 1:0]            out_agg_tx_ctl_tc,
  output  wire  [bonded_lanes * 8 - 1 : 0]      out_agg_tx_data_tc,
  output  wire  [bonded_lanes - 1:0]            out_agg_txpcs_rst,
  output  wire  [bonded_lanes * 3 - 1 : 0]      out_emsip_com_clk_out,
  output  wire  [bonded_lanes * 27 - 1 : 0]     out_emsip_com_out,
  output  wire  [bonded_lanes * 129 - 1 : 0]    out_emsip_rx_out,
  output  wire  [bonded_lanes * 16 - 1 : 0]     out_emsip_rx_special_out,
  output  wire  [bonded_lanes * 3 - 1 : 0]      out_emsip_tx_clk_out,
  output  wire  [bonded_lanes * 16 - 1 : 0]     out_emsip_tx_special_out,
  output  wire  [bonded_lanes * 4 - 1 : 0]      out_pld_8g_a1a2_k1k2_flag,
  output  wire  [bonded_lanes - 1:0]            out_pld_8g_align_status,
  output  wire  [bonded_lanes - 1:0]            out_pld_8g_bistdone,
  output  wire  [bonded_lanes - 1:0]            out_pld_8g_bisterr,
  output  wire  [bonded_lanes - 1:0]            out_pld_8g_byteord_flag,
  output  wire  [bonded_lanes - 1:0]            out_pld_8g_empty_rmf,
  output  wire  [bonded_lanes - 1:0]            out_pld_8g_empty_rx,
  output  wire  [bonded_lanes - 1:0]            out_pld_8g_empty_tx,
  output  wire  [bonded_lanes - 1:0]            out_pld_8g_full_rmf,
  output  wire  [bonded_lanes - 1:0]            out_pld_8g_full_rx,
  output  wire  [bonded_lanes - 1:0]            out_pld_8g_full_tx,
  output  wire  [bonded_lanes - 1:0]            out_pld_8g_phystatus,
  output  wire  [bonded_lanes - 1:0]            out_pld_8g_rlv_lt,
  output  wire  [bonded_lanes - 1:0]            out_pld_8g_rx_clk_out,
  output  wire  [bonded_lanes * 4 - 1 : 0]      out_pld_8g_rx_data_valid,
  output  wire  [bonded_lanes - 1:0]            out_pld_8g_rxelecidle,
  output  wire  [bonded_lanes * 3 - 1 : 0]      out_pld_8g_rxstatus,
  output  wire  [bonded_lanes - 1:0]            out_pld_8g_rxvalid,
  output  wire  [bonded_lanes - 1:0]            out_pld_8g_signal_detect_out,
  output  wire  [bonded_lanes - 1:0]            out_pld_8g_tx_clk_out,
  output  wire  [bonded_lanes * 5 - 1 : 0]      out_pld_8g_wa_boundary,
  output  wire  [bonded_lanes - 1:0]            out_pld_clklow,
  output  wire  [bonded_lanes - 1:0]            out_pld_fref,
  output  wire  [bonded_lanes * 11 - 1 : 0]     out_pld_reserved_out,
  output  wire  [bonded_lanes * 64 - 1 : 0]     out_pld_rx_data,
  output  wire  [bonded_lanes * 20 - 1 : 0]     out_pld_test_data,
  output  wire  [bonded_lanes - 1:0]            out_pld_test_si_to_agg_out,
  output  wire  [bonded_lanes * 12 - 1 : 0]     out_pma_current_coeff,
  output  wire  [bonded_lanes - 1:0]            out_pma_nfrzdrv,
  output  wire  [bonded_lanes - 1:0]            out_pma_partial_reconfig,
  output  wire  [bonded_lanes - 1:0]            out_pma_ppm_lock,
  output  wire  [bonded_lanes * 5 - 1 : 0]      out_pma_reserved_out,
  output  wire  [bonded_lanes - 1:0]            out_pma_rx_clk_out,
  output  wire  [bonded_lanes - 1:0]            out_pma_tx_clk_out,

  // av_xcvr_avmm ports
  // Reconfiguration signal bundles
  input   wire  [bonded_lanes*W_S5_RECONFIG_BUNDLE_TO_XCVR  -1:0]  reconfig_to_xcvr,
  output  wire  [bonded_lanes*W_S5_RECONFIG_BUNDLE_FROM_XCVR-1:0]  reconfig_from_xcvr,
  // Control inputs from PLD
  input   wire  [bonded_lanes-1     :0]         seriallpbken,                   // 1 = enable serial loopback
  // PCS clocks
  input   wire  [bonded_lanes-1     :0]         in_pld_8g_pld_rx_clk,           // 8g PCS RX clock
  // PCS resets
  input   wire  [bonded_lanes-1     :0]         in_pld_8g_txurstpcs_n,          // 8g PCS TX reset
  input   wire  [bonded_lanes-1     :0]         in_pld_8g_rxurstpcs_n,          // 8g PCS RX reset
  // PMA resets
  input   wire  [bonded_lanes-1     :0]         rx_crurstn,                     // CDR analog reset (active low)
  input   wire  [bonded_lanes-1     :0]         in_pld_rxpma_rstb_in,
  // PCS data
  // Calibration clocks
  //calibration status
  output  wire  [bonded_lanes-1     :0]         tx_cal_busy,
  output  wire  [bonded_lanes-1     :0]         rx_cal_busy,
  output  wire  [bonded_lanes-1     :0]         rx_sd
);

  
  wire  [bonded_lanes - 1 : 0]          rx_clklow;
  wire  [bonded_lanes - 1 : 0]          rx_fref;
  wire  [bonded_lanes - 1 : 0]          out_pcs_rx_pll_phase_lock_out;
  wire  [bonded_lanes - 1 : 0]          tx_rxdetectvalid;
  wire  [bonded_lanes - 1 : 0]          tx_rxfound;
  wire  [bonded_lanes -1 : 0]           tx_pcieswdone;
  wire  [(bonded_lanes*16)-1:0 ]        pma_avmmreaddata_tx_cgb;
  wire  [(bonded_lanes*16)-1:0 ]        pma_avmmreaddata_tx_ser;
  wire  [(bonded_lanes*16)-1:0 ]        pma_avmmreaddata_tx_buf;
  wire  [(bonded_lanes*16)-1:0 ]        pma_avmmreaddata_rx_ser;
  wire  [(bonded_lanes*16)-1:0 ]        pma_avmmreaddata_rx_buf;
  wire  [(bonded_lanes*16)-1:0 ]        pma_avmmreaddata_rx_cdr;
  wire  [(bonded_lanes*16)-1:0 ]        pma_avmmreaddata_rx_mux;
  wire  [bonded_lanes-1:0 ]             pma_blockselect_tx_cgb;
  wire  [bonded_lanes-1:0 ]             pma_blockselect_tx_ser;
  wire  [bonded_lanes-1:0 ]             pma_blockselect_tx_buf;
  wire  [bonded_lanes-1:0 ]             pma_blockselect_rx_ser;
  wire  [bonded_lanes-1:0 ]             pma_blockselect_rx_buf;
  wire  [bonded_lanes-1:0 ]             pma_blockselect_rx_cdr;
  wire  [bonded_lanes-1:0 ]             pma_blockselect_rx_mux;
  wire  [bonded_lanes-1:0 ]             pll_aux_atb_comp_out;
  wire  [bonded_lanes * 16 - 1 : 0]     out_avmmreaddata_com_pcs_pma_if;
  wire  [bonded_lanes * 16 - 1 : 0]     out_avmmreaddata_com_pld_pcs_if;
  wire  [bonded_lanes * 16 - 1 : 0]     out_avmmreaddata_pcs8g_rx;
  wire  [bonded_lanes * 16 - 1 : 0]     out_avmmreaddata_pcs8g_tx;
  wire  [bonded_lanes * 16 - 1 : 0]     out_avmmreaddata_pipe12;
  wire  [bonded_lanes * 16 - 1 : 0]     out_avmmreaddata_rx_pcs_pma_if;
  wire  [bonded_lanes * 16 - 1 : 0]     out_avmmreaddata_rx_pld_pcs_if;
  wire  [bonded_lanes * 16 - 1 : 0]     out_avmmreaddata_tx_pcs_pma_if;
  wire  [bonded_lanes * 16 - 1 : 0]     out_avmmreaddata_tx_pld_pcs_if;
  wire  [bonded_lanes - 1:0]            out_blockselect_com_pcs_pma_if;
  wire  [bonded_lanes - 1:0]            out_blockselect_com_pld_pcs_if;
  wire  [bonded_lanes - 1:0]            out_blockselect_pcs8g_rx;
  wire  [bonded_lanes - 1:0]            out_blockselect_pcs8g_tx;
  wire  [bonded_lanes - 1:0]            out_blockselect_pipe12;
  wire  [bonded_lanes - 1:0]            out_blockselect_rx_pcs_pma_if;
  wire  [bonded_lanes - 1:0]            out_blockselect_rx_pld_pcs_if;
  wire  [bonded_lanes - 1:0]            out_blockselect_tx_pcs_pma_if;
  wire  [bonded_lanes - 1:0]            out_blockselect_tx_pld_pcs_if;
  wire  [bonded_lanes - 1:0]            out_pma_early_eios;
  wire  [bonded_lanes - 1:0]            out_pma_ltr;
  wire  [bonded_lanes - 1:0]            out_pma_pcie_switch;
  wire  [bonded_lanes - 1:0]            out_pma_rxclkslip;
  wire  [bonded_lanes - 1:0]            out_pma_rxpma_rstb;
  wire  [bonded_lanes * 20 - 1 : 0]     out_pma_tx_data;
  wire  [bonded_lanes - 1:0]            out_pma_tx_elec_idle;
  wire  [bonded_lanes - 1:0]            out_pma_txdetectrx;
  wire  [bonded_lanes-1     :0]         out_pld_8g_txurstpcs_n;
  wire  [bonded_lanes-1     :0]         out_pld_8g_rxurstpcs_n;
  wire  [bonded_lanes-1     :0]         out_rx_crurstn;
  wire  [bonded_lanes-1     :0]         out_pld_rxpma_rstb_in;
  wire                                  calclk;
  wire  [bonded_lanes-1     :0]         pma_hardoccalen;
  wire  [bonded_lanes-1     :0]         pma_seriallpbken;
  wire  [bonded_lanes-1     :0]         chnl_avmm_clk;
  wire  [bonded_lanes-1     :0]         chnl_avmm_rstn;
  wire  [bonded_lanes*16-1  :0]         chnl_avmm_writedata;
  wire  [bonded_lanes*11-1  :0]         chnl_avmm_address;
  wire  [bonded_lanes-1     :0]         chnl_avmm_write;
  wire  [bonded_lanes-1     :0]         chnl_avmm_read;
  wire  [bonded_lanes*2-1   :0]         chnl_avmm_byteen;
  wire  [((pma_prot_mode == "pma direct") ? (bonded_lanes*80) : (bonded_lanes*20))-1: 0] 	    rx_dataout_int;
  wire  [bonded_lanes*20-1: 0] 	    in_pma_rx_data;
  wire [bonded_lanes-1     :0] 		hardoccalen_av_only;
generate
	if ( (device_family == "Arria V") || (device_family == "Cyclone V"))
  assign hardoccalen_av_only = pma_hardoccalen ;
  else
		assign hardoccalen_av_only = {bonded_lanes{1'b0}};
 endgenerate
 
  // Following for PMA Direct, if PMA direct mode then 80 bit data directly from PMA
  // otherwise 64 bit data from PCS
  generate 
      genvar num_ch;
      
      if (pma_prot_mode == "pma direct")
      begin
	      assign rx_dataout = rx_dataout_int;
	      
	      for (num_ch=0; num_ch < bonded_lanes; num_ch = num_ch + 1)
	      begin:in_pma_rx_data_inst
              assign in_pma_rx_data[num_ch*20 +: 20] = rx_dataout_int[80*num_ch +: 20];
          end
      end    
      else
      begin
	      assign rx_dataout = 80'b0;
	      assign in_pma_rx_data = rx_dataout_int;
	  end
	  
  endgenerate

  av_pma #(
      .rx_enable                     (rx_enable                     ), // (1,0) Enable or disable reciever PMA
      .tx_enable                     (tx_enable                     ), // (1,0) Enable or disable transmitter PMA
      .bonded_lanes                  (bonded_lanes                  ), // Number of bonded lanes
      .bonding_master_ch             (bonding_master_ch             ), // Indicates which channel is master
      .pma_bonding_master            (pma_bonding_master            ), // (List i.e. "0,3,..."), Indicates which channels is master
      .bonding_master_only           (bonding_master_only           ), // Indicates bonding_master_channel is MASTER_ONLY
      .channel_number                (channel_number                ), //
      .plls                          (plls                          ), // (1+) Number of high-speed serial clocks from TX plls (tx_ser_clk)
      .pll_sel                       (pll_sel                       ), // (0 - plls-1) // Which PLL clock to use
      .pma_prot_mode                 (pma_prot_mode                 ), // (basic,cpri,cpri_rx_tx,disabled_prot_mode,gige, pipe_g1,pipe_g2,srio_2p1,test,xaui)
      .pma_mode                      (pma_mode                      ), // (8,10,16,20,32,40,64,80) Serialization factor
	  .base_data_rate                (base_data_rate                ), // Base data rate for CGB
      .pma_data_rate                 (pma_data_rate                 ), // Serial data rate in bits-per-second
      .cdr_reconfig                  (cdr_reconfig                  ), // 1-Enable CDR reconfiguration, 0-Disable CDR reconfiguration
      .cdr_reference_clock_frequency (cdr_reference_clock_frequency ),
      .cdr_refclk_cnt                (cdr_refclk_cnt                ),
      .cdr_refclk_sel                (cdr_refclk_sel                ), // Initial CDR reference clock selection
      .deser_enable_bit_slip         (deser_enable_bit_slip         ),
      .auto_negotiation              (auto_negotiation              ), // ("true","false") PCIe Auto-Negotiation (Gen1,2,3)
      .tx_clk_div                    (tx_clk_div                    ), // (1,2,4,8)
      .pcie_rst                      (pcie_rst                      ),
      .fref_vco_bypass               (fref_vco_bypass               ),
      .sd_on                         (sd_on                         ),
      .pdb_sd                        (pdb_sd                        ),
      .pma_bonding_mode              (pma_bonding_mode              ),  // valid value "x1", "xN"
      .external_master_cgb           (external_master_cgb           ),
      .cvp_en_iocsr                  (cvp_en_iocsr                  )
    ) inst_av_pma (
      // TX/RX ports
      .calclk                        (calclk                        ), // Calibration clock (to aux block)
      .seriallpbken                  (pma_seriallpbken              ), // 1 = enable serial loopback
      .pciesw                        (out_pma_pcie_switch           ), // PCIe generation select
      // RX ports
      .rx_rstn                       (out_pma_rxpma_rstb            ), // Active low digital reset for (deserializer, CDR, RX buf)
      .rx_crurstn                    (out_rx_crurstn                ), // CDR analog reset (active low)
      .rx_datain                     (rx_datain                     ), // RX serial data input
      .rx_bslip                      (out_pma_rxclkslip             ), // PMA bitslip. Slips one clock cycle (2 UI of data)
      .rx_cdr_ref_clk                (rx_cdr_ref_clk                ), // Reference clock for CDR
      .rx_ltr                        (out_pma_ltr                   ), // Force lock-to_reference clock
      .rx_ltd                        (rx_ltd                        ), // Force lock-to-data stream
      .rx_freqlock                   (out_pma_ppm_lock              ), // frequency lock detector input (external PPM detector)
      .rx_earlyeios                  (out_pma_early_eios            ), // Early electricle idle ordered sequence
      .rx_hardoccalen                (hardoccalen_av_only                    ), // Enable Offset cancellation
      .rx_clkdivrx                   (rx_clkdivrx                   ), // RX parallel clock output
      .rx_dataout                    (rx_dataout_int                ), // RX parallel data output
      .rx_sd                         (rx_sd                         ), // RX signal detect
      .rx_clklow                     (rx_clklow                     ), // RX low frequency recovered clock
      .rx_fref                       (rx_fref                       ), // RX PFD reference clock (rx_cdr_refclk after divider)
      .rx_is_lockedtodata            (rx_is_lockedtodata            ), // Indicates lock to incoming data rate
      .rx_is_lockedtoref             (rx_is_lockedtoref             ), // Indicates lock to reference clock
      .out_pcs_signal_ok             (out_pcs_signal_ok             ),
      .out_pcs_rx_pll_phase_lock_out (out_pcs_rx_pll_phase_lock_out ),
      // TX ports
      //input port for buf
      .tx_datain                     ((pma_prot_mode == "pma direct") ? in_pld_tx_pma_data : out_pma_tx_data               ), // TX parallel data input
      .tx_txelecidl                  (out_pma_tx_elec_idle          ), // TX force electricle idle
      .tx_rxdetclk                   (tx_rxdetclk                   ), // Clock for detection of downstream receiver (125MHz ?)
      .tx_txdetrx                    (out_pma_txdetectrx            ), // 1 = enable downstream receiver detection
      //output port for buf
      .tx_dataout                    (tx_dataout                    ), // TX serial data output
      .tx_rxdetectvalid              (tx_rxdetectvalid              ), // Indicates corresponding tx_rxfound signal contains valid data
      .tx_rxfound                    (tx_rxfound                    ), // Indicates downnstream receiver is detected (qualify with tx_rxdetectvalid)
      //input ports for ser
      .tx_rstn                       (tx_rstn                       ), // TODO - Examine resets
      //output ports for ser
      .tx_clkdivtx                   (tx_clkdivtx                   ), // TX parallel clock output
      //input ports for cgb
      .tx_ser_clk                    (tx_ser_clk                    ), // High-speed serial clock(s) from PLL
      .tx_pcsrstn                    (tx_pcsrstn                    ),
      .tx_fref                       (tx_fref                       ),
	  .tx_rstn_cgb_master            (tx_rstn_cgb_master            ),
      .tx_cpulsein                   (tx_cpulsein                   ),
      .tx_hclkin                     (tx_hclkin                     ),
      .tx_lfclkin                    (tx_lfclkin                    ),
      .tx_pclkin                     (tx_pclkin                     ),
      //output ports for cgb
      .tx_pcieswdone                 (tx_pcieswdone                 ), // Inidicates PMA has accepted value on pciesw input.
      // AVMM ports
      .pma_avmmrstn                  (chnl_avmm_rstn                ), // one for each lane
      .pma_avmmclk                   (chnl_avmm_clk                 ), // one for each lane
      .pma_avmmwrite                 (chnl_avmm_write               ), // one for each lane
      .pma_avmmread                  (chnl_avmm_read                ), // one for each lane
      .pma_avmmbyteen                (chnl_avmm_byteen              ), // two for each lane
      .pma_avmmaddress               (chnl_avmm_address             ), // 11 for each lane
      .pma_avmmwritedata             (chnl_avmm_writedata           ), // 16 for each lane
      .pma_avmmreaddata_tx_cgb       (pma_avmmreaddata_tx_cgb       ), // TX AVMM CGB readdata (16 for each lane)
      .pma_avmmreaddata_tx_ser       (pma_avmmreaddata_tx_ser       ), // TX AVMM SER readdata (16 for each lane)
      .pma_avmmreaddata_tx_buf       (pma_avmmreaddata_tx_buf       ), // TX AVMM BUF readdata (16 for each lane)
      .pma_avmmreaddata_rx_ser       (pma_avmmreaddata_rx_ser       ), // RX AVMM SER readdata (16 for each lane)
      .pma_avmmreaddata_rx_buf       (pma_avmmreaddata_rx_buf       ), // RX AVMM BUF readdata (16 for each lane)
      .pma_avmmreaddata_rx_cdr       (pma_avmmreaddata_rx_cdr       ), // RX AVMM CDR readdata (16 for each lane)
      .pma_avmmreaddata_rx_mux       (pma_avmmreaddata_rx_mux       ), // RX AVMM CDR MUX readdata (16 for each lane)
      .pma_blockselect_tx_cgb        (pma_blockselect_tx_cgb        ), // TX AVMM CGB blockselect (1 for each lane)
      .pma_blockselect_tx_ser        (pma_blockselect_tx_ser        ), // TX AVMM SER blockselect (1 for each lane)
      .pma_blockselect_tx_buf        (pma_blockselect_tx_buf        ), // TX AVMM BUF blockselect (1 for each lane)
      .pma_blockselect_rx_ser        (pma_blockselect_rx_ser        ), // RX AVMM SER blockselect (1 for each lane)
      .pma_blockselect_rx_buf        (pma_blockselect_rx_buf        ), // RX AVMM BUF blockselect (1 for each lane)
      .pma_blockselect_rx_cdr        (pma_blockselect_rx_cdr        ), // RX AVMM SER blockselect (1 for each lane)
      .pma_blockselect_rx_mux        (pma_blockselect_rx_mux        ), // RX AVMM BUF blockselect (1 for each lane)
      .pll_aux_atb_comp_out          (pll_aux_atb_comp_out          )  // Voltage comparator output for DCD (1 for each lane)
);


  av_pcs #(
      .bonded_lanes                  (bonded_lanes                  ),
      .bonding_master_ch             (bonding_master_ch             ),
      .enable_8g_rx                  (enable_8g_rx                  ),
      .enable_8g_tx                  (enable_8g_tx                  ),
      .enable_pma_direct_tx          (enable_pma_direct_tx          ),
      .enable_pma_direct_rx          (enable_pma_direct_rx          ),	  
      .enable_dyn_reconfig           (enable_dyn_reconfig           ),
      .enable_gen12_pipe             (enable_gen12_pipe             ),
      .channel_number                (channel_number                ),
      // parameters for arriav_hssi_8g_rx_pcs
      .pcs8g_rx_agg_block_sel        (pcs8g_rx_agg_block_sel        ), // same_smrt_pack|other_smrt_pack
      .pcs8g_rx_auto_error_replacement(pcs8g_rx_auto_error_replacement), // dis_err_replace|en_err_replace
      .pcs8g_rx_auto_speed_nego      (pcs8g_rx_auto_speed_nego      ), // dis_asn|en_asn_g2_freq_scal
      .pcs8g_rx_bist_ver             (pcs8g_rx_bist_ver             ), // dis_bist|incremental|cjpat|crpat
      .pcs8g_rx_bist_ver_clr_flag    (pcs8g_rx_bist_ver_clr_flag    ), // dis_bist_clr_flag|en_bist_clr_flag
      .pcs8g_rx_bit_reversal         (pcs8g_rx_bit_reversal         ), // dis_bit_reversal|en_bit_reversal
      .pcs8g_rx_bo_pad               (pcs8g_rx_bo_pad               ),
      .pcs8g_rx_bo_pattern           (pcs8g_rx_bo_pattern           ),
      .pcs8g_rx_bypass_pipeline_reg  (pcs8g_rx_bypass_pipeline_reg  ), // dis_bypass_pipeline|en_bypass_pipeline
      .pcs8g_rx_byte_deserializer    (pcs8g_rx_byte_deserializer    ), // dis_bds|en_bds_by_2|en_bds_by_2_det
      .pcs8g_rx_byte_order           (pcs8g_rx_byte_order           ), // dis_bo|en_pcs_ctrl_eight_bit_bo|en_pcs_ctrl_nine_bit_bo|en_pcs_ctrl_ten_bit_bo|en_pld_ctrl_eight_bit_bo|en_pld_ctrl_nine_bit_bo|en_pld_ctrl_ten_bit_bo
      .pcs8g_rx_cdr_ctrl             (pcs8g_rx_cdr_ctrl             ), // dis_cdr_ctrl|en_cdr_ctrl|en_cdr_ctrl_w_cid
      .pcs8g_rx_cdr_ctrl_rxvalid_mask(pcs8g_rx_cdr_ctrl_rxvalid_mask), // dis_rxvalid_mask|en_rxvalid_mask
      .pcs8g_rx_cid_pattern          (pcs8g_rx_cid_pattern          ), // cid_pattern_0|cid_pattern_1
      .pcs8g_rx_cid_pattern_len      (pcs8g_rx_cid_pattern_len      ),
      .pcs8g_rx_clkcmp_pattern_n     (pcs8g_rx_clkcmp_pattern_n     ),
      .pcs8g_rx_clkcmp_pattern_p     (pcs8g_rx_clkcmp_pattern_p     ),
      .pcs8g_rx_clock_gate_bds_dec_asn(pcs8g_rx_clock_gate_bds_dec_asn), // dis_bds_dec_asn_clk_gating|en_bds_dec_asn_clk_gating
      .pcs8g_rx_clock_gate_bist      (pcs8g_rx_clock_gate_bist      ), // dis_bist_clk_gating|en_bist_clk_gating
      .pcs8g_rx_clock_gate_byteorder (pcs8g_rx_clock_gate_byteorder ), // dis_byteorder_clk_gating|en_byteorder_clk_gating
      .pcs8g_rx_clock_gate_cdr_eidle (pcs8g_rx_clock_gate_cdr_eidle ), // dis_cdr_eidle_clk_gating|en_cdr_eidle_clk_gating
      .pcs8g_rx_clock_gate_dskw_rd   (pcs8g_rx_clock_gate_dskw_rd   ), // dis_dskw_rdclk_gating|en_dskw_rdclk_gating
      .pcs8g_rx_clock_gate_dw_dskw_wr(pcs8g_rx_clock_gate_dw_dskw_wr), // dis_dw_dskw_wrclk_gating|en_dw_dskw_wrclk_gating
      .pcs8g_rx_clock_gate_dw_pc_wrclk(pcs8g_rx_clock_gate_dw_pc_wrclk), // dis_dw_pc_wrclk_gating|en_dw_pc_wrclk_gating
      .pcs8g_rx_clock_gate_dw_rm_rd  (pcs8g_rx_clock_gate_dw_rm_rd  ), // dis_dw_rm_rdclk_gating|en_dw_rm_rdclk_gating
      .pcs8g_rx_clock_gate_dw_rm_wr  (pcs8g_rx_clock_gate_dw_rm_wr  ), // dis_dw_rm_wrclk_gating|en_dw_rm_wrclk_gating
      .pcs8g_rx_clock_gate_dw_wa     (pcs8g_rx_clock_gate_dw_wa     ), // dis_dw_wa_clk_gating|en_dw_wa_clk_gating
      .pcs8g_rx_clock_gate_pc_rdclk  (pcs8g_rx_clock_gate_pc_rdclk  ), // dis_pc_rdclk_gating|en_pc_rdclk_gating
      .pcs8g_rx_clock_gate_prbs      (pcs8g_rx_clock_gate_prbs      ), // dis_prbs_clk_gating|en_prbs_clk_gating
      .pcs8g_rx_clock_gate_sw_dskw_wr(pcs8g_rx_clock_gate_sw_dskw_wr), // dis_sw_dskw_wrclk_gating|en_sw_dskw_wrclk_gating
      .pcs8g_rx_clock_gate_sw_pc_wrclk(pcs8g_rx_clock_gate_sw_pc_wrclk), // dis_sw_pc_wrclk_gating|en_sw_pc_wrclk_gating
      .pcs8g_rx_clock_gate_sw_rm_rd  (pcs8g_rx_clock_gate_sw_rm_rd  ), // dis_sw_rm_rdclk_gating|en_sw_rm_rdclk_gating
      .pcs8g_rx_clock_gate_sw_rm_wr  (pcs8g_rx_clock_gate_sw_rm_wr  ), // dis_sw_rm_wrclk_gating|en_sw_rm_wrclk_gating
      .pcs8g_rx_clock_gate_sw_wa     (pcs8g_rx_clock_gate_sw_wa     ), // dis_sw_wa_clk_gating|en_sw_wa_clk_gating
      .pcs8g_rx_comp_fifo_rst_pld_ctrl(pcs8g_rx_comp_fifo_rst_pld_ctrl), // dis_comp_fifo_rst_pld_ctrl|en_comp_fifo_rst_pld_ctrl
      .pcs8g_rx_deskew               (pcs8g_rx_deskew               ), // dis_deskew|en_srio_v2p1|en_xaui
      .pcs8g_rx_deskew_pattern       (pcs8g_rx_deskew_pattern       ),
      .pcs8g_rx_deskew_prog_pattern_only(pcs8g_rx_deskew_prog_pattern_only), // dis_deskew_prog_pat_only|en_deskew_prog_pat_only
      .pcs8g_rx_dw_one_or_two_symbol_bo(pcs8g_rx_dw_one_or_two_symbol_bo), // donot_care_one_two_bo|one_symbol_bo|two_symbol_bo_eight_bit|two_symbol_bo_nine_bit|two_symbol_bo_ten_bit
      .pcs8g_rx_eidle_entry_eios     (pcs8g_rx_eidle_entry_eios     ), // dis_eidle_eios|en_eidle_eios
      .pcs8g_rx_eidle_entry_iei      (pcs8g_rx_eidle_entry_iei      ), // dis_eidle_iei|en_eidle_iei
      .pcs8g_rx_eidle_entry_sd       (pcs8g_rx_eidle_entry_sd       ), // dis_eidle_sd|en_eidle_sd
      .pcs8g_rx_eightb_tenb_decoder  (pcs8g_rx_eightb_tenb_decoder  ), // dis_8b10b|en_8b10b_ibm|en_8b10b_sgx
      .pcs8g_rx_eightbtenb_decoder_output_sel(pcs8g_rx_eightbtenb_decoder_output_sel), // data_8b10b_decoder|data_xaui_sm
      .pcs8g_rx_err_flags_sel        (pcs8g_rx_err_flags_sel        ), // err_flags_wa|err_flags_8b10b
      .pcs8g_rx_fixed_pat_det        (pcs8g_rx_fixed_pat_det        ), // dis_fixed_patdet|en_fixed_patdet
      .pcs8g_rx_fixed_pat_num        (pcs8g_rx_fixed_pat_num        ),
      .pcs8g_rx_force_signal_detect  (pcs8g_rx_force_signal_detect  ), // en_force_signal_detect|dis_force_signal_detect
      .pcs8g_rx_hip_mode             (pcs8g_rx_hip_mode             ), // dis_hip|en_hip
      .pcs8g_rx_ibm_invalid_code     (pcs8g_rx_ibm_invalid_code     ), // dis_ibm_invalid_code|en_ibm_invalid_code
      .pcs8g_rx_invalid_code_flag_only(pcs8g_rx_invalid_code_flag_only), // dis_invalid_code_only|en_invalid_code_only
      .pcs8g_rx_mask_cnt             (pcs8g_rx_mask_cnt             ),
      .pcs8g_rx_pad_or_edb_error_replace(pcs8g_rx_pad_or_edb_error_replace), // replace_edb|replace_pad|replace_edb_dynamic
      .pcs8g_rx_pc_fifo_rst_pld_ctrl (pcs8g_rx_pc_fifo_rst_pld_ctrl ), // dis_pc_fifo_rst_pld_ctrl|en_pc_fifo_rst_pld_ctrl
      .pcs8g_rx_pcs_bypass           (pcs8g_rx_pcs_bypass           ), // dis_pcs_bypass|en_pcs_bypass
      .pcs8g_rx_phase_compensation_fifo(pcs8g_rx_phase_compensation_fifo), // low_latency|normal_latency|register_fifo|pld_ctrl_low_latency|pld_ctrl_normal_latency
      .pcs8g_rx_pipe_if_enable       (pcs8g_rx_pipe_if_enable       ), // dis_pipe_rx|en_pipe_rx
      .pcs8g_rx_pma_done_count       (pcs8g_rx_pma_done_count       ),
      .pcs8g_rx_pma_dw               (pcs8g_rx_pma_dw               ), // eight_bit|ten_bit|sixteen_bit|twenty_bit
      .pcs8g_rx_polarity_inversion   (pcs8g_rx_polarity_inversion   ), // dis_pol_inv|en_pol_inv
      .pcs8g_rx_polinv_8b10b_dec     (pcs8g_rx_polinv_8b10b_dec     ), // dis_polinv_8b10b_dec|en_polinv_8b10b_dec
      .pcs8g_rx_prbs_ver             (pcs8g_rx_prbs_ver             ), // dis_prbs|prbs_7_sw|prbs_7_dw|prbs_8|prbs_10|prbs_23_sw|prbs_23_dw|prbs_15|prbs_31|prbs_hf_sw|prbs_hf_dw|prbs_lf_sw|prbs_lf_dw|prbs_mf_sw|prbs_mf_dw
      .pcs8g_rx_prbs_ver_clr_flag    (pcs8g_rx_prbs_ver_clr_flag    ), // dis_prbs_clr_flag|en_prbs_clr_flag
      .pcs8g_rx_prot_mode            (pcs8g_rx_prot_mode            ), // pipe_g1|pipe_g2|cpri|cpri_rx_tx|gige|xaui|srio_2p1|test|basic|disabled_prot_mode
      .pcs8g_rx_rate_match           (pcs8g_rx_rate_match           ), // dis_rm|xaui_rm|gige_rm|pipe_rm|pipe_rm_0ppm|sw_basic_rm|srio_v2p1_rm|srio_v2p1_rm_0ppm|dw_basic_rm
      .pcs8g_rx_re_bo_on_wa          (pcs8g_rx_re_bo_on_wa          ), // dis_re_bo_on_wa|en_re_bo_on_wa
      .pcs8g_rx_runlength_check      (pcs8g_rx_runlength_check      ), // dis_runlength|en_runlength_sw|en_runlength_dw
      .pcs8g_rx_runlength_val        (pcs8g_rx_runlength_val        ),
      .pcs8g_rx_rx_clk1              (pcs8g_rx_rx_clk1              ), // rcvd_clk_clk1|tx_pma_clock_clk1|rcvd_clk_agg_clk1|rcvd_clk_agg_top_or_bottom_clk1
      .pcs8g_rx_rx_clk2              (pcs8g_rx_rx_clk2              ), // rcvd_clk_clk2|tx_pma_clock_clk2|refclk_dig2_clk2
      .pcs8g_rx_rx_clk_free_running  (pcs8g_rx_rx_clk_free_running  ), // dis_rx_clk_free_run|en_rx_clk_free_run
      .pcs8g_rx_rx_pcs_urst          (pcs8g_rx_rx_pcs_urst          ), // dis_rx_pcs_urst|en_rx_pcs_urst
      .pcs8g_rx_rx_rcvd_clk          (pcs8g_rx_rx_rcvd_clk          ), // rcvd_clk_rcvd_clk|tx_pma_clock_rcvd_clk
      .pcs8g_rx_rx_rd_clk            (pcs8g_rx_rx_rd_clk            ), // pld_rx_clk|rx_clk
      .pcs8g_rx_rx_refclk            (pcs8g_rx_rx_refclk            ), // dis_refclk_sel|en_refclk_sel
      .pcs8g_rx_rx_wr_clk            (pcs8g_rx_rx_wr_clk            ), // rx_clk2_div_1_2_4|txfifo_rd_clk
      .pcs8g_rx_sup_mode             (pcs8g_rx_sup_mode             ), // user_mode|engineering_mode
      .pcs8g_rx_symbol_swap          (pcs8g_rx_symbol_swap          ), // dis_symbol_swap|en_symbol_swap
      .pcs8g_rx_test_bus_sel         (pcs8g_rx_test_bus_sel         ), // prbs_bist_testbus|tx_testbus|tx_ctrl_plane_testbus|wa_testbus|deskew_testbus|rm_testbus|rx_ctrl_testbus|pcie_ctrl_testbus|rx_ctrl_plane_testbus|agg_testbus
      .pcs8g_rx_test_mode            (pcs8g_rx_test_mode            ), // dont_care_test|prbs|bist
      .pcs8g_rx_tx_rx_parallel_loopback(pcs8g_rx_tx_rx_parallel_loopback), // dis_plpbk|en_plpbk
      .pcs8g_rx_use_default_base_address(pcs8g_rx_use_default_base_address), // false|true
      .pcs8g_rx_user_base_address    (pcs8g_rx_user_base_address    ), // 0..2047
      .pcs8g_rx_wa_boundary_lock_ctrl(pcs8g_rx_wa_boundary_lock_ctrl), // bit_slip|sync_sm|deterministic_latency|auto_align_pld_ctrl
      .pcs8g_rx_wa_clk_slip_spacing  (pcs8g_rx_wa_clk_slip_spacing  ), // min_clk_slip_spacing|user_programmable_clk_slip_spacing
      .pcs8g_rx_wa_clk_slip_spacing_data(pcs8g_rx_wa_clk_slip_spacing_data),
      .pcs8g_rx_wa_det_latency_sync_status_beh(pcs8g_rx_wa_det_latency_sync_status_beh), // assert_sync_status_imm|assert_sync_status_non_imm|dont_care_assert_sync
      .pcs8g_rx_wa_disp_err_flag     (pcs8g_rx_wa_disp_err_flag     ), // dis_disp_err_flag|en_disp_err_flag
      .pcs8g_rx_wa_kchar             (pcs8g_rx_wa_kchar             ), // dis_kchar|en_kchar
      .pcs8g_rx_wa_pd                (pcs8g_rx_wa_pd                ), // dont_care_wa_pd_0|dont_care_wa_pd_1|wa_pd_7|wa_pd_10|wa_pd_20|wa_pd_40|wa_pd_8_sw|wa_pd_8_dw|wa_pd_16_sw|wa_pd_16_dw|wa_pd_32|wa_pd_fixed_7_k28p5|wa_pd_fixed_10_k28p5|wa_pd_fixed_16_a1a2_sw|wa_pd_fixed_16_a1a2_dw|wa_pd_fixed_32_a1a1a2a2|prbs15_fixed_wa_pd_16_sw|prbs15_fixed_wa_pd_16_dw|prbs15_fixed_wa_pd_20_dw|prbs31_fixed_wa_pd_16_sw|prbs31_fixed_wa_pd_16_dw|prbs31_fixed_wa_pd_10_sw|prbs31_fixed_wa_pd_40_dw|prbs8_fixed_wa|prbs10_fixed_wa|prbs7_fixed_wa_pd_16_sw|prbs7_fixed_wa_pd_16_dw|prbs7_fixed_wa_pd_20_dw|prbs23_fixed_wa_pd_16_sw|prbs23_fixed_wa_pd_32_dw|prbs23_fixed_wa_pd_40_dw
      .pcs8g_rx_wa_pd_data           (pcs8g_rx_wa_pd_data           ),
      .pcs8g_rx_wa_pd_polarity       (pcs8g_rx_wa_pd_polarity       ), // dis_pd_both_pol|en_pd_both_pol|dont_care_both_pol
      .pcs8g_rx_wa_pld_controlled    (pcs8g_rx_wa_pld_controlled    ), // dis_pld_ctrl|pld_ctrl_sw|rising_edge_sensitive_dw|level_sensitive_dw
      .pcs8g_rx_wa_renumber_data     (pcs8g_rx_wa_renumber_data     ),
      .pcs8g_rx_wa_rgnumber_data     (pcs8g_rx_wa_rgnumber_data     ),
      .pcs8g_rx_wa_rknumber_data     (pcs8g_rx_wa_rknumber_data     ),
      .pcs8g_rx_wa_rosnumber_data    (pcs8g_rx_wa_rosnumber_data    ),
      .pcs8g_rx_wa_rvnumber_data     (pcs8g_rx_wa_rvnumber_data     ),
      .pcs8g_rx_wa_sync_sm_ctrl      (pcs8g_rx_wa_sync_sm_ctrl      ), // gige_sync_sm|pipe_sync_sm|xaui_sync_sm|srio1p3_sync_sm|srio2p1_sync_sm|sw_basic_sync_sm|dw_basic_sync_sm|fibre_channel_sync_sm
      .pcs8g_rx_wait_cnt             (pcs8g_rx_wait_cnt             ),
      // parameters for arriav_hssi_8g_tx_pcs
      .pcs8g_tx_agg_block_sel        (pcs8g_tx_agg_block_sel        ), // same_smrt_pack|other_smrt_pack
      .pcs8g_tx_auto_speed_nego_gen2 (pcs8g_tx_auto_speed_nego_gen2 ), // dis_asn_g2|en_asn_g2_freq_scal
      .pcs8g_tx_bist_gen             (pcs8g_tx_bist_gen             ), // dis_bist|incremental|cjpat|crpat
      .pcs8g_tx_bit_reversal         (pcs8g_tx_bit_reversal         ), // dis_bit_reversal|en_bit_reversal
      .pcs8g_tx_bypass_pipeline_reg  (pcs8g_tx_bypass_pipeline_reg  ), // dis_bypass_pipeline|en_bypass_pipeline
      .pcs8g_tx_byte_serializer      (pcs8g_tx_byte_serializer      ), // dis_bs|en_bs_by_2
      .pcs8g_tx_cid_pattern          (pcs8g_tx_cid_pattern          ), // cid_pattern_0|cid_pattern_1
      .pcs8g_tx_cid_pattern_len      (pcs8g_tx_cid_pattern_len      ),
      .pcs8g_tx_clock_gate_bist      (pcs8g_tx_clock_gate_bist      ), // dis_bist_clk_gating|en_bist_clk_gating
      .pcs8g_tx_clock_gate_bs_enc    (pcs8g_tx_clock_gate_bs_enc    ), // dis_bs_enc_clk_gating|en_bs_enc_clk_gating
      .pcs8g_tx_clock_gate_dw_fifowr (pcs8g_tx_clock_gate_dw_fifowr ), // dis_dw_fifowr_clk_gating|en_dw_fifowr_clk_gating
      .pcs8g_tx_clock_gate_fiford    (pcs8g_tx_clock_gate_fiford    ), // dis_fiford_clk_gating|en_fiford_clk_gating
      .pcs8g_tx_clock_gate_prbs      (pcs8g_tx_clock_gate_prbs      ), // dis_prbs_clk_gating|en_prbs_clk_gating
      .pcs8g_tx_clock_gate_sw_fifowr (pcs8g_tx_clock_gate_sw_fifowr ), // dis_sw_fifowr_clk_gating|en_sw_fifowr_clk_gating
      .pcs8g_tx_data_selection_8b10b_encoder_input(pcs8g_tx_data_selection_8b10b_encoder_input), // normal_data_path|xaui_sm|gige_idle_conversion
      .pcs8g_tx_dynamic_clk_switch   (pcs8g_tx_dynamic_clk_switch   ), // dis_dyn_clk_switch|en_dyn_clk_switch
      .pcs8g_tx_eightb_tenb_disp_ctrl(pcs8g_tx_eightb_tenb_disp_ctrl), // dis_disp_ctrl|en_disp_ctrl|en_ib_disp_ctrl
      .pcs8g_tx_eightb_tenb_encoder  (pcs8g_tx_eightb_tenb_encoder  ), // dis_8b10b|en_8b10b_ibm|en_8b10b_sgx
      .pcs8g_tx_force_echar          (pcs8g_tx_force_echar          ), // dis_force_echar|en_force_echar
      .pcs8g_tx_force_kchar          (pcs8g_tx_force_kchar          ), // dis_force_kchar|en_force_kchar
      .pcs8g_tx_hip_mode             (pcs8g_tx_hip_mode             ), // dis_hip|en_hip
      .pcs8g_tx_pcfifo_urst          (pcs8g_tx_pcfifo_urst          ), // dis_pcfifourst|en_pcfifourst
      .pcs8g_tx_pcs_bypass           (pcs8g_tx_pcs_bypass           ), // dis_pcs_bypass|en_pcs_bypass
      .pcs8g_tx_phase_compensation_fifo(pcs8g_tx_phase_compensation_fifo), // low_latency|normal_latency|register_fifo|pld_ctrl_low_latency|pld_ctrl_normal_latency
      .pcs8g_tx_phfifo_write_clk_sel (pcs8g_tx_phfifo_write_clk_sel ), // pld_tx_clk|tx_clk
      .pcs8g_tx_pma_dw               (pcs8g_tx_pma_dw               ), // eight_bit|ten_bit|sixteen_bit|twenty_bit
      .pcs8g_tx_polarity_inversion   (pcs8g_tx_polarity_inversion   ), // dis_polinv|enable_polinv
      .pcs8g_tx_prbs_gen             (pcs8g_tx_prbs_gen             ), // dis_prbs|prbs_7_sw|prbs_7_dw|prbs_8|prbs_10|prbs_23_sw|prbs_23_dw|prbs_15|prbs_31|prbs_hf_sw|prbs_hf_dw|prbs_lf_sw|prbs_lf_dw|prbs_mf_sw|prbs_mf_dw
      .pcs8g_tx_prot_mode            (pcs8g_tx_prot_mode            ), // pipe_g1|pipe_g2|cpri|cpri_rx_tx|gige|xaui|srio_2p1|test|basic|disabled_prot_mode
      .pcs8g_tx_refclk_b_clk_sel     (pcs8g_tx_refclk_b_clk_sel     ), // tx_pma_clock|refclk_dig
      .pcs8g_tx_revloop_back_rm      (pcs8g_tx_revloop_back_rm      ), // dis_rev_loopback_rx_rm|en_rev_loopback_rx_rm
      .pcs8g_tx_sup_mode             (pcs8g_tx_sup_mode             ), // user_mode|engineering_mode
      .pcs8g_tx_symbol_swap          (pcs8g_tx_symbol_swap          ), // dis_symbol_swap|en_symbol_swap
      .pcs8g_tx_test_mode            (pcs8g_tx_test_mode            ), // dont_care_test|prbs|bist
      .pcs8g_tx_tx_bitslip           (pcs8g_tx_tx_bitslip           ), // dis_tx_bitslip|en_tx_bitslip
      .pcs8g_tx_tx_compliance_controlled_disparity(pcs8g_tx_tx_compliance_controlled_disparity), // dis_txcompliance|en_txcompliance_pipe2p0
      .pcs8g_tx_txclk_freerun        (pcs8g_tx_txclk_freerun        ), // dis_freerun_tx|en_freerun_tx
      .pcs8g_tx_txpcs_urst           (pcs8g_tx_txpcs_urst           ), // dis_txpcs_urst|en_txpcs_urst
      .pcs8g_tx_use_default_base_address(pcs8g_tx_use_default_base_address), // false|true
      .pcs8g_tx_user_base_address    (pcs8g_tx_user_base_address    ), // 0..2047
      // parameters for arriav_hssi_common_pcs_pma_interface
      .com_pcs_pma_if_auto_speed_ena (com_pcs_pma_if_auto_speed_ena ), // dis_auto_speed_ena|en_auto_speed_ena
      .com_pcs_pma_if_force_freqdet  (com_pcs_pma_if_force_freqdet  ), // force_freqdet_dis|force1_freqdet_en|force0_freqdet_en
      .com_pcs_pma_if_func_mode      (com_pcs_pma_if_func_mode      ), // disable|hrdrstctrl_cmu|eightg_only_pld|eightg_only_hip|pma_direct
      .com_pcs_pma_if_pipe_if_g3pcs  (com_pcs_pma_if_pipe_if_g3pcs  ), // pipe_if_8gpcs
      .com_pcs_pma_if_pma_if_dft_en  (com_pcs_pma_if_pma_if_dft_en  ), // dft_dis
      .com_pcs_pma_if_pma_if_dft_val (com_pcs_pma_if_pma_if_dft_val ), // dft_0
      .com_pcs_pma_if_ppm_cnt_rst    (com_pcs_pma_if_ppm_cnt_rst    ), // ppm_cnt_rst_dis|ppm_cnt_rst_en
      .com_pcs_pma_if_ppm_deassert_early(com_pcs_pma_if_ppm_deassert_early), // deassert_early_dis|deassert_early_en
      .com_pcs_pma_if_ppm_gen1_2_cnt (com_pcs_pma_if_ppm_gen1_2_cnt ), // cnt_32k|cnt_64k
      .com_pcs_pma_if_ppm_post_eidle_delay(com_pcs_pma_if_ppm_post_eidle_delay), // cnt_200_cycles|cnt_400_cycles
      .com_pcs_pma_if_ppmsel         (com_pcs_pma_if_ppmsel         ), // ppmsel_default|ppmsel_1000|ppmsel_500|ppmsel_300|ppmsel_250|ppmsel_200|ppmsel_125|ppmsel_100|ppmsel_62p5|ppm_other
      .com_pcs_pma_if_prot_mode      (com_pcs_pma_if_prot_mode      ), // disabled_prot_mode|pipe_g1|pipe_g2|other_protocols
      .com_pcs_pma_if_selectpcs      (com_pcs_pma_if_selectpcs      ), // eight_g_pcs
      .com_pcs_pma_if_sup_mode       (com_pcs_pma_if_sup_mode       ), // user_mode|engineering_mode
      .com_pcs_pma_if_use_default_base_address(com_pcs_pma_if_use_default_base_address), // false|true
      .com_pcs_pma_if_user_base_address(com_pcs_pma_if_user_base_address), // 0..2047
      // parameters for arriav_hssi_common_pld_pcs_interface
      .com_pld_pcs_if_hip_enable     (com_pld_pcs_if_hip_enable     ), // hip_disable|hip_enable
      .com_pld_pcs_if_hrdrstctrl_en_cfg(com_pld_pcs_if_hrdrstctrl_en_cfg), // hrst_dis_cfg|hrst_en_cfg
      .com_pld_pcs_if_hrdrstctrl_en_cfgusr(com_pld_pcs_if_hrdrstctrl_en_cfgusr), // hrst_dis_cfgusr|hrst_en_cfgusr
      .com_pld_pcs_if_pld_side_data_source(com_pld_pcs_if_pld_side_data_source), // hip|pld
      .com_pld_pcs_if_pld_side_reserved_source0(com_pld_pcs_if_pld_side_reserved_source0), // pld_res0|hip_res0
      .com_pld_pcs_if_pld_side_reserved_source1(com_pld_pcs_if_pld_side_reserved_source1), // pld_res1|hip_res1
      .com_pld_pcs_if_pld_side_reserved_source10(com_pld_pcs_if_pld_side_reserved_source10), // pld_res10|hip_res10
      .com_pld_pcs_if_pld_side_reserved_source11(com_pld_pcs_if_pld_side_reserved_source11), // pld_res11|hip_res11
      .com_pld_pcs_if_pld_side_reserved_source2(com_pld_pcs_if_pld_side_reserved_source2), // pld_res2|hip_res2
      .com_pld_pcs_if_pld_side_reserved_source3(com_pld_pcs_if_pld_side_reserved_source3), // pld_res3|hip_res3
      .com_pld_pcs_if_pld_side_reserved_source4(com_pld_pcs_if_pld_side_reserved_source4), // pld_res4|hip_res4
      .com_pld_pcs_if_pld_side_reserved_source5(com_pld_pcs_if_pld_side_reserved_source5), // pld_res5|hip_res5
      .com_pld_pcs_if_pld_side_reserved_source6(com_pld_pcs_if_pld_side_reserved_source6), // pld_res6|hip_res6
      .com_pld_pcs_if_pld_side_reserved_source7(com_pld_pcs_if_pld_side_reserved_source7), // pld_res7|hip_res7
      .com_pld_pcs_if_pld_side_reserved_source8(com_pld_pcs_if_pld_side_reserved_source8), // pld_res8|hip_res8
      .com_pld_pcs_if_pld_side_reserved_source9(com_pld_pcs_if_pld_side_reserved_source9), // pld_res9|hip_res9
      .com_pld_pcs_if_testbus_sel    (com_pld_pcs_if_testbus_sel    ), // eight_g_pcs|pma_if
      .com_pld_pcs_if_use_default_base_address(com_pld_pcs_if_use_default_base_address), // false|true
      .com_pld_pcs_if_user_base_address(com_pld_pcs_if_user_base_address), // 0..2047
      .com_pld_pcs_if_usrmode_sel4rst(com_pld_pcs_if_usrmode_sel4rst), // usermode|last_frz
      // parameters for arriav_hssi_pipe_gen1_2
      .pipe12_elec_idle_delay_val    (pipe12_elec_idle_delay_val    ),
      .pipe12_elecidle_delay         (pipe12_elecidle_delay         ), // elec_idle_delay
      .pipe12_error_replace_pad      (pipe12_error_replace_pad      ), // replace_edb|replace_pad
      .pipe12_hip_mode               (pipe12_hip_mode               ), // dis_hip|en_hip
      .pipe12_ind_error_reporting    (pipe12_ind_error_reporting    ), // dis_ind_error_reporting|en_ind_error_reporting
      .pipe12_phy_status_delay       (pipe12_phy_status_delay       ), // phystatus_delay
      .pipe12_phystatus_delay_val    (pipe12_phystatus_delay_val    ),
      .pipe12_phystatus_rst_toggle   (pipe12_phystatus_rst_toggle   ), // dis_phystatus_rst_toggle|en_phystatus_rst_toggle
      .pipe12_pipe_byte_de_serializer_en(pipe12_pipe_byte_de_serializer_en), // dis_bds|en_bds_by_2|dont_care_bds
      .pipe12_prot_mode              (pipe12_prot_mode              ), // pipe_g1|pipe_g2|srio_2p1|basic|disabled_prot_mode
      .pipe12_rpre_emph_a_val        (pipe12_rpre_emph_a_val        ),
      .pipe12_rpre_emph_b_val        (pipe12_rpre_emph_b_val        ),
      .pipe12_rpre_emph_c_val        (pipe12_rpre_emph_c_val        ),
      .pipe12_rpre_emph_d_val        (pipe12_rpre_emph_d_val        ),
      .pipe12_rpre_emph_e_val        (pipe12_rpre_emph_e_val        ),
      .pipe12_rpre_emph_settings     (pipe12_rpre_emph_settings     ),
      .pipe12_rvod_sel_a_val         (pipe12_rvod_sel_a_val         ),
      .pipe12_rvod_sel_b_val         (pipe12_rvod_sel_b_val         ),
      .pipe12_rvod_sel_c_val         (pipe12_rvod_sel_c_val         ),
      .pipe12_rvod_sel_d_val         (pipe12_rvod_sel_d_val         ),
      .pipe12_rvod_sel_e_val         (pipe12_rvod_sel_e_val         ),
      .pipe12_rvod_sel_settings      (pipe12_rvod_sel_settings      ),
      .pipe12_rx_pipe_enable         (pipe12_rx_pipe_enable         ), // dis_pipe_rx|en_pipe_rx
      .pipe12_rxdetect_bypass        (pipe12_rxdetect_bypass        ), // dis_rxdetect_bypass|en_rxdetect_bypass
      .pipe12_sup_mode               (pipe12_sup_mode               ), // user_mode|engineering_mode
      .pipe12_tx_pipe_enable         (pipe12_tx_pipe_enable         ), // dis_pipe_tx|en_pipe_tx
      .pipe12_txswing                (pipe12_txswing                ), // dis_txswing|en_txswing
      .pipe12_use_default_base_address(pipe12_use_default_base_address), // false|true
      .pipe12_user_base_address      (pipe12_user_base_address      ), // 0..2047
      // parameters for arriav_hssi_rx_pcs_pma_interface
      .rx_pcs_pma_if_clkslip_sel     (rx_pcs_pma_if_clkslip_sel     ), // pld|slip_eight_g_pcs
      .rx_pcs_pma_if_prot_mode       (rx_pcs_pma_if_prot_mode       ), // other_protocols|cpri_8g
      .rx_pcs_pma_if_selectpcs       (rx_pcs_pma_if_selectpcs       ), // eight_g_pcs|default
      .rx_pcs_pma_if_use_default_base_address(rx_pcs_pma_if_use_default_base_address), // false|true
      .rx_pcs_pma_if_user_base_address(rx_pcs_pma_if_user_base_address), // 0..2047
      // parameters for arriav_hssi_rx_pld_pcs_interface
      .rx_pld_pcs_if_is_8g_0ppm      (rx_pld_pcs_if_is_8g_0ppm      ), // false|true
      .rx_pld_pcs_if_pcs_side_block_sel(rx_pld_pcs_if_pcs_side_block_sel), // eight_g_pcs|default
      .rx_pld_pcs_if_pld_side_data_source(rx_pld_pcs_if_pld_side_data_source), // hip|pld
      .rx_pld_pcs_if_use_default_base_address(rx_pld_pcs_if_use_default_base_address), // false|true
      .rx_pld_pcs_if_user_base_address(rx_pld_pcs_if_user_base_address), // 0..2047
      // parameters for arriav_hssi_tx_pcs_pma_interface
      .tx_pcs_pma_if_selectpcs       (tx_pcs_pma_if_selectpcs       ), // eight_g_pcs|default
      .tx_pcs_pma_if_use_default_base_address(tx_pcs_pma_if_use_default_base_address), // false|true
      .tx_pcs_pma_if_user_base_address(tx_pcs_pma_if_user_base_address), // 0..2047
      // parameters for arriav_hssi_tx_pld_pcs_interface
      .tx_pld_pcs_if_is_8g_0ppm      (tx_pld_pcs_if_is_8g_0ppm      ), // false|true
      .tx_pld_pcs_if_pld_side_data_source(tx_pld_pcs_if_pld_side_data_source), // hip|pld
      .tx_pld_pcs_if_use_default_base_address(tx_pld_pcs_if_use_default_base_address), // false|true
      .tx_pld_pcs_if_user_base_address(tx_pld_pcs_if_user_base_address)  // 0..2047
    ) inst_av_pcs (
      .in_agg_align_status           (in_agg_align_status           ),
      .in_agg_align_status_sync_0    (in_agg_align_status_sync_0    ),
      .in_agg_align_status_sync_0_top_or_bot(in_agg_align_status_sync_0_top_or_bot),
      .in_agg_align_status_top_or_bot(in_agg_align_status_top_or_bot),
      .in_agg_cg_comp_rd_d_all       (in_agg_cg_comp_rd_d_all       ),
      .in_agg_cg_comp_rd_d_all_top_or_bot(in_agg_cg_comp_rd_d_all_top_or_bot),
      .in_agg_cg_comp_wr_all         (in_agg_cg_comp_wr_all         ),
      .in_agg_cg_comp_wr_all_top_or_bot(in_agg_cg_comp_wr_all_top_or_bot),
      .in_agg_del_cond_met_0         (in_agg_del_cond_met_0         ),
      .in_agg_del_cond_met_0_top_or_bot(in_agg_del_cond_met_0_top_or_bot),
      .in_agg_en_dskw_qd             (in_agg_en_dskw_qd             ),
      .in_agg_en_dskw_qd_top_or_bot  (in_agg_en_dskw_qd_top_or_bot  ),
      .in_agg_en_dskw_rd_ptrs        (in_agg_en_dskw_rd_ptrs        ),
      .in_agg_en_dskw_rd_ptrs_top_or_bot(in_agg_en_dskw_rd_ptrs_top_or_bot),
      .in_agg_fifo_ovr_0             (in_agg_fifo_ovr_0             ),
      .in_agg_fifo_ovr_0_top_or_bot  (in_agg_fifo_ovr_0_top_or_bot  ),
      .in_agg_fifo_rd_in_comp_0      (in_agg_fifo_rd_in_comp_0      ),
      .in_agg_fifo_rd_in_comp_0_top_or_bot(in_agg_fifo_rd_in_comp_0_top_or_bot),
      .in_agg_fifo_rst_rd_qd         (in_agg_fifo_rst_rd_qd         ),
      .in_agg_fifo_rst_rd_qd_top_or_bot(in_agg_fifo_rst_rd_qd_top_or_bot),
      .in_agg_insert_incomplete_0    (in_agg_insert_incomplete_0    ),
      .in_agg_insert_incomplete_0_top_or_bot(in_agg_insert_incomplete_0_top_or_bot),
      .in_agg_latency_comp_0         (in_agg_latency_comp_0         ),
      .in_agg_latency_comp_0_top_or_bot(in_agg_latency_comp_0_top_or_bot),
      .in_agg_rcvd_clk_agg           (in_agg_rcvd_clk_agg           ),
      .in_agg_rcvd_clk_agg_top_or_bot(in_agg_rcvd_clk_agg_top_or_bot),
      .in_agg_rx_control_rs          (in_agg_rx_control_rs          ),
      .in_agg_rx_control_rs_top_or_bot(in_agg_rx_control_rs_top_or_bot),
      .in_agg_rx_data_rs             (in_agg_rx_data_rs             ),
      .in_agg_rx_data_rs_top_or_bot  (in_agg_rx_data_rs_top_or_bot  ),
      .in_agg_test_so_to_pld_in      (in_agg_test_so_to_pld_in      ),
      .in_agg_testbus                (in_agg_testbus                ),
      .in_agg_tx_ctl_ts              (in_agg_tx_ctl_ts              ),
      .in_agg_tx_ctl_ts_top_or_bot   (in_agg_tx_ctl_ts_top_or_bot   ),
      .in_agg_tx_data_ts             (in_agg_tx_data_ts             ),
      .in_agg_tx_data_ts_top_or_bot  (in_agg_tx_data_ts_top_or_bot  ),
      .in_avmmaddress                (chnl_avmm_address             ),
      .in_avmmbyteen                 (chnl_avmm_byteen              ),
      .in_avmmclk                    (chnl_avmm_clk                 ),
      .in_avmmread                   (chnl_avmm_read                ),
      .in_avmmrstn                   (chnl_avmm_rstn                ),
      .in_avmmwrite                  (chnl_avmm_write               ),
      .in_avmmwritedata              (chnl_avmm_writedata           ),
      .in_emsip_com_in               (in_emsip_com_in               ),
      .in_emsip_rx_special_in        (in_emsip_rx_special_in        ),
      .in_emsip_tx_in                (in_emsip_tx_in                ),
      .in_emsip_tx_special_in        (in_emsip_tx_special_in        ),
      .in_pld_8g_a1a2_size           (in_pld_8g_a1a2_size           ),
      .in_pld_8g_bitloc_rev_en       (in_pld_8g_bitloc_rev_en       ),
      .in_pld_8g_bitslip             (in_pld_8g_bitslip             ),
      .in_pld_8g_byte_rev_en         (in_pld_8g_byte_rev_en         ),
      .in_pld_8g_bytordpld           (in_pld_8g_bytordpld           ),
      .in_pld_8g_cmpfifourst_n       (in_pld_8g_cmpfifourst_n       ),
      .in_pld_8g_encdt               (in_pld_8g_encdt               ),
      .in_pld_8g_phfifourst_rx_n     (in_pld_8g_phfifourst_rx_n     ),
      .in_pld_8g_phfifourst_tx_n     (in_pld_8g_phfifourst_tx_n     ),
      .in_pld_8g_pld_rx_clk          (in_pld_8g_pld_rx_clk          ),
      .in_pld_8g_pld_tx_clk          (in_pld_8g_pld_tx_clk          ),
      .in_pld_8g_polinv_rx           (in_pld_8g_polinv_rx           ),
      .in_pld_8g_polinv_tx           (in_pld_8g_polinv_tx           ),
      .in_pld_8g_powerdown           (in_pld_8g_powerdown           ),
      .in_pld_8g_prbs_cid_en         (in_pld_8g_prbs_cid_en         ),
      .in_pld_8g_rddisable_tx        (in_pld_8g_rddisable_tx        ),
      .in_pld_8g_rdenable_rmf        (in_pld_8g_rdenable_rmf        ),
      .in_pld_8g_rdenable_rx         (in_pld_8g_rdenable_rx         ),
      .in_pld_8g_refclk_dig          (in_pld_8g_refclk_dig          ),
      .in_pld_8g_refclk_dig2         (in_pld_8g_refclk_dig2         ),
      .in_pld_8g_rev_loopbk          (in_pld_8g_rev_loopbk          ),
      .in_pld_8g_rxpolarity          (in_pld_8g_rxpolarity          ),
      .in_pld_8g_rxurstpcs_n         (out_pld_8g_rxurstpcs_n        ),
      .in_pld_8g_tx_boundary_sel     (in_pld_8g_tx_boundary_sel     ),
      .in_pld_8g_tx_data_valid       (in_pld_8g_tx_data_valid       ),
      .in_pld_8g_txdeemph            (in_pld_8g_txdeemph            ),
      .in_pld_8g_txdetectrxloopback  (in_pld_8g_txdetectrxloopback  ),
      .in_pld_8g_txelecidle          (in_pld_8g_txelecidle          ),
      .in_pld_8g_txmargin            (in_pld_8g_txmargin            ),
      .in_pld_8g_txswing             (in_pld_8g_txswing             ),
      .in_pld_8g_txurstpcs_n         (out_pld_8g_txurstpcs_n        ),
      .in_pld_8g_wrdisable_rx        (in_pld_8g_wrdisable_rx        ),
      .in_pld_8g_wrenable_rmf        (in_pld_8g_wrenable_rmf        ),
      .in_pld_8g_wrenable_tx         (in_pld_8g_wrenable_tx         ),
      .in_pld_agg_refclk_dig         (in_pld_agg_refclk_dig         ),
      .in_pld_eidleinfersel          (in_pld_eidleinfersel          ),
      .in_pld_ltr                    (in_pld_ltr                    ),
      .in_pld_partial_reconfig_in    (in_pld_partial_reconfig_in    ),
      .in_pld_pcs_pma_if_refclk_dig  (in_pld_pcs_pma_if_refclk_dig  ),
      .in_pld_rate                   (in_pld_rate                   ),
      .in_pld_reserved_in            (in_pld_reserved_in            ),
      .in_pld_rx_clk_slip_in         (in_pld_rx_clk_slip_in         ),
      .in_pld_rxpma_rstb_in          (out_pld_rxpma_rstb_in         ),
      .in_pld_scan_mode_n            (in_pld_scan_mode_n            ),
      .in_pld_scan_shift_n           (in_pld_scan_shift_n           ),
      .in_pld_sync_sm_en             (in_pld_sync_sm_en             ),
      .in_pld_tx_data                (in_pld_tx_data                ),
      .in_pma_clklow_in              (rx_clklow                     ),
      .in_pma_fref_in                (rx_fref                       ),
      .in_pma_hclk                   (in_pma_hclk                   ),
      .in_pma_pcie_sw_done           (tx_pcieswdone                 ),
      .in_pma_reserved_in            (in_pma_reserved_in            ),
      .in_pma_rx_data                (in_pma_rx_data                ),
      .in_pma_rx_detect_valid        (tx_rxdetectvalid              ),
      .in_pma_rx_found               (tx_rxfound                    ),
      .in_pma_rx_freq_tx_cmu_pll_lock_in(in_pma_rx_freq_tx_cmu_pll_lock_in),
      .in_pma_rx_pll_phase_lock_in   (out_pcs_rx_pll_phase_lock_out ),
      .in_pma_rx_pma_clk             (rx_clkdivrx                   ),
      .in_pma_sigdet                 (rx_sd                         ),
      .in_pma_tx_pma_clk             (tx_clkdivtx                   ),
      .out_agg_align_det_sync        (out_agg_align_det_sync        ),
      .out_agg_align_status_sync     (out_agg_align_status_sync     ),
      .out_agg_cg_comp_rd_d_out      (out_agg_cg_comp_rd_d_out      ),
      .out_agg_cg_comp_wr_out        (out_agg_cg_comp_wr_out        ),
      .out_agg_dec_ctl               (out_agg_dec_ctl               ),
      .out_agg_dec_data              (out_agg_dec_data              ),
      .out_agg_dec_data_valid        (out_agg_dec_data_valid        ),
      .out_agg_del_cond_met_out      (out_agg_del_cond_met_out      ),
      .out_agg_fifo_ovr_out          (out_agg_fifo_ovr_out          ),
      .out_agg_fifo_rd_out_comp      (out_agg_fifo_rd_out_comp      ),
      .out_agg_insert_incomplete_out (out_agg_insert_incomplete_out ),
      .out_agg_latency_comp_out      (out_agg_latency_comp_out      ),
      .out_agg_rd_align              (out_agg_rd_align              ),
      .out_agg_rd_enable_sync        (out_agg_rd_enable_sync        ),
      .out_agg_refclk_dig            (out_agg_refclk_dig            ),
      .out_agg_running_disp          (out_agg_running_disp          ),
      .out_agg_rxpcs_rst             (out_agg_rxpcs_rst             ),
      .out_agg_scan_mode_n           (out_agg_scan_mode_n           ),
      .out_agg_scan_shift_n          (out_agg_scan_shift_n          ),
      .out_agg_sync_status           (out_agg_sync_status           ),
      .out_agg_tx_ctl_tc             (out_agg_tx_ctl_tc             ),
      .out_agg_tx_data_tc            (out_agg_tx_data_tc            ),
      .out_agg_txpcs_rst             (out_agg_txpcs_rst             ),
      .out_avmmreaddata_com_pcs_pma_if(out_avmmreaddata_com_pcs_pma_if),
      .out_avmmreaddata_com_pld_pcs_if(out_avmmreaddata_com_pld_pcs_if),
      .out_avmmreaddata_pcs8g_rx     (out_avmmreaddata_pcs8g_rx     ),
      .out_avmmreaddata_pcs8g_tx     (out_avmmreaddata_pcs8g_tx     ),
      .out_avmmreaddata_pipe12       (out_avmmreaddata_pipe12       ),
      .out_avmmreaddata_rx_pcs_pma_if(out_avmmreaddata_rx_pcs_pma_if),
      .out_avmmreaddata_rx_pld_pcs_if(out_avmmreaddata_rx_pld_pcs_if),
      .out_avmmreaddata_tx_pcs_pma_if(out_avmmreaddata_tx_pcs_pma_if),
      .out_avmmreaddata_tx_pld_pcs_if(out_avmmreaddata_tx_pld_pcs_if),
      .out_blockselect_com_pcs_pma_if(out_blockselect_com_pcs_pma_if),
      .out_blockselect_com_pld_pcs_if(out_blockselect_com_pld_pcs_if),
      .out_blockselect_pcs8g_rx      (out_blockselect_pcs8g_rx      ),
      .out_blockselect_pcs8g_tx      (out_blockselect_pcs8g_tx      ),
      .out_blockselect_pipe12        (out_blockselect_pipe12        ),
      .out_blockselect_rx_pcs_pma_if (out_blockselect_rx_pcs_pma_if ),
      .out_blockselect_rx_pld_pcs_if (out_blockselect_rx_pld_pcs_if ),
      .out_blockselect_tx_pcs_pma_if (out_blockselect_tx_pcs_pma_if ),
      .out_blockselect_tx_pld_pcs_if (out_blockselect_tx_pld_pcs_if ),
      .out_emsip_com_clk_out         (out_emsip_com_clk_out         ),
      .out_emsip_com_out             (out_emsip_com_out             ),
      .out_emsip_rx_out              (out_emsip_rx_out              ),
      .out_emsip_rx_special_out      (out_emsip_rx_special_out      ),
      .out_emsip_tx_clk_out          (out_emsip_tx_clk_out          ),
      .out_emsip_tx_special_out      (out_emsip_tx_special_out      ),
      .out_pld_8g_a1a2_k1k2_flag     (out_pld_8g_a1a2_k1k2_flag     ),
      .out_pld_8g_align_status       (out_pld_8g_align_status       ),
      .out_pld_8g_bistdone           (out_pld_8g_bistdone           ),
      .out_pld_8g_bisterr            (out_pld_8g_bisterr            ),
      .out_pld_8g_byteord_flag       (out_pld_8g_byteord_flag       ),
      .out_pld_8g_empty_rmf          (out_pld_8g_empty_rmf          ),
      .out_pld_8g_empty_rx           (out_pld_8g_empty_rx           ),
      .out_pld_8g_empty_tx           (out_pld_8g_empty_tx           ),
      .out_pld_8g_full_rmf           (out_pld_8g_full_rmf           ),
      .out_pld_8g_full_rx            (out_pld_8g_full_rx            ),
      .out_pld_8g_full_tx            (out_pld_8g_full_tx            ),
      .out_pld_8g_phystatus          (out_pld_8g_phystatus          ),
      .out_pld_8g_rlv_lt             (out_pld_8g_rlv_lt             ),
      .out_pld_8g_rx_clk_out         (out_pld_8g_rx_clk_out         ),
      .out_pld_8g_rx_data_valid      (out_pld_8g_rx_data_valid      ),
      .out_pld_8g_rxelecidle         (out_pld_8g_rxelecidle         ),
      .out_pld_8g_rxstatus           (out_pld_8g_rxstatus           ),
      .out_pld_8g_rxvalid            (out_pld_8g_rxvalid            ),
      .out_pld_8g_signal_detect_out  (out_pld_8g_signal_detect_out  ),
      .out_pld_8g_tx_clk_out         (out_pld_8g_tx_clk_out         ),
      .out_pld_8g_wa_boundary        (out_pld_8g_wa_boundary        ),
      .out_pld_clklow                (out_pld_clklow                ),
      .out_pld_fref                  (out_pld_fref                  ),
      .out_pld_reserved_out          (out_pld_reserved_out          ),
      .out_pld_rx_data               (out_pld_rx_data               ),
      .out_pld_test_data             (out_pld_test_data             ),
      .out_pld_test_si_to_agg_out    (out_pld_test_si_to_agg_out    ),
      .out_pma_current_coeff         (out_pma_current_coeff         ),
      .out_pma_early_eios            (out_pma_early_eios            ),
      .out_pma_ltr                   (out_pma_ltr                   ),
      .out_pma_nfrzdrv               (out_pma_nfrzdrv               ),
      .out_pma_partial_reconfig      (out_pma_partial_reconfig      ),
      .out_pma_pcie_switch           (out_pma_pcie_switch           ),
      .out_pma_ppm_lock              (out_pma_ppm_lock              ),
      .out_pma_reserved_out          (out_pma_reserved_out          ),
      .out_pma_rx_clk_out            (out_pma_rx_clk_out            ),
      .out_pma_rxclkslip             (out_pma_rxclkslip             ),
      .out_pma_rxpma_rstb            (out_pma_rxpma_rstb            ),
      .out_pma_tx_clk_out            (out_pma_tx_clk_out            ),
      .out_pma_tx_data               (out_pma_tx_data               ),
      .out_pma_tx_elec_idle          (out_pma_tx_elec_idle          ),
      .out_pma_txdetectrx            (out_pma_txdetectrx            )
);


  av_xcvr_avmm #(
      .bonded_lanes                  (bonded_lanes                  ), // Number of lanes
      .bonding_master_ch             (bonding_master_ch             ), // Indicates which channel is master
      .bonding_master_only           (bonding_master_only           ), // Indicates which channels are MASTER_ONLY. List of strings.
      .pma_reserved_ch               (pma_reserved_ch               ), // Indicates which channels are reserved
      // PMA enables
      .rx_enable                     (rx_enable                     ), // Indicates whether this interface contains an rx channel.
      .tx_enable                     (tx_enable                     ), // Indicates whether this interface contains a tx channel
      // PCS enables
      .enable_8g_tx                  (enable_8g_tx                  ), // Is 8g TX PCS enabled?
      .enable_8g_rx                  (enable_8g_rx                  ), // Is 8g RX PCS enabled?
      // Services requests
      .request_dcd                   (request_dcd                   ), // Request Duty Cycle Distortion correction at startup
      .request_vrc                   (request_vrc                   ),  // Request Voltage Regulator Calibration at startup
      .request_offset                (request_offset                )  // Request RX Offset Cancellation at startup - defaults to enabled, only PCIE w/HIP should unset this
    ) inst_av_xcvr_avmm (
      // Reconfiguration signal bundles
      .reconfig_to_xcvr              (reconfig_to_xcvr              ),
      .reconfig_from_xcvr            (reconfig_from_xcvr            ),
      // Control inputs from PLD
      .seriallpbken                  (seriallpbken                  ), // 1 = enable serial loopback
      // PCS clocks
      .in_pld_8g_pld_rx_clk          (in_pld_8g_pld_rx_clk          ), // 8g PCS RX clock
      // PCS resets
      .in_pld_8g_txurstpcs_n         (in_pld_8g_txurstpcs_n         ), // 8g PCS TX reset
      .in_pld_8g_rxurstpcs_n         (in_pld_8g_rxurstpcs_n         ), // 8g PCS RX reset
      .out_pld_8g_txurstpcs_n        (out_pld_8g_txurstpcs_n        ), // 8g PCS TX reset
      .out_pld_8g_rxurstpcs_n        (out_pld_8g_rxurstpcs_n        ), // 8g PCS RX reset
      // PMA resets
      .rx_crurstn                    (rx_crurstn                    ), // CDR analog reset (active low)
      .in_pld_rxpma_rstb_in          (in_pld_rxpma_rstb_in          ),
      .out_rx_crurstn                (out_rx_crurstn                ), // CDR analog reset (active low)
      .out_pld_rxpma_rstb_in         (out_pld_rxpma_rstb_in         ),
      // PCS data
      .out_pld_rx_data               (out_pld_rx_data               ), // PCS data output
      // Calibration clocks
      .calclk                        (calclk                        ), // Calibration clock driven from reconfig clock to aux block
      //calibration status
      .tx_cal_busy                   (tx_cal_busy                   ),
      .rx_cal_busy                   (rx_cal_busy                   ),
      // Reconfig controls
      .pma_hardoccalen               (pma_hardoccalen               ),
      .pma_seriallpbken              (pma_seriallpbken              ),
      // Reconfig status
      .pcs_8g_prbs_done              ( {bonded_lanes{1'b0}}         ),
      .pcs_8g_prbs_err               ( {bonded_lanes{1'b0}}         ),
      // Channel AVMM interface signals
      .chnl_avmm_clk                 (chnl_avmm_clk                 ),
      .chnl_avmm_rstn                (chnl_avmm_rstn                ),
      .chnl_avmm_writedata           (chnl_avmm_writedata           ),
      .chnl_avmm_address             (chnl_avmm_address             ),
      .chnl_avmm_write               (chnl_avmm_write               ),
      .chnl_avmm_read                (chnl_avmm_read                ),
      .chnl_avmm_byteen              (chnl_avmm_byteen              ),
      // PMA AVMM signals
      .pma_avmmreaddata_tx_cgb       (pma_avmmreaddata_tx_cgb       ), // TX AVMM CGB readdata (16 for each lane)
      .pma_avmmreaddata_tx_ser       (pma_avmmreaddata_tx_ser       ), // TX AVMM SER readdata (16 for each lane)
      .pma_avmmreaddata_tx_buf       (pma_avmmreaddata_tx_buf       ), // TX AVMM BUF readdata (16 for each lane)
      .pma_avmmreaddata_rx_ser       (pma_avmmreaddata_rx_ser       ), // RX AVMM SER readdata (16 for each lane)
      .pma_avmmreaddata_rx_buf       (pma_avmmreaddata_rx_buf       ), // RX AVMM BUF readdata (16 for each lane)
      .pma_avmmreaddata_rx_cdr       (pma_avmmreaddata_rx_cdr       ), // RX AVMM CDR readdata (16 for each lane)
      .pma_avmmreaddata_rx_mux       (pma_avmmreaddata_rx_mux       ), // RX AVMM CDR MUX readdata (16 for each lane)
      .pma_blockselect_tx_cgb        (pma_blockselect_tx_cgb        ), // TX AVMM CGB blockselect (1 for each lane)
      .pma_blockselect_tx_ser        (pma_blockselect_tx_ser        ), // TX AVMM SER blockselect (1 for each lane)
      .pma_blockselect_tx_buf        (pma_blockselect_tx_buf        ), // TX AVMM BUF blockselect (1 for each lane)
      .pma_blockselect_rx_ser        (pma_blockselect_rx_ser        ), // RX AVMM SER blockselect (1 for each lane)
      .pma_blockselect_rx_buf        (pma_blockselect_rx_buf        ), // RX AVMM BUF blockselect (1 for each lane)
      .pma_blockselect_rx_cdr        (pma_blockselect_rx_cdr        ), // RX AVMM CDR blockselect (1 for each lane)
      .pma_blockselect_rx_mux        (pma_blockselect_rx_mux        ), // RX AVMM CDR MUX blockselect (1 for each lane)
      .pll_aux_atb_comp_out          (pll_aux_atb_comp_out          ), // Voltage comparator output for DCD (1 for each lane)
      // PCS AVMM signals
      .avmmreaddata_com_pcs_pma_if   (out_avmmreaddata_com_pcs_pma_if),
      .avmmreaddata_com_pld_pcs_if   (out_avmmreaddata_com_pld_pcs_if),
      .avmmreaddata_pcs8g_rx         (out_avmmreaddata_pcs8g_rx     ),
      .avmmreaddata_pcs8g_tx         (out_avmmreaddata_pcs8g_tx     ),
      .avmmreaddata_pipe12           (out_avmmreaddata_pipe12       ),
      .avmmreaddata_rx_pcs_pma_if    (out_avmmreaddata_rx_pcs_pma_if),
      .avmmreaddata_rx_pld_pcs_if    (out_avmmreaddata_rx_pld_pcs_if),
      .avmmreaddata_tx_pcs_pma_if    (out_avmmreaddata_tx_pcs_pma_if),
      .avmmreaddata_tx_pld_pcs_if    (out_avmmreaddata_tx_pld_pcs_if),
      .blockselect_com_pcs_pma_if    (out_blockselect_com_pcs_pma_if),
      .blockselect_com_pld_pcs_if    (out_blockselect_com_pld_pcs_if),
      .blockselect_pcs8g_rx          (out_blockselect_pcs8g_rx      ),
      .blockselect_pcs8g_tx          (out_blockselect_pcs8g_tx      ),
      .blockselect_pipe12            (out_blockselect_pipe12        ),
      .blockselect_rx_pcs_pma_if     (out_blockselect_rx_pcs_pma_if ),
      .blockselect_rx_pld_pcs_if     (out_blockselect_rx_pld_pcs_if ),
      .blockselect_tx_pcs_pma_if     (out_blockselect_tx_pcs_pma_if ),
      .blockselect_tx_pld_pcs_if     (out_blockselect_tx_pld_pcs_if )
);
endmodule
