// =============================================
//  Template of Assignment in Top Module File
// =============================================

// Copy and edit as "top_assignment.vh"

// Copyright(C) 2024 ep2k All Rights Reserved.

// -----------------------------------
//  Toggle Switch / Push button Input
// -----------------------------------

/*
    ---------------
      Example
    ---------------

    // ---- Reset --------

    assign reset_ext = ~RESET_N;

    // ---- Internal Cartridge --------

    assign use_intcart = 1'b0;              // ifdef USE_INTCART

    // ---- Additional Functions --------

    assign graphic_off = {1'b0, ~KEY};
    assign sound_off = SW[7:0];
    assign interpol_sel = 2'h0;             // ifdef USE_INTERPOLATE
    assign echo_off = 1'b0;
    assign pad_exchange = SW[8];
    assign coord_pointer_en = SW[9];         // ifdef USE_COORD_POINTER
    assign coord_pointer_coarse = 1'b0;     // ifdef USE_COORD_POINTER
    
*/

// ---- Reset --------

assign reset_ext = ~RESET_N;

// ---- Internal Cartridge --------

assign use_intcart = 1'b0;              // ifdef USE_INTCART

// ---- Additional Functions --------

assign graphic_off = 5'h0;
assign sound_off = 8'h0;
assign interpol_sel = 2'h0;             // ifdef USE_INTERPOLATE
assign echo_off = 1'b0;
assign pad_exchange = 1'b0;
assign coord_pointer_en = 1'b0;         // ifdef USE_COORD_POINTER
assign coord_pointer_coarse = 1'b0;     // ifdef USE_COORD_POINTER


// ------------------------------
//  LED / Seven Segment Output
// ------------------------------

/*
    --------------------
      List of signals
    --------------------

    [2:0] bgmode
    [11:0] frame_ctr
    var_fast
    
    [7:0] coord_pointer_x   // ifdef USE_COORD_POINTER
    [7:0] coord_pointer_y   // ifdef USE_COORD_POINTER
    [7:0] envx_square_pwm   // ifdef USE_ENVX_SQUARE_PWM
    [14:0] sound_abs_max    // ifdef USE_SOUND_ABS_MAX

    [6:0] hex_p1_l  // Directly assign to HEX
    [6:0] hex_p1_r  // Directly assign to HEX
    [6:0] hex_p2_l  // Directly assign to HEX
    [6:0] hex_p2_r  // Directly assign to HEX

    -------------------------
      Seven Segment Template
    -------------------------

    seg7 seg7_x(
        .din(value[3:0]),
        .dout(HEX)
    );

    ---------------
      Example
    ---------------

    assign LEDR = {var_fast, 1'b0, envx_square_pwm};

    assign HEX0 = hex_p2_r;
    assign HEX1 = hex_p2_l;
    assign HEX2 = hex_p1_r;
    assign HEX3 = hex_p1_l;

    assign HEX4 = 7'h7f;

    seg7 seg7_5(
        .din({1'b0, bgmode}),
        .dout(HEX5)
    );

*/

assign LEDR = 10'h0;

assign HEX0 = 7'h7f;
assign HEX1 = 7'h7f;
assign HEX2 = 7'h7f;
assign HEX3 = 7'h7f;
assign HEX4 = 7'h7f;
assign HEX5 = 7'h7f;
