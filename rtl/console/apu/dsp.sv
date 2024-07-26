// ===================================
//  S-DSP (ADPCM Audio Processing)
// ===================================

// Copyright(C) 2024 ep2k All Rights Reserved.

`include "config.vh"

module dsp
    import apu_pkg::*;
(
    input logic clk,
    input logic cpu_en,
    input logic [3:0] clk_step,
    input logic reset,

    input logic [6:0] dspaddr,
    input logic [7:0] dspaddr_wdata,
    output logic [7:0] dspaddr_rdata,
    input logic dspaddr_write,

    output logic [15:0] addr_0,
    input logic [7:0] rdata_0,
    output logic [7:0] wdata_0,
    output logic [15:0] addr_1,
    input logic [7:0] rdata_1,
    output logic [7:0] wdata_1,
    output logic write,

    output logic [15:0] sound_l,
    output logic [15:0] sound_r,

    output logic [6:0] envx_x[7:0],
    input logic [7:0] sound_off,
    input logic [1:0] interpol_sel,
    input logic echo_off
);

    genvar gi;

    // ------------------------------
    //  Wires
    // ------------------------------
    
    dsp_target_type target;
    logic [2:0] ch;

    logic exe_32khz;

    // ---- Channel Sound --------

    logic [14:0] noise_sample;

    logic [14:0] src_addr_x[7:0];
    logic [15:0] brr_control_addr_x[7:0];
    logic [15:0] brr_sample_addr_0_x[7:0];
    logic [15:0] brr_sample_addr_1_x[7:0];

    `ifdef USE_INTERPOLATE
        logic [14:0] interpol_pcm_x_y[7:0][3:0];
        logic [7:0] interpol_index_x[7:0];
        logic [14:0] interpol_out_x[7:0];
    `endif

    logic [14:0] chsound_l_x[7:0];
    logic [14:0] chsound_r_x[7:0];

    logic [14:0] outx_x[7:0];
    logic [7:0] set_endx;

    // ---- Main Mix --------

    logic signed [17:0] suml_raw, sumr_raw;             // Max: 3FFF*8=1FFF8(17bit) + sign(1bit)
    logic signed [15:0] suml, sumr;                     // suml/r_rawにオーバーフロー処理
    logic signed [17:0] suml_echo_raw, sumr_echo_raw;   // Max: 3FFF*8=1FFF8(17bit) + sign(1bit)
    logic signed [15:0] suml_echo, sumr_echo;           // suml/r_echo_rawにオーバーフロー処理
    logic signed [22:0] suml_x_mvl_raw, sumr_x_mvr_raw; // suml/r * mvol_l/r, sumr * mvol_r
    logic signed [15:0] suml_x_mvl, sumr_x_mvr;         // suml/r_x_mvl/r_raw >> 7

    // ---- Echo --------

    logic [15:0] echo_addr_0, echo_addr_1;
    logic [7:0] echo_wdata_0, echo_wdata_1;

    logic signed [15:0] echo_l, echo_r;

    logic signed [22:0] ecl_x_evl_raw, ecr_x_evr_raw;   // echo_l/r * evol_l/r
    logic signed [15:0] ecl_x_evl, ecr_x_evr;           // ecl/r_x_evl/r >> 7

    // ---- Main + Echo --------

    logic [16:0] sound_l_raw, sound_r_raw;

    // ------------------------------
    //  Registers
    // ------------------------------
    
    logic [7:0] vol_l_x[7:0];           // Left channel volume (signed)
    logic [7:0] vol_r_x[7:0];           // Right channel volume (signed)
    logic [15:0] pitch_x[7:0];          // Pitch (14bit, 上位2bitは読み書きのみ)
    logic [7:0] srcn_x[7:0];            // Source number (Sample table entry)
    logic [15:0] adsr_control_x[7:0];   // ADSR control
    logic [7:0] gain_control_x[7:0];    // GAIN control

    logic signed [7:0] mvol_l = 8'h0, mvol_r = 8'h0;    // Main volume (signed)
    logic signed [7:0] evol_l = 8'h0, evol_r = 8'h0;    // Echo volume (signed)
    logic [7:0] control = 8'b111_00000;                 // FLG
    logic [7:0] endx = 8'h0;                            // Sample end flg
    logic signed [7:0] echo_fb = 8'h0;                  // Echo feedback volume (signed)
    logic [7:0] unused = 8'h0;                          // Unused register(R/W)
    logic [7:0] pmon_en = 8'h0;                         // Pitch modulation enable (for each voice)
    logic [7:0] noise_en = 8'h0;                        // Use noise sample (for each voice)
    logic [7:0] echo_en = 8'h0;                         // Echo enable (for each voice)
    logic [7:0] sample_dir = 8'h0;                      // Offset of source directory ($dd00-$ddFF)
    logic [7:0] echo_page = 8'h0;                       // Echo buffer start offset ($ee00)
    logic [3:0] echo_delay = 4'h0;                      // Echo delay
    logic signed [7:0] echo_coef_x[7:0];                // Echo FIR Filter coefficients

    logic [4:0] step = 5'd0;

    // ------------------------------
    //  Main
    // ------------------------------
    
    // ---- DSP I/O Registers --------

    // dspaddr -> target
    always_comb begin
        priority casez (dspaddr)
            7'h?0: target = DT_VOL_L_X;
            7'h?1: target = DT_VOL_R_X;
            7'h?2: target = DT_P_L_X;
            7'h?3: target = DT_P_H_X;
            7'h?4: target = DT_SRCN_X;
            7'h?5: target = DT_ADSR_1_X;
            7'h?6: target = DT_ADSR_2_X;
            7'h?7: target = DT_GAIN_X;
            7'h?8: target = DT_ENVX_X;
            7'h?9: target = DT_OUTX_X;
            7'h0c: target = DT_MVOL_L;
            7'h1c: target = DT_MVOL_R;
            7'h2c: target = DT_EVOL_L;
            7'h3c: target = DT_EVOL_R;
            7'h4c: target = DT_KON;
            7'h5c: target = DT_KOF;
            7'h6c: target = DT_FLG;
            7'h7c: target = DT_ENDX;
            7'h0d: target = DT_EFB;
            7'h1d: target = DT_UNUSED;
            7'h2d: target = DT_PMON;
            7'h3d: target = DT_NON;
            7'h4d: target = DT_EON;
            7'h5d: target = DT_DIR;
            7'h6d: target = DT_ESA;
            7'h7d: target = DT_EDL;
            7'h?f: target = DT_COEF_X;
            default: target = DT_NONE;
        endcase
    end

    assign ch = dspaddr[6:4];

    // target -> rdata
    always_comb begin
        case (target)
            DT_VOL_L_X: dspaddr_rdata = vol_l_x[ch];
            DT_VOL_R_X: dspaddr_rdata = vol_r_x[ch];
            DT_P_L_X: dspaddr_rdata = pitch_x[ch][7:0];
            DT_P_H_X: dspaddr_rdata = pitch_x[ch][15:8];
            DT_SRCN_X: dspaddr_rdata = srcn_x[ch];
            DT_ADSR_1_X: dspaddr_rdata = adsr_control_x[ch][7:0];
            DT_ADSR_2_X: dspaddr_rdata = adsr_control_x[ch][15:8];
            DT_GAIN_X: dspaddr_rdata = gain_control_x[ch];
            DT_ENVX_X: dspaddr_rdata = {1'b0, envx_x[ch]};
            DT_OUTX_X: dspaddr_rdata = outx_x[ch][14:7];

            DT_MVOL_L: dspaddr_rdata = mvol_l;
            DT_MVOL_R: dspaddr_rdata = mvol_r;
            DT_EVOL_L: dspaddr_rdata = evol_l;
            DT_EVOL_R: dspaddr_rdata = evol_r;
            // DT_KON: dspaddr_rdata = key_on;
            // DT_KOF: dspaddr_rdata = key_off;
            DT_FLG: dspaddr_rdata = control;
            DT_ENDX: dspaddr_rdata = endx;
            DT_EFB: dspaddr_rdata = echo_fb;
            DT_UNUSED: dspaddr_rdata = unused;
            DT_PMON: dspaddr_rdata = pmon_en;
            DT_NON: dspaddr_rdata = noise_en;
            DT_EON: dspaddr_rdata = echo_en;
            DT_DIR: dspaddr_rdata = sample_dir;
            DT_ESA: dspaddr_rdata = echo_page;
            DT_EDL: dspaddr_rdata = {4'h0, echo_delay};
            DT_COEF_X: dspaddr_rdata = echo_coef_x[ch];
            default: dspaddr_rdata = 8'h0;
        endcase
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            for (int i = 0; i < 8; i++) begin
                vol_l_x[i] <= 8'h0;
                vol_r_x[i] <= 8'h0;
                pitch_x[i] <= 16'h0;
                srcn_x[i] <= 8'h0;
                adsr_control_x[i] <= 16'h0;
                gain_control_x[i] <= 8'h0;
                echo_coef_x[i] <= 8'h0;
            end
            mvol_l <= 8'h0;
            mvol_r <= 8'h0;
            evol_l <= 8'h0;
            evol_r <= 8'h0;
            control <= 8'b111_00000;
            echo_fb <= 8'h0;
            unused <= 8'h0;
            pmon_en <= 8'h0;
            noise_en <= 8'h0;
            echo_en <= 8'h0;
            sample_dir <= 8'h0;
            echo_page <= 8'h0;
            echo_delay <= 4'h0;
        end else if (dspaddr_write) begin
            case (target)
                DT_VOL_L_X: vol_l_x[ch] <= dspaddr_wdata;
                DT_VOL_R_X: vol_r_x[ch] <= dspaddr_wdata;
                DT_P_L_X: pitch_x[ch][7:0] <= dspaddr_wdata;
                DT_P_H_X: pitch_x[ch][15:8] <= dspaddr_wdata;
                DT_SRCN_X: srcn_x[ch] <= dspaddr_wdata;
                DT_ADSR_1_X: adsr_control_x[ch][7:0] <= dspaddr_wdata;
                DT_ADSR_2_X: adsr_control_x[ch][15:8] <= dspaddr_wdata;
                DT_GAIN_X: gain_control_x[ch] <= dspaddr_wdata;
                DT_MVOL_L: mvol_l <= dspaddr_wdata;
                DT_MVOL_R: mvol_r <= dspaddr_wdata;
                DT_EVOL_L: evol_l <= dspaddr_wdata;
                DT_EVOL_R: evol_r <= dspaddr_wdata;
                DT_FLG: control <= dspaddr_wdata;
                DT_EFB: echo_fb <= dspaddr_wdata;
                DT_UNUSED: unused <= dspaddr_wdata;
                DT_PMON: pmon_en <= dspaddr_wdata;
                DT_NON: noise_en <= dspaddr_wdata;
                DT_EON: echo_en <= dspaddr_wdata;
                DT_DIR: sample_dir <= dspaddr_wdata;
                DT_ESA: echo_page <= dspaddr_wdata;
                DT_EDL: echo_delay <= dspaddr_wdata[3:0];
                DT_COEF_X: echo_coef_x[ch] <= dspaddr_wdata;
                default: ;
            endcase
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            endx <= 8'h0;
        end else if ((target == DT_ENDX) & dspaddr_write) begin
            endx <= 8'h0;
        end else if ((target == DT_KON) & dspaddr_write) begin
            endx <= endx & (~dspaddr_wdata);
        end else if (cpu_en) begin
            endx <= endx | set_endx;
        end
    end

    // ---- Step Counter --------
    // step = 0, 1, 2, ..., 31 (1 Cycle)

    always_ff @(posedge clk) begin
        if (reset) begin
            step <= 5'd0;
        end else if (cpu_en) begin
            step <= step + 5'd1;
        end
    end

    assign exe_32khz = (step == 5'd31);

    // ---- ARAM Access --------
    // DSP can use 2 Addresses per 1 Cycle(32 Steps)

    always_comb begin
        addr_0 = 'x;
        addr_1 = 'x;
        write = 1'b0;
        priority casez (step[4:1])
            4'b00??: begin
                addr_0 = {src_addr_x[step[2:0]], 1'b0};
                addr_1 = {src_addr_x[step[2:0]], 1'b1};
            end
            4'b01??: begin
                addr_0 = brr_control_addr_x[step[2:0]];
            end
            4'b10??: begin
                addr_0 = brr_sample_addr_0_x[step[2:0]];
                addr_1 = brr_sample_addr_1_x[step[2:0]];
            end
            4'b1100: begin
                addr_0 = echo_addr_0;
                addr_1 = echo_addr_1;
            end
            4'b1111: begin
                addr_0 = echo_addr_0;
                addr_1 = echo_addr_1;
                write = ~control[5];    // FLG.ECHO
            end
            default: ;
        endcase
    end

    assign wdata_0 = echo_wdata_0;
    assign wdata_1 = echo_wdata_1;

    // ---- Channel Sound --------

    // Noise Sample Generator
    noise noise(
        .clk,
        .cpu_en,
        .reset,

        .exe_32khz,

        .rate_id(control[4:0]),
        .sample(noise_sample)
    );

    generate
        for (gi = 0; gi < 8; gi++) begin : GenDSPCh

            // Pitch Modulation
            logic [10:0] pmon_factor;
            if (gi == 0) begin
                assign pmon_factor = 11'h0;
            end else begin
                assign pmon_factor = {~outx_x[gi-1][14], outx_x[gi-1][13:4]};
            end

            // Channel Sound Processing
            dsp_ch dsp_ch(
                .clk,
                .cpu_en,
                .reset,

                .vol_l(vol_l_x[gi]),
                .vol_r(vol_r_x[gi]),
                .pitch(pitch_x[gi]),
                .srcn(srcn_x[gi]),
                .adsr_control(adsr_control_x[gi]),
                .gain_control(gain_control_x[gi]),
                .pmon_en(pmon_en[gi]),
                .noise_en(noise_en[gi]),

                .sample_dir,

                .noise_sample,

                .key_on((target == DT_KON) & dspaddr_wdata[gi] & dspaddr_write),
                .key_off((target == DT_KOF) & dspaddr_wdata[gi] & dspaddr_write),
                
                .pmon_factor,

                .src_access((step[4:3] == 2'b00) & (step[2:0] == gi)),
                .brr_control_access((step[4:3] == 2'b01) & (step[2:0] == gi)),
                .brr_sample_access((step[4:3] == 2'b10) & (step[2:0] == gi)),
                .pcm_calc(step[4:2] == 3'b110),
                .pcm_calc_num(step[1:0]),
                .exe_32khz,

                .src_addr(src_addr_x[gi]),
                .brr_control_addr(brr_control_addr_x[gi]),
                .brr_sample_addr_0(brr_sample_addr_0_x[gi]),
                .brr_sample_addr_1(brr_sample_addr_1_x[gi]),
                .aram_rdata_0(rdata_0),
                .aram_rdata_1(rdata_1),

                `ifdef USE_INTERPOLATE
                    .interpol_pcm_x(interpol_pcm_x_y[gi]),
                    .interpol_index(interpol_index_x[gi]),
                    .interpol_out(interpol_out_x[gi]),
                `endif

                .chsound_l(chsound_l_x[gi]),
                .chsound_r(chsound_r_x[gi]),

                .envx(envx_x[gi]),
                .outx(outx_x[gi]),
                .set_endx(set_endx[gi])
            );
        end
    endgenerate

    `ifdef USE_INTERPOLATE
        // PCM Interpolation
        interpolate interpolate(
            .clk,
            .cpu_en,
            .reset,

            .step,
            .exe_32khz,

            .sel(interpol_sel),

            .pcm_x_y(interpol_pcm_x_y),
            .index_x(interpol_index_x),
            .out_x(interpol_out_x)
        );
    `endif

    // ---- Main Mix --------

    always_comb begin
        suml_raw = 18'h0;
        sumr_raw = 18'h0;
        for (int i = 0; i < 8; i++) begin
            if (~sound_off[i]) begin
                suml_raw += {{3{chsound_l_x[i][14]}}, chsound_l_x[i]};
                sumr_raw += {{3{chsound_r_x[i][14]}}, chsound_r_x[i]};
            end
        end
    end
    
    always_comb begin
        if (~suml_raw[17] & (suml_raw[16:15] != 2'b00)) begin
            suml = 16'h7fff;
        end else if (suml_raw[17] & (suml_raw[16:15] != 2'b11)) begin
            suml = 16'h8000;
        end else begin
            suml = suml_raw[15:0];
        end
    end
    always_comb begin
        if (~sumr_raw[17] & (sumr_raw[16:15] != 2'b00)) begin
            sumr = 16'h7fff;
        end else if (sumr_raw[17] & (sumr_raw[16:15] != 2'b11)) begin
            sumr = 16'h8000;
        end else begin
            sumr = sumr_raw[15:0];
        end
    end

    always_comb begin
        suml_echo_raw = 18'h0;
        sumr_echo_raw = 18'h0;
        for (int i = 0; i < 8; i++) begin
            if ((~sound_off[i]) & echo_en[i]) begin
                suml_echo_raw += {{3{chsound_l_x[i][14]}}, chsound_l_x[i]};
                sumr_echo_raw += {{3{chsound_r_x[i][14]}}, chsound_r_x[i]};
            end
        end
    end

    always_comb begin
        if ((~suml_echo_raw[17]) & (suml_echo_raw[16:15] != 2'b00)) begin
            suml_echo = 16'h7fff;
        end else if (suml_echo_raw[17] & (suml_echo_raw[16:15] != 2'b11)) begin
            suml_echo = 16'h8000;
        end else begin
            suml_echo = suml_echo_raw[15:0];
        end
    end
    always_comb begin
        if ((~sumr_echo_raw[17]) & (sumr_echo_raw[16:15] != 2'b00)) begin
            sumr_echo = 16'h7fff;
        end else if (sumr_echo_raw[17] & (sumr_echo_raw[16:15] != 2'b11)) begin
            sumr_echo = 16'h8000;
        end else begin
            sumr_echo = sumr_echo_raw[15:0];
        end
    end

    assign suml_x_mvl_raw = $signed(suml) * $signed(mvol_l);
    assign sumr_x_mvr_raw = $signed(sumr) * $signed(mvol_r);
    assign suml_x_mvl = suml_x_mvl_raw[22:7];
    assign sumr_x_mvr = sumr_x_mvr_raw[22:7];


    // ---- Echo --------

    echo echo(
        .clk,
        .cpu_en,
        .clk_step,
        .reset,

        .step,
        .exe_32khz,

        .echo_page,
        .echo_fb,
        .echo_delay,
        .echo_coef_x,

        .suml_main(suml_echo),
        .sumr_main(sumr_echo),

        .aram_addr_0(echo_addr_0),
        .aram_rdata_0(rdata_0),
        .aram_wdata_0(echo_wdata_0),
        .aram_addr_1(echo_addr_1),
        .aram_rdata_1(rdata_1),
        .aram_wdata_1(echo_wdata_1),

        .echo_l,
        .echo_r
    );

    assign ecl_x_evl_raw = $signed(echo_l) * $signed(evol_l);
    assign ecr_x_evr_raw = $signed(echo_r) * $signed(evol_r);

    assign ecl_x_evl = ecl_x_evl_raw[22:7];
    assign ecr_x_evr = ecr_x_evr_raw[22:7];

    // ---- Main + Echo --------

    assign sound_l_raw = echo_off
            ? {suml_x_mvl[15], suml_x_mvl}
            : ({suml_x_mvl[15], suml_x_mvl} + {ecl_x_evl[15], ecl_x_evl});
    assign sound_r_raw = echo_off
            ? {sumr_x_mvr[15], sumr_x_mvr}
            : ({sumr_x_mvr[15], sumr_x_mvr} + {ecr_x_evr[15], ecr_x_evr});

    always_comb begin
        if (control[6]) begin // FLG.MUTE
            sound_l = 16'h0;
        end else if (sound_l_raw[16:15] == 2'b01) begin
            sound_l = 16'h7fff;
        end else if (sound_l_raw[16:15] == 2'b10) begin
            sound_l = 16'h8000;
        end else begin
            sound_l = sound_l_raw[15:0];
        end
    end
    always_comb begin
        if (control[6]) begin // FLG.MUTE
            sound_r = 16'h0;
        end else if (sound_r_raw[16:15] == 2'b01) begin
            sound_r = 16'h7fff;
        end else if (sound_r_raw[16:15] == 2'b10) begin
            sound_r = 16'h8000;
        end else begin
            sound_r = sound_r_raw[15:0];
        end
    end

endmodule
