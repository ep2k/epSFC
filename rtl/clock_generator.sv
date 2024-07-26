// ==============================
//  Clock Generator (PLL)
// ==============================

// Copyright(C) 2024 ep2k All Rights Reserved.

module clock_generator (
    input logic [3:0] pin_clks,     // 50 MHz

    output logic clk,               // 21.47727 MHz
    output logic apu_clk,           // 10.24 MHz
    output logic vga_clk,           // 25.175 MHz
    output logic dr_clk,            // 75 MHz
    output logic dr_clko,           // 75 MHz - 3ns
    output logic pad_clk            // 500 kHz
);

    // ------------------------------
    //  Wires
    // ------------------------------
    
    logic master_out, apu_out, vga_out, dr_out, dro_out;
    logic master_l, apu_l, vga_l, dr_l;

    // ------------------------------
    //  Registers
    // ------------------------------
    
    logic [5:0] pad_ctr = 6'd0; // 0 ~ 49

    // ------------------------------
    //  Main
    // ------------------------------

    pll_master pll_master(      // IP (PLL: 50MHz -> 21.47727MHz)
        .refclk(pin_clks[0]),
        .rst(1'b0),
        .outclk_0(master_out),
        .locked(master_l)
    );

    pll_apu pll_apu(            // IP (PLL: 50MHz -> 10.24MHz)
        .refclk(pin_clks[1]),
        .rst(1'b0),
        .outclk_0(apu_out),
        .locked(apu_l)
    );

    pll_vga pll_vga(            // IP (PLL: 50MHz -> 25.175MHz)
        .refclk(pin_clks[2]),
        .rst(1'b0),
        .outclk_0(vga_out),
        .locked(vga_l)
    );

    pll_dr pll_dr(              // IP (PLL: 50MHz -> 75MHz, 75MHz-3ns)
        .refclk(pin_clks[3]),
        .rst(1'b0),
        .outclk_0(dr_out),
        .outclk_1(dro_out),
        .locked(dr_l)
    );

    assign clk = master_l & master_out;
    assign apu_clk = apu_l & apu_out;
    assign vga_clk = vga_l & vga_out;
    assign dr_clk = dr_l & dr_out;
    assign dr_clko = dr_l & dro_out;

    // 50MHz -> 500kHz
    always_ff @(posedge pin_clks[0]) begin
        pad_ctr <= (pad_ctr == 6'd49) ? 6'd0 : (pad_ctr + 6'd1);
        if (pad_ctr == 6'd49) begin
            pad_clk <= ~pad_clk;
        end
    end
    
endmodule
