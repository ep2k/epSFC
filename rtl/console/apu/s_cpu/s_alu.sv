// ==============================
//  ALU in SPC700 CPU
// ==============================

// Copyright(C) 2024 ep2k All Rights Reserved.

module s_alu
    import s_cpu_pkg::*;
(
    input logic [15:0] a,
    input logic [15:0] b,
    input logic c,

    output logic [15:0] y,
    output logic [4:0] flgs,

    input alu_control_type control,
    input logic bit8
);
    
    // ------------------------------
    //  Wires
    // ------------------------------
    
    logic [7:0] y_or, y_and, y_eor, y_clr;
    logic [15:0] y_add, y_adc, y_sub, y_sbc;
    logic [4:0] y_addh, y_adch, y_subh, y_sbch;
    logic [8:0] y_asl, y_rol, y_lsr, y_ror;
    
    // ------------------------------
    //  Main
    // ------------------------------

    assign y_or = a[7:0] | b[7:0];
    assign y_and = a[7:0] & b[7:0];
    assign y_eor = a[7:0] ^ b[7:0];
    assign y_clr = (~a[7:0]) & b[7:0];

    assign y_add = bit8
            ? ({8'h0, a[7:0]} + {8'h0, b[7:0]})
            : (a + b);
    assign y_adc = bit8
            ? ({8'h0, a[7:0]} + {8'h0, b[7:0]} + {15'h0, c})
            : (a + b + {15'h0, c});
    assign y_sub = bit8
            ? ({8'h0, a[7:0]} + {8'h0, ~b[7:0]} + 16'h1)
            : (a + (~b) + 16'h1);
    assign y_sbc = bit8
            ? ({8'h0, a[7:0]} + {8'h0, ~b[7:0]} + {15'h0, c})
            : (a + (~b) + {15'h0, c});
    
    assign y_addh = {1'b0, a[3:0]} + {1'b0, b[3:0]};
    assign y_adch = {1'b0, a[3:0]} + {1'b0, b[3:0]} + {4'h0, c};
    assign y_subh = {1'b0, a[3:0]} + {1'b0, ~b[3:0]} + 5'h1;
    assign y_sbch = {1'b0, a[3:0]} + {1'b0, ~b[3:0]} + {4'h0, c};

    assign y_asl = {a[7:0], 1'b0};
    assign y_rol = {a[7:0], c};
    assign y_lsr = {a[0], 1'b0, a[7:1]};
    assign y_ror = {a[0], c, a[7:1]};

    always_comb begin
        case (control)
            SC_ACTL_OR: y = {8'h0, y_or};
            SC_ACTL_AND: y = {8'h0, y_and};
            SC_ACTL_EOR: y = {8'h0, y_eor};
            SC_ACTL_CLR: y = {8'h0, y_clr};
            SC_ACTL_ADD: y = y_add;
            SC_ACTL_ADC: y = y_adc;
            SC_ACTL_SUB: y = y_sub;
            SC_ACTL_SBC: y = y_sbc;
            SC_ACTL_ASL: y = {7'h0, y_asl};
            SC_ACTL_ROL: y = {7'h0, y_rol};
            SC_ACTL_LSR: y = {7'h0, y_lsr};
            SC_ACTL_ROR: y = {7'h0, y_ror};
            default: y = 'x;
        endcase
    end

    assign flgs[AN] = y[7];
    assign flgs[AZ] = (y[7:0] == 8'h0);
    assign flgs[AC] = y[8];

    always_comb begin
        case (control)
            SC_ACTL_ADD: flgs[AV] = (~(a[7] ^ b[7])) & (a[7] ^ y[7]);
            SC_ACTL_ADC: flgs[AV] = (~(a[7] ^ b[7])) & (a[7] ^ y[7]);
            SC_ACTL_SUB: flgs[AV] = (a[7] ^ b[7]) & (a[7] ^ y[7]);
            SC_ACTL_SBC: flgs[AV] = (a[7] ^ b[7]) & (a[7] ^ y[7]);
            default: flgs[AV] = 1'b0;
        endcase
    end

    always_comb begin
        case (control)
            SC_ACTL_ADD: flgs[AH] = y_addh[4];
            SC_ACTL_ADC: flgs[AH] = y_adch[4];
            SC_ACTL_SUB: flgs[AH] = y_subh[4];
            SC_ACTL_SBC: flgs[AH] = y_sbch[4];
            default: flgs[AH] = 1'b0;
        endcase
    end

endmodule
