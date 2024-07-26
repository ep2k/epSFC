// ==============================
//  Echo Controller
// ==============================

// Copyright(C) 2024 ep2k All Rights Reserved.

module echo (
    input logic clk,
    input logic cpu_en,
    input logic [3:0] clk_step,
    input logic reset,

    input logic [4:0] step,
    input logic exe_32khz,

    input logic [7:0] echo_page,
    input logic signed [7:0] echo_fb,
    input logic [3:0] echo_delay,
    input logic signed [7:0] echo_coef_x[7:0],

    input logic signed [15:0] suml_main,
    input logic signed [15:0] sumr_main,

    output logic [15:0] aram_addr_0,
    input logic [7:0] aram_rdata_0,
    output logic [7:0] aram_wdata_0,
    output logic [15:0] aram_addr_1,
    input logic [7:0] aram_rdata_1,
    output logic [7:0] aram_wdata_1,

    output logic signed [15:0] echo_l,
    output logic signed [15:0] echo_r
);
    
    // ------------------------------
    //  Wires
    // ------------------------------
    
    logic signed [15:0] mul_a;
    logic signed [7:0] mul_b;
    logic signed [22:0] mul_y;

    logic signed [15:0] suml, sumr;
    
    logic signed [15:0] suml_x_efb, sumr_x_efb;
    logic signed [15:0] ram_in_l, ram_in_r;

    logic [12:0] ram_size;

    // ------------------------------
    //  Registers
    // ------------------------------
    
    logic signed [14:0] firbuf_l[7:0];
    logic signed [14:0] firbuf_r[7:0];

    logic signed [18:0] suml_raw, sumr_raw;

    logic signed [22:0] suml_x_efb_raw, sumr_x_efb_raw;

    logic [3:0] echo_delay_reg = 4'h0;
    logic [12:0] ram_index = 13'h0;

    // ------------------------------
    //  Main
    // ------------------------------

    // ---- ARAM Access --------

    assign aram_addr_0 = {echo_page, 8'h0} + {1'b0, ram_index, step[0], 1'b0};
    assign aram_addr_1 = {echo_page, 8'h0} + {1'b0, ram_index, step[0], 1'b1};

    assign aram_wdata_0 = step[0] ? {ram_in_r[7:1], 1'b0} : {ram_in_l[7:1], 1'b0};
    assign aram_wdata_1 = step[0] ? ram_in_r[15:8] : ram_in_l[15:8];

    // ---- FIR Buffer --------

    // fir_buf
    always_ff @(posedge clk) begin
        if (reset) begin
            for (int i = 0; i < 8; i++) begin
                firbuf_l[i] <= 15'h0;
                firbuf_r[i] <= 15'h0;
            end
        end else if (cpu_en) begin
            if (step == 5'd24) begin
                firbuf_l[0][6:0] <= aram_rdata_0[7:1];
                firbuf_l[0][14:7] <= aram_rdata_1;
            end else if (step == 5'd25) begin
                firbuf_r[0][6:0] <= aram_rdata_0[7:1];
                firbuf_r[0][14:7] <= aram_rdata_1;
            end else if (exe_32khz) begin
                for (int i = 1; i < 8; i++) begin
                    firbuf_l[i] <= firbuf_l[i-1];
                    firbuf_r[i] <= firbuf_r[i-1];
                end
            end
        end
    end

    // ---- Multiplier --------

    // mul_a, mul_b
    always_comb begin
        case (step)
            5'd26: begin
                mul_a = {firbuf_l[clk_step[2:0]][14], firbuf_l[clk_step[2:0]]};
                mul_b = echo_coef_x[~clk_step[2:0]];
            end
            5'd27: begin
                mul_a = {firbuf_r[clk_step[2:0]][14], firbuf_r[clk_step[2:0]]};
                mul_b = echo_coef_x[~clk_step[2:0]];
            end
            5'd28: begin
                mul_a = suml;
                mul_b = echo_fb;
            end
            5'd29: begin
                mul_a = sumr;
                mul_b = echo_fb;
            end
            default: {mul_a, mul_b} = 0;
        endcase
    end

    assign mul_y = $signed(mul_a) * $signed(mul_b);

    // ---- FIR Calculation --------

    // suml/r_rawは複数クロックかけて乗算, 加算を行う

    always_ff @(posedge clk) begin
        if (reset) begin
            suml_raw <= 19'h0;
        end else if ((step == 5'd26) & (~clk_step[3])) begin
            suml_raw <= suml_raw + {{2{mul_y[22]}}, mul_y[22:6]};
        end else if (cpu_en & exe_32khz) begin
            suml_raw <= 19'h0;
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            sumr_raw <= 19'h0;
        end else if ((step == 5'd27) & (~clk_step[3])) begin
            sumr_raw <= sumr_raw + {{2{mul_y[22]}}, mul_y[22:6]};
        end else if (cpu_en & exe_32khz) begin
            sumr_raw <= 19'h0;
        end
    end

    // overflow handling
    always_comb begin
        if ((~suml_raw[18]) & (suml_raw[17:15] != 3'b000)) begin
            suml = 16'h7fff;
        end else if (suml_raw[18] & (suml_raw[17:15] != 3'b111)) begin
            suml = 16'h8000;
        end else begin
            suml = suml_raw[15:0];
        end
    end
    always_comb begin
        if ((~sumr_raw[18]) & (sumr_raw[17:15] != 3'b000)) begin
            sumr = 16'h7fff;
        end else if (sumr_raw[18] & (sumr_raw[17:15] != 3'b111)) begin
            sumr = 16'h8000;
        end else begin
            sumr = sumr_raw[15:0];
        end
    end

    // echo_l/r (Output)
    always_ff @(posedge clk) begin
        if (reset) begin
            echo_l <= 16'h0;
            echo_r <= 16'h0;
        end else if (cpu_en & exe_32khz) begin
            echo_l <= suml;
            echo_r <= sumr;
        end
    end

    // ---- Echo Feedback --------

    always_ff @(posedge clk) begin
        if (reset) begin
            suml_x_efb_raw <= 23'h0;
        end else if (cpu_en & (step == 5'd28)) begin
            suml_x_efb_raw <= mul_y;
        end
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            sumr_x_efb_raw <= 23'h0;
        end else if (cpu_en & (step == 5'd29)) begin
            sumr_x_efb_raw <= mul_y;
        end
    end

    assign suml_x_efb = suml_x_efb_raw[22:7];
    assign sumr_x_efb = sumr_x_efb_raw[22:7];

    assign ram_in_l = suml_main + suml_x_efb;
    assign ram_in_r = sumr_main + sumr_x_efb;

    // ---- Echo Delay --------

    always_ff @(posedge clk) begin
        if (reset) begin
            echo_delay_reg <= 4'h0;
        end else if (cpu_en & exe_32khz & (ram_index == ram_size)) begin
            echo_delay_reg <= echo_delay;
        end
    end

    always_comb begin
        unique case (echo_delay_reg)
            4'h0: ram_size = 13'd0;
            4'h1: ram_size = 13'd511;
            4'h2: ram_size = 13'd1023;
            4'h3: ram_size = 13'd1535;
            4'h4: ram_size = 13'd2047;
            4'h5: ram_size = 13'd2559;
            4'h6: ram_size = 13'd3071;
            4'h7: ram_size = 13'd3583;
            4'h8: ram_size = 13'd4095;
            4'h9: ram_size = 13'd4607;
            4'ha: ram_size = 13'd5119;
            4'hb: ram_size = 13'd5631;
            4'hc: ram_size = 13'd6143;
            4'hd: ram_size = 13'd6655;
            4'he: ram_size = 13'd7167;
            4'hf: ram_size = 13'd7679;
        endcase
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            ram_index <= 13'h0;
        end else if (cpu_en & exe_32khz) begin
            ram_index <= (ram_index == ram_size) ? 13'h0 : (ram_index + 13'h1);
        end
    end

endmodule
