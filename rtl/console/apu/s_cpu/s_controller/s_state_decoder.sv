// ========================================
//  State Decoder in SPC700 CPU Controller
// ========================================

// Copyright(C) 2024 ep2k All Rights Reserved.

module s_state_decoder
    import s_cpu_pkg::*;
(
    input state_type state,
    input instruction_type instruction,

    output ctl_signals_type ctl_signals
);

    instruction_type i;
    ctl_signals_type s;

    assign i = instruction;
    assign ctl_signals = s;

    always_comb begin

        s.mem_addr_src = SC_MA_PC;
        s.mem_read = 1'b0;
        s.mem_write = 1'b0;

        s.wdata_src = SC_W_ALUY;
        s.reg1_write = 1'b0;
        s.reg2_write = 1'b0;
        s.op_write = 1'b0;
        s.temp_write = 1'b0;

        s.psw_wdata_src = SC_PW_ALUF;
        s.psw_write = 8'h0;

        s.pc_wdata_src = SC_PCW_PC_1;
        s.pc_write = 2'b00;

        s.addr_wdata_src = SC_AW_ALUY;
        s.addr_write = 2'b00;

        s.alu_a_src = SC_AA_REG1;
        s.alu_b_src = SC_AB_0;
        s.alu_c_src = SC_AC_C;
        s.alu_control = SC_ACTL_ADD;
        s.alu_bit8 = 1'b0;
        s.c2_write = 1'b0;

        s.bitalu_b_src = SC_BAB_OP75;
        s.bitalu_control = SC_BACTL_AND1_C;

        s.daas_control = SC_DACTL_DAA;

        s.mul_init = 1'b0;
        s.mul = 1'b0;
        s.div_init = 1'b0;
        s.div = 1'b0;
        s.div_last = 1'b0;

        if ((state == SS_OPFETCH) | (state == SS_ADLFETCH) | (state == SS_ADHFETCH) | (state == SS_TEMPFETCH)) begin
            
            // op/addr[7:0]/addr[15:8]/temp <- mem[PC++]

            s.mem_addr_src = SC_MA_PC;
            s.mem_read = 1'b1;

            s.addr_wdata_src = SC_AW_RD;
            s.wdata_src = SC_W_RD;

            s.op_write = (state == SS_OPFETCH);
            s.addr_write[0] = (state == SS_ADLFETCH);
            s.addr_write[1] = (state == SS_ADHFETCH);
            s.temp_write = (state == SS_TEMPFETCH);
            
            // s.alu_a_src = SC_AA_PC;
            // s.alu_b_src = SC_AB_1;
            // s.alu_control = SC_ACTL_ADD;
            // s.alu_bit8 = 1'b0;
            // s.pc_wdata_src = SC_PCW_ALUY;
            s.pc_wdata_src = SC_PCW_PC_1;
            s.pc_write = 2'b11;

        end else if (state == SS_READ_MEMDP) begin
            
            // mem[dp]

            s.mem_addr_src = SC_MA_DP;
            s.mem_read = 1'b1;

        end else if ((state == SS_COPY_REG1_REG2) | (state == SS_COPY_REG1_MEMSR)) begin
            
            // reg1 <- reg2/mem[01, reg2]

            s.mem_addr_src = SC_MA_SR2;
            s.mem_read = (state == SS_COPY_REG1_MEMSR);

            s.alu_a_src = (state == SS_COPY_REG1_REG2) ? SC_AA_REG2 : SC_AA_RD;
            s.alu_b_src = SC_AB_0;
            s.alu_control = SC_ACTL_ADD;
            s.alu_bit8 = 1'b1;

            s.wdata_src = SC_W_ALUY;
            s.reg1_write = 1'b1;

            s.psw_wdata_src = SC_PW_ALUF;
            {s.psw_write[N], s.psw_write[Z]} = (i == SI_MOV) ? 2'b11 : 2'b00;

        end else if ((state == SS_COPY_MEMDR_TEMP) | (state == SS_COPY_MEMDP_TEMP) | (state == SS_COPY_MEMDP1_TEMP) | (state == SS_COPY_MEMABS_TEMP) | (state == SS_COPY_MEMABSMINI_TEMP)) begin
            
            // mem[reg2]/mem[dp]/mem[dp+1]/mem[abs]/mem[abs mini] <- temp

            case (state)
                SS_COPY_MEMDR_TEMP: s.mem_addr_src = SC_MA_DR2;
                SS_COPY_MEMDP_TEMP: s.mem_addr_src = SC_MA_DP;
                SS_COPY_MEMDP1_TEMP: s.mem_addr_src = SC_MA_DP_1;
                SS_COPY_MEMABS_TEMP: s.mem_addr_src = SC_MA_ABS;
                SS_COPY_MEMABSMINI_TEMP: s.mem_addr_src = SC_MA_ABSMINI;
                default: ;
            endcase

            s.alu_a_src = SC_AA_TEMP;
            s.alu_b_src = SC_AB_0;
            s.alu_control = SC_ACTL_ADD;
            s.alu_bit8 = 1'b1;
            s.wdata_src = SC_W_ALUY;
            s.mem_write = 1'b1;

        end else if ((state == SS_COPY_MEMDP_REG1) | (state == SS_COPY_MEMSR_REG1)) begin
            
            // mem[dp]/mem[01, reg2] <- reg1

            s.mem_addr_src = (state == SS_COPY_MEMDP_REG1) ? SC_MA_DP : SC_MA_SR2;
            s.alu_a_src = SC_AA_REG1;
            s.alu_b_src = SC_AB_0;
            s.alu_control = SC_ACTL_ADD;
            s.alu_bit8 = 1'b1;
            s.wdata_src = SC_W_ALUY;
            s.mem_write = 1'b1;

        end else if (state == SS_COPY_MEMDP1_REG2) begin
            
            // mem[dp+1] <- reg2

            s.mem_addr_src = SC_MA_DP_1;
            s.alu_a_src = SC_AA_REG2;
            s.alu_b_src = SC_AB_0;
            s.alu_control = SC_ACTL_ADD;
            s.alu_bit8 = 1'b1;
            s.wdata_src = SC_W_ALUY;
            s.mem_write = 1'b1;

        end else if ((state == SS_COPY_MEMSRP2_PCH) | (state == SS_COPY_MEMSRP1_PCL) | (state == SS_COPY_MEMSR_PSW)) begin
            
            // mem[01, reg2+2] <- pc[15:8]
            // mem[01, reg2+1] <- pc[7:0]
            // mem[01, reg2] <- psw

            case (state)
                SS_COPY_MEMSRP2_PCH: {s.mem_addr_src, s.wdata_src} = {SC_MA_SR2_2, SC_W_PCH};
                SS_COPY_MEMSRP1_PCL: {s.mem_addr_src, s.wdata_src} = {SC_MA_SR2_1, SC_W_PCL};
                SS_COPY_MEMSR_PSW: {s.mem_addr_src, s.wdata_src} = {SC_MA_SR2, SC_W_PSW};
                default: ;
            endcase

            s.mem_write = 1'b1;

        end else if ((state == SS_COPY_ADL_MEMDT) | (state == SS_COPY_ADL_MEMFFDE)) begin

            // addr[7:0] <- mem[temp]/mem[FFDE-{op[7:4],1'b0}]

            s.mem_addr_src = (state == SS_COPY_ADL_MEMDT)
                        ? SC_MA_DT : SC_MA_FFDE;
            s.mem_read = 1'b1;

            s.addr_wdata_src = SC_AW_RD;
            s.addr_write[0] = 1'b1;
            
        end else if ((state == SS_COPY_ADH_MEMDT1) | (state == SS_COPY_ADH_MEMFFDF)) begin

            // addr[15:8] <- mem[temp+1]/mem[FFDF-{op[7:4], 1'b0}]

            s.mem_addr_src = (state == SS_COPY_ADH_MEMDT1)
                        ? SC_MA_DT_1 : SC_MA_FFDF;
            s.mem_read = 1'b1;

            s.addr_wdata_src = SC_AW_RD;
            s.addr_write[1] = 1'b1;
            
        end else if ((state == SS_COPY_PCL_MEMSRP1) | (state == SS_COPY_PCL_MEMFFDE)) begin
            
            // pc[7:0] <- mem[01, reg2+1]/mem[FFDE-{op[7:4], 1'b0}]

            s.mem_addr_src = (state == SS_COPY_PCL_MEMSRP1)
                        ? SC_MA_SR2_1 : SC_MA_FFDE;
            s.mem_read = 1'b1;

            s.pc_wdata_src = SC_PCW_RD;
            s.pc_write[0] = 1'b1;

        end else if ((state == SS_COPY_PCH_MEMSRP2) | (state == SS_COPY_PCH_MEMFFDF)) begin
            
            // pc[15:8] <- mem[01, reg2+2]/mem[FFDF-{op[7:4], 1'b0}]

            s.mem_addr_src = (state == SS_COPY_PCH_MEMSRP2)
                        ? SC_MA_SR2_2 : SC_MA_FFDF;
            s.mem_read = 1'b1;

            s.pc_wdata_src = SC_PCW_RD;
            s.pc_write[1] = 1'b1;

        end else if ((state == SS_COPY_PC_ADDR) | (state == SS_COPY_PC_FF_ADL) | (state == SS_COPY_PC_MEMABS1_TEMP) | (state == SS_COPY_PC_FETCH_TEMP)) begin

            // pc <- addr/{FF, addr[7:0]}/{mem[addr+1], temp}/{mem[PC],temp}

            s.mem_addr_src = (state == SS_COPY_PC_MEMABS1_TEMP)
                        ? SC_MA_ABS_1 : SC_MA_PC;
            s.mem_read = ((state == SS_COPY_PC_MEMABS1_TEMP)
                            | (state == SS_COPY_PC_FETCH_TEMP));
            
            s.alu_a_src = SC_AA_ADDR;
            s.alu_b_src = SC_AB_0;
            s.alu_control = SC_ACTL_ADD;
            s.alu_bit8 = 1'b0;

            case (state)
                SS_COPY_PC_ADDR: s.pc_wdata_src = SC_PCW_ALUY;
                SS_COPY_PC_FF_ADL: s.pc_wdata_src = SC_PCW_FF_ADL;
                default: s.pc_wdata_src = SC_PCW_RD_TEMP;
            endcase

            s.pc_write = 2'b11;
            
        end else if (state == SS_COPY_PSW_MEMSR) begin
            
            // psw <- mem[01, reg2]

            s.mem_addr_src = SC_MA_SR2;
            s.mem_read = 1'b1;

            s.psw_wdata_src = SC_PW_RD;
            s.psw_write = 8'hff;

        end else if (state == SS_COPY_TEMP_REG1) begin
            
            // temp <- reg1

            s.alu_a_src = SC_AA_REG1;
            s.alu_b_src = SC_AB_0;
            s.alu_control = SC_ACTL_ADD;
            s.alu_bit8 = 1'b1;

            s.wdata_src = SC_W_ALUY;
            s.temp_write = 1'b1;

        end else if ((state == SS_COPY_TEMP_MEMDR1) | (state == SS_COPY_TEMP_MEMDP) | (state == SS_COPY_TEMP_MEMDP2) | (state == SS_COPY_TEMP_MEMDP_M1) | (state == SS_COPY_TEMP_MEMABS)) begin
            
            // temp <- mem[reg1]/mem[dp]/mem[dp2]/mem[dp]-1/mem[abs]

            case (state)
                SS_COPY_TEMP_MEMDR1: s.mem_addr_src = SC_MA_DR1;
                SS_COPY_TEMP_MEMDP: s.mem_addr_src = SC_MA_DP;
                SS_COPY_TEMP_MEMDP2: s.mem_addr_src = SC_MA_DP2;
                SS_COPY_TEMP_MEMDP_M1: s.mem_addr_src = SC_MA_DP;
                SS_COPY_TEMP_MEMABS: s.mem_addr_src = SC_MA_ABS;
                default: ;
            endcase

            s.mem_read = 1'b1;

            s.alu_a_src = SC_AA_RD;
            s.alu_b_src = (state == SS_COPY_TEMP_MEMDP_M1)
                        ? SC_AB_1 : SC_AB_0;
            s.alu_control = SC_ACTL_SUB;
            s.alu_bit8 = 1'b1;

            s.wdata_src = SC_W_ALUY;
            s.temp_write = 1'b1;

        end else if ((state == SS_CALC_REG1_MEMPC) | (state == SS_CALC_REG1_MEMDR) | (state == SS_CALC_REG1_MEMDP) | (state == SS_CALC_REG1_MEMABS)) begin
            
            // reg1 <- reg1 + mem[PC++]/mem[reg2]/mem[dp]/mem[abs]
            // reg1 <- mem[PC++]/mem[reg2]/mem[dp]/mem[abs] (MOV)

            case (state)
                SS_CALC_REG1_MEMPC: s.mem_addr_src = SC_MA_PC;
                SS_CALC_REG1_MEMDR: s.mem_addr_src = SC_MA_DR2;
                SS_CALC_REG1_MEMDP: s.mem_addr_src = SC_MA_DP;
                SS_CALC_REG1_MEMABS: s.mem_addr_src = SC_MA_ABS;
                default: ;
            endcase

            s.mem_read = 1'b1;
            
            s.pc_wdata_src = SC_PCW_PC_1;
            s.pc_write = (state == SS_CALC_REG1_MEMPC) ? 2'b11 : 2'b00;

            s.alu_a_src = (i == SI_MOV) ? SC_AA_RD : SC_AA_REG1;
            s.alu_b_src = (i == SI_MOV) ? SC_AB_0 : SC_AB_RD;
            s.alu_c_src = SC_AC_C;
            s.alu_bit8 = 1'b1;

            s.wdata_src = SC_W_ALUY;
            s.reg1_write = (i != SI_CMP);

            s.psw_wdata_src = SC_PW_ALUF;

            case (i)
                SI_MOV: begin
                        s.alu_control = SC_ACTL_ADD;
                        s.psw_write[N] = 1'b1;
                        s.psw_write[Z] = 1'b1;
                    end
                SI_ADC: begin
                        s.alu_control = SC_ACTL_ADC;
                        s.psw_write[N] = 1'b1;
                        s.psw_write[V] = 1'b1;
                        s.psw_write[H] = 1'b1;
                        s.psw_write[Z] = 1'b1;
                        s.psw_write[C] = 1'b1;
                    end
                SI_ADD: begin
                        s.alu_control = SC_ACTL_ADD;
                        s.psw_write[N] = 1'b1;
                        s.psw_write[V] = 1'b1;
                        s.psw_write[H] = 1'b1;
                        s.psw_write[Z] = 1'b1;
                        s.psw_write[C] = 1'b1;
                    end
                SI_SBC: begin
                        s.alu_control = SC_ACTL_SBC;
                        s.psw_write[N] = 1'b1;
                        s.psw_write[V] = 1'b1;
                        s.psw_write[H] = 1'b1;
                        s.psw_write[Z] = 1'b1;
                        s.psw_write[C] = 1'b1;
                    end
                SI_SUB: begin
                        s.alu_control = SC_ACTL_SUB;
                        s.psw_write[N] = 1'b1;
                        s.psw_write[V] = 1'b1;
                        s.psw_write[H] = 1'b1;
                        s.psw_write[Z] = 1'b1;
                        s.psw_write[C] = 1'b1;
                    end
                SI_CMP: begin
                        s.alu_control = SC_ACTL_SUB;
                        s.psw_write[N] = 1'b1;
                        s.psw_write[Z] = 1'b1;
                        s.psw_write[C] = 1'b1;
                    end
                SI_AND: begin
                        s.alu_control = SC_ACTL_AND;
                        s.psw_write[N] = 1'b1;
                        s.psw_write[Z] = 1'b1;
                    end
                SI_OR: begin
                        s.alu_control = SC_ACTL_OR;
                        s.psw_write[N] = 1'b1;
                        s.psw_write[Z] = 1'b1;
                    end
                SI_EOR: begin
                        s.alu_control = SC_ACTL_EOR;
                        s.psw_write[N] = 1'b1;
                        s.psw_write[Z] = 1'b1;
                    end
                default: ;
            endcase

        end else if ((state == SS_CALC_TEMP_MEMDR) | (state == SS_CALC_TEMP_MEMDP)) begin

            // temp <- mem[reg2]/mem[dp] + temp
            // temp <- temp (SI_MOV)

            case (state)
                SS_CALC_TEMP_MEMDR: s.mem_addr_src = SC_MA_DR2;
                SS_CALC_TEMP_MEMDP: s.mem_addr_src = SC_MA_DP;
                default: ;
            endcase

            s.mem_read = (i != SI_MOV);

            s.alu_a_src = (i == SI_MOV) ? SC_AA_TEMP : SC_AA_RD;
            s.alu_b_src = (i == SI_MOV) ? SC_AB_0 : SC_AB_TEMP;
            s.alu_c_src = SC_AC_C;
            s.alu_bit8 = 1'b1;

            s.wdata_src = SC_W_ALUY;
            s.temp_write = (i != SI_CMP);

            s.psw_wdata_src = SC_PW_ALUF;

            case (i)
                SI_MOV: begin
                        s.alu_control = SC_ACTL_ADD;
                    end
                SI_ADC: begin
                        s.alu_control = SC_ACTL_ADC;
                        s.psw_write[N] = 1'b1;
                        s.psw_write[V] = 1'b1;
                        s.psw_write[H] = 1'b1;
                        s.psw_write[Z] = 1'b1;
                        s.psw_write[C] = 1'b1;
                    end
                SI_SBC: begin
                        s.alu_control = SC_ACTL_SBC;
                        s.psw_write[N] = 1'b1;
                        s.psw_write[V] = 1'b1;
                        s.psw_write[H] = 1'b1;
                        s.psw_write[Z] = 1'b1;
                        s.psw_write[C] = 1'b1;
                    end
                SI_CMP: begin
                        s.alu_control = SC_ACTL_SUB;
                        s.psw_write[N] = 1'b1;
                        s.psw_write[Z] = 1'b1;
                        s.psw_write[C] = 1'b1;
                    end
                SI_AND: begin
                        s.alu_control = SC_ACTL_AND;
                        s.psw_write[N] = 1'b1;
                        s.psw_write[Z] = 1'b1;
                    end
                SI_OR: begin
                        s.alu_control = SC_ACTL_OR;
                        s.psw_write[N] = 1'b1;
                        s.psw_write[Z] = 1'b1;
                    end
                SI_EOR: begin
                        s.alu_control = SC_ACTL_EOR;
                        s.psw_write[N] = 1'b1;
                        s.psw_write[Z] = 1'b1;
                    end
                default: ;
            endcase
            
        end else if (state == SS_CALC_REG2_MEMDP1) begin
            
            // reg2 <- reg2 + mem[dp+1] (16bit演算用)

            s.mem_addr_src = SC_MA_DP_1;
            s.mem_read = 1'b1;

            s.alu_a_src = (i == SI_MOV) ? SC_AA_RD : SC_AA_REG2;
            s.alu_b_src = (i == SI_MOV) ? SC_AB_0 : SC_AB_RD;
            s.alu_c_src = SC_AC_C;
            s.alu_bit8 = 1'b1;

            s.wdata_src = SC_W_ALUY;
            s.reg2_write = (i != SI_CMP);

            s.psw_wdata_src = SC_PW_ALUF2;

            case (i)
                SI_MOV: begin
                        s.alu_control = SC_ACTL_ADD;
                        s.psw_write[N] = 1'b1;
                        s.psw_write[Z] = 1'b1;
                    end
                SI_ADC: begin
                        s.alu_control = SC_ACTL_ADC;
                        s.psw_write[N] = 1'b1;
                        s.psw_write[V] = 1'b1;
                        s.psw_write[Z] = 1'b1;
                        s.psw_write[C] = 1'b1;
                    end
                SI_ADD: begin
                        s.alu_control = SC_ACTL_ADC;
                        s.psw_write[N] = 1'b1;
                        s.psw_write[V] = 1'b1;
                        s.psw_write[Z] = 1'b1;
                        s.psw_write[C] = 1'b1;
                    end
                SI_SBC: begin
                        s.alu_control = SC_ACTL_SBC;
                        s.psw_write[N] = 1'b1;
                        s.psw_write[V] = 1'b1;
                        s.psw_write[Z] = 1'b1;
                        s.psw_write[C] = 1'b1;
                    end
                SI_SUB: begin
                        s.alu_control = SC_ACTL_SBC;
                        s.psw_write[N] = 1'b1;
                        s.psw_write[V] = 1'b1;
                        s.psw_write[Z] = 1'b1;
                        s.psw_write[C] = 1'b1;
                    end
                SI_CMP: begin
                        s.alu_control = SC_ACTL_SBC;
                        s.psw_write[N] = 1'b1;
                        s.psw_write[Z] = 1'b1;
                        s.psw_write[C] = 1'b1;
                    end
                default: ;
            endcase

        end else if ((state == SS_CALC_REG1) | (state == SS_CALC_MEMDP) | (state == SS_CALC_MEMDP1) | (state == SS_CALC_MEMABS)) begin

            // reg1/temp <- reg1/mem[dp]/mem[dp+1]/mem[abs] + 1

            case (state)
                SS_CALC_MEMDP: s.mem_addr_src = SC_MA_DP;
                SS_CALC_MEMDP1: s.mem_addr_src = SC_MA_DP_1;
                SS_CALC_MEMABS: s.mem_addr_src = SC_MA_ABS;
                default: ;
            endcase

            s.mem_read = (state != SS_CALC_REG1);

            s.alu_a_src = (state == SS_CALC_REG1) ? SC_AA_REG1 : SC_AA_RD;
            s.alu_b_src = (state == SS_CALC_MEMDP1) ? SC_AB_0 : SC_AB_1;
            s.alu_c_src = (state == SS_CALC_MEMDP1) ? SC_AC_C2 : SC_AC_C;
            s.alu_bit8 = 1'b1;
            s.c2_write = 1'b1;

            s.wdata_src = SC_W_ALUY;
            s.reg1_write = (state == SS_CALC_REG1);
            s.temp_write = (state != SS_CALC_REG1);

            s.psw_wdata_src = (state == SS_CALC_MEMDP1) ? SC_PW_ALUF2 : SC_PW_ALUF;

            case (i)
                SI_INC: begin
                        s.alu_control = (state == SS_CALC_MEMDP1)
                                ? SC_ACTL_ADC : SC_ACTL_ADD;
                        s.psw_write[N] = 1'b1;
                        s.psw_write[Z] = 1'b1;
                    end
                SI_DEC: begin
                        s.alu_control = (state == SS_CALC_MEMDP1)
                                ? SC_ACTL_SBC : SC_ACTL_SUB;
                        s.psw_write[N] = 1'b1;
                        s.psw_write[Z] = 1'b1;
                    end
                SI_ASL: begin
                        s.alu_control = SC_ACTL_ASL;
                        s.psw_write[N] = 1'b1;
                        s.psw_write[Z] = 1'b1;
                        s.psw_write[C] = 1'b1;
                    end
                SI_LSR: begin
                        s.alu_control = SC_ACTL_LSR;
                        s.psw_write[N] = 1'b1;
                        s.psw_write[Z] = 1'b1;
                        s.psw_write[C] = 1'b1;
                    end
                SI_ROL: begin
                        s.alu_control = SC_ACTL_ROL;
                        s.psw_write[N] = 1'b1;
                        s.psw_write[Z] = 1'b1;
                        s.psw_write[C] = 1'b1;
                    end
                SI_ROR: begin
                        s.alu_control = SC_ACTL_ROR;
                        s.psw_write[N] = 1'b1;
                        s.psw_write[Z] = 1'b1;
                        s.psw_write[C] = 1'b1;
                    end
                default: ;
            endcase
            
        end else if (state == SS_SC1_DP) begin
            
            // temp <- mem[dp]の第op[7:4]bitを0/1にしたもの

            s.mem_addr_src = SC_MA_DP;
            s.mem_read = 1'b1;

            s.bitalu_b_src = SC_BAB_OP75;
            s.bitalu_control = (i == SI_SET1) ? SC_BACTL_SET1 : SC_BACTL_CLR1;

            s.wdata_src = SC_W_BITALUY;
            s.temp_write = 1'b1;

        end else if (state == SS_TSC_ABS_1) begin
            
            // temp <- mem[abs]
            // reg1 - mem[abs] // [TODO] SUB?

            s.mem_addr_src = SC_MA_ABS;
            s.mem_read = 1'b1;

            s.wdata_src = SC_W_RD;
            s.temp_write = 1'b1;

            s.alu_a_src = SC_AA_REG1;
            s.alu_b_src = SC_AB_RD;
            s.alu_control = SC_ACTL_SUB;
            s.alu_bit8 = 1'b1;

            s.psw_wdata_src = SC_PW_ALUF;
            {s.psw_write[N], s.psw_write[Z]} = 2'b11;

        end else if (state == SS_TSC_ABS_2) begin
            
            // temp <- reg1 OR/CLR temp

            s.alu_a_src = SC_AA_REG1;
            s.alu_b_src = SC_AB_TEMP;
            s.alu_control = (i == SI_TSET) ? SC_ACTL_OR : SC_ACTL_CLR;
            s.alu_bit8 = 1'b1;

            s.wdata_src = SC_W_ALUY;
            s.temp_write = 1'b1;

        end else if (state == SS_CALC1_C_ABS) begin
            
            // p[C] <- BITALU(mem[addr[12:0]], addr[15:13])

            s.mem_addr_src = SC_MA_ABSMINI;
            s.mem_read = 1'b1;

            s.bitalu_b_src = SC_BAB_ADDR1513;
            
            case (i)
                SI_AND1: s.bitalu_control = SC_BACTL_AND1_C;
                SI_AND1_N: s.bitalu_control = SC_BACTL_AND1_N_C;
                SI_OR1: s.bitalu_control = SC_BACTL_OR1_C;
                SI_OR1_N: s.bitalu_control = SC_BACTL_OR1_N_C;
                SI_EOR1: s.bitalu_control = SC_BACTL_EOR1_C;
                SI_MOV1: s.bitalu_control = SC_BACTL_MOV1_C;
                default: ;
            endcase

            s.psw_wdata_src = SC_PW_BITALUC;
            s.psw_write[C] = 1'b1;

        end else if (state == SS_CALC1_ABS_C) begin
            
            // temp <- BITALU(mem[addr[12:0]], addr[15:13])

            s.mem_addr_src = SC_MA_ABSMINI;
            s.mem_read = 1'b1;

            s.bitalu_b_src = SC_BAB_ADDR1513;
            
            case (i)
                SI_NOT1: s.bitalu_control = SC_BACTL_NOT1;
                SI_MOV1: s.bitalu_control = SC_BACTL_MOV1_C;
                default: ;
            endcase

            s.wdata_src = SC_W_BITALUY;
            s.temp_write = 1'b1;

        end else if (state == SS_ADD_ADDR_REG2) begin
            
            // addr <- addr + reg2

            s.alu_a_src = SC_AA_ADDR;
            s.alu_b_src = SC_AB_REG2;
            s.alu_control = SC_ACTL_ADD;
            s.alu_bit8 = 1'b0;

            s.addr_wdata_src = SC_AW_ALUY;
            s.addr_write = 2'b11;

        end else if (state == SS_ADD_TEMP_REG2) begin
            
            // temp <- temp + reg2

            s.alu_a_src = SC_AA_TEMP;
            s.alu_b_src = SC_AB_REG2;
            s.alu_control = SC_ACTL_ADD;
            s.alu_bit8 = 1'b1;

            s.wdata_src = SC_W_ALUY;
            s.temp_write = 1'b1;

        end else if (state == SS_ADD_PC_TEMP) begin
            
            // pc <- pc + temp

            s.alu_a_src = SC_AA_PC;
            s.alu_b_src = SC_AB_TEMP;
            s.alu_control = SC_ACTL_ADD;
            s.alu_bit8 = 1'b0;

            s.pc_wdata_src = SC_PCW_ALUY;
            s.pc_write = 2'b11;

        end else if (state == SS_SUB_REG1_TEMP) begin
            
            // reg1 - temp

            s.alu_a_src = SC_AA_REG1;
            s.alu_b_src = SC_AB_TEMP;
            s.alu_control = SC_ACTL_SUB;
            s.alu_bit8 = 1'b1;

        end else if (state == SS_XCN_REG1) begin
            
            // reg1 <- {reg1[3:0], reg1[7:4]}
            
            s.alu_a_src = SC_AA_REG1_XCN;
            s.alu_b_src = SC_AB_0;
            s.alu_control = SC_ACTL_ADD;
            s.alu_bit8 = 1'b1;

            s.wdata_src = SC_W_ALUY;
            s.reg1_write = 1'b1;

            s.psw_wdata_src = SC_PW_ALUF;
            {s.psw_write[N], s.psw_write[Z]} = 2'b11;

        end else if ((state == SS_REG2_INC) | (state == SS_REG2_DEC) | (state == SS_REG2_INC2) | (state == SS_REG2_DEC2)) begin
            
            // reg2 <- reg2 +/- 1/2

            s.alu_a_src = SC_AA_REG2;
            s.alu_b_src = ((state == SS_REG2_INC) | (state == SS_REG2_DEC))
                            ? SC_AB_1 : SC_AB_2;
            s.alu_control = ((state == SS_REG2_INC) | (state == SS_REG2_INC2))
                            ? SC_ACTL_ADD : SC_ACTL_SUB;
            s.alu_bit8 = 1'b1;

            s.wdata_src = SC_W_ALUY;
            s.reg2_write = 1'b1;

        end else if ((state == SS_PC_INC) | (state == SS_PC_INC_BRKSET)) begin
            
            // pc <- pc + 1

            // s.alu_a_src = SC_AA_PC;
            // s.alu_b_src = SC_AB_1;
            // s.alu_control = SC_ACTL_ADD;
            // s.alu_bit8 = 1'b0;

            // s.pc_wdata_src = SC_PCW_ALUY;
            s.pc_wdata_src = SC_PCW_PC_1;
            s.pc_write = 2'b11;

            s.psw_wdata_src = SC_PW_BRK;
            {s.psw_write[B], s.psw_write[I]}
                = (state == SS_PC_INC_BRKSET) ? 2'b11 : 2'b00;

        end else if (state == SS_PSW_CHANGE) begin
            
            // p[?] <- ?

            case (i)
                SI_CLRC: begin
                        s.psw_wdata_src = SC_PW_0;
                        s.psw_write[C] = 1'b1;
                    end
                SI_SETC: begin
                        s.psw_wdata_src = SC_PW_FF;
                        s.psw_write[C] = 1'b1;
                    end
                SI_NOTC: begin
                        s.psw_wdata_src = SC_PW_NOTC;
                        s.psw_write[C] = 1'b1;
                    end
                SI_CLRV: begin
                        s.psw_wdata_src = SC_PW_0;
                        s.psw_write[V] = 1'b1;
                        s.psw_write[H] = 1'b1;
                    end
                SI_CLRP: begin
                        s.psw_wdata_src = SC_PW_0;
                        s.psw_write[P] = 1'b1;
                    end
                SI_SETP: begin
                        s.psw_wdata_src = SC_PW_FF;
                        s.psw_write[P] = 1'b1;
                    end
                SI_EI: begin
                        s.psw_wdata_src = SC_PW_FF;
                        s.psw_write[I] = 1'b1;
                    end
                SI_DI: begin
                        s.psw_wdata_src = SC_PW_0;
                        s.psw_write[I] = 1'b1;
                    end
                default: ;
            endcase

        end else if (state == SS_MUL_INIT) begin
            
            // mul_init

            s.mul_init = 1'b1;

        end else if ((state == SS_MUL_0) | (state == SS_MUL_1) | (state == SS_MUL_2) | (state == SS_MUL_3) | (state == SS_MUL_4) | (state == SS_MUL_5) | (state == SS_MUL_6)) begin
            
            // mul

            s.mul = 1'b1;

        end else if (state == SS_DIV_INIT) begin
            
            // div_init
            // reg1 - reg2

            s.div_init = 1'b1;

            s.alu_a_src = SC_AA_REG1;
            s.alu_b_src = SC_AB_REG2;
            s.alu_control = SC_ACTL_SUB;
            s.alu_bit8 = 1'b1;

            s.psw_wdata_src = SC_PW_ALUF;
            s.psw_write[1] = 1'b1;

        end else if ((state == SS_DIV_0) | (state == SS_DIV_1) | (state == SS_DIV_2) | (state == SS_DIV_3) | (state == SS_DIV_4) | (state == SS_DIV_5) | (state == SS_DIV_6) | (state == SS_DIV_7) | (state == SS_DIV_8)) begin
            
            // div, reg1-temp

            s.div = 1'b1;

            s.alu_a_src = SC_AA_REG1;
            s.alu_b_src = SC_AB_TEMP;
            s.alu_control = SC_ACTL_SUB;
            s.alu_bit8 = 1'b1;
        
        end else if (state == SS_DIV_LAST) begin
            
            // div_last

            s.div_last = 1'b1;

        end else if (state == SS_DAAS) begin
            
            // reg1, PSW <- daas(reg1, PSW)

            s.daas_control = (i == SI_DAA) ? SC_DACTL_DAA : SC_DACTL_DAS;
            s.wdata_src = SC_W_DAASY;
            s.reg1_write = 1'b1;

            s.psw_wdata_src = SC_PW_DAASF;
            {s.psw_write[N], s.psw_write[Z], s.psw_write[C]} = 3'b111;

        end else begin
            ;
        end
        
    end
    
endmodule
