// ===================================
//  Template of Config Header File
// ===================================

// Copy and edit as "config.vh"

// Copyright(C) 2024 ep2k All Rights Reserved.

`ifndef CONFIG_VH
`define CONFIG_VH

// ---- APU --------

`define USE_INTERPOLATE         // Comment out to disable

// ---- Internal Cartridge --------

`define USE_INTCART             // Comment out to disable

// ---- VGA --------

`define VGA_H_BACK 10'd48       // 0-64
`define VGA_V_BACK 10'd32       // 0-43

// ---- Additional Functions --------

`define USE_COORD_POINTER       // Comment out to disable
  `define COORD_POINTER_R 5'h1F // 0-1F
  `define COORD_POINTER_G 5'h0  // 0-1F
  `define COORD_POINTER_B 5'h0  // 0-1F
`define USE_ENVX_SQUARE_PWM     // Comment out to disable
`define USE_SOUND_ABS_MAX       // Comment out to disable
`define USE_CPU_CYCLE_DEBUG     // Comment out to disable


`endif // CONFIG_VH
