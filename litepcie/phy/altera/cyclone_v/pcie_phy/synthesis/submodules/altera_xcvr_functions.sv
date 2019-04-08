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
// Common functions for transceiver PHY IP
//
// $Header$
//
// PACKAGE DECLARATION
package altera_xcvr_functions;
	localparam integer MAX_CHARS = 86; // To accomodate LONG parameter lists.
	localparam integer MAX_STRS = 16;
  localparam integer MAX_XCVR_CHANNELS = 64;


  // Reconfiguration bundle widths per family
  localparam integer W_S5_RECONFIG_BUNDLE_TO_XCVR    = 70;
  localparam integer W_S5_RECONFIG_BUNDLE_FROM_XCVR  = 46;
  localparam integer W_A5_RECONFIG_BUNDLE_TO_XCVR    = 70;
  localparam integer W_A5_RECONFIG_BUNDLE_FROM_XCVR  = 46;
  localparam integer W_S4_RECONFIG_BUNDLE_TO_XCVR    = 4;
  localparam integer W_S4_RECONFIG_BUNDLE_FROM_XCVR  = 17;
  localparam integer W_C4_RECONFIG_BUNDLE_TO_XCVR    = 4;
  localparam integer W_C4_RECONFIG_BUNDLE_FROM_XCVR  = 17;

  // Reconfiguration bundle widths per family
  localparam integer W_S5_RECONFIG_BUNDLE_TO_GXB    = W_S5_RECONFIG_BUNDLE_TO_XCVR;
  localparam integer W_S5_RECONFIG_BUNDLE_FROM_GXB  = W_S5_RECONFIG_BUNDLE_FROM_XCVR;
  localparam integer W_A5_RECONFIG_BUNDLE_TO_GXB    = W_A5_RECONFIG_BUNDLE_TO_XCVR;
  localparam integer W_A5_RECONFIG_BUNDLE_FROM_GXB  = W_A5_RECONFIG_BUNDLE_FROM_XCVR;
  localparam integer W_S4_RECONFIG_BUNDLE_TO_GXB    = W_S4_RECONFIG_BUNDLE_TO_XCVR;
  localparam integer W_S4_RECONFIG_BUNDLE_FROM_GXB  = W_S4_RECONFIG_BUNDLE_FROM_XCVR;
  localparam integer W_C4_RECONFIG_BUNDLE_TO_GXB    = W_C4_RECONFIG_BUNDLE_TO_XCVR;
  localparam integer W_C4_RECONFIG_BUNDLE_FROM_GXB  = W_C4_RECONFIG_BUNDLE_FROM_XCVR;

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
						is_numeric = 0;	// stop accepting new numeric digits in value
						// if it's a-z, convert to upper case A-Z
						if (c >= c_a && c <= c_z) c = (c & 8'h5f);	// convert a-z (lower) to A-Z (upper)
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
	
	// convert integer Hz to a frequency string
	// integer Hz as type time, and the frequency string will use MHz units
	// Must remain a constant function - can't use $sformat or string.itoa().
	function [MAX_CHARS*8-1:0] hz2str (
		input time hz
	);
		integer pos;
		integer f_unit;	// 10**f_unit is offset from Hz for larger unit
                time hz_mod_10;
		begin
			hz2str = "0.000000 MHz";	// minimum string value
			f_unit = 6;	// MHz offsets Hz value by 6 decimal digits

			// convert time back to string with frequency units
			// char positions 3 to 0 are used by " MHz", so start with digits at pos 4
			for (pos = 4; pos < MAX_CHARS && hz > 0; pos = pos + 1) begin
				if (f_unit == 0) begin
					hz2str[pos*8 +: 8] = 8'h2e;	// add "." character
					pos = pos + 1;
				end
				f_unit = f_unit - 1;
                                hz_mod_10 = (hz % 10);
				hz2str[pos*8 +: 8] = hz_mod_10[7:0] | 8'h30;
				hz = hz / 10;
				//$display("hz2str() => so far '%s', pos (%d), f_unit(%d) ", hz2str, pos, f_unit);
			end
			//$display("hz2str() returns '%s'", hz2str);
		end
	endfunction

  // Convert a string to an integer
  // Uses pre-existing str2hz function
  function integer str2int(
    input [MAX_CHARS*8-1:0] instring
  );
    time temp;
    temp = str2hz(instring); // str2hz assume Hertz as default unit. Don't need to add 'Hz' to input.
    str2int = temp[31:0];
  endfunction


  // Convert an integer to a string
  function [MAX_CHARS*8-1:0] int2str(
    input integer in_int
  );
    integer i;
    integer this_char;
    i = 0;
    int2str = "";
    do
    begin
      this_char = (in_int % 10) + 48;
      int2str[i*8+:8] = this_char[7:0];
      i=i+1;
      in_int = in_int / 10; 
    end
    while(in_int > 0);
  endfunction

	// function to convert at most 40-bit long string to binary
	function [39 : 0] m_str_to_bin;
	    input [40*8 : 1] s;
	    reg   [40*8 : 1] reg_s;
	    reg   [40:1]     res;
	
	    integer m;
	    begin
	      
	        reg_s = s;
	        for (m = 40; m > 0; m = m-1 )
	        begin
	            res[m] = reg_s[313];
	            reg_s = reg_s << 8;
	        end
	          
	        m_str_to_bin = res;
	    end   
	endfunction


  //////////////////////////////
  // Convert the argument string to a 64-bit binary value
  // @hex_str The string to be converted specified as an ASCII hexadecimal string
  function [63:0] m_hex_to_bin (
    input [8*MAX_CHARS-1:0] hex_str
  );
    integer i;
  
    reg [63:0] out; // = 64'h0000_0000_0000_0000;
    reg [7:0] this_char;

    begin

      out = 64'h0000_0000_0000_0000;
  
      for(i=0; i<16; i=i+1)  begin
        this_char = hex_str[i*8+:8];
        if(this_char >= 48 && this_char <= 57)
          out[i*4+:4] = this_char - 48;
        else if(this_char >= 65 && this_char <= 70)
          out[i*4+:4] = this_char - 55;
        else if(this_char >= 97 && this_char <= 102)
          out[i*4+:4] = this_char - 87;
        else begin
          out[i*4+:4] = 0;
        end
      end
    end
    m_hex_to_bin = out;
  endfunction



	////////////////////////////////////////////////////////////////////
	// Verify that the string value is contained in the legal set.
	//
	// The 'set' can consist of a single string with no delimiters, e.g. "individual",
	// or multiple values, separated by commas, and surrounded by parens, e.g. "(one,two,three,four,five)"
	//
	// Returns 1 if the value is in the set, and 0 otherwise
	function integer is_in_legal_set(
		input [MAX_CHARS*8-1:0] value,
		input [MAX_STRS*MAX_CHARS*8-1:0] set
	);
		if (value == "<auto_any>")
			is_in_legal_set = 1;
		else if (value == "<auto_single>")
			is_in_legal_set = (set[7:0] == 8'h29) ? 0 : 1;  // 8'h29 is closing parenthesis char
		else if (value == set)
			is_in_legal_set = 1;  // value matches single value in set
		else begin
			// check value against each in set
			integer close_pos;	// end of string marker can be comma or closing paren
			integer open_pos;	// open paren is start of set, if appropriate
			reg [MAX_STRS*MAX_CHARS*8-1:0] legalstr;
			
			is_in_legal_set = 0;
			open_pos = MAX_STRS*MAX_CHARS-1;
      // Remove closing parenthesis if exists
      if(set[7:0] == 8'h29) begin
        set = (set >> 8);
        set[(MAX_STRS*MAX_CHARS*8-1)-:8] = 8'h00;
      end
      // look for first non-null and non open paren character
	    while (open_pos > 0 && (set[open_pos*8 +: 8] == 8'h00 || set[open_pos*8 +: 8] == 8'h28)) // look for first non-null
				open_pos = open_pos - 1;

			while (is_in_legal_set == 0 && open_pos >= 0) begin
	      close_pos = open_pos;
				while (close_pos > 0
						 && set[close_pos*8 +: 8] != 8'h2c) // look for comma (8'h2c)
					close_pos = close_pos - 1;
			  if (close_pos >= 0) begin
          close_pos = close_pos == 0 ? 0 : close_pos + 1;
				  legalstr = ((set & ((1'b1 << open_pos*8+8)-1)) >> close_pos*8);
					if (value == legalstr)
						is_in_legal_set = 1;
				end
				open_pos = close_pos-2;  // prepare to look for next legal string
			end
		end
		//$display("is_in_legal_set(): returns %d", is_in_legal_set);
	endfunction


  // Accepts a string list of comma seperated numbers and returns a binary
  // field where each bit indicates whether the index corresponding to that bit
  // was found in the legal set.
  //
  // @param count - The number of integer indexes to check for in the set
  //                or the highest integer minus 1.
  // @param set - The list containing the integer values to search for
  // @return - A bitfield where each bit indicates whether the corresponding
  //           integer was found in the legal set.
  function [MAX_XCVR_CHANNELS-1:0] map_numerical_is_in_legal_set(
    input integer count,
    input [MAX_STRS*MAX_CHARS*8-1:0] set
  );
    integer index;
    reg [MAX_XCVR_CHANNELS-1:0] retval;

    // Validate count parameter
    if(count > MAX_XCVR_CHANNELS)
      $display("Error: [map_numerical_is_in_legal_set]: Invalid value for count: %0d",count);

    map_numerical_is_in_legal_set = {MAX_XCVR_CHANNELS{1'b0}};
    retval = {MAX_XCVR_CHANNELS{1'b0}};
    for(index = 0; index < count; index = index + 1) begin
      if(is_in_legal_set(int2str(index),set))
        retval = retval | (({MAX_XCVR_CHANNELS{1'b0}} | 1'b1) << index);
    end
    map_numerical_is_in_legal_set = retval;
  endfunction


  // Accepts a string list of comma seperated numbers and returns a binary
  // field where each byte contains the corresponding number found in the
  // list.
  //
  // @param count - The number of elements in the list.
  // @param set - The list containing the integer values.
  // @return - A bitfield where each byte contains the corresponding number found
  //          at that location in the list.
  function [MAX_XCVR_CHANNELS*8-1:0] map_numerical_legal_set(
    input integer count,
    input [MAX_STRS*MAX_CHARS*8-1:0] set
  );
    integer index;
    reg [MAX_XCVR_CHANNELS-1:0] retval;
    reg [MAX_CHARS*8-1:0] str_val;
    reg [7:0]             int_val;

    // Validate count parameter
    if(count > MAX_XCVR_CHANNELS || count > 256)
      $display("Error: [map_numerical_legal_set]: Invalid value for count: %0d",count);

    map_numerical_legal_set = {MAX_XCVR_CHANNELS{8'd0}};
    retval = {MAX_XCVR_CHANNELS{8'd0}};
    for(index = 0; index < count; index = index + 1) begin
      str_val = get_value_at_index(index,set);
      if(str_val != "NA") begin
        int_val = str2int(str_val);
        if(int_val > 255)
          $display("Error: [map_numerical_legal_set]: Invalid string contains non-numerical item or value:%0d",int_val);
        else begin
          retval = retval | ( ( {MAX_XCVR_CHANNELS{8'd0}} | int_val ) << (index * 8));
        end
      end
    end
    map_numerical_legal_set = retval;
  endfunction


  // Accepts a comma separated list of string values and returns the element
  // found at the specified index. If the index is invalid, "NA" is returned
  //
  // @param index - The index of the value to return within "set"
  // @param set - A comma separated list of string values. The entire list may
  //            be surrounded by parenthesis("(item0,item1,item2)")
  function [MAX_CHARS*8-1:0] get_value_at_index(
    input integer index,
    input [MAX_STRS*MAX_CHARS*8-1:0] set
  );
    // check value against each in set
	  integer close_pos;	// end of string marker can be comma or closing paren
		integer open_pos;	// open paren is start of set, if appropriate
		reg [MAX_STRS*MAX_CHARS*8-1:0] legalstr;
    integer cur_index;
			
    get_value_at_index = "";
    legalstr = "NA";
    cur_index = 0;
	  open_pos = MAX_STRS*MAX_CHARS-1;
    // Remove closing parenthesis if exists
    if(set[7:0] == 8'h29) begin
      set = (set >> 8);
      set[(MAX_STRS*MAX_CHARS*8-1)-:8] = 8'h00;
    end
    // Find the start of the string
	  while (open_pos >= 1 && (set[open_pos*8 +: 8] == 8'h00 || set[open_pos*8 +: 8] == 8'h28)) // look for first non-null
				open_pos = open_pos - 1;

    // Iterate through list until the string is found or we've reached the end of the list
	  while (legalstr == "NA" && open_pos >= 0 && cur_index <= index) begin
	    close_pos = open_pos;
      // Move the close iterator to the end of the current value (or end of string)
			while (close_pos > 0
					&& set[close_pos*8 +: 8] != 8'h2c) // look for comma (8'h2c)
			  close_pos = close_pos - 1;
			if (close_pos >= 0) begin
          close_pos = close_pos == 0 ? 0 : close_pos + 1;
          if(index == cur_index) begin 
				    legalstr = ((set & ((1'b1 << open_pos*8+8)-1)) >> close_pos*8);
				  end
				  open_pos = close_pos-2;  // prepare to look for next legal string
      end
      cur_index = cur_index + 1;
		end

    cur_index = 0;
    while(legalstr[cur_index*8+:8] != 0) begin
      get_value_at_index[cur_index*8+:8] = legalstr[cur_index*8+:8];
      cur_index = cur_index + 1;
    end
    
		//$display("is_in_legal_set(): returns %d", is_in_legal_set);
	endfunction

	// The goal was to return one of the values, does not matter which one.
	// ~45 times faster than get_value_at_index( 0, set );
	function [MAX_CHARS*8-1:0] get_first_enum_value( input [MAX_STRS*MAX_CHARS*8-1:0] set );

		int start_pos, cur_idx;
		bit [7:0] cur_set_char;
                   
        // Ensure null-terminating the string.
        // MODIFIED: Work around for a QuestaSim vopt bug: set[(MAX_STRS*MAX_CHARS*8-8) +: 8 ] = 8'h00; 
        set [ ( MAX_STRS * MAX_CHARS * 8 -1) : ( MAX_STRS * MAX_CHARS * 8 - 8) ] = 8 'h00 ;

		start_pos = set[7:0] == 8'h29 ? 8 : 0;
		cur_idx = 0;

		get_first_enum_value = "";

		forever
			begin
				cur_set_char = set[ cur_idx + start_pos +: 8 ];

				// comma, par or 0
				if ( cur_set_char == 8'h2c || cur_set_char == 8'h28 || cur_set_char == 8'h00 )
					break;

				get_first_enum_value[ cur_idx +: 8 ] = cur_set_char;
				cur_idx = cur_idx + 8;
			end

		// get_first_enum_value = get_value_at_index( 0, set );

	endfunction

	// This functions is ~12 times faster than is_in_legal_set
	function integer is_enum_in_legal_set( input [MAX_CHARS*8-1:0] value, input [MAX_STRS*MAX_CHARS*8-1:0] set );

		if ( value == "<auto_any>" )
			return 1;
		else if (value == "<auto_single>")
			return (set[7:0] == 8'h29) ? 0 : 1;  // 8'h29 is closing parenthesis char
		else if (value == set)
			return 1;  // value matches single value in set
		else 
		begin
			// ')'
			int set_pos;
			set_pos = 0;
			if ( set[7:0] == 8'h29 )
				set_pos = 8;

                         // Ensure null-terminating the string.
                         set[(MAX_STRS*MAX_CHARS*8-8) +: 8 ] = 8'h00;

			forever
				begin
					int cur_cmp_len;
					cur_cmp_len = 0;

					// $display( "set_pos ", set_pos/8 );

					forever
						begin

							int cur_val_char, cur_set_char;
							cur_val_char = value[ cur_cmp_len +: 8 ];
							cur_set_char = set[ set_pos +: 8 ];

							// $display( "comparing ", set_pos/8, cur_cmp_len/8, " " , value[ cur_cmp_len +: 8 ], " ", set[ set_pos +: 8 ] );

							if ( cur_val_char == 0 )
								// The end of value reached, check whether set has comma, par or 0
								if ( cur_set_char == 8'h2c || cur_set_char == 8'h28 || cur_set_char == 8'h00 )
									return 1;

							if ( cur_val_char != cur_set_char )
								break;
								
							cur_cmp_len = cur_cmp_len + 8;
							set_pos = set_pos + 8;
						end

					forever
						begin
							int cur_set_char;
							cur_set_char = set[ set_pos +: 8 ];

							// $display( "skipping ", set_pos/8 );

							// ','
							if ( cur_set_char == 8'h2c )
								begin
									set_pos = set_pos + 8;
									break;
								end

							if ( cur_set_char == 8'h00 )
								return 0;

							set_pos = set_pos + 8;

						end
				end
		end

	endfunction

	// The first parameter is just a number, NOT a string
	function integer is_numeric_in_legal_set( input [MAX_CHARS*8-1:0] value, input [MAX_STRS*MAX_CHARS*8-1:0] set );
		is_numeric_in_legal_set = 1;
	endfunction

	// AP stubs --- end


	////////////////////////////////////////////////////////////////////////
	// Returns ceil_log2() value
	localparam integer MAX_PRECISION = 32;	// VCS requires this declaration outside the function
	function integer ceil_log2;
		input [MAX_PRECISION-1:0] input_num;
		integer i;
		reg [MAX_PRECISION-1:0] try_result;
		begin
			i = 0;
			try_result = 1;
			while ((try_result << i) < input_num && i < MAX_PRECISION)
				i = i + 1;
			ceil_log2 = i;
		end
	endfunction

  ////////////////////////////////////////////////////////////////////
  // Return the number of bits required to represent an integer
  // E.g. 0->1; 1->1; 2->2; 3->2 ... 31->5; 32->6
  //
  function integer clogb2;
    input [MAX_PRECISION-1:0] input_num;
    begin
      for (clogb2=0; input_num>0 && clogb2<MAX_PRECISION; clogb2=clogb2+1)
        input_num = input_num >> 1;
      if(clogb2 == 0)
        clogb2 = 1;
    end
  endfunction

	////////////////////////////////////////////////////////////////////
	// Return current device family string for display purposes
	`ifndef XCVR_DEV_FAM
		`ifdef ALTERA_RESERVED_QIS_FAMILY
			`define XCVR_DEV_FAM `ALTERA_RESERVED_QIS_FAMILY	// synthesis: use QIS-defined value
		`else
			`define XCVR_DEV_FAM device_family	// simulation: use passed-in value
		`endif
	`endif
	function [MAX_CHARS*8-1:0] current_device_family (
		input [MAX_CHARS*8-1:0] device_family
	);
		current_device_family = `XCVR_DEV_FAM;
	endfunction

	////////////////////////////////////////////////////////////////////
	// Match device family against standard family name strings
	//
	// Returns 1 if the names feature is present in the given device family
	function integer has_s4_style_hssi (
		input [MAX_CHARS*8-1:0] device_family
	);
		has_s4_style_hssi = (  (`XCVR_DEV_FAM == "Stratix IV")
							|| (`XCVR_DEV_FAM == "Arria II")
							|| (`XCVR_DEV_FAM == "Cyclone IV GX")	// not exact, but close enough
							|| (`XCVR_DEV_FAM == "Arria II GX")
							|| (`XCVR_DEV_FAM == "Arria II GZ")
							|| (`XCVR_DEV_FAM == "HardCopy IV")
							) ? 1 : 0;
	endfunction

	////////////////////////////////////////////////////////////////////
	// Match device family against standard family name strings
	//
	// Returns 1 if the names feature is present in the given device family
	function integer has_s5_style_hssi (
		input [MAX_CHARS*8-1:0] device_family
	);
		has_s5_style_hssi = (  (`XCVR_DEV_FAM == "Stratix V") || (`XCVR_DEV_FAM == "Arria V GZ")
							) ? 1 : 0;
	endfunction
	
	////////////////////////////////////////////////////////////////////
	// Match device family against standard family name strings
	//
	// Returns 1 if the names feature is present in the given device family
	function integer has_a5_style_hssi (
		input [MAX_CHARS*8-1:0] device_family
	);
		has_a5_style_hssi = (  (`XCVR_DEV_FAM == "Arria V")
							) ? 1 : 0;
	endfunction
	
	////////////////////////////////////////////////////////////////////
	// Match device family against standard family name strings
	//
	// Returns 1 if the names feature is present in the given device family
	function integer has_c5_style_hssi (
		input [MAX_CHARS*8-1:0] device_family
	);
		has_c5_style_hssi = (  (`XCVR_DEV_FAM == "Cyclone V")
							) ? 1 : 0;
	endfunction
	
	////////////////////////////////////////////////////////////////////
	// Match device family against standard family name strings
	//
	// Returns 1 if the names feature is present in the given device family
	function integer has_c4_style_hssi (
		input [MAX_CHARS*8-1:0] device_family
	);
		has_c4_style_hssi = (  (`XCVR_DEV_FAM == "Cyclone IV GX")
							) ? 1 : 0;
	endfunction

  ////////////////////////////////////////////////////////////////////
  // Get reconfig_to_gxb bundle width for specified device family
  //
  // Returns 0 if the device_family argument is invalid, otherwise
  // it returns the width of the reconfig_to_gxb bundle for that family
  function integer get_reconfig_to_gxb_width (
    input [MAX_CHARS*8-1:0] device_family
  );
    if (has_s5_style_hssi(device_family) || has_a5_style_hssi(device_family) || has_c5_style_hssi(device_family)) 
      get_reconfig_to_gxb_width = W_S5_RECONFIG_BUNDLE_TO_XCVR;
    else if (has_s4_style_hssi(device_family))
      get_reconfig_to_gxb_width = W_S4_RECONFIG_BUNDLE_TO_XCVR;
   else if (has_c4_style_hssi(device_family))
      get_reconfig_to_gxb_width = W_C4_RECONFIG_BUNDLE_TO_XCVR;
    else
      get_reconfig_to_gxb_width = 0;
  endfunction

  ////////////////////////////////////////////////////////////////////
  // Get reconfig_from_gxb bundle width for specified device family
  //
  // Returns 0 if the device_family argument is invalid, otherwise
  // it returns the width of the reconfig_from_gxb bundle for that family
  function integer get_reconfig_from_gxb_width (
    input [MAX_CHARS*8-1:0] device_family
  );
    if (has_s5_style_hssi(device_family) || has_a5_style_hssi(device_family) || has_c5_style_hssi(device_family)) 
      get_reconfig_from_gxb_width = W_S5_RECONFIG_BUNDLE_FROM_XCVR;
    else if (has_s4_style_hssi(device_family))
      get_reconfig_from_gxb_width = W_S4_RECONFIG_BUNDLE_FROM_XCVR;
    else if (has_c4_style_hssi(device_family))
      get_reconfig_from_gxb_width = W_C4_RECONFIG_BUNDLE_FROM_XCVR;
    else
      get_reconfig_from_gxb_width = 0;
  endfunction
  
    ////////////////////////////////////////////////////////////////////
  // Get reconfig_to_xcvr total port width for specified device family
  //
  // Returns 0 if the device_family argument is invalid, otherwise
  // it returns the width of the reconfig_to_xcvr port for that family
  function integer get_reconfig_to_width (
    input [MAX_CHARS*8-1:0] device_family,
    input integer reconfig_interfaces
  );
    if (has_s5_style_hssi(device_family) || has_a5_style_hssi(device_family) || has_c5_style_hssi(device_family)) 
      get_reconfig_to_width = get_s5_reconfig_to_width(reconfig_interfaces);
    else if (has_s4_style_hssi(device_family))
      get_reconfig_to_width = W_S4_RECONFIG_BUNDLE_TO_XCVR;
    else if (has_c4_style_hssi(device_family))
      get_reconfig_to_width = W_C4_RECONFIG_BUNDLE_TO_XCVR;
    else
      get_reconfig_to_width = 0;
  endfunction

    ////////////////////////////////////////////////////////////////////
  // Get reconfig_to_xcvr total port width for Stratix V device family
  //
  function integer get_s5_reconfig_to_width (
    input integer reconfig_interfaces
  );
    get_s5_reconfig_to_width = reconfig_interfaces * get_reconfig_to_gxb_width("Stratix V");
  endfunction

    ////////////////////////////////////////////////////////////////////
  // Get reconfig_from_xcvr total port width for specified device family
  //
  // Returns 0 if the device_family argument is invalid, otherwise
  // it returns the width of the reconfig_from_xcvr port for that family
  function integer get_reconfig_from_width (
    input [MAX_CHARS*8-1:0] device_family,
    input integer reconfig_interfaces
  );
    if (has_s5_style_hssi(device_family) || has_a5_style_hssi(device_family) || has_c5_style_hssi(device_family))
      get_reconfig_from_width = reconfig_interfaces * get_reconfig_from_gxb_width(device_family);
    else if (has_s4_style_hssi(device_family))
      get_reconfig_from_width = reconfig_interfaces * get_reconfig_from_gxb_width(device_family);
    else if (has_c4_style_hssi(device_family))
      get_reconfig_from_width = reconfig_interfaces * get_reconfig_from_gxb_width(device_family);
    else
      get_reconfig_from_width = 0;
  endfunction

    ////////////////////////////////////////////////////////////////////
  // Get reconfig_from_xcvr total port width for Stratix V device family
  //
  function integer get_s5_reconfig_from_width (
    input integer reconfig_interfaces
  );
    get_s5_reconfig_from_width = reconfig_interfaces * get_reconfig_from_gxb_width("Stratix V");
  endfunction

    ////////////////////////////////////////////////////////////////////
  // Get number of reconfig interfaces for Custom PHY
  // NOTE - !!Has since been used by other PHY IP!!
  //
  // @param device_family - Desired device family
  // @param operation_mode - "Duplex","Rx","Tx" or "duplex", "rx_only", "tx_only" in 10gbaser
  // @param lanes - Number of channels
  // @param plls - Number of TX plls (per channel)
  // @param bonded_group_size - Size of bonded group (1 or lanes)
  // @param data_path_type - Abuse of function by overloading for ATT support
  //                       - Carry on the abuse
  //
  // @return 0 if the device_family argument is invalid, otherwise
  //          it returns the width of the reconfig_from_xcvr port for that family
  function integer get_custom_reconfig_interfaces(
    input [MAX_CHARS*8-1:0] device_family,
    input [MAX_CHARS*8-1:0] operation_mode,
    input integer           lanes,
    input integer           plls,
    input integer           bonded_group_size,
    input [MAX_CHARS*8-1:0] data_path_type = "",
    input [MAX_CHARS*8-1:0] bonded_mode = "xN"
  );
    integer reconfig_interfaces;
    reconfig_interfaces = 0;
    if (has_s5_style_hssi(device_family) || has_a5_style_hssi(device_family) || has_c5_style_hssi(device_family)) begin
      // ATT specific calculations
      if( data_path_type == "ATT" ) begin
        if((operation_mode == "RX_ONLY") || (operation_mode == "rx_only") || (operation_mode == "Rx") || (operation_mode == "RX") || (operation_mode == "rx")) begin
            reconfig_interfaces = lanes;
        end else if((operation_mode == "TX_ONLY") || (operation_mode == "tx_only") || (operation_mode == "Tx") || (operation_mode == "TX") || (operation_mode == "tx")) begin
            reconfig_interfaces = 2*lanes;
        end else begin
            reconfig_interfaces = 3*lanes;
        end
      end else begin
        // Custom PHY calculations
        if((operation_mode == "RX") || (operation_mode == "Rx") || (operation_mode == "rx_only"))
          reconfig_interfaces = lanes;
        else begin
          bonded_group_size = (bonded_mode == "fb_compensation") ? 1 : 
                              (bonded_mode == "non_bonded") ? 1 : bonded_group_size;
          reconfig_interfaces = lanes+(plls*(lanes/bonded_group_size));
        end
      end
    end
    get_custom_reconfig_interfaces = reconfig_interfaces;
  endfunction

    ////////////////////////////////////////////////////////////////////
  // Get reconfig_to_xcvr total port width for Custom PHY
  //
  // @param device_family - Desired device family
  // @param operation_mode - "Duplex","Rx","Tx" or "duplex", "rx_only", "tx_only" in 10gbaser
  // @param lanes - Number of transceiver channels
  // @param plls - Number of plls per bonded group
  // @param bonded_group_size - Size of bonded group (1 or lanes)
  // @param data_path_type - Abuse of function to support ATT
  //
  // @return - 0 if the device_family argument is invalid, otherwise
  // it returns the width of the reconfig_from_xcvr port for that family
  function integer get_custom_reconfig_to_width(
    input [MAX_CHARS*8-1:0] device_family,
    input [MAX_CHARS*8-1:0] operation_mode,
    input integer           lanes,
    input integer           plls,
    input integer           bonded_group_size,
    input [MAX_CHARS*8-1:0] data_path_type = "",
    input [MAX_CHARS*8-1:0] bonded_mode = "xN"
  );
    integer reconfig_interfaces;
    reconfig_interfaces = get_custom_reconfig_interfaces(device_family,operation_mode,lanes,plls,bonded_group_size, data_path_type, bonded_mode );
    get_custom_reconfig_to_width = get_s5_reconfig_to_width(reconfig_interfaces);
  endfunction

    ////////////////////////////////////////////////////////////////////
  // Get reconfig_from_xcvr total port width for Custom PHY
  //
  // @param device_family - Desired device family
  // @param operation_mode - "Duplex","Rx","Tx" or "duplex", "rx_only", "tx_only" in 10gbaser
  // @param lanes - Number of transceiver channels
  // @param plls - Number of plls per bonded group
  // @param bonded_group_size - Size of bonded group (1 or lanes)
  // @param data_path_type - Abuse of function to support ATT
  //
  // @return - 0 if the device_family argument is invalid, otherwise
  // it returns the width of the reconfig_from_xcvr port for that family
  function integer get_custom_reconfig_from_width(
    input [MAX_CHARS*8-1:0] device_family,
    input [MAX_CHARS*8-1:0] operation_mode,
    input integer           lanes,
    input integer           plls,
    input integer           bonded_group_size,
    input [MAX_CHARS*8-1:0] data_path_type = "",
    input [MAX_CHARS*8-1:0] bonded_mode = "xN"
  );
    integer reconfig_interfaces;
    reconfig_interfaces = get_custom_reconfig_interfaces(device_family,operation_mode,lanes,plls,bonded_group_size, data_path_type, bonded_mode);
    get_custom_reconfig_from_width = get_s5_reconfig_from_width(reconfig_interfaces);
  endfunction


   ////////////////////////////////////////////////////////////////////   
   // Start Interlaken Specific functions for calculating reconfig interfaces 
   // and reconfig_to_gxb, reconfig_from_gxb widths  

    ////////////////////////////////////////////////////////////////////
  // Get number of reconfig interfaces for Interlaken PHY
  //
  // @param device_family - Desired device family
  // @param operation_mode - "Duplex","Rx","Tx" or "duplex", "rx_only", "tx_only" in 10gbaser
  // Returns 0 if the device_family argument is invalid, otherwise
  // it returns the width of the reconfig_from_xcvr port for that family
  function integer get_interlaken_reconfig_interfaces(
    input [MAX_CHARS*8-1:0] device_family,
    input [MAX_CHARS*8-1:0] operation_mode,
    input integer 	    bonded_group_size,
    input integer           lanes
  );
     integer 		    reconfig_interfaces;
     integer 		    xslices;
     integer 		    xremain;
     integer 		    totalplls;
		    
    reconfig_interfaces = 0;
    if (has_s5_style_hssi(device_family) || has_a5_style_hssi(device_family) || has_c5_style_hssi(device_family)) begin
      if((operation_mode == "RX") || (operation_mode == "Rx") || (operation_mode == "rx_only"))
        reconfig_interfaces = lanes;
      else begin
	 xslices = lanes/bonded_group_size;
	 xremain = lanes % bonded_group_size;
	 
	 if (xremain >0)
	   totalplls = xslices +1;
	 else
	   totalplls = xslices;
         reconfig_interfaces = lanes+totalplls;
      end // else: !if((operation_mode == "RX") || (operation_mode == "Rx") || (operation_mode == "rx_only"))
    end // if (has_s5_style_hssi(device_family))
    get_interlaken_reconfig_interfaces = reconfig_interfaces;
  endfunction

    ////////////////////////////////////////////////////////////////////
  // Get reconfig_to_xcvr total port width for Interlaken PHY
  //
  // @param device_family - Desired device family
  // @param operation_mode - "Duplex","Rx","Tx" or "duplex", "rx_only", "tx_only" in 10gbaser
  // @param lanes - Number of transceiver channels
  // Returns 0 if the device_family argument is invalid, otherwise
  // it returns the width of the reconfig_from_xcvr port for that family
  function integer get_interlaken_reconfig_to_width(
    input [MAX_CHARS*8-1:0] device_family,
    input [MAX_CHARS*8-1:0] operation_mode,
    input integer 	    bonded_group_size,
    input integer           lanes
  );
    integer reconfig_interfaces;
    reconfig_interfaces = get_interlaken_reconfig_interfaces(device_family,operation_mode,bonded_group_size,lanes);
    get_interlaken_reconfig_to_width = get_s5_reconfig_to_width(reconfig_interfaces);
  endfunction

    ////////////////////////////////////////////////////////////////////
  // Get reconfig_from_xcvr total port width for Custom PHY
  //
  // @param device_family - Desired device family
  // @param operation_mode - "Duplex","Rx","Tx" or "duplex", "rx_only", "tx_only" in 10gbaser
  // Returns 0 if the device_family argument is invalid, otherwise
  // it returns the width of the reconfig_from_xcvr port for that family
  function integer get_interlaken_reconfig_from_width(
    input [MAX_CHARS*8-1:0] device_family,
    input [MAX_CHARS*8-1:0] operation_mode,
    input integer 	    bonded_group_size,          						      
    input integer           lanes
  );
    integer reconfig_interfaces;
    reconfig_interfaces = get_interlaken_reconfig_interfaces(device_family,operation_mode,bonded_group_size,lanes);
    get_interlaken_reconfig_from_width = get_s5_reconfig_from_width(reconfig_interfaces);
  endfunction

   // End Interlaken specific functions
   ////////////////////////////////////////////////////////////////////   




   
endpackage
