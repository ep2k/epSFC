// ==============================
//  Top module for DE0-CV
// ==============================

// Copyright(C) 2024 ep2k All Rights Reserved.

`include "config.vh"    // include/de0cv/config.vh

module epSFC_de0cv (
    input logic [3:0]   CLK_50M,    // Clock 50MHz
    input logic         RESET_N,    // Push Button "Reset" (DEV_CLRn)

    input logic [9:0]   SW,         // Toggle Switch
    input logic [3:0]   KEY,        // Push Button

    output logic [9:0]  LEDR,       // LED Red

    output logic [6:0]  HEX0,       // Seven Segment Digit 0
    output logic [6:0]  HEX1,       // Seven Segment Digit 1
    output logic [6:0]  HEX2,       // Seven Segment Digit 2
    output logic [6:0]  HEX3,       // Seven Segment Digit 3
    output logic [6:0]  HEX4,       // Seven Segment Digit 4
    output logic [6:0]  HEX5,       // Seven Segment Digit 5

    output logic [3:0]  VGA_R,      // VGA Red
    output logic [3:0]  VGA_G,      // VGA Green
    output logic [3:0]  VGA_B,      // VGA Blue
    output logic        VGA_HS,     // VGA H-Sync
    output logic        VGA_VS,     // VGA V-Sync

    inout logic [15:0]  DRAM_DQ,    // SDRAM Data
    output logic [12:0] DRAM_ADDR,  // SDRAM Address
    output logic [1:0]  DRAM_BA,    // SDRAM Bank Address
    output logic        DRAM_CLK,   // SDRAM Clock
    output logic        DRAM_CKE,   // SDRAM Clock Enable
    output logic        DRAM_LDQM,  // SDRAM Low-Byte Data Mask
    output logic        DRAM_UDQM,  // SDRAM High-Byte Data Mask
    output logic        DRAM_WE_N,  // SDRAM Write Enable
    output logic        DRAM_CAS_N, // SDRAM Column Address Strobe
    output logic        DRAM_RAS_N, // SDRAM Row Address Strobe
    output logic        DRAM_CS_N,  // SDRAM Chip Select

    output logic        SD_CLK,     // SD-Card Clock
    inout logic         SD_CMD,     // SD-Card Command
    inout logic [3:0]   SD_DATA,    // SD-Card Data

    inout logic         PS2_CLK,    // PS/2 Clock
    inout logic         PS2_DAT,    // PS/2 Data
    inout logic         PS2_CLK2,   // PS/2 Clock (2nd device)
    inout logic         PS2_DAT2,   // PS/2 Data (2nd device)

    inout logic [35:0]  GPIO_0,     // GPIO 0
    inout logic [35:0]  GPIO_1      // GPIO 1
);

    genvar gi;

    // ------------------------------
    //  Wires
    // ------------------------------
    
    // ---- Reset --------

    logic reset;
    logic reset_ext;

    // ---- Clock --------
    
    logic clk;          // 21.47727 MHz
    logic apu_clk;      // 10.24 MHz
    logic vga_clk;      // 25.175 MHz
    logic dr_clk;       // 75 MHz
    logic dr_clko;      // 75 MHz - 3ns
    logic pad_clk;      // 500 kHz

    // ---- Cartridge --------

    logic [23:0] a_addr;
    logic a_write, a_read, cart_en, wram_en;
    logic [7:0] b_addr;
    logic b_write, b_read;

    logic [7:0] cart_rdata, cart_wdata;
    logic cart_send;

    logic use_intcart;
    logic [7:0] cart_rdata_int;

    logic cart_reset_in, cart_irq_in;
    logic cpu_clk_out, refresh;

    // ---- PPU --------

    logic [8:0] w_x, w_y, r_x, r_y;
    logic [14:0] w_color, r_color;
    logic color_write;
    logic w_req, r_req;
    
    logic overscan;
    logic interlace;
    logic [2:0] bgmode;
    logic [11:0] frame_ctr;

    // ---- Other Console Signals --------

    logic hvint_irq;

    logic cpu_en_m1;    // cpu_enの1クロック前にHigh

    // 有効なカートリッジ信号のテストに使用(後に信号を確定し不要なものを削除)
    logic n_cpu_en;
    logic cpu_en_m2;
    logic mid_en;

    logic var_fast;

    // ---- Sound --------

    logic [15:0] sound_l, sound_r;
    logic [6:0] envx_x[7:0];

    logic sound_l_pdm, sound_r_pdm;

    // ---- Joypad --------

    // DUALSHOCK
    logic p1_dat, p1_cmd, p1_sel, p1_sclk, p1_ack;
    logic p2_dat, p2_cmd, p2_sel, p2_sclk, p2_ack;

    logic [15:0] p1_buttons, p2_buttons;
    logic p1_connect, p2_connect;
    logic p1_reset;
    logic [11:0] joy1, joy2;

    logic no_push_pwm; // 非プッシュかつ接続時のLED出力
    logic [6:0] hex_p1_l, hex_p1_r, hex_p2_l, hex_p2_r;

    // ---- SDRAM --------

    logic [15:0] dr_wdata, dr_rdata;
    logic dr_send;

    // ---- Additional Functions --------

    logic [4:0] graphic_off;    // PPU 各レイヤー(GB, OBJ)をオフ
    logic [7:0] sound_off;      // APU 各チャンネルをオフ
    logic [1:0] interpol_sel;   // APU BRR補間方法を選択(0: ガウス, 1: 線形, 3: なし)
    logic echo_off;             // APU エコー機能をオフ
    logic pad_exchange;         // Joypad P1, P2を交換
    logic coord_pointer_en;     // 指定した座標に点を表示
    logic coord_pointer_coarse; // 座標指定を粗調整(0: 1pxずつ, 1: 10pxずつ)

    logic [7:0] envx_square_pwm;

    // ------------------------------
    //  Registers
    // ------------------------------

    // ---- Cartridge --------

    logic [7:0] cart_rdata_reg;

    // ---- Joypad --------

    logic [15:0] p1_buttons_reg, p2_buttons_reg;
    logic p1_connect_reg, p2_connect_reg;

    // ---- Additional Functions --------

    logic [7:0] coord_pointer_x = 8'h0;
    logic [7:0] coord_pointer_y = 8'h0;

    logic [14:0] sound_abs_max = 15'h0;

    // ------------------------------
    //  Main
    // ------------------------------
    
    `include "top_assignment.sv"    // include/de0cv/top_assignment.vh

    // ---- GPIO Assignment --------

    assign {
        GPIO_1[31], GPIO_1[20], GPIO_1[19], GPIO_1[23],     // 23-20
        GPIO_1[16], GPIO_1[14], GPIO_1[12], GPIO_1[10],     // 19-16
        GPIO_0[6], GPIO_1[3], GPIO_1[1], GPIO_0[4],         // 15-12
        GPIO_0[5], GPIO_1[2], GPIO_0[9], GPIO_1[11],        // 11-8
        GPIO_1[9], GPIO_1[13], GPIO_1[15], GPIO_1[17],      // 7-4
        GPIO_1[21], GPIO_1[18], GPIO_1[22], GPIO_1[33]      // 3-0
    }
    = use_intcart ? '1 : ~a_addr;
    assign GPIO_1[32] = (~use_intcart) & a_write;
    assign GPIO_1[34] = (~use_intcart) & a_read;
    assign GPIO_1[35] = (~use_intcart) & cart_en;
    assign GPIO_1[5] = (~use_intcart) & wram_en;

    assign {
        GPIO_1[8], GPIO_0[7], GPIO_1[28], GPIO_1[29],       // 7-4
        GPIO_1[26], GPIO_1[27], GPIO_1[24], GPIO_1[25]      // 3-0
    }
    = use_intcart ? '1 : ~b_addr;
    assign GPIO_1[4] = (~use_intcart) & b_write;
    assign GPIO_1[0] = (~use_intcart) & b_read;

    assign {
        GPIO_0[12], GPIO_0[16], GPIO_0[13], GPIO_0[11],     // 7-4
        GPIO_0[15], GPIO_0[17], GPIO_0[10], GPIO_0[8]       // 3-0
    }
    = ((~use_intcart) & cart_send) ? cart_wdata : 'z;
    assign cart_rdata = {
        GPIO_0[12], GPIO_0[16], GPIO_0[13], GPIO_0[11],     // 7-4
        GPIO_0[15], GPIO_0[17], GPIO_0[10], GPIO_0[8]       // 3-0
    };
    assign GPIO_0[14] = (~use_intcart) & cart_send;

    assign GPIO_1[30] = use_intcart | (~cpu_clk_out);
    assign GPIO_1[6] = use_intcart | (~clk);
    assign GPIO_1[7] = use_intcart | (~refresh);

    assign GPIO_0[28] = ((~use_intcart) & reset) ? 1'b0 : 1'bz;
    assign cart_reset_in = GPIO_0[28];

    assign GPIO_0[29] = ((~use_intcart) & hvint_irq) ? 1'b0 : 1'bz;
    assign cart_irq_in = GPIO_0[29];

    assign GPIO_0[30] = sound_l_pdm;
    assign GPIO_0[31] = sound_r_pdm;

    assign p1_dat = GPIO_0[19];
    assign GPIO_0[21] = p1_cmd;
    assign GPIO_0[23] = p1_sel;
    assign GPIO_0[25] = p1_sclk;
    assign p1_ack = GPIO_0[26];
    assign {GPIO_0[19], GPIO_0[26]} = 'z;

    assign p2_dat = GPIO_0[18];
    assign GPIO_0[20] = p2_cmd;
    assign GPIO_0[22] = p2_sel;
    assign GPIO_0[24] = p2_sclk;
    assign p2_ack = GPIO_0[27];
    assign {GPIO_0[18], GPIO_0[27]} = 'z;
    
    // ---- Reset --------

    // assign reset_ext = ~RESET_N; // in "top_assignment.sv"
    assign reset = reset_ext | p1_reset;

    // ---- Clock --------

    clock_generator clock_generator(
        .pin_clks(CLK_50M),

        .clk,
        .apu_clk,
        .vga_clk,
        .dr_clk,
        .dr_clko,
        .pad_clk
    );

    // ---- Console (Main part) --------

    always_ff @(posedge clk) begin
        if (cpu_en_m1) begin
            cart_rdata_reg <= use_intcart ? cart_rdata_int : cart_rdata;
        end
    end

    console console(
        .clk,
        .apu_clk,
        .reset,

        .cart_rdata(cart_rdata_reg),
        .wdata(cart_wdata),
        .cart_send,

        .a_addr,
        .a_write,
        .a_read,
        .cart_en,
        .wram_en,

        .b_addr,
        .b_write,
        .b_read,
        
        .refresh,
        .cpu_clk_out,

        // .cart_irq_in,
        .cart_irq_in(1'b0),     // temporarily disabled
        .hvint_irq,

        .n_cpu_en,
        .cpu_en_m1,
        .cpu_en_m2,
        .mid_en,
        .var_fast,

        .x(w_x),
        .y(w_y),
        .color(w_color),
        .color_write,
        .dr_write_req(w_req),
        .overscan,
        .interlace,
        .bgmode,
        .frame_ctr,
        .graphic_off,
        .coord_pointer_en,
        .coord_pointer_x,
        .coord_pointer_y,

        .sound_l,
        .sound_r,
        .envx_x,
        .interpol_sel,
        .sound_off,
        .echo_off,

        .joy1(coord_pointer_en ? 12'h0 : joy1),
        .joy2,
        .joy3(12'h0),
        .joy4(12'h0),
        .joy_connect({2'b0, p2_connect_reg, p1_connect_reg})
    );

    // ---- VGA --------

    vga_controller vga_controller(
        .clk(vga_clk),
        .overscan,
        .interlace,
        
        .y_next(r_y),
        .r_req,

        .x_next(r_x),
        .color(r_color),

        .vga_r(VGA_R),
        .vga_g(VGA_G),
        .vga_b(VGA_B),
        .vga_hs(VGA_HS),
        .vga_vs(VGA_VS)
    );

    // ---- ΔΣ DAC --------

    delta_sigma #(.WIDTH(15)) delta_sigma_left(
        .clk(CLK_50M[0]),
        .data_in({~sound_l[14], sound_l[13:0]}), // -4000~3FFF -> 0~7FFF
        .pulse_out(sound_l_pdm)
    );

    delta_sigma #(.WIDTH(15)) delta_sigma_right(
        .clk(CLK_50M[0]),
        .data_in({~sound_r[14], sound_r[13:0]}), // -4000~3FFF -> 0~7FFF
        .pulse_out(sound_r_pdm)
    );

    // ---- Joypad --------
    
    // DUALSHOCK Driver
    pad_driver p1_driver(
        .clk(pad_clk),
        .reset(reset_ext),

        .analog_mode(1'b0),
        .vibrate_sub(1'b0),
        .vibrate(8'h0),

        .dat(p1_dat),
        .cmd(p1_cmd),
        .n_sel(p1_sel),
        .sclk(p1_sclk),
        .n_ack(p1_ack),

        .pad_connect(p1_connect),

        .pad_buttons(p1_buttons)
    );

    // DUALSHOCK Driver
    pad_driver p2_driver(
        .clk(pad_clk),
        .reset(reset_ext),

        .analog_mode(1'b0),
        .vibrate_sub(1'b0),
        .vibrate(8'h0),

        .dat(p2_dat),
        .cmd(p2_cmd),
        .n_sel(p2_sel),
        .sclk(p2_sclk),
        .n_ack(p2_ack),

        .pad_connect(p2_connect),

        .pad_buttons(p2_buttons)
    );

    always_ff @(posedge clk) begin
        p1_buttons_reg <= pad_exchange ? p2_buttons : p1_buttons;
        p2_buttons_reg <= pad_exchange ? p1_buttons : p2_buttons;
        p1_connect_reg <= pad_exchange ? p2_connect : p1_connect;
        p2_connect_reg <= pad_exchange ? p1_connect : p2_connect;
    end

    assign joy1 = ~{
        p1_buttons_reg[14],     // B
        p1_buttons_reg[15],     // Y
        p1_buttons_reg[0],      // Select
        p1_buttons_reg[3],      // Start
        p1_buttons_reg[4],      // Up
        p1_buttons_reg[6],      // Down
        p1_buttons_reg[7],      // Left
        p1_buttons_reg[5],      // Right
        p1_buttons_reg[13],     // A
        p1_buttons_reg[12],     // X
        p1_buttons_reg[10],     // L
        p1_buttons_reg[11]      // R
    };

    assign joy2 = ~{
        p2_buttons_reg[14],     // B
        p2_buttons_reg[15],     // Y
        p2_buttons_reg[0],      // Select
        p2_buttons_reg[3],      // Start
        p2_buttons_reg[4],      // Up
        p2_buttons_reg[6],      // Down
        p2_buttons_reg[7],      // Left
        p2_buttons_reg[5],      // Right
        p2_buttons_reg[13],     // A
        p2_buttons_reg[12],     // X
        p2_buttons_reg[10],     // L
        p2_buttons_reg[11]      // R
    };

    assign p1_reset = (p1_buttons_reg[11:8] == 4'h0);

    pwm #(.WIDTH(8)) pwm_no_push(
        .clk,
        .din(8'h1),
        .dout(no_push_pwm)
    );

    seg7_joypad seg7_joy1(
        .joypad(joy1),
        .no_push_pwm(p1_connect_reg & no_push_pwm),
        .dout_l(hex_p1_l),
        .dout_r(hex_p1_r)
    );

    seg7_joypad seg7_joy2(
        .joypad(joy2),
        .no_push_pwm(p2_connect_reg & no_push_pwm),
        .dout_l(hex_p2_l),
        .dout_r(hex_p2_r)
    );

    // ---- SDRAM --------

    sdram_controller sdram_controller(
        .clk(dr_clk),

        .dr_wdata,
        .dr_rdata,
        .dr_addr(DRAM_ADDR),
        .dr_ba(DRAM_BA),
        .dr_cke(DRAM_CKE),
        .dr_ldqm(DRAM_LDQM),
        .dr_udqm(DRAM_UDQM),
        .dr_n_we(DRAM_WE_N),
        .dr_n_cas(DRAM_CAS_N),
        .dr_n_ras(DRAM_RAS_N),
        .dr_n_cs(DRAM_CS_N),
        .dr_send,

        .w_x,
        .w_y,
        .w_color,
        .color_write,
        .w_req,

        .r_req,
        .r_y,

        .r_x,
        .r_color
    );

    assign DRAM_DQ = dr_send ? dr_wdata : 'z;
    assign dr_rdata = DRAM_DQ;

    assign DRAM_CLK = dr_clko;

    // ---- Internal Cartridge (Optional) --------

    `ifdef USE_INTCART
        cartridge cartridge(
            .clk,
            
            .a_addr,
            .a_write(a_write & use_intcart),
            .a_read(a_read & use_intcart),
            .cart_en,
            .rdata(cart_rdata_int),
            .wdata(cart_wdata)
        );
    `else
        assign cart_rdata_int = 8'h0;
    `endif

    // ---- Additional Functions (Optional) --------

    `ifdef USE_COORD_POINTER // 指定した座標に点を表示

        // ---- Wires --------
        logic [3:0] joy_dpad;

        // ---- Registers --------
        logic [3:0] joy_dpad_reg;

        // ---- Main --------

        assign joy_dpad = joy1[7:4];

        always_ff @(posedge clk) begin
            joy_dpad_reg <= joy_dpad;
        end

        always_ff @(posedge clk) begin
            if (coord_pointer_en) begin
                if (joy_dpad[0] & (~joy_dpad_reg[0])) begin // →
                    coord_pointer_x <=
                        coord_pointer_x + (coord_pointer_coarse ? 10 : 1);
                end else if (joy_dpad[1] & (~joy_dpad_reg[1])) begin // ←
                    coord_pointer_x <=
                        coord_pointer_x - (coord_pointer_coarse ? 10 : 1);
                end

                if (joy_dpad[2] & (~joy_dpad_reg[2])) begin // ↓
                    coord_pointer_y <=
                        coord_pointer_y + (coord_pointer_coarse ? 10 : 1);
                end else if (joy_dpad[3] & (~joy_dpad_reg[3])) begin // ↑
                    coord_pointer_y <=
                        coord_pointer_y - (coord_pointer_coarse ? 10 : 1);
                end
            end
        end
    `endif

    `ifdef USE_ENVX_SQUARE_PWM // (サウンド各ch音量)^2をPWMで表示
        generate
            for (gi = 0; gi < 8; gi++) begin : GenEnvxPWMs
                logic [6:0] envx;
                logic [13:0] envx_square;

                assign envx = envx_x[gi];

                // envx_square = envx * envx
                bram_envx_square_table_rom bram_envx_square_table_rom(      // IP (ROM: 1-PORT, 14bit * 128)
                    .address(envx),                                         // rom/system/envx_square_table.mif
                    .clock(clk),
                    .q(envx_square)
                );

                pwm #(.WIDTH(14)) pwm_envx(
                    .clk,
                    .din(envx_square),
                    .dout(envx_square_pwm[gi])
                );
            end
        endgenerate
    `else
        assign envx_square_pwm = 8'h0;
    `endif

    `ifdef USE_SOUND_ABS_MAX

        // ---- Wires --------
        logic [14:0] sound_l_abs;
        logic [14:0] sound_r_abs;

        // ---- Main --------

        assign sound_l_abs = sound_l[15] ? (-sound_l) : sound_l;
        assign sound_r_abs = sound_r[15] ? (-sound_r) : sound_r;

        always_ff @(posedge apu_clk) begin
            if (reset) begin
                sound_abs_max <= 15'h0;
            end else if (sound_l_abs > sound_abs_max) begin
                if (sound_r_abs > sound_l_abs) begin
                    sound_abs_max <= sound_r_abs;
                end else begin
                    sound_abs_max <= sound_l_abs;
                end
            end else if (sound_r_abs > sound_abs_max) begin
                sound_abs_max <= sound_r_abs;
            end
        end

    `endif

    // ------------------------------
    //  Unused pins
    // ------------------------------

    // LED
    // assign LEDR = 10'h0;

    // Seven Segement
    // assign HEX0 = 7'h7f;
    // assign HEX1 = 7'h7f;
    // assign HEX2 = 7'h7f;
    // assign HEX3 = 7'h7f;
    // assign HEX4 = 7'h7f;
    // assign HEX5 = 7'h7f;
    // assign HEX6 = 7'h7f;

    // VGA
    // assign VGA_R = 4'h0;
    // assign VGA_G = 4'h0;
    // assign VGA_B = 4'h0;
    // assign VGA_HS = 1'b1;
    // assign VGA_VS = 1'b1;

    // SDRAM
    // assign DRAM_DQ = 'z;
    // assign DRAM_ADDR = 12'h0;
    // assign DRAM_BA = 2'h0;
    // assign DRAM_CLK = 1'b0;
    // assign DRAM_CKE = 1'b0;
    // assign DRAM_LDQM = 1'b0;
    // assign DRAM_UDQM = 1'b0;
    // assign DRAM_WE_N = 1'b0;
    // assign DRAM_CAS_N = 1'b0;
    // assign DRAM_RAS_N = 1'b0;
    // assign DRAM_CS_N = 1'b0;

    // SD-Card
    assign SD_CLK = 1'b0;
    assign SD_CMD = 1'bz;
    assign SD_DATA = 'z;

    // PS/2
    assign PS2_CLK = 1'bz;
    assign PS2_DAT = 1'bz;
    assign PS2_CLK2 = 1'bz;
    assign PS2_DAT2 = 1'bz;

    // GPIO
    // assign GPIO_0 = 'z;
    // assign GPIO_1 = 'z;
    assign GPIO_0[3:0] = 'z;

endmodule
