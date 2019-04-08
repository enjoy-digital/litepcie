//Legal Notice: (C)2019 Altera Corporation. All rights reserved.  Your
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

// synthesis translate_off
`timescale 1ns / 1ps
// synthesis translate_on

// turn off superfluous verilog processor warnings 
// altera message_level Level1 
// altera message_off 10034 10035 10036 10037 10230 10240 10030 

module alt_xcvr_reconfig_cpu_reconfig_cpu_register_bank_a_module (
                                                                   // inputs:
                                                                    clock,
                                                                    data,
                                                                    rdaddress,
                                                                    wraddress,
                                                                    wren,

                                                                   // outputs:
                                                                    q
                                                                 )
;

  parameter lpm_file = "UNUSED";


  output  [ 31: 0] q;
  input            clock;
  input   [ 31: 0] data;
  input   [  4: 0] rdaddress;
  input   [  4: 0] wraddress;
  input            wren;


wire    [ 31: 0] q;
wire    [ 31: 0] ram_data;
wire    [ 31: 0] ram_q;
  assign q = ram_q;
  assign ram_data = data;
  altsyncram the_altsyncram
    (
      .address_a (wraddress),
      .address_b (rdaddress),
      .clock0 (clock),
      .data_a (ram_data),
      .q_b (ram_q),
      .wren_a (wren)
    );

  defparam the_altsyncram.address_reg_b = "CLOCK0",
           the_altsyncram.init_file = lpm_file,
           the_altsyncram.maximum_depth = 0,
           the_altsyncram.numwords_a = 32,
           the_altsyncram.numwords_b = 32,
           the_altsyncram.operation_mode = "DUAL_PORT",
           the_altsyncram.outdata_reg_b = "UNREGISTERED",
           the_altsyncram.ram_block_type = "AUTO",
           the_altsyncram.rdcontrol_reg_b = "CLOCK0",
           the_altsyncram.read_during_write_mode_mixed_ports = "DONT_CARE",
           the_altsyncram.width_a = 32,
           the_altsyncram.width_b = 32,
           the_altsyncram.widthad_a = 5,
           the_altsyncram.widthad_b = 5;


endmodule


// synthesis translate_off
`timescale 1ns / 1ps
// synthesis translate_on

// turn off superfluous verilog processor warnings 
// altera message_level Level1 
// altera message_off 10034 10035 10036 10037 10230 10240 10030 

module alt_xcvr_reconfig_cpu_reconfig_cpu_register_bank_b_module (
                                                                   // inputs:
                                                                    clock,
                                                                    data,
                                                                    rdaddress,
                                                                    wraddress,
                                                                    wren,

                                                                   // outputs:
                                                                    q
                                                                 )
;

  parameter lpm_file = "UNUSED";


  output  [ 31: 0] q;
  input            clock;
  input   [ 31: 0] data;
  input   [  4: 0] rdaddress;
  input   [  4: 0] wraddress;
  input            wren;


wire    [ 31: 0] q;
wire    [ 31: 0] ram_data;
wire    [ 31: 0] ram_q;
  assign q = ram_q;
  assign ram_data = data;
  altsyncram the_altsyncram
    (
      .address_a (wraddress),
      .address_b (rdaddress),
      .clock0 (clock),
      .data_a (ram_data),
      .q_b (ram_q),
      .wren_a (wren)
    );

  defparam the_altsyncram.address_reg_b = "CLOCK0",
           the_altsyncram.init_file = lpm_file,
           the_altsyncram.maximum_depth = 0,
           the_altsyncram.numwords_a = 32,
           the_altsyncram.numwords_b = 32,
           the_altsyncram.operation_mode = "DUAL_PORT",
           the_altsyncram.outdata_reg_b = "UNREGISTERED",
           the_altsyncram.ram_block_type = "AUTO",
           the_altsyncram.rdcontrol_reg_b = "CLOCK0",
           the_altsyncram.read_during_write_mode_mixed_ports = "DONT_CARE",
           the_altsyncram.width_a = 32,
           the_altsyncram.width_b = 32,
           the_altsyncram.widthad_a = 5,
           the_altsyncram.widthad_b = 5;


endmodule


