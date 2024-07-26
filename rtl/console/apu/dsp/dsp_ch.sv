// ==============================
//  Channel Sound Processing
// ==============================

// Copyright(C) 2024 ep2k All Rights Reserved.

`include "config.vh"

module dsp_ch
    import apu_pkg::*;
(
    input logic clk,        // 10.24MHz
    input logic cpu_en,     // 1.24MHz
    input logic reset,

    input logic signed [7:0] vol_l,
    input logic signed [7:0] vol_r,
    input logic [15:0] pitch,
    input logic [7:0] srcn,
    input logic [15:0] adsr_control,
    input logic [7:0] gain_control,
    input logic pmon_en,
    input logic noise_en,

    input logic [7:0] sample_dir,

    input logic [14:0] noise_sample,

    input logic key_on,
    input logic key_off,

    input logic [10:0] pmon_factor,

    input logic src_access,
    input logic brr_control_access,
    input logic brr_sample_access,
    input logic pcm_calc,
    input logic [1:0] pcm_calc_num,
    input logic exe_32khz,

    output logic [14:0] src_addr,   // LSBは0と1両方アクセス
    output logic [15:0] brr_control_addr,
    output logic [15:0] brr_sample_addr_0,
    output logic [15:0] brr_sample_addr_1,
    input logic [7:0] aram_rdata_0,
    input logic [7:0] aram_rdata_1,

    `ifdef USE_INTERPOLATE
        output logic [14:0] interpol_pcm_x[3:0],
        output logic [7:0] interpol_index,
        input logic [14:0] interpol_out,
    `endif

    output logic [14:0] chsound_l,
    output logic [14:0] chsound_r,

    output logic [6:0] envx,
    output logic [14:0] outx,
    output logic set_endx
);

    // ------------------------------
    //  Wires
    // ------------------------------
    
    logic brr_end;
    logic env_stop;

    logic [10:0] level;
    logic adsr_release;

    `ifndef USE_INTERPOLATE
        logic [14:0] pcm1_out;
    `endif

    logic signed [25:0] outx_raw;
    logic signed [21:0] chsound_l_raw, chsound_r_raw;
    
    // ------------------------------
    //  Main
    // ------------------------------

    brr brr(
        .clk,
        .cpu_en,
        .reset,

        .src_access,
        .brr_control_access,
        .brr_sample_access,
        .pcm_calc,
        .pcm_calc_num,
        .exe_32khz,

        .dir(sample_dir),
        .srcn,
        .pitch(pitch[13:0]),
        .pmon_en,
        .pmon_factor,

        .key_on,

        .src_addr,
        .brr_control_addr,
        .brr_sample_addr_0,
        .brr_sample_addr_1,

        .aram_rdata_0,
        .aram_rdata_1,
        
        .adsr_release,

        `ifdef USE_INTERPOLATE
            .interpol_pcm_x,
            .interpol_index,
        `else
            .pcm1_out,
        `endif

        .set_endx,
        .brr_end,
        .env_stop
    );

    envelope envelope(
        .clk,
        .cpu_en,
        .reset,

        .key_on,
        .key_off,
        .brr_end,

        .exe_32khz,

        .env_stop,

        .adsr_control,
        .gain_control,

        .level,
        .is_release(adsr_release)
    );
    
    assign envx = level[10:4];
    
    `ifdef USE_INTERPOLATE
        assign outx_raw = noise_en
            ? $signed(noise_sample) * $signed({1'b0, level})
            : $signed(interpol_out) * $signed({1'b0, level});
    `else
        assign outx_raw = noise_en
            ? $signed(noise_sample) * $signed({1'b0, level});
            : $signed(pcm1_out) * $signed({1'b0, level}); // 26=14+11+1
    `endif

    assign outx = outx_raw[25:11];

    assign chsound_l_raw = $signed(outx) * $signed(vol_l);
    assign chsound_r_raw = $signed(outx) * $signed(vol_r);

    assign chsound_l = chsound_l_raw[21:7];
    assign chsound_r = chsound_r_raw[21:7];
    
endmodule
