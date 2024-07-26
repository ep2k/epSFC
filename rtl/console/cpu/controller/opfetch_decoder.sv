// =======================================================
//  Opcode Fetch Time Decoder in 65816 CPU Controller
// =======================================================

// Copyright(C) 2024 ep2k All Rights Reserved.

module opfetch_decoder
    import cpu_pkg::*;
(
    input addressing_type addressing,
    input logic irq,
    output ctl_signals_type ctl_signals
);

    ctl_signals_type s;
    assign ctl_signals = s;

    always_comb begin
        
        s.mem_wdata_src = C_MW_AL;
        s.mem_write = 1'b0;

        s.reg_wdata_src = C_RW_ALUY;
        s.a_write = 2'b0;
        s.x_write = 2'b0;
        s.y_write = 2'b0;
        s.sp_write = 2'b0;
        s.dp_write = 2'b0;
        s.pbr_write = 1'b0;
        s.dbr_write = 1'b0;
        s.sp_inc = 1'b0;

        s.p_wdata_src = C_PW_CTL;
        s.p_wdata_ctl = 8'h0;
        s.p_write = 8'h0;
        s.xce = 1'b0;

        s.addr_inc = 1'b0;
        s.addr_bank_inc = 1'b0;
        s.addr2_inc = 1'b0;
        s.addr2_page_wrap = 1'b0;
        s.addr2_bank_inc = 1'b0;

        s.alu_a_src = C_AA_A;
        s.alu_b_src = C_AB_0;
        s.alu_c_src = C_AC_C;
        s.alu_control = C_ACTL_ADD;
        s.alu_bit8 = 1'b0;
        s.alu_bcd = 1'b0;

        /*
            op_reg <- mem[pc]
            if ~(A_WAIT & (~irq)) pc++
            addr, addr2にデフォルトアドレスを書き込み
        */

        s.mem_addr_src = C_MA_PC; // pc
        s.mem_read = 1'b1;
        s.pc_wdata_src = C_PCW_PC_1; // pc+1
        s.pc_write = ((addressing == A_WAIT) & (~irq)) ? 2'b00 : 2'b11; // addressingが不定だと問題

        {s.addr_write, s.addr2_write} = 6'b111_111;
        case (addressing)
            A_IMM_JMP: s.addr_wdata_src = C_AW_PC_1;    // {pbr, pc+16'h1}
            A_ABS_JMP: s.addr_wdata_src = C_AW_0;       // 24'h0
            A_ABSL_JMP: s.addr_wdata_src = C_AW_0;      // 24'h0
            A_ABSX_JMP: s.addr_wdata_src = C_AW_PBR;    // {pbr, 16'h0}
            A_DP: s.addr_wdata_src = C_AW_DP;           // {8'h0, dp}
            A_DPX: s.addr_wdata_src = C_AW_DP;          // {8'h0, dp}
            A_DPY: s.addr_wdata_src = C_AW_DP;          // {8'h0, dp}
            A_SPR: s.addr_wdata_src = C_AW_0;           // 24'h0
            default: s.addr_wdata_src = C_AW_DBR;       // {dbr, 16'h0}
        endcase
        case (addressing)
            A_SUB_ABSX: s.addr2_wdata_src = C_AW_PBR;   // {pbr, 16'h0}
            A_INDP: s.addr2_wdata_src = C_AW_DP;        // {8'h0, dp}
            A_INDPX: s.addr2_wdata_src = C_AW_DP;       // {8'h0, dp}
            A_INDPY: s.addr2_wdata_src = C_AW_DP;       // {8'h0, dp}
            A_INDPL: s.addr2_wdata_src = C_AW_DP;       // {8'h0, dp}
            A_INDPLY: s.addr2_wdata_src = C_AW_DP;      // {8'h0, dp}
            A_INSPRY: s.addr2_wdata_src = C_AW_0;       // 24'h0;
            A_PEI: s.addr2_wdata_src = C_AW_DP;         // {8'h0, dp}
            default: s.addr2_wdata_src = C_AW_DBR;      // {dbr, 16'h0}
        endcase

    end

endmodule
