// ==============================
//  SCP700 CPU Controller
// ==============================

// Copyright(C) 2024 ep2k All Rights Reserved.

module s_controller
    import s_cpu_pkg::*;
(
    input logic clk,
    input logic cpu_en,
    input logic reset,

    input logic [7:0] op,

    input logic [7:0] psw,
    input logic reg2_0,
    input logic flgz,
    input logic temp_0,
    input logic not_bsc,

    output reg_src_type reg1_src,
    output reg_src_type reg2_src,
    output ctl_signals_type ctl_signals
);
    
    // ------------------------------
    //  Wires
    // ------------------------------
    
    addressing_type addressing;
    instruction_type instruction;

    state_type next_state;

    logic cond_false;

    // ------------------------------
    //  Registers
    // ------------------------------
    
    state_type state = SS_OPFETCH;

    // ------------------------------
    //  Main
    // ------------------------------

    // state
    always_ff @(posedge clk) begin
        if (reset) begin
            state <= SS_OPFETCH;
        end else if (cpu_en) begin
            state <= next_state;
        end
    end

    // cond_false
    always_comb begin
        case (instruction)
            SI_BRA: cond_false = 1'b0;
            SI_BEQ: cond_false = ~psw[Z];
            SI_BNE: cond_false = psw[Z];
            SI_BCS: cond_false = ~psw[C];
            SI_BCC: cond_false = psw[C];
            SI_BVS: cond_false = ~psw[V];
            SI_BVC: cond_false = psw[V];
            SI_BMI: cond_false = ~psw[N];
            SI_BPL: cond_false = psw[N];
            default: cond_false = 1'b0;
        endcase
    end

    // op -> addressing, instruction, reg1_src, reg2_src
    s_op_table op_table(
        .op,

        .addressing,
        .instruction,
        .reg1_src,
        .reg2_src
    );

    // state, addressing, instruction, 条件 -> next_state
    s_next_state_detector next_state_detector(
        .state,
        .addressing,
        .instruction,

        .cond_false,
        .reg2_0,
        .flgz,
        .temp_0,
        .not_bsc,

        .next_state
    );

    // state, instruction -> ctl_signals
    s_state_decoder state_decoder(
        .state,
        .instruction,

        .ctl_signals
    );
    
endmodule
