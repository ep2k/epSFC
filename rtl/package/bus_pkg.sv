// ==============================
//  Bus-A & Bus-B Package
// ==============================

// Copyright(C) 2024 ep2k All Rights Reserved.

`ifndef BUS_PKG_SV
`define BUS_PKG_SV

package bus_pkg;

    typedef enum logic [1:0] {
        MEM_FAST,
        MEM_SLOW,
        MEM_XSLOW,
        MEM_VAR
    } mem_speed_type;

    typedef enum logic [2:0] {
        A_RT_CART,
        A_RT_WRAM,
        A_RT_JOY,
        A_RT_HV,
        A_RT_MD,
        A_RT_DMA
    } a_read_target_type;

    typedef enum logic [5:0] {
        A_JOYWR,
        A_NMITIMEN,
        A_WRIO,
        A_WRMPYA,
        A_WRMPYB,
        A_WRDIVL,
        A_WRDIVH,
        A_WRDIVB,
        A_HTIMEL,
        A_HTIMEH,
        A_VTIMEL,
        A_VTIMEH,
        A_MDMAEN,
        A_HDMAEN,
        A_MEMSEL,
        A_DMAPX_W,
        A_BBADX_W,
        A_A1TXL_W,
        A_A1TXH_W,
        A_A1BX_W,
        A_DASXL_W,
        A_DASXH_W,
        A_DASXB_W,
        A_A2AXL_W,
        A_A2AXH_W,
        A_NTRLX_W,
        A_UNUSEDX_W,

        A_JOYA,
        A_JOYB,
        A_RDNMI,
        A_TIMEUP,
        A_HVBJOY,
        A_RDIO,
        A_RDDIVL,
        A_RDDIVH,
        A_RDMPYL,
        A_RDMPYH,
        A_JOY1L,
        A_JOY1H,
        A_JOY2L,
        A_JOY2H,
        A_JOY3L,
        A_JOY3H,
        A_JOY4L,
        A_JOY4H,
        A_DMAPX_R,
        A_BBADX_R,
        A_A1TXL_R,
        A_A1TXH_R,
        A_A1BX_R,
        A_DASXL_R,
        A_DASXH_R,
        A_DASXB_R,
        A_A2AXL_R,
        A_A2AXH_R,
        A_NTRLX_R,
        A_UNUSEDX_R,

        A_NONE
    } a_op_type;

    typedef enum logic [1:0] {
        B_RT_CART,
        B_RT_PPU,
        B_RT_APU,
        B_RT_WRAM
    } b_read_target_type;

    typedef enum logic [6:0] {
        B_INDISP,
        B_OBSEL,
        B_OAMADDL,
        B_OAMADDH,
        B_OAMDATA,
        B_BGMODE,
        B_MOSAIC,
        B_BG1SC,
        B_BG2SC,
        B_BG3SC,
        B_BG4SC,
        B_BG12NBA,
        B_BG34NBA,
        B_BG1HOFS,
        B_BG1VOFS,
        B_BG2HOFS,
        B_BG2VOFS,
        B_BG3HOFS,
        B_BG3VOFS,
        B_BG4HOFS,
        B_BG4VOFS,
        B_VMAIN,
        B_VMADDL,
        B_VMADDH,
        B_VMDATAL,
        B_VMDATAH,
        B_M7SEL,
        B_M7A,
        B_M7B,
        B_M7C,
        B_M7D,
        B_M7X,
        B_M7Y,
        B_CGADD,
        B_CGDATA,
        B_W12SEL,
        B_W34SEL,
        B_WOBJSEL,
        B_WH0,
        B_WH1,
        B_WH2,
        B_WH3,
        B_WBGLOG,
        B_WOBJLOG,
        B_TM,
        B_TS,
        B_TMW,
        B_TSW,
        B_CGWSEL,
        B_CGADSUB,
        B_COLDATA,
        B_SETINI,

        B_APUIO0_W,
        B_APUIO1_W,
        B_APUIO2_W,
        B_APUIO3_W,

        B_WMDATA_W,
        B_WMADDL,
        B_WMADDM,
        B_WMADDH,

        B_MPYL,
        B_MPYM,
        B_MPYH,
        B_SLHV,
        B_RDOAM,
        B_RDVRAML,
        B_RDVRAMH,
        B_RDCGRAM,
        B_OPHCT,
        B_OPVCT,
        B_STAT77,
        B_STAT78,

        B_APUIO0_R,
        B_APUIO1_R,
        B_APUIO2_R,
        B_APUIO3_R,

        B_WMDATA_R,

        B_NONE
    } b_op_type;

endpackage

`endif  // BUS_PKG_SV
