// ==============================
//  SFC Hardware Emulator
// ==============================

// Copyright(C) 2024 ep2k All Rights Reserved.

module console
    import bus_pkg::*;
(
    input logic clk,
    input logic apu_clk,
    input logic reset,

    input logic [7:0] cart_rdata,
    output logic [7:0] wdata,
    output logic cart_send,

    output logic [23:0] a_addr,
    output logic a_write,
    output logic a_read,
    output logic cart_en,
    output logic wram_en,

    output logic [7:0] b_addr,
    output logic b_write,
    output logic b_read,

    output logic refresh,
    output logic cpu_clk_out,

    input logic cart_irq_in,
    output logic hvint_irq,

    output logic n_cpu_en,
    output logic cpu_en_m1,
    output logic cpu_en_m2,
    output logic mid_en,
    output logic var_fast,

    output logic [8:0] x,
    output logic [8:0] y,
    output logic [14:0] color,
    output logic color_write,
    output logic dr_write_req,
    output logic overscan,
    output logic interlace,
    output logic [2:0] bgmode,
    output logic [11:0] frame_ctr,
    input logic [4:0] graphic_off,
    input logic coord_pointer_en,
    input logic [7:0] coord_pointer_x,
    input logic [7:0] coord_pointer_y,

    output logic [15:0] sound_l,
    output logic [15:0] sound_r,
    output logic [6:0] envx_x[7:0],
    input logic [1:0] interpol_sel,
    input logic [7:0] sound_off,
    input logic echo_off,

    input logic [11:0] joy1,
    input logic [11:0] joy2,
    input logic [11:0] joy3,
    input logic [11:0] joy4,
    input logic [3:0] joy_connect
);

    // ------------------------------
    //  Wires
    // ------------------------------
    
    logic [23:0] cpu_addr;
    logic [7:0] cpu_rdata, cpu_wdata;
    logic cpu_read, cpu_write;
    mem_speed_type mem_speed;
    logic cpu_en;

    logic b_en;
    logic [7:0] a_rdata, b_rdata;
    a_read_target_type a_read_target;
    a_op_type a_op;
    b_read_target_type b_read_target;
    b_op_type b_op;

    logic nmi;

    logic dma;
    logic [23:0] a_addr_dma;
    logic [7:0] b_addr_dma;
    logic a_write_dma, a_read_dma, b_write_dma, b_read_dma, dma_a2b;

    logic [7:0] wram_rdata, hvint_rdata, joy_rdata, muldiv_rdata, dma_rdata, ppu_rdata, apu_rdata;

    logic [8:0] h_ctr;
    logic [8:0] v_ctr;
    
    // ------------------------------
    //  Main
    // ------------------------------

    assign a_addr = dma ? a_addr_dma : cpu_addr;
    assign b_addr = dma ? b_addr_dma : cpu_addr[7:0];

    assign a_write = dma ? a_write_dma : ((~b_en) & cpu_write);
    assign a_read = dma ? a_read_dma : ((~b_en) & cpu_read);
    assign b_write = dma ? b_write_dma : (b_en & cpu_write);
    assign b_read = dma ? b_read_dma : (b_en & cpu_read);

    assign wdata = dma ? (dma_a2b ? a_rdata : b_rdata) : cpu_wdata;

    always_comb begin
        if (dma) begin
            if (dma_a2b) begin  // A -> B
                cart_send = (b_op == B_NONE) & b_write;
            end else begin      // B -> A
                cart_send = (a_op == A_NONE) & (~wram_en) & a_write;
            end
        end else begin
            cart_send = a_write | b_write;
        end
    end

    cpu cpu(
        .clk,
        .cpu_en((~dma) & cpu_en),
        .reset,

        .irq(cart_irq_in | hvint_irq),
        .nmi,

        .mem_addr(cpu_addr),
        .mem_rdata(b_en ? b_rdata : a_rdata),
        .mem_wdata(cpu_wdata),
        .mem_read(cpu_read),
        .mem_write(cpu_write)
    );

    speed_counter speed_counter(
        .clk,
        .reset,

        .mem_access(a_write | a_read | b_write | b_read | dma),
        .mem_speed(dma ? MEM_SLOW : mem_speed),

        .speed_change(a_op == A_MEMSEL),
        .new_speed(wdata[0]),

        .stop(refresh),

        .cpu_en,
        .n_cpu_en,
        .cpu_en_m1,
        .cpu_en_m2,
        .mid_en,

        .cpu_clk_out,

        .var_fast
    );

    a_addr_decoder a_addr_decoder(
        .a_addr,
        .a_write,
        .a_read,

        .cart_en,
        .wram_en,
        .b_en,

        .a_read_target, // cart, wram, joy, mul_div, hv_int, dma
        .a_op,

        .mem_speed
    );

    b_addr_decoder b_addr_decoder(
        .b_addr,
        .b_write,
        .b_read,

        .b_read_target, // cart, ppu, apu, wram_b
        .b_op
    );

    // a_read_target -> a_rdata
    always_comb begin
        case (a_read_target)
            A_RT_CART: a_rdata = cart_rdata;
            A_RT_WRAM: a_rdata = wram_rdata;
            A_RT_JOY: a_rdata = joy_rdata;
            A_RT_HV: a_rdata = hvint_rdata;
            A_RT_MD: a_rdata = muldiv_rdata;
            A_RT_DMA: a_rdata = dma_rdata;
            default: a_rdata = cart_rdata;
        endcase
    end

    // b_read_target -> b_rdata
    always_comb begin
        case (b_read_target)
            B_RT_CART: b_rdata = cart_rdata;
            B_RT_PPU: b_rdata = ppu_rdata;
            B_RT_APU: b_rdata = apu_rdata;
            B_RT_WRAM: b_rdata = wram_rdata;
            default: b_rdata = cart_rdata;
        endcase
    end

    refresh_controller refresh_controller(
        .clk,
        .cpu_en,
        .reset,

        .start(h_ctr == 9'd133),
        .refresh
    );

    wram wram(
        .clk,
        .cpu_en,
        .reset,

        .addr_a({a_addr[22] & a_addr[16], a_addr[15:0]}),
        .wram_en,
        .a_write,

        .b_op,

        .wdata,
        .rdata(wram_rdata)
    );

    hvint hvint(
        .clk,
        .cpu_en,
        .reset,

        .a_op,
        .wdata,
        .rdata(hvint_rdata),

        .h_ctr,
        .v_ctr,
        .overscan,

        .nmi,
        .irq(hvint_irq)
    );

    joypad joypad(
        .clk,
        .cpu_en,
        .reset,

        .a_op,
        .wdata,
        .rdata(joy_rdata),

        .joy1,
        .joy2,
        .joy3,
        .joy4,
        .connect(joy_connect),
        .auto_read_time((v_ctr == (overscan ? 9'd240 : 9'd225)) & (h_ctr == 9'd32))
    );

    muldiv muldiv(
        .clk,
        .cpu_en,
        .reset,

        .a_op,
        .wdata,
        .rdata(muldiv_rdata)
    );

    dma_controller dma_controller(
        .clk,
        .cpu_en,
        .reset,

        .a_op,
        .op_ch(a_addr[6:4]),
        .wdata,
        .rdata(dma_rdata),

        .hdma_init((v_ctr == 9'd0) & (h_ctr == 9'd6)),
        .hdma_start((v_ctr < (overscan ? 9'd240 : 9'd225)) & (h_ctr == 9'd278)),

        .dma,
        .a_addr(a_addr_dma),
        .b_addr(b_addr_dma),
        .a_write(a_write_dma),
        .a_read(a_read_dma),
        .b_write(b_write_dma),
        .b_read(b_read_dma),
        .a2b(dma_a2b) // HDMAでテーブルからフェッチするときはdma_a2b=1
    );

    ppu ppu(
        .clk,
        .cpu_en,
        .reset,

        .b_op,
        .wdata,
        .rdata(ppu_rdata),

        .h_ctr,
        .v_ctr,
        .frame_ctr,

        .xout(x),
        .yout(y),
        .color,
        .color_write,
        .dr_write_req,

        .overscan,
        .interlace,
        .bgmode_out(bgmode),
        .graphic_off,
        .coord_pointer_en,
        .coord_pointer_x,
        .coord_pointer_y
    );

    apu apu(
        .clk(apu_clk),
        .reset,

        .c_clk(clk),
        .c_cpu_en(cpu_en),

        .b_op,
        .c_wdata(wdata),
        .c_rdata(apu_rdata),

        .sound_l,
        .sound_r,

        .interpol_sel,
        .sound_off,
        .echo_off,
        .envx_x
    );
    
endmodule
