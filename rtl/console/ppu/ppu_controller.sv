// ==============================
//  PPU Controller
// ==============================

// Copyright(C) 2024 ep2k All Rights Reserved.

module ppu_controller (
    input logic clk,
    input logic reset,
    input logic overscan,
    input logic interlace,
    input logic [2:0] bgmode,

    output logic [2:0] dot_ctr = 3'd0,
    output logic [8:0] h_ctr = 9'd0,
    output logic [8:0] v_ctr = 9'd0,
    output logic field = 1'b0,
    output logic [11:0] frame_ctr = 12'd0,

    output logic dot_en,
    output logic obj_en,

    output logic [8:0] x_fetch,
    output logic [7:0] x_mid,
    output logic [7:0] y,

    output logic [2:0] bg_mode[3:0],
    output logic [1:0] bg_target,
    output logic fetch_map,
    output logic fetch_data,
    output logic [2:0] fetch_data_num,

    output logic oamaddr_reload,
    output logic start_oamprefetch,
    output logic start_objfetch,
    output logic obj_ovf_clear,

    output logic color_period,

    output logic [8:0] xout,
    output logic [8:0] yout,
    output logic color_write,
    output logic dr_write_req
);

    // ------------------------------
    //  Wires
    // ------------------------------
    
    logic [2:0] dot_ctr_max;

    logic fetch_period, write_period;
    logic fetch_map_raw, fetch_data_raw;

    // ------------------------------
    //  Registers
    // ------------------------------
    
    logic ppu_period_v = 1'b0;      // 1 <= v_ctr < 225/240
    logic obj_period_v = 1'b0;      // 0 <= v_ctr < 224/239
    logic fetch_period_h = 1'b0;    // 6 <= h_ctr[10:2] < 262+8
    logic color_period_h = 1'b0;    // 6+16 <= h_ctr[10:2] < 262+16
    logic write_period_h = 1'b0;    // 6+16+1 <= h_ctr[10:2] < 262+16+1
    logic dr_write_req_v = 1'b0;    // 2 <= v_ctr < 226/241

    // ------------------------------
    //  Main
    // ------------------------------
    
    // ---- dot_ctr (Dot Counter) -> dot_en, obj_en --------

    always_ff @(posedge clk) begin
        if (reset) begin
            dot_ctr <= 3'd0;
        end else begin
            dot_ctr <= dot_en ? 3'd0 : (dot_ctr + 3'd1);
        end
    end

    // h=0,1,2,3 (インターレースオフ & field=1 & v=240 「でない」とき) で5クロック (Normal Line)
    assign dot_ctr_max =
            (h_ctr[8:2] == 7'h0) & (interlace | (~field) | (v_ctr != 9'd240))
                ? 3'd4 : 3'd3;

    assign dot_en = (dot_ctr == dot_ctr_max);
    assign obj_en = dot_ctr[0];

    // ---- H/V Counter --------

    always_ff @(posedge clk) begin
        if (reset) begin
            h_ctr <= 9'd0;
        end else if (dot_en) begin
            h_ctr <= (h_ctr == 9'd339) ? 9'd0 : (h_ctr + 9'd1);
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            v_ctr <= 9'd0;
        end else if (dot_en & (h_ctr == 9'd339)) begin
            v_ctr <= (v_ctr == ((interlace & (~field)) ? 9'd262 : 9'd261))
                            ? 9'd0 : (v_ctr + 9'd1);
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            frame_ctr <= 12'd0;
        end else if (dot_en & (h_ctr == 9'd339) & (v_ctr == ((interlace & (~field)) ? 9'd262 : 9'd261))) begin
            frame_ctr <= frame_ctr + 12'd1;
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            field <= 1'b0;
        end else if (dot_en & (v_ctr == 9'd0) & (h_ctr == 9'd1)) begin
            field <= ~field;
        end
    end

    // ---- X/Y Calculation --------

    assign x_fetch = h_ctr - 6;
    assign x_mid = x_fetch - 16;
    assign y = v_ctr[7:0];

    assign xout = {x_mid - 1, dot_ctr[1]};
    assign yout = {v_ctr - 2, interlace & field};

    // ---- Period Register --------

    always_ff @(posedge clk) begin
        if (reset) begin
            ppu_period_v <= 1'b0;
        end else if (v_ctr == 9'd1) begin
            ppu_period_v <= 1'b1;
        end else if ((~overscan) & (v_ctr == 9'd225)) begin
            ppu_period_v <= 1'b0;
        end else if (v_ctr == 9'd240) begin
            ppu_period_v <= 1'b0;
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            obj_period_v <= 1'b0;
        end else if (v_ctr == 9'd0) begin
            obj_period_v <= 1'b1;
        end else if ((~overscan) & (v_ctr == 9'd224)) begin
            obj_period_v <= 1'b0;
        end else if (v_ctr == 9'd239) begin
            obj_period_v <= 1'b0;
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            fetch_period_h <= 1'b0;
        end else if (dot_en & (h_ctr == 9'd5)) begin
            fetch_period_h <= 1'b1;
        end else if (dot_en & (h_ctr == (9'd261 + 9'd8))) begin
            fetch_period_h <= 1'b0;
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            color_period_h <= 1'b0;
        end else if (dot_en & (h_ctr == (9'd5 + 9'd16))) begin
            color_period_h <= 1'b1;
        end else if (dot_en & (h_ctr == (9'd261 + 9'd16))) begin
            color_period_h <= 1'b0;
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            write_period_h <= 1'b0;
        end else if (dot_en & (h_ctr == (9'd5 + 9'd16 + 9'd1))) begin
            write_period_h <= 1'b1;
        end else if (dot_en & (h_ctr == (9'd261 + 9'd16 + 9'd1))) begin
            write_period_h <= 1'b0;
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            dr_write_req_v <= 1'b0;
        end else if (dot_en & (h_ctr == 9'd339)) begin
            if (v_ctr == 9'd1) begin
                dr_write_req_v <= 1'b1;
            end else if ((~overscan) & (v_ctr == 9'd225)) begin
                dr_write_req_v <= 1'b0;
            end else if (v_ctr == 9'd240) begin
                dr_write_req_v <= 1'b0;
            end
        end
    end

    // ---- Timing Calculation --------

    assign color_write = write_period & dot_ctr[0];
    assign dr_write_req = dr_write_req_v & (h_ctr == 9'd0);
    assign fetch_period = ppu_period_v & fetch_period_h;
    assign color_period = ppu_period_v & color_period_h;
    assign write_period = ppu_period_v & write_period_h;
    assign oamaddr_reload =
            (v_ctr == (overscan ? 9'd240 : 9'd225))
            & (h_ctr == 9'd10);
    assign start_oamprefetch = obj_period_v & (h_ctr == 9'd22) & (~dot_ctr[1]);
    assign start_objfetch = obj_period_v & (h_ctr == 9'd269);
    assign obj_ovf_clear = (v_ctr == 9'd0) & (h_ctr == 9'd0);

    // ---- BG Control --------

    /*
        Mode 0: 2bpp 2bpp 2bpp 2bpp (1ワード 1ワード 1ワード 1ワード)
            0:BG1タイルマップ
            1:BG1タイルデータ
            2:BG2タイルマップ
            3:BG2タイルデータ
            4:BG3タイルマップ
            5:BG3タイルデータ
            6:BG4タイルマップ
            7:BG4タイルデータ

        Mode 1: 4bpp 4bpp 2bpp (2ワード 2ワード 1ワード)
            0:BG1タイルマップ
            1:BG1タイルデータ0
            2:BG1タイルデータ1
            3:BG2タイルマップ
            4:BG2タイルデータ0
            5:BG2タイルデータ1
            6:BG3タイルマップ
            7:BG3タイルデータ

        Mode 2: 4bpp 4bpp OPT(2) (2ワード 2ワード +OPT)
            0:BG1タイルマップ
            1:BG1タイルデータ0
            2:BG1タイルデータ1
            3:BG2タイルマップ
            4:BG2タイルデータ0
            5:BG2タイルデータ1
            6:OPT Horizontal (BG3)
            7:OPT Vertical (BG3)

        Mode 3: 8bpp 4bpp (4ワード 2ワード)
            0:BG1タイルマップ
            1:BG1タイルデータ0
            2:BG1タイルデータ1
            3:BG1タイルデータ2
            4:BG1タイルデータ3
            5:BG2タイルマップ
            6:BG2タイルデータ0
            7:BG2タイルデータ1

        Mode 4: 8bpp 2bpp OPT(1) (4ワード 1ワード +OPT)
            0:BG1タイルマップ
            1:BG1タイルデータ0
            2:BG1タイルデータ1
            3:BG1タイルデータ2
            4:BG1タイルデータ3
            5:BG2タイルマップ
            6:BG2タイルデータ
            7:OPT (BG3)

        Mode 5: 4bpp 2bpp (2ワード 1ワード)，True H-RES，インターレース時高解像度スクロール
            0:BG1タイルマップ
            1:BG1タイルデータ0-0
            2:BG1タイルデータ0-1
            3:BG1タイルデータ1-0
            4:BG1タイルデータ1-1
            5:BG2タイルマップ
            6:BG2タイルデータ0-0
            7:BG2タイルデータ0-1

        Mode 6: 4bpp OPT(2) (2ワード +OPT)，True H-RES，インターレース時高解像度スクロール
            0:BG1タイルマップ
            1:BG1タイルデータ0-0
            2:BG1タイルデータ0-1
            3:BG1タイルデータ1-0
            4:BG1タイルデータ1-1
            6:OPT Horizontal (BG3)
            7:OPT Vertical (BG3)

        Mode 7: 8bpp (4ワード)，回転・拡大
        - タイルマップフェッチに1クロック
        - タイルデータフェッチに4クロック
    */

    // bg_mode: 各BGレイヤーのモード(2bpp/4bpp/8bpp/OPT, True H-RES)
    always_comb begin
        /*
            000: OPT(2), 100: OPT(1)
            001: 2bpp, 101: 2bpp(True H-RES)
            010: 4bpp, 110: 4bpp(True H-RES)
            011: 8bpp
        */
        bg_mode[0] = 3'b0;
        bg_mode[1] = 3'b0;
        bg_mode[2] = 3'b0;
        bg_mode[3] = 3'b0;
        unique case (bgmode)
            3'h0: begin
                bg_mode[0] = 3'b001;    // 2bpp
                bg_mode[1] = 3'b001;    // 2bpp
                bg_mode[2] = 3'b001;    // 2bpp
                bg_mode[3] = 3'b001;    // 2bpp
            end
            3'h1: begin
                bg_mode[0] = 3'b010;    // 4bpp
                bg_mode[1] = 3'b010;    // 4bpp
                bg_mode[2] = 3'b001;    // 2bpp
            end
            3'h2: begin
                bg_mode[0] = 3'b010;    // 4bpp
                bg_mode[1] = 3'b010;    // 4bpp
                bg_mode[2] = 3'b000;    // OPT(2)
            end
            3'h3: begin
                bg_mode[0] = 3'b011;    // 8bpp
                bg_mode[1] = 3'b010;    // 4bpp
            end
            3'h4: begin
                bg_mode[0] = 3'b011;    // 8bpp
                bg_mode[1] = 3'b001;    // 2bpp
                bg_mode[2] = 3'b100;    // OPT(1)
            end
            3'h5: begin
                bg_mode[0] = 3'b110;    // 4bpp(True H-RES)
                bg_mode[1] = 3'b101;    // 2bpp(True H-RES)
            end
            3'h6: begin
                bg_mode[0] = 3'b110;    // 4bpp(True H-RES)
                bg_mode[2] = 3'b000;    // OPT(2)
            end
            3'h7: ;
        endcase
    end

    // bg_target: VRAMアクセスを行うBGレイヤー
    always_comb begin
        priority casez ({bgmode, x_fetch[2:0]})

            // BG Mode 0
            6'o0?: bg_target = x_fetch[2:1];

            // BG Mode 1
            6'o10: bg_target = 2'd0;
            6'o11: bg_target = 2'd0;
            6'o12: bg_target = 2'd0;
            6'o13: bg_target = 2'd1;
            6'o14: bg_target = 2'd1;
            6'o15: bg_target = 2'd1;
            6'o16: bg_target = 2'd2;
            6'o17: bg_target = 2'd2;

            // BG Mode 2
            6'o20: bg_target = 2'd0;
            6'o21: bg_target = 2'd0;
            6'o22: bg_target = 2'd0;
            6'o23: bg_target = 2'd1;
            6'o24: bg_target = 2'd1;
            6'o25: bg_target = 2'd1;
            6'o26: bg_target = 2'd2;
            6'o27: bg_target = 2'd2;

            // BG Mode 3
            6'o30: bg_target = 2'd0;
            6'o31: bg_target = 2'd0;
            6'o32: bg_target = 2'd0;
            6'o33: bg_target = 2'd0;
            6'o34: bg_target = 2'd0;
            6'o35: bg_target = 2'd1;
            6'o36: bg_target = 2'd1;
            6'o37: bg_target = 2'd1;

            // BG Mode 4
            6'o40: bg_target = 2'd0;
            6'o41: bg_target = 2'd0;
            6'o42: bg_target = 2'd0;
            6'o43: bg_target = 2'd0;
            6'o44: bg_target = 2'd0;
            6'o45: bg_target = 2'd1;
            6'o46: bg_target = 2'd1;
            6'o47: bg_target = 2'd2;

            // BG Mode 5
            6'o50: bg_target = 2'd0;
            6'o51: bg_target = 2'd0;
            6'o52: bg_target = 2'd0;
            6'o53: bg_target = 2'd0;
            6'o54: bg_target = 2'd0;
            6'o55: bg_target = 2'd1;
            6'o56: bg_target = 2'd1;
            6'o57: bg_target = 2'd1;

            // BG Mode 6
            6'o60: bg_target = 2'd0;
            6'o61: bg_target = 2'd0;
            6'o62: bg_target = 2'd0;
            6'o63: bg_target = 2'd0;
            6'o64: bg_target = 2'd0;
            6'o66: bg_target = 2'd2;
            6'o67: bg_target = 2'd2;

            default: bg_target = 'x;
        endcase
    end

    // fetch_map_raw: VRAMタイルマップデータ(及びOPT)をフェッチするタイミング
    always_comb begin
        unique case (bgmode)
            3'h0: fetch_map_raw = ~x_fetch[0];  // x=0,2,4,6
            3'h1: fetch_map_raw =
                (x_fetch[2:0] == 3'h0)      // x=0,
                | (x_fetch[2:0] == 3'h3)    //   3,
                | (x_fetch[2:0] == 3'h6);   //   6
            3'h2: fetch_map_raw =
                (x_fetch[2:0] == 3'h0)      // x=0,
                | (x_fetch[2:0] == 3'h3)    //   3,
                | (x_fetch[2:1] == 2'b11);  //   6,7
            3'h3: fetch_map_raw =
                (x_fetch[2:0] == 3'h0)      // x=0,
                | (x_fetch[2:0] == 3'h5);   //   5
            3'h4: fetch_map_raw =
                (x_fetch[2:0] == 3'h0)      // x=0,
                | (x_fetch[2:0] == 3'h5)    //   5,
                | (x_fetch[2:0] == 3'h7);   //   7
            3'h5: fetch_map_raw =
                (x_fetch[2:0] == 3'h0)      // x=0,
                | (x_fetch[2:0] == 3'h5);   //   5 
            3'h6: fetch_map_raw =
                (x_fetch[2:0] == 3'h0)      // x=0,
                | (x_fetch[2:1] == 2'b11);  //   6,7
            3'h7: fetch_map_raw = (x_fetch[2:0] == 3'h0);   // x=0
        endcase
    end

    // fetch_data_raw: VRAMからタイルデータをフェッチするタイミング
    // 基本は~fetch_map_raw, BG Mode 6 のみ x_fetch=5 で何もしないため除外
    always_comb begin
        case (bgmode)
            3'h6: fetch_data_raw = (~fetch_map_raw) & (x_fetch[2:0] != 3'h5); // 5除外
            default: fetch_data_raw = ~fetch_map_raw;
        endcase
    end

    // 実際に処理を行うのはfetch_periodのみ
    assign fetch_map = fetch_period & fetch_map_raw;
    assign fetch_data = fetch_period & fetch_data_raw;

    // fetch_data_num: フェッチするタイルデータのオフセット
    always_comb begin
        priority casez ({bgmode, x_fetch[2:0]})
            /*
                000: データ0 / OPT(2, Horizontal) / OPT(1)
                001: データ0上位8bit (同時にピクセルシフトレジスタを組み換え, True H-RES用) / OPT(2, Vertical)
                010: データ1
                011: データ1上位8bit (同時にピクセルシフトレジスタを組み換え, True H-RES用)
                100: データ2
                101: データ2上位8bit (同時にピクセルシフトレジスタを組み換え, True H-RES用)
                110: データ3
                111: データ3上位8bit (同時にピクセルシフトレジスタを組み換え, True H-RES用)
            */
            6'o0?: fetch_data_num = 3'b000; // Mode 0, x=1,3,5,7: データ0

            6'o11: fetch_data_num = 3'b000; // Mode 1, x=1: データ0
            6'o12: fetch_data_num = 3'b010; // Mode 1, x=2: データ1
            6'o14: fetch_data_num = 3'b000; // Mode 1, x=4: データ0
            6'o15: fetch_data_num = 3'b010; // Mode 1, x=5: データ1
            6'o17: fetch_data_num = 3'b000; // Mode 1, x=7: データ0

            6'o21: fetch_data_num = 3'b000; // Mode 2, x=1: データ0
            6'o22: fetch_data_num = 3'b010; // Mode 2, x=2: データ1
            6'o24: fetch_data_num = 3'b000; // Mode 2, x=4: データ0
            6'o25: fetch_data_num = 3'b010; // Mode 2, x=5: データ1
            6'o26: fetch_data_num = 3'b000; // Mode 2, x=6: OPT(2, Horizontal)
            6'o27: fetch_data_num = 3'b001; // Mode 2, x=7: OPT(2, Vertical)

            6'o31: fetch_data_num = 3'b000; // Mode 3, x=1: データ0
            6'o32: fetch_data_num = 3'b010; // Mode 3, x=2: データ1
            6'o33: fetch_data_num = 3'b100; // Mode 3, x=3: データ2
            6'o34: fetch_data_num = 3'b110; // Mode 3, x=4: データ3
            6'o36: fetch_data_num = 3'b000; // Mode 3, x=6: データ0
            6'o37: fetch_data_num = 3'b010; // Mode 3, x=7: データ1

            6'o41: fetch_data_num = 3'b000; // Mode 4, x=1: データ0
            6'o42: fetch_data_num = 3'b010; // Mode 4, x=2: データ1
            6'o43: fetch_data_num = 3'b100; // Mode 4, x=3: データ2
            6'o44: fetch_data_num = 3'b110; // Mode 4, x=4: データ3
            6'o46: fetch_data_num = 3'b000; // Mode 4, x=6: データ0
            6'o47: fetch_data_num = 3'b000; // Mode 4, x=7: OPT(1)

            6'o51: fetch_data_num = 3'b000; // Mode 5, x=1: データ0-0
            6'o52: fetch_data_num = 3'b001; // Mode 5, x=2: データ0-1
            6'o53: fetch_data_num = 3'b010; // Mode 5, x=3: データ1-0
            6'o54: fetch_data_num = 3'b011; // Mode 5, x=4: データ1-1
            6'o56: fetch_data_num = 3'b000; // Mode 5, x=6: データ0-0
            6'o57: fetch_data_num = 3'b001; // Mode 5, x=7: データ0-1

            6'o61: fetch_data_num = 3'b000; // Mode 6, x=1: データ0-0
            6'o62: fetch_data_num = 3'b001; // Mode 6, x=2: データ0-1
            6'o63: fetch_data_num = 3'b010; // Mode 6, x=3: データ1-0
            6'o64: fetch_data_num = 3'b011; // Mode 6, x=4: データ1-1
            6'o66: fetch_data_num = 3'b000; // Mode 6, x=6: OPT(2, Horizontal)
            6'o67: fetch_data_num = 3'b001; // Mode 6, x=7: OPT(2, Vertical)
            
            default: fetch_data_num = 'x;
        endcase
    end
    
endmodule
