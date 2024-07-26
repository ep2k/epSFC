// ==============================
//  SDRAM Controller Package
// ==============================

// Copyright(C) 2024 ep2k All Rights Reserved.

`ifndef DR_PKG_SV
`define DR_PKG_SV

package dr_pkg;

    parameter COL_NUM = 512;
    parameter INIREF_TIME = 8;

    parameter CL = 2; // CASレイテンシ

    parameter BOOT0_WAIT = 20000;
    parameter BOOT1_WAIT = 20000;
    parameter PRE_WAIT = 2;
    parameter REF_WAIT = 10;
    parameter MRS_WAIT = 1;
    parameter ACT_WAIT = 1;
    parameter READ_WAIT = CL + COL_NUM - 1;
    parameter WRIT_WAIT = COL_NUM - 1;

    parameter logic [12:0] MRS = 13'b010_0_111;

    typedef enum logic [3:0] {
        S_BOOT0,
        S_BOOT1,
        S_PALL,
        S_REF,
        S_MRS,
        S_IDLE,
        S_ACT,
        S_READ,
        S_WRIT,
        S_PRE
    } state_type;

    typedef enum logic [1:0] {
        E_IDLE,
        E_READ,
        E_WRIT
    } exe_type;

endpackage

`endif  // DR_PKG_SV
