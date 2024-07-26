// ==============================
//  Noise Sample Generator
// ==============================

// Copyright(C) 2024 ep2k All Rights Reserved.

module noise (
    input logic clk,
    input logic cpu_en,
    input logic reset,

    input logic exe_32khz,

    input logic [4:0] rate_id,
    output logic [14:0] sample
);

    // ------------------------------
    //  Wires
    // ------------------------------
    
    logic [10:0] rate;

    // ------------------------------
    //  Registers
    // ------------------------------
    
    logic [14:0] sample_reg = 15'h4000;
    logic [10:0] rate_ctr = 11'h0;

    // ------------------------------
    //  Main
    // ------------------------------

    assign sample = sample_reg;

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

    always_ff @(posedge clk) begin
        if (reset) begin
            rate_ctr <= 11'h0;
        end else if (cpu_en & exe_32khz) begin
            rate_ctr <= (rate_ctr < rate) ? (rate_ctr + 11'h1) : 11'h0;
        end
    end

    // Linear Feedback Shift Register
    always_ff @(posedge clk) begin
        if (reset) begin
            sample_reg <= 15'h4000;
        end else if (cpu_en & exe_32khz & (rate_id != 5'h0) & (rate_ctr == rate)) begin
            sample_reg <= {sample_reg[0] ^ sample_reg[1], sample_reg[14:1]};
        end
    end
    
endmodule
