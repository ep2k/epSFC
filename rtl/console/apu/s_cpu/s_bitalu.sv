// ==============================
//  1bit ALU in SPC700 CPU
// ==============================

// Copyright(C) 2024 ep2k All Rights Reserved.

module s_bitalu
    import s_cpu_pkg::*;
(
    input logic [7:0] a,
    input logic [2:0] b,
    input logic c,

    output logic [7:0] y,
    output logic cout,

    input bitalu_control_type control
);

    always_comb begin
        y = a;
        case (control)
            SC_BACTL_SET1: y[b] = 1'b1;
            SC_BACTL_CLR1: y[b] = 1'b0;
            SC_BACTL_NOT1: y[b] = ~a[b];
            SC_BACTL_MOV1_C: y[b] = c;
            default: y = 8'h0;
        endcase
    end

    always_comb begin
        case (control)
            SC_BACTL_AND1_C: cout = c & a[b];
            SC_BACTL_AND1_N_C: cout = c & (~a[b]);
            SC_BACTL_OR1_C: cout = c | a[b];
            SC_BACTL_OR1_N_C: cout = c | (~a[b]);
            SC_BACTL_EOR1_C: cout = c ^ a[b];
            SC_BACTL_MOV1_C: cout = a[b];
            default: cout = 1'b0;
        endcase
    end
    
endmodule
