//Copyright (C)2014-2024 Gowin Semiconductor Corporation.
//All rights reserved.
//File Title: IP file
//Tool Version: V1.9.10.03 Education (64-bit)
//Part Number: GW2A-LV18PG256C8/I7
//Device: GW2A-18C
//Created Time: Fri Nov 28 19:50:00 2025

// PLL for 800x600@72Hz HDMI output
// Input: 27MHz
// Output: ~250MHz (serial clock for TMDS, will be divided by 5 for ~50MHz pixel clock)
//
// Gowin rPLL constraints:
//   - VCO must be 500-1250MHz
//   - CLKOUT = VCO / ODIV (ODIV valid: 2,4,8,16,32,48,64,80,96,112,128)
//   - VCO = FCLKIN * FBDIV / IDIV
//
// For ~250MHz output with VCO in valid range:
//   VCO = 500MHz, ODIV = 2 -> CLKOUT = 250MHz
//   VCO = 27 * FBDIV / IDIV = 500MHz
//   27 * FBDIV / IDIV = 500 -> FBDIV/IDIV = 18.52
//   Try: IDIV=1, FBDIV=19 -> VCO = 27*19 = 513MHz (valid!), CLKOUT = 513/2 = 256.5MHz
//   Pixel clock = 256.5/5 = 51.3MHz (close to 50MHz, ~2.6% error)
//
//   Final: IDIV=1 (IDIV_SEL=0), FBDIV=19 (FBDIV_SEL=18), ODIV=2 (ODIV_SEL=2)

module TMDS_rPLL_250 (
    input clkin,     // 27MHz
    output clkout,   // 256.5MHz
    output lock
);

wire clkoutp_o;
wire clkoutd_o;
wire clkoutd3_o;
wire gw_gnd;

assign gw_gnd = 1'b0;

rPLL rpll_inst (
    .CLKOUT(clkout),
    .LOCK(lock),
    .CLKOUTP(clkoutp_o),
    .CLKOUTD(clkoutd_o),
    .CLKOUTD3(clkoutd3_o),
    .RESET(gw_gnd),
    .RESET_P(gw_gnd),
    .CLKIN(clkin),
    .CLKFB(gw_gnd),
    .FBDSEL({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd}),
    .IDSEL({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd}),
    .ODSEL({gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd,gw_gnd}),
    .PSDA({gw_gnd,gw_gnd,gw_gnd,gw_gnd}),
    .DUTYDA({gw_gnd,gw_gnd,gw_gnd,gw_gnd}),
    .FDLY({gw_gnd,gw_gnd,gw_gnd,gw_gnd})
);

defparam rpll_inst.FCLKIN = "27";
defparam rpll_inst.DYN_IDIV_SEL = "false";
defparam rpll_inst.IDIV_SEL = 0;           // IDIV = 1
defparam rpll_inst.DYN_FBDIV_SEL = "false";
defparam rpll_inst.FBDIV_SEL = 18;         // FBDIV = 19 -> VCO = 27*19 = 513MHz
defparam rpll_inst.DYN_ODIV_SEL = "false";
defparam rpll_inst.ODIV_SEL = 2;           // ODIV = 2 -> CLKOUT = 513/2 = 256.5MHz
defparam rpll_inst.PSDA_SEL = "0000";
defparam rpll_inst.DYN_DA_EN = "true";
defparam rpll_inst.DUTYDA_SEL = "1000";
defparam rpll_inst.CLKOUT_FT_DIR = 1'b1;
defparam rpll_inst.CLKOUTP_FT_DIR = 1'b1;
defparam rpll_inst.CLKOUT_DLY_STEP = 0;
defparam rpll_inst.CLKOUTP_DLY_STEP = 0;
defparam rpll_inst.CLKFB_SEL = "internal";
defparam rpll_inst.CLKOUT_BYPASS = "false";
defparam rpll_inst.CLKOUTP_BYPASS = "false";
defparam rpll_inst.CLKOUTD_BYPASS = "false";
defparam rpll_inst.DYN_SDIV_SEL = 2;
defparam rpll_inst.CLKOUTD_SRC = "CLKOUT";
defparam rpll_inst.CLKOUTD3_SRC = "CLKOUT";
defparam rpll_inst.DEVICE = "GW2A-18C";

endmodule
