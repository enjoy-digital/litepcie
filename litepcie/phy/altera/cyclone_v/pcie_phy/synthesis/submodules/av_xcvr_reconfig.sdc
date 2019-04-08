# (C) 2001-2018 Intel Corporation. All rights reserved.
# Your use of Intel Corporation's design tools, logic functions and other 
# software and tools, and its AMPP partner logic functions, and any output 
# files from any of the foregoing (including device programming or simulation 
# files), and any associated documentation or information are expressly subject 
# to the terms and conditions of the Intel Program License Subscription 
# Agreement, Intel FPGA IP License Agreement, or other applicable 
# license agreement, including, without limitation, that your use is for the 
# sole purpose of programming logic devices manufactured by Intel and sold by 
# Intel or its authorized distributors.  Please refer to the applicable 
# agreement for further details.


# SDC file for alt_xcvr_reconfig
# You will need to adjust the constraints based on your design
#**************************************************************
# Create Clock
#  -enable and edit these two constraints to fit your design
#**************************************************************

# Note - the source for the mgmt_clk_clk should be set to whatever parent port drives the alt_xcvr_reconfig's mgmt_clk_clk port
#create_clock -period 10ns  -name {mgmt_clk_clk} [get_ports {mgmt_clk_clk}]

# Note that the source clock should be the mgmt_clk_clk, or whichever parent clock is driving it
#create_generated_clock -name sv_reconfig_pma_testbus_clk -source [get_ports {mgmt_clk_clk}] -divide_by 1  [get_registers *sv_xcvr_reconfig_basic:s5|*alt_xcvr_arbiter:pif*|*grant*]

# The following constraint is a TCL loop used to generate clocks for the basic block in 
# the reconfiguration controller.  However, if the constraints are already in place
# then comment out this loop, as timequest will report warnings for overwriting
# clocks.  An alternative is to use the commented constraint above.  It needs to be 
# modified to fit the design.
#
# Procedure: 
# First, Report a collection of clocks to reg_init[0], which is the reconfig clk.  
# Next, for each item in the collection, we report the upper hierarchy up to reg_init[0], 
# and concatenate pif[0]*|*grant* to create the destination.  We use the value of
# count to create unique names of the clock instince.  Then increment count.
set count 0

# If the generated clocks for the pmatestbus (grant[0]) already exist, then do not regenerate them.
if { [get_collection_size [get_clocks -nowarn sv_reconfig_pma_testbus_clk_?]] eq 0 } {
  set grant_clk [get_pins -compatibility_mode -no_duplicates *\|basic\|a5\|reg_init\[0\]\|clk]
  foreach_in_collection reconfig_clk $grant_clk {
    set reconfig_clk [get_object_info -name $reconfig_clk]
    if [regexp {^(.*.)(?=reg_init)} $reconfig_clk grant_clk] {
      create_generated_clock -add -name sv_reconfig_pma_testbus_clk_$count -source [get_pins -compatibility_mode -no_duplicates $reconfig_clk] -divide_by 1  [get_registers $grant_clk*pif[0]*\|*grant*]
      set_clock_groups -exclusive -group [get_clocks sv_reconfig_pma_testbus_clk_$count]
      incr count
    }
  }
}

#**************************************************************
# False paths
#**************************************************************
# testbus not an actual clock - set asynchronous to all other clocks
# Comment this back in if you are using the commented constraints above
# for creating generated clocks.
#set_clock_groups -exclusive -group [get_clocks {sv_reconfig_pma_testbus_clk}]

