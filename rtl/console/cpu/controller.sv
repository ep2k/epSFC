// ==============================
//  61586 CPU Controller
// ==============================

// Copyright(C) 2024 ep2k All Rights Reserved.

`include "config.vh"    // include/de0cv/config.vh

module controller
    import cpu_pkg::*;
(
    input logic clk,
    input logic cpu_en,
    input logic reset,

    input logic [7:0] mem_rdata,

    input logic e,
    input logic [7:0] p,
    input logic [3:0] alu_flgs,
    input logic carry,
    input logic m8,
    input logic x8,

    input logic a_max, // a == FFFF
    input logic dplz, // dp[7:0] == 0
    input logic page_cross, // pc relative(pc + 8bit 符号拡張)でページクロス

    input logic nmi,
    input logic irq,

    output ctl_signals_type ctl_signals,

    output logic [4:0] ints // COP, BRK, IRQ, NMI, RESET
);

    // ------------------------------
    //  Wires
    // ------------------------------
    
    addressing_type addressing_next;
    instruction_type instruction_next;
    logic [2:0] init_op_counter_next;

    ctl_signals_type ctl_signals_opfetch, ctl_signals_state, ctl_signals_op;

    state_type first_state, next_state;
    logic op_finish;
    logic irq_start;

    // ------------------------------
    //  Registers
    // ------------------------------
    
    addressing_type addressing = A_HARD_INT;
    instruction_type instruction = I_HARD_INT;

    state_type state = S_PC_DEC;
    logic [2:0] op_counter = 3'd1;

    (* syn_noprune *) logic [7:0] op;

    logic nmi_flg = 1'b0;
    logic nmi_prev;

    logic exe_reset = 1'b1;
    logic exe_nmi = 1'b0;
    logic exe_irq = 1'b0;

    // ------------------------------
    //  Main
    // ------------------------------

    assign ints = {
        instruction == I_COP,
        instruction == I_BRK,
        exe_irq,
        exe_nmi,
        exe_reset
    };

    assign irq_start = (~p[I]) & irq;

    always_ff @(posedge clk) begin
        if (reset) begin
            state <= S_PC_DEC;
        end else if (cpu_en) begin
            if (state == S_FETCH_OPCODE) begin
                state <= (nmi_flg | irq_start) ? S_PC_DEC : first_state;
            end else if (state == S_OP_CALC) begin
                if (op_finish | (op_counter == 3'd0)) begin
                    state <= S_FETCH_OPCODE;
                end
            end else begin
                state <= next_state;
            end
        end
    end

    always_ff @(posedge clk) begin
        if (cpu_en & (state == S_FETCH_OPCODE)) begin
            op <= mem_rdata;    // デバッグ用(制御には使用されない)
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            addressing <= A_HARD_INT;
            instruction <= I_HARD_INT;
        end else if (cpu_en & (state == S_FETCH_OPCODE)) begin
            addressing <= (nmi_flg | irq_start) ? A_HARD_INT : addressing_next;
            instruction <= (nmi_flg | irq_start) ? I_HARD_INT : instruction_next;
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            op_counter <= 3'd1;
        end else if (cpu_en) begin
            if (state == S_FETCH_OPCODE) begin
                op_counter <= (nmi_flg | irq_start) ? 3'd1 : init_op_counter_next;
            end else if (state == S_OP_CALC) begin
                op_counter <= op_counter - 3'd1;
            end 
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            nmi_flg <= 1'b0;
        end else if ((~nmi_prev) & nmi) begin
            nmi_flg <= 1'b1;
        end else if (cpu_en & (state == S_FETCH_OPCODE)) begin
            nmi_flg <= 1'b0;
        end
    end

    always_ff @(posedge clk) begin
        nmi_prev <= nmi;
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            exe_reset <= 1'b1;
            exe_nmi <= 1'b0;
            exe_irq <= 1'b0;
        end else if (cpu_en & (state == S_FETCH_OPCODE)) begin
            exe_reset <= 1'b0;
            exe_nmi <= nmi_flg;
            exe_irq <= irq_start;
        end
    end

    // op, m8 -> addressing, instruction, init_op_counter
    opcode_table opcode_table(
        .op(mem_rdata),     // opレジスタは使用せず直接mem_rdataを入力
                            // (mem_rdataはcpu_en_m1でcart_rdataを保存するため，opでは間に合わない)
        .m8,

        .addressing(addressing_next),
        .instruction(instruction_next),
        .init_op_counter(init_op_counter_next)
    );

    // addressing_next, 各種信号 -> first_state
    first_state_detector first_state_detector(
        .addressing(addressing_next),

        .m8,
        .x8,

        .first_state
    );

    // state, addressing, 各種信号 -> next_state
    next_state_detector next_state_detector(
        .state,
        .addressing,

        .e,
        .carry,
        .m8,
        .x8,
        .i_mem(
            (instruction == I_STA) | (instruction == I_STX)
             | (instruction == I_STY) | (instruction == I_STZ)
             | (instruction == I_INC) | (instruction == I_DEC)
             | (instruction == I_ASL) | (instruction == I_LSR)
             | (instruction == I_ROL) | (instruction == I_ROR)
        ),
        .dplz,

        .next_state
    );

    // addressing_next -> OPフェッチ時制御信号
    opfetch_decoder opfetch_decoder(
        .addressing(addressing_next),
        .irq,
        .ctl_signals(ctl_signals_opfetch)
    );

    // state, addressing, 各種信号 -> 制御信号
    state_decoder state_decoder(
        .state,
        .addressing,

        .irq,
        .p,
        .alu_flgs,
        .carry,
        .a_max,
        .dp_wrap(e & dplz),

        .ctl_signals(ctl_signals_state)
    );

    // instruction, op_counter, 各種信号  -> 制御信号
    op_calc_decoder op_calc_decoder(
        .instruction,
        .op_counter,

        .m8,
        .x8,
        .e,
        .p,

        .alu_flgs,
        .page_cross,

        .imm(addressing == A_IMM),

        .ctl_signals(ctl_signals_op),
        .op_finish
    );

    // 制御信号選択
    always_comb begin
        case (state)
            S_FETCH_OPCODE: ctl_signals = ctl_signals_opfetch;
            S_OP_CALC: ctl_signals = ctl_signals_op;
            default: ctl_signals = ctl_signals_state;
        endcase
    end

    `ifdef USE_CPU_CYCLE_DEBUG
        cpu_cycle_debug cpu_cycle_debug(
            .clk,
            .cpu_en,
            .reset,

            .state_fetch_opcode(state == S_FETCH_OPCODE),
            .op,
            .hard_int(exe_reset | exe_irq | exe_nmi),

            .m8,
            .x8,
            .e,
            .dplz,
            .p
        );
    `endif
    
endmodule