// synthesis translate_off
`timescale 1ns / 1ps
// synthesis translate_on

// turn off superfluous verilog processor warnings 
// altera message_level Level1 
// altera message_off 10034 10035 10036 10037 10230 10240 10030 

module alt_xcvr_reconfig_cpu_reconfig_cpu (
                                            // inputs:
                                             clk,
                                             d_irq,
                                             d_readdata,
                                             d_waitrequest,
                                             i_readdata,
                                             i_waitrequest,
                                             reset_n,

                                            // outputs:
                                             d_address,
                                             d_byteenable,
                                             d_read,
                                             d_write,
                                             d_writedata,
                                             i_address,
                                             i_read,
                                             no_ci_readra
                                          )
;

  output  [ 13: 0] d_address;
  output  [  3: 0] d_byteenable;
  output           d_read;
  output           d_write;
  output  [ 31: 0] d_writedata;
  output  [ 11: 0] i_address;
  output           i_read;
  output           no_ci_readra;
  input            clk;
  input   [ 31: 0] d_irq;
  input   [ 31: 0] d_readdata;
  input            d_waitrequest;
  input   [ 31: 0] i_readdata;
  input            i_waitrequest;
  input            reset_n;


wire    [  1: 0] D_compare_op;
wire             D_ctrl_alu_force_xor;
wire             D_ctrl_alu_signed_comparison;
wire             D_ctrl_alu_subtract;
wire             D_ctrl_b_is_dst;
wire             D_ctrl_br;
wire             D_ctrl_br_cmp;
wire             D_ctrl_br_uncond;
wire             D_ctrl_break;
wire             D_ctrl_crst;
wire             D_ctrl_custom;
wire             D_ctrl_custom_multi;
wire             D_ctrl_exception;
wire             D_ctrl_force_src2_zero;
wire             D_ctrl_hi_imm16;
wire             D_ctrl_ignore_dst;
wire             D_ctrl_implicit_dst_eretaddr;
wire             D_ctrl_implicit_dst_retaddr;
wire             D_ctrl_jmp_direct;
wire             D_ctrl_jmp_indirect;
wire             D_ctrl_ld;
wire             D_ctrl_ld_io;
wire             D_ctrl_ld_non_io;
wire             D_ctrl_ld_signed;
wire             D_ctrl_logic;
wire             D_ctrl_rdctl_inst;
wire             D_ctrl_retaddr;
wire             D_ctrl_rot_right;
wire             D_ctrl_shift_logical;
wire             D_ctrl_shift_right_arith;
wire             D_ctrl_shift_rot;
wire             D_ctrl_shift_rot_right;
wire             D_ctrl_src2_choose_imm;
wire             D_ctrl_st;
wire             D_ctrl_uncond_cti_non_br;
wire             D_ctrl_unsigned_lo_imm16;
wire             D_ctrl_wrctl_inst;
wire    [  4: 0] D_dst_regnum;
wire    [ 55: 0] D_inst;
reg     [ 31: 0] D_iw /* synthesis ALTERA_IP_DEBUG_VISIBLE = 1 */;
wire    [  4: 0] D_iw_a;
wire    [  4: 0] D_iw_b;
wire    [  4: 0] D_iw_c;
wire    [  2: 0] D_iw_control_regnum;
wire    [  7: 0] D_iw_custom_n;
wire             D_iw_custom_readra;
wire             D_iw_custom_readrb;
wire             D_iw_custom_writerc;
wire    [ 15: 0] D_iw_imm16;
wire    [ 25: 0] D_iw_imm26;
wire    [  4: 0] D_iw_imm5;
wire    [  1: 0] D_iw_memsz;
wire    [  5: 0] D_iw_op;
wire    [  5: 0] D_iw_opx;
wire    [  4: 0] D_iw_shift_imm5;
wire    [  4: 0] D_iw_trap_break_imm5;
wire    [  9: 0] D_jmp_direct_target_waddr;
wire    [  1: 0] D_logic_op;
wire    [  1: 0] D_logic_op_raw;
wire             D_mem16;
wire             D_mem32;
wire             D_mem8;
wire             D_op_add;
wire             D_op_addi;
wire             D_op_and;
wire             D_op_andhi;
wire             D_op_andi;
wire             D_op_beq;
wire             D_op_bge;
wire             D_op_bgeu;
wire             D_op_blt;
wire             D_op_bltu;
wire             D_op_bne;
wire             D_op_br;
wire             D_op_break;
wire             D_op_bret;
wire             D_op_call;
wire             D_op_callr;
wire             D_op_cmpeq;
wire             D_op_cmpeqi;
wire             D_op_cmpge;
wire             D_op_cmpgei;
wire             D_op_cmpgeu;
wire             D_op_cmpgeui;
wire             D_op_cmplt;
wire             D_op_cmplti;
wire             D_op_cmpltu;
wire             D_op_cmpltui;
wire             D_op_cmpne;
wire             D_op_cmpnei;
wire             D_op_crst;
wire             D_op_custom;
wire             D_op_div;
wire             D_op_divu;
wire             D_op_eret;
wire             D_op_flushd;
wire             D_op_flushda;
wire             D_op_flushi;
wire             D_op_flushp;
wire             D_op_hbreak;
wire             D_op_initd;
wire             D_op_initda;
wire             D_op_initi;
wire             D_op_intr;
wire             D_op_jmp;
wire             D_op_jmpi;
wire             D_op_ldb;
wire             D_op_ldbio;
wire             D_op_ldbu;
wire             D_op_ldbuio;
wire             D_op_ldh;
wire             D_op_ldhio;
wire             D_op_ldhu;
wire             D_op_ldhuio;
wire             D_op_ldl;
wire             D_op_ldw;
wire             D_op_ldwio;
wire             D_op_mul;
wire             D_op_muli;
wire             D_op_mulxss;
wire             D_op_mulxsu;
wire             D_op_mulxuu;
wire             D_op_nextpc;
wire             D_op_nor;
wire             D_op_opx;
wire             D_op_or;
wire             D_op_orhi;
wire             D_op_ori;
wire             D_op_rdctl;
wire             D_op_rdprs;
wire             D_op_ret;
wire             D_op_rol;
wire             D_op_roli;
wire             D_op_ror;
wire             D_op_rsv02;
wire             D_op_rsv09;
wire             D_op_rsv10;
wire             D_op_rsv17;
wire             D_op_rsv18;
wire             D_op_rsv25;
wire             D_op_rsv26;
wire             D_op_rsv33;
wire             D_op_rsv34;
wire             D_op_rsv41;
wire             D_op_rsv42;
wire             D_op_rsv49;
wire             D_op_rsv57;
wire             D_op_rsv61;
wire             D_op_rsv62;
wire             D_op_rsv63;
wire             D_op_rsvx00;
wire             D_op_rsvx10;
wire             D_op_rsvx15;
wire             D_op_rsvx17;
wire             D_op_rsvx21;
wire             D_op_rsvx25;
wire             D_op_rsvx33;
wire             D_op_rsvx34;
wire             D_op_rsvx35;
wire             D_op_rsvx42;
wire             D_op_rsvx43;
wire             D_op_rsvx44;
wire             D_op_rsvx47;
wire             D_op_rsvx50;
wire             D_op_rsvx51;
wire             D_op_rsvx55;
wire             D_op_rsvx56;
wire             D_op_rsvx60;
wire             D_op_rsvx63;
wire             D_op_sll;
wire             D_op_slli;
wire             D_op_sra;
wire             D_op_srai;
wire             D_op_srl;
wire             D_op_srli;
wire             D_op_stb;
wire             D_op_stbio;
wire             D_op_stc;
wire             D_op_sth;
wire             D_op_sthio;
wire             D_op_stw;
wire             D_op_stwio;
wire             D_op_sub;
wire             D_op_sync;
wire             D_op_trap;
wire             D_op_wrctl;
wire             D_op_wrprs;
wire             D_op_xor;
wire             D_op_xorhi;
wire             D_op_xori;
reg              D_valid;
wire    [ 55: 0] D_vinst;
wire             D_wr_dst_reg;
wire    [ 31: 0] E_alu_result;
reg              E_alu_sub;
wire    [ 32: 0] E_arith_result;
wire    [ 31: 0] E_arith_src1;
wire    [ 31: 0] E_arith_src2;
wire             E_ci_multi_stall;
wire    [ 31: 0] E_ci_result;
wire             E_cmp_result;
wire    [ 31: 0] E_control_rd_data;
wire             E_eq;
reg              E_invert_arith_src_msb;
wire             E_ld_stall;
wire    [ 31: 0] E_logic_result;
wire             E_logic_result_is_0;
wire             E_lt;
wire    [ 13: 0] E_mem_baddr;
wire    [  3: 0] E_mem_byte_en;
reg              E_new_inst;
reg     [  4: 0] E_shift_rot_cnt;
wire    [  4: 0] E_shift_rot_cnt_nxt;
wire             E_shift_rot_done;
wire             E_shift_rot_fill_bit;
reg     [ 31: 0] E_shift_rot_result;
wire    [ 31: 0] E_shift_rot_result_nxt;
wire             E_shift_rot_stall;
reg     [ 31: 0] E_src1;
reg     [ 31: 0] E_src2;
wire    [ 31: 0] E_st_data;
wire             E_st_stall;
wire             E_stall;
reg              E_valid;
wire    [ 55: 0] E_vinst;
wire             E_wrctl_bstatus;
wire             E_wrctl_estatus;
wire             E_wrctl_ienable;
wire             E_wrctl_status;
wire    [ 31: 0] F_av_iw;
wire    [  4: 0] F_av_iw_a;
wire    [  4: 0] F_av_iw_b;
wire    [  4: 0] F_av_iw_c;
wire    [  2: 0] F_av_iw_control_regnum;
wire    [  7: 0] F_av_iw_custom_n;
wire             F_av_iw_custom_readra;
wire             F_av_iw_custom_readrb;
wire             F_av_iw_custom_writerc;
wire    [ 15: 0] F_av_iw_imm16;
wire    [ 25: 0] F_av_iw_imm26;
wire    [  4: 0] F_av_iw_imm5;
wire    [  1: 0] F_av_iw_memsz;
wire    [  5: 0] F_av_iw_op;
wire    [  5: 0] F_av_iw_opx;
wire    [  4: 0] F_av_iw_shift_imm5;
wire    [  4: 0] F_av_iw_trap_break_imm5;
wire             F_av_mem16;
wire             F_av_mem32;
wire             F_av_mem8;
wire    [ 55: 0] F_inst;
wire    [ 31: 0] F_iw;
wire    [  4: 0] F_iw_a;
wire    [  4: 0] F_iw_b;
wire    [  4: 0] F_iw_c;
wire    [  2: 0] F_iw_control_regnum;
wire    [  7: 0] F_iw_custom_n;
wire             F_iw_custom_readra;
wire             F_iw_custom_readrb;
wire             F_iw_custom_writerc;
wire    [ 15: 0] F_iw_imm16;
wire    [ 25: 0] F_iw_imm26;
wire    [  4: 0] F_iw_imm5;
wire    [  1: 0] F_iw_memsz;
wire    [  5: 0] F_iw_op;
wire    [  5: 0] F_iw_opx;
wire    [  4: 0] F_iw_shift_imm5;
wire    [  4: 0] F_iw_trap_break_imm5;
wire             F_mem16;
wire             F_mem32;
wire             F_mem8;
wire             F_op_add;
wire             F_op_addi;
wire             F_op_and;
wire             F_op_andhi;
wire             F_op_andi;
wire             F_op_beq;
wire             F_op_bge;
wire             F_op_bgeu;
wire             F_op_blt;
wire             F_op_bltu;
wire             F_op_bne;
wire             F_op_br;
wire             F_op_break;
wire             F_op_bret;
wire             F_op_call;
wire             F_op_callr;
wire             F_op_cmpeq;
wire             F_op_cmpeqi;
wire             F_op_cmpge;
wire             F_op_cmpgei;
wire             F_op_cmpgeu;
wire             F_op_cmpgeui;
wire             F_op_cmplt;
wire             F_op_cmplti;
wire             F_op_cmpltu;
wire             F_op_cmpltui;
wire             F_op_cmpne;
wire             F_op_cmpnei;
wire             F_op_crst;
wire             F_op_custom;
wire             F_op_div;
wire             F_op_divu;
wire             F_op_eret;
wire             F_op_flushd;
wire             F_op_flushda;
wire             F_op_flushi;
wire             F_op_flushp;
wire             F_op_hbreak;
wire             F_op_initd;
wire             F_op_initda;
wire             F_op_initi;
wire             F_op_intr;
wire             F_op_jmp;
wire             F_op_jmpi;
wire             F_op_ldb;
wire             F_op_ldbio;
wire             F_op_ldbu;
wire             F_op_ldbuio;
wire             F_op_ldh;
wire             F_op_ldhio;
wire             F_op_ldhu;
wire             F_op_ldhuio;
wire             F_op_ldl;
wire             F_op_ldw;
wire             F_op_ldwio;
wire             F_op_mul;
wire             F_op_muli;
wire             F_op_mulxss;
wire             F_op_mulxsu;
wire             F_op_mulxuu;
wire             F_op_nextpc;
wire             F_op_nor;
wire             F_op_opx;
wire             F_op_or;
wire             F_op_orhi;
wire             F_op_ori;
wire             F_op_rdctl;
wire             F_op_rdprs;
wire             F_op_ret;
wire             F_op_rol;
wire             F_op_roli;
wire             F_op_ror;
wire             F_op_rsv02;
wire             F_op_rsv09;
wire             F_op_rsv10;
wire             F_op_rsv17;
wire             F_op_rsv18;
wire             F_op_rsv25;
wire             F_op_rsv26;
wire             F_op_rsv33;
wire             F_op_rsv34;
wire             F_op_rsv41;
wire             F_op_rsv42;
wire             F_op_rsv49;
wire             F_op_rsv57;
wire             F_op_rsv61;
wire             F_op_rsv62;
wire             F_op_rsv63;
wire             F_op_rsvx00;
wire             F_op_rsvx10;
wire             F_op_rsvx15;
wire             F_op_rsvx17;
wire             F_op_rsvx21;
wire             F_op_rsvx25;
wire             F_op_rsvx33;
wire             F_op_rsvx34;
wire             F_op_rsvx35;
wire             F_op_rsvx42;
wire             F_op_rsvx43;
wire             F_op_rsvx44;
wire             F_op_rsvx47;
wire             F_op_rsvx50;
wire             F_op_rsvx51;
wire             F_op_rsvx55;
wire             F_op_rsvx56;
wire             F_op_rsvx60;
wire             F_op_rsvx63;
wire             F_op_sll;
wire             F_op_slli;
wire             F_op_sra;
wire             F_op_srai;
wire             F_op_srl;
wire             F_op_srli;
wire             F_op_stb;
wire             F_op_stbio;
wire             F_op_stc;
wire             F_op_sth;
wire             F_op_sthio;
wire             F_op_stw;
wire             F_op_stwio;
wire             F_op_sub;
wire             F_op_sync;
wire             F_op_trap;
wire             F_op_wrctl;
wire             F_op_wrprs;
wire             F_op_xor;
wire             F_op_xorhi;
wire             F_op_xori;
reg     [  9: 0] F_pc /* synthesis ALTERA_IP_DEBUG_VISIBLE = 1 */;
wire             F_pc_en;
wire    [  9: 0] F_pc_no_crst_nxt;
wire    [  9: 0] F_pc_nxt;
wire    [  9: 0] F_pc_plus_one;
wire    [  1: 0] F_pc_sel_nxt;
wire    [ 11: 0] F_pcb;
wire    [ 11: 0] F_pcb_nxt;
wire    [ 11: 0] F_pcb_plus_four;
wire             F_valid;
wire    [ 55: 0] F_vinst;
reg     [  1: 0] R_compare_op;
reg              R_ctrl_alu_force_xor;
wire             R_ctrl_alu_force_xor_nxt;
reg              R_ctrl_alu_signed_comparison;
wire             R_ctrl_alu_signed_comparison_nxt;
reg              R_ctrl_alu_subtract;
wire             R_ctrl_alu_subtract_nxt;
reg              R_ctrl_b_is_dst;
wire             R_ctrl_b_is_dst_nxt;
reg              R_ctrl_br;
reg              R_ctrl_br_cmp;
wire             R_ctrl_br_cmp_nxt;
wire             R_ctrl_br_nxt;
reg              R_ctrl_br_uncond;
wire             R_ctrl_br_uncond_nxt;
reg              R_ctrl_break;
wire             R_ctrl_break_nxt;
reg              R_ctrl_crst;
wire             R_ctrl_crst_nxt;
reg              R_ctrl_custom;
reg              R_ctrl_custom_multi;
wire             R_ctrl_custom_multi_nxt;
wire             R_ctrl_custom_nxt;
reg              R_ctrl_exception;
wire             R_ctrl_exception_nxt;
reg              R_ctrl_force_src2_zero;
wire             R_ctrl_force_src2_zero_nxt;
reg              R_ctrl_hi_imm16;
wire             R_ctrl_hi_imm16_nxt;
reg              R_ctrl_ignore_dst;
wire             R_ctrl_ignore_dst_nxt;
reg              R_ctrl_implicit_dst_eretaddr;
wire             R_ctrl_implicit_dst_eretaddr_nxt;
reg              R_ctrl_implicit_dst_retaddr;
wire             R_ctrl_implicit_dst_retaddr_nxt;
reg              R_ctrl_jmp_direct;
wire             R_ctrl_jmp_direct_nxt;
reg              R_ctrl_jmp_indirect;
wire             R_ctrl_jmp_indirect_nxt;
reg              R_ctrl_ld;
reg              R_ctrl_ld_io;
wire             R_ctrl_ld_io_nxt;
reg              R_ctrl_ld_non_io;
wire             R_ctrl_ld_non_io_nxt;
wire             R_ctrl_ld_nxt;
reg              R_ctrl_ld_signed;
wire             R_ctrl_ld_signed_nxt;
reg              R_ctrl_logic;
wire             R_ctrl_logic_nxt;
reg              R_ctrl_rdctl_inst;
wire             R_ctrl_rdctl_inst_nxt;
reg              R_ctrl_retaddr;
wire             R_ctrl_retaddr_nxt;
reg              R_ctrl_rot_right;
wire             R_ctrl_rot_right_nxt;
reg              R_ctrl_shift_logical;
wire             R_ctrl_shift_logical_nxt;
reg              R_ctrl_shift_right_arith;
wire             R_ctrl_shift_right_arith_nxt;
reg              R_ctrl_shift_rot;
wire             R_ctrl_shift_rot_nxt;
reg              R_ctrl_shift_rot_right;
wire             R_ctrl_shift_rot_right_nxt;
reg              R_ctrl_src2_choose_imm;
wire             R_ctrl_src2_choose_imm_nxt;
reg              R_ctrl_st;
wire             R_ctrl_st_nxt;
reg              R_ctrl_uncond_cti_non_br;
wire             R_ctrl_uncond_cti_non_br_nxt;
reg              R_ctrl_unsigned_lo_imm16;
wire             R_ctrl_unsigned_lo_imm16_nxt;
reg              R_ctrl_wrctl_inst;
wire             R_ctrl_wrctl_inst_nxt;
reg     [  4: 0] R_dst_regnum /* synthesis ALTERA_IP_DEBUG_VISIBLE = 1 */;
wire             R_en;
reg     [  1: 0] R_logic_op;
wire    [ 31: 0] R_rf_a;
wire    [ 31: 0] R_rf_b;
wire    [ 31: 0] R_src1;
wire    [ 31: 0] R_src2;
wire    [ 15: 0] R_src2_hi;
wire    [ 15: 0] R_src2_lo;
reg              R_src2_use_imm;
wire    [  7: 0] R_stb_data;
wire    [ 15: 0] R_sth_data;
reg              R_valid;
wire    [ 55: 0] R_vinst;
reg              R_wr_dst_reg;
reg     [ 31: 0] W_alu_result;
wire             W_br_taken;
reg              W_bstatus_reg;
wire             W_bstatus_reg_inst_nxt;
wire             W_bstatus_reg_nxt;
reg              W_cmp_result;
reg     [ 31: 0] W_control_rd_data;
wire    [ 31: 0] W_cpuid_reg;
reg              W_estatus_reg;
wire             W_estatus_reg_inst_nxt;
wire             W_estatus_reg_nxt;
reg     [ 31: 0] W_ienable_reg;
wire    [ 31: 0] W_ienable_reg_nxt;
reg     [ 31: 0] W_ipending_reg;
wire    [ 31: 0] W_ipending_reg_nxt;
wire    [ 13: 0] W_mem_baddr;
wire    [ 31: 0] W_rf_wr_data;
wire             W_rf_wren;
wire             W_status_reg;
reg              W_status_reg_pie;
wire             W_status_reg_pie_inst_nxt;
wire             W_status_reg_pie_nxt;
reg              W_valid /* synthesis ALTERA_IP_DEBUG_VISIBLE = 1 */;
wire    [ 55: 0] W_vinst;
wire    [ 31: 0] W_wr_data;
wire    [ 31: 0] W_wr_data_non_zero;
wire             av_fill_bit;
reg     [  1: 0] av_ld_align_cycle;
wire    [  1: 0] av_ld_align_cycle_nxt;
wire             av_ld_align_one_more_cycle;
reg              av_ld_aligning_data;
wire             av_ld_aligning_data_nxt;
reg     [  7: 0] av_ld_byte0_data;
wire    [  7: 0] av_ld_byte0_data_nxt;
reg     [  7: 0] av_ld_byte1_data;
wire             av_ld_byte1_data_en;
wire    [  7: 0] av_ld_byte1_data_nxt;
reg     [  7: 0] av_ld_byte2_data;
wire    [  7: 0] av_ld_byte2_data_nxt;
reg     [  7: 0] av_ld_byte3_data;
wire    [  7: 0] av_ld_byte3_data_nxt;
wire    [ 31: 0] av_ld_data_aligned_filtered;
wire    [ 31: 0] av_ld_data_aligned_unfiltered;
wire             av_ld_done;
wire             av_ld_extend;
wire             av_ld_getting_data;
wire             av_ld_rshift8;
reg              av_ld_waiting_for_data;
wire             av_ld_waiting_for_data_nxt;
wire             av_sign_bit;
wire    [ 13: 0] d_address;
reg     [  3: 0] d_byteenable;
reg              d_read;
wire             d_read_nxt;
reg              d_write;
wire             d_write_nxt;
reg     [ 31: 0] d_writedata;
wire             hbreak_req;
wire    [ 11: 0] i_address;
reg              i_read;
wire             i_read_nxt;
wire    [ 31: 0] iactive;
wire             intr_req;
wire             no_ci_readra;
wire    [ 31: 0] oci_ienable;
wire             test_has_ended;
  //the_alt_xcvr_reconfig_cpu_reconfig_cpu_test_bench, which is an e_instance
  alt_xcvr_reconfig_cpu_reconfig_cpu_test_bench the_alt_xcvr_reconfig_cpu_reconfig_cpu_test_bench
    (
      .D_iw                          (D_iw),
      .D_iw_op                       (D_iw_op),
      .D_iw_opx                      (D_iw_opx),
      .D_valid                       (D_valid),
      .E_valid                       (E_valid),
      .F_pcb                         (F_pcb),
      .F_valid                       (F_valid),
      .R_ctrl_ld                     (R_ctrl_ld),
      .R_ctrl_ld_non_io              (R_ctrl_ld_non_io),
      .R_dst_regnum                  (R_dst_regnum),
      .R_wr_dst_reg                  (R_wr_dst_reg),
      .W_valid                       (W_valid),
      .W_vinst                       (W_vinst),
      .W_wr_data                     (W_wr_data),
      .av_ld_data_aligned_filtered   (av_ld_data_aligned_filtered),
      .av_ld_data_aligned_unfiltered (av_ld_data_aligned_unfiltered),
      .clk                           (clk),
      .d_address                     (d_address),
      .d_byteenable                  (d_byteenable),
      .d_read                        (d_read),
      .d_write                       (d_write),
      .i_address                     (i_address),
      .i_read                        (i_read),
      .i_readdata                    (i_readdata),
      .i_waitrequest                 (i_waitrequest),
      .reset_n                       (reset_n),
      .test_has_ended                (test_has_ended)
    );

  assign F_av_iw_a = F_av_iw[31 : 27];
  assign F_av_iw_b = F_av_iw[26 : 22];
  assign F_av_iw_c = F_av_iw[21 : 17];
  assign F_av_iw_custom_n = F_av_iw[13 : 6];
  assign F_av_iw_custom_readra = F_av_iw[16];
  assign F_av_iw_custom_readrb = F_av_iw[15];
  assign F_av_iw_custom_writerc = F_av_iw[14];
  assign F_av_iw_opx = F_av_iw[16 : 11];
  assign F_av_iw_op = F_av_iw[5 : 0];
  assign F_av_iw_shift_imm5 = F_av_iw[10 : 6];
  assign F_av_iw_trap_break_imm5 = F_av_iw[10 : 6];
  assign F_av_iw_imm5 = F_av_iw[10 : 6];
  assign F_av_iw_imm16 = F_av_iw[21 : 6];
  assign F_av_iw_imm26 = F_av_iw[31 : 6];
  assign F_av_iw_memsz = F_av_iw[4 : 3];
  assign F_av_iw_control_regnum = F_av_iw[8 : 6];
  assign F_av_mem8 = F_av_iw_memsz == 2'b00;
  assign F_av_mem16 = F_av_iw_memsz == 2'b01;
  assign F_av_mem32 = F_av_iw_memsz[1] == 1'b1;
  assign F_iw_a = F_iw[31 : 27];
  assign F_iw_b = F_iw[26 : 22];
  assign F_iw_c = F_iw[21 : 17];
  assign F_iw_custom_n = F_iw[13 : 6];
  assign F_iw_custom_readra = F_iw[16];
  assign F_iw_custom_readrb = F_iw[15];
  assign F_iw_custom_writerc = F_iw[14];
  assign F_iw_opx = F_iw[16 : 11];
  assign F_iw_op = F_iw[5 : 0];
  assign F_iw_shift_imm5 = F_iw[10 : 6];
  assign F_iw_trap_break_imm5 = F_iw[10 : 6];
  assign F_iw_imm5 = F_iw[10 : 6];
  assign F_iw_imm16 = F_iw[21 : 6];
  assign F_iw_imm26 = F_iw[31 : 6];
  assign F_iw_memsz = F_iw[4 : 3];
  assign F_iw_control_regnum = F_iw[8 : 6];
  assign F_mem8 = F_iw_memsz == 2'b00;
  assign F_mem16 = F_iw_memsz == 2'b01;
  assign F_mem32 = F_iw_memsz[1] == 1'b1;
  assign D_iw_a = D_iw[31 : 27];
  assign D_iw_b = D_iw[26 : 22];
  assign D_iw_c = D_iw[21 : 17];
  assign D_iw_custom_n = D_iw[13 : 6];
  assign D_iw_custom_readra = D_iw[16];
  assign D_iw_custom_readrb = D_iw[15];
  assign D_iw_custom_writerc = D_iw[14];
  assign D_iw_opx = D_iw[16 : 11];
  assign D_iw_op = D_iw[5 : 0];
  assign D_iw_shift_imm5 = D_iw[10 : 6];
  assign D_iw_trap_break_imm5 = D_iw[10 : 6];
  assign D_iw_imm5 = D_iw[10 : 6];
  assign D_iw_imm16 = D_iw[21 : 6];
  assign D_iw_imm26 = D_iw[31 : 6];
  assign D_iw_memsz = D_iw[4 : 3];
  assign D_iw_control_regnum = D_iw[8 : 6];
  assign D_mem8 = D_iw_memsz == 2'b00;
  assign D_mem16 = D_iw_memsz == 2'b01;
  assign D_mem32 = D_iw_memsz[1] == 1'b1;
  assign F_op_call = F_iw_op == 0;
  assign F_op_jmpi = F_iw_op == 1;
  assign F_op_ldbu = F_iw_op == 3;
  assign F_op_addi = F_iw_op == 4;
  assign F_op_stb = F_iw_op == 5;
  assign F_op_br = F_iw_op == 6;
  assign F_op_ldb = F_iw_op == 7;
  assign F_op_cmpgei = F_iw_op == 8;
  assign F_op_ldhu = F_iw_op == 11;
  assign F_op_andi = F_iw_op == 12;
  assign F_op_sth = F_iw_op == 13;
  assign F_op_bge = F_iw_op == 14;
  assign F_op_ldh = F_iw_op == 15;
  assign F_op_cmplti = F_iw_op == 16;
  assign F_op_initda = F_iw_op == 19;
  assign F_op_ori = F_iw_op == 20;
  assign F_op_stw = F_iw_op == 21;
  assign F_op_blt = F_iw_op == 22;
  assign F_op_ldw = F_iw_op == 23;
  assign F_op_cmpnei = F_iw_op == 24;
  assign F_op_flushda = F_iw_op == 27;
  assign F_op_xori = F_iw_op == 28;
  assign F_op_stc = F_iw_op == 29;
  assign F_op_bne = F_iw_op == 30;
  assign F_op_ldl = F_iw_op == 31;
  assign F_op_cmpeqi = F_iw_op == 32;
  assign F_op_ldbuio = F_iw_op == 35;
  assign F_op_muli = F_iw_op == 36;
  assign F_op_stbio = F_iw_op == 37;
  assign F_op_beq = F_iw_op == 38;
  assign F_op_ldbio = F_iw_op == 39;
  assign F_op_cmpgeui = F_iw_op == 40;
  assign F_op_ldhuio = F_iw_op == 43;
  assign F_op_andhi = F_iw_op == 44;
  assign F_op_sthio = F_iw_op == 45;
  assign F_op_bgeu = F_iw_op == 46;
  assign F_op_ldhio = F_iw_op == 47;
  assign F_op_cmpltui = F_iw_op == 48;
  assign F_op_initd = F_iw_op == 51;
  assign F_op_orhi = F_iw_op == 52;
  assign F_op_stwio = F_iw_op == 53;
  assign F_op_bltu = F_iw_op == 54;
  assign F_op_ldwio = F_iw_op == 55;
  assign F_op_rdprs = F_iw_op == 56;
  assign F_op_flushd = F_iw_op == 59;
  assign F_op_xorhi = F_iw_op == 60;
  assign F_op_rsv02 = F_iw_op == 2;
  assign F_op_rsv09 = F_iw_op == 9;
  assign F_op_rsv10 = F_iw_op == 10;
  assign F_op_rsv17 = F_iw_op == 17;
  assign F_op_rsv18 = F_iw_op == 18;
  assign F_op_rsv25 = F_iw_op == 25;
  assign F_op_rsv26 = F_iw_op == 26;
  assign F_op_rsv33 = F_iw_op == 33;
  assign F_op_rsv34 = F_iw_op == 34;
  assign F_op_rsv41 = F_iw_op == 41;
  assign F_op_rsv42 = F_iw_op == 42;
  assign F_op_rsv49 = F_iw_op == 49;
  assign F_op_rsv57 = F_iw_op == 57;
  assign F_op_rsv61 = F_iw_op == 61;
  assign F_op_rsv62 = F_iw_op == 62;
  assign F_op_rsv63 = F_iw_op == 63;
  assign F_op_eret = F_op_opx & (F_iw_opx == 1);
  assign F_op_roli = F_op_opx & (F_iw_opx == 2);
  assign F_op_rol = F_op_opx & (F_iw_opx == 3);
  assign F_op_flushp = F_op_opx & (F_iw_opx == 4);
  assign F_op_ret = F_op_opx & (F_iw_opx == 5);
  assign F_op_nor = F_op_opx & (F_iw_opx == 6);
  assign F_op_mulxuu = F_op_opx & (F_iw_opx == 7);
  assign F_op_cmpge = F_op_opx & (F_iw_opx == 8);
  assign F_op_bret = F_op_opx & (F_iw_opx == 9);
  assign F_op_ror = F_op_opx & (F_iw_opx == 11);
  assign F_op_flushi = F_op_opx & (F_iw_opx == 12);
  assign F_op_jmp = F_op_opx & (F_iw_opx == 13);
  assign F_op_and = F_op_opx & (F_iw_opx == 14);
  assign F_op_cmplt = F_op_opx & (F_iw_opx == 16);
  assign F_op_slli = F_op_opx & (F_iw_opx == 18);
  assign F_op_sll = F_op_opx & (F_iw_opx == 19);
  assign F_op_wrprs = F_op_opx & (F_iw_opx == 20);
  assign F_op_or = F_op_opx & (F_iw_opx == 22);
  assign F_op_mulxsu = F_op_opx & (F_iw_opx == 23);
  assign F_op_cmpne = F_op_opx & (F_iw_opx == 24);
  assign F_op_srli = F_op_opx & (F_iw_opx == 26);
  assign F_op_srl = F_op_opx & (F_iw_opx == 27);
  assign F_op_nextpc = F_op_opx & (F_iw_opx == 28);
  assign F_op_callr = F_op_opx & (F_iw_opx == 29);
  assign F_op_xor = F_op_opx & (F_iw_opx == 30);
  assign F_op_mulxss = F_op_opx & (F_iw_opx == 31);
  assign F_op_cmpeq = F_op_opx & (F_iw_opx == 32);
  assign F_op_divu = F_op_opx & (F_iw_opx == 36);
  assign F_op_div = F_op_opx & (F_iw_opx == 37);
  assign F_op_rdctl = F_op_opx & (F_iw_opx == 38);
  assign F_op_mul = F_op_opx & (F_iw_opx == 39);
  assign F_op_cmpgeu = F_op_opx & (F_iw_opx == 40);
  assign F_op_initi = F_op_opx & (F_iw_opx == 41);
  assign F_op_trap = F_op_opx & (F_iw_opx == 45);
  assign F_op_wrctl = F_op_opx & (F_iw_opx == 46);
  assign F_op_cmpltu = F_op_opx & (F_iw_opx == 48);
  assign F_op_add = F_op_opx & (F_iw_opx == 49);
  assign F_op_break = F_op_opx & (F_iw_opx == 52);
  assign F_op_hbreak = F_op_opx & (F_iw_opx == 53);
  assign F_op_sync = F_op_opx & (F_iw_opx == 54);
  assign F_op_sub = F_op_opx & (F_iw_opx == 57);
  assign F_op_srai = F_op_opx & (F_iw_opx == 58);
  assign F_op_sra = F_op_opx & (F_iw_opx == 59);
  assign F_op_intr = F_op_opx & (F_iw_opx == 61);
  assign F_op_crst = F_op_opx & (F_iw_opx == 62);
  assign F_op_rsvx00 = F_op_opx & (F_iw_opx == 0);
  assign F_op_rsvx10 = F_op_opx & (F_iw_opx == 10);
  assign F_op_rsvx15 = F_op_opx & (F_iw_opx == 15);
  assign F_op_rsvx17 = F_op_opx & (F_iw_opx == 17);
  assign F_op_rsvx21 = F_op_opx & (F_iw_opx == 21);
  assign F_op_rsvx25 = F_op_opx & (F_iw_opx == 25);
  assign F_op_rsvx33 = F_op_opx & (F_iw_opx == 33);
  assign F_op_rsvx34 = F_op_opx & (F_iw_opx == 34);
  assign F_op_rsvx35 = F_op_opx & (F_iw_opx == 35);
  assign F_op_rsvx42 = F_op_opx & (F_iw_opx == 42);
  assign F_op_rsvx43 = F_op_opx & (F_iw_opx == 43);
  assign F_op_rsvx44 = F_op_opx & (F_iw_opx == 44);
  assign F_op_rsvx47 = F_op_opx & (F_iw_opx == 47);
  assign F_op_rsvx50 = F_op_opx & (F_iw_opx == 50);
  assign F_op_rsvx51 = F_op_opx & (F_iw_opx == 51);
  assign F_op_rsvx55 = F_op_opx & (F_iw_opx == 55);
  assign F_op_rsvx56 = F_op_opx & (F_iw_opx == 56);
  assign F_op_rsvx60 = F_op_opx & (F_iw_opx == 60);
  assign F_op_rsvx63 = F_op_opx & (F_iw_opx == 63);
  assign F_op_opx = F_iw_op == 58;
  assign F_op_custom = F_iw_op == 50;
  assign D_op_call = D_iw_op == 0;
  assign D_op_jmpi = D_iw_op == 1;
  assign D_op_ldbu = D_iw_op == 3;
  assign D_op_addi = D_iw_op == 4;
  assign D_op_stb = D_iw_op == 5;
  assign D_op_br = D_iw_op == 6;
  assign D_op_ldb = D_iw_op == 7;
  assign D_op_cmpgei = D_iw_op == 8;
  assign D_op_ldhu = D_iw_op == 11;
  assign D_op_andi = D_iw_op == 12;
  assign D_op_sth = D_iw_op == 13;
  assign D_op_bge = D_iw_op == 14;
  assign D_op_ldh = D_iw_op == 15;
  assign D_op_cmplti = D_iw_op == 16;
  assign D_op_initda = D_iw_op == 19;
  assign D_op_ori = D_iw_op == 20;
  assign D_op_stw = D_iw_op == 21;
  assign D_op_blt = D_iw_op == 22;
  assign D_op_ldw = D_iw_op == 23;
  assign D_op_cmpnei = D_iw_op == 24;
  assign D_op_flushda = D_iw_op == 27;
  assign D_op_xori = D_iw_op == 28;
  assign D_op_stc = D_iw_op == 29;
  assign D_op_bne = D_iw_op == 30;
  assign D_op_ldl = D_iw_op == 31;
  assign D_op_cmpeqi = D_iw_op == 32;
  assign D_op_ldbuio = D_iw_op == 35;
  assign D_op_muli = D_iw_op == 36;
  assign D_op_stbio = D_iw_op == 37;
  assign D_op_beq = D_iw_op == 38;
  assign D_op_ldbio = D_iw_op == 39;
  assign D_op_cmpgeui = D_iw_op == 40;
  assign D_op_ldhuio = D_iw_op == 43;
  assign D_op_andhi = D_iw_op == 44;
  assign D_op_sthio = D_iw_op == 45;
  assign D_op_bgeu = D_iw_op == 46;
  assign D_op_ldhio = D_iw_op == 47;
  assign D_op_cmpltui = D_iw_op == 48;
  assign D_op_initd = D_iw_op == 51;
  assign D_op_orhi = D_iw_op == 52;
  assign D_op_stwio = D_iw_op == 53;
  assign D_op_bltu = D_iw_op == 54;
  assign D_op_ldwio = D_iw_op == 55;
  assign D_op_rdprs = D_iw_op == 56;
  assign D_op_flushd = D_iw_op == 59;
  assign D_op_xorhi = D_iw_op == 60;
  assign D_op_rsv02 = D_iw_op == 2;
  assign D_op_rsv09 = D_iw_op == 9;
  assign D_op_rsv10 = D_iw_op == 10;
  assign D_op_rsv17 = D_iw_op == 17;
  assign D_op_rsv18 = D_iw_op == 18;
  assign D_op_rsv25 = D_iw_op == 25;
  assign D_op_rsv26 = D_iw_op == 26;
  assign D_op_rsv33 = D_iw_op == 33;
  assign D_op_rsv34 = D_iw_op == 34;
  assign D_op_rsv41 = D_iw_op == 41;
  assign D_op_rsv42 = D_iw_op == 42;
  assign D_op_rsv49 = D_iw_op == 49;
  assign D_op_rsv57 = D_iw_op == 57;
  assign D_op_rsv61 = D_iw_op == 61;
  assign D_op_rsv62 = D_iw_op == 62;
  assign D_op_rsv63 = D_iw_op == 63;
  assign D_op_eret = D_op_opx & (D_iw_opx == 1);
  assign D_op_roli = D_op_opx & (D_iw_opx == 2);
  assign D_op_rol = D_op_opx & (D_iw_opx == 3);
  assign D_op_flushp = D_op_opx & (D_iw_opx == 4);
  assign D_op_ret = D_op_opx & (D_iw_opx == 5);
  assign D_op_nor = D_op_opx & (D_iw_opx == 6);
  assign D_op_mulxuu = D_op_opx & (D_iw_opx == 7);
  assign D_op_cmpge = D_op_opx & (D_iw_opx == 8);
  assign D_op_bret = D_op_opx & (D_iw_opx == 9);
  assign D_op_ror = D_op_opx & (D_iw_opx == 11);
  assign D_op_flushi = D_op_opx & (D_iw_opx == 12);
  assign D_op_jmp = D_op_opx & (D_iw_opx == 13);
  assign D_op_and = D_op_opx & (D_iw_opx == 14);
  assign D_op_cmplt = D_op_opx & (D_iw_opx == 16);
  assign D_op_slli = D_op_opx & (D_iw_opx == 18);
  assign D_op_sll = D_op_opx & (D_iw_opx == 19);
  assign D_op_wrprs = D_op_opx & (D_iw_opx == 20);
  assign D_op_or = D_op_opx & (D_iw_opx == 22);
  assign D_op_mulxsu = D_op_opx & (D_iw_opx == 23);
  assign D_op_cmpne = D_op_opx & (D_iw_opx == 24);
  assign D_op_srli = D_op_opx & (D_iw_opx == 26);
  assign D_op_srl = D_op_opx & (D_iw_opx == 27);
  assign D_op_nextpc = D_op_opx & (D_iw_opx == 28);
  assign D_op_callr = D_op_opx & (D_iw_opx == 29);
  assign D_op_xor = D_op_opx & (D_iw_opx == 30);
  assign D_op_mulxss = D_op_opx & (D_iw_opx == 31);
  assign D_op_cmpeq = D_op_opx & (D_iw_opx == 32);
  assign D_op_divu = D_op_opx & (D_iw_opx == 36);
  assign D_op_div = D_op_opx & (D_iw_opx == 37);
  assign D_op_rdctl = D_op_opx & (D_iw_opx == 38);
  assign D_op_mul = D_op_opx & (D_iw_opx == 39);
  assign D_op_cmpgeu = D_op_opx & (D_iw_opx == 40);
  assign D_op_initi = D_op_opx & (D_iw_opx == 41);
  assign D_op_trap = D_op_opx & (D_iw_opx == 45);
  assign D_op_wrctl = D_op_opx & (D_iw_opx == 46);
  assign D_op_cmpltu = D_op_opx & (D_iw_opx == 48);
  assign D_op_add = D_op_opx & (D_iw_opx == 49);
  assign D_op_break = D_op_opx & (D_iw_opx == 52);
  assign D_op_hbreak = D_op_opx & (D_iw_opx == 53);
  assign D_op_sync = D_op_opx & (D_iw_opx == 54);
  assign D_op_sub = D_op_opx & (D_iw_opx == 57);
  assign D_op_srai = D_op_opx & (D_iw_opx == 58);
  assign D_op_sra = D_op_opx & (D_iw_opx == 59);
  assign D_op_intr = D_op_opx & (D_iw_opx == 61);
  assign D_op_crst = D_op_opx & (D_iw_opx == 62);
  assign D_op_rsvx00 = D_op_opx & (D_iw_opx == 0);
  assign D_op_rsvx10 = D_op_opx & (D_iw_opx == 10);
  assign D_op_rsvx15 = D_op_opx & (D_iw_opx == 15);
  assign D_op_rsvx17 = D_op_opx & (D_iw_opx == 17);
  assign D_op_rsvx21 = D_op_opx & (D_iw_opx == 21);
  assign D_op_rsvx25 = D_op_opx & (D_iw_opx == 25);
  assign D_op_rsvx33 = D_op_opx & (D_iw_opx == 33);
  assign D_op_rsvx34 = D_op_opx & (D_iw_opx == 34);
  assign D_op_rsvx35 = D_op_opx & (D_iw_opx == 35);
  assign D_op_rsvx42 = D_op_opx & (D_iw_opx == 42);
  assign D_op_rsvx43 = D_op_opx & (D_iw_opx == 43);
  assign D_op_rsvx44 = D_op_opx & (D_iw_opx == 44);
  assign D_op_rsvx47 = D_op_opx & (D_iw_opx == 47);
  assign D_op_rsvx50 = D_op_opx & (D_iw_opx == 50);
  assign D_op_rsvx51 = D_op_opx & (D_iw_opx == 51);
  assign D_op_rsvx55 = D_op_opx & (D_iw_opx == 55);
  assign D_op_rsvx56 = D_op_opx & (D_iw_opx == 56);
  assign D_op_rsvx60 = D_op_opx & (D_iw_opx == 60);
  assign D_op_rsvx63 = D_op_opx & (D_iw_opx == 63);
  assign D_op_opx = D_iw_op == 58;
  assign D_op_custom = D_iw_op == 50;
  assign R_en = 1'b1;
  assign E_ci_result = 0;
  //custom_instruction_master, which is an e_custom_instruction_master
  assign no_ci_readra = 1'b0;
  assign E_ci_multi_stall = 1'b0;
  assign iactive = d_irq[31 : 0] & 32'b00000000000000000000000000000001;
  assign F_pc_sel_nxt = R_ctrl_exception                          ? 2'b00 :
    R_ctrl_break                              ? 2'b01 :
    (W_br_taken | R_ctrl_uncond_cti_non_br)   ? 2'b10 :
    2'b11;

  assign F_pc_no_crst_nxt = (F_pc_sel_nxt == 2'b00)? 8 :
    (F_pc_sel_nxt == 2'b01)? 8 :
    (F_pc_sel_nxt == 2'b10)? E_arith_result[11 : 2] :
    F_pc_plus_one;

  assign F_pc_nxt = F_pc_no_crst_nxt;
  assign F_pcb_nxt = {F_pc_nxt, 2'b00};
  assign F_pc_en = W_valid;
  assign F_pc_plus_one = F_pc + 1;
  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          F_pc <= 0;
      else if (F_pc_en)
          F_pc <= F_pc_nxt;
    end


  assign F_pcb = {F_pc, 2'b00};
  assign F_pcb_plus_four = {F_pc_plus_one, 2'b00};
  assign F_valid = i_read & ~i_waitrequest;
  assign i_read_nxt = W_valid | (i_read & i_waitrequest);
  assign i_address = {F_pc, 2'b00};
  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          i_read <= 1'b1;
      else 
        i_read <= i_read_nxt;
    end


  assign hbreak_req = 1'b0;
  assign intr_req = W_status_reg_pie & (W_ipending_reg != 0);
  assign F_av_iw = i_readdata;
  assign F_iw = hbreak_req     ? 4040762 :
    1'b0   ? 127034 :
    intr_req       ? 3926074 : 
    F_av_iw;

  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          D_iw <= 0;
      else if (F_valid)
          D_iw <= F_iw;
    end


  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          D_valid <= 0;
      else 
        D_valid <= F_valid;
    end


  assign D_dst_regnum = D_ctrl_implicit_dst_retaddr    ? 5'd31 : 
    D_ctrl_implicit_dst_eretaddr   ? 5'd29 : 
    D_ctrl_b_is_dst                ? D_iw_b :
    D_iw_c;

  assign D_wr_dst_reg = (D_dst_regnum != 0) & ~D_ctrl_ignore_dst;
  assign D_logic_op_raw = D_op_opx ? D_iw_opx[4 : 3] : 
    D_iw_op[4 : 3];

  assign D_logic_op = D_ctrl_alu_force_xor ? 2'b11 : D_logic_op_raw;
  assign D_compare_op = D_op_opx ? D_iw_opx[4 : 3] : 
    D_iw_op[4 : 3];

  assign D_jmp_direct_target_waddr = D_iw[31 : 6];
  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          R_valid <= 0;
      else 
        R_valid <= D_valid;
    end


  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          R_wr_dst_reg <= 0;
      else 
        R_wr_dst_reg <= D_wr_dst_reg;
    end


  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          R_dst_regnum <= 0;
      else 
        R_dst_regnum <= D_dst_regnum;
    end


  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          R_logic_op <= 0;
      else 
        R_logic_op <= D_logic_op;
    end


  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          R_compare_op <= 0;
      else 
        R_compare_op <= D_compare_op;
    end


  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          R_src2_use_imm <= 0;
      else 
        R_src2_use_imm <= D_ctrl_src2_choose_imm | (D_ctrl_br & R_valid);
    end


  assign W_rf_wren = (R_wr_dst_reg & W_valid) | ~reset_n;
  assign W_rf_wr_data = R_ctrl_ld ? av_ld_data_aligned_filtered : W_wr_data;
//alt_xcvr_reconfig_cpu_reconfig_cpu_register_bank_a, which is an nios_sdp_ram
alt_xcvr_reconfig_cpu_reconfig_cpu_register_bank_a_module alt_xcvr_reconfig_cpu_reconfig_cpu_register_bank_a
  (
    .clock     (clk),
    .data      (W_rf_wr_data),
    .q         (R_rf_a),
    .rdaddress (D_iw_a),
    .wraddress (R_dst_regnum),
    .wren      (W_rf_wren)
  );

//synthesis translate_off
`ifdef NO_PLI
defparam alt_xcvr_reconfig_cpu_reconfig_cpu_register_bank_a.lpm_file = "alt_xcvr_reconfig_cpu_reconfig_cpu_rf_ram_a.dat";
`else
defparam alt_xcvr_reconfig_cpu_reconfig_cpu_register_bank_a.lpm_file = "alt_xcvr_reconfig_cpu_reconfig_cpu_rf_ram_a.hex";
`endif
//synthesis translate_on
//synthesis read_comments_as_HDL on
//defparam alt_xcvr_reconfig_cpu_reconfig_cpu_register_bank_a.lpm_file = "alt_xcvr_reconfig_cpu_reconfig_cpu_rf_ram_a.mif";
//synthesis read_comments_as_HDL off
//alt_xcvr_reconfig_cpu_reconfig_cpu_register_bank_b, which is an nios_sdp_ram
alt_xcvr_reconfig_cpu_reconfig_cpu_register_bank_b_module alt_xcvr_reconfig_cpu_reconfig_cpu_register_bank_b
  (
    .clock     (clk),
    .data      (W_rf_wr_data),
    .q         (R_rf_b),
    .rdaddress (D_iw_b),
    .wraddress (R_dst_regnum),
    .wren      (W_rf_wren)
  );

