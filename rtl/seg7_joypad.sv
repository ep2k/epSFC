// ========================================
//  Seven Segment Decoder for SFC Joypad
// ========================================

// Copyright(C) 2024 ep2k All Rights Reserved.

module seg7_joypad (
    input  logic [11:0] joypad,
    input  logic no_push_pwm,
    output logic [6:0] dout_l,
    output logic [6:0] dout_r
);

    assign dout_l = ~{
        joypad[7] | no_push_pwm,    // Up
        joypad[1] | no_push_pwm,    // L
        joypad[5] | no_push_pwm,    // Left
        joypad[6] | no_push_pwm,    // Down
        joypad[4] | no_push_pwm,    // Right
        joypad[9] | no_push_pwm,    // Select
        1'b0
    };

    assign dout_r = ~{
        joypad[2] | no_push_pwm,    // X
        joypad[8] | no_push_pwm,    // Start
        joypad[10] | no_push_pwm,   // Y
        joypad[11] | no_push_pwm,   // B
        joypad[3] | no_push_pwm,    // A
        joypad[0] | no_push_pwm,    // R
        1'b0
    };
    
endmodule
