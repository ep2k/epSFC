// ===================================
//  SDRAM Controller for Frame Buffer
// ===================================

// Copyright(C) 2024 ep2k All Rights Reserved.

module sdram_controller
    import dr_pkg::*;
(
    input logic clk,                // 75 MHz

    output logic [15:0] dr_wdata,
    input logic [15:0] dr_rdata,
    output logic [12:0] dr_addr,
    output logic [1:0] dr_ba,
    output logic dr_cke,
    output logic dr_ldqm,
    output logic dr_udqm,
    output logic dr_n_we,
    output logic dr_n_cas,
    output logic dr_n_ras,
    output logic dr_n_cs,
    output logic dr_send,
    
    input logic [14:0] w_color,
    input logic [8:0] w_x,
    input logic [8:0] w_y,
    input logic color_write,
    input logic w_req,

    input logic r_req,
    input logic [8:0] r_y,

    input logic [8:0] r_x,
    output logic [14:0] r_color
);

    // ------------------------------
    //  Wires
    // ------------------------------

    logic [14:0] ctr_max;

    logic [14:0] dr_wdata_0, dr_wdata_1;
    logic [14:0] r_color_0, r_color_1;

    // ------------------------------
    //  Registers
    // ------------------------------

    logic w_req_reg = 1'b0;
    logic r_req_reg = 1'b0;
    logic [4:0] r_req_prev;
    logic [4:0] w_req_prev;

    logic w_tgl = 1'b0;
    logic r_tgl = 1'b0;

    logic [14:0] w_color_reg;
    logic [8:0] w_x_reg;
    logic [8:0] w_y_reg;
    logic [2:0] color_write_reg;

    state_type state = S_BOOT0;
    exe_type exe = E_IDLE;
    logic [14:0] ctr = 15'h0;
    logic [3:0] ref_ctr = 4'h0;

    // ------------------------------
    //  Main
    // ------------------------------

    // ---- Synchronization: master_clk/vga_clk -> dr_clk --------

    always_ff @(posedge clk) begin
        w_req_prev <= {w_req_prev[3:0], w_req};
        r_req_prev <= {r_req_prev[3:0], r_req};
    end

    always_ff @(posedge clk) begin
        if ({w_req_prev, w_req} == 6'b000111) begin
            w_req_reg <= 1'b1;
            w_tgl <= ~w_tgl;
        end else if (exe == E_WRIT) begin
            w_req_reg <= 1'b0;
        end
    end

    always_ff @(posedge clk) begin
        if ({r_req_prev, r_req} == 6'b000111) begin
            r_req_reg <= 1'b1;
            r_tgl <= ~r_tgl;
        end else if (exe == E_READ) begin
            r_req_reg <= 1'b0;
        end
    end

    always_ff @(posedge clk) begin
        w_color_reg <= w_color;
        w_x_reg <= w_x;
        w_y_reg <= w_y;
        color_write_reg <= {color_write_reg[1:0], color_write};
    end

    // ---- State Machine --------

    always_ff @(posedge clk) begin
        ctr <= (ctr == ctr_max) ? 15'h0 : (ctr + 15'h1);
        if ((state == S_REF) & (ctr == ctr_max)) begin
            ref_ctr <= ref_ctr + 1;
        end
    end

    always_comb begin
        case (state)
            S_BOOT0: ctr_max = BOOT0_WAIT;
            S_BOOT1: ctr_max = BOOT1_WAIT;
            S_PALL: ctr_max = PRE_WAIT;
            S_REF: ctr_max = REF_WAIT;
            S_MRS: ctr_max = MRS_WAIT;
            S_ACT: ctr_max = ACT_WAIT;
            S_READ: ctr_max = READ_WAIT;
            S_WRIT: ctr_max = WRIT_WAIT;
            S_PRE: ctr_max = PRE_WAIT;
            S_IDLE: ctr_max = 0;
            default: ctr_max = 0;
        endcase
    end

    always_ff @(posedge clk) begin
        case (state)
            S_BOOT0: if (ctr == ctr_max) state <= S_BOOT1;
            S_BOOT1: if (ctr == ctr_max) state <= S_PALL;
            S_PALL: if (ctr == ctr_max) state <= S_REF;
            S_REF: if ((ctr == ctr_max) & (ref_ctr == INIREF_TIME)) state <= S_MRS;
            S_MRS: if (ctr == ctr_max) state <= S_IDLE;
            S_IDLE: if (exe != E_IDLE) state <= S_ACT;
            S_ACT: if (ctr == ctr_max) state <= (exe == E_WRIT) ? S_WRIT : S_READ;
            S_WRIT: if (ctr == ctr_max) state <= S_PRE;
            S_READ: if (ctr == ctr_max) state <= S_PRE;
            S_PRE: if (ctr == ctr_max) state <= S_IDLE;
            default: ;
        endcase
    end

    always_ff @(posedge clk) begin
        case (exe)
            E_IDLE: if (w_req_reg) begin
                        exe <= E_WRIT;
                    end else if (r_req_reg) begin
                        exe <= E_READ;
                    end
            E_WRIT: if (state == S_WRIT) exe <= E_IDLE;
            E_READ: if (state == S_READ) exe <= E_IDLE;
            default: ;
        endcase
    end

    // ---- COM Signals --------

    assign dr_cke = (state != S_BOOT0);
    assign dr_ldqm = ~((state == S_ACT) | (state == S_WRIT) | (state == S_READ));
    assign dr_udqm = ~((state == S_ACT) | (state == S_WRIT) | (state == S_READ));
    assign dr_n_cs = 1'b0;

    always_comb begin
        if (ctr == 0) begin
            case (state)
                S_PALL: {dr_n_ras, dr_n_cas, dr_n_we} = 3'b010;
                S_REF: {dr_n_ras, dr_n_cas, dr_n_we} = 3'b001;
                S_MRS: {dr_n_ras, dr_n_cas, dr_n_we} = 3'b000;
                S_ACT: {dr_n_ras, dr_n_cas, dr_n_we} = 3'b011;
                S_WRIT: {dr_n_ras, dr_n_cas, dr_n_we} = 3'b100;
                S_READ: {dr_n_ras, dr_n_cas, dr_n_we} = 3'b101;
                S_PRE: {dr_n_ras, dr_n_cas, dr_n_we} = 3'b010;
                default: {dr_n_ras, dr_n_cas, dr_n_we} = 3'b111;
            endcase
        end else begin
            {dr_n_ras, dr_n_cas, dr_n_we} = 3'b111;
        end
    end

    always_comb begin
        case (state)
            S_PALL: dr_addr = {2'b0, 1'b1, 10'b0};
            S_PRE: dr_addr = {2'b0, 1'b0, 10'b0};
            S_MRS: dr_addr = MRS;
            S_ACT: dr_addr = (exe == E_WRIT) ? {4'h0, w_y_reg} : {4'h0, r_y};
            S_WRIT: dr_addr = 13'h0;
            S_READ: dr_addr = 13'h0;
            default: dr_addr = 13'h0;
        endcase
    end

    assign dr_ba = 2'h0;

    assign dr_send = (state == S_WRIT);

    // ---- Buffer --------

    bram_dr_buf w_buf_0(        // IP (RAM: 2-PORT, 15bit * 512)
        .clock(clk),
        .wraddress(w_x_reg),
        .data(w_color_reg),
        .wren(w_tgl & ({color_write_reg, color_write} == 3'b011)),
        .rdaddress((state == S_WRIT) ? (ctr + 1) : 0), // 1クロック先に読み出し
        .q(dr_wdata_0)
    );

    bram_dr_buf w_buf_1(        // IP (RAM: 2-PORT, 15bit * 512)
        .clock(clk),
        .wraddress(w_x_reg),
        .data(w_color_reg),
        .wren((~w_tgl) & ({color_write_reg, color_write} == 3'b011)),
        .rdaddress((state == S_WRIT) ? (ctr + 1) : 0), // 1クロック先に読み出し
        .q(dr_wdata_1)
    );

    assign dr_wdata = w_tgl ? {1'b0, dr_wdata_1} : {1'b0, dr_wdata_0};

    bram_dr_buf r_buf_0(        // IP (RAM: 2-PORT, 15bit * 512)
        .clock(clk),
        .wraddress(ctr - CL),
        .data(dr_rdata[14:0]),
        .wren(r_tgl & (state == S_READ)),
        .rdaddress(r_x),
        .q(r_color_0)
    );

    bram_dr_buf r_buf_1(        // IP (RAM: 2-PORT, 15bit * 512)
        .clock(clk),
        .wraddress(ctr - CL),
        .data(dr_rdata[14:0]),        
        .wren((~r_tgl) & (state == S_READ)),
        .rdaddress(r_x),
        .q(r_color_1)
    );

    assign r_color = r_tgl ? r_color_1 : r_color_0;

endmodule
