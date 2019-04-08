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


// Top-level definitions for transceiver reconfig IP
//
// $Header$
//
// PACKAGE DECLARATION
package alt_xcvr_reconfig_h;

        ////////////////////////////////////////////////////////
        // Top-level register map for transceiver reconfig IP
        ////////////////////////////////////////////////////////
        localparam W_XR_ADDR = 7;               // address width on mgmt interface
        localparam W_XR_FEATURE_LADDR = 3; // address width of standard feature block, and basic logical interface
        typedef bit [W_XR_ADDR         -1:0] t_xreconf_addr;
        typedef bit [W_XR_FEATURE_LADDR-1:0] t_xr_feature_addr;

  // Feature block indices (used for address decoding for each block)
  localparam INDEX_XR_OFFSET  = 0;
  localparam INDEX_XR_ANALOG  = 1;
  localparam INDEX_XR_EYEMON  = 2;
  localparam INDEX_XR_DFE     = 3;
  localparam INDEX_XR_DIRECT  = 4;
  localparam INDEX_XR_ADCE    = 5;
  localparam INDEX_XR_LC      = 6;
  localparam INDEX_XR_MIF     = 7;
  localparam INDEX_XR_PLL     = 8;
  localparam INDEX_XR_DCD     = 9;
  localparam INDEX_XR_END     = 10;  // must always mark end of address space

        // Each feature block is allocated an 8-word address range
  localparam [W_XR_ADDR-1:0] ADDR_XR_OFFSET_BASE = t_xreconf_addr'(INDEX_XR_OFFSET << W_XR_FEATURE_LADDR);
  localparam [W_XR_ADDR-1:0] ADDR_XR_ANALOG_BASE = t_xreconf_addr'(INDEX_XR_ANALOG << W_XR_FEATURE_LADDR);
  localparam [W_XR_ADDR-1:0] ADDR_XR_EYEMON_BASE = t_xreconf_addr'(INDEX_XR_EYEMON << W_XR_FEATURE_LADDR);
  localparam [W_XR_ADDR-1:0] ADDR_XR_DFE_BASE    = t_xreconf_addr'(INDEX_XR_DFE    << W_XR_FEATURE_LADDR);
  localparam [W_XR_ADDR-1:0] ADDR_XR_DIRECT_BASE = t_xreconf_addr'(INDEX_XR_DIRECT << W_XR_FEATURE_LADDR);
  localparam [W_XR_ADDR-1:0] ADDR_XR_ADCE_BASE   = t_xreconf_addr'(INDEX_XR_ADCE   << W_XR_FEATURE_LADDR);
  localparam [W_XR_ADDR-1:0] ADDR_XR_LC_BASE     = t_xreconf_addr'(INDEX_XR_LC     << W_XR_FEATURE_LADDR);
  localparam [W_XR_ADDR-1:0] ADDR_XR_MIF_BASE    = t_xreconf_addr'(INDEX_XR_MIF    << W_XR_FEATURE_LADDR);
  localparam [W_XR_ADDR-1:0] ADDR_XR_PLL_BASE    = t_xreconf_addr'(INDEX_XR_PLL    << W_XR_FEATURE_LADDR);
  localparam [W_XR_ADDR-1:0] ADDR_XR_DCD_BASE    = t_xreconf_addr'(INDEX_XR_DCD    << W_XR_FEATURE_LADDR);
  localparam [W_XR_ADDR-1:0] ADDR_XR_END_BASE    = t_xreconf_addr'(INDEX_XR_END    << W_XR_FEATURE_LADDR);  // must always mark end of address space

  localparam [W_XR_FEATURE_LADDR-1:0] XR_STATUS_OFST            = t_xr_feature_addr'(2);
  localparam                          XR_STATUS_OFST_COMB_BUSY = 8;

        ////////////////////////////////////////////////////////
        // Offset Cancellation block addresses
        ////////////////////////////////////////////////////////
        localparam [W_XR_ADDR-1:0] ADDR_XR_OFFSET_STATUS = t_xreconf_addr'(ADDR_XR_OFFSET_BASE + 2);


        ////////////////////////////////////////////////////////
        // Analog block addresses 
        ////////////////////////////////////////////////////////
        localparam [W_XR_ADDR-1:0] ADDR_XR_ANALOG_LCH    = t_xreconf_addr'(ADDR_XR_ANALOG_BASE + 0);
        localparam [W_XR_ADDR-1:0] ADDR_XR_ANALOG_PCH    = t_xreconf_addr'(ADDR_XR_ANALOG_BASE + 1);
        localparam [W_XR_ADDR-1:0] ADDR_XR_ANALOG_STATUS = t_xreconf_addr'(ADDR_XR_ANALOG_BASE + 2);
        localparam [W_XR_ADDR-1:0] ADDR_XR_ANALOG_OFFSET = t_xreconf_addr'(ADDR_XR_ANALOG_BASE + 3);
        localparam [W_XR_ADDR-1:0] ADDR_XR_ANALOG_DATA   = t_xreconf_addr'(ADDR_XR_ANALOG_BASE + 4);

        // Analog internal register offsets
        // These are to be written to the analog offset address register, ADDR_XR_ANALOG_OFFSET
        localparam XR_ANALOG_OFFSET_VOD = 0;
        localparam XR_ANALOG_OFFSET_PREEMPH0T = 1;
        localparam XR_ANALOG_OFFSET_PREEMPH1T = 2;
        localparam XR_ANALOG_OFFSET_PREEMPH2T = 3;
        localparam XR_ANALOG_OFFSET_RXDCGAIN = 16;
        localparam XR_ANALOG_OFFSET_RXEQCTRL = 17;
        localparam XR_ANALOG_OFFSET_PRECDRLPBK = 32;
        localparam XR_ANALOG_OFFSET_POSTCDRLPBK = 33;   

        ////////////////////////////////////////////////////////
        // DFE block addresses 
        ////////////////////////////////////////////////////////
        localparam [W_XR_ADDR-1:0] ADDR_XR_DFE_LCH    = t_xreconf_addr'(ADDR_XR_DFE_BASE + 0);
        localparam [W_XR_ADDR-1:0] ADDR_XR_DFE_PCH    = t_xreconf_addr'(ADDR_XR_DFE_BASE + 1);
        localparam [W_XR_ADDR-1:0] ADDR_XR_DFE_STATUS = t_xreconf_addr'(ADDR_XR_DFE_BASE + 2);
        localparam [W_XR_ADDR-1:0] ADDR_XR_DFE_OFFSET = t_xreconf_addr'(ADDR_XR_DFE_BASE + 3);
        localparam [W_XR_ADDR-1:0] ADDR_XR_DFE_DATA   = t_xreconf_addr'(ADDR_XR_DFE_BASE + 4);
                
        // DFE internal register offsets
        // These are to be written to the DFE offset address register, ADDR_XR_DFE_OFFSET
        localparam XR_DFE_OFFSET_CTRL      = 0;
        localparam XR_DFE_OFFSET_TAP1      = 1;
        localparam XR_DFE_OFFSET_TAP2      = 2;
        localparam XR_DFE_OFFSET_TAP3      = 3;
        localparam XR_DFE_OFFSET_TAP4      = 4;
        localparam XR_DFE_OFFSET_TAP5      = 5;
        localparam XR_DFE_OFFSET_REF       = 6;
        localparam XR_DFE_OFFSET_STEP      = 7;
        localparam XR_DFE_OFFSET_ADAPT_TIME= 8;
        localparam XR_DFE_OFFSET_RUN       = 10;
        localparam XR_DFE_OFFSET_TAP_ADAPT = 11;
        localparam XR_DFE_OFFSET_DFE12     = 18;
        localparam XR_DFE_OFFSET_DFE13     = 19;
        localparam XR_DFE_OFFSET_DFE14     = 20;
        localparam XR_DFE_OFFSET_DFE15     = 21;
        localparam XR_DFE_OFFSET_CAL_PLL   = 22;
        localparam XR_DFE_OFFSET_CAL_TBUS  = 23;
        localparam XR_DFE_OFFSET_CAL_SAMPL = 24;
        localparam XR_DFE_OFFSET_CAL_RESET = 25;
        localparam XR_DFE_OFFSET_ADAPT_WAIT = 26;
        localparam XR_DFE_OFFSET_ADAPT_COUNT= 27;

        ////////////////////////////////////////////////////////
        // Eyemon block addresses
        ////////////////////////////////////////////////////////
        localparam [W_XR_ADDR-1:0] ADDR_XR_EYEMON_LCH     = t_xreconf_addr'(ADDR_XR_EYEMON_BASE + 0);
        localparam [W_XR_ADDR-1:0] ADDR_XR_EYEMON_PCH     = t_xreconf_addr'(ADDR_XR_EYEMON_BASE + 1);
        localparam [W_XR_ADDR-1:0] ADDR_XR_EYEMON_STATUS  = t_xreconf_addr'(ADDR_XR_EYEMON_BASE + 2);
        localparam [W_XR_ADDR-1:0] ADDR_XR_EYEMON_OFFSET  = t_xreconf_addr'(ADDR_XR_EYEMON_BASE + 3);
        localparam [W_XR_ADDR-1:0] ADDR_XR_EYEMON_DATA    = t_xreconf_addr'(ADDR_XR_EYEMON_BASE + 4);

        // EYEMON internal register offsets
        // These are to be written to the EYEMON offset address register, ADDR_XR_EYEMON_OFFSET
        localparam XR_EYEMON_OFFSET_CTRL     = 0;
        localparam XR_EYEMON_OFFSET_HPHASE   = 1;
        localparam XR_EYEMON_OFFSET_VHEIGHT  = 2;
        localparam XR_EYEMON_OFFSET_EYEMON16 = 3;
        localparam XR_EYEMON_OFFSET_EYEMON17 = 4;
        localparam XR_EYEMON_OFFSET_BIT_LOW  = 5;
        localparam XR_EYEMON_OFFSET_BIT_HI   = 6;
        localparam XR_EYEMON_OFFSET_ERR_LOW  = 7;
        localparam XR_EYEMON_OFFSET_ERR_HI   = 8;
        localparam XR_EYEMON_OFFSET_EXCP_LOW = 9;
        localparam XR_EYEMON_OFFSET_BERTHRESH= 10;

        ////////////////////////////////////////////////////////
        // ADCE block addresses 
        ////////////////////////////////////////////////////////
        localparam [W_XR_ADDR-1:0] ADDR_XR_ADCE_LCH    = t_xreconf_addr'(ADDR_XR_ADCE_BASE + 0); // Logical  channel number
        localparam [W_XR_ADDR-1:0] ADDR_XR_ADCE_PCH    = t_xreconf_addr'(ADDR_XR_ADCE_BASE + 1); // Physical channel number
        localparam [W_XR_ADDR-1:0] ADDR_XR_ADCE_STATUS = t_xreconf_addr'(ADDR_XR_ADCE_BASE + 2);
        localparam [W_XR_ADDR-1:0] ADDR_XR_ADCE_OFFSET = t_xreconf_addr'(ADDR_XR_ADCE_BASE + 3);
        localparam [W_XR_ADDR-1:0] ADDR_XR_ADCE_DATA   = t_xreconf_addr'(ADDR_XR_ADCE_BASE + 4);
                
        // ADCE internal register offsets
        // These are to be written to the ADCE offset address register, ADDR_XR_ADCE_OFFSET
        localparam XR_ADCE_OFFSET_CTRL        =  0;
        localparam XR_ADCE_OFFSET_RESULTS     =  1; // Manual setting equivalent to ADCE results
        localparam XR_ADCE_OFFSET_BW          =  2;
        localparam XR_ADCE_OFFSET_TIMEOUT     =  3; // Timeout override register for adapt_done signal 
        localparam XR_ADCE_OFFSET_RADCE_ATT_0 =  9; // radce_att[15: 0]
        localparam XR_ADCE_OFFSET_RADCE_ATT_1 = 10; // radce_att[31:15]
        localparam XR_ADCE_OFFSET_RADCE_ATT_2 = 11; // radce_att[47:32]
        localparam XR_ADCE_OFFSET_RADCE_ATT_3 = 12; // radce_att[63:48]
        localparam XR_ADCE_OFFSET_RADCE_ATT_4 = 13; // radce_att[79:64]
        localparam XR_ADCE_OFFSET_RADCE_ATT_5 = 14; // radce_att[95:80]
        localparam XR_ADCE_OFFSET_RADCE_ATT_6 = 15; // radce_att[111:96]

       ////////////////////////////////////////////////////////
        // DCD block addresses
        ////////////////////////////////////////////////////////
        localparam [W_XR_ADDR-1:0] ADDR_XR_DCD_LCH     = t_xreconf_addr'(ADDR_XR_DCD_BASE + 0);
        localparam [W_XR_ADDR-1:0] ADDR_XR_DCD_PCH     = t_xreconf_addr'(ADDR_XR_DCD_BASE + 1);
        localparam [W_XR_ADDR-1:0] ADDR_XR_DCD_STATUS  = t_xreconf_addr'(ADDR_XR_DCD_BASE + 2);
        localparam [W_XR_ADDR-1:0] ADDR_XR_DCD_OFFSET  = t_xreconf_addr'(ADDR_XR_DCD_BASE + 3);
        localparam [W_XR_ADDR-1:0] ADDR_XR_DCD_DATA    = t_xreconf_addr'(ADDR_XR_DCD_BASE + 4);

        // DCD internal register offsets
        // These are to be written to the DFE offset address register, ADDR_XR_DCD_OFFSET
        localparam XR_DCD_OFFSET_CTRL     = 0;

        ////////////////////////////////////////////////////////
        // MIF block addresses
        ////////////////////////////////////////////////////////
        localparam [W_XR_ADDR-1:0] ADDR_XR_MIF_LCH     = t_xreconf_addr'(ADDR_XR_MIF_BASE + 0);
        localparam [W_XR_ADDR-1:0] ADDR_XR_MIF_PCH     = t_xreconf_addr'(ADDR_XR_MIF_BASE + 1);
        localparam [W_XR_ADDR-1:0] ADDR_XR_MIF_STATUS  = t_xreconf_addr'(ADDR_XR_MIF_BASE + 2);
        localparam [W_XR_ADDR-1:0] ADDR_XR_MIF_OFFSET  = t_xreconf_addr'(ADDR_XR_MIF_BASE + 3);
        localparam [W_XR_ADDR-1:0] ADDR_XR_MIF_DATA    = t_xreconf_addr'(ADDR_XR_MIF_BASE + 4);

        ////////////////////////////////////////////////////////
        // PLL block addresses
        ////////////////////////////////////////////////////////
        localparam [W_XR_ADDR-1:0] ADDR_XR_PLL_LCH     = t_xreconf_addr'(ADDR_XR_PLL_BASE + 0);
        localparam [W_XR_ADDR-1:0] ADDR_XR_PLL_PCH     = t_xreconf_addr'(ADDR_XR_PLL_BASE + 1);
        localparam [W_XR_ADDR-1:0] ADDR_XR_PLL_STATUS  = t_xreconf_addr'(ADDR_XR_PLL_BASE + 2);
        localparam [W_XR_ADDR-1:0] ADDR_XR_PLL_OFFSET  = t_xreconf_addr'(ADDR_XR_PLL_BASE + 3);
        localparam [W_XR_ADDR-1:0] ADDR_XR_PLL_DATA    = t_xreconf_addr'(ADDR_XR_PLL_BASE + 4);


       
   
        ////////////////////////////////////////////////////////
        // Basic block addresses (internal, private addresses)
        ////////////////////////////////////////////////////////
        // The 'basic' interface block is the switch that routes requests to
        // an appropriate physical reconfiguration interface.  A logical channel
        // number acts as a channel ID, which allows the basic block to find
        // the corresponding physical reconfiguration interface, and a physical
        // channel index within a physical interface.
        //
        // The Basic (B) block features are also available via the direct access block.
        // All users of the basic block, including the direct access block, must
        // acquire appropriate semaphores before using an interface, and release
        // the semaphores when done, to avoid locking out other feature blocks.
        localparam [W_XR_FEATURE_LADDR-1:0] ADDR_XCVR_RECONFIG_BASIC_MUTEX            = t_xr_feature_addr'(0);
        localparam [W_XR_FEATURE_LADDR-1:0] ADDR_XCVR_RECONFIG_BASIC_LOGICAL_CHANNEL  = t_xr_feature_addr'(1);
        localparam [W_XR_FEATURE_LADDR-1:0] ADDR_XCVR_RECONFIG_BASIC_PHYSICAL_CHANNEL = t_xr_feature_addr'(2);
        localparam [W_XR_FEATURE_LADDR-1:0] ADDR_XCVR_RECONFIG_BASIC_CONTROL          = t_xr_feature_addr'(3);
        localparam [W_XR_FEATURE_LADDR-1:0] ADDR_XCVR_RECONFIG_BASIC_OFFSET_ADDR      = t_xr_feature_addr'(4);
        localparam [W_XR_FEATURE_LADDR-1:0] ADDR_XCVR_RECONFIG_BASIC_DATA             = t_xr_feature_addr'(5);


        ////////////////////////////////////////////////////////
        // Direct Access & Basic block addresses
        ////////////////////////////////////////////////////////
        //
        // The minimum steps to read & write a reconfiguration word are the following:
        //  Step 1  - acquire basic arbiter lock (write 1 to ADDR_XR_DIRECT_ARB_ACQ)
        //  Step 2  - write logical channel number to ADDR_XR_DIRECT_LCH
        //  Step 3  - acquire channel lock
        //       3a - request channel lock (write XR_DIRECT_CONTROL_PHYS_LOCK_SET to ADDR_XR_DIRECT_CONTROL)
        //       3b - confirm channel lock (read ADDR_XR_DIRECT_CONTROL, mask with XR_DIRECT_STATUS_BITMASK_PHYS_LOCK_GRANTED)
        //          -- repeat step 3b until result after applying mask is != 0
        //  Step 4  - write channel offset address to ADDR_XR_DIRECT_OFFSET
        //  Step 5  - read existing value from reconfig space, modify, then write back
        //       5a (read cycle part 1)  - write XR_DIRECT_CONTROL_RECONF_READ to ADDR_XR_DIRECT_CONTROL
        //       5b (read cycle part 2)  - read data from ADDR_XR_DIRECT_DATA
        //       5c (write cycle part 1) - write modified value to ADDR_XR_DIRECT_DATA
        //       5d (write cycle part 2) - write XR_DIRECT_CONTROL_RECONF_WRITE to ADDR_XR_DIRECT_CONTROL
        //          -- addtional read-modify-write cycles, repeat from step 2 or 4 (can skip step 3a)
        //  Step 6  - release channel lock (write XR_DIRECT_CONTROL_PHYS_LOCK_CLEAR to ADDR_XR_DIRECT_CONTROL)
        //  Step 7  - release basic arbiter lock (write 0 to ADDR_XR_DIRECT_ARB_ACQ)
        //
        // Direct/Basic register bitmap ---------------------------------------------------------
        // word addr            wr/rd                description
        //    ------------------------------------------------------
        //      0                wr                 basic arbiter, 1 to request access, 0 to release lock
        //      1               wr/rd               logical channel number
        //      2                rd                 physical channel number.  When lower 3 bits are 3'b111, means ch is not present
        //      3               wr/rd               status/control -- see XR_DIRECT_CONTROL_* opcodes and XR_DIRECT_STATUS_* bitfield definitions
        //      4               wr/rd               offset_addr  -- for opcode-based reads & writes
        //      5               wr/rd               data         -- for opcode-based reads & writes
        //      6                --                 reserved
        //      7                --                 reserved
        localparam [W_XR_ADDR-1:0] ADDR_XR_DIRECT_ARB_ACQ = t_xreconf_addr'(ADDR_XR_DIRECT_BASE + 0); // write 1 to request B access, 0 to release
        localparam [W_XR_ADDR-1:0] ADDR_XR_DIRECT_LCH     = t_xreconf_addr'(ADDR_XR_DIRECT_BASE + ADDR_XCVR_RECONFIG_BASIC_LOGICAL_CHANNEL);
        localparam [W_XR_ADDR-1:0] ADDR_XR_DIRECT_PCH     = t_xreconf_addr'(ADDR_XR_DIRECT_BASE + ADDR_XCVR_RECONFIG_BASIC_PHYSICAL_CHANNEL);
        localparam [W_XR_ADDR-1:0] ADDR_XR_DIRECT_CONTROL = t_xreconf_addr'(ADDR_XR_DIRECT_BASE + ADDR_XCVR_RECONFIG_BASIC_CONTROL);
        localparam [W_XR_ADDR-1:0] ADDR_XR_DIRECT_OFFSET  = t_xreconf_addr'(ADDR_XR_DIRECT_BASE + ADDR_XCVR_RECONFIG_BASIC_OFFSET_ADDR);
        localparam [W_XR_ADDR-1:0] ADDR_XR_DIRECT_DATA    = t_xreconf_addr'(ADDR_XR_DIRECT_BASE + ADDR_XCVR_RECONFIG_BASIC_DATA);

        // Opcode values for writes to control word, ADDR_XR_DIRECT_CONTROL
        localparam XR_DIRECT_CONTROL_RECONF_WRITE         = 32'b0000;   // reconfig space: write current DATA to OFFSET addr (as physical addr or ch offset addr)
        localparam XR_DIRECT_CONTROL_RECONF_READ          = 32'b0001;   // reconfig space: read from OFFSET_ADDR, save result in DATA
        localparam XR_DIRECT_CONTROL_LADDR_SET            = 32'b0010;   // interpret OFFSET_ADDR as logical addr, with automatic ch addr offset
        localparam XR_DIRECT_CONTROL_PADDR_SET            = 32'b0011;   // interpret OFFSET_ADDR as physical addr, with no automatic addr offset
        localparam XR_DIRECT_CONTROL_PHYS_LOCK_CLEAR      = 32'b0100; // clear lock request for current channel
        localparam XR_DIRECT_CONTROL_PHYS_LOCK_SET        = 32'b0101; // set lock request for current channel
        localparam XR_DIRECT_CONTROL_ADDR_AUTO_INCR_CLEAR = 32'b0110; // clear auto-write-and-address-increment mode for data writes
        localparam XR_DIRECT_CONTROL_ADDR_AUTO_INCR_SET   = 32'b0111; // set auto-write-and-address-increment mode for data writes
        localparam XR_DIRECT_CONTROL_INTERNAL_WRITE       = 32'b1000; // Internal registers, mainly testbus control
        //localparam XR_DIRECT_CONTROL_INTERNAL_READ      = 32'b1001; // internal reg space: read from OFFSET_ADDR, save result in DATA
        localparam XR_DIRECT_CONTROL_TABLE_READ           = 32'b1011; // ROM table lookup, especially for PLL and clock mux remapping

        // Read of control/status reg returns this bitfield data
        localparam XR_DIRECT_STATUS_BITMASK_PHYS_LOCK_GRANTED = 32'b0001;       // on read, bit 0 is grant status
        localparam XR_DIRECT_STATUS_BITMASK_PHYS_LOCK_REQUESTED = 32'b0010;     // on read, bit 1 is physical lock request flag
        localparam XR_DIRECT_STATUS_BITMASK_USING_PHYS_ADDR = 32'b0100; // on read, bit 2 is physical addr mode indicator (0 mean logical addr)
        localparam XR_DIRECT_STATUS_BITMASK_USING_ADDR_AUTO_INCR = 32'b1000;    // on read, bit 3 is auto-write-and-addr-incr mode indicator

        // Internal register addresses, for read/write via these opcodes: XR_DIRECT_CONTROL_INTERNAL_*
        localparam XR_DIRECT_OFFSET_TESTBUS_SEL = 2'd0; // internal register for testbus sel
        

endpackage
