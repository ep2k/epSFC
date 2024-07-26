// ==============================
//  H/V Interrupt Controller
// ==============================

// Copyright(C) 2024 ep2k All Rights Reserved.

module hvint
    import bus_pkg::*;
(
    input logic clk,
    input logic cpu_en,
    input logic reset,

    input a_op_type a_op,
    input logic [7:0] wdata,
    output logic [7:0] rdata,

    input logic [8:0] h_ctr,
    input logic [8:0] v_ctr,
    input logic overscan,

    output logic nmi,
    output logic irq
);
    
    // ------------------------------
    //  Wires
    // ------------------------------
    
    logic vblank, hblank;

    logic set_irq_flg;
    logic h0_period, heq_period, veq_period;

    // ------------------------------
    //  Registers
    // ------------------------------

    logic [8:0] h_timer = 9'h0;
    logic [8:0] v_timer = 9'h0;
    logic nmi_flg = 1'b0;
    logic irq_flg = 1'b0;

    logic [2:0] control = 3'h0;

    logic vblank_prev;

    // ------------------------------
    //  Main
    // ------------------------------
    
    assign nmi = control[2] & nmi_flg;
    assign irq = irq_flg;

    always_comb begin
        case (a_op)
            A_RDNMI: rdata = {nmi_flg, 3'h7, 4'h2};
            A_TIMEUP: rdata = {irq_flg, 7'h0};
            A_HVBJOY: rdata = {vblank, hblank, 5'h0, 1'b0};
            default: rdata = 8'h0;
        endcase
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            control <= 3'h0;
        end else if (cpu_en & (a_op == A_NMITIMEN)) begin
            control <= {wdata[7], wdata[5:4]};
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            h_timer <= 9'h0;
            v_timer <= 9'h0;
        end else if (cpu_en) begin
            if (a_op == A_HTIMEL) begin
                h_timer[7:0] <= wdata;
            end else if (a_op == A_HTIMEH) begin
                h_timer[8] <= wdata[0];
            end else if (a_op == A_VTIMEL) begin
                v_timer[7:0] <= wdata;
            end else if (a_op == A_VTIMEH) begin
                v_timer[8] <= wdata[0];
            end
        end
    end

    assign vblank = (v_ctr >= (overscan ? 9'd240 : 9'd225));
    assign hblank = (h_ctr >= 9'd274) | (h_ctr == 9'd0);

    assign h0_period = (h_ctr >= 9'd2) & (h_ctr < 9'd4);
    assign heq_period = (h_ctr >= (h_timer + 9'd3))
                            & (h_ctr < (h_timer + 9'd5));
    assign veq_period = (v_ctr == v_timer);

    always_ff @(posedge clk) begin
        vblank_prev <= vblank;
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            nmi_flg <= 1'b0;
        end else if (~vblank) begin
            nmi_flg <= 1'b0;
        end else if ((~vblank_prev) & vblank) begin
            nmi_flg <= 1'b1;
        end else if (cpu_en & (a_op == A_RDNMI)) begin
            nmi_flg <= 1'b0;
        end
    end

    always_comb begin
        unique case (control[1:0])
            2'h0: set_irq_flg = 1'b0;
            2'h1: set_irq_flg = heq_period;
            2'h2: set_irq_flg = veq_period & h0_period;
            2'h3: set_irq_flg = veq_period & heq_period;
        endcase
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            irq_flg <= 1'b0;
        end else if (set_irq_flg) begin
            irq_flg <= 1'b1;
        end else if (control[1:0] == 2'h0) begin
            irq_flg <= 1'b0;
        end else if (cpu_en & (a_op == A_TIMEUP)) begin
            irq_flg <= 1'b0;
        end
    end
    
endmodule
