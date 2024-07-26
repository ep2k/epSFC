// ==============================
//  Emulated Cartridge
// ==============================

// Copyright(C) 2024 ep2k All Rights Reserved.

module cartridge (
    input logic clk,

    input logic [23:0] a_addr,
    input logic a_write,
    input logic a_read,
    input logic cart_en,
    output logic [7:0] rdata,
    input logic [7:0] wdata
);

    // Bank 00,01 の 8000-FFFF
    // ROMはIPで配置

    logic [7:0] rdata_0, rdata_1;

    bram_cartrom_0 rom_0(           // IP (ROM: 1-PORT, 8bit * 8000h)
        .address(a_addr[14:0]),     // rom/cartridge/cartrom_0.mif
        .clock(clk),
        .q(rdata_0)
    );

    bram_cartrom_1 rom_1(           // IP (ROM: 1-PORT, 8bit * 8000h)
        .address(a_addr[14:0]),     // rom/cartridge/cartrom_1.mif
        .clock(clk),
        .q(rdata_1)
    );

    assign rdata = a_addr[16] ? rdata_1 : rdata_0;
    
endmodule
