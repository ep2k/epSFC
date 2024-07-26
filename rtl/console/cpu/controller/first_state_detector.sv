// ==================================================
//  First State Detector in 65186 CPU Controller
// ==================================================

// Copyright(C) 2024 ep2k All Rights Reserved.

module first_state_detector
    import cpu_pkg::*;
(
    input addressing_type addressing,

    input logic m8,
    input logic x8,

    output state_type first_state
);

    always_comb begin

        if (addressing == A_SOFT_INT) begin
            
            first_state = S_PC_INC;

        end else if (addressing == A_WAIT) begin

            first_state = S_FETCH_OPCODE;

        end else if ((addressing == A_ABS) | (addressing == A_ABS_JMP) | (addressing == A_ABSL_JMP)) begin
            
            first_state = S_FETCH_OPRAND_L;

        end else if ((addressing == A_ABSX) | (addressing == A_ABSY) | (addressing == A_ABSX_JMP)) begin
            
            first_state = S_FETCH_OPRAND_L;

        end else if ((addressing == A_ABSL) | (addressing == A_ABSLX)) begin
            
            first_state = S_FETCH_OPRAND_L;

        end else if (addressing == A_DP) begin
            
            first_state = S_FETCH_OPRAND_L;

        end else if (addressing == A_DPX) begin
            
            first_state = S_FETCH_OPRAND_L;

        end else if (addressing == A_DPY) begin
            
            first_state = S_FETCH_OPRAND_L;

        end else if (addressing == A_INDP) begin
            
            first_state = S_FETCH_OPRAND_L;

        end else if (addressing == A_INDPX) begin
            
            first_state = S_FETCH_OPRAND_L;

        end else if (addressing == A_INDPY) begin

            first_state = S_FETCH_OPRAND_L;
            
        end else if ((addressing == A_INDPL) | (addressing == A_INDPLY)) begin
            
            first_state = S_FETCH_OPRAND_L;

        end else if (addressing == A_SPR) begin
            
            first_state = S_FETCH_OPRAND_L;

        end else if (addressing == A_INSPRY) begin
            
            first_state = S_FETCH_OPRAND_L;

        end else if (addressing == A_PUSH_A) begin
            
            first_state = (~m8) ? S_PUSH_H : S_PUSH_L;

        end else if ((addressing == A_PUSH_X) | (addressing == A_PUSH_Y)) begin
            
            first_state = (~x8) ? S_PUSH_H : S_PUSH_L;

        end else if (addressing == A_PUSH_DP) begin
            
            first_state = S_PUSH_H;

        end else if ((addressing == A_PUSH_P) | (addressing == A_PUSH_PB) | (addressing == A_PUSH_DB)) begin
            
            first_state = S_PUSH_L;

        end else if (addressing == A_PULL_A) begin
            
            first_state = S_PULL_L;

        end else if ((addressing == A_PULL_X) | (addressing == A_PULL_Y)) begin
            
            first_state = S_PULL_L;

        end else if (addressing == A_PULL_DP) begin
            
            first_state = S_PULL_L;

        end else if ((addressing == A_PULL_P) | (addressing == A_PULL_PB) | (addressing == A_PULL_DB)) begin
            
            first_state = S_PULL_L;

        end else if ((addressing == A_RTI) | (addressing == A_RTL) | (addressing == A_RTS)) begin
            
            first_state = (addressing == A_RTI) ? S_PULL_P : S_PULL_L;

        end else if ((addressing == A_SUB_IMM) | (addressing == A_SUB_IMML)) begin
            
            first_state = S_FETCH_OPRAND_L;

        end else if (addressing == A_SUB_ABSX) begin
            
            first_state = S_FETCH_OPRAND_L;

        end else if (addressing == A_PEA) begin
            
            first_state = S_FETCH_OPRAND_L;

        end else if (addressing == A_PEI) begin
            
            first_state = S_FETCH_OPRAND_L;

        end else if (addressing == A_PER) begin
            
            first_state = S_FETCH_OPRAND_L;

        end else if ((addressing == A_MVN) | (addressing == A_MVP)) begin
            
            first_state = S_FETCH_BANK_1;

        end else begin // A_IMP, A_IMM, A_IMM_JMP

            first_state = S_OP_CALC;
            
        end

    end
    
endmodule
