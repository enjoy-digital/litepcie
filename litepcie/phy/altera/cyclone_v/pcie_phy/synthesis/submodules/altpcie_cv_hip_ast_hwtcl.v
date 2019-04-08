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

`define ALTRPCIE_HWTCL_CV_HIP_ATOM

module altpcie_cv_hip_ast_hwtcl # (
      parameter MIN_AST_BUS_WIDTH                                 = 64,
      parameter MAX_NUM_FUNC_SUPPORT                              = 8,
      parameter num_of_func_hwtcl                                 = MAX_NUM_FUNC_SUPPORT,
      parameter pll_refclk_freq_hwtcl                             = "100 MHz",
      parameter set_pld_clk_x1_625MHz_hwtcl                       = 0,
      parameter enable_slot_register_hwtcl                        = 0,
      parameter slotclkcfg_hwtcl                                  = 1,
      parameter enable_rx_buffer_checking_hwtcl                   = "false",
      parameter single_rx_detect_hwtcl                            = 0,
      parameter use_crc_forwarding_hwtcl                          = 0,
      parameter gen12_lane_rate_mode_hwtcl                        = "Gen1 (2.5 Gbps)",
      parameter lane_mask_hwtcl                                   = "x4",
      parameter disable_link_x2_support_hwtcl                     = "false",
      parameter ast_width_hwtcl                                   = "rx_tx_64",
      parameter port_link_number_hwtcl                            = 1,
      parameter device_number_hwtcl                               = 0,
      parameter bypass_clk_switch_hwtcl                           = "disable",
      parameter pipex1_debug_sel_hwtcl                            = "disable",
      parameter pclk_out_sel_hwtcl                                = "pclk",
      parameter use_tl_cfg_sync_hwtcl                             = 0,

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

      parameter flr_capability_0_hwtcl                              = "true",
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

      parameter flr_capability_1_hwtcl                              = "true",
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

      parameter flr_capability_2_hwtcl                              = "true",
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

      parameter flr_capability_3_hwtcl                              = "true",
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

      parameter flr_capability_4_hwtcl                              = "true",
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

      parameter flr_capability_5_hwtcl                              = "true",
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

      parameter flr_capability_6_hwtcl                              = "true",
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

      parameter flr_capability_7_hwtcl                              = "true",
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
      parameter enable_adapter_half_rate_mode_hwtcl               = "true",
      parameter vc0_clk_enable_hwtcl                              = "true",
      parameter register_pipe_signals_hwtcl                       = "true",
      parameter io_window_addr_width_hwtcl                        = 0,
      parameter prefetchable_mem_window_addr_width_hwtcl          = 0,
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
      parameter ACDS_VERSION_HWTCL                                = "",
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
      output                reset_status,
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
      output               fixedclk_locked,

      // HIP control signals
      input  [4 : 0]       tl_hpg_ctrl_er,

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

      input [port_width_data_hwtcl-1 : 0]    tx_st_data,
      input                                  tx_st_eop,
      input                                  tx_st_sop,
      input                                  tx_st_empty,
      input                                  tx_st_valid,
      input                                  tx_st_err,

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
   clogb2 =0;
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


altpcie_av_hip_ast_hwtcl # (
      .MIN_AST_BUS_WIDTH                                                (MIN_AST_BUS_WIDTH                                       ),
      .MAX_NUM_FUNC_SUPPORT                                             (MAX_NUM_FUNC_SUPPORT                                    ),
      .device_family                                                    ("Cyclone V"                                             ),
      .num_of_func_hwtcl                                                (num_of_func_hwtcl                                       ),
      .pll_refclk_freq_hwtcl                                            (pll_refclk_freq_hwtcl                                   ),
      .set_pld_clk_x1_625MHz_hwtcl                                      (set_pld_clk_x1_625MHz_hwtcl                             ),
      .enable_slot_register_hwtcl                                       (enable_slot_register_hwtcl                              ),
      .slotclkcfg_hwtcl                                                 (slotclkcfg_hwtcl                                        ),
      .enable_rx_buffer_checking_hwtcl                                  (enable_rx_buffer_checking_hwtcl                         ),
      .single_rx_detect_hwtcl                                           (single_rx_detect_hwtcl                                  ),
      .use_crc_forwarding_hwtcl                                         (use_crc_forwarding_hwtcl                                ),
      .gen12_lane_rate_mode_hwtcl                                       (gen12_lane_rate_mode_hwtcl                              ),
      .lane_mask_hwtcl                                                  (lane_mask_hwtcl                                         ),
      .disable_link_x2_support_hwtcl                                    (disable_link_x2_support_hwtcl                           ),
      .ast_width_hwtcl                                                  (ast_width_hwtcl                                         ),
      .port_link_number_hwtcl                                           (port_link_number_hwtcl                                  ),
      .device_number_hwtcl                                              (device_number_hwtcl                                     ),
      .bypass_clk_switch_hwtcl                                          (bypass_clk_switch_hwtcl                                 ),
      .pipex1_debug_sel_hwtcl                                           (pipex1_debug_sel_hwtcl                                  ),
      .pclk_out_sel_hwtcl                                               (pclk_out_sel_hwtcl                                      ),
      .use_tl_cfg_sync_hwtcl                                            (use_tl_cfg_sync_hwtcl                                   ),
      .porttype_func0_hwtcl                                             (porttype_func0_hwtcl                                    ),
      .porttype_func1_hwtcl                                             (porttype_func1_hwtcl                                    ),
      .porttype_func2_hwtcl                                             (porttype_func2_hwtcl                                    ),
      .porttype_func3_hwtcl                                             (porttype_func3_hwtcl                                    ),
      .porttype_func4_hwtcl                                             (porttype_func4_hwtcl                                    ),
      .porttype_func5_hwtcl                                             (porttype_func5_hwtcl                                    ),
      .porttype_func6_hwtcl                                             (porttype_func6_hwtcl                                    ),
      .porttype_func7_hwtcl                                             (porttype_func7_hwtcl                                    ),
      .vendor_id_0_hwtcl                                                (vendor_id_0_hwtcl                                       ),
      .device_id_0_hwtcl                                                (device_id_0_hwtcl                                       ),
      .revision_id_0_hwtcl                                              (revision_id_0_hwtcl                                     ),
      .class_code_0_hwtcl                                               (class_code_0_hwtcl                                      ),
      .subsystem_vendor_id_0_hwtcl                                      (subsystem_vendor_id_0_hwtcl                             ),
      .subsystem_device_id_0_hwtcl                                      (subsystem_device_id_0_hwtcl                             ),
      .bar0_io_space_0_hwtcl                                            (bar0_io_space_0_hwtcl                                   ),
      .bar0_64bit_mem_space_0_hwtcl                                     (bar0_64bit_mem_space_0_hwtcl                            ),
      .bar0_prefetchable_0_hwtcl                                        (bar0_prefetchable_0_hwtcl                               ),
      .bar0_size_mask_0_hwtcl                                           (bar0_size_mask_0_hwtcl                                  ),
      .bar1_io_space_0_hwtcl                                            (bar1_io_space_0_hwtcl                                   ),
      .bar1_64bit_mem_space_0_hwtcl                                     (bar1_64bit_mem_space_0_hwtcl                            ),
      .bar1_prefetchable_0_hwtcl                                        (bar1_prefetchable_0_hwtcl                               ),
      .bar1_size_mask_0_hwtcl                                           (bar1_size_mask_0_hwtcl                                  ),
      .bar2_io_space_0_hwtcl                                            (bar2_io_space_0_hwtcl                                   ),
      .bar2_64bit_mem_space_0_hwtcl                                     (bar2_64bit_mem_space_0_hwtcl                            ),
      .bar2_prefetchable_0_hwtcl                                        (bar2_prefetchable_0_hwtcl                               ),
      .bar2_size_mask_0_hwtcl                                           (bar2_size_mask_0_hwtcl                                  ),
      .bar3_io_space_0_hwtcl                                            (bar3_io_space_0_hwtcl                                   ),
      .bar3_64bit_mem_space_0_hwtcl                                     (bar3_64bit_mem_space_0_hwtcl                            ),
      .bar3_prefetchable_0_hwtcl                                        (bar3_prefetchable_0_hwtcl                               ),
      .bar3_size_mask_0_hwtcl                                           (bar3_size_mask_0_hwtcl                                  ),
      .bar4_io_space_0_hwtcl                                            (bar4_io_space_0_hwtcl                                   ),
      .bar4_64bit_mem_space_0_hwtcl                                     (bar4_64bit_mem_space_0_hwtcl                            ),
      .bar4_prefetchable_0_hwtcl                                        (bar4_prefetchable_0_hwtcl                               ),
      .bar4_size_mask_0_hwtcl                                           (bar4_size_mask_0_hwtcl                                  ),
      .bar5_io_space_0_hwtcl                                            (bar5_io_space_0_hwtcl                                   ),
      .bar5_64bit_mem_space_0_hwtcl                                     (bar5_64bit_mem_space_0_hwtcl                            ),
      .bar5_prefetchable_0_hwtcl                                        (bar5_prefetchable_0_hwtcl                               ),
      .bar5_size_mask_0_hwtcl                                           (bar5_size_mask_0_hwtcl                                  ),
      .expansion_base_address_register_0_hwtcl                          (expansion_base_address_register_0_hwtcl                 ),
      .msi_multi_message_capable_0_hwtcl                                (msi_multi_message_capable_0_hwtcl                       ),
      .msi_64bit_addressing_capable_0_hwtcl                             (msi_64bit_addressing_capable_0_hwtcl                    ),
      .msi_masking_capable_0_hwtcl                                      (msi_masking_capable_0_hwtcl                             ),
      .msi_support_0_hwtcl                                              (msi_support_0_hwtcl                                     ),
      .interrupt_pin_0_hwtcl                                            (interrupt_pin_0_hwtcl                                   ),
      .enable_function_msix_support_0_hwtcl                             (enable_function_msix_support_0_hwtcl                    ),
      .msix_table_size_0_hwtcl                                          (msix_table_size_0_hwtcl                                 ),
      .msix_table_bir_0_hwtcl                                           (msix_table_bir_0_hwtcl                                  ),
      .msix_table_offset_0_hwtcl                                        (msix_table_offset_0_hwtcl                               ),
      .msix_pba_bir_0_hwtcl                                             (msix_pba_bir_0_hwtcl                                    ),
      .msix_pba_offset_0_hwtcl                                          (msix_pba_offset_0_hwtcl                                 ),
      .use_aer_0_hwtcl                                                  (use_aer_0_hwtcl                                         ),
      .ecrc_check_capable_0_hwtcl                                       (ecrc_check_capable_0_hwtcl                              ),
      .ecrc_gen_capable_0_hwtcl                                         (ecrc_gen_capable_0_hwtcl                                ),
      .slot_power_scale_0_hwtcl                                         (slot_power_scale_0_hwtcl                                ),
      .slot_power_limit_0_hwtcl                                         (slot_power_limit_0_hwtcl                                ),
      .slot_number_0_hwtcl                                              (slot_number_0_hwtcl                                     ),
      .max_payload_size_0_hwtcl                                         (max_payload_size_0_hwtcl                                ),
      .extend_tag_field_0_hwtcl                                         (extend_tag_field_0_hwtcl                                ),
      .completion_timeout_0_hwtcl                                       (completion_timeout_0_hwtcl                              ),
      .enable_completion_timeout_disable_0_hwtcl                        (enable_completion_timeout_disable_0_hwtcl               ),
      .surprise_down_error_support_0_hwtcl                              (surprise_down_error_support_0_hwtcl                     ),
      .dll_active_report_support_0_hwtcl                                (dll_active_report_support_0_hwtcl                       ),
      .rx_ei_l0s_0_hwtcl                                                (rx_ei_l0s_0_hwtcl                                       ),
      .endpoint_l0_latency_0_hwtcl                                      (endpoint_l0_latency_0_hwtcl                             ),
      .endpoint_l1_latency_0_hwtcl                                      (endpoint_l1_latency_0_hwtcl                             ),
      .maximum_current_0_hwtcl                                          (maximum_current_0_hwtcl                                 ),
      .device_specific_init_0_hwtcl                                     (device_specific_init_0_hwtcl                            ),
      .ssvid_0_hwtcl                                                    (ssvid_0_hwtcl                                           ),
      .ssid_0_hwtcl                                                     (ssid_0_hwtcl                                            ),
      .bridge_port_vga_enable_0_hwtcl                                   (bridge_port_vga_enable_0_hwtcl                          ),
      .bridge_port_ssid_support_0_hwtcl                                 (bridge_port_ssid_support_0_hwtcl                        ),
      .flr_capability_0_hwtcl                                           (flr_capability_0_hwtcl                                  ),
      .disable_snoop_packet_0_hwtcl                                     (disable_snoop_packet_0_hwtcl                            ),
      .vendor_id_1_hwtcl                                                (vendor_id_1_hwtcl                                       ),
      .device_id_1_hwtcl                                                (device_id_1_hwtcl                                       ),
      .revision_id_1_hwtcl                                              (revision_id_1_hwtcl                                     ),
      .class_code_1_hwtcl                                               (class_code_1_hwtcl                                      ),
      .subsystem_vendor_id_1_hwtcl                                      (subsystem_vendor_id_1_hwtcl                             ),
      .subsystem_device_id_1_hwtcl                                      (subsystem_device_id_1_hwtcl                             ),
      .bar0_io_space_1_hwtcl                                            (bar0_io_space_1_hwtcl                                   ),
      .bar0_64bit_mem_space_1_hwtcl                                     (bar0_64bit_mem_space_1_hwtcl                            ),
      .bar0_prefetchable_1_hwtcl                                        (bar0_prefetchable_1_hwtcl                               ),
      .bar0_size_mask_1_hwtcl                                           (bar0_size_mask_1_hwtcl                                  ),
      .bar1_io_space_1_hwtcl                                            (bar1_io_space_1_hwtcl                                   ),
      .bar1_64bit_mem_space_1_hwtcl                                     (bar1_64bit_mem_space_1_hwtcl                            ),
      .bar1_prefetchable_1_hwtcl                                        (bar1_prefetchable_1_hwtcl                               ),
      .bar1_size_mask_1_hwtcl                                           (bar1_size_mask_1_hwtcl                                  ),
      .bar2_io_space_1_hwtcl                                            (bar2_io_space_1_hwtcl                                   ),
      .bar2_64bit_mem_space_1_hwtcl                                     (bar2_64bit_mem_space_1_hwtcl                            ),
      .bar2_prefetchable_1_hwtcl                                        (bar2_prefetchable_1_hwtcl                               ),
      .bar2_size_mask_1_hwtcl                                           (bar2_size_mask_1_hwtcl                                  ),
      .bar3_io_space_1_hwtcl                                            (bar3_io_space_1_hwtcl                                   ),
      .bar3_64bit_mem_space_1_hwtcl                                     (bar3_64bit_mem_space_1_hwtcl                            ),
      .bar3_prefetchable_1_hwtcl                                        (bar3_prefetchable_1_hwtcl                               ),
      .bar3_size_mask_1_hwtcl                                           (bar3_size_mask_1_hwtcl                                  ),
      .bar4_io_space_1_hwtcl                                            (bar4_io_space_1_hwtcl                                   ),
      .bar4_64bit_mem_space_1_hwtcl                                     (bar4_64bit_mem_space_1_hwtcl                            ),
      .bar4_prefetchable_1_hwtcl                                        (bar4_prefetchable_1_hwtcl                               ),
      .bar4_size_mask_1_hwtcl                                           (bar4_size_mask_1_hwtcl                                  ),
      .bar5_io_space_1_hwtcl                                            (bar5_io_space_1_hwtcl                                   ),
      .bar5_64bit_mem_space_1_hwtcl                                     (bar5_64bit_mem_space_1_hwtcl                            ),
      .bar5_prefetchable_1_hwtcl                                        (bar5_prefetchable_1_hwtcl                               ),
      .bar5_size_mask_1_hwtcl                                           (bar5_size_mask_1_hwtcl                                  ),
      .expansion_base_address_register_1_hwtcl                          (expansion_base_address_register_1_hwtcl                 ),
      .msi_multi_message_capable_1_hwtcl                                (msi_multi_message_capable_1_hwtcl                       ),
      .msi_64bit_addressing_capable_1_hwtcl                             (msi_64bit_addressing_capable_1_hwtcl                    ),
      .msi_masking_capable_1_hwtcl                                      (msi_masking_capable_1_hwtcl                             ),
      .msi_support_1_hwtcl                                              (msi_support_1_hwtcl                                     ),
      .interrupt_pin_1_hwtcl                                            (interrupt_pin_1_hwtcl                                   ),
      .enable_function_msix_support_1_hwtcl                             (enable_function_msix_support_1_hwtcl                    ),
      .msix_table_size_1_hwtcl                                          (msix_table_size_1_hwtcl                                 ),
      .msix_table_bir_1_hwtcl                                           (msix_table_bir_1_hwtcl                                  ),
      .msix_table_offset_1_hwtcl                                        (msix_table_offset_1_hwtcl                               ),
      .msix_pba_bir_1_hwtcl                                             (msix_pba_bir_1_hwtcl                                    ),
      .msix_pba_offset_1_hwtcl                                          (msix_pba_offset_1_hwtcl                                 ),
      .use_aer_1_hwtcl                                                  (use_aer_1_hwtcl                                         ),
      .ecrc_check_capable_1_hwtcl                                       (ecrc_check_capable_1_hwtcl                              ),
      .ecrc_gen_capable_1_hwtcl                                         (ecrc_gen_capable_1_hwtcl                                ),
      .slot_power_scale_1_hwtcl                                         (slot_power_scale_1_hwtcl                                ),
      .slot_power_limit_1_hwtcl                                         (slot_power_limit_1_hwtcl                                ),
      .slot_number_1_hwtcl                                              (slot_number_1_hwtcl                                     ),
      .max_payload_size_1_hwtcl                                         (max_payload_size_1_hwtcl                                ),
      .extend_tag_field_1_hwtcl                                         (extend_tag_field_1_hwtcl                                ),
      .completion_timeout_1_hwtcl                                       (completion_timeout_1_hwtcl                              ),
      .enable_completion_timeout_disable_1_hwtcl                        (enable_completion_timeout_disable_1_hwtcl               ),
      .surprise_down_error_support_1_hwtcl                              (surprise_down_error_support_1_hwtcl                     ),
      .dll_active_report_support_1_hwtcl                                (dll_active_report_support_1_hwtcl                       ),
      .rx_ei_l0s_1_hwtcl                                                (rx_ei_l0s_1_hwtcl                                       ),
      .endpoint_l0_latency_1_hwtcl                                      (endpoint_l0_latency_1_hwtcl                             ),
      .endpoint_l1_latency_1_hwtcl                                      (endpoint_l1_latency_1_hwtcl                             ),
      .maximum_current_1_hwtcl                                          (maximum_current_1_hwtcl                                 ),
      .device_specific_init_1_hwtcl                                     (device_specific_init_1_hwtcl                            ),
      .ssvid_1_hwtcl                                                    (ssvid_1_hwtcl                                           ),
      .ssid_1_hwtcl                                                     (ssid_1_hwtcl                                            ),
      .bridge_port_vga_enable_1_hwtcl                                   (bridge_port_vga_enable_1_hwtcl                          ),
      .bridge_port_ssid_support_1_hwtcl                                 (bridge_port_ssid_support_1_hwtcl                        ),
      .flr_capability_1_hwtcl                                           (flr_capability_1_hwtcl                                  ),
      .disable_snoop_packet_1_hwtcl                                     (disable_snoop_packet_1_hwtcl                            ),
      .vendor_id_2_hwtcl                                                (vendor_id_2_hwtcl                                       ),
      .device_id_2_hwtcl                                                (device_id_2_hwtcl                                       ),
      .revision_id_2_hwtcl                                              (revision_id_2_hwtcl                                     ),
      .class_code_2_hwtcl                                               (class_code_2_hwtcl                                      ),
      .subsystem_vendor_id_2_hwtcl                                      (subsystem_vendor_id_2_hwtcl                             ),
      .subsystem_device_id_2_hwtcl                                      (subsystem_device_id_2_hwtcl                             ),
      .bar0_io_space_2_hwtcl                                            (bar0_io_space_2_hwtcl                                   ),
      .bar0_64bit_mem_space_2_hwtcl                                     (bar0_64bit_mem_space_2_hwtcl                            ),
      .bar0_prefetchable_2_hwtcl                                        (bar0_prefetchable_2_hwtcl                               ),
      .bar0_size_mask_2_hwtcl                                           (bar0_size_mask_2_hwtcl                                  ),
      .bar1_io_space_2_hwtcl                                            (bar1_io_space_2_hwtcl                                   ),
      .bar1_64bit_mem_space_2_hwtcl                                     (bar1_64bit_mem_space_2_hwtcl                            ),
      .bar1_prefetchable_2_hwtcl                                        (bar1_prefetchable_2_hwtcl                               ),
      .bar1_size_mask_2_hwtcl                                           (bar1_size_mask_2_hwtcl                                  ),
      .bar2_io_space_2_hwtcl                                            (bar2_io_space_2_hwtcl                                   ),
      .bar2_64bit_mem_space_2_hwtcl                                     (bar2_64bit_mem_space_2_hwtcl                            ),
      .bar2_prefetchable_2_hwtcl                                        (bar2_prefetchable_2_hwtcl                               ),
      .bar2_size_mask_2_hwtcl                                           (bar2_size_mask_2_hwtcl                                  ),
      .bar3_io_space_2_hwtcl                                            (bar3_io_space_2_hwtcl                                   ),
      .bar3_64bit_mem_space_2_hwtcl                                     (bar3_64bit_mem_space_2_hwtcl                            ),
      .bar3_prefetchable_2_hwtcl                                        (bar3_prefetchable_2_hwtcl                               ),
      .bar3_size_mask_2_hwtcl                                           (bar3_size_mask_2_hwtcl                                  ),
      .bar4_io_space_2_hwtcl                                            (bar4_io_space_2_hwtcl                                   ),
      .bar4_64bit_mem_space_2_hwtcl                                     (bar4_64bit_mem_space_2_hwtcl                            ),
      .bar4_prefetchable_2_hwtcl                                        (bar4_prefetchable_2_hwtcl                               ),
      .bar4_size_mask_2_hwtcl                                           (bar4_size_mask_2_hwtcl                                  ),
      .bar5_io_space_2_hwtcl                                            (bar5_io_space_2_hwtcl                                   ),
      .bar5_64bit_mem_space_2_hwtcl                                     (bar5_64bit_mem_space_2_hwtcl                            ),
      .bar5_prefetchable_2_hwtcl                                        (bar5_prefetchable_2_hwtcl                               ),
      .bar5_size_mask_2_hwtcl                                           (bar5_size_mask_2_hwtcl                                  ),
      .expansion_base_address_register_2_hwtcl                          (expansion_base_address_register_2_hwtcl                 ),
      .msi_multi_message_capable_2_hwtcl                                (msi_multi_message_capable_2_hwtcl                       ),
      .msi_64bit_addressing_capable_2_hwtcl                             (msi_64bit_addressing_capable_2_hwtcl                    ),
      .msi_masking_capable_2_hwtcl                                      (msi_masking_capable_2_hwtcl                             ),
      .msi_support_2_hwtcl                                              (msi_support_2_hwtcl                                     ),
      .interrupt_pin_2_hwtcl                                            (interrupt_pin_2_hwtcl                                   ),
      .enable_function_msix_support_2_hwtcl                             (enable_function_msix_support_2_hwtcl                    ),
      .msix_table_size_2_hwtcl                                          (msix_table_size_2_hwtcl                                 ),
      .msix_table_bir_2_hwtcl                                           (msix_table_bir_2_hwtcl                                  ),
      .msix_table_offset_2_hwtcl                                        (msix_table_offset_2_hwtcl                               ),
      .msix_pba_bir_2_hwtcl                                             (msix_pba_bir_2_hwtcl                                    ),
      .msix_pba_offset_2_hwtcl                                          (msix_pba_offset_2_hwtcl                                 ),
      .use_aer_2_hwtcl                                                  (use_aer_2_hwtcl                                         ),
      .ecrc_check_capable_2_hwtcl                                       (ecrc_check_capable_2_hwtcl                              ),
      .ecrc_gen_capable_2_hwtcl                                         (ecrc_gen_capable_2_hwtcl                                ),
      .slot_power_scale_2_hwtcl                                         (slot_power_scale_2_hwtcl                                ),
      .slot_power_limit_2_hwtcl                                         (slot_power_limit_2_hwtcl                                ),
      .slot_number_2_hwtcl                                              (slot_number_2_hwtcl                                     ),
      .max_payload_size_2_hwtcl                                         (max_payload_size_2_hwtcl                                ),
      .extend_tag_field_2_hwtcl                                         (extend_tag_field_2_hwtcl                                ),
      .completion_timeout_2_hwtcl                                       (completion_timeout_2_hwtcl                              ),
      .enable_completion_timeout_disable_2_hwtcl                        (enable_completion_timeout_disable_2_hwtcl               ),
      .surprise_down_error_support_2_hwtcl                              (surprise_down_error_support_2_hwtcl                     ),
      .dll_active_report_support_2_hwtcl                                (dll_active_report_support_2_hwtcl                       ),
      .rx_ei_l0s_2_hwtcl                                                (rx_ei_l0s_2_hwtcl                                       ),
      .endpoint_l0_latency_2_hwtcl                                      (endpoint_l0_latency_2_hwtcl                             ),
      .endpoint_l1_latency_2_hwtcl                                      (endpoint_l1_latency_2_hwtcl                             ),
      .maximum_current_2_hwtcl                                          (maximum_current_2_hwtcl                                 ),
      .device_specific_init_2_hwtcl                                     (device_specific_init_2_hwtcl                            ),
      .ssvid_2_hwtcl                                                    (ssvid_2_hwtcl                                           ),
      .ssid_2_hwtcl                                                     (ssid_2_hwtcl                                            ),
      .bridge_port_vga_enable_2_hwtcl                                   (bridge_port_vga_enable_2_hwtcl                          ),
      .bridge_port_ssid_support_2_hwtcl                                 (bridge_port_ssid_support_2_hwtcl                        ),
      .flr_capability_2_hwtcl                                           (flr_capability_2_hwtcl                                  ),
      .disable_snoop_packet_2_hwtcl                                     (disable_snoop_packet_2_hwtcl                            ),
      .vendor_id_3_hwtcl                                                (vendor_id_3_hwtcl                                       ),
      .device_id_3_hwtcl                                                (device_id_3_hwtcl                                       ),
      .revision_id_3_hwtcl                                              (revision_id_3_hwtcl                                     ),
      .class_code_3_hwtcl                                               (class_code_3_hwtcl                                      ),
      .subsystem_vendor_id_3_hwtcl                                      (subsystem_vendor_id_3_hwtcl                             ),
      .subsystem_device_id_3_hwtcl                                      (subsystem_device_id_3_hwtcl                             ),
      .bar0_io_space_3_hwtcl                                            (bar0_io_space_3_hwtcl                                   ),
      .bar0_64bit_mem_space_3_hwtcl                                     (bar0_64bit_mem_space_3_hwtcl                            ),
      .bar0_prefetchable_3_hwtcl                                        (bar0_prefetchable_3_hwtcl                               ),
      .bar0_size_mask_3_hwtcl                                           (bar0_size_mask_3_hwtcl                                  ),
      .bar1_io_space_3_hwtcl                                            (bar1_io_space_3_hwtcl                                   ),
      .bar1_64bit_mem_space_3_hwtcl                                     (bar1_64bit_mem_space_3_hwtcl                            ),
      .bar1_prefetchable_3_hwtcl                                        (bar1_prefetchable_3_hwtcl                               ),
      .bar1_size_mask_3_hwtcl                                           (bar1_size_mask_3_hwtcl                                  ),
      .bar2_io_space_3_hwtcl                                            (bar2_io_space_3_hwtcl                                   ),
      .bar2_64bit_mem_space_3_hwtcl                                     (bar2_64bit_mem_space_3_hwtcl                            ),
      .bar2_prefetchable_3_hwtcl                                        (bar2_prefetchable_3_hwtcl                               ),
      .bar2_size_mask_3_hwtcl                                           (bar2_size_mask_3_hwtcl                                  ),
      .bar3_io_space_3_hwtcl                                            (bar3_io_space_3_hwtcl                                   ),
      .bar3_64bit_mem_space_3_hwtcl                                     (bar3_64bit_mem_space_3_hwtcl                            ),
      .bar3_prefetchable_3_hwtcl                                        (bar3_prefetchable_3_hwtcl                               ),
      .bar3_size_mask_3_hwtcl                                           (bar3_size_mask_3_hwtcl                                  ),
      .bar4_io_space_3_hwtcl                                            (bar4_io_space_3_hwtcl                                   ),
      .bar4_64bit_mem_space_3_hwtcl                                     (bar4_64bit_mem_space_3_hwtcl                            ),
      .bar4_prefetchable_3_hwtcl                                        (bar4_prefetchable_3_hwtcl                               ),
      .bar4_size_mask_3_hwtcl                                           (bar4_size_mask_3_hwtcl                                  ),
      .bar5_io_space_3_hwtcl                                            (bar5_io_space_3_hwtcl                                   ),
      .bar5_64bit_mem_space_3_hwtcl                                     (bar5_64bit_mem_space_3_hwtcl                            ),
      .bar5_prefetchable_3_hwtcl                                        (bar5_prefetchable_3_hwtcl                               ),
      .bar5_size_mask_3_hwtcl                                           (bar5_size_mask_3_hwtcl                                  ),
      .expansion_base_address_register_3_hwtcl                          (expansion_base_address_register_3_hwtcl                 ),
      .msi_multi_message_capable_3_hwtcl                                (msi_multi_message_capable_3_hwtcl                       ),
      .msi_64bit_addressing_capable_3_hwtcl                             (msi_64bit_addressing_capable_3_hwtcl                    ),
      .msi_masking_capable_3_hwtcl                                      (msi_masking_capable_3_hwtcl                             ),
      .msi_support_3_hwtcl                                              (msi_support_3_hwtcl                                     ),
      .interrupt_pin_3_hwtcl                                            (interrupt_pin_3_hwtcl                                   ),
      .enable_function_msix_support_3_hwtcl                             (enable_function_msix_support_3_hwtcl                    ),
      .msix_table_size_3_hwtcl                                          (msix_table_size_3_hwtcl                                 ),
      .msix_table_bir_3_hwtcl                                           (msix_table_bir_3_hwtcl                                  ),
      .msix_table_offset_3_hwtcl                                        (msix_table_offset_3_hwtcl                               ),
      .msix_pba_bir_3_hwtcl                                             (msix_pba_bir_3_hwtcl                                    ),
      .msix_pba_offset_3_hwtcl                                          (msix_pba_offset_3_hwtcl                                 ),
      .use_aer_3_hwtcl                                                  (use_aer_3_hwtcl                                         ),
      .ecrc_check_capable_3_hwtcl                                       (ecrc_check_capable_3_hwtcl                              ),
      .ecrc_gen_capable_3_hwtcl                                         (ecrc_gen_capable_3_hwtcl                                ),
      .slot_power_scale_3_hwtcl                                         (slot_power_scale_3_hwtcl                                ),
      .slot_power_limit_3_hwtcl                                         (slot_power_limit_3_hwtcl                                ),
      .slot_number_3_hwtcl                                              (slot_number_3_hwtcl                                     ),
      .max_payload_size_3_hwtcl                                         (max_payload_size_3_hwtcl                                ),
      .extend_tag_field_3_hwtcl                                         (extend_tag_field_3_hwtcl                                ),
      .completion_timeout_3_hwtcl                                       (completion_timeout_3_hwtcl                              ),
      .enable_completion_timeout_disable_3_hwtcl                        (enable_completion_timeout_disable_3_hwtcl               ),
      .surprise_down_error_support_3_hwtcl                              (surprise_down_error_support_3_hwtcl                     ),
      .dll_active_report_support_3_hwtcl                                (dll_active_report_support_3_hwtcl                       ),
      .rx_ei_l0s_3_hwtcl                                                (rx_ei_l0s_3_hwtcl                                       ),
      .endpoint_l0_latency_3_hwtcl                                      (endpoint_l0_latency_3_hwtcl                             ),
      .endpoint_l1_latency_3_hwtcl                                      (endpoint_l1_latency_3_hwtcl                             ),
      .maximum_current_3_hwtcl                                          (maximum_current_3_hwtcl                                 ),
      .device_specific_init_3_hwtcl                                     (device_specific_init_3_hwtcl                            ),
      .ssvid_3_hwtcl                                                    (ssvid_3_hwtcl                                           ),
      .ssid_3_hwtcl                                                     (ssid_3_hwtcl                                            ),
      .bridge_port_vga_enable_3_hwtcl                                   (bridge_port_vga_enable_3_hwtcl                          ),
      .bridge_port_ssid_support_3_hwtcl                                 (bridge_port_ssid_support_3_hwtcl                        ),
      .flr_capability_3_hwtcl                                           (flr_capability_3_hwtcl                                  ),
      .disable_snoop_packet_3_hwtcl                                     (disable_snoop_packet_3_hwtcl                            ),
      .vendor_id_4_hwtcl                                                (vendor_id_4_hwtcl                                       ),
      .device_id_4_hwtcl                                                (device_id_4_hwtcl                                       ),
      .revision_id_4_hwtcl                                              (revision_id_4_hwtcl                                     ),
      .class_code_4_hwtcl                                               (class_code_4_hwtcl                                      ),
      .subsystem_vendor_id_4_hwtcl                                      (subsystem_vendor_id_4_hwtcl                             ),
      .subsystem_device_id_4_hwtcl                                      (subsystem_device_id_4_hwtcl                             ),
      .bar0_io_space_4_hwtcl                                            (bar0_io_space_4_hwtcl                                   ),
      .bar0_64bit_mem_space_4_hwtcl                                     (bar0_64bit_mem_space_4_hwtcl                            ),
      .bar0_prefetchable_4_hwtcl                                        (bar0_prefetchable_4_hwtcl                               ),
      .bar0_size_mask_4_hwtcl                                           (bar0_size_mask_4_hwtcl                                  ),
      .bar1_io_space_4_hwtcl                                            (bar1_io_space_4_hwtcl                                   ),
      .bar1_64bit_mem_space_4_hwtcl                                     (bar1_64bit_mem_space_4_hwtcl                            ),
      .bar1_prefetchable_4_hwtcl                                        (bar1_prefetchable_4_hwtcl                               ),
      .bar1_size_mask_4_hwtcl                                           (bar1_size_mask_4_hwtcl                                  ),
      .bar2_io_space_4_hwtcl                                            (bar2_io_space_4_hwtcl                                   ),
      .bar2_64bit_mem_space_4_hwtcl                                     (bar2_64bit_mem_space_4_hwtcl                            ),
      .bar2_prefetchable_4_hwtcl                                        (bar2_prefetchable_4_hwtcl                               ),
      .bar2_size_mask_4_hwtcl                                           (bar2_size_mask_4_hwtcl                                  ),
      .bar3_io_space_4_hwtcl                                            (bar3_io_space_4_hwtcl                                   ),
      .bar3_64bit_mem_space_4_hwtcl                                     (bar3_64bit_mem_space_4_hwtcl                            ),
      .bar3_prefetchable_4_hwtcl                                        (bar3_prefetchable_4_hwtcl                               ),
      .bar3_size_mask_4_hwtcl                                           (bar3_size_mask_4_hwtcl                                  ),
      .bar4_io_space_4_hwtcl                                            (bar4_io_space_4_hwtcl                                   ),
      .bar4_64bit_mem_space_4_hwtcl                                     (bar4_64bit_mem_space_4_hwtcl                            ),
      .bar4_prefetchable_4_hwtcl                                        (bar4_prefetchable_4_hwtcl                               ),
      .bar4_size_mask_4_hwtcl                                           (bar4_size_mask_4_hwtcl                                  ),
      .bar5_io_space_4_hwtcl                                            (bar5_io_space_4_hwtcl                                   ),
      .bar5_64bit_mem_space_4_hwtcl                                     (bar5_64bit_mem_space_4_hwtcl                            ),
      .bar5_prefetchable_4_hwtcl                                        (bar5_prefetchable_4_hwtcl                               ),
      .bar5_size_mask_4_hwtcl                                           (bar5_size_mask_4_hwtcl                                  ),
      .expansion_base_address_register_4_hwtcl                          (expansion_base_address_register_4_hwtcl                 ),
      .msi_multi_message_capable_4_hwtcl                                (msi_multi_message_capable_4_hwtcl                       ),
      .msi_64bit_addressing_capable_4_hwtcl                             (msi_64bit_addressing_capable_4_hwtcl                    ),
      .msi_masking_capable_4_hwtcl                                      (msi_masking_capable_4_hwtcl                             ),
      .msi_support_4_hwtcl                                              (msi_support_4_hwtcl                                     ),
      .interrupt_pin_4_hwtcl                                            (interrupt_pin_4_hwtcl                                   ),
      .enable_function_msix_support_4_hwtcl                             (enable_function_msix_support_4_hwtcl                    ),
      .msix_table_size_4_hwtcl                                          (msix_table_size_4_hwtcl                                 ),
      .msix_table_bir_4_hwtcl                                           (msix_table_bir_4_hwtcl                                  ),
      .msix_table_offset_4_hwtcl                                        (msix_table_offset_4_hwtcl                               ),
      .msix_pba_bir_4_hwtcl                                             (msix_pba_bir_4_hwtcl                                    ),
      .msix_pba_offset_4_hwtcl                                          (msix_pba_offset_4_hwtcl                                 ),
      .use_aer_4_hwtcl                                                  (use_aer_4_hwtcl                                         ),
      .ecrc_check_capable_4_hwtcl                                       (ecrc_check_capable_4_hwtcl                              ),
      .ecrc_gen_capable_4_hwtcl                                         (ecrc_gen_capable_4_hwtcl                                ),
      .slot_power_scale_4_hwtcl                                         (slot_power_scale_4_hwtcl                                ),
      .slot_power_limit_4_hwtcl                                         (slot_power_limit_4_hwtcl                                ),
      .slot_number_4_hwtcl                                              (slot_number_4_hwtcl                                     ),
      .max_payload_size_4_hwtcl                                         (max_payload_size_4_hwtcl                                ),
      .extend_tag_field_4_hwtcl                                         (extend_tag_field_4_hwtcl                                ),
      .completion_timeout_4_hwtcl                                       (completion_timeout_4_hwtcl                              ),
      .enable_completion_timeout_disable_4_hwtcl                        (enable_completion_timeout_disable_4_hwtcl               ),
      .surprise_down_error_support_4_hwtcl                              (surprise_down_error_support_4_hwtcl                     ),
      .dll_active_report_support_4_hwtcl                                (dll_active_report_support_4_hwtcl                       ),
      .rx_ei_l0s_4_hwtcl                                                (rx_ei_l0s_4_hwtcl                                       ),
      .endpoint_l0_latency_4_hwtcl                                      (endpoint_l0_latency_4_hwtcl                             ),
      .endpoint_l1_latency_4_hwtcl                                      (endpoint_l1_latency_4_hwtcl                             ),
      .maximum_current_4_hwtcl                                          (maximum_current_4_hwtcl                                 ),
      .device_specific_init_4_hwtcl                                     (device_specific_init_4_hwtcl                            ),
      .ssvid_4_hwtcl                                                    (ssvid_4_hwtcl                                           ),
      .ssid_4_hwtcl                                                     (ssid_4_hwtcl                                            ),
      .bridge_port_vga_enable_4_hwtcl                                   (bridge_port_vga_enable_4_hwtcl                          ),
      .bridge_port_ssid_support_4_hwtcl                                 (bridge_port_ssid_support_4_hwtcl                        ),
      .flr_capability_4_hwtcl                                           (flr_capability_4_hwtcl                                  ),
      .disable_snoop_packet_4_hwtcl                                     (disable_snoop_packet_4_hwtcl                            ),
      .vendor_id_5_hwtcl                                                (vendor_id_5_hwtcl                                       ),
      .device_id_5_hwtcl                                                (device_id_5_hwtcl                                       ),
      .revision_id_5_hwtcl                                              (revision_id_5_hwtcl                                     ),
      .class_code_5_hwtcl                                               (class_code_5_hwtcl                                      ),
      .subsystem_vendor_id_5_hwtcl                                      (subsystem_vendor_id_5_hwtcl                             ),
      .subsystem_device_id_5_hwtcl                                      (subsystem_device_id_5_hwtcl                             ),
      .bar0_io_space_5_hwtcl                                            (bar0_io_space_5_hwtcl                                   ),
      .bar0_64bit_mem_space_5_hwtcl                                     (bar0_64bit_mem_space_5_hwtcl                            ),
      .bar0_prefetchable_5_hwtcl                                        (bar0_prefetchable_5_hwtcl                               ),
      .bar0_size_mask_5_hwtcl                                           (bar0_size_mask_5_hwtcl                                  ),
      .bar1_io_space_5_hwtcl                                            (bar1_io_space_5_hwtcl                                   ),
      .bar1_64bit_mem_space_5_hwtcl                                     (bar1_64bit_mem_space_5_hwtcl                            ),
      .bar1_prefetchable_5_hwtcl                                        (bar1_prefetchable_5_hwtcl                               ),
      .bar1_size_mask_5_hwtcl                                           (bar1_size_mask_5_hwtcl                                  ),
      .bar2_io_space_5_hwtcl                                            (bar2_io_space_5_hwtcl                                   ),
      .bar2_64bit_mem_space_5_hwtcl                                     (bar2_64bit_mem_space_5_hwtcl                            ),
      .bar2_prefetchable_5_hwtcl                                        (bar2_prefetchable_5_hwtcl                               ),
      .bar2_size_mask_5_hwtcl                                           (bar2_size_mask_5_hwtcl                                  ),
      .bar3_io_space_5_hwtcl                                            (bar3_io_space_5_hwtcl                                   ),
      .bar3_64bit_mem_space_5_hwtcl                                     (bar3_64bit_mem_space_5_hwtcl                            ),
      .bar3_prefetchable_5_hwtcl                                        (bar3_prefetchable_5_hwtcl                               ),
      .bar3_size_mask_5_hwtcl                                           (bar3_size_mask_5_hwtcl                                  ),
      .bar4_io_space_5_hwtcl                                            (bar4_io_space_5_hwtcl                                   ),
      .bar4_64bit_mem_space_5_hwtcl                                     (bar4_64bit_mem_space_5_hwtcl                            ),
      .bar4_prefetchable_5_hwtcl                                        (bar4_prefetchable_5_hwtcl                               ),
      .bar4_size_mask_5_hwtcl                                           (bar4_size_mask_5_hwtcl                                  ),
      .bar5_io_space_5_hwtcl                                            (bar5_io_space_5_hwtcl                                   ),
      .bar5_64bit_mem_space_5_hwtcl                                     (bar5_64bit_mem_space_5_hwtcl                            ),
      .bar5_prefetchable_5_hwtcl                                        (bar5_prefetchable_5_hwtcl                               ),
      .bar5_size_mask_5_hwtcl                                           (bar5_size_mask_5_hwtcl                                  ),
      .expansion_base_address_register_5_hwtcl                          (expansion_base_address_register_5_hwtcl                 ),
      .msi_multi_message_capable_5_hwtcl                                (msi_multi_message_capable_5_hwtcl                       ),
      .msi_64bit_addressing_capable_5_hwtcl                             (msi_64bit_addressing_capable_5_hwtcl                    ),
      .msi_masking_capable_5_hwtcl                                      (msi_masking_capable_5_hwtcl                             ),
      .msi_support_5_hwtcl                                              (msi_support_5_hwtcl                                     ),
      .interrupt_pin_5_hwtcl                                            (interrupt_pin_5_hwtcl                                   ),
      .enable_function_msix_support_5_hwtcl                             (enable_function_msix_support_5_hwtcl                    ),
      .msix_table_size_5_hwtcl                                          (msix_table_size_5_hwtcl                                 ),
      .msix_table_bir_5_hwtcl                                           (msix_table_bir_5_hwtcl                                  ),
      .msix_table_offset_5_hwtcl                                        (msix_table_offset_5_hwtcl                               ),
      .msix_pba_bir_5_hwtcl                                             (msix_pba_bir_5_hwtcl                                    ),
      .msix_pba_offset_5_hwtcl                                          (msix_pba_offset_5_hwtcl                                 ),
      .use_aer_5_hwtcl                                                  (use_aer_5_hwtcl                                         ),
      .ecrc_check_capable_5_hwtcl                                       (ecrc_check_capable_5_hwtcl                              ),
      .ecrc_gen_capable_5_hwtcl                                         (ecrc_gen_capable_5_hwtcl                                ),
      .slot_power_scale_5_hwtcl                                         (slot_power_scale_5_hwtcl                                ),
      .slot_power_limit_5_hwtcl                                         (slot_power_limit_5_hwtcl                                ),
      .slot_number_5_hwtcl                                              (slot_number_5_hwtcl                                     ),
      .max_payload_size_5_hwtcl                                         (max_payload_size_5_hwtcl                                ),
      .extend_tag_field_5_hwtcl                                         (extend_tag_field_5_hwtcl                                ),
      .completion_timeout_5_hwtcl                                       (completion_timeout_5_hwtcl                              ),
      .enable_completion_timeout_disable_5_hwtcl                        (enable_completion_timeout_disable_5_hwtcl               ),
      .surprise_down_error_support_5_hwtcl                              (surprise_down_error_support_5_hwtcl                     ),
      .dll_active_report_support_5_hwtcl                                (dll_active_report_support_5_hwtcl                       ),
      .rx_ei_l0s_5_hwtcl                                                (rx_ei_l0s_5_hwtcl                                       ),
      .endpoint_l0_latency_5_hwtcl                                      (endpoint_l0_latency_5_hwtcl                             ),
      .endpoint_l1_latency_5_hwtcl                                      (endpoint_l1_latency_5_hwtcl                             ),
      .maximum_current_5_hwtcl                                          (maximum_current_5_hwtcl                                 ),
      .device_specific_init_5_hwtcl                                     (device_specific_init_5_hwtcl                            ),
      .ssvid_5_hwtcl                                                    (ssvid_5_hwtcl                                           ),
      .ssid_5_hwtcl                                                     (ssid_5_hwtcl                                            ),
      .bridge_port_vga_enable_5_hwtcl                                   (bridge_port_vga_enable_5_hwtcl                          ),
      .bridge_port_ssid_support_5_hwtcl                                 (bridge_port_ssid_support_5_hwtcl                        ),
      .flr_capability_5_hwtcl                                           (flr_capability_5_hwtcl                                  ),
      .disable_snoop_packet_5_hwtcl                                     (disable_snoop_packet_5_hwtcl                            ),
      .vendor_id_6_hwtcl                                                (vendor_id_6_hwtcl                                       ),
      .device_id_6_hwtcl                                                (device_id_6_hwtcl                                       ),
      .revision_id_6_hwtcl                                              (revision_id_6_hwtcl                                     ),
      .class_code_6_hwtcl                                               (class_code_6_hwtcl                                      ),
      .subsystem_vendor_id_6_hwtcl                                      (subsystem_vendor_id_6_hwtcl                             ),
      .subsystem_device_id_6_hwtcl                                      (subsystem_device_id_6_hwtcl                             ),
      .bar0_io_space_6_hwtcl                                            (bar0_io_space_6_hwtcl                                   ),
      .bar0_64bit_mem_space_6_hwtcl                                     (bar0_64bit_mem_space_6_hwtcl                            ),
      .bar0_prefetchable_6_hwtcl                                        (bar0_prefetchable_6_hwtcl                               ),
      .bar0_size_mask_6_hwtcl                                           (bar0_size_mask_6_hwtcl                                  ),
      .bar1_io_space_6_hwtcl                                            (bar1_io_space_6_hwtcl                                   ),
      .bar1_64bit_mem_space_6_hwtcl                                     (bar1_64bit_mem_space_6_hwtcl                            ),
      .bar1_prefetchable_6_hwtcl                                        (bar1_prefetchable_6_hwtcl                               ),
      .bar1_size_mask_6_hwtcl                                           (bar1_size_mask_6_hwtcl                                  ),
      .bar2_io_space_6_hwtcl                                            (bar2_io_space_6_hwtcl                                   ),
      .bar2_64bit_mem_space_6_hwtcl                                     (bar2_64bit_mem_space_6_hwtcl                            ),
      .bar2_prefetchable_6_hwtcl                                        (bar2_prefetchable_6_hwtcl                               ),
      .bar2_size_mask_6_hwtcl                                           (bar2_size_mask_6_hwtcl                                  ),
      .bar3_io_space_6_hwtcl                                            (bar3_io_space_6_hwtcl                                   ),
      .bar3_64bit_mem_space_6_hwtcl                                     (bar3_64bit_mem_space_6_hwtcl                            ),
      .bar3_prefetchable_6_hwtcl                                        (bar3_prefetchable_6_hwtcl                               ),
      .bar3_size_mask_6_hwtcl                                           (bar3_size_mask_6_hwtcl                                  ),
      .bar4_io_space_6_hwtcl                                            (bar4_io_space_6_hwtcl                                   ),
      .bar4_64bit_mem_space_6_hwtcl                                     (bar4_64bit_mem_space_6_hwtcl                            ),
      .bar4_prefetchable_6_hwtcl                                        (bar4_prefetchable_6_hwtcl                               ),
      .bar4_size_mask_6_hwtcl                                           (bar4_size_mask_6_hwtcl                                  ),
      .bar5_io_space_6_hwtcl                                            (bar5_io_space_6_hwtcl                                   ),
      .bar5_64bit_mem_space_6_hwtcl                                     (bar5_64bit_mem_space_6_hwtcl                            ),
      .bar5_prefetchable_6_hwtcl                                        (bar5_prefetchable_6_hwtcl                               ),
      .bar5_size_mask_6_hwtcl                                           (bar5_size_mask_6_hwtcl                                  ),
      .expansion_base_address_register_6_hwtcl                          (expansion_base_address_register_6_hwtcl                 ),
      .msi_multi_message_capable_6_hwtcl                                (msi_multi_message_capable_6_hwtcl                       ),
      .msi_64bit_addressing_capable_6_hwtcl                             (msi_64bit_addressing_capable_6_hwtcl                    ),
      .msi_masking_capable_6_hwtcl                                      (msi_masking_capable_6_hwtcl                             ),
      .msi_support_6_hwtcl                                              (msi_support_6_hwtcl                                     ),
      .interrupt_pin_6_hwtcl                                            (interrupt_pin_6_hwtcl                                   ),
      .enable_function_msix_support_6_hwtcl                             (enable_function_msix_support_6_hwtcl                    ),
      .msix_table_size_6_hwtcl                                          (msix_table_size_6_hwtcl                                 ),
      .msix_table_bir_6_hwtcl                                           (msix_table_bir_6_hwtcl                                  ),
      .msix_table_offset_6_hwtcl                                        (msix_table_offset_6_hwtcl                               ),
      .msix_pba_bir_6_hwtcl                                             (msix_pba_bir_6_hwtcl                                    ),
      .msix_pba_offset_6_hwtcl                                          (msix_pba_offset_6_hwtcl                                 ),
      .use_aer_6_hwtcl                                                  (use_aer_6_hwtcl                                         ),
      .ecrc_check_capable_6_hwtcl                                       (ecrc_check_capable_6_hwtcl                              ),
      .ecrc_gen_capable_6_hwtcl                                         (ecrc_gen_capable_6_hwtcl                                ),
      .slot_power_scale_6_hwtcl                                         (slot_power_scale_6_hwtcl                                ),
      .slot_power_limit_6_hwtcl                                         (slot_power_limit_6_hwtcl                                ),
      .slot_number_6_hwtcl                                              (slot_number_6_hwtcl                                     ),
      .max_payload_size_6_hwtcl                                         (max_payload_size_6_hwtcl                                ),
      .extend_tag_field_6_hwtcl                                         (extend_tag_field_6_hwtcl                                ),
      .completion_timeout_6_hwtcl                                       (completion_timeout_6_hwtcl                              ),
      .enable_completion_timeout_disable_6_hwtcl                        (enable_completion_timeout_disable_6_hwtcl               ),
      .surprise_down_error_support_6_hwtcl                              (surprise_down_error_support_6_hwtcl                     ),
      .dll_active_report_support_6_hwtcl                                (dll_active_report_support_6_hwtcl                       ),
      .rx_ei_l0s_6_hwtcl                                                (rx_ei_l0s_6_hwtcl                                       ),
      .endpoint_l0_latency_6_hwtcl                                      (endpoint_l0_latency_6_hwtcl                             ),
      .endpoint_l1_latency_6_hwtcl                                      (endpoint_l1_latency_6_hwtcl                             ),
      .maximum_current_6_hwtcl                                          (maximum_current_6_hwtcl                                 ),
      .device_specific_init_6_hwtcl                                     (device_specific_init_6_hwtcl                            ),
      .ssvid_6_hwtcl                                                    (ssvid_6_hwtcl                                           ),
      .ssid_6_hwtcl                                                     (ssid_6_hwtcl                                            ),
      .bridge_port_vga_enable_6_hwtcl                                   (bridge_port_vga_enable_6_hwtcl                          ),
      .bridge_port_ssid_support_6_hwtcl                                 (bridge_port_ssid_support_6_hwtcl                        ),
      .flr_capability_6_hwtcl                                           (flr_capability_6_hwtcl                                  ),
      .disable_snoop_packet_6_hwtcl                                     (disable_snoop_packet_6_hwtcl                            ),
      .vendor_id_7_hwtcl                                                (vendor_id_7_hwtcl                                       ),
      .device_id_7_hwtcl                                                (device_id_7_hwtcl                                       ),
      .revision_id_7_hwtcl                                              (revision_id_7_hwtcl                                     ),
      .class_code_7_hwtcl                                               (class_code_7_hwtcl                                      ),
      .subsystem_vendor_id_7_hwtcl                                      (subsystem_vendor_id_7_hwtcl                             ),
      .subsystem_device_id_7_hwtcl                                      (subsystem_device_id_7_hwtcl                             ),
      .bar0_io_space_7_hwtcl                                            (bar0_io_space_7_hwtcl                                   ),
      .bar0_64bit_mem_space_7_hwtcl                                     (bar0_64bit_mem_space_7_hwtcl                            ),
      .bar0_prefetchable_7_hwtcl                                        (bar0_prefetchable_7_hwtcl                               ),
      .bar0_size_mask_7_hwtcl                                           (bar0_size_mask_7_hwtcl                                  ),
      .bar1_io_space_7_hwtcl                                            (bar1_io_space_7_hwtcl                                   ),
      .bar1_64bit_mem_space_7_hwtcl                                     (bar1_64bit_mem_space_7_hwtcl                            ),
      .bar1_prefetchable_7_hwtcl                                        (bar1_prefetchable_7_hwtcl                               ),
      .bar1_size_mask_7_hwtcl                                           (bar1_size_mask_7_hwtcl                                  ),
      .bar2_io_space_7_hwtcl                                            (bar2_io_space_7_hwtcl                                   ),
      .bar2_64bit_mem_space_7_hwtcl                                     (bar2_64bit_mem_space_7_hwtcl                            ),
      .bar2_prefetchable_7_hwtcl                                        (bar2_prefetchable_7_hwtcl                               ),
      .bar2_size_mask_7_hwtcl                                           (bar2_size_mask_7_hwtcl                                  ),
      .bar3_io_space_7_hwtcl                                            (bar3_io_space_7_hwtcl                                   ),
      .bar3_64bit_mem_space_7_hwtcl                                     (bar3_64bit_mem_space_7_hwtcl                            ),
      .bar3_prefetchable_7_hwtcl                                        (bar3_prefetchable_7_hwtcl                               ),
      .bar3_size_mask_7_hwtcl                                           (bar3_size_mask_7_hwtcl                                  ),
      .bar4_io_space_7_hwtcl                                            (bar4_io_space_7_hwtcl                                   ),
      .bar4_64bit_mem_space_7_hwtcl                                     (bar4_64bit_mem_space_7_hwtcl                            ),
      .bar4_prefetchable_7_hwtcl                                        (bar4_prefetchable_7_hwtcl                               ),
      .bar4_size_mask_7_hwtcl                                           (bar4_size_mask_7_hwtcl                                  ),
      .bar5_io_space_7_hwtcl                                            (bar5_io_space_7_hwtcl                                   ),
      .bar5_64bit_mem_space_7_hwtcl                                     (bar5_64bit_mem_space_7_hwtcl                            ),
      .bar5_prefetchable_7_hwtcl                                        (bar5_prefetchable_7_hwtcl                               ),
      .bar5_size_mask_7_hwtcl                                           (bar5_size_mask_7_hwtcl                                  ),
      .expansion_base_address_register_7_hwtcl                          (expansion_base_address_register_7_hwtcl                 ),
      .msi_multi_message_capable_7_hwtcl                                (msi_multi_message_capable_7_hwtcl                       ),
      .msi_64bit_addressing_capable_7_hwtcl                             (msi_64bit_addressing_capable_7_hwtcl                    ),
      .msi_masking_capable_7_hwtcl                                      (msi_masking_capable_7_hwtcl                             ),
      .msi_support_7_hwtcl                                              (msi_support_7_hwtcl                                     ),
      .interrupt_pin_7_hwtcl                                            (interrupt_pin_7_hwtcl                                   ),
      .enable_function_msix_support_7_hwtcl                             (enable_function_msix_support_7_hwtcl                    ),
      .msix_table_size_7_hwtcl                                          (msix_table_size_7_hwtcl                                 ),
      .msix_table_bir_7_hwtcl                                           (msix_table_bir_7_hwtcl                                  ),
      .msix_table_offset_7_hwtcl                                        (msix_table_offset_7_hwtcl                               ),
      .msix_pba_bir_7_hwtcl                                             (msix_pba_bir_7_hwtcl                                    ),
      .msix_pba_offset_7_hwtcl                                          (msix_pba_offset_7_hwtcl                                 ),
      .use_aer_7_hwtcl                                                  (use_aer_7_hwtcl                                         ),
      .ecrc_check_capable_7_hwtcl                                       (ecrc_check_capable_7_hwtcl                              ),
      .ecrc_gen_capable_7_hwtcl                                         (ecrc_gen_capable_7_hwtcl                                ),
      .slot_power_scale_7_hwtcl                                         (slot_power_scale_7_hwtcl                                ),
      .slot_power_limit_7_hwtcl                                         (slot_power_limit_7_hwtcl                                ),
      .slot_number_7_hwtcl                                              (slot_number_7_hwtcl                                     ),
      .max_payload_size_7_hwtcl                                         (max_payload_size_7_hwtcl                                ),
      .extend_tag_field_7_hwtcl                                         (extend_tag_field_7_hwtcl                                ),
      .completion_timeout_7_hwtcl                                       (completion_timeout_7_hwtcl                              ),
      .enable_completion_timeout_disable_7_hwtcl                        (enable_completion_timeout_disable_7_hwtcl               ),
      .surprise_down_error_support_7_hwtcl                              (surprise_down_error_support_7_hwtcl                     ),
      .dll_active_report_support_7_hwtcl                                (dll_active_report_support_7_hwtcl                       ),
      .rx_ei_l0s_7_hwtcl                                                (rx_ei_l0s_7_hwtcl                                       ),
      .endpoint_l0_latency_7_hwtcl                                      (endpoint_l0_latency_7_hwtcl                             ),
      .endpoint_l1_latency_7_hwtcl                                      (endpoint_l1_latency_7_hwtcl                             ),
      .maximum_current_7_hwtcl                                          (maximum_current_7_hwtcl                                 ),
      .device_specific_init_7_hwtcl                                     (device_specific_init_7_hwtcl                            ),
      .ssvid_7_hwtcl                                                    (ssvid_7_hwtcl                                           ),
      .ssid_7_hwtcl                                                     (ssid_7_hwtcl                                            ),
      .bridge_port_vga_enable_7_hwtcl                                   (bridge_port_vga_enable_7_hwtcl                          ),
      .bridge_port_ssid_support_7_hwtcl                                 (bridge_port_ssid_support_7_hwtcl                        ),
      .flr_capability_7_hwtcl                                           (flr_capability_7_hwtcl                                  ),
      .disable_snoop_packet_7_hwtcl                                     (disable_snoop_packet_7_hwtcl                            ),
      .no_soft_reset_hwtcl                                              (no_soft_reset_hwtcl                                     ),
      .d1_support_hwtcl                                                 (d1_support_hwtcl                                        ),
      .d2_support_hwtcl                                                 (d2_support_hwtcl                                        ),
      .d0_pme_hwtcl                                                     (d0_pme_hwtcl                                            ),
      .d1_pme_hwtcl                                                     (d1_pme_hwtcl                                            ),
      .d2_pme_hwtcl                                                     (d2_pme_hwtcl                                            ),
      .d3_hot_pme_hwtcl                                                 (d3_hot_pme_hwtcl                                        ),
      .d3_cold_pme_hwtcl                                                (d3_cold_pme_hwtcl                                       ),
      .low_priority_vc_hwtcl                                            (low_priority_vc_hwtcl                                   ),
      .indicator_hwtcl                                                  (indicator_hwtcl                                         ),
      .enable_l0s_aspm_hwtcl                                            (enable_l0s_aspm_hwtcl                                   ),
      .enable_l1_aspm_hwtcl                                             (enable_l1_aspm_hwtcl                                    ),
      .l1_exit_latency_sameclock_hwtcl                                  (l1_exit_latency_sameclock_hwtcl                         ),
      .l1_exit_latency_diffclock_hwtcl                                  (l1_exit_latency_diffclock_hwtcl                         ),
      .hot_plug_support_hwtcl                                           (hot_plug_support_hwtcl                                  ),
      .diffclock_nfts_count_hwtcl                                       (diffclock_nfts_count_hwtcl                              ),
      .sameclock_nfts_count_hwtcl                                       (sameclock_nfts_count_hwtcl                              ),
      .no_command_completed_hwtcl                                       (no_command_completed_hwtcl                              ),
      .eie_before_nfts_count_hwtcl                                      (eie_before_nfts_count_hwtcl                             ),
      .gen2_diffclock_nfts_count_hwtcl                                  (gen2_diffclock_nfts_count_hwtcl                         ),
      .gen2_sameclock_nfts_count_hwtcl                                  (gen2_sameclock_nfts_count_hwtcl                         ),
      .deemphasis_enable_hwtcl                                          (deemphasis_enable_hwtcl                                 ),
      .pcie_spec_version_hwtcl                                          (pcie_spec_version_hwtcl                                 ),
      .l0_exit_latency_sameclock_hwtcl                                  (l0_exit_latency_sameclock_hwtcl                         ),
      .l0_exit_latency_diffclock_hwtcl                                  (l0_exit_latency_diffclock_hwtcl                         ),
      .l2_async_logic_hwtcl                                             (l2_async_logic_hwtcl                                    ),
      .aspm_optionality_hwtcl                                           (aspm_optionality_hwtcl                                  ),
      .enable_adapter_half_rate_mode_hwtcl                              (enable_adapter_half_rate_mode_hwtcl                     ),
      .vc0_clk_enable_hwtcl                                             (vc0_clk_enable_hwtcl                                    ),
      .register_pipe_signals_hwtcl                                      (register_pipe_signals_hwtcl                             ),
      .io_window_addr_width_hwtcl                                       (io_window_addr_width_hwtcl                              ),
      .prefetchable_mem_window_addr_width_hwtcl                         (prefetchable_mem_window_addr_width_hwtcl                ),
      .tx_cdc_almost_empty_hwtcl                                        (tx_cdc_almost_empty_hwtcl                               ),
      .rx_cdc_almost_full_hwtcl                                         (rx_cdc_almost_full_hwtcl                                ),
      .tx_cdc_almost_full_hwtcl                                         (tx_cdc_almost_full_hwtcl                                ),
      .rx_l0s_count_idl_hwtcl                                           (rx_l0s_count_idl_hwtcl                                  ),
      .cdc_dummy_insert_limit_hwtcl                                     (cdc_dummy_insert_limit_hwtcl                            ),
      .ei_delay_powerdown_count_hwtcl                                   (ei_delay_powerdown_count_hwtcl                          ),
      .millisecond_cycle_count_hwtcl                                    (millisecond_cycle_count_hwtcl                           ),
      .skp_os_schedule_count_hwtcl                                      (skp_os_schedule_count_hwtcl                             ),
      .fc_init_timer_hwtcl                                              (fc_init_timer_hwtcl                                     ),
      .l01_entry_latency_hwtcl                                          (l01_entry_latency_hwtcl                                 ),
      .flow_control_update_count_hwtcl                                  (flow_control_update_count_hwtcl                         ),
      .flow_control_timeout_count_hwtcl                                 (flow_control_timeout_count_hwtcl                        ),
      .credit_buffer_allocation_aux_hwtcl                               (credit_buffer_allocation_aux_hwtcl                      ),
      .vc0_rx_flow_ctrl_posted_header_hwtcl                             (vc0_rx_flow_ctrl_posted_header_hwtcl                    ),
      .vc0_rx_flow_ctrl_posted_data_hwtcl                               (vc0_rx_flow_ctrl_posted_data_hwtcl                      ),
      .vc0_rx_flow_ctrl_nonposted_header_hwtcl                          (vc0_rx_flow_ctrl_nonposted_header_hwtcl                 ),
      .vc0_rx_flow_ctrl_nonposted_data_hwtcl                            (vc0_rx_flow_ctrl_nonposted_data_hwtcl                   ),
      .vc0_rx_flow_ctrl_compl_header_hwtcl                              (vc0_rx_flow_ctrl_compl_header_hwtcl                     ),
      .vc0_rx_flow_ctrl_compl_data_hwtcl                                (vc0_rx_flow_ctrl_compl_data_hwtcl                       ),
      .cpl_spc_header_hwtcl                                             (cpl_spc_header_hwtcl                                    ),
      .cpl_spc_data_hwtcl                                               (cpl_spc_data_hwtcl                                      ),
      .retry_buffer_last_active_address_hwtcl                           (retry_buffer_last_active_address_hwtcl                  ),
      .hip_hard_reset_hwtcl                                             (hip_hard_reset_hwtcl                                    ),
      .reserved_debug_hwtcl                                             (reserved_debug_hwtcl                                    ),
      .hip_reconfig_hwtcl                                               (hip_reconfig_hwtcl                                      ),
      .port_width_data_hwtcl                                            (port_width_data_hwtcl                                   ),
      .ACDS_VERSION_HWTCL                                               (ACDS_VERSION_HWTCL                                      ),
      .cvp_rate_sel_hwtcl                                               (cvp_rate_sel_hwtcl                                      ),
      .cvp_data_compressed_hwtcl                                        (cvp_data_compressed_hwtcl                               ),
      .cvp_data_encrypted_hwtcl                                         (cvp_data_encrypted_hwtcl                                ),
      .cvp_mode_reset_hwtcl                                             (cvp_mode_reset_hwtcl                                    ),
      .cvp_clk_reset_hwtcl                                              (cvp_clk_reset_hwtcl                                     ),
      .in_cvp_mode_hwtcl                                                (in_cvp_mode_hwtcl                                       ),
      .core_clk_sel_hwtcl                                               (core_clk_sel_hwtcl                                      ),
      .rpre_emph_a_val_hwtcl                                            (rpre_emph_a_val_hwtcl                                   ),
      .rpre_emph_b_val_hwtcl                                            (rpre_emph_b_val_hwtcl                                   ),
      .rpre_emph_c_val_hwtcl                                            (rpre_emph_c_val_hwtcl                                   ),
      .rpre_emph_d_val_hwtcl                                            (rpre_emph_d_val_hwtcl                                   ),
      .rpre_emph_e_val_hwtcl                                            (rpre_emph_e_val_hwtcl                                   ),
      .rvod_sel_a_val_hwtcl                                             (rvod_sel_a_val_hwtcl                                    ),
      .rvod_sel_b_val_hwtcl                                             (rvod_sel_b_val_hwtcl                                    ),
      .rvod_sel_c_val_hwtcl                                             (rvod_sel_c_val_hwtcl                                    ),
      .rvod_sel_d_val_hwtcl                                             (rvod_sel_d_val_hwtcl                                    ),
      .rvod_sel_e_val_hwtcl                                             (rvod_sel_e_val_hwtcl                                    ),
      .vsec_id_hwtcl                                                    (vsec_id_hwtcl                                           ),
      .vsec_rev_hwtcl                                                   (vsec_rev_hwtcl                                          ),
      .user_id_hwtcl                                                    (user_id_hwtcl                                           )
) altpcie_av_hip_ast_hwtcl (
      .test_in                                                          (test_in                                                 ),  //input  [31 : 0]
      .simu_mode_pipe                                                   (simu_mode_pipe                                          ),  //input
      .pin_perst                                                        (pin_perst                                               ),  //input
      .npor                                                             (npor                                                    ),  //input
      .reset_status                                                     (reset_status                                            ),  //output
      .serdes_pll_locked                                                (serdes_pll_locked                                       ),  //output
      .pld_clk_inuse                                                    (pld_clk_inuse                                           ),  //output
      .pld_core_ready                                                   (pld_core_ready                                          ),  //input
      .testin_zero                                                      (testin_zero                                             ),  //output
      .pld_clk                                                          (pld_clk                                                 ),  //input
      .refclk                                                           (refclk                                                  ),  //input
      .reconfig_to_xcvr                                                 (reconfig_to_xcvr                                        ),  //input  [reconfig_to_xcvr_width-1:0]
      .busy_xcvr_reconfig                                               (busy_xcvr_reconfig                                      ),  //input
      .reconfig_from_xcvr                                               (reconfig_from_xcvr                                      ),  //output [reconfig_from_xcvr_width-1:0]
      .fixedclk_locked                                                  (fixedclk_locked                                         ),  //output
      .tl_hpg_ctrl_er                                                   (tl_hpg_ctrl_er                                          ),  //input  [4 : 0]
      .sim_pipe_rate                                                    (sim_pipe_rate                                           ),  //output [1:0]
      .sim_pipe_pclk_in                                                 (sim_pipe_pclk_in                                        ),  //input
      .sim_pipe_pclk_out                                                (sim_pipe_pclk_out                                       ),  //output
      .sim_pipe_clk250_out                                              (sim_pipe_clk250_out                                     ),  //output
      .sim_pipe_clk500_out                                              (sim_pipe_clk500_out                                     ),  //output
      .sim_ltssmstate                                                   (sim_ltssmstate                                          ),  //output [4 : 0]
      .phystatus0                                                       (phystatus0                                              ),  //input
      .phystatus1                                                       (phystatus1                                              ),  //input
      .phystatus2                                                       (phystatus2                                              ),  //input
      .phystatus3                                                       (phystatus3                                              ),  //input
      .phystatus4                                                       (phystatus4                                              ),  //input
      .phystatus5                                                       (phystatus5                                              ),  //input
      .phystatus6                                                       (phystatus6                                              ),  //input
      .phystatus7                                                       (phystatus7                                              ),  //input
      .rxdata0                                                          (rxdata0                                                 ),  //input  [7 : 0]
      .rxdata1                                                          (rxdata1                                                 ),  //input  [7 : 0]
      .rxdata2                                                          (rxdata2                                                 ),  //input  [7 : 0]
      .rxdata3                                                          (rxdata3                                                 ),  //input  [7 : 0]
      .rxdata4                                                          (rxdata4                                                 ),  //input  [7 : 0]
      .rxdata5                                                          (rxdata5                                                 ),  //input  [7 : 0]
      .rxdata6                                                          (rxdata6                                                 ),  //input  [7 : 0]
      .rxdata7                                                          (rxdata7                                                 ),  //input  [7 : 0]
      .rxdatak0                                                         (rxdatak0                                                ),  //input
      .rxdatak1                                                         (rxdatak1                                                ),  //input
      .rxdatak2                                                         (rxdatak2                                                ),  //input
      .rxdatak3                                                         (rxdatak3                                                ),  //input
      .rxdatak4                                                         (rxdatak4                                                ),  //input
      .rxdatak5                                                         (rxdatak5                                                ),  //input
      .rxdatak6                                                         (rxdatak6                                                ),  //input
      .rxdatak7                                                         (rxdatak7                                                ),  //input
      .rxelecidle0                                                      (rxelecidle0                                             ),  //input
      .rxelecidle1                                                      (rxelecidle1                                             ),  //input
      .rxelecidle2                                                      (rxelecidle2                                             ),  //input
      .rxelecidle3                                                      (rxelecidle3                                             ),  //input
      .rxelecidle4                                                      (rxelecidle4                                             ),  //input
      .rxelecidle5                                                      (rxelecidle5                                             ),  //input
      .rxelecidle6                                                      (rxelecidle6                                             ),  //input
      .rxelecidle7                                                      (rxelecidle7                                             ),  //input
      .rxstatus0                                                        (rxstatus0                                               ),  //input  [2 : 0]
      .rxstatus1                                                        (rxstatus1                                               ),  //input  [2 : 0]
      .rxstatus2                                                        (rxstatus2                                               ),  //input  [2 : 0]
      .rxstatus3                                                        (rxstatus3                                               ),  //input  [2 : 0]
      .rxstatus4                                                        (rxstatus4                                               ),  //input  [2 : 0]
      .rxstatus5                                                        (rxstatus5                                               ),  //input  [2 : 0]
      .rxstatus6                                                        (rxstatus6                                               ),  //input  [2 : 0]
      .rxstatus7                                                        (rxstatus7                                               ),  //input  [2 : 0]
      .rxvalid0                                                         (rxvalid0                                                ),  //input
      .rxvalid1                                                         (rxvalid1                                                ),  //input
      .rxvalid2                                                         (rxvalid2                                                ),  //input
      .rxvalid3                                                         (rxvalid3                                                ),  //input
      .rxvalid4                                                         (rxvalid4                                                ),  //input
      .rxvalid5                                                         (rxvalid5                                                ),  //input
      .rxvalid6                                                         (rxvalid6                                                ),  //input
      .rxvalid7                                                         (rxvalid7                                                ),  //input
      .hip_reconfig_address                                             (hip_reconfig_address                                    ),  //input  [9 : 0]
      .hip_reconfig_byte_en                                             (hip_reconfig_byte_en                                    ),  //input  [1 : 0]
      .hip_reconfig_clk                                                 (hip_reconfig_clk                                        ),  //input
      .hip_reconfig_read                                                (hip_reconfig_read                                       ),  //input
      .hip_reconfig_rst_n                                               (hip_reconfig_rst_n                                      ),  //input
      .hip_reconfig_write                                               (hip_reconfig_write                                      ),  //input
      .hip_reconfig_writedata                                           (hip_reconfig_writedata                                  ),  //input  [15: 0]
      .app_int_sts_vec                                                  (app_int_sts_vec                                         ),  //input  [(2**addr_width_delta(num_of_func_hwtcl))-1 : 0] tl_app_int_sts_vec,
      .app_msi_func                                                     (app_msi_func                                            ),  //input  [2 : 0]
      .app_msi_num                                                      (app_msi_num                                             ),  //input  [4 : 0]
      .app_msi_req                                                      (app_msi_req                                             ),  //input
      .app_msi_tc                                                       (app_msi_tc                                              ),  //input  [2 : 0]
      .aer_msi_num                                                      (aer_msi_num                                             ),  //input  [4 : 0]
      .pex_msi_num                                                      (pex_msi_num                                             ),  //input  [4 : 0]
      .lmi_addr                                                         (lmi_addr                                                ),  //input  [addr_width_delta(num_of_func_hwtcl)+11 : 0]
      .lmi_din                                                          (lmi_din                                                 ),  //input  [31 : 0]
      .lmi_rden                                                         (lmi_rden                                                ),  //input
      .lmi_wren                                                         (lmi_wren                                                ),  //input
      .pm_auxpwr                                                        (pm_auxpwr                                               ),  //input
      .pm_data                                                          (pm_data                                                 ),  //input  [9 : 0]
      .pme_to_cr                                                        (pme_to_cr                                               ),  //input
      .pm_event                                                         (pm_event                                                ),  //input
      .pm_event_func                                                    (pm_event_func                                           ),  //input  [2 : 0]
      .rx_st_mask                                                       (rx_st_mask                                              ),  //input
      .rx_st_ready                                                      (rx_st_ready                                             ),  //input
      .tx_st_data                                                       (tx_st_data                                              ),  //input [port_width_data_hwtcl-1 : 0]
      .tx_st_eop                                                        (tx_st_eop                                               ),  //input
      .tx_st_sop                                                        (tx_st_sop                                               ),  //input
      .tx_st_empty                                                      (tx_st_empty                                             ),  //input [1:0]
      .tx_st_valid                                                      (tx_st_valid                                             ),  //input
      .tx_st_err                                                        (tx_st_err                                               ),  //input
      .cpl_err                                                          (cpl_err                                                 ),  //input  [6 :0]
      .cpl_err_func                                                     (cpl_err_func                                            ),  //input  [2:0]
      .cpl_pending                                                      (cpl_pending                                             ),  //input  [num_of_func_hwtcl-1:0]
      .ser_shift_load                                                   (ser_shift_load                                          ),  //input
      .interface_sel                                                    (interface_sel                                           ),  //input
      .clrrxpath                                                        (clrrxpath                                               ),  //input
      .eidleinfersel0                                                   (eidleinfersel0                                          ),  //output [2 : 0]
      .eidleinfersel1                                                   (eidleinfersel1                                          ),  //output [2 : 0]
      .eidleinfersel2                                                   (eidleinfersel2                                          ),  //output [2 : 0]
      .eidleinfersel3                                                   (eidleinfersel3                                          ),  //output [2 : 0]
      .eidleinfersel4                                                   (eidleinfersel4                                          ),  //output [2 : 0]
      .eidleinfersel5                                                   (eidleinfersel5                                          ),  //output [2 : 0]
      .eidleinfersel6                                                   (eidleinfersel6                                          ),  //output [2 : 0]
      .eidleinfersel7                                                   (eidleinfersel7                                          ),  //output [2 : 0]
      .powerdown0                                                       (powerdown0                                              ),  //output [1 : 0]
      .powerdown1                                                       (powerdown1                                              ),  //output [1 : 0]
      .powerdown2                                                       (powerdown2                                              ),  //output [1 : 0]
      .powerdown3                                                       (powerdown3                                              ),  //output [1 : 0]
      .powerdown4                                                       (powerdown4                                              ),  //output [1 : 0]
      .powerdown5                                                       (powerdown5                                              ),  //output [1 : 0]
      .powerdown6                                                       (powerdown6                                              ),  //output [1 : 0]
      .powerdown7                                                       (powerdown7                                              ),  //output [1 : 0]
      .rxpolarity0                                                      (rxpolarity0                                             ),  //output
      .rxpolarity1                                                      (rxpolarity1                                             ),  //output
      .rxpolarity2                                                      (rxpolarity2                                             ),  //output
      .rxpolarity3                                                      (rxpolarity3                                             ),  //output
      .rxpolarity4                                                      (rxpolarity4                                             ),  //output
      .rxpolarity5                                                      (rxpolarity5                                             ),  //output
      .rxpolarity6                                                      (rxpolarity6                                             ),  //output
      .rxpolarity7                                                      (rxpolarity7                                             ),  //output
      .txcompl0                                                         (txcompl0                                                ),  //output
      .txcompl1                                                         (txcompl1                                                ),  //output
      .txcompl2                                                         (txcompl2                                                ),  //output
      .txcompl3                                                         (txcompl3                                                ),  //output
      .txcompl4                                                         (txcompl4                                                ),  //output
      .txcompl5                                                         (txcompl5                                                ),  //output
      .txcompl6                                                         (txcompl6                                                ),  //output
      .txcompl7                                                         (txcompl7                                                ),  //output
      .txdata0                                                          (txdata0                                                 ),  //output [7 : 0]
      .txdata1                                                          (txdata1                                                 ),  //output [7 : 0]
      .txdata2                                                          (txdata2                                                 ),  //output [7 : 0]
      .txdata3                                                          (txdata3                                                 ),  //output [7 : 0]
      .txdata4                                                          (txdata4                                                 ),  //output [7 : 0]
      .txdata5                                                          (txdata5                                                 ),  //output [7 : 0]
      .txdata6                                                          (txdata6                                                 ),  //output [7 : 0]
      .txdata7                                                          (txdata7                                                 ),  //output [7 : 0]
      .txdatak0                                                         (txdatak0                                                ),  //output
      .txdatak1                                                         (txdatak1                                                ),  //output
      .txdatak2                                                         (txdatak2                                                ),  //output
      .txdatak3                                                         (txdatak3                                                ),  //output
      .txdatak4                                                         (txdatak4                                                ),  //output
      .txdatak5                                                         (txdatak5                                                ),  //output
      .txdatak6                                                         (txdatak6                                                ),  //output
      .txdatak7                                                         (txdatak7                                                ),  //output
      .txdatavalid0                                                     (txdatavalid0                                            ),  //output
      .txdatavalid1                                                     (txdatavalid1                                            ),  //output
      .txdatavalid2                                                     (txdatavalid2                                            ),  //output
      .txdatavalid3                                                     (txdatavalid3                                            ),  //output
      .txdatavalid4                                                     (txdatavalid4                                            ),  //output
      .txdatavalid5                                                     (txdatavalid5                                            ),  //output
      .txdatavalid6                                                     (txdatavalid6                                            ),  //output
      .txdatavalid7                                                     (txdatavalid7                                            ),  //output
      .txdetectrx0                                                      (txdetectrx0                                             ),  //output
      .txdetectrx1                                                      (txdetectrx1                                             ),  //output
      .txdetectrx2                                                      (txdetectrx2                                             ),  //output
      .txdetectrx3                                                      (txdetectrx3                                             ),  //output
      .txdetectrx4                                                      (txdetectrx4                                             ),  //output
      .txdetectrx5                                                      (txdetectrx5                                             ),  //output
      .txdetectrx6                                                      (txdetectrx6                                             ),  //output
      .txdetectrx7                                                      (txdetectrx7                                             ),  //output
      .txelecidle0                                                      (txelecidle0                                             ),  //output
      .txelecidle1                                                      (txelecidle1                                             ),  //output
      .txelecidle2                                                      (txelecidle2                                             ),  //output
      .txelecidle3                                                      (txelecidle3                                             ),  //output
      .txelecidle4                                                      (txelecidle4                                             ),  //output
      .txelecidle5                                                      (txelecidle5                                             ),  //output
      .txelecidle6                                                      (txelecidle6                                             ),  //output
      .txelecidle7                                                      (txelecidle7                                             ),  //output
      .txmargin0                                                        (txmargin0                                               ),  //output [2 : 0]
      .txmargin1                                                        (txmargin1                                               ),  //output [2 : 0]
      .txmargin2                                                        (txmargin2                                               ),  //output [2 : 0]
      .txmargin3                                                        (txmargin3                                               ),  //output [2 : 0]
      .txmargin4                                                        (txmargin4                                               ),  //output [2 : 0]
      .txmargin5                                                        (txmargin5                                               ),  //output [2 : 0]
      .txmargin6                                                        (txmargin6                                               ),  //output [2 : 0]
      .txmargin7                                                        (txmargin7                                               ),  //output [2 : 0]
      .txdeemph0                                                        (txdeemph0                                               ),  //output
      .txdeemph1                                                        (txdeemph1                                               ),  //output
      .txdeemph2                                                        (txdeemph2                                               ),  //output
      .txdeemph3                                                        (txdeemph3                                               ),  //output
      .txdeemph4                                                        (txdeemph4                                               ),  //output
      .txdeemph5                                                        (txdeemph5                                               ),  //output
      .txdeemph6                                                        (txdeemph6                                               ),  //output
      .txdeemph7                                                        (txdeemph7                                               ),  //output
      .txswing0                                                         (txswing0                                                ),  //output
      .txswing1                                                         (txswing1                                                ),  //output
      .txswing2                                                         (txswing2                                                ),  //output
      .txswing3                                                         (txswing3                                                ),  //output
      .txswing4                                                         (txswing4                                                ),  //output
      .txswing5                                                         (txswing5                                                ),  //output
      .txswing6                                                         (txswing6                                                ),  //output
      .txswing7                                                         (txswing7                                                ),  //output
      .coreclkout                                                       (coreclkout                                              ),  //output
      .derr_cor_ext_rcv0                                                (derr_cor_ext_rcv0                                       ),  //output
      .derr_cor_ext_rpl                                                 (derr_cor_ext_rpl                                        ),  //output
      .derr_rpl                                                         (derr_rpl                                                ),  //output
      .dl_current_speed                                                 (dl_current_speed                                        ),  //output [1:0]
      .dl_ltssm                                                         (dl_ltssm                                                ),  //output [4:0]
      .dlup_exit                                                        (dlup_exit                                               ),  //output
      .ev128ns                                                          (ev128ns                                                 ),  //output
      .ev1us                                                            (ev1us                                                   ),  //output
      .hotrst_exit                                                      (hotrst_exit                                             ),  //output
      .int_status                                                       (int_status                                              ),  //output [3 : 0]
      .l2_exit                                                          (l2_exit                                                 ),  //output
      .lane_act                                                         (lane_act                                                ),  //output [3 : 0]
      .ko_cpl_spc_header                                                (ko_cpl_spc_header                                       ),  //output [7 :0]
      .ko_cpl_spc_data                                                  (ko_cpl_spc_data                                         ),  //output [11 :0]
      .hip_reconfig_readdata                                            (hip_reconfig_readdata                                   ),  //output [15: 0]
      .serr_out                                                         (serr_out                                                ),  //output
      .app_msi_ack                                                      (app_msi_ack                                             ),  //output
      .lmi_ack                                                          (lmi_ack                                                 ),  //output
      .lmi_dout                                                         (lmi_dout                                                ),  //output [31 : 0]
      .pme_to_sr                                                        (pme_to_sr                                               ),  //output
      .rx_bar_dec_func_num                                              (rx_bar_dec_func_num                                     ),  //output [2 : 0]
      .rx_st_bar                                                        (rx_st_bar                                               ),  //output [7 : 0]
      .rx_st_be                                                         (rx_st_be                                                ),  //output [(port_width_data_hwtcl/8)-1 : 0]
      .rx_st_data                                                       (rx_st_data                                              ),  //output [port_width_data_hwtcl-1 : 0]
      .rx_st_sop                                                        (rx_st_sop                                               ),  //output
      .rx_st_eop                                                        (rx_st_eop                                               ),  //output
      .rx_st_empty                                                      (rx_st_empty                                             ),  //output [1:0]
      .rx_st_valid                                                      (rx_st_valid                                             ),  //output
      .rx_st_err                                                        (rx_st_err                                               ),  //output
      .rx_fifo_empty                                                    (rx_fifo_empty                                           ),  //output
      .rx_fifo_full                                                     (rx_fifo_full                                            ),  //output
      .tl_cfg_add                                                       (tl_cfg_add                                              ),  //output [6 : 0]
      .tl_cfg_ctl                                                       (tl_cfg_ctl                                              ),  //output [31 : 0]
      .tl_cfg_ctl_wr                                                    (tl_cfg_ctl_wr                                           ),  //output
      .tl_cfg_sts                                                       (tl_cfg_sts                                              ),  //output [122 : 0]
      .tl_cfg_sts_wr                                                    (tl_cfg_sts_wr                                           ),  //output
      .tx_cred_datafccp                                                 (tx_cred_datafccp                                        ),  //output [11 : 0]
      .tx_cred_datafcnp                                                 (tx_cred_datafcnp                                        ),  //output [11 : 0]
      .tx_cred_datafcp                                                  (tx_cred_datafcp                                         ),  //output [11 : 0]
      .tx_cred_fchipcons                                                (tx_cred_fchipcons                                       ),  //output [5 : 0]
      .tx_cred_fcinfinite                                               (tx_cred_fcinfinite                                      ),  //output [5 : 0]
      .tx_cred_hdrfccp                                                  (tx_cred_hdrfccp                                         ),  //output [7 : 0]
      .tx_cred_hdrfcnp                                                  (tx_cred_hdrfcnp                                         ),  //output [7 : 0]
      .tx_cred_hdrfcp                                                   (tx_cred_hdrfcp                                          ),  //output [7 : 0]
      .tx_st_ready                                                      (tx_st_ready                                             ),  //output
      .tx_fifo_empty                                                    (tx_fifo_empty                                           ),  //output
      .tx_fifo_full                                                     (tx_fifo_full                                            ),  //output
      .tx_fifo_rdp                                                      (tx_fifo_rdp                                             ),  //output  [3:0]
      .tx_fifo_wrp                                                      (tx_fifo_wrp                                             ),  //output  [3:0]
      .rx_in0                                                           (rx_in0                                                  ),  //input
      .rx_in1                                                           (rx_in1                                                  ),  //input
      .rx_in2                                                           (rx_in2                                                  ),  //input
      .rx_in3                                                           (rx_in3                                                  ),  //input
      .rx_in4                                                           (rx_in4                                                  ),  //input
      .rx_in5                                                           (rx_in5                                                  ),  //input
      .rx_in6                                                           (rx_in6                                                  ),  //input
      .rx_in7                                                           (rx_in7                                                  ),  //input
      .tx_out0                                                          (tx_out0                                                 ),  //output
      .tx_out1                                                          (tx_out1                                                 ),  //output
      .tx_out2                                                          (tx_out2                                                 ),  //output
      .tx_out3                                                          (tx_out3                                                 ),  //output
      .tx_out4                                                          (tx_out4                                                 ),  //output
      .tx_out5                                                          (tx_out5                                                 ),  //output
      .tx_out6                                                          (tx_out6                                                 ),  //output
      .tx_out7                                                          (tx_out7                                                 )   //output
      );
endmodule
