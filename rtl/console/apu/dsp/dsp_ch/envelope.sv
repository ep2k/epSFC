// ==============================
//  Envelope (ADSR/GAIN)
// ==============================

// Copyright(C) 2024 ep2k All Rights Reserved.

module envelope (
    input logic clk,
    input logic cpu_en,
    input logic reset,

    input logic key_on,
    input logic key_off,
    input logic brr_end,

    input logic exe_32khz,

    input logic [15:0] adsr_control,
    input logic [7:0] gain_control,

    input logic env_stop,

    output logic [10:0] level = 11'h0,
    output logic is_release
);

    typedef enum logic [1:0] {
        ADSR_ATTACK,
        ADSR_DECAY,
        ADSR_SUSTAIN,
        ADSR_RELEASE
    } adsr_state_type;
    
    // ------------------------------
    //  Wires
    // ------------------------------
    
    logic [4:0] rate_id;
    logic [10:0] rate;

    logic [10:0] step;
    logic minus;

    logic [10:0] level_m1;              // level - 1
    logic [10:0] level_m1_rls8_p1;      // ((Level - 1) >> 8) + 1
    logic [11:0] level_next_raw;
    logic [10:0] level_next;            // level_next_raw[11]=1ならクリップ

    // ------------------------------
    //  Registers
    // ------------------------------
    
    adsr_state_type adsr_state = ADSR_RELEASE;

    logic [10:0] rate_ctr = 11'h0;

    // ------------------------------
    //  Main
    // ------------------------------    

    // ---- State Machiine --------

    always_ff @(posedge clk) begin
        if (reset) begin
            adsr_state <= ADSR_RELEASE;
        end else if (key_on) begin
            adsr_state <= ADSR_ATTACK;
        end else if (key_off) begin
            adsr_state <= ADSR_RELEASE;
        end else if (cpu_en) begin
            if (brr_end) begin
                adsr_state <= ADSR_RELEASE;
            end else if (exe_32khz & (~env_stop)) begin
                if ((adsr_state == ADSR_ATTACK) & (level[10:5] == '1)) begin
                    adsr_state <= ADSR_DECAY;
                end else if ((adsr_state == ADSR_DECAY) & (level[10:8] <= adsr_control[15:13])) begin
                    adsr_state <= ADSR_SUSTAIN;
                end
            end
        end
    end

    assign is_release = (adsr_state == ADSR_RELEASE);

    always_comb begin
        if (adsr_state == ADSR_RELEASE) begin
            rate_id = 5'h1f;
            step = 11'd8;
            minus = 1'b1;
        end else if (adsr_control[7] | (~gain_control[7])) begin // ADSRモード/DIRECT GAIN
            case (adsr_state)
                ADSR_ATTACK: begin
                    rate_id = {adsr_control[3:0], 1'b1};
                    step = (rate_id == 5'h1f) ? 11'd1024 : 11'd32;
                    minus = 1'b0;
                end
                ADSR_DECAY: begin
                    rate_id = {1'b1, adsr_control[6:4], 1'b0};
                    step = level_m1_rls8_p1;
                    minus = 1'b1;
                end
                ADSR_SUSTAIN: begin
                    rate_id = adsr_control[12:8];
                    step = level_m1_rls8_p1;
                    minus = 1'b1;
                end
                default: begin
                    rate_id = 'x;
                    step = 'x;
                    minus = 'x;
                end
            endcase
        end else begin // CUSTOM GAIN
            rate_id = gain_control[4:0];
            unique case (gain_control[6:5])
                2'b00: begin // Linear Decrease
                    step = 11'd32;
                    minus = 1'b1;
                end
                2'b01: begin // Exp Decrease
                    step = level_m1_rls8_p1;
                    minus = 1'b1;
                end
                2'b10: begin // Linear Increase
                    step = 11'd32;
                    minus = 1'b0;
                end
                2'b11: begin // Bent Increase
                    step = (level[10:9] == 2'b11) ? 11'd8 : 11'd32;
                    minus = 1'b0;
                end
            endcase
        end
    end

    // ---- Rate Counter --------

    always_comb begin
        unique case (rate_id)
            5'h0: rate = 11'd0;
            5'h1: rate = 11'd2047;
            5'h2: rate = 11'd1535;
            5'h3: rate = 11'd1279;
            5'h4: rate = 11'd1023;
            5'h5: rate = 11'd767;
            5'h6: rate = 11'd639;
            5'h7: rate = 11'd511;
            5'h8: rate = 11'd383;
            5'h9: rate = 11'd319;
            5'ha: rate = 11'd255;
            5'hb: rate = 11'd191;
            5'hc: rate = 11'd159;
            5'hd: rate = 11'd127;
            5'he: rate = 11'd95;
            5'hf: rate = 11'd79;
            5'h10: rate = 11'd63;
            5'h11: rate = 11'd47;
            5'h12: rate = 11'd39;
            5'h13: rate = 11'd31;
            5'h14: rate = 11'd23;
            5'h15: rate = 11'd19;
            5'h16: rate = 11'd15;
            5'h17: rate = 11'd11;
            5'h18: rate = 11'd9;
            5'h19: rate = 11'd7;
            5'h1a: rate = 11'd5;
            5'h1b: rate = 11'd4;
            5'h1c: rate = 11'd3;
            5'h1d: rate = 11'd2;
            5'h1e: rate = 11'd1;
            5'h1f: rate = 11'd0; 
        endcase
    end

    // rate_ctr
    always_ff @(posedge clk) begin
        if (reset) begin
            rate_ctr <= 11'h0;
        end else if (key_on) begin
            rate_ctr <= 11'h0;
        end else if (cpu_en & exe_32khz & (~env_stop)) begin
            rate_ctr <= (rate_ctr < rate) ? (rate_ctr + 11'h1) : 11'h0;
        end
    end

    // ---- Level --------

    // level
    always_ff @(posedge clk) begin
        if (reset) begin
            level <= 11'h0;
        end else if (key_on) begin
            level <= 11'h0;
        end else if (cpu_en) begin
            if (brr_end) begin
                level <= 11'h0;
            end else if (exe_32khz & (~env_stop)) begin // 32kHz
                if ((~adsr_control[7]) & (~gain_control[7]) & (adsr_state != ADSR_RELEASE)) begin // DIRECT GAIN
                    level <= {gain_control[6:0], 4'h0};
                end else if ((rate_id != 5'd0) & (rate_ctr == rate)) begin
                    level <= level_next;
                end
            end
        end
    end

    assign level_next_raw = minus
                ? ({1'b0, level} - {1'b0, step})
                : ({1'b0, level} + {1'b0, step});
    assign level_next = level_next_raw[11]
                ? (minus ? 11'h0 : 11'h7ff) : level_next_raw[10:0]; // オーバーフロー時にクリップ

    assign level_m1 = level - 11'h1;
    assign level_m1_rls8_p1 = {8'h0, level_m1[10:8]} + 11'h1;

endmodule
