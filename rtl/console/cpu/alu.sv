// ==============================
//  ALU in 65816 CPU
// ==============================

// Copyright(C) 2024 ep2k All Rights Reserved.

module alu
    import cpu_pkg::*;
(
    input logic [15:0] a,
    input logic [15:0] b,
    input logic c,

    output logic [15:0] y,
    output logic [3:0] flgs,

    input alu_control_type control,
    input logic bit8,
    input logic bcd
);

    // ------------------------------
    //  Wires
    // ------------------------------
    
    logic [16:0] y17;

    logic [15:0] y_or, y_and, y_eor, y_res; 
    logic [16:0] y_add, y_adc, y_sub, y_sbc;
    logic [16:0] y_asl, y_lsr, y_rol, y_ror;

    logic [8:0] yd_adc, yd_sbc;
    logic [4:0] ydl_adc_raw, ydl_adc, ydh_adc_raw, ydh_adc;
    logic [4:0] ydl_sbc_raw, ydl_sbc, ydh_sbc_raw, ydh_sbc;

    // ------------------------------
    //  Main
    // ------------------------------

    assign y_or = a | b;
    assign y_and = a & b;
    assign y_eor = a ^ b;
    assign y_res = a & (~b);

    assign y_add = bit8
            ? ({9'h0, a[7:0]} + {9'h0, b[7:0]})
            : ({1'b0, a} + {1'b0, b});
    assign y_adc = bit8
            ? ({9'h0, a[7:0]} + {9'h0, b[7:0]} + {16'h0, c})
            : ({1'b0, a} + {1'b0, b} + {16'h0, c});
    assign y_sub = bit8
            ? ({9'h0, a[7:0]} + {9'h0, ~b[7:0]} + 17'h1)
            : ({1'b0, a} + {1'b0, ~b} + 17'h1);
    assign y_sbc = bit8
            ? ({9'h0, a[7:0]} + {9'h0, ~b[7:0]} + {16'h0, c})
            : ({1'b0, a} + {1'b0, ~b} + {16'h0, c});

    assign y_asl = {a, 1'b0};
    assign y_lsr = bit8 ? {8'h0, a[0], 1'b0, a[7:1]} : {a[0], 1'b0, a[15:1]};
    assign y_rol = {a, c};
    assign y_ror = bit8 ? {8'h0, a[0], c, a[7:1]} : {a[0], c, a[15:1]};

    assign ydl_adc_raw = {1'b0, a[3:0]} + {1'b0, b[3:0]} + {4'h0, c};
    assign ydl_adc = (ydl_adc_raw >= 5'ha) ? (ydl_adc_raw + 5'h6) : ydl_adc_raw;
    assign ydh_adc_raw = {1'b0, a[7:4]} + {1'b0, b[7:4]} + {4'h0, ydl_adc[4]};
    assign ydh_adc = (ydh_adc_raw >= 5'ha) ? (ydh_adc_raw + 5'h6) : ydh_adc_raw;
    assign yd_adc = {ydh_adc, ydl_adc[3:0]};

    assign ydl_sbc_raw = {1'b0, a[3:0]} + {1'b0, ~b[3:0]} + {4'h0, c};
    assign ydl_sbc = (~ydl_sbc_raw[4]) ? (ydl_sbc_raw - 5'h6) : ydl_sbc_raw;
    assign ydh_sbc_raw = {1'b0, a[7:4]} + {1'b0, ~b[7:4]} + {4'h0, ydl_sbc[4]};
    assign ydh_sbc = (~ydh_sbc_raw[4]) ? (ydh_sbc_raw - 5'h6) : ydh_sbc_raw;
    assign yd_sbc = {ydh_sbc, ydl_sbc[3:0]};

    always_comb begin
        if (bcd) begin
            case (control)
                C_ACTL_ADC: y17 = {8'h0, yd_adc};
                C_ACTL_SBC: y17 = {8'h0, yd_sbc};
                default: y17 = 17'h0;
            endcase
        end else begin
            case (control)
                C_ACTL_OR : y17 = {1'b0, y_or};
                C_ACTL_AND: y17 = {1'b0, y_and};
                C_ACTL_EOR: y17 = {1'b0, y_eor};
                C_ACTL_BIT: y17 = {1'b0, y_and};
                C_ACTL_ADD: y17 = y_add;
                C_ACTL_ADC: y17 = y_adc;
                C_ACTL_SUB: y17 = y_sub;
                C_ACTL_SBC: y17 = y_sbc;

                C_ACTL_TSB: y17 = {1'b0, y_or};
                C_ACTL_TRB: y17 = {1'b0, y_res};

                C_ACTL_ASL: y17 = y_asl;
                C_ACTL_LSR: y17 = y_lsr;
                C_ACTL_ROL: y17 = y_rol;
                C_ACTL_ROR: y17 = y_ror;

                default: y17 = 17'h0;
            endcase
        end
    end

    assign y = y17[15:0];
    assign flgs[AC] = (bit8 | bcd) ? y17[8] : y17[16];

    always_comb begin
        case (control)
            C_ACTL_BIT: flgs[AN] = bit8 ? b[7] : b[15];
            default: flgs[AN] = (bit8 | bcd) ? y17[7] : y17[15];
        endcase
    end

    always_comb begin
        if (bcd) begin
            case (control)
                C_ACTL_ADC: flgs[AV] = y17[8] | ((~(a[7] ^ b[7])) & (a[7] ^ y17[7]));
                C_ACTL_SBC: flgs[AV] = (a[7] ^ b[7]) & (a[7] ^ y17[7]);
                default: flgs[AV] = 1'b0;
            endcase
        end else if (bit8) begin
            case (control)
                // (aの符号==bの符号) かつ (aの符号!=yの符号)
                C_ACTL_ADC: flgs[AV] = (~(a[7] ^ b[7])) & (a[7] ^ y17[7]);
                // (aの符号!=bの符号) かつ (aの符号!=yの符号)
                C_ACTL_SBC: flgs[AV] = (a[7] ^ b[7]) & (a[7] ^ y17[7]);
                C_ACTL_BIT: flgs[AV] = b[6];
                default: flgs[AV] = 1'b0;
            endcase
        end else begin
            case (control)
                C_ACTL_ADC: flgs[AV] = (~(a[15] ^ b[15])) & (a[15] ^ y17[15]);
                C_ACTL_SBC: flgs[AV] = (a[15] ^ b[15]) & (a[15] ^ y17[15]);
                C_ACTL_BIT: flgs[AV] = b[14];
                default: flgs[AV] = 1'b0;
            endcase
        end
    end

    always_comb begin
        case (control)
            C_ACTL_TSB: flgs[AZ] = bit8 ? (y_and[7:0] == 8'h0) : (y_and == 16'h0);
            C_ACTL_TRB: flgs[AZ] = bit8 ? (y_and[7:0] == 8'h0) : (y_and == 16'h0);
            default: flgs[AZ] = (bit8 | bcd) ? (y[7:0] == 8'h0) : (y == 16'h0);
        endcase
    end

endmodule
