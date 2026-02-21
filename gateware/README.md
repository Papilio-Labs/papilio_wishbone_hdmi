# Gateware for papilio_wishbone_hdmi

This folder contains the HDL gateware sources for the `papilio_wishbone_hdmi` library. All files are at the top level (flat structure per Papilio Library Standards).

## Modular Video Architecture

The HDMI gateware uses a **modular architecture** — include only the video modes you need. The canonical top-level is `video_top_modular.v` which supports all modes with runtime switching via Wishbone.

## File Listing

### Core Components (Always Required)

| File | Description |
|------|-------------|
| `hdmi_phy_720p.v` | Shared HDMI physical layer: PLL, timing, TMDS, serializers |
| `tmds_encoder.v` | Open-source TMDS 8b/10b encoder with DC balance |
| `TMDS_rPLL.v` | PLL wrapper: 27MHz → 371.25MHz serial clock, 74.25MHz pixel clock |
| `TMDS_rPLL_200.v` | PLL variant for 200MHz operation |
| `TMDS_rPLL_250.v` | PLL variant for 250MHz operation |
| `simple_hdmi_tx.v` | Simple HDMI transmitter module |
| `hdmi_timing.v` | HDMI timing generator |

### Video Mode Modules (Pick & Choose)

| File | Description | BRAM |
|------|-------------|------|
| `wb_video_testpattern.v` | Test patterns: color bars, grid, grayscale | None |
| `wb_video_text.v` | 80x26 text mode, 16 colors, cursor, auto-advance | ~10KB |
| `wb_video_framebuffer.v` | 160x120 RGB332 → 720p with 6× scaling | ~20KB |

### Support Modules

| File | Description |
|------|-------------|
| `char_ram_8x8.v` | 8×8 character font ROM (VGA-style) |
| `char_ram_dpb.v` | Dual-port BRAM for character RAM |
| `color_bar_generator.v` | Color bar pattern generator |
| `framebuffer_ram.v` | Framebuffer BRAM primitive |
| `gowin_rpll.v` | Gowin rPLL primitive wrapper |
| `testpattern.v` | Legacy test pattern module |
| `wb_address_decoder.v` | Wishbone address decoder helper |
| `wb_char_ram.v` | Wishbone wrapper for character RAM |
| `wb_hdmi_colorbar.v` | Wishbone wrapper for color bar |
| `wb_text_mode.v` | Wishbone wrapper for text mode |
| `wb_video_ctrl.v` | Wishbone video controller (legacy) |

### Canonical Top-Level

| File | Description |
|------|-------------|
| `video_top_modular.v` | **Canonical top**: all video modes, Wishbone interface, 16-bit address space |

### Constraint Files

| File | Board |
|------|-------|
| `constraints/hdmi_papilio_retrocade.cst` | Papilio Retrocade (GW2A-18C) |

### Archived Modules (`archive/`)

Non-canonical top-level variants moved to archive for reference only:

| File | Notes |
|------|-------|
| `video_top.v` | Original single-mode top |
| `video_top_800x600.v` | 800×600 variant (not maintained) |
| `video_top_combined.v` | Combined variant using Gowin DVI IP |
| `video_top_framebuffer.v` | Framebuffer-only variant |
| `video_top_hqvga.v` | HQVGA (240×160) variant |
| `video_top_testpattern_only.v` | Minimal test-pattern-only variant |
| `video_top_wb.v` | Older Wishbone variant |
| `dvi_tx.v` | Gowin encrypted DVI IP (proprietary, not open-source) |
| `dvi_tx.ipc` | Gowin IP configuration |
| `dvi_tx.vo` | Gowin encrypted netlist |

## Key Features

- **Open-Source TMDS**: No proprietary Gowin IP required for `video_top_modular.v`
- **720p Output**: 1280×720 @ 60Hz
- **Wishbone Interface**: 16-bit address space, 8-bit data
- **Gowin Primitives**: Uses rPLL, CLKDIV, OSER10, ELVDS_OBUF (standard Gowin primitives, not encrypted IP)

## Clock Requirements

- **Input**: 27MHz reference clock (`I_clk`)
- **Generated**: 74.25MHz pixel clock, 371.25MHz serial clock (via rPLL)

## Complete Register Map (video_top_modular.v)

### Mode Control (0x0000–0x000F)

