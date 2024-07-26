// ==============================
//  APU Package
// ==============================

// Copyright(C) 2024 ep2k All Rights Reserved.

`ifndef APU_PKG_SV
`define APU_PKG_SV

package apu_pkg;

    typedef enum logic [3:0] {
        AT_ARAM,
        AT_IPLROM,

        AT_TEST,
        AT_CONTROL,
        AT_DSPADDR,
        AT_DSPDATA,
        AT_PORT0,
        AT_PORT1,
        AT_PORT2,
        AT_PORT3,
        AT_TIMER0,
        AT_TIMER1,
        AT_TIMER2,
        AT_COUNTER0,
        AT_COUNTER1,
        AT_COUNTER2
    } apu_target_type;

    typedef enum logic [4:0] {
        DT_VOL_L_X,
        DT_VOL_R_X,
        DT_P_L_X,
        DT_P_H_X,
        DT_SRCN_X,
        DT_ADSR_1_X,
        DT_ADSR_2_X,
        DT_GAIN_X,
        DT_ENVX_X,
        DT_OUTX_X,

        DT_MVOL_L,
        DT_MVOL_R,
        DT_EVOL_L,
        DT_EVOL_R,
        DT_KON,
        DT_KOF,
        DT_FLG,
        DT_ENDX,
        DT_EFB,
        DT_UNUSED,
        DT_PMON,
        DT_NON,
        DT_EON,
        DT_DIR,
        DT_ESA,
        DT_EDL,
        DT_COEF_X,

        DT_NONE
    } dsp_target_type;

endpackage

`endif  // APU_PKG_SV
