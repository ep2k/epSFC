// ==============================
//  SPC700 CPU Package
// ==============================

// Copyright(C) 2024 ep2k All Rights Reserved.

`ifndef S_CPU_PKG_SV
`define S_CPU_PKG_SV

package s_cpu_pkg;
    
    parameter N = 7, V = 6, P = 5, B = 4, H = 3, I = 2, Z = 1, C = 0;
    parameter AN = 4, AV = 3, AH = 2, AZ = 1, AC = 0;

    typedef enum logic [1:0] {
        SC_R_A,         // a
        SC_R_X,         // x
        SC_R_Y,         // y
        SC_R_SP         // sp
    } reg_src_type;

    typedef enum logic[3:0] {
        SC_MA_PC,       // pc
        SC_MA_DP,       // {00, addr[7:0]}
        SC_MA_DP_1,     // {00, addr[7:0] + 8'h1}
        SC_MA_DP2,      // {00, addr[15:8]}
        SC_MA_DT,       // {00, temp}
        SC_MA_DT_1,     // {00, temp + 8'h1}
        SC_MA_DR1,      // {00, reg1}
        SC_MA_DR2,      // {00, reg2}
        SC_MA_ABS,      // addr
        SC_MA_ABS_1,    // addr + 16'h1
        SC_MA_ABSMINI,  // {3'h0, addr[12:0]}
        SC_MA_SR2,      // {01, reg2}
        SC_MA_SR2_1,    // {01, reg2 + 8'h1}
        SC_MA_SR2_2,    // {01, reg2 + 8'h2}
        SC_MA_FFDE,     // 16'hffde - {3'h0, op[7:4], 1'b0}
        SC_MA_FFDF      // 16'hffdf - {3'h0, op[7:4], 1'b0}
    } mem_addr_src_type;

    typedef enum logic[3:0] {
        // SC_W_REG1,      // reg1
        // SC_W_REG1_XCN,  // {reg1[3:0], reg1[7:4]}
        // SC_W_REG2,      // reg2
        SC_W_PSW,       // psw
        SC_W_PCH,       // pc[15:8]
        SC_W_PCL,       // pc[7:0]
        // SC_W_TEMP,      // temp
        SC_W_ALUY,      // alu_y[7:0]
        SC_W_BITALUY,   // bitalu_y
        SC_W_DAASY,     // daas_y
        SC_W_RD         // rdata
    } wdata_src_type;

    typedef enum logic[3:0] {
        SC_PW_ALUF,     // alu_flgs
        SC_PW_ALUF2,    // alu_flgs2
        SC_PW_BITALUC,  // {7'h0, bitalu_c}
        SC_PW_DAASF,    // daas_flgs
        SC_PW_NOTC,     // {7'h0, ~psw[C]}
        SC_PW_BRK,      // brk_flgs
        SC_PW_FF,       // 8'hff
        SC_PW_0,        // 8'h0
        SC_PW_RD        // mem_rdata
    } psw_wdata_src_type;

    typedef enum logic[2:0] {
        SC_PCW_PC_1,    // pc+1
        SC_PCW_ALUY,    // alu_y
        SC_PCW_RD,      // {mem_rdata, mem_rdata}
        SC_PCW_RD_TEMP, // {mem_rdata, temp} 
        SC_PCW_FF_ADL   // {8'hff, addr[7:0]} 
    } pc_wdata_src_type;

    typedef enum logic {
        SC_AW_ALUY,     // alu_y
        SC_AW_RD        // {mem_rdata, mem_rdata}
    } addr_wdata_src_type;

    typedef enum logic[2:0] {
        SC_AA_REG1,     // {8'h0, reg1}
        SC_AA_REG1_XCN, // {8'h0, reg1[3:0], reg1[7:4]}
        SC_AA_REG2,     // {8'h0, reg2}
        SC_AA_PC,       // pc
        SC_AA_TEMP,     // {8'h0, temp}
        SC_AA_ADDR,     // addr
        SC_AA_RD        // {8'h0, mem_rdata}
    } alu_a_src_type;

    typedef enum logic[2:0] {
        SC_AB_0,        // 16'h0
        SC_AB_1,        // 16'h1
        SC_AB_2,        // 16'h2
        // SC_AB_REG1,     // {8'h0, reg1}
        SC_AB_REG2,     // {8'h0, reg2}
        SC_AB_TEMP,     // {{8{temp[7]}}, temp}
        SC_AB_RD        // {8'h0, mem_rdata}
    } alu_b_src_type;

    typedef enum logic {
        SC_AC_C,        // psw[C]
        SC_AC_C2        // c2
    } alu_c_src_type;

    typedef enum logic[3:0] {
        SC_ACTL_OR,
        SC_ACTL_AND,
        SC_ACTL_EOR,
        SC_ACTL_CLR,
        SC_ACTL_ADD,
        SC_ACTL_ADC,
        SC_ACTL_SUB,
        SC_ACTL_SBC,

        SC_ACTL_ASL,
        SC_ACTL_ROL,
        SC_ACTL_LSR,
        SC_ACTL_ROR
    } alu_control_type;

    typedef enum logic {
        SC_BAB_OP75,        // op[7:5]
        SC_BAB_ADDR1513     // addr[15:13]
    } bitalu_b_src_type;

    typedef enum logic[3:0] {
        SC_BACTL_AND1_C,
        SC_BACTL_AND1_N_C,
        SC_BACTL_OR1_C,
        SC_BACTL_OR1_N_C,
        SC_BACTL_EOR1_C,
        SC_BACTL_MOV1_C,
        SC_BACTL_SET1,
        SC_BACTL_CLR1,
        SC_BACTL_NOT1
    } bitalu_control_type;

    typedef enum logic {
        SC_DACTL_DAA,
        SC_DACTL_DAS
    } daas_control_type;

    typedef struct packed {

        mem_addr_src_type mem_addr_src;
        logic mem_read;
        logic mem_write;

        wdata_src_type wdata_src;
        logic reg1_write;
        logic reg2_write;
        logic op_write;
        logic temp_write;

        psw_wdata_src_type psw_wdata_src;
        logic [7:0] psw_write;

        pc_wdata_src_type pc_wdata_src;
        logic [1:0] pc_write;

        addr_wdata_src_type addr_wdata_src;
        logic [1:0] addr_write;

        alu_a_src_type alu_a_src;
        alu_b_src_type alu_b_src;
        alu_c_src_type alu_c_src;
        alu_control_type alu_control;
        logic alu_bit8;
        logic c2_write;

        bitalu_b_src_type bitalu_b_src;
        bitalu_control_type bitalu_control;

        daas_control_type daas_control;

        logic mul_init;
        logic mul;
        logic div_init;
        logic div;
        logic div_last;

    } ctl_signals_type;

    typedef enum logic[5:0] {

        // データ2つに対する命令(MOVと8bit演算)
        SA_REG_REG,
        SA_REG_IMM,
        SA_REG_DR, SA_REG_DRINC,
        SA_DR_REG, SA_DRINC_REG,
        SA_DR_DR,
        SA_REG_DP, SA_REG_DPR,
        SA_DP_REG, SA_DPR_REG,
        SA_REG_ABS, SA_REG_ABSR,
        SA_ABS_REG, SA_ABSR_REG,
        SA_REG_INDPR, SA_REG_INDP_R,
        SA_INDP_REG, SA_INDPR_REG, SA_INDP_R_REG,
        SA_DP_IMM,
        SA_DP_DP,
        SA_YA_DP16,
        SA_DP16_YA,

        // データ1つに対する命令(INCやシフト演算など)
        SA_REG,
        SA_DP, SA_DPR,
        SA_ABS,
        SA_DP16,

        // ジャンプ
        SA_JMP_IMM,
        SA_JMP_ABSR,

        // 分岐
        SA_BRA,
        SA_BBSC_DP,
        SA_CBNE_DP, SA_CBNE_DPR,
        SA_DBNZ_DP,
        SA_DBNZ_REG,

        // CALL
        SA_CALL_IMM,
        SA_CALL_UP,
        SA_CALL_N,

        // RET
        SA_RET,
        SA_RETI,
        
        // プッシュ，ポップ
        SA_PUSH_REG, SA_PUSH_PSW,
        SA_POP_REG, SA_POP_PSW,

        // 1bit演算
        SA_SC1_DP,
        SA_TSC_ABS,
        SA_CALC1_C_ABS,
        SA_CALC1_ABS_C,

        // ステータスフラグ
        SA_PSW_CHANGE,
        
        // その他
        SA_BRK,
        SA_XCN_REG,
        SA_MUL_YA,
        SA_DIV_YA_X,
        SA_DAAS,
        SA_NOP

    } addressing_type;

    typedef enum logic[6:0] { 
        SS_OPFETCH,                 // オペコードフェッチ
        SS_ADLFETCH,                // メモリ[PC++]をaddr[7:0]に格納
        SS_ADHFETCH,                // メモリ[PC++]をaddr[15:8]に格納
        SS_TEMPFETCH,               // メモリ[PC++]をtempに格納

        SS_READ_MEMDP,              // メモリ[{00/01, dp}]を読み込み(何もしない)

        SS_COPY_REG1_REG2,          // レジスタ2をレジスタ1に書き込み
        SS_COPY_REG1_MEMSR,         // メモリ[01, レジスタ2]をレジスタ1に書き込み
        SS_COPY_MEMDR_TEMP,         // メモリ[{00/01, レジスタ2}]にtempを書き込み
        SS_COPY_MEMSR_REG1,         // メモリ[{01, レジスタ2}]にレジスタ1を書き込み
        SS_COPY_MEMSRP2_PCH,        // メモリ[{01, レジスタ2+2}]にPC[15:8]を書き込み
        SS_COPY_MEMSRP1_PCL,        // メモリ[{01, レジスタ2+1}]にPC[7:0]を書き込み
        SS_COPY_MEMSR_PSW,          // メモリ[{01, レジスタ2}]にPSWを書き込み
        SS_COPY_MEMDP_TEMP,         // メモリ[{00/01, dp}]にtempを書き込み
        SS_COPY_MEMDP1_TEMP,        // メモリ[{00/01, dp+1}]にtempを書き込み
        SS_COPY_MEMDP_REG1,         // メモリ[{00/01, dp}]にレジスタ1を書き込み
        SS_COPY_MEMDP1_REG2,         // メモリ[{00/01, dp+1}]にレジスタ2を書き込み
        SS_COPY_MEMABS_TEMP,        // メモリ[abs]にtempを書き込み
        SS_COPY_MEMABSMINI_TEMP,    // メモリ[{3'h0, abs[12:0]}]にtempを書き込み
        SS_COPY_ADL_MEMDT,          // abs[7:0]にメモリ[{00/01, temp}]を書き込み
        SS_COPY_ADH_MEMDT1,         // abs[7:0]にメモリ[{00/01, temp+1}]を書き込み
        SS_COPY_ADL_MEMFFDE,        // メモリ[FFDE-{op[7:4],1'b0}]をabs[7:0]に格納
        SS_COPY_ADH_MEMFFDF,        // メモリ[FFDF-{op[7:4],1'b0}]をabs[15:8]に格納
        SS_COPY_PCL_MEMFFDE,        // メモリ[FFDE-{op[7:4],1'b0}]をpc[7:0]に格納
        SS_COPY_PCH_MEMFFDF,        // メモリ[FFDF-{op[7:4],1'b0}]をpc[15:8]に格納
        SS_COPY_TEMP_REG1,          // レジスタ1をtempに書き込み
        SS_COPY_TEMP_MEMDR1,        // メモリ[{00/01, レジスタ1}]を読み込みtempに書き込み
        SS_COPY_TEMP_MEMDP,         // メモリ[{00/01, dp}]をtempに書き込み
        SS_COPY_TEMP_MEMDP_M1,      // メモリ[{00/01, dp}]-1をtempに書き込み
        SS_COPY_TEMP_MEMDP2,        // メモリ[{00/01, dp2}]をtempに書き込み
        SS_COPY_TEMP_MEMABS,        // メモリ[abs]をtempに書き込み
        SS_COPY_PC_FETCH_TEMP,      // {メモリ[PC++], temp}をPCに書き込み
        SS_COPY_PC_MEMABS1_TEMP,    // {メモリ[abs+1], temp}をPCに書き込み
        SS_COPY_PC_ADDR,            // addrをPCに書き込み
        SS_COPY_PC_FF_ADL,          // {FF, addr[7:0]}をPCに書き込み
        SS_COPY_PCL_MEMSRP1,        // メモリ[{01, レジスタ2+1}]をPC[7:0]に書き込み
        SS_COPY_PCH_MEMSRP2,        // メモリ[{01, レジスタ2+2}]をPC[15:8]に書き込み
        SS_COPY_PSW_MEMSR,          // メモリ[{01, レジスタ2}]をPSWに書き込み

        SS_CALC_REG1_MEMPC,         // メモリ[PC++]を読みこみレジスタ1と演算，レジスタ1に書き込み
        SS_CALC_REG1_MEMDR,         // メモリ[{00/01, レジスタ2}]を読み込みレジスタ1と演算，レジスタ1に書き込み
        SS_CALC_REG1_MEMDP,         // メモリ[{00/01, dp}]を読み込みレジスタ1と演算，レジスタ1に書き込み
        SS_CALC_REG2_MEMDP1,        // メモリ[{00/01, dp+1}]を読み込みレジスタ2と演算，レジスタ2に書き込み
        SS_CALC_REG1_MEMABS,        // メモリ[abs]を読み込みレジスタ1と演算，レジスタ1に書き込み
        SS_CALC_TEMP_MEMDR,         // メモリ[{00/01, レジスタ2}]を読み込みtempと演算，tempに書き込み
        SS_CALC_TEMP_MEMDP,         // メモリ[{00/01, dp}]を読み込みtempと演算，tempに書き込み

        SS_CALC_REG1,               // レジスタ1に対して演算，レジスタ1に書き込み
        SS_CALC_MEMDP,              // メモリ[{00/01, dp}]に対して演算，tempに書き込み
        SS_CALC_MEMDP1,             // メモリ[{00/01, dp+1}]に対して演算，tempに書き込み
        SS_CALC_MEMABS,             // メモリ[abs]に対して演算，tempに書き込み

        SS_SC1_DP,                  // メモリ[{00/01, dp}]を読み込み，第op[7:4]bitを~op[3]にし，tempに書き込み
        SS_TSC_ABS_1,               // メモリ[abs]を読み込み，tempに書き込み，レジスタ1と演算(SUB)しフラグに書き込み
        SS_TSC_ABS_2,               // tempとレジスタ1で演算(OR/CLR)，tempに書き込み
        SS_CALC1_C_ABS,             // メモリ[{3'h0, abs[12:0]}]を読みこみabs[15:13]を使用して演算，P[C]に書き込み
        SS_CALC1_ABS_C,             // メモリ[{3'h0, abs[12:0]}]を読みこみabs[15:13]を使用して演算，tempに書き込み

        SS_ADD_ADDR_REG2,           // addrにレジスタ2を加算
        SS_ADD_TEMP_REG2,           // tempにレジスタ2を加算
        SS_ADD_PC_TEMP,             // PCにtemp(符号拡張)を加算
        // SS_SUB_TEMP_REG1,           // tempからレジスタ1を減算
        SS_SUB_REG1_TEMP,           // レジスタ1-tempを計算
        SS_XCN_REG1,                // {レジスタ1[3:0], レジスタ1[7:4]}をレジスタ1に書き込み

        SS_REG2_INC,                // reg2++
        SS_REG2_INC2,               // reg2 += 2
        SS_REG2_DEC,                // reg2--
        SS_REG2_DEC2,               // reg2 -= 2
        SS_PC_INC,                  // PC++
        SS_PC_INC_BRKSET,           // PC++, PSW[B]=1

        SS_PSW_CHANGE,              // 所定のフラグをセット/リセット

        SS_MUL_INIT,
        SS_MUL_6,
        SS_MUL_5,
        SS_MUL_4,
        SS_MUL_3,
        SS_MUL_2,
        SS_MUL_1,
        SS_MUL_0,

        // SS_DIV_HSET,                // レジスタ1-レジスタ2をし，hフラグセット S_DIV_HSET
        SS_DIV_INIT,
        SS_DIV_8,
        SS_DIV_7,
        SS_DIV_6,
        SS_DIV_5,
        SS_DIV_4,
        SS_DIV_3,
        SS_DIV_2,
        SS_DIV_1,
        SS_DIV_0,
        SS_DIV_LAST,

        SS_DAAS,                    // レジスタ1とPSWを受け取りレジスタ1とPSWを変更

        SS_NOP,                      // NOP
        SS_NOP1,                     // NOP
        SS_NOP2,                     // NOP

        SS_ERROR
    } state_type;

    typedef enum logic[6:0] {
        SI_MOV, SI_MOV_NF,
        SI_ADC, SI_ADD, SI_SBC, SI_SUB, SI_CMP,
        SI_AND, SI_OR, SI_EOR,
        SI_INC, SI_DEC,
        SI_ASL, SI_LSR, SI_ROL, SI_ROR, SI_XCN,
        SI_MUL, SI_DIV,
        SI_DAA, SI_DAS,
        SI_BRA, SI_BEQ, SI_BNE, SI_BCS, SI_BCC, SI_BVS, SI_BVC, SI_BMI, SI_BPL,
        SI_BBS, SI_BBC,
        SI_CBNE, SI_DBNZ,
        SI_JMP,
        SI_CALL, SI_PCALL, SI_TCALL,
        SI_BRK,
        SI_RET, SI_RETI,
        SI_PUSH, SI_POP,
        SI_SET1, SI_CLR1,
        SI_TSET, SI_TCLR,
        SI_AND1, SI_AND1_N, SI_OR1, SI_OR1_N,
        SI_EOR1, SI_NOT1, SI_MOV1,
        SI_CLRC, SI_SETC, SI_NOTC, SI_CLRV, SI_CLRP, SI_SETP, SI_EI, SI_DI,
        SI_NOP, SI_SLEEP, SI_STOP
    } instruction_type;

endpackage

`endif  // S_CPU_PKG_SV
