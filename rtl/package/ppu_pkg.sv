// ==============================
//  PPU Package
// ==============================

// Copyright(C) 2024 ep2k All Rights Reserved.

`ifndef PPU_PKG_SV
`define PPU_PKG_SV

package ppu_pkg;

    parameter MAX_BPP = 8;

    typedef struct packed {
        logic [MAX_BPP-1:0] main;
        logic [MAX_BPP-1:0] sub;

        logic [2:0] palette;
        logic prior;
    } bg_pixel_type;

    typedef struct packed {
        logic [3:0] main;

        logic [2:0] palette;
        logic [1:0] prior;
    } obj_pixel_type;

    typedef struct packed {
        logic [7:0] pixels_3;
        logic [7:0] pixels_2;
        logic [7:0] pixels_1;
        logic [7:0] pixels_0;
        logic signed [8:0] x;
        logic [2:0] palette;
        logic [1:0] prior;
    } obj_type;

    typedef struct packed {
        logic signed [8:0] x;
        logic [2:0] palette;
        logic [1:0] prior;
        logic [7:0] tile_exist;
        logic [8:0] tile_index;
        logic [5:0] fine_y;
        logic x_flip;
        logic [2:0] size_x;
    } obj_next_list_type;

    typedef enum logic [3:0] {
        BG1_2, BG1_4, BG1_8,
        BG2_2_0, BG2_2, BG2_4, BG2_7,
        BG3_2_0, BG3_2,
        BG4_2,
        OBJ,
        BACK
    } refer_pal_type;

endpackage

`endif  // PPU_PKG_SV
