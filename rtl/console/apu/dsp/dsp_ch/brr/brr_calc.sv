// ==============================
//  BRR Calculation
// ==============================

// Copyright(C) 2024 ep2k All Rights Reserved.

module brr_calc (
    input logic [14:0] sample_shift,
    input logic [14:0] pcm1,
    input logic [14:0] pcm2,
    input logic [1:0] filter,

    output logic [14:0] pcm
);
    
    // ------------------------------
    //  Wires
    // ------------------------------
    
    logic [18:0] pcm1_x15;
    logic [20:0] pcm1_x61;
    logic [21:0] pcm1_x115;
    logic [18:0] pcm2_x15;
    logic [18:0] pcm2_x13;

    logic [14:0] pcm1_15p16;
    logic [15:0] pcm1_61p32;
    logic [15:0] pcm1_115p64;
    logic [14:0] pcm2_15p16;
    logic [14:0] pcm2_13p16;
    
    // ------------------------------
    //  Main
    // ------------------------------

    assign pcm1_x15
        = {pcm1, 4'h0} - {{4{pcm1[14]}}, pcm1}; // 14+4+1 bit
    assign pcm1_x61
        = {pcm1, 6'h0} - {{5{pcm1[14]}}, pcm1, 1'b0} - {{6{pcm1[14]}}, pcm1}; // 14+6+1 bit
    assign pcm1_x115
        = {pcm1, 7'h0} - {{4{pcm1[14]}}, pcm1, 3'h0} - {{5{pcm1[14]}}, pcm1, 2'h0} - {{7{pcm1[14]}}, pcm1}; // 14+7+1 bit
    assign pcm2_x15
        = {pcm2, 4'h0} - {{4{pcm2[14]}}, pcm2}; // 14+4+1 bit
    assign pcm2_x13
        = {pcm2[14], pcm2, 3'h0} + {{2{pcm2[14]}}, pcm2, 2'h0} + {{4{pcm2[14]}}, pcm2}; // 14+4+1 bit

    assign pcm1_15p16 = pcm1_x15[18:4];
    assign pcm1_61p32 = pcm1_x61[20:5];
    assign pcm1_115p64 = pcm1_x115[21:6];
    assign pcm2_15p16 = pcm2_x15[18:4];
    assign pcm2_13p16 = pcm2_x13[18:4];

    always_comb begin
        unique case (filter)
            2'b00: pcm = sample_shift;
            2'b01: pcm = sample_shift + pcm1_15p16;
            2'b10: pcm = {sample_shift[14], sample_shift} + pcm1_61p32 - {pcm2_15p16[14], pcm2_15p16};
            2'b11: pcm = {sample_shift[14], sample_shift} + pcm1_115p64 - {pcm2_13p16[14], pcm2_13p16};
        endcase
    end

endmodule
