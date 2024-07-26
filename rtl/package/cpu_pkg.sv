// ==============================
//  65816 CPU Package
// ==============================

// Copyright(C) 2024 ep2k All Rights Reserved.

`ifndef CPU_PKG_SV
`define CPU_PKG_SV

package cpu_pkg;
    
    parameter N = 7, V = 6, M = 5, X = 4, D = 3, I = 2, Z = 1, C = 0;
    parameter BRK = 4;
    parameter AN = 3, AV = 2, AZ = 1, AC = 0;

    parameter B = 2, H = 1, L = 0;

    typedef enum logic[3:0] {
        C_MA_PC,        // {pbr, pc}
        C_MA_PC_1,      // {pbr, pc+1}
        C_MA_ADDR,      // addr
        C_MA_ADDR_1,    // addr+1
        C_MA_ADDR2,     // addr2
        C_MA_SP,        // {0, sp}
        C_MA_SP_1,      // {0, sp+1}
        C_MA_X,         // {dbr, X}
        C_MA_Y,         // {dbr, Y}
        C_MA_VA,        // vector_addr
        C_MA_VA_1       // vector_addr + 1
    } mem_addr_src_type;

    typedef enum logic[4:0] {
        C_MW_AL,        // a[7:0]
        C_MW_AH,        // a[15:8]
        C_MW_XL,        // x[7:0]
        C_MW_XH,        // x[15:8]
        C_MW_YL,        // y[7:0]
        C_MW_YH,        // y[15:8]
        C_MW_DPL,       // dp[7:0]
        C_MW_DPH,       // dp[15:8]
        C_MW_PBR,       // pbr
        C_MW_DBR,       // dbr
        C_MW_P,         // p
        C_MW_PCL,       // pc[7:0]
        C_MW_PCH,       // pc[15:8]
        C_MW_ADDRL,     // addr[7:0]
        C_MW_ADDRH,     // addr[15:8]
        C_MW_ADDR2L,    // addr2[7:0]
        C_MW_ADDR2H,    // addr2[15:8]
        C_MW_0          // 0
    } mem_wdata_src_type;

    typedef enum logic[1:0] {
        C_RW_ALUY,      // alu_y
        C_RW_ALUYL,     // {alu_y[7:0], alu_y[7:0]}
        C_RW_RD,        // {mem_rdata, mem_rdata}
        // C_RW_AH,        // {8'h0, a[15:8]}
        C_RW_ADDRB      // {8'h0, addr[23:16]}
        // C_RW_A,         // a
        // C_RW_X,         // x
        // C_RW_Y,         // y
        // C_RW_ADDRL_H,   // {addr[7:0], 8'h0}
        // C_RW_ADDR,      // addr[15:0]
    } reg_wdata_src_type;

    typedef enum logic[1:0] {
        C_PW_CTL,       // p_wdata_ctl
        C_PW_ALUYL,     // alu_y[7:0]
        C_PW_RWL        // reg_wdata[7:0]
    } p_wdata_src_type;

    typedef enum logic[1:0] {
        C_PCW_PC_1,     // pc+1
        C_PCW_ALUY,     // alu_y
        C_PCW_ADDR,     // addr[15:0]
        C_PCW_RD        // {mem_rdata, mem_rdata}
    } pc_wdata_src_type;

    typedef enum logic[3:0] {
        C_AW_ALUY,      // {8'h0, alu_y}
        C_AW_ALUYL,     // {alu_y[7:0], alu_y[7:0], alu_y[7:0]}
        C_AW_DBR,       // {dbr, 16'h0}
        C_AW_PBR,       // {pbr, 16'h0}
        C_AW_PC_1,      // {pbr, pc+1}
        C_AW_DP,        // {8'h0, dp}
        C_AW_A,         // {8'h0, a}
        C_AW_RD,        // {mem_rdata, mem_rdata, mem_rdata}
        C_AW_0          // 24'h0
        // C_AW_RD_ALUY,   // {8'h0, mem_rdata, alu_y[7:0]}
    } addr_wdata_src_type; // addr2_wdata_srcも兼用

    typedef enum logic[3:0] {
        C_AA_A,         // a
        C_AA_AH,        // {8'h0, a[15:8]}
        C_AA_X,         // x
        C_AA_XH,        // {8'h0, x[15:8]}
        C_AA_Y,         // y
        C_AA_YH,        // {8'h0, y[15:8]}
        C_AA_SP,        // sp
        C_AA_DP,        // dp
        C_AA_DPL,       // {8'h0, dp[7:0]}
        C_AA_P,         // {8'h0, p}
        C_AA_PC,        // pc
        C_AA_ADDR,      // addr[15:0]
        C_AA_ADDR2,     // addr2[15:0]
        C_AA_0          // 16'h0
        // C_AA_RD_H,      // {mem_rdata, 8'h0}
        // C_AA_RD_L       // {8'h0, mem_rdata}
    } alu_a_src_type;

    typedef enum logic[3:0] {
        C_AB_0,             // 16'h0
        C_AB_1,             // 16'h1
        C_AB_2,             // 16'h2
        // C_AB_3,             // 16'h3
        C_AB_A,             // a
        C_AB_ADDR,          // addr[15:0]
        C_AB_ADDRL_SIGNED,  // {{8{addr[7]}}, addr[7:0]} (符号拡張)
        C_AB_ADDRH,         // {8'h0, addr[15:8]}
        C_AB_ADDR2,         // addr2[15:0]
        C_AB_RD             // {8'h0, mem_rdata}
        // C_AB_FFFF,          // 16'hffff
        // C_AB_PC,            // pc
    } alu_b_src_type;

    typedef enum logic {
        C_AC_C,         // p[C]
        C_AC_CARRY      // carry
    } alu_c_src_type;

    typedef enum logic[3:0] {
        C_ACTL_OR,
        C_ACTL_AND,
        C_ACTL_EOR,
        C_ACTL_BIT,
        C_ACTL_ADD,
        C_ACTL_ADC,
        C_ACTL_SUB,
        C_ACTL_SBC,

        C_ACTL_TSB,
        C_ACTL_TRB,

        C_ACTL_ASL,
        C_ACTL_ROL,
        C_ACTL_LSR,
        C_ACTL_ROR
    } alu_control_type;

    typedef struct packed {

        mem_addr_src_type mem_addr_src;
        mem_wdata_src_type mem_wdata_src;
        logic mem_read;
        logic mem_write;
        
        reg_wdata_src_type reg_wdata_src;
        logic [1:0] a_write;
        logic [1:0] x_write;
        logic [1:0] y_write;
        logic [1:0] sp_write;
        logic [1:0] dp_write;
        logic pbr_write;
        logic dbr_write;
        logic sp_inc;

        p_wdata_src_type p_wdata_src;
        logic [7:0] p_wdata_ctl;
        logic [7:0] p_write;
        logic xce;

        pc_wdata_src_type pc_wdata_src;
        logic [1:0] pc_write;

        addr_wdata_src_type addr_wdata_src;
        addr_wdata_src_type addr2_wdata_src;
        logic [2:0] addr_write;
        logic [2:0] addr2_write;
        logic addr_inc, addr_bank_inc;
        logic addr2_inc, addr2_page_wrap, addr2_bank_inc;

        alu_a_src_type alu_a_src;
        alu_b_src_type alu_b_src;
        alu_c_src_type alu_c_src;
        alu_control_type alu_control;
        logic alu_bit8;
        logic alu_bcd;

    }  ctl_signals_type;

    typedef enum logic[5:0] {
        A_IMP,
        A_IMM, A_IMM_JMP,
        A_ABS, A_ABS_JMP,
        A_ABSX, A_ABSY, A_ABSX_JMP,
        A_ABSL,
        A_ABSLX,
        A_ABSL_JMP,
        A_DP,
        A_DPX, A_DPY,
        A_INDP,
        A_INDPX,
        A_INDPY,
        A_INDPL,
        A_INDPLY,
        A_SPR,
        A_INSPRY,
        A_PUSH_A, A_PUSH_X, A_PUSH_Y, A_PUSH_P, A_PUSH_DP, A_PUSH_PB, A_PUSH_DB,
        A_PULL_A, A_PULL_X, A_PULL_Y, A_PULL_P, A_PULL_DP, A_PULL_PB, A_PULL_DB,
        A_RTI, A_RTL, A_RTS,
        A_SUB_IMM, A_SUB_IMML,
        A_SUB_ABSX,
        A_PEA,
        A_PEI,
        A_PER,
        A_SOFT_INT, A_HARD_INT,
        A_WAIT,
        A_MVN, A_MVP
    } addressing_type;

    typedef enum logic[5:0] { 
        S_FETCH_OPCODE,
        S_FETCH_OPRAND_L, S_FETCH_OPRAND_H, S_FETCH_OPRAND_B,
        S_READ_ADDR2_L, S_READ_ADDR2_H, S_READ_ADDR2_B,
        S_ADD_ADDR_X, S_ADD_ADDR_Y, S_ADD_ADDR2_X,
        S_ADD_ADDRB_CARRY,
        // S_ADD_ADDRH_XH, S_ADD_ADDRH_YH,
        // S_ADD_ADDRH_CARRY,
        S_ADD_ADDR_DPL, S_ADD_ADDR2_DPL,
        S_ADD_ADDR_PC,
        S_ADD_ADDR_SP, S_ADD_ADDR2_SP,
        S_PUSH_B, S_PUSH_H, S_PUSH_L, S_PUSH_P,
        S_PULL_P, S_PULL_L, S_PULL_H, S_PULL_B,
        S_COPY_PC_ADDR,
        S_PC_INC, S_PC_DEC,
        S_FETCH_BANK_1, S_FETCH_BANK_2,
        S_MV_READ,
        S_MV_WRITE,
        S_DEC_A,
        S_MV_LOOP,

        S_OP_CALC,

        S_ERROR
    } state_type;

    typedef enum logic[6:0] {
        I_LDA, I_LDX, I_LDY,
        I_STA, I_STX, I_STY, I_STZ,
        I_ADC, I_SBC, I_AND, I_EOR, I_ORA, I_BIT,
        I_REP, I_SEP,
        I_CMP, I_CPX, I_CPY,
        I_INC_A, I_DEC_A, I_ASL_A, I_LSR_A, I_ROL_A, I_ROR_A,
        I_INX, I_INY, I_DEX, I_DEY,
        I_INC, I_DEC, I_ASL, I_LSR, I_ROL, I_ROR, I_TRB, I_TSB,
        I_BCC, I_BCS, I_BEQ, I_BMI, I_BNE, I_BPL, I_BRA, I_BVC, I_BVS, I_BRL,
        I_JMP, I_JMPL, I_JSR,
        I_CLC, I_CLD, I_CLI, I_CLV, I_SEC, I_SED, I_SEI,
        I_TXA, I_TYA, I_TAX, I_TAY, I_TYX, I_TXY, I_TDC, I_TCD,
        I_TSC, I_TSX, I_TCS, I_TXS,
        I_PHA, I_PLA,
        I_PEA, I_PEI, I_PER,
        I_RTI, I_RTL, I_RTS,
        I_XBA, I_XCE,
        I_MVP, I_MVN,

        I_BRK, I_COP,

        I_NOP, I_WDM, I_WAI, I_STP,

        I_HARD_INT
    } instruction_type;

endpackage

`endif  // CPU_PKG_SV