| Address | Register | Access | Description |
|---------|----------|--------|-------------|
| 0x0000 | VIDEO_MODE | R/W | Video mode: `0`=test-pattern, `1`=text, `2`=framebuffer |

### Test Pattern (0x0010–0x001F)

| Address | Register | Access | Description |
|---------|----------|--------|-------------|
| 0x0010 | TP_PATTERN | R/W | Pattern: `0`=color bars, `1`=grid, `2`=grayscale |
| 0x0011 | TP_STATUS | R | Version/status byte |

### Text Mode (0x0020–0x00FF)

| Address | Register | Access | Description |
|---------|----------|--------|-------------|
| 0x0020 | TEXT_CONTROL | R/W | Bit 0: clear screen, Bit 1: cursor enable |
| 0x0021 | TEXT_CURSOR_X | R/W | Cursor X position (0–79) |
| 0x0022 | TEXT_CURSOR_Y | R/W | Cursor Y position (0–29) |
| 0x0023 | TEXT_ATTR | R/W | Attribute: `[7:4]`=bg color, `[3:0]`=fg color |
| 0x0024 | TEXT_CHAR | W | Write character at cursor (auto-advance) |
| 0x0025 | TEXT_ATTR_WR | W | Write attribute at cursor |
| 0x0026 | TEXT_ADDR_HI | R/W | High byte of direct RAM address |
| 0x0027 | TEXT_ADDR_LO | R/W | Low byte of direct RAM address |
| 0x0028 | TEXT_DATA_WR | W | Write char data to RAM address |
| 0x0029 | TEXT_ATTR_DATA | W | Write attr data to RAM address |
| 0x002A | TEXT_FONT_ADDR | W | Custom font address (0–63) |
| 0x002B | TEXT_FONT_DATA | W | Custom font data byte |

### Framebuffer (0x0100–0x7FFF)

| Address | Description |
|---------|-------------|
| 0x0100–0x7FFF | Pixel data: 160×120 RGB332, row-major |

## Text Color Values (4-bit)

| Value | Color | Value | Color |
|-------|-------|-------|-------|
| 0x0 | Black | 0x8 | Dark Gray |
| 0x1 | Blue | 0x9 | Light Blue |
| 0x2 | Green | 0xA | Light Green |
| 0x3 | Cyan | 0xB | Light Cyan |
| 0x4 | Red | 0xC | Light Red |
| 0x5 | Magenta | 0xD | Light Magenta |
| 0x6 | Brown | 0xE | Yellow |
| 0x7 | Light Gray | 0xF | White |

## Wishbone Interface (video_top_modular.v)

```verilog
module video_top_modular (
    input         I_clk,       // 27MHz system clock
    input         I_rst_n,     // Active-low reset
    input         I_wb_clk,    // Wishbone clock
    input  [15:0] I_wb_adr,    // 16-bit Wishbone address
    input  [7:0]  I_wb_dat,    // Wishbone data input
    input         I_wb_we,     // Write enable
    input         I_wb_stb,    // Wishbone strobe
    input         I_wb_cyc,    // Wishbone cycle
    output reg    O_wb_ack,    // Wishbone acknowledge
    output reg [7:0] O_wb_dat, // Wishbone data output
    output        O_tmds_clk_p,
    output        O_tmds_clk_n,
    output [2:0]  O_tmds_data_p,  // {red, green, blue}
    output [2:0]  O_tmds_data_n
);
```

## Constraint Files

### Papilio Retrocade (`constraints/hdmi_papilio_retrocade.cst`)

Board: Papilio Retrocade (GW2A-18C), FPGA Bank 1 (1.8V)

```
IO_LOC "O_tmds_clk_p"     P6,T6;    IO_PORT ... IO_TYPE=LVCMOS18D
IO_LOC "O_tmds_data_p[0]" M6,T8;    IO_PORT ... IO_TYPE=LVCMOS18D  (Blue)
IO_LOC "O_tmds_data_p[1]" T11,P11;  IO_PORT ... IO_TYPE=LVCMOS18D  (Green)
IO_LOC "O_tmds_data_p[2]" T12,R11;  IO_PORT ... IO_TYPE=LVCMOS18D  (Red)
```

## Simulation

Testbenches are in `../tests/sim/`. Run with:
```bash
python ../tests/sim/run_all_sims.py
```
