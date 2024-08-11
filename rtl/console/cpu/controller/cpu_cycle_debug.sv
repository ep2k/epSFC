// ==============================
//  65816 CPU Cycles Debug
// ==============================

// Copyright(C) 2024 ep2k All Rights Reserved.

module cpu_cycle_debug
    import cpu_pkg::*;
(
    input logic clk,
    input logic cpu_en,
    input logic reset,

    input logic state_fetch_opcode,
    input logic [7:0] op,
    input logic hard_int,

    input logic m8,
    input logic x8,
    input logic e,
    input logic dplz,
    input logic [7:0] p
);
    
    // ------------------------------
    //  Wires
    // ------------------------------
    
    logic [3:0] cycle_ref;
    logic page_cross;

    logic [3:0] n_m8_1, n_m8_2;
    logic [3:0] n_x8_1;
    logic [3:0] e_1, n_e_1;
    logic [3:0] n_dplz_1;

    logic error_raw;

    // ------------------------------
    //  Registers
    // ------------------------------
    
    (* syn_noprune *) logic error = 1'b0;

    logic [3:0] cycle_ctr = 4'd0;

    // ------------------------------
    //  Main
    // ------------------------------

    // cycle_ctr
    always_ff @(posedge clk) begin
        if (reset) begin
            cycle_ctr <= 4'd0;
        end else if (cpu_en) begin
            cycle_ctr <= state_fetch_opcode ? 4'd0 : (cycle_ctr + 4'd1);
        end
    end

    assign n_m8_1 = (~m8) ? 4'd1 : 4'd0;
    assign n_m8_2 = (~m8) ? 4'd2 : 4'd0;
    assign n_x8_1 = (~x8) ? 4'd1 : 4'd0;
    assign e_1 = e ? 4'd1 : 4'd0;
    assign n_e_1 = (~e) ? 4'd1 : 4'd0;
    assign n_dplz_1 = (~dplz) ? 4'd1 : 4'd0;

    // cycle_ref, page_cross
    always_comb begin
        unique case (op)
            // ADC
            8'h69: {cycle_ref, page_cross} = {4'd2 + n_m8_1, 1'b0};
            8'h6d: {cycle_ref, page_cross} = {4'd4 + n_m8_1, 1'b0};
            8'h6f: {cycle_ref, page_cross} = {4'd5 + n_m8_1, 1'b0};
            8'h65: {cycle_ref, page_cross} = {4'd3 + n_m8_1 + n_dplz_1, 1'b0};
            8'h72: {cycle_ref, page_cross} = {4'd5 + n_m8_1 + n_dplz_1, 1'b0};
            8'h67: {cycle_ref, page_cross} = {4'd6 + n_m8_1 + n_dplz_1, 1'b0};
            8'h7d: {cycle_ref, page_cross} = {4'd4 + n_m8_1, 1'b1};
            8'h7f: {cycle_ref, page_cross} = {4'd5 + n_m8_1, 1'b0};
            8'h79: {cycle_ref, page_cross} = {4'd4 + n_m8_1, 1'b1};
            8'h75: {cycle_ref, page_cross} = {4'd4 + n_m8_1 + n_dplz_1, 1'b0};
            8'h61: {cycle_ref, page_cross} = {4'd6 + n_m8_1 + n_dplz_1, 1'b0};
            8'h71: {cycle_ref, page_cross} = {4'd5 + n_m8_1 + n_dplz_1, 1'b1};
            8'h77: {cycle_ref, page_cross} = {4'd6 + n_m8_1 + n_dplz_1, 1'b0};
            8'h63: {cycle_ref, page_cross} = {4'd4 + n_m8_1, 1'b0};
            8'h73: {cycle_ref, page_cross} = {4'd7 + n_m8_1, 1'b0};

            // AND
            8'h29: {cycle_ref, page_cross} = {4'd2 + n_m8_1, 1'b0};
            8'h2d: {cycle_ref, page_cross} = {4'd4 + n_m8_1, 1'b0};
            8'h2f: {cycle_ref, page_cross} = {4'd5 + n_m8_1, 1'b0};
            8'h25: {cycle_ref, page_cross} = {4'd3 + n_m8_1 + n_dplz_1, 1'b0};
            8'h32: {cycle_ref, page_cross} = {4'd5 + n_m8_1 + n_dplz_1, 1'b0};
            8'h27: {cycle_ref, page_cross} = {4'd6 + n_m8_1 + n_dplz_1, 1'b0};
            8'h3d: {cycle_ref, page_cross} = {4'd4 + n_m8_1, 1'b1};
            8'h3f: {cycle_ref, page_cross} = {4'd5 + n_m8_1, 1'b0};
            8'h39: {cycle_ref, page_cross} = {4'd4 + n_m8_1, 1'b1};
            8'h35: {cycle_ref, page_cross} = {4'd4 + n_m8_1 + n_dplz_1, 1'b0};
            8'h21: {cycle_ref, page_cross} = {4'd6 + n_m8_1 + n_dplz_1, 1'b0};
            8'h31: {cycle_ref, page_cross} = {4'd5 + n_m8_1 + n_dplz_1, 1'b1};
            8'h37: {cycle_ref, page_cross} = {4'd6 + n_m8_1 + n_dplz_1, 1'b0};
            8'h23: {cycle_ref, page_cross} = {4'd4 + n_m8_1, 1'b0};
            8'h33: {cycle_ref, page_cross} = {4'd7 + n_m8_1, 1'b0};

            // ASL
            8'h0a: {cycle_ref, page_cross} = {4'd2, 1'b0};
            8'h0e: {cycle_ref, page_cross} = {4'd6 + n_m8_2, 1'b0};
            8'h06: {cycle_ref, page_cross} = {4'd5 + n_m8_2 + n_dplz_1, 1'b0};
            8'h1e: {cycle_ref, page_cross} = {4'd7 + n_m8_2, 1'b0};
            8'h16: {cycle_ref, page_cross} = {4'd6 + n_m8_2 + n_dplz_1, 1'b0};

            // Branches
            8'h90: {cycle_ref, page_cross} = {4'd2 + e_1 + ((~p[C]) ? 3'h1 : 3'h0), 1'b0};
            8'hb0: {cycle_ref, page_cross} = {4'd2 + e_1 + (p[C] ? 3'h1 : 3'h0), 1'b0};
            8'hd0: {cycle_ref, page_cross} = {4'd2 + e_1 + ((~p[Z]) ? 3'h1 : 3'h0), 1'b0};
            8'hf0: {cycle_ref, page_cross} = {4'd2 + e_1 + (p[Z] ? 3'h1 : 3'h0), 1'b0};
            8'h10: {cycle_ref, page_cross} = {4'd2 + e_1 + ((~p[N]) ? 3'h1 : 3'h0), 1'b0};
            8'h30: {cycle_ref, page_cross} = {4'd2 + e_1 + (p[N] ? 3'h1 : 3'h0), 1'b0};
            8'h50: {cycle_ref, page_cross} = {4'd2 + e_1 + ((~p[V]) ? 3'h1 : 3'h0), 1'b0};
            8'h70: {cycle_ref, page_cross} = {4'd2 + e_1 + (p[V] ? 3'h1 : 3'h0), 1'b0};
            8'h80: {cycle_ref, page_cross} = {4'd3 + e_1, 1'b0};
            8'h82: {cycle_ref, page_cross} = {4'd4, 1'b0};

            // BIT
            8'h89: {cycle_ref, page_cross} = {4'd2 + n_m8_1, 1'b0};
            8'h2c: {cycle_ref, page_cross} = {4'd4 + n_m8_1, 1'b0};
            8'h24: {cycle_ref, page_cross} = {4'd3 + n_m8_1 + n_dplz_1, 1'b0};
            8'h3c: {cycle_ref, page_cross} = {4'd4 + n_m8_1, 1'b1};
            8'h34: {cycle_ref, page_cross} = {4'd4 + n_m8_1 + n_dplz_1, 1'b0};

            // Software Interrupts
            8'h00: {cycle_ref, page_cross} = {4'd7 + n_e_1, 1'b0};
            8'h02: {cycle_ref, page_cross} = {4'd7 + n_e_1, 1'b0};

            // Clear Status Flags
            8'h18: {cycle_ref, page_cross} = {4'd2, 1'b0};
            8'h58: {cycle_ref, page_cross} = {4'd2, 1'b0};
            8'hd8: {cycle_ref, page_cross} = {4'd2, 1'b0};
            8'hb8: {cycle_ref, page_cross} = {4'd2, 1'b0};

            // CMP
            8'hc9: {cycle_ref, page_cross} = {4'd2 + n_m8_1, 1'b0};
            8'hcd: {cycle_ref, page_cross} = {4'd4 + n_m8_1, 1'b0};
            8'hcf: {cycle_ref, page_cross} = {4'd5 + n_m8_1, 1'b0};
            8'hc5: {cycle_ref, page_cross} = {4'd3 + n_m8_1 + n_dplz_1, 1'b0};
            8'hd2: {cycle_ref, page_cross} = {4'd5 + n_m8_1 + n_dplz_1, 1'b0};
            8'hc7: {cycle_ref, page_cross} = {4'd6 + n_m8_1 + n_dplz_1, 1'b0};
            8'hdd: {cycle_ref, page_cross} = {4'd4 + n_m8_1, 1'b1};
            8'hdf: {cycle_ref, page_cross} = {4'd5 + n_m8_1, 1'b0};
            8'hd9: {cycle_ref, page_cross} = {4'd4 + n_m8_1, 1'b1};
            8'hd5: {cycle_ref, page_cross} = {4'd4 + n_m8_1 + n_dplz_1, 1'b0};
            8'hc1: {cycle_ref, page_cross} = {4'd6 + n_m8_1 + n_dplz_1, 1'b0};
            8'hd1: {cycle_ref, page_cross} = {4'd5 + n_m8_1 + n_dplz_1, 1'b1};
            8'hd7: {cycle_ref, page_cross} = {4'd6 + n_m8_1 + n_dplz_1, 1'b0};
            8'hc3: {cycle_ref, page_cross} = {4'd4 + n_m8_1, 1'b0};
            8'hd3: {cycle_ref, page_cross} = {4'd7 + n_m8_1, 1'b0};

            // CPX
            8'he0: {cycle_ref, page_cross} = {4'd2 + n_x8_1, 1'b0};
            8'hec: {cycle_ref, page_cross} = {4'd4 + n_x8_1, 1'b0};
            8'he4: {cycle_ref, page_cross} = {4'd3 + n_x8_1 + n_dplz_1, 1'b0};

            // CPY
            8'hc0: {cycle_ref, page_cross} = {4'd2 + n_x8_1, 1'b0};
            8'hcc: {cycle_ref, page_cross} = {4'd4 + n_x8_1, 1'b0};
            8'hc4: {cycle_ref, page_cross} = {4'd3 + n_x8_1 + n_dplz_1, 1'b0};

            // DEC
            8'h3a: {cycle_ref, page_cross} = {4'd2, 1'b0};
            8'hce: {cycle_ref, page_cross} = {4'd6 + n_m8_2, 1'b0};
            8'hc6: {cycle_ref, page_cross} = {4'd5 + n_m8_2 + n_dplz_1, 1'b0};
            8'hde: {cycle_ref, page_cross} = {4'd7 + n_m8_2, 1'b0};
            8'hd6: {cycle_ref, page_cross} = {4'd6 + n_m8_2 + n_dplz_1, 1'b0};

            // DEX, DEY
            8'hca: {cycle_ref, page_cross} = {4'd2, 1'b0};
            8'h88: {cycle_ref, page_cross} = {4'd2, 1'b0};

            // EOR
            8'h49: {cycle_ref, page_cross} = {4'd2 + n_m8_1, 1'b0};
            8'h4d: {cycle_ref, page_cross} = {4'd4 + n_m8_1, 1'b0};
            8'h4f: {cycle_ref, page_cross} = {4'd5 + n_m8_1, 1'b0};
            8'h45: {cycle_ref, page_cross} = {4'd3 + n_m8_1 + n_dplz_1, 1'b0};
            8'h52: {cycle_ref, page_cross} = {4'd5 + n_m8_1 + n_dplz_1, 1'b0};
            8'h47: {cycle_ref, page_cross} = {4'd6 + n_m8_1 + n_dplz_1, 1'b0};
            8'h5d: {cycle_ref, page_cross} = {4'd4 + n_m8_1, 1'b1};
            8'h5f: {cycle_ref, page_cross} = {4'd5 + n_m8_1, 1'b0};
            8'h59: {cycle_ref, page_cross} = {4'd4 + n_m8_1, 1'b1};
            8'h55: {cycle_ref, page_cross} = {4'd4 + n_m8_1 + n_dplz_1, 1'b0};
            8'h41: {cycle_ref, page_cross} = {4'd6 + n_m8_1 + n_dplz_1, 1'b0};
            8'h51: {cycle_ref, page_cross} = {4'd5 + n_m8_1 + n_dplz_1, 1'b1};
            8'h57: {cycle_ref, page_cross} = {4'd6 + n_m8_1 + n_dplz_1, 1'b0};
            8'h43: {cycle_ref, page_cross} = {4'd4 + n_m8_1, 1'b0};
            8'h53: {cycle_ref, page_cross} = {4'd7 + n_m8_1, 1'b0};

            // INC
            8'h1a: {cycle_ref, page_cross} = {4'd2, 1'b0};
            8'hee: {cycle_ref, page_cross} = {4'd6 + n_m8_2, 1'b0};
            8'he6: {cycle_ref, page_cross} = {4'd5 + n_m8_2 + n_dplz_1, 1'b0};
            8'hfe: {cycle_ref, page_cross} = {4'd7 + n_m8_2, 1'b0};
            8'hf6: {cycle_ref, page_cross} = {4'd6 + n_m8_2 + n_dplz_1, 1'b0};

            // INX, INY
            8'he8: {cycle_ref, page_cross} = {4'd2, 1'b0};
            8'hc8: {cycle_ref, page_cross} = {4'd2, 1'b0};

            // JMP
            8'h4c: {cycle_ref, page_cross} = {4'd3, 1'b0};
            8'h6c: {cycle_ref, page_cross} = {4'd5, 1'b0};
            8'h7c: {cycle_ref, page_cross} = {4'd6, 1'b0};
            8'h5c: {cycle_ref, page_cross} = {4'd4, 1'b0};
            8'hdc: {cycle_ref, page_cross} = {4'd6, 1'b0};

            // JSR, JSL
            8'h20: {cycle_ref, page_cross} = {4'd6, 1'b0};
            8'hfc: {cycle_ref, page_cross} = {4'd8, 1'b0};
            8'h22: {cycle_ref, page_cross} = {4'd8, 1'b0};

            // LDA
            8'ha9: {cycle_ref, page_cross} = {4'd2 + n_m8_1, 1'b0};
            8'had: {cycle_ref, page_cross} = {4'd4 + n_m8_1, 1'b0};
            8'haf: {cycle_ref, page_cross} = {4'd5 + n_m8_1, 1'b0};
            8'ha5: {cycle_ref, page_cross} = {4'd3 + n_m8_1 + n_dplz_1, 1'b0};
            8'hb2: {cycle_ref, page_cross} = {4'd5 + n_m8_1 + n_dplz_1, 1'b0};
            8'ha7: {cycle_ref, page_cross} = {4'd6 + n_m8_1 + n_dplz_1, 1'b0};
            8'hbd: {cycle_ref, page_cross} = {4'd4 + n_m8_1, 1'b1};
            8'hbf: {cycle_ref, page_cross} = {4'd5 + n_m8_1, 1'b0};
            8'hb9: {cycle_ref, page_cross} = {4'd4 + n_m8_1, 1'b1};
            8'hb5: {cycle_ref, page_cross} = {4'd4 + n_m8_1 + n_dplz_1, 1'b0};
            8'ha1: {cycle_ref, page_cross} = {4'd6 + n_m8_1 + n_dplz_1, 1'b0};
            8'hb1: {cycle_ref, page_cross} = {4'd5 + n_m8_1 + n_dplz_1, 1'b1};
            8'hb7: {cycle_ref, page_cross} = {4'd6 + n_m8_1 + n_dplz_1, 1'b0};
            8'ha3: {cycle_ref, page_cross} = {4'd4 + n_m8_1, 1'b0};
            8'hb3: {cycle_ref, page_cross} = {4'd7 + n_m8_1, 1'b0};

            // LDX
            8'ha2: {cycle_ref, page_cross} = {4'd2 + n_x8_1, 1'b0};
            8'hae: {cycle_ref, page_cross} = {4'd4 + n_x8_1, 1'b0};
            8'ha6: {cycle_ref, page_cross} = {4'd3 + n_x8_1 + n_dplz_1, 1'b0};
            8'hbe: {cycle_ref, page_cross} = {4'd4 + n_x8_1, 1'b1};
            8'hb6: {cycle_ref, page_cross} = {4'd4 + n_x8_1 + n_dplz_1, 1'b0};

            // LDY
            8'ha0: {cycle_ref, page_cross} = {4'd2 + n_x8_1, 1'b0};
            8'hac: {cycle_ref, page_cross} = {4'd4 + n_x8_1, 1'b0};
            8'ha4: {cycle_ref, page_cross} = {4'd3 + n_x8_1 + n_dplz_1, 1'b0};
            8'hbc: {cycle_ref, page_cross} = {4'd4 + n_x8_1, 1'b1};
            8'hb4: {cycle_ref, page_cross} = {4'd4 + n_x8_1 + n_dplz_1, 1'b0};

            // LSR
            8'h4a: {cycle_ref, page_cross} = {4'd2, 1'b0};
            8'h4e: {cycle_ref, page_cross} = {4'd6 + n_m8_2, 1'b0};
            8'h46: {cycle_ref, page_cross} = {4'd5 + n_m8_2 + n_dplz_1, 1'b0};
            8'h5e: {cycle_ref, page_cross} = {4'd7 + n_m8_2, 1'b0};
            8'h56: {cycle_ref, page_cross} = {4'd6 + n_m8_2 + n_dplz_1, 1'b0};

            // MVN, MVP
            8'h54: {cycle_ref, page_cross} = {4'd7, 1'b0};
            8'h44: {cycle_ref, page_cross} = {4'd7, 1'b0};

            // NOP
            8'hea: {cycle_ref, page_cross} = {4'd2, 1'b0};

            // ORA
            8'h09: {cycle_ref, page_cross} = {4'd2 + n_m8_1, 1'b0};
            8'h0d: {cycle_ref, page_cross} = {4'd4 + n_m8_1, 1'b0};
            8'h0f: {cycle_ref, page_cross} = {4'd5 + n_m8_1, 1'b0};
            8'h05: {cycle_ref, page_cross} = {4'd3 + n_m8_1 + n_dplz_1, 1'b0};
            8'h12: {cycle_ref, page_cross} = {4'd5 + n_m8_1 + n_dplz_1, 1'b0};
            8'h07: {cycle_ref, page_cross} = {4'd6 + n_m8_1 + n_dplz_1, 1'b0};
            8'h1d: {cycle_ref, page_cross} = {4'd4 + n_m8_1, 1'b1};
            8'h1f: {cycle_ref, page_cross} = {4'd5 + n_m8_1, 1'b0};
            8'h19: {cycle_ref, page_cross} = {4'd4 + n_m8_1, 1'b1};
            8'h15: {cycle_ref, page_cross} = {4'd4 + n_m8_1 + n_dplz_1, 1'b0};
            8'h01: {cycle_ref, page_cross} = {4'd6 + n_m8_1 + n_dplz_1, 1'b0};
            8'h11: {cycle_ref, page_cross} = {4'd5 + n_m8_1 + n_dplz_1, 1'b1};
            8'h17: {cycle_ref, page_cross} = {4'd6 + n_m8_1 + n_dplz_1, 1'b0};
            8'h03: {cycle_ref, page_cross} = {4'd4 + n_m8_1, 1'b0};
            8'h13: {cycle_ref, page_cross} = {4'd7 + n_m8_1, 1'b0};

            // PEA
            8'hf4: {cycle_ref, page_cross} = {4'd5, 1'b0};

            // PEI
            8'hd4: {cycle_ref, page_cross} = {4'd6 + n_dplz_1, 1'b0};

            // PER
            8'h62: {cycle_ref, page_cross} = {4'd6, 1'b0};

            // Push
            8'h48: {cycle_ref, page_cross} = {4'd3 + n_m8_1, 1'b0};
            8'h8b: {cycle_ref, page_cross} = {4'd3, 1'b0};
            8'h0b: {cycle_ref, page_cross} = {4'd4, 1'b0};
            8'h4b: {cycle_ref, page_cross} = {4'd3, 1'b0};
            8'h08: {cycle_ref, page_cross} = {4'd3, 1'b0};
            8'hda: {cycle_ref, page_cross} = {4'd3 + n_x8_1, 1'b0};
            8'h5a: {cycle_ref, page_cross} = {4'd3 + n_x8_1, 1'b0};

            // Pull
            8'h68: {cycle_ref, page_cross} = {4'd4 + n_m8_1, 1'b0};
            8'hab: {cycle_ref, page_cross} = {4'd4, 1'b0};
            8'h2b: {cycle_ref, page_cross} = {4'd5, 1'b0};
            8'h28: {cycle_ref, page_cross} = {4'd4, 1'b0};
            8'hfa: {cycle_ref, page_cross} = {4'd4 + n_x8_1, 1'b0};
            8'h7a: {cycle_ref, page_cross} = {4'd4 + n_x8_1, 1'b0};

            // REP
            8'hc2: {cycle_ref, page_cross} = {4'd3, 1'b0};

            // ROL
            8'h2a: {cycle_ref, page_cross} = {4'd2, 1'b0};
            8'h2e: {cycle_ref, page_cross} = {4'd6 + n_m8_2, 1'b0};
            8'h26: {cycle_ref, page_cross} = {4'd5 + n_m8_2 + n_dplz_1, 1'b0};
            8'h3e: {cycle_ref, page_cross} = {4'd7 + n_m8_2, 1'b0};
            8'h36: {cycle_ref, page_cross} = {4'd6 + n_m8_2 + n_dplz_1, 1'b0};

            // ROR
            8'h6a: {cycle_ref, page_cross} = {4'd2, 1'b0};
            8'h6e: {cycle_ref, page_cross} = {4'd6 + n_m8_2, 1'b0};
            8'h66: {cycle_ref, page_cross} = {4'd5 + n_m8_2 + n_dplz_1, 1'b0};
            8'h7e: {cycle_ref, page_cross} = {4'd7 + n_m8_2, 1'b0};
            8'h76: {cycle_ref, page_cross} = {4'd6 + n_m8_2 + n_dplz_1, 1'b0};

            // RTI, RTS, RTL
            8'h40: {cycle_ref, page_cross} = {4'd6 + n_e_1, 1'b0};
            8'h60: {cycle_ref, page_cross} = {4'd6, 1'b0};
            8'h6b: {cycle_ref, page_cross} = {4'd6, 1'b0};

            // SBC
            8'he9: {cycle_ref, page_cross} = {4'd2 + n_m8_1, 1'b0};
            8'hed: {cycle_ref, page_cross} = {4'd4 + n_m8_1, 1'b0};
            8'hef: {cycle_ref, page_cross} = {4'd5 + n_m8_1, 1'b0};
            8'he5: {cycle_ref, page_cross} = {4'd3 + n_m8_1 + n_dplz_1, 1'b0};
            8'hf2: {cycle_ref, page_cross} = {4'd5 + n_m8_1 + n_dplz_1, 1'b0};
            8'he7: {cycle_ref, page_cross} = {4'd6 + n_m8_1 + n_dplz_1, 1'b0};
            8'hfd: {cycle_ref, page_cross} = {4'd4 + n_m8_1, 1'b1};
            8'hff: {cycle_ref, page_cross} = {4'd5 + n_m8_1, 1'b0};
            8'hf9: {cycle_ref, page_cross} = {4'd4 + n_m8_1, 1'b1};
            8'hf5: {cycle_ref, page_cross} = {4'd4 + n_m8_1 + n_dplz_1, 1'b0};
            8'he1: {cycle_ref, page_cross} = {4'd6 + n_m8_1 + n_dplz_1, 1'b0};
            8'hf1: {cycle_ref, page_cross} = {4'd5 + n_m8_1 + n_dplz_1, 1'b1};
            8'hf7: {cycle_ref, page_cross} = {4'd6 + n_m8_1 + n_dplz_1, 1'b0};
            8'he3: {cycle_ref, page_cross} = {4'd4 + n_m8_1, 1'b0};
            8'hf3: {cycle_ref, page_cross} = {4'd7 + n_m8_1, 1'b0};

            // SEC, SEI, SED
            8'h38: {cycle_ref, page_cross} = {4'd2, 1'b0};
            8'h78: {cycle_ref, page_cross} = {4'd2, 1'b0};
            8'hf8: {cycle_ref, page_cross} = {4'd2, 1'b0};

            // SEP
            8'he2: {cycle_ref, page_cross} = {4'd3, 1'b0};

            // STA
            8'h8d: {cycle_ref, page_cross} = {4'd4 + n_m8_1, 1'b0};
            8'h8f: {cycle_ref, page_cross} = {4'd5 + n_m8_1, 1'b0};
            8'h85: {cycle_ref, page_cross} = {4'd3 + n_m8_1 + n_dplz_1, 1'b0};
            8'h92: {cycle_ref, page_cross} = {4'd5 + n_m8_1 + n_dplz_1, 1'b0};
            8'h87: {cycle_ref, page_cross} = {4'd6 + n_m8_1 + n_dplz_1, 1'b0};
            8'h9d: {cycle_ref, page_cross} = {4'd5 + n_m8_1, 1'b0};
            8'h9f: {cycle_ref, page_cross} = {4'd5 + n_m8_1, 1'b0};
            8'h99: {cycle_ref, page_cross} = {4'd5 + n_m8_1, 1'b0};
            8'h95: {cycle_ref, page_cross} = {4'd4 + n_m8_1 + n_dplz_1, 1'b0};
            8'h81: {cycle_ref, page_cross} = {4'd6 + n_m8_1 + n_dplz_1, 1'b0};
            8'h91: {cycle_ref, page_cross} = {4'd6 + n_m8_1 + n_dplz_1, 1'b0};
            8'h97: {cycle_ref, page_cross} = {4'd6 + n_m8_1 + n_dplz_1, 1'b0};
            8'h83: {cycle_ref, page_cross} = {4'd4 + n_m8_1, 1'b0};
            8'h93: {cycle_ref, page_cross} = {4'd7 + n_m8_1, 1'b0};

            // STP
            8'hdb: {cycle_ref, page_cross} = {4'd1, 1'b0};

            // STX
            8'h8e: {cycle_ref, page_cross} = {4'd4 + n_x8_1, 1'b0};
            8'h86: {cycle_ref, page_cross} = {4'd3 + n_x8_1 + n_dplz_1, 1'b0};
            8'h96: {cycle_ref, page_cross} = {4'd4 + n_x8_1 + n_dplz_1, 1'b0};

            // STY
            8'h8c: {cycle_ref, page_cross} = {4'd4 + n_x8_1, 1'b0};
            8'h84: {cycle_ref, page_cross} = {4'd3 + n_x8_1 + n_dplz_1, 1'b0};
            8'h94: {cycle_ref, page_cross} = {4'd4 + n_x8_1 + n_dplz_1, 1'b0};

            // STZ
            8'h9c: {cycle_ref, page_cross} = {4'd4 + n_m8_1, 1'b0};
            8'h64: {cycle_ref, page_cross} = {4'd3 + n_m8_1 + n_dplz_1, 1'b0};
            8'h9e: {cycle_ref, page_cross} = {4'd5 + n_m8_1, 1'b0};
            8'h74: {cycle_ref, page_cross} = {4'd4 + n_m8_1 + n_dplz_1, 1'b0};

            // Transfer Registers
            8'haa: {cycle_ref, page_cross} = {4'd2, 1'b0};
            8'ha8: {cycle_ref, page_cross} = {4'd2, 1'b0};
            8'h5b: {cycle_ref, page_cross} = {4'd2, 1'b0};
            8'h1b: {cycle_ref, page_cross} = {4'd2, 1'b0};
            8'h7b: {cycle_ref, page_cross} = {4'd2, 1'b0};
            8'h3b: {cycle_ref, page_cross} = {4'd2, 1'b0};
            8'hba: {cycle_ref, page_cross} = {4'd2, 1'b0};
            8'h8a: {cycle_ref, page_cross} = {4'd2, 1'b0};
            8'h9a: {cycle_ref, page_cross} = {4'd2, 1'b0};
            8'h9b: {cycle_ref, page_cross} = {4'd2, 1'b0};
            8'h98: {cycle_ref, page_cross} = {4'd2, 1'b0};
            8'hbb: {cycle_ref, page_cross} = {4'd2, 1'b0};

            // TRB
            8'h1c: {cycle_ref, page_cross} = {4'd6 + n_m8_2, 1'b0};
            8'h14: {cycle_ref, page_cross} = {4'd5 + n_m8_2 + n_dplz_1, 1'b0};

            // TSB
            8'h0c: {cycle_ref, page_cross} = {4'd6 + n_m8_2, 1'b0};
            8'h04: {cycle_ref, page_cross} = {4'd5 + n_m8_2 + n_dplz_1, 1'b0};

            // WAI
            8'hcb: {cycle_ref, page_cross} = {4'd1, 1'b0};

            // WDM
            8'h42: {cycle_ref, page_cross} = {4'd2, 1'b0};

            // XBA
            8'heb: {cycle_ref, page_cross} = {4'd3, 1'b0};

            // XCE
            8'hfb: {cycle_ref, page_cross} = {4'd2, 1'b0};
        endcase
    end

    // error
    always_ff @(posedge clk) begin
        if (reset) begin
            error <= 1'b0;
        end else if (cpu_en & state_fetch_opcode) begin
            error <= (~hard_int) & (
                ~(
                    (cycle_ctr == (cycle_ref - 4'd1))
                    | (page_cross & (cycle_ctr == cycle_ref))
                )
            );
        end
    end
    
endmodule
