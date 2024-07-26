// ===================================
//  IPL (Initial Program Loader) ROM
// ===================================

// Copyright(C) 2024 ep2k All Rights Reserved.

module ipl_rom (
    input logic [5:0] address,
    output logic [7:0] q
);

    always_comb begin
        unique case (address)
            6'h00: q = 8'hcd; // mov x,EF
            6'h01: q = 8'hef;
            6'h02: q = 8'hbd; // mov sp,x
            6'h03: q = 8'he8; // mov a,00
            6'h04: q = 8'h00;
            6'h05: q = 8'hc6; // mov [x],a
            6'h06: q = 8'h1d; // dec x
            6'h07: q = 8'hd0; // jnz FC (-2)
            6'h08: q = 8'hfc;
            6'h09: q = 8'h8f; // mov [F4],AA
            6'h0a: q = 8'haa;
            6'h0b: q = 8'hf4;
            6'h0c: q = 8'h8f; // mov [F5],BB
            6'h0d: q = 8'hbb;
            6'h0e: q = 8'hf5;
            6'h0f: q = 8'h78; // cmp [F4],CC
            6'h10: q = 8'hcc;
            6'h11: q = 8'hf4;
            6'h12: q = 8'hd0; // jnz FB (-3)
            6'h13: q = 8'hfb;
            6'h14: q = 8'h2f; // bra 19 (goto 2F)
            6'h15: q = 8'h19;
            6'h16: q = 8'heb; // mov y,[F4]
            6'h17: q = 8'hf4;
            6'h18: q = 8'hd0; // jnz FC (-2)
            6'h19: q = 8'hfc;
            6'h1a: q = 8'h7e; // cmp y,[F4]
            6'h1b: q = 8'hf4;
            6'h1c: q = 8'hd0; // jnz 0B (goto 29)
            6'h1d: q = 8'h0b;
            6'h1e: q = 8'he4; // mov a,[F5]
            6'h1f: q = 8'hf5;
            6'h20: q = 8'hcb; // mov [F4],y
            6'h21: q = 8'hf4;
            6'h22: q = 8'hd7; // mov [[00]+y],a
            6'h23: q = 8'h00;
            6'h24: q = 8'hfc; // inc y
            6'h25: q = 8'hd0; // jnz F3 (goto 1a)
            6'h26: q = 8'hf3;
            6'h27: q = 8'hab; // inc [01]
            6'h28: q = 8'h01;
            6'h29: q = 8'h10; // bpl EF (goto 1a)
            6'h2a: q = 8'hef;
            6'h2b: q = 8'h7e; // cmp y,[F4]
            6'h2c: q = 8'hf4;
            6'h2d: q = 8'h10; // bpl EB (goto 1a)
            6'h2e: q = 8'heb;
            6'h2f: q = 8'hba; // movw ya,[F6]
            6'h30: q = 8'hf6;
            6'h31: q = 8'hda; // movw[00],ya
            6'h32: q = 8'h00;
            6'h33: q = 8'hba; // movw [ya],F4
            6'h34: q = 8'hf4;
            6'h35: q = 8'hc4; // mov [F4],a
            6'h36: q = 8'hf4;
            6'h37: q = 8'hdd; // mov a,y
            6'h38: q = 8'h5d; // mov x,a
            6'h39: q = 8'hd0; // jnz DB (goto 16)
            6'h3a: q = 8'hdb;
            6'h3b: q = 8'h1f; // jmp [0000+x]
            6'h3c: q = 8'h00;
            6'h3d: q = 8'h00;
            6'h3e: q = 8'hc0; // FFCO (reset vector)
            6'h3f: q = 8'hff;
        endcase
    end
    
endmodule