//synthesis translate_off
`ifdef NO_PLI
defparam alt_xcvr_reconfig_cpu_reconfig_cpu_register_bank_b.lpm_file = "alt_xcvr_reconfig_cpu_reconfig_cpu_rf_ram_b.dat";
`else
defparam alt_xcvr_reconfig_cpu_reconfig_cpu_register_bank_b.lpm_file = "alt_xcvr_reconfig_cpu_reconfig_cpu_rf_ram_b.hex";
`endif
//synthesis translate_on
//synthesis read_comments_as_HDL on
//defparam alt_xcvr_reconfig_cpu_reconfig_cpu_register_bank_b.lpm_file = "alt_xcvr_reconfig_cpu_reconfig_cpu_rf_ram_b.mif";
//synthesis read_comments_as_HDL off
  assign R_src1 = (((R_ctrl_br & E_valid) | (R_ctrl_retaddr & R_valid)))? {F_pc_plus_one, 2'b00} :
    ((R_ctrl_jmp_direct & E_valid))? {D_jmp_direct_target_waddr, 2'b00} :
    R_rf_a;

  assign R_src2_lo = ((R_ctrl_force_src2_zero|R_ctrl_hi_imm16))? 16'b0 :
    (R_src2_use_imm)? D_iw_imm16 :
    R_rf_b[15 : 0];

  assign R_src2_hi = ((R_ctrl_force_src2_zero|R_ctrl_unsigned_lo_imm16))? 16'b0 :
    (R_ctrl_hi_imm16)? D_iw_imm16 :
    (R_src2_use_imm)? {16 {D_iw_imm16[15]}} :
    R_rf_b[31 : 16];

  assign R_src2 = {R_src2_hi, R_src2_lo};
  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          E_valid <= 0;
      else 
        E_valid <= R_valid | E_stall;
    end


  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          E_new_inst <= 0;
      else 
        E_new_inst <= R_valid;
    end


  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          E_src1 <= 0;
      else 
        E_src1 <= R_src1;
    end


  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          E_src2 <= 0;
      else 
        E_src2 <= R_src2;
    end


  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          E_invert_arith_src_msb <= 0;
      else 
        E_invert_arith_src_msb <= D_ctrl_alu_signed_comparison & R_valid;
    end


  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          E_alu_sub <= 0;
      else 
        E_alu_sub <= D_ctrl_alu_subtract & R_valid;
    end


  assign E_stall = E_shift_rot_stall | E_ld_stall | E_st_stall | E_ci_multi_stall;
  assign E_arith_src1 = { E_src1[31] ^ E_invert_arith_src_msb, 
    E_src1[30 : 0]};

  assign E_arith_src2 = { E_src2[31] ^ E_invert_arith_src_msb, 
    E_src2[30 : 0]};

  assign E_arith_result = E_alu_sub ?
    E_arith_src1 - E_arith_src2 :
    E_arith_src1 + E_arith_src2;

  assign E_mem_baddr = E_arith_result[13 : 0];
  assign E_logic_result = (R_logic_op == 2'b00)? (~(E_src1 | E_src2)) :
    (R_logic_op == 2'b01)? (E_src1 & E_src2) :
    (R_logic_op == 2'b10)? (E_src1 | E_src2) :
    (E_src1 ^ E_src2);

  assign E_logic_result_is_0 = E_logic_result == 0;
  assign E_eq = E_logic_result_is_0;
  assign E_lt = E_arith_result[32];
  assign E_cmp_result = (R_compare_op == 2'b00)? E_eq :
    (R_compare_op == 2'b01)? ~E_lt :
    (R_compare_op == 2'b10)? E_lt :
    ~E_eq;

  assign E_shift_rot_cnt_nxt = E_new_inst ? E_src2[4 : 0] : E_shift_rot_cnt-1;
  assign E_shift_rot_done = (E_shift_rot_cnt == 0) & ~E_new_inst;
  assign E_shift_rot_stall = R_ctrl_shift_rot & E_valid & ~E_shift_rot_done;
  assign E_shift_rot_fill_bit = R_ctrl_shift_logical ? 1'b0 :
    (R_ctrl_rot_right ? E_shift_rot_result[0] : 
    E_shift_rot_result[31]);

  assign E_shift_rot_result_nxt = (E_new_inst)? E_src1 :
    (R_ctrl_shift_rot_right)? {E_shift_rot_fill_bit, E_shift_rot_result[31 : 1]} :
    {E_shift_rot_result[30 : 0], E_shift_rot_fill_bit};

  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          E_shift_rot_result <= 0;
      else 
        E_shift_rot_result <= E_shift_rot_result_nxt;
    end


  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          E_shift_rot_cnt <= 0;
      else 
        E_shift_rot_cnt <= E_shift_rot_cnt_nxt;
    end


  assign E_control_rd_data = (D_iw_control_regnum == 3'd0)? W_status_reg :
    (D_iw_control_regnum == 3'd1)? W_estatus_reg :
    (D_iw_control_regnum == 3'd2)? W_bstatus_reg :
    (D_iw_control_regnum == 3'd3)? W_ienable_reg :
    (D_iw_control_regnum == 3'd4)? W_ipending_reg :
    W_cpuid_reg;

  assign E_alu_result = ((R_ctrl_br_cmp | R_ctrl_rdctl_inst))? 0 :
    (R_ctrl_shift_rot)? E_shift_rot_result :
    (R_ctrl_logic)? E_logic_result :
    (R_ctrl_custom)? E_ci_result :
    E_arith_result;

  assign R_stb_data = R_rf_b[7 : 0];
  assign R_sth_data = R_rf_b[15 : 0];
  assign E_st_data = (D_mem8)? {R_stb_data, R_stb_data, R_stb_data, R_stb_data} :
    (D_mem16)? {R_sth_data, R_sth_data} :
    R_rf_b;

  assign E_mem_byte_en = ({D_iw_memsz, E_mem_baddr[1 : 0]} == {2'b00, 2'b00})? 4'b0001 :
    ({D_iw_memsz, E_mem_baddr[1 : 0]} == {2'b00, 2'b01})? 4'b0010 :
    ({D_iw_memsz, E_mem_baddr[1 : 0]} == {2'b00, 2'b10})? 4'b0100 :
    ({D_iw_memsz, E_mem_baddr[1 : 0]} == {2'b00, 2'b11})? 4'b1000 :
    ({D_iw_memsz, E_mem_baddr[1 : 0]} == {2'b01, 2'b00})? 4'b0011 :
    ({D_iw_memsz, E_mem_baddr[1 : 0]} == {2'b01, 2'b01})? 4'b0011 :
    ({D_iw_memsz, E_mem_baddr[1 : 0]} == {2'b01, 2'b10})? 4'b1100 :
    ({D_iw_memsz, E_mem_baddr[1 : 0]} == {2'b01, 2'b11})? 4'b1100 :
    4'b1111;

  assign d_read_nxt = (R_ctrl_ld & E_new_inst) | (d_read & d_waitrequest);
  assign E_ld_stall = R_ctrl_ld & ((E_valid & ~av_ld_done) | E_new_inst);
  assign d_write_nxt = (R_ctrl_st & E_new_inst) | (d_write & d_waitrequest);
  assign E_st_stall = d_write_nxt;
  assign d_address = W_mem_baddr;
  assign av_ld_getting_data = d_read & ~d_waitrequest;
  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          d_read <= 0;
      else 
        d_read <= d_read_nxt;
    end


  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          d_writedata <= 0;
      else 
        d_writedata <= E_st_data;
    end


  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          d_byteenable <= 0;
      else 
        d_byteenable <= E_mem_byte_en;
    end


  assign av_ld_align_cycle_nxt = av_ld_getting_data ? 0 : (av_ld_align_cycle+1);
  assign av_ld_align_one_more_cycle = av_ld_align_cycle == (D_mem16 ? 2 : 3);
  assign av_ld_aligning_data_nxt = av_ld_aligning_data ? 
    ~av_ld_align_one_more_cycle : 
    (~D_mem32 & av_ld_getting_data);

  assign av_ld_waiting_for_data_nxt = av_ld_waiting_for_data ? 
    ~av_ld_getting_data : 
    (R_ctrl_ld & E_new_inst);

  assign av_ld_done = ~av_ld_waiting_for_data_nxt & (D_mem32 | ~av_ld_aligning_data_nxt);
  assign av_ld_rshift8 = av_ld_aligning_data & 
    (av_ld_align_cycle < (W_mem_baddr[1 : 0]));

  assign av_ld_extend = av_ld_aligning_data;
  assign av_ld_byte0_data_nxt = av_ld_rshift8      ? av_ld_byte1_data :
    av_ld_extend       ? av_ld_byte0_data :
    d_readdata[7 : 0];

  assign av_ld_byte1_data_nxt = av_ld_rshift8      ? av_ld_byte2_data :
    av_ld_extend       ? {8 {av_fill_bit}} :
    d_readdata[15 : 8];

  assign av_ld_byte2_data_nxt = av_ld_rshift8      ? av_ld_byte3_data :
    av_ld_extend       ? {8 {av_fill_bit}} :
    d_readdata[23 : 16];

  assign av_ld_byte3_data_nxt = av_ld_rshift8      ? av_ld_byte3_data :
    av_ld_extend       ? {8 {av_fill_bit}} :
    d_readdata[31 : 24];

  assign av_ld_byte1_data_en = ~(av_ld_extend & D_mem16 & ~av_ld_rshift8);
  assign av_ld_data_aligned_unfiltered = {av_ld_byte3_data, av_ld_byte2_data, 
    av_ld_byte1_data, av_ld_byte0_data};

  assign av_sign_bit = D_mem16 ? av_ld_byte1_data[7] : av_ld_byte0_data[7];
  assign av_fill_bit = av_sign_bit & R_ctrl_ld_signed;
  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          av_ld_align_cycle <= 0;
      else 
        av_ld_align_cycle <= av_ld_align_cycle_nxt;
    end


  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          av_ld_waiting_for_data <= 0;
      else 
        av_ld_waiting_for_data <= av_ld_waiting_for_data_nxt;
    end


  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          av_ld_aligning_data <= 0;
      else 
        av_ld_aligning_data <= av_ld_aligning_data_nxt;
    end


  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          av_ld_byte0_data <= 0;
      else 
        av_ld_byte0_data <= av_ld_byte0_data_nxt;
    end


  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          av_ld_byte1_data <= 0;
      else if (av_ld_byte1_data_en)
          av_ld_byte1_data <= av_ld_byte1_data_nxt;
    end


  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          av_ld_byte2_data <= 0;
      else 
        av_ld_byte2_data <= av_ld_byte2_data_nxt;
    end


  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          av_ld_byte3_data <= 0;
      else 
        av_ld_byte3_data <= av_ld_byte3_data_nxt;
    end


  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          W_valid <= 0;
      else 
        W_valid <= E_valid & ~E_stall;
    end


  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          W_control_rd_data <= 0;
      else 
        W_control_rd_data <= E_control_rd_data;
    end


  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          W_cmp_result <= 0;
      else 
        W_cmp_result <= E_cmp_result;
    end


  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          W_alu_result <= 0;
      else 
        W_alu_result <= E_alu_result;
    end


  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          W_status_reg_pie <= 0;
      else 
        W_status_reg_pie <= W_status_reg_pie_nxt;
    end


  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          W_estatus_reg <= 0;
      else 
        W_estatus_reg <= W_estatus_reg_nxt;
    end


  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          W_bstatus_reg <= 0;
      else 
        W_bstatus_reg <= W_bstatus_reg_nxt;
    end


  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          W_ienable_reg <= 0;
      else 
        W_ienable_reg <= W_ienable_reg_nxt;
    end


  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          W_ipending_reg <= 0;
      else 
        W_ipending_reg <= W_ipending_reg_nxt;
    end


  assign W_cpuid_reg = 0;
  assign W_wr_data_non_zero = R_ctrl_br_cmp ? W_cmp_result :
    R_ctrl_rdctl_inst       ? W_control_rd_data :
    W_alu_result[31 : 0];

  assign W_wr_data = W_wr_data_non_zero;
  assign W_br_taken = R_ctrl_br & W_cmp_result;
  assign W_mem_baddr = W_alu_result[13 : 0];
  assign W_status_reg = W_status_reg_pie;
  assign E_wrctl_status = R_ctrl_wrctl_inst & 
    (D_iw_control_regnum == 3'd0);

  assign E_wrctl_estatus = R_ctrl_wrctl_inst & 
    (D_iw_control_regnum == 3'd1);

  assign E_wrctl_bstatus = R_ctrl_wrctl_inst & 
    (D_iw_control_regnum == 3'd2);

  assign E_wrctl_ienable = R_ctrl_wrctl_inst & 
    (D_iw_control_regnum == 3'd3);

  assign W_status_reg_pie_inst_nxt = (R_ctrl_exception | R_ctrl_break | R_ctrl_crst) ? 1'b0 :
    (D_op_eret)                     ? W_estatus_reg :
    (D_op_bret)                     ? W_bstatus_reg :
    (E_wrctl_status)                ? E_src1[0] :
    W_status_reg_pie;

  assign W_status_reg_pie_nxt = E_valid ? W_status_reg_pie_inst_nxt : W_status_reg_pie;
  assign W_estatus_reg_inst_nxt = (R_ctrl_crst)        ? 0 :
    (R_ctrl_exception)   ? W_status_reg :
    (E_wrctl_estatus)    ? E_src1[0] :
    W_estatus_reg;

  assign W_estatus_reg_nxt = E_valid ? W_estatus_reg_inst_nxt : W_estatus_reg;
  assign W_bstatus_reg_inst_nxt = (R_ctrl_break)       ? W_status_reg :
    (E_wrctl_bstatus)    ? E_src1[0] :
    W_bstatus_reg;

  assign W_bstatus_reg_nxt = E_valid ? W_bstatus_reg_inst_nxt : W_bstatus_reg;
  assign W_ienable_reg_nxt = ((E_wrctl_ienable & E_valid) ? 
    E_src1[31 : 0] : W_ienable_reg) & 32'b00000000000000000000000000000001;

  assign W_ipending_reg_nxt = iactive & W_ienable_reg & oci_ienable & 32'b00000000000000000000000000000001;
  assign oci_ienable = {32{1'b1}};
  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          d_write <= 0;
      else 
        d_write <= d_write_nxt;
    end


  assign D_ctrl_custom = 1'b0;
  assign R_ctrl_custom_nxt = D_ctrl_custom;
  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          R_ctrl_custom <= 0;
      else if (R_en)
          R_ctrl_custom <= R_ctrl_custom_nxt;
    end


  assign D_ctrl_custom_multi = 1'b0;
  assign R_ctrl_custom_multi_nxt = D_ctrl_custom_multi;
  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          R_ctrl_custom_multi <= 0;
      else if (R_en)
          R_ctrl_custom_multi <= R_ctrl_custom_multi_nxt;
    end


  assign D_ctrl_jmp_indirect = D_op_eret|
    D_op_bret|
    D_op_rsvx17|
    D_op_rsvx25|
    D_op_ret|
    D_op_jmp|
    D_op_rsvx21|
    D_op_callr;

  assign R_ctrl_jmp_indirect_nxt = D_ctrl_jmp_indirect;
  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          R_ctrl_jmp_indirect <= 0;
      else if (R_en)
          R_ctrl_jmp_indirect <= R_ctrl_jmp_indirect_nxt;
    end


  assign D_ctrl_jmp_direct = D_op_call|D_op_jmpi;
  assign R_ctrl_jmp_direct_nxt = D_ctrl_jmp_direct;
  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          R_ctrl_jmp_direct <= 0;
      else if (R_en)
          R_ctrl_jmp_direct <= R_ctrl_jmp_direct_nxt;
    end


  assign D_ctrl_implicit_dst_retaddr = D_op_call|D_op_rsv02;
  assign R_ctrl_implicit_dst_retaddr_nxt = D_ctrl_implicit_dst_retaddr;
  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          R_ctrl_implicit_dst_retaddr <= 0;
      else if (R_en)
          R_ctrl_implicit_dst_retaddr <= R_ctrl_implicit_dst_retaddr_nxt;
    end


  assign D_ctrl_implicit_dst_eretaddr = D_op_div|D_op_divu|D_op_mul|D_op_muli|D_op_mulxss|D_op_mulxsu|D_op_mulxuu;
  assign R_ctrl_implicit_dst_eretaddr_nxt = D_ctrl_implicit_dst_eretaddr;
  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          R_ctrl_implicit_dst_eretaddr <= 0;
      else if (R_en)
          R_ctrl_implicit_dst_eretaddr <= R_ctrl_implicit_dst_eretaddr_nxt;
    end


  assign D_ctrl_exception = D_op_trap|
    D_op_rsvx44|
    D_op_div|
    D_op_divu|
    D_op_mul|
    D_op_muli|
    D_op_mulxss|
    D_op_mulxsu|
    D_op_mulxuu|
    D_op_intr|
    D_op_rsvx60;

  assign R_ctrl_exception_nxt = D_ctrl_exception;
  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          R_ctrl_exception <= 0;
      else if (R_en)
          R_ctrl_exception <= R_ctrl_exception_nxt;
    end


  assign D_ctrl_break = D_op_break|D_op_hbreak;
  assign R_ctrl_break_nxt = D_ctrl_break;
  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          R_ctrl_break <= 0;
      else if (R_en)
          R_ctrl_break <= R_ctrl_break_nxt;
    end


  assign D_ctrl_crst = D_op_crst|D_op_rsvx63;
  assign R_ctrl_crst_nxt = D_ctrl_crst;
  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          R_ctrl_crst <= 0;
      else if (R_en)
          R_ctrl_crst <= R_ctrl_crst_nxt;
    end


  assign D_ctrl_uncond_cti_non_br = D_op_call|
    D_op_jmpi|
    D_op_eret|
    D_op_bret|
    D_op_rsvx17|
    D_op_rsvx25|
    D_op_ret|
    D_op_jmp|
    D_op_rsvx21|
    D_op_callr;

  assign R_ctrl_uncond_cti_non_br_nxt = D_ctrl_uncond_cti_non_br;
  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          R_ctrl_uncond_cti_non_br <= 0;
      else if (R_en)
          R_ctrl_uncond_cti_non_br <= R_ctrl_uncond_cti_non_br_nxt;
    end


  assign D_ctrl_retaddr = D_op_call|
    D_op_rsv02|
    D_op_nextpc|
    D_op_callr|
    D_op_trap|
    D_op_rsvx44|
    D_op_div|
    D_op_divu|
    D_op_mul|
    D_op_muli|
    D_op_mulxss|
    D_op_mulxsu|
    D_op_mulxuu|
    D_op_intr|
    D_op_rsvx60|
    D_op_break|
    D_op_hbreak;

  assign R_ctrl_retaddr_nxt = D_ctrl_retaddr;
  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          R_ctrl_retaddr <= 0;
      else if (R_en)
          R_ctrl_retaddr <= R_ctrl_retaddr_nxt;
    end


  assign D_ctrl_shift_logical = D_op_slli|D_op_sll|D_op_srli|D_op_srl;
  assign R_ctrl_shift_logical_nxt = D_ctrl_shift_logical;
  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          R_ctrl_shift_logical <= 0;
      else if (R_en)
          R_ctrl_shift_logical <= R_ctrl_shift_logical_nxt;
    end


  assign D_ctrl_shift_right_arith = D_op_srai|D_op_sra;
  assign R_ctrl_shift_right_arith_nxt = D_ctrl_shift_right_arith;
  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          R_ctrl_shift_right_arith <= 0;
      else if (R_en)
          R_ctrl_shift_right_arith <= R_ctrl_shift_right_arith_nxt;
    end


  assign D_ctrl_rot_right = D_op_rsvx10|D_op_ror|D_op_rsvx42|D_op_rsvx43;
  assign R_ctrl_rot_right_nxt = D_ctrl_rot_right;
  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          R_ctrl_rot_right <= 0;
      else if (R_en)
          R_ctrl_rot_right <= R_ctrl_rot_right_nxt;
    end


  assign D_ctrl_shift_rot_right = D_op_srli|
    D_op_srl|
    D_op_srai|
    D_op_sra|
    D_op_rsvx10|
    D_op_ror|
    D_op_rsvx42|
    D_op_rsvx43;

  assign R_ctrl_shift_rot_right_nxt = D_ctrl_shift_rot_right;
  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          R_ctrl_shift_rot_right <= 0;
      else if (R_en)
          R_ctrl_shift_rot_right <= R_ctrl_shift_rot_right_nxt;
    end


  assign D_ctrl_shift_rot = D_op_slli|
    D_op_rsvx50|
    D_op_sll|
    D_op_rsvx51|
    D_op_roli|
    D_op_rsvx34|
    D_op_rol|
    D_op_rsvx35|
    D_op_srli|
    D_op_srl|
    D_op_srai|
    D_op_sra|
    D_op_rsvx10|
    D_op_ror|
    D_op_rsvx42|
    D_op_rsvx43;

  assign R_ctrl_shift_rot_nxt = D_ctrl_shift_rot;
  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          R_ctrl_shift_rot <= 0;
      else if (R_en)
          R_ctrl_shift_rot <= R_ctrl_shift_rot_nxt;
    end


  assign D_ctrl_logic = D_op_and|
    D_op_or|
    D_op_xor|
    D_op_nor|
    D_op_andhi|
    D_op_orhi|
    D_op_xorhi|
    D_op_andi|
    D_op_ori|
    D_op_xori;

  assign R_ctrl_logic_nxt = D_ctrl_logic;
  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          R_ctrl_logic <= 0;
      else if (R_en)
          R_ctrl_logic <= R_ctrl_logic_nxt;
    end


  assign D_ctrl_hi_imm16 = D_op_andhi|D_op_orhi|D_op_xorhi;
  assign R_ctrl_hi_imm16_nxt = D_ctrl_hi_imm16;
  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          R_ctrl_hi_imm16 <= 0;
      else if (R_en)
          R_ctrl_hi_imm16 <= R_ctrl_hi_imm16_nxt;
    end


  assign D_ctrl_unsigned_lo_imm16 = D_op_cmpgeui|
    D_op_cmpltui|
    D_op_andi|
    D_op_ori|
    D_op_xori|
    D_op_roli|
    D_op_rsvx10|
    D_op_slli|
    D_op_srli|
    D_op_rsvx34|
    D_op_rsvx42|
    D_op_rsvx50|
    D_op_srai;

  assign R_ctrl_unsigned_lo_imm16_nxt = D_ctrl_unsigned_lo_imm16;
  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          R_ctrl_unsigned_lo_imm16 <= 0;
      else if (R_en)
          R_ctrl_unsigned_lo_imm16 <= R_ctrl_unsigned_lo_imm16_nxt;
    end


  assign D_ctrl_br_uncond = D_op_br|D_op_rsv02;
  assign R_ctrl_br_uncond_nxt = D_ctrl_br_uncond;
  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          R_ctrl_br_uncond <= 0;
      else if (R_en)
          R_ctrl_br_uncond <= R_ctrl_br_uncond_nxt;
    end


  assign D_ctrl_br = D_op_br|
    D_op_bge|
    D_op_blt|
    D_op_bne|
    D_op_beq|
    D_op_bgeu|
    D_op_bltu|
    D_op_rsv62;

  assign R_ctrl_br_nxt = D_ctrl_br;
  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          R_ctrl_br <= 0;
      else if (R_en)
          R_ctrl_br <= R_ctrl_br_nxt;
    end


  assign D_ctrl_alu_subtract = D_op_sub|
    D_op_rsvx25|
    D_op_cmplti|
    D_op_cmpltui|
    D_op_cmplt|
    D_op_cmpltu|
    D_op_blt|
    D_op_bltu|
    D_op_cmpgei|
    D_op_cmpgeui|
    D_op_cmpge|
    D_op_cmpgeu|
    D_op_bge|
    D_op_rsv10|
    D_op_bgeu|
    D_op_rsv42;

  assign R_ctrl_alu_subtract_nxt = D_ctrl_alu_subtract;
  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          R_ctrl_alu_subtract <= 0;
      else if (R_en)
          R_ctrl_alu_subtract <= R_ctrl_alu_subtract_nxt;
    end


  assign D_ctrl_alu_signed_comparison = D_op_cmpge|D_op_cmpgei|D_op_cmplt|D_op_cmplti|D_op_bge|D_op_blt;
  assign R_ctrl_alu_signed_comparison_nxt = D_ctrl_alu_signed_comparison;
  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          R_ctrl_alu_signed_comparison <= 0;
      else if (R_en)
          R_ctrl_alu_signed_comparison <= R_ctrl_alu_signed_comparison_nxt;
    end


  assign D_ctrl_br_cmp = D_op_br|
    D_op_bge|
    D_op_blt|
    D_op_bne|
    D_op_beq|
    D_op_bgeu|
    D_op_bltu|
    D_op_rsv62|
    D_op_cmpgei|
    D_op_cmplti|
    D_op_cmpnei|
    D_op_cmpgeui|
    D_op_cmpltui|
    D_op_cmpeqi|
    D_op_rsvx00|
    D_op_cmpge|
    D_op_cmplt|
    D_op_cmpne|
    D_op_cmpgeu|
    D_op_cmpltu|
    D_op_cmpeq|
    D_op_rsvx56;

  assign R_ctrl_br_cmp_nxt = D_ctrl_br_cmp;
  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          R_ctrl_br_cmp <= 0;
      else if (R_en)
          R_ctrl_br_cmp <= R_ctrl_br_cmp_nxt;
    end


  assign D_ctrl_ld_signed = D_op_ldb|
    D_op_ldh|
    D_op_ldl|
    D_op_ldw|
    D_op_ldbio|
    D_op_ldhio|
    D_op_ldwio|
    D_op_rsv63;

  assign R_ctrl_ld_signed_nxt = D_ctrl_ld_signed;
  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          R_ctrl_ld_signed <= 0;
      else if (R_en)
          R_ctrl_ld_signed <= R_ctrl_ld_signed_nxt;
    end


  assign D_ctrl_ld = D_op_ldb|
    D_op_ldh|
    D_op_ldl|
    D_op_ldw|
    D_op_ldbio|
    D_op_ldhio|
    D_op_ldwio|
    D_op_rsv63|
    D_op_ldbu|
    D_op_ldhu|
    D_op_ldbuio|
    D_op_ldhuio;

  assign R_ctrl_ld_nxt = D_ctrl_ld;
  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          R_ctrl_ld <= 0;
      else if (R_en)
          R_ctrl_ld <= R_ctrl_ld_nxt;
    end


  assign D_ctrl_ld_non_io = D_op_ldbu|D_op_ldhu|D_op_ldb|D_op_ldh|D_op_ldw|D_op_ldl;
  assign R_ctrl_ld_non_io_nxt = D_ctrl_ld_non_io;
  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          R_ctrl_ld_non_io <= 0;
      else if (R_en)
          R_ctrl_ld_non_io <= R_ctrl_ld_non_io_nxt;
    end


  assign D_ctrl_st = D_op_stb|
    D_op_sth|
    D_op_stw|
    D_op_stc|
    D_op_stbio|
    D_op_sthio|
    D_op_stwio|
    D_op_rsv61;

  assign R_ctrl_st_nxt = D_ctrl_st;
  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          R_ctrl_st <= 0;
      else if (R_en)
          R_ctrl_st <= R_ctrl_st_nxt;
    end


  assign D_ctrl_ld_io = D_op_ldbuio|D_op_ldhuio|D_op_ldbio|D_op_ldhio|D_op_ldwio|D_op_rsv63;
  assign R_ctrl_ld_io_nxt = D_ctrl_ld_io;
  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          R_ctrl_ld_io <= 0;
      else if (R_en)
          R_ctrl_ld_io <= R_ctrl_ld_io_nxt;
    end


  assign D_ctrl_b_is_dst = D_op_addi|
    D_op_andhi|
    D_op_orhi|
    D_op_xorhi|
    D_op_andi|
    D_op_ori|
    D_op_xori|
    D_op_call|
    D_op_rdprs|
    D_op_cmpgei|
    D_op_cmplti|
    D_op_cmpnei|
    D_op_cmpgeui|
    D_op_cmpltui|
    D_op_cmpeqi|
    D_op_jmpi|
    D_op_rsv09|
    D_op_rsv17|
    D_op_rsv25|
    D_op_rsv33|
    D_op_rsv41|
    D_op_rsv49|
    D_op_rsv57|
    D_op_ldb|
    D_op_ldh|
    D_op_ldl|
    D_op_ldw|
    D_op_ldbio|
    D_op_ldhio|
    D_op_ldwio|
    D_op_rsv63|
    D_op_ldbu|
    D_op_ldhu|
    D_op_ldbuio|
    D_op_ldhuio|
    D_op_initd|
    D_op_initda|
    D_op_flushd|
    D_op_flushda;

  assign R_ctrl_b_is_dst_nxt = D_ctrl_b_is_dst;
  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          R_ctrl_b_is_dst <= 0;
      else if (R_en)
          R_ctrl_b_is_dst <= R_ctrl_b_is_dst_nxt;
    end


  assign D_ctrl_ignore_dst = D_op_br|
    D_op_bge|
    D_op_blt|
    D_op_bne|
    D_op_beq|
    D_op_bgeu|
    D_op_bltu|
    D_op_rsv62|
    D_op_stb|
    D_op_sth|
    D_op_stw|
    D_op_stc|
    D_op_stbio|
    D_op_sthio|
    D_op_stwio|
    D_op_rsv61|
    D_op_jmpi|
    D_op_rsv09|
    D_op_rsv17|
    D_op_rsv25|
    D_op_rsv33|
    D_op_rsv41|
    D_op_rsv49|
    D_op_rsv57;

  assign R_ctrl_ignore_dst_nxt = D_ctrl_ignore_dst;
  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          R_ctrl_ignore_dst <= 0;
      else if (R_en)
          R_ctrl_ignore_dst <= R_ctrl_ignore_dst_nxt;
    end


  assign D_ctrl_src2_choose_imm = D_op_addi|
    D_op_andhi|
    D_op_orhi|
    D_op_xorhi|
    D_op_andi|
    D_op_ori|
    D_op_xori|
    D_op_call|
    D_op_rdprs|
    D_op_cmpgei|
    D_op_cmplti|
    D_op_cmpnei|
    D_op_cmpgeui|
    D_op_cmpltui|
    D_op_cmpeqi|
    D_op_jmpi|
    D_op_rsv09|
    D_op_rsv17|
    D_op_rsv25|
    D_op_rsv33|
    D_op_rsv41|
    D_op_rsv49|
    D_op_rsv57|
    D_op_ldb|
    D_op_ldh|
    D_op_ldl|
    D_op_ldw|
    D_op_ldbio|
    D_op_ldhio|
    D_op_ldwio|
    D_op_rsv63|
    D_op_ldbu|
    D_op_ldhu|
    D_op_ldbuio|
    D_op_ldhuio|
    D_op_initd|
    D_op_initda|
    D_op_flushd|
    D_op_flushda|
    D_op_stb|
    D_op_sth|
    D_op_stw|
    D_op_stc|
    D_op_stbio|
    D_op_sthio|
    D_op_stwio|
    D_op_rsv61|
    D_op_roli|
    D_op_rsvx10|
    D_op_slli|
    D_op_srli|
    D_op_rsvx34|
    D_op_rsvx42|
    D_op_rsvx50|
    D_op_srai;

  assign R_ctrl_src2_choose_imm_nxt = D_ctrl_src2_choose_imm;
  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          R_ctrl_src2_choose_imm <= 0;
      else if (R_en)
          R_ctrl_src2_choose_imm <= R_ctrl_src2_choose_imm_nxt;
    end


  assign D_ctrl_wrctl_inst = D_op_wrctl;
  assign R_ctrl_wrctl_inst_nxt = D_ctrl_wrctl_inst;
  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          R_ctrl_wrctl_inst <= 0;
      else if (R_en)
          R_ctrl_wrctl_inst <= R_ctrl_wrctl_inst_nxt;
    end


  assign D_ctrl_rdctl_inst = D_op_rdctl;
  assign R_ctrl_rdctl_inst_nxt = D_ctrl_rdctl_inst;
  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          R_ctrl_rdctl_inst <= 0;
      else if (R_en)
          R_ctrl_rdctl_inst <= R_ctrl_rdctl_inst_nxt;
    end


  assign D_ctrl_force_src2_zero = D_op_call|
    D_op_rsv02|
    D_op_nextpc|
    D_op_callr|
    D_op_trap|
    D_op_rsvx44|
    D_op_intr|
    D_op_rsvx60|
    D_op_break|
    D_op_hbreak|
    D_op_eret|
    D_op_bret|
    D_op_rsvx17|
    D_op_rsvx25|
    D_op_ret|
    D_op_jmp|
    D_op_rsvx21|
    D_op_jmpi;

  assign R_ctrl_force_src2_zero_nxt = D_ctrl_force_src2_zero;
  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          R_ctrl_force_src2_zero <= 0;
      else if (R_en)
          R_ctrl_force_src2_zero <= R_ctrl_force_src2_zero_nxt;
    end


  assign D_ctrl_alu_force_xor = D_op_cmpgei|
    D_op_cmpgeui|
    D_op_cmpeqi|
    D_op_cmpge|
    D_op_cmpgeu|
    D_op_cmpeq|
    D_op_cmpnei|
    D_op_cmpne|
    D_op_bge|
    D_op_rsv10|
    D_op_bgeu|
    D_op_rsv42|
    D_op_beq|
    D_op_rsv34|
    D_op_bne|
    D_op_rsv62|
    D_op_br|
    D_op_rsv02;

  assign R_ctrl_alu_force_xor_nxt = D_ctrl_alu_force_xor;
  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
          R_ctrl_alu_force_xor <= 0;
      else if (R_en)
          R_ctrl_alu_force_xor <= R_ctrl_alu_force_xor_nxt;
    end


  //data_master, which is an e_avalon_master
  //instruction_master, which is an e_avalon_master

//synthesis translate_off
//////////////// SIMULATION-ONLY CONTENTS
  assign F_inst = (F_op_call)? 56'h20202063616c6c :
    (F_op_jmpi)? 56'h2020206a6d7069 :
    (F_op_ldbu)? 56'h2020206c646275 :
    (F_op_addi)? 56'h20202061646469 :
    (F_op_stb)? 56'h20202020737462 :
    (F_op_br)? 56'h20202020206272 :
    (F_op_ldb)? 56'h202020206c6462 :
    (F_op_cmpgei)? 56'h20636d70676569 :
    (F_op_ldhu)? 56'h2020206c646875 :
    (F_op_andi)? 56'h202020616e6469 :
    (F_op_sth)? 56'h20202020737468 :
    (F_op_bge)? 56'h20202020626765 :
    (F_op_ldh)? 56'h202020206c6468 :
    (F_op_cmplti)? 56'h20636d706c7469 :
    (F_op_initda)? 56'h20696e69746461 :
    (F_op_ori)? 56'h202020206f7269 :
    (F_op_stw)? 56'h20202020737477 :
    (F_op_blt)? 56'h20202020626c74 :
    (F_op_ldw)? 56'h202020206c6477 :
    (F_op_cmpnei)? 56'h20636d706e6569 :
    (F_op_flushda)? 56'h666c7573686461 :
    (F_op_xori)? 56'h202020786f7269 :
    (F_op_bne)? 56'h20202020626e65 :
    (F_op_cmpeqi)? 56'h20636d70657169 :
    (F_op_ldbuio)? 56'h206c646275696f :
    (F_op_muli)? 56'h2020206d756c69 :
    (F_op_stbio)? 56'h2020737462696f :
    (F_op_beq)? 56'h20202020626571 :
    (F_op_ldbio)? 56'h20206c6462696f :
    (F_op_cmpgeui)? 56'h636d7067657569 :
    (F_op_ldhuio)? 56'h206c646875696f :
    (F_op_andhi)? 56'h2020616e646869 :
    (F_op_sthio)? 56'h2020737468696f :
    (F_op_bgeu)? 56'h20202062676575 :
    (F_op_ldhio)? 56'h20206c6468696f :
    (F_op_cmpltui)? 56'h636d706c747569 :
    (F_op_initd)? 56'h2020696e697464 :
    (F_op_orhi)? 56'h2020206f726869 :
    (F_op_stwio)? 56'h2020737477696f :
    (F_op_bltu)? 56'h202020626c7475 :
    (F_op_ldwio)? 56'h20206c6477696f :
    (F_op_flushd)? 56'h20666c75736864 :
    (F_op_xorhi)? 56'h2020786f726869 :
    (F_op_eret)? 56'h20202065726574 :
    (F_op_roli)? 56'h202020726f6c69 :
    (F_op_rol)? 56'h20202020726f6c :
    (F_op_flushp)? 56'h20666c75736870 :
    (F_op_ret)? 56'h20202020726574 :
    (F_op_nor)? 56'h202020206e6f72 :
    (F_op_mulxuu)? 56'h206d756c787575 :
    (F_op_cmpge)? 56'h2020636d706765 :
    (F_op_bret)? 56'h20202062726574 :
    (F_op_ror)? 56'h20202020726f72 :
    (F_op_flushi)? 56'h20666c75736869 :
    (F_op_jmp)? 56'h202020206a6d70 :
    (F_op_and)? 56'h20202020616e64 :
    (F_op_cmplt)? 56'h2020636d706c74 :
    (F_op_slli)? 56'h202020736c6c69 :
    (F_op_sll)? 56'h20202020736c6c :
    (F_op_or)? 56'h20202020206f72 :
    (F_op_mulxsu)? 56'h206d756c787375 :
    (F_op_cmpne)? 56'h2020636d706e65 :
    (F_op_srli)? 56'h20202073726c69 :
    (F_op_srl)? 56'h2020202073726c :
    (F_op_nextpc)? 56'h206e6578747063 :
    (F_op_callr)? 56'h202063616c6c72 :
    (F_op_xor)? 56'h20202020786f72 :
    (F_op_mulxss)? 56'h206d756c787373 :
    (F_op_cmpeq)? 56'h2020636d706571 :
    (F_op_divu)? 56'h20202064697675 :
    (F_op_div)? 56'h20202020646976 :
    (F_op_rdctl)? 56'h2020726463746c :
    (F_op_mul)? 56'h202020206d756c :
    (F_op_cmpgeu)? 56'h20636d70676575 :
    (F_op_initi)? 56'h2020696e697469 :
    (F_op_trap)? 56'h20202074726170 :
    (F_op_wrctl)? 56'h2020777263746c :
    (F_op_cmpltu)? 56'h20636d706c7475 :
    (F_op_add)? 56'h20202020616464 :
    (F_op_break)? 56'h2020627265616b :
    (F_op_sync)? 56'h20202073796e63 :
    (F_op_sub)? 56'h20202020737562 :
    (F_op_srai)? 56'h20202073726169 :
    (F_op_sra)? 56'h20202020737261 :
    (F_op_intr)? 56'h202020696e7472 :
    56'h20202020424144;

  assign D_inst = (D_op_call)? 56'h20202063616c6c :
    (D_op_jmpi)? 56'h2020206a6d7069 :
    (D_op_ldbu)? 56'h2020206c646275 :
    (D_op_addi)? 56'h20202061646469 :
    (D_op_stb)? 56'h20202020737462 :
    (D_op_br)? 56'h20202020206272 :
    (D_op_ldb)? 56'h202020206c6462 :
    (D_op_cmpgei)? 56'h20636d70676569 :
    (D_op_ldhu)? 56'h2020206c646875 :
    (D_op_andi)? 56'h202020616e6469 :
    (D_op_sth)? 56'h20202020737468 :
    (D_op_bge)? 56'h20202020626765 :
    (D_op_ldh)? 56'h202020206c6468 :
    (D_op_cmplti)? 56'h20636d706c7469 :
    (D_op_initda)? 56'h20696e69746461 :
    (D_op_ori)? 56'h202020206f7269 :
    (D_op_stw)? 56'h20202020737477 :
    (D_op_blt)? 56'h20202020626c74 :
    (D_op_ldw)? 56'h202020206c6477 :
    (D_op_cmpnei)? 56'h20636d706e6569 :
    (D_op_flushda)? 56'h666c7573686461 :
    (D_op_xori)? 56'h202020786f7269 :
    (D_op_bne)? 56'h20202020626e65 :
    (D_op_cmpeqi)? 56'h20636d70657169 :
    (D_op_ldbuio)? 56'h206c646275696f :
    (D_op_muli)? 56'h2020206d756c69 :
    (D_op_stbio)? 56'h2020737462696f :
    (D_op_beq)? 56'h20202020626571 :
    (D_op_ldbio)? 56'h20206c6462696f :
    (D_op_cmpgeui)? 56'h636d7067657569 :
    (D_op_ldhuio)? 56'h206c646875696f :
    (D_op_andhi)? 56'h2020616e646869 :
    (D_op_sthio)? 56'h2020737468696f :
    (D_op_bgeu)? 56'h20202062676575 :
    (D_op_ldhio)? 56'h20206c6468696f :
    (D_op_cmpltui)? 56'h636d706c747569 :
    (D_op_initd)? 56'h2020696e697464 :
    (D_op_orhi)? 56'h2020206f726869 :
    (D_op_stwio)? 56'h2020737477696f :
    (D_op_bltu)? 56'h202020626c7475 :
    (D_op_ldwio)? 56'h20206c6477696f :
    (D_op_flushd)? 56'h20666c75736864 :
    (D_op_xorhi)? 56'h2020786f726869 :
    (D_op_eret)? 56'h20202065726574 :
    (D_op_roli)? 56'h202020726f6c69 :
    (D_op_rol)? 56'h20202020726f6c :
    (D_op_flushp)? 56'h20666c75736870 :
    (D_op_ret)? 56'h20202020726574 :
    (D_op_nor)? 56'h202020206e6f72 :
    (D_op_mulxuu)? 56'h206d756c787575 :
    (D_op_cmpge)? 56'h2020636d706765 :
    (D_op_bret)? 56'h20202062726574 :
    (D_op_ror)? 56'h20202020726f72 :
    (D_op_flushi)? 56'h20666c75736869 :
    (D_op_jmp)? 56'h202020206a6d70 :
    (D_op_and)? 56'h20202020616e64 :
    (D_op_cmplt)? 56'h2020636d706c74 :
    (D_op_slli)? 56'h202020736c6c69 :
    (D_op_sll)? 56'h20202020736c6c :
    (D_op_or)? 56'h20202020206f72 :
    (D_op_mulxsu)? 56'h206d756c787375 :
    (D_op_cmpne)? 56'h2020636d706e65 :
    (D_op_srli)? 56'h20202073726c69 :
    (D_op_srl)? 56'h2020202073726c :
    (D_op_nextpc)? 56'h206e6578747063 :
    (D_op_callr)? 56'h202063616c6c72 :
    (D_op_xor)? 56'h20202020786f72 :
    (D_op_mulxss)? 56'h206d756c787373 :
    (D_op_cmpeq)? 56'h2020636d706571 :
    (D_op_divu)? 56'h20202064697675 :
    (D_op_div)? 56'h20202020646976 :
    (D_op_rdctl)? 56'h2020726463746c :
    (D_op_mul)? 56'h202020206d756c :
    (D_op_cmpgeu)? 56'h20636d70676575 :
    (D_op_initi)? 56'h2020696e697469 :
    (D_op_trap)? 56'h20202074726170 :
    (D_op_wrctl)? 56'h2020777263746c :
    (D_op_cmpltu)? 56'h20636d706c7475 :
    (D_op_add)? 56'h20202020616464 :
    (D_op_break)? 56'h2020627265616b :
    (D_op_sync)? 56'h20202073796e63 :
    (D_op_sub)? 56'h20202020737562 :
    (D_op_srai)? 56'h20202073726169 :
    (D_op_sra)? 56'h20202020737261 :
    (D_op_intr)? 56'h202020696e7472 :
    56'h20202020424144;

  assign F_vinst = F_valid ? F_inst : {7{8'h2d}};
  assign D_vinst = D_valid ? D_inst : {7{8'h2d}};
  assign R_vinst = R_valid ? D_inst : {7{8'h2d}};
  assign E_vinst = E_valid ? D_inst : {7{8'h2d}};
  assign W_vinst = W_valid ? D_inst : {7{8'h2d}};

//////////////// END SIMULATION-ONLY CONTENTS

//synthesis translate_on

endmodule

