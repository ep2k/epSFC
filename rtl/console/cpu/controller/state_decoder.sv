// ========================================
//  State Decoder in 65186 CPU Controller
// ========================================

// Copyright(C) 2024 ep2k All Rights Reserved.

module state_decoder
    import cpu_pkg::*;
(
    input state_type state,
    input addressing_type addressing,

    input logic irq,
    input logic [7:0] p,
    input logic [3:0] alu_flgs,
    input logic carry,
    input logic a_max,
    input logic dp_wrap,

    output ctl_signals_type ctl_signals
);

    ctl_signals_type s;
    assign ctl_signals = s;

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

        if ((state == S_FETCH_OPRAND_L) | (state == S_FETCH_OPRAND_H) | (state == S_FETCH_OPRAND_B)) begin

            /*
                addr[L/H/B] ← mem[pc] + alpha
                addr2[L/H/B] ← mem[pc] + alpha
                pc++

                Lのとき
                    ABSX/Y, ABSX_JMP, ABSLX, SUB_ABSXならX/Y[7:0]を加算
                Hのとき
                    ABSX/Y, ABSX_JMP, ABSLX, SUB_ABSXならX/Y[15:8]とcarryを加算
                    SUB_IMM, SUB_ABSXならpc++しない
                    SUB_ABSXで繰り上がりがあるならaddr2[B]++
                Bのとき
                    ABSLXならcarryを加算
                    SUB_IMMLならpc++しない
            */

            s.mem_addr_src = C_MA_PC; // pc
            s.mem_read = 1'b1;
            s.pc_wdata_src = C_PCW_PC_1; // pc+1
            
            if (state == S_FETCH_OPRAND_H) begin
                if (addressing == A_SUB_IMM) begin
                    s.pc_write = 2'b00;
                end else if (addressing == A_SUB_ABSX) begin
                    s.pc_write = 2'b00;
                    s.addr2_bank_inc = alu_flgs[AC];
                end else begin
                    s.pc_write = 2'b11;
                end
            end else if (state == S_FETCH_OPRAND_B) begin
                s.pc_write = (addressing == A_SUB_IMML) ? 2'b00 : 2'b11;
            end else begin
                s.pc_write = 2'b11;
            end

            if (state == S_FETCH_OPRAND_L) begin
                if ((addressing == A_ABSX) | (addressing == A_ABSX_JMP) | (addressing == A_ABSLX) | (addressing == A_SUB_ABSX)) begin
                    s.alu_a_src = C_AA_X; // x
                    s.alu_control = C_ACTL_ADD; // ADD
                end else if (addressing == A_ABSY) begin
                    s.alu_a_src = C_AA_Y; // y
                    s.alu_control = C_ACTL_ADD; // ADD
                end else begin
                    s.alu_a_src = C_AA_0; // 0
                    s.alu_control = C_ACTL_ADD; // ADD
                end
            end else if (state == S_FETCH_OPRAND_H) begin
                if ((addressing == A_ABSX) | (addressing == A_ABSX_JMP) | (addressing == A_ABSLX) | (addressing == A_SUB_ABSX)) begin
                    s.alu_a_src = C_AA_XH; // {8'h0, x[15:8]}
                    s.alu_control = C_ACTL_ADC; // ADC
                end else if (addressing == A_ABSY) begin
                    s.alu_a_src = C_AA_YH; // {8'h0, y[15:8]}
                    s.alu_control = C_ACTL_ADC; // ADC
                end else begin
                    s.alu_a_src = C_AA_0; // 0
                    s.alu_control = C_ACTL_ADD; // ADD
                end
            end else begin // S_FETCH_OPRAND_B
                s.alu_a_src = C_AA_0; // 0
                s.alu_control = (addressing == A_ABSLX) ? C_ACTL_ADC : C_ACTL_ADD; // ADC/ADD
            end

            s.alu_b_src = C_AB_RD; // {8'h0, mem_rdata}
            s.alu_c_src = C_AC_CARRY; // carry
            s.alu_bit8 = 1'b1;

            s.addr_wdata_src = C_AW_ALUYL; // {alu_y[7:0], alu_y[7:0], alu_y[7:0]}
            s.addr2_wdata_src = C_AW_ALUYL; // {alu_y[7:0], alu_y[7:0], alu_y[7:0]}
            if (state == S_FETCH_OPRAND_L) begin
                s.addr_write[L] = 1'b1;
                s.addr2_write[L] = 1'b1;
            end else if (state == S_FETCH_OPRAND_H) begin
                s.addr_write[H] = 1'b1;
                s.addr2_write[H] = 1'b1;
            end else begin // S_FETCH_OPRAND_B
                s.addr_write[B] = 1'b1;
                s.addr2_write[B] = 1'b1;
            end

        end else if ((state == S_READ_ADDR2_L) | (state == S_READ_ADDR2_H) | (state == S_READ_ADDR2_B)) begin

            /*
                addr[L/H/B] ← mem[addr2] + alpha
                addr2++

                Lのとき
                    INDPY, INDPLYならY[7:0]を加算
                Hのとき
                    INDPY, INDPLYならY[15:8]とcarryを加算
                Bのとき
                    INDPLYならcarryを加算
            */

            s.mem_addr_src = C_MA_ADDR2; // addr2
            s.mem_read = 1'b1;
            s.addr2_inc = 1'b1;
            s.addr2_page_wrap = dp_wrap & ((addressing == A_INDP) | (addressing == A_INDPX) | (addressing == A_INDPY) | (addressing == A_SUB_ABSX));

            if (state == S_READ_ADDR2_L) begin
                if ((addressing == A_INDPY) | (addressing == A_INDPLY)) begin
                    s.alu_a_src = C_AA_Y; // y
                    s.alu_control = C_ACTL_ADD; // ADD
                end else begin
                    s.alu_a_src = C_AA_0; // 0
                    s.alu_control = C_ACTL_ADD; // ADD
                end
            end else if (state == S_READ_ADDR2_H) begin
                if ((addressing == A_INDPY) | (addressing == A_INDPLY)) begin
                    s.alu_a_src = C_AA_YH; // {8'h0, y[15:8]}
                    s.alu_control = C_ACTL_ADC; // ADC
                end else begin
                    s.alu_a_src = C_AA_0; // 0
                    s.alu_control = C_ACTL_ADD; // ADD
                end
            end else begin // S_FETCH_OPRAND_B
                s.alu_a_src = C_AA_0; // 0
                s.alu_control = (addressing == A_INDPLY) ? C_ACTL_ADC : C_ACTL_ADD; // ADC/ADD
            end

            s.alu_b_src = C_AB_RD; // {8'h0, mem_rdata}
            s.alu_c_src = C_AC_CARRY; // carry
            s.alu_bit8 = 1'b1;

            s.addr_wdata_src = C_AW_ALUYL; // {alu_y[7:0], alu_y[7:0], alu_y[7:0]}
            if (state == S_READ_ADDR2_L) begin
                s.addr_write[L] = 1'b1;
            end else if (state == S_READ_ADDR2_H) begin
                s.addr_write[H] = 1'b1;
            end else begin
                s.addr_write[B] = 1'b1;
            end

        end else if ((state == S_ADD_ADDR_X) | (state == S_ADD_ADDR_Y) | (state == S_ADD_ADDR2_X)) begin

            /*
                addr <- addr + X/Y
                addr2 <- addr2 + X
            */

            s.alu_a_src = (state == S_ADD_ADDR_Y) ? C_AA_Y : C_AA_X; // y/x
            s.alu_b_src = (state == S_ADD_ADDR2_X) ? C_AB_ADDR2 : C_AB_ADDR; // addr2[15:0]/addr[15:0]
            s.alu_control = C_ACTL_ADD; // ADD

            s.addr_wdata_src = C_AW_ALUY; // alu_y
            s.addr2_wdata_src = C_AW_ALUY; // alu_y
            s.addr_write[1:0] = (state == S_ADD_ADDR2_X) ? 2'b00 : {~dp_wrap, 1'b1};
            s.addr2_write[1:0] = (state == S_ADD_ADDR2_X) ? {~dp_wrap, 1'b1} : 2'b00;
        
        end else if (state == S_ADD_ADDRB_CARRY) begin

            /*
                addr[B] <- addr[B] + carry
            */

            // 後に考える．addr_inc? alu?
            // aluならalu_bにaddr[23:16]が必要

            s.addr_bank_inc = carry & (addressing != A_ABSX_JMP);

        end else if ((state == S_ADD_ADDR_DPL) | (state == S_ADD_ADDR2_DPL)) begin

            /*
                addr[15:0] <- addr[15:0] + DP[7:0]
                addr2[15:0] <- addr2[15:0] + DP[7:0]
            */

            s.alu_a_src = C_AA_DPL; // dp[7:0]
            s.alu_b_src = (state == S_ADD_ADDR_DPL) ? C_AB_ADDR : C_AB_ADDR2; // addr/addr2[15:0]
            s.alu_control = C_ACTL_ADD; // ADD

            s.addr_wdata_src = C_AW_ALUY; // {8'h0, alu_y}
            s.addr2_wdata_src = C_AW_ALUY; // {8'h0, alu_y}
            s.addr_write[1:0] = (state == S_ADD_ADDR_DPL) ? 2'b11 : 2'b00;
            s.addr2_write[1:0] = (state == S_ADD_ADDR2_DPL) ? 2'b11 : 2'b00;

        end else if (state == S_ADD_ADDR_PC) begin

            /*
                addr[15:0] <- pc + addr[15:0]
            */

            s.alu_a_src = C_AA_PC; // pc
            s.alu_b_src = C_AB_ADDR; // addr[15:0]
            s.alu_control = C_ACTL_ADD; // ADD

            s.addr_wdata_src = C_AW_ALUY; // alu_y
            s.addr_write[1:0] = 2'b11;

        end else if ((state == S_ADD_ADDR_SP) | (state == S_ADD_ADDR2_SP)) begin

            /*
                addr/addr2[15:0] <- addr/addr2[15:0] + sp
            */

            s.alu_a_src = C_AA_SP; // sp
            s.alu_b_src = (state == S_ADD_ADDR_SP) ? C_AB_ADDR : C_AB_ADDR2; // addr/addr2[15:0]
            s.alu_control = C_ACTL_ADD; // ADD

            s.addr_wdata_src = C_AW_ALUY; // {8'h0, alu_y}
            s.addr2_wdata_src = C_AW_ALUY; // {8'h0, alu_y}
            s.addr_write[1:0] = (state == S_ADD_ADDR_SP) ? 2'b11 : 2'b00;
            s.addr2_write[1:0] = (state == S_ADD_ADDR2_SP) ? 2'b11 : 2'b00;

        end else if ((state == S_PUSH_B) | (state == S_PUSH_H) | (state == S_PUSH_L) | (state == S_PUSH_P)) begin

            /*
                mem[sp] <- データ
                sp--
            */

            s.mem_addr_src = C_MA_SP; // sp
            s.mem_write = 1'b1;
            
            if (state == S_PUSH_B) begin
                s.mem_wdata_src = C_MW_PBR; // pbr
            end else if (state == S_PUSH_H) begin
                case (addressing)
                    A_PUSH_A: s.mem_wdata_src = C_MW_AH; // a[15:8]
                    A_PUSH_X: s.mem_wdata_src = C_MW_XH; // x[15:8]
                    A_PUSH_Y: s.mem_wdata_src = C_MW_YH; // y[15:8]
                    A_PUSH_DP: s.mem_wdata_src = C_MW_DPH; // dp[15:8]
                    A_SUB_IMM: s.mem_wdata_src = C_MW_PCH; // pc[15:8]
                    A_SUB_IMML: s.mem_wdata_src = C_MW_PCH; // pc[15:8]
                    A_SUB_ABSX: s.mem_wdata_src = C_MW_PCH; // pc[15:8]
                    A_PEA: s.mem_wdata_src = C_MW_ADDRH; // addr[15:8]
                    A_PEI: s.mem_wdata_src = C_MW_ADDRH; // addr[15:8]
                    A_PER: s.mem_wdata_src = C_MW_ADDRH; // addr[15:8]
                    A_SOFT_INT: s.mem_wdata_src = C_MW_PCH; // pc[15:8]
                    A_HARD_INT: s.mem_wdata_src = C_MW_PCH; // pc[15:8]
                    default: s.mem_wdata_src = C_MW_ADDRH; // addr[15:8]
                endcase
            end else if (state == S_PUSH_L) begin
                case (addressing)
                    A_PUSH_A: s.mem_wdata_src = C_MW_AL; // a[7:0]
                    A_PUSH_X: s.mem_wdata_src = C_MW_XL; // x[7:0]
                    A_PUSH_Y: s.mem_wdata_src = C_MW_YL; // y[7:0]
                    A_PUSH_P: s.mem_wdata_src = C_MW_P; // p
                    A_PUSH_DP: s.mem_wdata_src = C_MW_DPL; // dp[7:0]
                    A_PUSH_PB: s.mem_wdata_src = C_MW_PBR; // pbr
                    A_PUSH_DB: s.mem_wdata_src = C_MW_DBR; // dbr
                    A_SUB_IMM: s.mem_wdata_src = C_MW_PCL; // pc[7:0]
                    A_SUB_IMML: s.mem_wdata_src = C_MW_PCL; // pc[7:0]
                    A_SUB_ABSX: s.mem_wdata_src = C_MW_PCL; // pc[7:0]
                    A_PEA: s.mem_wdata_src = C_MW_ADDRL; // addr[7:0]
                    A_PEI: s.mem_wdata_src = C_MW_ADDRL; // addr[7:0]
                    A_PER: s.mem_wdata_src = C_MW_ADDRL; // addr[7:0]
                    A_SOFT_INT: s.mem_wdata_src = C_MW_PCL; // pc[7:0]
                    A_HARD_INT: s.mem_wdata_src = C_MW_PCL; // pc[7:0]
                    default: s.mem_wdata_src = C_MW_PCL; // addr[7:0]
                endcase
            end else begin // S_PUSH_P
                s.mem_wdata_src = C_MW_P; // p
            end

            s.alu_a_src = C_AA_SP; // sp
            s.alu_b_src = C_AB_1; // 1
            s.alu_control = C_ACTL_SUB; // SUB

            s.reg_wdata_src = C_RW_ALUY; // alu_y
            s.sp_write = 2'b11;

        end else if ((state == S_PULL_P) | (state == S_PULL_L) | (state == S_PULL_H) | (state == S_PULL_B)) begin

            /*
                データ <- mem[sp+1]
                sp++
            */

            s.mem_addr_src = C_MA_SP_1; // sp+1
            s.mem_read = 1'b1;
            s.sp_inc = 1'b1;

            s.alu_a_src = C_AA_0; // 0
            s.alu_b_src = C_AB_RD; // {8'h0, mem_rdata}
            s.alu_control = C_ACTL_ADD; // ADD
            s.alu_bit8 = 1'b1;

            s.reg_wdata_src = C_RW_ALUYL; // {alu_y[7:0], alu_y[7:0]}
            s.pc_wdata_src = C_PCW_RD; // {mem_rdata, mem_rdata}
            s.p_wdata_src = ((addressing == A_PULL_P) | (state == S_PULL_P))
                    ? C_PW_RWL : C_PW_CTL; // reg_wdata[7:0]/p_wdata_ctl

            if (state == S_PULL_P) begin
                s.p_write = 8'hff;
            end else if (state == S_PULL_L) begin
                s.a_write[L] = (addressing == A_PULL_A);
                s.x_write[L] = (addressing == A_PULL_X);
                s.y_write[L] = (addressing == A_PULL_Y);
                s.dp_write[L] = (addressing == A_PULL_DP);
                s.pbr_write = (addressing == A_PULL_PB);
                s.dbr_write = (addressing == A_PULL_DB);
                s.pc_write[L] =
                    (addressing == A_RTI)
                    | (addressing == A_RTL)
                    | (addressing == A_RTS);
                if (addressing == A_PULL_P) begin
                    s.p_write = 8'hff;
                end else if (s.pc_write[L]) begin
                    s.p_write = 8'h0;
                end else begin
                    s.p_wdata_ctl[N] = alu_flgs[AN];
                    s.p_wdata_ctl[Z] = alu_flgs[AZ];
                    s.p_write[N] = 1'b1;
                    s.p_write[Z] = 1'b1;
                end
            end else if (state == S_PULL_H) begin
                s.a_write[H] = (addressing == A_PULL_A);
                s.x_write[H] = (addressing == A_PULL_X);
                s.y_write[H] = (addressing == A_PULL_Y);
                s.dp_write[H] = (addressing == A_PULL_DP);
                s.pc_write[H] =
                    (addressing == A_RTI)
                    | (addressing == A_RTL)
                    | (addressing == A_RTS);
                if (s.pc_write[H]) begin
                    s.p_write = 8'h0;
                end else begin
                    s.p_wdata_ctl[N] = alu_flgs[AN];
                    s.p_wdata_ctl[Z] = alu_flgs[AZ] & p[Z];
                    s.p_write[N] = 1'b1;
                    s.p_write[Z] = 1'b1;
                end
            end else begin // S_PULL_B
                s.pbr_write = 1'b1;
            end

        end else if (state == S_COPY_PC_ADDR) begin

            /*
                {pbr, pc} <- addr
                pbrへの書き込みはJSLのみ
            */

            s.pc_wdata_src = C_PCW_ADDR; // addr[15:0]
            s.pc_write = 2'b11;

            s.reg_wdata_src = C_RW_ADDRB; // addr[23:16]
            s.pbr_write = (addressing == A_SUB_IMML);

        end else if ((state == S_PC_INC) | (state == S_PC_DEC)) begin

            /*
                pc <- pc +/- 1
            */

            s.alu_a_src = C_AA_PC; // pc
            s.alu_b_src = C_AB_1; // 1
            s.alu_control = (state == S_PC_INC) ? C_ACTL_ADD : C_ACTL_SUB; // ADD/ADC

            s.pc_wdata_src = C_PCW_ALUY; // alu_y
            s.pc_write = 2'b11;

        end else if ((state == S_FETCH_BANK_1) | (state == S_FETCH_BANK_2)) begin

            /*
                S_FETCH_BANK_1: dbr <- mem[pc+1]
                S_FETCH_BANK_2: dbr <- mem[pc++]
            */

            s.mem_addr_src = (state == S_FETCH_BANK_1) ? C_MA_PC_1 : C_MA_PC; // pc+1/pc
            s.mem_read = 1'b1;
            s.reg_wdata_src = C_RW_RD; // mem_rdata
            s.dbr_write = 1'b1;

            s.pc_wdata_src = C_PCW_PC_1; // pc+1
            s.pc_write = (state == S_FETCH_BANK_2) ? 2'b11 : 2'b00;
            
        end else if (state == S_MV_READ) begin

            /*
                addr[7:0] <- mem[X]
                X <- X +/- 1
            */

            s.mem_addr_src = C_MA_X; // {dbr, x}
            s.mem_read = 1'b1;
            
            s.addr_wdata_src = C_AW_RD; // mem_rdata
            s.addr_write[L] = 1'b1;

            s.alu_a_src = C_AA_X; // x
            s.alu_b_src = C_AB_1; // 1
            s.alu_control = (addressing == A_MVP) ? C_ACTL_SUB : C_ACTL_ADD; // SUB/ADD

            s.reg_wdata_src = C_RW_ALUY; // alu_y
            s.x_write = 2'b11;

        end else if (state == S_MV_WRITE) begin

            /*
                mem[Y] <- addr[7:0]
                Y <- Y +/- 1
            */

            s.mem_addr_src = C_MA_Y; // {dbr, y}
            s.mem_wdata_src = C_MW_ADDRL; // addr[7:0]
            s.mem_write = 1'b1;

            s.alu_a_src = C_AA_Y; // y
            s.alu_b_src = C_AB_1; // 1
            s.alu_control = (addressing == A_MVP) ? C_ACTL_SUB : C_ACTL_ADD; // SUB/ADD

            s.reg_wdata_src = C_RW_ALUY; // alu_y
            s.y_write = 2'b11;

        end else if (state == S_DEC_A) begin

            /*
                A <- A - 1
            */

            s.alu_a_src = C_AA_A; // a
            s.alu_b_src = C_AB_1; // 1
            s.alu_control = C_ACTL_SUB; // SUB

            s.reg_wdata_src = C_RW_ALUY; // alu_y
            s.a_write = 2'b11;

        end else if (state == S_MV_LOOP) begin

            /*
                A!= FFFFならばPC-=2, そうでなければPC++
            */

            s.alu_a_src = C_AA_PC; // pc
            s.alu_b_src = C_AB_2; // 2
            s.alu_control = C_ACTL_SUB; // SUB

            s.pc_wdata_src = a_max ? C_PCW_PC_1 : C_PCW_ALUY; // pc+1/alu_y
            s.pc_write = 2'b11;

        end else if (state == S_OP_CALC) begin
            ;
        end else begin
            ;
        end
    end
    
endmodule
