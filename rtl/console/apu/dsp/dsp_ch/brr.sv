// ==============================
//  Bit Rate Reduction (ADPCM)
// ==============================

// Copyright(C) 2024 ep2k All Rights Reserved.

`include "config.vh"

module brr (
    input logic clk,        // 10.24MHz
    input logic cpu_en,     // 1.024MHz
    input logic reset,

    input logic src_access,
    input logic brr_control_access,
    input logic brr_sample_access,
    input logic pcm_calc,
    input logic [1:0] pcm_calc_num,
    input logic exe_32khz,

    input logic [7:0] dir,
    input logic [7:0] srcn,
    input logic [13:0] pitch,
    input logic pmon_en,
    input logic [10:0] pmon_factor,

    input logic key_on,

    output logic [14:0] src_addr,
    output logic [15:0] brr_control_addr,
    output logic [15:0] brr_sample_addr_0,
    output logic [15:0] brr_sample_addr_1,

    input logic [7:0] aram_rdata_0,
    input logic [7:0] aram_rdata_1,

    input logic adsr_release,

    `ifdef USE_INTERPOLATE
        output logic [14:0] interpol_pcm_x[3:0],
        output logic [7:0] interpol_index,
    `else
        output logic [14:0] pcm1_out,
    `endif

    output logic set_endx,
    output logic brr_end,
    output logic env_stop
);

    genvar gi;

    typedef enum logic [2:0] {
        BS_BRR = 3'b000,
        BS_KEY_ON = 3'b001,
        BS_NORM_CONT = 3'b010,
        BS_INIT_CONT = 3'b011,
        BS_INIT_SAMP = 3'b100
    } brr_state_type;

    // ------------------------------
    //  Wires
    // ------------------------------
    
    logic [3:0] new_sample[3:0];
    logic [14:0] new_sample_shift[3:0];

    logic [23:0] pitch_pmon_raw;
    logic [13:0] pitch_pmon;

    logic [3:0] bc_sample_num;
    logic [3:0] bc_pcm1_num_raw, bc_pcm1_num;
    logic [3:0] bc_pcm2_num_raw, bc_pcm2_num;
    logic [14:0] new_pcm;

    // ------------------------------
    //  Registers
    // ------------------------------
    
    brr_state_type brr_state = BS_BRR;

    logic [15:0] brr_start_addr = 16'h0;
    logic [3:0] shift_amount = 4'h0;
    logic [1:0] filter = 2'h0;
    logic [1:0] loop_shifter = 2'b00;

    logic [14:0] pcm_buffer[11:0];
    
    logic [1:0] sample_num = 2'h0;  // 0, 1, 2, 3
    logic [1:0] buffer_num = 2'h0;  // 0, 1, 2
    logic next_block_flg = 1'b0;

    logic [14:0] pitch_ctr = 15'h0;
    logic pitch_ctr_14_prev = 1'b0;

    logic [1:0] env_stop_ctr = 2'b0;

    // ------------------------------
    //  Main
    // ------------------------------

    /*
        [ 概要 ]

        KEY_ONでBRR開始アドレス取得
        INIT_CONT, NORM_CONTでコントロールブロックを取得
        INIT_SAMP or BRRかつサンプルブロックの境界を超えたら(pitch_ctr[14]が変化したら)PCMバッファを埋める

        key_on時はINIT_CONT -> INIT_SAMP で最初にPCMバッファを12サンプルすべて埋める
        定常時(BRR)では，4サンプル使用するたびにPCMバッファを埋める，16サンプル(1ブロック)使用するたびにコントロールブロックを取得 or key_off

        [ 詳細 ]

        key_onが書き込まれたとき
            sample_num, buffer_num, pitch_ctr, loop_shifter リセット
            state <- KEY_ON
        
        state=KEY_ON かつ src_access のとき
            source directory(DIR)にアクセスし，BRR開始アドレスを取得 -> brr_start_addr
            state <- INIT_CONT

        state=INIT_CONT or NORM_CONT かつ brr_control_access のとき
            BRR開始アドレスにアクセスし，コントロールブロックを取得 -> loop_shifter[0], shift_amount, filter
            state=INIT_CONT なら state <- INIT_SAMP
            state=NORM_CONT なら state <- BRR

        (state=INIT_SAMP または 「state=BRR かつ pitch_ctr[14]が変化」) かつ brr_sample_access のとき
            4サンプルを読み出しシフトしてからPCMバッファに仮保存
            brr_addr = brr_start_addr + {sample_num, 1'b0/1} + 1 の 2Bytes * 2サンプル
            sample_num <- sample_num + 1
            sample_num = 3 のとき
                brr_start_addr <- brr_start_addr + 9
                next_block_flg <- 1
        
        (state=INIT_SAMP または 「state=BRR かつ pitch_ctr[14]が変化」) かつ pcm_calc のとき
            PCMバッファに仮保存した値からBRR計算，PCMバッファに改めて保存
                pcm_buffer[{buffer_num, pcm_calc_num}]
                    <- BRR(filter, pcm_buffer[{buffer_num, pcm_calc_num - 0/1/2}])
            最後に(pcm_calc_num == 3 のとき)
                buffer_num <- buffer_num + 1 (0~2)
                buffer_num = 2 のとき
                    state <- BRR (INIT_SAMP用)
        
        exe_32khz かつ state!=INIT_SAMP のとき
            pitch_ctr <- picth_ctr + pitch
            pitch_ctr_14_prev <- pitch_ctr[14] (pitch_ctr[14]が変化: pitch_ctr_14_prev ^ pitch_ctr[14])
            interpol_pcm_x <- PCMバッファの値(4サンプル)

        state=BRR かつ next_block_flg かつ src_access のとき
            state <- NORM_CONT, next_block_flg <- 0
            loop_shifter[1] のとき
                source directory(DIR)にアクセスし，BRR開始アドレスを取得 -> brr_start_addr
    */

    // ---- Output Signals --------

    assign src_addr = {dir, 7'h0} + {6'h0, srcn, next_block_flg};
    assign brr_control_addr = brr_start_addr;
    assign brr_sample_addr_0 = brr_start_addr + {13'h0, sample_num, 1'b0} + 16'h1;
    assign brr_sample_addr_1 = brr_start_addr + {13'h0, sample_num, 1'b1} + 16'h1;

    // INIT_CONT or NORM_CONT で E=1 のとき set_endxを送る
    assign set_endx = brr_control_access & brr_state[1] & (aram_rdata_0[0]) & (~adsr_release);

    // INIT_CONT or NORM_CONT でLE=01 のとき brr_endを送る
    assign brr_end = brr_control_access & brr_state[1] & (aram_rdata_0[1:0] == 2'b01);

    // ----------------------

    // brr_state
    always_ff @(posedge clk) begin
        if (reset) begin
            brr_state <= BS_BRR;
        end else if (key_on) begin
            brr_state <= BS_KEY_ON;
        end else if (cpu_en) begin
            if (src_access & (brr_state == BS_KEY_ON)) begin
                brr_state <= BS_INIT_CONT;
            end else if (src_access & (brr_state == BS_BRR) & next_block_flg) begin
                brr_state <= BS_NORM_CONT;
            end else if (brr_control_access & brr_state[1]) begin // INIT_CONT or NORM_CONT
                // INIT_CONT -> INIT_SAMP, NORM_CONT -> BRR
                brr_state <= (brr_state == BS_INIT_CONT) ? BS_INIT_SAMP : BS_BRR;
            end else if (pcm_calc & (pcm_calc_num == 2'h3) & (brr_state == BS_INIT_SAMP) & (buffer_num == 2'h2)) begin
                brr_state <= BS_BRR;
            end
        end
    end

    // brr_start_addr
    always_ff @(posedge clk) begin
        if (reset) begin
            brr_start_addr <= 15'h0;
        end else if (cpu_en) begin
            if (src_access & (brr_state == BS_KEY_ON) | ((brr_state == BS_BRR) & next_block_flg & loop_shifter[0])) begin
                brr_start_addr <= {aram_rdata_1, aram_rdata_0};
            end else if (brr_sample_access & ((brr_state == BS_INIT_SAMP) | ((brr_state == BS_BRR) & (pitch_ctr[14] ^ pitch_ctr_14_prev))) & (sample_num == 2'h3)) begin
                brr_start_addr <= brr_start_addr + 16'h9;
            end
        end
    end

    // shift_amount, filter
    always_ff @(posedge clk) begin
        if (reset) begin
            shift_amount <= 4'h0;
            filter <= 2'h0;
        end else if (cpu_en) begin
            if (brr_control_access & brr_state[1]) begin // INIT_CONT or NORM_CONT
                {shift_amount, filter} <= aram_rdata_0[7:2];
            end
        end
    end
    
    // loop_shifter
    always_ff @(posedge clk) begin
        if (reset) begin
            loop_shifter <= 2'b00;
        end else if (key_on) begin
            loop_shifter <= 2'b00;
        end else if (cpu_en & brr_control_access & brr_state[1]) begin // INIT_CONT or NORM_CONT
            loop_shifter <= {loop_shifter[0], (aram_rdata_0[1:0] == 2'b11)};
        end
    end

    assign new_sample[0] = aram_rdata_0[7:4];
    assign new_sample[1] = aram_rdata_0[3:0];
    assign new_sample[2] = aram_rdata_1[7:4];
    assign new_sample[3] = aram_rdata_1[3:0];

    generate
        for (gi = 0; gi < 4; gi++) begin : GenNewSampleShift
            always_comb begin
                case (shift_amount)
                    4'd0:  new_sample_shift[gi] = {{12{new_sample[gi][3]}}, new_sample[gi][3:1]};
                    4'd1:  new_sample_shift[gi] = {{11{new_sample[gi][3]}}, new_sample[gi]};
                    4'd2:  new_sample_shift[gi] = {{10{new_sample[gi][3]}}, new_sample[gi], 1'b0};
                    4'd3:  new_sample_shift[gi] = {{9{new_sample[gi][3]}}, new_sample[gi], 2'b0};
                    4'd4:  new_sample_shift[gi] = {{8{new_sample[gi][3]}}, new_sample[gi], 3'b0};
                    4'd5:  new_sample_shift[gi] = {{7{new_sample[gi][3]}}, new_sample[gi], 4'b0};
                    4'd6:  new_sample_shift[gi] = {{6{new_sample[gi][3]}}, new_sample[gi], 5'b0};
                    4'd7:  new_sample_shift[gi] = {{5{new_sample[gi][3]}}, new_sample[gi], 6'b0};
                    4'd8:  new_sample_shift[gi] = {{4{new_sample[gi][3]}}, new_sample[gi], 7'b0};
                    4'd9:  new_sample_shift[gi] = {{3{new_sample[gi][3]}}, new_sample[gi], 8'b0};
                    4'd10: new_sample_shift[gi] = {{2{new_sample[gi][3]}}, new_sample[gi], 9'b0};
                    4'd11: new_sample_shift[gi] = {new_sample[gi][3], new_sample[gi], 10'b0};
                    default: new_sample_shift[gi] = {new_sample[gi], 11'b0}; // 12-15
                endcase
            end
        end
    endgenerate

    // pcm_buffer
    always_ff @(posedge clk) begin
        if (reset) begin
            for (int i = 0; i < 12; i++) begin
                pcm_buffer[i] <= 15'h0;
            end
        end else if (cpu_en) begin
            if ((brr_state == BS_INIT_SAMP) | ((brr_state == BS_BRR) & (pitch_ctr[14] ^ pitch_ctr_14_prev))) begin // INIT_SAMP or (BRR かつ サンプル境界越え)
                if (brr_sample_access) begin
                    pcm_buffer[{buffer_num, 2'b00}] <= new_sample_shift[0];
                    pcm_buffer[{buffer_num, 2'b01}] <= new_sample_shift[1];
                    pcm_buffer[{buffer_num, 2'b10}] <= new_sample_shift[2];
                    pcm_buffer[{buffer_num, 2'b11}] <= new_sample_shift[3];
                end else if (pcm_calc) begin
                    pcm_buffer[{buffer_num, pcm_calc_num}] <= new_pcm;
                end
            end
        end
    end

    // sample_num, buffer_num
    always_ff @(posedge clk) begin
        if (reset) begin
            sample_num <= 2'h0;
            buffer_num <= 2'h0;
        end else if (key_on) begin
            sample_num <= 2'h0;
            buffer_num <= 2'h0;
        end else if (cpu_en) begin
            if (brr_sample_access & ((brr_state == BS_INIT_SAMP) | ((brr_state == BS_BRR) & (pitch_ctr[14] ^ pitch_ctr_14_prev)))) begin
                sample_num <= sample_num + 2'h1;
            end else if (pcm_calc & (pcm_calc_num == 2'h3) & ((brr_state == BS_INIT_SAMP) | ((brr_state == BS_BRR) & (pitch_ctr[14] ^ pitch_ctr_14_prev)))) begin
                buffer_num <= (buffer_num == 2'h2) ? 2'h0 : (buffer_num + 2'h1);
            end
        end
    end

    // next_block_flg
    always_ff @(posedge clk) begin
        if (reset) begin
            next_block_flg <= 1'b0;
        end else if (key_on) begin
            next_block_flg <= 1'b0;
        end else if (cpu_en) begin
            if (brr_sample_access & ((brr_state == BS_INIT_SAMP) | ((brr_state == BS_BRR) & (pitch_ctr[14] ^ pitch_ctr_14_prev)))) begin
                next_block_flg <= (sample_num == 2'h3);
            end else if (src_access) begin
                next_block_flg <= 1'b0;
            end
        end
    end

    // ---- Pitch Counter --------

    assign pitch_pmon_raw = pitch * pmon_factor;
    assign pitch_pmon = pitch_pmon_raw[23:10];

    // pitch_ctr
    always_ff @(posedge clk) begin
        if (reset) begin
            pitch_ctr <= 15'h0;
            pitch_ctr_14_prev <= 1'b0;
        end else if (key_on) begin
            pitch_ctr <= 15'h0;
            pitch_ctr_14_prev <= 1'b0;
        end else if (cpu_en & exe_32khz & (brr_state != BS_INIT_SAMP)) begin
            pitch_ctr <= pitch_ctr + {1'b0, pmon_en ? pitch_pmon : pitch};
            pitch_ctr_14_prev <= pitch_ctr[14];
        end
    end

    // ---- BRR Calculation --------

    assign bc_sample_num = {buffer_num, pcm_calc_num};
    assign bc_pcm1_num_raw = bc_sample_num - 4'd1;
    assign bc_pcm1_num = (bc_pcm1_num_raw >= 4'd12) ? (bc_pcm1_num_raw + 4'd12) : bc_pcm1_num_raw;
    assign bc_pcm2_num_raw = bc_sample_num - 4'd2;
    assign bc_pcm2_num = (bc_pcm2_num_raw >= 4'd12) ? (bc_pcm2_num_raw + 4'd12) : bc_pcm2_num_raw;

    brr_calc brr_calc(
        .sample_shift(pcm_buffer[bc_sample_num]),
        .pcm1(pcm_buffer[bc_pcm1_num]),
        .pcm2(pcm_buffer[bc_pcm2_num]),
        .filter,

        .pcm(new_pcm)
    );

    `ifdef USE_INTERPOLATE
        generate
            for (gi = 0; gi < 4; gi++) begin : GeninterpolPCM
                logic [3:0] interpol_pcm_num_raw;
                logic [3:0] interpol_pcm_num;

                assign interpol_pcm_num_raw = {buffer_num, pitch_ctr[13:12]} + gi;
                assign interpol_pcm_num = (interpol_pcm_num_raw >= 4'd12) ? (interpol_pcm_num_raw - 4'd12) : interpol_pcm_num_raw;

                always_ff @(posedge clk) begin
                    if (reset) begin
                        interpol_pcm_x[gi] <= 15'h0;
                    end else if (cpu_en & exe_32khz & (brr_state != BS_INIT_SAMP)) begin
                        interpol_pcm_x[gi] <= pcm_buffer[interpol_pcm_num];
                    end
                end
            end
        endgenerate

        always_ff @(posedge clk) begin
            if (reset) begin
                interpol_index <= 8'h0;
            end else if (cpu_en & exe_32khz & (brr_state != BS_INIT_SAMP)) begin
                interpol_index <= pitch_ctr[11:4];
            end
        end
    `else
        logic [3:0] pcm1_out_num_raw;
        logic [3:0] pcm1_out_num;

        assign pcm1_out_num_raw = {buffer_num, pitch_ctr[13:12]} + 4'h1;
        assign pcm1_out_num = (pcm1_out_num_raw >= 4'd12) ? (pcm1_out_num_raw - 4'd12) : pcm1_out_num_raw;

        always_ff @(posedge clk) begin
            if (reset) begin
                pcm1_out <= 8'h0;
            end else if (cpu_en & exe_32khz & (brr_state != BS_INIT_SAMP)) begin
                pcm1_out <= pcm_buffer[pcm1_out_num];
            end
        end
    `endif

    // ---- Envelope stop --------
    // key_on後，PCMバッファが埋まり再生が開始されるまでEnvelopeを停止しておく

    // env_stop_ctr
    always_ff @(posedge clk) begin
        if (reset) begin
            env_stop_ctr <= 2'b00;
        end else if (key_on) begin
            env_stop_ctr <= 2'b11;
        end else if (cpu_en) begin
            if ((env_stop_ctr == 2'b11) & pcm_calc & (pcm_calc_num == 2'h3) & (brr_state == BS_INIT_SAMP) & (buffer_num == 2'h2)) begin
                env_stop_ctr <= 2'b10;
            end else if (exe_32khz & (env_stop_ctr[1] ^ env_stop_ctr[0])) begin // env_stop_ctr == 10 or 01
                env_stop_ctr <= env_stop_ctr - 2'b01;
            end
        end
    end

    assign env_stop = (env_stop_ctr != 2'b00); // to Envelope

endmodule
