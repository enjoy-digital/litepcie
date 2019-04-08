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

module alt_xcvr_reconfig_cpu_reconfig_cpu_test_bench (
                                                       // inputs:
                                                        D_iw,
                                                        D_iw_op,
                                                        D_iw_opx,
                                                        D_valid,
                                                        E_valid,
                                                        F_pcb,
                                                        F_valid,
                                                        R_ctrl_ld,
                                                        R_ctrl_ld_non_io,
                                                        R_dst_regnum,
                                                        R_wr_dst_reg,
                                                        W_valid,
                                                        W_vinst,
                                                        W_wr_data,
                                                        av_ld_data_aligned_unfiltered,
                                                        clk,
                                                        d_address,
                                                        d_byteenable,
                                                        d_read,
                                                        d_write,
                                                        i_address,
                                                        i_read,
                                                        i_readdata,
                                                        i_waitrequest,
                                                        reset_n,

                                                       // outputs:
                                                        av_ld_data_aligned_filtered,
                                                        test_has_ended
                                                     )
;

  output  [ 31: 0] av_ld_data_aligned_filtered;
  output           test_has_ended;
  input   [ 31: 0] D_iw;
  input   [  5: 0] D_iw_op;
  input   [  5: 0] D_iw_opx;
  input            D_valid;
  input            E_valid;
  input   [ 11: 0] F_pcb;
  input            F_valid;
  input            R_ctrl_ld;
  input            R_ctrl_ld_non_io;
  input   [  4: 0] R_dst_regnum;
  input            R_wr_dst_reg;
  input            W_valid;
  input   [ 55: 0] W_vinst;
  input   [ 31: 0] W_wr_data;
  input   [ 31: 0] av_ld_data_aligned_unfiltered;
  input            clk;
  input   [ 13: 0] d_address;
  input   [  3: 0] d_byteenable;
  input            d_read;
  input            d_write;
  input   [ 11: 0] i_address;
  input            i_read;
  input   [ 31: 0] i_readdata;
  input            i_waitrequest;
  input            reset_n;


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
wire    [ 31: 0] av_ld_data_aligned_filtered;
wire             av_ld_data_aligned_unfiltered_0_is_x;
wire             av_ld_data_aligned_unfiltered_10_is_x;
wire             av_ld_data_aligned_unfiltered_11_is_x;
wire             av_ld_data_aligned_unfiltered_12_is_x;
wire             av_ld_data_aligned_unfiltered_13_is_x;
wire             av_ld_data_aligned_unfiltered_14_is_x;
wire             av_ld_data_aligned_unfiltered_15_is_x;
wire             av_ld_data_aligned_unfiltered_16_is_x;
wire             av_ld_data_aligned_unfiltered_17_is_x;
wire             av_ld_data_aligned_unfiltered_18_is_x;
wire             av_ld_data_aligned_unfiltered_19_is_x;
wire             av_ld_data_aligned_unfiltered_1_is_x;
wire             av_ld_data_aligned_unfiltered_20_is_x;
wire             av_ld_data_aligned_unfiltered_21_is_x;
wire             av_ld_data_aligned_unfiltered_22_is_x;
wire             av_ld_data_aligned_unfiltered_23_is_x;
wire             av_ld_data_aligned_unfiltered_24_is_x;
wire             av_ld_data_aligned_unfiltered_25_is_x;
wire             av_ld_data_aligned_unfiltered_26_is_x;
wire             av_ld_data_aligned_unfiltered_27_is_x;
wire             av_ld_data_aligned_unfiltered_28_is_x;
wire             av_ld_data_aligned_unfiltered_29_is_x;
wire             av_ld_data_aligned_unfiltered_2_is_x;
wire             av_ld_data_aligned_unfiltered_30_is_x;
wire             av_ld_data_aligned_unfiltered_31_is_x;
wire             av_ld_data_aligned_unfiltered_3_is_x;
wire             av_ld_data_aligned_unfiltered_4_is_x;
wire             av_ld_data_aligned_unfiltered_5_is_x;
wire             av_ld_data_aligned_unfiltered_6_is_x;
wire             av_ld_data_aligned_unfiltered_7_is_x;
wire             av_ld_data_aligned_unfiltered_8_is_x;
wire             av_ld_data_aligned_unfiltered_9_is_x;
wire             test_has_ended;
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
  assign test_has_ended = 1'b0;

