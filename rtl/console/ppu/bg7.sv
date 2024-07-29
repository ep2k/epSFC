// ==============================
//  BG Mode 7 (Rotation/Scaling)
// ==============================

// Copyright(C) 2024 ep2k All Rights Reserved.

module bg7
    import ppu_pkg::*;
(
    input logic clk,
    input logic reset,
    input logic dot_en,
    input logic [2:0] dot_ctr,

    input logic [3:0] m7sel,

    input logic [15:0] m7_a,
    input logic [15:0] m7_b,
    input logic [15:0] m7_c,
    input logic [15:0] m7_d,

    input logic [12:0] m7_xofs,
    input logic [12:0] m7_yofs,
    input logic [12:0] m7_xorig,
    input logic [12:0] m7_yorig,

    input logic [7:0] x,
    input logic [7:0] y,

    output logic [14:0] vram_l_addr,
    output logic [14:0] vram_h_addr,
    input logic [7:0] vram_rdata_l,
    input logic [7:0] vram_rdata_h,

    output bg_pixel_type pixel
);
    
    // ------------------------------
    //  Wires
    // ------------------------------

    logic signed [15:0] mul1_a, mul2_a;     // A, B, C, D
    logic signed [12:0] mul1_b, mul2_b;     // X + XOFS - XO, Y + YOFS - YO
                                            // (12(+1)bit + 12(+1)bit + 8bit -> Max. 12(+1)bit)
    logic signed [27:0] mul1_y, mul2_y;     // 15bit+12bit+1bit=28bit

    // ------------------------------
    //  Registers
    // ------------------------------
    
    // ------------------------------
    //  Main
    // ------------------------------
    
    // ---- Multiplier --------

    /*
        Mul1:
            t=0(VRAM.X): A * (X + XOFS - XO)
            t=1(VRAM.Y): C * (X + XOFS - XO)
        Mul2:
            t=0(VRAM.X): B * (Y + YOFS - YO)
            t=1(VRAM.Y): D * (Y + YOFS - YO)
    */

    assign mul1_a = dot_ctr[0] ? m7_c : m7_a;
    assign mul1_b = {5'h0, m7sel[0] ? (~x) : x} + m7_xofs - m7_xorig;       // x_flip if m7sel[0]=1

    assign mul2_a = dot_ctr[0] ? m7_d : m7_b;
    assign mul2_b = {5'h0, m7sel[1] ? (~y) : y} + m7_yofs - m7_yorig;       // y_flip if m7sel[1]=1

    assign mul1_y = $signed(mul1_a) * $signed(mul1_b);
    assign mul2_y = $signed(mul2_a) * $signed(mul2_b);

endmodule
