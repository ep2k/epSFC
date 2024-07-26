// ==================================================
//  next_state Detector in SPC700 CPU Controller
// ==================================================

// Copyright(C) 2024 ep2k All Rights Reserved.

module s_next_state_detector
    import s_cpu_pkg::*;
(
    input state_type state,
    input addressing_type addressing,
    input instruction_type instruction,

    input logic cond_false,
    input logic reg2_0,
    input logic flgz,
    input logic temp_0,
    input logic not_bsc,

    output state_type next_state
);

    addressing_type a;
    instruction_type i;

    assign a = addressing;
    assign i = instruction;

    always_comb begin
        
        if (a == SA_REG_REG) begin
            
            case (state)
                SS_OPFETCH: next_state = SS_COPY_REG1_REG2;
                SS_COPY_REG1_REG2: next_state = SS_OPFETCH;
                default: next_state = SS_ERROR;
            endcase

        end else if (a == SA_REG_IMM) begin
            
            case (state)
                SS_OPFETCH: next_state = SS_CALC_REG1_MEMPC;
                SS_CALC_REG1_MEMPC: next_state = SS_OPFETCH;
                default: next_state = SS_ERROR;
            endcase

        end else if ((a == SA_REG_DR) | (a == SA_REG_DRINC)) begin
            
            case (state)
                SS_OPFETCH: next_state = SS_CALC_REG1_MEMDR;
                SS_CALC_REG1_MEMDR: next_state = (a == SA_REG_DRINC) ? SS_REG2_INC : SS_NOP;
                SS_REG2_INC: next_state = SS_NOP;
                SS_NOP: next_state = SS_OPFETCH;
                default: next_state = SS_ERROR;
            endcase

        end else if ((a == SA_DR_REG) | (a == SA_DRINC_REG)) begin
            
            case (state)
                SS_OPFETCH: next_state = SS_COPY_TEMP_REG1;
                SS_COPY_TEMP_REG1: next_state = SS_COPY_MEMDR_TEMP;
                SS_COPY_MEMDR_TEMP: next_state = (a == SA_DRINC_REG) ? SS_REG2_INC : SS_NOP;
                SS_REG2_INC: next_state = SS_OPFETCH;
                SS_NOP: next_state = SS_OPFETCH;
                default: next_state = SS_ERROR;
            endcase

        end else if (a == SA_DR_DR) begin
            
            case (state)
                SS_OPFETCH: next_state = SS_COPY_TEMP_MEMDR1;
                SS_COPY_TEMP_MEMDR1: next_state = SS_CALC_TEMP_MEMDR;
                SS_CALC_TEMP_MEMDR: next_state = SS_COPY_MEMDR_TEMP;
                SS_COPY_MEMDR_TEMP: next_state = SS_NOP;
                SS_NOP: next_state = SS_OPFETCH;
                default: next_state = SS_ERROR;
            endcase

        end else if ((a == SA_REG_DP) | (a == SA_REG_DPR)) begin
            
            case (state)
                SS_OPFETCH: next_state = SS_ADLFETCH;
                SS_ADLFETCH: next_state = (a == SA_REG_DPR) ? SS_ADD_ADDR_REG2 : SS_CALC_REG1_MEMDP;
                SS_ADD_ADDR_REG2: next_state = SS_CALC_REG1_MEMDP;
                SS_CALC_REG1_MEMDP: next_state = SS_OPFETCH;
                default: next_state = SS_ERROR;
            endcase

        end else if ((a == SA_DP_REG) | (a == SA_DPR_REG)) begin
            
            case (state)
                SS_OPFETCH: next_state = SS_ADLFETCH;
                SS_ADLFETCH: next_state = (a == SA_DPR_REG) ? SS_ADD_ADDR_REG2 : SS_COPY_TEMP_REG1;
                SS_ADD_ADDR_REG2: next_state = SS_COPY_TEMP_REG1;
                SS_COPY_TEMP_REG1: next_state = SS_COPY_MEMDP_TEMP;
                SS_COPY_MEMDP_TEMP: next_state = SS_OPFETCH;
                default: next_state = SS_ERROR;
            endcase

        end else if ((a == SA_REG_ABS) | (a == SA_REG_ABSR)) begin
            
            case (state)
                SS_OPFETCH: next_state = SS_ADLFETCH;
                SS_ADLFETCH: next_state = SS_ADHFETCH;
                SS_ADHFETCH: next_state = (a == SA_REG_ABSR) ? SS_ADD_ADDR_REG2 : SS_CALC_REG1_MEMABS;
                SS_ADD_ADDR_REG2: next_state = SS_CALC_REG1_MEMABS;
                SS_CALC_REG1_MEMABS: next_state = SS_OPFETCH;
                default: next_state = SS_ERROR;
            endcase

        end else if ((a == SA_ABS_REG) | (a == SA_ABSR_REG)) begin
            
            case (state)
                SS_OPFETCH: next_state = SS_ADLFETCH;
                SS_ADLFETCH: next_state = SS_ADHFETCH;
                SS_ADHFETCH: next_state = (a == SA_ABSR_REG) ? SS_ADD_ADDR_REG2 : SS_COPY_TEMP_REG1;
                SS_ADD_ADDR_REG2: next_state = SS_COPY_TEMP_REG1;
                SS_COPY_TEMP_REG1: next_state = SS_COPY_MEMABS_TEMP;
                SS_COPY_MEMABS_TEMP: next_state = SS_OPFETCH;
                default: next_state = SS_ERROR;
            endcase

        end else if ((a == SA_REG_INDPR) | (a == SA_REG_INDP_R)) begin
            
            case (state)
                SS_OPFETCH: next_state = SS_TEMPFETCH;
                SS_TEMPFETCH: next_state = (a == SA_REG_INDPR) ? SS_ADD_TEMP_REG2 : SS_COPY_ADL_MEMDT;
                SS_ADD_TEMP_REG2: next_state = SS_COPY_ADL_MEMDT;
                SS_COPY_ADL_MEMDT: next_state = SS_COPY_ADH_MEMDT1;
                SS_COPY_ADH_MEMDT1: next_state = (a == SA_REG_INDP_R) ? SS_ADD_ADDR_REG2 : SS_CALC_REG1_MEMABS;
                SS_ADD_ADDR_REG2: next_state = SS_CALC_REG1_MEMABS;
                SS_CALC_REG1_MEMABS: next_state = SS_OPFETCH;
                default: next_state = SS_ERROR;
            endcase

        end else if ((a == SA_INDPR_REG) | (a == SA_INDP_R_REG)) begin
            
            case (state)
                SS_OPFETCH: next_state = SS_TEMPFETCH;
                SS_TEMPFETCH: next_state = (a == SA_INDPR_REG) ? SS_ADD_TEMP_REG2 : SS_COPY_ADL_MEMDT;
                SS_ADD_TEMP_REG2: next_state = SS_COPY_ADL_MEMDT;
                SS_COPY_ADL_MEMDT: next_state = SS_COPY_ADH_MEMDT1;
                SS_COPY_ADH_MEMDT1: next_state = (a == SA_INDP_R_REG) ? SS_ADD_ADDR_REG2 : SS_COPY_TEMP_REG1;
                SS_ADD_ADDR_REG2: next_state = SS_COPY_TEMP_REG1;
                SS_COPY_TEMP_REG1: next_state = SS_COPY_MEMABS_TEMP;
                SS_COPY_MEMABS_TEMP: next_state = SS_OPFETCH;
                default: next_state = SS_ERROR;
            endcase

        end else if (a == SA_DP_IMM) begin
            
            case (state)
                SS_OPFETCH: next_state = SS_TEMPFETCH;
                SS_TEMPFETCH: next_state = SS_ADLFETCH;
                SS_ADLFETCH: next_state = SS_CALC_TEMP_MEMDP;
                SS_CALC_TEMP_MEMDP: next_state = (i == SI_CMP)
                                    ? SS_NOP : SS_COPY_MEMDP_TEMP;
                SS_NOP: next_state = SS_OPFETCH;
                SS_COPY_MEMDP_TEMP: next_state = SS_OPFETCH;
                default: next_state = SS_ERROR;
            endcase

        end else if (a == SA_DP_DP) begin
            
            case (state)
                SS_OPFETCH: next_state = SS_ADHFETCH;
                SS_ADHFETCH: next_state = SS_ADLFETCH;
                SS_ADLFETCH: next_state = SS_COPY_TEMP_MEMDP2;
                SS_COPY_TEMP_MEMDP2: next_state = SS_CALC_TEMP_MEMDP;
                SS_CALC_TEMP_MEMDP: next_state = (i == SI_CMP)
                                    ? SS_NOP : SS_COPY_MEMDP_TEMP;
                SS_NOP: next_state = SS_OPFETCH;
                SS_COPY_MEMDP_TEMP: next_state = SS_OPFETCH;
                default: next_state = SS_ERROR;
            endcase

        end else if (a == SA_YA_DP16) begin
            
            case (state)
                SS_OPFETCH: next_state = SS_ADLFETCH;
                SS_ADLFETCH: next_state = SS_CALC_REG1_MEMDP;
                SS_CALC_REG1_MEMDP: next_state = SS_CALC_REG2_MEMDP1;
                SS_CALC_REG2_MEMDP1: next_state = (i == SI_CMP) ? SS_OPFETCH : SS_NOP;
                SS_NOP: next_state = SS_OPFETCH;
                default: next_state = SS_ERROR;
            endcase

        end else if (a == SA_DP16_YA) begin
            
            case (state)
                SS_OPFETCH: next_state = SS_ADLFETCH;
                SS_ADLFETCH: next_state = SS_COPY_MEMDP_REG1;
                SS_COPY_MEMDP_REG1: next_state = SS_COPY_MEMDP1_REG2;
                SS_COPY_MEMDP1_REG2: next_state = SS_OPFETCH;
                default: next_state = SS_ERROR;
            endcase

        end else if (a == SA_REG) begin
            
            case (state)
                SS_OPFETCH: next_state = SS_CALC_REG1;
                SS_CALC_REG1: next_state = SS_OPFETCH;
                default: next_state = SS_ERROR;
            endcase

        end else if ((a == SA_DP) | (a == SA_DPR)) begin
            
            case (state)
                SS_OPFETCH: next_state = SS_ADLFETCH;
                SS_ADLFETCH: next_state = (a == SA_DPR) ? SS_ADD_ADDR_REG2 : SS_CALC_MEMDP;
                SS_ADD_ADDR_REG2: next_state = SS_CALC_MEMDP;
                SS_CALC_MEMDP: next_state = SS_COPY_MEMDP_TEMP;
                SS_COPY_MEMDP_TEMP: next_state = SS_OPFETCH;
                default: next_state = SS_ERROR;
            endcase

        end else if (a == SA_ABS) begin
            
            case (state)
                SS_OPFETCH: next_state = SS_ADLFETCH;
                SS_ADLFETCH: next_state = SS_ADHFETCH;
                SS_ADHFETCH: next_state = SS_CALC_MEMABS;
                SS_CALC_MEMABS: next_state = SS_COPY_MEMABS_TEMP;
                SS_COPY_MEMABS_TEMP: next_state = SS_OPFETCH;
                default: next_state = SS_ERROR;
            endcase

        end else if (a == SA_DP16) begin
            
            case (state)
                SS_OPFETCH: next_state = SS_ADLFETCH;
                SS_ADLFETCH: next_state = SS_CALC_MEMDP;
                SS_CALC_MEMDP: next_state = SS_COPY_MEMDP_TEMP;
                SS_COPY_MEMDP_TEMP: next_state = SS_CALC_MEMDP1;
                SS_CALC_MEMDP1: next_state = SS_COPY_MEMDP1_TEMP;
                SS_COPY_MEMDP1_TEMP: next_state = SS_OPFETCH;
                default: next_state = SS_ERROR;
            endcase

        end else if (a == SA_JMP_IMM) begin
            
            case (state)
                SS_OPFETCH: next_state = SS_TEMPFETCH;
                SS_TEMPFETCH: next_state = SS_COPY_PC_FETCH_TEMP;
                SS_COPY_PC_FETCH_TEMP: next_state = SS_OPFETCH;
                default: next_state = SS_ERROR;
            endcase

        end else if (a == SA_JMP_ABSR) begin
            
            case (state)
                SS_OPFETCH: next_state = SS_ADLFETCH;
                SS_ADLFETCH: next_state = SS_ADHFETCH;
                SS_ADHFETCH: next_state = SS_ADD_ADDR_REG2;
                SS_ADD_ADDR_REG2: next_state = SS_COPY_TEMP_MEMABS;
                SS_COPY_TEMP_MEMABS: next_state = SS_COPY_PC_MEMABS1_TEMP;
                SS_COPY_PC_MEMABS1_TEMP: next_state = SS_OPFETCH;
                default: next_state = SS_ERROR;
            endcase

        end else if (a == SA_BRA) begin
            
            case (state)
                SS_OPFETCH: next_state = SS_TEMPFETCH;
                SS_TEMPFETCH: next_state = cond_false ? SS_OPFETCH : SS_ADD_PC_TEMP;
                SS_ADD_PC_TEMP: next_state = SS_NOP;
                SS_NOP: next_state = SS_OPFETCH;
                default: next_state = SS_ERROR;
            endcase

        end else if (a == SA_BBSC_DP) begin
            
            case (state)
                SS_OPFETCH: next_state = SS_ADLFETCH;
                SS_ADLFETCH: next_state = SS_TEMPFETCH;
                SS_TEMPFETCH: next_state = SS_NOP;
                SS_NOP: next_state = SS_READ_MEMDP;
                SS_READ_MEMDP: next_state = not_bsc ? SS_OPFETCH : SS_ADD_PC_TEMP;
                SS_ADD_PC_TEMP: next_state = SS_NOP1;
                SS_NOP1: next_state = SS_OPFETCH;
                default: next_state = SS_ERROR;
            endcase

        end else if ((a == SA_CBNE_DP) | (a == SA_CBNE_DPR)) begin
            
            case (state)
                SS_OPFETCH: next_state = SS_ADLFETCH;
                SS_ADLFETCH: next_state = (a == SA_CBNE_DPR) ? SS_ADD_ADDR_REG2 : SS_COPY_TEMP_MEMDP;
                SS_ADD_ADDR_REG2: next_state = SS_COPY_TEMP_MEMDP;
                SS_COPY_TEMP_MEMDP: next_state = SS_SUB_REG1_TEMP;
                SS_SUB_REG1_TEMP: next_state = flgz ? SS_PC_INC : SS_NOP;
                SS_PC_INC: next_state = SS_OPFETCH;
                SS_NOP: next_state = SS_TEMPFETCH;
                SS_TEMPFETCH: next_state = SS_ADD_PC_TEMP;
                SS_ADD_PC_TEMP: next_state = SS_OPFETCH;
                default: next_state = SS_ERROR;
            endcase

        end else if (a == SA_DBNZ_DP) begin
            
            case (state)
                SS_OPFETCH: next_state = SS_ADLFETCH;
                SS_ADLFETCH: next_state = SS_COPY_TEMP_MEMDP_M1;
                SS_COPY_TEMP_MEMDP_M1: next_state = SS_COPY_MEMDP_TEMP;
                SS_COPY_MEMDP_TEMP: next_state = temp_0 ? SS_PC_INC : SS_NOP;
                SS_PC_INC: next_state = SS_OPFETCH;
                SS_NOP: next_state = SS_TEMPFETCH;
                SS_TEMPFETCH: next_state = SS_ADD_PC_TEMP;
                SS_ADD_PC_TEMP: next_state = SS_OPFETCH; 
                default: next_state = SS_ERROR;
            endcase

        end else if (a == SA_DBNZ_REG) begin
            
            case (state)
                SS_OPFETCH: next_state = SS_TEMPFETCH;
                SS_TEMPFETCH: next_state = SS_REG2_DEC;
                SS_REG2_DEC: next_state = SS_NOP;
                SS_NOP: next_state = reg2_0 ? SS_OPFETCH : SS_ADD_PC_TEMP;
                SS_ADD_PC_TEMP: next_state = SS_NOP1;
                SS_NOP1: next_state = SS_OPFETCH;
                default: next_state = SS_ERROR;
            endcase

        end else if (a == SA_CALL_IMM) begin
            
            case (state)
                SS_OPFETCH: next_state = SS_ADLFETCH;
                SS_ADLFETCH: next_state = SS_ADHFETCH;
                SS_ADHFETCH: next_state = SS_REG2_DEC2;
                SS_REG2_DEC2: next_state = SS_COPY_MEMSRP2_PCH;
                SS_COPY_MEMSRP2_PCH: next_state = SS_COPY_MEMSRP1_PCL;
                SS_COPY_MEMSRP1_PCL: next_state = SS_COPY_PC_ADDR;
                SS_COPY_PC_ADDR: next_state = SS_NOP;
                SS_NOP: next_state = SS_OPFETCH;
                default: next_state = SS_ERROR;
            endcase

        end else if (a == SA_CALL_UP) begin
            
            case (state)
                SS_OPFETCH: next_state = SS_ADLFETCH;
                SS_ADLFETCH: next_state = SS_REG2_DEC2;
                SS_REG2_DEC2: next_state = SS_COPY_MEMSRP2_PCH;
                SS_COPY_MEMSRP2_PCH: next_state = SS_COPY_MEMSRP1_PCL;
                SS_COPY_MEMSRP1_PCL: next_state = SS_COPY_PC_FF_ADL;
                SS_COPY_PC_FF_ADL: next_state = SS_OPFETCH;
                default: next_state = SS_ERROR;
            endcase

        end else if (a == SA_CALL_N) begin
            
            case (state)
                SS_OPFETCH: next_state = SS_COPY_ADL_MEMFFDE;
                SS_COPY_ADL_MEMFFDE: next_state = SS_COPY_ADH_MEMFFDF;
                SS_COPY_ADH_MEMFFDF: next_state = SS_REG2_DEC2;
                SS_REG2_DEC2: next_state = SS_COPY_MEMSRP2_PCH;
                SS_COPY_MEMSRP2_PCH: next_state = SS_COPY_MEMSRP1_PCL;
                SS_COPY_MEMSRP1_PCL: next_state = SS_COPY_PC_ADDR;
                SS_COPY_PC_ADDR: next_state = SS_NOP;
                SS_NOP: next_state = SS_OPFETCH;
                default: next_state = SS_ERROR;
            endcase

        end else if (a == SA_RET) begin
            
            case (state)
                SS_OPFETCH: next_state = SS_COPY_PCL_MEMSRP1;
                SS_COPY_PCL_MEMSRP1: next_state = SS_COPY_PCH_MEMSRP2;
                SS_COPY_PCH_MEMSRP2: next_state = SS_REG2_INC2;
                SS_REG2_INC2: next_state = SS_NOP;
                SS_NOP: next_state = SS_OPFETCH;
                default: next_state = SS_ERROR;
            endcase

        end else if (a == SA_RETI) begin
            
            case (state)
                SS_OPFETCH: next_state = SS_REG2_INC;
                SS_REG2_INC: next_state = SS_COPY_PSW_MEMSR;
                SS_COPY_PSW_MEMSR: next_state = SS_COPY_PCL_MEMSRP1;
                SS_COPY_PCL_MEMSRP1: next_state = SS_COPY_PCH_MEMSRP2;
                SS_COPY_PCH_MEMSRP2: next_state = SS_REG2_INC2;
                SS_REG2_INC2: next_state = SS_OPFETCH;
                default: next_state = SS_ERROR;
            endcase

        end else if ((a == SA_PUSH_REG) | (a == SA_PUSH_PSW)) begin
            
            case (state)
                SS_OPFETCH: next_state = (a == SA_PUSH_REG) ? SS_COPY_MEMSR_REG1 : SS_COPY_MEMSR_PSW;
                SS_COPY_MEMSR_REG1: next_state = SS_REG2_DEC;
                SS_COPY_MEMSR_PSW: next_state = SS_REG2_DEC;
                SS_REG2_DEC: next_state = SS_NOP;
                SS_NOP: next_state = SS_OPFETCH;
                default: next_state = SS_ERROR;
            endcase

        end else if ((a == SA_POP_REG) | (a == SA_POP_PSW)) begin
            
            case (state)
                SS_OPFETCH: next_state = SS_REG2_INC;
                SS_REG2_INC: next_state = (a == SA_POP_REG) ? SS_COPY_REG1_MEMSR : SS_COPY_PSW_MEMSR;
                SS_COPY_REG1_MEMSR: next_state = SS_NOP;
                SS_COPY_PSW_MEMSR: next_state = SS_NOP;
                SS_NOP: next_state = SS_OPFETCH;
                default: next_state = SS_ERROR;
            endcase

        end else if (a == SA_SC1_DP) begin
            
            case (state)
                SS_OPFETCH: next_state = SS_ADLFETCH;
                SS_ADLFETCH: next_state = SS_SC1_DP;
                SS_SC1_DP: next_state = SS_COPY_MEMDP_TEMP;
                SS_COPY_MEMDP_TEMP: next_state = SS_OPFETCH;
                default: next_state = SS_ERROR;
            endcase

        end else if (a == SA_TSC_ABS) begin
            
            case (state)
                SS_OPFETCH: next_state = SS_ADLFETCH;
                SS_ADLFETCH: next_state = SS_ADHFETCH;
                SS_ADHFETCH: next_state = SS_TSC_ABS_1;
                SS_TSC_ABS_1: next_state = SS_TSC_ABS_2;
                SS_TSC_ABS_2: next_state = SS_COPY_MEMABS_TEMP;
                SS_COPY_MEMABS_TEMP: next_state = SS_OPFETCH;
                default: next_state = SS_ERROR;
            endcase

        end else if (a == SA_CALC1_C_ABS) begin
            
            case (state)
                SS_OPFETCH: next_state = SS_ADLFETCH;
                SS_ADLFETCH: next_state = SS_ADHFETCH;
                SS_ADHFETCH: next_state = SS_CALC1_C_ABS;
                SS_CALC1_C_ABS: next_state = ((i == SI_OR1) | (i == SI_OR1_N) | (i == SI_EOR1)) ? SS_NOP : SS_OPFETCH;
                SS_NOP: next_state = SS_OPFETCH;
                default: next_state = SS_ERROR;
            endcase

        end else if (a == SA_CALC1_ABS_C) begin
            
            case (state)
                SS_OPFETCH: next_state = SS_ADLFETCH;
                SS_ADLFETCH: next_state = SS_ADHFETCH;
                SS_ADHFETCH: next_state = SS_CALC1_ABS_C;
                SS_CALC1_ABS_C: next_state = SS_COPY_MEMABSMINI_TEMP;
                SS_COPY_MEMABSMINI_TEMP: next_state = (i == SI_MOV1) ? SS_NOP : SS_OPFETCH;
                SS_NOP: next_state = SS_OPFETCH;
                default: next_state = SS_ERROR;
            endcase

        end else if (a == SA_PSW_CHANGE) begin
            
            case (state)
                SS_OPFETCH: next_state = SS_PSW_CHANGE;
                SS_PSW_CHANGE: next_state = ((i == SI_EI) | (i == SI_DI) | (i == SI_NOTC)) ? SS_NOP : SS_OPFETCH;
                SS_NOP: next_state = SS_OPFETCH;
                default: next_state = SS_ERROR;
            endcase

        end else if (a == SA_BRK) begin
            
            case (state)
                SS_OPFETCH: next_state = SS_PC_INC_BRKSET;
                SS_PC_INC_BRKSET: next_state = SS_REG2_DEC2;
                SS_REG2_DEC2: next_state = SS_COPY_MEMSRP2_PCH;
                SS_COPY_MEMSRP2_PCH: next_state = SS_COPY_MEMSRP1_PCL;
                SS_COPY_MEMSRP1_PCL: next_state = SS_COPY_MEMSR_PSW;
                SS_COPY_MEMSR_PSW: next_state = SS_REG2_DEC;
                SS_REG2_DEC: next_state = SS_COPY_PCL_MEMFFDE;
                SS_COPY_PCL_MEMFFDE: next_state = SS_COPY_PCH_MEMFFDF;
                SS_COPY_PCH_MEMFFDF: next_state = SS_OPFETCH;
                default: next_state = SS_ERROR;
            endcase

        end else if (a == SA_XCN_REG) begin
            
            case (state)
                SS_OPFETCH: next_state = SS_XCN_REG1;
                SS_XCN_REG1: next_state = SS_NOP;
                SS_NOP: next_state = SS_NOP1;
                SS_NOP1: next_state = SS_NOP2;
                SS_NOP2: next_state = SS_OPFETCH;
                default: next_state = SS_ERROR;
            endcase

        end else if (a == SA_MUL_YA) begin
            
            case (state)
                SS_OPFETCH: next_state = SS_MUL_INIT;
                SS_MUL_INIT: next_state = SS_MUL_6;
                SS_MUL_6: next_state = SS_MUL_5;
                SS_MUL_5: next_state = SS_MUL_4;
                SS_MUL_4: next_state = SS_MUL_3;
                SS_MUL_3: next_state = SS_MUL_2;
                SS_MUL_2: next_state = SS_MUL_1;
                SS_MUL_1: next_state = SS_MUL_0;
                SS_MUL_0: next_state = SS_OPFETCH;
                default: next_state = SS_ERROR;
            endcase

        end else if (a == SA_DIV_YA_X) begin
            
            case (state)
                SS_OPFETCH: next_state = SS_DIV_INIT;
                SS_DIV_INIT: next_state = SS_DIV_8;
                SS_DIV_8: next_state = SS_DIV_7;
                SS_DIV_7: next_state = SS_DIV_6;
                SS_DIV_6: next_state = SS_DIV_5;
                SS_DIV_5: next_state = SS_DIV_4;
                SS_DIV_4: next_state = SS_DIV_3;
                SS_DIV_3: next_state = SS_DIV_2;
                SS_DIV_2: next_state = SS_DIV_1;
                SS_DIV_1: next_state = SS_DIV_0;
                SS_DIV_0: next_state = SS_DIV_LAST;
                SS_DIV_LAST: next_state = SS_OPFETCH;
                default: next_state = SS_ERROR;
            endcase

        end else if (a == SA_DAAS) begin
            
            case (state)
                SS_OPFETCH: next_state = SS_DAAS;
                SS_DAAS: next_state = SS_NOP;
                SS_NOP: next_state = SS_OPFETCH;
                default: next_state = SS_ERROR;
            endcase

        end else if (a == SA_NOP) begin
            
            case (state)
                SS_OPFETCH: next_state = SS_NOP;
                SS_NOP: next_state = SS_OPFETCH;
                default: next_state = SS_ERROR;
            endcase

        end else begin
            
            next_state = SS_ERROR;

        end

    end
    
endmodule
