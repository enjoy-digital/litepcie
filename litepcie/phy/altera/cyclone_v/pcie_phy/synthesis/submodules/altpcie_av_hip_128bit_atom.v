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

// turn off superfluous verilog processor warnings
// altera message_level Level1
// altera message_off 10034 10035 10036 10037 10230 10240 10030

(* altera_attribute = "-name ALLOW_CHILD_PARTITIONS off" *) module altpcie_av_hip_128bit_atom # (

   parameter MEM_CHECK=0,
   parameter USE_INTERNAL_250MHZ_PLL = 1,
   parameter pll_refclk_freq = "100 MHz", //legal value = "100 MHz", "125 MHz"
   parameter set_pld_clk_x1_625MHz = 0,
   parameter reconfig_to_xcvr_width = 350,
   parameter reconfig_from_xcvr_width = 230,
   parameter hip_reconfig = 0,
   parameter device_family             = "Arria V",

   parameter enable_slot_register = "false",
   parameter pcie_mode = "shared_mode",
   parameter enable_rx_buffer_checking = "false",
   parameter [3:0] single_rx_detect = 4'b0,
   parameter use_crc_forwarding = "false",
   parameter gen12_lane_rate_mode = "gen1", // "gen1", "gen1_gen2"
   parameter lane_mask = "x4",
   parameter multi_function = "one_func",
   parameter disable_link_x2_support = "false",
   parameter ast_width = "rx_tx_64",

   parameter [7:0] port_link_number = 8'b1,
   parameter [4:0] device_number = 5'b0,
   parameter bypass_clk_switch = "disable",
   parameter disable_clk_switch = "disable",
   parameter pipex1_debug_sel = "disable",
   parameter pclk_out_sel = "pclk",
   parameter use_tl_cfg_sync = 0,

   //Multifunction related parameters
   //General/Common across functions
   parameter          porttype_func0          = "ep_native",
   parameter          porttype_func1          = "ep_native",
   parameter          porttype_func2          = "ep_native",
   parameter          porttype_func3          = "ep_native",
   parameter          porttype_func4          = "ep_native",
   parameter          porttype_func5          = "ep_native",
   parameter          porttype_func6          = "ep_native",
   parameter          porttype_func7          = "ep_native",

   parameter [3:0]    eie_before_nfts_count   = 4'b100,
   parameter [7:0]    gen2_diffclock_nfts_count = 8'b11111111,
   parameter [7:0]    gen2_sameclock_nfts_count = 8'b11111111,

   parameter          slotclk_cfg             = "dynamic_slotclkcfg",
   parameter          aspm_optionality        = "true",
   parameter          enable_l1_aspm          = "false",
   parameter          enable_l0s_aspm         = "false",
   parameter [2:0]    l1_exit_latency_sameclock = 3'b0,
   parameter [2:0]    l1_exit_latency_diffclock = 3'b0,
   parameter [2:0]    l0_exit_latency_sameclock = 3'b110,
   parameter [2:0]    l0_exit_latency_diffclock = 3'b110,
   parameter          io_window_addr_width  = "window_32_bit",
   parameter          prefetchable_mem_window_addr_width = "prefetch_32",
   parameter          deemphasis_enable       = "false",
   parameter          pcie_spec_version       = "v2",

   //Function 0

   parameter          vendor_id_0                   = 16'b0001000101110010,
   parameter          device_id_0                   = 16'b1,
   parameter          revision_id_0                 = 8'b1,
   parameter          class_code_0                  = 24'b111111110000000000000000,
   parameter          subsystem_vendor_id_0         = 16'b0001000101110010,
   parameter          subsystem_device_id_0         = 16'b1,

   parameter          bar0_io_space_0               = "false",
   parameter          bar0_64bit_mem_space_0        = "true",
   parameter          bar0_prefetchable_0           = "true",
   parameter [27:0]   bar0_size_mask_0              = 28'b1111111111111111111111111111,
   parameter          bar1_io_space_0               = "false",
   parameter          bar1_64bit_mem_space_0        = "false",
   parameter          bar1_prefetchable_0           = "false",
   parameter [27:0]   bar1_size_mask_0              = 28'b0,
   parameter          bar2_io_space_0               = "false",
   parameter          bar2_64bit_mem_space_0        = "false",
   parameter          bar2_prefetchable_0           = "false",
   parameter [27:0]   bar2_size_mask_0              = 28'b0,
   parameter          bar3_io_space_0               = "false",
   parameter          bar3_64bit_mem_space_0        = "false",
   parameter          bar3_prefetchable_0           = "false",
   parameter [27:0]   bar3_size_mask_0              = 28'b0,
   parameter          bar4_io_space_0               = "false",
   parameter          bar4_64bit_mem_space_0        = "false",
   parameter          bar4_prefetchable_0           = "false",
   parameter [27:0]   bar4_size_mask_0              = 28'b0,
   parameter          bar5_io_space_0               = "false",
   parameter          bar5_64bit_mem_space_0        = "false",
   parameter          bar5_prefetchable_0           = "false",
   parameter [27:0]   bar5_size_mask_0              = 28'b0,

   parameter          msi_multi_message_capable_0   = "count_4",
   parameter          msi_64bit_addressing_capable_0= "true",
   parameter          msi_masking_capable_0         = "false",
   parameter          msi_support_0                 = "true",
   parameter          interrupt_pin_0               = "inta",
   parameter          enable_function_msix_support_0= "true",
   parameter [10:0]   msix_table_size_0             = 11'b0,
   parameter [2:0]    msix_table_bir_0              = 3'b0,
   parameter [28:0]   msix_table_offset_0           = 29'b0,
   parameter [2:0]    msix_pba_bir_0                = 3'b0,
   parameter [28:0]   msix_pba_offset_0             = 29'b0,

   parameter          use_aer_0                     = "false",
   parameter          ecrc_check_capable_0          = "true",
   parameter          ecrc_gen_capable_0            = "true",

   parameter [1:0]    slot_power_scale_0            = 2'b0,
   parameter [7:0]    slot_power_limit_0            = 8'b0,
   parameter [12:0]   slot_number_0                 = 13'b0,

   parameter          max_payload_size_0            = "payload_512",
   parameter          extend_tag_field_0            = "false",
   parameter          completion_timeout_0          = "abcd",
   parameter          enable_completion_timeout_disable_0 = "true",

   parameter          surprise_down_error_support_0 = "false",
   parameter          dll_active_report_support_0   = "false",

   parameter          rx_ei_l0s_0                   = "disable",
   parameter [2:0]    endpoint_l0_latency_0         = 3'b0,
   parameter [2:0]    endpoint_l1_latency_0         = 3'b0,
   parameter          maximum_current_0             = 3'b0,
   parameter          device_specific_init_0        = "false",

   parameter [31:0]   expansion_base_address_register_0 = 32'b0,

   parameter [15:0]   ssvid_0                       = 16'b0,
   parameter [15:0]   ssid_0                        = 16'b0,

   parameter          bridge_port_vga_enable_0      = "false",
   parameter          bridge_port_ssid_support_0    = "false",

   parameter          flr_capability_0              = "true",
   parameter          disable_snoop_packet_0        = "false",

   //Function 1

   parameter          vendor_id_1                   = 16'b0001000101110010,
   parameter          device_id_1                   = 16'b1,
   parameter          revision_id_1                 = 8'b1,
   parameter          class_code_1                  = 24'b111111110000000000000000,
   parameter          subsystem_vendor_id_1         = 16'b0001000101110010,
   parameter          subsystem_device_id_1         = 16'b1,

   parameter          bar0_io_space_1               = "false",
   parameter          bar0_64bit_mem_space_1        = "true",
   parameter          bar0_prefetchable_1           = "true",
   parameter [27:0]   bar0_size_mask_1              = 28'b1111111111111111111111111111,
   parameter          bar1_io_space_1               = "false",
   parameter          bar1_64bit_mem_space_1        = "false",
   parameter          bar1_prefetchable_1           = "false",
   parameter [27:0]   bar1_size_mask_1              = 28'b0,
   parameter          bar2_io_space_1               = "false",
   parameter          bar2_64bit_mem_space_1        = "false",
   parameter          bar2_prefetchable_1           = "false",
   parameter [27:0]   bar2_size_mask_1              = 28'b0,
   parameter          bar3_io_space_1               = "false",
   parameter          bar3_64bit_mem_space_1        = "false",
   parameter          bar3_prefetchable_1           = "false",
   parameter [27:0]   bar3_size_mask_1              = 28'b0,
   parameter          bar4_io_space_1               = "false",
   parameter          bar4_64bit_mem_space_1        = "false",
   parameter          bar4_prefetchable_1           = "false",
   parameter [27:0]   bar4_size_mask_1              = 28'b0,
   parameter          bar5_io_space_1               = "false",
   parameter          bar5_64bit_mem_space_1        = "false",
   parameter          bar5_prefetchable_1           = "false",
   parameter [27:0]   bar5_size_mask_1              = 28'b0,

   parameter          msi_multi_message_capable_1   = "count_4",
   parameter          msi_64bit_addressing_capable_1= "true",
   parameter          msi_masking_capable_1         = "false",
   parameter          msi_support_1                 = "true",
   parameter          interrupt_pin_1               = "inta",
   parameter          enable_function_msix_support_1= "true",
   parameter [10:0]   msix_table_size_1             = 11'b0,
   parameter [2:0]    msix_table_bir_1              = 3'b0,
   parameter [28:0]   msix_table_offset_1           = 29'b0,
   parameter [2:0]    msix_pba_bir_1                = 3'b0,
   parameter [28:0]   msix_pba_offset_1             = 29'b0,

   parameter          use_aer_1                     = "false",
   parameter          ecrc_check_capable_1          = "true",
   parameter          ecrc_gen_capable_1            = "true",

   parameter [1:0]    slot_power_scale_1            = 2'b0,
   parameter [7:0]    slot_power_limit_1            = 8'b0,
   parameter [12:0]   slot_number_1                 = 13'b0,

   parameter          max_payload_size_1            = "payload_512",
   parameter          extend_tag_field_1            = "false",
   parameter          completion_timeout_1          = "abcd",
   parameter          enable_completion_timeout_disable_1 = "true",

   parameter          surprise_down_error_support_1 = "false",
   parameter          dll_active_report_support_1   = "false",

   parameter          rx_ei_l0s_1                   = "disable",
   parameter [2:0]    endpoint_l0_latency_1         = 3'b0,
   parameter [2:0]    endpoint_l1_latency_1         = 3'b0,
   parameter          maximum_current_1             = 3'b0,
   parameter          device_specific_init_1        = "false",

   parameter [31:0]   expansion_base_address_register_1 = 32'b0,

   parameter [15:0]   ssvid_1                       = 16'b0,
   parameter [15:0]   ssid_1                        = 16'b0,

   parameter          bridge_port_vga_enable_1      = "false",
   parameter          bridge_port_ssid_support_1    = "false",

   parameter          flr_capability_1              = "true",
   parameter          disable_snoop_packet_1        = "false",

   //Function 2

   parameter          vendor_id_2                   = 16'b0001000101110010,
   parameter          device_id_2                   = 16'b1,
   parameter          revision_id_2                 = 8'b1,
   parameter          class_code_2                  = 24'b111111110000000000000000,
   parameter          subsystem_vendor_id_2         = 16'b0001000101110010,
   parameter          subsystem_device_id_2         = 16'b1,

   parameter          bar0_io_space_2               = "false",
   parameter          bar0_64bit_mem_space_2        = "true",
   parameter          bar0_prefetchable_2           = "true",
   parameter [27:0]   bar0_size_mask_2              = 28'b1111111111111111111111111111,
   parameter          bar1_io_space_2               = "false",
   parameter          bar1_64bit_mem_space_2        = "false",
   parameter          bar1_prefetchable_2           = "false",
   parameter [27:0]   bar1_size_mask_2              = 28'b0,
   parameter          bar2_io_space_2               = "false",
   parameter          bar2_64bit_mem_space_2        = "false",
   parameter          bar2_prefetchable_2           = "false",
   parameter [27:0]   bar2_size_mask_2              = 28'b0,
   parameter          bar3_io_space_2               = "false",
   parameter          bar3_64bit_mem_space_2        = "false",
   parameter          bar3_prefetchable_2           = "false",
   parameter [27:0]   bar3_size_mask_2              = 28'b0,
   parameter          bar4_io_space_2               = "false",
   parameter          bar4_64bit_mem_space_2        = "false",
   parameter          bar4_prefetchable_2           = "false",
   parameter [27:0]   bar4_size_mask_2              = 28'b0,
   parameter          bar5_io_space_2               = "false",
   parameter          bar5_64bit_mem_space_2        = "false",
   parameter          bar5_prefetchable_2           = "false",
   parameter [27:0]   bar5_size_mask_2              = 28'b0,

   parameter          msi_multi_message_capable_2   = "count_4",
   parameter          msi_64bit_addressing_capable_2= "true",
   parameter          msi_masking_capable_2         = "false",
   parameter          msi_support_2                 = "true",
   parameter          interrupt_pin_2               = "inta",
   parameter          enable_function_msix_support_2= "true",
   parameter [10:0]   msix_table_size_2             = 11'b0,
   parameter [2:0]    msix_table_bir_2              = 3'b0,
   parameter [28:0]   msix_table_offset_2           = 29'b0,
   parameter [2:0]    msix_pba_bir_2                = 3'b0,
   parameter [28:0]   msix_pba_offset_2             = 29'b0,

   parameter          use_aer_2                     = "false",
   parameter          ecrc_check_capable_2          = "true",
   parameter          ecrc_gen_capable_2            = "true",

   parameter [1:0]    slot_power_scale_2            = 2'b0,
   parameter [7:0]    slot_power_limit_2            = 8'b0,
   parameter [12:0]   slot_number_2                 = 13'b0,

   parameter          max_payload_size_2            = "payload_512",
   parameter          extend_tag_field_2            = "false",
   parameter          completion_timeout_2          = "abcd",
   parameter          enable_completion_timeout_disable_2 = "true",

   parameter          surprise_down_error_support_2 = "false",
   parameter          dll_active_report_support_2   = "false",

   parameter          rx_ei_l0s_2                   = "disable",
   parameter [2:0]    endpoint_l0_latency_2         = 3'b0,
   parameter [2:0]    endpoint_l1_latency_2         = 3'b0,
   parameter          maximum_current_2             = 3'b0,
   parameter          device_specific_init_2        = "false",

   parameter [31:0]   expansion_base_address_register_2 = 32'b0,

   parameter [15:0]   ssvid_2                       = 16'b0,
   parameter [15:0]   ssid_2                        = 16'b0,

   parameter          flr_capability_2              = "true",
   parameter          disable_snoop_packet_2        = "false",

   //Function 3

   parameter          vendor_id_3                   = 16'b0001000101110010,
   parameter          device_id_3                   = 16'b1,
   parameter          revision_id_3                 = 8'b1,
   parameter          class_code_3                  = 24'b111111110000000000000000,
   parameter          subsystem_vendor_id_3         = 16'b0001000101110010,
   parameter          subsystem_device_id_3         = 16'b1,

   parameter          bar0_io_space_3               = "false",
   parameter          bar0_64bit_mem_space_3        = "true",
   parameter          bar0_prefetchable_3           = "true",
   parameter [27:0]   bar0_size_mask_3              = 28'b1111111111111111111111111111,
   parameter          bar1_io_space_3               = "false",
   parameter          bar1_64bit_mem_space_3        = "false",
   parameter          bar1_prefetchable_3           = "false",
   parameter [27:0]   bar1_size_mask_3              = 28'b0,
   parameter          bar2_io_space_3               = "false",
   parameter          bar2_64bit_mem_space_3        = "false",
   parameter          bar2_prefetchable_3           = "false",
   parameter [27:0]   bar2_size_mask_3              = 28'b0,
   parameter          bar3_io_space_3               = "false",
   parameter          bar3_64bit_mem_space_3        = "false",
   parameter          bar3_prefetchable_3           = "false",
   parameter [27:0]   bar3_size_mask_3              = 28'b0,
   parameter          bar4_io_space_3               = "false",
   parameter          bar4_64bit_mem_space_3        = "false",
   parameter          bar4_prefetchable_3           = "false",
   parameter [27:0]   bar4_size_mask_3              = 28'b0,
   parameter          bar5_io_space_3               = "false",
   parameter          bar5_64bit_mem_space_3        = "false",
   parameter          bar5_prefetchable_3           = "false",
   parameter [27:0]   bar5_size_mask_3              = 28'b0,

   parameter          msi_multi_message_capable_3   = "count_4",
   parameter          msi_64bit_addressing_capable_3= "true",
   parameter          msi_masking_capable_3         = "false",
   parameter          msi_support_3                 = "true",
   parameter          interrupt_pin_3               = "inta",
   parameter          enable_function_msix_support_3= "true",
   parameter [10:0]   msix_table_size_3             = 11'b0,
   parameter [2:0]    msix_table_bir_3              = 3'b0,
   parameter [28:0]   msix_table_offset_3           = 29'b0,
   parameter [2:0]    msix_pba_bir_3                = 3'b0,
   parameter [28:0]   msix_pba_offset_3             = 29'b0,

   parameter          use_aer_3                     = "false",
   parameter          ecrc_check_capable_3          = "true",
   parameter          ecrc_gen_capable_3            = "true",

   parameter [1:0]    slot_power_scale_3            = 2'b0,
   parameter [7:0]    slot_power_limit_3            = 8'b0,
   parameter [12:0]   slot_number_3                 = 13'b0,

   parameter          max_payload_size_3            = "payload_512",
   parameter          extend_tag_field_3            = "false",
   parameter          completion_timeout_3          = "abcd",
   parameter          enable_completion_timeout_disable_3 = "true",

   parameter          surprise_down_error_support_3 = "false",
   parameter          dll_active_report_support_3   = "false",

   parameter          rx_ei_l0s_3                   = "disable",
   parameter [2:0]    endpoint_l0_latency_3         = 3'b0,
   parameter [2:0]    endpoint_l1_latency_3         = 3'b0,
   parameter          maximum_current_3             = 3'b0,
   parameter          device_specific_init_3        = "false",

   parameter [31:0]   expansion_base_address_register_3 = 32'b0,

   parameter [15:0]   ssvid_3                       = 16'b0,
   parameter [15:0]   ssid_3                        = 16'b0,

   parameter          flr_capability_3              = "true",
   parameter          disable_snoop_packet_3        = "false",

   //Function 4

   parameter          vendor_id_4                   = 16'b0001000101110010,
   parameter          device_id_4                   = 16'b1,
   parameter          revision_id_4                 = 8'b1,
   parameter          class_code_4                  = 24'b111111110000000000000000,
   parameter          subsystem_vendor_id_4         = 16'b0001000101110010,
   parameter          subsystem_device_id_4         = 16'b1,

   parameter          bar0_io_space_4               = "false",
   parameter          bar0_64bit_mem_space_4        = "true",
   parameter          bar0_prefetchable_4           = "true",
   parameter [27:0]   bar0_size_mask_4              = 28'b1111111111111111111111111111,
   parameter          bar1_io_space_4               = "false",
   parameter          bar1_64bit_mem_space_4        = "false",
   parameter          bar1_prefetchable_4           = "false",
   parameter [27:0]   bar1_size_mask_4              = 28'b0,
   parameter          bar2_io_space_4               = "false",
   parameter          bar2_64bit_mem_space_4        = "false",
   parameter          bar2_prefetchable_4           = "false",
   parameter [27:0]   bar2_size_mask_4              = 28'b0,
   parameter          bar3_io_space_4               = "false",
   parameter          bar3_64bit_mem_space_4        = "false",
   parameter          bar3_prefetchable_4           = "false",
   parameter [27:0]   bar3_size_mask_4              = 28'b0,
   parameter          bar4_io_space_4               = "false",
   parameter          bar4_64bit_mem_space_4        = "false",
   parameter          bar4_prefetchable_4           = "false",
   parameter [27:0]   bar4_size_mask_4              = 28'b0,
   parameter          bar5_io_space_4               = "false",
   parameter          bar5_64bit_mem_space_4        = "false",
   parameter          bar5_prefetchable_4           = "false",
   parameter [27:0]   bar5_size_mask_4              = 28'b0,

   parameter          msi_multi_message_capable_4   = "count_4",
   parameter          msi_64bit_addressing_capable_4= "true",
   parameter          msi_masking_capable_4         = "false",
   parameter          msi_support_4                 = "true",
   parameter          interrupt_pin_4               = "inta",
   parameter          enable_function_msix_support_4= "true",
   parameter [10:0]   msix_table_size_4             = 11'b0,
   parameter [2:0]    msix_table_bir_4              = 3'b0,
   parameter [28:0]   msix_table_offset_4           = 29'b0,
   parameter [2:0]    msix_pba_bir_4                = 3'b0,
   parameter [28:0]   msix_pba_offset_4             = 29'b0,

   parameter          use_aer_4                     = "false",
   parameter          ecrc_check_capable_4          = "true",
   parameter          ecrc_gen_capable_4            = "true",

   parameter [1:0]    slot_power_scale_4            = 2'b0,
   parameter [7:0]    slot_power_limit_4            = 8'b0,
   parameter [12:0]   slot_number_4                 = 13'b0,

   parameter          max_payload_size_4            = "payload_512",
   parameter          extend_tag_field_4            = "false",
   parameter          completion_timeout_4          = "abcd",
   parameter          enable_completion_timeout_disable_4 = "true",

   parameter          surprise_down_error_support_4 = "false",
   parameter          dll_active_report_support_4   = "false",

   parameter          rx_ei_l0s_4                   = "disable",
   parameter [2:0]    endpoint_l0_latency_4         = 3'b0,
   parameter [2:0]    endpoint_l1_latency_4         = 3'b0,
   parameter          maximum_current_4             = 3'b0,
   parameter          device_specific_init_4        = "false",

   parameter [31:0]   expansion_base_address_register_4 = 32'b0,

   parameter [15:0]   ssvid_4 = 16'b0,
   parameter [15:0]   ssid_4  = 16'b0,

   parameter          flr_capability_4              = "true",
   parameter          disable_snoop_packet_4        = "false",

   //Function 5

   parameter          vendor_id_5                   = 16'b0001000101110010,
   parameter          device_id_5                   = 16'b1,
   parameter          revision_id_5                 = 8'b1,
   parameter          class_code_5                  = 24'b111111110000000000000000,
   parameter          subsystem_vendor_id_5         = 16'b0001000101110010,
   parameter          subsystem_device_id_5         = 16'b1,

   parameter          bar0_io_space_5               = "false",
   parameter          bar0_64bit_mem_space_5        = "true",
   parameter          bar0_prefetchable_5           = "true",
   parameter [27:0]   bar0_size_mask_5              = 28'b1111111111111111111111111111,
   parameter          bar1_io_space_5               = "false",
   parameter          bar1_64bit_mem_space_5        = "false",
   parameter          bar1_prefetchable_5           = "false",
   parameter [27:0]   bar1_size_mask_5              = 28'b0,
   parameter          bar2_io_space_5               = "false",
   parameter          bar2_64bit_mem_space_5        = "false",
   parameter          bar2_prefetchable_5           = "false",
   parameter [27:0]   bar2_size_mask_5              = 28'b0,
   parameter          bar3_io_space_5               = "false",
   parameter          bar3_64bit_mem_space_5        = "false",
   parameter          bar3_prefetchable_5           = "false",
   parameter [27:0]   bar3_size_mask_5              = 28'b0,
   parameter          bar4_io_space_5               = "false",
   parameter          bar4_64bit_mem_space_5        = "false",
   parameter          bar4_prefetchable_5           = "false",
   parameter [27:0]   bar4_size_mask_5              = 28'b0,
   parameter          bar5_io_space_5               = "false",
   parameter          bar5_64bit_mem_space_5        = "false",
   parameter          bar5_prefetchable_5           = "false",
   parameter [27:0]   bar5_size_mask_5              = 28'b0,

   parameter          msi_multi_message_capable_5   = "count_4",
   parameter          msi_64bit_addressing_capable_5= "true",
   parameter          msi_masking_capable_5         = "false",
   parameter          msi_support_5                 = "true",
   parameter          interrupt_pin_5               = "inta",
   parameter          enable_function_msix_support_5= "true",
   parameter [10:0]   msix_table_size_5             = 11'b0,
   parameter [2:0]    msix_table_bir_5              = 3'b0,
   parameter [28:0]   msix_table_offset_5           = 29'b0,
   parameter [2:0]    msix_pba_bir_5                = 3'b0,
   parameter [28:0]   msix_pba_offset_5             = 29'b0,

   parameter          use_aer_5                     = "false",
   parameter          ecrc_check_capable_5          = "true",
   parameter          ecrc_gen_capable_5            = "true",

   parameter [1:0]    slot_power_scale_5            = 2'b0,
   parameter [7:0]    slot_power_limit_5            = 8'b0,
   parameter [12:0]   slot_number_5                 = 13'b0,

   parameter          max_payload_size_5            = "payload_512",
   parameter          extend_tag_field_5            = "false",
   parameter          completion_timeout_5          = "abcd",
   parameter          enable_completion_timeout_disable_5 = "true",

   parameter          surprise_down_error_support_5 = "false",
   parameter          dll_active_report_support_5   = "false",

   parameter          rx_ei_l0s_5                   = "disable",
   parameter [2:0]    endpoint_l0_latency_5         = 3'b0,
   parameter [2:0]    endpoint_l1_latency_5         = 3'b0,
   parameter          maximum_current_5             = 3'b0,
   parameter          device_specific_init_5        = "false",

   parameter [31:0]   expansion_base_address_register_5 = 32'b0,

   parameter [15:0]   ssvid_5                       = 16'b0,
   parameter [15:0]   ssid_5                        = 16'b0,

   parameter          flr_capability_5              = "true",
   parameter          disable_snoop_packet_5        = "false",

   //Function 6

   parameter          vendor_id_6                   = 16'b0001000101110010,
   parameter          device_id_6                   = 16'b1,
   parameter          revision_id_6                 = 8'b1,
   parameter          class_code_6                  = 24'b111111110000000000000000,
   parameter          subsystem_vendor_id_6         = 16'b0001000101110010,
   parameter          subsystem_device_id_6         = 16'b1,

   parameter          bar0_io_space_6               = "false",
   parameter          bar0_64bit_mem_space_6        = "true",
   parameter          bar0_prefetchable_6           = "true",
   parameter [27:0]   bar0_size_mask_6              = 28'b1111111111111111111111111111,
   parameter          bar1_io_space_6               = "false",
   parameter          bar1_64bit_mem_space_6        = "false",
   parameter          bar1_prefetchable_6           = "false",
   parameter [27:0]   bar1_size_mask_6              = 28'b0,
   parameter          bar2_io_space_6               = "false",
   parameter          bar2_64bit_mem_space_6        = "false",
   parameter          bar2_prefetchable_6           = "false",
   parameter [27:0]   bar2_size_mask_6              = 28'b0,
   parameter          bar3_io_space_6               = "false",
   parameter          bar3_64bit_mem_space_6        = "false",
   parameter          bar3_prefetchable_6           = "false",
   parameter [27:0]   bar3_size_mask_6              = 28'b0,
   parameter          bar4_io_space_6               = "false",
   parameter          bar4_64bit_mem_space_6        = "false",
   parameter          bar4_prefetchable_6           = "false",
   parameter [27:0]   bar4_size_mask_6              = 28'b0,
   parameter          bar5_io_space_6               = "false",
   parameter          bar5_64bit_mem_space_6        = "false",
   parameter          bar5_prefetchable_6           = "false",
   parameter [27:0]   bar5_size_mask_6              = 28'b0,

   parameter          msi_multi_message_capable_6   = "count_4",
   parameter          msi_64bit_addressing_capable_6= "true",
   parameter          msi_masking_capable_6         = "false",
   parameter          msi_support_6                 = "true",
   parameter          interrupt_pin_6               = "inta",
   parameter          enable_function_msix_support_6= "true",
   parameter [10:0]   msix_table_size_6             = 11'b0,
   parameter [2:0]    msix_table_bir_6              = 3'b0,
   parameter [28:0]   msix_table_offset_6           = 29'b0,
   parameter [2:0]    msix_pba_bir_6                = 3'b0,
   parameter [28:0]   msix_pba_offset_6             = 29'b0,

   parameter          use_aer_6                     = "false",
   parameter          ecrc_check_capable_6          = "true",
   parameter          ecrc_gen_capable_6            = "true",

   parameter [1:0]    slot_power_scale_6            = 2'b0,
   parameter [7:0]    slot_power_limit_6            = 8'b0,
   parameter [12:0]   slot_number_6                 = 13'b0,

   parameter          max_payload_size_6            = "payload_512",
   parameter          extend_tag_field_6            = "false",
   parameter          completion_timeout_6          = "abcd",
   parameter          enable_completion_timeout_disable_6 = "true",

   parameter          surprise_down_error_support_6 = "false",
   parameter          dll_active_report_support_6   = "false",

   parameter          rx_ei_l0s_6                   = "disable",
   parameter [2:0]    endpoint_l0_latency_6         = 3'b0,
   parameter [2:0]    endpoint_l1_latency_6         = 3'b0,
   parameter          maximum_current_6             = 3'b0,
   parameter          device_specific_init_6        = "false",

   parameter [31:0]   expansion_base_address_register_6 = 32'b0,

   parameter [15:0]   ssvid_6 = 16'b0,
   parameter [15:0]   ssid_6  = 16'b0,

   parameter          flr_capability_6              = "true",
   parameter          disable_snoop_packet_6        = "false",

   //Function 7

   parameter          vendor_id_7                   = 16'b0001000101110010,
   parameter          device_id_7                   = 16'b1,
   parameter          revision_id_7                 = 8'b1,
   parameter          class_code_7                  = 24'b111111110000000000000000,
   parameter          subsystem_vendor_id_7         = 16'b0001000101110010,
   parameter          subsystem_device_id_7         = 16'b1,

   parameter          bar0_io_space_7               = "false",
   parameter          bar0_64bit_mem_space_7        = "true",
   parameter          bar0_prefetchable_7           = "true",
   parameter [27:0]   bar0_size_mask_7              = 28'b1111111111111111111111111111,
   parameter          bar1_io_space_7               = "false",
   parameter          bar1_64bit_mem_space_7        = "false",
   parameter          bar1_prefetchable_7           = "false",
   parameter [27:0]   bar1_size_mask_7              = 28'b0,
   parameter          bar2_io_space_7               = "false",
   parameter          bar2_64bit_mem_space_7        = "false",
   parameter          bar2_prefetchable_7           = "false",
   parameter [27:0]   bar2_size_mask_7              = 28'b0,
   parameter          bar3_io_space_7               = "false",
   parameter          bar3_64bit_mem_space_7        = "false",
   parameter          bar3_prefetchable_7           = "false",
   parameter [27:0]   bar3_size_mask_7              = 28'b0,
   parameter          bar4_io_space_7               = "false",
   parameter          bar4_64bit_mem_space_7        = "false",
   parameter          bar4_prefetchable_7           = "false",
   parameter [27:0]   bar4_size_mask_7              = 28'b0,
   parameter          bar5_io_space_7               = "false",
   parameter          bar5_64bit_mem_space_7        = "false",
   parameter          bar5_prefetchable_7           = "false",
   parameter [27:0]   bar5_size_mask_7              = 28'b0,

   parameter          msi_multi_message_capable_7   = "count_4",
   parameter          msi_64bit_addressing_capable_7= "true",
   parameter          msi_masking_capable_7         = "false",
   parameter          msi_support_7                 = "true",
   parameter          interrupt_pin_7               = "inta",
   parameter          enable_function_msix_support_7= "true",
   parameter [10:0]   msix_table_size_7             = 11'b0,
   parameter [2:0]    msix_table_bir_7              = 3'b0,
   parameter [28:0]   msix_table_offset_7           = 29'b0,
   parameter [2:0]    msix_pba_bir_7                = 3'b0,
   parameter [28:0]   msix_pba_offset_7             = 29'b0,

   parameter          use_aer_7                     = "false",
   parameter          ecrc_check_capable_7          = "true",
   parameter          ecrc_gen_capable_7            = "true",

   parameter [1:0]    slot_power_scale_7            = 2'b0,
   parameter [7:0]    slot_power_limit_7            = 8'b0,
   parameter [12:0]   slot_number_7                 = 13'b0,

   parameter          max_payload_size_7            = "payload_512",
   parameter          extend_tag_field_7            = "false",
   parameter          completion_timeout_7          = "abcd",
   parameter          enable_completion_timeout_disable_7 = "true",

   parameter          surprise_down_error_support_7 = "false",
   parameter          dll_active_report_support_7   = "false",

   parameter          rx_ei_l0s_7                   = "disable",
   parameter [2:0]    endpoint_l0_latency_7         = 3'b0,
   parameter [2:0]    endpoint_l1_latency_7         = 3'b0,
   parameter          maximum_current_7             = 3'b0,
   parameter          device_specific_init_7        = "false",

   parameter [31:0]   expansion_base_address_register_7 = 32'b0,

   parameter [15:0]   ssvid_7                       = 16'b0,
   parameter [15:0]   ssid_7                        = 16'b0,

   parameter          flr_capability_7              = "true",
   parameter          disable_snoop_packet_7        = "false",

//-------------------------

   parameter no_soft_reset = "false",
   parameter d1_support = "false",
   parameter d2_support = "false",
   parameter d0_pme = "false",
   parameter d1_pme = "false",
   parameter d2_pme = "false",
   parameter d3_hot_pme = "false",
   parameter d3_cold_pme = "false",
   parameter low_priority_vc = "single_vc",
   parameter [2:0] indicator = 3'b111,
   parameter [15:0] retry_buffer_memory_settings  = 16'b0000_0000_0000_0110,
   parameter [15:0] vc0_rx_buffer_memory_settings = 16'b0000_0000_0000_0110,
   parameter [6:0] hot_plug_support = 7'b0,
   parameter [7:0] diffclock_nfts_count = 8'b1000_0000,
   parameter [7:0] sameclock_nfts_count = 8'b1000_0000,
   parameter no_command_completed = "true",
   parameter l2_async_logic = "enable",
   parameter enable_adapter_half_rate_mode = "false",
   parameter vc0_clk_enable = "true",
   parameter register_pipe_signals = "false",
   parameter [3:0] rx_cdc_almost_full = 4'b1100,
   parameter [3:0] tx_cdc_almost_full = 4'b1100,
   parameter [7:0] rx_l0s_count_idl = 8'b0,
   parameter [3:0] cdc_dummy_insert_limit = 4'b1011,
   parameter [7:0] ei_delay_powerdown_count = 8'b1010,
   parameter [19:0] millisecond_cycle_count = 20'b00111100101010110100,
   parameter [10:0] skp_os_schedule_count = 11'b0,
   parameter [10:0] fc_init_timer = 11'b10000000000,
   parameter [4:0] l01_entry_latency = 5'b11111,
   parameter [4:0] flow_control_update_count = 5'b11110,
   parameter [7:0] flow_control_timeout_count = 8'b11001000,
   parameter [7:0] vc0_rx_flow_ctrl_posted_header = 8'b00010010,
   parameter [11:0] vc0_rx_flow_ctrl_posted_data = 12'b000001011110,
   parameter [7:0] vc0_rx_flow_ctrl_nonposted_header = 8'b00100000,
   parameter [7:0] vc0_rx_flow_ctrl_nonposted_data = 8'b0,
   parameter [7:0] vc0_rx_flow_ctrl_compl_header = 8'b00000000,
   parameter [11:0] vc0_rx_flow_ctrl_compl_data = 12'b000000000000,
   parameter [9:0] rx_ptr0_posted_dpram_min = 10'b0,
   parameter [9:0] rx_ptr0_posted_dpram_max = 10'b0,
   parameter [9:0] rx_ptr0_nonposted_dpram_min = 10'b0,
   parameter [9:0] rx_ptr0_nonposted_dpram_max = 10'b0,
   parameter [7:0] retry_buffer_last_active_address = 8'b11111111,
   parameter [74:0] bist_memory_settings = 75'b0,
   parameter credit_buffer_allocation_aux = "balanced",
   parameter iei_enable_settings = "gen2_infei_infsd_gen1_infei_sd",
   parameter [15:0] vsec_id = 16'b1000101110010,
   parameter cvp_rate_sel = "full_rate",
   parameter hard_reset_bypass = "false",
   parameter cvp_data_compressed = "false",
   parameter cvp_data_encrypted = "false",
   parameter cvp_mode_reset = "false",
   parameter cvp_clk_reset = "false",
   parameter cvp_enable = "cvp_dis", // "cvp_dis", "cvp_en"
   parameter [3:0] vsec_cap = 4'b0,
   parameter [127:0] jtag_id = 128'b0,
   parameter [15:0] user_id = 16'b0,
   parameter disable_auto_crs = "disable",
   parameter [7:0] tx_swing_data = 8'b0,
   //Pipe related parameters
   parameter hip_hard_reset = "disable",

   // Exposing the Pre-emphasis and VOD static values
   parameter rpre_emph_a_val = 6'd0,
   parameter rpre_emph_b_val = 6'd0,
   parameter rpre_emph_c_val = 6'd0,
   parameter rpre_emph_d_val = 6'd0,
   parameter rpre_emph_e_val = 6'd0,
   parameter rvod_sel_a_val  = 6'd0,
   parameter rvod_sel_b_val  = 6'd0,
   parameter rvod_sel_c_val  = 6'd0,
   parameter rvod_sel_d_val  = 6'd0,
   parameter rvod_sel_e_val  = 6'd0
) (
      // Reset signals
   input       pipe_mode,
   input       por,
   output  reg reset_status,
   input       pin_perst,

   // Clock
   input                 pld_clk,
   input                 pclk_in,
   output                clk250_out,
   output                clk500_out,
   output                serdes_pll_locked,

   // Serdes related
   //input                 cal_blk_clk,
   input                 refclk,

   // Reconfig GXB
   input                [reconfig_to_xcvr_width-1:0]   reconfig_to_xcvr,
   input                busy_xcvr_reconfig,
   output               [reconfig_from_xcvr_width-1:0] reconfig_from_xcvr,
   output               fixedclk_locked,

   // HIP control signals
   input  [1 : 0]        mode,
   input  [39: 0]       test_in,
   output [63: 0]       test_out,

   //HIP AVMM Interface signals
   input [9:0]    avmmaddress,
   input [1:0]    avmmbyteen,
   input          avmmclk,
   input          avmmread,
   input          avmmrstn,
   input          avmmwrite,
   input [15:0]   avmmwritedata,
   output [15:0]   avmmreaddata,

   // Input PIPE simulation _ext for simulation only
   input                 phystatus0_ext,
   input                 phystatus1_ext,
   input                 phystatus2_ext,
   input                 phystatus3_ext,
   input                 phystatus4_ext,
   input                 phystatus5_ext,
   input                 phystatus6_ext,
   input                 phystatus7_ext,
   input  [7 : 0]        rxdata0_ext,
   input  [7 : 0]        rxdata1_ext,
   input  [7 : 0]        rxdata2_ext,
   input  [7 : 0]        rxdata3_ext,
   input  [7 : 0]        rxdata4_ext,
   input  [7 : 0]        rxdata5_ext,
   input  [7 : 0]        rxdata6_ext,
   input  [7 : 0]        rxdata7_ext,
   input                 rxdatak0_ext,
   input                 rxdatak1_ext,
   input                 rxdatak2_ext,
   input                 rxdatak3_ext,
   input                 rxdatak4_ext,
   input                 rxdatak5_ext,
   input                 rxdatak6_ext,
   input                 rxdatak7_ext,
   input                 rxelecidle0_ext,
   input                 rxelecidle1_ext,
   input                 rxelecidle2_ext,
   input                 rxelecidle3_ext,
   input                 rxelecidle4_ext,
   input                 rxelecidle5_ext,
   input                 rxelecidle6_ext,
   input                 rxelecidle7_ext,
   input  [2 : 0]        rxstatus0_ext,
   input  [2 : 0]        rxstatus1_ext,
   input  [2 : 0]        rxstatus2_ext,
   input  [2 : 0]        rxstatus3_ext,
   input  [2 : 0]        rxstatus4_ext,
   input  [2 : 0]        rxstatus5_ext,
   input  [2 : 0]        rxstatus6_ext,
   input  [2 : 0]        rxstatus7_ext,
   input                 rxvalid0_ext,
   input                 rxvalid1_ext,
   input                 rxvalid2_ext,
   input                 rxvalid3_ext,
   input                 rxvalid4_ext,
   input                 rxvalid5_ext,
   input                 rxvalid6_ext,
   input                 rxvalid7_ext,

   // Application signals inputs
   input [4:0]    tl_aer_msi_num,
   input [2:0]    tl_app_inta_funcnum,
   input [2:0]    tl_app_intb_funcnum,
   input [2:0]    tl_app_intc_funcnum,
   input [2:0]    tl_app_intd_funcnum,
   input          tl_app_inta_sts,
   input          tl_app_intb_sts,
   input          tl_app_intc_sts,
   input          tl_app_intd_sts,
   input [2:0]    tl_app_msi_func,
   input [4:0]    tl_app_msi_num,
   input          tl_app_msi_req,
   input [2:0]    tl_app_msi_tc,
   input [4:0]    tl_hpg_ctrl_er,
   input [4:0]    tl_pex_msi_num,
   input [14:0]   lmi_addr,
   input [31:0]   lmi_din,
   input          lmi_rden,
   input          lmi_wren,
   input          tl_pm_auxpwr,
   input [9:0]    tl_pm_data,
   input          tl_pme_to_cr,
   input          tl_pm_event,
   input [2:0]    tl_pm_event_func,
   input          rx_mask_vc0,
   input          rx_st_ready_vc0,

   input [127:0]  tx_st_data_vc0,
   input [1:0]    tx_st_sop_vc0,
   input [1:0]    tx_st_eop_vc0,
   input          tx_st_err_vc0,
   input          tx_st_valid_vc0,

   input          mdio_clk,
   input [1:0]    mdio_dev_addr,
   input          mdio_in,
   input          ser_shift_load,
   input          cbhipmdioen,
   input          clrrxpath,

   input [6:0]    cpl_err,
   input [2:0]    cpl_errfunc,
   input [7:0]    cpl_pending,
   input          tl_slotclk_cfg,
   input [15:0]   pci_err,
   input [1:0]    hipextraclkin,
   input [29:0]   hipextrain,

   // Input for internal test port (PE/TE)
   input       bistscanenn,
   input       bistscanin,
   input       bisttestenn,
   input       scanmoden,
   input       scanenn,
   //input                 usermode,
   input          dl_comclk_reg,
   input [12:0]   dl_ctrl_link2,
   input [7:0]    dl_vc_ctrl,
   input          dpriorefclkdig,
   input          interfacesel,

   // Input for past QII 10.0 support
   input  [14 : 0]       dbgpipex1rx,


   // Output Pipe interface
   output [2 : 0]        eidleinfersel0_ext,
   output [2 : 0]        eidleinfersel1_ext,
   output [2 : 0]        eidleinfersel2_ext,
   output [2 : 0]        eidleinfersel3_ext,
   output [2 : 0]        eidleinfersel4_ext,
   output [2 : 0]        eidleinfersel5_ext,
   output [2 : 0]        eidleinfersel6_ext,
   output [2 : 0]        eidleinfersel7_ext,
   output [1 : 0]        powerdown0_ext,
   output [1 : 0]        powerdown1_ext,
   output [1 : 0]        powerdown2_ext,
   output [1 : 0]        powerdown3_ext,
   output [1 : 0]        powerdown4_ext,
   output [1 : 0]        powerdown5_ext,
   output [1 : 0]        powerdown6_ext,
   output [1 : 0]        powerdown7_ext,
   output                rxpolarity0_ext,
   output                rxpolarity1_ext,
   output                rxpolarity2_ext,
   output                rxpolarity3_ext,
   output                rxpolarity4_ext,
   output                rxpolarity5_ext,
   output                rxpolarity6_ext,
   output                rxpolarity7_ext,
   output                txcompl0_ext,
   output                txcompl1_ext,
   output                txcompl2_ext,
   output                txcompl3_ext,
   output                txcompl4_ext,
   output                txcompl5_ext,
   output                txcompl6_ext,
   output                txcompl7_ext,
   output [7 : 0]        txdata0_ext,
   output [7 : 0]        txdata1_ext,
   output [7 : 0]        txdata2_ext,
   output [7 : 0]        txdata3_ext,
   output [7 : 0]        txdata4_ext,
   output [7 : 0]        txdata5_ext,
   output [7 : 0]        txdata6_ext,
   output [7 : 0]        txdata7_ext,
   output                txdatak0_ext,
   output                txdatak1_ext,
   output                txdatak2_ext,
   output                txdatak3_ext,
   output                txdatak4_ext,
   output                txdatak5_ext,
   output                txdatak6_ext,
   output                txdatak7_ext,
   output                txdatavalid0_ext,
   output                txdatavalid1_ext,
   output                txdatavalid2_ext,
   output                txdatavalid3_ext,
   output                txdatavalid4_ext,
   output                txdatavalid5_ext,
   output                txdatavalid6_ext,
   output                txdatavalid7_ext,
   output                txdetectrx0_ext,
   output                txdetectrx1_ext,
   output                txdetectrx2_ext,
   output                txdetectrx3_ext,
   output                txdetectrx4_ext,
   output                txdetectrx5_ext,
   output                txdetectrx6_ext,
   output                txdetectrx7_ext,
   output                txelecidle0_ext,
   output                txelecidle1_ext,
   output                txelecidle2_ext,
   output                txelecidle3_ext,
   output                txelecidle4_ext,
   output                txelecidle5_ext,
   output                txelecidle6_ext,
   output                txelecidle7_ext,
   output [2 : 0]        txmargin0_ext,
   output [2 : 0]        txmargin1_ext,
   output [2 : 0]        txmargin2_ext,
   output [2 : 0]        txmargin3_ext,
   output [2 : 0]        txmargin4_ext,
   output [2 : 0]        txmargin5_ext,
   output [2 : 0]        txmargin6_ext,
   output [2 : 0]        txmargin7_ext,
   output                txdeemph0_ext,
   output                txdeemph1_ext,
   output                txdeemph2_ext,
   output                txdeemph3_ext,
   output                txdeemph4_ext,
   output                txdeemph5_ext,
   output                txdeemph6_ext,
   output                txdeemph7_ext,
   output                txswing0_ext,
   output                txswing1_ext,
   output                txswing2_ext,
   output                txswing3_ext,
   output                txswing4_ext,
   output                txswing5_ext,
   output                txswing6_ext,
   output                txswing7_ext,

   // Output HIP Status signals
   input          pldcoreready,
   output  reg    pld_clk_in_use,
   output         coreclkout,
   //output [1 : 0]        currentspeed,
   output         derr_cor_ext_rcv0,
   //output         derr_cor_ext_rcv1,
   output         derr_cor_ext_rpl,
   output         derr_rpl,
   output [1:0]   dl_current_speed,
   output [4:0]   dl_ltssm,
   output         dlup_exit,
   output         ev128ns,
   output         ev1us,
   output         hotrst_exit,
   output [3:0]   int_status,
   output         l2_exit,
   output [3:0]   lane_act,
   output         ltssml0state,
   output         rate,
   output [7:0]   flr_sts,
   output         r2c_err_ext,
   output         successful_speed_negotiation_int,

   // Output Application interface
   output          tl_app_inta_ack,
   output          tl_app_intb_ack,
   output          tl_app_intc_ack,
   output          tl_app_intd_ack,
   output          tl_app_msi_ack,
   output          lmi_ack,
   output [31: 0]  lmi_dout,
   output          tl_pme_to_sr,

   output [2:0]    rx_bar_dec_func_num_vc0,
   output [7:0]    rx_bar_dec_vc0,
   output [15:0]   rx_be_vc0,
   output [127:0]  rx_st_data_vc0,
   output [1:0]    rx_st_sop_vc0,
   output [1:0]    rx_st_eop_vc0,
   output          rx_st_valid_vc0,
   output          rx_st_err_vc0,
   output          rx_fifo_empty_vc0,
   output          rx_fifo_full_vc0,
   output [3:0]    rx_fifo_rdp_vc0,
   output [3:0]    rx_fifo_wrp_vc0,

   output          serr_out,
   output          swdn_wake,
   output          swup_hotrst,
   output [6:0]   tl_cfg_add,
   output [31:0]  tl_cfg_ctl,
   output         tl_cfg_ctl_wr,
   output [122:0] tl_cfg_sts,
   output         tl_cfg_sts_wr,
   output [11:0]  tx_cred_datafccp,
   output [11:0]  tx_cred_datafcnp,
   output [11:0]  tx_cred_datafcp,
   output [5:0]   tx_cred_fchipcons,
   output [5:0]   tx_cred_fcinfinite,
   output [7:0]   tx_cred_hdrfccp,
   output [7:0]   tx_cred_hdrfcnp,
   output [7:0]   tx_cred_hdrfcp,
   output [35:0]  tx_cred_vc0,
   output         tx_st_ready_vc0,
   output         tx_fifo_empty_vc0,
   output         tx_fifo_full_vc0,
   output [3:0]   tx_fifo_rdp_vc0,
   output [3:0]   tx_fifo_wrp_vc0,
   output         mdio_oen_n,
   output         mdio_out,
   output [1:0]   hipextraclkout,
   output [29:0]  hipextraout,

   // serial interface
   input          rx_in0,
   input          rx_in1,
   input          rx_in2,
   input          rx_in3,
   input          rx_in4,
   input          rx_in5,
   input          rx_in6,
   input          rx_in7,

   output         tx_out0,
   output         tx_out1,
   output         tx_out2,
   output         tx_out3,
   output         tx_out4,
   output         tx_out5,
   output         tx_out6,
   output         tx_out7,

   // Output for internal test port (PE/TE)
   output      bistdonearcv0,
   output      bistdonearcv1,
   output      bistdonearpl,
   output      bistdonebrcv0,
   output      bistdonebrcv1,
   output      bistdonebrpl,
   output      bistpassrcv0,
   output      bistpassrcv1,
   output      bistpassrpl,
   output      bistscanoutrcv0,
   output      bistscanoutrcv1,
   output      bistscanoutrpl,
   output      wakeoen
   );

//////////////////////////
// Function Declartions:
//////////////////////////

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

   function [8*25:1] get_core_clk_divider_param;
      input [8*25:1] l_ast_width;
      input [8*25:1] l_gen12_lane_rate_mode;
      input [8*25:1] l_lane_mask;
      input x1_625MHz;
      begin
         if      ((low_str(l_ast_width)=="rx_tx_64" ) && (low_str(l_gen12_lane_rate_mode)=="gen1"     ) && (low_str(l_lane_mask)=="x1"))  get_core_clk_divider_param=(x1_625MHz==1)?"div_4":"div_2"; // Gen1 : pllfixedclk = 250MHz
         else if ((low_str(l_ast_width)=="rx_tx_64" ) && (low_str(l_gen12_lane_rate_mode)=="gen1"     ) && (low_str(l_lane_mask)=="x2"))  get_core_clk_divider_param="div_2";
         else if ((low_str(l_ast_width)=="rx_tx_64" ) && (low_str(l_gen12_lane_rate_mode)=="gen1"     ) && (low_str(l_lane_mask)=="x4"))  get_core_clk_divider_param="div_2";
         else if ((low_str(l_ast_width)=="rx_tx_64" ) && (low_str(l_gen12_lane_rate_mode)=="gen1_gen2") && (low_str(l_lane_mask)=="x1"))  get_core_clk_divider_param=(x1_625MHz==1)?"div_8":"div_4"; // Gen2 : pllfixedclk = 500MHz
         else if ((low_str(l_ast_width)=="rx_tx_64" ) && (low_str(l_gen12_lane_rate_mode)=="gen1_gen2") && (low_str(l_lane_mask)=="x2"))  get_core_clk_divider_param="div_4"; // Gen2 : pllfixedclk = 500MHz

         else if ((low_str(l_ast_width)=="rx_tx_128") && (low_str(l_gen12_lane_rate_mode)=="gen1"     ) && (low_str(l_lane_mask)=="x1"))  get_core_clk_divider_param="div_4"; // Gen1 : pllfixedclk = 250MHz
         else if ((low_str(l_ast_width)=="rx_tx_128") && (low_str(l_gen12_lane_rate_mode)=="gen1"     ) && (low_str(l_lane_mask)=="x2"))  get_core_clk_divider_param="div_4";
         else if ((low_str(l_ast_width)=="rx_tx_128") && (low_str(l_gen12_lane_rate_mode)=="gen1"     ) && (low_str(l_lane_mask)=="x4"))  get_core_clk_divider_param="div_2";
         else if ((low_str(l_ast_width)=="rx_tx_128") && (low_str(l_gen12_lane_rate_mode)=="gen1"     ) && (low_str(l_lane_mask)=="x8"))  get_core_clk_divider_param="div_1";
         else if ((low_str(l_ast_width)=="rx_tx_128") && (low_str(l_gen12_lane_rate_mode)=="gen1_gen2") && (low_str(l_lane_mask)=="x1"))  get_core_clk_divider_param="div_8"; // Gen2 : pllfixedclk = 500MHz
         else if ((low_str(l_ast_width)=="rx_tx_128") && (low_str(l_gen12_lane_rate_mode)=="gen1_gen2") && (low_str(l_lane_mask)=="x2"))  get_core_clk_divider_param="div_4";
         else if ((low_str(l_ast_width)=="rx_tx_128") && (low_str(l_gen12_lane_rate_mode)=="gen1_gen2") && (low_str(l_lane_mask)=="x4"))  get_core_clk_divider_param="div_2";
         else                                                                                                                             get_core_clk_divider_param="div_1";
      end
   endfunction

   // Convert parameter strings to lower case
   genvar i;

   //synthesis translate_off
   localparam ALTPCIE_HIP_128BIT_SIM_ONLY  = 1;
   //synthesis translate_on

   //synthesis read_comments_as_HDL on
   //localparam ALTPCIE_HIP_128BIT_SIM_ONLY = 0;
   //synthesis read_comments_as_HDL off

   localparam PLD_CLK_IS_250MHZ =0;
   localparam USE_HARD_RESET    = (low_str(hip_hard_reset)=="disable") ? 0:1;
   localparam ST_DATA_WIDTH     =(low_str(ast_width)=="rx_tx_128")?128:64;
   localparam ST_BE_WIDTH       =(low_str(ast_width)=="rx_tx_128")? 16: 8;
   localparam ST_CTRL_WIDTH     =(low_str(ast_width)=="rx_tx_128")?  2: 1;

   // Control HRC fabric input reset
   localparam HIPRST_USE_LOCAL_NPOR              = (porttype_func0=="rp")?1:0;// Disabled for CVP POF, RP is never CVP
   localparam HIPRST_USE_DLUP_EXIT               = (porttype_func0=="rp")?0:1;// HIP self-reset in altpcie_rs_hip/altpcie_rs_serdes only applicable for EP
   localparam HIPRST_USE_LTSSM_HOTRESET          = (porttype_func0=="rp")?0:1;// .. ..
   localparam HIPRST_USE_LTSSM_DISABLE           = (porttype_func0=="rp")?0:1;// .. ..
   localparam HIPRST_USE_LTSSM_EXIT_DETECTQUIET  = (porttype_func0=="rp")?0:1;// .. ..
   localparam HIPRST_USE_L2                      = (porttype_func0=="rp")?0:1;// .. ..

   localparam LANES             = (low_str(lane_mask)=="x1")?1:(low_str(lane_mask)=="x2")?2:(low_str(lane_mask)=="x4")?4:8; //legal value: 1+
   localparam LANES_P1          = LANES+1;
   localparam [127:0] ONES      = 128'HFFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF_FFFF;
   localparam [127:0] ZEROS     = 128'H0000_0000_0000_0000_0000_0000_0000_0000;

   // HIP Localparams -->
   localparam func_mode                      = "enable";
   localparam bonding_mode                   = (low_str(func_mode)=="enable") ? (((low_str(gen12_lane_rate_mode)=="gen1")&&(low_str(lane_mask)=="x8")) ? "x8_g1"    :
                                                                                                                           (low_str(lane_mask)=="x4")  ?  "x4"      :
                                                                                                                           (low_str(lane_mask)=="x2")  ?  "x2"      :"x1") : "bond_disable";
   localparam prot_mode                      = (low_str(func_mode)=="enable") ? (((low_str(gen12_lane_rate_mode)=="gen2")&&(low_str(lane_mask)!="x8")) ? "pipe_g2"  : "pipe_g1") : "disabled_prot_mode";
   localparam vc_enable                      = "single_vc" ;
   localparam bypass_cdc                     = "false";
   localparam bypass_tl                      = "false";
   localparam vc1_clk_enable                 = "false";
   localparam enable_rx_reordering           = "true";
   localparam national_inst_thru_enhance     = "false";
   localparam disable_tag_check              = "enable";

   localparam core_clk_disable_clk_switch    = "pld_clk";
   localparam core_clk_sel                   = "pld_clk";
   localparam core_clk_out_sel               = (low_str(enable_adapter_half_rate_mode)=="true")?"div_2":"div_1";
   localparam core_clk_source                = "pll_fixed_clk";
   localparam core_clk_divider               = get_core_clk_divider_param(ast_width, gen12_lane_rate_mode, lane_mask, set_pld_clk_x1_625MHz);
   localparam enable_ch0_pclk_out  = (LANES==8)?"pclk_central":"pclk_ch01";
   localparam enable_ch01_pclk_out = ((LANES==2)||(LANES==4))?"pclk_ch1":"pclk_ch0";

    //localparam per function
   localparam vc_arbitration                 = "single_vc";
   localparam intel_id_access                = "false";

   localparam io_window_addr_width_1         = "none";
   localparam prefetchable_mem_window_addr_width_1 = "prefetch_0";
   localparam no_command_completed_1         = "false";
   localparam [6:0] hot_plug_support_1       = 7'b0;
   localparam low_priority_vc_1              = "single_vc";
   localparam [2:0] indicator_1              = 3'b111;

   localparam io_window_addr_width_2         = "none";
   localparam prefetchable_mem_window_addr_width_2 = "prefetch_0";
   localparam no_command_completed_2         = "false";
   localparam [6:0] hot_plug_support_2       = 7'b0;
   localparam bridge_port_vga_enable_2       = "false";
   localparam bridge_port_ssid_support_2     = "false";
   localparam low_priority_vc_2              = "single_vc";
   localparam [2:0] indicator_2              = 3'b111;

   localparam io_window_addr_width_3         = "none";
   localparam prefetchable_mem_window_addr_width_3 = "prefetch_0";
   localparam no_command_completed_3         = "false";
   localparam [6:0] hot_plug_support_3       = 7'b0;
   localparam bridge_port_vga_enable_3       = "false";
   localparam bridge_port_ssid_support_3     = "false";
   localparam low_priority_vc_3              = "single_vc";
   localparam [2:0] indicator_3              = 3'b111;

   localparam io_window_addr_width_4  = "none";
   localparam prefetchable_mem_window_addr_width_4 = "prefetch_0";
   localparam no_command_completed_4 = "false";
   localparam [6:0] hot_plug_support_4 = 7'b0;
   localparam bridge_port_vga_enable_4   = "false";
   localparam bridge_port_ssid_support_4 = "false";
   localparam low_priority_vc_4 = "single_vc";
   localparam [2:0] indicator_4 = 3'b111;

   localparam io_window_addr_width_5  = "none";
   localparam prefetchable_mem_window_addr_width_5 = "prefetch_0";
   localparam no_command_completed_5 = "false";
   localparam [6:0] hot_plug_support_5 = 7'b0;
   localparam bridge_port_vga_enable_5   = "false";
   localparam bridge_port_ssid_support_5 = "false";
   localparam low_priority_vc_5 = "single_vc";
   localparam [2:0] indicator_5 = 3'b111;

   localparam io_window_addr_width_6  = "none";
   localparam prefetchable_mem_window_addr_width_6 = "prefetch_0";
   localparam no_command_completed_6 = "false";
   localparam [6:0] hot_plug_support_6 = 7'b0;
   localparam bridge_port_vga_enable_6   = "false";
   localparam bridge_port_ssid_support_6 = "false";
   localparam low_priority_vc_6 = "single_vc";
   localparam [2:0] indicator_6 = 3'b111;

   localparam io_window_addr_width_7  = "none";
   localparam prefetchable_mem_window_addr_width_7 = "prefetch_0";
   localparam no_command_completed_7 = "false";
   localparam [6:0] hot_plug_support_7 = 7'b0;
   localparam bridge_port_vga_enable_7   = "false";
   localparam bridge_port_ssid_support_7 = "false";
   localparam low_priority_vc_7 = "single_vc";
   localparam [2:0] indicator_7 = 3'b111;


   // Hard Reset Controller parameters
   localparam hrdrstctrl_en                      = "hrdrstctrl_en";  // "hrdrstctrl_dis", "hrdrstctrl_en".
   localparam rstctrl_pld_clr                    = "true";// "false", "true".
   localparam rstctrl_debug_en                   = "false";// "false", "true".
   localparam rstctrl_force_inactive_rst         = "false";// "false", "true".
   localparam rstctrl_perst_enable               = "level";// "level", "neg_edge", "not_used".
   localparam rstctrl_hip_ep                     = "hip_ep";      //"hip_ep", "hip_not_ep".
   localparam rstctrl_hard_block_enable          = (low_str(hip_hard_reset) == "disable") ? "pld_rst_ctl" : "hard_rst_ctl"; //"hard_rst_ctl", "pld_rst_ctl"
   localparam rstctrl_rx_pma_rstb_inv            = "false";//"false", "true".
   localparam rstctrl_tx_pma_rstb_inv            = "false";//"false", "true".
   localparam rstctrl_rx_pcs_rst_n_inv           = "false";//"false", "true".
   localparam rstctrl_tx_pcs_rst_n_inv           = "false";//"false", "true".
   localparam rstctrl_altpe2_crst_n_inv          = "false";//"false", "true".
   localparam rstctrl_altpe2_srst_n_inv          = "false";//"false", "true".
   localparam rstctrl_altpe2_rst_n_inv           = "false";//"false", "true".
   localparam rstctrl_tx_pma_syncp_inv           = "false";//"false", "true".
   localparam rstctrl_1us_count_fref_clk         = "rstctrl_1us_cnt";//
   localparam [19:0] rstctrl_1us_count_fref_clk_value   = (pll_refclk_freq == "125 MHz")?20'b00000000000001111101:20'b00000000000001100100;//
   localparam rstctrl_1ms_count_fref_clk         = "rstctrl_1ms_cnt";//
   localparam [19:0] rstctrl_1ms_count_fref_clk_value   = (pll_refclk_freq == "125 MHz")?20'b00001110100001001000:20'b00011000011010100000;//
   localparam rstctrl_off_cal_done_select        = "not_active";// "ch0_sel", "ch01_sel", "ch0123_sel", "ch0123_5678_sel", "not_active".
   localparam rstctrl_rx_pma_rstb_cmu_select     = (LANES==1)?"ch1cmu_sel":(LANES==2)?"ch4cmu_sel":(LANES==4)?"ch4cmu_sel":(LANES==8)?((low_str(gen12_lane_rate_mode)=="gen1")? "ch4cmu_sel":"not_active") : "not_active"; // "ch1cmu_sel", "ch4cmu_sel", "ch4_10cmu_sel", "not_active".
   localparam rstctrl_rx_pma_rstb_select         = (LANES==1)?"ch01_out":(LANES==2)?"ch014_out":(LANES==4)?"ch01234_out":(LANES==8)?((low_str(gen12_lane_rate_mode)=="gen1")?"ch012345678_out":"not_active") : "not_active";        // "ch0_out", "ch01_out", "ch0123_out", "ch012345678_out", "ch012345678_10_out", "not_active".
   localparam rstctrl_rx_pll_freq_lock_select    = (LANES==1)?"ch0_sel":(LANES==2)?"ch01_sel":(LANES==4)?"ch0123_sel":(LANES==8)?((low_str(gen12_lane_rate_mode)=="gen1")? "ch0123_5678_sel":"not_active"): "not_active"; // "ch0_sel", "ch01_sel", "ch0123_sel", "ch0123_5678_sel", "not_active", "ch0_sel", "ch01_sel", "ch0123_sel", "ch0123_5678_sel".
   localparam rstctrl_mask_tx_pll_lock_select    = "not_active";// "ch1_sel", "ch4_sel", "ch4_10_sel", "not_active".
   localparam rstctrl_rx_pll_lock_select         = (LANES==1)?"ch0_sel":(LANES==2)?"ch01_sel":(LANES==4)?"ch0123_sel":(LANES==8)?((low_str(gen12_lane_rate_mode)=="gen1")?"ch0123_5678_sel":"not_active"):"not_active"; // "ch0_sel", "ch01_sel", "ch0123_sel", "ch0123_5678_sel", "not_active".
   localparam rstctrl_perstn_select              = "perstn_pin";// "perstn_pin", "perstn_pld".
   localparam rstctrl_tx_lc_pll_rstb_select      = "not_active";// "ch1_out", "ch7_out", "not_active".
   localparam rstctrl_fref_clk_select            = "ch0_sel";// "ch0_sel", "ch1_sel", "ch2_sel", "ch3_sel", "ch4_sel", "ch5_sel", "ch6_sel", "ch7_sel", "ch8_sel", "ch9_sel", "ch10_sel", "ch11_sel".
   localparam rstctrl_off_cal_en_select          = "not_active";// "ch0_out", "ch01_out", "ch0123_out", "ch0123_5678_out", "not_active".
   localparam rstctrl_ltssm_disable              = (porttype_func0=="rp")?"enable":"disable"; //"disable", "enable".
   localparam rstctrl_tx_pma_syncp_select        = (LANES==1)?"ch1_out":(LANES==2)?"ch4_out":(LANES==4)?"ch4_out":(LANES==8)?((low_str(gen12_lane_rate_mode)=="gen1")? "ch4_out":"not_active"):"not_active"; // "ch1_out", "ch4_out", "ch4_10_out", "not_active".
   localparam rstctrl_rx_pcs_rst_n_select        = (LANES==1)?"ch0_out":(LANES==2)?"ch01_out":(LANES==4)?"ch0123_out":(LANES==8)?((low_str(gen12_lane_rate_mode)=="gen1")? "ch012345678_out":"not_active"):"not_active";        //  "ch0_out", "ch01_out", "ch0123_out", "ch012345678_out", "ch012345678_10_out", "not_active".
   localparam rstctrl_tx_cmu_pll_lock_select     = (LANES==1)?"ch1_sel":(LANES==2)?"ch4_sel":(LANES==4)?"ch4_sel":(LANES==8)?((low_str(gen12_lane_rate_mode)=="gen1")? "ch4_sel":"not_active"):"not_active"; //  "ch1_sel", "ch4_sel", "ch4_10_sel", "not_active".
   localparam rstctrl_tx_pcs_rst_n_select        = (LANES==1)?"ch0_out":(LANES==2)?"ch01_out":(LANES==4)?"ch0123_out":(LANES==8)?((low_str(gen12_lane_rate_mode)=="gen1")? "ch012345678_out":"not_active"):"not_active";     // "ch0_out", "ch01_out", "ch0123_out", "ch012345678_out", "ch012345678_10_out", "not_active".
   localparam rstctrl_tx_lc_pll_lock_select      = "not_active";// "ch1_sel", "ch7_sel", "not_active".
   localparam rstctrl_timer_a                    = "rstctrl_timer_a";
   localparam rstctrl_timer_a_type               = "fref_cycles";//possible values are: "not_enabled", "milli_secs", "micro_secs", "fref_cycles"
   localparam [7:0] rstctrl_timer_a_value        = 8'd10;
   localparam rstctrl_timer_b                    = "rstctrl_timer_b";
   localparam rstctrl_timer_b_type               = "fref_cycles";//possible values are: "not_enabled", "milli_secs", "micro_secs", "fref_cycles"
   localparam [7:0] rstctrl_timer_b_value        = 8'd10;
   localparam rstctrl_timer_c                    = "rstctrl_timer_c";
   localparam rstctrl_timer_c_type               = "fref_cycles";//possible values are: "not_enabled", "milli_secs", "micro_secs", "fref_cycles"
   localparam [7:0] rstctrl_timer_c_value        = 8'd10;
   localparam rstctrl_timer_d                    = "rstctrl_timer_d";
   localparam rstctrl_timer_d_type               = "fref_cycles";//possible values are: "not_enabled", "milli_secs", "micro_secs", "fref_cycles"
   localparam [7:0] rstctrl_timer_d_value        = 8'd20;
   localparam rstctrl_timer_e                    = "rstctrl_timer_e";
   localparam rstctrl_timer_e_type               = "fref_cycles";//possible values are: "not_enabled", "milli_secs", "micro_secs", "fref_cycles"
   localparam [7:0] rstctrl_timer_e_value        = 8'd01;
   localparam rstctrl_timer_f                    = "rstctrl_timer_f";
   localparam rstctrl_timer_f_type               = "fref_cycles";//possible values are: "not_enabled", "milli_secs", "micro_secs", "fref_cycles"
   localparam [7:0] rstctrl_timer_f_value        = 8'd10;
   localparam rstctrl_timer_g                    = "rstctrl_timer_g";
   localparam rstctrl_timer_g_type               = "fref_cycles";//possible values are: "not_enabled", "milli_secs", "micro_secs", "fref_cycles"
   localparam [7:0] rstctrl_timer_g_value        = 8'd10;
   localparam rstctrl_timer_h                    = "rstctrl_timer_h";
   localparam rstctrl_timer_h_type               = (ALTPCIE_HIP_128BIT_SIM_ONLY==1)?"micro_secs":"milli_secs";        // "milli_secs";//possible values are: "not_enabled", "milli_secs", "micro_secs", "fref_cycles"
   localparam [7:0] rstctrl_timer_h_value        = 8'd01;
   localparam rstctrl_timer_i                    = "rstctrl_timer_i";
   localparam rstctrl_timer_i_type               = "fref_cycles";//possible values are: "not_enabled", "milli_secs", "micro_secs", "fref_cycles"
   localparam [7:0] rstctrl_timer_i_value        = 8'd20;
   localparam rstctrl_timer_j                    = "rstctrl_timer_j";
   localparam rstctrl_timer_j_type               = "micro_secs";//possible values are: "not_enabled", "milli_secs", "micro_secs", "fref_cycles"
   localparam [7:0] rstctrl_timer_j_value        = 8'h1;
   localparam testmode_control                   = "disable"; //"enable", "disable"

   localparam role_based_error_reporting         = "true";
   localparam bridge_66mhzcap                    = "false"; //A5 11.1 has no support for bridge
   localparam fastb2bcap                         = "false"; //A5 11.1 has no support for bridge
   localparam devseltim                          = "fast_devsel_decoding";
   localparam [6:0] lattim_ro_data               = "0001000";
   localparam lattim                             = "ro";
   localparam memwrinv                           = "ro";
   localparam br_rcb                             = "ro";
   localparam rxfreqlk_cnt_en                    = "false";
   localparam [19:0] rxfreqlk_cnt                = 20'b0;
   localparam skp_insertion_control              = "disable";//"disable", "enable".
   localparam tx_l0s_adjust                      = "disable";//"disable", "enable".

   //Pipe Localparams -->
   localparam starting_channel_number            = 0; //legal value: 0+
   localparam protocol_version                   = (low_str(gen12_lane_rate_mode)=="gen1")?"Gen 1":
                                                   (low_str(gen12_lane_rate_mode)=="gen1_gen2")?"Gen 2":"<invalid>"; //legal value: "gen1", "gen2"
   localparam deser_factor                       = 8;
   localparam hip_enable                         = "true";

   localparam reference_clock_frequency_parameter = (pll_refclk_freq == "100 MHz"? "100.0 MHz" : "125.0 MHz");


   // SDC_STATEMENT
   (* altera_attribute = {"-name SDC_STATEMENT \"set_false_path -from [ get_pins -compatibility {*arriav_hd_altpe2_hip_top|testinhip\[*\]\" "} *)


   // SERDES
   //input from reset controller
   wire  [LANES-1:0]                   serdes_xcvr_powerdown;
   wire                                serdes_pll_powerdown;
   wire                                serdes_fixedclk;
   wire                                serdes_pll_fixedclk_locked;
   wire                                fboutclk_fixedclk;
   wire                                open_fbclk_serdes;
   wire  [LANES-1:0]                   serdes_tx_digitalreset;
   wire  [LANES-1:0]                   serdes_rx_analogreset; // for rx pma
   wire  [LANES-1:0]                   serdes_rx_digitalreset; //for rx pcs
   wire  [LANES-1:0]                   serdes_rx_cal_busy;
   wire  [LANES-1:0]                   serdes_tx_cal_busy;


   //clk signal

   //pipe interface ports
   wire  [LANES * deser_factor - 1:0]        serdes_pipe_txdata;
   wire  [((LANES * deser_factor)/8) - 1:0]  serdes_pipe_txdatak;
   wire  [LANES - 1:0]                       serdes_pipe_txdetectrx_loopback;
   wire  [LANES - 1:0]                       serdes_pipe_txcompliance;
   wire  [LANES - 1:0]                       serdes_pipe_txelecidle;
   wire  [LANES - 1:0]                       serdes_pipe_txdeemph;
   wire  [LANES*3 - 1:0]                     serdes_pipe_txmargin;
   wire  [LANES - 1:0]                       serdes_pipe_txswing;
   wire  [LANES- 1:0]                        serdes_pipe_rate;
   wire                                      serdes_ratectrl;
   wire  [LANES*2 - 1:0]                     serdes_pipe_powerdown;

   wire  [LANES * deser_factor - 1:0]        serdes_pipe_rxdata;
   wire  [((LANES * deser_factor)/8) - 1:0]  serdes_pipe_rxdatak;
   wire  [LANES - 1:0]                       serdes_pipe_rxvalid;
   wire  [LANES - 1:0]                       serdes_pipe_rxpolarity;
   wire  [LANES - 1:0]                       serdes_pipe_rxelecidle;
   wire  [LANES - 1:0]                       serdes_pipe_phystatus;
   wire  [LANES*3 - 1:0]                     serdes_pipe_rxstatus;
   wire  [(LANES == 8 ? (LANES+1):LANES)*3 -1 : 0] serdes_pld8grxstatus;

   wire [2:0] pld8grxstatus0;
   wire [2:0] pld8grxstatus1;
   wire [2:0] pld8grxstatus2;
   wire [2:0] pld8grxstatus3;
   wire [2:0] pld8grxstatus4;
   wire [2:0] pld8grxstatus5;
   wire [2:0] pld8grxstatus6;
   wire [2:0] pld8grxstatus7;

   //non-PIPE ports
   //MM ports
   wire  [LANES*3-1:0]                 serdes_rx_eidleinfersel;
   wire  [LANES-1:0]                   serdes_rx_set_locktodata;
   wire  [LANES-1:0]                   serdes_rx_set_locktoref;
   wire  [LANES-1:0]                   serdes_tx_invpolarity;
   wire  [((LANES*deser_factor)/8) -1:0] serdes_rx_errdetect;
   wire  [((LANES*deser_factor)/8) -1:0] serdes_rx_disperr;
   wire  [((LANES*deser_factor)/8) -1:0] serdes_rx_patterndetect;
   wire  [((LANES*deser_factor)/8) -1:0] serdes_rx_syncstatus;
   wire  [LANES-1:0]                   serdes_rx_phase_comp_fifo_error;
   wire  [LANES-1:0]                   serdes_tx_phase_comp_fifo_error;
   wire  [LANES-1:0]                   serdes_rx_is_lockedtoref;
   wire  [LANES-1:0]                   serdes_rx_signaldetect;
   wire  [LANES-1:0]                   serdes_rx_is_lockedtodata;

   //non-MM ports
   wire  [LANES-1:0]                   serdes_rx_serial_data;
   wire  [LANES-1:0]                   serdes_tx_serial_data;
   wire                                serdes_pipe_pclk;
   wire                                serdes_pipe_pclkch1      ;
   wire                                serdes_pllfixedclkch0;
   wire                                serdes_pllfixedclkch1;
   wire                                serdes_pipe_pclkcentral  ;
   wire                                serdes_pllfixedclkcentral;

   wire                                mserdes_pipe_pclk;
   wire                                mserdes_pipe_pclkch1      ;
   wire                                mserdes_pllfixedclkch0;
   wire                                mserdes_pllfixedclkch1;
   wire                                mserdes_pipe_pclkcentral  ;
   wire                                mserdes_pllfixedclkcentral;

   wire                                sim_pipe32_pclk;

   // reset controller signal
   wire rst_ctrl_rx_pll_locked  ;
   wire rst_ctrl_rxanalogreset  ;
   wire rst_ctrl_rxdigitalreset ;
   wire rst_ctrl_txdigitalreset ;
   wire pld_clk_in_use_hip;


   // Pull to known values
   wire unconnected_wire = 1'b0;
   wire [512:0] unconnected_bus = {512{1'b0}};


   ////////////////////////////////////////////////////////////////////////////////////
   //
   // PIPE signals interface
   //
   wire                phystatus0     ;// HIP input
   wire                phystatus1     ;// HIP input
   wire                phystatus2     ;// HIP input
   wire                phystatus3     ;// HIP input
   wire                phystatus4     ;// HIP input
   wire                phystatus5     ;// HIP input
   wire                phystatus6     ;// HIP input
   wire                phystatus7     ;// HIP input
   wire                rxblkst0       = 1'b0;// HIP input
   wire                rxblkst1       = 1'b0;// HIP input
   wire                rxblkst2       = 1'b0;// HIP input
   wire                rxblkst3       = 1'b0;// HIP input
   wire                rxblkst4       = 1'b0;// HIP input
   wire                rxblkst5       = 1'b0;// HIP input
   wire                rxblkst6       = 1'b0;// HIP input
   wire                rxblkst7       = 1'b0;// HIP input
   wire [7 : 0]       rxdata0        ;// HIP input  [31 : 0]
   wire [7 : 0]       rxdata1        ;// HIP input  [31 : 0]
   wire [7 : 0]       rxdata2        ;// HIP input  [31 : 0]
   wire [7 : 0]       rxdata3        ;// HIP input  [31 : 0]
   wire [7 : 0]       rxdata4        ;// HIP input  [31 : 0]
   wire [7 : 0]       rxdata5        ;// HIP input  [31 : 0]
   wire [7 : 0]       rxdata6        ;// HIP input  [31 : 0]
   wire [7 : 0]       rxdata7        ;// HIP input  [31 : 0]
   wire               rxdatak0       ;// HIP input  [3 : 0]
   wire               rxdatak1       ;// HIP input  [3 : 0]
   wire               rxdatak2       ;// HIP input  [3 : 0]
   wire               rxdatak3       ;// HIP input  [3 : 0]
   wire               rxdatak4       ;// HIP input  [3 : 0]
   wire               rxdatak5       ;// HIP input  [3 : 0]
   wire               rxdatak6       ;// HIP input  [3 : 0]
   wire               rxdatak7       ;// HIP input  [3 : 0]
   wire                rxdataskip0    = 1'b0;// HIP input
   wire                rxdataskip1    = 1'b0;// HIP input
   wire                rxdataskip2    = 1'b0;// HIP input
   wire                rxdataskip3    = 1'b0;// HIP input
   wire                rxdataskip4    = 1'b0;// HIP input
   wire                rxdataskip5    = 1'b0;// HIP input
   wire                rxdataskip6    = 1'b0;// HIP input
   wire                rxdataskip7    = 1'b0;// HIP input
   wire                rxelecidle0    ;// HIP input
   wire                rxelecidle1    ;// HIP input
   wire                rxelecidle2    ;// HIP input
   wire                rxelecidle3    ;// HIP input
   wire                rxelecidle4    ;// HIP input
   wire                rxelecidle5    ;// HIP input
   wire                rxelecidle6    ;// HIP input
   wire                rxelecidle7    ;// HIP input
   wire                rxfreqlocked0  = 1'b0;// HIP input
   wire                rxfreqlocked1  = 1'b0;// HIP input
   wire                rxfreqlocked2  = 1'b0;// HIP input
   wire                rxfreqlocked3  = 1'b0;// HIP input
   wire                rxfreqlocked4  = 1'b0;// HIP input
   wire                rxfreqlocked5  = 1'b0;// HIP input
   wire                rxfreqlocked6  = 1'b0;// HIP input
   wire                rxfreqlocked7  = 1'b0;// HIP input
   wire [2 : 0]        rxstatus0      ;// HIP input  [2 : 0]
   wire [2 : 0]        rxstatus1      ;// HIP input  [2 : 0]
   wire [2 : 0]        rxstatus2      ;// HIP input  [2 : 0]
   wire [2 : 0]        rxstatus3      ;// HIP input  [2 : 0]
   wire [2 : 0]        rxstatus4      ;// HIP input  [2 : 0]
   wire [2 : 0]        rxstatus5      ;// HIP input  [2 : 0]
   wire [2 : 0]        rxstatus6      ;// HIP input  [2 : 0]
   wire [2 : 0]        rxstatus7      ;// HIP input  [2 : 0]
   wire [1 : 0]        rxsynchd0      = 2'b00;// HIP input  [1 : 0]
   wire [1 : 0]        rxsynchd1      = 2'b00;// HIP input  [1 : 0]
   wire [1 : 0]        rxsynchd2      = 2'b00;// HIP input  [1 : 0]
   wire [1 : 0]        rxsynchd3      = 2'b00;// HIP input  [1 : 0]
   wire [1 : 0]        rxsynchd4      = 2'b00;// HIP input  [1 : 0]
   wire [1 : 0]        rxsynchd5      = 2'b00;// HIP input  [1 : 0]
   wire [1 : 0]        rxsynchd6      = 2'b00;// HIP input  [1 : 0]
   wire [1 : 0]        rxsynchd7      = 2'b00;// HIP input  [1 : 0]
   wire                rxvalid0       ;// HIP input
   wire                rxvalid1       ;// HIP input
   wire                rxvalid2       ;// HIP input
   wire                rxvalid3       ;// HIP input
   wire                rxvalid4       ;// HIP input
   wire                rxvalid5       ;// HIP input
   wire                rxvalid6       ;// HIP input
   wire                rxvalid7       ;// HIP input
   wire [2 : 0]        eidleinfersel0            ;// HIP output [2 : 0]
   wire [2 : 0]        eidleinfersel1            ;// HIP output [2 : 0]
   wire [2 : 0]        eidleinfersel2            ;// HIP output [2 : 0]
   wire [2 : 0]        eidleinfersel3            ;// HIP output [2 : 0]
   wire [2 : 0]        eidleinfersel4            ;// HIP output [2 : 0]
   wire [2 : 0]        eidleinfersel5            ;// HIP output [2 : 0]
   wire [2 : 0]        eidleinfersel6            ;// HIP output [2 : 0]
   wire [2 : 0]        eidleinfersel7            ;// HIP output [2 : 0]
   wire [1 : 0]        powerdown0                ;// HIP output [1 : 0]
   wire [1 : 0]        powerdown1                ;// HIP output [1 : 0]
   wire [1 : 0]        powerdown2                ;// HIP output [1 : 0]
   wire [1 : 0]        powerdown3                ;// HIP output [1 : 0]
   wire [1 : 0]        powerdown4                ;// HIP output [1 : 0]
   wire [1 : 0]        powerdown5                ;// HIP output [1 : 0]
   wire [1 : 0]        powerdown6                ;// HIP output [1 : 0]
   wire [1 : 0]        powerdown7                ;// HIP output [1 : 0]
   wire                rxpolarity0               ;// HIP output
   wire                rxpolarity1               ;// HIP output
   wire                rxpolarity2               ;// HIP output
   wire                rxpolarity3               ;// HIP output
   wire                rxpolarity4               ;// HIP output
   wire                rxpolarity5               ;// HIP output
   wire                rxpolarity6               ;// HIP output
   wire                rxpolarity7               ;// HIP output
   wire                txcompl0                  ;// HIP output
   wire                txcompl1                  ;// HIP output
   wire                txcompl2                  ;// HIP output
   wire                txcompl3                  ;// HIP output
   wire                txcompl4                  ;// HIP output
   wire                txcompl5                  ;// HIP output
   wire                txcompl6                  ;// HIP output
   wire                txcompl7                  ;// HIP output
   wire [7 : 0]        txdata0                   ;// HIP output [7 : 0]
   wire [7 : 0]        txdata1                   ;// HIP output [7 : 0]
   wire [7 : 0]        txdata2                   ;// HIP output [7 : 0]
   wire [7 : 0]        txdata3                   ;// HIP output [7 : 0]
   wire [7 : 0]        txdata4                   ;// HIP output [7 : 0]
   wire [7 : 0]        txdata5                   ;// HIP output [7 : 0]
   wire [7 : 0]        txdata6                   ;// HIP output [7 : 0]
   wire [7 : 0]        txdata7                   ;// HIP output [7 : 0]
   wire                txdatak0                  ;// HIP output
   wire                txdatak1                  ;// HIP output
   wire                txdatak2                  ;// HIP output
   wire                txdatak3                  ;// HIP output
   wire                txdatak4                  ;// HIP output
   wire                txdatak5                  ;// HIP output
   wire                txdatak6                  ;// HIP output
   wire                txdatak7                  ;// HIP output
   wire                txdatavalid0              ;// Going nowhere to remove
   wire                txdatavalid1              ;// Going nowhere to remove
   wire                txdatavalid2              ;// Going nowhere to remove
   wire                txdatavalid3              ;// Going nowhere to remove
   wire                txdatavalid4              ;// Going nowhere to remove
   wire                txdatavalid5              ;// Going nowhere to remove
   wire                txdatavalid6              ;// Going nowhere to remove
   wire                txdatavalid7              ;// Going nowhere to remove
   wire                txdetectrx0               ;// HIP output
   wire                txdetectrx1               ;// HIP output
   wire                txdetectrx2               ;// HIP output
   wire                txdetectrx3               ;// HIP output
   wire                txdetectrx4               ;// HIP output
   wire                txdetectrx5               ;// HIP output
   wire                txdetectrx6               ;// HIP output
   wire                txdetectrx7               ;// HIP output
   wire                txelecidle0               ;// HIP output
   wire                txelecidle1               ;// HIP output
   wire                txelecidle2               ;// HIP output
   wire                txelecidle3               ;// HIP output
   wire                txelecidle4               ;// HIP output
   wire                txelecidle5               ;// HIP output
   wire                txelecidle6               ;// HIP output
   wire                txelecidle7               ;// HIP output
   wire [2 : 0]        txmargin0                 ;// HIP output [2 : 0]
   wire [2 : 0]        txmargin1                 ;// HIP output [2 : 0]
   wire [2 : 0]        txmargin2                 ;// HIP output [2 : 0]
   wire [2 : 0]        txmargin3                 ;// HIP output [2 : 0]
   wire [2 : 0]        txmargin4                 ;// HIP output [2 : 0]
   wire [2 : 0]        txmargin5                 ;// HIP output [2 : 0]
   wire [2 : 0]        txmargin6                 ;// HIP output [2 : 0]
   wire [2 : 0]        txmargin7                 ;// HIP output [2 : 0]
   wire                txswing0                  ;// HIP output
   wire                txswing1                  ;// HIP output
   wire                txswing2                  ;// HIP output
   wire                txswing3                  ;// HIP output
   wire                txswing4                  ;// HIP output
   wire                txswing5                  ;// HIP output
   wire                txswing6                  ;// HIP output
   wire                txswing7                  ;// HIP output
   wire                txdeemph0                 ;// HIP output
   wire                txdeemph1                 ;// HIP output
   wire                txdeemph2                 ;// HIP output
   wire                txdeemph3                 ;// HIP output
   wire                txdeemph4                 ;// HIP output
   wire                txdeemph5                 ;// HIP output
   wire                txdeemph6                 ;// HIP output
   wire                txdeemph7                 ;// HIP output
   wire                rate0;
   wire                rate1;
   wire                rate2;
   wire                rate3;
   wire                rate4;
   wire                rate5;
   wire                rate6;
   wire                rate7;
   wire                ratectrl;


   // Hardreset signals
   // Reset Control Interface Ch0
   wire [8:0] txpcsrstn;          // HIP output
   wire [8:0] rxpcsrstn;          // HIP output
   wire [8:0] txpmasyncp;         // HIP output
   wire [11:0] rxpmarstb;          // HIP output
   //wire [11:0] txlcpllrstb;        // HIP output
   wire [8:0] offcalen;           // HIP output
   wire [8:0] frefclk;            // HIP input
   wire [LANES:0] frefclk_int;            // HIP input
   //wire [8:0] txlcplllock;        // HIP input
   wire [8:0] rxfreqtxcmuplllock; // HIP input
   wire [((LANES==2)?4:LANES):0] rxfreqtxcmuplllock_int; // HIP input
   wire [8:0] rxpllphaselock;     // HIP input
   wire [((LANES==2)?4:LANES):0] rxpllphaselock_int;     // HIP input
   //wire [11:0] masktxplllock;      // HIP input

   wire [LANES:0] serdes_txpcsrstn;          // HIP output
   wire [LANES:0] serdes_rxpcsrstn;          // HIP output
   wire [LANES:0] serdes_txpmasyncp;         // HIP output
   wire [((LANES==2)?4:LANES):0] serdes_rxpmarstb;          // HIP output
   //wire [LANES:0] serdes_txlcpllrstb;        // HIP output
   wire [LANES:0] serdes_offcalen;           // HIP output
   wire [LANES:0] serdes_frefclk;            // HIP input
   wire [LANES:0] serdes_offcaldone;         // HIP input
   wire [LANES:0] serdes_txlcplllock;        // HIP input
   wire [((LANES==2)?4:LANES):0] serdes_rxfreqtxcmuplllock; // HIP input
   wire [LANES:0] serdes_rxpllphaselock;     // HIP input
   //wire [LANES:0] serdes_masktxplllock;      // HIP input
   wire           serdes_pll_locked_xcvr;

   // PLD Application clocks core_clkout
   wire         crst;
   wire         srst;
   reg  [7:0]   flrreset_hip;
   wire         reset_status_hip;
   reg          reset_status_sync;
   wire         arst         ; // por synchronized to pld_clk
   reg  [2:0]   arst_r ;
   wire         hiprst;



   wire           tl_cfg_ctl_wr_hip;
   wire           tl_cfg_sts_wr_hip;
   wire [31:0]    tl_cfg_ctl_hip;
   wire [6:0]     tl_cfg_add_hip;
   wire [122:0]   tl_cfg_sts_hip;

   wire [LANES-1:0]            int_sigdet;

   // serial assignment
   assign serdes_pll_fixedclk_locked = 1'b1;
   assign serdes_pll_locked = (pipe_mode==1'b1)?1'b1:serdes_pll_locked_xcvr;
   assign serdes_fixedclk = refclk;

//------------------------------------------------------------------------------------------------------------------------------------
//------------------------------------------------------------ fix -------------------------------------------------------------------
//------------------------------------------------------------------------------------------------------------------------------------

//********************************************************************
// Manipulate locked to data
//********************************************************************
wire    [7:0]   rx_is_lockedtodata_sync;
altpcie_av_hd_dpcmn_bitsync2#(
    .DWIDTH     ( 8 )
)
bitsync_rx_ltd
(
    .clk            ( pld_clk ),
    .rst_n          ( ~por ),
    .data_in        ( (LANES==1)?{7'h7F,serdes_rx_is_lockedtodata[LANES-1:0]}:(LANES==2)?{6'h3F,serdes_rx_is_lockedtodata[LANES-1:0]}:(LANES==4)?{4'hF, serdes_rx_is_lockedtodata[LANES-1:0]}:serdes_rx_is_lockedtodata[LANES-1:0]),
    .data_out       ( rx_is_lockedtodata_sync )
);

wire   freqlock_ok;
wire   freqlock_ok_x1;
wire   freqlock_ok_x2;
wire   freqlock_ok_x4;
wire   freqlock_ok_x8;

assign freqlock_ok_x1   = rx_is_lockedtodata_sync[0];
assign freqlock_ok_x2   = &rx_is_lockedtodata_sync[1:0];
assign freqlock_ok_x4   = &rx_is_lockedtodata_sync[3:0];
assign freqlock_ok_x8   = &rx_is_lockedtodata_sync[7:0];

assign freqlock_ok      = ( lane_act == 4'b1000 ) ? freqlock_ok_x8 :
                          ( lane_act == 4'b0100 ) ? freqlock_ok_x4 :
                          ( lane_act == 4'b0010 ) ? freqlock_ok_x2 : freqlock_ok_x1;

//********************************************************************
// State Machine to control Word Aligner
//********************************************************************

// Maximum Cycle for PPM detector to stable
localparam [16:0] HOLD_COUNT_MAX = 17'd125000;    // 1ms

// State Machine Coding
localparam IDLE     = 1'b0;
localparam STOP_WA_SM = 1'b1;

// Net
reg       state;
reg [4:0]       dl_ltssm_reg;
reg             in_pld_sync_sm_en;
reg [21:0]      timeout_count;
reg             rcv_timeout;
reg             timeout_count_en;
reg [16:0]      hold_count;

always@( posedge pld_clk or posedge por ) begin
  if( por ) begin
            state               <= IDLE;
            dl_ltssm_reg    <= 5'h00;
            in_pld_sync_sm_en <= 1'b1;
            hold_count          <= 17'd0;
  end
  else begin
    dl_ltssm_reg <= dl_ltssm;
    case( state )
            IDLE    : begin
               in_pld_sync_sm_en <= 1'b1;
               if( dl_ltssm == 5'h0C && dl_ltssm_reg == 5'h1A && (ALTPCIE_HIP_128BIT_SIM_ONLY==0)  ) begin
                      state   <= STOP_WA_SM;
                      hold_count  <= 17'd0;
               end
               else begin
                      state   <= IDLE;
                      hold_count  <= 17'd0;
               end
            end

            STOP_WA_SM  :   begin
               in_pld_sync_sm_en <= 1'b0;
               if ( hold_count == HOLD_COUNT_MAX )       // back to IDLE state if LTD can stable for a period of time
                   begin
                       state <= IDLE;
               end
               else if ( dl_ltssm != 5'h0C )             // back to IDLE state if no LTSSM no longer in recovery.rcv.lock
               begin
                     state <= IDLE;
               end
               else                                      // continue in STOP_WA_SM state if LTD does not stable
               begin
                       state <= STOP_WA_SM;
               end
               if( freqlock_ok )                         // count LTD stable time
               begin
                       hold_count <= hold_count + 17'd1;
               end

               else                                      // reset hold_count if LTD is not stable
               begin
                       hold_count <= 17'd0;
               end
            end

   endcase
  end
end

//------------------------------------------------------------------------------------------------------------------------------------
//------------------------------------------------------------- Code End -------------------------------------------------------------
//------------------------------------------------------------------------------------------------------------------------------------

   generate
      begin : g_soft_reset
         if (USE_HARD_RESET==0) begin

               altpcie_rs_serdes # (
                  .HIPRST_USE_LTSSM_HOTRESET          (HIPRST_USE_LTSSM_HOTRESET        ),
                  .HIPRST_USE_LTSSM_DISABLE           (HIPRST_USE_LTSSM_DISABLE         ),
                  .HIPRST_USE_LTSSM_EXIT_DETECTQUIET  (HIPRST_USE_LTSSM_EXIT_DETECTQUIET),
                  .HIPRST_USE_L2                      (HIPRST_USE_L2                    ),
                  .HIPRST_USE_DLUP_EXIT               (HIPRST_USE_DLUP_EXIT             )
               ) altpcie_rs_serdes (
               .pld_clk(pld_clk),
               .test_in({33'h0,test_in[6],5'h00,test_in[0]}),
               .ltssm(dl_ltssm),
               .dlup_exit (dlup_exit),
               .hotrst_exit (hotrst_exit),
               .l2_exit (l2_exit),
               .npor_serdes((pipe_mode==1'b1)?~por:(serdes_pll_fixedclk_locked==1'b0)?1'b0:~por),
               .npor_core((~por | pin_perst) & pld_clk_in_use),
               .tx_cal_busy(|serdes_tx_cal_busy),
               .rx_cal_busy(|serdes_rx_cal_busy),
               .pll_locked(serdes_pll_locked),
               .rx_freqlocked  ((LANES==1)?{7'h7F,serdes_rx_is_lockedtodata[LANES-1:0]}:(LANES==2)?{6'h3F,serdes_rx_is_lockedtodata[LANES-1:0]}:(LANES==4)?{4'hF, serdes_rx_is_lockedtodata[LANES-1:0]}:serdes_rx_is_lockedtodata[LANES-1:0]),                                                            // input  [7:0]
               .rx_pll_locked  ((LANES==1)?{7'h7F,serdes_rx_is_lockedtoref[LANES-1:0] }:(LANES==2)?{6'h3F,serdes_rx_is_lockedtoref[LANES-1:0]}:(LANES==4)?{4'hF, serdes_rx_is_lockedtoref[LANES-1:0] }:serdes_rx_is_lockedtoref[LANES-1:0] ),                                                            // input  [7:0]
               .rx_signaldetect  ((LANES==1)?{7'h00,int_sigdet[LANES-1:0]}:(LANES==2)?{6'h00,int_sigdet[LANES-1:0]}:(LANES==4)?{4'h0, int_sigdet[LANES-1:0]}:int_sigdet[LANES-1:0]),
               .simu_serial(!pipe_mode),
               .fifo_err(1'b0),
               .rc_inclk_eq_125mhz((PLD_CLK_IS_250MHZ==0)?1'b1:1'b0),
               .detect_mask_rxdrst(1'b1),
               .crst (crst),
               .srst (srst),
               .txdigitalreset (rst_ctrl_txdigitalreset),
               .rxanalogreset  (rst_ctrl_rxanalogreset),
               .rxdigitalreset (rst_ctrl_rxdigitalreset)
               );
            assign fixedclk_locked = serdes_pll_fixedclk_locked;
         end
         else begin
         // HIP complementary reset circuit when using Hard Reset Controller
            altpcie_rs_hip # (
               .HIPRST_USE_LOCAL_NPOR              (HIPRST_USE_LOCAL_NPOR),
               .HIPRST_USE_LTSSM_HOTRESET          (HIPRST_USE_LTSSM_HOTRESET        ),
               .HIPRST_USE_LTSSM_DISABLE           (HIPRST_USE_LTSSM_DISABLE         ),
               .HIPRST_USE_LTSSM_EXIT_DETECTQUIET  (HIPRST_USE_LTSSM_EXIT_DETECTQUIET),
               .HIPRST_USE_L2                      (HIPRST_USE_L2                    ),
               .HIPRST_USE_DLUP_EXIT               (HIPRST_USE_DLUP_EXIT             )
            ) altpcie_rs_hip (
               .pld_clk       (pld_clk),
               .dlup_exit     (dlup_exit),
               .hotrst_exit   (hotrst_exit),
               .ltssm         (dl_ltssm),
               .l2_exit       (l2_exit),
               .npor_core     (~por & pld_clk_in_use),
               .hiprst        (hiprst));
            assign fixedclk_locked = serdes_pll_locked;
         end
      end
   endgenerate

   generate
      begin : g_serdes_soft_rst_input
         for (i=0;i<LANES;i=i+1) begin : g_serdes_rst
            assign serdes_tx_digitalreset[i] = (low_str(hip_hard_reset)=="disable")?rst_ctrl_txdigitalreset    :1'b0;
            assign serdes_rx_analogreset [i] = (low_str(hip_hard_reset)=="disable")?rst_ctrl_rxanalogreset     :1'b0;
            assign serdes_rx_digitalreset[i] = (low_str(hip_hard_reset)=="disable")?rst_ctrl_rxdigitalreset    :1'b0;
         end
      end
   endgenerate

   assign serdes_pll_powerdown       = (low_str(hip_hard_reset)=="disable")?por:1'b0;
   assign serdes_rx_set_locktodata   = {LANES{1'b0}};
   assign serdes_rx_set_locktoref    = {LANES{1'b0}};
   assign serdes_tx_invpolarity      = {LANES{1'b0}};

   assign serdes_txpcsrstn           = txpcsrstn[LANES:0]   ;// HIP Hard Reset Controller output
   assign serdes_rxpcsrstn           = rxpcsrstn[LANES:0]   ;// HIP Hard Reset Controller output
   assign serdes_txpmasyncp          = txpmasyncp[LANES:0]  ;// HIP Hard Reset Controller output
   assign serdes_rxpmarstb           = (LANES == 2) ? rxpmarstb[4:0] : rxpmarstb[LANES:0]   ;// HIP Hard Reset Controller output
   assign serdes_offcalen            = ZEROS[LANES:0]    ;// HIP Hard Reset Controller output

   assign frefclk_int               = (pipe_mode==1'b1)?{LANES_P1{refclk}}:serdes_frefclk;// HIP Hard Reset Controller input
   assign frefclk                   = (LANES==1)?{7'h00, frefclk_int} : (LANES==4)?{3'h0, frefclk_int} : frefclk_int;

   assign rxfreqtxcmuplllock_int    = (pipe_mode==1'b1)?ONES[((LANES==2)?4:LANES):0]:serdes_rxfreqtxcmuplllock;// HIP Hard Reset Controller input
   assign rxfreqtxcmuplllock        = (LANES==1)?{7'h00, rxfreqtxcmuplllock_int} : (LANES==2 || LANES==4)?{3'h0, rxfreqtxcmuplllock_int} : rxfreqtxcmuplllock_int;

   assign rxpllphaselock_int        = (pipe_mode==1'b1)?ONES[((LANES==2)?4:LANES):0]:serdes_rxpllphaselock    ;// HIP Hard Reset Controller input
   assign rxpllphaselock            = (LANES==1)?{7'h00, rxpllphaselock_int} : (LANES==2 || LANES==4)?{3'h0, rxpllphaselock_int} : rxpllphaselock_int;

   generate begin : g_serdes_pipe_io
      if (LANES==1) begin
        assign int_sigdet = serdes_rx_is_lockedtodata;

        // TX

         assign serdes_ratectrl                    = unconnected_bus[0];
         assign serdes_pipe_rate[0]                = rate0;   // Currently only Gen2 rate0[1] is unconnected
         assign serdes_pipe_txdata[7 :0]           = txdata0;
         assign serdes_pipe_txdatak[0]             = txdatak0;
         assign serdes_pipe_txcompliance[0]        = txcompl0;
         assign serdes_pipe_txelecidle[0]          = txelecidle0;
         assign serdes_pipe_txdeemph[0]            = txdeemph0;
         assign serdes_pipe_txmargin[ 2: 0]        = txmargin0;
         assign serdes_pipe_txswing[0]             = txswing0;
         assign serdes_pipe_powerdown[ 1 : 0]      = powerdown0;
         assign serdes_pipe_rxpolarity[0]          = rxpolarity0 ;
         assign serdes_pipe_txdetectrx_loopback[0] = txdetectrx0;

         assign tx_out0 = serdes_tx_serial_data[0];

         //RX
         //
         assign  serdes_rx_serial_data[0]     = rx_in0;
         assign  serdes_rx_eidleinfersel[2:0] = eidleinfersel0;

         assign  rxdata0      = (pipe_mode==1'b1)?rxdata0_ext    :serdes_pipe_rxdata[7 :0  ];

         assign  rxdatak0     = (pipe_mode==1'b1)?rxdatak0_ext   :serdes_pipe_rxdatak[0] ;

         assign  rxvalid0     = (pipe_mode==1'b1)?rxvalid0_ext   :serdes_pipe_rxvalid[0] ;

         assign  rxelecidle0  = (pipe_mode==1'b1)?rxelecidle0_ext:serdes_pipe_rxelecidle[0] ;

         assign  phystatus0   = (pipe_mode==1'b1)?phystatus0_ext :serdes_pipe_phystatus[0] ;

         assign  rxstatus0    = (pipe_mode==1'b1)?rxstatus0_ext  :serdes_pipe_rxstatus[ 2: 0];

         assign pld8grxstatus0 = serdes_pld8grxstatus[2:0];

         assign mserdes_pipe_pclk         = serdes_pipe_pclk;
         assign mserdes_pipe_pclkch1      = unconnected_wire;
         assign mserdes_pllfixedclkch0    = serdes_pllfixedclkch0;
         assign mserdes_pllfixedclkch1    = unconnected_wire;
         assign mserdes_pipe_pclkcentral  = unconnected_wire;
         assign mserdes_pllfixedclkcentral= unconnected_wire;

         assign  rxdata1      = (pipe_mode==1'b1)?0    :unconnected_bus[31:0];
         assign  rxdata2      = (pipe_mode==1'b1)?0    :unconnected_bus[31:0];
         assign  rxdata3      = (pipe_mode==1'b1)?0    :unconnected_bus[31:0];
         assign  rxdata4      = (pipe_mode==1'b1)?0    :unconnected_bus[31:0];
         assign  rxdata5      = (pipe_mode==1'b1)?0    :unconnected_bus[31:0];
         assign  rxdata6      = (pipe_mode==1'b1)?0    :unconnected_bus[31:0];
         assign  rxdata7      = (pipe_mode==1'b1)?0    :unconnected_bus[31:0];

         assign  rxdatak1     = (pipe_mode==1'b1)?0   :unconnected_bus[3:0] ;
         assign  rxdatak2     = (pipe_mode==1'b1)?0   :unconnected_bus[3:0] ;
         assign  rxdatak3     = (pipe_mode==1'b1)?0   :unconnected_bus[3:0] ;
         assign  rxdatak4     = (pipe_mode==1'b1)?0   :unconnected_bus[3:0] ;
         assign  rxdatak5     = (pipe_mode==1'b1)?0   :unconnected_bus[3:0] ;
         assign  rxdatak6     = (pipe_mode==1'b1)?0   :unconnected_bus[3:0] ;
         assign  rxdatak7     = (pipe_mode==1'b1)?0   :unconnected_bus[3:0] ;

         assign  rxvalid1     = (pipe_mode==1'b1)?0   :unconnected_wire;
         assign  rxvalid2     = (pipe_mode==1'b1)?0   :unconnected_wire;
         assign  rxvalid3     = (pipe_mode==1'b1)?0   :unconnected_wire;
         assign  rxvalid4     = (pipe_mode==1'b1)?0   :unconnected_wire;
         assign  rxvalid5     = (pipe_mode==1'b1)?0   :unconnected_wire;
         assign  rxvalid6     = (pipe_mode==1'b1)?0   :unconnected_wire;
         assign  rxvalid7     = (pipe_mode==1'b1)?0   :unconnected_wire;

         assign  rxelecidle1  = (pipe_mode==1'b1)?0:unconnected_wire;
         assign  rxelecidle2  = (pipe_mode==1'b1)?0:unconnected_wire;
         assign  rxelecidle3  = (pipe_mode==1'b1)?0:unconnected_wire;
         assign  rxelecidle4  = (pipe_mode==1'b1)?0:unconnected_wire;
         assign  rxelecidle5  = (pipe_mode==1'b1)?0:unconnected_wire;
         assign  rxelecidle6  = (pipe_mode==1'b1)?0:unconnected_wire;
         assign  rxelecidle7  = (pipe_mode==1'b1)?0:unconnected_wire;

         assign  phystatus1   = (pipe_mode==1'b1)?1'b0              :unconnected_wire;
         assign  phystatus2   = (pipe_mode==1'b1)?1'b0              :unconnected_wire;
         assign  phystatus3   = (pipe_mode==1'b1)?1'b0              :unconnected_wire;
         assign  phystatus4   = (pipe_mode==1'b1)?1'b0              :unconnected_wire;
         assign  phystatus5   = (pipe_mode==1'b1)?1'b0              :unconnected_wire;
         assign  phystatus6   = (pipe_mode==1'b1)?1'b0              :unconnected_wire;
         assign  phystatus7   = (pipe_mode==1'b1)?1'b0              :unconnected_wire;

         assign  rxstatus1    = (pipe_mode==1'b1)?0  :unconnected_bus[2:0];
         assign  rxstatus2    = (pipe_mode==1'b1)?0  :unconnected_bus[2:0];
         assign  rxstatus3    = (pipe_mode==1'b1)?0  :unconnected_bus[2:0];
         assign  rxstatus4    = (pipe_mode==1'b1)?0  :unconnected_bus[2:0];
         assign  rxstatus5    = (pipe_mode==1'b1)?0  :unconnected_bus[2:0];
         assign  rxstatus6    = (pipe_mode==1'b1)?0  :unconnected_bus[2:0];
         assign  rxstatus7    = (pipe_mode==1'b1)?0  :unconnected_bus[2:0];

         assign pld8grxstatus1 = unconnected_bus[2:0];
         assign pld8grxstatus2 = unconnected_bus[2:0];
         assign pld8grxstatus3 = unconnected_bus[2:0];
         assign pld8grxstatus4 = unconnected_bus[2:0];
         assign pld8grxstatus5 = unconnected_bus[2:0];
         assign pld8grxstatus6 = unconnected_bus[2:0];
         assign pld8grxstatus7 = unconnected_bus[2:0];

         // Reset signals

      end
      else if (LANES==2) begin
         assign int_sigdet = {
         serdes_rx_is_lockedtodata[1] | serdes_rx_is_lockedtodata[0],
         serdes_rx_is_lockedtodata[0] | serdes_rx_is_lockedtodata[0]
         };
         // TX
         assign serdes_ratectrl                 = unconnected_bus[0];
         assign serdes_pipe_rate[0]             = rate0;
         assign serdes_pipe_rate[1]             = rate1;

         assign serdes_pipe_txdata[7 :0  ]      = txdata0;
         assign serdes_pipe_txdata[15 :8 ]      = txdata1;

         assign serdes_pipe_txdatak[0]          = txdatak0;
         assign serdes_pipe_txdatak[1]          = txdatak1;

         assign serdes_pipe_txcompliance[0]     = txcompl0;
         assign serdes_pipe_txcompliance[1]     = txcompl1;

         assign serdes_pipe_txelecidle[0]       = txelecidle0;
         assign serdes_pipe_txelecidle[1]       = txelecidle1;

         assign serdes_pipe_txdeemph[0]         = txdeemph0;
         assign serdes_pipe_txdeemph[1]         = txdeemph1;

         assign serdes_pipe_txmargin[ 2: 0]     = txmargin0;
         assign serdes_pipe_txmargin[ 5: 3]     = txmargin1;

         assign serdes_pipe_txswing[0]          = txswing0;
         assign serdes_pipe_txswing[1]          = txswing1;

         assign serdes_pipe_powerdown[ 1 : 0]   = powerdown0;
         assign serdes_pipe_powerdown[ 3 : 2]   = powerdown1;

         assign  serdes_pipe_rxpolarity[0]      = rxpolarity0 ;
         assign  serdes_pipe_rxpolarity[1]      = rxpolarity1 ;

         assign serdes_pipe_txdetectrx_loopback[0] = txdetectrx0;
         assign serdes_pipe_txdetectrx_loopback[1] = txdetectrx1;

         assign     tx_out0                = serdes_tx_serial_data[0];
         assign     tx_out1                = serdes_tx_serial_data[1];

         //RX
         //
         assign  serdes_rx_serial_data[0]=rx_in0;
         assign  serdes_rx_serial_data[1]=rx_in1;

         assign  serdes_rx_eidleinfersel[2:0] = eidleinfersel0;
         assign  serdes_rx_eidleinfersel[5:3] = eidleinfersel1;

         assign  rxdata0      = (pipe_mode==1'b1)?rxdata0_ext    :serdes_pipe_rxdata[7 :0  ];
         assign  rxdata1      = (pipe_mode==1'b1)?rxdata1_ext    :serdes_pipe_rxdata[15 :8 ];

         assign  rxdatak0     = (pipe_mode==1'b1)?rxdatak0_ext   :serdes_pipe_rxdatak[0] ;
         assign  rxdatak1     = (pipe_mode==1'b1)?rxdatak1_ext   :serdes_pipe_rxdatak[1] ;

         assign  rxvalid0     = (pipe_mode==1'b1)?rxvalid0_ext   :serdes_pipe_rxvalid[0] ;
         assign  rxvalid1     = (pipe_mode==1'b1)?rxvalid1_ext   :serdes_pipe_rxvalid[1] ;

         assign  rxelecidle0  = (pipe_mode==1'b1)?rxelecidle0_ext:serdes_pipe_rxelecidle[0] ;
         assign  rxelecidle1  = (pipe_mode==1'b1)?rxelecidle1_ext:serdes_pipe_rxelecidle[1] ;

         assign  phystatus0   = (pipe_mode==1'b1)?phystatus0_ext :serdes_pipe_phystatus[0] ;
         assign  phystatus1   = (pipe_mode==1'b1)?phystatus1_ext :serdes_pipe_phystatus[1] ;

         assign  rxstatus0    = (pipe_mode==1'b1)?rxstatus0_ext  :serdes_pipe_rxstatus[ 2: 0];
         assign  rxstatus1    = (pipe_mode==1'b1)?rxstatus1_ext  :serdes_pipe_rxstatus[ 5: 3];

         assign pld8grxstatus0 = serdes_pld8grxstatus[2:0];
         assign pld8grxstatus1 = serdes_pld8grxstatus[5:3];

         assign mserdes_pipe_pclk         = unconnected_wire;
         assign mserdes_pipe_pclkch1      = serdes_pipe_pclkch1;
         assign mserdes_pllfixedclkch0    = unconnected_wire;
         assign mserdes_pllfixedclkch1    = serdes_pllfixedclkch1 ;
         assign mserdes_pipe_pclkcentral  = unconnected_wire;
         assign mserdes_pllfixedclkcentral= unconnected_wire;

         assign  rxdata2      = (pipe_mode==1'b1)?0    :unconnected_bus[31:0];
         assign  rxdata3      = (pipe_mode==1'b1)?0    :unconnected_bus[31:0];
         assign  rxdata4      = (pipe_mode==1'b1)?0    :unconnected_bus[31:0];
         assign  rxdata5      = (pipe_mode==1'b1)?0    :unconnected_bus[31:0];
         assign  rxdata6      = (pipe_mode==1'b1)?0    :unconnected_bus[31:0];
         assign  rxdata7      = (pipe_mode==1'b1)?0    :unconnected_bus[31:0];
         assign  rxdatak2     = (pipe_mode==1'b1)?0   :unconnected_bus[3:0] ;
         assign  rxdatak3     = (pipe_mode==1'b1)?0   :unconnected_bus[3:0] ;
         assign  rxdatak4     = (pipe_mode==1'b1)?0   :unconnected_bus[3:0] ;
         assign  rxdatak5     = (pipe_mode==1'b1)?0   :unconnected_bus[3:0] ;
         assign  rxdatak6     = (pipe_mode==1'b1)?0   :unconnected_bus[3:0] ;
         assign  rxdatak7     = (pipe_mode==1'b1)?0   :unconnected_bus[3:0] ;
         assign  rxvalid2     = (pipe_mode==1'b1)?0   :unconnected_wire;
         assign  rxvalid3     = (pipe_mode==1'b1)?0   :unconnected_wire;
         assign  rxvalid4     = (pipe_mode==1'b1)?0   :unconnected_wire;
         assign  rxvalid5     = (pipe_mode==1'b1)?0   :unconnected_wire;
         assign  rxvalid6     = (pipe_mode==1'b1)?0   :unconnected_wire;
         assign  rxvalid7     = (pipe_mode==1'b1)?0   :unconnected_wire;
         assign  rxelecidle2  = (pipe_mode==1'b1)?0:unconnected_wire;
         assign  rxelecidle3  = (pipe_mode==1'b1)?0:unconnected_wire;
         assign  rxelecidle4  = (pipe_mode==1'b1)?0:unconnected_wire;
         assign  rxelecidle5  = (pipe_mode==1'b1)?0:unconnected_wire;
         assign  rxelecidle6  = (pipe_mode==1'b1)?0:unconnected_wire;
         assign  rxelecidle7  = (pipe_mode==1'b1)?0:unconnected_wire;
         assign  phystatus2   = (pipe_mode==1'b1)?1'b0 :unconnected_wire ;
         assign  phystatus3   = (pipe_mode==1'b1)?1'b0 :unconnected_wire ;
         assign  phystatus4   = (pipe_mode==1'b1)?1'b0 :unconnected_wire ;
         assign  phystatus5   = (pipe_mode==1'b1)?1'b0 :unconnected_wire ;
         assign  phystatus6   = (pipe_mode==1'b1)?1'b0 :unconnected_wire ;
         assign  phystatus7   = (pipe_mode==1'b1)?1'b0 :unconnected_wire ;
         assign  rxstatus2    = (pipe_mode==1'b1)?0  :unconnected_bus[2:0];
         assign  rxstatus3    = (pipe_mode==1'b1)?0  :unconnected_bus[2:0];
         assign  rxstatus4    = (pipe_mode==1'b1)?0  :unconnected_bus[2:0];
         assign  rxstatus5    = (pipe_mode==1'b1)?0  :unconnected_bus[2:0];
         assign  rxstatus6    = (pipe_mode==1'b1)?0  :unconnected_bus[2:0];
         assign  rxstatus7    = (pipe_mode==1'b1)?0  :unconnected_bus[2:0];

         assign pld8grxstatus2 = unconnected_bus[2:0];
         assign pld8grxstatus3 = unconnected_bus[2:0];
         assign pld8grxstatus4 = unconnected_bus[2:0];
         assign pld8grxstatus5 = unconnected_bus[2:0];
         assign pld8grxstatus6 = unconnected_bus[2:0];
         assign pld8grxstatus7 = unconnected_bus[2:0];

      end
      else if (LANES==4) begin
         assign int_sigdet = {
         serdes_rx_is_lockedtodata[3] | serdes_rx_is_lockedtodata[0],
         serdes_rx_is_lockedtodata[2] | serdes_rx_is_lockedtodata[0],
         serdes_rx_is_lockedtodata[1] | serdes_rx_is_lockedtodata[0],
         serdes_rx_is_lockedtodata[0] | serdes_rx_is_lockedtodata[0]
         };
         // TX
         assign serdes_ratectrl              = unconnected_bus[0];
         assign serdes_pipe_rate[0]          = rate0;
         assign serdes_pipe_rate[1]          = rate1;
         assign serdes_pipe_rate[2]          = rate2;
         assign serdes_pipe_rate[3]          = rate3;

         assign serdes_pipe_txdata[7 :0 ]   = txdata0;
         assign serdes_pipe_txdata[15:8 ]   = txdata1;
         assign serdes_pipe_txdata[23:16]   = txdata2;
         assign serdes_pipe_txdata[31:24]   = txdata3;

         assign serdes_pipe_txdatak[0]    = txdatak0;
         assign serdes_pipe_txdatak[1]    = txdatak1;
         assign serdes_pipe_txdatak[2]    = txdatak2;
         assign serdes_pipe_txdatak[3]    = txdatak3;

         assign serdes_pipe_txcompliance[0]   = txcompl0;
         assign serdes_pipe_txcompliance[1]   = txcompl1;
         assign serdes_pipe_txcompliance[2]   = txcompl2;
         assign serdes_pipe_txcompliance[3]   = txcompl3;

         assign serdes_pipe_txelecidle[0]     = txelecidle0;
         assign serdes_pipe_txelecidle[1]     = txelecidle1;
         assign serdes_pipe_txelecidle[2]     = txelecidle2;
         assign serdes_pipe_txelecidle[3]     = txelecidle3;

         assign serdes_pipe_txdeemph[0]       = txdeemph0;
         assign serdes_pipe_txdeemph[1]       = txdeemph1;
         assign serdes_pipe_txdeemph[2]       = txdeemph2;
         assign serdes_pipe_txdeemph[3]       = txdeemph3;

         assign serdes_pipe_txmargin[ 2: 0]   = txmargin0;
         assign serdes_pipe_txmargin[ 5: 3]   = txmargin1;
         assign serdes_pipe_txmargin[ 8: 6]   = txmargin2;
         assign serdes_pipe_txmargin[11: 9]   = txmargin3;

         assign serdes_pipe_txswing[0]        = txswing0;
         assign serdes_pipe_txswing[1]        = txswing1;
         assign serdes_pipe_txswing[2]        = txswing2;
         assign serdes_pipe_txswing[3]        = txswing3;

         assign serdes_pipe_powerdown[ 1 : 0] = powerdown0;
         assign serdes_pipe_powerdown[ 3 : 2] = powerdown1;
         assign serdes_pipe_powerdown[ 5 : 4] = powerdown2;
         assign serdes_pipe_powerdown[ 7 : 6] = powerdown3;

         assign serdes_pipe_rxpolarity[0]    = rxpolarity0 ;
         assign serdes_pipe_rxpolarity[1]    = rxpolarity1 ;
         assign serdes_pipe_rxpolarity[2]    = rxpolarity2 ;
         assign serdes_pipe_rxpolarity[3]    = rxpolarity3 ;

         assign serdes_pipe_txdetectrx_loopback[0] = txdetectrx0;
         assign serdes_pipe_txdetectrx_loopback[1] = txdetectrx1;
         assign serdes_pipe_txdetectrx_loopback[2] = txdetectrx2;
         assign serdes_pipe_txdetectrx_loopback[3] = txdetectrx3;

         assign     tx_out0                = serdes_tx_serial_data[0];
         assign     tx_out1                = serdes_tx_serial_data[1];
         assign     tx_out2                = serdes_tx_serial_data[2];
         assign     tx_out3                = serdes_tx_serial_data[3];

         //RX
         //
         assign  serdes_rx_serial_data[0]=rx_in0;
         assign  serdes_rx_serial_data[1]=rx_in1;
         assign  serdes_rx_serial_data[2]=rx_in2;
         assign  serdes_rx_serial_data[3]=rx_in3;

         assign  serdes_rx_eidleinfersel[2:0] = eidleinfersel0;
         assign  serdes_rx_eidleinfersel[5:3] = eidleinfersel1;
         assign  serdes_rx_eidleinfersel[8:6] = eidleinfersel2;
         assign  serdes_rx_eidleinfersel[11:9]= eidleinfersel3;

         assign  rxdata0      = (pipe_mode==1'b1)?rxdata0_ext    :serdes_pipe_rxdata[7 :0  ];
         assign  rxdata1      = (pipe_mode==1'b1)?rxdata1_ext    :serdes_pipe_rxdata[15 :8 ];
         assign  rxdata2      = (pipe_mode==1'b1)?rxdata2_ext    :serdes_pipe_rxdata[23 :16 ];
         assign  rxdata3      = (pipe_mode==1'b1)?rxdata3_ext    :serdes_pipe_rxdata[31 :24 ];

         assign  rxdatak0     = (pipe_mode==1'b1)?rxdatak0_ext   :serdes_pipe_rxdatak[0] ;
         assign  rxdatak1     = (pipe_mode==1'b1)?rxdatak1_ext   :serdes_pipe_rxdatak[1] ;
         assign  rxdatak2     = (pipe_mode==1'b1)?rxdatak2_ext   :serdes_pipe_rxdatak[2] ;
         assign  rxdatak3     = (pipe_mode==1'b1)?rxdatak3_ext   :serdes_pipe_rxdatak[3] ;

         assign  rxvalid0     = (pipe_mode==1'b1)?rxvalid0_ext   :serdes_pipe_rxvalid[0] ;
         assign  rxvalid1     = (pipe_mode==1'b1)?rxvalid1_ext   :serdes_pipe_rxvalid[1] ;
         assign  rxvalid2     = (pipe_mode==1'b1)?rxvalid2_ext   :serdes_pipe_rxvalid[2] ;
         assign  rxvalid3     = (pipe_mode==1'b1)?rxvalid3_ext   :serdes_pipe_rxvalid[3] ;

         assign  rxelecidle0  = (pipe_mode==1'b1)?rxelecidle0_ext:serdes_pipe_rxelecidle[0] ;
         assign  rxelecidle1  = (pipe_mode==1'b1)?rxelecidle1_ext:serdes_pipe_rxelecidle[1] ;
         assign  rxelecidle2  = (pipe_mode==1'b1)?rxelecidle2_ext:serdes_pipe_rxelecidle[2] ;
         assign  rxelecidle3  = (pipe_mode==1'b1)?rxelecidle3_ext:serdes_pipe_rxelecidle[3] ;

         assign  phystatus0   = (pipe_mode==1'b1)?phystatus0_ext :serdes_pipe_phystatus[0] ;
         assign  phystatus1   = (pipe_mode==1'b1)?phystatus1_ext :serdes_pipe_phystatus[1] ;
         assign  phystatus2   = (pipe_mode==1'b1)?phystatus2_ext :serdes_pipe_phystatus[2] ;
         assign  phystatus3   = (pipe_mode==1'b1)?phystatus3_ext :serdes_pipe_phystatus[3] ;

         assign  rxstatus0    = (pipe_mode==1'b1)?rxstatus0_ext  :serdes_pipe_rxstatus[ 2: 0];
         assign  rxstatus1    = (pipe_mode==1'b1)?rxstatus1_ext  :serdes_pipe_rxstatus[ 5: 3];
         assign  rxstatus2    = (pipe_mode==1'b1)?rxstatus2_ext  :serdes_pipe_rxstatus[ 8: 6];
         assign  rxstatus3    = (pipe_mode==1'b1)?rxstatus3_ext  :serdes_pipe_rxstatus[11: 9];

         assign pld8grxstatus0 = serdes_pld8grxstatus[2:0];
         assign pld8grxstatus1 = serdes_pld8grxstatus[5:3];
         assign pld8grxstatus2 = serdes_pld8grxstatus[8:6];
         assign pld8grxstatus3 = serdes_pld8grxstatus[11:9];

         assign mserdes_pipe_pclk         = unconnected_wire;
         assign mserdes_pipe_pclkch1      = serdes_pipe_pclkch1;
         assign mserdes_pllfixedclkch0    = unconnected_wire;
         assign mserdes_pllfixedclkch1    = serdes_pllfixedclkch1;
         assign mserdes_pipe_pclkcentral  = unconnected_wire;
         assign mserdes_pllfixedclkcentral= unconnected_wire;

         assign  rxdata4      = (pipe_mode==1'b1)?0    :unconnected_bus[31:0];
         assign  rxdata5      = (pipe_mode==1'b1)?0    :unconnected_bus[31:0];
         assign  rxdata6      = (pipe_mode==1'b1)?0    :unconnected_bus[31:0];
         assign  rxdata7      = (pipe_mode==1'b1)?0    :unconnected_bus[31:0];
         assign  rxdatak4     = (pipe_mode==1'b1)?0   :unconnected_bus[3:0] ;
         assign  rxdatak5     = (pipe_mode==1'b1)?0   :unconnected_bus[3:0] ;
         assign  rxdatak6     = (pipe_mode==1'b1)?0   :unconnected_bus[3:0] ;
         assign  rxdatak7     = (pipe_mode==1'b1)?0   :unconnected_bus[3:0] ;
         assign  rxvalid4     = (pipe_mode==1'b1)?0   :unconnected_wire;
         assign  rxvalid5     = (pipe_mode==1'b1)?0   :unconnected_wire;
         assign  rxvalid6     = (pipe_mode==1'b1)?0   :unconnected_wire;
         assign  rxvalid7     = (pipe_mode==1'b1)?0   :unconnected_wire;
         assign  rxelecidle4  = (pipe_mode==1'b1)?0:unconnected_wire;
         assign  rxelecidle5  = (pipe_mode==1'b1)?0:unconnected_wire;
         assign  rxelecidle6  = (pipe_mode==1'b1)?0:unconnected_wire;
         assign  rxelecidle7  = (pipe_mode==1'b1)?0:unconnected_wire;
         assign  phystatus4   = (pipe_mode==1'b1)?1'b0 :unconnected_wire ;
         assign  phystatus5   = (pipe_mode==1'b1)?1'b0 :unconnected_wire ;
         assign  phystatus6   = (pipe_mode==1'b1)?1'b0 :unconnected_wire ;
         assign  phystatus7   = (pipe_mode==1'b1)?1'b0 :unconnected_wire ;
         assign  rxstatus4    = (pipe_mode==1'b1)?0  :unconnected_bus[2:0];
         assign  rxstatus5    = (pipe_mode==1'b1)?0  :unconnected_bus[2:0];
         assign  rxstatus6    = (pipe_mode==1'b1)?0  :unconnected_bus[2:0];
         assign  rxstatus7    = (pipe_mode==1'b1)?0  :unconnected_bus[2:0];

         assign pld8grxstatus4 = unconnected_bus[2:0];
         assign pld8grxstatus5 = unconnected_bus[2:0];
         assign pld8grxstatus6 = unconnected_bus[2:0];
         assign pld8grxstatus7 = unconnected_bus[2:0];

      end
      else begin // x8
         assign int_sigdet = {
         serdes_rx_is_lockedtodata[7] | serdes_rx_is_lockedtodata[0],
         serdes_rx_is_lockedtodata[6] | serdes_rx_is_lockedtodata[0],
         serdes_rx_is_lockedtodata[5] | serdes_rx_is_lockedtodata[0],
         serdes_rx_is_lockedtodata[4] | serdes_rx_is_lockedtodata[0],
         serdes_rx_is_lockedtodata[3] | serdes_rx_is_lockedtodata[0],
         serdes_rx_is_lockedtodata[2] | serdes_rx_is_lockedtodata[0],
         serdes_rx_is_lockedtodata[1] | serdes_rx_is_lockedtodata[0],
         serdes_rx_is_lockedtodata[0] | serdes_rx_is_lockedtodata[0]
         };
         // TX
         assign serdes_ratectrl           = ratectrl;
         assign serdes_pipe_rate[0]       = rate0;
         assign serdes_pipe_rate[1]       = rate1;
         assign serdes_pipe_rate[2]       = rate2;
         assign serdes_pipe_rate[3]       = rate3;
         assign serdes_pipe_rate[4]       = rate4;
         assign serdes_pipe_rate[5]       = rate5;
         assign serdes_pipe_rate[6]       = rate6;
         assign serdes_pipe_rate[7]       = rate7;

         assign serdes_pipe_txdata[7 :0 ]   = txdata0;
         assign serdes_pipe_txdata[15:8 ]   = txdata1;
         assign serdes_pipe_txdata[23:16]   = txdata2;
         assign serdes_pipe_txdata[31:24]   = txdata3;
         assign serdes_pipe_txdata[39:32]   = txdata4;
         assign serdes_pipe_txdata[47:40]   = txdata5;
         assign serdes_pipe_txdata[55:48]   = txdata6;
         assign serdes_pipe_txdata[63:56]   = txdata7;

         assign serdes_pipe_txdatak[0]    = txdatak0;
         assign serdes_pipe_txdatak[1]    = txdatak1;
         assign serdes_pipe_txdatak[2]    = txdatak2;
         assign serdes_pipe_txdatak[3]    = txdatak3;
         assign serdes_pipe_txdatak[4]    = txdatak4;
         assign serdes_pipe_txdatak[5]    = txdatak5;
         assign serdes_pipe_txdatak[6]    = txdatak6;
         assign serdes_pipe_txdatak[7]    = txdatak7;

         assign serdes_pipe_txcompliance[0]   = txcompl0;
         assign serdes_pipe_txcompliance[1]   = txcompl1;
         assign serdes_pipe_txcompliance[2]   = txcompl2;
         assign serdes_pipe_txcompliance[3]   = txcompl3;
         assign serdes_pipe_txcompliance[4]   = txcompl4;
         assign serdes_pipe_txcompliance[5]   = txcompl5;
         assign serdes_pipe_txcompliance[6]   = txcompl6;
         assign serdes_pipe_txcompliance[7]   = txcompl7;

         assign serdes_pipe_txelecidle[0]     = txelecidle0;
         assign serdes_pipe_txelecidle[1]     = txelecidle1;
         assign serdes_pipe_txelecidle[2]     = txelecidle2;
         assign serdes_pipe_txelecidle[3]     = txelecidle3;
         assign serdes_pipe_txelecidle[4]     = txelecidle4;
         assign serdes_pipe_txelecidle[5]     = txelecidle5;
         assign serdes_pipe_txelecidle[6]     = txelecidle6;
         assign serdes_pipe_txelecidle[7]     = txelecidle7;

         assign serdes_pipe_txdeemph[0]       = txdeemph0;
         assign serdes_pipe_txdeemph[1]       = txdeemph1;
         assign serdes_pipe_txdeemph[2]       = txdeemph2;
         assign serdes_pipe_txdeemph[3]       = txdeemph3;
         assign serdes_pipe_txdeemph[4]       = txdeemph4;
         assign serdes_pipe_txdeemph[5]       = txdeemph5;
         assign serdes_pipe_txdeemph[6]       = txdeemph6;
         assign serdes_pipe_txdeemph[7]       = txdeemph7;

         assign serdes_pipe_txmargin[ 2: 0]   = txmargin0;
         assign serdes_pipe_txmargin[ 5: 3]   = txmargin1;
         assign serdes_pipe_txmargin[ 8: 6]   = txmargin2;
         assign serdes_pipe_txmargin[11: 9]   = txmargin3;
         assign serdes_pipe_txmargin[14:12]   = txmargin4;
         assign serdes_pipe_txmargin[17:15]   = txmargin5;
         assign serdes_pipe_txmargin[20:18]   = txmargin6;
         assign serdes_pipe_txmargin[23:21]   = txmargin7;

         assign serdes_pipe_txswing[0]        = txswing0;
         assign serdes_pipe_txswing[1]        = txswing1;
         assign serdes_pipe_txswing[2]        = txswing2;
         assign serdes_pipe_txswing[3]        = txswing3;
         assign serdes_pipe_txswing[4]        = txswing4;
         assign serdes_pipe_txswing[5]        = txswing5;
         assign serdes_pipe_txswing[6]        = txswing6;
         assign serdes_pipe_txswing[7]        = txswing7;

         assign serdes_pipe_powerdown[ 1 : 0] = powerdown0;
         assign serdes_pipe_powerdown[ 3 : 2] = powerdown1;
         assign serdes_pipe_powerdown[ 5 : 4] = powerdown2;
         assign serdes_pipe_powerdown[ 7 : 6] = powerdown3;
         assign serdes_pipe_powerdown[ 9 : 8] = powerdown4;
         assign serdes_pipe_powerdown[11 :10] = powerdown5;
         assign serdes_pipe_powerdown[13 :12] = powerdown6;
         assign serdes_pipe_powerdown[15 :14] = powerdown7;

         assign  serdes_pipe_rxpolarity[0]    = rxpolarity0 ;
         assign  serdes_pipe_rxpolarity[1]    = rxpolarity1 ;
         assign  serdes_pipe_rxpolarity[2]    = rxpolarity2 ;
         assign  serdes_pipe_rxpolarity[3]    = rxpolarity3 ;
         assign  serdes_pipe_rxpolarity[4]    = rxpolarity4 ;
         assign  serdes_pipe_rxpolarity[5]    = rxpolarity5 ;
         assign  serdes_pipe_rxpolarity[6]    = rxpolarity6 ;
         assign  serdes_pipe_rxpolarity[7]    = rxpolarity7 ;

         assign serdes_pipe_txdetectrx_loopback[0] = txdetectrx0;
         assign serdes_pipe_txdetectrx_loopback[1] = txdetectrx1;
         assign serdes_pipe_txdetectrx_loopback[2] = txdetectrx2;
         assign serdes_pipe_txdetectrx_loopback[3] = txdetectrx3;
         assign serdes_pipe_txdetectrx_loopback[4] = txdetectrx4;
         assign serdes_pipe_txdetectrx_loopback[5] = txdetectrx5;
         assign serdes_pipe_txdetectrx_loopback[6] = txdetectrx6;
         assign serdes_pipe_txdetectrx_loopback[7] = txdetectrx7;

         assign tx_out0                            = serdes_tx_serial_data[0];
         assign tx_out1                            = serdes_tx_serial_data[1];
         assign tx_out2                            = serdes_tx_serial_data[2];
         assign tx_out3                            = serdes_tx_serial_data[3];
         assign tx_out4                            = serdes_tx_serial_data[4];
         assign tx_out5                            = serdes_tx_serial_data[5];
         assign tx_out6                            = serdes_tx_serial_data[6];
         assign tx_out7                            = serdes_tx_serial_data[7];

         //RX
         //
         assign  serdes_rx_serial_data[0]=rx_in0;
         assign  serdes_rx_serial_data[1]=rx_in1;
         assign  serdes_rx_serial_data[2]=rx_in2;
         assign  serdes_rx_serial_data[3]=rx_in3;
         assign  serdes_rx_serial_data[4]=rx_in4;
         assign  serdes_rx_serial_data[5]=rx_in5;
         assign  serdes_rx_serial_data[6]=rx_in6;
         assign  serdes_rx_serial_data[7]=rx_in7;

         assign  serdes_rx_eidleinfersel[2:0]   = eidleinfersel0;
         assign  serdes_rx_eidleinfersel[5:3]   = eidleinfersel1;
         assign  serdes_rx_eidleinfersel[8:6]   = eidleinfersel2;
         assign  serdes_rx_eidleinfersel[11:9]  = eidleinfersel3;
         assign  serdes_rx_eidleinfersel[14:12] = eidleinfersel4;
         assign  serdes_rx_eidleinfersel[17:15] = eidleinfersel5;
         assign  serdes_rx_eidleinfersel[20:18] = eidleinfersel6;
         assign  serdes_rx_eidleinfersel[23:21] = eidleinfersel7;

         assign  rxdata0      = (pipe_mode==1'b1)?rxdata0_ext    :serdes_pipe_rxdata[7:0  ];
         assign  rxdata1      = (pipe_mode==1'b1)?rxdata1_ext    :serdes_pipe_rxdata[15:8];
         assign  rxdata2      = (pipe_mode==1'b1)?rxdata2_ext    :serdes_pipe_rxdata[23:16];
         assign  rxdata3      = (pipe_mode==1'b1)?rxdata3_ext    :serdes_pipe_rxdata[31:24];
         assign  rxdata4      = (pipe_mode==1'b1)?rxdata4_ext    :serdes_pipe_rxdata[39:32];
         assign  rxdata5      = (pipe_mode==1'b1)?rxdata5_ext    :serdes_pipe_rxdata[47:40];
         assign  rxdata6      = (pipe_mode==1'b1)?rxdata6_ext    :serdes_pipe_rxdata[55:48];
         assign  rxdata7      = (pipe_mode==1'b1)?rxdata7_ext    :serdes_pipe_rxdata[63:56];

         assign  rxdatak0     = (pipe_mode==1'b1)?rxdatak0_ext   :serdes_pipe_rxdatak[0] ;
         assign  rxdatak1     = (pipe_mode==1'b1)?rxdatak1_ext   :serdes_pipe_rxdatak[1] ;
         assign  rxdatak2     = (pipe_mode==1'b1)?rxdatak2_ext   :serdes_pipe_rxdatak[2] ;
         assign  rxdatak3     = (pipe_mode==1'b1)?rxdatak3_ext   :serdes_pipe_rxdatak[3] ;
         assign  rxdatak4     = (pipe_mode==1'b1)?rxdatak4_ext   :serdes_pipe_rxdatak[4] ;
         assign  rxdatak5     = (pipe_mode==1'b1)?rxdatak5_ext   :serdes_pipe_rxdatak[5] ;
         assign  rxdatak6     = (pipe_mode==1'b1)?rxdatak6_ext   :serdes_pipe_rxdatak[6] ;
         assign  rxdatak7     = (pipe_mode==1'b1)?rxdatak7_ext   :serdes_pipe_rxdatak[7] ;

         assign  rxvalid0     = (pipe_mode==1'b1)?rxvalid0_ext   :serdes_pipe_rxvalid[0] ;
         assign  rxvalid1     = (pipe_mode==1'b1)?rxvalid1_ext   :serdes_pipe_rxvalid[1] ;
         assign  rxvalid2     = (pipe_mode==1'b1)?rxvalid2_ext   :serdes_pipe_rxvalid[2] ;
         assign  rxvalid3     = (pipe_mode==1'b1)?rxvalid3_ext   :serdes_pipe_rxvalid[3] ;
         assign  rxvalid4     = (pipe_mode==1'b1)?rxvalid4_ext   :serdes_pipe_rxvalid[4] ;
         assign  rxvalid5     = (pipe_mode==1'b1)?rxvalid5_ext   :serdes_pipe_rxvalid[5] ;
         assign  rxvalid6     = (pipe_mode==1'b1)?rxvalid6_ext   :serdes_pipe_rxvalid[6] ;
         assign  rxvalid7     = (pipe_mode==1'b1)?rxvalid7_ext   :serdes_pipe_rxvalid[7] ;

         assign  rxelecidle0  = (pipe_mode==1'b1)?rxelecidle0_ext:serdes_pipe_rxelecidle[0] ;
         assign  rxelecidle1  = (pipe_mode==1'b1)?rxelecidle1_ext:serdes_pipe_rxelecidle[1] ;
         assign  rxelecidle2  = (pipe_mode==1'b1)?rxelecidle2_ext:serdes_pipe_rxelecidle[2] ;
         assign  rxelecidle3  = (pipe_mode==1'b1)?rxelecidle3_ext:serdes_pipe_rxelecidle[3] ;
         assign  rxelecidle4  = (pipe_mode==1'b1)?rxelecidle4_ext:serdes_pipe_rxelecidle[4] ;
         assign  rxelecidle5  = (pipe_mode==1'b1)?rxelecidle5_ext:serdes_pipe_rxelecidle[5] ;
         assign  rxelecidle6  = (pipe_mode==1'b1)?rxelecidle6_ext:serdes_pipe_rxelecidle[6] ;
         assign  rxelecidle7  = (pipe_mode==1'b1)?rxelecidle7_ext:serdes_pipe_rxelecidle[7] ;

         assign  phystatus0   = (pipe_mode==1'b1)?phystatus0_ext :serdes_pipe_phystatus[0] ;
         assign  phystatus1   = (pipe_mode==1'b1)?phystatus1_ext :serdes_pipe_phystatus[1] ;
         assign  phystatus2   = (pipe_mode==1'b1)?phystatus2_ext :serdes_pipe_phystatus[2] ;
         assign  phystatus3   = (pipe_mode==1'b1)?phystatus3_ext :serdes_pipe_phystatus[3] ;
         assign  phystatus4   = (pipe_mode==1'b1)?phystatus4_ext :serdes_pipe_phystatus[4] ;
         assign  phystatus5   = (pipe_mode==1'b1)?phystatus5_ext :serdes_pipe_phystatus[5] ;
         assign  phystatus6   = (pipe_mode==1'b1)?phystatus6_ext :serdes_pipe_phystatus[6] ;
         assign  phystatus7   = (pipe_mode==1'b1)?phystatus7_ext :serdes_pipe_phystatus[7] ;

         assign  rxstatus0    = (pipe_mode==1'b1)?rxstatus0_ext  :serdes_pipe_rxstatus[ 2: 0];
         assign  rxstatus1    = (pipe_mode==1'b1)?rxstatus1_ext  :serdes_pipe_rxstatus[ 5: 3];
         assign  rxstatus2    = (pipe_mode==1'b1)?rxstatus2_ext  :serdes_pipe_rxstatus[ 8: 6];
         assign  rxstatus3    = (pipe_mode==1'b1)?rxstatus3_ext  :serdes_pipe_rxstatus[11: 9];
         assign  rxstatus4    = (pipe_mode==1'b1)?rxstatus4_ext  :serdes_pipe_rxstatus[14:12];
         assign  rxstatus5    = (pipe_mode==1'b1)?rxstatus5_ext  :serdes_pipe_rxstatus[17:15];
         assign  rxstatus6    = (pipe_mode==1'b1)?rxstatus6_ext  :serdes_pipe_rxstatus[20:18];
         assign  rxstatus7    = (pipe_mode==1'b1)?rxstatus7_ext  :serdes_pipe_rxstatus[23:21];

         assign pld8grxstatus0 = serdes_pld8grxstatus[2:0];
         assign pld8grxstatus1 = serdes_pld8grxstatus[5:3];
         assign pld8grxstatus2 = serdes_pld8grxstatus[8:6];
         assign pld8grxstatus3 = serdes_pld8grxstatus[11:9];
         assign pld8grxstatus4 = serdes_pld8grxstatus[17:15];
         assign pld8grxstatus5 = serdes_pld8grxstatus[20:18];
         assign pld8grxstatus6 = serdes_pld8grxstatus[23:21];
         assign pld8grxstatus7 = serdes_pld8grxstatus[26:24];

         assign mserdes_pipe_pclk         = unconnected_wire;
         assign mserdes_pipe_pclkch1      = unconnected_wire;
         assign mserdes_pllfixedclkch0    = unconnected_wire;
         assign mserdes_pllfixedclkch1    = unconnected_wire;
         assign mserdes_pipe_pclkcentral  = serdes_pipe_pclkcentral;
         assign mserdes_pllfixedclkcentral= serdes_pllfixedclkcentral;
      end
   end
   endgenerate

   assign rate          = (pipe_mode==1'b1)?rate0:1'b0;

   always @(posedge pld_clk or posedge por) begin
      if (por == 1'b1) begin
         arst_r[2:0] <= 3'b111;
      end
      else begin
         arst_r[2:0] <= {arst_r[1],arst_r[0],1'b0};
      end
   end
   assign arst = arst_r[2];

   always @(posedge pld_clk or posedge arst) begin
      if (arst==1'b1) begin
         pld_clk_in_use    <= 1'b0;
         reset_status      <= 1'b1;
         reset_status_sync <= 1'b1;
         flrreset_hip      <= 8'h0;
      end
      else begin
         pld_clk_in_use    <= pld_clk_in_use_hip;
         reset_status_sync <= reset_status_hip;
         reset_status      <= reset_status_sync;
         flrreset_hip[0]   <= (flr_capability_0=="true")?flr_sts[0]:1'b0;
         flrreset_hip[1]   <= (flr_capability_1=="true")?flr_sts[1]:1'b0;
         flrreset_hip[2]   <= (flr_capability_2=="true")?flr_sts[2]:1'b0;
         flrreset_hip[3]   <= (flr_capability_3=="true")?flr_sts[3]:1'b0;
         flrreset_hip[4]   <= (flr_capability_4=="true")?flr_sts[4]:1'b0;
         flrreset_hip[5]   <= (flr_capability_5=="true")?flr_sts[5]:1'b0;
         flrreset_hip[6]   <= (flr_capability_6=="true")?flr_sts[6]:1'b0;
         flrreset_hip[7]   <= (flr_capability_7=="true")?flr_sts[7]:1'b0;
      end
   end

   generate begin : g_cavhip
      if (device_family=="Cyclone V") begin

            // synthesis translate_off
               arriav_hd_altpe2_hip_top_simu_only_dump cyclonev_hd_altpe2_hip_top_simu_only_dump (
                     .rx_val_dl           (arriav_hd_altpe2_hip_top.arriav_hd_altpe2_hip_top_i.arriav_hd_altpe2_hip_top_encrypted_i.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.rx_val_dl             ),
                     .rx_data_dl          (arriav_hd_altpe2_hip_top.arriav_hd_altpe2_hip_top_i.arriav_hd_altpe2_hip_top_encrypted_i.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.rx_data_dl [63:0]     ),
                     .rx_datak_dl         (arriav_hd_altpe2_hip_top.arriav_hd_altpe2_hip_top_i.arriav_hd_altpe2_hip_top_encrypted_i.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.rx_datak_dl[7:0]      ),
                     .txok                (arriav_hd_altpe2_hip_top.arriav_hd_altpe2_hip_top_i.arriav_hd_altpe2_hip_top_encrypted_i.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.txok   ),
                     .sop                 (arriav_hd_altpe2_hip_top.arriav_hd_altpe2_hip_top_i.arriav_hd_altpe2_hip_top_encrypted_i.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.sop    ),
                     .eop                 (arriav_hd_altpe2_hip_top.arriav_hd_altpe2_hip_top_i.arriav_hd_altpe2_hip_top_encrypted_i.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.eop    ),
                     .eot                 (arriav_hd_altpe2_hip_top.arriav_hd_altpe2_hip_top_i.arriav_hd_altpe2_hip_top_encrypted_i.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.eot    ),
                     .tdata               (arriav_hd_altpe2_hip_top.arriav_hd_altpe2_hip_top_i.arriav_hd_altpe2_hip_top_encrypted_i.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.tdata  [63:0]),
                     .tdatak              (arriav_hd_altpe2_hip_top.arriav_hd_altpe2_hip_top_i.arriav_hd_altpe2_hip_top_encrypted_i.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.tdatak [7:0] ),
                     .rx_data_tlp_tl      (arriav_hd_altpe2_hip_top.arriav_hd_altpe2_hip_top_i.arriav_hd_altpe2_hip_top_encrypted_i.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.rx_data_tlp_tl  [63:0]),
                     .rx_dval_tlp_tl      (arriav_hd_altpe2_hip_top.arriav_hd_altpe2_hip_top_i.arriav_hd_altpe2_hip_top_encrypted_i.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.rx_dval_tlp_tl        ),
                     .rx_fval_tlp_tl      (arriav_hd_altpe2_hip_top.arriav_hd_altpe2_hip_top_i.arriav_hd_altpe2_hip_top_encrypted_i.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.rx_fval_tlp_tl        ),
                     .rx_hval_tlp_tl      (arriav_hd_altpe2_hip_top.arriav_hd_altpe2_hip_top_i.arriav_hd_altpe2_hip_top_encrypted_i.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.rx_hval_tlp_tl        ),
                     .rx_mlf_tlp_tl       (arriav_hd_altpe2_hip_top.arriav_hd_altpe2_hip_top_i.arriav_hd_altpe2_hip_top_encrypted_i.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.rx_mlf_tlp_tl         ),
                     .rx_ecrcerr_tlp_tl   (arriav_hd_altpe2_hip_top.arriav_hd_altpe2_hip_top_i.arriav_hd_altpe2_hip_top_encrypted_i.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.rx_ecrcerr_tlp_tl     ),
                     .rx_discard_tlp_tl   (arriav_hd_altpe2_hip_top.arriav_hd_altpe2_hip_top_i.arriav_hd_altpe2_hip_top_encrypted_i.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.rx_discard_tlp_tl     ),
                     .rx_check_tlp_tl     (arriav_hd_altpe2_hip_top.arriav_hd_altpe2_hip_top_i.arriav_hd_altpe2_hip_top_encrypted_i.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.rx_check_tlp_tl       ),
                     .rx_ok_tlp_tl        (arriav_hd_altpe2_hip_top.arriav_hd_altpe2_hip_top_i.arriav_hd_altpe2_hip_top_encrypted_i.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.rx_ok_tlp_tl          ),
                     .rx_err_tlp_tl       (arriav_hd_altpe2_hip_top.arriav_hd_altpe2_hip_top_i.arriav_hd_altpe2_hip_top_encrypted_i.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.rx_err_tlp_tl         ),
                     .tx_req_tlp_tl       (arriav_hd_altpe2_hip_top.arriav_hd_altpe2_hip_top_i.arriav_hd_altpe2_hip_top_encrypted_i.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.tx_req_tlp_tl         ),
                     .tx_ack_tlp_tl       (arriav_hd_altpe2_hip_top.arriav_hd_altpe2_hip_top_i.arriav_hd_altpe2_hip_top_encrypted_i.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.tx_ack_tlp_tl         ),
                     .tx_dreq_tlp_tl      (arriav_hd_altpe2_hip_top.arriav_hd_altpe2_hip_top_i.arriav_hd_altpe2_hip_top_encrypted_i.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.tx_dreq_tlp_tl        ),
                     .tx_err_tlp_tl       (arriav_hd_altpe2_hip_top.arriav_hd_altpe2_hip_top_i.arriav_hd_altpe2_hip_top_encrypted_i.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.tx_err_tlp_tl         ),
                     .tx_data_tlp_tl      (arriav_hd_altpe2_hip_top.arriav_hd_altpe2_hip_top_i.arriav_hd_altpe2_hip_top_encrypted_i.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.tx_data_tlp_tl[63:0]  ),
                     .clk                 (arriav_hd_altpe2_hip_top.arriav_hd_altpe2_hip_top_i.arriav_hd_altpe2_hip_top_encrypted_i.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.clk              ),
                     .rstn                (arriav_hd_altpe2_hip_top.arriav_hd_altpe2_hip_top_i.arriav_hd_altpe2_hip_top_encrypted_i.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.rstn             ),
                     .srst                (arriav_hd_altpe2_hip_top.arriav_hd_altpe2_hip_top_i.arriav_hd_altpe2_hip_top_encrypted_i.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.srst             ),
                     .ev128ns             (arriav_hd_altpe2_hip_top.arriav_hd_altpe2_hip_top_i.arriav_hd_altpe2_hip_top_encrypted_i.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.ev128ns          ),
                     .dl_up               (arriav_hd_altpe2_hip_top.arriav_hd_altpe2_hip_top_i.arriav_hd_altpe2_hip_top_encrypted_i.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.dl_up            ),
                     .err_dll             (arriav_hd_altpe2_hip_top.arriav_hd_altpe2_hip_top_i.arriav_hd_altpe2_hip_top_encrypted_i.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.err_dll          ),
                     .rx_err_frame        (arriav_hd_altpe2_hip_top.arriav_hd_altpe2_hip_top_i.arriav_hd_altpe2_hip_top_encrypted_i.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.rx_err_frame     ),
                     .lane_act            (arriav_hd_altpe2_hip_top.arriav_hd_altpe2_hip_top_i.arriav_hd_altpe2_hip_top_encrypted_i.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.lane_act         ),
                     .l0state             (arriav_hd_altpe2_hip_top.arriav_hd_altpe2_hip_top_i.arriav_hd_altpe2_hip_top_encrypted_i.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.l0state          ),
                     .l0sstate            (arriav_hd_altpe2_hip_top.arriav_hd_altpe2_hip_top_i.arriav_hd_altpe2_hip_top_encrypted_i.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.l0sstate         ),
                     .link_up             (arriav_hd_altpe2_hip_top.arriav_hd_altpe2_hip_top_i.arriav_hd_altpe2_hip_top_encrypted_i.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.link_up          ),
                     .link_train          (arriav_hd_altpe2_hip_top.arriav_hd_altpe2_hip_top_i.arriav_hd_altpe2_hip_top_encrypted_i.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.link_train       ),
                     .test_ltssm          (arriav_hd_altpe2_hip_top.arriav_hd_altpe2_hip_top_i.arriav_hd_altpe2_hip_top_encrypted_i.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.test_ltssm       ),
                     .rx_val_fc           (arriav_hd_altpe2_hip_top.arriav_hd_altpe2_hip_top_i.arriav_hd_altpe2_hip_top_encrypted_i.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.rx_val_fc       ),
                     .rx_val_fc_real      (arriav_hd_altpe2_hip_top.arriav_hd_altpe2_hip_top_i.arriav_hd_altpe2_hip_top_encrypted_i.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.rx_val_fc_real  ),
                     .rx_ini_fc           (arriav_hd_altpe2_hip_top.arriav_hd_altpe2_hip_top_i.arriav_hd_altpe2_hip_top_encrypted_i.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.rx_ini_fc       ),
                     .rx_ini_fc_real      (arriav_hd_altpe2_hip_top.arriav_hd_altpe2_hip_top_i.arriav_hd_altpe2_hip_top_encrypted_i.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.rx_ini_fc_real  ),
                     .rx_typ_fc           (arriav_hd_altpe2_hip_top.arriav_hd_altpe2_hip_top_i.arriav_hd_altpe2_hip_top_encrypted_i.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.rx_typ_fc       ),
                     .rx_vcid_fc          (arriav_hd_altpe2_hip_top.arriav_hd_altpe2_hip_top_i.arriav_hd_altpe2_hip_top_encrypted_i.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.rx_vcid_fc      ),
                     .rx_hdr_fc           (arriav_hd_altpe2_hip_top.arriav_hd_altpe2_hip_top_i.arriav_hd_altpe2_hip_top_encrypted_i.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.rx_hdr_fc       ),
                     .rx_data_fc          (arriav_hd_altpe2_hip_top.arriav_hd_altpe2_hip_top_i.arriav_hd_altpe2_hip_top_encrypted_i.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.rx_data_fc      ),
                     .req_upfc            (arriav_hd_altpe2_hip_top.arriav_hd_altpe2_hip_top_i.arriav_hd_altpe2_hip_top_encrypted_i.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.req_upfc        ),
                     .snd_upfc            (arriav_hd_altpe2_hip_top.arriav_hd_altpe2_hip_top_i.arriav_hd_altpe2_hip_top_encrypted_i.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.snd_upfc        ),
                     .ack_upfc            (arriav_hd_altpe2_hip_top.arriav_hd_altpe2_hip_top_i.arriav_hd_altpe2_hip_top_encrypted_i.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.ack_upfc        ),
                     .ack_snd_upfc        (arriav_hd_altpe2_hip_top.arriav_hd_altpe2_hip_top_i.arriav_hd_altpe2_hip_top_encrypted_i.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.ack_snd_upfc    ),
                     .ack_req_upfc        (arriav_hd_altpe2_hip_top.arriav_hd_altpe2_hip_top_i.arriav_hd_altpe2_hip_top_encrypted_i.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.ack_req_upfc    ),
                     .typ_upfc            (arriav_hd_altpe2_hip_top.arriav_hd_altpe2_hip_top_i.arriav_hd_altpe2_hip_top_encrypted_i.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.typ_upfc  [1:0] ),
                     .vcid_upfc           (arriav_hd_altpe2_hip_top.arriav_hd_altpe2_hip_top_i.arriav_hd_altpe2_hip_top_encrypted_i.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.vcid_upfc [2:0] ),
                     .hdr_upfc            (arriav_hd_altpe2_hip_top.arriav_hd_altpe2_hip_top_i.arriav_hd_altpe2_hip_top_encrypted_i.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.hdr_upfc  [7:0] ),
                     .data_upfc           (arriav_hd_altpe2_hip_top.arriav_hd_altpe2_hip_top_i.arriav_hd_altpe2_hip_top_encrypted_i.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.data_upfc [11:0]));
            // synthesis translate_on
         cyclonev_hd_altpe2_hip_top # (
            .func_mode                                (func_mode),
            .bonding_mode                             (bonding_mode),
            .prot_mode                                (prot_mode),
            .cvp_enable                               (cvp_enable),
            .vc_enable                                (vc_enable),
            .enable_slot_register                     (enable_slot_register),
            .pcie_mode                                (pcie_mode),
            .bypass_cdc                               (bypass_cdc), // Note: A5 only close timing on CDC ENABLED mode. Check rbc
            .enable_rx_reordering                     (enable_rx_reordering),
            .enable_rx_buffer_checking                (enable_rx_buffer_checking),
            .single_rx_detect_data                    (single_rx_detect),
            .use_crc_forwarding                       ((low_str(use_aer_0) == "false") ? "false" : use_crc_forwarding),
            .bypass_tl                                (bypass_tl),
            .gen12_lane_rate_mode                     (gen12_lane_rate_mode),
            .lane_mask                                (lane_mask),
            .disable_link_x2_support                  (disable_link_x2_support),
            .national_inst_thru_enhance               (national_inst_thru_enhance),
            .disable_tag_check                        (disable_tag_check),
            .multi_function                           ((low_str(func_mode) == "enable") ? multi_function : "one_func" ),
            .port_link_number_data                    (port_link_number),
            .device_number_data                       (device_number),
            .bypass_clk_switch                        (bypass_clk_switch),
            .disable_clk_switch                       (disable_clk_switch),
            .core_clk_disable_clk_switch              (core_clk_disable_clk_switch),
            .core_clk_out_sel                         (core_clk_out_sel),
            .core_clk_divider                         (core_clk_divider),
            .core_clk_source                          (core_clk_source),
            .core_clk_sel                             ((low_str(bypass_clk_switch) == "enable") ? "pld_clk" : core_clk_sel),
            .enable_ch0_pclk_out                      (enable_ch0_pclk_out),
            .enable_ch01_pclk_out                     (enable_ch01_pclk_out),
            .pipex1_debug_sel                         (pipex1_debug_sel),
            .pclk_out_sel                             (pclk_out_sel),

            .bridge_66mhzcap                          (bridge_66mhzcap),
            .fastb2bcap                               (fastb2bcap),
            .devseltim                                (devseltim),
            .lattim_ro_data                           (lattim_ro_data   ),
            .lattim                                   (lattim           ),
            .memwrinv                                 ((low_str(func_mode)=="enable") ? "rw" : memwrinv),
            .br_rcb                                   ((low_str(func_mode)=="enable") ? "rw" : br_rcb),
            .rxfreqlk_cnt_en                          (rxfreqlk_cnt_en  ),
            .rxfreqlk_cnt_data                        (rxfreqlk_cnt),
            .enable_adapter_half_rate_mode            (enable_adapter_half_rate_mode),
            .vc0_clk_enable                           (vc0_clk_enable),
            .vc1_clk_enable                           (vc1_clk_enable),
            .register_pipe_signals                    (register_pipe_signals),

            .no_soft_reset_0                          (no_soft_reset),

            //Func0 - Device Identification Registers
            .vendor_id_data_0                         (vendor_id_0),
            .device_id_data_0                         (device_id_0),
            .revision_id_data_0                       (revision_id_0),
            .class_code_data_0                        (class_code_0),
            .subsystem_vendor_id_data_0               (subsystem_vendor_id_0),
            .subsystem_device_id_data_0               (subsystem_device_id_0),
            .intel_id_access_0                        (intel_id_access),

            //Func 0 - BARs
            .bar0_io_space_0                          (bar0_io_space_0),
            .bar0_64bit_mem_space_0                   (bar0_64bit_mem_space_0),
            .bar0_prefetchable_0                      (bar0_prefetchable_0),
            .bar0_size_mask_data_0                    (bar0_size_mask_0),
            .bar1_io_space_0                          (bar1_io_space_0),
            .bar1_64bit_mem_space_0                   (bar1_64bit_mem_space_0),
            .bar1_prefetchable_0                      (bar1_prefetchable_0),
            .bar1_size_mask_data_0                    (bar1_size_mask_0),
            .bar2_io_space_0                          (bar2_io_space_0),
            .bar2_64bit_mem_space_0                   (bar2_64bit_mem_space_0),
            .bar2_prefetchable_0                      (bar2_prefetchable_0),
            .bar2_size_mask_data_0                    (bar2_size_mask_0),
            .bar3_io_space_0                          (bar3_io_space_0),
            .bar3_64bit_mem_space_0                   (bar3_64bit_mem_space_0),
            .bar3_prefetchable_0                      (bar3_prefetchable_0),
            .bar3_size_mask_data_0                    (bar3_size_mask_0),
            .bar4_io_space_0                          (bar4_io_space_0),
            .bar4_64bit_mem_space_0                   (bar4_64bit_mem_space_0),
            .bar4_prefetchable_0                      (bar4_prefetchable_0),
            .bar4_size_mask_data_0                    (bar4_size_mask_0),
            .bar5_io_space_0                          (bar5_io_space_0),
            .bar5_64bit_mem_space_0                   (bar5_64bit_mem_space_0),
            .bar5_prefetchable_0                      (bar5_prefetchable_0),
            .bar5_size_mask_data_0                    (bar5_size_mask_0),

            .device_specific_init_0                   (device_specific_init_0),
            .maximum_current_data_0                   (maximum_current_0),
            .d1_support_0                             (d1_support),
            .d2_support_0                             (d2_support),
            .d0_pme_0                                 (d0_pme),
            .d1_pme_0                                 (d1_pme),
            .d2_pme_0                                 (d2_pme),
            .d3_hot_pme_0                             (d3_hot_pme),
            .d3_cold_pme_0                            (d3_cold_pme),
            .use_aer_0                                (use_aer_0),
            .low_priority_vc_0                        (low_priority_vc),
            .vc_arbitration_0                         (vc_arbitration),
            .disable_snoop_packet_0                   (disable_snoop_packet_0),

            .max_payload_size_0                       (max_payload_size_0),
            .extend_tag_field_0                       (extend_tag_field_0),
            .completion_timeout_0                     (completion_timeout_0),
            .enable_completion_timeout_disable_0      (enable_completion_timeout_disable_0),

            .surprise_down_error_support_0            (surprise_down_error_support_0),
            .dll_active_report_support_0              (dll_active_report_support_0),

            .rx_ei_l0s_0                              (rx_ei_l0s_0),
            .endpoint_l0_latency_data_0               (endpoint_l0_latency_0),
            .endpoint_l1_latency_data_0               (endpoint_l1_latency_0),

            .indicator_data_0                         (indicator),
            .role_based_error_reporting_0             (role_based_error_reporting),
            .max_link_width_0                         (lane_mask),

            .aspm_optionality_0                       (aspm_optionality),
            .enable_l1_aspm_0                         (enable_l1_aspm),
            .enable_l0s_aspm_0                        (enable_l0s_aspm),

            .l1_exit_latency_sameclock_data_0         (l1_exit_latency_sameclock),
            .l1_exit_latency_diffclock_data_0         (l1_exit_latency_diffclock),
            .l0_exit_latency_sameclock_data_0         (l0_exit_latency_sameclock),
            .l0_exit_latency_diffclock_data_0         (l0_exit_latency_diffclock),

            .hot_plug_support_data_0                  (hot_plug_support),

            .slot_power_scale_data_0                  (slot_power_scale_0),
            .slot_power_limit_data_0                  (slot_power_limit_0),
            .slot_number_data_0                       (slot_number_0),

            .diffclock_nfts_count_data_0              (diffclock_nfts_count),
            .sameclock_nfts_count_data_0              (sameclock_nfts_count),

            .ecrc_check_capable_0                     (ecrc_check_capable_0),
            .ecrc_gen_capable_0                       (ecrc_gen_capable_0),
            .no_command_completed_0                   (no_command_completed),

            .msi_multi_message_capable_0              (msi_multi_message_capable_0),
            .msi_64bit_addressing_capable_0           (msi_64bit_addressing_capable_0),
            .msi_masking_capable_0                    (msi_masking_capable_0),
            .msi_support_0                            (msi_support_0),
            .interrupt_pin_0                          (interrupt_pin_0),
            .enable_function_msix_support_0           (enable_function_msix_support_0),
            .msix_table_size_data_0                   (msix_table_size_0),
            .msix_table_bir_data_0                    (msix_table_bir_0),
            .msix_table_offset_data_0                 (msix_table_offset_0),
            .msix_pba_bir_data_0                      (msix_pba_bir_0),
            .msix_pba_offset_data_0                   (msix_pba_offset_0),

            .bridge_port_vga_enable_0                 (bridge_port_vga_enable_0   ),
            .bridge_port_ssid_support_0               (bridge_port_ssid_support_0 ),
            .ssvid_data_0                             (ssvid_0),
            .ssid_data_0                              (ssid_0),
            .eie_before_nfts_count_data_0             (eie_before_nfts_count),
            .gen2_diffclock_nfts_count_data_0         (gen2_diffclock_nfts_count),
            .gen2_sameclock_nfts_count_data_0         (gen2_sameclock_nfts_count),
            .deemphasis_enable_0                      (deemphasis_enable),
            .pcie_spec_version_0                      (pcie_spec_version),
            .l2_async_logic_0                         (l2_async_logic),
            .flr_capability_0                         (flr_capability_0),

            .expansion_base_address_register_data_0   (expansion_base_address_register_0),

            .io_window_addr_width_0                   (io_window_addr_width),
            .prefetchable_mem_window_addr_width_0     (prefetchable_mem_window_addr_width),

            .rx_cdc_almost_full_data                  (rx_cdc_almost_full),
            .tx_cdc_almost_full_data                  (tx_cdc_almost_full),
            .rx_l0s_count_idl_data                    (rx_l0s_count_idl),
            .cdc_dummy_insert_limit_data              (cdc_dummy_insert_limit),
            .ei_delay_powerdown_count_data            (ei_delay_powerdown_count),
            .millisecond_cycle_count_data             (millisecond_cycle_count),
            .skp_os_schedule_count_data               (skp_os_schedule_count),
            .fc_init_timer_data                       (fc_init_timer),
            .l01_entry_latency_data                   (l01_entry_latency),
            .flow_control_update_count_data           (flow_control_update_count),
            .flow_control_timeout_count_data          (flow_control_timeout_count),
            .vc0_rx_flow_ctrl_posted_header_data      (vc0_rx_flow_ctrl_posted_header),
            .vc0_rx_flow_ctrl_posted_data_data        (vc0_rx_flow_ctrl_posted_data),
            .vc0_rx_flow_ctrl_nonposted_header_data   (vc0_rx_flow_ctrl_nonposted_header),
            .vc0_rx_flow_ctrl_nonposted_data_data     (vc0_rx_flow_ctrl_nonposted_data),
            .vc0_rx_flow_ctrl_compl_header_data       (vc0_rx_flow_ctrl_compl_header),
            .vc0_rx_flow_ctrl_compl_data_data         (vc0_rx_flow_ctrl_compl_data),
            .rx_ptr0_posted_dpram_min_data            (rx_ptr0_posted_dpram_min),
            .rx_ptr0_posted_dpram_max_data            (rx_ptr0_posted_dpram_max),
            .rx_ptr0_nonposted_dpram_min_data         (rx_ptr0_nonposted_dpram_min),
            .rx_ptr0_nonposted_dpram_max_data         (rx_ptr0_nonposted_dpram_max),
            .retry_buffer_last_active_address_data    (retry_buffer_last_active_address),
            .retry_buffer_memory_settings_data        (retry_buffer_memory_settings),
            .vc0_rx_buffer_memory_settings_data       (vc0_rx_buffer_memory_settings),
            .bist_memory_settings_data                (bist_memory_settings),
            .credit_buffer_allocation_aux             (credit_buffer_allocation_aux),
            .iei_enable_settings                      (iei_enable_settings),
            .vsec_id_data                             (vsec_id),
            .hard_reset_bypass                        (hard_reset_bypass),
            .cvp_rate_sel                             ((low_str(cvp_enable) == "cvp_en") ? cvp_rate_sel : "full_rate" ),
            .cvp_data_compressed                      ((low_str(cvp_enable) == "cvp_en") ? cvp_data_compressed : "false"),
            .cvp_data_encrypted                       ((low_str(cvp_enable) == "cvp_en") ? cvp_data_encrypted : "false"),
            .cvp_mode_reset                           ((low_str(cvp_enable) == "cvp_en") ? cvp_mode_reset : "false"),
            .cvp_clk_reset                            ((low_str(cvp_enable) == "cvp_en") ? cvp_clk_reset : "false"),
            .cvp_isolation                            ((low_str(cvp_enable) == "cvp_en") ? "disable" : "enable"),
            .vsec_cap_data                            (vsec_cap),
            .jtag_id_data                             (jtag_id),
            .user_id_data                             (user_id),

            .hrdrstctrl_en                            ((USE_HARD_RESET==0)?"hrdrstctrl_dis" : hrdrstctrl_en ),
            .rstctrl_debug_en                         ((USE_HARD_RESET==0)?"false"                 :rstctrl_debug_en                   ),
            .rstctrl_rx_pma_rstb_inv                  ((USE_HARD_RESET==0)?"false"                 :rstctrl_rx_pma_rstb_inv            ),
            .rstctrl_tx_pma_rstb_inv                  ((USE_HARD_RESET==0)?"false"                 :rstctrl_tx_pma_rstb_inv            ),
            .rstctrl_rx_pcs_rst_n_inv                 ((USE_HARD_RESET==0)?"false"                 :rstctrl_rx_pcs_rst_n_inv           ),
            .rstctrl_tx_pcs_rst_n_inv                 ((USE_HARD_RESET==0)?"false"                 :rstctrl_tx_pcs_rst_n_inv           ),
            .rstctrl_altpe2_crst_n_inv                ((USE_HARD_RESET==0)?"false"                 :rstctrl_altpe2_crst_n_inv          ),
            .rstctrl_altpe2_srst_n_inv                ((USE_HARD_RESET==0)?"false"                 :rstctrl_altpe2_srst_n_inv          ),
            .rstctrl_altpe2_rst_n_inv                 ((USE_HARD_RESET==0)?"false"                 :rstctrl_altpe2_rst_n_inv           ),
            .rstctrl_tx_pma_syncp_inv                 ((USE_HARD_RESET==0)?"false"                 :rstctrl_tx_pma_syncp_inv           ),
            .rstctrl_perst_enable                     ((USE_HARD_RESET==0)?"level"                 :rstctrl_perst_enable               ),
            .rstctrl_hard_block_enable                ((USE_HARD_RESET==0)?"pld_rst_ctl"           :rstctrl_hard_block_enable          ),
            .rstctrl_perstn_select                    ((USE_HARD_RESET==0)?"perstn_pin"            :rstctrl_perstn_select              ),
            .rstctrl_hip_ep                           ((USE_HARD_RESET==0)?"hip_not_ep"            :rstctrl_hip_ep                     ),
            .rstctrl_pld_clr                          ((USE_HARD_RESET==0)?"false"                 :rstctrl_pld_clr                    ),
            .rstctrl_force_inactive_rst               ((USE_HARD_RESET==0)?"false"                 :rstctrl_force_inactive_rst         ),
            .rstctrl_timer_a_type                     ((USE_HARD_RESET==0)?"not_enabled"           :rstctrl_timer_a_type               ),
            .rstctrl_timer_a_value                    ((USE_HARD_RESET==0)?8'h1                    :rstctrl_timer_a_value              ),
            .rstctrl_timer_a                          ((USE_HARD_RESET==0)?"rstctrl_timer_a"       :rstctrl_timer_a                    ),
            .rstctrl_timer_b_type                     ((USE_HARD_RESET==0)?"not_enabled"           :rstctrl_timer_b_type               ),
            .rstctrl_timer_b_value                    ((USE_HARD_RESET==0)?8'h1                    :rstctrl_timer_b_value              ),
            .rstctrl_timer_b                          ((USE_HARD_RESET==0)?"rstctrl_timer_b"       :rstctrl_timer_b                    ),
            .rstctrl_timer_c_type                     ((USE_HARD_RESET==0)?"not_enabled"           :rstctrl_timer_c_type               ),
            .rstctrl_timer_c_value                    ((USE_HARD_RESET==0)?8'h1                    :rstctrl_timer_c_value              ),
            .rstctrl_timer_c                          ((USE_HARD_RESET==0)?"rstctrl_timer_c"       :rstctrl_timer_c                    ),
            .rstctrl_timer_d_type                     ((USE_HARD_RESET==0)?"not_enabled"           :rstctrl_timer_d_type               ),
            .rstctrl_timer_d_value                    ((USE_HARD_RESET==0)?8'h1                    :rstctrl_timer_d_value              ),
            .rstctrl_timer_d                          ((USE_HARD_RESET==0)?"rstctrl_timer_d"       :rstctrl_timer_d                    ),
            .rstctrl_timer_e_type                     ((USE_HARD_RESET==0)?"not_enabled"           :rstctrl_timer_e_type               ),
            .rstctrl_timer_e_value                    ((USE_HARD_RESET==0)?8'h1                    :rstctrl_timer_e_value              ),
            .rstctrl_timer_e                          ((USE_HARD_RESET==0)?"rstctrl_timer_e"       :rstctrl_timer_e                    ),
            .rstctrl_timer_f_type                     ((USE_HARD_RESET==0)?"not_enabled"           :rstctrl_timer_f_type               ),
            .rstctrl_timer_f_value                    ((USE_HARD_RESET==0)?8'h1                    :rstctrl_timer_f_value              ),
            .rstctrl_timer_f                          ((USE_HARD_RESET==0)?"rstctrl_timer_f"       :rstctrl_timer_f                    ),
            .rstctrl_timer_g_type                     ((USE_HARD_RESET==0)?"not_enabled"           :rstctrl_timer_g_type               ),
            .rstctrl_timer_g_value                    ((USE_HARD_RESET==0)?8'h1                    :rstctrl_timer_g_value              ),
            .rstctrl_timer_g                          ((USE_HARD_RESET==0)?"rstctrl_timer_g"       :rstctrl_timer_g                    ),
            .rstctrl_timer_h_type                     ((USE_HARD_RESET==0)?"not_enabled"           :rstctrl_timer_h_type               ),
            .rstctrl_timer_h_value                    ((USE_HARD_RESET==0)?8'h1                    :rstctrl_timer_h_value              ),
            .rstctrl_timer_h                          ((USE_HARD_RESET==0)?"rstctrl_timer_h"       :rstctrl_timer_h                    ),
            .rstctrl_timer_i_type                     ((USE_HARD_RESET==0)?"not_enabled"           :rstctrl_timer_i_type               ),
            .rstctrl_timer_i_value                    ((USE_HARD_RESET==0)?8'h1                    :rstctrl_timer_i_value              ),
            .rstctrl_timer_i                          ((USE_HARD_RESET==0)?"rstctrl_timer_i"       :rstctrl_timer_i                    ),
            .rstctrl_timer_j_type                     ((USE_HARD_RESET==0)?"not_enabled"           :rstctrl_timer_j_type               ),
            .rstctrl_timer_j_value                    ((USE_HARD_RESET==0)?8'h1                    :rstctrl_timer_j_value              ),
            .rstctrl_timer_j                          ((USE_HARD_RESET==0)?"rstctrl_timer_j"       :rstctrl_timer_j                    ),
            .rstctrl_1ms_count_fref_clk_value         ((USE_HARD_RESET==0)?20'b00001111010000100100:rstctrl_1ms_count_fref_clk_value   ),
            .rstctrl_1ms_count_fref_clk               ((USE_HARD_RESET==0)?"rstctrl_1ms_cnt"       :rstctrl_1ms_count_fref_clk         ),
            .rstctrl_1us_count_fref_clk_value         ((USE_HARD_RESET==0)?20'b00000000000000111111:rstctrl_1us_count_fref_clk_value   ),
            .rstctrl_1us_count_fref_clk               ((USE_HARD_RESET==0)?"rstctrl_1us_cnt"       :rstctrl_1us_count_fref_clk         ),
            .rstctrl_tx_pcs_rst_n_select              ((USE_HARD_RESET==0)?"not_active"            :rstctrl_tx_pcs_rst_n_select        ),
            .rstctrl_rx_pcs_rst_n_select              ((USE_HARD_RESET==0)?"not_active"            :rstctrl_rx_pcs_rst_n_select        ),
            .rstctrl_rx_pma_rstb_cmu_select           ((USE_HARD_RESET==0)?"not_active"            :rstctrl_rx_pma_rstb_cmu_select     ),
            .rstctrl_rx_pma_rstb_select               ((USE_HARD_RESET==0)?"not_active"            :rstctrl_rx_pma_rstb_select         ),
            .rstctrl_tx_lc_pll_rstb_select            ((USE_HARD_RESET==0)?"not_active"            :rstctrl_tx_lc_pll_rstb_select      ),
            .rstctrl_off_cal_en_select                ((USE_HARD_RESET==0)?"not_active"            :rstctrl_off_cal_en_select          ),
            .rstctrl_fref_clk_select                  ((USE_HARD_RESET==0)?"ch0_sel"               :rstctrl_fref_clk_select            ),
            .rstctrl_off_cal_done_select              ((USE_HARD_RESET==0)?"not_active"            :rstctrl_off_cal_done_select        ),
            .rstctrl_tx_lc_pll_lock_select            ((USE_HARD_RESET==0)?"not_active"            :rstctrl_tx_lc_pll_lock_select      ),
            .rstctrl_tx_cmu_pll_lock_select           ((USE_HARD_RESET==0)?"not_active"            :rstctrl_tx_cmu_pll_lock_select     ),
            .rstctrl_rx_pll_freq_lock_select          ((USE_HARD_RESET==0)?"not_active"            :rstctrl_rx_pll_freq_lock_select    ),
            .rstctrl_rx_pll_lock_select               ((USE_HARD_RESET==0)?"not_active"            :rstctrl_rx_pll_lock_select         ),
            .rstctrl_mask_tx_pll_lock_select          ((USE_HARD_RESET==0)?"not_active"            :rstctrl_mask_tx_pll_lock_select    ),
            .rstctrl_tx_pma_syncp_select              ((USE_HARD_RESET==0)?"not_active"            :rstctrl_tx_pma_syncp_select        ),
            .rstctrl_ltssm_disable                    ((USE_HARD_RESET==0)?"disable"               :rstctrl_ltssm_disable              ),

            .slotclk_cfg                              (slotclk_cfg),
            .skp_insertion_control                    (skp_insertion_control),
            .testmode_control                         ((low_str(func_mode)=="enable") ? testmode_control : "disable"),
            .tx_swing_data                            (tx_swing_data),
            .tx_l0s_adjust                            (tx_l0s_adjust),
            .disable_auto_crs                         (disable_auto_crs),

            .no_soft_reset_1                          (no_soft_reset),

            //Func 1 - Device Identification Registers
            .vendor_id_data_1                         (vendor_id_1),
            .device_id_data_1                         (device_id_1),
            .revision_id_data_1                       (revision_id_1),
            .class_code_data_1                        (class_code_1),
            .subsystem_vendor_id_data_1               (subsystem_vendor_id_1),
            .subsystem_device_id_data_1               (subsystem_device_id_1),
            .intel_id_access_1                        (intel_id_access),
            //Func 1 - BARs
            .bar0_io_space_1                          (bar0_io_space_1),
            .bar0_64bit_mem_space_1                   (bar0_64bit_mem_space_1),
            .bar0_prefetchable_1                      (bar0_prefetchable_1),
            .bar0_size_mask_data_1                    (bar0_size_mask_1),
            .bar1_io_space_1                          (bar1_io_space_1),
            .bar1_64bit_mem_space_1                   (bar1_64bit_mem_space_1),
            .bar1_prefetchable_1                      (bar1_prefetchable_1),
            .bar1_size_mask_data_1                    (bar1_size_mask_1),
            .bar2_io_space_1                          (bar2_io_space_1),
            .bar2_64bit_mem_space_1                   (bar2_64bit_mem_space_1),
            .bar2_prefetchable_1                      (bar2_prefetchable_1),
            .bar2_size_mask_data_1                    (bar2_size_mask_1),
            .bar3_io_space_1                          (bar3_io_space_1),
            .bar3_64bit_mem_space_1                   (bar3_64bit_mem_space_1),
            .bar3_prefetchable_1                      (bar3_prefetchable_1),
            .bar3_size_mask_data_1                    (bar3_size_mask_1),
            .bar4_io_space_1                          (bar4_io_space_1),
            .bar4_64bit_mem_space_1                   (bar4_64bit_mem_space_1),
            .bar4_prefetchable_1                      (bar4_prefetchable_1),
            .bar4_size_mask_data_1                    (bar4_size_mask_1),
            .bar5_io_space_1                          (bar5_io_space_1),
            .bar5_64bit_mem_space_1                   (bar5_64bit_mem_space_1),
            .bar5_prefetchable_1                      (bar5_prefetchable_1),
            .bar5_size_mask_data_1                    (bar5_size_mask_1),

            .device_specific_init_1                   (device_specific_init_1),
            .maximum_current_data_1                   (maximum_current_1),
            .d1_support_1                             (d1_support),
            .d2_support_1                             (d2_support),
            .d0_pme_1                                 (d0_pme),
            .d1_pme_1                                 (d1_pme),
            .d2_pme_1                                 (d2_pme),
            .d3_hot_pme_1                             (d3_hot_pme),
            .d3_cold_pme_1                            (d3_cold_pme),
            .use_aer_1                                (use_aer_1),
            .low_priority_vc_1                        (low_priority_vc_1),
            .vc_arbitration_1                         (vc_arbitration),
            .disable_snoop_packet_1                   (disable_snoop_packet_1),

            .max_payload_size_1                       (max_payload_size_1),
            .extend_tag_field_1                       (extend_tag_field_1),
            .completion_timeout_1                     (completion_timeout_1),
            .enable_completion_timeout_disable_1      (enable_completion_timeout_disable_1),

            .surprise_down_error_support_1            (surprise_down_error_support_1),
            .dll_active_report_support_1              (dll_active_report_support_1),

            .rx_ei_l0s_1                              (rx_ei_l0s_1),
            .endpoint_l0_latency_data_1               (endpoint_l0_latency_1),
            .endpoint_l1_latency_data_1               (endpoint_l1_latency_1),

            .indicator_data_1                         (indicator_1),
            .role_based_error_reporting_1             (role_based_error_reporting),
            .max_link_width_1                         (lane_mask),

            .aspm_optionality_1                       (aspm_optionality),
            .enable_l1_aspm_1                         (enable_l1_aspm),
            .enable_l0s_aspm_1                        (enable_l0s_aspm),

            .l1_exit_latency_sameclock_data_1         (l1_exit_latency_sameclock),
            .l1_exit_latency_diffclock_data_1         (l1_exit_latency_diffclock),
            .l0_exit_latency_sameclock_data_1         (l0_exit_latency_sameclock),
            .l0_exit_latency_diffclock_data_1         (l0_exit_latency_diffclock),

            .hot_plug_support_data_1                  (hot_plug_support_1),

            .slot_power_scale_data_1                  (slot_power_scale_1),
            .slot_power_limit_data_1                  (slot_power_limit_1),
            .slot_number_data_1                       (slot_number_1),

            .diffclock_nfts_count_data_1              (diffclock_nfts_count),
            .sameclock_nfts_count_data_1              (sameclock_nfts_count),

            .ecrc_check_capable_1                     (ecrc_check_capable_1),
            .ecrc_gen_capable_1                       (ecrc_gen_capable_1),

            .no_command_completed_1                   (no_command_completed_1),

            .msi_multi_message_capable_1              (msi_multi_message_capable_1),
            .msi_64bit_addressing_capable_1           (msi_64bit_addressing_capable_1),
            .msi_masking_capable_1                    (msi_masking_capable_1),
            .msi_support_1                            (msi_support_1),
            .interrupt_pin_1                          (interrupt_pin_1),
            .enable_function_msix_support_1           (enable_function_msix_support_1),
            .msix_table_size_data_1                   (msix_table_size_1),
            .msix_table_bir_data_1                    (msix_table_bir_1),
            .msix_table_offset_data_1                 (msix_table_offset_1),
            .msix_pba_bir_data_1                      (msix_pba_bir_1),
            .msix_pba_offset_data_1                   (msix_pba_offset_1),

            .bridge_port_vga_enable_1                 (bridge_port_vga_enable_1   ),
            .bridge_port_ssid_support_1               (bridge_port_ssid_support_1 ),
            .ssvid_data_1                             (ssvid_1),
            .ssid_data_1                              (ssid_1),
            .eie_before_nfts_count_data_1             (eie_before_nfts_count),
            .gen2_diffclock_nfts_count_data_1         (gen2_diffclock_nfts_count),
            .gen2_sameclock_nfts_count_data_1         (gen2_sameclock_nfts_count),
            .deemphasis_enable_1                      (deemphasis_enable),
            .pcie_spec_version_1                      (pcie_spec_version),
            .l2_async_logic_1                         (l2_async_logic),
            .flr_capability_1                         (flr_capability_1),

            .expansion_base_address_register_data_1   (expansion_base_address_register_1),

            .io_window_addr_width_1                   (io_window_addr_width_1),
            .prefetchable_mem_window_addr_width_1     (prefetchable_mem_window_addr_width_1),

            .no_soft_reset_2                          (no_soft_reset),

            //Func2 - Device Identification Registers
            .vendor_id_data_2                         (vendor_id_2),
            .device_id_data_2                         (device_id_2),
            .revision_id_data_2                       (revision_id_2),
            .class_code_data_2                        (class_code_2),
            .subsystem_vendor_id_data_2               (subsystem_vendor_id_2),
            .subsystem_device_id_data_2               (subsystem_device_id_2),
            .intel_id_access_2                        (intel_id_access),
            //Func 2 - BARs
            .bar0_io_space_2                          (bar0_io_space_2),
            .bar0_64bit_mem_space_2                   (bar0_64bit_mem_space_2),
            .bar0_prefetchable_2                      (bar0_prefetchable_2),
            .bar0_size_mask_data_2                    (bar0_size_mask_2),
            .bar1_io_space_2                          (bar1_io_space_2),
            .bar1_64bit_mem_space_2                   (bar1_64bit_mem_space_2),
            .bar1_prefetchable_2                      (bar1_prefetchable_2),
            .bar1_size_mask_data_2                    (bar1_size_mask_2),
            .bar2_io_space_2                          (bar2_io_space_2),
            .bar2_64bit_mem_space_2                   (bar2_64bit_mem_space_2),
            .bar2_prefetchable_2                      (bar2_prefetchable_2),
            .bar2_size_mask_data_2                    (bar2_size_mask_2),
            .bar3_io_space_2                          (bar3_io_space_2),
            .bar3_64bit_mem_space_2                   (bar3_64bit_mem_space_2),
            .bar3_prefetchable_2                      (bar3_prefetchable_2),
            .bar3_size_mask_data_2                    (bar3_size_mask_2),
            .bar4_io_space_2                          (bar4_io_space_2),
            .bar4_64bit_mem_space_2                   (bar4_64bit_mem_space_2),
            .bar4_prefetchable_2                      (bar4_prefetchable_2),
            .bar4_size_mask_data_2                    (bar4_size_mask_2),
            .bar5_io_space_2                          (bar5_io_space_2),
            .bar5_64bit_mem_space_2                   (bar5_64bit_mem_space_2),
            .bar5_prefetchable_2                      (bar5_prefetchable_2),
            .bar5_size_mask_data_2                    (bar5_size_mask_2),

            .device_specific_init_2                   (device_specific_init_2),
            .maximum_current_data_2                   (maximum_current_2),
            .d1_support_2                             (d1_support),
            .d2_support_2                             (d2_support),
            .d0_pme_2                                 (d0_pme),
            .d1_pme_2                                 (d1_pme),
            .d2_pme_2                                 (d2_pme),
            .d3_hot_pme_2                             (d3_hot_pme),
            .d3_cold_pme_2                            (d3_cold_pme),
            .use_aer_2                                (use_aer_2),
            .low_priority_vc_2                        (low_priority_vc_2),
            .vc_arbitration_2                         (vc_arbitration),
            .disable_snoop_packet_2                   (disable_snoop_packet_2),

            .max_payload_size_2                       (max_payload_size_2),
            .extend_tag_field_2                       (extend_tag_field_2),
            .completion_timeout_2                     (completion_timeout_2),
            .enable_completion_timeout_disable_2      (enable_completion_timeout_disable_2),

            .surprise_down_error_support_2            (surprise_down_error_support_2),
            .dll_active_report_support_2              (dll_active_report_support_2),

            .rx_ei_l0s_2                              (rx_ei_l0s_2),
            .endpoint_l0_latency_data_2               (endpoint_l0_latency_2),
            .endpoint_l1_latency_data_2               (endpoint_l1_latency_2),

            .indicator_data_2                         (indicator_2),
            .role_based_error_reporting_2             (role_based_error_reporting),
            .max_link_width_2                         (lane_mask),

            .aspm_optionality_2                       (aspm_optionality),
            .enable_l1_aspm_2                         (enable_l1_aspm),
            .enable_l0s_aspm_2                        (enable_l0s_aspm),

            .l1_exit_latency_sameclock_data_2         (l1_exit_latency_sameclock),
            .l1_exit_latency_diffclock_data_2         (l1_exit_latency_diffclock),
            .l0_exit_latency_sameclock_data_2         (l0_exit_latency_sameclock),
            .l0_exit_latency_diffclock_data_2         (l0_exit_latency_diffclock),

            .hot_plug_support_data_2                  (hot_plug_support_2),

            .slot_power_scale_data_2                  (slot_power_scale_2),
            .slot_power_limit_data_2                  (slot_power_limit_2),
            .slot_number_data_2                       (slot_number_2),

            .diffclock_nfts_count_data_2              (diffclock_nfts_count),
            .sameclock_nfts_count_data_2              (sameclock_nfts_count),

            .ecrc_check_capable_2                     (ecrc_check_capable_2),
            .ecrc_gen_capable_2                       (ecrc_gen_capable_2),

            .no_command_completed_2                   (no_command_completed_2),

            .msi_multi_message_capable_2              (msi_multi_message_capable_2),
            .msi_64bit_addressing_capable_2           (msi_64bit_addressing_capable_2),
            .msi_masking_capable_2                    (msi_masking_capable_2),
            .msi_support_2                            (msi_support_2),
            .interrupt_pin_2                          (interrupt_pin_2),
            .enable_function_msix_support_2           (enable_function_msix_support_2),
            .msix_table_size_data_2                   (msix_table_size_2),
            .msix_table_bir_data_2                    (msix_table_bir_2),
            .msix_table_offset_data_2                 (msix_table_offset_2),
            .msix_pba_bir_data_2                      (msix_pba_bir_2),
            .msix_pba_offset_data_2                   (msix_pba_offset_2),

            .bridge_port_vga_enable_2                 (bridge_port_vga_enable_2),
            .bridge_port_ssid_support_2               (bridge_port_ssid_support_2),
            .ssvid_data_2                             (ssvid_2),
            .ssid_data_2                              (ssid_2),
            .eie_before_nfts_count_data_2             (eie_before_nfts_count),
            .gen2_diffclock_nfts_count_data_2         (gen2_diffclock_nfts_count),
            .gen2_sameclock_nfts_count_data_2         (gen2_sameclock_nfts_count),
            .deemphasis_enable_2                      (deemphasis_enable),
            .pcie_spec_version_2                      (pcie_spec_version),
            .l2_async_logic_2                         (l2_async_logic),
            .flr_capability_2                         (flr_capability_2),

            .expansion_base_address_register_data_2   (expansion_base_address_register_2),

            .io_window_addr_width_2                   (io_window_addr_width_2),
            .prefetchable_mem_window_addr_width_2     (prefetchable_mem_window_addr_width_2),

            .no_soft_reset_3                          (no_soft_reset),

            //Func3 - Device Identification Registers
            .vendor_id_data_3                         (vendor_id_3),
            .device_id_data_3                         (device_id_3),
            .revision_id_data_3                       (revision_id_3),
            .class_code_data_3                        (class_code_3),
            .subsystem_vendor_id_data_3               (subsystem_vendor_id_3),
            .subsystem_device_id_data_3               (subsystem_device_id_3),
            .intel_id_access_3                        (intel_id_access),
            //Func 3 - BARs
            .bar0_io_space_3                          (bar0_io_space_3),
            .bar0_64bit_mem_space_3                   (bar0_64bit_mem_space_3),
            .bar0_prefetchable_3                      (bar0_prefetchable_3),
            .bar0_size_mask_data_3                    (bar0_size_mask_3),
            .bar1_io_space_3                          (bar1_io_space_3),
            .bar1_64bit_mem_space_3                   (bar1_64bit_mem_space_3),
            .bar1_prefetchable_3                      (bar1_prefetchable_3),
            .bar1_size_mask_data_3                    (bar1_size_mask_3),
            .bar2_io_space_3                          (bar2_io_space_3),
            .bar2_64bit_mem_space_3                   (bar2_64bit_mem_space_3),
            .bar2_prefetchable_3                      (bar2_prefetchable_3),
            .bar2_size_mask_data_3                    (bar2_size_mask_3),
            .bar3_io_space_3                          (bar3_io_space_3),
            .bar3_64bit_mem_space_3                   (bar3_64bit_mem_space_3),
            .bar3_prefetchable_3                      (bar3_prefetchable_3),
            .bar3_size_mask_data_3                    (bar3_size_mask_3),
            .bar4_io_space_3                          (bar4_io_space_3),
            .bar4_64bit_mem_space_3                   (bar4_64bit_mem_space_3),
            .bar4_prefetchable_3                      (bar4_prefetchable_3),
            .bar4_size_mask_data_3                    (bar4_size_mask_3),
            .bar5_io_space_3                          (bar5_io_space_3),
            .bar5_64bit_mem_space_3                   (bar5_64bit_mem_space_3),
            .bar5_prefetchable_3                      (bar5_prefetchable_3),
            .bar5_size_mask_data_3                    (bar5_size_mask_3),


            .device_specific_init_3                   (device_specific_init_3),
            .maximum_current_data_3                   (maximum_current_3),
            .d1_support_3                             (d1_support),
            .d2_support_3                             (d2_support),
            .d0_pme_3                                 (d0_pme),
            .d1_pme_3                                 (d1_pme),
            .d2_pme_3                                 (d2_pme),
            .d3_hot_pme_3                             (d3_hot_pme),
            .d3_cold_pme_3                            (d3_cold_pme),
            .use_aer_3                                (use_aer_3),
            .low_priority_vc_3                        (low_priority_vc_3),
            .vc_arbitration_3                         (vc_arbitration),
            .disable_snoop_packet_3                   (disable_snoop_packet_3),

            .max_payload_size_3                       (max_payload_size_3),
            .extend_tag_field_3                       (extend_tag_field_3),
            .completion_timeout_3                     (completion_timeout_3),
            .enable_completion_timeout_disable_3      (enable_completion_timeout_disable_3),

            .surprise_down_error_support_3            (surprise_down_error_support_3),
            .dll_active_report_support_3              (dll_active_report_support_3),

            .rx_ei_l0s_3                              (rx_ei_l0s_3),
            .endpoint_l0_latency_data_3               (endpoint_l0_latency_3),
            .endpoint_l1_latency_data_3               (endpoint_l1_latency_3),

            .indicator_data_3                         (indicator_3),
            .role_based_error_reporting_3             (role_based_error_reporting),
            .max_link_width_3                         (lane_mask),

            .aspm_optionality_3                       (aspm_optionality),
            .enable_l1_aspm_3                         (enable_l1_aspm),
            .enable_l0s_aspm_3                        (enable_l0s_aspm),

            .l1_exit_latency_sameclock_data_3         (l1_exit_latency_sameclock),
            .l1_exit_latency_diffclock_data_3         (l1_exit_latency_diffclock),
            .l0_exit_latency_sameclock_data_3         (l0_exit_latency_sameclock),
            .l0_exit_latency_diffclock_data_3         (l0_exit_latency_diffclock),

            .hot_plug_support_data_3                  (hot_plug_support_3),

            .slot_power_scale_data_3                  (slot_power_scale_3),
            .slot_power_limit_data_3                  (slot_power_limit_3),
            .slot_number_data_3                       (slot_number_3),

            .diffclock_nfts_count_data_3              (diffclock_nfts_count),
            .sameclock_nfts_count_data_3              (sameclock_nfts_count),

            .ecrc_check_capable_3                     (ecrc_check_capable_3),
            .ecrc_gen_capable_3                       (ecrc_gen_capable_3),

            .no_command_completed_3                   (no_command_completed_3),

            .msi_multi_message_capable_3              (msi_multi_message_capable_3),
            .msi_64bit_addressing_capable_3           (msi_64bit_addressing_capable_3),
            .msi_masking_capable_3                    (msi_masking_capable_3),
            .msi_support_3                            (msi_support_3),
            .interrupt_pin_3                          (interrupt_pin_3),
            .enable_function_msix_support_3           (enable_function_msix_support_3),
            .msix_table_size_data_3                   (msix_table_size_3),
            .msix_table_bir_data_3                    (msix_table_bir_3),
            .msix_table_offset_data_3                 (msix_table_offset_3),
            .msix_pba_bir_data_3                      (msix_pba_bir_3),
            .msix_pba_offset_data_3                   (msix_pba_offset_3),

            .bridge_port_vga_enable_3                 (bridge_port_vga_enable_3),
            .bridge_port_ssid_support_3               (bridge_port_ssid_support_3),
            .ssvid_data_3                             (ssvid_3),
            .ssid_data_3                              (ssid_3),
            .eie_before_nfts_count_data_3             (eie_before_nfts_count),
            .gen2_diffclock_nfts_count_data_3         (gen2_diffclock_nfts_count),
            .gen2_sameclock_nfts_count_data_3         (gen2_sameclock_nfts_count),
            .deemphasis_enable_3                      (deemphasis_enable),
            .pcie_spec_version_3                      (pcie_spec_version),
            .l2_async_logic_3                         (l2_async_logic),
            .flr_capability_3                         (flr_capability_3),

            .expansion_base_address_register_data_3   (expansion_base_address_register_3),

            .io_window_addr_width_3                   (io_window_addr_width_3),
            .prefetchable_mem_window_addr_width_3     (prefetchable_mem_window_addr_width_3),


            .no_soft_reset_4                          (no_soft_reset),

            //Func4 - Device Identification Registers
            .vendor_id_data_4                         (vendor_id_4),
            .device_id_data_4                         (device_id_4),
            .revision_id_data_4                       (revision_id_4),
            .class_code_data_4                        (class_code_4),
            .subsystem_vendor_id_data_4               (subsystem_vendor_id_4),
            .subsystem_device_id_data_4               (subsystem_device_id_4),
            .intel_id_access_4                        (intel_id_access),
            //Func 4 - BARs
            .bar0_io_space_4                          (bar0_io_space_4),
            .bar0_64bit_mem_space_4                   (bar0_64bit_mem_space_4),
            .bar0_prefetchable_4                      (bar0_prefetchable_4),
            .bar0_size_mask_data_4                    (bar0_size_mask_4),
            .bar1_io_space_4                          (bar1_io_space_4),
            .bar1_64bit_mem_space_4                   (bar1_64bit_mem_space_4),
            .bar1_prefetchable_4                      (bar1_prefetchable_4),
            .bar1_size_mask_data_4                    (bar1_size_mask_4),
            .bar2_io_space_4                          (bar2_io_space_4),
            .bar2_64bit_mem_space_4                   (bar2_64bit_mem_space_4),
            .bar2_prefetchable_4                      (bar2_prefetchable_4),
            .bar2_size_mask_data_4                    (bar2_size_mask_4),
            .bar3_io_space_4                          (bar3_io_space_4),
            .bar3_64bit_mem_space_4                   (bar3_64bit_mem_space_4),
            .bar3_prefetchable_4                      (bar3_prefetchable_4),
            .bar3_size_mask_data_4                    (bar3_size_mask_4),
            .bar4_io_space_4                          (bar4_io_space_4),
            .bar4_64bit_mem_space_4                   (bar4_64bit_mem_space_4),
            .bar4_prefetchable_4                      (bar4_prefetchable_4),
            .bar4_size_mask_data_4                    (bar4_size_mask_4),
            .bar5_io_space_4                          (bar5_io_space_4),
            .bar5_64bit_mem_space_4                   (bar5_64bit_mem_space_4),
            .bar5_prefetchable_4                      (bar5_prefetchable_4),
            .bar5_size_mask_data_4                    (bar5_size_mask_4),

            .device_specific_init_4                   (device_specific_init_4),
            .maximum_current_data_4                   (maximum_current_4),
            .d1_support_4                             (d1_support),
            .d2_support_4                             (d2_support),
            .d0_pme_4                                 (d0_pme),
            .d1_pme_4                                 (d1_pme),
            .d2_pme_4                                 (d2_pme),
            .d3_hot_pme_4                             (d3_hot_pme),
            .d3_cold_pme_4                            (d3_cold_pme),
            .use_aer_4                                (use_aer_4),
            .low_priority_vc_4                        (low_priority_vc_4),
            .vc_arbitration_4                         (vc_arbitration),
            .disable_snoop_packet_4                   (disable_snoop_packet_4),

            .max_payload_size_4                       (max_payload_size_4),
            .extend_tag_field_4                       (extend_tag_field_4),
            .completion_timeout_4                     (completion_timeout_4),
            .enable_completion_timeout_disable_4      (enable_completion_timeout_disable_4),

            .surprise_down_error_support_4            (surprise_down_error_support_4),
            .dll_active_report_support_4              (dll_active_report_support_4),

            .rx_ei_l0s_4                              (rx_ei_l0s_4),
            .endpoint_l0_latency_data_4               (endpoint_l0_latency_4),
            .endpoint_l1_latency_data_4               (endpoint_l1_latency_4),

            .indicator_data_4                         (indicator_4),
            .role_based_error_reporting_4             (role_based_error_reporting),
            .max_link_width_4                         (lane_mask),

            .aspm_optionality_4                       (aspm_optionality),
            .enable_l1_aspm_4                         (enable_l1_aspm),
            .enable_l0s_aspm_4                        (enable_l0s_aspm),

            .l1_exit_latency_sameclock_data_4         (l1_exit_latency_sameclock),
            .l1_exit_latency_diffclock_data_4         (l1_exit_latency_diffclock),
            .l0_exit_latency_sameclock_data_4         (l0_exit_latency_sameclock),
            .l0_exit_latency_diffclock_data_4         (l0_exit_latency_diffclock),

            .hot_plug_support_data_4                  (hot_plug_support_4),

            .slot_power_scale_data_4                  (slot_power_scale_4),
            .slot_power_limit_data_4                  (slot_power_limit_4),
            .slot_number_data_4                       (slot_number_4),

            .diffclock_nfts_count_data_4              (diffclock_nfts_count),
            .sameclock_nfts_count_data_4              (sameclock_nfts_count),

            .ecrc_check_capable_4                     (ecrc_check_capable_4),
            .ecrc_gen_capable_4                       (ecrc_gen_capable_4),

            .no_command_completed_4                   (no_command_completed_4),

            .msi_multi_message_capable_4              (msi_multi_message_capable_4),
            .msi_64bit_addressing_capable_4           (msi_64bit_addressing_capable_4),
            .msi_masking_capable_4                    (msi_masking_capable_4),
            .msi_support_4                            (msi_support_4),
            .interrupt_pin_4                          (interrupt_pin_4),
            .enable_function_msix_support_4           (enable_function_msix_support_4),
            .msix_table_size_data_4                   (msix_table_size_4),
            .msix_table_bir_data_4                    (msix_table_bir_4),
            .msix_table_offset_data_4                 (msix_table_offset_4),
            .msix_pba_bir_data_4                      (msix_pba_bir_4),
            .msix_pba_offset_data_4                   (msix_pba_offset_4),

            .bridge_port_vga_enable_4                 (bridge_port_vga_enable_4),
            .bridge_port_ssid_support_4               (bridge_port_ssid_support_4),
            .ssvid_data_4                             (ssvid_4),
            .ssid_data_4                              (ssid_4),
            .eie_before_nfts_count_data_4             (eie_before_nfts_count),
            .gen2_diffclock_nfts_count_data_4         (gen2_diffclock_nfts_count),
            .gen2_sameclock_nfts_count_data_4         (gen2_sameclock_nfts_count),
            .deemphasis_enable_4                      (deemphasis_enable),
            .pcie_spec_version_4                      (pcie_spec_version),
            .l2_async_logic_4                         (l2_async_logic),
            .flr_capability_4                         (flr_capability_4),

            .expansion_base_address_register_data_4   (expansion_base_address_register_4),

            .io_window_addr_width_4                   (io_window_addr_width_4),
            .prefetchable_mem_window_addr_width_4     (prefetchable_mem_window_addr_width_4),

            .no_soft_reset_5                          (no_soft_reset),

            //Func 5 - Device Identification Registers
            .vendor_id_data_5                         (vendor_id_5),
            .device_id_data_5                         (device_id_5),
            .revision_id_data_5                       (revision_id_5),
            .class_code_data_5                        (class_code_5),
            .subsystem_vendor_id_data_5               (subsystem_vendor_id_5),
            .subsystem_device_id_data_5               (subsystem_device_id_5),
            .intel_id_access_5                        (intel_id_access),
            //Func 5 - BARs
            .bar0_io_space_5                          (bar0_io_space_5),
            .bar0_64bit_mem_space_5                   (bar0_64bit_mem_space_5),
            .bar0_prefetchable_5                      (bar0_prefetchable_5),
            .bar0_size_mask_data_5                    (bar0_size_mask_5),
            .bar1_io_space_5                          (bar1_io_space_5),
            .bar1_64bit_mem_space_5                   (bar1_64bit_mem_space_5),
            .bar1_prefetchable_5                      (bar1_prefetchable_5),
            .bar1_size_mask_data_5                    (bar1_size_mask_5),
            .bar2_io_space_5                          (bar2_io_space_5),
            .bar2_64bit_mem_space_5                   (bar2_64bit_mem_space_5),
            .bar2_prefetchable_5                      (bar2_prefetchable_5),
            .bar2_size_mask_data_5                    (bar2_size_mask_5),
            .bar3_io_space_5                          (bar3_io_space_5),
            .bar3_64bit_mem_space_5                   (bar3_64bit_mem_space_5),
            .bar3_prefetchable_5                      (bar3_prefetchable_5),
            .bar3_size_mask_data_5                    (bar3_size_mask_5),
            .bar4_io_space_5                          (bar4_io_space_5),
            .bar4_64bit_mem_space_5                   (bar4_64bit_mem_space_5),
            .bar4_prefetchable_5                      (bar4_prefetchable_5),
            .bar4_size_mask_data_5                    (bar4_size_mask_5),
            .bar5_io_space_5                          (bar5_io_space_5),
            .bar5_64bit_mem_space_5                   (bar5_64bit_mem_space_5),
            .bar5_prefetchable_5                      (bar5_prefetchable_5),
            .bar5_size_mask_data_5                    (bar5_size_mask_5),

            .device_specific_init_5                   (device_specific_init_5),
            .maximum_current_data_5                   (maximum_current_5),
            .d1_support_5                             (d1_support),
            .d2_support_5                             (d2_support),
            .d0_pme_5                                 (d0_pme),
            .d1_pme_5                                 (d1_pme),
            .d2_pme_5                                 (d2_pme),
            .d3_hot_pme_5                             (d3_hot_pme),
            .d3_cold_pme_5                            (d3_cold_pme),
            .use_aer_5                                (use_aer_5),
            .low_priority_vc_5                        (low_priority_vc_5),
            .vc_arbitration_5                         (vc_arbitration),
            .disable_snoop_packet_5                   (disable_snoop_packet_5),

            .max_payload_size_5                       (max_payload_size_5),
            .extend_tag_field_5                       (extend_tag_field_5),
            .completion_timeout_5                     (completion_timeout_5),
            .enable_completion_timeout_disable_5      (enable_completion_timeout_disable_5),

            .surprise_down_error_support_5            (surprise_down_error_support_5),
            .dll_active_report_support_5              (dll_active_report_support_5),

            .rx_ei_l0s_5                              (rx_ei_l0s_5),
            .endpoint_l0_latency_data_5               (endpoint_l0_latency_5),
            .endpoint_l1_latency_data_5               (endpoint_l1_latency_5),

            .indicator_data_5                         (indicator_5),
            .role_based_error_reporting_5             (role_based_error_reporting),
            .max_link_width_5                         (lane_mask),

            .aspm_optionality_5                       (aspm_optionality),
            .enable_l1_aspm_5                         (enable_l1_aspm),
            .enable_l0s_aspm_5                        (enable_l0s_aspm),

            .l1_exit_latency_sameclock_data_5         (l1_exit_latency_sameclock),
            .l1_exit_latency_diffclock_data_5         (l1_exit_latency_diffclock),
            .l0_exit_latency_sameclock_data_5         (l0_exit_latency_sameclock),
            .l0_exit_latency_diffclock_data_5         (l0_exit_latency_diffclock),

            .hot_plug_support_data_5                  (hot_plug_support_5),

            .slot_power_scale_data_5                  (slot_power_scale_5),
            .slot_power_limit_data_5                  (slot_power_limit_5),
            .slot_number_data_5                       (slot_number_5),

            .diffclock_nfts_count_data_5              (diffclock_nfts_count),
            .sameclock_nfts_count_data_5              (sameclock_nfts_count),

            .ecrc_check_capable_5                     (ecrc_check_capable_5),
            .ecrc_gen_capable_5                       (ecrc_gen_capable_5),

            .no_command_completed_5                   (no_command_completed_5),

            .msi_multi_message_capable_5              (msi_multi_message_capable_5),
            .msi_64bit_addressing_capable_5           (msi_64bit_addressing_capable_5),
            .msi_masking_capable_5                    (msi_masking_capable_5),
            .msi_support_5                            (msi_support_5),
            .interrupt_pin_5                          (interrupt_pin_5),
            .enable_function_msix_support_5           (enable_function_msix_support_5),
            .msix_table_size_data_5                   (msix_table_size_5),
            .msix_table_bir_data_5                    (msix_table_bir_5),
            .msix_table_offset_data_5                 (msix_table_offset_5),
            .msix_pba_bir_data_5                      (msix_pba_bir_5),
            .msix_pba_offset_data_5                   (msix_pba_offset_5),

            .bridge_port_vga_enable_5                 (bridge_port_vga_enable_5),
            .bridge_port_ssid_support_5               (bridge_port_ssid_support_5),
            .ssvid_data_5                             (ssvid_5),
            .ssid_data_5                              (ssid_5),
            .eie_before_nfts_count_data_5             (eie_before_nfts_count),
            .gen2_diffclock_nfts_count_data_5         (gen2_diffclock_nfts_count),
            .gen2_sameclock_nfts_count_data_5         (gen2_sameclock_nfts_count),
            .deemphasis_enable_5                      (deemphasis_enable),
            .pcie_spec_version_5                      (pcie_spec_version),
            .l2_async_logic_5                         (l2_async_logic),
            .flr_capability_5                         (flr_capability_5),

            .expansion_base_address_register_data_5   (expansion_base_address_register_5),

            .io_window_addr_width_5                   (io_window_addr_width_5),
            .prefetchable_mem_window_addr_width_5     (prefetchable_mem_window_addr_width_5),

            .no_soft_reset_6                          (no_soft_reset),

            //Func6 - Device Identification Registers
            .vendor_id_data_6                         (vendor_id_6),
            .device_id_data_6                         (device_id_6),
            .revision_id_data_6                       (revision_id_6),
            .class_code_data_6                        (class_code_6),
            .subsystem_vendor_id_data_6               (subsystem_vendor_id_6),
            .subsystem_device_id_data_6               (subsystem_device_id_6),
            .intel_id_access_6                        (intel_id_access),
            //Func 6 - BARs
            .bar0_io_space_6                          (bar0_io_space_6),
            .bar0_64bit_mem_space_6                   (bar0_64bit_mem_space_6),
            .bar0_prefetchable_6                      (bar0_prefetchable_6),
            .bar0_size_mask_data_6                    (bar0_size_mask_6),
            .bar1_io_space_6                          (bar1_io_space_6),
            .bar1_64bit_mem_space_6                   (bar1_64bit_mem_space_6),
            .bar1_prefetchable_6                      (bar1_prefetchable_6),
            .bar1_size_mask_data_6                    (bar1_size_mask_6),
            .bar2_io_space_6                          (bar2_io_space_6),
            .bar2_64bit_mem_space_6                   (bar2_64bit_mem_space_6),
            .bar2_prefetchable_6                      (bar2_prefetchable_6),
            .bar2_size_mask_data_6                    (bar2_size_mask_6),
            .bar3_io_space_6                          (bar3_io_space_6),
            .bar3_64bit_mem_space_6                   (bar3_64bit_mem_space_6),
            .bar3_prefetchable_6                      (bar3_prefetchable_6),
            .bar3_size_mask_data_6                    (bar3_size_mask_6),
            .bar4_io_space_6                          (bar4_io_space_6),
            .bar4_64bit_mem_space_6                   (bar4_64bit_mem_space_6),
            .bar4_prefetchable_6                      (bar4_prefetchable_6),
            .bar4_size_mask_data_6                    (bar4_size_mask_6),
            .bar5_io_space_6                          (bar5_io_space_6),
            .bar5_64bit_mem_space_6                   (bar5_64bit_mem_space_6),
            .bar5_prefetchable_6                      (bar5_prefetchable_6),
            .bar5_size_mask_data_6                    (bar5_size_mask_6),

            .device_specific_init_6                   (device_specific_init_6),
            .maximum_current_data_6                   (maximum_current_6),
            .d1_support_6                             (d1_support),
            .d2_support_6                             (d2_support),
            .d0_pme_6                                 (d0_pme),
            .d1_pme_6                                 (d1_pme),
            .d2_pme_6                                 (d2_pme),
            .d3_hot_pme_6                             (d3_hot_pme),
            .d3_cold_pme_6                            (d3_cold_pme),
            .use_aer_6                                (use_aer_6),
            .low_priority_vc_6                        (low_priority_vc_6),
            .vc_arbitration_6                         (vc_arbitration),
            .disable_snoop_packet_6                   (disable_snoop_packet_6),

            .max_payload_size_6                       (max_payload_size_6),
            .extend_tag_field_6                       (extend_tag_field_6),
            .completion_timeout_6                     (completion_timeout_6),
            .enable_completion_timeout_disable_6      (enable_completion_timeout_disable_6),

            .surprise_down_error_support_6            (surprise_down_error_support_6),
            .dll_active_report_support_6              (dll_active_report_support_6),

            .rx_ei_l0s_6                              (rx_ei_l0s_6),
            .endpoint_l0_latency_data_6               (endpoint_l0_latency_6),
            .endpoint_l1_latency_data_6               (endpoint_l1_latency_6),

            .indicator_data_6                         (indicator_6),
            .role_based_error_reporting_6             (role_based_error_reporting),
            .max_link_width_6                         (lane_mask),

            .aspm_optionality_6                       (aspm_optionality),
            .enable_l1_aspm_6                         (enable_l1_aspm),
            .enable_l0s_aspm_6                        (enable_l0s_aspm),

            .l1_exit_latency_sameclock_data_6         (l1_exit_latency_sameclock),
            .l1_exit_latency_diffclock_data_6         (l1_exit_latency_diffclock),
            .l0_exit_latency_sameclock_data_6         (l0_exit_latency_sameclock),
            .l0_exit_latency_diffclock_data_6         (l0_exit_latency_diffclock),

            .hot_plug_support_data_6                  (hot_plug_support_6),

            .slot_power_scale_data_6                  (slot_power_scale_6),
            .slot_power_limit_data_6                  (slot_power_limit_6),
            .slot_number_data_6                       (slot_number_6),

            .diffclock_nfts_count_data_6              (diffclock_nfts_count),
            .sameclock_nfts_count_data_6              (sameclock_nfts_count),

            .ecrc_check_capable_6                     (ecrc_check_capable_6),
            .ecrc_gen_capable_6                       (ecrc_gen_capable_6),

            .no_command_completed_6                   (no_command_completed_6),

            .msi_multi_message_capable_6              (msi_multi_message_capable_6),
            .msi_64bit_addressing_capable_6           (msi_64bit_addressing_capable_6),
            .msi_masking_capable_6                    (msi_masking_capable_6),
            .msi_support_6                            (msi_support_6),
            .interrupt_pin_6                          (interrupt_pin_6),
            .enable_function_msix_support_6           (enable_function_msix_support_6),
            .msix_table_size_data_6                   (msix_table_size_6),
            .msix_table_bir_data_6                    (msix_table_bir_6),
            .msix_table_offset_data_6                 (msix_table_offset_6),
            .msix_pba_bir_data_6                      (msix_pba_bir_6),
            .msix_pba_offset_data_6                   (msix_pba_offset_6),

            .bridge_port_vga_enable_6                 (bridge_port_vga_enable_6),
            .bridge_port_ssid_support_6               (bridge_port_ssid_support_6),
            .ssvid_data_6                             (ssvid_6),
            .ssid_data_6                              (ssid_6),
            .eie_before_nfts_count_data_6             (eie_before_nfts_count),
            .gen2_diffclock_nfts_count_data_6         (gen2_diffclock_nfts_count),
            .gen2_sameclock_nfts_count_data_6         (gen2_sameclock_nfts_count),
            .deemphasis_enable_6                      (deemphasis_enable),
            .pcie_spec_version_6                      (pcie_spec_version),
            .l2_async_logic_6                         (l2_async_logic),
            .flr_capability_6                         (flr_capability_6),

            .expansion_base_address_register_data_6   (expansion_base_address_register_6),

            .io_window_addr_width_6                   (io_window_addr_width_6),
            .prefetchable_mem_window_addr_width_6     (prefetchable_mem_window_addr_width_6),

            .no_soft_reset_7                          (no_soft_reset),

            //Func7 - Device Identification Registers
            .vendor_id_data_7                         (vendor_id_7),
            .device_id_data_7                         (device_id_7),
            .revision_id_data_7                       (revision_id_7),
            .class_code_data_7                        (class_code_7),
            .subsystem_vendor_id_data_7               (subsystem_vendor_id_7),
            .subsystem_device_id_data_7               (subsystem_device_id_7),
            .intel_id_access_7                        (intel_id_access),
            //Func 7 - BARs
            .bar0_io_space_7                          (bar0_io_space_7),
            .bar0_64bit_mem_space_7                   (bar0_64bit_mem_space_7),
            .bar0_prefetchable_7                      (bar0_prefetchable_7),
            .bar0_size_mask_data_7                    (bar0_size_mask_7),
            .bar1_io_space_7                          (bar1_io_space_7),
            .bar1_64bit_mem_space_7                   (bar1_64bit_mem_space_7),
            .bar1_prefetchable_7                      (bar1_prefetchable_7),
            .bar1_size_mask_data_7                    (bar1_size_mask_7),
            .bar2_io_space_7                          (bar2_io_space_7),
            .bar2_64bit_mem_space_7                   (bar2_64bit_mem_space_7),
            .bar2_prefetchable_7                      (bar2_prefetchable_7),
            .bar2_size_mask_data_7                    (bar2_size_mask_7),
            .bar3_io_space_7                          (bar3_io_space_7),
            .bar3_64bit_mem_space_7                   (bar3_64bit_mem_space_7),
            .bar3_prefetchable_7                      (bar3_prefetchable_7),
            .bar3_size_mask_data_7                    (bar3_size_mask_7),
            .bar4_io_space_7                          (bar4_io_space_7),
            .bar4_64bit_mem_space_7                   (bar4_64bit_mem_space_7),
            .bar4_prefetchable_7                      (bar4_prefetchable_7),
            .bar4_size_mask_data_7                    (bar4_size_mask_7),
            .bar5_io_space_7                          (bar5_io_space_7),
            .bar5_64bit_mem_space_7                   (bar5_64bit_mem_space_7),
            .bar5_prefetchable_7                      (bar5_prefetchable_7),
            .bar5_size_mask_data_7                    (bar5_size_mask_7),

            .device_specific_init_7                   (device_specific_init_7),
            .maximum_current_data_7                   (maximum_current_7),
            .d1_support_7                             (d1_support),
            .d2_support_7                             (d2_support),
            .d0_pme_7                                 (d0_pme),
            .d1_pme_7                                 (d1_pme),
            .d2_pme_7                                 (d2_pme),
            .d3_hot_pme_7                             (d3_hot_pme),
            .d3_cold_pme_7                            (d3_cold_pme),
            .use_aer_7                                (use_aer_7),
            .low_priority_vc_7                        (low_priority_vc_7),
            .vc_arbitration_7                         (vc_arbitration),
            .disable_snoop_packet_7                   (disable_snoop_packet_7),

            .max_payload_size_7                       (max_payload_size_7),
            .extend_tag_field_7                       (extend_tag_field_7),
            .completion_timeout_7                     (completion_timeout_7),
            .enable_completion_timeout_disable_7      (enable_completion_timeout_disable_7),

            .surprise_down_error_support_7            (surprise_down_error_support_7),
            .dll_active_report_support_7              (dll_active_report_support_7),

            .rx_ei_l0s_7                              (rx_ei_l0s_7),
            .endpoint_l0_latency_data_7               (endpoint_l0_latency_7),
            .endpoint_l1_latency_data_7               (endpoint_l1_latency_7),

            .indicator_data_7                         (indicator_7),
            .role_based_error_reporting_7             (role_based_error_reporting),
            .max_link_width_7                         (lane_mask),

            .aspm_optionality_7                       (aspm_optionality),
            .enable_l1_aspm_7                         (enable_l1_aspm),
            .enable_l0s_aspm_7                        (enable_l0s_aspm),

            .l1_exit_latency_sameclock_data_7         (l1_exit_latency_sameclock),
            .l1_exit_latency_diffclock_data_7         (l1_exit_latency_diffclock),
            .l0_exit_latency_sameclock_data_7         (l0_exit_latency_sameclock),
            .l0_exit_latency_diffclock_data_7         (l0_exit_latency_diffclock),

            .hot_plug_support_data_7                  (hot_plug_support_7),

            .slot_power_scale_data_7                  (slot_power_scale_7),
            .slot_power_limit_data_7                  (slot_power_limit_7),
            .slot_number_data_7                       (slot_number_7),

            .diffclock_nfts_count_data_7              (diffclock_nfts_count),
            .sameclock_nfts_count_data_7              (sameclock_nfts_count),

            .ecrc_check_capable_7                     (ecrc_check_capable_7),
            .ecrc_gen_capable_7                       (ecrc_gen_capable_7),

            .no_command_completed_7                   (no_command_completed_7),

            .msi_multi_message_capable_7              (msi_multi_message_capable_7),
            .msi_64bit_addressing_capable_7           (msi_64bit_addressing_capable_7),
            .msi_masking_capable_7                    (msi_masking_capable_7),
            .msi_support_7                            (msi_support_7),
            .interrupt_pin_7                          (interrupt_pin_7),
            .enable_function_msix_support_7           (enable_function_msix_support_7),
            .msix_table_size_data_7                   (msix_table_size_7),
            .msix_table_bir_data_7                    (msix_table_bir_7),
            .msix_table_offset_data_7                 (msix_table_offset_7),
            .msix_pba_bir_data_7                      (msix_pba_bir_7),
            .msix_pba_offset_data_7                   (msix_pba_offset_7),

            .bridge_port_vga_enable_7                 (bridge_port_vga_enable_7),
            .bridge_port_ssid_support_7               (bridge_port_ssid_support_7),
            .ssvid_data_7                             (ssvid_7),
            .ssid_data_7                              (ssid_7),
            .eie_before_nfts_count_data_7             (eie_before_nfts_count),
            .gen2_diffclock_nfts_count_data_7         (gen2_diffclock_nfts_count),
            .gen2_sameclock_nfts_count_data_7         (gen2_sameclock_nfts_count),
            .deemphasis_enable_7                      (deemphasis_enable),
            .pcie_spec_version_7                      (pcie_spec_version),
            .l2_async_logic_7                         (l2_async_logic),
            .flr_capability_7                         (flr_capability_7),

            .expansion_base_address_register_data_7   (expansion_base_address_register_7),

            .io_window_addr_width_7                   (io_window_addr_width_7),
            .prefetchable_mem_window_addr_width_7     (prefetchable_mem_window_addr_width_7),

            .porttype_func0                           ((porttype_func0 == "ep_legacy") ? "ep_legacy" :
                                                       (porttype_func0 == "rp"       ) ? "rp"        :
                                                       (porttype_func0 == "bridge"  ) ? "bridge" : "ep_native"),

            .porttype_func1                           (((low_str(multi_function) != "one_func") && (porttype_func1 == "ep_legacy")) ? "ep_legacy" :
                                                       ((low_str(multi_function) != "one_func") && (porttype_func1 == "bridge"   )  ? "bridge" : "ep_native")),

            .porttype_func2                           (((low_str(multi_function) != "one_func") && (porttype_func2 == "ep_legacy")) ? "ep_legacy" : "ep_native"),
            .porttype_func3                           (((low_str(multi_function) != "one_func") && (porttype_func3 == "ep_legacy")) ? "ep_legacy" : "ep_native"),
            .porttype_func4                           (((low_str(multi_function) != "one_func") && (porttype_func4 == "ep_legacy")) ? "ep_legacy" : "ep_native"),
            .porttype_func5                           (((low_str(multi_function) != "one_func") && (porttype_func5 == "ep_legacy")) ? "ep_legacy" : "ep_native"),
            .porttype_func6                           (((low_str(multi_function) != "one_func") && (porttype_func6 == "ep_legacy")) ? "ep_legacy" : "ep_native"),
            .porttype_func7                           (((low_str(multi_function) != "one_func") && (porttype_func7 == "ep_legacy")) ? "ep_legacy" : "ep_native")
               ) arriav_hd_altpe2_hip_top (
            // Input Ports
            .avmmaddress                              ((hip_reconfig==1)? avmmaddress:10'h0   ), // input [9:0]    avmmaddress;            //PLD   // address input
            .avmmbyteen                               ((hip_reconfig==1)? avmmbyteen:2'b00    ), // input [1:0]    avmmbyteen;             //PLD   // Byte enable
            .avmmclk                                  ((hip_reconfig==1)? avmmclk:1'b0        ), // input          avmmclk;                //PLD   // DPRIO clock
            .avmmread                                 ((hip_reconfig==1)? avmmread:1'b0       ), // input          avmmread;               //PLD   // read enable input
            .avmmrstn                                 ((hip_reconfig==1)? avmmrstn:1'b1       ), // input          avmmrstn;               //PLD   // DPRIO reset
            .avmmwrite                                ((hip_reconfig==1)? avmmwrite:1'b0      ), // input          avmmwrite;              //PLD   // write enable input
            .avmmwritedata                            ((hip_reconfig==1)? avmmwritedata:16'h0 ), // input [15:0]   avmmwritedata;          //PLD   // write data input
            .bistscanenn                              ((MEM_CHECK==0)?1'b1:bistscanenn        ), // input          bistscanenn;            //PLD -- shared for all 3 memory blocks
            .bistscanin                               ((MEM_CHECK==0)?1'b0:bistscanin         ), // input          bistscanen;             //PLD -- shared for all 3 memory blocks
            .bisttestenn                              ((MEM_CHECK==0)?1'b1:bisttestenn        ), // input          bistscanin;             //PLD -- shared for all 3 memory blocks
            .bistenn                                  ((MEM_CHECK==0)?1'b1:bisttestenn        ), // input          bistesten;              //PLD
            .cbhipmdioen                              (cbhipmdioen                            ), // input          cbhipmdioen;            //PLD   // Control block option bit to block MDIO IOs
            .coreclkin                                (pld_clk                                ), // input          coreclkin;              //PLD
            .corecrst                                 ((USE_HARD_RESET==0)?crst:1'b0          ), // input          corecrst;               //PLD
            .corepor                                  (por                                    ), // input          corepor;                //PLD
            .corerst                                  (por                                    ), // input          corerst;                //PLD
            .coresrst                                 ((USE_HARD_RESET==0)?srst:1'b0          ), // input          coresrst;               //PLD
            .cplerr                                   (cpl_err                                ), // input [6:0]    cplerr;                 //PLD
            .cplerrfunc                               (cpl_errfunc                            ), // input [2:0]    cplerrfunc;             //PLD
            .cplpending                               (cpl_pending                            ), // input [7:0]    cplpending;             //PLD
      // synthesis translate_off
            .csrcbdin                                 (1'b0                                   ), // input          csrcbdin;               //CB    // CSR configuration mode data input
            .csrclk                                   (1'b0                                   ), // input          csrclk;                 //CB    // CSR clock
            .csrdin                                   (1'b0                                   ), // input          csrdin;                 //CB    // Previous CSR bit data output
            .csren                                    (1'b0                                   ), // input          csren;                  //CB    // CSR enable
            .csrenscan                                (1'b0                                   ), // input          csrenscan;              //CB    // enable scan control input
            .csrin                                    (1'b0                                   ), // input          csrin;                  //CB    // Serial CSR input
            .csrloadcsr                               (1'b0                                   ), // input          csrloadcsr;             //CB    // JTAG scan mode control input
            .csrpipein                                (1'b0                                   ), // input          csrpipein;              //CB    // Input to the Pipeline register to suport 200MHz
            .csrseg                                   (1'b0                                   ), // input          csrseg;                 //CB    // VSS for Seg0, VCC for seg[31:1]
            .csrtcsrin                                (1'b0                                   ), // input          csrtcsrin;              //CB    // CSR test/scan mode data input
            .csrtverify                               (1'b0                                   ), // input          csrtverify;             //CB    // test verify control input
            .cvpconfigdone                            (1'b0                                   ), // input          cvpconfigdone;          //CB
            .cvpconfigerror                           (1'b0                                   ), // input          cvpconfigerror;         //CB
            .cvpconfigready                           (1'b0                                   ), // input          cvpconfigready;         //CB
            .cvpen                                    (1'b0                                   ), // input          cvpen;                  //CB
            .entest                                   (1'b0                                   ), // input          entest;                 //CB
            .usermode                                 (1'b1                                   ), // input          usermode;               //CB    -- use to gate off input signal
            .hippartialreconfign                      (1'b1                                   ), // input          hippartialreconfign;    //CB    -- use to gate off output signal
            .iocsrrdydly                              (1'b0                                   ), // input          iocsrrdydly;            //CB -- I/O CSR Ready Delayed (Low when IOCSR is not configured)
            .plniotri                                 (1'b1                                   ), // input          plniotri;               //CB
            .por                                      (por                                   ),  // input          por;                    //CB
      // synthesis translate_on
            .dbgpipex1rx                              (dbgpipex1rx                           ), // input [14:0]   dbgpipex1rx;            //PLD
            .dlcomclkreg                              (dl_comclk_reg                        ),  // input          dlcomclkreg;            //PLD   // ww51.5 change by Ning Xue
            .dlctrllink2                              (dl_ctrl_link2                        ),  // input [12:0]   dlctrllink2;            //PLD
            .dlvcctrl                                 (dl_vc_ctrl                           ),  // input [7:0]    dlvcctrl;               //PLD
            .dpriorefclkdig                           (dpriorefclkdig                       ),  // input          dpriorefclkdig;         //PLD
            .flrreset                                 (flrreset_hip                          ), // input [7:0]    flrreset;               //PLD
            .frefclk0                                 (frefclk[0]                            ), // input          frefclk0;               //PCS
            .frefclk1                                 (frefclk[1]                            ), // input          frefclk1;               //PCS
            .frefclk2                                 (frefclk[2]                            ), // input          frefclk2;               //PCS
            .frefclk3                                 (frefclk[3]                            ), // input          frefclk3;               //PCS
            .frefclk4                                 (frefclk[4]                            ), // input          frefclk4;               //PCS
            .frefclk5                                 (frefclk[5]                            ), // input          frefclk5;               //PCS
            .frefclk6                                 (frefclk[6]                            ), // input          frefclk6;               //PCS
            .frefclk7                                 (frefclk[7]                            ), // input          frefclk7;               //PCS
            .frefclk8                                 (frefclk[8]                            ), // input          frefclk8;               //PCS
            .frzlogic                                 (1'b0                                  ), // input          frzlogic;               //PLD
            .frzreg                                   (1'b0                                  ), // input          frzreg;                 //PLD
            .hipextraclkin                            (hipextraclkin                         ), // input [1:0]    hipextraclkin;
            .hipextrain                               (hipextrain                            ), // input [29:0]   hipextrain;        //
            .interfacesel                             ((hip_reconfig==1)? interfacesel:1'b1 ),  // input          interfacesel;           //PLD   // Interface selection inputs
            .lmiaddr                                  (lmi_addr                              ), // input  [14:0]  lmiaddr;                //PLD
            .lmidin                                   (lmi_din                               ), // input  [31:0]  lmidin;                 //PLD
            .lmirden                                  (lmi_rden                              ), // input          lmirden;                //PLD
            .lmiwren                                  (lmi_wren                              ), // input          lmiwren;                //PLD
            .mdioclk                                  (mdio_clk                              ), // input          mdioclk;                //PLD   // MDIO clock
            .mdiodevaddr                              (mdio_dev_addr                         ), // input [1:0]    mdiodevaddr;            //PLD     //MDIO device address tied at PLD interface
            .mdioin                                   (mdio_in                               ), // input          mdioin;                 //PLD   // MDIO serial input
            .mode                                     (mode                                  ), // input [1:0]    mode;                   //PLD
            .nfrzdrv                                  (1'b1                                  ), // input          nfrzdrv;                //PLD
            .pcierr                                   (pci_err                               ), // input [15:0]   pcierr;                 //PLD
            .pclkcentral                              ((pipe_mode==1'b1)? pclk_in: mserdes_pipe_pclkcentral),  // input          pclkcentral;                 //PCS-PMA
            .pclkch0                                  ((pipe_mode==1'b1)? pclk_in: mserdes_pipe_pclk),         // input          pclkch0;                     //PCS-PMA
            .pclkch1                                  ((pipe_mode==1'b1)? pclk_in: mserdes_pipe_pclkch1),      // input          pclkch1;                     //PCS-PMA
            .phyrst                                   (por                                   ),        // input          phyrst;                 //PLD
            .physrst                                  ((USE_HARD_RESET==0)?srst:1'b0         ),        // input          physrst;                //PLD
            .phystatus0                               (phystatus0                            ),             // input          phystatus0;             //PCS
            .phystatus1                               (phystatus1                            ),             // input          phystatus1;             //PCS
            .phystatus2                               (phystatus2                            ),             // input          phystatus2;             //PCS
            .phystatus3                               (phystatus3                            ),             // input          phystatus3;             //PCS
            .phystatus4                               (phystatus4                            ),             // input          phystatus4;             //PCS
            .phystatus5                               (phystatus5                            ),             // input          phystatus5;             //PCS
            .phystatus6                               (phystatus6                            ),             // input          phystatus6;             //PCS
            .phystatus7                               (phystatus7                            ),             // input          phystatus7;             //PCS
            .pinperstn                                ((USE_HARD_RESET==0)?1'b1: pin_perst   ),        // input          pinperstn;              // Active low PCIE reset from PCIE Interface PIN
            .pldclk                                   (pld_clk                               ),        // input          pldclk;                 //PLD
            .pldclrhipn                               ((USE_HARD_RESET==0)?1'b1:~hiprst      ),       // input          pldclrhipn;             //PLD -- From PLD Active low signal To Hard Reset Ctrl, reset the HIP NON STICKY Bits (CRST & SRST)
            .pldclrpcshipn                            (1'b1                                  ),        // input          pldclrpcshipn;          //PLD -- From PLD Active low signal To Hard Reset Ctrl, reset the PCS/HIP
            .pldclrpmapcshipn                         (1'b1                                  ),        // input          pldclrpmapcshipn;       //PLD -- From PLD Active low signal To Hard Reset Ctrl, reset the PMA/PCS/HIP
            .pldcoreready                             (pldcoreready                          ),        // input          pldcoreready;           //PLD
            .pldperstn                                (1'b1                                  ),        // input          pldperstn;              // Active low PCIE reset from PLD core
            .pldrst                                   (por                                   ),        // input          pldrst;                 //PLD
            .pldsrst                                  ((USE_HARD_RESET==0)?srst:1'b0         ),        // input          pldsrst;                //PLD
            .pllfixedclkcentral                       ((pipe_mode==1'b0)? mserdes_pllfixedclkcentral:(low_str(gen12_lane_rate_mode)=="gen1_gen2")?clk500_out:clk250_out), // input          pllfixedclkcentral;        //PCS-PMA
            .pllfixedclkch0                           ((pipe_mode==1'b0)? mserdes_pllfixedclkch0    :(low_str(gen12_lane_rate_mode)=="gen1_gen2")?clk500_out:clk250_out), // input          pllfixedclkch0;            //PCS-PMA
            .pllfixedclkch1                           ((pipe_mode==1'b0)? mserdes_pllfixedclkch1    :(low_str(gen12_lane_rate_mode)=="gen1_gen2")?clk500_out:clk250_out), // input          pllfixedclkch1;            //PCS-PMA
            .rxfreqtxcmuplllock0                      (rxfreqtxcmuplllock[0]                 ),             // input          rxfreqtxcmuplllock0;    //PCS
            .rxfreqtxcmuplllock1                      (rxfreqtxcmuplllock[1]                 ),             // input          rxfreqtxcmuplllock1;    //PCS
            .rxfreqtxcmuplllock2                      (rxfreqtxcmuplllock[2]                 ),             // input          rxfreqtxcmuplllock2;    //PCS
            .rxfreqtxcmuplllock3                      (rxfreqtxcmuplllock[3]                 ),             // input          rxfreqtxcmuplllock3;    //PCS
            .rxfreqtxcmuplllock4                      (rxfreqtxcmuplllock[4]                 ),             // input          rxfreqtxcmuplllock4;    //PCS
            .rxfreqtxcmuplllock5                      (rxfreqtxcmuplllock[5]                 ),             // input          rxfreqtxcmuplllock5;    //PCS
            .rxfreqtxcmuplllock6                      (rxfreqtxcmuplllock[6]                 ),             // input          rxfreqtxcmuplllock6;    //PCS
            .rxfreqtxcmuplllock7                      (rxfreqtxcmuplllock[7]                 ),             // input          rxfreqtxcmuplllock7;    //PCS
            .rxfreqtxcmuplllock8                      (rxfreqtxcmuplllock[8]                 ),             // input          rxfreqtxcmuplllock8;    //PCS
            .rxmaskvc0                                (rx_mask_vc0                           ),             // input          rxmaskvc0;              //PLD
            .rxpllphaselock0                          (rxpllphaselock[0]                     ),             // input          rxpllphaselock0;        //PCS
            .rxpllphaselock1                          (rxpllphaselock[1]                     ),             // input          rxpllphaselock1;        //PCS
            .rxpllphaselock2                          (rxpllphaselock[2]                     ),             // input          rxpllphaselock2;        //PCS
            .rxpllphaselock3                          (rxpllphaselock[3]                     ),             // input          rxpllphaselock3;        //PCS
            .rxpllphaselock4                          (rxpllphaselock[4]                     ),             // input          rxpllphaselock4;        //PCS
            .rxpllphaselock5                          (rxpllphaselock[5]                     ),             // input          rxpllphaselock5;        //PCS
            .rxpllphaselock6                          (rxpllphaselock[6]                     ),             // input          rxpllphaselock6;        //PCS
            .rxpllphaselock7                          (rxpllphaselock[7]                     ),             // input          rxpllphaselock7;        //PCS
            .rxpllphaselock8                          (rxpllphaselock[8]                     ),             // input          rxpllphaselock8;        //PCS
            .rxreadyvc0                               (rx_st_ready_vc0                       ),             // input          rxreadyvc0;             //PLD
            .rxdata0                                  (rxdata0                               ),             // input [7:0]    rxdata0;                //PCS
            .rxdata1                                  (rxdata1                               ),             // input [7:0]    rxdata1;                //PCS
            .rxdata2                                  (rxdata2                               ),             // input [7:0]    rxdata2;                //PCS
            .rxdata3                                  (rxdata3                               ),             // input [7:0]    rxdata3;                //PCS
            .rxdata4                                  (rxdata4                               ),             // input [7:0]    rxdata4;                //PCS
            .rxdata5                                  (rxdata5                               ),             // input [7:0]    rxdata5;                //PCS
            .rxdata6                                  (rxdata6                               ),             // input [7:0]    rxdata6;                //PCS
            .rxdata7                                  (rxdata7                               ),             // input [7:0]    rxdata7;                //PCS
            .rxdatak0                                 (rxdatak0                              ),             // input          rxdatak0;               //PCS
            .rxdatak1                                 (rxdatak1                              ),             // input          rxdatak1;               //PCS
            .rxdatak2                                 (rxdatak2                              ),             // input          rxdatak2;               //PCS
            .rxdatak3                                 (rxdatak3                              ),             // input          rxdatak3;               //PCS
            .rxdatak4                                 (rxdatak4                              ),             // input          rxdatak4;               //PCS
            .rxdatak5                                 (rxdatak5                              ),             // input          rxdatak5;               //PCS
            .rxdatak6                                 (rxdatak6                              ),             // input          rxdatak6;               //PCS
            .rxdatak7                                 (rxdatak7                              ),             // input          rxdatak7;               //PCS
            .rxelecidle0                              (rxelecidle0                           ),             // input          rxelecidle0;            //PCS
            .rxelecidle1                              (rxelecidle1                           ),             // input          rxelecidle1;            //PCS
            .rxelecidle2                              (rxelecidle2                           ),             // input          rxelecidle2;            //PCS
            .rxelecidle3                              (rxelecidle3                           ),             // input          rxelecidle3;            //PCS
            .rxelecidle4                              (rxelecidle4                           ),             // input          rxelecidle4;            //PCS
            .rxelecidle5                              (rxelecidle5                           ),             // input          rxelecidle5;            //PCS
            .rxelecidle6                              (rxelecidle6                           ),             // input          rxelecidle6;            //PCS
            .rxelecidle7                              (rxelecidle7                           ),             // input          rxelecidle7;            //PCS
            .rxfreqlocked0                            (rxfreqlocked0                         ),             // input          rxfreqlocked0;          //PCS-PMA
            .rxfreqlocked1                            (rxfreqlocked1                         ),             // input          rxfreqlocked1;          //PCS-PMA
            .rxfreqlocked2                            (rxfreqlocked2                         ),             // input          rxfreqlocked2;          //PCS-PMA
            .rxfreqlocked3                            (rxfreqlocked3                         ),             // input          rxfreqlocked3;          //PCS-PMA
            .rxfreqlocked4                            (rxfreqlocked4                         ),             // input          rxfreqlocked4;          //PCS-PMA
            .rxfreqlocked5                            (rxfreqlocked5                         ),             // input          rxfreqlocked5;          //PCS-PMA
            .rxfreqlocked6                            (rxfreqlocked6                         ),             // input          rxfreqlocked6;          //PCS-PMA
            .rxfreqlocked7                            (rxfreqlocked7                         ),             // input          rxfreqlocked7;          //PCS-PMA
            .rxstatus0                                (rxstatus0                             ),             // input [2:0]    rxstatus0;              //PCS
            .rxstatus1                                (rxstatus1                             ),             // input [2:0]    rxstatus1;              //PCS
            .rxstatus2                                (rxstatus2                             ),             // input [2:0]    rxstatus2;              //PCS
            .rxstatus3                                (rxstatus3                             ),             // input [2:0]    rxstatus3;              //PCS
            .rxstatus4                                (rxstatus4                             ),             // input [2:0]    rxstatus4;              //PCS
            .rxstatus5                                (rxstatus5                             ),             // input [2:0]    rxstatus5;              //PCS
            .rxstatus6                                (rxstatus6                             ),             // input [2:0]    rxstatus6;              //PCS
            .rxstatus7                                (rxstatus7                             ),             // input [2:0]    rxstatus7;              //PCS
            .rxvalid0                                 (rxvalid0                             ),         // input          rxvalid0;               //PCS
            .rxvalid1                                 (rxvalid1                             ),         // input          rxvalid1;               //PCS
            .rxvalid2                                 (rxvalid2                             ),         // input          rxvalid2;               //PCS
            .rxvalid3                                 (rxvalid3                             ),         // input          rxvalid3;               //PCS
            .rxvalid4                                 (rxvalid4                             ),         // input          rxvalid4;               //PCS
            .rxvalid5                                 (rxvalid5                             ),         // input          rxvalid5;               //PCS
            .rxvalid6                                 (rxvalid6                             ),         // input          rxvalid6;               //PCS
            .rxvalid7                                 (rxvalid7                             ),         // input          rxvalid7;               //PCS
            .scanenn                                  (scanenn                              ),         // input          scanenn;                //PLD
            .scanmoden                                ((MEM_CHECK==0)?1'b1:scanmoden         ),         // input          scanmoden;              //PLD
            .sershiftload                             ((hip_reconfig==1)? ser_shift_load:1'b1),        // input          sershiftload;           //CB    // 1'b1=shift in data from si into scan flop
            .swdnin                                   (3'b000                               ),         // input  [2:0]   swdnin;                 //PLD
            .swupin                                   (7'b0000000                           ),         // input  [6:0]   swupin;                 //PLD
            .testinhip                                (test_in                              ),         // input [39:0]   testinhip;              //PLD
            .tlaermsinum                              (tl_aer_msi_num                       ),         // input [4:0]    tlaermsinum;            //PLD
            .tlappintafuncnum                         (tl_app_inta_funcnum                  ),         // input [2:0]    tlappintafuncnum;       //PLD
            .tlappintasts                             (tl_app_inta_sts                      ),         // input          tlappintasts;           //PLD
            .tlappintbfuncnum                         (tl_app_intb_funcnum                  ),         // input [2:0]    tlappintbfuncnum;       //PLD
            .tlappintbsts                             (tl_app_intb_sts                      ),         // input          tlappintbsts;           //PLD
            .tlappintcfuncnum                         (tl_app_intc_funcnum                  ),         // input [2:0]    tlappintcfuncnum;       //PLD
            .tlappintcsts                             (tl_app_intc_sts                      ),         // input          tlappintcsts;           //PLD
            .tlappintdfuncnum                         (tl_app_intd_funcnum                  ),         // input [2:0]    tlappintdfuncnum;       //PLD
            .tlappintdsts                             (tl_app_intd_sts                      ),         // input          tlappintdsts;           //PLD
            .tlappmsifunc                             (tl_app_msi_func                      ),         // input [2:0]    tlappmsifunc;           //PLD
            .tlappmsinum                              (tl_app_msi_num                       ),         // input [4:0]    tlappmsinum;            //PLD
            .tlappmsireq                              (tl_app_msi_req                       ),         // input          tlappmsireq;            //PLD
            .tlappmsitc                               (tl_app_msi_tc                        ),         // input [2:0]    tlappmsitc;             //PLD
            .tlhpgctrler                              (tl_hpg_ctrl_er                       ),         // input [4:0]    tlhpgctrler;            //PLD
            .tlpexmsinum                              (tl_pex_msi_num                       ),         // input [4:0]    tlpexmsinum;            //PLD
            .tlpmauxpwr                               (tl_pm_auxpwr                         ),         // input          tlpmauxpwr;             //PLD
            .tlpmdata                                 (tl_pm_data                           ),         // input  [9:0]   tlpmdata;               //PLD
            .tlpmevent                                (tl_pm_event                          ),         // input          tlpmevent;              //PLD
            .tlpmeventfunc                            (tl_pm_event_func                     ),         // input [2:0]    tlpmeventfunc;          //PLD
            .tlpmetocr                                (tl_pme_to_cr                         ),         // input          tlpmetocr;              //PLD
            .tlslotclkcfg                             (tl_slotclk_cfg                       ),         // input          tlslotclkcfg;           //PLD
            .txdatavc00                               (tx_st_data_vc0[63:0]                 ),         // input  [63:0]  txdatavc00;             //PLD
            .txdatavc01                               (tx_st_data_vc0[127:64]               ),         // input  [63:0]  txdatavc01;             //PLD
            .txeopvc00                                (tx_st_eop_vc0[0]                     ),         // input          txeopvc00;              //PLD
            .txeopvc01                                (tx_st_eop_vc0[1]                     ),         // input          txeopvc01;              //PLD
            .txerrvc0                                 (tx_st_err_vc0                        ),         // input          txerrvc0;               //PLD
            .txsopvc00                                (tx_st_sop_vc0[0]                     ),         // input          txsopvc00;              //PLD
            .txsopvc01                                (tx_st_sop_vc0[1]                     ),         // input          txsopvc01;              //PLD
            .txvalidvc0                               (tx_st_valid_vc0                      ),         // input          txvalidvc0;             //PLD

            // Output Ports
            .avmmreaddata                             (avmmreaddata               ),                   //output  [15:0]  avmm_readdata;          //PLD   // Read data output
            .bistdonearcv0                            (bistdonearcv0              ),                   //output          bist_donea_rcv0;        //PLD
            .bistdonearcv1                            (bistdonearcv1              ),                   //output          bist_donea_rcv1;        //PLD
            .bistdonearpl                             (bistdonearpl               ),                   //output          bist_donea_rpl;         //PLD
            .bistdonebrcv0                            (bistdonebrcv0              ),                   //output          bist_doneb_rcv0;        //PLD
            .bistdonebrcv1                            (bistdonebrcv1              ),                   //output          bist_doneb_rcv1;        //PLD
            .bistdonebrpl                             (bistdonebrpl               ),                   //output          bist_doneb_rpl;         //PLD
            .bistpassrcv0                             (bistpassrcv0               ),                   //output          bist_pass_rcv0;         //PLD
            .bistpassrcv1                             (bistpassrcv1               ),                   //output          bist_pass_rcv1;         //PLD
            .bistpassrpl                              (bistpassrpl                ),                   //output          bist_pass_rpl;          //PLD
            .bistscanoutrcv0                          (bistscanoutrcv0            ),                   //output          bist_scanout_rcv0;      //PLD
            .bistscanoutrcv1                          (bistscanoutrcv1            ),                   //output          bist_scanout_rcv1;      //PLD
            .bistscanoutrpl                           (bistscanoutrpl             ),                   //output          bist_scanout_rpl;       //PLD
            .clrrxpath                                (clrrxpath                  ),                   //output          clr_rxpath;             //PLD
            .coreclkout                               (coreclkout                 ),                   //output          core_clk_out;           //PLD
            .derrcorextrcv0                           (derr_cor_ext_rcv0          ),                   //output          derr_cor_ext_rcv0;      //PLD
            .derrcorextrpl                            (derr_cor_ext_rpl           ),                   //output          derr_cor_ext_rpl;       //PLD
            .derrrpl                                  (derr_rpl                   ),                   //output          derr_rpl;               //PLD
            .dlcurrentspeed                           (dl_current_speed           ),                   //output [1:0]    dl_current_speed;       //PLD
            .dlltssm                                  (dl_ltssm                   ),                   //output [4:0]    dl_ltssm;               //PLD
            .dlupexit                                 (dlup_exit                  ),                   //output          dlup_exit;              //PLD
            .eidleinfersel0                           (eidleinfersel0             ),                        //output [2:0]    eidle_infer_sel0;       //PCS
            .eidleinfersel1                           (eidleinfersel1             ),                        //output [2:0]    eidle_infer_sel1;       //PCS
            .eidleinfersel2                           (eidleinfersel2             ),                        //output [2:0]    eidle_infer_sel2;       //PCS
            .eidleinfersel3                           (eidleinfersel3             ),                        //output [2:0]    eidle_infer_sel3;       //PCS
            .eidleinfersel4                           (eidleinfersel4             ),                        //output [2:0]    eidle_infer_sel4;       //PCS
            .eidleinfersel5                           (eidleinfersel5             ),                        //output [2:0]    eidle_infer_sel5;       //PCS
            .eidleinfersel6                           (eidleinfersel6             ),                        //output [2:0]    eidle_infer_sel6;       //PCS
            .eidleinfersel7                           (eidleinfersel7             ),                        //output [2:0]    eidle_infer_sel7;       //PCS
            .ev128ns                                  (ev128ns                    ),                   //output          ev_128ns;               //PLD
            .ev1us                                    (ev1us                      ),                   //output          ev_1us;                 //PLD
            .flrsts                                   (flr_sts                    ),                   //output  [7:0]   flr_sts;                //PLD
            .hipextraclkout                           (hipextraclkout             ),                   //output  [1:0]   hip_extraclkout;
            .hipextraout                              (hipextraout                ),                   //output  [29:0]  hip_extraout;           //PLD
            .hotrstexit                               (hotrst_exit                ),                   //output          hotrst_exit;            //PLD
            .intstatus                                (int_status                 ),                   //output [3:0]    int_status;             //PLD
            .l2exit                                   (l2_exit                    ),                   //output          l2_exit;                //PLD
            .laneact                                  (lane_act                   ),                   //output [3:0]    lane_act;               //PLD
            .lmiack                                   (lmi_ack                    ),                   //output          lmi_ack;                //PLD
            .lmidout                                  (lmi_dout                   ),                   //output [31:0]   lmi_dout;               //PLD
            .ltssml0state                             (ltssml0state               ),                   //output          ltssm_l0_state;         //PLD
            .mdiooenn                                 (mdio_oen_n                 ),                   //output          mdio_oen_n;             //PLD   // MDIO output enable
            .mdioout                                  (mdio_out                   ),                   //output          mdio_out;               //PLD   // MDIO serial output
            .pldclkinuse                              (pld_clk_in_use_hip         ),                   //output          pld_clk_in_use;
            .powerdown0                               (powerdown0                 ),                   //output [1:0]    powerdown0;             //PCS
            .powerdown1                               (powerdown1                 ),                   //output [1:0]    powerdown1;             //PCS
            .powerdown2                               (powerdown2                 ),                   //output [1:0]    powerdown2;             //PCS
            .powerdown3                               (powerdown3                 ),                   //output [1:0]    powerdown3;             //PCS
            .powerdown4                               (powerdown4                 ),                   //output [1:0]    powerdown4;             //PCS
            .powerdown5                               (powerdown5                 ),                   //output [1:0]    powerdown5;             //PCS
            .powerdown6                               (powerdown6                 ),                   //output [1:0]    powerdown6;             //PCS
            .powerdown7                               (powerdown7                 ),                   //output [1:0]    powerdown7;             //PCS
            .r2cerrext                                (r2c_err_ext                ),                   //output          r2c_err_ext;
            .rate0                                    (rate0                      ),                   //output          rate0;                  //PCS
            .rate1                                    (rate1                      ),                   //output          rate1;                  //PCS
            .rate2                                    (rate2                      ),                   //output          rate2;                  //PCS
            .rate3                                    (rate3                      ),                   //output          rate3;                  //PCS
            .rate4                                    (ratectrl                   ),                   //output          rate4;                  //PCS
            .rate5                                    (rate4                      ),                   //output          rate5;                  //PCS
            .rate6                                    (rate5                      ),                   //output          rate6;                  //PCS
            .rate7                                    (rate6                      ),                   //output          rate7;                  //PCS
            .rate8                                    (rate7                      ),                   //output          rate8;                  //PCS
            .resetstatus                              (reset_status_hip           ),                   //output          reset_status;           //PLD
            .rxbardecfuncnumvc0                       (rx_bar_dec_func_num_vc0    ),                   //output [2:0]    rx_bar_dec_func_num_vc0;//PLD
            .rxbardecvc0                              (rx_bar_dec_vc0             ),                   //output [7:0]    rx_bar_dec_vc0;         //PLD
            .rxbevc00                                 (rx_be_vc0[7:0]             ),                   //output [7:0]    rx_be_vc0_0;            //PLD
            .rxbevc01                                 (rx_be_vc0[15:8]            ),                   //output [7:0]    rx_be_vc0_1;            //PLD
            .rxdatavc00                               (rx_st_data_vc0[63:0]       ),                   //output [63:0]   rx_data_vc0_0;          //PLD
            .rxdatavc01                               (rx_st_data_vc0[127:64]     ),                   //output [63:0]   rx_data_vc0_1;          //PLD
            .rxeopvc00                                (rx_st_eop_vc0[0]           ),                   //output          rx_eop_vc0_0;           //PLD
            .rxeopvc01                                (rx_st_eop_vc0[1]           ),                   //output          rx_eop_vc0_1;           //PLD
            .rxerrvc0                                 (rx_st_err_vc0              ),                   //output          rx_err_vc0;             //PLD   // uncorrectable error
            .rxfifoemptyvc0                           (rx_fifo_empty_vc0          ),                   //output          rx_fifo_empty_vc0;      //PLD
            .rxfifofullvc0                            (rx_fifo_full_vc0           ),                   //output          rx_fifo_full_vc0;       //PLD
            .rxfifordpvc0                             (rx_fifo_rdp_vc0            ),                   //output [3:0]    rx_fifo_rdp_vc0;        //PLD
            .rxfifowrpvc0                             (rx_fifo_wrp_vc0            ),                   //output [3:0]    rx_fifo_wrp_vc0;        //PLD
            .rxpcsrstn0                               (rxpcsrstn[0]               ),                        //output          rx_pcs_rst_n0;          //PCS
            .rxpcsrstn1                               (rxpcsrstn[1]               ),                        //output          rx_pcs_rst_n1;          //PCS
            .rxpcsrstn2                               (rxpcsrstn[2]               ),                        //output          rx_pcs_rst_n2;          //PCS
            .rxpcsrstn3                               (rxpcsrstn[3]               ),                        //output          rx_pcs_rst_n3;          //PCS
            .rxpcsrstn4                               (rxpcsrstn[4]               ),                        //output          rx_pcs_rst_n4;          //PCS
            .rxpcsrstn5                               (rxpcsrstn[5]               ),                        //output          rx_pcs_rst_n5;          //PCS
            .rxpcsrstn6                               (rxpcsrstn[6]               ),                        //output          rx_pcs_rst_n6;          //PCS
            .rxpcsrstn7                               (rxpcsrstn[7]               ),                        //output          rx_pcs_rst_n7;          //PCS
            .rxpcsrstn8                               (rxpcsrstn[8]               ),                        //output          rx_pcs_rst_n8;          //PCS
            .rxpmarstb0                               (rxpmarstb[0]               ),                        //output          rx_pma_rstb0;           //PCS
            .rxpmarstb1                               (rxpmarstb[1]               ),                        //output          rx_pma_rstb1;           //PCS
            .rxpmarstb2                               (rxpmarstb[2]               ),                        //output          rx_pma_rstb2;           //PCS
            .rxpmarstb3                               (rxpmarstb[3]               ),                        //output          rx_pma_rstb3;           //PCS
            .rxpmarstb4                               (rxpmarstb[4]               ),                        //output          rx_pma_rstb4;           //PCS
            .rxpmarstb5                               (rxpmarstb[5]               ),                        //output          rx_pma_rstb5;           //PCS
            .rxpmarstb6                               (rxpmarstb[6]               ),                        //output          rx_pma_rstb6;           //PCS
            .rxpmarstb7                               (rxpmarstb[7]               ),                        //output          rx_pma_rstb7;           //PCS
            .rxpmarstb8                               (rxpmarstb[8]               ),                        //output          rx_pma_rstb8;           //PCS
            .rxsopvc00                                (rx_st_sop_vc0[0]              ),                //output          rx_sop_vc0_0;           //PLD
            .rxsopvc01                                (rx_st_sop_vc0[1]              ),                //output          rx_sop_vc0_1;           //PLD
            .rxvalidvc0                               (rx_st_valid_vc0               ),                //output          rx_valid_vc0;           //PLD
            .rxpolarity0                              (rxpolarity0                ),                        //output          rxpolarity0;            //PCS
            .rxpolarity1                              (rxpolarity1                ),                        //output          rxpolarity1;            //PCS
            .rxpolarity2                              (rxpolarity2                ),                        //output          rxpolarity2;            //PCS
            .rxpolarity3                              (rxpolarity3                ),                        //output          rxpolarity3;            //PCS
            .rxpolarity4                              (rxpolarity4                ),                        //output          rxpolarity4;            //PCS
            .rxpolarity5                              (rxpolarity5                ),                        //output          rxpolarity5;            //PCS
            .rxpolarity6                              (rxpolarity6                ),                        //output          rxpolarity6;            //PCS
            .rxpolarity7                              (rxpolarity7                ),                        //output          rxpolarity7;            //PCS
            .serrout                                  (serr_out                   ),                   //output          serr_out;               //PLD
            .successfulspeednegotiationint            (successful_speed_negotiation_int),              //output          successful_speed_negotiation_int;
            .swdnwake                                 (swdn_wake                  ),                   //output          swdn_wake;              //PLD
            .swuphotrst                               (swup_hotrst                ),                   //output          swup_hotrst;            //PLD
            .testouthip                               (test_out                   ),                   //output [63:0]   test_out_hip;           //PLD
            .tlappintaack                             (tl_app_inta_ack            ),                   //output          tl_app_inta_ack;        //PLD
            .tlappintback                             (tl_app_intb_ack            ),                   //output          tl_app_intb_ack;        //PLD
            .tlappintcack                             (tl_app_intc_ack            ),                   //output          tl_app_intc_ack;        //PLD
            .tlappintdack                             (tl_app_intd_ack            ),                   //output          tl_app_intd_ack;        //PLD
            .tlappmsiack                              (tl_app_msi_ack             ),                   //output          tl_app_msi_ack;         //PLD
            .tlcfgadd                                 (tl_cfg_add_hip             ),                   //output [6:0]    tl_cfg_add;             //PLD
            .tlcfgctl                                 (tl_cfg_ctl_hip             ),                   //output [31:0]   tl_cfg_ctl;             //PLD
            .tlcfgctlwr                               (tl_cfg_ctl_wr_hip          ),                   //output          tl_cfg_ctl_wr;          //PLD
            .tlcfgsts                                 (tl_cfg_sts_hip             ),                   //output [122:0]  tl_cfg_sts;             //PLD
            .tlcfgstswr                               (tl_cfg_sts_wr_hip          ),                   //output          tl_cfg_sts_wr;          //PLD
            .tlpmetosr                                (tl_pme_to_sr               ),                   //output          tl_pme_to_sr;           //PLD
            .txcreddatafccp                           (tx_cred_datafccp           ),                   //output  [11:0]  tx_cred_data_fc_cp;     //PLD TL to AL Signals the Data credit of the received FC completion
            .txcreddatafcnp                           (tx_cred_datafcnp           ),                   //output  [11:0]  tx_cred_data_fc_np;     //PLD TL to AL Signals the Data credit of the received FC Non Posted
            .txcreddatafcp                            (tx_cred_datafcp            ),                   //output  [11:0]  tx_cred_data_fc_p;      //PLD TL to AL Signals the Data credit of the received FC Posted
            .txcredfchipcons                          (tx_cred_fchipcons          ),                   //output  [5:0]   tx_cred_fc_hip_cons;    //PLD TL to AL Indicates that HIP consumed one of PH PD, NPH, NPD, CH, CD
            .txcredfcinfinite                         (tx_cred_fcinfinite         ),                   //output  [5:0]   tx_cred_fc_infinite;    //PLD TL to AL Indicates if this is an infinite credit PH PD, NPH, NPD, CH, CD
            .txcredhdrfccp                            (tx_cred_hdrfccp            ),                   //output  [7:0]   tx_cred_hdr_fc_cp;      //PLD TL to AL Header credit of the received FC completion.
            .txcredhdrfcnp                            (tx_cred_hdrfcnp            ),                   //output  [7:0]   tx_cred_hdr_fc_np;      //PLD TL to AL Header credit of the received FC Non Posted
            .txcredhdrfcp                             (tx_cred_hdrfcp             ),                   //output  [7:0]   tx_cred_hdr_fc_p;       //PLD TL to AL Header credit of the received FC Posted.
            .txcredvc0                                (tx_cred_vc0                ),                   //output [35:0]   tx_cred_vc0;            //PLD
            .txdeemph0                                (txdeemph0               ),                           //output          tx_deemph0;             //PCS
            .txdeemph1                                (txdeemph1               ),                           //output          tx_deemph1;             //PCS
            .txdeemph2                                (txdeemph2               ),                           //output          tx_deemph2;             //PCS
            .txdeemph3                                (txdeemph3               ),                           //output          tx_deemph3;             //PCS
            .txdeemph4                                (txdeemph4               ),                           //output          tx_deemph4;             //PCS
            .txdeemph5                                (txdeemph5               ),                           //output          tx_deemph5;             //PCS
            .txdeemph6                                (txdeemph6               ),                           //output          tx_deemph6;             //PCS
            .txdeemph7                                (txdeemph7               ),                           //output          tx_deemph7;             //PCS
            .txfifoemptyvc0                           (tx_fifo_empty_vc0       ),                           //output          tx_fifo_empty_vc0;      //PLD
            .txfifofullvc0                            (tx_fifo_full_vc0        ),                           //output          tx_fifo_full_vc0;       //PLD
            .txfifordpvc0                             (tx_fifo_rdp_vc0         ),                           //output [3:0]    tx_fifo_rdp_vc0;        //PLD
            .txfifowrpvc0                             (tx_fifo_wrp_vc0         ),                           //output [3:0]    tx_fifo_wrp_vc0;        //PLD
            .txmargin0                                (txmargin0               ),                           //output [2:0]    tx_margin0;             //PCS
            .txmargin1                                (txmargin1               ),                           //output [2:0]    tx_margin1;             //PCS
            .txmargin2                                (txmargin2               ),                           //output [2:0]    tx_margin2;             //PCS
            .txmargin3                                (txmargin3               ),                           //output [2:0]    tx_margin3;             //PCS
            .txmargin4                                (txmargin4               ),                           //output [2:0]    tx_margin4;             //PCS
            .txmargin5                                (txmargin5               ),                           //output [2:0]    tx_margin5;             //PCS
            .txmargin6                                (txmargin6               ),                           //output [2:0]    tx_margin6;             //PCS
            .txmargin7                                (txmargin7               ),                           //output [2:0]    tx_margin7;             //PCS
            .txpcsrstn0                               (txpcsrstn[0]            ),                           //output          tx_pcs_rst_n0;          //PCS
            .txpcsrstn1                               (txpcsrstn[1]            ),                           //output          tx_pcs_rst_n1;          //PCS
            .txpcsrstn2                               (txpcsrstn[2]            ),                           //output          tx_pcs_rst_n2;          //PCS
            .txpcsrstn3                               (txpcsrstn[3]            ),                           //output          tx_pcs_rst_n3;          //PCS
            .txpcsrstn4                               (txpcsrstn[4]            ),                           //output          tx_pcs_rst_n4;          //PCS
            .txpcsrstn5                               (txpcsrstn[5]            ),                           //output          tx_pcs_rst_n5;          //PCS
            .txpcsrstn6                               (txpcsrstn[6]            ),                           //output          tx_pcs_rst_n6;          //PCS
            .txpcsrstn7                               (txpcsrstn[7]            ),                           //output          tx_pcs_rst_n7;          //PCS
            .txpcsrstn8                               (txpcsrstn[8]            ),                           //output          tx_pcs_rst_n8;          //PCS
            .txpmasyncp0                              (txpmasyncp[0]           ),                           //output          tx_pma_syncp0;          //PCS
            .txpmasyncp1                              (txpmasyncp[1]           ),                           //output          tx_pma_syncp1;          //PCS
            .txpmasyncp2                              (txpmasyncp[2]           ),                           //output          tx_pma_syncp2;          //PCS
            .txpmasyncp3                              (txpmasyncp[3]           ),                           //output          tx_pma_syncp3;          //PCS
            .txpmasyncp4                              (txpmasyncp[4]           ),                           //output          tx_pma_syncp4;          //PCS
            .txpmasyncp5                              (txpmasyncp[5]           ),                           //output          tx_pma_syncp5;          //PCS
            .txpmasyncp6                              (txpmasyncp[6]           ),                           //output          tx_pma_syncp6;          //PCS
            .txpmasyncp7                              (txpmasyncp[7]           ),                           //output          tx_pma_syncp7;          //PCS
            .txpmasyncp8                              (txpmasyncp[8]           ),                           //output          tx_pma_syncp8;          //PCS
            .txreadyvc0                               (tx_st_ready_vc0         ),                           //output          tx_ready_vc0;           //PLD
            .txcompl0                                 (txcompl0                ),                           //output          txcompl0;               //PCS
            .txcompl1                                 (txcompl1                ),                           //output          txcompl1;               //PCS
            .txcompl2                                 (txcompl2                ),                           //output          txcompl2;               //PCS
            .txcompl3                                 (txcompl3                ),                           //output          txcompl3;               //PCS
            .txcompl4                                 (txcompl4                ),                           //output          txcompl4;               //PCS
            .txcompl5                                 (txcompl5                ),                           //output          txcompl5;               //PCS
            .txcompl6                                 (txcompl6                ),                           //output          txcompl6;               //PCS
            .txcompl7                                 (txcompl7                ),                           //output          txcompl7;               //PCS
            //PIPE signals between PCS and HIP
            .txdata0                                  (txdata0                 ),                           //output [7:0]    txdata0;                //PCS
            .txdata1                                  (txdata1                 ),                           //output [7:0]    txdata1;                //PCS
            .txdata2                                  (txdata2                 ),                           //output [7:0]    txdata2;                //PCS
            .txdata3                                  (txdata3                 ),                           //output [7:0]    txdata3;                //PCS
            .txdata4                                  (txdata4                 ),                           //output [7:0]    txdata4;                //PCS
            .txdata5                                  (txdata5                 ),                           //output [7:0]    txdata5;                //PCS
            .txdata6                                  (txdata6                 ),                           //output [7:0]    txdata6;                //PCS
            .txdata7                                  (txdata7                 ),                           //output [7:0]    txdata7;                //PCS
            .txdatak0                                 (txdatak0                ),                           //output          txdatak0;               //PCS
            .txdatak1                                 (txdatak1                ),                           //output          txdatak1;               //PCS
            .txdatak2                                 (txdatak2                ),                           //output          txdatak2;               //PCS
            .txdatak3                                 (txdatak3                ),                           //output          txdatak3;               //PCS
            .txdatak4                                 (txdatak4                ),                           //output          txdatak4;               //PCS
            .txdatak5                                 (txdatak5                ),                           //output          txdatak5;               //PCS
            .txdatak6                                 (txdatak6                ),                           //output          txdatak6;               //PCS
            .txdatak7                                 (txdatak7                ),                           //output          txdatak7;               //PCS
            .txdetectrx0                              (txdetectrx0             ),                           //output          txdetectrx0;            //PCS
            .txdetectrx1                              (txdetectrx1             ),                           //output          txdetectrx1;            //PCS
            .txdetectrx2                              (txdetectrx2             ),                           //output          txdetectrx2;            //PCS
            .txdetectrx3                              (txdetectrx3             ),                           //output          txdetectrx3;            //PCS
            .txdetectrx4                              (txdetectrx4             ),                           //output          txdetectrx4;            //PCS
            .txdetectrx5                              (txdetectrx5             ),                           //output          txdetectrx5;            //PCS
            .txdetectrx6                              (txdetectrx6             ),                           //output          txdetectrx6;            //PCS
            .txdetectrx7                              (txdetectrx7             ),                           //output          txdetectrx7;            //PCS
            .txelecidle0                              (txelecidle0             ),                           //output          txelecidle0;            //PCS
            .txelecidle1                              (txelecidle1             ),                           //output          txelecidle1;            //PCS
            .txelecidle2                              (txelecidle2             ),                           //output          txelecidle2;            //PCS
            .txelecidle3                              (txelecidle3             ),                           //output          txelecidle3;            //PCS
            .txelecidle4                              (txelecidle4             ),                           //output          txelecidle4;            //PCS
            .txelecidle5                              (txelecidle5             ),                           //output          txelecidle5;            //PCS
            .txelecidle6                              (txelecidle6             ),                           //output          txelecidle6;            //PCS
            .txelecidle7                              (txelecidle7             ),                           //output          txelecidle7;            //PCS
            .txswing0                                 (txswing0                ),                           //output          txswing0;               //PCS-PMA
            .txswing1                                 (txswing1                ),                           //output          txswing1;               //PCS-PMA
            .txswing2                                 (txswing2                ),                           //output          txswing2;               //PCS-PMA
            .txswing3                                 (txswing3                ),                           //output          txswing3;               //PCS-PMA
            .txswing4                                 (txswing4                ),                           //output          txswing4;               //PCS-PMA
            .txswing5                                 (txswing5                ),                           //output          txswing5;               //PCS-PMA
            .txswing6                                 (txswing6                ),                           //output          txswing6;               //PCS-PMA
            .txswing7                                 (txswing7                ),                           //output          txswing7;               //PCS-PMA
            .wakeoen                                  (wakeoen                 )                            //output          wake_oen;               //PLD
               );

      end
      else begin

            // synthesis translate_off
               arriav_hd_altpe2_hip_top_simu_only_dump arriav_hd_altpe2_hip_top_simu_only_dump (
                     .rx_val_dl           (arriav_hd_altpe2_hip_top.inst.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.rx_val_dl             ),
                     .rx_data_dl          (arriav_hd_altpe2_hip_top.inst.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.rx_data_dl [63:0]     ),
                     .rx_datak_dl         (arriav_hd_altpe2_hip_top.inst.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.rx_datak_dl[7:0]      ),
                     .txok                (arriav_hd_altpe2_hip_top.inst.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.txok   ),
                     .sop                 (arriav_hd_altpe2_hip_top.inst.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.sop    ),
                     .eop                 (arriav_hd_altpe2_hip_top.inst.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.eop    ),
                     .eot                 (arriav_hd_altpe2_hip_top.inst.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.eot    ),
                     .tdata               (arriav_hd_altpe2_hip_top.inst.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.tdata  [63:0]),
                     .tdatak              (arriav_hd_altpe2_hip_top.inst.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.tdatak [7:0] ),
                     .rx_data_tlp_tl      (arriav_hd_altpe2_hip_top.inst.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.rx_data_tlp_tl  [63:0]),
                     .rx_dval_tlp_tl      (arriav_hd_altpe2_hip_top.inst.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.rx_dval_tlp_tl        ),
                     .rx_fval_tlp_tl      (arriav_hd_altpe2_hip_top.inst.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.rx_fval_tlp_tl        ),
                     .rx_hval_tlp_tl      (arriav_hd_altpe2_hip_top.inst.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.rx_hval_tlp_tl        ),
                     .rx_mlf_tlp_tl       (arriav_hd_altpe2_hip_top.inst.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.rx_mlf_tlp_tl         ),
                     .rx_ecrcerr_tlp_tl   (arriav_hd_altpe2_hip_top.inst.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.rx_ecrcerr_tlp_tl     ),
                     .rx_discard_tlp_tl   (arriav_hd_altpe2_hip_top.inst.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.rx_discard_tlp_tl     ),
                     .rx_check_tlp_tl     (arriav_hd_altpe2_hip_top.inst.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.rx_check_tlp_tl       ),
                     .rx_ok_tlp_tl        (arriav_hd_altpe2_hip_top.inst.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.rx_ok_tlp_tl          ),
                     .rx_err_tlp_tl       (arriav_hd_altpe2_hip_top.inst.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.rx_err_tlp_tl         ),
                     .tx_req_tlp_tl       (arriav_hd_altpe2_hip_top.inst.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.tx_req_tlp_tl         ),
                     .tx_ack_tlp_tl       (arriav_hd_altpe2_hip_top.inst.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.tx_ack_tlp_tl         ),
                     .tx_dreq_tlp_tl      (arriav_hd_altpe2_hip_top.inst.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.tx_dreq_tlp_tl        ),
                     .tx_err_tlp_tl       (arriav_hd_altpe2_hip_top.inst.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.tx_err_tlp_tl         ),
                     .tx_data_tlp_tl      (arriav_hd_altpe2_hip_top.inst.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.tx_data_tlp_tl[63:0]  ),
                     .clk                 (arriav_hd_altpe2_hip_top.inst.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.clk              ),
                     .rstn                (arriav_hd_altpe2_hip_top.inst.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.rstn             ),
                     .srst                (arriav_hd_altpe2_hip_top.inst.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.srst             ),
                     .ev128ns             (arriav_hd_altpe2_hip_top.inst.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.ev128ns          ),
                     .dl_up               (arriav_hd_altpe2_hip_top.inst.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.dl_up            ),
                     .err_dll             (arriav_hd_altpe2_hip_top.inst.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.err_dll          ),
                     .rx_err_frame        (arriav_hd_altpe2_hip_top.inst.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.rx_err_frame     ),
                     .lane_act            (arriav_hd_altpe2_hip_top.inst.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.lane_act         ),
                     .l0state             (arriav_hd_altpe2_hip_top.inst.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.l0state          ),
                     .l0sstate            (arriav_hd_altpe2_hip_top.inst.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.l0sstate         ),
                     .link_up             (arriav_hd_altpe2_hip_top.inst.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.link_up          ),
                     .link_train          (arriav_hd_altpe2_hip_top.inst.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.link_train       ),
                     .test_ltssm          (arriav_hd_altpe2_hip_top.inst.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.test_ltssm       ),
                     .rx_val_fc           (arriav_hd_altpe2_hip_top.inst.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.rx_val_fc       ),
                     .rx_val_fc_real      (arriav_hd_altpe2_hip_top.inst.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.rx_val_fc_real  ),
                     .rx_ini_fc           (arriav_hd_altpe2_hip_top.inst.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.rx_ini_fc       ),
                     .rx_ini_fc_real      (arriav_hd_altpe2_hip_top.inst.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.rx_ini_fc_real  ),
                     .rx_typ_fc           (arriav_hd_altpe2_hip_top.inst.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.rx_typ_fc       ),
                     .rx_vcid_fc          (arriav_hd_altpe2_hip_top.inst.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.rx_vcid_fc      ),
                     .rx_hdr_fc           (arriav_hd_altpe2_hip_top.inst.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.rx_hdr_fc       ),
                     .rx_data_fc          (arriav_hd_altpe2_hip_top.inst.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.rx_data_fc      ),
                     .req_upfc            (arriav_hd_altpe2_hip_top.inst.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.req_upfc        ),
                     .snd_upfc            (arriav_hd_altpe2_hip_top.inst.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.snd_upfc        ),
                     .ack_upfc            (arriav_hd_altpe2_hip_top.inst.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.ack_upfc        ),
                     .ack_snd_upfc        (arriav_hd_altpe2_hip_top.inst.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.ack_snd_upfc    ),
                     .ack_req_upfc        (arriav_hd_altpe2_hip_top.inst.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.ack_req_upfc    ),
                     .typ_upfc            (arriav_hd_altpe2_hip_top.inst.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.typ_upfc  [1:0] ),
                     .vcid_upfc           (arriav_hd_altpe2_hip_top.inst.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.vcid_upfc [2:0] ),
                     .hdr_upfc            (arriav_hd_altpe2_hip_top.inst.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.hdr_upfc  [7:0] ),
                     .data_upfc           (arriav_hd_altpe2_hip_top.inst.hd_altpe2_hip_top_inst.pciexp_top_hip_1.core.core_inst.dlink.data_upfc [11:0]));
            // synthesis translate_on

         arriav_hd_altpe2_hip_top # (
            .func_mode                                (func_mode),
            .bonding_mode                             (bonding_mode),
            .prot_mode                                (prot_mode),
                 //.sup_mode                                 (),
            .cvp_enable                               (cvp_enable),
                 //.pcie_spec_1p0_compliance                 (),
            .vc_enable                                (vc_enable),
            .enable_slot_register                     (enable_slot_register),
            .pcie_mode                                (pcie_mode),
            .bypass_cdc                               (bypass_cdc), // Note: A5 only close timing on CDC ENABLED mode. Check rbc
                 //.cdc_clk_relation                         (),
            .enable_rx_reordering                     (enable_rx_reordering),
            .enable_rx_buffer_checking                (enable_rx_buffer_checking),
            .single_rx_detect_data                    (single_rx_detect),
            .use_crc_forwarding                       ((low_str(use_aer_0) == "false") ? "false" : use_crc_forwarding),
            .bypass_tl                                (bypass_tl),
            .gen12_lane_rate_mode                     (gen12_lane_rate_mode),
            .lane_mask                                (lane_mask),
            .disable_link_x2_support                  (disable_link_x2_support),
            .national_inst_thru_enhance               (national_inst_thru_enhance),
            .disable_tag_check                        (disable_tag_check),
            .multi_function                           ((low_str(func_mode) == "enable") ? multi_function : "one_func" ),
            .port_link_number_data                    (port_link_number),
            .device_number_data                       (device_number),
            .bypass_clk_switch                        (bypass_clk_switch),
            .disable_clk_switch                       (disable_clk_switch),
            .core_clk_disable_clk_switch              (core_clk_disable_clk_switch),
            .core_clk_out_sel                         (core_clk_out_sel),
            .core_clk_divider                         (core_clk_divider),
            .core_clk_source                          (core_clk_source),
            .core_clk_sel                             ((low_str(bypass_clk_switch) == "enable") ? "pld_clk" : core_clk_sel),
            .enable_ch0_pclk_out                      (enable_ch0_pclk_out),
            .enable_ch01_pclk_out                     (enable_ch01_pclk_out),
            .pipex1_debug_sel                         (pipex1_debug_sel),
            .pclk_out_sel                             (pclk_out_sel),

            .bridge_66mhzcap                          (bridge_66mhzcap),
            .fastb2bcap                               (fastb2bcap),
            .devseltim                                (devseltim),
            .lattim_ro_data                           (lattim_ro_data   ),
            .lattim                                   (lattim           ),
            .memwrinv                                 ((low_str(func_mode)=="enable") ? "rw" : memwrinv),
            .br_rcb                                   ((low_str(func_mode)=="enable") ? "rw" : br_rcb),
            .rxfreqlk_cnt_en                          (rxfreqlk_cnt_en  ),
            .rxfreqlk_cnt_data                        (rxfreqlk_cnt),
            .enable_adapter_half_rate_mode            (enable_adapter_half_rate_mode),
            .vc0_clk_enable                           (vc0_clk_enable),
            .vc1_clk_enable                           (vc1_clk_enable),
            .register_pipe_signals                    (register_pipe_signals),

            .no_soft_reset_0                          (no_soft_reset),

            //Func0 - Device Identification Registers
            .vendor_id_data_0                         (vendor_id_0),
            .device_id_data_0                         (device_id_0),
            .revision_id_data_0                       (revision_id_0),
            .class_code_data_0                        (class_code_0),
            .subsystem_vendor_id_data_0               (subsystem_vendor_id_0),
            .subsystem_device_id_data_0               (subsystem_device_id_0),
            .intel_id_access_0                        (intel_id_access),

            //Func 0 - BARs
            .bar0_io_space_0                          (bar0_io_space_0),
            .bar0_64bit_mem_space_0                   (bar0_64bit_mem_space_0),
            .bar0_prefetchable_0                      (bar0_prefetchable_0),
            .bar0_size_mask_data_0                    (bar0_size_mask_0),
            .bar1_io_space_0                          (bar1_io_space_0),
            .bar1_64bit_mem_space_0                   (bar1_64bit_mem_space_0),
            .bar1_prefetchable_0                      (bar1_prefetchable_0),
            .bar1_size_mask_data_0                    (bar1_size_mask_0),
            .bar2_io_space_0                          (bar2_io_space_0),
            .bar2_64bit_mem_space_0                   (bar2_64bit_mem_space_0),
            .bar2_prefetchable_0                      (bar2_prefetchable_0),
            .bar2_size_mask_data_0                    (bar2_size_mask_0),
            .bar3_io_space_0                          (bar3_io_space_0),
            .bar3_64bit_mem_space_0                   (bar3_64bit_mem_space_0),
            .bar3_prefetchable_0                      (bar3_prefetchable_0),
            .bar3_size_mask_data_0                    (bar3_size_mask_0),
            .bar4_io_space_0                          (bar4_io_space_0),
            .bar4_64bit_mem_space_0                   (bar4_64bit_mem_space_0),
            .bar4_prefetchable_0                      (bar4_prefetchable_0),
            .bar4_size_mask_data_0                    (bar4_size_mask_0),
            .bar5_io_space_0                          (bar5_io_space_0),
            .bar5_64bit_mem_space_0                   (bar5_64bit_mem_space_0),
            .bar5_prefetchable_0                      (bar5_prefetchable_0),
            .bar5_size_mask_data_0                    (bar5_size_mask_0),

            .device_specific_init_0                   (device_specific_init_0),
            .maximum_current_data_0                   (maximum_current_0),
            .d1_support_0                             (d1_support),
            .d2_support_0                             (d2_support),
            .d0_pme_0                                 (d0_pme),
            .d1_pme_0                                 (d1_pme),
            .d2_pme_0                                 (d2_pme),
            .d3_hot_pme_0                             (d3_hot_pme),
            .d3_cold_pme_0                            (d3_cold_pme),
            .use_aer_0                                (use_aer_0),
            .low_priority_vc_0                        (low_priority_vc),
            .vc_arbitration_0                         (vc_arbitration),
            .disable_snoop_packet_0                   (disable_snoop_packet_0),

            .max_payload_size_0                       (max_payload_size_0),
            .extend_tag_field_0                       (extend_tag_field_0),
            .completion_timeout_0                     (completion_timeout_0),
            .enable_completion_timeout_disable_0      (enable_completion_timeout_disable_0),

            .surprise_down_error_support_0            (surprise_down_error_support_0),
            .dll_active_report_support_0              (dll_active_report_support_0),

            .rx_ei_l0s_0                              (rx_ei_l0s_0),
            .endpoint_l0_latency_data_0               (endpoint_l0_latency_0),
            .endpoint_l1_latency_data_0               (endpoint_l1_latency_0),

            .indicator_data_0                         (indicator),
            .role_based_error_reporting_0             (role_based_error_reporting),
            .max_link_width_0                         (lane_mask),

            .aspm_optionality_0                       (aspm_optionality),
            .enable_l1_aspm_0                         (enable_l1_aspm),
            .enable_l0s_aspm_0                        (enable_l0s_aspm),

            .l1_exit_latency_sameclock_data_0         (l1_exit_latency_sameclock),
            .l1_exit_latency_diffclock_data_0         (l1_exit_latency_diffclock),
            .l0_exit_latency_sameclock_data_0         (l0_exit_latency_sameclock),
            .l0_exit_latency_diffclock_data_0         (l0_exit_latency_diffclock),

            .hot_plug_support_data_0                  (hot_plug_support),

            .slot_power_scale_data_0                  (slot_power_scale_0),
            .slot_power_limit_data_0                  (slot_power_limit_0),
            .slot_number_data_0                       (slot_number_0),

            //      .electromech_interlock_0                  (),
            .diffclock_nfts_count_data_0              (diffclock_nfts_count),
            .sameclock_nfts_count_data_0              (sameclock_nfts_count),

            .ecrc_check_capable_0                     (ecrc_check_capable_0),
            .ecrc_gen_capable_0                       (ecrc_gen_capable_0),
            .no_command_completed_0                   (no_command_completed),

            .msi_multi_message_capable_0              (msi_multi_message_capable_0),
            .msi_64bit_addressing_capable_0           (msi_64bit_addressing_capable_0),
            .msi_masking_capable_0                    (msi_masking_capable_0),
            .msi_support_0                            (msi_support_0),
            .interrupt_pin_0                          (interrupt_pin_0),
            .enable_function_msix_support_0           (enable_function_msix_support_0),
            .msix_table_size_data_0                   (msix_table_size_0),
            .msix_table_bir_data_0                    (msix_table_bir_0),
            .msix_table_offset_data_0                 (msix_table_offset_0),
            .msix_pba_bir_data_0                      (msix_pba_bir_0),
            .msix_pba_offset_data_0                   (msix_pba_offset_0),

            .bridge_port_vga_enable_0                 (bridge_port_vga_enable_0   ),
            .bridge_port_ssid_support_0               (bridge_port_ssid_support_0 ),
            .ssvid_data_0                             (ssvid_0),
            .ssid_data_0                              (ssid_0),
            .eie_before_nfts_count_data_0             (eie_before_nfts_count),
            .gen2_diffclock_nfts_count_data_0         (gen2_diffclock_nfts_count),
            .gen2_sameclock_nfts_count_data_0         (gen2_sameclock_nfts_count),
            .deemphasis_enable_0                      (deemphasis_enable),
            .pcie_spec_version_0                      (pcie_spec_version),
            .l2_async_logic_0                         (l2_async_logic),
            .flr_capability_0                         (flr_capability_0),

            .expansion_base_address_register_data_0   (expansion_base_address_register_0),

            .io_window_addr_width_0                   (io_window_addr_width),
            .prefetchable_mem_window_addr_width_0     (prefetchable_mem_window_addr_width),

            .rx_cdc_almost_full_data                  (rx_cdc_almost_full),
            .tx_cdc_almost_full_data                  (tx_cdc_almost_full),
            .rx_l0s_count_idl_data                    (rx_l0s_count_idl),
            .cdc_dummy_insert_limit_data              (cdc_dummy_insert_limit),
            .ei_delay_powerdown_count_data            (ei_delay_powerdown_count),
            .millisecond_cycle_count_data             (millisecond_cycle_count),
            .skp_os_schedule_count_data               (skp_os_schedule_count),
            .fc_init_timer_data                       (fc_init_timer),
            .l01_entry_latency_data                   (l01_entry_latency),
            .flow_control_update_count_data           (flow_control_update_count),
            .flow_control_timeout_count_data          (flow_control_timeout_count),
            .vc0_rx_flow_ctrl_posted_header_data      (vc0_rx_flow_ctrl_posted_header),
            .vc0_rx_flow_ctrl_posted_data_data        (vc0_rx_flow_ctrl_posted_data),
            .vc0_rx_flow_ctrl_nonposted_header_data   (vc0_rx_flow_ctrl_nonposted_header),
            .vc0_rx_flow_ctrl_nonposted_data_data     (vc0_rx_flow_ctrl_nonposted_data),
            .vc0_rx_flow_ctrl_compl_header_data       (vc0_rx_flow_ctrl_compl_header),
            .vc0_rx_flow_ctrl_compl_data_data         (vc0_rx_flow_ctrl_compl_data),
            .rx_ptr0_posted_dpram_min_data            (rx_ptr0_posted_dpram_min),
            .rx_ptr0_posted_dpram_max_data            (rx_ptr0_posted_dpram_max),
            .rx_ptr0_nonposted_dpram_min_data         (rx_ptr0_nonposted_dpram_min),
            .rx_ptr0_nonposted_dpram_max_data         (rx_ptr0_nonposted_dpram_max),
            .retry_buffer_last_active_address_data    (retry_buffer_last_active_address),
            .retry_buffer_memory_settings_data        (retry_buffer_memory_settings),
            .vc0_rx_buffer_memory_settings_data       (vc0_rx_buffer_memory_settings),
            .bist_memory_settings_data                (bist_memory_settings),
            .credit_buffer_allocation_aux             (credit_buffer_allocation_aux),
            .iei_enable_settings                      (iei_enable_settings),
            .vsec_id_data                             (vsec_id),
            .hard_reset_bypass                        (hard_reset_bypass),
            .cvp_rate_sel                             ((low_str(cvp_enable) == "cvp_en") ? cvp_rate_sel : "full_rate" ),
            .cvp_data_compressed                      ((low_str(cvp_enable) == "cvp_en") ? cvp_data_compressed : "false"),
            .cvp_data_encrypted                       ((low_str(cvp_enable) == "cvp_en") ? cvp_data_encrypted : "false"),
            .cvp_mode_reset                           ((low_str(cvp_enable) == "cvp_en") ? cvp_mode_reset : "false"),
            .cvp_clk_reset                            ((low_str(cvp_enable) == "cvp_en") ? cvp_clk_reset : "false"),
            .cvp_isolation                            ((low_str(cvp_enable) == "cvp_en") ? "disable" : "enable"),
            .vsec_cap_data                            (vsec_cap),
            .jtag_id_data                             (jtag_id),
            .user_id_data                             (user_id),

            .hrdrstctrl_en                            ((USE_HARD_RESET==0)?"hrdrstctrl_dis" : hrdrstctrl_en ),
            .rstctrl_debug_en                         ((USE_HARD_RESET==0)?"false"                 :rstctrl_debug_en                   ),
            .rstctrl_rx_pma_rstb_inv                  ((USE_HARD_RESET==0)?"false"                 :rstctrl_rx_pma_rstb_inv            ),
            .rstctrl_tx_pma_rstb_inv                  ((USE_HARD_RESET==0)?"false"                 :rstctrl_tx_pma_rstb_inv            ),
            .rstctrl_rx_pcs_rst_n_inv                 ((USE_HARD_RESET==0)?"false"                 :rstctrl_rx_pcs_rst_n_inv           ),
            .rstctrl_tx_pcs_rst_n_inv                 ((USE_HARD_RESET==0)?"false"                 :rstctrl_tx_pcs_rst_n_inv           ),
            .rstctrl_altpe2_crst_n_inv                ((USE_HARD_RESET==0)?"false"                 :rstctrl_altpe2_crst_n_inv          ),
            .rstctrl_altpe2_srst_n_inv                ((USE_HARD_RESET==0)?"false"                 :rstctrl_altpe2_srst_n_inv          ),
            .rstctrl_altpe2_rst_n_inv                 ((USE_HARD_RESET==0)?"false"                 :rstctrl_altpe2_rst_n_inv           ),
            .rstctrl_tx_pma_syncp_inv                 ((USE_HARD_RESET==0)?"false"                 :rstctrl_tx_pma_syncp_inv           ),
            .rstctrl_perst_enable                     ((USE_HARD_RESET==0)?"level"                 :rstctrl_perst_enable               ),
            .rstctrl_hard_block_enable                ((USE_HARD_RESET==0)?"pld_rst_ctl"           :rstctrl_hard_block_enable          ),
            .rstctrl_perstn_select                    ((USE_HARD_RESET==0)?"perstn_pin"            :rstctrl_perstn_select              ),
            .rstctrl_hip_ep                           ((USE_HARD_RESET==0)?"hip_not_ep"            :rstctrl_hip_ep                     ),
            .rstctrl_pld_clr                          ((USE_HARD_RESET==0)?"false"                 :rstctrl_pld_clr                    ),
            .rstctrl_force_inactive_rst               ((USE_HARD_RESET==0)?"false"                 :rstctrl_force_inactive_rst         ),
            .rstctrl_timer_a_type                     ((USE_HARD_RESET==0)?"not_enabled"           :rstctrl_timer_a_type               ),
            .rstctrl_timer_a_value                    ((USE_HARD_RESET==0)?8'h1                    :rstctrl_timer_a_value              ),
            .rstctrl_timer_a                          ((USE_HARD_RESET==0)?"rstctrl_timer_a"       :rstctrl_timer_a                    ),
            .rstctrl_timer_b_type                     ((USE_HARD_RESET==0)?"not_enabled"           :rstctrl_timer_b_type               ),
            .rstctrl_timer_b_value                    ((USE_HARD_RESET==0)?8'h1                    :rstctrl_timer_b_value              ),
            .rstctrl_timer_b                          ((USE_HARD_RESET==0)?"rstctrl_timer_b"       :rstctrl_timer_b                    ),
            .rstctrl_timer_c_type                     ((USE_HARD_RESET==0)?"not_enabled"           :rstctrl_timer_c_type               ),
            .rstctrl_timer_c_value                    ((USE_HARD_RESET==0)?8'h1                    :rstctrl_timer_c_value              ),
            .rstctrl_timer_c                          ((USE_HARD_RESET==0)?"rstctrl_timer_c"       :rstctrl_timer_c                    ),
            .rstctrl_timer_d_type                     ((USE_HARD_RESET==0)?"not_enabled"           :rstctrl_timer_d_type               ),
            .rstctrl_timer_d_value                    ((USE_HARD_RESET==0)?8'h1                    :rstctrl_timer_d_value              ),
            .rstctrl_timer_d                          ((USE_HARD_RESET==0)?"rstctrl_timer_d"       :rstctrl_timer_d                    ),
            .rstctrl_timer_e_type                     ((USE_HARD_RESET==0)?"not_enabled"           :rstctrl_timer_e_type               ),
            .rstctrl_timer_e_value                    ((USE_HARD_RESET==0)?8'h1                    :rstctrl_timer_e_value              ),
            .rstctrl_timer_e                          ((USE_HARD_RESET==0)?"rstctrl_timer_e"       :rstctrl_timer_e                    ),
            .rstctrl_timer_f_type                     ((USE_HARD_RESET==0)?"not_enabled"           :rstctrl_timer_f_type               ),
            .rstctrl_timer_f_value                    ((USE_HARD_RESET==0)?8'h1                    :rstctrl_timer_f_value              ),
            .rstctrl_timer_f                          ((USE_HARD_RESET==0)?"rstctrl_timer_f"       :rstctrl_timer_f                    ),
            .rstctrl_timer_g_type                     ((USE_HARD_RESET==0)?"not_enabled"           :rstctrl_timer_g_type               ),
            .rstctrl_timer_g_value                    ((USE_HARD_RESET==0)?8'h1                    :rstctrl_timer_g_value              ),
            .rstctrl_timer_g                          ((USE_HARD_RESET==0)?"rstctrl_timer_g"       :rstctrl_timer_g                    ),
            .rstctrl_timer_h_type                     ((USE_HARD_RESET==0)?"not_enabled"           :rstctrl_timer_h_type               ),
            .rstctrl_timer_h_value                    ((USE_HARD_RESET==0)?8'h1                    :rstctrl_timer_h_value              ),
            .rstctrl_timer_h                          ((USE_HARD_RESET==0)?"rstctrl_timer_h"       :rstctrl_timer_h                    ),
            .rstctrl_timer_i_type                     ((USE_HARD_RESET==0)?"not_enabled"           :rstctrl_timer_i_type               ),
            .rstctrl_timer_i_value                    ((USE_HARD_RESET==0)?8'h1                    :rstctrl_timer_i_value              ),
            .rstctrl_timer_i                          ((USE_HARD_RESET==0)?"rstctrl_timer_i"       :rstctrl_timer_i                    ),
            .rstctrl_timer_j_type                     ((USE_HARD_RESET==0)?"not_enabled"           :rstctrl_timer_j_type               ),
            .rstctrl_timer_j_value                    ((USE_HARD_RESET==0)?8'h1                    :rstctrl_timer_j_value              ),
            .rstctrl_timer_j                          ((USE_HARD_RESET==0)?"rstctrl_timer_j"       :rstctrl_timer_j                    ),
            .rstctrl_1ms_count_fref_clk_value         ((USE_HARD_RESET==0)?20'b00001111010000100100:rstctrl_1ms_count_fref_clk_value   ),
            .rstctrl_1ms_count_fref_clk               ((USE_HARD_RESET==0)?"rstctrl_1ms_cnt"       :rstctrl_1ms_count_fref_clk         ),
            .rstctrl_1us_count_fref_clk_value         ((USE_HARD_RESET==0)?20'b00000000000000111111:rstctrl_1us_count_fref_clk_value   ),
            .rstctrl_1us_count_fref_clk               ((USE_HARD_RESET==0)?"rstctrl_1us_cnt"       :rstctrl_1us_count_fref_clk         ),
            .rstctrl_tx_pcs_rst_n_select              ((USE_HARD_RESET==0)?"not_active"            :rstctrl_tx_pcs_rst_n_select        ),
            .rstctrl_rx_pcs_rst_n_select              ((USE_HARD_RESET==0)?"not_active"            :rstctrl_rx_pcs_rst_n_select        ),
            .rstctrl_rx_pma_rstb_cmu_select           ((USE_HARD_RESET==0)?"not_active"            :rstctrl_rx_pma_rstb_cmu_select     ),
            .rstctrl_rx_pma_rstb_select               ((USE_HARD_RESET==0)?"not_active"            :rstctrl_rx_pma_rstb_select         ),
            .rstctrl_tx_lc_pll_rstb_select            ((USE_HARD_RESET==0)?"not_active"            :rstctrl_tx_lc_pll_rstb_select      ),
            .rstctrl_off_cal_en_select                ((USE_HARD_RESET==0)?"not_active"            :rstctrl_off_cal_en_select          ),
            .rstctrl_fref_clk_select                  ((USE_HARD_RESET==0)?"ch0_sel"               :rstctrl_fref_clk_select            ),
            .rstctrl_off_cal_done_select              ((USE_HARD_RESET==0)?"not_active"            :rstctrl_off_cal_done_select        ),
            .rstctrl_tx_lc_pll_lock_select            ((USE_HARD_RESET==0)?"not_active"            :rstctrl_tx_lc_pll_lock_select      ),
            .rstctrl_tx_cmu_pll_lock_select           ((USE_HARD_RESET==0)?"not_active"            :rstctrl_tx_cmu_pll_lock_select     ),
            .rstctrl_rx_pll_freq_lock_select          ((USE_HARD_RESET==0)?"not_active"            :rstctrl_rx_pll_freq_lock_select    ),
            .rstctrl_rx_pll_lock_select               ((USE_HARD_RESET==0)?"not_active"            :rstctrl_rx_pll_lock_select         ),
            .rstctrl_mask_tx_pll_lock_select          ((USE_HARD_RESET==0)?"not_active"            :rstctrl_mask_tx_pll_lock_select    ),
            .rstctrl_tx_pma_syncp_select              ((USE_HARD_RESET==0)?"not_active"            :rstctrl_tx_pma_syncp_select        ),
            .rstctrl_ltssm_disable                    ((USE_HARD_RESET==0)?"disable"               :rstctrl_ltssm_disable              ),

            .slotclk_cfg                              (slotclk_cfg),
            .skp_insertion_control                    (skp_insertion_control),
            .testmode_control                         ((low_str(func_mode)=="enable") ? testmode_control : "disable"),
            .tx_swing_data                            (tx_swing_data),
            .tx_l0s_adjust                            (tx_l0s_adjust),
            .disable_auto_crs                         (disable_auto_crs),
            .no_soft_reset_1                          (no_soft_reset),

            //Func 1 - Device Identification Registers
            .vendor_id_data_1                         (vendor_id_1),
            .device_id_data_1                         (device_id_1),
            .revision_id_data_1                       (revision_id_1),
            .class_code_data_1                        (class_code_1),
            .subsystem_vendor_id_data_1               (subsystem_vendor_id_1),
            .subsystem_device_id_data_1               (subsystem_device_id_1),
            .intel_id_access_1                        (intel_id_access),
            //Func 1 - BARs
            .bar0_io_space_1                          (bar0_io_space_1),
            .bar0_64bit_mem_space_1                   (bar0_64bit_mem_space_1),
            .bar0_prefetchable_1                      (bar0_prefetchable_1),
            .bar0_size_mask_data_1                    (bar0_size_mask_1),
            .bar1_io_space_1                          (bar1_io_space_1),
            .bar1_64bit_mem_space_1                   (bar1_64bit_mem_space_1),
            .bar1_prefetchable_1                      (bar1_prefetchable_1),
            .bar1_size_mask_data_1                    (bar1_size_mask_1),
            .bar2_io_space_1                          (bar2_io_space_1),
            .bar2_64bit_mem_space_1                   (bar2_64bit_mem_space_1),
            .bar2_prefetchable_1                      (bar2_prefetchable_1),
            .bar2_size_mask_data_1                    (bar2_size_mask_1),
            .bar3_io_space_1                          (bar3_io_space_1),
            .bar3_64bit_mem_space_1                   (bar3_64bit_mem_space_1),
            .bar3_prefetchable_1                      (bar3_prefetchable_1),
            .bar3_size_mask_data_1                    (bar3_size_mask_1),
            .bar4_io_space_1                          (bar4_io_space_1),
            .bar4_64bit_mem_space_1                   (bar4_64bit_mem_space_1),
            .bar4_prefetchable_1                      (bar4_prefetchable_1),
            .bar4_size_mask_data_1                    (bar4_size_mask_1),
            .bar5_io_space_1                          (bar5_io_space_1),
            .bar5_64bit_mem_space_1                   (bar5_64bit_mem_space_1),
            .bar5_prefetchable_1                      (bar5_prefetchable_1),
            .bar5_size_mask_data_1                    (bar5_size_mask_1),

            .device_specific_init_1                   (device_specific_init_1),
            .maximum_current_data_1                   (maximum_current_1),
            .d1_support_1                             (d1_support),
            .d2_support_1                             (d2_support),
            .d0_pme_1                                 (d0_pme),
            .d1_pme_1                                 (d1_pme),
            .d2_pme_1                                 (d2_pme),
            .d3_hot_pme_1                             (d3_hot_pme),
            .d3_cold_pme_1                            (d3_cold_pme),
            .use_aer_1                                (use_aer_1),
            .low_priority_vc_1                        (low_priority_vc_1),
            .vc_arbitration_1                         (vc_arbitration),
            .disable_snoop_packet_1                   (disable_snoop_packet_1),

            .max_payload_size_1                       (max_payload_size_1),
            .extend_tag_field_1                       (extend_tag_field_1),
            .completion_timeout_1                     (completion_timeout_1),
            .enable_completion_timeout_disable_1      (enable_completion_timeout_disable_1),

            .surprise_down_error_support_1            (surprise_down_error_support_1),
            .dll_active_report_support_1              (dll_active_report_support_1),

            .rx_ei_l0s_1                              (rx_ei_l0s_1),
            .endpoint_l0_latency_data_1               (endpoint_l0_latency_1),
            .endpoint_l1_latency_data_1               (endpoint_l1_latency_1),

            .indicator_data_1                         (indicator_1),
            .role_based_error_reporting_1             (role_based_error_reporting),
            .max_link_width_1                         (lane_mask),

            .aspm_optionality_1                       (aspm_optionality),
            .enable_l1_aspm_1                         (enable_l1_aspm),
            .enable_l0s_aspm_1                        (enable_l0s_aspm),

            .l1_exit_latency_sameclock_data_1         (l1_exit_latency_sameclock),
            .l1_exit_latency_diffclock_data_1         (l1_exit_latency_diffclock),
            .l0_exit_latency_sameclock_data_1         (l0_exit_latency_sameclock),
            .l0_exit_latency_diffclock_data_1         (l0_exit_latency_diffclock),

            .hot_plug_support_data_1                  (hot_plug_support_1),

            .slot_power_scale_data_1                  (slot_power_scale_1),
            .slot_power_limit_data_1                  (slot_power_limit_1),
            .slot_number_data_1                       (slot_number_1),

      //      .electromech_interlock_1                  (),
            .diffclock_nfts_count_data_1              (diffclock_nfts_count),
            .sameclock_nfts_count_data_1              (sameclock_nfts_count),

            .ecrc_check_capable_1                     (ecrc_check_capable_1),
            .ecrc_gen_capable_1                       (ecrc_gen_capable_1),

            .no_command_completed_1                   (no_command_completed_1),

            .msi_multi_message_capable_1              (msi_multi_message_capable_1),
            .msi_64bit_addressing_capable_1           (msi_64bit_addressing_capable_1),
            .msi_masking_capable_1                    (msi_masking_capable_1),
            .msi_support_1                            (msi_support_1),
            .interrupt_pin_1                          (interrupt_pin_1),
            .enable_function_msix_support_1           (enable_function_msix_support_1),
            .msix_table_size_data_1                   (msix_table_size_1),
            .msix_table_bir_data_1                    (msix_table_bir_1),
            .msix_table_offset_data_1                 (msix_table_offset_1),
            .msix_pba_bir_data_1                      (msix_pba_bir_1),
            .msix_pba_offset_data_1                   (msix_pba_offset_1),

            .bridge_port_vga_enable_1                 (bridge_port_vga_enable_1   ),
            .bridge_port_ssid_support_1               (bridge_port_ssid_support_1 ),
            .ssvid_data_1                             (ssvid_1),
            .ssid_data_1                              (ssid_1),
            .eie_before_nfts_count_data_1             (eie_before_nfts_count),
            .gen2_diffclock_nfts_count_data_1         (gen2_diffclock_nfts_count),
            .gen2_sameclock_nfts_count_data_1         (gen2_sameclock_nfts_count),
            .deemphasis_enable_1                      (deemphasis_enable),
            .pcie_spec_version_1                      (pcie_spec_version),
            .l2_async_logic_1                         (l2_async_logic),
            .flr_capability_1                         (flr_capability_1),

            .expansion_base_address_register_data_1   (expansion_base_address_register_1),

            .io_window_addr_width_1                   (io_window_addr_width_1),
            .prefetchable_mem_window_addr_width_1     (prefetchable_mem_window_addr_width_1),

            .no_soft_reset_2                          (no_soft_reset),

            //Func2 - Device Identification Registers
            .vendor_id_data_2                         (vendor_id_2),
            .device_id_data_2                         (device_id_2),
            .revision_id_data_2                       (revision_id_2),
            .class_code_data_2                        (class_code_2),
            .subsystem_vendor_id_data_2               (subsystem_vendor_id_2),
            .subsystem_device_id_data_2               (subsystem_device_id_2),
            .intel_id_access_2                        (intel_id_access),
            //Func 2 - BARs
            .bar0_io_space_2                          (bar0_io_space_2),
            .bar0_64bit_mem_space_2                   (bar0_64bit_mem_space_2),
            .bar0_prefetchable_2                      (bar0_prefetchable_2),
            .bar0_size_mask_data_2                    (bar0_size_mask_2),
            .bar1_io_space_2                          (bar1_io_space_2),
            .bar1_64bit_mem_space_2                   (bar1_64bit_mem_space_2),
            .bar1_prefetchable_2                      (bar1_prefetchable_2),
            .bar1_size_mask_data_2                    (bar1_size_mask_2),
            .bar2_io_space_2                          (bar2_io_space_2),
            .bar2_64bit_mem_space_2                   (bar2_64bit_mem_space_2),
            .bar2_prefetchable_2                      (bar2_prefetchable_2),
            .bar2_size_mask_data_2                    (bar2_size_mask_2),
            .bar3_io_space_2                          (bar3_io_space_2),
            .bar3_64bit_mem_space_2                   (bar3_64bit_mem_space_2),
            .bar3_prefetchable_2                      (bar3_prefetchable_2),
            .bar3_size_mask_data_2                    (bar3_size_mask_2),
            .bar4_io_space_2                          (bar4_io_space_2),
            .bar4_64bit_mem_space_2                   (bar4_64bit_mem_space_2),
            .bar4_prefetchable_2                      (bar4_prefetchable_2),
            .bar4_size_mask_data_2                    (bar4_size_mask_2),
            .bar5_io_space_2                          (bar5_io_space_2),
            .bar5_64bit_mem_space_2                   (bar5_64bit_mem_space_2),
            .bar5_prefetchable_2                      (bar5_prefetchable_2),
            .bar5_size_mask_data_2                    (bar5_size_mask_2),

            .device_specific_init_2                   (device_specific_init_2),
            .maximum_current_data_2                   (maximum_current_2),
            .d1_support_2                             (d1_support),
            .d2_support_2                             (d2_support),
            .d0_pme_2                                 (d0_pme),
            .d1_pme_2                                 (d1_pme),
            .d2_pme_2                                 (d2_pme),
            .d3_hot_pme_2                             (d3_hot_pme),
            .d3_cold_pme_2                            (d3_cold_pme),
            .use_aer_2                                (use_aer_2),
            .low_priority_vc_2                        (low_priority_vc_2),
            .vc_arbitration_2                         (vc_arbitration),
            .disable_snoop_packet_2                   (disable_snoop_packet_2),

            .max_payload_size_2                       (max_payload_size_2),
            .extend_tag_field_2                       (extend_tag_field_2),
            .completion_timeout_2                     (completion_timeout_2),
            .enable_completion_timeout_disable_2      (enable_completion_timeout_disable_2),

            .surprise_down_error_support_2            (surprise_down_error_support_2),
            .dll_active_report_support_2              (dll_active_report_support_2),

            .rx_ei_l0s_2                              (rx_ei_l0s_2),
            .endpoint_l0_latency_data_2               (endpoint_l0_latency_2),
            .endpoint_l1_latency_data_2               (endpoint_l1_latency_2),

            .indicator_data_2                         (indicator_2),
            .role_based_error_reporting_2             (role_based_error_reporting),
            .max_link_width_2                         (lane_mask),

            .aspm_optionality_2                       (aspm_optionality),
            .enable_l1_aspm_2                         (enable_l1_aspm),
            .enable_l0s_aspm_2                        (enable_l0s_aspm),

            .l1_exit_latency_sameclock_data_2         (l1_exit_latency_sameclock),
            .l1_exit_latency_diffclock_data_2         (l1_exit_latency_diffclock),
            .l0_exit_latency_sameclock_data_2         (l0_exit_latency_sameclock),
            .l0_exit_latency_diffclock_data_2         (l0_exit_latency_diffclock),

            .hot_plug_support_data_2                  (hot_plug_support_2),

            .slot_power_scale_data_2                  (slot_power_scale_2),
            .slot_power_limit_data_2                  (slot_power_limit_2),
            .slot_number_data_2                       (slot_number_2),

      //      .electromech_interlock_2                  (),
            .diffclock_nfts_count_data_2              (diffclock_nfts_count),
            .sameclock_nfts_count_data_2              (sameclock_nfts_count),

            .ecrc_check_capable_2                     (ecrc_check_capable_2),
            .ecrc_gen_capable_2                       (ecrc_gen_capable_2),

            .no_command_completed_2                   (no_command_completed_2),

            .msi_multi_message_capable_2              (msi_multi_message_capable_2),
            .msi_64bit_addressing_capable_2           (msi_64bit_addressing_capable_2),
            .msi_masking_capable_2                    (msi_masking_capable_2),
            .msi_support_2                            (msi_support_2),
            .interrupt_pin_2                          (interrupt_pin_2),
            .enable_function_msix_support_2           (enable_function_msix_support_2),
            .msix_table_size_data_2                   (msix_table_size_2),
            .msix_table_bir_data_2                    (msix_table_bir_2),
            .msix_table_offset_data_2                 (msix_table_offset_2),
            .msix_pba_bir_data_2                      (msix_pba_bir_2),
            .msix_pba_offset_data_2                   (msix_pba_offset_2),

            .bridge_port_vga_enable_2                 (bridge_port_vga_enable_2),
            .bridge_port_ssid_support_2               (bridge_port_ssid_support_2),
            .ssvid_data_2                             (ssvid_2),
            .ssid_data_2                              (ssid_2),
            .eie_before_nfts_count_data_2             (eie_before_nfts_count),
            .gen2_diffclock_nfts_count_data_2         (gen2_diffclock_nfts_count),
            .gen2_sameclock_nfts_count_data_2         (gen2_sameclock_nfts_count),
            .deemphasis_enable_2                      (deemphasis_enable),
            .pcie_spec_version_2                      (pcie_spec_version),
            .l2_async_logic_2                         (l2_async_logic),
            .flr_capability_2                         (flr_capability_2),

            .expansion_base_address_register_data_2   (expansion_base_address_register_2),

            .io_window_addr_width_2                   (io_window_addr_width_2),
            .prefetchable_mem_window_addr_width_2     (prefetchable_mem_window_addr_width_2),

            .no_soft_reset_3                          (no_soft_reset),

            //Func3 - Device Identification Registers
            .vendor_id_data_3                         (vendor_id_3),
            .device_id_data_3                         (device_id_3),
            .revision_id_data_3                       (revision_id_3),
            .class_code_data_3                        (class_code_3),
            .subsystem_vendor_id_data_3               (subsystem_vendor_id_3),
            .subsystem_device_id_data_3               (subsystem_device_id_3),
            .intel_id_access_3                        (intel_id_access),
            //Func 3 - BARs
            .bar0_io_space_3                          (bar0_io_space_3),
            .bar0_64bit_mem_space_3                   (bar0_64bit_mem_space_3),
            .bar0_prefetchable_3                      (bar0_prefetchable_3),
            .bar0_size_mask_data_3                    (bar0_size_mask_3),
            .bar1_io_space_3                          (bar1_io_space_3),
            .bar1_64bit_mem_space_3                   (bar1_64bit_mem_space_3),
            .bar1_prefetchable_3                      (bar1_prefetchable_3),
            .bar1_size_mask_data_3                    (bar1_size_mask_3),
            .bar2_io_space_3                          (bar2_io_space_3),
            .bar2_64bit_mem_space_3                   (bar2_64bit_mem_space_3),
            .bar2_prefetchable_3                      (bar2_prefetchable_3),
            .bar2_size_mask_data_3                    (bar2_size_mask_3),
            .bar3_io_space_3                          (bar3_io_space_3),
            .bar3_64bit_mem_space_3                   (bar3_64bit_mem_space_3),
            .bar3_prefetchable_3                      (bar3_prefetchable_3),
            .bar3_size_mask_data_3                    (bar3_size_mask_3),
            .bar4_io_space_3                          (bar4_io_space_3),
            .bar4_64bit_mem_space_3                   (bar4_64bit_mem_space_3),
            .bar4_prefetchable_3                      (bar4_prefetchable_3),
            .bar4_size_mask_data_3                    (bar4_size_mask_3),
            .bar5_io_space_3                          (bar5_io_space_3),
            .bar5_64bit_mem_space_3                   (bar5_64bit_mem_space_3),
            .bar5_prefetchable_3                      (bar5_prefetchable_3),
            .bar5_size_mask_data_3                    (bar5_size_mask_3),


            .device_specific_init_3                   (device_specific_init_3),
            .maximum_current_data_3                   (maximum_current_3),
            .d1_support_3                             (d1_support),
            .d2_support_3                             (d2_support),
            .d0_pme_3                                 (d0_pme),
            .d1_pme_3                                 (d1_pme),
            .d2_pme_3                                 (d2_pme),
            .d3_hot_pme_3                             (d3_hot_pme),
            .d3_cold_pme_3                            (d3_cold_pme),
            .use_aer_3                                (use_aer_3),
            .low_priority_vc_3                        (low_priority_vc_3),
            .vc_arbitration_3                         (vc_arbitration),
            .disable_snoop_packet_3                   (disable_snoop_packet_3),

            .max_payload_size_3                       (max_payload_size_3),
            .extend_tag_field_3                       (extend_tag_field_3),
            .completion_timeout_3                     (completion_timeout_3),
            .enable_completion_timeout_disable_3      (enable_completion_timeout_disable_3),

            .surprise_down_error_support_3            (surprise_down_error_support_3),
            .dll_active_report_support_3              (dll_active_report_support_3),

            .rx_ei_l0s_3                              (rx_ei_l0s_3),
            .endpoint_l0_latency_data_3               (endpoint_l0_latency_3),
            .endpoint_l1_latency_data_3               (endpoint_l1_latency_3),

            .indicator_data_3                         (indicator_3),
            .role_based_error_reporting_3             (role_based_error_reporting),
            .max_link_width_3                         (lane_mask),

            .aspm_optionality_3                       (aspm_optionality),
            .enable_l1_aspm_3                         (enable_l1_aspm),
            .enable_l0s_aspm_3                        (enable_l0s_aspm),

            .l1_exit_latency_sameclock_data_3         (l1_exit_latency_sameclock),
            .l1_exit_latency_diffclock_data_3         (l1_exit_latency_diffclock),
            .l0_exit_latency_sameclock_data_3         (l0_exit_latency_sameclock),
            .l0_exit_latency_diffclock_data_3         (l0_exit_latency_diffclock),

            .hot_plug_support_data_3                  (hot_plug_support_3),

            .slot_power_scale_data_3                  (slot_power_scale_3),
            .slot_power_limit_data_3                  (slot_power_limit_3),
            .slot_number_data_3                       (slot_number_3),

      //      .electromech_interlock_3                  (),
            .diffclock_nfts_count_data_3              (diffclock_nfts_count),
            .sameclock_nfts_count_data_3              (sameclock_nfts_count),

            .ecrc_check_capable_3                     (ecrc_check_capable_3),
            .ecrc_gen_capable_3                       (ecrc_gen_capable_3),

            .no_command_completed_3                   (no_command_completed_3),

            .msi_multi_message_capable_3              (msi_multi_message_capable_3),
            .msi_64bit_addressing_capable_3           (msi_64bit_addressing_capable_3),
            .msi_masking_capable_3                    (msi_masking_capable_3),
            .msi_support_3                            (msi_support_3),
            .interrupt_pin_3                          (interrupt_pin_3),
            .enable_function_msix_support_3           (enable_function_msix_support_3),
            .msix_table_size_data_3                   (msix_table_size_3),
            .msix_table_bir_data_3                    (msix_table_bir_3),
            .msix_table_offset_data_3                 (msix_table_offset_3),
            .msix_pba_bir_data_3                      (msix_pba_bir_3),
            .msix_pba_offset_data_3                   (msix_pba_offset_3),

            .bridge_port_vga_enable_3                 (bridge_port_vga_enable_3),
            .bridge_port_ssid_support_3               (bridge_port_ssid_support_3),
            .ssvid_data_3                             (ssvid_3),
            .ssid_data_3                              (ssid_3),
            .eie_before_nfts_count_data_3             (eie_before_nfts_count),
            .gen2_diffclock_nfts_count_data_3         (gen2_diffclock_nfts_count),
            .gen2_sameclock_nfts_count_data_3         (gen2_sameclock_nfts_count),
            .deemphasis_enable_3                      (deemphasis_enable),
            .pcie_spec_version_3                      (pcie_spec_version),
            .l2_async_logic_3                         (l2_async_logic),
            .flr_capability_3                         (flr_capability_3),

            .expansion_base_address_register_data_3   (expansion_base_address_register_3),

            .io_window_addr_width_3                   (io_window_addr_width_3),
            .prefetchable_mem_window_addr_width_3     (prefetchable_mem_window_addr_width_3),


            .no_soft_reset_4                          (no_soft_reset),

            //Func4 - Device Identification Registers
            .vendor_id_data_4                         (vendor_id_4),
            .device_id_data_4                         (device_id_4),
            .revision_id_data_4                       (revision_id_4),
            .class_code_data_4                        (class_code_4),
            .subsystem_vendor_id_data_4               (subsystem_vendor_id_4),
            .subsystem_device_id_data_4               (subsystem_device_id_4),
            .intel_id_access_4                        (intel_id_access),
            //Func 4 - BARs
            .bar0_io_space_4                          (bar0_io_space_4),
            .bar0_64bit_mem_space_4                   (bar0_64bit_mem_space_4),
            .bar0_prefetchable_4                      (bar0_prefetchable_4),
            .bar0_size_mask_data_4                    (bar0_size_mask_4),
            .bar1_io_space_4                          (bar1_io_space_4),
            .bar1_64bit_mem_space_4                   (bar1_64bit_mem_space_4),
            .bar1_prefetchable_4                      (bar1_prefetchable_4),
            .bar1_size_mask_data_4                    (bar1_size_mask_4),
            .bar2_io_space_4                          (bar2_io_space_4),
            .bar2_64bit_mem_space_4                   (bar2_64bit_mem_space_4),
            .bar2_prefetchable_4                      (bar2_prefetchable_4),
            .bar2_size_mask_data_4                    (bar2_size_mask_4),
            .bar3_io_space_4                          (bar3_io_space_4),
            .bar3_64bit_mem_space_4                   (bar3_64bit_mem_space_4),
            .bar3_prefetchable_4                      (bar3_prefetchable_4),
            .bar3_size_mask_data_4                    (bar3_size_mask_4),
            .bar4_io_space_4                          (bar4_io_space_4),
            .bar4_64bit_mem_space_4                   (bar4_64bit_mem_space_4),
            .bar4_prefetchable_4                      (bar4_prefetchable_4),
            .bar4_size_mask_data_4                    (bar4_size_mask_4),
            .bar5_io_space_4                          (bar5_io_space_4),
            .bar5_64bit_mem_space_4                   (bar5_64bit_mem_space_4),
            .bar5_prefetchable_4                      (bar5_prefetchable_4),
            .bar5_size_mask_data_4                    (bar5_size_mask_4),

            .device_specific_init_4                   (device_specific_init_4),
            .maximum_current_data_4                   (maximum_current_4),
            .d1_support_4                             (d1_support),
            .d2_support_4                             (d2_support),
            .d0_pme_4                                 (d0_pme),
            .d1_pme_4                                 (d1_pme),
            .d2_pme_4                                 (d2_pme),
            .d3_hot_pme_4                             (d3_hot_pme),
            .d3_cold_pme_4                            (d3_cold_pme),
            .use_aer_4                                (use_aer_4),
            .low_priority_vc_4                        (low_priority_vc_4),
            .vc_arbitration_4                         (vc_arbitration),
            .disable_snoop_packet_4                   (disable_snoop_packet_4),

            .max_payload_size_4                       (max_payload_size_4),
            .extend_tag_field_4                       (extend_tag_field_4),
            .completion_timeout_4                     (completion_timeout_4),
            .enable_completion_timeout_disable_4      (enable_completion_timeout_disable_4),

            .surprise_down_error_support_4            (surprise_down_error_support_4),
            .dll_active_report_support_4              (dll_active_report_support_4),

            .rx_ei_l0s_4                              (rx_ei_l0s_4),
            .endpoint_l0_latency_data_4               (endpoint_l0_latency_4),
            .endpoint_l1_latency_data_4               (endpoint_l1_latency_4),

            .indicator_data_4                         (indicator_4),
            .role_based_error_reporting_4             (role_based_error_reporting),
            .max_link_width_4                         (lane_mask),

            .aspm_optionality_4                       (aspm_optionality),
            .enable_l1_aspm_4                         (enable_l1_aspm),
            .enable_l0s_aspm_4                        (enable_l0s_aspm),

            .l1_exit_latency_sameclock_data_4         (l1_exit_latency_sameclock),
            .l1_exit_latency_diffclock_data_4         (l1_exit_latency_diffclock),
            .l0_exit_latency_sameclock_data_4         (l0_exit_latency_sameclock),
            .l0_exit_latency_diffclock_data_4         (l0_exit_latency_diffclock),

            .hot_plug_support_data_4                  (hot_plug_support_4),

            .slot_power_scale_data_4                  (slot_power_scale_4),
            .slot_power_limit_data_4                  (slot_power_limit_4),
            .slot_number_data_4                       (slot_number_4),

      //      .electromech_interlock_4                  (),
            .diffclock_nfts_count_data_4              (diffclock_nfts_count),
            .sameclock_nfts_count_data_4              (sameclock_nfts_count),

            .ecrc_check_capable_4                     (ecrc_check_capable_4),
            .ecrc_gen_capable_4                       (ecrc_gen_capable_4),

            .no_command_completed_4                   (no_command_completed_4),

            .msi_multi_message_capable_4              (msi_multi_message_capable_4),
            .msi_64bit_addressing_capable_4           (msi_64bit_addressing_capable_4),
            .msi_masking_capable_4                    (msi_masking_capable_4),
            .msi_support_4                            (msi_support_4),
            .interrupt_pin_4                          (interrupt_pin_4),
            .enable_function_msix_support_4           (enable_function_msix_support_4),
            .msix_table_size_data_4                   (msix_table_size_4),
            .msix_table_bir_data_4                    (msix_table_bir_4),
            .msix_table_offset_data_4                 (msix_table_offset_4),
            .msix_pba_bir_data_4                      (msix_pba_bir_4),
            .msix_pba_offset_data_4                   (msix_pba_offset_4),

            .bridge_port_vga_enable_4                 (bridge_port_vga_enable_4),
            .bridge_port_ssid_support_4               (bridge_port_ssid_support_4),
            .ssvid_data_4                             (ssvid_4),
            .ssid_data_4                              (ssid_4),
            .eie_before_nfts_count_data_4             (eie_before_nfts_count),
            .gen2_diffclock_nfts_count_data_4         (gen2_diffclock_nfts_count),
            .gen2_sameclock_nfts_count_data_4         (gen2_sameclock_nfts_count),
            .deemphasis_enable_4                      (deemphasis_enable),
            .pcie_spec_version_4                      (pcie_spec_version),
            .l2_async_logic_4                         (l2_async_logic),
            .flr_capability_4                         (flr_capability_4),

            .expansion_base_address_register_data_4   (expansion_base_address_register_4),

            .io_window_addr_width_4                   (io_window_addr_width_4),
            .prefetchable_mem_window_addr_width_4     (prefetchable_mem_window_addr_width_4),

            .no_soft_reset_5                          (no_soft_reset),

            //Func 5 - Device Identification Registers
            .vendor_id_data_5                         (vendor_id_5),
            .device_id_data_5                         (device_id_5),
            .revision_id_data_5                       (revision_id_5),
            .class_code_data_5                        (class_code_5),
            .subsystem_vendor_id_data_5               (subsystem_vendor_id_5),
            .subsystem_device_id_data_5               (subsystem_device_id_5),
            .intel_id_access_5                        (intel_id_access),
            //Func 5 - BARs
            .bar0_io_space_5                          (bar0_io_space_5),
            .bar0_64bit_mem_space_5                   (bar0_64bit_mem_space_5),
            .bar0_prefetchable_5                      (bar0_prefetchable_5),
            .bar0_size_mask_data_5                    (bar0_size_mask_5),
            .bar1_io_space_5                          (bar1_io_space_5),
            .bar1_64bit_mem_space_5                   (bar1_64bit_mem_space_5),
            .bar1_prefetchable_5                      (bar1_prefetchable_5),
            .bar1_size_mask_data_5                    (bar1_size_mask_5),
            .bar2_io_space_5                          (bar2_io_space_5),
            .bar2_64bit_mem_space_5                   (bar2_64bit_mem_space_5),
            .bar2_prefetchable_5                      (bar2_prefetchable_5),
            .bar2_size_mask_data_5                    (bar2_size_mask_5),
            .bar3_io_space_5                          (bar3_io_space_5),
            .bar3_64bit_mem_space_5                   (bar3_64bit_mem_space_5),
            .bar3_prefetchable_5                      (bar3_prefetchable_5),
            .bar3_size_mask_data_5                    (bar3_size_mask_5),
            .bar4_io_space_5                          (bar4_io_space_5),
            .bar4_64bit_mem_space_5                   (bar4_64bit_mem_space_5),
            .bar4_prefetchable_5                      (bar4_prefetchable_5),
            .bar4_size_mask_data_5                    (bar4_size_mask_5),
            .bar5_io_space_5                          (bar5_io_space_5),
            .bar5_64bit_mem_space_5                   (bar5_64bit_mem_space_5),
            .bar5_prefetchable_5                      (bar5_prefetchable_5),
            .bar5_size_mask_data_5                    (bar5_size_mask_5),

            .device_specific_init_5                   (device_specific_init_5),
            .maximum_current_data_5                   (maximum_current_5),
            .d1_support_5                             (d1_support),
            .d2_support_5                             (d2_support),
            .d0_pme_5                                 (d0_pme),
            .d1_pme_5                                 (d1_pme),
            .d2_pme_5                                 (d2_pme),
            .d3_hot_pme_5                             (d3_hot_pme),
            .d3_cold_pme_5                            (d3_cold_pme),
            .use_aer_5                                (use_aer_5),
            .low_priority_vc_5                        (low_priority_vc_5),
            .vc_arbitration_5                         (vc_arbitration),
            .disable_snoop_packet_5                   (disable_snoop_packet_5),

            .max_payload_size_5                       (max_payload_size_5),
            .extend_tag_field_5                       (extend_tag_field_5),
            .completion_timeout_5                     (completion_timeout_5),
            .enable_completion_timeout_disable_5      (enable_completion_timeout_disable_5),

            .surprise_down_error_support_5            (surprise_down_error_support_5),
            .dll_active_report_support_5              (dll_active_report_support_5),

            .rx_ei_l0s_5                              (rx_ei_l0s_5),
            .endpoint_l0_latency_data_5               (endpoint_l0_latency_5),
            .endpoint_l1_latency_data_5               (endpoint_l1_latency_5),

            .indicator_data_5                         (indicator_5),
            .role_based_error_reporting_5             (role_based_error_reporting),
            .max_link_width_5                         (lane_mask),

            .aspm_optionality_5                       (aspm_optionality),
            .enable_l1_aspm_5                         (enable_l1_aspm),
            .enable_l0s_aspm_5                        (enable_l0s_aspm),

            .l1_exit_latency_sameclock_data_5         (l1_exit_latency_sameclock),
            .l1_exit_latency_diffclock_data_5         (l1_exit_latency_diffclock),
            .l0_exit_latency_sameclock_data_5         (l0_exit_latency_sameclock),
            .l0_exit_latency_diffclock_data_5         (l0_exit_latency_diffclock),

            .hot_plug_support_data_5                  (hot_plug_support_5),

            .slot_power_scale_data_5                  (slot_power_scale_5),
            .slot_power_limit_data_5                  (slot_power_limit_5),
            .slot_number_data_5                       (slot_number_5),

      //      .electromech_interlock_5                  (),
            .diffclock_nfts_count_data_5              (diffclock_nfts_count),
            .sameclock_nfts_count_data_5              (sameclock_nfts_count),

            .ecrc_check_capable_5                     (ecrc_check_capable_5),
            .ecrc_gen_capable_5                       (ecrc_gen_capable_5),

            .no_command_completed_5                   (no_command_completed_5),

            .msi_multi_message_capable_5              (msi_multi_message_capable_5),
            .msi_64bit_addressing_capable_5           (msi_64bit_addressing_capable_5),
            .msi_masking_capable_5                    (msi_masking_capable_5),
            .msi_support_5                            (msi_support_5),
            .interrupt_pin_5                          (interrupt_pin_5),
            .enable_function_msix_support_5           (enable_function_msix_support_5),
            .msix_table_size_data_5                   (msix_table_size_5),
            .msix_table_bir_data_5                    (msix_table_bir_5),
            .msix_table_offset_data_5                 (msix_table_offset_5),
            .msix_pba_bir_data_5                      (msix_pba_bir_5),
            .msix_pba_offset_data_5                   (msix_pba_offset_5),

            .bridge_port_vga_enable_5                 (bridge_port_vga_enable_5),
            .bridge_port_ssid_support_5               (bridge_port_ssid_support_5),
            .ssvid_data_5                             (ssvid_5),
            .ssid_data_5                              (ssid_5),
            .eie_before_nfts_count_data_5             (eie_before_nfts_count),
            .gen2_diffclock_nfts_count_data_5         (gen2_diffclock_nfts_count),
            .gen2_sameclock_nfts_count_data_5         (gen2_sameclock_nfts_count),
            .deemphasis_enable_5                      (deemphasis_enable),
            .pcie_spec_version_5                      (pcie_spec_version),
            .l2_async_logic_5                         (l2_async_logic),
            .flr_capability_5                         (flr_capability_5),

            .expansion_base_address_register_data_5   (expansion_base_address_register_5),

            .io_window_addr_width_5                   (io_window_addr_width_5),
            .prefetchable_mem_window_addr_width_5     (prefetchable_mem_window_addr_width_5),

            .no_soft_reset_6                          (no_soft_reset),

            //Func6 - Device Identification Registers
            .vendor_id_data_6                         (vendor_id_6),
            .device_id_data_6                         (device_id_6),
            .revision_id_data_6                       (revision_id_6),
            .class_code_data_6                        (class_code_6),
            .subsystem_vendor_id_data_6               (subsystem_vendor_id_6),
            .subsystem_device_id_data_6               (subsystem_device_id_6),
            .intel_id_access_6                        (intel_id_access),
            //Func 6 - BARs
            .bar0_io_space_6                          (bar0_io_space_6),
            .bar0_64bit_mem_space_6                   (bar0_64bit_mem_space_6),
            .bar0_prefetchable_6                      (bar0_prefetchable_6),
            .bar0_size_mask_data_6                    (bar0_size_mask_6),
            .bar1_io_space_6                          (bar1_io_space_6),
            .bar1_64bit_mem_space_6                   (bar1_64bit_mem_space_6),
            .bar1_prefetchable_6                      (bar1_prefetchable_6),
            .bar1_size_mask_data_6                    (bar1_size_mask_6),
            .bar2_io_space_6                          (bar2_io_space_6),
            .bar2_64bit_mem_space_6                   (bar2_64bit_mem_space_6),
            .bar2_prefetchable_6                      (bar2_prefetchable_6),
            .bar2_size_mask_data_6                    (bar2_size_mask_6),
            .bar3_io_space_6                          (bar3_io_space_6),
            .bar3_64bit_mem_space_6                   (bar3_64bit_mem_space_6),
            .bar3_prefetchable_6                      (bar3_prefetchable_6),
            .bar3_size_mask_data_6                    (bar3_size_mask_6),
            .bar4_io_space_6                          (bar4_io_space_6),
            .bar4_64bit_mem_space_6                   (bar4_64bit_mem_space_6),
            .bar4_prefetchable_6                      (bar4_prefetchable_6),
            .bar4_size_mask_data_6                    (bar4_size_mask_6),
            .bar5_io_space_6                          (bar5_io_space_6),
            .bar5_64bit_mem_space_6                   (bar5_64bit_mem_space_6),
            .bar5_prefetchable_6                      (bar5_prefetchable_6),
            .bar5_size_mask_data_6                    (bar5_size_mask_6),

            .device_specific_init_6                   (device_specific_init_6),
            .maximum_current_data_6                   (maximum_current_6),
            .d1_support_6                             (d1_support),
            .d2_support_6                             (d2_support),
            .d0_pme_6                                 (d0_pme),
            .d1_pme_6                                 (d1_pme),
            .d2_pme_6                                 (d2_pme),
            .d3_hot_pme_6                             (d3_hot_pme),
            .d3_cold_pme_6                            (d3_cold_pme),
            .use_aer_6                                (use_aer_6),
            .low_priority_vc_6                        (low_priority_vc_6),
            .vc_arbitration_6                         (vc_arbitration),
            .disable_snoop_packet_6                   (disable_snoop_packet_6),

            .max_payload_size_6                       (max_payload_size_6),
            .extend_tag_field_6                       (extend_tag_field_6),
            .completion_timeout_6                     (completion_timeout_6),
            .enable_completion_timeout_disable_6      (enable_completion_timeout_disable_6),

            .surprise_down_error_support_6            (surprise_down_error_support_6),
            .dll_active_report_support_6              (dll_active_report_support_6),

            .rx_ei_l0s_6                              (rx_ei_l0s_6),
            .endpoint_l0_latency_data_6               (endpoint_l0_latency_6),
            .endpoint_l1_latency_data_6               (endpoint_l1_latency_6),

            .indicator_data_6                         (indicator_6),
            .role_based_error_reporting_6             (role_based_error_reporting),
            .max_link_width_6                         (lane_mask),

            .aspm_optionality_6                       (aspm_optionality),
            .enable_l1_aspm_6                         (enable_l1_aspm),
            .enable_l0s_aspm_6                        (enable_l0s_aspm),

            .l1_exit_latency_sameclock_data_6         (l1_exit_latency_sameclock),
            .l1_exit_latency_diffclock_data_6         (l1_exit_latency_diffclock),
            .l0_exit_latency_sameclock_data_6         (l0_exit_latency_sameclock),
            .l0_exit_latency_diffclock_data_6         (l0_exit_latency_diffclock),

            .hot_plug_support_data_6                  (hot_plug_support_6),

            .slot_power_scale_data_6                  (slot_power_scale_6),
            .slot_power_limit_data_6                  (slot_power_limit_6),
            .slot_number_data_6                       (slot_number_6),

      //      .electromech_interlock_6                  (),
            .diffclock_nfts_count_data_6              (diffclock_nfts_count),
            .sameclock_nfts_count_data_6              (sameclock_nfts_count),

            .ecrc_check_capable_6                     (ecrc_check_capable_6),
            .ecrc_gen_capable_6                       (ecrc_gen_capable_6),

            .no_command_completed_6                   (no_command_completed_6),

            .msi_multi_message_capable_6              (msi_multi_message_capable_6),
            .msi_64bit_addressing_capable_6           (msi_64bit_addressing_capable_6),
            .msi_masking_capable_6                    (msi_masking_capable_6),
            .msi_support_6                            (msi_support_6),
            .interrupt_pin_6                          (interrupt_pin_6),
            .enable_function_msix_support_6           (enable_function_msix_support_6),
            .msix_table_size_data_6                   (msix_table_size_6),
            .msix_table_bir_data_6                    (msix_table_bir_6),
            .msix_table_offset_data_6                 (msix_table_offset_6),
            .msix_pba_bir_data_6                      (msix_pba_bir_6),
            .msix_pba_offset_data_6                   (msix_pba_offset_6),

            .bridge_port_vga_enable_6                 (bridge_port_vga_enable_6),
            .bridge_port_ssid_support_6               (bridge_port_ssid_support_6),
            .ssvid_data_6                             (ssvid_6),
            .ssid_data_6                              (ssid_6),
            .eie_before_nfts_count_data_6             (eie_before_nfts_count),
            .gen2_diffclock_nfts_count_data_6         (gen2_diffclock_nfts_count),
            .gen2_sameclock_nfts_count_data_6         (gen2_sameclock_nfts_count),
            .deemphasis_enable_6                      (deemphasis_enable),
            .pcie_spec_version_6                      (pcie_spec_version),
            .l2_async_logic_6                         (l2_async_logic),
            .flr_capability_6                         (flr_capability_6),

            .expansion_base_address_register_data_6   (expansion_base_address_register_6),

            .io_window_addr_width_6                   (io_window_addr_width_6),
            .prefetchable_mem_window_addr_width_6     (prefetchable_mem_window_addr_width_6),

            .no_soft_reset_7                          (no_soft_reset),

            //Func7 - Device Identification Registers
            .vendor_id_data_7                         (vendor_id_7),
            .device_id_data_7                         (device_id_7),
            .revision_id_data_7                       (revision_id_7),
            .class_code_data_7                        (class_code_7),
            .subsystem_vendor_id_data_7               (subsystem_vendor_id_7),
            .subsystem_device_id_data_7               (subsystem_device_id_7),
            .intel_id_access_7                        (intel_id_access),
            //Func 7 - BARs
            .bar0_io_space_7                          (bar0_io_space_7),
            .bar0_64bit_mem_space_7                   (bar0_64bit_mem_space_7),
            .bar0_prefetchable_7                      (bar0_prefetchable_7),
            .bar0_size_mask_data_7                    (bar0_size_mask_7),
            .bar1_io_space_7                          (bar1_io_space_7),
            .bar1_64bit_mem_space_7                   (bar1_64bit_mem_space_7),
            .bar1_prefetchable_7                      (bar1_prefetchable_7),
            .bar1_size_mask_data_7                    (bar1_size_mask_7),
            .bar2_io_space_7                          (bar2_io_space_7),
            .bar2_64bit_mem_space_7                   (bar2_64bit_mem_space_7),
            .bar2_prefetchable_7                      (bar2_prefetchable_7),
            .bar2_size_mask_data_7                    (bar2_size_mask_7),
            .bar3_io_space_7                          (bar3_io_space_7),
            .bar3_64bit_mem_space_7                   (bar3_64bit_mem_space_7),
            .bar3_prefetchable_7                      (bar3_prefetchable_7),
            .bar3_size_mask_data_7                    (bar3_size_mask_7),
            .bar4_io_space_7                          (bar4_io_space_7),
            .bar4_64bit_mem_space_7                   (bar4_64bit_mem_space_7),
            .bar4_prefetchable_7                      (bar4_prefetchable_7),
            .bar4_size_mask_data_7                    (bar4_size_mask_7),
            .bar5_io_space_7                          (bar5_io_space_7),
            .bar5_64bit_mem_space_7                   (bar5_64bit_mem_space_7),
            .bar5_prefetchable_7                      (bar5_prefetchable_7),
            .bar5_size_mask_data_7                    (bar5_size_mask_7),

            .device_specific_init_7                   (device_specific_init_7),
            .maximum_current_data_7                   (maximum_current_7),
            .d1_support_7                             (d1_support),
            .d2_support_7                             (d2_support),
            .d0_pme_7                                 (d0_pme),
            .d1_pme_7                                 (d1_pme),
            .d2_pme_7                                 (d2_pme),
            .d3_hot_pme_7                             (d3_hot_pme),
            .d3_cold_pme_7                            (d3_cold_pme),
            .use_aer_7                                (use_aer_7),
            .low_priority_vc_7                        (low_priority_vc_7),
            .vc_arbitration_7                         (vc_arbitration),
            .disable_snoop_packet_7                   (disable_snoop_packet_7),

            .max_payload_size_7                       (max_payload_size_7),
            .extend_tag_field_7                       (extend_tag_field_7),
            .completion_timeout_7                     (completion_timeout_7),
            .enable_completion_timeout_disable_7      (enable_completion_timeout_disable_7),

            .surprise_down_error_support_7            (surprise_down_error_support_7),
            .dll_active_report_support_7              (dll_active_report_support_7),

            .rx_ei_l0s_7                              (rx_ei_l0s_7),
            .endpoint_l0_latency_data_7               (endpoint_l0_latency_7),
            .endpoint_l1_latency_data_7               (endpoint_l1_latency_7),

            .indicator_data_7                         (indicator_7),
            .role_based_error_reporting_7             (role_based_error_reporting),
            .max_link_width_7                         (lane_mask),

            .aspm_optionality_7                       (aspm_optionality),
            .enable_l1_aspm_7                         (enable_l1_aspm),
            .enable_l0s_aspm_7                        (enable_l0s_aspm),

            .l1_exit_latency_sameclock_data_7         (l1_exit_latency_sameclock),
            .l1_exit_latency_diffclock_data_7         (l1_exit_latency_diffclock),
            .l0_exit_latency_sameclock_data_7         (l0_exit_latency_sameclock),
            .l0_exit_latency_diffclock_data_7         (l0_exit_latency_diffclock),

            .hot_plug_support_data_7                  (hot_plug_support_7),

            .slot_power_scale_data_7                  (slot_power_scale_7),
            .slot_power_limit_data_7                  (slot_power_limit_7),
            .slot_number_data_7                       (slot_number_7),

      //      .electromech_interlock_7                  (),
            .diffclock_nfts_count_data_7              (diffclock_nfts_count),
            .sameclock_nfts_count_data_7              (sameclock_nfts_count),

            .ecrc_check_capable_7                     (ecrc_check_capable_7),
            .ecrc_gen_capable_7                       (ecrc_gen_capable_7),

            .no_command_completed_7                   (no_command_completed_7),

            .msi_multi_message_capable_7              (msi_multi_message_capable_7),
            .msi_64bit_addressing_capable_7           (msi_64bit_addressing_capable_7),
            .msi_masking_capable_7                    (msi_masking_capable_7),
            .msi_support_7                            (msi_support_7),
            .interrupt_pin_7                          (interrupt_pin_7),
            .enable_function_msix_support_7           (enable_function_msix_support_7),
            .msix_table_size_data_7                   (msix_table_size_7),
            .msix_table_bir_data_7                    (msix_table_bir_7),
            .msix_table_offset_data_7                 (msix_table_offset_7),
            .msix_pba_bir_data_7                      (msix_pba_bir_7),
            .msix_pba_offset_data_7                   (msix_pba_offset_7),

            .bridge_port_vga_enable_7                 (bridge_port_vga_enable_7),
            .bridge_port_ssid_support_7               (bridge_port_ssid_support_7),
            .ssvid_data_7                             (ssvid_7),
            .ssid_data_7                              (ssid_7),
            .eie_before_nfts_count_data_7             (eie_before_nfts_count),
            .gen2_diffclock_nfts_count_data_7         (gen2_diffclock_nfts_count),
            .gen2_sameclock_nfts_count_data_7         (gen2_sameclock_nfts_count),
            .deemphasis_enable_7                      (deemphasis_enable),
            .pcie_spec_version_7                      (pcie_spec_version),
            .l2_async_logic_7                         (l2_async_logic),
            .flr_capability_7                         (flr_capability_7),

            .expansion_base_address_register_data_7   (expansion_base_address_register_7),

            .io_window_addr_width_7                   (io_window_addr_width_7),
            .prefetchable_mem_window_addr_width_7     (prefetchable_mem_window_addr_width_7),

            .porttype_func0                           ((porttype_func0 == "ep_legacy") ? "ep_legacy" :
                                                       (porttype_func0 == "rp"       ) ? "rp"        :
                                                       (porttype_func0 == "bridge"  ) ? "bridge" : "ep_native"),

            .porttype_func1                           (((low_str(multi_function) != "one_func") && (porttype_func1 == "ep_legacy")) ? "ep_legacy" :
                                                       ((low_str(multi_function) != "one_func") && (porttype_func1 == "bridge"   )  ? "bridge" : "ep_native")),

            .porttype_func2                           (((low_str(multi_function) != "one_func") && (porttype_func2 == "ep_legacy")) ? "ep_legacy" : "ep_native"),
            .porttype_func3                           (((low_str(multi_function) != "one_func") && (porttype_func3 == "ep_legacy")) ? "ep_legacy" : "ep_native"),
            .porttype_func4                           (((low_str(multi_function) != "one_func") && (porttype_func4 == "ep_legacy")) ? "ep_legacy" : "ep_native"),
            .porttype_func5                           (((low_str(multi_function) != "one_func") && (porttype_func5 == "ep_legacy")) ? "ep_legacy" : "ep_native"),
            .porttype_func6                           (((low_str(multi_function) != "one_func") && (porttype_func6 == "ep_legacy")) ? "ep_legacy" : "ep_native"),
            .porttype_func7                           (((low_str(multi_function) != "one_func") && (porttype_func7 == "ep_legacy")) ? "ep_legacy" : "ep_native")

               ) arriav_hd_altpe2_hip_top (
            // Input Ports
            .avmmaddress                              ((hip_reconfig==1)? avmmaddress:10'h0   ), // input [9:0]    avmmaddress;            //PLD   // address input
            .avmmbyteen                               ((hip_reconfig==1)? avmmbyteen:2'b00    ), // input [1:0]    avmmbyteen;             //PLD   // Byte enable
            .avmmclk                                  ((hip_reconfig==1)? avmmclk:1'b0        ), // input          avmmclk;                //PLD   // DPRIO clock
            .avmmread                                 ((hip_reconfig==1)? avmmread:1'b0       ), // input          avmmread;               //PLD   // read enable input
            .avmmrstn                                 ((hip_reconfig==1)? avmmrstn:1'b1       ), // input          avmmrstn;               //PLD   // DPRIO reset
            .avmmwrite                                ((hip_reconfig==1)? avmmwrite:1'b0      ), // input          avmmwrite;              //PLD   // write enable input
            .avmmwritedata                            ((hip_reconfig==1)? avmmwritedata:16'h0 ), // input [15:0]   avmmwritedata;          //PLD   // write data input
            .bistscanenn                              ((MEM_CHECK==0)?1'b1:bistscanenn        ), // input          bistscanenn;            //PLD -- shared for all 3 memory blocks
            .bistscanin                               ((MEM_CHECK==0)?1'b0:bistscanin         ), // input          bistscanen;             //PLD -- shared for all 3 memory blocks
            .bisttestenn                              ((MEM_CHECK==0)?1'b1:bisttestenn        ), // input          bistscanin;             //PLD -- shared for all 3 memory blocks
            .bistenn                                  ((MEM_CHECK==0)?1'b1:bisttestenn        ), // input          bistesten;              //PLD
            .cbhipmdioen                              (cbhipmdioen                            ), // input          cbhipmdioen;            //PLD   // Control block option bit to block MDIO IOs
            .coreclkin                                (pld_clk                                ), // input          coreclkin;              //PLD
            .corecrst                                 ((USE_HARD_RESET==0)?crst:1'b0          ), // input          corecrst;               //PLD
            .corepor                                  (por                                    ), // input          corepor;                //PLD
            .corerst                                  (por                                    ), // input          corerst;                //PLD
            .coresrst                                 ((USE_HARD_RESET==0)?srst:1'b0          ), // input          coresrst;               //PLD
            .cplerr                                   (cpl_err                                ), // input [6:0]    cplerr;                 //PLD
            .cplerrfunc                               (cpl_errfunc                            ), // input [2:0]    cplerrfunc;             //PLD
            .cplpending                               (cpl_pending                            ), // input [7:0]    cplpending;             //PLD
      // synthesis translate_off
            .csrcbdin                                 (1'b0                                   ), // input          csrcbdin;               //CB    // CSR configuration mode data input
            .csrclk                                   (1'b0                                   ), // input          csrclk;                 //CB    // CSR clock
            .csrdin                                   (1'b0                                   ), // input          csrdin;                 //CB    // Previous CSR bit data output
            .csren                                    (1'b0                                   ), // input          csren;                  //CB    // CSR enable
            .csrenscan                                (1'b0                                   ), // input          csrenscan;              //CB    // enable scan control input
            .csrin                                    (1'b0                                   ), // input          csrin;                  //CB    // Serial CSR input
            .csrloadcsr                               (1'b0                                   ), // input          csrloadcsr;             //CB    // JTAG scan mode control input
            .csrpipein                                (1'b0                                   ), // input          csrpipein;              //CB    // Input to the Pipeline register to suport 200MHz
            .csrseg                                   (1'b0                                   ), // input          csrseg;                 //CB    // VSS for Seg0, VCC for seg[31:1]
            .csrtcsrin                                (1'b0                                   ), // input          csrtcsrin;              //CB    // CSR test/scan mode data input
            .csrtverify                               (1'b0                                   ), // input          csrtverify;             //CB    // test verify control input
            .cvpconfigdone                            (1'b0                                   ), // input          cvpconfigdone;          //CB
            .cvpconfigerror                           (1'b0                                   ), // input          cvpconfigerror;         //CB
            .cvpconfigready                           (1'b0                                   ), // input          cvpconfigready;         //CB
            .cvpen                                    (1'b0                                   ), // input          cvpen;                  //CB
            .entest                                   (1'b0                                   ), // input          entest;                 //CB
            .usermode                                 (1'b1                                   ), // input          usermode;               //CB    -- use to gate off input signal
            .hippartialreconfign                      (1'b1                                   ), // input          hippartialreconfign;    //CB    -- use to gate off output signal
            .iocsrrdydly                              (1'b0                                   ), // input          iocsrrdydly;            //CB -- I/O CSR Ready Delayed (Low when IOCSR is not configured)
            .plniotri                                 (1'b1                                   ), // input          plniotri;               //CB
            .por                                      (por                                   ),  // input          por;                    //CB
      // synthesis translate_on
            .dbgpipex1rx                              (dbgpipex1rx                           ), // input [14:0]   dbgpipex1rx;            //PLD
            .dlcomclkreg                              (dl_comclk_reg                        ),  // input          dlcomclkreg;            //PLD   // ww51.5 change by Ning Xue
            .dlctrllink2                              (dl_ctrl_link2                        ),  // input [12:0]   dlctrllink2;            //PLD
            .dlvcctrl                                 (dl_vc_ctrl                           ),  // input [7:0]    dlvcctrl;               //PLD
            .dpriorefclkdig                           (dpriorefclkdig                       ),  // input          dpriorefclkdig;         //PLD
            .flrreset                                 (flrreset_hip                          ), // input [7:0]    flrreset;               //PLD
            .frefclk0                                 (frefclk[0]                            ), // input          frefclk0;               //PCS
            .frefclk1                                 (frefclk[1]                            ), // input          frefclk1;               //PCS
            .frefclk2                                 (frefclk[2]                            ), // input          frefclk2;               //PCS
            .frefclk3                                 (frefclk[3]                            ), // input          frefclk3;               //PCS
            .frefclk4                                 (frefclk[4]                            ), // input          frefclk4;               //PCS
            .frefclk5                                 (frefclk[5]                            ), // input          frefclk5;               //PCS
            .frefclk6                                 (frefclk[6]                            ), // input          frefclk6;               //PCS
            .frefclk7                                 (frefclk[7]                            ), // input          frefclk7;               //PCS
            .frefclk8                                 (frefclk[8]                            ), // input          frefclk8;               //PCS
            .frzlogic                                 (1'b0                                  ), // input          frzlogic;               //PLD
            .frzreg                                   (1'b0                                  ), // input          frzreg;                 //PLD
            .hipextraclkin                            (hipextraclkin                         ), // input [1:0]    hipextraclkin;
            .hipextrain                               (hipextrain                            ), // input [29:0]   hipextrain;        //
            .interfacesel                             ((hip_reconfig==1)? interfacesel:1'b1 ),  // input          interfacesel;           //PLD   // Interface selection inputs
            .lmiaddr                                  (lmi_addr                              ), // input  [14:0]  lmiaddr;                //PLD
            .lmidin                                   (lmi_din                               ), // input  [31:0]  lmidin;                 //PLD
            .lmirden                                  (lmi_rden                              ), // input          lmirden;                //PLD
            .lmiwren                                  (lmi_wren                              ), // input          lmiwren;                //PLD
            .mdioclk                                  (mdio_clk                              ), // input          mdioclk;                //PLD   // MDIO clock
            .mdiodevaddr                              (mdio_dev_addr                         ), // input [1:0]    mdiodevaddr;            //PLD     //MDIO device address tied at PLD interface
            .mdioin                                   (mdio_in                               ), // input          mdioin;                 //PLD   // MDIO serial input
            .mode                                     (mode                                  ), // input [1:0]    mode;                   //PLD
            .nfrzdrv                                  (1'b1                                  ), // input          nfrzdrv;                //PLD
            .pcierr                                   (pci_err                               ), // input [15:0]   pcierr;                 //PLD
            .pclkcentral                              ((pipe_mode==1'b1)? pclk_in: mserdes_pipe_pclkcentral),  // input          pclkcentral;                 //PCS-PMA
            .pclkch0                                  ((pipe_mode==1'b1)? pclk_in: mserdes_pipe_pclk),         // input          pclkch0;                     //PCS-PMA
            .pclkch1                                  ((pipe_mode==1'b1)? pclk_in: mserdes_pipe_pclkch1),      // input          pclkch1;                     //PCS-PMA
            .phyrst                                   (por                                   ),        // input          phyrst;                 //PLD
            .physrst                                  ((USE_HARD_RESET==0)?srst:1'b0         ),        // input          physrst;                //PLD
            .phystatus0                               (phystatus0                            ),             // input          phystatus0;             //PCS
            .phystatus1                               (phystatus1                            ),             // input          phystatus1;             //PCS
            .phystatus2                               (phystatus2                            ),             // input          phystatus2;             //PCS
            .phystatus3                               (phystatus3                            ),             // input          phystatus3;             //PCS
            .phystatus4                               (phystatus4                            ),             // input          phystatus4;             //PCS
            .phystatus5                               (phystatus5                            ),             // input          phystatus5;             //PCS
            .phystatus6                               (phystatus6                            ),             // input          phystatus6;             //PCS
            .phystatus7                               (phystatus7                            ),             // input          phystatus7;             //PCS
            .pinperstn                                (pin_perst                             ),        // input          pinperstn;              // Active low PCIE reset from PCIE Interface PIN
            .pldclk                                   (pld_clk                               ),        // input          pldclk;                 //PLD
            .pldclrhipn                               ((USE_HARD_RESET==0)?1'b1:~hiprst      ),       // input          pldclrhipn;             //PLD -- From PLD Active low signal To Hard Reset Ctrl, reset the HIP NON STICKY Bits (CRST & SRST)
            .pldclrpcshipn                            (1'b1                                  ),        // input          pldclrpcshipn;          //PLD -- From PLD Active low signal To Hard Reset Ctrl, reset the PCS/HIP
            .pldclrpmapcshipn                         (1'b1                                  ),        // input          pldclrpmapcshipn;       //PLD -- From PLD Active low signal To Hard Reset Ctrl, reset the PMA/PCS/HIP
            .pldcoreready                             (pldcoreready                          ),        // input          pldcoreready;           //PLD
            .pldperstn                                (1'b1                                  ),        // input          pldperstn;              // Active low PCIE reset from PLD core
            .pldrst                                   (por                                   ),        // input          pldrst;                 //PLD
            .pldsrst                                  ((USE_HARD_RESET==0)?srst:1'b0         ),        // input          pldsrst;                //PLD
            .pllfixedclkcentral                       ((pipe_mode==1'b0)? mserdes_pllfixedclkcentral:(low_str(gen12_lane_rate_mode)=="gen1_gen2")?clk500_out:clk250_out), // input          pllfixedclkcentral;        //PCS-PMA
            .pllfixedclkch0                           ((pipe_mode==1'b0)? mserdes_pllfixedclkch0    :(low_str(gen12_lane_rate_mode)=="gen1_gen2")?clk500_out:clk250_out), // input          pllfixedclkch0;            //PCS-PMA
            .pllfixedclkch1                           ((pipe_mode==1'b0)? mserdes_pllfixedclkch1    :(low_str(gen12_lane_rate_mode)=="gen1_gen2")?clk500_out:clk250_out), // input          pllfixedclkch1;            //PCS-PMA
            .rxfreqtxcmuplllock0                      (rxfreqtxcmuplllock[0]                 ),             // input          rxfreqtxcmuplllock0;    //PCS
            .rxfreqtxcmuplllock1                      (rxfreqtxcmuplllock[1]                 ),             // input          rxfreqtxcmuplllock1;    //PCS
            .rxfreqtxcmuplllock2                      (rxfreqtxcmuplllock[2]                 ),             // input          rxfreqtxcmuplllock2;    //PCS
            .rxfreqtxcmuplllock3                      (rxfreqtxcmuplllock[3]                 ),             // input          rxfreqtxcmuplllock3;    //PCS
            .rxfreqtxcmuplllock4                      (rxfreqtxcmuplllock[4]                 ),             // input          rxfreqtxcmuplllock4;    //PCS
            .rxfreqtxcmuplllock5                      (rxfreqtxcmuplllock[5]                 ),             // input          rxfreqtxcmuplllock5;    //PCS
            .rxfreqtxcmuplllock6                      (rxfreqtxcmuplllock[6]                 ),             // input          rxfreqtxcmuplllock6;    //PCS
            .rxfreqtxcmuplllock7                      (rxfreqtxcmuplllock[7]                 ),             // input          rxfreqtxcmuplllock7;    //PCS
            .rxfreqtxcmuplllock8                      (rxfreqtxcmuplllock[8]                 ),             // input          rxfreqtxcmuplllock8;    //PCS
            .rxmaskvc0                                (rx_mask_vc0                           ),             // input          rxmaskvc0;              //PLD
            .rxpllphaselock0                          (rxpllphaselock[0]                     ),             // input          rxpllphaselock0;        //PCS
            .rxpllphaselock1                          (rxpllphaselock[1]                     ),             // input          rxpllphaselock1;        //PCS
            .rxpllphaselock2                          (rxpllphaselock[2]                     ),             // input          rxpllphaselock2;        //PCS
            .rxpllphaselock3                          (rxpllphaselock[3]                     ),             // input          rxpllphaselock3;        //PCS
            .rxpllphaselock4                          (rxpllphaselock[4]                     ),             // input          rxpllphaselock4;        //PCS
            .rxpllphaselock5                          (rxpllphaselock[5]                     ),             // input          rxpllphaselock5;        //PCS
            .rxpllphaselock6                          (rxpllphaselock[6]                     ),             // input          rxpllphaselock6;        //PCS
            .rxpllphaselock7                          (rxpllphaselock[7]                     ),             // input          rxpllphaselock7;        //PCS
            .rxpllphaselock8                          (rxpllphaselock[8]                     ),             // input          rxpllphaselock8;        //PCS
            .rxreadyvc0                               (rx_st_ready_vc0                       ),             // input          rxreadyvc0;             //PLD
            .rxdata0                                  (rxdata0                               ),             // input [7:0]    rxdata0;                //PCS
            .rxdata1                                  (rxdata1                               ),             // input [7:0]    rxdata1;                //PCS
            .rxdata2                                  (rxdata2                               ),             // input [7:0]    rxdata2;                //PCS
            .rxdata3                                  (rxdata3                               ),             // input [7:0]    rxdata3;                //PCS
            .rxdata4                                  (rxdata4                               ),             // input [7:0]    rxdata4;                //PCS
            .rxdata5                                  (rxdata5                               ),             // input [7:0]    rxdata5;                //PCS
            .rxdata6                                  (rxdata6                               ),             // input [7:0]    rxdata6;                //PCS
            .rxdata7                                  (rxdata7                               ),             // input [7:0]    rxdata7;                //PCS
            .rxdatak0                                 (rxdatak0                              ),             // input          rxdatak0;               //PCS
            .rxdatak1                                 (rxdatak1                              ),             // input          rxdatak1;               //PCS
            .rxdatak2                                 (rxdatak2                              ),             // input          rxdatak2;               //PCS
            .rxdatak3                                 (rxdatak3                              ),             // input          rxdatak3;               //PCS
            .rxdatak4                                 (rxdatak4                              ),             // input          rxdatak4;               //PCS
            .rxdatak5                                 (rxdatak5                              ),             // input          rxdatak5;               //PCS
            .rxdatak6                                 (rxdatak6                              ),             // input          rxdatak6;               //PCS
            .rxdatak7                                 (rxdatak7                              ),             // input          rxdatak7;               //PCS
            .rxelecidle0                              (rxelecidle0                           ),             // input          rxelecidle0;            //PCS
            .rxelecidle1                              (rxelecidle1                           ),             // input          rxelecidle1;            //PCS
            .rxelecidle2                              (rxelecidle2                           ),             // input          rxelecidle2;            //PCS
            .rxelecidle3                              (rxelecidle3                           ),             // input          rxelecidle3;            //PCS
            .rxelecidle4                              (rxelecidle4                           ),             // input          rxelecidle4;            //PCS
            .rxelecidle5                              (rxelecidle5                           ),             // input          rxelecidle5;            //PCS
            .rxelecidle6                              (rxelecidle6                           ),             // input          rxelecidle6;            //PCS
            .rxelecidle7                              (rxelecidle7                           ),             // input          rxelecidle7;            //PCS
            .rxfreqlocked0                            (rxfreqlocked0                         ),             // input          rxfreqlocked0;          //PCS-PMA
            .rxfreqlocked1                            (rxfreqlocked1                         ),             // input          rxfreqlocked1;          //PCS-PMA
            .rxfreqlocked2                            (rxfreqlocked2                         ),             // input          rxfreqlocked2;          //PCS-PMA
            .rxfreqlocked3                            (rxfreqlocked3                         ),             // input          rxfreqlocked3;          //PCS-PMA
            .rxfreqlocked4                            (rxfreqlocked4                         ),             // input          rxfreqlocked4;          //PCS-PMA
            .rxfreqlocked5                            (rxfreqlocked5                         ),             // input          rxfreqlocked5;          //PCS-PMA
            .rxfreqlocked6                            (rxfreqlocked6                         ),             // input          rxfreqlocked6;          //PCS-PMA
            .rxfreqlocked7                            (rxfreqlocked7                         ),             // input          rxfreqlocked7;          //PCS-PMA
            .rxstatus0                                (rxstatus0                             ),             // input [2:0]    rxstatus0;              //PCS
            .rxstatus1                                (rxstatus1                             ),             // input [2:0]    rxstatus1;              //PCS
            .rxstatus2                                (rxstatus2                             ),             // input [2:0]    rxstatus2;              //PCS
            .rxstatus3                                (rxstatus3                             ),             // input [2:0]    rxstatus3;              //PCS
            .rxstatus4                                (rxstatus4                             ),             // input [2:0]    rxstatus4;              //PCS
            .rxstatus5                                (rxstatus5                             ),             // input [2:0]    rxstatus5;              //PCS
            .rxstatus6                                (rxstatus6                             ),             // input [2:0]    rxstatus6;              //PCS
            .rxstatus7                                (rxstatus7                             ),             // input [2:0]    rxstatus7;              //PCS
            .rxvalid0                                 (rxvalid0                             ),         // input          rxvalid0;               //PCS
            .rxvalid1                                 (rxvalid1                             ),         // input          rxvalid1;               //PCS
            .rxvalid2                                 (rxvalid2                             ),         // input          rxvalid2;               //PCS
            .rxvalid3                                 (rxvalid3                             ),         // input          rxvalid3;               //PCS
            .rxvalid4                                 (rxvalid4                             ),         // input          rxvalid4;               //PCS
            .rxvalid5                                 (rxvalid5                             ),         // input          rxvalid5;               //PCS
            .rxvalid6                                 (rxvalid6                             ),         // input          rxvalid6;               //PCS
            .rxvalid7                                 (rxvalid7                             ),         // input          rxvalid7;               //PCS
            .scanenn                                  (scanenn                              ),         // input          scanenn;                //PLD
            .scanmoden                                ((MEM_CHECK==0)?1'b1:scanmoden         ),         // input          scanmoden;              //PLD
            .sershiftload                             ((hip_reconfig==1)? ser_shift_load:1'b1),        // input          sershiftload;           //CB    // 1'b1=shift in data from si into scan flop
            .swdnin                                   (3'b000                               ),         // input  [2:0]   swdnin;                 //PLD
            .swupin                                   (7'b0000000                           ),         // input  [6:0]   swupin;                 //PLD
            .testinhip                                (test_in                              ),         // input [39:0]   testinhip;              //PLD
            .tlaermsinum                              (tl_aer_msi_num                       ),         // input [4:0]    tlaermsinum;            //PLD
            .tlappintafuncnum                         (tl_app_inta_funcnum                  ),         // input [2:0]    tlappintafuncnum;       //PLD
            .tlappintasts                             (tl_app_inta_sts                      ),         // input          tlappintasts;           //PLD
            .tlappintbfuncnum                         (tl_app_intb_funcnum                  ),         // input [2:0]    tlappintbfuncnum;       //PLD
            .tlappintbsts                             (tl_app_intb_sts                      ),         // input          tlappintbsts;           //PLD
            .tlappintcfuncnum                         (tl_app_intc_funcnum                  ),         // input [2:0]    tlappintcfuncnum;       //PLD
            .tlappintcsts                             (tl_app_intc_sts                      ),         // input          tlappintcsts;           //PLD
            .tlappintdfuncnum                         (tl_app_intd_funcnum                  ),         // input [2:0]    tlappintdfuncnum;       //PLD
            .tlappintdsts                             (tl_app_intd_sts                      ),         // input          tlappintdsts;           //PLD
            .tlappmsifunc                             (tl_app_msi_func                      ),         // input [2:0]    tlappmsifunc;           //PLD
            .tlappmsinum                              (tl_app_msi_num                       ),         // input [4:0]    tlappmsinum;            //PLD
            .tlappmsireq                              (tl_app_msi_req                       ),         // input          tlappmsireq;            //PLD
            .tlappmsitc                               (tl_app_msi_tc                        ),         // input [2:0]    tlappmsitc;             //PLD
            .tlhpgctrler                              (tl_hpg_ctrl_er                       ),         // input [4:0]    tlhpgctrler;            //PLD
            .tlpexmsinum                              (tl_pex_msi_num                       ),         // input [4:0]    tlpexmsinum;            //PLD
            .tlpmauxpwr                               (tl_pm_auxpwr                         ),         // input          tlpmauxpwr;             //PLD
            .tlpmdata                                 (tl_pm_data                           ),         // input  [9:0]   tlpmdata;               //PLD
            .tlpmevent                                (tl_pm_event                          ),         // input          tlpmevent;              //PLD
            .tlpmeventfunc                            (tl_pm_event_func                     ),         // input [2:0]    tlpmeventfunc;          //PLD
            .tlpmetocr                                (tl_pme_to_cr                         ),         // input          tlpmetocr;              //PLD
            .tlslotclkcfg                             (tl_slotclk_cfg                       ),         // input          tlslotclkcfg;           //PLD
            .txdatavc00                               (tx_st_data_vc0[63:0]                 ),         // input  [63:0]  txdatavc00;             //PLD
            .txdatavc01                               (tx_st_data_vc0[127:64]               ),         // input  [63:0]  txdatavc01;             //PLD
            .txeopvc00                                (tx_st_eop_vc0[0]                     ),         // input          txeopvc00;              //PLD
            .txeopvc01                                (tx_st_eop_vc0[1]                     ),         // input          txeopvc01;              //PLD
            .txerrvc0                                 (tx_st_err_vc0                        ),         // input          txerrvc0;               //PLD
            .txsopvc00                                (tx_st_sop_vc0[0]                     ),         // input          txsopvc00;              //PLD
            .txsopvc01                                (tx_st_sop_vc0[1]                     ),         // input          txsopvc01;              //PLD
            .txvalidvc0                               (tx_st_valid_vc0                      ),         // input          txvalidvc0;             //PLD

            // Output Ports
            .avmmreaddata                             (avmmreaddata               ),                   //output  [15:0]  avmm_readdata;          //PLD   // Read data output
            .bistdonearcv0                            (bistdonearcv0              ),                   //output          bist_donea_rcv0;        //PLD
            .bistdonearcv1                            (bistdonearcv1              ),                   //output          bist_donea_rcv1;        //PLD
            .bistdonearpl                             (bistdonearpl               ),                   //output          bist_donea_rpl;         //PLD
            .bistdonebrcv0                            (bistdonebrcv0              ),                   //output          bist_doneb_rcv0;        //PLD
            .bistdonebrcv1                            (bistdonebrcv1              ),                   //output          bist_doneb_rcv1;        //PLD
            .bistdonebrpl                             (bistdonebrpl               ),                   //output          bist_doneb_rpl;         //PLD
            .bistpassrcv0                             (bistpassrcv0               ),                   //output          bist_pass_rcv0;         //PLD
            .bistpassrcv1                             (bistpassrcv1               ),                   //output          bist_pass_rcv1;         //PLD
            .bistpassrpl                              (bistpassrpl                ),                   //output          bist_pass_rpl;          //PLD
            .bistscanoutrcv0                          (bistscanoutrcv0            ),                   //output          bist_scanout_rcv0;      //PLD
            .bistscanoutrcv1                          (bistscanoutrcv1            ),                   //output          bist_scanout_rcv1;      //PLD
            .bistscanoutrpl                           (bistscanoutrpl             ),                   //output          bist_scanout_rpl;       //PLD
            .clrrxpath                                (clrrxpath                  ),                   //output          clr_rxpath;             //PLD
            .coreclkout                               (coreclkout                 ),                   //output          core_clk_out;           //PLD
            .derrcorextrcv0                           (derr_cor_ext_rcv0          ),                   //output          derr_cor_ext_rcv0;      //PLD
            .derrcorextrpl                            (derr_cor_ext_rpl           ),                   //output          derr_cor_ext_rpl;       //PLD
            .derrrpl                                  (derr_rpl                   ),                   //output          derr_rpl;               //PLD
            .dlcurrentspeed                           (dl_current_speed           ),                   //output [1:0]    dl_current_speed;       //PLD
            .dlltssm                                  (dl_ltssm                   ),                   //output [4:0]    dl_ltssm;               //PLD
            .dlupexit                                 (dlup_exit                  ),                   //output          dlup_exit;              //PLD
            .eidleinfersel0                           (eidleinfersel0             ),                        //output [2:0]    eidle_infer_sel0;       //PCS
            .eidleinfersel1                           (eidleinfersel1             ),                        //output [2:0]    eidle_infer_sel1;       //PCS
            .eidleinfersel2                           (eidleinfersel2             ),                        //output [2:0]    eidle_infer_sel2;       //PCS
            .eidleinfersel3                           (eidleinfersel3             ),                        //output [2:0]    eidle_infer_sel3;       //PCS
            .eidleinfersel4                           (eidleinfersel4             ),                        //output [2:0]    eidle_infer_sel4;       //PCS
            .eidleinfersel5                           (eidleinfersel5             ),                        //output [2:0]    eidle_infer_sel5;       //PCS
            .eidleinfersel6                           (eidleinfersel6             ),                        //output [2:0]    eidle_infer_sel6;       //PCS
            .eidleinfersel7                           (eidleinfersel7             ),                        //output [2:0]    eidle_infer_sel7;       //PCS
            .ev128ns                                  (ev128ns                    ),                   //output          ev_128ns;               //PLD
            .ev1us                                    (ev1us                      ),                   //output          ev_1us;                 //PLD
            .flrsts                                   (flr_sts                    ),                   //output  [7:0]   flr_sts;                //PLD
            .hipextraclkout                           (hipextraclkout             ),                   //output  [1:0]   hip_extraclkout;
            .hipextraout                              (hipextraout                ),                   //output  [29:0]  hip_extraout;           //PLD
            .hotrstexit                               (hotrst_exit                ),                   //output          hotrst_exit;            //PLD
            .intstatus                                (int_status                 ),                   //output [3:0]    int_status;             //PLD
            .l2exit                                   (l2_exit                    ),                   //output          l2_exit;                //PLD
            .laneact                                  (lane_act                   ),                   //output [3:0]    lane_act;               //PLD
            .lmiack                                   (lmi_ack                    ),                   //output          lmi_ack;                //PLD
            .lmidout                                  (lmi_dout                   ),                   //output [31:0]   lmi_dout;               //PLD
            .ltssml0state                             (ltssml0state               ),                   //output          ltssm_l0_state;         //PLD
            .mdiooenn                                 (mdio_oen_n                 ),                   //output          mdio_oen_n;             //PLD   // MDIO output enable
            .mdioout                                  (mdio_out                   ),                   //output          mdio_out;               //PLD   // MDIO serial output
            .pldclkinuse                              (pld_clk_in_use_hip         ),                   //output          pld_clk_in_use;
            .powerdown0                               (powerdown0                 ),                   //output [1:0]    powerdown0;             //PCS
            .powerdown1                               (powerdown1                 ),                   //output [1:0]    powerdown1;             //PCS
            .powerdown2                               (powerdown2                 ),                   //output [1:0]    powerdown2;             //PCS
            .powerdown3                               (powerdown3                 ),                   //output [1:0]    powerdown3;             //PCS
            .powerdown4                               (powerdown4                 ),                   //output [1:0]    powerdown4;             //PCS
            .powerdown5                               (powerdown5                 ),                   //output [1:0]    powerdown5;             //PCS
            .powerdown6                               (powerdown6                 ),                   //output [1:0]    powerdown6;             //PCS
            .powerdown7                               (powerdown7                 ),                   //output [1:0]    powerdown7;             //PCS
            .r2cerrext                                (r2c_err_ext                ),                   //output          r2c_err_ext;
            .rate0                                    (rate0                      ),                   //output          rate0;                  //PCS
            .rate1                                    (rate1                      ),                   //output          rate1;                  //PCS
            .rate2                                    (rate2                      ),                   //output          rate2;                  //PCS
            .rate3                                    (rate3                      ),                   //output          rate3;                  //PCS
            .rate4                                    (ratectrl                   ),                   //output          rate4;                  //PCS
            .rate5                                    (rate4                      ),                   //output          rate5;                  //PCS
            .rate6                                    (rate5                      ),                   //output          rate6;                  //PCS
            .rate7                                    (rate6                      ),                   //output          rate7;                  //PCS
            .rate8                                    (rate7                      ),                   //output          rate8;                  //PCS
            .resetstatus                              (reset_status_hip           ),                   //output          reset_status;           //PLD
            .rxbardecfuncnumvc0                       (rx_bar_dec_func_num_vc0    ),                   //output [2:0]    rx_bar_dec_func_num_vc0;//PLD
            .rxbardecvc0                              (rx_bar_dec_vc0             ),                   //output [7:0]    rx_bar_dec_vc0;         //PLD
            .rxbevc00                                 (rx_be_vc0[7:0]             ),                   //output [7:0]    rx_be_vc0_0;            //PLD
            .rxbevc01                                 (rx_be_vc0[15:8]            ),                   //output [7:0]    rx_be_vc0_1;            //PLD
            .rxdatavc00                               (rx_st_data_vc0[63:0]       ),                   //output [63:0]   rx_data_vc0_0;          //PLD
            .rxdatavc01                               (rx_st_data_vc0[127:64]     ),                   //output [63:0]   rx_data_vc0_1;          //PLD
            .rxeopvc00                                (rx_st_eop_vc0[0]           ),                   //output          rx_eop_vc0_0;           //PLD
            .rxeopvc01                                (rx_st_eop_vc0[1]           ),                   //output          rx_eop_vc0_1;           //PLD
            .rxerrvc0                                 (rx_st_err_vc0              ),                   //output          rx_err_vc0;             //PLD   // uncorrectable error
            .rxfifoemptyvc0                           (rx_fifo_empty_vc0          ),                   //output          rx_fifo_empty_vc0;      //PLD
            .rxfifofullvc0                            (rx_fifo_full_vc0           ),                   //output          rx_fifo_full_vc0;       //PLD
            .rxfifordpvc0                             (rx_fifo_rdp_vc0            ),                   //output [3:0]    rx_fifo_rdp_vc0;        //PLD
            .rxfifowrpvc0                             (rx_fifo_wrp_vc0            ),                   //output [3:0]    rx_fifo_wrp_vc0;        //PLD
            .rxpcsrstn0                               (rxpcsrstn[0]               ),                        //output          rx_pcs_rst_n0;          //PCS
            .rxpcsrstn1                               (rxpcsrstn[1]               ),                        //output          rx_pcs_rst_n1;          //PCS
            .rxpcsrstn2                               (rxpcsrstn[2]               ),                        //output          rx_pcs_rst_n2;          //PCS
            .rxpcsrstn3                               (rxpcsrstn[3]               ),                        //output          rx_pcs_rst_n3;          //PCS
            .rxpcsrstn4                               (rxpcsrstn[4]               ),                        //output          rx_pcs_rst_n4;          //PCS
            .rxpcsrstn5                               (rxpcsrstn[5]               ),                        //output          rx_pcs_rst_n5;          //PCS
            .rxpcsrstn6                               (rxpcsrstn[6]               ),                        //output          rx_pcs_rst_n6;          //PCS
            .rxpcsrstn7                               (rxpcsrstn[7]               ),                        //output          rx_pcs_rst_n7;          //PCS
            .rxpcsrstn8                               (rxpcsrstn[8]               ),                        //output          rx_pcs_rst_n8;          //PCS
            .rxpmarstb0                               (rxpmarstb[0]               ),                        //output          rx_pma_rstb0;           //PCS
            .rxpmarstb1                               (rxpmarstb[1]               ),                        //output          rx_pma_rstb1;           //PCS
            .rxpmarstb2                               (rxpmarstb[2]               ),                        //output          rx_pma_rstb2;           //PCS
            .rxpmarstb3                               (rxpmarstb[3]               ),                        //output          rx_pma_rstb3;           //PCS
            .rxpmarstb4                               (rxpmarstb[4]               ),                        //output          rx_pma_rstb4;           //PCS
            .rxpmarstb5                               (rxpmarstb[5]               ),                        //output          rx_pma_rstb5;           //PCS
            .rxpmarstb6                               (rxpmarstb[6]               ),                        //output          rx_pma_rstb6;           //PCS
            .rxpmarstb7                               (rxpmarstb[7]               ),                        //output          rx_pma_rstb7;           //PCS
            .rxpmarstb8                               (rxpmarstb[8]               ),                        //output          rx_pma_rstb8;           //PCS
            .rxsopvc00                                (rx_st_sop_vc0[0]              ),                //output          rx_sop_vc0_0;           //PLD
            .rxsopvc01                                (rx_st_sop_vc0[1]              ),                //output          rx_sop_vc0_1;           //PLD
            .rxvalidvc0                               (rx_st_valid_vc0               ),                //output          rx_valid_vc0;           //PLD
            .rxpolarity0                              (rxpolarity0                ),                        //output          rxpolarity0;            //PCS
            .rxpolarity1                              (rxpolarity1                ),                        //output          rxpolarity1;            //PCS
            .rxpolarity2                              (rxpolarity2                ),                        //output          rxpolarity2;            //PCS
            .rxpolarity3                              (rxpolarity3                ),                        //output          rxpolarity3;            //PCS
            .rxpolarity4                              (rxpolarity4                ),                        //output          rxpolarity4;            //PCS
            .rxpolarity5                              (rxpolarity5                ),                        //output          rxpolarity5;            //PCS
            .rxpolarity6                              (rxpolarity6                ),                        //output          rxpolarity6;            //PCS
            .rxpolarity7                              (rxpolarity7                ),                        //output          rxpolarity7;            //PCS
            .serrout                                  (serr_out                   ),                   //output          serr_out;               //PLD
            .successfulspeednegotiationint            (successful_speed_negotiation_int),              //output          successful_speed_negotiation_int;
            .swdnwake                                 (swdn_wake                  ),                   //output          swdn_wake;              //PLD
            .swuphotrst                               (swup_hotrst                ),                   //output          swup_hotrst;            //PLD
            .testouthip                               (test_out                   ),                   //output [63:0]   test_out_hip;           //PLD
            .tlappintaack                             (tl_app_inta_ack            ),                   //output          tl_app_inta_ack;        //PLD
            .tlappintback                             (tl_app_intb_ack            ),                   //output          tl_app_intb_ack;        //PLD
            .tlappintcack                             (tl_app_intc_ack            ),                   //output          tl_app_intc_ack;        //PLD
            .tlappintdack                             (tl_app_intd_ack            ),                   //output          tl_app_intd_ack;        //PLD
            .tlappmsiack                              (tl_app_msi_ack             ),                   //output          tl_app_msi_ack;         //PLD
            .tlcfgadd                                 (tl_cfg_add_hip             ),                   //output [6:0]    tl_cfg_add;             //PLD
            .tlcfgctl                                 (tl_cfg_ctl_hip             ),                   //output [31:0]   tl_cfg_ctl;             //PLD
            .tlcfgctlwr                               (tl_cfg_ctl_wr_hip          ),                   //output          tl_cfg_ctl_wr;          //PLD
            .tlcfgsts                                 (tl_cfg_sts_hip             ),                   //output [122:0]  tl_cfg_sts;             //PLD
            .tlcfgstswr                               (tl_cfg_sts_wr_hip          ),                   //output          tl_cfg_sts_wr;          //PLD
            .tlpmetosr                                (tl_pme_to_sr               ),                   //output          tl_pme_to_sr;           //PLD
            .txcreddatafccp                           (tx_cred_datafccp           ),                   //output  [11:0]  tx_cred_data_fc_cp;     //PLD TL to AL Signals the Data credit of the received FC completion
            .txcreddatafcnp                           (tx_cred_datafcnp           ),                   //output  [11:0]  tx_cred_data_fc_np;     //PLD TL to AL Signals the Data credit of the received FC Non Posted
            .txcreddatafcp                            (tx_cred_datafcp            ),                   //output  [11:0]  tx_cred_data_fc_p;      //PLD TL to AL Signals the Data credit of the received FC Posted
            .txcredfchipcons                          (tx_cred_fchipcons          ),                   //output  [5:0]   tx_cred_fc_hip_cons;    //PLD TL to AL Indicates that HIP consumed one of PH PD, NPH, NPD, CH, CD
            .txcredfcinfinite                         (tx_cred_fcinfinite         ),                   //output  [5:0]   tx_cred_fc_infinite;    //PLD TL to AL Indicates if this is an infinite credit PH PD, NPH, NPD, CH, CD
            .txcredhdrfccp                            (tx_cred_hdrfccp            ),                   //output  [7:0]   tx_cred_hdr_fc_cp;      //PLD TL to AL Header credit of the received FC completion.
            .txcredhdrfcnp                            (tx_cred_hdrfcnp            ),                   //output  [7:0]   tx_cred_hdr_fc_np;      //PLD TL to AL Header credit of the received FC Non Posted
            .txcredhdrfcp                             (tx_cred_hdrfcp             ),                   //output  [7:0]   tx_cred_hdr_fc_p;       //PLD TL to AL Header credit of the received FC Posted.
            .txcredvc0                                (tx_cred_vc0                ),                   //output [35:0]   tx_cred_vc0;            //PLD
            .txdeemph0                                (txdeemph0               ),                           //output          tx_deemph0;             //PCS
            .txdeemph1                                (txdeemph1               ),                           //output          tx_deemph1;             //PCS
            .txdeemph2                                (txdeemph2               ),                           //output          tx_deemph2;             //PCS
            .txdeemph3                                (txdeemph3               ),                           //output          tx_deemph3;             //PCS
            .txdeemph4                                (txdeemph4               ),                           //output          tx_deemph4;             //PCS
            .txdeemph5                                (txdeemph5               ),                           //output          tx_deemph5;             //PCS
            .txdeemph6                                (txdeemph6               ),                           //output          tx_deemph6;             //PCS
            .txdeemph7                                (txdeemph7               ),                           //output          tx_deemph7;             //PCS
            .txfifoemptyvc0                           (tx_fifo_empty_vc0       ),                           //output          tx_fifo_empty_vc0;      //PLD
            .txfifofullvc0                            (tx_fifo_full_vc0        ),                           //output          tx_fifo_full_vc0;       //PLD
            .txfifordpvc0                             (tx_fifo_rdp_vc0         ),                           //output [3:0]    tx_fifo_rdp_vc0;        //PLD
            .txfifowrpvc0                             (tx_fifo_wrp_vc0         ),                           //output [3:0]    tx_fifo_wrp_vc0;        //PLD
            .txmargin0                                (txmargin0               ),                           //output [2:0]    tx_margin0;             //PCS
            .txmargin1                                (txmargin1               ),                           //output [2:0]    tx_margin1;             //PCS
            .txmargin2                                (txmargin2               ),                           //output [2:0]    tx_margin2;             //PCS
            .txmargin3                                (txmargin3               ),                           //output [2:0]    tx_margin3;             //PCS
            .txmargin4                                (txmargin4               ),                           //output [2:0]    tx_margin4;             //PCS
            .txmargin5                                (txmargin5               ),                           //output [2:0]    tx_margin5;             //PCS
            .txmargin6                                (txmargin6               ),                           //output [2:0]    tx_margin6;             //PCS
            .txmargin7                                (txmargin7               ),                           //output [2:0]    tx_margin7;             //PCS
            .txpcsrstn0                               (txpcsrstn[0]            ),                           //output          tx_pcs_rst_n0;          //PCS
            .txpcsrstn1                               (txpcsrstn[1]            ),                           //output          tx_pcs_rst_n1;          //PCS
            .txpcsrstn2                               (txpcsrstn[2]            ),                           //output          tx_pcs_rst_n2;          //PCS
            .txpcsrstn3                               (txpcsrstn[3]            ),                           //output          tx_pcs_rst_n3;          //PCS
            .txpcsrstn4                               (txpcsrstn[4]            ),                           //output          tx_pcs_rst_n4;          //PCS
            .txpcsrstn5                               (txpcsrstn[5]            ),                           //output          tx_pcs_rst_n5;          //PCS
            .txpcsrstn6                               (txpcsrstn[6]            ),                           //output          tx_pcs_rst_n6;          //PCS
            .txpcsrstn7                               (txpcsrstn[7]            ),                           //output          tx_pcs_rst_n7;          //PCS
            .txpcsrstn8                               (txpcsrstn[8]            ),                           //output          tx_pcs_rst_n8;          //PCS
            .txpmasyncp0                              (txpmasyncp[0]           ),                           //output          tx_pma_syncp0;          //PCS
            .txpmasyncp1                              (txpmasyncp[1]           ),                           //output          tx_pma_syncp1;          //PCS
            .txpmasyncp2                              (txpmasyncp[2]           ),                           //output          tx_pma_syncp2;          //PCS
            .txpmasyncp3                              (txpmasyncp[3]           ),                           //output          tx_pma_syncp3;          //PCS
            .txpmasyncp4                              (txpmasyncp[4]           ),                           //output          tx_pma_syncp4;          //PCS
            .txpmasyncp5                              (txpmasyncp[5]           ),                           //output          tx_pma_syncp5;          //PCS
            .txpmasyncp6                              (txpmasyncp[6]           ),                           //output          tx_pma_syncp6;          //PCS
            .txpmasyncp7                              (txpmasyncp[7]           ),                           //output          tx_pma_syncp7;          //PCS
            .txpmasyncp8                              (txpmasyncp[8]           ),                           //output          tx_pma_syncp8;          //PCS
            .txreadyvc0                               (tx_st_ready_vc0         ),                           //output          tx_ready_vc0;           //PLD
            .txcompl0                                 (txcompl0                ),                           //output          txcompl0;               //PCS
            .txcompl1                                 (txcompl1                ),                           //output          txcompl1;               //PCS
            .txcompl2                                 (txcompl2                ),                           //output          txcompl2;               //PCS
            .txcompl3                                 (txcompl3                ),                           //output          txcompl3;               //PCS
            .txcompl4                                 (txcompl4                ),                           //output          txcompl4;               //PCS
            .txcompl5                                 (txcompl5                ),                           //output          txcompl5;               //PCS
            .txcompl6                                 (txcompl6                ),                           //output          txcompl6;               //PCS
            .txcompl7                                 (txcompl7                ),                           //output          txcompl7;               //PCS
            //PIPE signals between PCS and HIP
            .txdata0                                  (txdata0                 ),                           //output [7:0]    txdata0;                //PCS
            .txdata1                                  (txdata1                 ),                           //output [7:0]    txdata1;                //PCS
            .txdata2                                  (txdata2                 ),                           //output [7:0]    txdata2;                //PCS
            .txdata3                                  (txdata3                 ),                           //output [7:0]    txdata3;                //PCS
            .txdata4                                  (txdata4                 ),                           //output [7:0]    txdata4;                //PCS
            .txdata5                                  (txdata5                 ),                           //output [7:0]    txdata5;                //PCS
            .txdata6                                  (txdata6                 ),                           //output [7:0]    txdata6;                //PCS
            .txdata7                                  (txdata7                 ),                           //output [7:0]    txdata7;                //PCS
            .txdatak0                                 (txdatak0                ),                           //output          txdatak0;               //PCS
            .txdatak1                                 (txdatak1                ),                           //output          txdatak1;               //PCS
            .txdatak2                                 (txdatak2                ),                           //output          txdatak2;               //PCS
            .txdatak3                                 (txdatak3                ),                           //output          txdatak3;               //PCS
            .txdatak4                                 (txdatak4                ),                           //output          txdatak4;               //PCS
            .txdatak5                                 (txdatak5                ),                           //output          txdatak5;               //PCS
            .txdatak6                                 (txdatak6                ),                           //output          txdatak6;               //PCS
            .txdatak7                                 (txdatak7                ),                           //output          txdatak7;               //PCS
            .txdetectrx0                              (txdetectrx0             ),                           //output          txdetectrx0;            //PCS
            .txdetectrx1                              (txdetectrx1             ),                           //output          txdetectrx1;            //PCS
            .txdetectrx2                              (txdetectrx2             ),                           //output          txdetectrx2;            //PCS
            .txdetectrx3                              (txdetectrx3             ),                           //output          txdetectrx3;            //PCS
            .txdetectrx4                              (txdetectrx4             ),                           //output          txdetectrx4;            //PCS
            .txdetectrx5                              (txdetectrx5             ),                           //output          txdetectrx5;            //PCS
            .txdetectrx6                              (txdetectrx6             ),                           //output          txdetectrx6;            //PCS
            .txdetectrx7                              (txdetectrx7             ),                           //output          txdetectrx7;            //PCS
            .txelecidle0                              (txelecidle0             ),                           //output          txelecidle0;            //PCS
            .txelecidle1                              (txelecidle1             ),                           //output          txelecidle1;            //PCS
            .txelecidle2                              (txelecidle2             ),                           //output          txelecidle2;            //PCS
            .txelecidle3                              (txelecidle3             ),                           //output          txelecidle3;            //PCS
            .txelecidle4                              (txelecidle4             ),                           //output          txelecidle4;            //PCS
            .txelecidle5                              (txelecidle5             ),                           //output          txelecidle5;            //PCS
            .txelecidle6                              (txelecidle6             ),                           //output          txelecidle6;            //PCS
            .txelecidle7                              (txelecidle7             ),                           //output          txelecidle7;            //PCS
            .txswing0                                 (txswing0                ),                           //output          txswing0;               //PCS-PMA
            .txswing1                                 (txswing1                ),                           //output          txswing1;               //PCS-PMA
            .txswing2                                 (txswing2                ),                           //output          txswing2;               //PCS-PMA
            .txswing3                                 (txswing3                ),                           //output          txswing3;               //PCS-PMA
            .txswing4                                 (txswing4                ),                           //output          txswing4;               //PCS-PMA
            .txswing5                                 (txswing5                ),                           //output          txswing5;               //PCS-PMA
            .txswing6                                 (txswing6                ),                           //output          txswing6;               //PCS-PMA
            .txswing7                                 (txswing7                ),                           //output          txswing7;               //PCS-PMA
            .wakeoen                                  (wakeoen                 )                            //output          wake_oen;               //PLD
               );
      end
   end
   endgenerate

   generate begin : g_pcie_xcvr
      if (USE_HARD_RESET==0) begin
            av_xcvr_pipe_native_hip
               #(
                  .lanes                              (LANES                             ), //legal value: 1+
                  .starting_channel_number            (starting_channel_number           ), //legal value: 0+
                  .protocol_version                   (protocol_version                  ), //legal value: "gen1", "gen2"
                  .deser_factor                       (deser_factor                      ),
                  .pll_refclk_freq                    (pll_refclk_freq                   ), //legal value = "100 MHz", "125 MHz"
                  .hip_hard_reset                     (hip_hard_reset                    ), //legal value = "100 MHz", "125 MHz"
                  .hip_enable                         (hip_enable                        ),
                  .pipe12_rpre_emph_a_val             (rpre_emph_a_val                   ),
                  .pipe12_rpre_emph_b_val             (rpre_emph_b_val                   ),
                  .pipe12_rpre_emph_c_val             (rpre_emph_c_val                   ),
                  .pipe12_rpre_emph_d_val             (rpre_emph_d_val                   ),
                  .pipe12_rpre_emph_e_val             (rpre_emph_e_val                   ),
                  .pipe12_rvod_sel_a_val              (rvod_sel_a_val                    ),
                  .pipe12_rvod_sel_b_val              (rvod_sel_b_val                    ),
                  .pipe12_rvod_sel_c_val              (rvod_sel_c_val                    ),
                  .pipe12_rvod_sel_d_val              (rvod_sel_d_val                    ),
                  .pipe12_rvod_sel_e_val              (rvod_sel_e_val                    ),
                  .cvp_enable                         (cvp_enable                        )
               ) av_xcvr_pipe_native_hip (
                  .pll_powerdown                      (1'b0), //
                  .tx_digitalreset                    ((pipe_mode==1'b1)?ONES[LANES-1:0]:serdes_tx_digitalreset [LANES-1:0]), //
                  .rx_analogreset                     ((pipe_mode==1'b1)?ONES[LANES-1:0]:serdes_rx_analogreset  [LANES-1:0]), //
                  .tx_analogreset                     ((pipe_mode==1'b1)?1'b0           :serdes_pll_powerdown              ), //
                  .rx_digitalreset                    ((pipe_mode==1'b1)?ONES[LANES-1:0]:serdes_rx_digitalreset [LANES-1:0]), //
                  .rx_cal_busy                        (serdes_rx_cal_busy [LANES-1:0]),
                  .tx_cal_busy                        (serdes_tx_cal_busy [LANES-1:0]),
                  //clk signal
                  .pll_ref_clk                        ((pipe_mode==1'b1)?1'b0:refclk), //
                  .fixedclk                           ((pipe_mode==1'b1)?1'b0:serdes_fixedclk), //
                  //pipe interface ports
                  .pipe_txdata                        (serdes_pipe_txdata             [LANES * deser_factor - 1:0]), //
                  .pipe_txdatak                       (serdes_pipe_txdatak            [((LANES * deser_factor)/8) - 1:0] ), //
                  .pipe_txdetectrx_loopback           (serdes_pipe_txdetectrx_loopback[LANES - 1:0]    ), //?
                  .pipe_txcompliance                  (serdes_pipe_txcompliance       [LANES - 1:0]    ), //
                  .pipe_txelecidle                    (serdes_pipe_txelecidle         [LANES - 1:0]    ), //
                  .pipe_txdeemph                      (serdes_pipe_txdeemph           [LANES - 1:0]    ), //
                  .pipe_txmargin                      (serdes_pipe_txmargin           [LANES * 3 - 1:0]), //
                  .pipe_txswing                       (serdes_pipe_txswing            [LANES - 1:0]    ),
                  .pipe_rate                          (serdes_pipe_rate               [LANES - 1:0]    ),
                  .rate_ctrl                          (serdes_ratectrl                                 ),
                  .pipe_powerdown                     (serdes_pipe_powerdown          [LANES * 2 - 1:0]), //
                  .pipe_rxdata                        (serdes_pipe_rxdata             [LANES * deser_factor - 1:0]      ), //
                  .pipe_rxdatak                       (serdes_pipe_rxdatak            [((LANES * deser_factor)/8) - 1:0]), //
                  .pipe_rxvalid                       (serdes_pipe_rxvalid            [LANES - 1:0]                     ), //
                  .pipe_rxpolarity                    (serdes_pipe_rxpolarity         [LANES - 1:0]                     ), //
                  .pipe_rxelecidle                    (serdes_pipe_rxelecidle         [LANES - 1:0]                     ), //
                  .pipe_phystatus                     (serdes_pipe_phystatus          [LANES - 1:0]                     ), //
                  .pipe_rxstatus                      (serdes_pipe_rxstatus           [LANES * 3 - 1:0]                 ), //
                  //non-PIPE ports
                  .rx_eidleinfersel                   (serdes_rx_eidleinfersel        [LANES*3  -1:0]),
                  .rx_set_locktodata                  (serdes_rx_set_locktodata       [LANES-1:0]  ),
                  .rx_set_locktoref                   (serdes_rx_set_locktoref        [LANES-1:0]  ),
                  .tx_invpolarity                     (serdes_tx_invpolarity          [LANES-1:0]  ),
                  .rx_errdetect                       (serdes_rx_errdetect            [((LANES*deser_factor)/8) -1:0]),
                  .rx_disperr                         (serdes_rx_disperr              [((LANES*deser_factor)/8) -1:0]),
                  .rx_patterndetect                   (serdes_rx_patterndetect        [((LANES*deser_factor)/8) -1:0]),
                  .rx_syncstatus                      (serdes_rx_syncstatus           [((LANES*deser_factor)/8) -1:0]),
                  .rx_phase_comp_fifo_error           (serdes_rx_phase_comp_fifo_error[LANES-1:0]  ),
                  .tx_phase_comp_fifo_error           (serdes_tx_phase_comp_fifo_error[LANES-1:0]  ),
                  .rx_is_lockedtoref                  (serdes_rx_is_lockedtoref       [LANES-1:0]  ),
                  .rx_signaldetect                    (serdes_rx_signaldetect         [LANES-1:0]  ),
                  .rx_is_lockedtodata                 (serdes_rx_is_lockedtodata      [LANES-1:0]  ),
                  .pll_locked                         (serdes_pll_locked_xcvr                      ),
                  .frefclk                            (serdes_frefclk                              ),// HIP input
                  //non-MM ports
                  .rx_serial_data                     (serdes_rx_serial_data[LANES-1:0]            ),
                  .tx_serial_data                     (serdes_tx_serial_data[LANES-1:0]            ),
                  // Reconfig interface
                  .pld8grxstatus                      (serdes_pld8grxstatus                        ),
                  .reconfig_to_xcvr                   (reconfig_to_xcvr                            ),
                  .reconfig_from_xcvr                 (reconfig_from_xcvr                          ),
                  .pllfixedclkcentral                 (serdes_pllfixedclkcentral                   ),
                  .pllfixedclkch0                     (serdes_pllfixedclkch0                       ),
                  .pllfixedclkch1                     (serdes_pllfixedclkch1                       ),
                  .pipe_pclk                          (serdes_pipe_pclk                            ),
                  .pipe_pclkch1                       (serdes_pipe_pclkch1                         ),
                  .pipe_pclkcentral                   (serdes_pipe_pclkcentral                     ),
                  .in_pld_sync_sm_en                  (in_pld_sync_sm_en                           )
                  );
      end
      else begin
            av_xcvr_pipe_native_hip
               #(
                  .lanes                              (LANES                             ), //legal value: 1+
                  .starting_channel_number            (starting_channel_number           ), //legal value: 0+
                  .protocol_version                   (protocol_version                  ), //legal value: "gen1", "gen2"
                  .deser_factor                       (deser_factor                      ),
                  .pll_refclk_freq                    (pll_refclk_freq                   ), //legal value = "100 MHz", "125 MHz"
                  .hip_hard_reset                     (hip_hard_reset                    ), //legal value = "100 MHz", "125 MHz"
                  .hip_enable                         (hip_enable                        ),
                  .pipe12_rpre_emph_a_val             (rpre_emph_a_val                   ),
                  .pipe12_rpre_emph_b_val             (rpre_emph_b_val                   ),
                  .pipe12_rpre_emph_c_val             (rpre_emph_c_val                   ),
                  .pipe12_rpre_emph_d_val             (rpre_emph_d_val                   ),
                  .pipe12_rpre_emph_e_val             (rpre_emph_e_val                   ),
                  .pipe12_rvod_sel_a_val              (rvod_sel_a_val                    ),
                  .pipe12_rvod_sel_b_val              (rvod_sel_b_val                    ),
                  .pipe12_rvod_sel_c_val              (rvod_sel_c_val                    ),
                  .pipe12_rvod_sel_d_val              (rvod_sel_d_val                    ),
                  .pipe12_rvod_sel_e_val              (rvod_sel_e_val                    ),
                  .cvp_enable                         (cvp_enable                        )
               )
            av_xcvr_pipe_native_hip
               (
                  .pll_powerdown                      (1'b0                                                                ), //
                  .tx_digitalreset                    ((pipe_mode==1'b1)?ONES[LANES-1:0]:serdes_tx_digitalreset [LANES-1:0]), //
                  .rx_analogreset                     ((pipe_mode==1'b1)?ONES[LANES-1:0]:serdes_rx_analogreset  [LANES-1:0]), //
                  .tx_analogreset                     ( (pipe_mode==1'b1)?1'b0           :serdes_pll_powerdown           ), //
                  .rx_digitalreset                    ((pipe_mode==1'b1)?ONES[LANES-1:0]:serdes_rx_digitalreset [LANES-1:0]), //
                  //clk signal
                  .pll_ref_clk                        ((pipe_mode==1'b1)?1'b0:refclk), //
                  .fixedclk                           ((pipe_mode==1'b1)?1'b0:serdes_fixedclk), //
                  //pipe interface ports
                  .pipe_txdata                        (serdes_pipe_txdata             [LANES * deser_factor - 1:0]), //
                  .pipe_txdatak                       (serdes_pipe_txdatak            [((LANES * deser_factor)/8) - 1:0] ), //
                  .pipe_txdetectrx_loopback           (serdes_pipe_txdetectrx_loopback[LANES - 1:0]    ), //?
                  .pipe_txcompliance                  (serdes_pipe_txcompliance       [LANES - 1:0]    ), //
                  .pipe_txelecidle                    (serdes_pipe_txelecidle         [LANES - 1:0]    ), //
                  .pipe_txdeemph                      (serdes_pipe_txdeemph           [LANES - 1:0]    ), //
                  .pipe_txmargin                      (serdes_pipe_txmargin           [LANES * 3 - 1:0]), //
                  .pipe_txswing                       (serdes_pipe_txswing            [LANES - 1:0]    ),
                  .pipe_rate                          (serdes_pipe_rate               [LANES - 1:0]    ),
                  .rate_ctrl                          (serdes_ratectrl                                 ),
                  .pipe_powerdown                     (serdes_pipe_powerdown          [LANES * 2 - 1:0]), //
                  .pipe_rxdata                        (serdes_pipe_rxdata             [LANES * deser_factor - 1:0]      ), //
                  .pipe_rxdatak                       (serdes_pipe_rxdatak            [((LANES * deser_factor)/8) - 1:0]), //
                  .pipe_rxvalid                       (serdes_pipe_rxvalid            [LANES - 1:0]                     ), //
                  .pipe_rxpolarity                    (serdes_pipe_rxpolarity         [LANES - 1:0]                     ), //
                  .pipe_rxelecidle                    (serdes_pipe_rxelecidle         [LANES - 1:0]                     ), //
                  .pipe_phystatus                     (serdes_pipe_phystatus          [LANES - 1:0]                     ), //
                  .pipe_rxstatus                      (serdes_pipe_rxstatus           [LANES * 3 - 1:0]                 ), //
                  //non-PIPE ports
                  .rx_eidleinfersel                   (serdes_rx_eidleinfersel        [LANES*3  -1:0]),
                  .rx_set_locktodata                  (serdes_rx_set_locktodata       [LANES-1:0]  ),
                  .rx_set_locktoref                   (serdes_rx_set_locktoref        [LANES-1:0]  ),
                  .tx_invpolarity                     (serdes_tx_invpolarity          [LANES-1:0]  ),
                  .rx_errdetect                       (serdes_rx_errdetect            [((LANES*deser_factor)/8) -1:0]),
                  .rx_disperr                         (serdes_rx_disperr              [((LANES*deser_factor)/8) -1:0]),
                  .rx_patterndetect                   (serdes_rx_patterndetect        [((LANES*deser_factor)/8) -1:0]),
                  .rx_syncstatus                      (serdes_rx_syncstatus           [((LANES*deser_factor)/8) -1:0]),
                  .rx_phase_comp_fifo_error           (serdes_rx_phase_comp_fifo_error[LANES-1:0]  ),
                  .tx_phase_comp_fifo_error           (serdes_tx_phase_comp_fifo_error[LANES-1:0]  ),
                  .rx_is_lockedtoref                  (serdes_rx_is_lockedtoref       [LANES-1:0]  ),
                  .rx_signaldetect                    (serdes_rx_signaldetect         [LANES-1:0]  ),
                  .rx_is_lockedtodata                 (serdes_rx_is_lockedtodata      [LANES-1:0]  ),
                  .pll_locked                         (serdes_pll_locked_xcvr                      ),
                  //non-MM ports
                  .rx_serial_data                     (serdes_rx_serial_data[LANES-1:0]            ),
                  .tx_serial_data                     (serdes_tx_serial_data[LANES-1:0]            ),
                  // Reconfig interface
                  .pld8grxstatus                       (serdes_pld8grxstatus     ),
                  .reconfig_to_xcvr                    (reconfig_to_xcvr         ),
                  .reconfig_from_xcvr                  (reconfig_from_xcvr       ),
                  .txpcsrstn                           (serdes_txpcsrstn         ),// HIP output
                  .rxpcsrstn                           (serdes_rxpcsrstn         ),// HIP output
                  .txpmasyncp                          (serdes_txpmasyncp        ),// HIP output
                  .rxpmarstb                           (serdes_rxpmarstb         ),// HIP output
                  //.txlcpllrstb                       (serdes_txlcpllrstb       ),// HIP output
                  .offcalen                            (serdes_offcalen          ),// HIP output
                  .frefclk                             (serdes_frefclk           ),// HIP input
                  .offcaldone                          (serdes_offcaldone        ),// HIP input
                  //.txlcplllock                       (serdes_txlcplllock       ),// HIP input
                  .rxfreqtxcmuplllock                 (serdes_rxfreqtxcmuplllock),// HIP input
                  .rxpllphaselock                     (serdes_rxpllphaselock    ),// HIP input
                  //.masktxplllock                    (serdes_masktxplllock     ),// HIP input

                  .pllfixedclkcentral                 (serdes_pllfixedclkcentral                   ),
                  .pllfixedclkch0                     (serdes_pllfixedclkch0                       ),
                  .pllfixedclkch1                     (serdes_pllfixedclkch1                       ),
                  .pipe_pclk                          (serdes_pipe_pclk                            ),
                  .pipe_pclkch1                       (serdes_pipe_pclkch1                         ),
                  .pipe_pclkcentral                   (serdes_pipe_pclkcentral                     ),
                  .in_pld_sync_sm_en                  (in_pld_sync_sm_en                           )
            );
      end
   end
   endgenerate

   assign serdes_txlcplllock[LANES-1:0]   = ONES[LANES-1:0];
//   assign serdes_masktxplllock[LANES-1:0] = ONES[LANES-1:0];


   generate
      begin : g_tl_cfg_sync
         if (use_tl_cfg_sync == 1) begin

            altpcie_tl_cfg_pipe altpcie_tl_cfg_pipe_inst
              (
               .clk (pld_clk),
               .srst (srst),
               .o_tl_cfg_add(tl_cfg_add),
               .o_tl_cfg_ctl(tl_cfg_ctl),
               .o_tl_cfg_ctl_wr(tl_cfg_ctl_wr),
               .o_tl_cfg_sts(tl_cfg_sts),
               .o_tl_cfg_sts_wr(tl_cfg_sts_wr),
               .i_tl_cfg_add(tl_cfg_add_hip),
               .i_tl_cfg_ctl(tl_cfg_ctl_hip),
               .i_tl_cfg_ctl_wr(tl_cfg_ctl_wr_hip),
               .i_tl_cfg_sts(tl_cfg_sts_hip),
               .i_tl_cfg_sts_wr(tl_cfg_sts_wr_hip)
              );
         end else begin
            assign tl_cfg_ctl_wr = tl_cfg_ctl_wr_hip;
            assign tl_cfg_sts_wr = tl_cfg_sts_wr_hip;
            assign tl_cfg_add    = tl_cfg_add_hip;
            assign tl_cfg_ctl    = tl_cfg_ctl_hip;
            assign tl_cfg_sts    = tl_cfg_sts_hip;
         end
      end
   endgenerate


////////////////////////////////////////////////////////////////////////////
// Simulation only

// synthesis translate_off

   wire open_locked;
   wire open_fbclkout;

   generic_pll #        ( .reference_clock_frequency(reference_clock_frequency_parameter), .output_clock_frequency("250.0 MHz") )
      refclk_to_250mhz      ( .refclk(refclk), .outclk(clk250_out), .locked(open_locked),    .fboutclk(open_fbclkout), .rst(1'b0), .fbclk(fbclkout));

   generic_pll #        ( .reference_clock_frequency(reference_clock_frequency_parameter), .output_clock_frequency("500.0 MHz") )
      pll_100mhz_to_500mhz      ( .refclk(refclk), .outclk(clk500_out), .locked(open_locked),    .fboutclk(open_fbclkout), .rst(1'b0), .fbclk(fbclkout));

   assign txdata0_ext                    = (pipe_mode==1'b0)?0:txdata0;
   assign txdata1_ext                    = (pipe_mode==1'b0)?0:txdata1;
   assign txdata2_ext                    = (pipe_mode==1'b0)?0:txdata2;
   assign txdata3_ext                    = (pipe_mode==1'b0)?0:txdata3;
   assign txdata4_ext                    = (pipe_mode==1'b0)?0:txdata4;
   assign txdata5_ext                    = (pipe_mode==1'b0)?0:txdata5;
   assign txdata6_ext                    = (pipe_mode==1'b0)?0:txdata6;
   assign txdata7_ext                    = (pipe_mode==1'b0)?0:txdata7;
   assign txdatak0_ext                   = (pipe_mode==1'b0)?0:txdatak0;
   assign txdatak1_ext                   = (pipe_mode==1'b0)?0:txdatak1;
   assign txdatak2_ext                   = (pipe_mode==1'b0)?0:txdatak2;
   assign txdatak3_ext                   = (pipe_mode==1'b0)?0:txdatak3;
   assign txdatak4_ext                   = (pipe_mode==1'b0)?0:txdatak4;
   assign txdatak5_ext                   = (pipe_mode==1'b0)?0:txdatak5;
   assign txdatak6_ext                   = (pipe_mode==1'b0)?0:txdatak6;
   assign txdatak7_ext                   = (pipe_mode==1'b0)?0:txdatak7;

   assign eidleinfersel0_ext             = (pipe_mode==1'b0)?0:eidleinfersel0                ;
   assign eidleinfersel1_ext             = (pipe_mode==1'b0)?0:eidleinfersel1                ;
   assign eidleinfersel2_ext             = (pipe_mode==1'b0)?0:eidleinfersel2                ;
   assign eidleinfersel3_ext             = (pipe_mode==1'b0)?0:eidleinfersel3                ;
   assign eidleinfersel4_ext             = (pipe_mode==1'b0)?0:eidleinfersel4                ;
   assign eidleinfersel5_ext             = (pipe_mode==1'b0)?0:eidleinfersel5                ;
   assign eidleinfersel6_ext             = (pipe_mode==1'b0)?0:eidleinfersel6                ;
   assign eidleinfersel7_ext             = (pipe_mode==1'b0)?0:eidleinfersel7                ;
   assign powerdown0_ext                 = (pipe_mode==1'b0)?0:powerdown0                    ;
   assign powerdown1_ext                 = (pipe_mode==1'b0)?0:powerdown1                    ;
   assign powerdown2_ext                 = (pipe_mode==1'b0)?0:powerdown2                    ;
   assign powerdown3_ext                 = (pipe_mode==1'b0)?0:powerdown3                    ;
   assign powerdown4_ext                 = (pipe_mode==1'b0)?0:powerdown4                    ;
   assign powerdown5_ext                 = (pipe_mode==1'b0)?0:powerdown5                    ;
   assign powerdown6_ext                 = (pipe_mode==1'b0)?0:powerdown6                    ;
   assign powerdown7_ext                 = (pipe_mode==1'b0)?0:powerdown7                    ;
   assign rxpolarity0_ext                = (pipe_mode==1'b0)?0:rxpolarity0                   ;
   assign rxpolarity1_ext                = (pipe_mode==1'b0)?0:rxpolarity1                   ;
   assign rxpolarity2_ext                = (pipe_mode==1'b0)?0:rxpolarity2                   ;
   assign rxpolarity3_ext                = (pipe_mode==1'b0)?0:rxpolarity3                   ;
   assign rxpolarity4_ext                = (pipe_mode==1'b0)?0:rxpolarity4                   ;
   assign rxpolarity5_ext                = (pipe_mode==1'b0)?0:rxpolarity5                   ;
   assign rxpolarity6_ext                = (pipe_mode==1'b0)?0:rxpolarity6                   ;
   assign rxpolarity7_ext                = (pipe_mode==1'b0)?0:rxpolarity7                   ;
   assign txcompl0_ext                   = (pipe_mode==1'b0)?0:txcompl0                      ;
   assign txcompl1_ext                   = (pipe_mode==1'b0)?0:txcompl1                      ;
   assign txcompl2_ext                   = (pipe_mode==1'b0)?0:txcompl2                      ;
   assign txcompl3_ext                   = (pipe_mode==1'b0)?0:txcompl3                      ;
   assign txcompl4_ext                   = (pipe_mode==1'b0)?0:txcompl4                      ;
   assign txcompl5_ext                   = (pipe_mode==1'b0)?0:txcompl5                      ;
   assign txcompl6_ext                   = (pipe_mode==1'b0)?0:txcompl6                      ;
   assign txcompl7_ext                   = (pipe_mode==1'b0)?0:txcompl7                      ;

   assign txdetectrx0_ext                = (pipe_mode==1'b0)?0:txdetectrx0                   ;
   assign txdetectrx1_ext                = (pipe_mode==1'b0)?0:txdetectrx1                   ;
   assign txdetectrx2_ext                = (pipe_mode==1'b0)?0:txdetectrx2                   ;
   assign txdetectrx3_ext                = (pipe_mode==1'b0)?0:txdetectrx3                   ;
   assign txdetectrx4_ext                = (pipe_mode==1'b0)?0:txdetectrx4                   ;
   assign txdetectrx5_ext                = (pipe_mode==1'b0)?0:txdetectrx5                   ;
   assign txdetectrx6_ext                = (pipe_mode==1'b0)?0:txdetectrx6                   ;
   assign txdetectrx7_ext                = (pipe_mode==1'b0)?0:txdetectrx7                   ;
   assign txelecidle0_ext                = (pipe_mode==1'b0)?0:txelecidle0                   ;
   assign txelecidle1_ext                = (pipe_mode==1'b0)?0:txelecidle1                   ;
   assign txelecidle2_ext                = (pipe_mode==1'b0)?0:txelecidle2                   ;
   assign txelecidle3_ext                = (pipe_mode==1'b0)?0:txelecidle3                   ;
   assign txelecidle4_ext                = (pipe_mode==1'b0)?0:txelecidle4                   ;
   assign txelecidle5_ext                = (pipe_mode==1'b0)?0:txelecidle5                   ;
   assign txelecidle6_ext                = (pipe_mode==1'b0)?0:txelecidle6                   ;
   assign txelecidle7_ext                = (pipe_mode==1'b0)?0:txelecidle7                   ;
   assign txmargin0_ext                  = (pipe_mode==1'b0)?0:txmargin0                     ;
   assign txmargin1_ext                  = (pipe_mode==1'b0)?0:txmargin1                     ;
   assign txmargin2_ext                  = (pipe_mode==1'b0)?0:txmargin2                     ;
   assign txmargin3_ext                  = (pipe_mode==1'b0)?0:txmargin3                     ;
   assign txmargin4_ext                  = (pipe_mode==1'b0)?0:txmargin4                     ;
   assign txmargin5_ext                  = (pipe_mode==1'b0)?0:txmargin5                     ;
   assign txmargin6_ext                  = (pipe_mode==1'b0)?0:txmargin6                     ;
   assign txmargin7_ext                  = (pipe_mode==1'b0)?0:txmargin7                     ;
   assign txdeemph0_ext                  = (pipe_mode==1'b0)?0:txdeemph0                     ;
   assign txdeemph1_ext                  = (pipe_mode==1'b0)?0:txdeemph1                     ;
   assign txdeemph2_ext                  = (pipe_mode==1'b0)?0:txdeemph2                     ;
   assign txdeemph3_ext                  = (pipe_mode==1'b0)?0:txdeemph3                     ;
   assign txdeemph4_ext                  = (pipe_mode==1'b0)?0:txdeemph4                     ;
   assign txdeemph5_ext                  = (pipe_mode==1'b0)?0:txdeemph5                     ;
   assign txdeemph6_ext                  = (pipe_mode==1'b0)?0:txdeemph6                     ;
   assign txdeemph7_ext                  = (pipe_mode==1'b0)?0:txdeemph7                     ;
   assign txswing0_ext                  = (pipe_mode==1'b0)?0:txswing0                     ;
   assign txswing1_ext                  = (pipe_mode==1'b0)?0:txswing1                     ;
   assign txswing2_ext                  = (pipe_mode==1'b0)?0:txswing2                     ;
   assign txswing3_ext                  = (pipe_mode==1'b0)?0:txswing3                     ;
   assign txswing4_ext                  = (pipe_mode==1'b0)?0:txswing4                     ;
   assign txswing5_ext                  = (pipe_mode==1'b0)?0:txswing5                     ;
   assign txswing6_ext                  = (pipe_mode==1'b0)?0:txswing6                     ;
   assign txswing7_ext                  = (pipe_mode==1'b0)?0:txswing7                     ;


// synthesis translate_on


endmodule

//Legal Notice: (C)2009 Altera Corporation. All rights reserved.  Your
//use of Altera Corporation's design tools, logic functions and other
//software and tools, and its AMPP partner logic functions, and any
//output files any of the foregoing (including device programming or
//simulation files), and any associated documentation or information are
//expressly subject to the terms and conditions of the Altera Program
//License Subscription Agreement or other applicable license agreement,
//including, without limitation, that your use is for the sole purpose
//of programming logic devices manufactured by Altera and sold by Altera
//or its authorized distributors.  Please refer to the applicable
//agreement for further details.
// turn off superfluous verilog processor warnings
// altera message_level Level1
// altera message_off 10034 10035 10036 10037 10230 10240 10030

//-----------------------------------------------------------------------------
// Title         : altpcie_tl_cfg_pipe
// Project       : PCI Express MegaCore function
//-----------------------------------------------------------------------------
// File          : altpcie_tl_cfg_pipe.v
// Author        : Altera Corporation
//-----------------------------------------------------------------------------
//
//  Description:  This module is to assist timing closure on TL_CFG bus
//-----------------------------------------------------------------------------

// synthesis translate_off
`timescale 1ns / 1ps
// synthesis translate_on
module altpcie_tl_cfg_pipe
  (
   input                clk,
   input                srst,
   output reg [ 6:0]    o_tl_cfg_add,
   output reg [31:0]    o_tl_cfg_ctl,
   output reg           o_tl_cfg_ctl_wr,
   output reg [122:0]   o_tl_cfg_sts,
   output reg           o_tl_cfg_sts_wr,
   input  [ 6:0]        i_tl_cfg_add,
   input  [31:0]        i_tl_cfg_ctl,
   input                i_tl_cfg_ctl_wr,
   input  [122:0]       i_tl_cfg_sts,
   input                i_tl_cfg_sts_wr
   );

   reg sts_wr_r,sts_wr_rr;
   reg ctl_wr_r,ctl_wr_rr;

   always @ (posedge clk)
     begin
     if (srst) begin
         o_tl_cfg_add <= 6'h0;
         o_tl_cfg_ctl <= {32{1'b0}};
         o_tl_cfg_ctl_wr <= {1{1'b0}};
         o_tl_cfg_sts <= {122{1'b0}};
         o_tl_cfg_sts_wr <= {1{1'b0}};
     end
     else begin
         // sts pipeline
         sts_wr_r <= i_tl_cfg_sts_wr;
         sts_wr_rr <= sts_wr_r;
         o_tl_cfg_sts_wr <= sts_wr_rr;
         if (o_tl_cfg_sts_wr != sts_wr_rr)
            o_tl_cfg_sts <= i_tl_cfg_sts;

         // ctl pipeline
         ctl_wr_r <= i_tl_cfg_ctl_wr;
         ctl_wr_rr <= ctl_wr_r;
         o_tl_cfg_ctl_wr <= ctl_wr_rr;
         if (o_tl_cfg_ctl_wr != ctl_wr_rr) begin
              o_tl_cfg_add <= i_tl_cfg_add;
              o_tl_cfg_ctl <= i_tl_cfg_ctl;
         end
       end
     end
endmodule

// synthesis translate_off
`timescale 1ns / 1ps
// synthesis translate_on
module altpcie_av_hd_dpcmn_bitsync
  #(
    parameter DWIDTH = 1,    // Sync Data input
    parameter SYNCSTAGE = 2, // Sync stages
    parameter RESET_VAL = 0  // Reset value
    )
    (
    input  wire              clk,     // clock
    input  wire              rst_n,   // async reset
    input  wire [DWIDTH-1:0] data_in, // data in
    output wire [DWIDTH-1:0] data_out // data out
     );

   // Define wires/regs
   reg [(DWIDTH*SYNCSTAGE)-1:0] sync_regs;
   wire                         reset_value;

   assign reset_value = (RESET_VAL == 1) ? 1'b1 : 1'b0;  // To eliminate truncating warning

   // Sync Always block
   always @(negedge rst_n or posedge clk) begin
      if (rst_n == 1'b0) begin
         sync_regs[(DWIDTH*SYNCSTAGE)-1:DWIDTH] <= {(DWIDTH*(SYNCSTAGE-1)){reset_value}};
      end
      else begin
         sync_regs[(DWIDTH*SYNCSTAGE)-1:DWIDTH] <= sync_regs[((DWIDTH*(SYNCSTAGE-1))-1):0];
      end
   end

   // Separated out the first stage of FFs without reset
   always @(posedge clk) begin
         sync_regs[DWIDTH-1:0] <= data_in;
   end

   assign data_out = sync_regs[((DWIDTH*SYNCSTAGE)-1):(DWIDTH*(SYNCSTAGE-1))];

endmodule // altpcie_av_hd_dpcmn_bitsync

// synthesis translate_off
`timescale 1ns / 1ps
// synthesis translate_on
module altpcie_av_hd_dpcmn_bitsync2
  #(
    parameter DWIDTH    = 1,    // Sync Data input
    parameter RESET_VAL = 0     // Reset value
    )
    (
    input  wire              clk,     // clock
    input  wire              rst_n,   // async reset
    input  wire [DWIDTH-1:0] data_in, // data in
    output wire [DWIDTH-1:0] data_out // data out
     );

// 2-stage synchronizer
localparam SYNCSTAGE = 2;

// synchronizer
altpcie_av_hd_dpcmn_bitsync
  #(
    .DWIDTH(DWIDTH),        // Sync Data input
    .SYNCSTAGE(SYNCSTAGE),  // Sync stages
    .RESET_VAL(RESET_VAL)   // Reset value
    ) altpcie_av_hd_dpcmn_bitsync2
    (
     .clk(clk),          // clock
     .rst_n(rst_n),      // async reset
     .data_in(data_in),  // data in
     .data_out(data_out) // data out
     );

endmodule // altpcie_av_hd_dpcmn_bitsync2


// synthesis translate_off
`timescale 1ns / 1ps
module arriav_hd_altpe2_hip_top_simu_only_dump (

   // SIMULATION_ONLY: Data link layer status signals
   input clk,
   input rstn,
   input srst,
   input ev128ns,
   input dl_up,
   input err_dll,
   input rx_err_frame,
   input [3:0] lane_act,
   input l0state,
   input l0sstate,
   input [4:0] test_ltssm,
   input link_up,
   input link_train,

   // SIMULATION_ONLY: Receive from PHY MAC to Data Link layer
   input        rx_val_dl,
   input [63:0] rx_data_dl,
   input [7:0]  rx_datak_dl,

   // SIMULATION_ONLY: Transmit : From data link layer to Phy Mac
   input  txok,
   input  sop,
   input  eop,
   input  eot,
   input [63:0] tdata,
   input [7:0] tdatak,

   // SIMULATION_ONLY: Receive from Data link Layer to Transaction Layer
   input[63:0] rx_data_tlp_tl,
   input rx_dval_tlp_tl,
   input rx_fval_tlp_tl,
   input rx_hval_tlp_tl,
   input rx_mlf_tlp_tl,
   input rx_ecrcerr_tlp_tl,
   input rx_discard_tlp_tl,
   input rx_check_tlp_tl,
   input rx_ok_tlp_tl,
   input rx_err_tlp_tl,

   // SIMULATION_ONLY: Transmit from Transaction Layer to Data link Layer
   input tx_req_tlp_tl,
   input tx_ack_tlp_tl,
   input tx_dreq_tlp_tl,
   input tx_err_tlp_tl,
   input[63:0] tx_data_tlp_tl,

   // SIMULATION_ONLY :: Data Link Layer Flow Control RX
   input rx_val_fc,
   input rx_val_fc_real,
   input rx_ini_fc,
   input rx_ini_fc_real,
   input[1:0] rx_typ_fc,
   input[2:0] rx_vcid_fc,
   input[7:0] rx_hdr_fc,
   input[11:0] rx_data_fc,
   // SIMULATION_ONLY :: Data Link Layer Flow Control TX
   input  req_upfc,
   input  snd_upfc,
   input  ack_upfc,
   input  ack_snd_upfc,
   input  ack_req_upfc,
   input  [1:0] typ_upfc,
   input  [2:0] vcid_upfc,
   input  [7:0] hdr_upfc,
   input  [11:0] data_upfc
   );

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//
// SIMULATION_ONLY SIMULATION_ONLY SIMULATION_ONLY
//
// Observation nodes inside Hard IP arriav_hd_altpe2_hip_top
//
//
reg   rx_val_dl_sim;
reg   [63:0] rx_data_dl_sim;
reg   [7:0]  rx_datak_dl_sim;
reg    txok_sim;
reg    sop_sim;
reg    eop_sim;
reg    eot_sim;
reg   [63:0] tdata_sim;
reg   [7:0] tdatak_sim;

reg  [63:0] rx_data_tlp_tl_sim;
reg   rx_dval_tlp_tl_sim;
reg   rx_fval_tlp_tl_sim;
reg   rx_hval_tlp_tl_sim;
reg   rx_mlf_tlp_tl_sim;
reg   rx_ecrcerr_tlp_tl_sim;
reg   rx_discard_tlp_tl_sim;
reg   rx_check_tlp_tl_sim;
reg   rx_ok_tlp_tl_sim;
reg   rx_err_tlp_tl_sim;
reg   tx_req_tlp_tl_sim;
reg   tx_ack_tlp_tl_sim;
reg   tx_dreq_tlp_tl_sim;
reg   tx_err_tlp_tl_sim;
reg  [63:0] tx_data_tlp_tl_sim;
reg   rx_val_fc_sim;
reg   rx_val_fc_real_sim;
reg   rx_ini_fc_sim;
reg   rx_ini_fc_real_sim;
reg  [1:0] rx_typ_fc_sim;
reg  [2:0] rx_vcid_fc_sim;
reg  [7:0] rx_hdr_fc_sim;
reg  [11:0] rx_data_fc_sim;
reg    req_upfc_sim;
reg    snd_upfc_sim;
reg    ack_upfc_sim;
reg    ack_snd_upfc_sim;
reg    ack_req_upfc_sim;
reg    [1:0] typ_upfc_sim;
reg    [2:0] vcid_upfc_sim;
reg    [7:0] hdr_upfc_sim;
reg    [11:0] data_upfc_sim;

reg   rstn_sim;
reg   srst_sim;
reg   ev128ns_sim;
reg   dl_up_sim;
reg   err_dll_sim;
reg   rx_err_frame_sim;
reg   [3:0] lane_act_sim;
reg   l0state_sim;
reg   l0sstate_sim;
reg   [4:0] test_ltssm_sim;
reg   link_up_sim;
reg   link_train_sim;

initial begin
   $display("Info: ======================================================================================================================================");
   $display("Info:                                                                                                ");
   $display("Info:    Module        : arriav_hd_altpe2_hip_top_simu_only_dump                                            ");
   $display("Info:    Description   : Access point to a subset of internal PCI Express Hard IP data link layer signals            ");
   $display("Info:    Instance Path : %m");
   $display("Info:                                                                                                ");
   $display("Info: ======================================================================================================================================");
end
   always @ (*) begin : p_rx_phymac_to_dl
      // SIMULATION_ONLY: Receive from PHY MAC to Data Link layer
      rx_val_dl_sim           = rx_val_dl         ;
      rx_data_dl_sim          = rx_data_dl [63:0] ;
      rx_datak_dl_sim         = rx_datak_dl[7:0]  ;
   end

   always @ (*) begin : p_tx_dl_to_phymac
      // SIMULATION_ONLY: Transmit : From data link layer to Phy Mac
      txok_sim                = txok   ;
      sop_sim                 = sop    ;
      eop_sim                 = eop    ;
      eot_sim                 = eot    ;
      tdata_sim               = tdata  [63:0];
      tdatak_sim              = tdatak [7:0] ;
   end

   always @ (*) begin : p_rx_dl_to_tl
      // SIMULATION_ONLY: Receive from Data link Layer to Transaction Layer
      rx_data_tlp_tl_sim      = rx_data_tlp_tl  [63:0];
      rx_dval_tlp_tl_sim      = rx_dval_tlp_tl        ;
      rx_fval_tlp_tl_sim      = rx_fval_tlp_tl        ;
      rx_hval_tlp_tl_sim      = rx_hval_tlp_tl        ;
      rx_mlf_tlp_tl_sim       = rx_mlf_tlp_tl         ;
      rx_ecrcerr_tlp_tl_sim   = rx_ecrcerr_tlp_tl     ;
      rx_discard_tlp_tl_sim   = rx_discard_tlp_tl     ;
      rx_check_tlp_tl_sim     = rx_check_tlp_tl       ;
      rx_ok_tlp_tl_sim        = rx_ok_tlp_tl          ;
      rx_err_tlp_tl_sim       = rx_err_tlp_tl         ;
   end

   always @ (*) begin : p_tx_tl_to_dl
      // SIMULATION_ONLY: Transmit from Transaction Layer to Data link Layer
      tx_req_tlp_tl_sim       = tx_req_tlp_tl        ;
      tx_ack_tlp_tl_sim       = tx_ack_tlp_tl        ;
      tx_dreq_tlp_tl_sim      = tx_dreq_tlp_tl       ;
      tx_err_tlp_tl_sim       = tx_err_tlp_tl        ;
      tx_data_tlp_tl_sim      = tx_data_tlp_tl[63:0] ;
   end

   always @ (*) begin : p_dlink_flow_control
      // SIMULATION_ONLY :: Data Link Layer Flow Control RX
      rx_val_fc_sim           = rx_val_fc;
      rx_val_fc_real_sim      = rx_val_fc_real;
      rx_ini_fc_sim           = rx_ini_fc;
      rx_ini_fc_real_sim      = rx_ini_fc_real;
      rx_typ_fc_sim           = rx_typ_fc;
      rx_vcid_fc_sim          = rx_vcid_fc;
      rx_hdr_fc_sim           = rx_hdr_fc;
      rx_data_fc_sim          = rx_data_fc        ;

      // SIMULATION_ONLY :: Data Link Layer Flow Control TX
      req_upfc_sim            = req_upfc;
      snd_upfc_sim            = snd_upfc;
      ack_upfc_sim            = ack_upfc;
      ack_snd_upfc_sim        = ack_snd_upfc;
      ack_req_upfc_sim        = ack_req_upfc;
      typ_upfc_sim            = typ_upfc  [1:0] ;
      vcid_upfc_sim           = vcid_upfc [2:0] ;
      hdr_upfc_sim            = hdr_upfc  [7:0] ;
      data_upfc_sim           = data_upfc [11:0];
   end

   always @ (*) begin : p_dlink_status
      rstn_sim         = rstn;
      srst_sim         = srst;
      ev128ns_sim      = ev128ns;
      dl_up_sim        = dl_up;
      err_dll_sim      = err_dll;
      lane_act_sim     = lane_act;
      l0state_sim      = l0state;
      l0sstate_sim     = l0sstate;
      test_ltssm_sim   = test_ltssm;
      link_up_sim      = link_up;
      link_train_sim   = link_train;
      rx_err_frame_sim = rx_err_frame;
   end
// SIMULATION_ONLY SIMULATION_ONLY SIMULATION_ONLY
//
// End of observation nodes inside Hard IP arriav_hd_altpe2_hip_top
//
//
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
endmodule // module arriav_hd_altpe2_hip_top_simu_only_dump

// synthesis translate_on
