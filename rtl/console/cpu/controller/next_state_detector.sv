// ==================================================
//  Next State Detector in 65186 CPU Controller
// ==================================================

// Copyright(C) 2024 ep2k All Rights Reserved.

module next_state_detector
    import cpu_pkg::*;
(
    input state_type state,
    input addressing_type addressing,

    input logic e,
    input logic carry,
    input logic m8,
    input logic x8,
    input logic i_mem,
    input logic dplz,

    output state_type next_state
);

    always_comb begin

        if ((addressing == A_SOFT_INT) | (addressing == A_HARD_INT)) begin
            
            case (state)
                // S_FETCH_OPCODE: next_state = (addressing == A_HARD_INT) ? S_PC_DEC : S_PC_INC;
                S_PC_DEC: next_state = e ? S_PUSH_H : S_PUSH_B;
                S_PC_INC: next_state = e ? S_PUSH_H : S_PUSH_B;
                S_PUSH_B: next_state = S_PUSH_H;
                S_PUSH_H: next_state = S_PUSH_L;
                S_PUSH_L: next_state = S_PUSH_P;
                S_PUSH_P: next_state = S_OP_CALC;
                default: next_state = S_ERROR;
            endcase

        end else if (addressing == A_WAIT) begin

            next_state = S_FETCH_OPCODE;

        end else if ((addressing == A_ABS) | (addressing == A_ABS_JMP) | (addressing == A_ABSL_JMP)) begin
            
            case (state)
                // S_FETCH_OPCODE: next_state = S_FETCH_OPRAND_L;
                S_FETCH_OPRAND_L: next_state = S_FETCH_OPRAND_H;
                S_FETCH_OPRAND_H: next_state = S_OP_CALC;
                default: next_state = S_ERROR;
            endcase

        end else if ((addressing == A_ABSX) | (addressing == A_ABSY) | (addressing == A_ABSX_JMP)) begin
            
            case (state)
                // S_FETCH_OPCODE: next_state = S_FETCH_OPRAND_L;
                S_FETCH_OPRAND_L: next_state = S_FETCH_OPRAND_H;
                S_FETCH_OPRAND_H: begin
                        if ((~x8) | carry | i_mem | (addressing == A_ABSX_JMP)) begin
                            // next_state = (addressing == A_ABSY) ? S_ADD_ADDRH_YH : S_ADD_ADDRH_XH; // A_ABS_JMPも?
                            next_state = S_ADD_ADDRB_CARRY;
                        end else begin
                            next_state = S_OP_CALC;
                        end
                    end
                S_ADD_ADDRB_CARRY: next_state = S_OP_CALC;
                default: next_state = S_ERROR;
            endcase

        end else if ((addressing == A_ABSL) | (addressing == A_ABSLX)) begin
            
            case (state)
                // S_FETCH_OPCODE: next_state = S_FETCH_OPRAND_L;
                S_FETCH_OPRAND_L: next_state = S_FETCH_OPRAND_H;
                S_FETCH_OPRAND_H: next_state = S_FETCH_OPRAND_B;
                S_FETCH_OPRAND_B: next_state = S_OP_CALC;
                default: next_state = S_ERROR;
            endcase

        end else if (addressing == A_DP) begin
            
            case (state)
                // S_FETCH_OPCODE: next_state = S_FETCH_OPRAND_L;
                S_FETCH_OPRAND_L: next_state = dplz ? S_OP_CALC : S_ADD_ADDR_DPL;
                S_ADD_ADDR_DPL: next_state = S_OP_CALC;
                default: next_state = S_ERROR;
            endcase

        end else if (addressing == A_DPX) begin
            
            case (state)
                // S_FETCH_OPCODE: next_state = S_FETCH_OPRAND_L;
                S_FETCH_OPRAND_L: next_state = dplz ? S_ADD_ADDR_X : S_ADD_ADDR_DPL;
                S_ADD_ADDR_DPL: next_state = S_ADD_ADDR_X;
                S_ADD_ADDR_X: next_state = S_OP_CALC;
                default: next_state = S_ERROR;
            endcase

        end else if (addressing == A_DPY) begin
            
            case (state)
                // S_FETCH_OPCODE: next_state = S_FETCH_OPRAND_L;
                S_FETCH_OPRAND_L: next_state = dplz ? S_ADD_ADDR_Y : S_ADD_ADDR_DPL;
                S_ADD_ADDR_DPL: next_state = S_ADD_ADDR_Y;
                S_ADD_ADDR_Y: next_state = S_OP_CALC;
                default: next_state = S_ERROR;
            endcase

        end else if (addressing == A_INDP) begin
            
            case (state)
                // S_FETCH_OPCODE: next_state = S_FETCH_OPRAND_L;
                S_FETCH_OPRAND_L: next_state = dplz ? S_READ_ADDR2_L : S_ADD_ADDR2_DPL;
                S_ADD_ADDR2_DPL: next_state = S_READ_ADDR2_L;
                S_READ_ADDR2_L: next_state = S_READ_ADDR2_H;
                S_READ_ADDR2_H: next_state = S_OP_CALC;
                default: next_state = S_ERROR;
            endcase

        end else if (addressing == A_INDPX) begin
            
            case (state)
                // S_FETCH_OPCODE: next_state = S_FETCH_OPRAND_L;
                S_FETCH_OPRAND_L: next_state = dplz ? S_ADD_ADDR2_X : S_ADD_ADDR2_DPL;
                S_ADD_ADDR2_DPL: next_state = S_ADD_ADDR2_X;
                S_ADD_ADDR2_X: next_state = S_READ_ADDR2_L;
                S_READ_ADDR2_L: next_state = S_READ_ADDR2_H;
                S_READ_ADDR2_H: next_state = S_OP_CALC;
                default: next_state = S_ERROR;
            endcase

        end else if (addressing == A_INDPY) begin

            case (state)
                // S_FETCH_OPCODE: next_state = S_FETCH_OPRAND_L;
                S_FETCH_OPRAND_L: next_state = dplz ? S_READ_ADDR2_L : S_ADD_ADDR2_DPL;
                S_ADD_ADDR2_DPL: next_state = S_READ_ADDR2_L;
                S_READ_ADDR2_L: next_state = S_READ_ADDR2_H;
                S_READ_ADDR2_H: next_state = ((~x8) | carry | i_mem) ? S_ADD_ADDRB_CARRY : S_OP_CALC;
                S_ADD_ADDRB_CARRY: next_state = S_OP_CALC;
                default: next_state = S_ERROR;
            endcase
            
        end else if ((addressing == A_INDPL) | (addressing == A_INDPLY)) begin
            
            case (state)
                // S_FETCH_OPCODE: next_state = S_FETCH_OPRAND_L;
                S_FETCH_OPRAND_L: next_state = dplz ? S_READ_ADDR2_L : S_ADD_ADDR2_DPL;
                S_ADD_ADDR2_DPL: next_state = S_READ_ADDR2_L;
                S_READ_ADDR2_L: next_state = S_READ_ADDR2_H;
                S_READ_ADDR2_H: next_state = S_READ_ADDR2_B;
                S_READ_ADDR2_B: next_state = S_OP_CALC;
                default: next_state = S_ERROR;
            endcase

        end else if (addressing == A_SPR) begin
            
            case (state)
                // S_FETCH_OPCODE: next_state = S_FETCH_OPRAND_L;
                S_FETCH_OPRAND_L: next_state = S_ADD_ADDR_SP;
                S_ADD_ADDR_SP: next_state = S_OP_CALC;
                default: next_state = S_ERROR;
            endcase

        end else if (addressing == A_INSPRY) begin
            
            case (state)
                // S_FETCH_OPCODE: next_state = S_FETCH_OPRAND_L;
                S_FETCH_OPRAND_L: next_state = S_ADD_ADDR2_SP;
                S_ADD_ADDR2_SP: next_state = S_READ_ADDR2_L;
                S_READ_ADDR2_L: next_state = S_READ_ADDR2_H;
                S_READ_ADDR2_H: next_state = S_ADD_ADDR_Y;
                S_ADD_ADDR_Y: next_state = S_OP_CALC;
                default: next_state = S_ERROR;
            endcase

        end else if (addressing == A_PUSH_A) begin
            
            case (state)
                // S_FETCH_OPCODE: next_state = (~m8) ? S_PUSH_H : S_PUSH_L;
                S_PUSH_H: next_state = S_PUSH_L;
                S_PUSH_L: next_state = S_OP_CALC;
                default: next_state = S_ERROR;
            endcase

        end else if ((addressing == A_PUSH_X) | (addressing == A_PUSH_Y)) begin
            
            case (state)
                // S_FETCH_OPCODE: next_state = (~x8) ? S_PUSH_H : S_PUSH_L;
                S_PUSH_H: next_state = S_PUSH_L;
                S_PUSH_L: next_state = S_OP_CALC;
                default: next_state = S_ERROR;
            endcase

        end else if (addressing == A_PUSH_DP) begin
            
            case (state)
                // S_FETCH_OPCODE: next_state = S_PUSH_H;
                S_PUSH_H: next_state = S_PUSH_L;
                S_PUSH_L: next_state = S_OP_CALC;
                default: next_state = S_ERROR;
            endcase

        end else if ((addressing == A_PUSH_P) | (addressing == A_PUSH_PB) | (addressing == A_PUSH_DB)) begin
            
            case (state)
                // S_FETCH_OPCODE: next_state = S_PUSH_L;
                S_PUSH_L: next_state = S_OP_CALC;
                default: next_state = S_ERROR;
            endcase

        end else if (addressing == A_PULL_A) begin
            
            case (state)
                // S_FETCH_OPCODE: next_state = S_PULL_L;
                S_PULL_L: next_state = (~m8) ? S_PULL_H : S_OP_CALC;
                S_PULL_H: next_state = S_OP_CALC;
                default: next_state = S_ERROR;
            endcase

        end else if ((addressing == A_PULL_X) | (addressing == A_PULL_Y)) begin
            
            case (state)
                // S_FETCH_OPCODE: next_state = S_PULL_L;
                S_PULL_L: next_state = (~x8) ? S_PULL_H : S_OP_CALC;
                S_PULL_H: next_state = S_OP_CALC;
                default: next_state = S_ERROR;
            endcase

        end else if (addressing == A_PULL_DP) begin
            
            case (state)
                // S_FETCH_OPCODE: next_state = S_PULL_L;
                S_PULL_L: next_state = S_PULL_H;
                S_PULL_H: next_state = S_OP_CALC;
                default: next_state = S_ERROR;
            endcase

        end else if ((addressing == A_PULL_P) | (addressing == A_PULL_PB) | (addressing == A_PULL_DB)) begin
            
            case (state)
                // S_FETCH_OPCODE: next_state = S_PULL_L;
                S_PULL_L: next_state = S_OP_CALC;
                default: next_state = S_ERROR;
            endcase

        end else if ((addressing == A_RTI) | (addressing == A_RTL) | (addressing == A_RTS)) begin
            
            case (state)
                // S_FETCH_OPCODE: next_state = (addressing == A_RTI) ? S_PULL_P : S_PULL_L;
                S_PULL_P: next_state = S_PULL_L;
                S_PULL_L: next_state = S_PULL_H;
                S_PULL_H: next_state =
                        ((addressing == A_RTL) | ((addressing == A_RTI) & (~e))) ? S_PULL_B : S_OP_CALC;
                S_PULL_B: next_state = S_OP_CALC;
                default: next_state = S_ERROR;
            endcase

        end else if ((addressing == A_SUB_IMM) | (addressing == A_SUB_IMML)) begin
            
            case (state)
                // S_FETCH_OPCODE: next_state = S_FETCH_OPRAND_L;
                S_FETCH_OPRAND_L: next_state = S_FETCH_OPRAND_H;
                S_FETCH_OPRAND_H: next_state = (addressing == A_SUB_IMML) ? S_FETCH_OPRAND_B : S_PUSH_H;
                S_FETCH_OPRAND_B: next_state = S_PUSH_B;
                S_PUSH_B: next_state = S_PUSH_H;
                S_PUSH_H: next_state = S_PUSH_L;
                S_PUSH_L: next_state = S_COPY_PC_ADDR;
                S_COPY_PC_ADDR: next_state = S_FETCH_OPCODE;
                default: next_state = S_ERROR;
            endcase

        end else if (addressing == A_SUB_ABSX) begin
            
            case (state)
                // S_FETCH_OPCODE: next_state = S_FETCH_OPRAND_L;
                S_FETCH_OPRAND_L: next_state = S_FETCH_OPRAND_H;
                S_FETCH_OPRAND_H: next_state = S_READ_ADDR2_L;
                S_READ_ADDR2_L: next_state = S_READ_ADDR2_H;
                S_READ_ADDR2_H: next_state = S_PUSH_H;
                S_PUSH_H: next_state = S_PUSH_L;
                S_PUSH_L: next_state = S_COPY_PC_ADDR;
                S_COPY_PC_ADDR: next_state = S_FETCH_OPCODE;
                default: next_state = S_ERROR;
            endcase

        end else if (addressing == A_PEA) begin
            
            case (state)
                // S_FETCH_OPCODE: next_state = S_FETCH_OPRAND_L;
                S_FETCH_OPRAND_L: next_state = S_FETCH_OPRAND_H;
                S_FETCH_OPRAND_H: next_state = S_PUSH_H;
                S_PUSH_H: next_state = S_PUSH_L;
                S_PUSH_L: next_state = S_FETCH_OPCODE;
                default: next_state = S_ERROR;
            endcase

        end else if (addressing == A_PEI) begin
            
            case (state)
                // S_FETCH_OPCODE: next_state = S_FETCH_OPRAND_L;
                S_FETCH_OPRAND_L: next_state = dplz ? S_READ_ADDR2_L : S_ADD_ADDR2_DPL;
                S_ADD_ADDR2_DPL: next_state = S_READ_ADDR2_L;
                S_READ_ADDR2_L: next_state = S_READ_ADDR2_H;
                S_READ_ADDR2_H: next_state = S_PUSH_H;
                S_PUSH_H: next_state = S_PUSH_L;
                S_PUSH_L: next_state = S_FETCH_OPCODE;
                default: next_state = S_ERROR;
            endcase

        end else if (addressing == A_PER) begin
            
            case (state)
                // S_FETCH_OPCODE: next_state = S_FETCH_OPRAND_L;
                S_FETCH_OPRAND_L: next_state = S_FETCH_OPRAND_H;
                S_FETCH_OPRAND_H: next_state = S_ADD_ADDR_PC;
                S_ADD_ADDR_PC: next_state = S_PUSH_H;
                S_PUSH_H: next_state = S_PUSH_L;
                S_PUSH_L: next_state = S_FETCH_OPCODE;
                default: next_state = S_ERROR;
            endcase

        end else if ((addressing == A_MVN) | (addressing == A_MVP)) begin
            
            case (state)
                // S_FETCH_OPCODE: next_state = S_FETCH_BANK_1;
                S_FETCH_BANK_1: next_state = S_MV_READ;
                S_MV_READ: next_state = S_FETCH_BANK_2;
                S_FETCH_BANK_2: next_state = S_MV_WRITE;
                S_MV_WRITE: next_state = S_DEC_A;
                S_DEC_A: next_state = S_MV_LOOP;
                S_MV_LOOP: next_state = S_FETCH_OPCODE;
                default: next_state = S_ERROR;
            endcase

        end else begin // A_IMP, A_IMM, A_IMM_JMP

            next_state = S_OP_CALC;
            
        end

    end
    
endmodule
