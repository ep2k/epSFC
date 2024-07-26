// ==============================
//  PCM Interpolation
// ==============================

// Copyright(C) 2024 ep2k All Rights Reserved.

module interpolate (
    input logic clk,
    input logic cpu_en,
    input logic reset,

    input logic [4:0] step,
    input logic exe_32khz,

    input logic [1:0] sel,  // 00: Gaussian, 01: Linear, 10: No Interpolation

    input logic [14:0] pcm_x_y[7:0][3:0],
    input logic [7:0] index_x[7:0],
    output logic [14:0] out_x[7:0]
);

    // ------------------------------
    //  Wires
    // ------------------------------
    
    logic [14:0] mul_a;
    logic [10:0] mul_b;
    logic [25:0] mul_y;

    logic [8:0] gauss_addr;
    logic [10:0] gauss;

    logic [15:0] gauss_out_raw;
    logic [14:0] gauss_out;
    
    logic [22:0] lerp_out_raw;
    logic [14:0] lerp_out;

    // ------------------------------
    //  Registers
    // ------------------------------
    
    logic [14:0] out_x_temp[7:0];

    logic [25:0] gauss_out_x[3:0];
    logic [22:0] lerp_out_x[1:0];

    // ------------------------------
    //  Main
    // ------------------------------    

    // ---- Output (out_x) --------

    // 全8chの計算を逐次的に繰り返し行い，out_x_tempに格納
    always_ff @(posedge clk) begin
        if (reset) begin
            for (int i = 0; i < 8; i++) begin
                out_x_temp[i] <= 15'h0;
            end
        end else begin
            case (sel)
                2'b01: out_x_temp[step[4:2]] <= lerp_out;
                2'b10: out_x_temp[step[4:2]] <= pcm_x_y[step[4:2]][1];
                default: out_x_temp[step[4:2]] <= gauss_out;
            endcase
        end
    end

    // 32kHzごとにout_x_tempをout_xに適用
    always_ff @(posedge clk) begin
        if (reset) begin
            for (int i = 0; i < 8; i++) begin
                out_x[i] <= 15'h0;
            end
        end
        if (cpu_en & exe_32khz) begin
            out_x <= out_x_temp;
        end
    end

    // ---- Multiplier --------

    always_comb begin
        case (sel)
            2'b01: begin // Linear
                mul_a = step[1]
                    ? pcm_x_y[step[4:2]][2]
                    : pcm_x_y[step[4:2]][1];
                mul_b = step[1]
                    ? {1'b0, index_x[step[4:2]]}
                    : ({1'b0, ~index_x[step[4:2]]} + 9'h1);
            end
            default: begin // Gaussian (or None)
                mul_a = pcm_x_y[step[4:2]][step[1:0]];
                mul_b = gauss;
            end
        endcase
    end

    assign mul_y = $signed(mul_a) * {1'b0, mul_b};

    // ---- Gaussian Interpolation --------

    always_comb begin
        unique case (step[1:0])
            2'b00: gauss_addr = {1'b0, ~index_x[step[4:2]]}; 
            2'b01: gauss_addr = {1'b1, ~index_x[step[4:2]]}; 
            2'b10: gauss_addr = {1'b1, index_x[step[4:2]]}; 
            2'b11: gauss_addr = {1'b0, index_x[step[4:2]]}; 
        endcase
    end

    bram_gauss_table_rom bram_gauss_table_rom(      // IP (ROM: 1-PORT, 11bit * 512)
        .address(gauss_addr),                       // rom/system/gauss_table_rom.mif
        .clock(clk),
        .q(gauss)
    );

    always_ff @(posedge clk) begin
        if (reset) begin
            for (int i = 0; i < 4; i++) begin
                gauss_out_x[i] <= 26'h0;
            end
        end else begin
            gauss_out_x[step[1:0]] <= mul_y;
        end
    end

    always_comb begin
        gauss_out_raw = 16'h0;
        for (int i = 0; i < 4; i++) begin
            gauss_out_raw += gauss_out_x[i][25:10];
        end
    end

    assign gauss_out = gauss_out_raw[15:1];


    // ---- Linear Interpolation --------

    always_ff @(posedge clk) begin
        if (reset) begin
            for (int i = 0; i < 2; i++) begin
                lerp_out_x[i] <= 23'h0;
            end
        end else begin
            lerp_out_x[step[1]] <= mul_y[22:0];
        end
    end

    always_comb begin
        lerp_out_raw = 23'h0;
        for (int i = 0; i < 2; i++) begin
            lerp_out_raw += lerp_out_x[i];
        end
    end

    assign lerp_out = lerp_out_raw[22:8];
    
endmodule
