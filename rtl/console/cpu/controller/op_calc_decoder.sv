// ==================================================
//  Operation Calc. Decoder in 65816 CPU Controller
// ==================================================

// Copyright(C) 2024 ep2k All Rights Reserved.

module op_calc_decoder
    import cpu_pkg::*;
(
    input instruction_type instruction,
    input logic [2:0] op_counter,

    input logic m8,
    input logic x8,
    input logic e,
    input logic [7:0] p,

    input logic [3:0] alu_flgs,
    input logic page_cross,

    input logic imm,

    output ctl_signals_type ctl_signals,
    output logic op_finish
);

    ctl_signals_type s;
    assign ctl_signals = s;

    instruction_type i;
    assign i = instruction;

    always_comb begin
        
        s.mem_addr_src = C_MA_PC;
        s.mem_wdata_src = C_MW_AL;
        s.mem_read = 1'b0;
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

        s.pc_wdata_src = C_PCW_PC_1;
        s.pc_write = 2'b0;
        
        s.addr_wdata_src = C_AW_RD;
        s.addr2_wdata_src = C_AW_RD;
        s.addr_write = 3'b0;
        s.addr2_write = 3'b0;
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

        op_finish = 1'b0;

        if ((i == I_LDA) | (i == I_LDX) | (i == I_LDY)) begin

            // [1] A/X/Y[7:0] <- mem[PC++/addr++]
            // [0] A/X/Y[15:8] <- mem[PC++/addr++]

            s.mem_addr_src = imm ? C_MA_PC : C_MA_ADDR; // pc/addr
            s.mem_read = 1'b1;

            s.pc_wdata_src = C_PCW_PC_1; // pc+1
            s.pc_write = imm ? 2'b11 : 2'b00;
            s.addr_inc = 1'b1;

            s.alu_a_src = C_AA_0; // 0
            s.alu_b_src = C_AB_RD; // {8'h0, mem_rdata}
            s.alu_control = C_ACTL_ADD; // ADD
            s.alu_bit8 = 1'b1;

            s.reg_wdata_src = C_RW_ALUYL; // {alu_y[7:0], alu_y[7:0]}
            s.a_write[(op_counter == 1) ? L : H] = (i == I_LDA);
            s.x_write[(op_counter == 1) ? L : H] = (i == I_LDX);
            s.y_write[(op_counter == 1) ? L : H] = (i == I_LDY);

            s.p_wdata_src = C_PW_CTL; // p_wdata_ctl
            s.p_wdata_ctl[N] = alu_flgs[AN];
            s.p_wdata_ctl[Z] = alu_flgs[AZ] & ((op_counter == 1) | p[Z]);
            {s.p_write[N], s.p_write[Z]} = 2'b11;

            op_finish = (
                ((i == I_LDA) & m8)
                | (((i == I_LDX) | (i == I_LDY)) & x8)
            );

        end else if ((i == I_STA) | (i == I_STX) | (i == I_STY) | (i == I_STZ)) begin

            // [1] mem[addr++] <- A/X/Y[7:0]/0
            // [0] mem[addr++] <- A/X/Y[15:8]/0

            s.mem_addr_src = C_MA_ADDR; // addr
            s.mem_write = 1'b1;
            s.addr_inc = 1'b1;

            case (i)
                I_STA: s.mem_wdata_src = (op_counter == 1) ? C_MW_AL : C_MW_AH; // a[7:0]/a[15:8]
                I_STX: s.mem_wdata_src = (op_counter == 1) ? C_MW_XL : C_MW_XH; // x[7:0]/x[15:8]
                I_STY: s.mem_wdata_src = (op_counter == 1) ? C_MW_YL : C_MW_YH; // y[7:0]/y[15:8]
                I_STZ: s.mem_wdata_src = C_MW_0; // 0
                default: s.mem_wdata_src = C_MW_0;
            endcase

            op_finish = (
                (((i == I_STA) | (i == I_STZ)) & m8)
                | (((i == I_STX) | (i == I_STY)) & x8)
            );
        
        end else if ((i == I_ADC) | (i == I_SBC) | (i == I_AND) | (i == I_EOR) | (i == I_ORA) | (i == I_BIT)) begin
            
            // [1] A[7:0] <- A[7:0] + mem[pc++/addr++]
            // [0] A[15:8] <- A[15:8] + mem[pc++/addr++]

            s.mem_addr_src = imm ? C_MA_PC : C_MA_ADDR; // pc/addr
            s.mem_read = 1'b1;

            s.pc_wdata_src = C_PCW_PC_1; // pc+1
            s.pc_write = imm ? 2'b11 : 2'b00;
            s.addr_inc = 1'b1;

            s.alu_a_src = (op_counter == 1) ? C_AA_A : C_AA_AH; // a[7:0]/a[15:8]
            s.alu_b_src = C_AB_RD; // mem_rdata
            s.alu_c_src = C_AC_C; // p[C]
            s.alu_bit8 = 1'b1;
            s.alu_bcd = ((i == I_ADC) | (i == I_SBC)) & p[D];
            case (i)
                I_ADC: s.alu_control = C_ACTL_ADC;
                I_SBC: s.alu_control = C_ACTL_SBC;
                I_AND: s.alu_control = C_ACTL_AND;
                I_EOR: s.alu_control = C_ACTL_EOR;
                I_ORA: s.alu_control = C_ACTL_OR;
                I_BIT: s.alu_control = C_ACTL_BIT;
                default: s.alu_control = C_ACTL_ADC;
            endcase

            s.reg_wdata_src = C_RW_ALUYL; // {alu_y[7:0], alu_y[7:0]}
            s.a_write[(op_counter == 1) ? L : H] = (i != I_BIT);

            s.p_wdata_src = C_PW_CTL; // p_wdata_ctl

            s.p_wdata_ctl[N] = alu_flgs[AN];
            s.p_wdata_ctl[V] = alu_flgs[AV];
            s.p_wdata_ctl[Z] = alu_flgs[AZ] & ((op_counter == 1) | p[Z]);
            s.p_wdata_ctl[C] = alu_flgs[AC];

            s.p_write[N] = ~((i == I_BIT) & imm);
            s.p_write[V] = (i == I_ADC) | (i == I_SBC) | ((i == I_BIT) & (~imm));
            s.p_write[Z] = 1'b1;
            s.p_write[C] = (i == I_ADC) | (i == I_SBC);

            op_finish = m8;

        end else if ((i == I_SEP) | (i == I_REP)) begin

            // [1] p <- p | mem[pc++] / p & (~mem[pc++])
            // [0] NOP

            s.mem_addr_src = C_MA_PC; // pc
            s.mem_read = (op_counter == 1);

            s.pc_wdata_src = C_PCW_PC_1; // pc+1
            s.pc_write = (op_counter == 1) ? 2'b11 : 2'b00;

            s.alu_a_src = C_AA_P; // p
            s.alu_b_src = C_AB_RD; // {8'h0, mem_rdata}
            s.alu_control = (i == I_SEP) ? C_ACTL_TSB : C_ACTL_TRB; // TSB/TRB

            s.p_wdata_src = C_PW_ALUYL; // alu_y[7:0]
            s.p_write = (op_counter == 1) ? 8'hff : 8'h0;
            
        end else if ((i == I_CMP) | (i == I_CPX) | (i == I_CPY)) begin

            // [1] A/X/Y[7:0] - mem[pc++/addr++]
            // [0] A/X/Y[15:8] - mem[pc++/addr++] + c

            s.mem_addr_src = imm ? C_MA_PC : C_MA_ADDR; // pc/addr
            s.mem_read = 1'b1;

            s.pc_wdata_src = C_PCW_PC_1; // pc+1
            s.pc_write = imm ? 2'b11 : 2'b00;
            s.addr_inc = 1'b1;

            case (i)
                I_CMP: s.alu_a_src = (op_counter == 1) ? C_AA_A : C_AA_AH; // a[7:0]/a[15:8]
                I_CPX: s.alu_a_src = (op_counter == 1) ? C_AA_X : C_AA_XH; // x[7:0]/x[15:8]
                I_CPY: s.alu_a_src = (op_counter == 1) ? C_AA_Y : C_AA_YH; // y[7:0]/y[15:8]
                default: s.alu_a_src = C_AA_A;
            endcase

            s.alu_b_src = C_AB_RD; // mem_rdata
            s.alu_c_src = C_AC_C; // p[C]
            s.alu_control = (op_counter == 1) ? C_ACTL_SUB : C_ACTL_SBC; // SUB/SBC
            s.alu_bit8 = 1'b1;
            
            s.p_wdata_src = C_PW_CTL; // p_wdata_ctl

            s.p_wdata_ctl[N] = alu_flgs[AN];
            s.p_wdata_ctl[Z] = alu_flgs[AZ] & ((op_counter == 1) | p[Z]);
            s.p_wdata_ctl[C] = alu_flgs[AC];

            s.p_write[N] = 1'b1;
            s.p_write[Z] = 1'b1;
            s.p_write[C] = 1'b1;

            op_finish = (
                ((i == I_CMP) & m8)
                | (((i == I_CPX) | (i == I_CPY)) & x8)
            );

        end else if ((i == I_INC_A) | (i == I_DEC_A) | (i == I_ASL_A) | (i == I_LSR_A) | (i == I_ROL_A) | (i == I_ROR_A)) begin

            // [0] A <- A + 1

            s.alu_a_src = C_AA_A; // a
            s.alu_b_src = C_AB_1; // 1
            case (i)
                I_INC_A: s.alu_control = C_ACTL_ADD; // ADD
                I_DEC_A: s.alu_control = C_ACTL_SUB; // SUB
                I_ASL_A: s.alu_control = C_ACTL_ASL; // ASL
                I_LSR_A: s.alu_control = C_ACTL_LSR; // LSR
                I_ROL_A: s.alu_control = C_ACTL_ROL; // ROL
                I_ROR_A: s.alu_control = C_ACTL_ROR; // ROR
                default: s.alu_control = C_ACTL_ADD;
            endcase
            s.alu_bit8 = m8;

            s.reg_wdata_src = C_RW_ALUY; // alu_y
            s.a_write = {~m8, 1'b1};

            s.p_wdata_src = C_PW_CTL; // p_wdata_ctl

            s.p_wdata_ctl[N] = alu_flgs[AN];
            s.p_wdata_ctl[Z] = alu_flgs[AZ];
            s.p_wdata_ctl[C] = alu_flgs[AC];

            s.p_write[N] = 1'b1;
            s.p_write[Z] = 1'b1;
            s.p_write[C] = ~((i == I_INC_A) | (i == I_DEC_A));

        end else if ((i == I_INC) | (i == I_DEC) | (i == I_ASL) | (i == I_LSR) | (i == I_ROL) | (i == I_ROR) | (i == I_TSB) | (i == I_TRB)) begin

            /*
                p[M] == 0 のとき
                    [4] addr2[7:0] <- mem[addr]
                    [3] addr2[15:8] <- mem[addr+1]
                    [2] addr2 <- addr2 + 1
                    [1] mem[addr] <- addr2[7:0]
                    [0] mem[addr+1] <- addr2[15:8]
                
                p[M] == 1 のとき
                    [3] addr2[7:0] <- mem[addr]
                    [2] addr2 <- addr2 + 1
                    [1] mem[addr] <- addr2[7:0]
            */

            s.mem_addr_src = ((~m8) & ((op_counter == 3) | (op_counter == 0)))
                            ? C_MA_ADDR_1 : C_MA_ADDR; // addr+1/addr
            s.mem_read = (op_counter == 4) | (op_counter == 3);
            s.mem_wdata_src = (op_counter == 1) ? C_MW_ADDR2L : C_MW_ADDR2H; // addr2[7:0]/[15:8]
            s.mem_write = (op_counter == 1) | (op_counter == 0);

            s.alu_a_src = C_AA_ADDR2; // addr2[15:0]
            s.alu_b_src = ((i == I_TSB) | (i == I_TRB)) ? C_AB_A : C_AB_1; // A/1
            case (i)
                I_INC: s.alu_control = C_ACTL_ADD; // ADD
                I_DEC: s.alu_control = C_ACTL_SUB; // SUB
                I_ASL: s.alu_control = C_ACTL_ASL; // ASL
                I_LSR: s.alu_control = C_ACTL_LSR; // LSR
                I_ROL: s.alu_control = C_ACTL_ROL; // ROL
                I_ROR: s.alu_control = C_ACTL_ROR; // ROR
                I_TSB: s.alu_control = C_ACTL_TSB; // TSB
                I_TRB: s.alu_control = C_ACTL_TRB; // TRB
                default: s.alu_control = C_ACTL_ADD;
            endcase
            s.alu_bit8 = m8;

            s.addr2_wdata_src = (op_counter == 2) ? C_AW_ALUY : C_AW_RD; // {8'h0, alu_y}/{mem_rdata, mem_rdata, mem_rdata}
            s.addr2_write[1:0] = {
                ((~m8) & (op_counter == 3)) | (op_counter == 2),
                (op_counter == 4) | (m8 & (op_counter == 3)) | (op_counter == 2)
            };

            s.p_wdata_src = C_PW_CTL; // p_wdata_ctl

            s.p_wdata_ctl[N] = alu_flgs[AN];
            s.p_wdata_ctl[Z] = alu_flgs[AZ];
            s.p_wdata_ctl[C] = alu_flgs[AC];

            s.p_write[N] = (op_counter == 2) & (i != I_TSB) & (i != I_TRB);
            s.p_write[Z] = (op_counter == 2);
            s.p_write[C] = (op_counter == 2) & ((i == I_ASL) | (i == I_LSR) | (i == I_ROL) | (i == I_ROR));

            op_finish = (op_counter == 1) & m8;

        end else if ((i == I_INX) | (i == I_INY) | (i == I_DEX) | (i == I_DEY)) begin

            // [0] X/Y <- X/Y + 1

            s.alu_a_src = ((i == I_INX) | (i == I_DEX)) ? C_AA_X : C_AA_Y; // x/y
            s.alu_b_src = C_AB_1; // 1
            s.alu_control = ((i == I_INX) | (i == I_INY)) ? C_ACTL_ADD : C_ACTL_SUB; // ADD/SUB
            s.alu_bit8 = x8;

            s.reg_wdata_src = C_RW_ALUY; // alu_y
            s.x_write = ((i == I_INX) | (i == I_DEX)) ? {~x8, 1'b1} : 2'b00;
            s.y_write = ((i == I_INY) | (i == I_DEY)) ? {~x8, 1'b1} : 2'b00;

            s.p_wdata_src = C_PW_CTL; // p_wdata_ctl

            s.p_wdata_ctl[N] = alu_flgs[AN];
            s.p_wdata_ctl[Z] = alu_flgs[AZ];

            s.p_write[N] = 1'b1;
            s.p_write[Z] = 1'b1;

        end else if ((i == I_BCS) | (i == I_BCC) | (i == I_BEQ) | (i == I_BNE) | (i == I_BMI) | (i == I_BPL) | (i == I_BVS) | (i == I_BVC) | (i == I_BRA)) begin

            // [2] addr[7:0] <- mem[pc++], 条件を満たさない場合は終了
            // [1] pc <- pc + addr[7:0](符号拡張), e=1でページクロス時は継続
            // [0] NOP

            s.mem_addr_src = C_MA_PC; // {pbr, pc}
            s.mem_read = (op_counter == 2);

            s.pc_wdata_src = (op_counter == 2) ? C_PCW_PC_1 : C_PCW_ALUY; // pc+1/alu_y
            s.pc_write = (op_counter != 0) ? 2'b11 : 2'b00;

            s.addr_wdata_src = C_AW_RD; // {mem_wdata, mem_wdata, mem_wdata}
            s.addr_write[L] = (op_counter == 2);

            s.alu_a_src = C_AA_PC; // pc
            s.alu_b_src = C_AB_ADDRL_SIGNED; // addr[7:0](符号拡張)
            s.alu_control = C_ACTL_ADD; // ADD

            case (op_counter)
                2: op_finish = ~(
                        ((i == I_BCS) & p[C])
                        | ((i == I_BCC) & (~p[C]))
                        | ((i == I_BEQ) & p[Z])
                        | ((i == I_BNE) & (~p[Z]))
                        | ((i == I_BMI) & p[N])
                        | ((i == I_BPL) & (~p[N]))
                        | ((i == I_BVS) & p[V])
                        | ((i == I_BVC) & (~p[V]))
                        | (i == I_BRA)
                    );
                1: op_finish = ~(e & page_cross);
                default: op_finish = 1'b0;
            endcase

        end else if (i == I_BRL) begin

            // [2] addr[7:0] <- mem[pc++]
            // [1] addr[15:8] <- mem[pc++]
            // [0] pc <- pc + addr

            s.mem_addr_src = C_MA_PC; // {pbr, pc}
            s.mem_read = (op_counter != 0);

            s.pc_wdata_src = (op_counter == 0) ? C_PCW_ALUY : C_PCW_PC_1; // alu_y/pc+1
            s.pc_write = 2'b11;

            s.addr_wdata_src = C_AW_RD; // {mem_rdata, mem_rdata, mem_rdata}
            s.addr_write[L] = (op_counter == 2);
            s.addr_write[H] = (op_counter == 1);

            s.alu_a_src = C_AA_PC; // pc
            s.alu_b_src = C_AB_ADDR; // addr
            s.alu_control = C_ACTL_ADD; // ADD
        
        end else if ((i == I_JMP) | (i == I_JMPL)) begin

            // [2] pc[7:0] <- mem[addr++] (IMMではデフォルトでaddr = {pbr, pc})
            // [1] pc[15:8] <- mem[addr++]
            // [0] pbr <- mem[addr++] (I_JMPLのみ)
            // addrのバンクに繰り上がりを加算するか？

            /*
                Absolute: A_IMM_JMP, I_JMP
                Absolute Long: A_IMM_JMP, I_JMPL
                Absolute Indirect: A_ABS_JMP, I_JMP
                Absolute Indexed Indirect: A_ABSX_JMP, I_JMP
                Absolute Indirect Long: A_ABSL_JMP, I_JMPL
            */

            s.mem_addr_src = C_MA_ADDR; // addr
            s.mem_read = 1'b1;
            s.addr_inc = 1'b1;

            s.pc_wdata_src = C_PCW_RD; // {mem_rdata, mem_rdata}
            s.reg_wdata_src = C_RW_RD; // {mem_rdata, mem_rdata}
            s.pc_write[L] = (op_counter == 2);
            s.pc_write[H] = (op_counter == 1);
            s.pbr_write = (op_counter == 0);

            op_finish = (op_counter == 1) & (i == I_JMP);

        end else if ((i == I_SEC) | (i == I_CLC)) begin

            s.p_wdata_src = C_PW_CTL; // p_wdata_ctl
            s.p_wdata_ctl[C] = (i == I_SEC);
            s.p_write[C] = 1'b1;

        end else if ((i == I_SED) | (i == I_CLD)) begin

            s.p_wdata_src = C_PW_CTL; // p_wdata_ctl
            s.p_wdata_ctl[D] = (i == I_SED);
            s.p_write[D] = 1'b1;

        end else if ((i == I_SEI) | (i == I_CLI)) begin

            s.p_wdata_src = C_PW_CTL; // p_wdata_ctl
            s.p_wdata_ctl[I] = (i == I_SEI);
            s.p_write[I] = 1'b1;

        end else if (i == I_CLV) begin

            s.p_wdata_src = C_PW_CTL; // p_wdata_ctl
            s.p_wdata_ctl[V] = 1'b0;
            s.p_write[V] = 1'b1;

        end else if ((i == I_TXA) | (i == I_TYA) | (i == I_TAX) | (i == I_TAY) | (i == I_TYX) | (i == I_TXY) | (i == I_TDC) | (i == I_TCD) | (i == I_TSC) | (i == I_TSX) | (i == I_TCS) | (i == I_TXS)) begin

            // [0] レジスタ間転送
            /*
                TXA: A <- X (m=1で下位のみ)
                TYA: A <- Y (m=1で下位のみ)

                TAX: X <- A (x=1で下位のみ)
                TAY: Y <- A (x=1で下位のみ)
                TYX: X <- Y (x=1で下位のみ)
                TXY: Y <- X (x=1で下位のみ)

                TDC: A <- DP
                TCD: DP <- A

                TSC: A <- SP
                TSX: X <- SP (x=1で下位のみ)
                
                TCS: SP <- A
                TXS: SP <- X
            */

            if ((i == I_TAX) | (i == I_TAY) | (i == I_TCD) | (i == I_TCS)) begin
                s.alu_a_src = C_AA_A; // a
            end else if ((i == I_TXA) | (i == I_TXY) | (i == I_TXS)) begin
                s.alu_a_src = C_AA_X; // x
            end else if ((i == I_TYA) | (i == I_TYX)) begin
                s.alu_a_src = C_AA_Y; // y
            end else if (i == I_TDC) begin
                s.alu_a_src = C_AA_DP; // dp
            end else begin // I_TSC, I_TSX
                s.alu_a_src = C_AA_SP; // sp
            end

            s.alu_b_src = C_AB_0; // 0
            s.alu_control = C_ACTL_ADD; // ADD

            s.alu_bit8 = (
                m8 & (
                    (i == I_TXA) | (i == I_TYA)
                )
            ) | (
                x8 & (
                    (i == I_TAX) | (i == I_TAY)
                    | (i == I_TYX) | (i == I_TXY) | (i == I_TSX)
                )
            );

            s.reg_wdata_src = C_RW_ALUY; // alu_y

            s.a_write[L] = ((i == I_TXA) | (i == I_TYA) | (i == I_TDC) | (i == I_TSC));
            s.a_write[H] = (((~m8) & ((i == I_TXA) | (i == I_TYA))) | (i == I_TDC) | (i == I_TSC));
            s.x_write = ((i == I_TAX) | (i == I_TYX) | (i == I_TSX)) ? 2'b11 : 2'b00;
            s.y_write = ((i == I_TAY) | (i == I_TXY)) ? 2'b11 : 2'b00;
            s.dp_write = (i == I_TCD) ? 2'b11 : 2'b00;
            s.sp_write = ((i == I_TCS) | (i == I_TXS)) ? 2'b11 : 2'b00;

            s.p_wdata_src = C_PW_CTL; // p_wdata_ctl
            s.p_wdata_ctl[N] = alu_flgs[AN];
            s.p_wdata_ctl[Z] = alu_flgs[AZ];
            s.p_write[N] = ~((i == I_TCS) | (i == I_TXS));
            s.p_write[Z] = ~((i == I_TCS) | (i == I_TXS));

        end else if ((i == I_PHA) | (i == I_PLA)) begin

            // [1] NOP (PLAのみ)
            // [0] NOP
            ;

        end else if ((i == I_RTI) | (i == I_RTL) | (i == I_RTS)) begin

            // [2] NOP (RTSのみ)
            // [1] NOP
            // [0] RTL, RTSならpc++

            s.pc_wdata_src = C_PCW_PC_1; // pc+1
            s.pc_write = ((op_counter == 0) & (i != I_RTI)) ? 2'b11 : 2'b00;

        end else if (i == I_XBA) begin

            // [1] addr[7:0] <- A[7:0] (直接), A[7:0] <- A[15:8] (ALU)
            // [0] A[15:8] <- addr[7:0]

            s.alu_a_src = (op_counter == 1) ? C_AA_AH : C_AA_ADDR; // {8'h0,a[15:8]}/addr[15:0]
            s.alu_b_src = C_AB_0; // 0
            s.alu_control = C_ACTL_ADD;
            s.alu_bit8 = 1'b1;

            s.reg_wdata_src = C_RW_ALUYL;
            s.a_write[L] = (op_counter == 1);
            s.a_write[H] = (op_counter == 0);

            s.p_wdata_src = C_PW_CTL;
            s.p_wdata_ctl[N] = alu_flgs[AN];
            s.p_wdata_ctl[Z] = alu_flgs[AZ];
            s.p_write[N] = (op_counter == 1);
            s.p_write[Z] = (op_counter == 1);

            s.addr_wdata_src = C_AW_A; // {8'h0, a}
            s.addr_write[L] = 1'b1;

        end else if (i == I_XCE) begin

            s.xce = 1'b1;

        end else if ((i == I_NOP) | (i == I_WDM)) begin

            // [0] WDMならpc++

            s.pc_wdata_src = C_PCW_PC_1; // pc+1
            s.pc_write = (i == I_WDM) ? 2'b11 : 2'b00;

        end else if ((i == I_BRK) | (i == I_COP) | (i == I_HARD_INT)) begin

            // [1] pc[7:0] <- mem[VA]
            // [0] pc[15:8] <- mem[VA+1]
            // pbr <- 0, p[D] <- 0, p[I] <- 1, e=1ならp[BRK] <- (i==I_BRK)

            s.mem_addr_src = (op_counter == 1) ? C_MA_VA : C_MA_VA_1; // vector_addr/vector_addr+1
            s.mem_read = 1'b1;

            s.pc_wdata_src = C_PCW_RD; // {mem_rdata, mem_rdata}
            s.pc_write[(op_counter == 1) ? L : H] = 1'b1;

            s.alu_a_src = C_AA_0; // 0
            s.alu_b_src = C_AB_0; // 0
            s.alu_control = C_ACTL_ADD; // ADD

            s.reg_wdata_src = C_RW_ALUY; // alu_y(0)
            s.pbr_write = 1'b1;

            s.p_wdata_src = C_PW_CTL; // p_wdata_ctl

            s.p_wdata_ctl[D] = 1'b0;
            s.p_wdata_ctl[I] = 1'b1;
            s.p_wdata_ctl[BRK] = (i == I_BRK);

            s.p_write[D] = 1'b1;
            s.p_write[I] = 1'b1;
            s.p_write[BRK] = e;

        end else begin
            ;
        end

    end

endmodule
