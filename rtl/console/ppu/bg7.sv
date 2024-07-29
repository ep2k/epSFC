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
    


endmodule
