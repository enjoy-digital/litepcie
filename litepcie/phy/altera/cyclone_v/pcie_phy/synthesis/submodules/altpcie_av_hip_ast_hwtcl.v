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


// synthesis translate_off
`timescale 1ns / 1ps
// synthesis translate_on

module altpcie_av_hip_ast_hwtcl # (
      parameter MIN_AST_BUS_WIDTH                                 = 64,
      parameter MAX_NUM_FUNC_SUPPORT                              = 8,
      parameter num_of_func_hwtcl                                 = 8,
      parameter pll_refclk_freq_hwtcl                             = "100 MHz",
      parameter set_pld_clk_x1_625MHz_hwtcl                       = 0,
      parameter enable_slot_register_hwtcl                        = 0,
      parameter device_family                                     = "Arria V",
      //parameter bypass_cdc_hwtcl                                  = "false",
      parameter slotclkcfg_hwtcl                                  = 1,
      parameter enable_rx_buffer_checking_hwtcl                   = "false",
      parameter single_rx_detect_hwtcl                            = 0,
      parameter use_crc_forwarding_hwtcl                          = 0,
      parameter gen12_lane_rate_mode_hwtcl                        = "Gen1 (2.5 Gbps)",
      parameter lane_mask_hwtcl                                   = "x4",
      //parameter multi_function_hwtcl                              = "Func 0 (Default)",
      parameter disable_link_x2_support_hwtcl                     = "false",
      //parameter wrong_device_id_hwtcl                             = "disable",
      //parameter data_pack_rx_hwtcl                                = "disable",
      parameter ast_width_hwtcl                                   = "rx_tx_64",
      //parameter use_ast_parity                                    = 0,
      //parameter ltssm_1ms_timeout_hwtcl                           = "disable",
      //parameter ltssm_freqlocked_check_hwtcl                      = "disable",
      //parameter deskew_comma_hwtcl                                = "skp_eieos_deskw",
      parameter port_link_number_hwtcl                            = 1,
      parameter device_number_hwtcl                               = 0,
      parameter bypass_clk_switch_hwtcl                           = "disable",
      parameter pipex1_debug_sel_hwtcl                            = "disable",
      parameter pclk_out_sel_hwtcl                                = "pclk",
      parameter use_tl_cfg_sync_hwtcl                             = 0,

      parameter ACDS_VERSION_HWTCL                                = "",
      parameter porttype_func0_hwtcl                              = "Native endpoint",
      parameter porttype_func1_hwtcl                              = "Native endpoint",
      parameter porttype_func2_hwtcl                              = "Native endpoint",
      parameter porttype_func3_hwtcl                              = "Native endpoint",
      parameter porttype_func4_hwtcl                              = "Native endpoint",
      parameter porttype_func5_hwtcl                              = "Native endpoint",
      parameter porttype_func6_hwtcl                              = "Native endpoint",
      parameter porttype_func7_hwtcl                              = "Native endpoint",

   //Function 0

      parameter vendor_id_0_hwtcl                                   = 4466,
      parameter device_id_0_hwtcl                                   = 57345,
      parameter revision_id_0_hwtcl                                 = 1,
      parameter class_code_0_hwtcl                                  = 16711680,
      parameter subsystem_vendor_id_0_hwtcl                         = 4466,
      parameter subsystem_device_id_0_hwtcl                         = 57345,

      parameter bar0_io_space_0_hwtcl                               = "Disabled",
      parameter bar0_64bit_mem_space_0_hwtcl                        = "Enabled",
      parameter bar0_prefetchable_0_hwtcl                           = "Enabled",
      parameter bar0_size_mask_0_hwtcl                              = 28,
      parameter bar1_io_space_0_hwtcl                               = "Disabled",
      parameter bar1_64bit_mem_space_0_hwtcl                        = "Disabled",
      parameter bar1_prefetchable_0_hwtcl                           = "Disabled",
      parameter bar1_size_mask_0_hwtcl                              = 0,
      parameter bar2_io_space_0_hwtcl                               = "Disabled",
      parameter bar2_64bit_mem_space_0_hwtcl                        = "Disabled",
      parameter bar2_prefetchable_0_hwtcl                           = "Disabled",
      parameter bar2_size_mask_0_hwtcl                              = 0,
      parameter bar3_io_space_0_hwtcl                               = "Disabled",
      parameter bar3_64bit_mem_space_0_hwtcl                        = "Disabled",
      parameter bar3_prefetchable_0_hwtcl                           = "Disabled",
      parameter bar3_size_mask_0_hwtcl                              = 0,
      parameter bar4_io_space_0_hwtcl                               = "Disabled",
      parameter bar4_64bit_mem_space_0_hwtcl                        = "Disabled",
      parameter bar4_prefetchable_0_hwtcl                           = "Disabled",
      parameter bar4_size_mask_0_hwtcl                              = 0,
      parameter bar5_io_space_0_hwtcl                               = "Disabled",
      parameter bar5_64bit_mem_space_0_hwtcl                        = "Disabled",
      parameter bar5_prefetchable_0_hwtcl                           = "Disabled",
      parameter bar5_size_mask_0_hwtcl                              = 0,
      parameter expansion_base_address_register_0_hwtcl             = 0,

      parameter msi_multi_message_capable_0_hwtcl                   = "count_4",
      parameter msi_64bit_addressing_capable_0_hwtcl                = "true",
      parameter msi_masking_capable_0_hwtcl                         = "false",
      parameter msi_support_0_hwtcl                                 = "true",
      parameter interrupt_pin_0_hwtcl                               = "inta",
      parameter enable_function_msix_support_0_hwtcl                = 0,
      parameter msix_table_size_0_hwtcl                             = 0,
      parameter msix_table_bir_0_hwtcl                              = 0,
      parameter msix_table_offset_0_hwtcl                           = "0",
      parameter msix_pba_bir_0_hwtcl                                = 0,
      parameter msix_pba_offset_0_hwtcl                             = "0",

      parameter use_aer_0_hwtcl                                     = 0,
      parameter ecrc_check_capable_0_hwtcl                          = 0,
      parameter ecrc_gen_capable_0_hwtcl                            = 0,

      parameter slot_power_scale_0_hwtcl                            = 0,
      parameter slot_power_limit_0_hwtcl                            = 0,
      parameter slot_number_0_hwtcl                                 = 0,

      parameter max_payload_size_0_hwtcl                            = 256,
      parameter extend_tag_field_0_hwtcl                            = "false",
      parameter completion_timeout_0_hwtcl                          = "abcd",
      parameter enable_completion_timeout_disable_0_hwtcl           = 1,

      parameter surprise_down_error_support_0_hwtcl                 = 0,
      parameter dll_active_report_support_0_hwtcl                   = 0,

      parameter rx_ei_l0s_0_hwtcl                                   = 0,
      parameter endpoint_l0_latency_0_hwtcl                         = 0,
      parameter endpoint_l1_latency_0_hwtcl                         = 0,
      parameter maximum_current_0_hwtcl                             = 0,
      parameter device_specific_init_0_hwtcl                        = "disable",

      parameter ssvid_0_hwtcl                                       = 0,
      parameter ssid_0_hwtcl                                        = 0,

      parameter bridge_port_vga_enable_0_hwtcl                      = "false",
      parameter bridge_port_ssid_support_0_hwtcl                    = "false",

      parameter flr_capability_0_hwtcl                              = 1,
      parameter disable_snoop_packet_0_hwtcl                        = "false",

   //----------------------------------------

   //Function 1

      parameter vendor_id_1_hwtcl                                   = 4466,
      parameter device_id_1_hwtcl                                   = 57345,
      parameter revision_id_1_hwtcl                                 = 1,
      parameter class_code_1_hwtcl                                  = 16711680,
      parameter subsystem_vendor_id_1_hwtcl                         = 4466,
      parameter subsystem_device_id_1_hwtcl                         = 57345,

      parameter bar0_io_space_1_hwtcl                               = "Disabled",
      parameter bar0_64bit_mem_space_1_hwtcl                        = "Enabled",
      parameter bar0_prefetchable_1_hwtcl                           = "Enabled",
      parameter bar0_size_mask_1_hwtcl                              = 28,
      parameter bar1_io_space_1_hwtcl                               = "Disabled",
      parameter bar1_64bit_mem_space_1_hwtcl                        = "Disabled",
      parameter bar1_prefetchable_1_hwtcl                           = "Disabled",
      parameter bar1_size_mask_1_hwtcl                              = 0,
      parameter bar2_io_space_1_hwtcl                               = "Disabled",
      parameter bar2_64bit_mem_space_1_hwtcl                        = "Disabled",
      parameter bar2_prefetchable_1_hwtcl                           = "Disabled",
      parameter bar2_size_mask_1_hwtcl                              = 0,
      parameter bar3_io_space_1_hwtcl                               = "Disabled",
      parameter bar3_64bit_mem_space_1_hwtcl                        = "Disabled",
      parameter bar3_prefetchable_1_hwtcl                           = "Disabled",
      parameter bar3_size_mask_1_hwtcl                              = 0,
      parameter bar4_io_space_1_hwtcl                               = "Disabled",
      parameter bar4_64bit_mem_space_1_hwtcl                        = "Disabled",
      parameter bar4_prefetchable_1_hwtcl                           = "Disabled",
      parameter bar4_size_mask_1_hwtcl                              = 0,
      parameter bar5_io_space_1_hwtcl                               = "Disabled",
      parameter bar5_64bit_mem_space_1_hwtcl                        = "Disabled",
      parameter bar5_prefetchable_1_hwtcl                           = "Disabled",
      parameter bar5_size_mask_1_hwtcl                              = 0,
      parameter expansion_base_address_register_1_hwtcl             = 0,

      parameter msi_multi_message_capable_1_hwtcl                   = "count_4",
      parameter msi_64bit_addressing_capable_1_hwtcl                = "true",
      parameter msi_masking_capable_1_hwtcl                         = "false",
      parameter msi_support_1_hwtcl                                 = "true",
      parameter interrupt_pin_1_hwtcl                               = "inta",
      parameter enable_function_msix_support_1_hwtcl                = 0,
      parameter msix_table_size_1_hwtcl                             = 0,
      parameter msix_table_bir_1_hwtcl                              = 0,
      parameter msix_table_offset_1_hwtcl                           = "0",
      parameter msix_pba_bir_1_hwtcl                                = 0,
      parameter msix_pba_offset_1_hwtcl                             = "0",

      parameter use_aer_1_hwtcl                                     = 0,
      parameter ecrc_check_capable_1_hwtcl                          = 0,
      parameter ecrc_gen_capable_1_hwtcl                            = 0,

      parameter slot_power_scale_1_hwtcl                            = 0,
      parameter slot_power_limit_1_hwtcl                            = 0,
      parameter slot_number_1_hwtcl                                 = 0,

      parameter max_payload_size_1_hwtcl                            = 256,
      parameter extend_tag_field_1_hwtcl                            = "false",
      parameter completion_timeout_1_hwtcl                          = "abcd",
      parameter enable_completion_timeout_disable_1_hwtcl           = 1,

      parameter surprise_down_error_support_1_hwtcl                 = 0,
      parameter dll_active_report_support_1_hwtcl                   = 0,

      parameter rx_ei_l0s_1_hwtcl                                   = 0,
      parameter endpoint_l0_latency_1_hwtcl                         = 0,
      parameter endpoint_l1_latency_1_hwtcl                         = 0,
      parameter maximum_current_1_hwtcl                             = 0,
      parameter device_specific_init_1_hwtcl                        = "disable",

      parameter ssvid_1_hwtcl                                       = 0,
      parameter ssid_1_hwtcl                                        = 0,

      parameter bridge_port_vga_enable_1_hwtcl                      = "false",
      parameter bridge_port_ssid_support_1_hwtcl                    = "false",

      parameter flr_capability_1_hwtcl                              = 1,
      parameter disable_snoop_packet_1_hwtcl                        = "false",

   //----------------------------------------

   //Function 2

      parameter vendor_id_2_hwtcl                                   = 4466,
      parameter device_id_2_hwtcl                                   = 57345,
      parameter revision_id_2_hwtcl                                 = 1,
      parameter class_code_2_hwtcl                                  = 16711680,
      parameter subsystem_vendor_id_2_hwtcl                         = 4466,
      parameter subsystem_device_id_2_hwtcl                         = 57345,

      parameter bar0_io_space_2_hwtcl                               = "Disabled",
      parameter bar0_64bit_mem_space_2_hwtcl                        = "Enabled",
      parameter bar0_prefetchable_2_hwtcl                           = "Enabled",
      parameter bar0_size_mask_2_hwtcl                              = 28,
      parameter bar1_io_space_2_hwtcl                               = "Disabled",
      parameter bar1_64bit_mem_space_2_hwtcl                        = "Disabled",
      parameter bar1_prefetchable_2_hwtcl                           = "Disabled",
      parameter bar1_size_mask_2_hwtcl                              = 0,
      parameter bar2_io_space_2_hwtcl                               = "Disabled",
      parameter bar2_64bit_mem_space_2_hwtcl                        = "Disabled",
      parameter bar2_prefetchable_2_hwtcl                           = "Disabled",
      parameter bar2_size_mask_2_hwtcl                              = 0,
      parameter bar3_io_space_2_hwtcl                               = "Disabled",
      parameter bar3_64bit_mem_space_2_hwtcl                        = "Disabled",
      parameter bar3_prefetchable_2_hwtcl                           = "Disabled",
      parameter bar3_size_mask_2_hwtcl                              = 0,
      parameter bar4_io_space_2_hwtcl                               = "Disabled",
      parameter bar4_64bit_mem_space_2_hwtcl                        = "Disabled",
      parameter bar4_prefetchable_2_hwtcl                           = "Disabled",
      parameter bar4_size_mask_2_hwtcl                              = 0,
      parameter bar5_io_space_2_hwtcl                               = "Disabled",
      parameter bar5_64bit_mem_space_2_hwtcl                        = "Disabled",
      parameter bar5_prefetchable_2_hwtcl                           = "Disabled",
      parameter bar5_size_mask_2_hwtcl                              = 0,
      parameter expansion_base_address_register_2_hwtcl             = 0,

      parameter msi_multi_message_capable_2_hwtcl                   = "count_4",
      parameter msi_64bit_addressing_capable_2_hwtcl                = "true",
      parameter msi_masking_capable_2_hwtcl                         = "false",
      parameter msi_support_2_hwtcl                                 = "true",
      parameter interrupt_pin_2_hwtcl                               = "inta",
      parameter enable_function_msix_support_2_hwtcl                = 0,
      parameter msix_table_size_2_hwtcl                             = 0,
      parameter msix_table_bir_2_hwtcl                              = 0,
      parameter msix_table_offset_2_hwtcl                           = "0",
      parameter msix_pba_bir_2_hwtcl                                = 0,
      parameter msix_pba_offset_2_hwtcl                             = "0",

      parameter use_aer_2_hwtcl                                     = 0,
      parameter ecrc_check_capable_2_hwtcl                          = 0,
      parameter ecrc_gen_capable_2_hwtcl                            = 0,

      parameter slot_power_scale_2_hwtcl                            = 0,
      parameter slot_power_limit_2_hwtcl                            = 0,
      parameter slot_number_2_hwtcl                                 = 0,

      parameter max_payload_size_2_hwtcl                            = 256,
      parameter extend_tag_field_2_hwtcl                            = "false",
      parameter completion_timeout_2_hwtcl                          = "abcd",
      parameter enable_completion_timeout_disable_2_hwtcl           = 1,

      parameter surprise_down_error_support_2_hwtcl                 = 0,
      parameter dll_active_report_support_2_hwtcl                   = 0,

      parameter rx_ei_l0s_2_hwtcl                                   = 0,
      parameter endpoint_l0_latency_2_hwtcl                         = 0,
      parameter endpoint_l1_latency_2_hwtcl                         = 0,
      parameter maximum_current_2_hwtcl                             = 0,
      parameter device_specific_init_2_hwtcl                        = "disable",

      parameter ssvid_2_hwtcl                                       = 0,
      parameter ssid_2_hwtcl                                        = 0,

      parameter bridge_port_vga_enable_2_hwtcl                      = "false",
      parameter bridge_port_ssid_support_2_hwtcl                    = "false",

      parameter flr_capability_2_hwtcl                              = 1,
      parameter disable_snoop_packet_2_hwtcl                        = "false",

   //----------------------------------------

   //Function 3

      parameter vendor_id_3_hwtcl                                   = 4466,
      parameter device_id_3_hwtcl                                   = 57345,
      parameter revision_id_3_hwtcl                                 = 1,
      parameter class_code_3_hwtcl                                  = 16711680,
      parameter subsystem_vendor_id_3_hwtcl                         = 4466,
      parameter subsystem_device_id_3_hwtcl                         = 57345,

      parameter bar0_io_space_3_hwtcl                               = "Disabled",
      parameter bar0_64bit_mem_space_3_hwtcl                        = "Enabled",
      parameter bar0_prefetchable_3_hwtcl                           = "Enabled",
      parameter bar0_size_mask_3_hwtcl                              = 28,
      parameter bar1_io_space_3_hwtcl                               = "Disabled",
      parameter bar1_64bit_mem_space_3_hwtcl                        = "Disabled",
      parameter bar1_prefetchable_3_hwtcl                           = "Disabled",
      parameter bar1_size_mask_3_hwtcl                              = 0,
      parameter bar2_io_space_3_hwtcl                               = "Disabled",
      parameter bar2_64bit_mem_space_3_hwtcl                        = "Disabled",
      parameter bar2_prefetchable_3_hwtcl                           = "Disabled",
      parameter bar2_size_mask_3_hwtcl                              = 0,
      parameter bar3_io_space_3_hwtcl                               = "Disabled",
      parameter bar3_64bit_mem_space_3_hwtcl                        = "Disabled",
      parameter bar3_prefetchable_3_hwtcl                           = "Disabled",
      parameter bar3_size_mask_3_hwtcl                              = 0,
      parameter bar4_io_space_3_hwtcl                               = "Disabled",
      parameter bar4_64bit_mem_space_3_hwtcl                        = "Disabled",
      parameter bar4_prefetchable_3_hwtcl                           = "Disabled",
      parameter bar4_size_mask_3_hwtcl                              = 0,
      parameter bar5_io_space_3_hwtcl                               = "Disabled",
      parameter bar5_64bit_mem_space_3_hwtcl                        = "Disabled",
      parameter bar5_prefetchable_3_hwtcl                           = "Disabled",
      parameter bar5_size_mask_3_hwtcl                              = 0,
      parameter expansion_base_address_register_3_hwtcl             = 0,

      parameter msi_multi_message_capable_3_hwtcl                   = "count_4",
      parameter msi_64bit_addressing_capable_3_hwtcl                = "true",
      parameter msi_masking_capable_3_hwtcl                         = "false",
      parameter msi_support_3_hwtcl                                 = "true",
      parameter interrupt_pin_3_hwtcl                               = "inta",
      parameter enable_function_msix_support_3_hwtcl                = 0,
      parameter msix_table_size_3_hwtcl                             = 0,
      parameter msix_table_bir_3_hwtcl                              = 0,
      parameter msix_table_offset_3_hwtcl                           = "0",
      parameter msix_pba_bir_3_hwtcl                                = 0,
      parameter msix_pba_offset_3_hwtcl                             = "0",

      parameter use_aer_3_hwtcl                                     = 0,
      parameter ecrc_check_capable_3_hwtcl                          = 0,
      parameter ecrc_gen_capable_3_hwtcl                            = 0,

      parameter slot_power_scale_3_hwtcl                            = 0,
      parameter slot_power_limit_3_hwtcl                            = 0,
      parameter slot_number_3_hwtcl                                 = 0,

      parameter max_payload_size_3_hwtcl                            = 256,
      parameter extend_tag_field_3_hwtcl                            = "false",
      parameter completion_timeout_3_hwtcl                          = "abcd",
      parameter enable_completion_timeout_disable_3_hwtcl           = 1,

      parameter surprise_down_error_support_3_hwtcl                 = 0,
      parameter dll_active_report_support_3_hwtcl                   = 0,

      parameter rx_ei_l0s_3_hwtcl                                   = 0,
      parameter endpoint_l0_latency_3_hwtcl                         = 0,
      parameter endpoint_l1_latency_3_hwtcl                         = 0,
      parameter maximum_current_3_hwtcl                             = 0,
      parameter device_specific_init_3_hwtcl                        = "disable",

      parameter ssvid_3_hwtcl                                       = 0,
      parameter ssid_3_hwtcl                                        = 0,

      parameter bridge_port_vga_enable_3_hwtcl                      = "false",
      parameter bridge_port_ssid_support_3_hwtcl                    = "false",

      parameter flr_capability_3_hwtcl                              = 1,
      parameter disable_snoop_packet_3_hwtcl                        = "false",

   //----------------------------------------

   //Function 4

      parameter vendor_id_4_hwtcl                                   = 4466,
      parameter device_id_4_hwtcl                                   = 57345,
      parameter revision_id_4_hwtcl                                 = 1,
      parameter class_code_4_hwtcl                                  = 16711680,
      parameter subsystem_vendor_id_4_hwtcl                         = 4466,
      parameter subsystem_device_id_4_hwtcl                         = 57345,

      parameter bar0_io_space_4_hwtcl                               = "Disabled",
      parameter bar0_64bit_mem_space_4_hwtcl                        = "Enabled",
      parameter bar0_prefetchable_4_hwtcl                           = "Enabled",
      parameter bar0_size_mask_4_hwtcl                              = 28,
      parameter bar1_io_space_4_hwtcl                               = "Disabled",
      parameter bar1_64bit_mem_space_4_hwtcl                        = "Disabled",
      parameter bar1_prefetchable_4_hwtcl                           = "Disabled",
      parameter bar1_size_mask_4_hwtcl                              = 0,
      parameter bar2_io_space_4_hwtcl                               = "Disabled",
      parameter bar2_64bit_mem_space_4_hwtcl                        = "Disabled",
      parameter bar2_prefetchable_4_hwtcl                           = "Disabled",
      parameter bar2_size_mask_4_hwtcl                              = 0,
      parameter bar3_io_space_4_hwtcl                               = "Disabled",
      parameter bar3_64bit_mem_space_4_hwtcl                        = "Disabled",
      parameter bar3_prefetchable_4_hwtcl                           = "Disabled",
      parameter bar3_size_mask_4_hwtcl                              = 0,
      parameter bar4_io_space_4_hwtcl                               = "Disabled",
      parameter bar4_64bit_mem_space_4_hwtcl                        = "Disabled",
      parameter bar4_prefetchable_4_hwtcl                           = "Disabled",
      parameter bar4_size_mask_4_hwtcl                              = 0,
      parameter bar5_io_space_4_hwtcl                               = "Disabled",
      parameter bar5_64bit_mem_space_4_hwtcl                        = "Disabled",
      parameter bar5_prefetchable_4_hwtcl                           = "Disabled",
      parameter bar5_size_mask_4_hwtcl                              = 0,
      parameter expansion_base_address_register_4_hwtcl             = 0,

      parameter msi_multi_message_capable_4_hwtcl                   = "count_4",
      parameter msi_64bit_addressing_capable_4_hwtcl                = "true",
      parameter msi_masking_capable_4_hwtcl                         = "false",
      parameter msi_support_4_hwtcl                                 = "true",
      parameter interrupt_pin_4_hwtcl                               = "inta",
      parameter enable_function_msix_support_4_hwtcl                = 0,
      parameter msix_table_size_4_hwtcl                             = 0,
      parameter msix_table_bir_4_hwtcl                              = 0,
      parameter msix_table_offset_4_hwtcl                           = "0",
      parameter msix_pba_bir_4_hwtcl                                = 0,
      parameter msix_pba_offset_4_hwtcl                             = "0",

      parameter use_aer_4_hwtcl                                     = 0,
      parameter ecrc_check_capable_4_hwtcl                          = 0,
      parameter ecrc_gen_capable_4_hwtcl                            = 0,

      parameter slot_power_scale_4_hwtcl                            = 0,
      parameter slot_power_limit_4_hwtcl                            = 0,
      parameter slot_number_4_hwtcl                                 = 0,

      parameter max_payload_size_4_hwtcl                            = 256,
      parameter extend_tag_field_4_hwtcl                            = "false",
      parameter completion_timeout_4_hwtcl                          = "abcd",
      parameter enable_completion_timeout_disable_4_hwtcl           = 1,

      parameter surprise_down_error_support_4_hwtcl                 = 0,
      parameter dll_active_report_support_4_hwtcl                   = 0,

      parameter rx_ei_l0s_4_hwtcl                                   = 0,
      parameter endpoint_l0_latency_4_hwtcl                         = 0,
      parameter endpoint_l1_latency_4_hwtcl                         = 0,
      parameter maximum_current_4_hwtcl                             = 0,
      parameter device_specific_init_4_hwtcl                        = "disable",

      parameter ssvid_4_hwtcl                                       = 0,
      parameter ssid_4_hwtcl                                        = 0,

      parameter bridge_port_vga_enable_4_hwtcl                      = "false",
      parameter bridge_port_ssid_support_4_hwtcl                    = "false",

      parameter flr_capability_4_hwtcl                              = 1,
      parameter disable_snoop_packet_4_hwtcl                        = "false",

   //----------------------------------------

   //Function 5

      parameter vendor_id_5_hwtcl                                   = 4466,
      parameter device_id_5_hwtcl                                   = 57345,
      parameter revision_id_5_hwtcl                                 = 1,
      parameter class_code_5_hwtcl                                  = 16711680,
      parameter subsystem_vendor_id_5_hwtcl                         = 4466,
      parameter subsystem_device_id_5_hwtcl                         = 57345,

      parameter bar0_io_space_5_hwtcl                               = "Disabled",
      parameter bar0_64bit_mem_space_5_hwtcl                        = "Enabled",
      parameter bar0_prefetchable_5_hwtcl                           = "Enabled",
      parameter bar0_size_mask_5_hwtcl                              = 28,
      parameter bar1_io_space_5_hwtcl                               = "Disabled",
      parameter bar1_64bit_mem_space_5_hwtcl                        = "Disabled",
      parameter bar1_prefetchable_5_hwtcl                           = "Disabled",
      parameter bar1_size_mask_5_hwtcl                              = 0,
      parameter bar2_io_space_5_hwtcl                               = "Disabled",
      parameter bar2_64bit_mem_space_5_hwtcl                        = "Disabled",
      parameter bar2_prefetchable_5_hwtcl                           = "Disabled",
      parameter bar2_size_mask_5_hwtcl                              = 0,
      parameter bar3_io_space_5_hwtcl                               = "Disabled",
      parameter bar3_64bit_mem_space_5_hwtcl                        = "Disabled",
      parameter bar3_prefetchable_5_hwtcl                           = "Disabled",
      parameter bar3_size_mask_5_hwtcl                              = 0,
      parameter bar4_io_space_5_hwtcl                               = "Disabled",
      parameter bar4_64bit_mem_space_5_hwtcl                        = "Disabled",
      parameter bar4_prefetchable_5_hwtcl                           = "Disabled",
      parameter bar4_size_mask_5_hwtcl                              = 0,
      parameter bar5_io_space_5_hwtcl                               = "Disabled",
      parameter bar5_64bit_mem_space_5_hwtcl                        = "Disabled",
      parameter bar5_prefetchable_5_hwtcl                           = "Disabled",
      parameter bar5_size_mask_5_hwtcl                              = 0,
      parameter expansion_base_address_register_5_hwtcl             = 0,

      parameter msi_multi_message_capable_5_hwtcl                   = "count_4",
      parameter msi_64bit_addressing_capable_5_hwtcl                = "true",
      parameter msi_masking_capable_5_hwtcl                         = "false",
      parameter msi_support_5_hwtcl                                 = "true",
      parameter interrupt_pin_5_hwtcl                               = "inta",
      parameter enable_function_msix_support_5_hwtcl                = 0,
      parameter msix_table_size_5_hwtcl                             = 0,
      parameter msix_table_bir_5_hwtcl                              = 0,
      parameter msix_table_offset_5_hwtcl                           = "0",
      parameter msix_pba_bir_5_hwtcl                                = 0,
      parameter msix_pba_offset_5_hwtcl                             = "0",

      parameter use_aer_5_hwtcl                                     = 0,
      parameter ecrc_check_capable_5_hwtcl                          = 0,
      parameter ecrc_gen_capable_5_hwtcl                            = 0,

      parameter slot_power_scale_5_hwtcl                            = 0,
      parameter slot_power_limit_5_hwtcl                            = 0,
      parameter slot_number_5_hwtcl                                 = 0,

      parameter max_payload_size_5_hwtcl                            = 256,
      parameter extend_tag_field_5_hwtcl                            = "false",
      parameter completion_timeout_5_hwtcl                          = "abcd",
      parameter enable_completion_timeout_disable_5_hwtcl           = 1,

      parameter surprise_down_error_support_5_hwtcl                 = 0,
      parameter dll_active_report_support_5_hwtcl                   = 0,

      parameter rx_ei_l0s_5_hwtcl                                   = 0,
      parameter endpoint_l0_latency_5_hwtcl                         = 0,
      parameter endpoint_l1_latency_5_hwtcl                         = 0,
      parameter maximum_current_5_hwtcl                             = 0,
      parameter device_specific_init_5_hwtcl                        = "disable",

      parameter ssvid_5_hwtcl                                       = 0,
      parameter ssid_5_hwtcl                                        = 0,

      parameter bridge_port_vga_enable_5_hwtcl                      = "false",
      parameter bridge_port_ssid_support_5_hwtcl                    = "false",

      parameter flr_capability_5_hwtcl                              = 1,
      parameter disable_snoop_packet_5_hwtcl                        = "false",

   //----------------------------------------

   //Function 6

      parameter vendor_id_6_hwtcl                                   = 4466,
      parameter device_id_6_hwtcl                                   = 57345,
      parameter revision_id_6_hwtcl                                 = 1,
      parameter class_code_6_hwtcl                                  = 16711680,
      parameter subsystem_vendor_id_6_hwtcl                         = 4466,
      parameter subsystem_device_id_6_hwtcl                         = 57345,

      parameter bar0_io_space_6_hwtcl                               = "Disabled",
      parameter bar0_64bit_mem_space_6_hwtcl                        = "Enabled",
      parameter bar0_prefetchable_6_hwtcl                           = "Enabled",
      parameter bar0_size_mask_6_hwtcl                              = 28,
      parameter bar1_io_space_6_hwtcl                               = "Disabled",
      parameter bar1_64bit_mem_space_6_hwtcl                        = "Disabled",
      parameter bar1_prefetchable_6_hwtcl                           = "Disabled",
      parameter bar1_size_mask_6_hwtcl                              = 0,
      parameter bar2_io_space_6_hwtcl                               = "Disabled",
      parameter bar2_64bit_mem_space_6_hwtcl                        = "Disabled",
      parameter bar2_prefetchable_6_hwtcl                           = "Disabled",
      parameter bar2_size_mask_6_hwtcl                              = 0,
      parameter bar3_io_space_6_hwtcl                               = "Disabled",
      parameter bar3_64bit_mem_space_6_hwtcl                        = "Disabled",
      parameter bar3_prefetchable_6_hwtcl                           = "Disabled",
      parameter bar3_size_mask_6_hwtcl                              = 0,
      parameter bar4_io_space_6_hwtcl                               = "Disabled",
      parameter bar4_64bit_mem_space_6_hwtcl                        = "Disabled",
      parameter bar4_prefetchable_6_hwtcl                           = "Disabled",
      parameter bar4_size_mask_6_hwtcl                              = 0,
      parameter bar5_io_space_6_hwtcl                               = "Disabled",
      parameter bar5_64bit_mem_space_6_hwtcl                        = "Disabled",
      parameter bar5_prefetchable_6_hwtcl                           = "Disabled",
      parameter bar5_size_mask_6_hwtcl                              = 0,
      parameter expansion_base_address_register_6_hwtcl             = 0,

      parameter msi_multi_message_capable_6_hwtcl                   = "count_4",
      parameter msi_64bit_addressing_capable_6_hwtcl                = "true",
      parameter msi_masking_capable_6_hwtcl                         = "false",
      parameter msi_support_6_hwtcl                                 = "true",
      parameter interrupt_pin_6_hwtcl                               = "inta",
      parameter enable_function_msix_support_6_hwtcl                = 0,
      parameter msix_table_size_6_hwtcl                             = 0,
      parameter msix_table_bir_6_hwtcl                              = 0,
      parameter msix_table_offset_6_hwtcl                           = "0",
      parameter msix_pba_bir_6_hwtcl                                = 0,
      parameter msix_pba_offset_6_hwtcl                             = "0",

      parameter use_aer_6_hwtcl                                     = 0,
      parameter ecrc_check_capable_6_hwtcl                          = 0,
      parameter ecrc_gen_capable_6_hwtcl                            = 0,

      parameter slot_power_scale_6_hwtcl                            = 0,
      parameter slot_power_limit_6_hwtcl                            = 0,
      parameter slot_number_6_hwtcl                                 = 0,

      parameter max_payload_size_6_hwtcl                            = 256,
      parameter extend_tag_field_6_hwtcl                            = "false",
      parameter completion_timeout_6_hwtcl                          = "abcd",
      parameter enable_completion_timeout_disable_6_hwtcl           = 1,

      parameter surprise_down_error_support_6_hwtcl                 = 0,
      parameter dll_active_report_support_6_hwtcl                   = 0,

      parameter rx_ei_l0s_6_hwtcl                                   = 0,
      parameter endpoint_l0_latency_6_hwtcl                         = 0,
      parameter endpoint_l1_latency_6_hwtcl                         = 0,
      parameter maximum_current_6_hwtcl                             = 0,
      parameter device_specific_init_6_hwtcl                        = "disable",

      parameter ssvid_6_hwtcl                                       = 0,
      parameter ssid_6_hwtcl                                        = 0,

      parameter bridge_port_vga_enable_6_hwtcl                      = "false",
      parameter bridge_port_ssid_support_6_hwtcl                    = "false",

      parameter flr_capability_6_hwtcl                              = 1,
      parameter disable_snoop_packet_6_hwtcl                        = "false",

   //----------------------------------------

   //Function 7

      parameter vendor_id_7_hwtcl                                   = 4466,
      parameter device_id_7_hwtcl                                   = 57345,
      parameter revision_id_7_hwtcl                                 = 1,
      parameter class_code_7_hwtcl                                  = 16711680,
      parameter subsystem_vendor_id_7_hwtcl                         = 4466,
      parameter subsystem_device_id_7_hwtcl                         = 57345,

      parameter bar0_io_space_7_hwtcl                               = "Disabled",
      parameter bar0_64bit_mem_space_7_hwtcl                        = "Enabled",
      parameter bar0_prefetchable_7_hwtcl                           = "Enabled",
      parameter bar0_size_mask_7_hwtcl                              = 28,
      parameter bar1_io_space_7_hwtcl                               = "Disabled",
      parameter bar1_64bit_mem_space_7_hwtcl                        = "Disabled",
      parameter bar1_prefetchable_7_hwtcl                           = "Disabled",
      parameter bar1_size_mask_7_hwtcl                              = 0,
      parameter bar2_io_space_7_hwtcl                               = "Disabled",
      parameter bar2_64bit_mem_space_7_hwtcl                        = "Disabled",
      parameter bar2_prefetchable_7_hwtcl                           = "Disabled",
      parameter bar2_size_mask_7_hwtcl                              = 0,
      parameter bar3_io_space_7_hwtcl                               = "Disabled",
      parameter bar3_64bit_mem_space_7_hwtcl                        = "Disabled",
      parameter bar3_prefetchable_7_hwtcl                           = "Disabled",
      parameter bar3_size_mask_7_hwtcl                              = 0,
      parameter bar4_io_space_7_hwtcl                               = "Disabled",
      parameter bar4_64bit_mem_space_7_hwtcl                        = "Disabled",
      parameter bar4_prefetchable_7_hwtcl                           = "Disabled",
      parameter bar4_size_mask_7_hwtcl                              = 0,
      parameter bar5_io_space_7_hwtcl                               = "Disabled",
      parameter bar5_64bit_mem_space_7_hwtcl                        = "Disabled",
      parameter bar5_prefetchable_7_hwtcl                           = "Disabled",
      parameter bar5_size_mask_7_hwtcl                              = 0,
      parameter expansion_base_address_register_7_hwtcl             = 0,

      parameter msi_multi_message_capable_7_hwtcl                   = "count_4",
      parameter msi_64bit_addressing_capable_7_hwtcl                = "true",
      parameter msi_masking_capable_7_hwtcl                         = "false",
      parameter msi_support_7_hwtcl                                 = "true",
      parameter interrupt_pin_7_hwtcl                               = "inta",
      parameter enable_function_msix_support_7_hwtcl                = 0,
      parameter msix_table_size_7_hwtcl                             = 0,
      parameter msix_table_bir_7_hwtcl                              = 0,
      parameter msix_table_offset_7_hwtcl                           = "0",
      parameter msix_pba_bir_7_hwtcl                                = 0,
      parameter msix_pba_offset_7_hwtcl                             = "0",

      parameter use_aer_7_hwtcl                                     = 0,
      parameter ecrc_check_capable_7_hwtcl                          = 0,
      parameter ecrc_gen_capable_7_hwtcl                            = 0,

      parameter slot_power_scale_7_hwtcl                            = 0,
      parameter slot_power_limit_7_hwtcl                            = 0,
      parameter slot_number_7_hwtcl                                 = 0,

      parameter max_payload_size_7_hwtcl                            = 256,
      parameter extend_tag_field_7_hwtcl                            = "false",
      parameter completion_timeout_7_hwtcl                          = "abcd",
      parameter enable_completion_timeout_disable_7_hwtcl           = 1,

      parameter surprise_down_error_support_7_hwtcl                 = 0,
      parameter dll_active_report_support_7_hwtcl                   = 0,

      parameter rx_ei_l0s_7_hwtcl                                   = 0,
      parameter endpoint_l0_latency_7_hwtcl                         = 0,
      parameter endpoint_l1_latency_7_hwtcl                         = 0,
      parameter maximum_current_7_hwtcl                             = 0,
      parameter device_specific_init_7_hwtcl                        = "disable",

      parameter ssvid_7_hwtcl                                       = 0,
      parameter ssid_7_hwtcl                                        = 0,

      parameter bridge_port_vga_enable_7_hwtcl                      = "false",
      parameter bridge_port_ssid_support_7_hwtcl                    = "false",

      parameter flr_capability_7_hwtcl                              = 1,
      parameter disable_snoop_packet_7_hwtcl                        = "false",

   //----------------------------------------

      parameter no_soft_reset_hwtcl                               = "false",
      parameter d1_support_hwtcl                                  = "false",
      parameter d2_support_hwtcl                                  = "false",
      parameter d0_pme_hwtcl                                      = "false",
      parameter d1_pme_hwtcl                                      = "false",
      parameter d2_pme_hwtcl                                      = "false",
      parameter d3_hot_pme_hwtcl                                  = "false",
      parameter d3_cold_pme_hwtcl                                 = "false",
      parameter low_priority_vc_hwtcl                             = "single_vc",
      parameter indicator_hwtcl                                   = 0,
      parameter enable_l0s_aspm_hwtcl                             = "true",
      parameter enable_l1_aspm_hwtcl                              = "false",
      parameter l1_exit_latency_sameclock_hwtcl                   = 0,
      parameter l1_exit_latency_diffclock_hwtcl                   = 0,
      parameter hot_plug_support_hwtcl                            = 0,
      parameter diffclock_nfts_count_hwtcl                        = 128,
      parameter sameclock_nfts_count_hwtcl                        = 128,
      //parameter extended_tag_reset_hwtcl                          = "false",
      parameter no_command_completed_hwtcl                        = "true",
      parameter eie_before_nfts_count_hwtcl                       = 4,
      parameter gen2_diffclock_nfts_count_hwtcl                   = 255,
      parameter gen2_sameclock_nfts_count_hwtcl                   = 255,
      parameter deemphasis_enable_hwtcl                           = "false",
      parameter pcie_spec_version_hwtcl                           = "v2",
      parameter l0_exit_latency_sameclock_hwtcl                   = 6,
      parameter l0_exit_latency_diffclock_hwtcl                   = 6,
      parameter l2_async_logic_hwtcl                              = "disable",
      parameter aspm_optionality_hwtcl                            = "true",
      //parameter atomic_op_routing_hwtcl                           = "false",
      //parameter atomic_op_completer_32bit_hwtcl                   = "false",
      //parameter atomic_op_completer_64bit_hwtcl                   = "false",
      //parameter cas_completer_128bit_hwtcl                        = "false",
      //parameter ltr_mechanism_hwtcl                               = "false",
      //parameter tph_completer_hwtcl                               = "false",
      //parameter extended_format_field_hwtcl                       = "true",
      //parameter atomic_malformed_hwtcl                            = "true",
      parameter enable_adapter_half_rate_mode_hwtcl               = "true",
      parameter vc0_clk_enable_hwtcl                              = "true",
      parameter register_pipe_signals_hwtcl                       = "true",
      parameter io_window_addr_width_hwtcl                        = 0,
      parameter prefetchable_mem_window_addr_width_hwtcl          = 0,
      //parameter skp_os_gen3_count_hwtcl                           = 0,
      parameter tx_cdc_almost_empty_hwtcl                         = 5,
      parameter rx_cdc_almost_full_hwtcl                          = 12,
      parameter tx_cdc_almost_full_hwtcl                          = 12,
      parameter rx_l0s_count_idl_hwtcl                            = 0,
      parameter cdc_dummy_insert_limit_hwtcl                      = 11,
      parameter ei_delay_powerdown_count_hwtcl                    = 10,
      parameter millisecond_cycle_count_hwtcl                     = 248500,
      parameter skp_os_schedule_count_hwtcl                       = 0,
      parameter fc_init_timer_hwtcl                               = 1024,
      parameter l01_entry_latency_hwtcl                           = 31,
      parameter flow_control_update_count_hwtcl                   = 30,
      parameter flow_control_timeout_count_hwtcl                  = 200,
      parameter credit_buffer_allocation_aux_hwtcl                = "balanced",
      parameter vc0_rx_flow_ctrl_posted_header_hwtcl              = 50,
      parameter vc0_rx_flow_ctrl_posted_data_hwtcl                = 360,
      parameter vc0_rx_flow_ctrl_nonposted_header_hwtcl           = 54,
      parameter vc0_rx_flow_ctrl_nonposted_data_hwtcl             = 0,
      parameter vc0_rx_flow_ctrl_compl_header_hwtcl               = 112,
      parameter vc0_rx_flow_ctrl_compl_data_hwtcl                 = 448,
      parameter cpl_spc_header_hwtcl                              = 112,
      parameter cpl_spc_data_hwtcl                                = 448,
      parameter retry_buffer_last_active_address_hwtcl            = 255,
      parameter reconfig_to_xcvr_width                            = 350,
      parameter reconfig_from_xcvr_width                          = 230,
      parameter hip_hard_reset_hwtcl                              = 1,
      parameter reserved_debug_hwtcl                              = 0,
      parameter hip_reconfig_hwtcl                                = 0,
      parameter port_width_data_hwtcl                             = 64,
      //parameter port_width_be_hwtcl                               = 16,
      parameter cvp_rate_sel_hwtcl                                =  "full_rate",
      parameter cvp_data_compressed_hwtcl                         =  "false",
      parameter cvp_data_encrypted_hwtcl                          =  "false",
      parameter cvp_mode_reset_hwtcl                              =  "false",
      parameter cvp_clk_reset_hwtcl                               =  "false",
      parameter in_cvp_mode_hwtcl                                 =  0,
      parameter core_clk_sel_hwtcl                                =  "core_clk_out",
      parameter rpre_emph_a_val_hwtcl                             = 0,
      parameter rpre_emph_b_val_hwtcl                             = 0,
      parameter rpre_emph_c_val_hwtcl                             = 0,
      parameter rpre_emph_d_val_hwtcl                             = 0,
      parameter rpre_emph_e_val_hwtcl                             = 0,
      parameter rvod_sel_a_val_hwtcl                              = 0,
      parameter rvod_sel_b_val_hwtcl                              = 0,
      parameter rvod_sel_c_val_hwtcl                              = 0,
      parameter rvod_sel_d_val_hwtcl                              = 0,
      parameter rvod_sel_e_val_hwtcl                              = 0,

     //VSEC User Parameters
      parameter user_id_hwtcl                                     = 0,
      parameter vsec_id_hwtcl                                     = 0,
      parameter vsec_rev_hwtcl                                    = 0
) (
      // Control signals
      input  [31 : 0]       test_in,
      input                 simu_mode_pipe,          // When 1'b1 indicate running DUT under pipe simulation

      // Reset signals
      input                 pin_perst,
      input                 npor,
      output reg            reset_status,
      output                serdes_pll_locked,
      output                pld_clk_inuse,
      input                 pld_core_ready,
      output                testin_zero,

      // Clock
      input                 pld_clk,

      // Serdes related
      input                 refclk,

      // Reconfig GXB
      input                [reconfig_to_xcvr_width-1:0]   reconfig_to_xcvr,
      input                busy_xcvr_reconfig,
      output               [reconfig_from_xcvr_width-1:0] reconfig_from_xcvr,
      output                fixedclk_locked,

      // HIP control signals
      input  [4 : 0]        tl_hpg_ctrl_er,

      // Input PIPE simulation _ext for simulation only
      output [1:0]          sim_pipe_rate,
      input                 sim_pipe_pclk_in,
      output                sim_pipe_pclk_out,
      output                sim_pipe_clk250_out,
      output                sim_pipe_clk500_out,
      output [4 : 0]        sim_ltssmstate,
      input                 phystatus0,
      input                 phystatus1,
      input                 phystatus2,
      input                 phystatus3,
      input                 phystatus4,
      input                 phystatus5,
      input                 phystatus6,
      input                 phystatus7,
      input  [7 : 0]        rxdata0,
      input  [7 : 0]        rxdata1,
      input  [7 : 0]        rxdata2,
      input  [7 : 0]        rxdata3,
      input  [7 : 0]        rxdata4,
      input  [7 : 0]        rxdata5,
      input  [7 : 0]        rxdata6,
      input  [7 : 0]        rxdata7,
      input                 rxdatak0,
      input                 rxdatak1,
      input                 rxdatak2,
      input                 rxdatak3,
      input                 rxdatak4,
      input                 rxdatak5,
      input                 rxdatak6,
      input                 rxdatak7,
      input                 rxelecidle0,
      input                 rxelecidle1,
      input                 rxelecidle2,
      input                 rxelecidle3,
      input                 rxelecidle4,
      input                 rxelecidle5,
      input                 rxelecidle6,
      input                 rxelecidle7,
      input  [2 : 0]        rxstatus0,
      input  [2 : 0]        rxstatus1,
      input  [2 : 0]        rxstatus2,
      input  [2 : 0]        rxstatus3,
      input  [2 : 0]        rxstatus4,
      input  [2 : 0]        rxstatus5,
      input  [2 : 0]        rxstatus6,
      input  [2 : 0]        rxstatus7,
      input                 rxvalid0,
      input                 rxvalid1,
      input                 rxvalid2,
      input                 rxvalid3,
      input                 rxvalid4,
      input                 rxvalid5,
      input                 rxvalid6,
      input                 rxvalid7,

      // Application signals inputs
      input  [9 : 0]        hip_reconfig_address,
      input  [1 : 0]        hip_reconfig_byte_en,
      input                 hip_reconfig_clk,
      input                 hip_reconfig_read,
      input                 hip_reconfig_rst_n,
      input                 hip_reconfig_write,
      input  [15: 0]        hip_reconfig_writedata,

      input  [(2**addr_width_delta(num_of_func_hwtcl))-1 : 0] app_int_sts_vec,

      input  [2 : 0]        app_msi_func,
      input  [4 : 0]        app_msi_num,
      input                 app_msi_req,
      input  [2 : 0]        app_msi_tc,
      input  [4 : 0]        aer_msi_num,
      input  [4 : 0]        pex_msi_num,

      input  [addr_width_delta(num_of_func_hwtcl)+11 : 0]  lmi_addr,
      input  [31 : 0]       lmi_din,
      input                 lmi_rden,
      input                 lmi_wren,

      input                 pm_auxpwr,
      input  [9 : 0]        pm_data,
      input                 pme_to_cr,
      input                 pm_event,
      input  [2 : 0]        pm_event_func,

      input                 rx_st_mask,
      input                 rx_st_ready,

      input [port_width_data_hwtcl-1 : 0]                      tx_st_data,
      input                                                    tx_st_eop,
      input                                                    tx_st_sop,
      input                                                    tx_st_empty,
      input                                                    tx_st_valid,
      input                                                    tx_st_err,

      input  [6 :0]         cpl_err,
      input  [2:0]          cpl_err_func,
      input  [num_of_func_hwtcl-1:0]          cpl_pending,

      input                   ser_shift_load,
      input                   interface_sel,

      input                   clrrxpath,

      // Output Pipe interface
      output [2 : 0]        eidleinfersel0,
      output [2 : 0]        eidleinfersel1,
      output [2 : 0]        eidleinfersel2,
      output [2 : 0]        eidleinfersel3,
      output [2 : 0]        eidleinfersel4,
      output [2 : 0]        eidleinfersel5,
      output [2 : 0]        eidleinfersel6,
      output [2 : 0]        eidleinfersel7,
      output [1 : 0]        powerdown0,
      output [1 : 0]        powerdown1,
      output [1 : 0]        powerdown2,
      output [1 : 0]        powerdown3,
      output [1 : 0]        powerdown4,
      output [1 : 0]        powerdown5,
      output [1 : 0]        powerdown6,
      output [1 : 0]        powerdown7,
      output                rxpolarity0,
      output                rxpolarity1,
      output                rxpolarity2,
      output                rxpolarity3,
      output                rxpolarity4,
      output                rxpolarity5,
      output                rxpolarity6,
      output                rxpolarity7,
      output                txcompl0,
      output                txcompl1,
      output                txcompl2,
      output                txcompl3,
      output                txcompl4,
      output                txcompl5,
      output                txcompl6,
      output                txcompl7,
      output [7 : 0]        txdata0,
      output [7 : 0]        txdata1,
      output [7 : 0]        txdata2,
      output [7 : 0]        txdata3,
      output [7 : 0]        txdata4,
      output [7 : 0]        txdata5,
      output [7 : 0]        txdata6,
      output [7 : 0]        txdata7,
      output                txdatak0,
      output                txdatak1,
      output                txdatak2,
      output                txdatak3,
      output                txdatak4,
      output                txdatak5,
      output                txdatak6,
      output                txdatak7,
      output                txdatavalid0,
      output                txdatavalid1,
      output                txdatavalid2,
      output                txdatavalid3,
      output                txdatavalid4,
      output                txdatavalid5,
      output                txdatavalid6,
      output                txdatavalid7,
      output                txdetectrx0,
      output                txdetectrx1,
      output                txdetectrx2,
      output                txdetectrx3,
      output                txdetectrx4,
      output                txdetectrx5,
      output                txdetectrx6,
      output                txdetectrx7,
      output                txelecidle0,
      output                txelecidle1,
      output                txelecidle2,
      output                txelecidle3,
      output                txelecidle4,
      output                txelecidle5,
      output                txelecidle6,
      output                txelecidle7,
      output [2 : 0]        txmargin0,
      output [2 : 0]        txmargin1,
      output [2 : 0]        txmargin2,
      output [2 : 0]        txmargin3,
      output [2 : 0]        txmargin4,
      output [2 : 0]        txmargin5,
      output [2 : 0]        txmargin6,
      output [2 : 0]        txmargin7,
      output                txdeemph0,
      output                txdeemph1,
      output                txdeemph2,
      output                txdeemph3,
      output                txdeemph4,
      output                txdeemph5,
      output                txdeemph6,
      output                txdeemph7,
      output                txswing0,
      output                txswing1,
      output                txswing2,
      output                txswing3,
      output                txswing4,
      output                txswing5,
      output                txswing6,
      output                txswing7,

      // Output HIP Status signals
      output                coreclkout,
      output                derr_cor_ext_rcv0,
      output                derr_cor_ext_rpl,
      output                derr_rpl,
      output [1:0]          dl_current_speed,
      output [4:0]          dl_ltssm,
      output                dlup_exit,
      output                ev128ns,
      output                ev1us,
      output                hotrst_exit,
      output [3 : 0]        int_status,
      output                l2_exit,
      output [3 : 0]        lane_act,
      output [7 :0]         ko_cpl_spc_header,
      output [11 :0]        ko_cpl_spc_data,

      // Output Application interface
      output [15: 0]        hip_reconfig_readdata,
      output                serr_out,
      output                app_msi_ack,

      output                lmi_ack,
      output [31 : 0]       lmi_dout,
      output                pme_to_sr,

      output [2 : 0]        rx_bar_dec_func_num,
      output [7 : 0]        rx_st_bar,
      output [(port_width_data_hwtcl/8)-1 : 0]                 rx_st_be,
      output [port_width_data_hwtcl-1 : 0]                     rx_st_data,
      output                                                   rx_st_sop,
      output                                                   rx_st_eop,
      output                                                   rx_st_empty,
      output                                                   rx_st_valid,

      output                rx_st_err,
      output                rx_fifo_empty,
      output                rx_fifo_full,

      output [addr_width_delta(num_of_func_hwtcl)+3 : 0]       tl_cfg_add,
      output [31 : 0]       tl_cfg_ctl,
      output                tl_cfg_ctl_wr,
      output [((num_of_func_hwtcl-1)*10)+52 : 0]               tl_cfg_sts,
      output                tl_cfg_sts_wr,
      output [11 : 0]       tx_cred_datafccp,
      output [11 : 0]       tx_cred_datafcnp,
      output [11 : 0]       tx_cred_datafcp,
      output [5 : 0]        tx_cred_fchipcons,
      output [5 : 0]        tx_cred_fcinfinite,
      output [7 : 0]        tx_cred_hdrfccp,
      output [7 : 0]        tx_cred_hdrfcnp,
      output [7 : 0]        tx_cred_hdrfcp,
      //output [35: 0]        tx_cred,
      output                tx_st_ready,
      output                tx_fifo_empty,
      output                tx_fifo_full,
      output  [3:0]         tx_fifo_rdp,
      output  [3:0]         tx_fifo_wrp,

      // serial interface
      input    rx_in0,
      input    rx_in1,
      input    rx_in2,
      input    rx_in3,
      input    rx_in4,
      input    rx_in5,
      input    rx_in6,
      input    rx_in7,

      output   tx_out0,
      output   tx_out1,
      output   tx_out2,
      output   tx_out3,
      output   tx_out4,
      output   tx_out5,
      output   tx_out6,
      output   tx_out7

      );

function integer clogb2 (input integer depth);
begin
   clogb2 = 0;
   for(clogb2=0; depth>1; clogb2=clogb2+1)
      depth = depth >> 1;
end
endfunction

function integer addr_width_delta (input integer num_of_func);
begin
   if (num_of_func > 1) begin
      addr_width_delta = clogb2(MAX_NUM_FUNC_SUPPORT);
   end
   else begin
      addr_width_delta = 0;
   end
end
endfunction

localparam integer MAX_CHARS = 32;
// Convert a string to an integer
// Uses pre-existing str2hz function
function integer str2int(
    input [MAX_CHARS*8-1:0] instring
  );
   time temp;

   begin
    temp = str2hz({instring,"Hz"});
    str2int = temp[31:0];
   end
endfunction

// convert frequency string into integer Hz.  Fractional Hz are truncated
// Must remain a constant function - can't use string.atoi().
function time str2hz (
                input [8*MAX_CHARS:1] s
        );

                integer i;
                integer c; // temp char storage for frequency conversion
                integer unit_tens; // assume already Hz
                integer is_numeric;
                integer saw_dot;

                reg [8:1] c_dot; // = ".";
                reg [8:1] c_space; // = " ";
                reg [8:1] c_a; // = 8'h61; //"a";
                reg [8:1] c_z; // = 8'h7a; //"z";
                reg [8*4:1] s_unit;
                reg [8*MAX_CHARS:1] s_shift;

                begin
                        // frequency ratio calculations
                        str2hz = 0;
                        unit_tens = 0; // assume already Hz
                        is_numeric = 1;
                        saw_dot = 0;
                        s_unit = "";

                        // Modelsim optimizer bug forces us to initialize these non-statically
                        c_dot = ".";
                        c_space = " ";
                        c_a = "a";
                        c_z = "z";
                        for (i=(MAX_CHARS-1); i>=0; i=i-1) begin
                                s_shift = (s >> (i*8));
                                c = s_shift[8:1] & 8'hff;
                                if (c > 0) begin
                                        //$display("[%d] => '%1s',", i, c);
                                        if (c >= 8'h30 && c <= 8'h39 && is_numeric) begin
                                                str2hz = (str2hz * 10) + (c & 8'h0f);
                                                if (saw_dot) unit_tens = unit_tens - 1;  // count digits after decimal point
                                        end else if (c == c_dot) saw_dot = 1;
                                        else if (c != c_space) begin
                                                is_numeric = 0; // stop accepting new numeric digits in value
                                                // if it's a-z, convert to upper case A-Z
                                                if (c >= c_a && c <= c_z) c = (c & 8'h5f);      // convert a-z (lower) to A-Z (upper)
                                                s_unit = (s_unit << 8) | c;
                                        end
                                end
                        end
                        //$display("numeric = %d x 10**(%2d), unit = '%0s'", str2hz, unit_tens, s_unit);

                        // account for frequency unit
                        if (s_unit == "GHZ" || s_unit == "GBPS") unit_tens = unit_tens + 9; // 10**9
                        else if (s_unit == "MHZ" || s_unit == "MBPS") unit_tens = unit_tens + 6; // 10**6
                        else if (s_unit == "KHZ" || s_unit == "KBPS") unit_tens = unit_tens + 3; // 10**3
                        else if (s_unit != "HZ" && s_unit != "BPS") begin
                                $display("Invalid frequency unit '%0s', assuming %d x 10**(%2d) 'Hz'", s_unit, str2hz, unit_tens);
                        end
                        //$display("numeric in Hz = %d x 10**(%2d)", str2hz, unit_tens);

                        // align numeric to Hz
                        if (unit_tens < 0) begin
                                //str2hz = str2hz / (10**(-unit_tens));
                                for (i=0; i>unit_tens; i=i-1) begin
                                        str2hz = str2hz / 10;
                                end
                        end else begin
                                //str2hz = str2hz * (10**unit_tens);
                                for (i=0; i<unit_tens; i=i+1) begin
                                        str2hz = str2hz * 10;
                                end
                        end
                        //$display("%d Hz", str2hz);
                end
endfunction

function [8*25:1] low_str;
// Convert parameter strings to lower case
   input [8*25:1] input_string;
   reg [8*25:1] return_string;
   reg [8*25:1] reg_string;
   reg [8:1] tmp;
   reg [8:1] conv_char;
   integer byte_count;
   begin
      reg_string = input_string;
      for (byte_count = 25; byte_count >= 1; byte_count = byte_count - 1) begin
         tmp = reg_string[8*25:(8*(25-1)+1)];
         reg_string = reg_string << 8;
         if ((tmp >= 65) && (tmp <= 90)) // ASCII number of 'A' is 65, 'Z' is 90
            begin
            conv_char = tmp + 32; // 32 is the difference in the position of 'A' and 'a' in the ASCII char set
            return_string = {return_string, conv_char};
            end
         else
            return_string = {return_string, tmp};
      end
   low_str = return_string;
   end
endfunction

function [39:0] calc_k_ptr_av;
   // purpose: Calculate the k_ptr values based on the supplied parameters
   // calc_k_ptr_av
   input[55:0] k_vc;
   reg[9:0]   post_min;
   reg[9:0]   post_max;
   reg[9:0]   nonp_min;
   reg[9:0]   nonp_max;
   integer     nonp_siz;
   begin
      post_min = 10'b00_0000_0000;
      nonp_max = 10'h2FF;
      // Reserve Space for the NonPosted Headers (and also NonPosted Data)
      nonp_siz = ((k_vc[27:20])) * 2;
      post_max = (use_crc_forwarding_hwtcl==1)?nonp_max - (nonp_siz[9 : 0])-({1'b0 , nonp_siz[9:1]}) :
                                                             nonp_max - nonp_siz[9:0];
      nonp_min = post_max + 1;
      calc_k_ptr_av = ({nonp_max[9:0], nonp_min[9:0], post_max[9:0], post_min[9:0]});
   end
endfunction

function [63:0] get_bar_size_mask;
   // Compute bar size mask based on BAR size
   input integer bara_64bit_mem_space ;// Integer 1 or 0
   input integer bara_size            ;// Integer number of bits
   input integer barb_size            ;// Integer number of bits
   reg [63:0] barab_size_mask64;
   reg [31:0] bara_size_mask32;
   reg [31:0] barb_size_mask32;
   begin
      barab_size_mask64 = {60'hffff_ffff_ffff_fff << (bara_size - 4), 4'h0};
      bara_size_mask32  = {28'hffff_fff           << (bara_size - 4), 4'h0};
      barb_size_mask32  = {28'hffff_fff           << (barb_size - 4), 4'h0};
      get_bar_size_mask = (bara_64bit_mem_space == 1)? barab_size_mask64[63:0]:
                              {barb_size_mask32[31:0]  , bara_size_mask32[31:0]};
   end
endfunction
function [31:0] get_expansion_base_addr_mask;
   // Compute expansion ROM size mask based on expansion ROM size
   input integer expansion_base_address_size;
   begin
      get_expansion_base_addr_mask = {28'hffff_fff << (expansion_base_address_size - 4), 4'h0};
   end
endfunction

//synthesis translate_off
localparam ALTPCIE_AV_HIP_AST_HWTCL_SIM_ONLY = 1;
//synthesis translate_on

//synthesis read_comments_as_HDL on
//localparam ALTPCIE_AV_HIP_AST_HWTCL_SIM_ONLY = 0;
//synthesis read_comments_as_HDL off

// Exposed parameters
localparam pll_refclk_freq                               = pll_refclk_freq_hwtcl                                               ;// String  : "100 MHz";
localparam enable_slot_register                          = (enable_slot_register_hwtcl==1)?"true":"false"                      ;// String  : "false";
//localparam bypass_cdc                                    = bypass_cdc_hwtcl                                                  ;// String  : "false";
localparam enable_rx_buffer_checking                     = enable_rx_buffer_checking_hwtcl                                     ;// String  : "false";
localparam [3:0] single_rx_detect                        = single_rx_detect_hwtcl   [3:0]                                      ;//int2_4b(single_rx_detect_hwtcl)                                     ;// integer : 4'b0;
localparam use_crc_forwarding                            = (use_crc_forwarding_hwtcl==1)?"true":"false"                        ;// String  : "false";
localparam gen12_lane_rate_mode                          = (gen12_lane_rate_mode_hwtcl=="Gen2 (5.0 Gbps)")?"gen1_gen2":"gen1"  ;// String  : "gen1";
localparam lane_mask                                     = lane_mask_hwtcl                                                     ;// String  : "x4";
localparam multi_function                                = (num_of_func_hwtcl == 1)?"one_func":
                                                           (num_of_func_hwtcl == 2)?"two_func":
                                                           (num_of_func_hwtcl == 3)?"three_func":
                                                           (num_of_func_hwtcl == 4)?"four_func":
                                                           (num_of_func_hwtcl == 5)?"five_func":
                                                           (num_of_func_hwtcl == 6)?"six_func":
                                                           (num_of_func_hwtcl == 7)?"seven_func":
                                                           (num_of_func_hwtcl == 8)?"eight_func":"one_func"       ;// String  : "one_func";
localparam disable_link_x2_support                       = disable_link_x2_support_hwtcl                                       ;// String  : "false";
//localparam dis_paritychk                                 = (use_ast_parity==0)?"disable":"enable"                              ;// String  : "enable";
//localparam wrong_device_id                               = wrong_device_id_hwtcl                                               ;// String  : "disable";
//localparam data_pack_rx                                  = data_pack_rx_hwtcl                                                  ;// String  : "disable";
localparam ast_width                                     = (ast_width_hwtcl=="Avalon-ST 128-bit")?"rx_tx_128":"rx_tx_64"       ;// String  : "rx_tx_64";
//localparam rx_ast_parity                                 = (use_ast_parity==0)?"disable":"enable"                              ;// String  : "disable";
//localparam tx_ast_parity                                 = (use_ast_parity==0)?"disable":"enable"                              ;// String  : "disable";
//localparam ltssm_1ms_timeout                             = ltssm_1ms_timeout_hwtcl                                             ;// String  : "disable";
//localparam ltssm_freqlocked_check                        = ltssm_freqlocked_check_hwtcl                                        ;// String  : "disable";
//localparam deskew_comma                                  = deskew_comma_hwtcl                                                  ;// String  : "skp_eieos_deskw";
localparam [7:0] port_link_number                        = port_link_number_hwtcl        [7:0]                                 ;//int2_8b(port_link_number_hwtcl)                                     ;// integer : 8'b1;
localparam [4:0] device_number                           = device_number_hwtcl           [4:0]                                 ;//int2_5b(device_number_hwtcl)                                        ;// Integer : 5'b0;
localparam bypass_clk_switch                             = bypass_clk_switch_hwtcl                                             ;// String  : "enable";
localparam pipex1_debug_sel                              = pipex1_debug_sel_hwtcl                                              ;// String  : "disable";
localparam pclk_out_sel                                  = pclk_out_sel_hwtcl                                                  ;// String  : "pclk";
localparam use_tl_cfg_sync                               = use_tl_cfg_sync_hwtcl                                               ;
localparam porttype_func0                                = (porttype_func0_hwtcl=="Root port")?"rp":(porttype_func0_hwtcl=="Legacy endpoint")?"ep_legacy":"ep_native"                                                ;
localparam porttype_func1                                = (porttype_func1_hwtcl=="Root port")?"rp":(porttype_func1_hwtcl=="Legacy endpoint")?"ep_legacy":"ep_native"                                                ;
localparam porttype_func2                                = (porttype_func2_hwtcl=="Root port")?"rp":(porttype_func2_hwtcl=="Legacy endpoint")?"ep_legacy":"ep_native"                                                ;
localparam porttype_func3                                = (porttype_func3_hwtcl=="Root port")?"rp":(porttype_func3_hwtcl=="Legacy endpoint")?"ep_legacy":"ep_native"                                                ;
localparam porttype_func4                                = (porttype_func4_hwtcl=="Root port")?"rp":(porttype_func4_hwtcl=="Legacy endpoint")?"ep_legacy":"ep_native"                                                ;
localparam porttype_func5                                = (porttype_func5_hwtcl=="Root port")?"rp":(porttype_func5_hwtcl=="Legacy endpoint")?"ep_legacy":"ep_native"                                                ;
localparam porttype_func6                                = (porttype_func6_hwtcl=="Root port")?"rp":(porttype_func6_hwtcl=="Legacy endpoint")?"ep_legacy":"ep_native"                                                ;
localparam porttype_func7                                = (porttype_func7_hwtcl=="Root port")?"rp":(porttype_func7_hwtcl=="Legacy endpoint")?"ep_legacy":"ep_native"                                                ;
localparam no_soft_reset                                 = no_soft_reset_hwtcl                                                 ;// String  : "false";
localparam d1_support                                    = d1_support_hwtcl                                                    ;// String  : "false";
localparam d2_support                                    = d2_support_hwtcl                                                    ;// String  : "false";
localparam d0_pme                                        = d0_pme_hwtcl                                                        ;// String  : "false";
localparam d1_pme                                        = d1_pme_hwtcl                                                        ;// String  : "false";
localparam d2_pme                                        = d2_pme_hwtcl                                                        ;// String  : "false";
localparam d3_hot_pme                                    = d3_hot_pme_hwtcl                                                    ;// String  : "false";
localparam d3_cold_pme                                   = d3_cold_pme_hwtcl                                                   ;// String  : "false";
localparam low_priority_vc                               = low_priority_vc_hwtcl                                               ;// String  : "single_vc";
localparam [2:0] indicator                               = indicator_hwtcl [2:0]                                               ;//int2_3b(indicator_hwtcl)                                            ;// Integer : 3'b111;
//localparam max_link_width                                = lane_mask_hwtcl                                                     ;// String  : "x4";
localparam enable_l0s_aspm                               = enable_l0s_aspm_hwtcl                                               ;// String  : "false";
localparam enable_l1_aspm                                = enable_l1_aspm_hwtcl                                                ;// String  : "false";
localparam [2:0] l1_exit_latency_sameclock               = l1_exit_latency_sameclock_hwtcl   [2:0]                                  ;//int2_3b(l1_exit_latency_sameclock_hwtcl)                            ;// Integer : 3'b0;
localparam [2:0] l1_exit_latency_diffclock               = l1_exit_latency_diffclock_hwtcl   [2:0]                                  ;//int2_3b(l1_exit_latency_diffclock_hwtcl)                            ;// Integer : 3'b0;
localparam [6:0] hot_plug_support                        = hot_plug_support_hwtcl            [6:0]                                  ;//int2_7b(hot_plug_support_hwtcl)                                     ;// Integer : 7'b0;
localparam [7:0] diffclock_nfts_count                    = diffclock_nfts_count_hwtcl        [7:0]                                  ;//int2_8b(diffclock_nfts_count_hwtcl)                                 ;// Integer : 8'b0;
localparam [7:0] sameclock_nfts_count                    = sameclock_nfts_count_hwtcl        [7:0]                                  ;//int2_8b(sameclock_nfts_count_hwtcl)                                 ;// Integer : 8'b0;
//localparam extended_tag_reset                            = extended_tag_reset_hwtcl                                            ;// String  : "false";
localparam no_command_completed                          = no_command_completed_hwtcl                                          ;// String  : "true";
localparam [3:0] eie_before_nfts_count                   = eie_before_nfts_count_hwtcl       [3:0]                                 ;//int2_4b(eie_before_nfts_count_hwtcl)                                ;// String  : 4'b100;
localparam [7:0] gen2_diffclock_nfts_count               = gen2_diffclock_nfts_count_hwtcl   [7:0]                                 ;//int2_8b(gen2_diffclock_nfts_count_hwtcl)                            ;// String  : 8'b11111111;
localparam [7:0] gen2_sameclock_nfts_count               = gen2_sameclock_nfts_count_hwtcl   [7:0]                                 ;//int2_8b(gen2_sameclock_nfts_count_hwtcl)                            ;// String  : 8'b11111111;
localparam deemphasis_enable                             = deemphasis_enable_hwtcl                                             ;// String  : "false";
localparam pcie_spec_version                             = (pcie_spec_version_hwtcl=="2.1")?"v2":"v2"                          ;// String  : "v2";
localparam [2:0] l0_exit_latency_sameclock               = l0_exit_latency_sameclock_hwtcl   [2:0]                                  ;//int2_3b(l0_exit_latency_sameclock_hwtcl)                            ;// String  : 3'b110;
localparam [2:0] l0_exit_latency_diffclock               = l0_exit_latency_diffclock_hwtcl   [2:0]                                  ;//int2_3b(l0_exit_latency_diffclock_hwtcl)                            ;// String  : 3'b110;
localparam l2_async_logic                                = l2_async_logic_hwtcl                                                ;// String  : "enable";
localparam aspm_optionality                              = aspm_optionality_hwtcl                                              ;// String  : "true";
localparam enable_adapter_half_rate_mode                 = enable_adapter_half_rate_mode_hwtcl                                 ;// String  : "false";
localparam vc0_clk_enable                                = vc0_clk_enable_hwtcl                                                ;// String  : "true";
localparam register_pipe_signals                         = register_pipe_signals_hwtcl                                         ;// String  : "false";

   // Function 0

localparam [15:0] vendor_id_0                              = vendor_id_0_hwtcl          [15:0]                                         ;//int2_16b(vendor_id_0_hwtcl)                                           ;// integer : 16'b1000101110010;
localparam [15:0] device_id_0                              = device_id_0_hwtcl          [15:0]                                         ;//int2_16b(device_id_0_hwtcl)                                           ;// integer : 16'b1;
localparam [ 7:0] revision_id_0                            = revision_id_0_hwtcl        [ 7:0]                                         ; //int2_8b(revision_id_0_hwtcl)                                          ;// integer : 8'b1;
localparam [23:0] class_code_0                             = class_code_0_hwtcl         [23:0]                                         ;//int2_24b(class_code_0_hwtcl)                                          ;// integer : 24'b111111110000000000000000;
localparam [15:0] subsystem_vendor_id_0                    = subsystem_vendor_id_0_hwtcl[15:0];//int2_16b(subsystem_vendor_id_0_hwtcl)                                 ;// integer : 16'b1000101110010;
localparam [15:0] subsystem_device_id_0                    = subsystem_device_id_0_hwtcl[15:0];//int2_16b(subsystem_device_id_0_hwtcl)                                 ;// integer : 16'b1;

localparam [63:0] bar01_size_mask_0                        = get_bar_size_mask((bar0_64bit_mem_space_0_hwtcl=="Enabled")?1:0,bar0_size_mask_0_hwtcl, bar1_size_mask_0_hwtcl) ;
localparam bar0_io_space_0                                 = (bar0_io_space_0_hwtcl        == "Enabled")?"true":"false"            ;// String  : "false";
localparam bar0_64bit_mem_space_0                          = (bar0_64bit_mem_space_0_hwtcl == "Enabled")?"true":"false"            ;// String  : "true";
localparam bar0_prefetchable_0                             = (bar0_prefetchable_0_hwtcl    == "Enabled")?"true":"false"            ;// String  : "true";
localparam [27:0] bar0_size_mask_0                         = bar01_size_mask_0[31:4]                                               ;// Bit vector
localparam bar1_io_space_64_0                              = (bar01_size_mask_0[32]==1'b1)?"true":"false";
localparam bar1_64bit_mem_space_64_0                       = (bar01_size_mask_0[34:33]==2'b11)?"all_one":(bar01_size_mask_0[34:33]==2'b10)?"true":"false";
localparam bar1_prefetchable_64_0                          = (bar01_size_mask_0[35]==1'b1)?"true":"false";
localparam bar1_io_space_0                                 = (bar0_64bit_mem_space_0_hwtcl == "Enabled")? bar1_io_space_64_0       : (bar1_io_space_0_hwtcl        == "Enabled")?"true":"false";// String  : "false";
localparam bar1_64bit_mem_space_0                          = (bar0_64bit_mem_space_0_hwtcl == "Enabled")? bar1_64bit_mem_space_64_0:                                                  "false";// String  : "false";
localparam bar1_prefetchable_0                             = (bar0_64bit_mem_space_0_hwtcl == "Enabled")? bar1_prefetchable_64_0   : (bar1_prefetchable_0_hwtcl    == "Enabled")?"true":"false";// String  : "false";
localparam [27:0] bar1_size_mask_0                         = bar01_size_mask_0[63:36]                                              ;// String  : "N/A";
localparam [63:0] bar23_size_mask_0                        = get_bar_size_mask((bar2_64bit_mem_space_0_hwtcl=="Enabled")?1:0,bar2_size_mask_0_hwtcl, bar3_size_mask_0_hwtcl) ;
localparam bar2_io_space_0                                 = (bar2_io_space_0_hwtcl        == "Enabled")?"true":"false"            ;// String  : "false";
localparam bar2_64bit_mem_space_0                          = (bar2_64bit_mem_space_0_hwtcl == "Enabled")?"true":"false"            ;// String  : "true";
localparam bar2_prefetchable_0                             = (bar2_prefetchable_0_hwtcl    == "Enabled")?"true":"false"            ;// String  : "true";
localparam [27:0] bar2_size_mask_0                         = bar23_size_mask_0[31:4]                                               ;// Bit vector
localparam bar3_io_space_64_0                              = (bar23_size_mask_0[32]==1'b1)?"true":"false";
localparam bar3_64bit_mem_space_64_0                       = (bar23_size_mask_0[34:33]==2'b11)?"all_one":(bar23_size_mask_0[34:33]==2'b10)?"true":"false";
localparam bar3_prefetchable_64_0                          = (bar23_size_mask_0[35]==1'b1)?"true":"false";
localparam bar3_io_space_0                                 = (bar2_64bit_mem_space_0_hwtcl == "Enabled")? bar3_io_space_64_0       : (bar3_io_space_0_hwtcl        == "Enabled")?"true":"false";// String  : "false";
localparam bar3_64bit_mem_space_0                          = (bar2_64bit_mem_space_0_hwtcl == "Enabled")? bar3_64bit_mem_space_64_0:                                                  "false";// String  : "false";
localparam bar3_prefetchable_0                             = (bar2_64bit_mem_space_0_hwtcl == "Enabled")? bar3_prefetchable_64_0   : (bar3_prefetchable_0_hwtcl    == "Enabled")?"true":"false";// String  : "false";
localparam [27:0] bar3_size_mask_0                         = bar23_size_mask_0[63:36]                                              ;// String  : "N/A";
localparam [63:0] bar45_size_mask_0                        = get_bar_size_mask((bar4_64bit_mem_space_0_hwtcl=="Enabled")?1:0,bar4_size_mask_0_hwtcl, bar5_size_mask_0_hwtcl) ;
localparam bar4_io_space_0                                 = (bar4_io_space_0_hwtcl        == "Enabled")?"true":"false"            ;// String  : "false";
localparam bar4_64bit_mem_space_0                          = (bar4_64bit_mem_space_0_hwtcl == "Enabled")?"true":"false"            ;// String  : "true";
localparam bar4_prefetchable_0                             = (bar4_prefetchable_0_hwtcl    == "Enabled")?"true":"false"            ;// String  : "true";
localparam [27:0] bar4_size_mask_0                         = bar45_size_mask_0[31:4]                                               ;// Bit vector
localparam bar5_io_space_64_0                              = (bar45_size_mask_0[32]==1'b1)?"true":"false";
localparam bar5_64bit_mem_space_64_0                       = (bar45_size_mask_0[34:33]==2'b11)?"all_one":(bar45_size_mask_0[34:33]==2'b10)?"true":"false";
localparam bar5_prefetchable_64_0                          = (bar45_size_mask_0[35]==1'b1)?"true":"false";
localparam bar5_io_space_0                                 = (bar4_64bit_mem_space_0_hwtcl == "Enabled")? bar5_io_space_64_0       : (bar5_io_space_0_hwtcl        == "Enabled")?"true":"false";// String  : "false";
localparam bar5_64bit_mem_space_0                          = (bar4_64bit_mem_space_0_hwtcl == "Enabled")? bar5_64bit_mem_space_64_0:                                                  "false";// String  : "false";
localparam bar5_prefetchable_0                             = (bar4_64bit_mem_space_0_hwtcl == "Enabled")? bar5_prefetchable_64_0   : (bar5_prefetchable_0_hwtcl    == "Enabled")?"true":"false";// String  : "false";
localparam [27:0] bar5_size_mask_0                         = bar45_size_mask_0[63:36]                                              ;// String  : "N/A";

localparam [31:0] expansion_base_address_register_0        = get_expansion_base_addr_mask(expansion_base_address_register_0_hwtcl) ;

localparam msi_multi_message_capable_0                     = (msi_multi_message_capable_0_hwtcl=="1")?"count_1":
                                                             (msi_multi_message_capable_0_hwtcl=="2")?"count_2":
                                                             (msi_multi_message_capable_0_hwtcl=="4")?"count_4":
                                                             (msi_multi_message_capable_0_hwtcl=="8")?"count_8":
                                                             (msi_multi_message_capable_0_hwtcl=="16")?"count_16":"count_32"       ;// String  : "count_4";
localparam msi_64bit_addressing_capable_0                  = msi_64bit_addressing_capable_0_hwtcl                                ;// String  : "true";
localparam msi_masking_capable_0                           = msi_masking_capable_0_hwtcl                                         ;// String  : "false";
localparam msi_support_0                                   = msi_support_0_hwtcl                                                 ;// String  : "true";
localparam interrupt_pin_0                                 = interrupt_pin_0_hwtcl                                               ;// String  : "inta";
localparam enable_function_msix_support_0                  = (enable_function_msix_support_0_hwtcl==1)?"true":"false"            ;// String  : "true";
localparam [10:0]msix_table_size_0                         = msix_table_size_0_hwtcl[10:0]                                       ;//int2_11b(msix_table_size_0_hwtcl)                                     ;// Integer : 11'b0;
localparam [ 2:0]msix_table_bir_0                          = msix_table_bir_0_hwtcl [ 2:0]                                       ;//int2_3b(msix_table_bir_0_hwtcl)                                       ;// Integer : 3'b0;
localparam [28:0]msix_table_offset_0                       = str2int(msix_table_offset_0_hwtcl) >> 3                             ;//int2_29b(msix_table_offset_0_hwtcl)                                   ;// Integer : 29'b0;
localparam [ 2:0]msix_pba_bir_0                            = msix_pba_bir_0_hwtcl  [ 2:0]                                        ;//int2_3b(msix_pba_bir_0_hwtcl)                                         ;// Integer : 3'b0;
localparam [28:0]msix_pba_offset_0                         = str2int(msix_pba_offset_0_hwtcl) >> 3                               ;//int2_29b(msix_pba_offset_0_hwtcl)                                     ;// Integer : 29'b0;

localparam use_aer_0                                       = (use_aer_0_hwtcl==1)?"true":"false"                                 ;// String  : "false";
localparam ecrc_check_capable_0                            = (ecrc_check_capable_0_hwtcl==1)?"true":"false"                      ;// String  : "true";
localparam ecrc_gen_capable_0                              = (ecrc_gen_capable_0_hwtcl  ==1)?"true":"false"                      ;// String  : "true";

localparam [1:0] slot_power_scale_0                        = slot_power_scale_0_hwtcl   [1:0]                                    ;//int2_2b(slot_power_scale_0_hwtcl)                                     ;// Integer : 2'b0;
localparam [7:0] slot_power_limit_0                        = slot_power_limit_0_hwtcl   [7:0]                                    ;//int2_8b(slot_power_limit_0_hwtcl)                                     ;// Integer : 8'b0;
localparam [12:0] slot_number_0                            = slot_number_0_hwtcl        [12:0]                                   ;//int2_13b(slot_number_0_hwtcl)                                         ;// Integer : 13'b0;

localparam max_payload_size_0                              = (max_payload_size_0_hwtcl==128 )?"payload_128":
                                                             (max_payload_size_0_hwtcl==256 )?"payload_256":
                                                             (max_payload_size_0_hwtcl==512 )?"payload_512": "payload_512"       ;// String  : "payload_512";
localparam extend_tag_field_0                              = (extend_tag_field_0_hwtcl=="32")?"false":"true"                     ;// String  : "false";
localparam completion_timeout_0                            = completion_timeout_0_hwtcl                                          ;// String  : "abcd";
localparam enable_completion_timeout_disable_0             = (enable_completion_timeout_disable_0_hwtcl==1)?"true":"false"       ;// String  : "true";

localparam surprise_down_error_support_0                   = (surprise_down_error_support_0_hwtcl==1)?"true":"false"             ;// String  : "false";
localparam dll_active_report_support_0                     = (dll_active_report_support_0_hwtcl  ==1)?"true":"false"             ;// String  : "false";

localparam rx_ei_l0s_0                                     = (rx_ei_l0s_0_hwtcl==0)?"disable":"enable"                           ;// String  : "disable";
localparam [2:0] endpoint_l0_latency_0                     = endpoint_l0_latency_0_hwtcl [2:0]                                        ;//int2_3b(endpoint_l0_latency_0_hwtcl)                                  ;// Integer : 3'b0;
localparam [2:0] endpoint_l1_latency_0                     = endpoint_l1_latency_0_hwtcl [2:0]                                        ;//int2_3b(endpoint_l1_latency_0_hwtcl)                                  ;// Integer : 3'b0;
localparam [2:0] maximum_current_0                         = maximum_current_0_hwtcl     [2:0]                                        ;//int2_3b(maximum_current_0_hwtcl)                                      ;// integer : 3'b0;
localparam device_specific_init_0                          = (device_specific_init_0_hwtcl=="disable")?"false":"true"             ;// String  : "false"

localparam [15:0]ssvid_0                                   = ssvid_0_hwtcl [15:0]                                                      ;//int2_16b(ssvid_0_hwtcl)                                               ;// String  : 16'b0;
localparam [15:0]ssid_0                                    = ssid_0_hwtcl  [15:0]                                                      ;//int2_16b(ssid_0_hwtcl)                                                ;// String  : 16'b0;

localparam bridge_port_vga_enable_0                        = bridge_port_vga_enable_0_hwtcl                                      ;// String  : "false";
localparam bridge_port_ssid_support_0                      = bridge_port_ssid_support_0_hwtcl                                    ;// String  : "false";

localparam flr_capability_0                                = (flr_capability_0_hwtcl==1)?"true":"false"                          ;// String  : "true";
localparam disable_snoop_packet_0                          = disable_snoop_packet_0_hwtcl                                        ;// String  : "false";

   //----------------------------------------

   // Function 1

localparam [15:0] vendor_id_1                              = vendor_id_1_hwtcl          [15:0]                                         ;//int2_16b(vendor_id_1_hwtcl)                                           ;// integer : 16'b1000101110010;
localparam [15:0] device_id_1                              = device_id_1_hwtcl          [15:0]                                         ;//int2_16b(device_id_1_hwtcl)                                           ;// integer : 16'b1;
localparam [ 7:0] revision_id_1                            = revision_id_1_hwtcl        [ 7:0]                                         ; //int2_8b(revision_id_1_hwtcl)                                          ;// integer : 8'b1;
localparam [23:0] class_code_1                             = class_code_1_hwtcl         [23:0]                                         ;//int2_24b(class_code_1_hwtcl)                                          ;// integer : 24'b111111110000000000000000;
localparam [15:0] subsystem_vendor_id_1                    = subsystem_vendor_id_1_hwtcl[15:0];//int2_16b(subsystem_vendor_id_1_hwtcl)                                 ;// integer : 16'b1000101110010;
localparam [15:0] subsystem_device_id_1                    = subsystem_device_id_1_hwtcl[15:0];//int2_16b(subsystem_device_id_1_hwtcl)                                 ;// integer : 16'b1;

localparam [63:0] bar01_size_mask_1                        = get_bar_size_mask((bar0_64bit_mem_space_1_hwtcl=="Enabled")?1:0,bar0_size_mask_1_hwtcl, bar1_size_mask_1_hwtcl) ;
localparam bar0_io_space_1                                 = (bar0_io_space_1_hwtcl        == "Enabled")?"true":"false"            ;// String  : "false";
localparam bar0_64bit_mem_space_1                          = (bar0_64bit_mem_space_1_hwtcl == "Enabled")?"true":"false"            ;// String  : "true";
localparam bar0_prefetchable_1                             = (bar0_prefetchable_1_hwtcl    == "Enabled")?"true":"false"            ;// String  : "true";
localparam [27:0] bar0_size_mask_1                         = bar01_size_mask_1[31:4]                                               ;// Bit vector
localparam bar1_io_space_64_1                              = (bar01_size_mask_1[32]==1'b1)?"true":"false";
localparam bar1_64bit_mem_space_64_1                       = (bar01_size_mask_1[34:33]==2'b11)?"all_one":(bar01_size_mask_1[34:33]==2'b10)?"true":"false";
localparam bar1_prefetchable_64_1                          = (bar01_size_mask_1[35]==1'b1)?"true":"false";
localparam bar1_io_space_1                                 = (bar0_64bit_mem_space_1_hwtcl == "Enabled")? bar1_io_space_64_1       : (bar1_io_space_1_hwtcl        == "Enabled")?"true":"false";// String  : "false";
localparam bar1_64bit_mem_space_1                          = (bar0_64bit_mem_space_1_hwtcl == "Enabled")? bar1_64bit_mem_space_64_1:                                                  "false";// String  : "false";
localparam bar1_prefetchable_1                             = (bar0_64bit_mem_space_1_hwtcl == "Enabled")? bar1_prefetchable_64_1   : (bar1_prefetchable_1_hwtcl    == "Enabled")?"true":"false";// String  : "false";
localparam [27:0] bar1_size_mask_1                         = bar01_size_mask_1[63:36]                                              ;// String  : "N/A";
localparam [63:0] bar23_size_mask_1                        = get_bar_size_mask((bar2_64bit_mem_space_1_hwtcl=="Enabled")?1:0,bar2_size_mask_1_hwtcl, bar3_size_mask_1_hwtcl) ;
localparam bar2_io_space_1                                 = (bar2_io_space_1_hwtcl        == "Enabled")?"true":"false"            ;// String  : "false";
localparam bar2_64bit_mem_space_1                          = (bar2_64bit_mem_space_1_hwtcl == "Enabled")?"true":"false"            ;// String  : "true";
localparam bar2_prefetchable_1                             = (bar2_prefetchable_1_hwtcl    == "Enabled")?"true":"false"            ;// String  : "true";
localparam [27:0] bar2_size_mask_1                         = bar23_size_mask_1[31:4]                                               ;// Bit vector
localparam bar3_io_space_64_1                              = (bar23_size_mask_1[32]==1'b1)?"true":"false";
localparam bar3_64bit_mem_space_64_1                       = (bar23_size_mask_1[34:33]==2'b11)?"all_one":(bar23_size_mask_1[34:33]==2'b10)?"true":"false";
localparam bar3_prefetchable_64_1                          = (bar23_size_mask_1[35]==1'b1)?"true":"false";
localparam bar3_io_space_1                                 = (bar2_64bit_mem_space_1_hwtcl == "Enabled")? bar3_io_space_64_1       : (bar3_io_space_1_hwtcl        == "Enabled")?"true":"false";// String  : "false";
localparam bar3_64bit_mem_space_1                          = (bar2_64bit_mem_space_1_hwtcl == "Enabled")? bar3_64bit_mem_space_64_1:                                                  "false";// String  : "false";
localparam bar3_prefetchable_1                             = (bar2_64bit_mem_space_1_hwtcl == "Enabled")? bar3_prefetchable_64_1   : (bar3_prefetchable_1_hwtcl    == "Enabled")?"true":"false";// String  : "false";
localparam [27:0] bar3_size_mask_1                         = bar23_size_mask_1[63:36]                                              ;// String  : "N/A";
localparam [63:0] bar45_size_mask_1                        = get_bar_size_mask((bar4_64bit_mem_space_1_hwtcl=="Enabled")?1:0,bar4_size_mask_1_hwtcl, bar5_size_mask_1_hwtcl) ;
localparam bar4_io_space_1                                 = (bar4_io_space_1_hwtcl        == "Enabled")?"true":"false"            ;// String  : "false";
localparam bar4_64bit_mem_space_1                          = (bar4_64bit_mem_space_1_hwtcl == "Enabled")?"true":"false"            ;// String  : "true";
localparam bar4_prefetchable_1                             = (bar4_prefetchable_1_hwtcl    == "Enabled")?"true":"false"            ;// String  : "true";
localparam [27:0] bar4_size_mask_1                         = bar45_size_mask_1[31:4]                                               ;// Bit vector
localparam bar5_io_space_64_1                              = (bar45_size_mask_1[32]==1'b1)?"true":"false";
localparam bar5_64bit_mem_space_64_1                       = (bar45_size_mask_1[34:33]==2'b11)?"all_one":(bar45_size_mask_1[34:33]==2'b10)?"true":"false";
localparam bar5_prefetchable_64_1                          = (bar45_size_mask_1[35]==1'b1)?"true":"false";
localparam bar5_io_space_1                                 = (bar4_64bit_mem_space_1_hwtcl == "Enabled")? bar5_io_space_64_1       : (bar5_io_space_1_hwtcl        == "Enabled")?"true":"false";// String  : "false";
localparam bar5_64bit_mem_space_1                          = (bar4_64bit_mem_space_1_hwtcl == "Enabled")? bar5_64bit_mem_space_64_1:                                                  "false";// String  : "false";
localparam bar5_prefetchable_1                             = (bar4_64bit_mem_space_1_hwtcl == "Enabled")? bar5_prefetchable_64_1   : (bar5_prefetchable_1_hwtcl    == "Enabled")?"true":"false";// String  : "false";
localparam [27:0] bar5_size_mask_1                         = bar45_size_mask_1[63:36]                                              ;// String  : "N/A";

localparam [31:0] expansion_base_address_register_1        = get_expansion_base_addr_mask(expansion_base_address_register_1_hwtcl) ;

localparam msi_multi_message_capable_1                     = (msi_multi_message_capable_1_hwtcl=="1")?"count_1":
                                                             (msi_multi_message_capable_1_hwtcl=="2")?"count_2":
                                                             (msi_multi_message_capable_1_hwtcl=="4")?"count_4":
                                                             (msi_multi_message_capable_1_hwtcl=="8")?"count_8":
                                                             (msi_multi_message_capable_1_hwtcl=="16")?"count_16":"count_32"       ;// String  : "count_4";
localparam msi_64bit_addressing_capable_1                  = msi_64bit_addressing_capable_1_hwtcl                                ;// String  : "true";
localparam msi_masking_capable_1                           = msi_masking_capable_1_hwtcl                                         ;// String  : "false";
localparam msi_support_1                                   = msi_support_1_hwtcl                                                 ;// String  : "true";
localparam interrupt_pin_1                                 = interrupt_pin_1_hwtcl                                               ;// String  : "inta";
localparam enable_function_msix_support_1                  = (enable_function_msix_support_1_hwtcl==1)?"true":"false"            ;// String  : "true";
localparam [10:0]msix_table_size_1                         = msix_table_size_1_hwtcl [10:0]                                            ;//int2_11b(msix_table_size_1_hwtcl)                                     ;// Integer : 11'b0;
localparam [ 2:0]msix_table_bir_1                          = msix_table_bir_1_hwtcl  [ 2:0]                                            ;//int2_3b(msix_table_bir_1_hwtcl)                                       ;// Integer : 3'b0;
localparam [28:0]msix_table_offset_1                       = str2int(msix_table_offset_1_hwtcl) >> 3                             ;//int2_29b(msix_table_offset_1_hwtcl)                                   ;// Integer : 29'b0;
localparam [ 2:0]msix_pba_bir_1                            = msix_pba_bir_1_hwtcl    [ 2:0]                                            ;//int2_3b(msix_pba_bir_1_hwtcl)                                         ;// Integer : 3'b0;
localparam [28:0]msix_pba_offset_1                         = str2int(msix_pba_offset_1_hwtcl) >> 3                               ;//int2_29b(msix_pba_offset_1_hwtcl)                                     ;// Integer : 29'b0;

localparam use_aer_1                                       = (use_aer_1_hwtcl==1)?"true":"false"                                 ;// String  : "false";
localparam ecrc_check_capable_1                            = (ecrc_check_capable_1_hwtcl==1)?"true":"false"                      ;// String  : "true";
localparam ecrc_gen_capable_1                              = (ecrc_gen_capable_1_hwtcl  ==1)?"true":"false"                      ;// String  : "true";

localparam [1:0] slot_power_scale_1                        = slot_power_scale_1_hwtcl  [1:0]                                           ;//int2_2b(slot_power_scale_1_hwtcl)                                     ;// Integer : 2'b0;
localparam [7:0] slot_power_limit_1                        = slot_power_limit_1_hwtcl  [7:0]                                           ;//int2_8b(slot_power_limit_1_hwtcl)                                     ;// Integer : 8'b0;
localparam [12:0] slot_number_1                            = slot_number_1_hwtcl       [12:0]                                          ;//int2_13b(slot_number_1_hwtcl)                                         ;// Integer : 13'b0;

localparam max_payload_size_1                              = (max_payload_size_1_hwtcl==128 )?"payload_128":
                                                             (max_payload_size_1_hwtcl==256 )?"payload_256":
                                                             (max_payload_size_1_hwtcl==512 )?"payload_512":"payload_512"        ;// String  : "payload_512";
localparam extend_tag_field_1                              = (extend_tag_field_1_hwtcl=="32")?"false":"true"                     ;// String  : "false";
localparam completion_timeout_1                            = completion_timeout_1_hwtcl                                          ;// String  : "abcd";
localparam enable_completion_timeout_disable_1             = (enable_completion_timeout_disable_1_hwtcl==1)?"true":"false"       ;// String  : "true";

localparam surprise_down_error_support_1                   = (surprise_down_error_support_1_hwtcl==1)?"true":"false"             ;// String  : "false";
localparam dll_active_report_support_1                     = (dll_active_report_support_1_hwtcl  ==1)?"true":"false"             ;// String  : "false";

localparam rx_ei_l0s_1                                     = (rx_ei_l0s_1_hwtcl==0)?"disable":"enable"                           ;// String  : "disable";
localparam [2:0] endpoint_l0_latency_1                     = endpoint_l0_latency_1_hwtcl   [2:0]                                      ;//int2_3b(endpoint_l0_latency_1_hwtcl)                                  ;// Integer : 3'b0;
localparam [2:0] endpoint_l1_latency_1                     = endpoint_l1_latency_1_hwtcl   [2:0]                                      ;//int2_3b(endpoint_l1_latency_1_hwtcl)                                  ;// Integer : 3'b0;
localparam [2:0] maximum_current_1                         = maximum_current_1_hwtcl       [2:0]                                      ;//int2_3b(maximum_current_1_hwtcl)                                      ;// integer : 3'b0;
localparam device_specific_init_1                          = (device_specific_init_1_hwtcl=="disable")?"false":"true"                                        ;// String  : "false"

localparam [15:0]ssvid_1                                   = ssvid_1_hwtcl   [15:0]                                                    ;//int2_16b(ssvid_1_hwtcl)                                               ;// String  : 16'b0;
localparam [15:0]ssid_1                                    = ssid_1_hwtcl    [15:0]                                                    ;//int2_16b(ssid_1_hwtcl)                                                ;// String  : 16'b0;

localparam bridge_port_vga_enable_1                        = bridge_port_vga_enable_1_hwtcl                                      ;// String  : "false";
localparam bridge_port_ssid_support_1                      = bridge_port_ssid_support_1_hwtcl                                    ;// String  : "false";

localparam flr_capability_1                                = (flr_capability_1_hwtcl==1)?"true":"false"                          ;// String  : "true";
localparam disable_snoop_packet_1                          = disable_snoop_packet_1_hwtcl                                        ;// String  : "false";

   //----------------------------------------

   // Function 2

localparam [15:0] vendor_id_2                              = vendor_id_2_hwtcl          [15:0]                                         ;//int2_16b(vendor_id_2_hwtcl)                                           ;// integer : 16'b1000101110010;
localparam [15:0] device_id_2                              = device_id_2_hwtcl          [15:0]                                         ;//int2_16b(device_id_2_hwtcl)                                           ;// integer : 16'b1;
localparam [ 7:0] revision_id_2                            = revision_id_2_hwtcl        [ 7:0]                                         ; //int2_8b(revision_id_2_hwtcl)                                          ;// integer : 8'b1;
localparam [23:0] class_code_2                             = class_code_2_hwtcl         [23:0]                                         ;//int2_24b(class_code_2_hwtcl)                                          ;// integer : 24'b111111110000000000000000;
localparam [15:0] subsystem_vendor_id_2                    = subsystem_vendor_id_2_hwtcl[15:0];//int2_16b(subsystem_vendor_id_2_hwtcl)                                 ;// integer : 16'b1000101110010;
localparam [15:0] subsystem_device_id_2                    = subsystem_device_id_2_hwtcl[15:0];//int2_16b(subsystem_device_id_2_hwtcl)                                 ;// integer : 16'b1;

localparam [63:0] bar01_size_mask_2                        = get_bar_size_mask((bar0_64bit_mem_space_2_hwtcl=="Enabled")?1:0,bar0_size_mask_2_hwtcl, bar1_size_mask_2_hwtcl) ;
localparam bar0_io_space_2                                 = (bar0_io_space_2_hwtcl        == "Enabled")?"true":"false"            ;// String  : "false";
localparam bar0_64bit_mem_space_2                          = (bar0_64bit_mem_space_2_hwtcl == "Enabled")?"true":"false"            ;// String  : "true";
localparam bar0_prefetchable_2                             = (bar0_prefetchable_2_hwtcl    == "Enabled")?"true":"false"            ;// String  : "true";
localparam [27:0] bar0_size_mask_2                         = bar01_size_mask_2[31:4]                                               ;// Bit vector
localparam bar1_io_space_64_2                              = (bar01_size_mask_2[32]==1'b1)?"true":"false";
localparam bar1_64bit_mem_space_64_2                       = (bar01_size_mask_2[34:33]==2'b11)?"all_one":(bar01_size_mask_2[34:33]==2'b10)?"true":"false";
localparam bar1_prefetchable_64_2                          = (bar01_size_mask_2[35]==1'b1)?"true":"false";
localparam bar1_io_space_2                                 = (bar0_64bit_mem_space_2_hwtcl == "Enabled")? bar1_io_space_64_2       : (bar1_io_space_2_hwtcl        == "Enabled")?"true":"false";// String  : "false";
localparam bar1_64bit_mem_space_2                          = (bar0_64bit_mem_space_2_hwtcl == "Enabled")? bar1_64bit_mem_space_64_2:                                                  "false";// String  : "false";
localparam bar1_prefetchable_2                             = (bar0_64bit_mem_space_2_hwtcl == "Enabled")? bar1_prefetchable_64_2   : (bar1_prefetchable_2_hwtcl    == "Enabled")?"true":"false";// String  : "false";
localparam [27:0] bar1_size_mask_2                         = bar01_size_mask_2[63:36]                                              ;// String  : "N/A";
localparam [63:0] bar23_size_mask_2                        = get_bar_size_mask((bar2_64bit_mem_space_2_hwtcl=="Enabled")?1:0,bar2_size_mask_2_hwtcl, bar3_size_mask_2_hwtcl) ;
localparam bar2_io_space_2                                 = (bar2_io_space_2_hwtcl        == "Enabled")?"true":"false"            ;// String  : "false";
localparam bar2_64bit_mem_space_2                          = (bar2_64bit_mem_space_2_hwtcl == "Enabled")?"true":"false"            ;// String  : "true";
localparam bar2_prefetchable_2                             = (bar2_prefetchable_2_hwtcl    == "Enabled")?"true":"false"            ;// String  : "true";
localparam [27:0] bar2_size_mask_2                         = bar23_size_mask_2[31:4]                                               ;// Bit vector
localparam bar3_io_space_64_2                              = (bar23_size_mask_2[32]==1'b1)?"true":"false";
localparam bar3_64bit_mem_space_64_2                       = (bar23_size_mask_2[34:33]==2'b11)?"all_one":(bar23_size_mask_2[34:33]==2'b10)?"true":"false";
localparam bar3_prefetchable_64_2                          = (bar23_size_mask_2[35]==1'b1)?"true":"false";
localparam bar3_io_space_2                                 = (bar2_64bit_mem_space_2_hwtcl == "Enabled")? bar3_io_space_64_2       : (bar3_io_space_2_hwtcl        == "Enabled")?"true":"false";// String  : "false";
localparam bar3_64bit_mem_space_2                          = (bar2_64bit_mem_space_2_hwtcl == "Enabled")? bar3_64bit_mem_space_64_2:                                                  "false";// String  : "false";
localparam bar3_prefetchable_2                             = (bar2_64bit_mem_space_2_hwtcl == "Enabled")? bar3_prefetchable_64_2   : (bar3_prefetchable_2_hwtcl    == "Enabled")?"true":"false";// String  : "false";
localparam [27:0] bar3_size_mask_2                         = bar23_size_mask_2[63:36]                                              ;// String  : "N/A";
localparam [63:0] bar45_size_mask_2                        = get_bar_size_mask((bar4_64bit_mem_space_2_hwtcl=="Enabled")?1:0,bar4_size_mask_2_hwtcl, bar5_size_mask_2_hwtcl) ;
localparam bar4_io_space_2                                 = (bar4_io_space_2_hwtcl        == "Enabled")?"true":"false"            ;// String  : "false";
localparam bar4_64bit_mem_space_2                          = (bar4_64bit_mem_space_2_hwtcl == "Enabled")?"true":"false"            ;// String  : "true";
localparam bar4_prefetchable_2                             = (bar4_prefetchable_2_hwtcl    == "Enabled")?"true":"false"            ;// String  : "true";
localparam [27:0] bar4_size_mask_2                         = bar45_size_mask_2[31:4]                                               ;// Bit vector
localparam bar5_io_space_64_2                              = (bar45_size_mask_2[32]==1'b1)?"true":"false";
localparam bar5_64bit_mem_space_64_2                       = (bar45_size_mask_2[34:33]==2'b11)?"all_one":(bar45_size_mask_2[34:33]==2'b10)?"true":"false";
localparam bar5_prefetchable_64_2                          = (bar45_size_mask_2[35]==1'b1)?"true":"false";
localparam bar5_io_space_2                                 = (bar4_64bit_mem_space_2_hwtcl == "Enabled")? bar5_io_space_64_2       : (bar5_io_space_2_hwtcl        == "Enabled")?"true":"false";// String  : "false";
localparam bar5_64bit_mem_space_2                          = (bar4_64bit_mem_space_2_hwtcl == "Enabled")? bar5_64bit_mem_space_64_2:                                                  "false";// String  : "false";
localparam bar5_prefetchable_2                             = (bar4_64bit_mem_space_2_hwtcl == "Enabled")? bar5_prefetchable_64_2   : (bar5_prefetchable_2_hwtcl    == "Enabled")?"true":"false";// String  : "false";
localparam [27:0] bar5_size_mask_2                         = bar45_size_mask_2[63:36]                                              ;// String  : "N/A";

localparam [31:0] expansion_base_address_register_2        = get_expansion_base_addr_mask(expansion_base_address_register_2_hwtcl) ;

localparam msi_multi_message_capable_2                     = (msi_multi_message_capable_2_hwtcl=="1")?"count_1":
                                                             (msi_multi_message_capable_2_hwtcl=="2")?"count_2":
                                                             (msi_multi_message_capable_2_hwtcl=="4")?"count_4":
                                                             (msi_multi_message_capable_2_hwtcl=="8")?"count_8":
                                                             (msi_multi_message_capable_2_hwtcl=="16")?"count_16":"count_32"       ;// String  : "count_4";
localparam msi_64bit_addressing_capable_2                  = msi_64bit_addressing_capable_2_hwtcl                                ;// String  : "true";
localparam msi_masking_capable_2                           = msi_masking_capable_2_hwtcl                                         ;// String  : "false";
localparam msi_support_2                                   = msi_support_2_hwtcl                                                 ;// String  : "true";
localparam interrupt_pin_2                                 = interrupt_pin_2_hwtcl                                               ;// String  : "inta";
localparam enable_function_msix_support_2                  = (enable_function_msix_support_2_hwtcl==1)?"true":"false"            ;// String  : "true";
localparam [10:0]msix_table_size_2                         = msix_table_size_2_hwtcl [10:0]                                            ;//int2_11b(msix_table_size_2_hwtcl)                                     ;// Integer : 11'b0;
localparam [ 2:0]msix_table_bir_2                          = msix_table_bir_2_hwtcl  [ 2:0]                                            ;//int2_3b(msix_table_bir_2_hwtcl)                                       ;// Integer : 3'b0;
localparam [28:0]msix_table_offset_2                       = str2int(msix_table_offset_2_hwtcl) >> 3                             ;//int2_29b(msix_table_offset_2_hwtcl)                                   ;// Integer : 29'b0;
localparam [ 2:0]msix_pba_bir_2                            = msix_pba_bir_2_hwtcl   [ 2:0]                                             ;//int2_3b(msix_pba_bir_2_hwtcl)                                         ;// Integer : 3'b0;
localparam [28:0]msix_pba_offset_2                         = str2int(msix_pba_offset_2_hwtcl) >> 3                               ;//int2_29b(msix_pba_offset_2_hwtcl)                                     ;// Integer : 29'b0;

localparam use_aer_2                                       = (use_aer_2_hwtcl==1)?"true":"false"                                 ;// String  : "false";
localparam ecrc_check_capable_2                            = (ecrc_check_capable_2_hwtcl==1)?"true":"false"                      ;// String  : "true";
localparam ecrc_gen_capable_2                              = (ecrc_gen_capable_2_hwtcl  ==1)?"true":"false"                      ;// String  : "true";

localparam [1:0] slot_power_scale_2                        = slot_power_scale_2_hwtcl [1:0]                                            ;//int2_2b(slot_power_scale_2_hwtcl)                                     ;// Integer : 2'b0;
localparam [7:0] slot_power_limit_2                        = slot_power_limit_2_hwtcl [7:0]                                            ;//int2_8b(slot_power_limit_2_hwtcl)                                     ;// Integer : 8'b0;
localparam [12:0] slot_number_2                            = slot_number_2_hwtcl      [12:0]                                           ;//int2_13b(slot_number_2_hwtcl)                                         ;// Integer : 13'b0;

localparam max_payload_size_2                              = (max_payload_size_2_hwtcl==128 )?"payload_128":
                                                             (max_payload_size_2_hwtcl==256 )?"payload_256":
                                                             (max_payload_size_2_hwtcl==512 )?"payload_512":"payload_512"       ;// String  : "payload_512";
localparam extend_tag_field_2                              = (extend_tag_field_2_hwtcl=="32")?"false":"true"                     ;// String  : "false";
localparam completion_timeout_2                            = completion_timeout_2_hwtcl                                          ;// String  : "abcd";
localparam enable_completion_timeout_disable_2             = (enable_completion_timeout_disable_2_hwtcl==1)?"true":"false"       ;// String  : "true";

localparam surprise_down_error_support_2                   = (surprise_down_error_support_2_hwtcl==1)?"true":"false"             ;// String  : "false";
localparam dll_active_report_support_2                     = (dll_active_report_support_2_hwtcl  ==1)?"true":"false"             ;// String  : "false";

localparam rx_ei_l0s_2                                     = (rx_ei_l0s_2_hwtcl==0)?"disable":"enable"                           ;// String  : "disable";
localparam [2:0] endpoint_l0_latency_2                     = endpoint_l0_latency_2_hwtcl [2:0]                                         ;//int2_3b(endpoint_l0_latency_2_hwtcl)                                  ;// Integer : 3'b0;
localparam [2:0] endpoint_l1_latency_2                     = endpoint_l1_latency_2_hwtcl [2:0]                                         ;//int2_3b(endpoint_l1_latency_2_hwtcl)                                  ;// Integer : 3'b0;
localparam [2:0] maximum_current_2                         = maximum_current_2_hwtcl     [2:0]                                         ;//int2_3b(maximum_current_2_hwtcl)                                      ;// integer : 3'b0;
localparam device_specific_init_2                          = (device_specific_init_2_hwtcl=="disable")?"false":"true"                                        ;// String  : "false"

localparam [15:0]ssvid_2                                   = ssvid_2_hwtcl  [15:0]                                                     ;//int2_16b(ssvid_2_hwtcl)                                               ;// String  : 16'b0;
localparam [15:0]ssid_2                                    = ssid_2_hwtcl   [15:0]                                                     ;//int2_16b(ssid_2_hwtcl)                                                ;// String  : 16'b0;

localparam bridge_port_vga_enable_2                        = bridge_port_vga_enable_2_hwtcl                                      ;// String  : "false";
localparam bridge_port_ssid_support_2                      = bridge_port_ssid_support_2_hwtcl                                    ;// String  : "false";

localparam flr_capability_2                                = (flr_capability_2_hwtcl==1)?"true":"false"                          ;// String  : "true";
localparam disable_snoop_packet_2                          = disable_snoop_packet_2_hwtcl                                        ;// String  : "false";

   //----------------------------------------

   // Function 3

localparam [15:0] vendor_id_3                              = vendor_id_3_hwtcl          [15:0]                                         ;//int2_16b(vendor_id_3_hwtcl)                                           ;// integer : 16'b1000101110010;
localparam [15:0] device_id_3                              = device_id_3_hwtcl          [15:0]                                         ;//int2_16b(device_id_3_hwtcl)                                           ;// integer : 16'b1;
localparam [ 7:0] revision_id_3                            = revision_id_3_hwtcl        [ 7:0]                                         ; //int2_8b(revision_id_3_hwtcl)                                          ;// integer : 8'b1;
localparam [23:0] class_code_3                             = class_code_3_hwtcl         [23:0]                                         ;//int2_24b(class_code_3_hwtcl)                                          ;// integer : 24'b111111110000000000000000;
localparam [15:0] subsystem_vendor_id_3                    = subsystem_vendor_id_3_hwtcl[15:0];//int2_16b(subsystem_vendor_id_3_hwtcl)                                 ;// integer : 16'b1000101110010;
localparam [15:0] subsystem_device_id_3                    = subsystem_device_id_3_hwtcl[15:0];//int2_16b(subsystem_device_id_3_hwtcl)                                 ;// integer : 16'b1;

localparam [63:0] bar01_size_mask_3                        = get_bar_size_mask((bar0_64bit_mem_space_3_hwtcl=="Enabled")?1:0,bar0_size_mask_3_hwtcl, bar1_size_mask_3_hwtcl) ;
localparam bar0_io_space_3                                 = (bar0_io_space_3_hwtcl        == "Enabled")?"true":"false"            ;// String  : "false";
localparam bar0_64bit_mem_space_3                          = (bar0_64bit_mem_space_3_hwtcl == "Enabled")?"true":"false"            ;// String  : "true";
localparam bar0_prefetchable_3                             = (bar0_prefetchable_3_hwtcl    == "Enabled")?"true":"false"            ;// String  : "true";
localparam [27:0] bar0_size_mask_3                         = bar01_size_mask_3[31:4]                                               ;// Bit vector
localparam bar1_io_space_64_3                              = (bar01_size_mask_3[32]==1'b1)?"true":"false";
localparam bar1_64bit_mem_space_64_3                       = (bar01_size_mask_3[34:33]==2'b11)?"all_one":(bar01_size_mask_3[34:33]==2'b10)?"true":"false";
localparam bar1_prefetchable_64_3                          = (bar01_size_mask_3[35]==1'b1)?"true":"false";
localparam bar1_io_space_3                                 = (bar0_64bit_mem_space_3_hwtcl == "Enabled")? bar1_io_space_64_3       : (bar1_io_space_3_hwtcl        == "Enabled")?"true":"false";// String  : "false";
localparam bar1_64bit_mem_space_3                          = (bar0_64bit_mem_space_3_hwtcl == "Enabled")? bar1_64bit_mem_space_64_3:                                                  "false";// String  : "false";
localparam bar1_prefetchable_3                             = (bar0_64bit_mem_space_3_hwtcl == "Enabled")? bar1_prefetchable_64_3   : (bar1_prefetchable_3_hwtcl    == "Enabled")?"true":"false";// String  : "false";
localparam [27:0] bar1_size_mask_3                         = bar01_size_mask_3[63:36]                                              ;// String  : "N/A";
localparam [63:0] bar23_size_mask_3                        = get_bar_size_mask((bar2_64bit_mem_space_3_hwtcl=="Enabled")?1:0,bar2_size_mask_3_hwtcl, bar3_size_mask_3_hwtcl) ;
localparam bar2_io_space_3                                 = (bar2_io_space_3_hwtcl        == "Enabled")?"true":"false"            ;// String  : "false";
localparam bar2_64bit_mem_space_3                          = (bar2_64bit_mem_space_3_hwtcl == "Enabled")?"true":"false"            ;// String  : "true";
localparam bar2_prefetchable_3                             = (bar2_prefetchable_3_hwtcl    == "Enabled")?"true":"false"            ;// String  : "true";
localparam [27:0] bar2_size_mask_3                         = bar23_size_mask_3[31:4]                                               ;// Bit vector
localparam bar3_io_space_64_3                              = (bar23_size_mask_3[32]==1'b1)?"true":"false";
localparam bar3_64bit_mem_space_64_3                       = (bar23_size_mask_3[34:33]==2'b11)?"all_one":(bar23_size_mask_3[34:33]==2'b10)?"true":"false";
localparam bar3_prefetchable_64_3                          = (bar23_size_mask_3[35]==1'b1)?"true":"false";
localparam bar3_io_space_3                                 = (bar2_64bit_mem_space_3_hwtcl == "Enabled")? bar3_io_space_64_3       : (bar3_io_space_3_hwtcl        == "Enabled")?"true":"false";// String  : "false";
localparam bar3_64bit_mem_space_3                          = (bar2_64bit_mem_space_3_hwtcl == "Enabled")? bar3_64bit_mem_space_64_3:                                                  "false";// String  : "false";
localparam bar3_prefetchable_3                             = (bar2_64bit_mem_space_3_hwtcl == "Enabled")? bar3_prefetchable_64_3   : (bar3_prefetchable_3_hwtcl    == "Enabled")?"true":"false";// String  : "false";
localparam [27:0] bar3_size_mask_3                         = bar23_size_mask_3[63:36]                                              ;// String  : "N/A";
localparam [63:0] bar45_size_mask_3                        = get_bar_size_mask((bar4_64bit_mem_space_3_hwtcl=="Enabled")?1:0,bar4_size_mask_3_hwtcl, bar5_size_mask_3_hwtcl) ;
localparam bar4_io_space_3                                 = (bar4_io_space_3_hwtcl        == "Enabled")?"true":"false"            ;// String  : "false";
localparam bar4_64bit_mem_space_3                          = (bar4_64bit_mem_space_3_hwtcl == "Enabled")?"true":"false"            ;// String  : "true";
localparam bar4_prefetchable_3                             = (bar4_prefetchable_3_hwtcl    == "Enabled")?"true":"false"            ;// String  : "true";
localparam [27:0] bar4_size_mask_3                         = bar45_size_mask_3[31:4]                                               ;// Bit vector
localparam bar5_io_space_64_3                              = (bar45_size_mask_3[32]==1'b1)?"true":"false";
localparam bar5_64bit_mem_space_64_3                       = (bar45_size_mask_3[34:33]==2'b11)?"all_one":(bar45_size_mask_3[34:33]==2'b10)?"true":"false";
localparam bar5_prefetchable_64_3                          = (bar45_size_mask_3[35]==1'b1)?"true":"false";
localparam bar5_io_space_3                                 = (bar4_64bit_mem_space_3_hwtcl == "Enabled")? bar5_io_space_64_3       : (bar5_io_space_3_hwtcl        == "Enabled")?"true":"false";// String  : "false";
localparam bar5_64bit_mem_space_3                          = (bar4_64bit_mem_space_3_hwtcl == "Enabled")? bar5_64bit_mem_space_64_3:                                                  "false";// String  : "false";
localparam bar5_prefetchable_3                             = (bar4_64bit_mem_space_3_hwtcl == "Enabled")? bar5_prefetchable_64_3   : (bar5_prefetchable_3_hwtcl    == "Enabled")?"true":"false";// String  : "false";
localparam [27:0] bar5_size_mask_3                         = bar45_size_mask_3[63:36]                                              ;// String  : "N/A";

localparam [31:0] expansion_base_address_register_3        = get_expansion_base_addr_mask(expansion_base_address_register_3_hwtcl) ;

localparam msi_multi_message_capable_3                     = (msi_multi_message_capable_3_hwtcl=="1")?"count_1":
                                                             (msi_multi_message_capable_3_hwtcl=="2")?"count_2":
                                                             (msi_multi_message_capable_3_hwtcl=="4")?"count_4":
                                                             (msi_multi_message_capable_3_hwtcl=="8")?"count_8":
                                                             (msi_multi_message_capable_3_hwtcl=="16")?"count_16":"count_32"       ;// String  : "count_4";
localparam msi_64bit_addressing_capable_3                  = msi_64bit_addressing_capable_3_hwtcl                                ;// String  : "true";
localparam msi_masking_capable_3                           = msi_masking_capable_3_hwtcl                                         ;// String  : "false";
localparam msi_support_3                                   = msi_support_3_hwtcl                                                 ;// String  : "true";
localparam interrupt_pin_3                                 = interrupt_pin_3_hwtcl                                               ;// String  : "inta";
localparam enable_function_msix_support_3                  = (enable_function_msix_support_3_hwtcl==1)?"true":"false"            ;// String  : "true";
localparam [10:0]msix_table_size_3                         = msix_table_size_3_hwtcl  [10:0]                                           ;//int2_11b(msix_table_size_3_hwtcl)                                     ;// Integer : 11'b0;
localparam [ 2:0]msix_table_bir_3                          = msix_table_bir_3_hwtcl   [ 2:0]                                           ;//int2_3b(msix_table_bir_3_hwtcl)                                       ;// Integer : 3'b0;
localparam [28:0]msix_table_offset_3                       = str2int(msix_table_offset_3_hwtcl) >> 3                             ;//int2_29b(msix_table_offset_3_hwtcl)                                   ;// Integer : 29'b0;
localparam [ 2:0]msix_pba_bir_3                            = msix_pba_bir_3_hwtcl     [ 2:0]                                           ;//int2_3b(msix_pba_bir_3_hwtcl)                                         ;// Integer : 3'b0;
localparam [28:0]msix_pba_offset_3                         = str2int(msix_pba_offset_3_hwtcl) >> 3                               ;//int2_29b(msix_pba_offset_3_hwtcl)                                     ;// Integer : 29'b0;

localparam use_aer_3                                       = (use_aer_3_hwtcl==1)?"true":"false"                                 ;// String  : "false";
localparam ecrc_check_capable_3                            = (ecrc_check_capable_3_hwtcl==1)?"true":"false"                      ;// String  : "true";
localparam ecrc_gen_capable_3                              = (ecrc_gen_capable_3_hwtcl  ==1)?"true":"false"                      ;// String  : "true";

localparam [1:0] slot_power_scale_3                        = slot_power_scale_3_hwtcl [1:0]                                            ;//int2_2b(slot_power_scale_3_hwtcl)                                     ;// Integer : 2'b0;
localparam [7:0] slot_power_limit_3                        = slot_power_limit_3_hwtcl [7:0]                                            ;//int2_8b(slot_power_limit_3_hwtcl)                                     ;// Integer : 8'b0;
localparam [12:0] slot_number_3                            = slot_number_3_hwtcl      [12:0]                                           ;//int2_13b(slot_number_3_hwtcl)                                         ;// Integer : 13'b0;

localparam max_payload_size_3                              = (max_payload_size_3_hwtcl==128 )?"payload_128":
                                                             (max_payload_size_3_hwtcl==256 )?"payload_256":
                                                             (max_payload_size_3_hwtcl==512 )?"payload_512":"payload_512"        ;// String  : "payload_512";
localparam extend_tag_field_3                              = (extend_tag_field_3_hwtcl=="32")?"false":"true"                     ;// String  : "false";
localparam completion_timeout_3                            = completion_timeout_3_hwtcl                                          ;// String  : "abcd";
localparam enable_completion_timeout_disable_3             = (enable_completion_timeout_disable_3_hwtcl==1)?"true":"false"       ;// String  : "true";

localparam surprise_down_error_support_3                   = (surprise_down_error_support_3_hwtcl==1)?"true":"false"             ;// String  : "false";
localparam dll_active_report_support_3                     = (dll_active_report_support_3_hwtcl  ==1)?"true":"false"             ;// String  : "false";

localparam rx_ei_l0s_3                                     = (rx_ei_l0s_3_hwtcl==0)?"disable":"enable"                           ;// String  : "disable";
localparam [2:0] endpoint_l0_latency_3                     = endpoint_l0_latency_3_hwtcl [2:0]                                        ;//int2_3b(endpoint_l0_latency_3_hwtcl)                                  ;// Integer : 3'b0;
localparam [2:0] endpoint_l1_latency_3                     = endpoint_l1_latency_3_hwtcl [2:0]                                        ;//int2_3b(endpoint_l1_latency_3_hwtcl)                                  ;// Integer : 3'b0;
localparam [2:0] maximum_current_3                         = maximum_current_3_hwtcl     [2:0]                                        ;//int2_3b(maximum_current_3_hwtcl)                                      ;// integer : 3'b0;
localparam device_specific_init_3                          = (device_specific_init_3_hwtcl=="disable")?"false":"true"                                        ;// String  : "false"

localparam [15:0]ssvid_3                                   = ssvid_3_hwtcl [15:0]                                                      ;//int2_16b(ssvid_3_hwtcl)                                               ;// String  : 16'b0;
localparam [15:0]ssid_3                                    = ssid_3_hwtcl  [15:0]                                                      ;//int2_16b(ssid_3_hwtcl)                                                ;// String  : 16'b0;

localparam bridge_port_vga_enable_3                        = bridge_port_vga_enable_3_hwtcl                                      ;// String  : "false";
localparam bridge_port_ssid_support_3                      = bridge_port_ssid_support_3_hwtcl                                    ;// String  : "false";

localparam flr_capability_3                                = (flr_capability_3_hwtcl==1)?"true":"false"                          ;// String  : "true";
localparam disable_snoop_packet_3                          = disable_snoop_packet_3_hwtcl                                        ;// String  : "false";

   //----------------------------------------

   // Function 4

localparam [15:0] vendor_id_4                              = vendor_id_4_hwtcl          [15:0]                                          ;//int2_16b(vendor_id_4_hwtcl)                                           ;// integer : 16'b1000101110010;
localparam [15:0] device_id_4                              = device_id_4_hwtcl          [15:0]                                          ;//int2_16b(device_id_4_hwtcl)                                           ;// integer : 16'b1;
localparam [ 7:0] revision_id_4                            = revision_id_4_hwtcl        [ 7:0]                                          ; //int2_8b(revision_id_4_hwtcl)                                          ;// integer : 8'b1;
localparam [23:0] class_code_4                             = class_code_4_hwtcl         [23:0]                                          ;//int2_24b(class_code_4_hwtcl)                                          ;// integer : 24'b111111110000000000000000;
localparam [15:0] subsystem_vendor_id_4                    = subsystem_vendor_id_4_hwtcl[15:0] ;//int2_16b(subsystem_vendor_id_4_hwtcl)                                 ;// integer : 16'b1000101110010;
localparam [15:0] subsystem_device_id_4                    = subsystem_device_id_4_hwtcl[15:0] ;//int2_16b(subsystem_device_id_4_hwtcl)                                 ;// integer : 16'b1;

localparam [63:0] bar01_size_mask_4                        = get_bar_size_mask((bar0_64bit_mem_space_4_hwtcl=="Enabled")?1:0,bar0_size_mask_4_hwtcl, bar1_size_mask_4_hwtcl) ;
localparam bar0_io_space_4                                 = (bar0_io_space_4_hwtcl        == "Enabled")?"true":"false"            ;// String  : "false";
localparam bar0_64bit_mem_space_4                          = (bar0_64bit_mem_space_4_hwtcl == "Enabled")?"true":"false"            ;// String  : "true";
localparam bar0_prefetchable_4                             = (bar0_prefetchable_4_hwtcl    == "Enabled")?"true":"false"            ;// String  : "true";
localparam [27:0] bar0_size_mask_4                         = bar01_size_mask_4[31:4]                                               ;// Bit vector
localparam bar1_io_space_64_4                              = (bar01_size_mask_4[32]==1'b1)?"true":"false";
localparam bar1_64bit_mem_space_64_4                       = (bar01_size_mask_4[34:33]==2'b11)?"all_one":(bar01_size_mask_4[34:33]==2'b10)?"true":"false";
localparam bar1_prefetchable_64_4                          = (bar01_size_mask_4[35]==1'b1)?"true":"false";
localparam bar1_io_space_4                                 = (bar0_64bit_mem_space_4_hwtcl == "Enabled")? bar1_io_space_64_4       : (bar1_io_space_4_hwtcl        == "Enabled")?"true":"false";// String  : "false";
localparam bar1_64bit_mem_space_4                          = (bar0_64bit_mem_space_4_hwtcl == "Enabled")? bar1_64bit_mem_space_64_4:                                                  "false";// String  : "false";
localparam bar1_prefetchable_4                             = (bar0_64bit_mem_space_4_hwtcl == "Enabled")? bar1_prefetchable_64_4   : (bar1_prefetchable_4_hwtcl    == "Enabled")?"true":"false";// String  : "false";
localparam [27:0] bar1_size_mask_4                         = bar01_size_mask_4[63:36]                                              ;// String  : "N/A";
localparam [63:0] bar23_size_mask_4                        = get_bar_size_mask((bar2_64bit_mem_space_4_hwtcl=="Enabled")?1:0,bar2_size_mask_4_hwtcl, bar3_size_mask_4_hwtcl) ;
localparam bar2_io_space_4                                 = (bar2_io_space_4_hwtcl        == "Enabled")?"true":"false"            ;// String  : "false";
localparam bar2_64bit_mem_space_4                          = (bar2_64bit_mem_space_4_hwtcl == "Enabled")?"true":"false"            ;// String  : "true";
localparam bar2_prefetchable_4                             = (bar2_prefetchable_4_hwtcl    == "Enabled")?"true":"false"            ;// String  : "true";
localparam [27:0] bar2_size_mask_4                         = bar23_size_mask_4[31:4]                                               ;// Bit vector
localparam bar3_io_space_64_4                              = (bar23_size_mask_4[32]==1'b1)?"true":"false";
localparam bar3_64bit_mem_space_64_4                       = (bar23_size_mask_4[34:33]==2'b11)?"all_one":(bar23_size_mask_4[34:33]==2'b10)?"true":"false";
localparam bar3_prefetchable_64_4                          = (bar23_size_mask_4[35]==1'b1)?"true":"false";
localparam bar3_io_space_4                                 = (bar2_64bit_mem_space_4_hwtcl == "Enabled")? bar3_io_space_64_4       : (bar3_io_space_4_hwtcl        == "Enabled")?"true":"false";// String  : "false";
localparam bar3_64bit_mem_space_4                          = (bar2_64bit_mem_space_4_hwtcl == "Enabled")? bar3_64bit_mem_space_64_4:                                                  "false";// String  : "false";
localparam bar3_prefetchable_4                             = (bar2_64bit_mem_space_4_hwtcl == "Enabled")? bar3_prefetchable_64_4   : (bar3_prefetchable_4_hwtcl    == "Enabled")?"true":"false";// String  : "false";
localparam [27:0] bar3_size_mask_4                         = bar23_size_mask_4[63:36]                                              ;// String  : "N/A";
localparam [63:0] bar45_size_mask_4                        = get_bar_size_mask((bar4_64bit_mem_space_4_hwtcl=="Enabled")?1:0,bar4_size_mask_4_hwtcl, bar5_size_mask_4_hwtcl) ;
localparam bar4_io_space_4                                 = (bar4_io_space_4_hwtcl        == "Enabled")?"true":"false"            ;// String  : "false";
localparam bar4_64bit_mem_space_4                          = (bar4_64bit_mem_space_4_hwtcl == "Enabled")?"true":"false"            ;// String  : "true";
localparam bar4_prefetchable_4                             = (bar4_prefetchable_4_hwtcl    == "Enabled")?"true":"false"            ;// String  : "true";
localparam [27:0] bar4_size_mask_4                         = bar45_size_mask_4[31:4]                                               ;// Bit vector
localparam bar5_io_space_64_4                              = (bar45_size_mask_4[32]==1'b1)?"true":"false";
localparam bar5_64bit_mem_space_64_4                       = (bar45_size_mask_4[34:33]==2'b11)?"all_one":(bar45_size_mask_4[34:33]==2'b10)?"true":"false";
localparam bar5_prefetchable_64_4                          = (bar45_size_mask_4[35]==1'b1)?"true":"false";
localparam bar5_io_space_4                                 = (bar4_64bit_mem_space_4_hwtcl == "Enabled")? bar5_io_space_64_4       : (bar5_io_space_4_hwtcl        == "Enabled")?"true":"false";// String  : "false";
localparam bar5_64bit_mem_space_4                          = (bar4_64bit_mem_space_4_hwtcl == "Enabled")? bar5_64bit_mem_space_64_4:                                                  "false";// String  : "false";
localparam bar5_prefetchable_4                             = (bar4_64bit_mem_space_4_hwtcl == "Enabled")? bar5_prefetchable_64_4   : (bar5_prefetchable_4_hwtcl    == "Enabled")?"true":"false";// String  : "false";
localparam [27:0] bar5_size_mask_4                         = bar45_size_mask_4[63:36]                                              ;// String  : "N/A";

localparam [31:0] expansion_base_address_register_4        = get_expansion_base_addr_mask(expansion_base_address_register_4_hwtcl) ;

localparam msi_multi_message_capable_4                     = (msi_multi_message_capable_4_hwtcl=="1")?"count_1":
                                                             (msi_multi_message_capable_4_hwtcl=="2")?"count_2":
                                                             (msi_multi_message_capable_4_hwtcl=="4")?"count_4":
                                                             (msi_multi_message_capable_4_hwtcl=="8")?"count_8":
                                                             (msi_multi_message_capable_4_hwtcl=="16")?"count_16":"count_32"       ;// String  : "count_4";
localparam msi_64bit_addressing_capable_4                  = msi_64bit_addressing_capable_4_hwtcl                                ;// String  : "true";
localparam msi_masking_capable_4                           = msi_masking_capable_4_hwtcl                                         ;// String  : "false";
localparam msi_support_4                                   = msi_support_4_hwtcl                                                 ;// String  : "true";
localparam interrupt_pin_4                                 = interrupt_pin_4_hwtcl                                               ;// String  : "inta";
localparam enable_function_msix_support_4                  = (enable_function_msix_support_4_hwtcl==1)?"true":"false"            ;// String  : "true";
localparam [10:0]msix_table_size_4                         = msix_table_size_4_hwtcl                     [10:0]                        ;//int2_11b(msix_table_size_4_hwtcl)                                     ;// Integer : 11'b0;
localparam [ 2:0]msix_table_bir_4                          = msix_table_bir_4_hwtcl                      [ 2:0]                        ;//int2_3b(msix_table_bir_4_hwtcl)                                       ;// Integer : 3'b0;
localparam [28:0]msix_table_offset_4                       = str2int(msix_table_offset_4_hwtcl) >> 3                                   ;//int2_29b(msix_table_offset_4_hwtcl)                                   ;// Integer : 29'b0;
localparam [ 2:0]msix_pba_bir_4                            = msix_pba_bir_4_hwtcl                        [ 2:0]                        ;//int2_3b(msix_pba_bir_4_hwtcl)                                         ;// Integer : 3'b0;
localparam [28:0]msix_pba_offset_4                         = str2int(msix_pba_offset_4_hwtcl) >> 3                                     ;//int2_29b(msix_pba_offset_4_hwtcl)                                     ;// Integer : 29'b0;

localparam use_aer_4                                       = (use_aer_4_hwtcl==1)?"true":"false"                                 ;// String  : "false";
localparam ecrc_check_capable_4                            = (ecrc_check_capable_4_hwtcl==1)?"true":"false"                      ;// String  : "true";
localparam ecrc_gen_capable_4                              = (ecrc_gen_capable_4_hwtcl  ==1)?"true":"false"                      ;// String  : "true";

localparam [1:0] slot_power_scale_4                        = slot_power_scale_4_hwtcl [1:0]                                            ;//int2_2b(slot_power_scale_4_hwtcl)                                     ;// Integer : 2'b0;
localparam [7:0] slot_power_limit_4                        = slot_power_limit_4_hwtcl [7:0]                                            ;//int2_8b(slot_power_limit_4_hwtcl)                                     ;// Integer : 8'b0;
localparam [12:0] slot_number_4                            = slot_number_4_hwtcl      [12:0]                                           ;//int2_13b(slot_number_4_hwtcl)                                         ;// Integer : 13'b0;

localparam max_payload_size_4                              = (max_payload_size_4_hwtcl==128 )?"payload_128":
                                                             (max_payload_size_4_hwtcl==256 )?"payload_256":
                                                             (max_payload_size_4_hwtcl==512 )?"payload_512":"payload_512"       ;// String  : "payload_512";
localparam extend_tag_field_4                              = (extend_tag_field_4_hwtcl=="32")?"false":"true"                     ;// String  : "false";
localparam completion_timeout_4                            = completion_timeout_4_hwtcl                                          ;// String  : "abcd";
localparam enable_completion_timeout_disable_4             = (enable_completion_timeout_disable_4_hwtcl==1)?"true":"false"       ;// String  : "true";

localparam surprise_down_error_support_4                   = (surprise_down_error_support_4_hwtcl==1)?"true":"false"             ;// String  : "false";
localparam dll_active_report_support_4                     = (dll_active_report_support_4_hwtcl  ==1)?"true":"false"             ;// String  : "false";

localparam rx_ei_l0s_4                                     = (rx_ei_l0s_4_hwtcl==0)?"disable":"enable"                           ;// String  : "disable";
localparam [2:0] endpoint_l0_latency_4                     = endpoint_l0_latency_4_hwtcl [2:0]                                         ;//int2_3b(endpoint_l0_latency_4_hwtcl)                                  ;// Integer : 3'b0;
localparam [2:0] endpoint_l1_latency_4                     = endpoint_l1_latency_4_hwtcl [2:0]                                         ;//int2_3b(endpoint_l1_latency_4_hwtcl)                                  ;// Integer : 3'b0;
localparam [2:0] maximum_current_4                         = maximum_current_4_hwtcl     [2:0]                                         ;//int2_3b(maximum_current_4_hwtcl)                                      ;// integer : 3'b0;
localparam device_specific_init_4                          = (device_specific_init_4_hwtcl=="disable")?"false":"true"                                        ;// String  : "false"

localparam [15:0]ssvid_4                                   = ssvid_4_hwtcl [15:0]                                                      ;//int2_16b(ssvid_4_hwtcl)                                               ;// String  : 16'b0;
localparam [15:0]ssid_4                                    = ssid_4_hwtcl  [15:0]                                                      ;//int2_16b(ssid_4_hwtcl)                                                ;// String  : 16'b0;

localparam bridge_port_vga_enable_4                        = bridge_port_vga_enable_4_hwtcl                                      ;// String  : "false";
localparam bridge_port_ssid_support_4                      = bridge_port_ssid_support_4_hwtcl                                    ;// String  : "false";

localparam flr_capability_4                                = (flr_capability_4_hwtcl==1)?"true":"false"                          ;// String  : "true";
localparam disable_snoop_packet_4                          = disable_snoop_packet_4_hwtcl                                        ;// String  : "false";

   //----------------------------------------

   // Function 5

localparam [15:0] vendor_id_5                              = vendor_id_5_hwtcl          [15:0]                                         ;//int2_16b(vendor_id_5_hwtcl)                                           ;// integer : 16'b1000101110010;
localparam [15:0] device_id_5                              = device_id_5_hwtcl          [15:0]                                         ;//int2_16b(device_id_5_hwtcl)                                           ;// integer : 16'b1;
localparam [ 7:0] revision_id_5                            = revision_id_5_hwtcl        [ 7:0]                                         ; //int2_8b(revision_id_5_hwtcl)                                          ;// integer : 8'b1;
localparam [23:0] class_code_5                             = class_code_5_hwtcl         [23:0]                                         ;//int2_24b(class_code_5_hwtcl)                                          ;// integer : 24'b111111110000000000000000;
localparam [15:0] subsystem_vendor_id_5                    = subsystem_vendor_id_5_hwtcl[15:0];//int2_16b(subsystem_vendor_id_5_hwtcl)                                 ;// integer : 16'b1000101110010;
localparam [15:0] subsystem_device_id_5                    = subsystem_device_id_5_hwtcl[15:0];//int2_16b(subsystem_device_id_5_hwtcl)                                 ;// integer : 16'b1;

localparam [63:0] bar01_size_mask_5                        = get_bar_size_mask((bar0_64bit_mem_space_5_hwtcl=="Enabled")?1:0,bar0_size_mask_5_hwtcl, bar1_size_mask_5_hwtcl) ;
localparam bar0_io_space_5                                 = (bar0_io_space_5_hwtcl        == "Enabled")?"true":"false"            ;// String  : "false";
localparam bar0_64bit_mem_space_5                          = (bar0_64bit_mem_space_5_hwtcl == "Enabled")?"true":"false"            ;// String  : "true";
localparam bar0_prefetchable_5                             = (bar0_prefetchable_5_hwtcl    == "Enabled")?"true":"false"            ;// String  : "true";
localparam [27:0] bar0_size_mask_5                         = bar01_size_mask_5[31:4]                                               ;// Bit vector
localparam bar1_io_space_64_5                              = (bar01_size_mask_5[32]==1'b1)?"true":"false";
localparam bar1_64bit_mem_space_64_5                       = (bar01_size_mask_5[34:33]==2'b11)?"all_one":(bar01_size_mask_5[34:33]==2'b10)?"true":"false";
localparam bar1_prefetchable_64_5                          = (bar01_size_mask_5[35]==1'b1)?"true":"false";
localparam bar1_io_space_5                                 = (bar0_64bit_mem_space_5_hwtcl == "Enabled")? bar1_io_space_64_5       : (bar1_io_space_5_hwtcl        == "Enabled")?"true":"false";// String  : "false";
localparam bar1_64bit_mem_space_5                          = (bar0_64bit_mem_space_5_hwtcl == "Enabled")? bar1_64bit_mem_space_64_5:                                                  "false";// String  : "false";
localparam bar1_prefetchable_5                             = (bar0_64bit_mem_space_5_hwtcl == "Enabled")? bar1_prefetchable_64_5   : (bar1_prefetchable_5_hwtcl    == "Enabled")?"true":"false";// String  : "false";
localparam [27:0] bar1_size_mask_5                         = bar01_size_mask_5[63:36]                                              ;// String  : "N/A";
localparam [63:0] bar23_size_mask_5                        = get_bar_size_mask((bar2_64bit_mem_space_5_hwtcl=="Enabled")?1:0,bar2_size_mask_5_hwtcl, bar3_size_mask_5_hwtcl) ;
localparam bar2_io_space_5                                 = (bar2_io_space_5_hwtcl        == "Enabled")?"true":"false"            ;// String  : "false";
localparam bar2_64bit_mem_space_5                          = (bar2_64bit_mem_space_5_hwtcl == "Enabled")?"true":"false"            ;// String  : "true";
localparam bar2_prefetchable_5                             = (bar2_prefetchable_5_hwtcl    == "Enabled")?"true":"false"            ;// String  : "true";
localparam [27:0] bar2_size_mask_5                         = bar23_size_mask_5[31:4]                                               ;// Bit vector
localparam bar3_io_space_64_5                              = (bar23_size_mask_5[32]==1'b1)?"true":"false";
localparam bar3_64bit_mem_space_64_5                       = (bar23_size_mask_5[34:33]==2'b11)?"all_one":(bar23_size_mask_5[34:33]==2'b10)?"true":"false";
localparam bar3_prefetchable_64_5                          = (bar23_size_mask_5[35]==1'b1)?"true":"false";
localparam bar3_io_space_5                                 = (bar2_64bit_mem_space_5_hwtcl == "Enabled")? bar3_io_space_64_5       : (bar3_io_space_5_hwtcl        == "Enabled")?"true":"false";// String  : "false";
localparam bar3_64bit_mem_space_5                          = (bar2_64bit_mem_space_5_hwtcl == "Enabled")? bar3_64bit_mem_space_64_5:                                                  "false";// String  : "false";
localparam bar3_prefetchable_5                             = (bar2_64bit_mem_space_5_hwtcl == "Enabled")? bar3_prefetchable_64_5   : (bar3_prefetchable_5_hwtcl    == "Enabled")?"true":"false";// String  : "false";
localparam [27:0] bar3_size_mask_5                         = bar23_size_mask_5[63:36]                                              ;// String  : "N/A";
localparam [63:0] bar45_size_mask_5                        = get_bar_size_mask((bar4_64bit_mem_space_5_hwtcl=="Enabled")?1:0,bar4_size_mask_5_hwtcl, bar5_size_mask_5_hwtcl) ;
localparam bar4_io_space_5                                 = (bar4_io_space_5_hwtcl        == "Enabled")?"true":"false"            ;// String  : "false";
localparam bar4_64bit_mem_space_5                          = (bar4_64bit_mem_space_5_hwtcl == "Enabled")?"true":"false"            ;// String  : "true";
localparam bar4_prefetchable_5                             = (bar4_prefetchable_5_hwtcl    == "Enabled")?"true":"false"            ;// String  : "true";
localparam [27:0] bar4_size_mask_5                         = bar45_size_mask_5[31:4]                                               ;// Bit vector
localparam bar5_io_space_64_5                              = (bar45_size_mask_5[32]==1'b1)?"true":"false";
localparam bar5_64bit_mem_space_64_5                       = (bar45_size_mask_5[34:33]==2'b11)?"all_one":(bar45_size_mask_5[34:33]==2'b10)?"true":"false";
localparam bar5_prefetchable_64_5                          = (bar45_size_mask_5[35]==1'b1)?"true":"false";
localparam bar5_io_space_5                                 = (bar4_64bit_mem_space_5_hwtcl == "Enabled")? bar5_io_space_64_5       : (bar5_io_space_5_hwtcl        == "Enabled")?"true":"false";// String  : "false";
localparam bar5_64bit_mem_space_5                          = (bar4_64bit_mem_space_5_hwtcl == "Enabled")? bar5_64bit_mem_space_64_5:                                                  "false";// String  : "false";
localparam bar5_prefetchable_5                             = (bar4_64bit_mem_space_5_hwtcl == "Enabled")? bar5_prefetchable_64_5   : (bar5_prefetchable_5_hwtcl    == "Enabled")?"true":"false";// String  : "false";
localparam [27:0] bar5_size_mask_5                         = bar45_size_mask_5[63:36]                                              ;// String  : "N/A";

localparam [31:0] expansion_base_address_register_5        = get_expansion_base_addr_mask(expansion_base_address_register_5_hwtcl) ;

localparam msi_multi_message_capable_5                     = (msi_multi_message_capable_5_hwtcl=="1")?"count_1":
                                                             (msi_multi_message_capable_5_hwtcl=="2")?"count_2":
                                                             (msi_multi_message_capable_5_hwtcl=="4")?"count_4":
                                                             (msi_multi_message_capable_5_hwtcl=="8")?"count_8":
                                                             (msi_multi_message_capable_5_hwtcl=="16")?"count_16":"count_32"       ;// String  : "count_4";
localparam msi_64bit_addressing_capable_5                  = msi_64bit_addressing_capable_5_hwtcl                                ;// String  : "true";
localparam msi_masking_capable_5                           = msi_masking_capable_5_hwtcl                                         ;// String  : "false";
localparam msi_support_5                                   = msi_support_5_hwtcl                                                 ;// String  : "true";
localparam interrupt_pin_5                                 = interrupt_pin_5_hwtcl                                               ;// String  : "inta";
localparam enable_function_msix_support_5                  = (enable_function_msix_support_5_hwtcl==1)?"true":"false"            ;// String  : "true";
localparam [10:0]msix_table_size_5                         = msix_table_size_5_hwtcl                     [10:0]                        ;//int2_11b(msix_table_size_5_hwtcl)                                     ;// Integer : 11'b0;
localparam [ 2:0]msix_table_bir_5                          = msix_table_bir_5_hwtcl                      [ 2:0]                        ;//int2_3b(msix_table_bir_5_hwtcl)                                       ;// Integer : 3'b0;
localparam [28:0]msix_table_offset_5                       = str2int(msix_table_offset_5_hwtcl) >> 3                                   ;//int2_29b(msix_table_offset_5_hwtcl)                                   ;// Integer : 29'b0;
localparam [ 2:0]msix_pba_bir_5                            = msix_pba_bir_5_hwtcl                        [ 2:0]                        ;//int2_3b(msix_pba_bir_5_hwtcl)                                         ;// Integer : 3'b0;
localparam [28:0]msix_pba_offset_5                         = str2int(msix_pba_offset_5_hwtcl) >> 3                                     ;//int2_29b(msix_pba_offset_5_hwtcl)                                     ;// Integer : 29'b0;

localparam use_aer_5                                       = (use_aer_5_hwtcl==1)?"true":"false"                                 ;// String  : "false";
localparam ecrc_check_capable_5                            = (ecrc_check_capable_5_hwtcl==1)?"true":"false"                      ;// String  : "true";
localparam ecrc_gen_capable_5                              = (ecrc_gen_capable_5_hwtcl  ==1)?"true":"false"                      ;// String  : "true";

localparam [1:0] slot_power_scale_5                        = slot_power_scale_5_hwtcl  [1:0]                                           ;//int2_2b(slot_power_scale_5_hwtcl)                                     ;// Integer : 2'b0;
localparam [7:0] slot_power_limit_5                        = slot_power_limit_5_hwtcl  [7:0]                                           ;//int2_8b(slot_power_limit_5_hwtcl)                                     ;// Integer : 8'b0;
localparam [12:0] slot_number_5                            = slot_number_5_hwtcl       [12:0]                                          ;//int2_13b(slot_number_5_hwtcl)                                         ;// Integer : 13'b0;

localparam max_payload_size_5                              = (max_payload_size_5_hwtcl==128 )?"payload_128":
                                                             (max_payload_size_5_hwtcl==256 )?"payload_256":
                                                             (max_payload_size_5_hwtcl==512 )?"payload_512":"payload_512"        ;// String  : "payload_512";
localparam extend_tag_field_5                              = (extend_tag_field_5_hwtcl=="32")?"false":"true"                     ;// String  : "false";
localparam completion_timeout_5                            = completion_timeout_5_hwtcl                                          ;// String  : "abcd";
localparam enable_completion_timeout_disable_5             = (enable_completion_timeout_disable_5_hwtcl==1)?"true":"false"       ;// String  : "true";

localparam surprise_down_error_support_5                   = (surprise_down_error_support_5_hwtcl==1)?"true":"false"             ;// String  : "false";
localparam dll_active_report_support_5                     = (dll_active_report_support_5_hwtcl  ==1)?"true":"false"             ;// String  : "false";

localparam rx_ei_l0s_5                                     = (rx_ei_l0s_5_hwtcl==0)?"disable":"enable"                           ;// String  : "disable";
localparam [2:0] endpoint_l0_latency_5                     = endpoint_l0_latency_5_hwtcl  [2:0]                                       ;//int2_3b(endpoint_l0_latency_5_hwtcl)                                  ;// Integer : 3'b0;
localparam [2:0] endpoint_l1_latency_5                     = endpoint_l1_latency_5_hwtcl  [2:0]                                       ;//int2_3b(endpoint_l1_latency_5_hwtcl)                                  ;// Integer : 3'b0;
localparam [2:0] maximum_current_5                         = maximum_current_5_hwtcl      [2:0]                                       ;//int2_3b(maximum_current_5_hwtcl)                                      ;// integer : 3'b0;
localparam device_specific_init_5                          = (device_specific_init_5_hwtcl=="disable")?"false":"true"                                        ;// String  : "false"

localparam [15:0]ssvid_5                                   = ssvid_5_hwtcl [15:0]                                                      ;//int2_16b(ssvid_5_hwtcl)                                               ;// String  : 16'b0;
localparam [15:0]ssid_5                                    = ssid_5_hwtcl  [15:0]                                                      ;//int2_16b(ssid_5_hwtcl)                                                ;// String  : 16'b0;

localparam bridge_port_vga_enable_5                        = bridge_port_vga_enable_5_hwtcl                                      ;// String  : "false";
localparam bridge_port_ssid_support_5                      = bridge_port_ssid_support_5_hwtcl                                    ;// String  : "false";

localparam flr_capability_5                                = (flr_capability_5_hwtcl==1)?"true":"false"                          ;// String  : "true";
localparam disable_snoop_packet_5                          = disable_snoop_packet_5_hwtcl                                        ;// String  : "false";

   //----------------------------------------

   // Function 6

localparam [15:0] vendor_id_6                              = vendor_id_6_hwtcl          [15:0]                                          ;//int2_16b(vendor_id_6_hwtcl)                                           ;// integer : 16'b1000101110010;
localparam [15:0] device_id_6                              = device_id_6_hwtcl          [15:0]                                          ;//int2_16b(device_id_6_hwtcl)                                           ;// integer : 16'b1;
localparam [ 7:0] revision_id_6                            = revision_id_6_hwtcl        [ 7:0]                                          ; //int2_8b(revision_id_6_hwtcl)                                          ;// integer : 8'b1;
localparam [23:0] class_code_6                             = class_code_6_hwtcl         [23:0]                                          ;//int2_24b(class_code_6_hwtcl)                                          ;// integer : 24'b111111110000000000000000;
localparam [15:0] subsystem_vendor_id_6                    = subsystem_vendor_id_6_hwtcl[15:0] ;//int2_16b(subsystem_vendor_id_6_hwtcl)                                 ;// integer : 16'b1000101110010;
localparam [15:0] subsystem_device_id_6                    = subsystem_device_id_6_hwtcl[15:0] ;//int2_16b(subsystem_device_id_6_hwtcl)                                 ;// integer : 16'b1;

localparam [63:0] bar01_size_mask_6                        = get_bar_size_mask((bar0_64bit_mem_space_6_hwtcl=="Enabled")?1:0,bar0_size_mask_6_hwtcl, bar1_size_mask_6_hwtcl) ;
localparam bar0_io_space_6                                 = (bar0_io_space_6_hwtcl        == "Enabled")?"true":"false"            ;// String  : "false";
localparam bar0_64bit_mem_space_6                          = (bar0_64bit_mem_space_6_hwtcl == "Enabled")?"true":"false"            ;// String  : "true";
localparam bar0_prefetchable_6                             = (bar0_prefetchable_6_hwtcl    == "Enabled")?"true":"false"            ;// String  : "true";
localparam [27:0] bar0_size_mask_6                         = bar01_size_mask_6[31:4]                                               ;// Bit vector
localparam bar1_io_space_64_6                              = (bar01_size_mask_6[32]==1'b1)?"true":"false";
localparam bar1_64bit_mem_space_64_6                       = (bar01_size_mask_6[34:33]==2'b11)?"all_one":(bar01_size_mask_6[34:33]==2'b10)?"true":"false";
localparam bar1_prefetchable_64_6                          = (bar01_size_mask_6[35]==1'b1)?"true":"false";
localparam bar1_io_space_6                                 = (bar0_64bit_mem_space_6_hwtcl == "Enabled")? bar1_io_space_64_6       : (bar1_io_space_6_hwtcl        == "Enabled")?"true":"false";// String  : "false";
localparam bar1_64bit_mem_space_6                          = (bar0_64bit_mem_space_6_hwtcl == "Enabled")? bar1_64bit_mem_space_64_6:                                                  "false";// String  : "false";
localparam bar1_prefetchable_6                             = (bar0_64bit_mem_space_6_hwtcl == "Enabled")? bar1_prefetchable_64_6   : (bar1_prefetchable_6_hwtcl    == "Enabled")?"true":"false";// String  : "false";
localparam [27:0] bar1_size_mask_6                         = bar01_size_mask_6[63:36]                                              ;// String  : "N/A";
localparam [63:0] bar23_size_mask_6                        = get_bar_size_mask((bar2_64bit_mem_space_6_hwtcl=="Enabled")?1:0,bar2_size_mask_6_hwtcl, bar3_size_mask_6_hwtcl) ;
localparam bar2_io_space_6                                 = (bar2_io_space_6_hwtcl        == "Enabled")?"true":"false"            ;// String  : "false";
localparam bar2_64bit_mem_space_6                          = (bar2_64bit_mem_space_6_hwtcl == "Enabled")?"true":"false"            ;// String  : "true";
localparam bar2_prefetchable_6                             = (bar2_prefetchable_6_hwtcl    == "Enabled")?"true":"false"            ;// String  : "true";
localparam [27:0] bar2_size_mask_6                         = bar23_size_mask_6[31:4]                                               ;// Bit vector
localparam bar3_io_space_64_6                              = (bar23_size_mask_6[32]==1'b1)?"true":"false";
localparam bar3_64bit_mem_space_64_6                       = (bar23_size_mask_6[34:33]==2'b11)?"all_one":(bar23_size_mask_6[34:33]==2'b10)?"true":"false";
localparam bar3_prefetchable_64_6                          = (bar23_size_mask_6[35]==1'b1)?"true":"false";
localparam bar3_io_space_6                                 = (bar2_64bit_mem_space_6_hwtcl == "Enabled")? bar3_io_space_64_6       : (bar3_io_space_6_hwtcl        == "Enabled")?"true":"false";// String  : "false";
localparam bar3_64bit_mem_space_6                          = (bar2_64bit_mem_space_6_hwtcl == "Enabled")? bar3_64bit_mem_space_64_6:                                                  "false";// String  : "false";
localparam bar3_prefetchable_6                             = (bar2_64bit_mem_space_6_hwtcl == "Enabled")? bar3_prefetchable_64_6   : (bar3_prefetchable_6_hwtcl    == "Enabled")?"true":"false";// String  : "false";
localparam [27:0] bar3_size_mask_6                         = bar23_size_mask_6[63:36]                                              ;// String  : "N/A";
localparam [63:0] bar45_size_mask_6                        = get_bar_size_mask((bar4_64bit_mem_space_6_hwtcl=="Enabled")?1:0,bar4_size_mask_6_hwtcl, bar5_size_mask_6_hwtcl) ;
localparam bar4_io_space_6                                 = (bar4_io_space_6_hwtcl        == "Enabled")?"true":"false"            ;// String  : "false";
localparam bar4_64bit_mem_space_6                          = (bar4_64bit_mem_space_6_hwtcl == "Enabled")?"true":"false"            ;// String  : "true";
localparam bar4_prefetchable_6                             = (bar4_prefetchable_6_hwtcl    == "Enabled")?"true":"false"            ;// String  : "true";
localparam [27:0] bar4_size_mask_6                         = bar45_size_mask_6[31:4]                                               ;// Bit vector
localparam bar5_io_space_64_6                              = (bar45_size_mask_6[32]==1'b1)?"true":"false";
localparam bar5_64bit_mem_space_64_6                       = (bar45_size_mask_6[34:33]==2'b11)?"all_one":(bar45_size_mask_6[34:33]==2'b10)?"true":"false";
localparam bar5_prefetchable_64_6                          = (bar45_size_mask_6[35]==1'b1)?"true":"false";
localparam bar5_io_space_6                                 = (bar4_64bit_mem_space_6_hwtcl == "Enabled")? bar5_io_space_64_6       : (bar5_io_space_6_hwtcl        == "Enabled")?"true":"false";// String  : "false";
localparam bar5_64bit_mem_space_6                          = (bar4_64bit_mem_space_6_hwtcl == "Enabled")? bar5_64bit_mem_space_64_6:                                                  "false";// String  : "false";
localparam bar5_prefetchable_6                             = (bar4_64bit_mem_space_6_hwtcl == "Enabled")? bar5_prefetchable_64_6   : (bar5_prefetchable_6_hwtcl    == "Enabled")?"true":"false";// String  : "false";
localparam [27:0] bar5_size_mask_6                         = bar45_size_mask_6[63:36]                                              ;// String  : "N/A";

localparam [31:0] expansion_base_address_register_6        = get_expansion_base_addr_mask(expansion_base_address_register_6_hwtcl) ;

localparam msi_multi_message_capable_6                     = (msi_multi_message_capable_6_hwtcl=="1")?"count_1":
                                                             (msi_multi_message_capable_6_hwtcl=="2")?"count_2":
                                                             (msi_multi_message_capable_6_hwtcl=="4")?"count_4":
                                                             (msi_multi_message_capable_6_hwtcl=="8")?"count_8":
                                                             (msi_multi_message_capable_6_hwtcl=="16")?"count_16":"count_32"       ;// String  : "count_4";
localparam msi_64bit_addressing_capable_6                  = msi_64bit_addressing_capable_6_hwtcl                                ;// String  : "true";
localparam msi_masking_capable_6                           = msi_masking_capable_6_hwtcl                                         ;// String  : "false";
localparam msi_support_6                                   = msi_support_6_hwtcl                                                 ;// String  : "true";
localparam interrupt_pin_6                                 = interrupt_pin_6_hwtcl                                               ;// String  : "inta";
localparam enable_function_msix_support_6                  = (enable_function_msix_support_6_hwtcl==1)?"true":"false"            ;// String  : "true";
localparam [10:0]msix_table_size_6                         = msix_table_size_6_hwtcl                       [10:0]                ;//int2_11b(msix_table_size_6_hwtcl)                                     ;// Integer : 11'b0;
localparam [ 2:0]msix_table_bir_6                          = msix_table_bir_6_hwtcl                        [ 2:0]                ;//int2_3b(msix_table_bir_6_hwtcl)                                       ;// Integer : 3'b0;
localparam [28:0]msix_table_offset_6                       = str2int(msix_table_offset_6_hwtcl) >> 3                             ;//int2_29b(msix_table_offset_6_hwtcl)                                   ;// Integer : 29'b0;
localparam [ 2:0]msix_pba_bir_6                            = msix_pba_bir_6_hwtcl                          [ 2:0]                ;//int2_3b(msix_pba_bir_6_hwtcl)                                         ;// Integer : 3'b0;
localparam [28:0]msix_pba_offset_6                         = str2int(msix_pba_offset_6_hwtcl) >> 3                               ;//int2_29b(msix_pba_offset_6_hwtcl)                                     ;// Integer : 29'b0;

localparam use_aer_6                                       = (use_aer_6_hwtcl==1)?"true":"false"                                 ;// String  : "false";
localparam ecrc_check_capable_6                            = (ecrc_check_capable_6_hwtcl==1)?"true":"false"                      ;// String  : "true";
localparam ecrc_gen_capable_6                              = (ecrc_gen_capable_6_hwtcl  ==1)?"true":"false"                      ;// String  : "true";

localparam [1:0] slot_power_scale_6                        = slot_power_scale_6_hwtcl  [1:0]                                           ;//int2_2b(slot_power_scale_6_hwtcl)                                     ;// Integer : 2'b0;
localparam [7:0] slot_power_limit_6                        = slot_power_limit_6_hwtcl  [7:0]                                           ;//int2_8b(slot_power_limit_6_hwtcl)                                     ;// Integer : 8'b0;
localparam [12:0] slot_number_6                            = slot_number_6_hwtcl       [12:0]                                          ;//int2_13b(slot_number_6_hwtcl)                                         ;// Integer : 13'b0;

localparam max_payload_size_6                              = (max_payload_size_6_hwtcl==128 )?"payload_128":
                                                             (max_payload_size_6_hwtcl==256 )?"payload_256":
                                                             (max_payload_size_6_hwtcl==512 )?"payload_512":"payload_512"        ;// String  : "payload_512";
localparam extend_tag_field_6                              = (extend_tag_field_6_hwtcl=="32")?"false":"true"                     ;// String  : "false";
localparam completion_timeout_6                            = completion_timeout_6_hwtcl                                          ;// String  : "abcd";
localparam enable_completion_timeout_disable_6             = (enable_completion_timeout_disable_6_hwtcl==1)?"true":"false"       ;// String  : "true";

localparam surprise_down_error_support_6                   = (surprise_down_error_support_6_hwtcl==1)?"true":"false"             ;// String  : "false";
localparam dll_active_report_support_6                     = (dll_active_report_support_6_hwtcl  ==1)?"true":"false"             ;// String  : "false";

localparam rx_ei_l0s_6                                     = (rx_ei_l0s_6_hwtcl==0)?"disable":"enable"                           ;// String  : "disable";
localparam [2:0] endpoint_l0_latency_6                     = endpoint_l0_latency_6_hwtcl                                         ;//int2_3b(endpoint_l0_latency_6_hwtcl)                                  ;// Integer : 3'b0;
localparam [2:0] endpoint_l1_latency_6                     = endpoint_l1_latency_6_hwtcl                                         ;//int2_3b(endpoint_l1_latency_6_hwtcl)                                  ;// Integer : 3'b0;
localparam [2:0] maximum_current_6                         = maximum_current_6_hwtcl                                             ;//int2_3b(maximum_current_6_hwtcl)                                      ;// integer : 3'b0;
localparam device_specific_init_6                          = (device_specific_init_6_hwtcl=="disable")?"false":"true"                                       ;// String  : "false"

localparam [15:0]ssvid_6                                   = ssvid_6_hwtcl  [15:0]                                                     ;//int2_16b(ssvid_6_hwtcl)                                               ;// String  : 16'b0;
localparam [15:0]ssid_6                                    = ssid_6_hwtcl   [15:0]                                                     ;//int2_16b(ssid_6_hwtcl)                                                ;// String  : 16'b0;

localparam bridge_port_vga_enable_6                        = bridge_port_vga_enable_6_hwtcl                                      ;// String  : "false";
localparam bridge_port_ssid_support_6                      = bridge_port_ssid_support_6_hwtcl                                    ;// String  : "false";

localparam flr_capability_6                                = (flr_capability_6_hwtcl==1)?"true":"false"                          ;// String  : "true";
localparam disable_snoop_packet_6                          = disable_snoop_packet_6_hwtcl                                        ;// String  : "false";

   //----------------------------------------

   // Function 7

localparam [15:0] vendor_id_7                              = vendor_id_7_hwtcl          [15:0]                                          ;//int2_16b(vendor_id_7_hwtcl)                                           ;// integer : 16'b1000101110010;
localparam [15:0] device_id_7                              = device_id_7_hwtcl          [15:0]                                          ;//int2_16b(device_id_7_hwtcl)                                           ;// integer : 16'b1;
localparam [ 7:0] revision_id_7                            = revision_id_7_hwtcl        [ 7:0]                                          ; //int2_8b(revision_id_7_hwtcl)                                          ;// integer : 8'b1;
localparam [23:0] class_code_7                             = class_code_7_hwtcl         [23:0]                                          ;//int2_24b(class_code_7_hwtcl)                                          ;// integer : 24'b111111110000000000000000;
localparam [15:0] subsystem_vendor_id_7                    = subsystem_vendor_id_7_hwtcl[15:0] ;//int2_16b(subsystem_vendor_id_7_hwtcl)                                 ;// integer : 16'b1000101110010;
localparam [15:0] subsystem_device_id_7                    = subsystem_device_id_7_hwtcl[15:0] ;//int2_16b(subsystem_device_id_7_hwtcl)                                 ;// integer : 16'b1;

localparam [63:0] bar01_size_mask_7                        = get_bar_size_mask((bar0_64bit_mem_space_7_hwtcl=="Enabled")?1:0,bar0_size_mask_7_hwtcl, bar1_size_mask_7_hwtcl) ;
localparam bar0_io_space_7                                 = (bar0_io_space_7_hwtcl        == "Enabled")?"true":"false"            ;// String  : "false";
localparam bar0_64bit_mem_space_7                          = (bar0_64bit_mem_space_7_hwtcl == "Enabled")?"true":"false"            ;// String  : "true";
localparam bar0_prefetchable_7                             = (bar0_prefetchable_7_hwtcl    == "Enabled")?"true":"false"            ;// String  : "true";
localparam [27:0] bar0_size_mask_7                         = bar01_size_mask_7[31:4]                                               ;// Bit vector
localparam bar1_io_space_64_7                              = (bar01_size_mask_7[32]==1'b1)?"true":"false";
localparam bar1_64bit_mem_space_64_7                       = (bar01_size_mask_7[34:33]==2'b11)?"all_one":(bar01_size_mask_7[34:33]==2'b10)?"true":"false";
localparam bar1_prefetchable_64_7                          = (bar01_size_mask_7[35]==1'b1)?"true":"false";
localparam bar1_io_space_7                                 = (bar0_64bit_mem_space_7_hwtcl == "Enabled")? bar1_io_space_64_7       : (bar1_io_space_7_hwtcl        == "Enabled")?"true":"false";// String  : "false";
localparam bar1_64bit_mem_space_7                          = (bar0_64bit_mem_space_7_hwtcl == "Enabled")? bar1_64bit_mem_space_64_7:                                                  "false";// String  : "false";
localparam bar1_prefetchable_7                             = (bar0_64bit_mem_space_7_hwtcl == "Enabled")? bar1_prefetchable_64_7   : (bar1_prefetchable_7_hwtcl    == "Enabled")?"true":"false";// String  : "false";
localparam [27:0] bar1_size_mask_7                         = bar01_size_mask_7[63:36]                                              ;// String  : "N/A";
localparam [63:0] bar23_size_mask_7                        = get_bar_size_mask((bar2_64bit_mem_space_7_hwtcl=="Enabled")?1:0,bar2_size_mask_7_hwtcl, bar3_size_mask_7_hwtcl) ;
localparam bar2_io_space_7                                 = (bar2_io_space_7_hwtcl        == "Enabled")?"true":"false"            ;// String  : "false";
localparam bar2_64bit_mem_space_7                          = (bar2_64bit_mem_space_7_hwtcl == "Enabled")?"true":"false"            ;// String  : "true";
localparam bar2_prefetchable_7                             = (bar2_prefetchable_7_hwtcl    == "Enabled")?"true":"false"            ;// String  : "true";
localparam [27:0] bar2_size_mask_7                         = bar23_size_mask_7[31:4]                                               ;// Bit vector
localparam bar3_io_space_64_7                              = (bar23_size_mask_7[32]==1'b1)?"true":"false";
localparam bar3_64bit_mem_space_64_7                       = (bar23_size_mask_7[34:33]==2'b11)?"all_one":(bar23_size_mask_7[34:33]==2'b10)?"true":"false";
localparam bar3_prefetchable_64_7                          = (bar23_size_mask_7[35]==1'b1)?"true":"false";
localparam bar3_io_space_7                                 = (bar2_64bit_mem_space_7_hwtcl == "Enabled")? bar3_io_space_64_7       : (bar3_io_space_7_hwtcl        == "Enabled")?"true":"false";// String  : "false";
localparam bar3_64bit_mem_space_7                          = (bar2_64bit_mem_space_7_hwtcl == "Enabled")? bar3_64bit_mem_space_64_7:                                                  "false";// String  : "false";
localparam bar3_prefetchable_7                             = (bar2_64bit_mem_space_7_hwtcl == "Enabled")? bar3_prefetchable_64_7   : (bar3_prefetchable_7_hwtcl    == "Enabled")?"true":"false";// String  : "false";
localparam [27:0] bar3_size_mask_7                         = bar23_size_mask_7[63:36]                                              ;// String  : "N/A";
localparam [63:0] bar45_size_mask_7                        = get_bar_size_mask((bar4_64bit_mem_space_7_hwtcl=="Enabled")?1:0,bar4_size_mask_7_hwtcl, bar5_size_mask_7_hwtcl) ;
localparam bar4_io_space_7                                 = (bar4_io_space_7_hwtcl        == "Enabled")?"true":"false"            ;// String  : "false";
localparam bar4_64bit_mem_space_7                          = (bar4_64bit_mem_space_7_hwtcl == "Enabled")?"true":"false"            ;// String  : "true";
localparam bar4_prefetchable_7                             = (bar4_prefetchable_7_hwtcl    == "Enabled")?"true":"false"            ;// String  : "true";
localparam [27:0] bar4_size_mask_7                         = bar45_size_mask_7[31:4]                                               ;// Bit vector
localparam bar5_io_space_64_7                              = (bar45_size_mask_7[32]==1'b1)?"true":"false";
localparam bar5_64bit_mem_space_64_7                       = (bar45_size_mask_7[34:33]==2'b11)?"all_one":(bar45_size_mask_7[34:33]==2'b10)?"true":"false";
localparam bar5_prefetchable_64_7                          = (bar45_size_mask_7[35]==1'b1)?"true":"false";
localparam bar5_io_space_7                                 = (bar4_64bit_mem_space_7_hwtcl == "Enabled")? bar5_io_space_64_7       : (bar5_io_space_7_hwtcl        == "Enabled")?"true":"false";// String  : "false";
localparam bar5_64bit_mem_space_7                          = (bar4_64bit_mem_space_7_hwtcl == "Enabled")? bar5_64bit_mem_space_64_7:                                                  "false";// String  : "false";
localparam bar5_prefetchable_7                             = (bar4_64bit_mem_space_7_hwtcl == "Enabled")? bar5_prefetchable_64_7   : (bar5_prefetchable_7_hwtcl    == "Enabled")?"true":"false";// String  : "false";
localparam [27:0] bar5_size_mask_7                         = bar45_size_mask_7[63:36]                                              ;// String  : "N/A";

localparam [31:0] expansion_base_address_register_7        = get_expansion_base_addr_mask(expansion_base_address_register_7_hwtcl) ;

localparam msi_multi_message_capable_7                     = (msi_multi_message_capable_7_hwtcl=="1")?"count_1":
                                                             (msi_multi_message_capable_7_hwtcl=="2")?"count_2":
                                                             (msi_multi_message_capable_7_hwtcl=="4")?"count_4":
                                                             (msi_multi_message_capable_7_hwtcl=="8")?"count_8":
                                                             (msi_multi_message_capable_7_hwtcl=="16")?"count_16":"count_32"       ;// String  : "count_4";
localparam msi_64bit_addressing_capable_7                  = msi_64bit_addressing_capable_7_hwtcl                                ;// String  : "true";
localparam msi_masking_capable_7                           = msi_masking_capable_7_hwtcl                                         ;// String  : "false";
localparam msi_support_7                                   = msi_support_7_hwtcl                                                 ;// String  : "true";
localparam interrupt_pin_7                                 = interrupt_pin_7_hwtcl                                               ;// String  : "inta";
localparam enable_function_msix_support_7                  = (enable_function_msix_support_7_hwtcl==1)?"true":"false"            ;// String  : "true";
localparam [10:0]msix_table_size_7                         = msix_table_size_7_hwtcl                    [10:0]                   ;//int2_11b(msix_table_size_7_hwtcl)                                     ;// Integer : 11'b0;
localparam [ 2:0]msix_table_bir_7                          = msix_table_bir_7_hwtcl                     [ 2:0]                   ;//int2_3b(msix_table_bir_7_hwtcl)                                       ;// Integer : 3'b0;
localparam [28:0]msix_table_offset_7                       = str2int(msix_table_offset_7_hwtcl) >> 3                             ;//int2_29b(msix_table_offset_7_hwtcl)                                   ;// Integer : 29'b0;
localparam [ 2:0]msix_pba_bir_7                            = msix_pba_bir_7_hwtcl                       [ 2:0]                   ;//int2_3b(msix_pba_bir_7_hwtcl)                                         ;// Integer : 3'b0;
localparam [28:0]msix_pba_offset_7                         = str2int(msix_pba_offset_7_hwtcl) >> 3                               ;//int2_29b(msix_pba_offset_7_hwtcl)                                     ;// Integer : 29'b0;

localparam use_aer_7                                       = (use_aer_7_hwtcl==1)?"true":"false"                                 ;// String  : "false";
localparam ecrc_check_capable_7                            = (ecrc_check_capable_7_hwtcl==1)?"true":"false"                      ;// String  : "true";
localparam ecrc_gen_capable_7                              = (ecrc_gen_capable_7_hwtcl  ==1)?"true":"false"                      ;// String  : "true";

localparam [1:0] slot_power_scale_7                        = slot_power_scale_7_hwtcl  [1:0]                                           ;//int2_2b(slot_power_scale_7_hwtcl)                                     ;// Integer : 2'b0;
localparam [7:0] slot_power_limit_7                        = slot_power_limit_7_hwtcl  [7:0]                                           ;//int2_8b(slot_power_limit_7_hwtcl)                                     ;// Integer : 8'b0;
localparam [12:0] slot_number_7                            = slot_number_7_hwtcl       [12:0]                                          ;//int2_13b(slot_number_7_hwtcl)                                         ;// Integer : 13'b0;

localparam max_payload_size_7                              = (max_payload_size_7_hwtcl==128 )?"payload_128":
                                                             (max_payload_size_7_hwtcl==256 )?"payload_256":
                                                             (max_payload_size_7_hwtcl==512 )?"payload_512":"payload_512"        ;// String  : "payload_512";
localparam extend_tag_field_7                              = (extend_tag_field_7_hwtcl=="32")?"false":"true"                     ;// String  : "false";
localparam completion_timeout_7                            = completion_timeout_7_hwtcl                                          ;// String  : "abcd";
localparam enable_completion_timeout_disable_7             = (enable_completion_timeout_disable_7_hwtcl==1)?"true":"false"       ;// String  : "true";

localparam surprise_down_error_support_7                   = (surprise_down_error_support_7_hwtcl==1)?"true":"false"             ;// String  : "false";
localparam dll_active_report_support_7                     = (dll_active_report_support_7_hwtcl  ==1)?"true":"false"             ;// String  : "false";

localparam rx_ei_l0s_7                                     = (rx_ei_l0s_7_hwtcl==0)?"disable":"enable"                           ;// String  : "disable";
localparam [2:0] endpoint_l0_latency_7                     = endpoint_l0_latency_7_hwtcl     [2:0]                               ;//int2_3b(endpoint_l0_latency_7_hwtcl)                                  ;// Integer : 3'b0;
localparam [2:0] endpoint_l1_latency_7                     = endpoint_l1_latency_7_hwtcl     [2:0]                               ;//int2_3b(endpoint_l1_latency_7_hwtcl)                                  ;// Integer : 3'b0;
localparam [2:0] maximum_current_7                         = maximum_current_7_hwtcl         [2:0]                               ;//int2_3b(maximum_current_7_hwtcl)                                      ;// integer : 3'b0;
localparam device_specific_init_7                          = (device_specific_init_7_hwtcl=="disable")?"false":"true"                                        ;// String  : "false"

localparam [15:0]ssvid_7                                   = ssvid_7_hwtcl  [15:0]                                               ;//int2_16b(ssvid_7_hwtcl)                                               ;// String  : 16'b0;
localparam [15:0]ssid_7                                    = ssid_7_hwtcl   [15:0]                                               ;//int2_16b(ssid_7_hwtcl)                                                ;// String  : 16'b0;

localparam bridge_port_vga_enable_7                        = bridge_port_vga_enable_7_hwtcl                                      ;// String  : "false";
localparam bridge_port_ssid_support_7                      = bridge_port_ssid_support_7_hwtcl                                    ;// String  : "false";

localparam flr_capability_7                                = (flr_capability_7_hwtcl==1)?"true":"false"                          ;// String  : "true";
localparam disable_snoop_packet_7                          = disable_snoop_packet_7_hwtcl                                        ;// String  : "false";

   //----------------------------------------

localparam io_window_addr_width                          = (io_window_addr_width_hwtcl==1)?"window_16_bit":(io_window_addr_width_hwtcl==2)?"window_32_bit":"none";// String  : "window_32_bit";
localparam prefetchable_mem_window_addr_width            = (prefetchable_mem_window_addr_width_hwtcl==0)?"prefetch_0":(prefetchable_mem_window_addr_width_hwtcl==2)?"prefetch_64":"prefetch_32";// String  : "prefetch_32";
localparam [3 :0]tx_cdc_almost_empty                     = tx_cdc_almost_empty_hwtcl                           [3 :0]                ;//int2_4b(tx_cdc_almost_empty_hwtcl)                                  ;// Integer : 4'b101;
localparam [3 :0]rx_cdc_almost_full                      = rx_cdc_almost_full_hwtcl                            [3 :0]                ;//int2_4b(rx_cdc_almost_full_hwtcl)                                   ;// Integer : 4'b1100;
localparam [3 :0]tx_cdc_almost_full                      = tx_cdc_almost_full_hwtcl                            [3 :0]                ;//int2_4b(tx_cdc_almost_full_hwtcl)                                   ;// Integer : 4'b1100;
localparam [7 :0]rx_l0s_count_idl                        = rx_l0s_count_idl_hwtcl                              [7 :0]                ;//int2_8b(rx_l0s_count_idl_hwtcl)                                     ;// Integer : 8'b0;
localparam [3 :0]cdc_dummy_insert_limit                  = cdc_dummy_insert_limit_hwtcl                        [3 :0]                ;//int2_4b(cdc_dummy_insert_limit_hwtcl)                               ;// Integer : 4'b1011;
localparam [7 :0]ei_delay_powerdown_count                = ei_delay_powerdown_count_hwtcl                      [7 :0]                ;//int2_8b(ei_delay_powerdown_count_hwtcl)                             ;// Integer : 8'b1010;
localparam [19:0]millisecond_cycle_count                 = millisecond_cycle_count_hwtcl                       [19:0]                ;//int2_20b(millisecond_cycle_count_hwtcl)                             ;// Integer : 20'b0;
localparam [10:0]skp_os_schedule_count                   = skp_os_schedule_count_hwtcl                         [10:0]                ;//int2_11b(skp_os_schedule_count_hwtcl)                               ;// Integer : 11'b0;
localparam [10:0]fc_init_timer                           = fc_init_timer_hwtcl                                 [10:0]                ;//int2_11b(fc_init_timer_hwtcl)                                       ;// Integer : 11'b10000000000;
localparam [4 :0]l01_entry_latency                       = l01_entry_latency_hwtcl                             [4 :0]                ;//int2_5b(l01_entry_latency_hwtcl)                                    ;// Integer : 5'b11111;
localparam [4 :0]flow_control_update_count               = flow_control_update_count_hwtcl                     [4 :0]                ;//int2_5b(flow_control_update_count_hwtcl)                            ;// Integer : 5'b11110;
localparam [7 :0]flow_control_timeout_count              = flow_control_timeout_count_hwtcl                    [7 :0]                ;//int2_8b(flow_control_timeout_count_hwtcl)                           ;// Integer : 8'b11001000;

localparam [ 7:0]retry_buffer_last_active_address        = retry_buffer_last_active_address_hwtcl              [ 7:0]               ;//int2_8b(retry_buffer_last_active_address_hwtcl)                    ;// Integer : 11'b11111111111;
localparam [15:0] retry_buffer_memory_settings           = 16'b0000000000000110                                                     ;
localparam [15:0] vc0_rx_buffer_memory_settings          = 16'b0000000000000110                                                     ;
// Credit Allocation
localparam credit_buffer_allocation_aux                  = (low_str(credit_buffer_allocation_aux_hwtcl)=="balanced")   ?"balanced":
                                                           (low_str(credit_buffer_allocation_aux_hwtcl)=="target")     ?"target":
                                                           (low_str(credit_buffer_allocation_aux_hwtcl)=="initiator")  ?"initiator":"absolute";
localparam [7:0]  vc0_rx_flow_ctrl_posted_header         = vc0_rx_flow_ctrl_posted_header_hwtcl                     [7:0]  ;//int2_8b(vc0_rx_flow_ctrl_posted_header_hwtcl)                       ;// Integer : 8'b110010;
localparam [11:0] vc0_rx_flow_ctrl_posted_data           = vc0_rx_flow_ctrl_posted_data_hwtcl                       [11:0] ;//int2_12b(vc0_rx_flow_ctrl_posted_data_hwtcl)                        ;// Integer : 12'b101101000;
localparam [7:0]  vc0_rx_flow_ctrl_nonposted_header      = vc0_rx_flow_ctrl_nonposted_header_hwtcl                  [7:0]  ;//int2_8b(vc0_rx_flow_ctrl_nonposted_header_hwtcl)                    ;// Integer : 8'b110110;
localparam [7:0]  vc0_rx_flow_ctrl_nonposted_data        = vc0_rx_flow_ctrl_nonposted_data_hwtcl                    [7:0]  ;//int2_8b(vc0_rx_flow_ctrl_nonposted_data_hwtcl)                      ;// Integer : 8'b0;
localparam [7:0]  vc0_rx_flow_ctrl_compl_header          = vc0_rx_flow_ctrl_compl_header_hwtcl                      [7:0]  ;//int2_8b(vc0_rx_flow_ctrl_compl_header_hwtcl)                        ;// Integer : 8'b1110000;
localparam [11:0] vc0_rx_flow_ctrl_compl_data            = vc0_rx_flow_ctrl_compl_data_hwtcl                        [11:0] ;//int2_12b(vc0_rx_flow_ctrl_compl_data_hwtcl)                         ;// Integer : 12'b111000000;
localparam [39:0] k_ptr                                  = calc_k_ptr_av({ vc0_rx_flow_ctrl_compl_data      ,
                                                                           vc0_rx_flow_ctrl_compl_header    ,
                                                                           vc0_rx_flow_ctrl_nonposted_data  ,
                                                                           vc0_rx_flow_ctrl_nonposted_header,
                                                                           vc0_rx_flow_ctrl_posted_data     ,
                                                                           vc0_rx_flow_ctrl_posted_header   });
localparam [9:0] rx_ptr0_posted_dpram_min               = k_ptr[9:0];
localparam [9:0] rx_ptr0_posted_dpram_max               = k_ptr[19:10];
localparam [9:0] rx_ptr0_nonposted_dpram_min            = k_ptr[29:20];
localparam [9:0] rx_ptr0_nonposted_dpram_max            = k_ptr[39:30];

// Not visible parameters
localparam pcie_mode                       = (multi_function=="one_func") ? porttype_func0  : "ep_native";
//localparam rx_sop_ctrl                                   = (low_str(ast_width)=="rx_tx_256")? "boundary_256":(low_str(ast_width)=="rx_tx_128")?"boundary_128":"boundary_64";// String  : "boundary_64";
localparam [74:0] bist_memory_settings     =  75'h0;
localparam        iei_enable_settings      =  "gen2_infei_infsd_gen1_infei_sd";
localparam [15:0] vsec_id                  =  vsec_id_hwtcl ; //16'b0001000101110010;
localparam        cvp_rate_sel             =  cvp_rate_sel_hwtcl;
localparam        hard_reset_bypass        =  (hip_hard_reset_hwtcl==0)? "true" : "false";
localparam        cvp_data_compressed      =  cvp_data_compressed_hwtcl;
localparam        cvp_data_encrypted       =  cvp_data_encrypted_hwtcl ;
localparam        cvp_mode_reset           =  cvp_mode_reset_hwtcl     ;
localparam        cvp_clk_reset            =  cvp_clk_reset_hwtcl      ;
localparam        cvp_enable               =  (ALTPCIE_AV_HIP_AST_HWTCL_SIM_ONLY==1) ? "cvp_dis" : (in_cvp_mode_hwtcl==0)? "cvp_dis" : "cvp_en";
localparam        hip_hard_reset           =  (hip_hard_reset_hwtcl==0)? "disable" : "enable";

localparam         MEM_CHECK=0;
localparam         USE_INTERNAL_250MHZ_PLL = 1;
localparam         disable_clk_switch = "disable";
localparam         port_type_hwtcl = porttype_func0_hwtcl; //TODO Add Multifunction support
localparam         slotclk_cfg = "dynamic_slotclkcfg";
localparam [3:0]   vsec_cap               = vsec_rev_hwtcl ;//4'h0;
localparam [127:0] jtag_id                = 128'h0;
localparam [15:0]  user_id                = user_id_hwtcl ;//16'h0;
localparam         disable_auto_crs       = "disable";
localparam [7:0]   tx_swing_data          = 8'h0;

//Pre-emphasis and VOD values
localparam [5:0] rpre_emph_a_val = rpre_emph_a_val_hwtcl[5:0];
localparam [5:0] rpre_emph_b_val = rpre_emph_b_val_hwtcl[5:0];
localparam [5:0] rpre_emph_c_val = rpre_emph_c_val_hwtcl[5:0];
localparam [5:0] rpre_emph_d_val = rpre_emph_d_val_hwtcl[5:0];
localparam [5:0] rpre_emph_e_val = rpre_emph_e_val_hwtcl[5:0];
localparam [5:0] rvod_sel_a_val  = rvod_sel_a_val_hwtcl [5:0];
localparam [5:0] rvod_sel_b_val  = rvod_sel_b_val_hwtcl [5:0];
localparam [5:0] rvod_sel_c_val  = rvod_sel_c_val_hwtcl [5:0];
localparam [5:0] rvod_sel_d_val  = rvod_sel_d_val_hwtcl [5:0];
localparam [5:0] rvod_sel_e_val  = rvod_sel_e_val_hwtcl [5:0];

// Input for internal test port (PE/TE)
wire                 vdd_scanenn            = 1'b1;

wire                 gnd_bistscanenn        = 1'b0;
wire                 gnd_bistscanin         = 1'b0;
wire                 gnd_bisttestenn        = 1'b0;
wire                 gnd_scanmoden          = 1'b0;
wire                 gnd_dl_comclk_reg      = 1'b0;
wire  [12: 0]        gnd_dl_ctrl_link2      = 13'h0;
wire  [7 : 0]        gnd_dl_vc_ctrl         = 8'h0;
wire                 gnd_dpriorefclkdig     = 1'b0;
wire                 gnd_mdio_clk           = 1'b0;
wire  [1:0]          gnd_mdio_dev_addr      = 2'h0;
wire                 gnd_mdio_in            = 1'b0;
wire                 gnd_cbhipmdioen        = 1'b0;
wire  [15:0]         gnd_pci_err            = 16'h0;
wire                 gnd_hipextraclkin      = 1'b0;
wire                 gnd_hipextrain         = 30'h0;
wire [14:0]          gnd_dbgpipex1rx        = 15'h0;


wire [1 :0]        tx_st_eop_vc0_int;
wire [1 :0]        tx_st_sop_vc0_int;
wire [127 : 0]     tx_st_data_vc0_int;
wire [127 : 0]     rx_st_data_vc0_int;
wire [15 : 0]      rx_be_vc0_int;
wire [1 : 0]       rx_st_sop_vc0_int;
wire               rx_st_valid_vc0_int;
wire [1 : 0]       rx_st_eop_vc0_int;

wire  [1 : 0]        mode;

wire open_flr_sts;
wire open_r2c_err_ext;
wire open_successful_speed_negotiation_int;
wire open_swdn_wake;
wire open_swup_hotrst;
wire open_mdio_oen_n;
wire open_mdio_out;
wire open_hipextraclkout;
wire open_hipextraout;


// Internal wire for internal test port (PE/TE)
wire         open_bistdonearcv0;
wire         open_bistdonearcv1;
wire         open_bistdonearpl;
wire         open_bistdonebrcv0;
wire         open_bistdonebrcv1;
wire         open_bistdonebrpl;
wire         open_bistpassrcv0;
wire         open_bistpassrcv1;
wire         open_bistpassrpl;
wire         open_bistscanoutrcv0;
wire         open_bistscanoutrcv1;
wire         open_bistscanoutrpl;
wire         open_wakeoen;
wire [35:0]  open_tx_cred_vc0;
wire         open_ltssml0state;
wire [63:0]  testout;
wire [63:0]  testin;

wire         simu_mode_pipe_tb;
wire [7:0]   cpl_pending_int;
wire [clogb2(MAX_NUM_FUNC_SUPPORT)+11:0] lmi_addr_int;
wire [6:0]   tl_cfg_add_int;
wire [122:0] tl_cfg_sts_int;

wire [7:0]   tl_app_int_sts_vec_int;
wire [2:0] tl_app_intb_funcnum;
wire tl_app_intb_sts;
wire [2:0] tl_app_inta_funcnum;
wire tl_app_inta_sts;

wire reset_status_int;
wire [1:0] current_speed_int;
wire [31:0] test_in_int;

initial begin
   $display("%s Hard IP for PCI Express %s", device_family, ACDS_VERSION_HWTCL);
end

// Since DCD Calibration IP is done during recovery speed, force test_out to have PIPE signals during recovery speed.
// Also, force current_speed to use pipe rate during recovery speed so we know when to run DCD calibration IP
assign test_in_int = (dl_ltssm == 5'h1A) ? {test_in[31:12],4'b0011,test_in[7:0]} : test_in;
assign dl_current_speed = (dl_ltssm == 5'h1A)? {testout[30], ~testout[30]} : current_speed_int;

always @(posedge pld_clk or negedge npor) begin
   if (!npor) begin
      reset_status <= 1'b1;
   end
   else if (!reset_status_int) begin
      reset_status <= 1'b0;
   end
   else begin
      reset_status <= 1'b1;
   end
end

assign mode = (port_type_hwtcl=="Native endpoint")?2'b00:2'b10;

generate begin : g_tl_app_int_sts_vec
   if (num_of_func_hwtcl==1) begin
      assign tl_app_int_sts_vec_int = {7'h0, app_int_sts_vec};
   end
   else begin
      assign tl_app_int_sts_vec_int = app_int_sts_vec;
   end
end
endgenerate

assign tl_app_intb_funcnum = tl_app_int_sts_vec_int[7:5];
assign tl_app_intb_sts     = tl_app_int_sts_vec_int[4];
assign tl_app_inta_funcnum = tl_app_int_sts_vec_int[3:1];
assign tl_app_inta_sts     = tl_app_int_sts_vec_int[0];

assign rx_st_be      = rx_be_vc0_int[(port_width_data_hwtcl/8)-1:0];
assign rx_st_data    = rx_st_data_vc0_int[port_width_data_hwtcl-1 :0];
assign rx_st_sop     = rx_st_sop_vc0_int[0];

generate begin : g_rx_st_eop_empty_vc0
   if (ast_width=="rx_tx_128") begin
      assign rx_st_empty   = rx_st_eop_vc0_int[0];
      assign rx_st_eop     = rx_st_eop_vc0_int[1];
   end
   else begin
      assign rx_st_eop     = rx_st_eop_vc0_int[0];
   end
end
endgenerate

assign tl_cfg_add = tl_cfg_add_int[addr_width_delta(num_of_func_hwtcl)+3:0];

assign tl_cfg_sts = tl_cfg_sts_int[((num_of_func_hwtcl-1)*10)+52:0];

generate begin : g_lmi_addr
   if (num_of_func_hwtcl==1) begin
      assign lmi_addr_int = {{clogb2(MAX_NUM_FUNC_SUPPORT){1'b0}}, lmi_addr};
   end
   else begin
      assign lmi_addr_int = lmi_addr;
   end
end
endgenerate

generate begin : g_cpl_pending
   if (num_of_func_hwtcl==1) begin
      assign cpl_pending_int = { 7'h0, cpl_pending};
   end
   else begin
      assign cpl_pending_int = cpl_pending;
   end
end
endgenerate

assign tx_st_sop_vc0_int    = {1'h0, tx_st_sop};

generate begin : g_tx_data
   if (ast_width=="rx_tx_128") begin
      assign tx_st_data_vc0_int   = tx_st_data;
      assign tx_st_eop_vc0_int[0] = tx_st_empty;
      assign tx_st_eop_vc0_int[1] = tx_st_eop;
   end
   else begin
      assign tx_st_data_vc0_int   = {64'h0,tx_st_data};
      assign tx_st_eop_vc0_int    = {1'h0, tx_st_eop};
   end
end
endgenerate

//por Reset Synchronizer on pld_clk
assign testin_zero         = test_in[0];
assign sim_ltssmstate      = dl_ltssm;
assign sim_pipe_pclk_out   = sim_pipe_pclk_in;
assign ko_cpl_spc_header[7 :0] = cpl_spc_header_hwtcl;//int2_8b(cpl_spc_header_hwtcl);
assign ko_cpl_spc_data [11 :0] = cpl_spc_data_hwtcl;//int2_12b(cpl_spc_data_hwtcl);
assign sim_pipe_rate[1]        = 1'b0;

altpcie_av_hip_128bit_atom # (
      .MEM_CHECK                                 (MEM_CHECK                                 ),      //parameter          MEM_CHECK                                 = 0,                                             //.MEM_CHECK                                                     (MEM_CHECK                                                     ),
      .USE_INTERNAL_250MHZ_PLL                   (USE_INTERNAL_250MHZ_PLL                   ),      //parameter          USE_INTERNAL_250MHZ_PLL                   = 1,                                             //.USE_INTERNAL_250MHZ_PLL                                       (USE_INTERNAL_250MHZ_PLL                                       ),
      .device_family                             (device_family                             ),
      .pll_refclk_freq                           (pll_refclk_freq                           ),      //parameter          pll_refclk_freq                           = "100 MHz", //legal value = "100 MHz", "125 MHz"//.coreclkout_hip_phaseshift                                     (coreclkout_hip_phaseshift                                     ),
      .set_pld_clk_x1_625MHz                     (set_pld_clk_x1_625MHz_hwtcl               ),      //parameter          set_pld_clk_x1_625MHz                     = 0,                                             //.pldclk_hip_phase_shift                                        (pldclk_hip_phase_shift                                        ),
      .reconfig_to_xcvr_width                    (reconfig_to_xcvr_width                    ),      //parameter          reconfig_to_xcvr_width                    = 350,                                           //.pll_refclk_freq                                               (pll_refclk_freq                                               ),
      .reconfig_from_xcvr_width                  (reconfig_from_xcvr_width                  ),      //parameter          reconfig_from_xcvr_width                  = 230,                                           //.set_pld_clk_x1_625MHz                                         (set_pld_clk_x1_625MHz_hwtcl                                   ),
      .hip_reconfig                              (hip_reconfig_hwtcl                        ),      //                                                                                                              //.enable_slot_register                                          (enable_slot_register                                          ),
      .enable_slot_register                      (enable_slot_register                      ),      //parameter          enable_slot_register                      = "false",                                       //.pcie_mode                                                     (pcie_mode                                                     ),
      .pcie_mode                                 (pcie_mode                                 ),      //parameter          pcie_mode                                 = "shared_mode",                                 //.bypass_cdc                                                    (bypass_cdc                                                    ),
      .enable_rx_buffer_checking                 (enable_rx_buffer_checking                 ),      //parameter          enable_rx_buffer_checking                 = "false",                                       //.enable_rx_buffer_checking                                     (enable_rx_buffer_checking                                     ),
      .single_rx_detect                          (single_rx_detect                          ),      //parameter [3:0]    single_rx_detect                          = 4'b0,                                          //.single_rx_detect                                              (single_rx_detect                                              ),
      .use_crc_forwarding                        (use_crc_forwarding                        ),      //parameter          use_crc_forwarding                        = "false",                                       //.use_crc_forwarding                                            (use_crc_forwarding                                            ),
      .gen12_lane_rate_mode                      (gen12_lane_rate_mode                      ),      //parameter          gen12_lane_rate_mode                      = "gen1", // "gen1", "gen1_gen2"                 //.gen12_lane_rate_mode                                         (gen12_lane_rate_mode                                         ),
      .lane_mask                                 (lane_mask                                 ),      //parameter          lane_mask                                 = "x4",                                          //.lane_mask                                                     (lane_mask                                                     ),
      .multi_function                            (multi_function                            ),      //parameter          multi_function                            = "one_func",                                    //.disable_link_x2_support                                       (disable_link_x2_support                                       ),
      //.coreclkout_hip_phaseshift                 (coreclkout_hip_phaseshift               ),      //parameter          coreclkout_hip_phaseshift                 = "0 ps",                                        //.hip_hard_reset                                                (hip_hard_reset                                                ),
      //.pldclk_hip_phase_shift                    (pldclk_hip_phase_shift                  ),      //parameter          pldclk_hip_phase_shift                    = "0 ps",                                        //.dis_paritychk                                                 (dis_paritychk                                                 ),
      .disable_link_x2_support                   (disable_link_x2_support                   ),      //parameter          disable_link_x2_support                   = "false",                                       //.reconfig_to_xcvr_width                                        (reconfig_to_xcvr_width                                        ),
      .ast_width                                 (ast_width                                 ),      //parameter          ast_width                                 = "rx_tx_64",                                    //.reconfig_from_xcvr_width                                      (reconfig_from_xcvr_width                                      ),
                                                                                                                                                                                                                         //.wrong_device_id                                               (wrong_device_id                                               ),
      .port_link_number                          (port_link_number                          ),      //parameter [7:0]    port_link_number                          = 8'b1,                                          //.data_pack_rx                                                  (data_pack_rx                                                  ),
      .device_number                             (device_number                             ),      //parameter [4:0]    device_number                             = 5'b0,                                          //.ast_width                                                     (ast_width                                                     ),
      .bypass_clk_switch                         (bypass_clk_switch                         ),      //parameter          bypass_clk_switch                         = "disable",                                     //.rx_sop_ctrl                                                   (rx_sop_ctrl                                                   ),
      .disable_clk_switch                        (disable_clk_switch                        ),      //parameter          disable_clk_switch                        = "disable",                                     //.rx_ast_parity                                                 (rx_ast_parity                                                 ),
      .pipex1_debug_sel                          (pipex1_debug_sel                          ),      //parameter          pipex1_debug_sel                          = "disable",                                     //.tx_ast_parity                                                 (tx_ast_parity                                                 ),
      .pclk_out_sel                              (pclk_out_sel                              ),      //parameter          pclk_out_sel                              = "pclk",                                        //.ltssm_1ms_timeout                                             (ltssm_1ms_timeout                                             ),
      .use_tl_cfg_sync                           (use_tl_cfg_sync                           ),      //parameter          use_tl_cfg_sync                           = 0,                                        //.ltssm_1ms_timeout                                             (ltssm_1ms_timeout                                             ),
                                                                                                                                                                                                                         //.ltssm_freqlocked_check                                        (ltssm_freqlocked_check                                        ),
       //Multifunction related parameters                                                                                                                                                                                //.deskew_comma                                                  (deskew_comma                                                  ),
       //General/Common across functions                                                                                                                                                                                 //.port_link_number                                              (port_link_number                                              ),
      .porttype_func0                            (porttype_func0                            ),      //parameter          porttype_func0                            = "ep_native";                                   //.device_number                                                 (device_number                                                 ),
      .porttype_func1                            (porttype_func1                            ),      //parameter          porttype_func1                            = "ep_native";                                   //.bypass_clk_switch                                             (bypass_clk_switch                                             ),
      .porttype_func2                            (porttype_func2                            ),      //parameter          porttype_func2                            = "ep_native";                                   //.pipex1_debug_sel                                              (pipex1_debug_sel                                              ),
      .porttype_func3                            (porttype_func3                            ),      //parameter          porttype_func3                            = "ep_native";                                   //.pclk_out_sel                                                  (pclk_out_sel                                                  ),
      .porttype_func4                            (porttype_func4                            ),      //parameter          porttype_func4                            = "ep_native";                                   //.vendor_id                                                     (vendor_id                                                     ),
      .porttype_func5                            (porttype_func5                            ),      //parameter          porttype_func5                            = "ep_native";                                   //.device_id                                                     (device_id                                                     ),
      .porttype_func6                            (porttype_func6                            ),      //parameter          porttype_func6                            = "ep_native";                                   //.revision_id                                                   (revision_id                                                   ),
      .porttype_func7                            (porttype_func7                            ),      //parameter          porttype_func7                            = "ep_native";                                   //.class_code                                                    (class_code                                                    ),
                                                                                                                                                                                                                         //.subsystem_vendor_id                                           (subsystem_vendor_id                                           ),
      .eie_before_nfts_count                     (eie_before_nfts_count                     ),      //parameter [3:0]    eie_before_nfts_count                     = 4'b100,                                        //.subsystem_device_id                                           (subsystem_device_id                                           ),
      .gen2_diffclock_nfts_count                 (gen2_diffclock_nfts_count                 ),      //parameter [7:0]    gen2_diffclock_nfts_count                 = 8'b11111111,                                   //.no_soft_reset                                                 (no_soft_reset                                                 ),
      .gen2_sameclock_nfts_count                 (gen2_sameclock_nfts_count                 ),      //parameter [7:0]    gen2_sameclock_nfts_count                 = 8'b11111111,                                   //.maximum_current                                               (maximum_current                                               ),
                                                                                                                                                                                                                         //.d1_support                                                    (d1_support                                                    ),
      .slotclk_cfg                               (slotclk_cfg                               ),      //parameter          slotclk_cfg                               = "dynamic_slotclkcfg";                          //.d2_support                                                    (d2_support                                                    ),
      .aspm_optionality                          (aspm_optionality                          ),      //parameter          aspm_optionality                          = "true";                                        //.d0_pme                                                        (d0_pme                                                        ),
      .enable_l1_aspm                            (enable_l1_aspm                            ),      //parameter          enable_l1_aspm                            = "false",                                       //.d1_pme                                                        (d1_pme                                                        ),
      .enable_l0s_aspm                           (enable_l0s_aspm                           ),      //parameter          enable_l0s_aspm                            = "false",                                       //.d2_pme                                                        (d2_pme                                                        ),
      .l1_exit_latency_sameclock                 (l1_exit_latency_sameclock                 ),      //parameter [2:0]    l1_exit_latency_sameclock                 = 3'b0,                                          //.d3_hot_pme                                                    (d3_hot_pme                                                    ),
      .l1_exit_latency_diffclock                 (l1_exit_latency_diffclock                 ),      //parameter [2:0]    l1_exit_latency_diffclock                 = 3'b0,                                          //.d3_cold_pme                                                   (d3_cold_pme                                                   ),
      .l0_exit_latency_sameclock                 (l0_exit_latency_sameclock                 ),      //parameter [2:0]    l0_exit_latency_sameclock                 = 3'b110,                                        //.use_aer                                                       (use_aer                                                       ),
      .l0_exit_latency_diffclock                 (l0_exit_latency_diffclock                 ),      //parameter [2:0]    l0_exit_latency_diffclock                 = 3'b110,                                        //.low_priority_vc                                               (low_priority_vc                                               ),
      .io_window_addr_width                      (io_window_addr_width                      ),      //parameter          io_window_addr_width                      = "window_32_bit",                               //.disable_snoop_packet                                          (disable_snoop_packet                                          ),
      .prefetchable_mem_window_addr_width        (prefetchable_mem_window_addr_width        ),      //parameter          prefetchable_mem_window_addr_width        = "prefetch_32",                                 //.max_payload_size                                              (max_payload_size                                              ),
      .deemphasis_enable                         (deemphasis_enable                         ),      //parameter          deemphasis_enable                         = "false",                                       //.surprise_down_error_support                                   (surprise_down_error_support                                   ),
      .pcie_spec_version                         (pcie_spec_version                         ),      //parameter          pcie_spec_version                         = "v2",                                          //.dll_active_report_support                                     (dll_active_report_support                                     ),
                                                                                                                                                                                                                         //.extend_tag_field                                              (extend_tag_field                                              ),
       //Function 0                                                                                                                                                                                                      //.endpoint_l0_latency                                           (endpoint_l0_latency                                           ),
                                                                                                                                                                                                                         //.endpoint_l1_latency                                           (endpoint_l1_latency                                           ),
      .vendor_id_0                               (vendor_id_0                               ),      //parameter          vendor_id_0                               = 16'b0001000101110010,                          //.indicator                                                     (indicator                                                     ),
      .device_id_0                               (device_id_0                               ),      //parameter          device_id_0                               = 16'b1,                                         //.slot_power_scale                                              (slot_power_scale                                              ),
      .revision_id_0                             (revision_id_0                             ),      //parameter          revision_id_0                             = 8'b1,                                          //.max_link_width                                                (max_link_width                                                ),
      .class_code_0                              (class_code_0                              ),      //parameter          class_code_0                              = 24'b111111110000000000000000,                  //.enable_l0s_aspm                                               (enable_l0s_aspm                                               ),
      .subsystem_vendor_id_0                     (subsystem_vendor_id_0                     ),      //parameter          subsystem_vendor_id_0                     = 16'b0001000101110010,                          //.enable_l1_aspm                                                (enable_l1_aspm                                                ),
      .subsystem_device_id_0                     (subsystem_device_id_0                     ),      //parameter          subsystem_device_id_0                     = 16'b1,                                         //.l1_exit_latency_sameclock                                     (l1_exit_latency_sameclock                                     ),
                                                                                                                                                                                                                         //.l1_exit_latency_diffclock                                     (l1_exit_latency_diffclock                                     ),
      .bar0_io_space_0                           (bar0_io_space_0                           ),      //parameter          bar0_io_space_0                           = "false",                                       //.hot_plug_support                                              (hot_plug_support                                              ),
      .bar0_64bit_mem_space_0                    (bar0_64bit_mem_space_0                    ),      //parameter          bar0_64bit_mem_space_0                    = "true",                                        //.slot_power_limit                                              (slot_power_limit                                              ),
      .bar0_prefetchable_0                       (bar0_prefetchable_0                       ),      //parameter          bar0_prefetchable_0                       = "true",                                        //.slot_number                                                   (slot_number                                                   ),
      .bar0_size_mask_0                          (bar0_size_mask_0                          ),      //parameter [27:0]   bar0_size_mask_0                          = 28'b1111111111111111111111111111,              //.diffclock_nfts_count                                          (diffclock_nfts_count                                          ),
      .bar1_io_space_0                           (bar1_io_space_0                           ),      //parameter          bar1_io_space_0                           = "false",                                       //.sameclock_nfts_count                                          (sameclock_nfts_count                                          ),
      .bar1_64bit_mem_space_0                    (bar1_64bit_mem_space_0                    ),      //parameter          bar1_64bit_mem_space_0                    = "false",                                       //.completion_timeout                                            (completion_timeout                                            ),
      .bar1_prefetchable_0                       (bar1_prefetchable_0                       ),      //parameter          bar1_prefetchable_0                       = "false",                                       //.enable_completion_timeout_disable                             (enable_completion_timeout_disable                             ),
      .bar1_size_mask_0                          (bar1_size_mask_0                          ),      //parameter [27:0]   bar1_size_mask_0                          = 28'b0,                                         //.extended_tag_reset                                            (extended_tag_reset                                            ),
      .bar2_io_space_0                           (bar2_io_space_0                           ),      //parameter          bar2_io_space_0                           = "false",                                       //.ecrc_check_capable                                            (ecrc_check_capable                                            ),
      .bar2_64bit_mem_space_0                    (bar2_64bit_mem_space_0                    ),      //parameter          bar2_64bit_mem_space_0                    = "false",                                       //.ecrc_gen_capable                                              (ecrc_gen_capable                                              ),
      .bar2_prefetchable_0                       (bar2_prefetchable_0                       ),      //parameter          bar2_prefetchable_0                       = "false",                                       //.no_command_completed                                          (no_command_completed                                          ),
      .bar2_size_mask_0                          (bar2_size_mask_0                          ),      //parameter [27:0]   bar2_size_mask_0                          = 28'b0,                                         //.msi_multi_message_capable                                     (msi_multi_message_capable                                     ),
      .bar3_io_space_0                           (bar3_io_space_0                           ),      //parameter          bar3_io_space_0                           = "false",                                       //.msi_64bit_addressing_capable                                  (msi_64bit_addressing_capable                                  ),
      .bar3_64bit_mem_space_0                    (bar3_64bit_mem_space_0                    ),      //parameter          bar3_64bit_mem_space_0                    = "false",                                       //.msi_masking_capable                                           (msi_masking_capable                                           ),
      .bar3_prefetchable_0                       (bar3_prefetchable_0                       ),      //parameter          bar3_prefetchable_0                       = "false",                                       //.msi_support                                                   (msi_support                                                   ),
      .bar3_size_mask_0                          (bar3_size_mask_0                          ),      //parameter [27:0]   bar3_size_mask_0                          = 28'b0,                                         //.interrupt_pin                                                 (interrupt_pin                                                 ),
      .bar4_io_space_0                           (bar4_io_space_0                           ),      //parameter          bar4_io_space_0                           = "false",                                       //.enable_function_msix_support                                  (enable_function_msix_support                                  ),
      .bar4_64bit_mem_space_0                    (bar4_64bit_mem_space_0                    ),      //parameter          bar4_64bit_mem_space_0                    = "false",                                       //.msix_table_size                                               (msix_table_size                                               ),
      .bar4_prefetchable_0                       (bar4_prefetchable_0                       ),      //parameter          bar4_prefetchable_0                       = "false",                                       //.msix_table_bir                                                (msix_table_bir                                                ),
      .bar4_size_mask_0                          (bar4_size_mask_0                          ),      //parameter [27:0]   bar4_size_mask_0                          = 28'b0,                                         //.msix_table_offset                                             (msix_table_offset                                             ),
      .bar5_io_space_0                           (bar5_io_space_0                           ),      //parameter          bar5_io_space_0                           = "false",                                       //.msix_pba_bir                                                  (msix_pba_bir                                                  ),
      .bar5_64bit_mem_space_0                    (bar5_64bit_mem_space_0                    ),      //parameter          bar5_64bit_mem_space_0                    = "false",                                       //.msix_pba_offset                                               (msix_pba_offset                                               ),
      .bar5_prefetchable_0                       (bar5_prefetchable_0                       ),      //parameter          bar5_prefetchable_0                       = "false",                                       //.bridge_port_vga_enable                                        (bridge_port_vga_enable                                        ),
      .bar5_size_mask_0                          (bar5_size_mask_0                          ),      //parameter [27:0]   bar5_size_mask_0                          = 28'b0,                                         //.bridge_port_ssid_support                                      (bridge_port_ssid_support                                      ),
                                                                                                                                                                                                                         //.ssvid                                                         (ssvid                                                         ),
      .msi_multi_message_capable_0               (msi_multi_message_capable_0               ),      //parameter          msi_multi_message_capable_0               = "count_4",                                     //.ssid                                                          (ssid                                                          ),
      .msi_64bit_addressing_capable_0            (msi_64bit_addressing_capable_0            ),      //parameter          msi_64bit_addressing_capable_0            = "true",                                        //.eie_before_nfts_count                                         (eie_before_nfts_count                                         ),
      .msi_masking_capable_0                     (msi_masking_capable_0                     ),      //parameter          msi_masking_capable_0                     = "false",                                       //.gen2_diffclock_nfts_count                                     (gen2_diffclock_nfts_count                                     ),
      .msi_support_0                             (msi_support_0                             ),      //parameter          msi_support_0                             = "true",                                        //.gen2_sameclock_nfts_count                                     (gen2_sameclock_nfts_count                                     ),
      .interrupt_pin_0                           (interrupt_pin_0                           ),      //parameter          interrupt_pin_0                           = "inta",                                        //.deemphasis_enable                                             (deemphasis_enable                                             ),
      .enable_function_msix_support_0            (enable_function_msix_support_0            ),      //parameter          enable_function_msix_support_0            = "true",                                        //.pcie_spec_version                                             (pcie_spec_version                                             ),
      .msix_table_size_0                         (msix_table_size_0                         ),      //parameter [10:0]   msix_table_size_0                         = 11'b0,                                         //.l0_exit_latency_sameclock                                     (l0_exit_latency_sameclock                                     ),
      .msix_table_bir_0                          (msix_table_bir_0                          ),      //parameter [2:0]    msix_table_bir_0                          = 3'b0,                                          //.l0_exit_latency_diffclock                                     (l0_exit_latency_diffclock                                     ),
      .msix_table_offset_0                       (msix_table_offset_0                       ),      //parameter [28:0]   msix_table_offset_0                       = 29'b0,                                         //.rx_ei_l0s                                                     (rx_ei_l0s                                                     ),
      .msix_pba_bir_0                            (msix_pba_bir_0                            ),      //parameter [2:0]    msix_pba_bir_0                            = 3'b0,                                          //.l2_async_logic                                                (l2_async_logic                                                ),
      .msix_pba_offset_0                         (msix_pba_offset_0                         ),      //parameter [28:0]   msix_pba_offset_0                         = 29'b0,                                         //.aspm_config_management                                        (aspm_config_management                                        ),
                                                                                                                                                                                                                         //.atomic_op_routing                                             (atomic_op_routing                                             ),
      .use_aer_0                                 (use_aer_0                                 ),      //parameter          use_aer_0                                 = "false",                                       //.atomic_op_completer_32bit                                     (atomic_op_completer_32bit                                     ),
      .ecrc_check_capable_0                      (ecrc_check_capable_0                      ),      //parameter          ecrc_check_capable_0                      = "true",                                        //.atomic_op_completer_64bit                                     (atomic_op_completer_64bit                                     ),
      .ecrc_gen_capable_0                        (ecrc_gen_capable_0                        ),      //parameter          ecrc_gen_capable_0                        = "true",                                        //.cas_completer_128bit                                          (cas_completer_128bit                                          ),
                                                                                                                                                                                                                         //.ltr_mechanism                                                 (ltr_mechanism                                                 ),
      .slot_power_scale_0                        (slot_power_scale_0                        ),
      .slot_power_limit_0                        (slot_power_limit_0                        ),
      .slot_number_0                             (slot_number_0                             ),

      .max_payload_size_0                        (max_payload_size_0                        ),      //parameter          max_payload_size_0                        = "payload_512",                                 //.tph_completer                                                 (tph_completer                                                 ),
      .extend_tag_field_0                        (extend_tag_field_0                        ),      //parameter          extend_tag_field_0                        = "false",                                       //.extended_format_field                                         (extended_format_field                                         ),
      .completion_timeout_0                      (completion_timeout_0                      ),      //parameter          completion_timeout_0                      = "abcd",                                        //.atomic_malformed                                              (atomic_malformed                                              ),
      .enable_completion_timeout_disable_0       (enable_completion_timeout_disable_0       ),      //parameter          enable_completion_timeout_disable_0       = "true",                                        //.flr_capability                                                (flr_capability                                                ),
                                                                                                                                                                                                                         //.enable_adapter_half_rate_mode                                 (enable_adapter_half_rate_mode                                 ),
      .surprise_down_error_support_0             (surprise_down_error_support_0             ),      //parameter          surprise_down_error_support_0             = "false",                                       //.vc0_clk_enable                                                (vc0_clk_enable                                                ),
      .dll_active_report_support_0               (dll_active_report_support_0               ),      //parameter          dll_active_report_support_0               = "false",                                       //.register_pipe_signals                                         (register_pipe_signals                                         ),
                                                                                                                                                                                                                         //.bar0_io_space                                                 (bar0_io_space                                                 ),
      .rx_ei_l0s_0                               (rx_ei_l0s_0                               ),      //parameter          rx_ei_l0s_0                               = "disable",                                     //.bar0_64bit_mem_space                                          (bar0_64bit_mem_space                                          ),
      .endpoint_l0_latency_0                     (endpoint_l0_latency_0                     ),      //parameter [2:0]    endpoint_l0_latency_0                     = 3'b0,                                          //.bar0_prefetchable                                             (bar0_prefetchable                                             ),
      .endpoint_l1_latency_0                     (endpoint_l1_latency_0                     ),      //parameter [2:0]    endpoint_l1_latency_0                     = 3'b0,                                          //.bar0_size_mask                                                (bar0_size_mask                                                ),
      .maximum_current_0                         (maximum_current_0                         ),      //parameter          maximum_current_0                         = 3'b0,                                          //.bar1_io_space                                                 (bar1_io_space                                                 ),
      .device_specific_init_0                    (device_specific_init_0                    ),      //parameter          device_specific_init_0                    = "false",                                       //.bar1_64bit_mem_space                                          (bar1_64bit_mem_space                                          ),
                                                                                                                                                                                                                         //.bar1_prefetchable                                             (bar1_prefetchable                                             ),
      .expansion_base_address_register_0         (expansion_base_address_register_0         ),      //parameter [31:0]   expansion_base_address_register_0         = 32'b0,                                         //.bar1_size_mask                                                (bar1_size_mask                                                ),
                                                                                                                                                                                                                         //.bar2_io_space                                                 (bar2_io_space                                                 ),
      .ssvid_0                                   (ssvid_0                                   ),      //parameter [15:0]   ssvid_0                                   = 16'b0,                                         //.bar2_64bit_mem_space                                          (bar2_64bit_mem_space                                          ),
      .ssid_0                                    (ssid_0                                    ),      //parameter [15:0]   ssid_0                                    = 16'b0,                                         //.bar2_prefetchable                                             (bar2_prefetchable                                             ),
                                                                                                                                                                                                                         //.bar2_size_mask                                                (bar2_size_mask                                                ),
      .bridge_port_vga_enable_0                  (bridge_port_vga_enable_0                  ),      //parameter          bridge_port_vga_enable_0                  = "false",                                       //.bar3_io_space                                                 (bar3_io_space                                                 ),
      .bridge_port_ssid_support_0                (bridge_port_ssid_support_0                ),      //parameter          bridge_port_ssid_support_0                = "false",                                       //.bar3_64bit_mem_space                                          (bar3_64bit_mem_space                                          ),
                                                                                                                                                                                                                         //.bar3_prefetchable                                             (bar3_prefetchable                                             ),
      .flr_capability_0                          (flr_capability_0                          ),      //parameter          flr_capability_0                          = "true",                                        //.bar3_size_mask                                                (bar3_size_mask                                                ),
      .disable_snoop_packet_0                    (disable_snoop_packet_0                    ),      //parameter          disable_snoop_packet_0                    = "false",                                       //.bar4_io_space                                                 (bar4_io_space                                                 ),
                                                                                                                                                                                                                         //.bar4_64bit_mem_space                                          (bar4_64bit_mem_space                                          ),
      //Function 1                                                                                                                                                                                                       //.bar4_prefetchable                                             (bar4_prefetchable                                             ),
                                                                                                                                                                                                                         //.bar4_size_mask                                                (bar4_size_mask                                                ),
      .vendor_id_1                               (vendor_id_1                               ),      //parameter          vendor_id_1                               = 16'b0001000101110010,                          //.bar5_io_space                                                 (bar5_io_space                                                 ),
      .device_id_1                               (device_id_1                               ),      //parameter          device_id_1                               = 16'b1,                                         //.bar5_64bit_mem_space                                          (bar5_64bit_mem_space                                          ),
      .revision_id_1                             (revision_id_1                             ),      //parameter          revision_id_1                             = 8'b1,                                          //.bar5_prefetchable                                             (bar5_prefetchable                                             ),
      .class_code_1                              (class_code_1                              ),      //parameter          class_code_1                              = 24'b111111110000000000000000,                  //.bar5_size_mask                                                (bar5_size_mask                                                ),
      .subsystem_vendor_id_1                     (subsystem_vendor_id_1                     ),      //parameter          subsystem_vendor_id_1                     = 16'b0001000101110010,                          //.expansion_base_address_register                               (expansion_base_address_register                               ),
      .subsystem_device_id_1                     (subsystem_device_id_1                     ),      //parameter          subsystem_device_id_1                     = 16'b1,                                         //.io_window_addr_width                                          (io_window_addr_width                                          ),
                                                                                                                                                                                                                         //.prefetchable_mem_window_addr_width                            (prefetchable_mem_window_addr_width                            ),
      .bar0_io_space_1                           (bar0_io_space_1                           ),      //parameter          bar0_io_space_1                           = "false",                                       //.skp_os_gen3_count                                             (skp_os_gen3_count                                             ),
      .bar0_64bit_mem_space_1                    (bar0_64bit_mem_space_1                    ),      //parameter          bar0_64bit_mem_space_1                    = "true",                                        //.tx_cdc_almost_empty                                           (tx_cdc_almost_empty                                           ),
      .bar0_prefetchable_1                       (bar0_prefetchable_1                       ),      //parameter          bar0_prefetchable_1                       = "true",                                        //.rx_cdc_almost_full                                            (rx_cdc_almost_full                                            ),
      .bar0_size_mask_1                          (bar0_size_mask_1                          ),      //parameter [27:0]   bar0_size_mask_1                          = 28'b1111111111111111111111111111,              //.tx_cdc_almost_full                                            (tx_cdc_almost_full                                            ),
      .bar1_io_space_1                           (bar1_io_space_1                           ),      //parameter          bar1_io_space_1                           = "false",                                       //.rx_l0s_count_idl                                              (rx_l0s_count_idl                                              ),
      .bar1_64bit_mem_space_1                    (bar1_64bit_mem_space_1                    ),      //parameter          bar1_64bit_mem_space_1                    = "false",                                       //.cdc_dummy_insert_limit                                        (cdc_dummy_insert_limit                                        ),
      .bar1_prefetchable_1                       (bar1_prefetchable_1                       ),      //parameter          bar1_prefetchable_1                       = "false",                                       //.ei_delay_powerdown_count                                      (ei_delay_powerdown_count                                      ),
      .bar1_size_mask_1                          (bar1_size_mask_1                          ),      //parameter [27:0]   bar1_size_mask_1                          = 28'b0,                                         //.millisecond_cycle_count                                       (millisecond_cycle_count                                       ),
      .bar2_io_space_1                           (bar2_io_space_1                           ),      //parameter          bar2_io_space_1                           = "false",                                       //.skp_os_schedule_count                                         (skp_os_schedule_count                                         ),
      .bar2_64bit_mem_space_1                    (bar2_64bit_mem_space_1                    ),      //parameter          bar2_64bit_mem_space_1                    = "false",                                       //.fc_init_timer                                                 (fc_init_timer                                                 ),
      .bar2_prefetchable_1                       (bar2_prefetchable_1                       ),      //parameter          bar2_prefetchable_1                       = "false",                                       //.l01_entry_latency                                             (l01_entry_latency                                             ),
      .bar2_size_mask_1                          (bar2_size_mask_1                          ),      //parameter [27:0]   bar2_size_mask_1                          = 28'b0,                                         //.flow_control_update_count                                     (flow_control_update_count                                     ),
      .bar3_io_space_1                           (bar3_io_space_1                           ),      //parameter          bar3_io_space_1                           = "false",                                       //.flow_control_timeout_count                                    (flow_control_timeout_count                                    ),
      .bar3_64bit_mem_space_1                    (bar3_64bit_mem_space_1                    ),      //parameter          bar3_64bit_mem_space_1                    = "false",                                       //.vc0_rx_flow_ctrl_posted_header                                (vc0_rx_flow_ctrl_posted_header                                ),
      .bar3_prefetchable_1                       (bar3_prefetchable_1                       ),      //parameter          bar3_prefetchable_1                       = "false",                                       //.vc0_rx_flow_ctrl_posted_data                                  (vc0_rx_flow_ctrl_posted_data                                  ),
      .bar3_size_mask_1                          (bar3_size_mask_1                          ),      //parameter [27:0]   bar3_size_mask_1                          = 28'b0,                                         //.vc0_rx_flow_ctrl_nonposted_header                             (vc0_rx_flow_ctrl_nonposted_header                             ),
      .bar4_io_space_1                           (bar4_io_space_1                           ),      //parameter          bar4_io_space_1                           = "false",                                       //.vc0_rx_flow_ctrl_nonposted_data                               (vc0_rx_flow_ctrl_nonposted_data                               ),
      .bar4_64bit_mem_space_1                    (bar4_64bit_mem_space_1                    ),      //parameter          bar4_64bit_mem_space_1                    = "false",                                       //.vc0_rx_flow_ctrl_compl_header                                 (vc0_rx_flow_ctrl_compl_header                                 ),
      .bar4_prefetchable_1                       (bar4_prefetchable_1                       ),      //parameter          bar4_prefetchable_1                       = "false",                                       //.vc0_rx_flow_ctrl_compl_data                                   (vc0_rx_flow_ctrl_compl_data                                   ),
      .bar4_size_mask_1                          (bar4_size_mask_1                          ),      //parameter [27:0]   bar4_size_mask_1                          = 28'b0,                                         //.rx_ptr0_posted_dpram_min                                      (rx_ptr0_posted_dpram_min                                      ),
      .bar5_io_space_1                           (bar5_io_space_1                           ),      //parameter          bar5_io_space_1                           = "false",                                       //.rx_ptr0_posted_dpram_max                                      (rx_ptr0_posted_dpram_max                                      ),
      .bar5_64bit_mem_space_1                    (bar5_64bit_mem_space_1                    ),      //parameter          bar5_64bit_mem_space_1                    = "false",                                       //.rx_ptr0_nonposted_dpram_min                                   (rx_ptr0_nonposted_dpram_min                                   ),
      .bar5_prefetchable_1                       (bar5_prefetchable_1                       ),      //parameter          bar5_prefetchable_1                       = "false",                                       //.rx_ptr0_nonposted_dpram_max                                   (rx_ptr0_nonposted_dpram_max                                   ),
      .bar5_size_mask_1                          (bar5_size_mask_1                          ),      //parameter [27:0]   bar5_size_mask_1                          = 28'b0,                                         //.retry_buffer_last_active_address                              (retry_buffer_last_active_address                              ),
                                                                                                                                                                                                                         //.retry_buffer_memory_settings                                  (retry_buffer_memory_settings                                  ),
      .msi_multi_message_capable_1               (msi_multi_message_capable_1               ),      //parameter          msi_multi_message_capable_1               = "count_4",                                     //.vc0_rx_buffer_memory_settings                                 (vc0_rx_buffer_memory_settings                                 ),
      .msi_64bit_addressing_capable_1            (msi_64bit_addressing_capable_1            ),      //parameter          msi_64bit_addressing_capable_1            = "true",                                        //.bist_memory_settings                                          (bist_memory_settings                                          ),
      .msi_masking_capable_1                     (msi_masking_capable_1                     ),      //parameter          msi_masking_capable_1                     = "false",                                       //.credit_buffer_allocation_aux                                  (credit_buffer_allocation_aux                                  ),
      .msi_support_1                             (msi_support_1                             ),      //parameter          msi_support_1                             = "true",                                        //.iei_enable_settings                                           (iei_enable_settings                                           ),
      .interrupt_pin_1                           (interrupt_pin_1                           ),      //parameter          interrupt_pin_1                           = "inta",                                        //.vsec_id                                                       (vsec_id                                                       ),
      .enable_function_msix_support_1            (enable_function_msix_support_1            ),      //parameter          enable_function_msix_support_1            = "true",                                        //.cvp_rate_sel                                                  (cvp_rate_sel                                                  ),
      .msix_table_size_1                         (msix_table_size_1                         ),      //parameter [10:0]   msix_table_size_1                         = 11'b0,                                         //.hard_reset_bypass                                             (hard_reset_bypass                                             ),
      .msix_table_bir_1                          (msix_table_bir_1                          ),      //parameter [2:0]    msix_table_bir_1                          = 3'b0,                                          //.cvp_data_compressed                                           (cvp_data_compressed                                           ),
      .msix_table_offset_1                       (msix_table_offset_1                       ),      //parameter [28:0]   msix_table_offset_1                       = 29'b0,                                         //.cvp_data_encrypted                                            (cvp_data_encrypted                                            ),
      .msix_pba_bir_1                            (msix_pba_bir_1                            ),      //parameter [2:0]    msix_pba_bir_1                            = 3'b0,                                          //.cvp_mode_reset                                                (cvp_mode_reset                                                ),
      .msix_pba_offset_1                         (msix_pba_offset_1                         ),      //parameter [28:0]   msix_pba_offset_1                         = 29'b0,                                         //.cvp_clk_reset                                                 (cvp_clk_reset                                                 ),
                                                                                                                                                                                                                         //.in_cvp_mode                                                   (in_cvp_mode                                                   ),
      .use_aer_1                                 (use_aer_1                                 ),      //parameter          use_aer_1                                 = "false",                                       //.vsec_cap                                                      (vsec_cap                                                      ),
      .ecrc_check_capable_1                      (ecrc_check_capable_1                      ),      //parameter          ecrc_check_capable_1                      = "true",                                        //.jtag_id                                                       (jtag_id                                                       ),
      .ecrc_gen_capable_1                        (ecrc_gen_capable_1                        ),      //parameter          ecrc_gen_capable_1                        = "true",                                        //.user_id                                                       (user_id                                                       ),

      .slot_power_scale_1                        (slot_power_scale_1                        ),      //parameter [1:0]    slot_power_scale_1                       = 2'b0,
      .slot_power_limit_1                        (slot_power_limit_1                        ),      //parameter [7:0]    slot_power_limit_1                       = 8'b0,
      .slot_number_1                             (slot_number_1                             ),      //parameter [12:0]   slot_number_1                            = 13'b0,

      .max_payload_size_1                        (max_payload_size_1                        ),      //parameter          max_payload_size_1                       = "payload_512",
      .extend_tag_field_1                        (extend_tag_field_1                        ),      //parameter          extend_tag_field_1                       = "false",
      .completion_timeout_1                      (completion_timeout_1                      ),      //parameter          completion_timeout_1                     = "abcd",
      .enable_completion_timeout_disable_1       (enable_completion_timeout_disable_1       ),      //parameter          enable_completion_timeout_disable_1      = "true",

      .surprise_down_error_support_1             (surprise_down_error_support_1             ),      //parameter          surprise_down_error_support_1            = "false",
      .dll_active_report_support_1               (dll_active_report_support_1               ),      //parameter          dll_active_report_support_1              = "false",

      .rx_ei_l0s_1                               (rx_ei_l0s_1                               ),      //parameter          rx_ei_l0s_1                              = "disable",
      .endpoint_l0_latency_1                     (endpoint_l0_latency_1                     ),      //parameter [2:0]    endpoint_l0_latency_1                    = 3'b0,
      .endpoint_l1_latency_1                     (endpoint_l1_latency_1                     ),      //parameter [2:0]    endpoint_l1_latency_1                    = 3'b0,
      .maximum_current_1                         (maximum_current_1                         ),      //parameter          maximum_current_1                        = 3'b0,
      .device_specific_init_1                    (device_specific_init_1                    ),      //parameter          device_specific_init_1                   = "false",

      .expansion_base_address_register_1         (expansion_base_address_register_1         ),      //parameter [31:0]   expansion_base_address_register_1        = 32'b0,

      .ssvid_1                                   (ssvid_1                                   ),      //parameter [15:0]   ssvid_1                                  = 16'b0,
      .ssid_1                                    (ssid_1                                    ),      //parameter [15:0]   ssid_1                                   = 16'b0,

      .bridge_port_vga_enable_1                  (bridge_port_vga_enable_1                  ),      //parameter          bridge_port_vga_enable_1                 = "false",
      .bridge_port_ssid_support_1                (bridge_port_ssid_support_1                ),      //parameter          bridge_port_ssid_support_1               = "false",

      .flr_capability_1                          (flr_capability_1                          ),      //parameter          flr_capability_1                         = "true",
      .disable_snoop_packet_1                    (disable_snoop_packet_1                    ),      //parameter          disable_snoop_packet_1                   = "false",

      //Function 2

      .vendor_id_2                               (vendor_id_2                               ),      //parameter          vendor_id_2                              = 16'b0001000101110010,
      .device_id_2                               (device_id_2                               ),      //parameter          device_id_2                              = 16'b1,
      .revision_id_2                             (revision_id_2                             ),      //parameter          revision_id_2                            = 8'b1,
      .class_code_2                              (class_code_2                              ),      //parameter          class_code_2                             = 24'b111111110000000000000000,
      .subsystem_vendor_id_2                     (subsystem_vendor_id_2                     ),      //parameter          subsystem_vendor_id_2                    = 16'b0001000101110010,
      .subsystem_device_id_2                     (subsystem_device_id_2                     ),      //parameter          subsystem_device_id_2                    = 16'b1,

      .bar0_io_space_2                           (bar0_io_space_2                           ),      //parameter          bar0_io_space_2                          = "false",
      .bar0_64bit_mem_space_2                    (bar0_64bit_mem_space_2                    ),      //parameter          bar0_64bit_mem_space_2                   = "true",
      .bar0_prefetchable_2                       (bar0_prefetchable_2                       ),      //parameter          bar0_prefetchable_2                      = "true",
      .bar0_size_mask_2                          (bar0_size_mask_2                          ),      //parameter [27:0]   bar0_size_mask_2                         = 28'b1111111111111111111111111111,
      .bar1_io_space_2                           (bar1_io_space_2                           ),      //parameter          bar1_io_space_2                          = "false",
      .bar1_64bit_mem_space_2                    (bar1_64bit_mem_space_2                    ),      //parameter          bar1_64bit_mem_space_2                   = "false",
      .bar1_prefetchable_2                       (bar1_prefetchable_2                       ),      //parameter          bar1_prefetchable_2                      = "false",
      .bar1_size_mask_2                          (bar1_size_mask_2                          ),      //parameter [27:0]   bar1_size_mask_2                         = 28'b0,
      .bar2_io_space_2                           (bar2_io_space_2                           ),      //parameter          bar2_io_space_2                          = "false",
      .bar2_64bit_mem_space_2                    (bar2_64bit_mem_space_2                    ),      //parameter          bar2_64bit_mem_space_2                   = "false",
      .bar2_prefetchable_2                       (bar2_prefetchable_2                       ),      //parameter          bar2_prefetchable_2                      = "false",
      .bar2_size_mask_2                          (bar2_size_mask_2                          ),      //parameter [27:0]   bar2_size_mask_2                         = 28'b0,
      .bar3_io_space_2                           (bar3_io_space_2                           ),      //parameter          bar3_io_space_2                          = "false",
      .bar3_64bit_mem_space_2                    (bar3_64bit_mem_space_2                    ),      //parameter          bar3_64bit_mem_space_2                   = "false",
      .bar3_prefetchable_2                       (bar3_prefetchable_2                       ),      //parameter          bar3_prefetchable_2                      = "false",
      .bar3_size_mask_2                          (bar3_size_mask_2                          ),      //parameter [27:0]   bar3_size_mask_2                         = 28'b0,
      .bar4_io_space_2                           (bar4_io_space_2                           ),      //parameter          bar4_io_space_2                          = "false",
      .bar4_64bit_mem_space_2                    (bar4_64bit_mem_space_2                    ),      //parameter          bar4_64bit_mem_space_2                   = "false",
      .bar4_prefetchable_2                       (bar4_prefetchable_2                       ),      //parameter          bar4_prefetchable_2                      = "false",
      .bar4_size_mask_2                          (bar4_size_mask_2                          ),      //parameter [27:0]   bar4_size_mask_2                         = 28'b0,
      .bar5_io_space_2                           (bar5_io_space_2                           ),      //parameter          bar5_io_space_2                          = "false",
      .bar5_64bit_mem_space_2                    (bar5_64bit_mem_space_2                    ),      //parameter          bar5_64bit_mem_space_2                   = "false",
      .bar5_prefetchable_2                       (bar5_prefetchable_2                       ),      //parameter          bar5_prefetchable_2                      = "false",
      .bar5_size_mask_2                          (bar5_size_mask_2                          ),      //parameter [27:0]   bar5_size_mask_2                         = 28'b0,

      .msi_multi_message_capable_2               (msi_multi_message_capable_2               ),      //parameter          msi_multi_message_capable_2              = "count_4",
      .msi_64bit_addressing_capable_2            (msi_64bit_addressing_capable_2            ),      //parameter          msi_64bit_addressing_capable_2           = "true",
      .msi_masking_capable_2                     (msi_masking_capable_2                     ),      //parameter          msi_masking_capable_2                    = "false",
      .msi_support_2                             (msi_support_2                             ),      //parameter          msi_support_2                            = "true",
      .interrupt_pin_2                           (interrupt_pin_2                           ),      //parameter          interrupt_pin_2                          = "inta",
      .enable_function_msix_support_2            (enable_function_msix_support_2            ),      //parameter          enable_function_msix_support_2           = "true",
      .msix_table_size_2                         (msix_table_size_2                         ),      //parameter [10:0]   msix_table_size_2                        = 11'b0,
      .msix_table_bir_2                          (msix_table_bir_2                          ),      //parameter [2:0]    msix_table_bir_2                         = 3'b0,
      .msix_table_offset_2                       (msix_table_offset_2                       ),      //parameter [28:0]   msix_table_offset_2                      = 29'b0,
      .msix_pba_bir_2                            (msix_pba_bir_2                            ),      //parameter [2:0]    msix_pba_bir_2                           = 3'b0,
      .msix_pba_offset_2                         (msix_pba_offset_2                         ),      //parameter [28:0]   msix_pba_offset_2                        = 29'b0,

      .use_aer_2                                 (use_aer_2                                 ),      //parameter          use_aer_2                                = "false",
      .ecrc_check_capable_2                      (ecrc_check_capable_2                      ),      //parameter          ecrc_check_capable_2                     = "true",
      .ecrc_gen_capable_2                        (ecrc_gen_capable_2                        ),      //parameter          ecrc_gen_capable_2                       = "true",

      .slot_power_scale_2                        (slot_power_scale_2                        ),      //parameter [1:0]    slot_power_scale_2                       = 2'b0,
      .slot_power_limit_2                        (slot_power_limit_2                        ),      //parameter [7:0]    slot_power_limit_2                       = 8'b0,
      .slot_number_2                             (slot_number_2                             ),      //parameter [12:0]   slot_number_2                            = 13'b0,

      .max_payload_size_2                        (max_payload_size_2                        ),      //parameter          max_payload_size_2                       = "payload_512",
      .extend_tag_field_2                        (extend_tag_field_2                        ),      //parameter          extend_tag_field_2                       = "false",
      .completion_timeout_2                      (completion_timeout_2                      ),      //parameter          completion_timeout_2                     = "abcd",
      .enable_completion_timeout_disable_2       (enable_completion_timeout_disable_2       ),      //parameter          enable_completion_timeout_disable_2      = "true",

      .surprise_down_error_support_2             (surprise_down_error_support_2             ),      //parameter          surprise_down_error_support_2            = "false",
      .dll_active_report_support_2               (dll_active_report_support_2               ),      //parameter          dll_active_report_support_2              = "false",

      .rx_ei_l0s_2                               (rx_ei_l0s_2                               ),      //parameter          rx_ei_l0s_2                              = "disable",
      .endpoint_l0_latency_2                     (endpoint_l0_latency_2                     ),      //parameter [2:0]    endpoint_l0_latency_2                    = 3'b0,
      .endpoint_l1_latency_2                     (endpoint_l1_latency_2                     ),      //parameter [2:0]    endpoint_l1_latency_2                    = 3'b0,
      .maximum_current_2                         (maximum_current_2                         ),      //parameter          maximum_current_2                        = 3'b0,
      .device_specific_init_2                    (device_specific_init_2                    ),      //parameter          device_specific_init_2                   = "false",

      .expansion_base_address_register_2         (expansion_base_address_register_2         ),      //parameter [31:0]   expansion_base_address_register_2        = 32'b0,

      .ssvid_2                                   (ssvid_2                                   ),      //parameter [15:0]   ssvid_2                                  = 16'b0,
      .ssid_2                                    (ssid_2                                    ),      //parameter [15:0]   ssid_2                                   = 16'b0,

      .flr_capability_2                          (flr_capability_2                          ),      //parameter          flr_capability_2                         = "true",
      .disable_snoop_packet_2                    (disable_snoop_packet_2                    ),      //parameter          disable_snoop_packet_2                   = "false",

      //Function 3

      .vendor_id_3                               (vendor_id_3                               ),      //parameter          vendor_id_3                              = 16'b0001000101110010,
      .device_id_3                               (device_id_3                               ),      //parameter          device_id_3                              = 16'b1,
      .revision_id_3                             (revision_id_3                             ),      //parameter          revision_id_3                            = 8'b1,
      .class_code_3                              (class_code_3                              ),      //parameter          class_code_3                             = 24'b111111110000000000000000,
      .subsystem_vendor_id_3                     (subsystem_vendor_id_3                     ),      //parameter          subsystem_vendor_id_3                    = 16'b0001000101110010,
      .subsystem_device_id_3                     (subsystem_device_id_3                     ),      //parameter          subsystem_device_id_3                    = 16'b1,

      .bar0_io_space_3                           (bar0_io_space_3                           ),      //parameter          bar0_io_space_3                          = "false",
      .bar0_64bit_mem_space_3                    (bar0_64bit_mem_space_3                    ),      //parameter          bar0_64bit_mem_space_3                   = "true",
      .bar0_prefetchable_3                       (bar0_prefetchable_3                       ),      //parameter          bar0_prefetchable_3                      = "true",
      .bar0_size_mask_3                          (bar0_size_mask_3                          ),      //parameter [27:0]   bar0_size_mask_3                         = 28'b1111111111111111111111111111,
      .bar1_io_space_3                           (bar1_io_space_3                           ),      //parameter          bar1_io_space_3                          = "false",
      .bar1_64bit_mem_space_3                    (bar1_64bit_mem_space_3                    ),      //parameter          bar1_64bit_mem_space_3                   = "false",
      .bar1_prefetchable_3                       (bar1_prefetchable_3                       ),      //parameter          bar1_prefetchable_3                      = "false",
      .bar1_size_mask_3                          (bar1_size_mask_3                          ),      //parameter [27:0]   bar1_size_mask_3                         = 28'b0,
      .bar2_io_space_3                           (bar2_io_space_3                           ),      //parameter          bar2_io_space_3                          = "false",
      .bar2_64bit_mem_space_3                    (bar2_64bit_mem_space_3                    ),      //parameter          bar2_64bit_mem_space_3                   = "false",
      .bar2_prefetchable_3                       (bar2_prefetchable_3                       ),      //parameter          bar2_prefetchable_3                      = "false",
      .bar2_size_mask_3                          (bar2_size_mask_3                          ),      //parameter [27:0]   bar2_size_mask_3                         = 28'b0,
      .bar3_io_space_3                           (bar3_io_space_3                           ),      //parameter          bar3_io_space_3                          = "false",
      .bar3_64bit_mem_space_3                    (bar3_64bit_mem_space_3                    ),      //parameter          bar3_64bit_mem_space_3                   = "false",
      .bar3_prefetchable_3                       (bar3_prefetchable_3                       ),      //parameter          bar3_prefetchable_3                      = "false",
      .bar3_size_mask_3                          (bar3_size_mask_3                          ),      //parameter [27:0]   bar3_size_mask_3                         = 28'b0,
      .bar4_io_space_3                           (bar4_io_space_3                           ),      //parameter          bar4_io_space_3                          = "false",
      .bar4_64bit_mem_space_3                    (bar4_64bit_mem_space_3                    ),      //parameter          bar4_64bit_mem_space_3                   = "false",
      .bar4_prefetchable_3                       (bar4_prefetchable_3                       ),      //parameter          bar4_prefetchable_3                      = "false",
      .bar4_size_mask_3                          (bar4_size_mask_3                          ),      //parameter [27:0]   bar4_size_mask_3                         = 28'b0,
      .bar5_io_space_3                           (bar5_io_space_3                           ),      //parameter          bar5_io_space_3                          = "false",
      .bar5_64bit_mem_space_3                    (bar5_64bit_mem_space_3                    ),      //parameter          bar5_64bit_mem_space_3                   = "false",
      .bar5_prefetchable_3                       (bar5_prefetchable_3                       ),      //parameter          bar5_prefetchable_3                      = "false",
      .bar5_size_mask_3                          (bar5_size_mask_3                          ),      //parameter [27:0]   bar5_size_mask_3                         = 28'b0,

      .msi_multi_message_capable_3               (msi_multi_message_capable_3               ),      //parameter          msi_multi_message_capable_3              = "count_4",
      .msi_64bit_addressing_capable_3            (msi_64bit_addressing_capable_3            ),      //parameter          msi_64bit_addressing_capable_3           = "true",
      .msi_masking_capable_3                     (msi_masking_capable_3                     ),      //parameter          msi_masking_capable_3                    = "false",
      .msi_support_3                             (msi_support_3                             ),      //parameter          msi_support_3                            = "true",
      .interrupt_pin_3                           (interrupt_pin_3                           ),      //parameter          interrupt_pin_3                          = "inta",
      .enable_function_msix_support_3            (enable_function_msix_support_3            ),      //parameter          enable_function_msix_support_3           = "true",
      .msix_table_size_3                         (msix_table_size_3                         ),      //parameter [10:0]   msix_table_size_3                        = 11'b0,
      .msix_table_bir_3                          (msix_table_bir_3                          ),      //parameter [2:0]    msix_table_bir_3                         = 3'b0,
      .msix_table_offset_3                       (msix_table_offset_3                       ),      //parameter [28:0]   msix_table_offset_3                      = 29'b0,
      .msix_pba_bir_3                            (msix_pba_bir_3                            ),      //parameter [2:0]    msix_pba_bir_3                           = 3'b0,
      .msix_pba_offset_3                         (msix_pba_offset_3                         ),      //parameter [28:0]   msix_pba_offset_3                        = 29'b0,

      .use_aer_3                                 (use_aer_3                                 ),      //parameter          use_aer_3                                = "false",
      .ecrc_check_capable_3                      (ecrc_check_capable_3                      ),      //parameter          ecrc_check_capable_3                     = "true",
      .ecrc_gen_capable_3                        (ecrc_gen_capable_3                        ),      //parameter          ecrc_gen_capable_3                       = "true",

      .slot_power_scale_3                        (slot_power_scale_3                        ),      //parameter [1:0]    slot_power_scale_3                       = 2'b0,
      .slot_power_limit_3                        (slot_power_limit_3                        ),      //parameter [7:0]    slot_power_limit_3                       = 8'b0,
      .slot_number_3                             (slot_number_3                             ),      //parameter [12:0]   slot_number_3                            = 13'b0,

      .max_payload_size_3                        (max_payload_size_3                        ),      //parameter          max_payload_size_3                       = "payload_512",
      .extend_tag_field_3                        (extend_tag_field_3                        ),      //parameter          extend_tag_field_3                       = "false",
      .completion_timeout_3                      (completion_timeout_3                      ),      //parameter          completion_timeout_3                     = "abcd",
      .enable_completion_timeout_disable_3       (enable_completion_timeout_disable_3       ),      //parameter          enable_completion_timeout_disable_3      = "true",

      .surprise_down_error_support_3             (surprise_down_error_support_3             ),      //parameter          surprise_down_error_support_3            = "false",
      .dll_active_report_support_3               (dll_active_report_support_3               ),      //parameter          dll_active_report_support_3              = "false",

      .rx_ei_l0s_3                               (rx_ei_l0s_3                               ),      //parameter          rx_ei_l0s_3                              = "disable",
      .endpoint_l0_latency_3                     (endpoint_l0_latency_3                     ),      //parameter [2:0]    endpoint_l0_latency_3                    = 3'b0,
      .endpoint_l1_latency_3                     (endpoint_l1_latency_3                     ),      //parameter [2:0]    endpoint_l1_latency_3                    = 3'b0,
      .maximum_current_3                         (maximum_current_3                         ),      //parameter          maximum_current_3                        = 3'b0,
      .device_specific_init_3                    (device_specific_init_3                    ),      //parameter          device_specific_init_3                   = "false",

      .expansion_base_address_register_3         (expansion_base_address_register_3         ),      //parameter [31:0]   expansion_base_address_register_3        = 32'b0,

      .ssvid_3                                   (ssvid_3                                   ),      //parameter [15:0]   ssvid_3                                  = 16'b0,
      .ssid_3                                    (ssid_3                                    ),      //parameter [15:0]   ssid_3                                   = 16'b0,

      .flr_capability_3                          (flr_capability_3                          ),      //parameter          flr_capability_3                         = "true",
      .disable_snoop_packet_3                    (disable_snoop_packet_3                    ),      //parameter          disable_snoop_packet_3                   = "false",

      //Function 4

      .vendor_id_4                               (vendor_id_4                               ),      //parameter          vendor_id_4                              = 16'b0001000101110010,
      .device_id_4                               (device_id_4                               ),      //parameter          device_id_4                              = 16'b1,
      .revision_id_4                             (revision_id_4                             ),      //parameter          revision_id_4                            = 8'b1,
      .class_code_4                              (class_code_4                              ),      //parameter          class_code_4                             = 24'b111111110000000000000000,
      .subsystem_vendor_id_4                     (subsystem_vendor_id_4                     ),      //parameter          subsystem_vendor_id_4                    = 16'b0001000101110010,
      .subsystem_device_id_4                     (subsystem_device_id_4                     ),      //parameter          subsystem_device_id_4                    = 16'b1,

      .bar0_io_space_4                           (bar0_io_space_4                           ),      //parameter          bar0_io_space_4                          = "false",
      .bar0_64bit_mem_space_4                    (bar0_64bit_mem_space_4                    ),      //parameter          bar0_64bit_mem_space_4                   = "true",
      .bar0_prefetchable_4                       (bar0_prefetchable_4                       ),      //parameter          bar0_prefetchable_4                      = "true",
      .bar0_size_mask_4                          (bar0_size_mask_4                          ),      //parameter [27:0]   bar0_size_mask_4                         = 28'b1111111111111111111111111111,
      .bar1_io_space_4                           (bar1_io_space_4                           ),      //parameter          bar1_io_space_4                          = "false",
      .bar1_64bit_mem_space_4                    (bar1_64bit_mem_space_4                    ),      //parameter          bar1_64bit_mem_space_4                   = "false",
      .bar1_prefetchable_4                       (bar1_prefetchable_4                       ),      //parameter          bar1_prefetchable_4                      = "false",
      .bar1_size_mask_4                          (bar1_size_mask_4                          ),      //parameter [27:0]   bar1_size_mask_4                         = 28'b0,
      .bar2_io_space_4                           (bar2_io_space_4                           ),      //parameter          bar2_io_space_4                          = "false",
      .bar2_64bit_mem_space_4                    (bar2_64bit_mem_space_4                    ),      //parameter          bar2_64bit_mem_space_4                   = "false",
      .bar2_prefetchable_4                       (bar2_prefetchable_4                       ),      //parameter          bar2_prefetchable_4                      = "false",
      .bar2_size_mask_4                          (bar2_size_mask_4                          ),      //parameter [27:0]   bar2_size_mask_4                         = 28'b0,
      .bar3_io_space_4                           (bar3_io_space_4                           ),      //parameter          bar3_io_space_4                          = "false",
      .bar3_64bit_mem_space_4                    (bar3_64bit_mem_space_4                    ),      //parameter          bar3_64bit_mem_space_4                   = "false",
      .bar3_prefetchable_4                       (bar3_prefetchable_4                       ),      //parameter          bar3_prefetchable_4                      = "false",
      .bar3_size_mask_4                          (bar3_size_mask_4                          ),      //parameter [27:0]   bar3_size_mask_4                         = 28'b0,
      .bar4_io_space_4                           (bar4_io_space_4                           ),      //parameter          bar4_io_space_4                          = "false",
      .bar4_64bit_mem_space_4                    (bar4_64bit_mem_space_4                    ),      //parameter          bar4_64bit_mem_space_4                   = "false",
      .bar4_prefetchable_4                       (bar4_prefetchable_4                       ),      //parameter          bar4_prefetchable_4                      = "false",
      .bar4_size_mask_4                          (bar4_size_mask_4                          ),      //parameter [27:0]   bar4_size_mask_4                         = 28'b0,
      .bar5_io_space_4                           (bar5_io_space_4                           ),      //parameter          bar5_io_space_4                          = "false",
      .bar5_64bit_mem_space_4                    (bar5_64bit_mem_space_4                    ),      //parameter          bar5_64bit_mem_space_4                   = "false",
      .bar5_prefetchable_4                       (bar5_prefetchable_4                       ),      //parameter          bar5_prefetchable_4                      = "false",
      .bar5_size_mask_4                          (bar5_size_mask_4                          ),      //parameter [27:0]   bar5_size_mask_4                         = 28'b0,

      .msi_multi_message_capable_4               (msi_multi_message_capable_4               ),      //parameter          msi_multi_message_capable_4              = "count_4",
      .msi_64bit_addressing_capable_4            (msi_64bit_addressing_capable_4            ),      //parameter          msi_64bit_addressing_capable_4           = "true",
      .msi_masking_capable_4                     (msi_masking_capable_4                     ),      //parameter          msi_masking_capable_4                    = "false",
      .msi_support_4                             (msi_support_4                             ),      //parameter          msi_support_4                            = "true",
      .interrupt_pin_4                           (interrupt_pin_4                           ),      //parameter          interrupt_pin_4                          = "inta",
      .enable_function_msix_support_4            (enable_function_msix_support_4            ),      //parameter          enable_function_msix_support_4           = "true",
      .msix_table_size_4                         (msix_table_size_4                         ),      //parameter [10:0]   msix_table_size_4                        = 11'b0,
      .msix_table_bir_4                          (msix_table_bir_4                          ),      //parameter [2:0]    msix_table_bir_4                         = 3'b0,
      .msix_table_offset_4                       (msix_table_offset_4                       ),      //parameter [28:0]   msix_table_offset_4                      = 29'b0,
      .msix_pba_bir_4                            (msix_pba_bir_4                            ),      //parameter [2:0]    msix_pba_bir_4                           = 3'b0,
      .msix_pba_offset_4                         (msix_pba_offset_4                         ),      //parameter [28:0]   msix_pba_offset_4                        = 29'b0,

      .use_aer_4                                 (use_aer_4                                 ),      //parameter          use_aer_4                                = "false",
      .ecrc_check_capable_4                      (ecrc_check_capable_4                      ),      //parameter          ecrc_check_capable_4                     = "true",
      .ecrc_gen_capable_4                        (ecrc_gen_capable_4                        ),      //parameter          ecrc_gen_capable_4                       = "true",

      .slot_power_scale_4                        (slot_power_scale_4                        ),      //parameter [1:0]    slot_power_scale_4                       = 2'b0,
      .slot_power_limit_4                        (slot_power_limit_4                        ),      //parameter [7:0]    slot_power_limit_4                       = 8'b0,
      .slot_number_4                             (slot_number_4                             ),      //parameter [12:0]   slot_number_4                            = 13'b0,

      .max_payload_size_4                        (max_payload_size_4                        ),      //parameter          max_payload_size_4                       = "payload_512",
      .extend_tag_field_4                        (extend_tag_field_4                        ),      //parameter          extend_tag_field_4                       = "false",
      .completion_timeout_4                      (completion_timeout_4                      ),      //parameter          completion_timeout_4                     = "abcd",
      .enable_completion_timeout_disable_4       (enable_completion_timeout_disable_4       ),      //parameter          enable_completion_timeout_disable_4      = "true",

      .surprise_down_error_support_4             (surprise_down_error_support_4             ),      //parameter          surprise_down_error_support_4            = "false",
      .dll_active_report_support_4               (dll_active_report_support_4               ),      //parameter          dll_active_report_support_4              = "false",

      .rx_ei_l0s_4                               (rx_ei_l0s_4                               ),      //parameter          rx_ei_l0s_4                              = "disable",
      .endpoint_l0_latency_4                     (endpoint_l0_latency_4                     ),      //parameter [2:0]    endpoint_l0_latency_4                    = 3'b0,
      .endpoint_l1_latency_4                     (endpoint_l1_latency_4                     ),      //parameter [2:0]    endpoint_l1_latency_4                    = 3'b0,
      .maximum_current_4                         (maximum_current_4                         ),      //parameter          maximum_current_4                        = 3'b0,
      .device_specific_init_4                    (device_specific_init_4                    ),      //parameter          device_specific_init_4                   = "false",

      .expansion_base_address_register_4         (expansion_base_address_register_4         ),      //parameter [31:0]   expansion_base_address_register_4        = 32'b0,

      .ssvid_4                                   (ssvid_4                                   ),      //parameter [15:0]   ssvid_4                                  = 16'b0,
      .ssid_4                                    (ssid_4                                    ),      //parameter [15:0]   ssid_4                                   = 16'b0,

      .flr_capability_4                          (flr_capability_4                          ),      //parameter          flr_capability_4                         = "true",
      .disable_snoop_packet_4                    (disable_snoop_packet_4                    ),      //parameter          disable_snoop_packet_4                   = "false",

      //Function 5

      .vendor_id_5                               (vendor_id_5                               ),      //parameter          vendor_id_5                              = 16'b0001000101110010,
      .device_id_5                               (device_id_5                               ),      //parameter          device_id_5                              = 16'b1,
      .revision_id_5                             (revision_id_5                             ),      //parameter          revision_id_5                            = 8'b1,
      .class_code_5                              (class_code_5                              ),      //parameter          class_code_5                             = 24'b111111110000000000000000,
      .subsystem_vendor_id_5                     (subsystem_vendor_id_5                     ),      //parameter          subsystem_vendor_id_5                    = 16'b0001000101110010,
      .subsystem_device_id_5                     (subsystem_device_id_5                     ),      //parameter          subsystem_device_id_5                    = 16'b1,

      .bar0_io_space_5                           (bar0_io_space_5                           ),      //parameter          bar0_io_space_5                          = "false",
      .bar0_64bit_mem_space_5                    (bar0_64bit_mem_space_5                    ),      //parameter          bar0_64bit_mem_space_5                   = "true",
      .bar0_prefetchable_5                       (bar0_prefetchable_5                       ),      //parameter          bar0_prefetchable_5                      = "true",
      .bar0_size_mask_5                          (bar0_size_mask_5                          ),      //parameter [27:0]   bar0_size_mask_5                         = 28'b1111111111111111111111111111,
      .bar1_io_space_5                           (bar1_io_space_5                           ),      //parameter          bar1_io_space_5                          = "false",
      .bar1_64bit_mem_space_5                    (bar1_64bit_mem_space_5                    ),      //parameter          bar1_64bit_mem_space_5                   = "false",
      .bar1_prefetchable_5                       (bar1_prefetchable_5                       ),      //parameter          bar1_prefetchable_5                      = "false",
      .bar1_size_mask_5                          (bar1_size_mask_5                          ),      //parameter [27:0]   bar1_size_mask_5                         = 28'b0,
      .bar2_io_space_5                           (bar2_io_space_5                           ),      //parameter          bar2_io_space_5                          = "false",
      .bar2_64bit_mem_space_5                    (bar2_64bit_mem_space_5                    ),      //parameter          bar2_64bit_mem_space_5                   = "false",
      .bar2_prefetchable_5                       (bar2_prefetchable_5                       ),      //parameter          bar2_prefetchable_5                      = "false",
      .bar2_size_mask_5                          (bar2_size_mask_5                          ),      //parameter [27:0]   bar2_size_mask_5                         = 28'b0,
      .bar3_io_space_5                           (bar3_io_space_5                           ),      //parameter          bar3_io_space_5                          = "false",
      .bar3_64bit_mem_space_5                    (bar3_64bit_mem_space_5                    ),      //parameter          bar3_64bit_mem_space_5                   = "false",
      .bar3_prefetchable_5                       (bar3_prefetchable_5                       ),      //parameter          bar3_prefetchable_5                      = "false",
      .bar3_size_mask_5                          (bar3_size_mask_5                          ),      //parameter [27:0]   bar3_size_mask_5                         = 28'b0,
      .bar4_io_space_5                           (bar4_io_space_5                           ),      //parameter          bar4_io_space_5                          = "false",
      .bar4_64bit_mem_space_5                    (bar4_64bit_mem_space_5                    ),      //parameter          bar4_64bit_mem_space_5                   = "false",
      .bar4_prefetchable_5                       (bar4_prefetchable_5                       ),      //parameter          bar4_prefetchable_5                      = "false",
      .bar4_size_mask_5                          (bar4_size_mask_5                          ),      //parameter [27:0]   bar4_size_mask_5                         = 28'b0,
      .bar5_io_space_5                           (bar5_io_space_5                           ),      //parameter          bar5_io_space_5                          = "false",
      .bar5_64bit_mem_space_5                    (bar5_64bit_mem_space_5                    ),      //parameter          bar5_64bit_mem_space_5                   = "false",
      .bar5_prefetchable_5                       (bar5_prefetchable_5                       ),      //parameter          bar5_prefetchable_5                      = "false",
      .bar5_size_mask_5                          (bar5_size_mask_5                          ),      //parameter [27:0]   bar5_size_mask_5                         = 28'b0,

      .msi_multi_message_capable_5               (msi_multi_message_capable_5               ),      //parameter          msi_multi_message_capable_5              = "count_4",
      .msi_64bit_addressing_capable_5            (msi_64bit_addressing_capable_5            ),      //parameter          msi_64bit_addressing_capable_5           = "true",
      .msi_masking_capable_5                     (msi_masking_capable_5                     ),      //parameter          msi_masking_capable_5                    = "false",
      .msi_support_5                             (msi_support_5                             ),      //parameter          msi_support_5                            = "true",
      .interrupt_pin_5                           (interrupt_pin_5                           ),      //parameter          interrupt_pin_5                          = "inta",
      .enable_function_msix_support_5            (enable_function_msix_support_5            ),      //parameter          enable_function_msix_support_5           = "true",
      .msix_table_size_5                         (msix_table_size_5                         ),      //parameter [10:0]   msix_table_size_5                        = 11'b0,
      .msix_table_bir_5                          (msix_table_bir_5                          ),      //parameter [2:0]    msix_table_bir_5                         = 3'b0,
      .msix_table_offset_5                       (msix_table_offset_5                       ),      //parameter [28:0]   msix_table_offset_5                      = 29'b0,
      .msix_pba_bir_5                            (msix_pba_bir_5                            ),      //parameter [2:0]    msix_pba_bir_5                           = 3'b0,
      .msix_pba_offset_5                         (msix_pba_offset_5                         ),      //parameter [28:0]   msix_pba_offset_5                        = 29'b0,

      .use_aer_5                                 (use_aer_5                                 ),      //parameter          use_aer_5                                = "false",
      .ecrc_check_capable_5                      (ecrc_check_capable_5                      ),      //parameter          ecrc_check_capable_5                     = "true",
      .ecrc_gen_capable_5                        (ecrc_gen_capable_5                        ),      //parameter          ecrc_gen_capable_5                       = "true",

      .slot_power_scale_5                        (slot_power_scale_5                        ),      //parameter [1:0]    slot_power_scale_5                       = 2'b0,
      .slot_power_limit_5                        (slot_power_limit_5                        ),      //parameter [7:0]    slot_power_limit_5                       = 8'b0,
      .slot_number_5                             (slot_number_5                             ),      //parameter [12:0]   slot_number_5                            = 13'b0,

      .max_payload_size_5                        (max_payload_size_5                        ),      //parameter          max_payload_size_5                       = "payload_512",
      .extend_tag_field_5                        (extend_tag_field_5                        ),      //parameter          extend_tag_field_5                       = "false",
      .completion_timeout_5                      (completion_timeout_5                      ),      //parameter          completion_timeout_5                     = "abcd",
      .enable_completion_timeout_disable_5       (enable_completion_timeout_disable_5       ),      //parameter          enable_completion_timeout_disable_5      = "true",

      .surprise_down_error_support_5             (surprise_down_error_support_5             ),      //parameter          surprise_down_error_support_5            = "false",
      .dll_active_report_support_5               (dll_active_report_support_5               ),      //parameter          dll_active_report_support_5              = "false",

      .rx_ei_l0s_5                               (rx_ei_l0s_5                               ),      //parameter          rx_ei_l0s_5                              = "disable",
      .endpoint_l0_latency_5                     (endpoint_l0_latency_5                     ),      //parameter [2:0]    endpoint_l0_latency_5                    = 3'b0,
      .endpoint_l1_latency_5                     (endpoint_l1_latency_5                     ),      //parameter [2:0]    endpoint_l1_latency_5                    = 3'b0,
      .maximum_current_5                         (maximum_current_5                         ),      //parameter          maximum_current_5                        = 3'b0,
      .device_specific_init_5                    (device_specific_init_5                    ),      //parameter          device_specific_init_5                   = "false",

      .expansion_base_address_register_5         (expansion_base_address_register_5         ),      //parameter [31:0]   expansion_base_address_register_5        = 32'b0,

      .ssvid_5                                   (ssvid_5                                   ),      //parameter [15:0]   ssvid_5                                  = 16'b0,
      .ssid_5                                    (ssid_5                                    ),      //parameter [15:0]   ssid_5                                   = 16'b0,

      .flr_capability_5                          (flr_capability_5                          ),      //parameter          flr_capability_5                         = "true",
      .disable_snoop_packet_5                    (disable_snoop_packet_5                    ),      //parameter          disable_snoop_packet_5                   = "false",

      //Function 6

      .vendor_id_6                               (vendor_id_6                               ),      //parameter          vendor_id_6                              = 16'b0001000101110010,
      .device_id_6                               (device_id_6                               ),      //parameter          device_id_6                              = 16'b1,
      .revision_id_6                             (revision_id_6                             ),      //parameter          revision_id_6                            = 8'b1,
      .class_code_6                              (class_code_6                              ),      //parameter          class_code_6                             = 24'b111111110000000000000000,
      .subsystem_vendor_id_6                     (subsystem_vendor_id_6                     ),      //parameter          subsystem_vendor_id_6                    = 16'b0001000101110010,
      .subsystem_device_id_6                     (subsystem_device_id_6                     ),      //parameter          subsystem_device_id_6                    = 16'b1,

      .bar0_io_space_6                           (bar0_io_space_6                           ),      //parameter          bar0_io_space_6                          = "false",
      .bar0_64bit_mem_space_6                    (bar0_64bit_mem_space_6                    ),      //parameter          bar0_64bit_mem_space_6                   = "true",
      .bar0_prefetchable_6                       (bar0_prefetchable_6                       ),      //parameter          bar0_prefetchable_6                      = "true",
      .bar0_size_mask_6                          (bar0_size_mask_6                          ),      //parameter [27:0]   bar0_size_mask_6                         = 28'b1111111111111111111111111111,
      .bar1_io_space_6                           (bar1_io_space_6                           ),      //parameter          bar1_io_space_6                          = "false",
      .bar1_64bit_mem_space_6                    (bar1_64bit_mem_space_6                    ),      //parameter          bar1_64bit_mem_space_6                   = "false",
      .bar1_prefetchable_6                       (bar1_prefetchable_6                       ),      //parameter          bar1_prefetchable_6                      = "false",
      .bar1_size_mask_6                          (bar1_size_mask_6                          ),      //parameter [27:0]   bar1_size_mask_6                         = 28'b0,
      .bar2_io_space_6                           (bar2_io_space_6                           ),      //parameter          bar2_io_space_6                          = "false",
      .bar2_64bit_mem_space_6                    (bar2_64bit_mem_space_6                    ),      //parameter          bar2_64bit_mem_space_6                   = "false",
      .bar2_prefetchable_6                       (bar2_prefetchable_6                       ),      //parameter          bar2_prefetchable_6                      = "false",
      .bar2_size_mask_6                          (bar2_size_mask_6                          ),      //parameter [27:0]   bar2_size_mask_6                         = 28'b0,
      .bar3_io_space_6                           (bar3_io_space_6                           ),      //parameter          bar3_io_space_6                          = "false",
      .bar3_64bit_mem_space_6                    (bar3_64bit_mem_space_6                    ),      //parameter          bar3_64bit_mem_space_6                   = "false",
      .bar3_prefetchable_6                       (bar3_prefetchable_6                       ),      //parameter          bar3_prefetchable_6                      = "false",
      .bar3_size_mask_6                          (bar3_size_mask_6                          ),      //parameter [27:0]   bar3_size_mask_6                         = 28'b0,
      .bar4_io_space_6                           (bar4_io_space_6                           ),      //parameter          bar4_io_space_6                          = "false",
      .bar4_64bit_mem_space_6                    (bar4_64bit_mem_space_6                    ),      //parameter          bar4_64bit_mem_space_6                   = "false",
      .bar4_prefetchable_6                       (bar4_prefetchable_6                       ),      //parameter          bar4_prefetchable_6                      = "false",
      .bar4_size_mask_6                          (bar4_size_mask_6                          ),      //parameter [27:0]   bar4_size_mask_6                         = 28'b0,
      .bar5_io_space_6                           (bar5_io_space_6                           ),      //parameter          bar5_io_space_6                          = "false",
      .bar5_64bit_mem_space_6                    (bar5_64bit_mem_space_6                    ),      //parameter          bar5_64bit_mem_space_6                   = "false",
      .bar5_prefetchable_6                       (bar5_prefetchable_6                       ),      //parameter          bar5_prefetchable_6                      = "false",
      .bar5_size_mask_6                          (bar5_size_mask_6                          ),      //parameter [27:0]   bar5_size_mask_6                         = 28'b0,

      .msi_multi_message_capable_6               (msi_multi_message_capable_6               ),      //parameter          msi_multi_message_capable_6              = "count_4",
      .msi_64bit_addressing_capable_6            (msi_64bit_addressing_capable_6            ),      //parameter          msi_64bit_addressing_capable_6           = "true",
      .msi_masking_capable_6                     (msi_masking_capable_6                     ),      //parameter          msi_masking_capable_6                    = "false",
      .msi_support_6                             (msi_support_6                             ),      //parameter          msi_support_6                            = "true",
      .interrupt_pin_6                           (interrupt_pin_6                           ),      //parameter          interrupt_pin_6                          = "inta",
      .enable_function_msix_support_6            (enable_function_msix_support_6            ),      //parameter          enable_function_msix_support_6           = "true",
      .msix_table_size_6                         (msix_table_size_6                         ),      //parameter [10:0]   msix_table_size_6                        = 11'b0,
      .msix_table_bir_6                          (msix_table_bir_6                          ),      //parameter [2:0]    msix_table_bir_6                         = 3'b0,
      .msix_table_offset_6                       (msix_table_offset_6                       ),      //parameter [28:0]   msix_table_offset_6                      = 29'b0,
      .msix_pba_bir_6                            (msix_pba_bir_6                            ),      //parameter [2:0]    msix_pba_bir_6                           = 3'b0,
      .msix_pba_offset_6                         (msix_pba_offset_6                         ),      //parameter [28:0]   msix_pba_offset_6                        = 29'b0,

      .use_aer_6                                 (use_aer_6                                 ),      //parameter          use_aer_6                                = "false",
      .ecrc_check_capable_6                      (ecrc_check_capable_6                      ),      //parameter          ecrc_check_capable_6                     = "true",
      .ecrc_gen_capable_6                        (ecrc_gen_capable_6                        ),      //parameter          ecrc_gen_capable_6                       = "true",

      .slot_power_scale_6                        (slot_power_scale_6                        ),      //parameter [1:0]    slot_power_scale_6                       = 2'b0,
      .slot_power_limit_6                        (slot_power_limit_6                        ),      //parameter [7:0]    slot_power_limit_6                       = 8'b0,
      .slot_number_6                             (slot_number_6                             ),      //parameter [12:0]   slot_number_6                            = 13'b0,

      .max_payload_size_6                        (max_payload_size_6                        ),      //parameter          max_payload_size_6                       = "payload_512",
      .extend_tag_field_6                        (extend_tag_field_6                        ),      //parameter          extend_tag_field_6                       = "false",
      .completion_timeout_6                      (completion_timeout_6                      ),      //parameter          completion_timeout_6                     = "abcd",
      .enable_completion_timeout_disable_6       (enable_completion_timeout_disable_6       ),      //parameter          enable_completion_timeout_disable_6      = "true",

      .surprise_down_error_support_6             (surprise_down_error_support_6             ),      //parameter          surprise_down_error_support_6            = "false",
      .dll_active_report_support_6               (dll_active_report_support_6               ),      //parameter          dll_active_report_support_6              = "false",

      .rx_ei_l0s_6                               (rx_ei_l0s_6                               ),      //parameter          rx_ei_l0s_6                              = "disable",
      .endpoint_l0_latency_6                     (endpoint_l0_latency_6                     ),      //parameter [2:0]    endpoint_l0_latency_6                    = 3'b0,
      .endpoint_l1_latency_6                     (endpoint_l1_latency_6                     ),      //parameter [2:0]    endpoint_l1_latency_6                    = 3'b0,
      .maximum_current_6                         (maximum_current_6                         ),      //parameter          maximum_current_6                        = 3'b0,
      .device_specific_init_6                    (device_specific_init_6                    ),      //parameter          device_specific_init_6                   = "false",

      .expansion_base_address_register_6         (expansion_base_address_register_6         ),      //parameter [31:0]   expansion_base_address_register_6        = 32'b0,

      .ssvid_6                                   (ssvid_6                                   ),      //parameter [15:0]   ssvid_6                                  = 16'b0,
      .ssid_6                                    (ssid_6                                    ),      //parameter [15:0]   ssid_6                                   = 16'b0,

      .flr_capability_6                          (flr_capability_6                          ),      //parameter          flr_capability_6                         = "true",
      .disable_snoop_packet_6                    (disable_snoop_packet_6                    ),      //parameter          disable_snoop_packet_6                   = "false",

      //Function 7

      .vendor_id_7                               (vendor_id_7                               ),      //parameter          vendor_id_7                              = 16'b0001000101110010,
      .device_id_7                               (device_id_7                               ),      //parameter          device_id_7                              = 16'b1,
      .revision_id_7                             (revision_id_7                             ),      //parameter          revision_id_7                            = 8'b1,
      .class_code_7                              (class_code_7                              ),      //parameter          class_code_7                             = 24'b111111110000000000000000,
      .subsystem_vendor_id_7                     (subsystem_vendor_id_7                     ),      //parameter          subsystem_vendor_id_7                    = 16'b0001000101110010,
      .subsystem_device_id_7                     (subsystem_device_id_7                     ),      //parameter          subsystem_device_id_7                    = 16'b1,

      .bar0_io_space_7                           (bar0_io_space_7                           ),      //parameter          bar0_io_space_7                          = "false",
      .bar0_64bit_mem_space_7                    (bar0_64bit_mem_space_7                    ),      //parameter          bar0_64bit_mem_space_7                   = "true",
      .bar0_prefetchable_7                       (bar0_prefetchable_7                       ),      //parameter          bar0_prefetchable_7                      = "true",
      .bar0_size_mask_7                          (bar0_size_mask_7                          ),      //parameter [27:0]   bar0_size_mask_7                         = 28'b1111111111111111111111111111,
      .bar1_io_space_7                           (bar1_io_space_7                           ),      //parameter          bar1_io_space_7                          = "false",
      .bar1_64bit_mem_space_7                    (bar1_64bit_mem_space_7                    ),      //parameter          bar1_64bit_mem_space_7                   = "false",
      .bar1_prefetchable_7                       (bar1_prefetchable_7                       ),      //parameter          bar1_prefetchable_7                      = "false",
      .bar1_size_mask_7                          (bar1_size_mask_7                          ),      //parameter [27:0]   bar1_size_mask_7                         = 28'b0,
      .bar2_io_space_7                           (bar2_io_space_7                           ),      //parameter          bar2_io_space_7                          = "false",
      .bar2_64bit_mem_space_7                    (bar2_64bit_mem_space_7                    ),      //parameter          bar2_64bit_mem_space_7                   = "false",
      .bar2_prefetchable_7                       (bar2_prefetchable_7                       ),      //parameter          bar2_prefetchable_7                      = "false",
      .bar2_size_mask_7                          (bar2_size_mask_7                          ),      //parameter [27:0]   bar2_size_mask_7                         = 28'b0,
      .bar3_io_space_7                           (bar3_io_space_7                           ),      //parameter          bar3_io_space_7                          = "false",
      .bar3_64bit_mem_space_7                    (bar3_64bit_mem_space_7                    ),      //parameter          bar3_64bit_mem_space_7                   = "false",
      .bar3_prefetchable_7                       (bar3_prefetchable_7                       ),      //parameter          bar3_prefetchable_7                      = "false",
      .bar3_size_mask_7                          (bar3_size_mask_7                          ),      //parameter [27:0]   bar3_size_mask_7                         = 28'b0,
      .bar4_io_space_7                           (bar4_io_space_7                           ),      //parameter          bar4_io_space_7                          = "false",
      .bar4_64bit_mem_space_7                    (bar4_64bit_mem_space_7                    ),      //parameter          bar4_64bit_mem_space_7                   = "false",
      .bar4_prefetchable_7                       (bar4_prefetchable_7                       ),      //parameter          bar4_prefetchable_7                      = "false",
      .bar4_size_mask_7                          (bar4_size_mask_7                          ),      //parameter [27:0]   bar4_size_mask_7                         = 28'b0,
      .bar5_io_space_7                           (bar5_io_space_7                           ),      //parameter          bar5_io_space_7                          = "false",
      .bar5_64bit_mem_space_7                    (bar5_64bit_mem_space_7                    ),      //parameter          bar5_64bit_mem_space_7                   = "false",
      .bar5_prefetchable_7                       (bar5_prefetchable_7                       ),      //parameter          bar5_prefetchable_7                      = "false",
      .bar5_size_mask_7                          (bar5_size_mask_7                          ),      //parameter [27:0]   bar5_size_mask_7                         = 28'b0,

      .msi_multi_message_capable_7               (msi_multi_message_capable_7               ),      //parameter          msi_multi_message_capable_7              = "count_4",
      .msi_64bit_addressing_capable_7            (msi_64bit_addressing_capable_7            ),      //parameter          msi_64bit_addressing_capable_7           = "true",
      .msi_masking_capable_7                     (msi_masking_capable_7                     ),      //parameter          msi_masking_capable_7                    = "false",
      .msi_support_7                             (msi_support_7                             ),      //parameter          msi_support_7                            = "true",
      .interrupt_pin_7                           (interrupt_pin_7                           ),      //parameter          interrupt_pin_7                          = "inta",
      .enable_function_msix_support_7            (enable_function_msix_support_7            ),      //parameter          enable_function_msix_support_7           = "true",
      .msix_table_size_7                         (msix_table_size_7                         ),      //parameter [10:0]   msix_table_size_7                        = 11'b0,
      .msix_table_bir_7                          (msix_table_bir_7                          ),      //parameter [2:0]    msix_table_bir_7                         = 3'b0,
      .msix_table_offset_7                       (msix_table_offset_7                       ),      //parameter [28:0]   msix_table_offset_7                      = 29'b0,
      .msix_pba_bir_7                            (msix_pba_bir_7                            ),      //parameter [2:0]    msix_pba_bir_7                           = 3'b0,
      .msix_pba_offset_7                         (msix_pba_offset_7                         ),      //parameter [28:0]   msix_pba_offset_7                        = 29'b0,

      .use_aer_7                                 (use_aer_7                                 ),      //parameter          use_aer_7                                = "false",
      .ecrc_check_capable_7                      (ecrc_check_capable_7                      ),      //parameter          ecrc_check_capable_7                     = "true",
      .ecrc_gen_capable_7                        (ecrc_gen_capable_7                        ),      //parameter          ecrc_gen_capable_7                       = "true",

      .slot_power_scale_7                        (slot_power_scale_7                        ),      //parameter [1:0]    slot_power_scale_7                       = 2'b0,
      .slot_power_limit_7                        (slot_power_limit_7                        ),      //parameter [7:0]    slot_power_limit_7                       = 8'b0,
      .slot_number_7                             (slot_number_7                             ),      //parameter [12:0]   slot_number_7                            = 13'b0,

      .max_payload_size_7                        (max_payload_size_7                        ),      //parameter          max_payload_size_7                       = "payload_512",
      .extend_tag_field_7                        (extend_tag_field_7                        ),      //parameter          extend_tag_field_7                       = "false",
      .completion_timeout_7                      (completion_timeout_7                      ),      //parameter          completion_timeout_7                     = "abcd",
      .enable_completion_timeout_disable_7       (enable_completion_timeout_disable_7       ),      //parameter          enable_completion_timeout_disable_7      = "true",

      .surprise_down_error_support_7             (surprise_down_error_support_7             ),      //parameter          surprise_down_error_support_7            = "false",
      .dll_active_report_support_7               (dll_active_report_support_7               ),      //parameter          dll_active_report_support_7              = "false",

      .rx_ei_l0s_7                               (rx_ei_l0s_7                               ),      //parameter          rx_ei_l0s_7                              = "disable",
      .endpoint_l0_latency_7                     (endpoint_l0_latency_7                     ),      //parameter [2:0]    endpoint_l0_latency_7                    = 3'b0,
      .endpoint_l1_latency_7                     (endpoint_l1_latency_7                     ),      //parameter [2:0]    endpoint_l1_latency_7                    = 3'b0,
      .maximum_current_7                         (maximum_current_7                         ),      //parameter          maximum_current_7                        = 3'b0,
      .device_specific_init_7                    (device_specific_init_7                    ),      //parameter          device_specific_init_7                   = "false",

      .expansion_base_address_register_7         (expansion_base_address_register_7         ),      //parameter [31:0]   expansion_base_address_register_7        = 32'b0,

      .ssvid_7                                   (ssvid_7                                   ),      //parameter [15:0]   ssvid_7                                  = 16'b0,
      .ssid_7                                    (ssid_7                                    ),      //parameter [15:0]   ssid_7                                   = 16'b0,

      .flr_capability_7                          (flr_capability_7                          ),      //parameter          flr_capability_7                         = "true",
      .disable_snoop_packet_7                    (disable_snoop_packet_7                    ),      //parameter          disable_snoop_packet_7                   = "false",

      .no_soft_reset                             (no_soft_reset                             ),      //parameter          no_soft_reset                            = "false", //TODO Confirm if common across Func0-7
      .d1_support                                (d1_support                                ),      //parameter          d1_support                               = "false",
      .d2_support                                (d2_support                                ),      //parameter          d2_support                               = "false",
      .d0_pme                                    (d0_pme                                    ),      //parameter          d0_pme                                   = "false",
      .d1_pme                                    (d1_pme                                    ),      //parameter          d1_pme                                   = "false",
      .d2_pme                                    (d2_pme                                    ),      //parameter          d2_pme                                   = "false",
      .d3_hot_pme                                (d3_hot_pme                                ),      //parameter          d3_hot_pme                               = "false",
      .d3_cold_pme                               (d3_cold_pme                               ),      //parameter          d3_cold_pme                              = "false",
      .low_priority_vc                           (low_priority_vc                           ),      //parameter          low_priority_vc                          = "single_vc",
      .indicator                                 (indicator                                 ),      //parameter [2:0]    indicator                                = 3'b111,
      .retry_buffer_memory_settings              (retry_buffer_memory_settings              ),      //parameter [15:0]   retry_buffer_memory_settings             = 16'b0000_0000_0000_0110
      .vc0_rx_buffer_memory_settings             (vc0_rx_buffer_memory_settings             ),      //parameter [15:0]   vc0_rx_buffer_memory_settings            = 16'b0000_0000_0000_0110,
      .hot_plug_support                          (hot_plug_support                          ),      //parameter [6:0]    hot_plug_support                         = 7'b0,
      .diffclock_nfts_count                      (diffclock_nfts_count                      ),      //parameter [7:0]    diffclock_nfts_count                     = 8'b1000_0000,
      .sameclock_nfts_count                      (sameclock_nfts_count                      ),      //parameter [7:0]    sameclock_nfts_count                     = 8'b1000_0000,
      .no_command_completed                      (no_command_completed                      ),      //parameter          no_command_completed                     = "true",
      .l2_async_logic                            (l2_async_logic                            ),      //parameter          l2_async_logic                           = "enable",
      .enable_adapter_half_rate_mode             (enable_adapter_half_rate_mode             ),      //parameter          enable_adapter_half_rate_mode            = "false",
      .vc0_clk_enable                            (vc0_clk_enable                            ),      //parameter          vc0_clk_enable                           = "true",
      .register_pipe_signals                     (register_pipe_signals                     ),      //parameter          register_pipe_signals                    = "false",
      .rx_cdc_almost_full                        (rx_cdc_almost_full                        ),      //parameter [3:0]    rx_cdc_almost_full                       = 4'b1100,
      .tx_cdc_almost_full                        (tx_cdc_almost_full                        ),      //parameter [3:0]    tx_cdc_almost_full                       = 4'b1100,
      .rx_l0s_count_idl                          (rx_l0s_count_idl                          ),      //parameter [7:0]    rx_l0s_count_idl                         = 8'b0,
      .cdc_dummy_insert_limit                    (cdc_dummy_insert_limit                    ),      //parameter [3:0]    cdc_dummy_insert_limit                   = 4'b1011,
      .ei_delay_powerdown_count                  (ei_delay_powerdown_count                  ),      //parameter [7:0]    ei_delay_powerdown_count                 = 8'b1010,
      .millisecond_cycle_count                   (millisecond_cycle_count                   ),      //parameter [19:0]   millisecond_cycle_count                  = 20'b00111100101010110100,
      .skp_os_schedule_count                     (skp_os_schedule_count                     ),      //parameter [10:0]   skp_os_schedule_count                    = 11'b0,
      .fc_init_timer                             (fc_init_timer                             ),      //parameter [10:0]   fc_init_timer                            = 11'b10000000000,
      .l01_entry_latency                         (l01_entry_latency                         ),      //parameter [4:0]    l01_entry_latency                        = 5'b11111,
      .flow_control_update_count                 (flow_control_update_count                 ),      //parameter [4:0]    flow_control_update_count                = 5'b11110,
      .flow_control_timeout_count                (flow_control_timeout_count                ),      //parameter [7:0]    flow_control_timeout_count               = 8'b11001000,
      .vc0_rx_flow_ctrl_posted_header            (vc0_rx_flow_ctrl_posted_header            ),      //parameter [7:0]    vc0_rx_flow_ctrl_posted_header           = 8'b00010010,
      .vc0_rx_flow_ctrl_posted_data              (vc0_rx_flow_ctrl_posted_data              ),      //parameter [11:0]   vc0_rx_flow_ctrl_posted_data             = 12'b000001011110,
      .vc0_rx_flow_ctrl_nonposted_header         (vc0_rx_flow_ctrl_nonposted_header         ),      //parameter [7:0]    vc0_rx_flow_ctrl_nonposted_header        = 8'b00100000,
      .vc0_rx_flow_ctrl_nonposted_data           (vc0_rx_flow_ctrl_nonposted_data           ),      //parameter [7:0]    vc0_rx_flow_ctrl_nonposted_data          = 8'b0,
      .vc0_rx_flow_ctrl_compl_header             (vc0_rx_flow_ctrl_compl_header             ),      //parameter [7:0]    vc0_rx_flow_ctrl_compl_header            = 8'b00000000,
      .vc0_rx_flow_ctrl_compl_data               (vc0_rx_flow_ctrl_compl_data               ),      //parameter [11:0]   vc0_rx_flow_ctrl_compl_data              = 12'b000000000000,
      .rx_ptr0_posted_dpram_min                  (rx_ptr0_posted_dpram_min                  ),      //parameter [9:0]    rx_ptr0_posted_dpram_min                 = 10'b0,
      .rx_ptr0_posted_dpram_max                  (rx_ptr0_posted_dpram_max                  ),      //parameter [9:0]    rx_ptr0_posted_dpram_max                 = 10'b0,
      .rx_ptr0_nonposted_dpram_min               (rx_ptr0_nonposted_dpram_min               ),      //parameter [9:0]    rx_ptr0_nonposted_dpram_min              = 10'b0,
      .rx_ptr0_nonposted_dpram_max               (rx_ptr0_nonposted_dpram_max               ),      //parameter [9:0]    rx_ptr0_nonposted_dpram_max              = 10'b0,
      .retry_buffer_last_active_address          (retry_buffer_last_active_address          ),      //parameter [7:0]    retry_buffer_last_active_address         = 8'b11111111,
      .bist_memory_settings                      (bist_memory_settings                      ),      //parameter [74:0]   bist_memory_settings                     = 75'b0,
      .credit_buffer_allocation_aux              (credit_buffer_allocation_aux              ),      //parameter          credit_buffer_allocation_aux             = "balanced",
      .iei_enable_settings                       (iei_enable_settings                       ),      //parameter          iei_enable_settings                      = "gen2_infei_infsd_gen1_infei_sd",
      .vsec_id                                   (vsec_id                                   ),      //parameter [15:0]   vsec_id                                  = 16'b1000101110010,
      .cvp_rate_sel                              (cvp_rate_sel                              ),      //parameter          cvp_rate_sel                             = "full_rate",
      .hard_reset_bypass                         (hard_reset_bypass                         ),      //parameter          hard_reset_bypass                        = "false",
      .cvp_data_compressed                       (cvp_data_compressed                       ),      //parameter          cvp_data_compressed                      = "false",
      .cvp_data_encrypted                        (cvp_data_encrypted                        ),      //parameter          cvp_data_encrypted                       = "false",
      .cvp_mode_reset                            (cvp_mode_reset                            ),      //parameter          cvp_mode_reset                           = "false",
      .cvp_clk_reset                             (cvp_clk_reset                             ),      //parameter          cvp_clk_reset                            = "false",
      .cvp_enable                                (cvp_enable                                ),      //parameter          cvp_enable                               = "cvp_dis"; // "cvp_dis", "cvp_en"
      .vsec_cap                                  (vsec_cap                                  ),      //parameter [3:0]    vsec_cap                                 = 4'b0,
      .jtag_id                                   (jtag_id                                   ),      //parameter [127:0]  jtag_id                                  = 128'b0,
      .user_id                                   (user_id                                   ),      //parameter [15:0]   user_id                                  = 16'b0,

      .disable_auto_crs                          (disable_auto_crs                          ),      //parameter          disable_auto_crs                         = "disable",
      //.plniotri_gate                             (plniotri_gate                             ),      //parameter          plniotri_gate                            = "disable",
      //.mdio_cb_opbit_enable                      (mdio_cb_opbit_enable                      ),      //parameter          mdio_cb_opbit_enable                     = "enable",
      .tx_swing_data                             (tx_swing_data                             ),      //parameter [7:0]    tx_swing_data                            = 8'b0,

      //Pipe related parameters
      .hip_hard_reset                            (hip_hard_reset                            ),      //parameter          hip_hard_reset                           = "disable"
      .rpre_emph_a_val                           (rpre_emph_a_val                           ),
      .rpre_emph_b_val                           (rpre_emph_b_val                           ),
      .rpre_emph_c_val                           (rpre_emph_c_val                           ),
      .rpre_emph_d_val                           (rpre_emph_d_val                           ),
      .rpre_emph_e_val                           (rpre_emph_e_val                           ),
      .rvod_sel_a_val                            (rvod_sel_a_val                            ),
      .rvod_sel_b_val                            (rvod_sel_b_val                            ),
      .rvod_sel_c_val                            (rvod_sel_c_val                            ),
      .rvod_sel_d_val                            (rvod_sel_d_val                            ),
      .rvod_sel_e_val                            (rvod_sel_e_val                            )
      ) altpcie_av_hip_128bit_atom (
       .pipe_mode                              (simu_mode_pipe_tb                  ),
       .por                                    (~npor                              ),
       .reset_status                           (reset_status_int                    ),
      // .flr_reset                              (8'h0                               ),
       .pin_perst                              (pin_perst                          ),
      // .pldclrhipn                             (                                   ),
      // .pldclrpcshipn                          (1'b1                               ),
      // .pldclrpmapcshipn                       (1'b1                               ),
      // .pldperstn                              (1'b1                               ),
       .serdes_pll_locked                      (serdes_pll_locked                  ),
       .pld_clk                                (pld_clk                            ),
       .pclk_in                                (sim_pipe_pclk_in                   ),
       .clk250_out                             (sim_pipe_clk250_out                ),
       .clk500_out                             (sim_pipe_clk500_out                ),
       .refclk                                 (refclk                             ),
       .reconfig_to_xcvr                       (reconfig_to_xcvr                   ),
       .busy_xcvr_reconfig                     (busy_xcvr_reconfig                 ),
       .reconfig_from_xcvr                     (reconfig_from_xcvr                 ),
       .fixedclk_locked                        (fixedclk_locked                    ),
       .mode                                   (mode                               ),
       .test_in                                (testin[39:0]                       ),
       .test_out                               (testout                            ),
       .avmmaddress                            ((hip_reconfig_hwtcl==0)?10'h0:hip_reconfig_address                  ),
       .avmmbyteen                             ((hip_reconfig_hwtcl==0)?2'h0 :hip_reconfig_byte_en                  ),
       .avmmclk                                ((hip_reconfig_hwtcl==0)?1'b0 :hip_reconfig_clk                      ),
       .avmmread                               ((hip_reconfig_hwtcl==0)?1'b0 :hip_reconfig_read                     ),
       .avmmrstn                               ((hip_reconfig_hwtcl==0)?1'b1 :hip_reconfig_rst_n                    ),
       .avmmwrite                              ((hip_reconfig_hwtcl==0)?1'b0 :hip_reconfig_write                    ),
       .avmmwritedata                          ((hip_reconfig_hwtcl==0)?16'h0:hip_reconfig_writedata                ),
       .avmmreaddata                           (hip_reconfig_readdata              ),
       .ser_shift_load                         ((hip_reconfig_hwtcl==0)?1'b1 :ser_shift_load                        ),
       .phystatus0_ext                         (phystatus0                         ),
       .phystatus1_ext                         (phystatus1                         ),
       .phystatus2_ext                         (phystatus2                         ),
       .phystatus3_ext                         (phystatus3                         ),
       .phystatus4_ext                         (phystatus4                         ),
       .phystatus5_ext                         (phystatus5                         ),
       .phystatus6_ext                         (phystatus6                         ),
       .phystatus7_ext                         (phystatus7                         ),
       .rxdata0_ext                            (rxdata0                            ),
       .rxdata1_ext                            (rxdata1                            ),
       .rxdata2_ext                            (rxdata2                            ),
       .rxdata3_ext                            (rxdata3                            ),
       .rxdata4_ext                            (rxdata4                            ),
       .rxdata5_ext                            (rxdata5                            ),
       .rxdata6_ext                            (rxdata6                            ),
       .rxdata7_ext                            (rxdata7                            ),
       .rxdatak0_ext                           (rxdatak0                           ),
       .rxdatak1_ext                           (rxdatak1                           ),
       .rxdatak2_ext                           (rxdatak2                           ),
       .rxdatak3_ext                           (rxdatak3                           ),
       .rxdatak4_ext                           (rxdatak4                           ),
       .rxdatak5_ext                           (rxdatak5                           ),
       .rxdatak6_ext                           (rxdatak6                           ),
       .rxdatak7_ext                           (rxdatak7                           ),
       .rxelecidle0_ext                        (rxelecidle0                        ),
       .rxelecidle1_ext                        (rxelecidle1                        ),
       .rxelecidle2_ext                        (rxelecidle2                        ),
       .rxelecidle3_ext                        (rxelecidle3                        ),
       .rxelecidle4_ext                        (rxelecidle4                        ),
       .rxelecidle5_ext                        (rxelecidle5                        ),
       .rxelecidle6_ext                        (rxelecidle6                        ),
       .rxelecidle7_ext                        (rxelecidle7                        ),
       .rxstatus0_ext                          (rxstatus0                          ),
       .rxstatus1_ext                          (rxstatus1                          ),
       .rxstatus2_ext                          (rxstatus2                          ),
       .rxstatus3_ext                          (rxstatus3                          ),
       .rxstatus4_ext                          (rxstatus4                          ),
       .rxstatus5_ext                          (rxstatus5                          ),
       .rxstatus6_ext                          (rxstatus6                          ),
       .rxstatus7_ext                          (rxstatus7                          ),
       .rxvalid0_ext                           (rxvalid0                           ),
       .rxvalid1_ext                           (rxvalid1                           ),
       .rxvalid2_ext                           (rxvalid2                           ),
       .rxvalid3_ext                           (rxvalid3                           ),
       .rxvalid4_ext                           (rxvalid4                           ),
       .rxvalid5_ext                           (rxvalid5                           ),
       .rxvalid6_ext                           (rxvalid6                           ),
       .rxvalid7_ext                           (rxvalid7                           ),
       .tl_aer_msi_num                         ((port_type_hwtcl=="Root port")?aer_msi_num:5'h0),
       .tl_app_inta_funcnum                    (tl_app_inta_funcnum                ),
       .tl_app_intb_funcnum                    (tl_app_intb_funcnum                ),
       .tl_app_intc_funcnum                    (3'b000                             ),
       .tl_app_intd_funcnum                    (3'b000                             ),
       .tl_app_inta_sts                        (tl_app_inta_sts                    ),
       .tl_app_intb_sts                        (tl_app_intb_sts                    ),
       .tl_app_intc_sts                        (1'b0                               ),
       .tl_app_intd_sts                        (1'b0                               ),
       .tl_app_msi_func                        (app_msi_func                       ),
       .tl_app_msi_num                         (app_msi_num                        ),
       .tl_app_msi_req                         (app_msi_req                        ),
       .tl_app_msi_tc                          (app_msi_tc                         ),
       .tl_hpg_ctrl_er                         (tl_hpg_ctrl_er                     ),
       .tl_pex_msi_num                         ((port_type_hwtcl=="Root port")?pex_msi_num:5'h0),
       .lmi_addr                               (lmi_addr_int                       ),
       .lmi_din                                (lmi_din                            ),
       .lmi_rden                               (lmi_rden                           ),
       .lmi_wren                               (lmi_wren                           ),
       .tl_pm_auxpwr                           (pm_auxpwr                          ),
       .tl_pm_data                             (pm_data                            ),
       .tl_pme_to_cr                           (pme_to_cr                          ),
       .tl_pm_event                            (pm_event                           ),
       .tl_pm_event_func                       (pm_event_func                      ),
       .rx_mask_vc0                            (rx_st_mask                         ),
       .rx_st_ready_vc0                        (rx_st_ready                        ),
       .tx_st_data_vc0                         (tx_st_data_vc0_int                 ),
       .tx_st_sop_vc0                          (tx_st_sop_vc0_int                  ),
       .tx_st_eop_vc0                          (tx_st_eop_vc0_int                  ),
       .tx_st_err_vc0                          (tx_st_err                          ),
       .tx_st_valid_vc0                        (tx_st_valid                        ),
       .mdio_clk                               (gnd_mdio_clk                       ),
       .mdio_dev_addr                          (gnd_mdio_dev_addr                  ),
       .mdio_in                                (gnd_mdio_in                        ),
       .cbhipmdioen                            (gnd_cbhipmdioen                    ),
       .clrrxpath                              (clrrxpath                          ),
       .cpl_err                                (cpl_err                            ),
       .cpl_errfunc                            (cpl_err_func                       ),
       .cpl_pending                            (cpl_pending_int                    ),
       .tl_slotclk_cfg                         ((slotclkcfg_hwtcl==1)?1'b1:1'b0    ),
       .pci_err                                (gnd_pci_err                        ),
       .hipextraclkin                          (gnd_hipextraclkin                  ),
       .hipextrain                             (gnd_hipextrain                     ),
       .bistscanenn                            (gnd_bistscanenn                    ),
       .bistscanin                             (gnd_bistscanin                     ),
       .bisttestenn                            (gnd_bisttestenn                    ),
       .scanmoden                              (gnd_scanmoden                      ),
       .scanenn                                (vdd_scanenn                        ),
       .dl_comclk_reg                          (gnd_dl_comclk_reg                  ),
       .dl_ctrl_link2                          (gnd_dl_ctrl_link2                  ),
       .dl_vc_ctrl                             (gnd_dl_vc_ctrl                     ),
       .dpriorefclkdig                         (gnd_dpriorefclkdig                 ),
       .interfacesel                           ((hip_reconfig_hwtcl==0)?1'b1 :interface_sel),
       .dbgpipex1rx                            (gnd_dbgpipex1rx                    ),
       .eidleinfersel0_ext                     (eidleinfersel0                     ),
       .eidleinfersel1_ext                     (eidleinfersel1                     ),
       .eidleinfersel2_ext                     (eidleinfersel2                     ),
       .eidleinfersel3_ext                     (eidleinfersel3                     ),
       .eidleinfersel4_ext                     (eidleinfersel4                     ),
       .eidleinfersel5_ext                     (eidleinfersel5                     ),
       .eidleinfersel6_ext                     (eidleinfersel6                     ),
       .eidleinfersel7_ext                     (eidleinfersel7                     ),
       .powerdown0_ext                         (powerdown0                         ),
       .powerdown1_ext                         (powerdown1                         ),
       .powerdown2_ext                         (powerdown2                         ),
       .powerdown3_ext                         (powerdown3                         ),
       .powerdown4_ext                         (powerdown4                         ),
       .powerdown5_ext                         (powerdown5                         ),
       .powerdown6_ext                         (powerdown6                         ),
       .powerdown7_ext                         (powerdown7                         ),
       .rxpolarity0_ext                        (rxpolarity0                        ),
       .rxpolarity1_ext                        (rxpolarity1                        ),
       .rxpolarity2_ext                        (rxpolarity2                        ),
       .rxpolarity3_ext                        (rxpolarity3                        ),
       .rxpolarity4_ext                        (rxpolarity4                        ),
       .rxpolarity5_ext                        (rxpolarity5                        ),
       .rxpolarity6_ext                        (rxpolarity6                        ),
       .rxpolarity7_ext                        (rxpolarity7                        ),
       .txcompl0_ext                           (txcompl0                           ),
       .txcompl1_ext                           (txcompl1                           ),
       .txcompl2_ext                           (txcompl2                           ),
       .txcompl3_ext                           (txcompl3                           ),
       .txcompl4_ext                           (txcompl4                           ),
       .txcompl5_ext                           (txcompl5                           ),
       .txcompl6_ext                           (txcompl6                           ),
       .txcompl7_ext                           (txcompl7                           ),
       .txdata0_ext                            (txdata0                            ),
       .txdata1_ext                            (txdata1                            ),
       .txdata2_ext                            (txdata2                            ),
       .txdata3_ext                            (txdata3                            ),
       .txdata4_ext                            (txdata4                            ),
       .txdata5_ext                            (txdata5                            ),
       .txdata6_ext                            (txdata6                            ),
       .txdata7_ext                            (txdata7                            ),
       .txdatak0_ext                           (txdatak0                           ),
       .txdatak1_ext                           (txdatak1                           ),
       .txdatak2_ext                           (txdatak2                           ),
       .txdatak3_ext                           (txdatak3                           ),
       .txdatak4_ext                           (txdatak4                           ),
       .txdatak5_ext                           (txdatak5                           ),
       .txdatak6_ext                           (txdatak6                           ),
       .txdatak7_ext                           (txdatak7                           ),
       .txdatavalid0_ext                       (txdatavalid0                       ),
       .txdatavalid1_ext                       (txdatavalid1                       ),
       .txdatavalid2_ext                       (txdatavalid2                       ),
       .txdatavalid3_ext                       (txdatavalid3                       ),
       .txdatavalid4_ext                       (txdatavalid4                       ),
       .txdatavalid5_ext                       (txdatavalid5                       ),
       .txdatavalid6_ext                       (txdatavalid6                       ),
       .txdatavalid7_ext                       (txdatavalid7                       ),
       .txdetectrx0_ext                        (txdetectrx0                        ),
       .txdetectrx1_ext                        (txdetectrx1                        ),
       .txdetectrx2_ext                        (txdetectrx2                        ),
       .txdetectrx3_ext                        (txdetectrx3                        ),
       .txdetectrx4_ext                        (txdetectrx4                        ),
       .txdetectrx5_ext                        (txdetectrx5                        ),
       .txdetectrx6_ext                        (txdetectrx6                        ),
       .txdetectrx7_ext                        (txdetectrx7                        ),
       .txelecidle0_ext                        (txelecidle0                        ),
       .txelecidle1_ext                        (txelecidle1                        ),
       .txelecidle2_ext                        (txelecidle2                        ),
       .txelecidle3_ext                        (txelecidle3                        ),
       .txelecidle4_ext                        (txelecidle4                        ),
       .txelecidle5_ext                        (txelecidle5                        ),
       .txelecidle6_ext                        (txelecidle6                        ),
       .txelecidle7_ext                        (txelecidle7                        ),
       .txmargin0_ext                          (txmargin0                          ),
       .txmargin1_ext                          (txmargin1                          ),
       .txmargin2_ext                          (txmargin2                          ),
       .txmargin3_ext                          (txmargin3                          ),
       .txmargin4_ext                          (txmargin4                          ),
       .txmargin5_ext                          (txmargin5                          ),
       .txmargin6_ext                          (txmargin6                          ),
       .txmargin7_ext                          (txmargin7                          ),
       .txdeemph0_ext                          (txdeemph0                          ),
       .txdeemph1_ext                          (txdeemph1                          ),
       .txdeemph2_ext                          (txdeemph2                          ),
       .txdeemph3_ext                          (txdeemph3                          ),
       .txdeemph4_ext                          (txdeemph4                          ),
       .txdeemph5_ext                          (txdeemph5                          ),
       .txdeemph6_ext                          (txdeemph6                          ),
       .txdeemph7_ext                          (txdeemph7                          ),
       .txswing0_ext                           (txswing0                           ),
       .txswing1_ext                           (txswing1                           ),
       .txswing2_ext                           (txswing2                           ),
       .txswing3_ext                           (txswing3                           ),
       .txswing4_ext                           (txswing4                           ),
       .txswing5_ext                           (txswing5                           ),
       .txswing6_ext                           (txswing6                           ),
       .txswing7_ext                           (txswing7                           ),
       .pldcoreready                           (pld_core_ready                     ),
       .pld_clk_in_use                         (pld_clk_inuse                      ),
       .coreclkout                             (coreclkout                         ),
       .derr_cor_ext_rcv0                      (derr_cor_ext_rcv0                  ),
       .derr_cor_ext_rpl                       (derr_cor_ext_rpl                   ),
       .derr_rpl                               (derr_rpl                           ),
       .dl_current_speed                       (current_speed_int                  ),
       .dl_ltssm                               (dl_ltssm                           ),
       .dlup_exit                              (dlup_exit                          ),
       .ev128ns                                (ev128ns                            ),
       .ev1us                                  (ev1us                              ),
       .hotrst_exit                            (hotrst_exit                        ),
       .int_status                             (int_status                         ),
       .l2_exit                                (l2_exit                            ),
       .lane_act                               (lane_act                           ),
       .ltssml0state                           (open_ltssml0state                  ),
       .rate                                   (sim_pipe_rate[0]                   ),
       .flr_sts                                (open_flr_sts                       ),
       .r2c_err_ext                            (open_r2c_err_ext                   ),
       .successful_speed_negotiation_int       (open_successful_speed_negotiation_int),
       .tl_app_msi_ack                         (app_msi_ack                        ),
       .lmi_ack                                (lmi_ack                            ),
       .lmi_dout                               (lmi_dout                           ),
       .tl_pme_to_sr                           (pme_to_sr                          ),
       .rx_bar_dec_func_num_vc0                (rx_bar_dec_func_num                ),
       .rx_bar_dec_vc0                         (rx_st_bar                          ),
       .rx_be_vc0                              (rx_be_vc0_int                      ),
       .rx_st_data_vc0                         (rx_st_data_vc0_int                 ),
       .rx_st_sop_vc0                          (rx_st_sop_vc0_int                  ),
       .rx_st_eop_vc0                          (rx_st_eop_vc0_int                  ),
       .rx_st_valid_vc0                        (rx_st_valid                        ),
       .rx_st_err_vc0                          (rx_st_err                          ),
       .rx_fifo_empty_vc0                      (rx_fifo_empty                      ),
       .rx_fifo_full_vc0                       (rx_fifo_full                       ),
       .serr_out                               (serr_out                           ),
       .swdn_wake                              (open_swdn_wake                     ),
       .swup_hotrst                            (open_swup_hotrst                   ),
       .tl_cfg_add                             (tl_cfg_add_int                     ),
       .tl_cfg_ctl                             (tl_cfg_ctl                         ),
       .tl_cfg_ctl_wr                          (tl_cfg_ctl_wr                      ),
       .tl_cfg_sts                             (tl_cfg_sts_int                     ),
       .tl_cfg_sts_wr                          (tl_cfg_sts_wr                      ),
       .tx_cred_datafccp                       (tx_cred_datafccp                   ),
       .tx_cred_datafcnp                       (tx_cred_datafcnp                   ),
       .tx_cred_datafcp                        (tx_cred_datafcp                    ),
       .tx_cred_fchipcons                      (tx_cred_fchipcons                  ),
       .tx_cred_fcinfinite                     (tx_cred_fcinfinite                 ),
       .tx_cred_hdrfccp                        (tx_cred_hdrfccp                    ),
       .tx_cred_hdrfcnp                        (tx_cred_hdrfcnp                    ),
       .tx_cred_hdrfcp                         (tx_cred_hdrfcp                     ),
       .tx_cred_vc0                            (open_tx_cred_vc0                   ),
       .tx_st_ready_vc0                        (tx_st_ready                        ),
       .tx_fifo_empty_vc0                      (tx_fifo_empty                      ),
       .tx_fifo_full_vc0                       (tx_fifo_full                       ),
       .tx_fifo_rdp_vc0                        (tx_fifo_rdp                        ),
       .tx_fifo_wrp_vc0                        (tx_fifo_wrp                        ),
       .mdio_oen_n                             (open_mdio_oen_n                    ),
       .mdio_out                               (open_mdio_out                      ),
       .hipextraclkout                         (open_hipextraclkout                ),
       .hipextraout                            (open_hipextraout                   ),
       .rx_in0                                 (rx_in0                             ),
       .rx_in1                                 (rx_in1                             ),
       .rx_in2                                 (rx_in2                             ),
       .rx_in3                                 (rx_in3                             ),
       .rx_in4                                 (rx_in4                             ),
       .rx_in5                                 (rx_in5                             ),
       .rx_in6                                 (rx_in6                             ),
       .rx_in7                                 (rx_in7                             ),
       .tx_out0                                (tx_out0                            ),
       .tx_out1                                (tx_out1                            ),
       .tx_out2                                (tx_out2                            ),
       .tx_out3                                (tx_out3                            ),
       .tx_out4                                (tx_out4                            ),
       .tx_out5                                (tx_out5                            ),
       .tx_out6                                (tx_out6                            ),
       .tx_out7                                (tx_out7                            ),
       .bistdonearcv0                          (open_bistdonearcv0                 ),
       .bistdonearcv1                          (open_bistdonearcv1                 ),
       .bistdonearpl                           (open_bistdonearpl                  ),
       .bistdonebrcv0                          (open_bistdonebrcv0                 ),
       .bistdonebrcv1                          (open_bistdonebrcv1                 ),
       .bistdonebrpl                           (open_bistdonebrpl                  ),
       .bistpassrcv0                           (open_bistpassrcv0                  ),
       .bistpassrcv1                           (open_bistpassrcv1                  ),
       .bistpassrpl                            (open_bistpassrpl                   ),
       .bistscanoutrcv0                        (open_bistscanoutrcv0               ),
       .bistscanoutrcv1                        (open_bistscanoutrcv1               ),
       .bistscanoutrpl                         (open_bistscanoutrpl                ),
       .wakeoen                                (open_wakeoen                       )
        );

//////////////// SIMULATION-ONLY CONTENTS
//synthesis translate_off
assign testin        = {32'h0, test_in_int[31:0]};
assign simu_mode_pipe_tb = simu_mode_pipe;
//////////////// END SIMULATION-ONLY CONTENTS
//synthesis translate_on
//////////////// SYNTHESIS-ONLY CONTENTS
// The section bellow is for synthesis only and is not used for simulation
// When reserved_debug_hwtcl=1, set SignalProbe access point to
// reservein and testin pins
//synthesis read_comments_as_HDL on
//assign simu_mode_pipe_tb = 1'b0;
//generate begin : g_reserved_debug
//   if (reserved_debug_hwtcl==0) begin
//      assign testin     = {32'h0, test_in_int[31:0]};
//   end
//   else begin
//      sld_mod_ram_rom #(
//              .cvalue            (32'h00000000),
//              .is_data_in_ram    (0),
//              .is_readable       (0),
//              .node_name         (1414090288),
//              .numwords          (1),
//              .shift_count_bits  (6),
//              .width_word        (32),
//              .widthad           (1)
//            ) signalprobe_test_in_lsb ( .data_write(testin[31:0]) );
//
//      sld_mod_ram_rom #(
//              .cvalue            (32'h00000000),
//              .is_data_in_ram    (0),
//              .is_readable       (0),
//              .node_name         (1414090289),
//              .numwords          (1),
//              .shift_count_bits  (6),
//              .width_word        (32),
//              .widthad           (1)
//            ) signalprobe_test_in_msb ( .data_write(testin[63:32]));
//
//   end
//end
//endgenerate
//synthesis read_comments_as_HDL off
//////////////// END SYNTHESIS-ONLY CONTENTS
endmodule