//synthesis translate_off
//////////////// SIMULATION-ONLY CONTENTS
  //Clearing 'X' data bits
  assign av_ld_data_aligned_unfiltered_0_is_x = ^(av_ld_data_aligned_unfiltered[0]) === 1'bx;

  assign av_ld_data_aligned_filtered[0] = (av_ld_data_aligned_unfiltered_0_is_x & (R_ctrl_ld_non_io)) ? 1'b0 : av_ld_data_aligned_unfiltered[0];
  assign av_ld_data_aligned_unfiltered_1_is_x = ^(av_ld_data_aligned_unfiltered[1]) === 1'bx;
  assign av_ld_data_aligned_filtered[1] = (av_ld_data_aligned_unfiltered_1_is_x & (R_ctrl_ld_non_io)) ? 1'b0 : av_ld_data_aligned_unfiltered[1];
  assign av_ld_data_aligned_unfiltered_2_is_x = ^(av_ld_data_aligned_unfiltered[2]) === 1'bx;
  assign av_ld_data_aligned_filtered[2] = (av_ld_data_aligned_unfiltered_2_is_x & (R_ctrl_ld_non_io)) ? 1'b0 : av_ld_data_aligned_unfiltered[2];
  assign av_ld_data_aligned_unfiltered_3_is_x = ^(av_ld_data_aligned_unfiltered[3]) === 1'bx;
  assign av_ld_data_aligned_filtered[3] = (av_ld_data_aligned_unfiltered_3_is_x & (R_ctrl_ld_non_io)) ? 1'b0 : av_ld_data_aligned_unfiltered[3];
  assign av_ld_data_aligned_unfiltered_4_is_x = ^(av_ld_data_aligned_unfiltered[4]) === 1'bx;
  assign av_ld_data_aligned_filtered[4] = (av_ld_data_aligned_unfiltered_4_is_x & (R_ctrl_ld_non_io)) ? 1'b0 : av_ld_data_aligned_unfiltered[4];
  assign av_ld_data_aligned_unfiltered_5_is_x = ^(av_ld_data_aligned_unfiltered[5]) === 1'bx;
  assign av_ld_data_aligned_filtered[5] = (av_ld_data_aligned_unfiltered_5_is_x & (R_ctrl_ld_non_io)) ? 1'b0 : av_ld_data_aligned_unfiltered[5];
  assign av_ld_data_aligned_unfiltered_6_is_x = ^(av_ld_data_aligned_unfiltered[6]) === 1'bx;
  assign av_ld_data_aligned_filtered[6] = (av_ld_data_aligned_unfiltered_6_is_x & (R_ctrl_ld_non_io)) ? 1'b0 : av_ld_data_aligned_unfiltered[6];
  assign av_ld_data_aligned_unfiltered_7_is_x = ^(av_ld_data_aligned_unfiltered[7]) === 1'bx;
  assign av_ld_data_aligned_filtered[7] = (av_ld_data_aligned_unfiltered_7_is_x & (R_ctrl_ld_non_io)) ? 1'b0 : av_ld_data_aligned_unfiltered[7];
  assign av_ld_data_aligned_unfiltered_8_is_x = ^(av_ld_data_aligned_unfiltered[8]) === 1'bx;
  assign av_ld_data_aligned_filtered[8] = (av_ld_data_aligned_unfiltered_8_is_x & (R_ctrl_ld_non_io)) ? 1'b0 : av_ld_data_aligned_unfiltered[8];
  assign av_ld_data_aligned_unfiltered_9_is_x = ^(av_ld_data_aligned_unfiltered[9]) === 1'bx;
  assign av_ld_data_aligned_filtered[9] = (av_ld_data_aligned_unfiltered_9_is_x & (R_ctrl_ld_non_io)) ? 1'b0 : av_ld_data_aligned_unfiltered[9];
  assign av_ld_data_aligned_unfiltered_10_is_x = ^(av_ld_data_aligned_unfiltered[10]) === 1'bx;
  assign av_ld_data_aligned_filtered[10] = (av_ld_data_aligned_unfiltered_10_is_x & (R_ctrl_ld_non_io)) ? 1'b0 : av_ld_data_aligned_unfiltered[10];
  assign av_ld_data_aligned_unfiltered_11_is_x = ^(av_ld_data_aligned_unfiltered[11]) === 1'bx;
  assign av_ld_data_aligned_filtered[11] = (av_ld_data_aligned_unfiltered_11_is_x & (R_ctrl_ld_non_io)) ? 1'b0 : av_ld_data_aligned_unfiltered[11];
  assign av_ld_data_aligned_unfiltered_12_is_x = ^(av_ld_data_aligned_unfiltered[12]) === 1'bx;
  assign av_ld_data_aligned_filtered[12] = (av_ld_data_aligned_unfiltered_12_is_x & (R_ctrl_ld_non_io)) ? 1'b0 : av_ld_data_aligned_unfiltered[12];
  assign av_ld_data_aligned_unfiltered_13_is_x = ^(av_ld_data_aligned_unfiltered[13]) === 1'bx;
  assign av_ld_data_aligned_filtered[13] = (av_ld_data_aligned_unfiltered_13_is_x & (R_ctrl_ld_non_io)) ? 1'b0 : av_ld_data_aligned_unfiltered[13];
  assign av_ld_data_aligned_unfiltered_14_is_x = ^(av_ld_data_aligned_unfiltered[14]) === 1'bx;
  assign av_ld_data_aligned_filtered[14] = (av_ld_data_aligned_unfiltered_14_is_x & (R_ctrl_ld_non_io)) ? 1'b0 : av_ld_data_aligned_unfiltered[14];
  assign av_ld_data_aligned_unfiltered_15_is_x = ^(av_ld_data_aligned_unfiltered[15]) === 1'bx;
  assign av_ld_data_aligned_filtered[15] = (av_ld_data_aligned_unfiltered_15_is_x & (R_ctrl_ld_non_io)) ? 1'b0 : av_ld_data_aligned_unfiltered[15];
  assign av_ld_data_aligned_unfiltered_16_is_x = ^(av_ld_data_aligned_unfiltered[16]) === 1'bx;
  assign av_ld_data_aligned_filtered[16] = (av_ld_data_aligned_unfiltered_16_is_x & (R_ctrl_ld_non_io)) ? 1'b0 : av_ld_data_aligned_unfiltered[16];
  assign av_ld_data_aligned_unfiltered_17_is_x = ^(av_ld_data_aligned_unfiltered[17]) === 1'bx;
  assign av_ld_data_aligned_filtered[17] = (av_ld_data_aligned_unfiltered_17_is_x & (R_ctrl_ld_non_io)) ? 1'b0 : av_ld_data_aligned_unfiltered[17];
  assign av_ld_data_aligned_unfiltered_18_is_x = ^(av_ld_data_aligned_unfiltered[18]) === 1'bx;
  assign av_ld_data_aligned_filtered[18] = (av_ld_data_aligned_unfiltered_18_is_x & (R_ctrl_ld_non_io)) ? 1'b0 : av_ld_data_aligned_unfiltered[18];
  assign av_ld_data_aligned_unfiltered_19_is_x = ^(av_ld_data_aligned_unfiltered[19]) === 1'bx;
  assign av_ld_data_aligned_filtered[19] = (av_ld_data_aligned_unfiltered_19_is_x & (R_ctrl_ld_non_io)) ? 1'b0 : av_ld_data_aligned_unfiltered[19];
  assign av_ld_data_aligned_unfiltered_20_is_x = ^(av_ld_data_aligned_unfiltered[20]) === 1'bx;
  assign av_ld_data_aligned_filtered[20] = (av_ld_data_aligned_unfiltered_20_is_x & (R_ctrl_ld_non_io)) ? 1'b0 : av_ld_data_aligned_unfiltered[20];
  assign av_ld_data_aligned_unfiltered_21_is_x = ^(av_ld_data_aligned_unfiltered[21]) === 1'bx;
  assign av_ld_data_aligned_filtered[21] = (av_ld_data_aligned_unfiltered_21_is_x & (R_ctrl_ld_non_io)) ? 1'b0 : av_ld_data_aligned_unfiltered[21];
  assign av_ld_data_aligned_unfiltered_22_is_x = ^(av_ld_data_aligned_unfiltered[22]) === 1'bx;
  assign av_ld_data_aligned_filtered[22] = (av_ld_data_aligned_unfiltered_22_is_x & (R_ctrl_ld_non_io)) ? 1'b0 : av_ld_data_aligned_unfiltered[22];
  assign av_ld_data_aligned_unfiltered_23_is_x = ^(av_ld_data_aligned_unfiltered[23]) === 1'bx;
  assign av_ld_data_aligned_filtered[23] = (av_ld_data_aligned_unfiltered_23_is_x & (R_ctrl_ld_non_io)) ? 1'b0 : av_ld_data_aligned_unfiltered[23];
  assign av_ld_data_aligned_unfiltered_24_is_x = ^(av_ld_data_aligned_unfiltered[24]) === 1'bx;
  assign av_ld_data_aligned_filtered[24] = (av_ld_data_aligned_unfiltered_24_is_x & (R_ctrl_ld_non_io)) ? 1'b0 : av_ld_data_aligned_unfiltered[24];
  assign av_ld_data_aligned_unfiltered_25_is_x = ^(av_ld_data_aligned_unfiltered[25]) === 1'bx;
  assign av_ld_data_aligned_filtered[25] = (av_ld_data_aligned_unfiltered_25_is_x & (R_ctrl_ld_non_io)) ? 1'b0 : av_ld_data_aligned_unfiltered[25];
  assign av_ld_data_aligned_unfiltered_26_is_x = ^(av_ld_data_aligned_unfiltered[26]) === 1'bx;
  assign av_ld_data_aligned_filtered[26] = (av_ld_data_aligned_unfiltered_26_is_x & (R_ctrl_ld_non_io)) ? 1'b0 : av_ld_data_aligned_unfiltered[26];
  assign av_ld_data_aligned_unfiltered_27_is_x = ^(av_ld_data_aligned_unfiltered[27]) === 1'bx;
  assign av_ld_data_aligned_filtered[27] = (av_ld_data_aligned_unfiltered_27_is_x & (R_ctrl_ld_non_io)) ? 1'b0 : av_ld_data_aligned_unfiltered[27];
  assign av_ld_data_aligned_unfiltered_28_is_x = ^(av_ld_data_aligned_unfiltered[28]) === 1'bx;
  assign av_ld_data_aligned_filtered[28] = (av_ld_data_aligned_unfiltered_28_is_x & (R_ctrl_ld_non_io)) ? 1'b0 : av_ld_data_aligned_unfiltered[28];
  assign av_ld_data_aligned_unfiltered_29_is_x = ^(av_ld_data_aligned_unfiltered[29]) === 1'bx;
  assign av_ld_data_aligned_filtered[29] = (av_ld_data_aligned_unfiltered_29_is_x & (R_ctrl_ld_non_io)) ? 1'b0 : av_ld_data_aligned_unfiltered[29];
  assign av_ld_data_aligned_unfiltered_30_is_x = ^(av_ld_data_aligned_unfiltered[30]) === 1'bx;
  assign av_ld_data_aligned_filtered[30] = (av_ld_data_aligned_unfiltered_30_is_x & (R_ctrl_ld_non_io)) ? 1'b0 : av_ld_data_aligned_unfiltered[30];
  assign av_ld_data_aligned_unfiltered_31_is_x = ^(av_ld_data_aligned_unfiltered[31]) === 1'bx;
  assign av_ld_data_aligned_filtered[31] = (av_ld_data_aligned_unfiltered_31_is_x & (R_ctrl_ld_non_io)) ? 1'b0 : av_ld_data_aligned_unfiltered[31];
  always @(posedge clk)
    begin
      if (reset_n)
          if (^(F_valid) === 1'bx)
            begin
              $write("%0d ns: ERROR: alt_xcvr_reconfig_cpu_reconfig_cpu_test_bench/F_valid is 'x'\n", $time);
              $stop;
            end
    end


  always @(posedge clk)
    begin
      if (reset_n)
          if (^(D_valid) === 1'bx)
            begin
              $write("%0d ns: ERROR: alt_xcvr_reconfig_cpu_reconfig_cpu_test_bench/D_valid is 'x'\n", $time);
              $stop;
            end
    end


  always @(posedge clk)
    begin
      if (reset_n)
          if (^(E_valid) === 1'bx)
            begin
              $write("%0d ns: ERROR: alt_xcvr_reconfig_cpu_reconfig_cpu_test_bench/E_valid is 'x'\n", $time);
              $stop;
            end
    end


  always @(posedge clk)
    begin
      if (reset_n)
          if (^(W_valid) === 1'bx)
            begin
              $write("%0d ns: ERROR: alt_xcvr_reconfig_cpu_reconfig_cpu_test_bench/W_valid is 'x'\n", $time);
              $stop;
            end
    end


  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
        begin
        end
      else if (W_valid)
          if (^(R_wr_dst_reg) === 1'bx)
            begin
              $write("%0d ns: ERROR: alt_xcvr_reconfig_cpu_reconfig_cpu_test_bench/R_wr_dst_reg is 'x'\n", $time);
              $stop;
            end
    end


  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
        begin
        end
      else if (W_valid & R_wr_dst_reg)
          if (^(W_wr_data) === 1'bx)
            begin
              $write("%0d ns: ERROR: alt_xcvr_reconfig_cpu_reconfig_cpu_test_bench/W_wr_data is 'x'\n", $time);
              $stop;
            end
    end


  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
        begin
        end
      else if (W_valid & R_wr_dst_reg)
          if (^(R_dst_regnum) === 1'bx)
            begin
              $write("%0d ns: ERROR: alt_xcvr_reconfig_cpu_reconfig_cpu_test_bench/R_dst_regnum is 'x'\n", $time);
              $stop;
            end
    end


  always @(posedge clk)
    begin
      if (reset_n)
          if (^(d_write) === 1'bx)
            begin
              $write("%0d ns: ERROR: alt_xcvr_reconfig_cpu_reconfig_cpu_test_bench/d_write is 'x'\n", $time);
              $stop;
            end
    end


  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
        begin
        end
      else if (d_write)
          if (^(d_byteenable) === 1'bx)
            begin
              $write("%0d ns: ERROR: alt_xcvr_reconfig_cpu_reconfig_cpu_test_bench/d_byteenable is 'x'\n", $time);
              $stop;
            end
    end


  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
        begin
        end
      else if (d_write | d_read)
          if (^(d_address) === 1'bx)
            begin
              $write("%0d ns: ERROR: alt_xcvr_reconfig_cpu_reconfig_cpu_test_bench/d_address is 'x'\n", $time);
              $stop;
            end
    end


  always @(posedge clk)
    begin
      if (reset_n)
          if (^(d_read) === 1'bx)
            begin
              $write("%0d ns: ERROR: alt_xcvr_reconfig_cpu_reconfig_cpu_test_bench/d_read is 'x'\n", $time);
              $stop;
            end
    end


  always @(posedge clk)
    begin
      if (reset_n)
          if (^(i_read) === 1'bx)
            begin
              $write("%0d ns: ERROR: alt_xcvr_reconfig_cpu_reconfig_cpu_test_bench/i_read is 'x'\n", $time);
              $stop;
            end
    end


  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
        begin
        end
      else if (i_read)
          if (^(i_address) === 1'bx)
            begin
              $write("%0d ns: ERROR: alt_xcvr_reconfig_cpu_reconfig_cpu_test_bench/i_address is 'x'\n", $time);
              $stop;
            end
    end


  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
        begin
        end
      else if (i_read & ~i_waitrequest)
          if (^(i_readdata) === 1'bx)
            begin
              $write("%0d ns: ERROR: alt_xcvr_reconfig_cpu_reconfig_cpu_test_bench/i_readdata is 'x'\n", $time);
              $stop;
            end
    end


  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
        begin
        end
      else if (W_valid & R_ctrl_ld)
          if (^(av_ld_data_aligned_unfiltered) === 1'bx)
            begin
              $write("%0d ns: WARNING: alt_xcvr_reconfig_cpu_reconfig_cpu_test_bench/av_ld_data_aligned_unfiltered is 'x'\n", $time);
            end
    end


  always @(posedge clk or negedge reset_n)
    begin
      if (reset_n == 0)
        begin
        end
      else if (W_valid & R_wr_dst_reg)
          if (^(W_wr_data) === 1'bx)
            begin
              $write("%0d ns: WARNING: alt_xcvr_reconfig_cpu_reconfig_cpu_test_bench/W_wr_data is 'x'\n", $time);
            end
    end



//////////////// END SIMULATION-ONLY CONTENTS

//synthesis translate_on
//synthesis read_comments_as_HDL on
//  
//  assign av_ld_data_aligned_filtered = av_ld_data_aligned_unfiltered;
//
//synthesis read_comments_as_HDL off

endmodule

