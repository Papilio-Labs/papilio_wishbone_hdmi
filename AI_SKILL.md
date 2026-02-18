# AI_SKILL.md — papilio_wishbone_hdmi

> **Scope:** Library-specific guidance only.
> For general Papilio/Wishbone patterns, see `papilio_dev_tools/AI_SKILL.md`.

## Library Purpose

`papilio_wishbone_hdmi` provides HDMI 720p video output for Papilio FPGA boards via a Wishbone-over-SPI interface. It supports:
- **Test patterns**: color bars, grid, grayscale
- **Text mode**: 80×30 character display, 16 fg/bg colors, 8×8 VGA font
- **Framebuffer**: 160×120 RGB332 scaled to 720p with 6× nearest-neighbor scaling
- **CLI plugin**: `hdmi` command group via `papilio_os`

All three video modes are selectable at runtime via a single Wishbone register.

---

## Architecture Overview

### Open-Source TMDS Path (Recommended)

```
ESP32 (SPI) -> WishboneSPI -> [video_top_modular] -> HDMI TMDS output
```

The canonical top-level is `video_top_modular.v`. It uses:
- `hdmi_phy_720p.v` — shared PHY (PLL, timing, TMDS encoder, ELVDS serializers)
- `tmds_encoder.v` — open-source 8b/10b encoder
- `TMDS_rPLL.v` — rPLL clock multiplier (27MHz → 74.25MHz pixel, 371.25MHz serial)
- `wb_video_testpattern.v` / `wb_video_text.v` / `wb_video_framebuffer.v` — video mode slaves

**No Gowin DVI IP required.** The archived `video_top_combined.v` (and `dvi_tx.v`) used the encrypted Gowin DVI IP but it is no longer the recommended path.

### Class Hierarchy

```
PapilioHdmi          (new - standard facade, Papilio<Name> compliant)
  └─ HDMIController  (existing - full-featured, backward-compatible)

HDMILiquidCrystal    (LCD-compatible print/cursor API, wraps HDMIController)
VGALiquidCrystal     (VGA framebuffer LCD adapter)
HQVGA                (240x160 HQVGA high-level framebuffer API)
  ├─ HQVGA_GFX       (Adafruit GFX adapter for HQVGA)
  ├─ HQVGA_TFT_eSPI  (TFT_eSPI adapter for HQVGA)
  ├─ HQVGA_U8g2      (U8g2 adapter for HQVGA)
  └─ HQVGA_LVGL      (LVGL display driver for HQVGA)
```

New code should use `PapilioHdmi`. Existing code using `HDMIController` directly continues to work unchanged.

---

## Complete Register Map

### Address Space: 0x0000 – 0x7FFF (16-bit addressing)

#### Mode Control (0x0000–0x000F)

| Address | Name | Access | Default | Description |
|---------|------|--------|---------|-------------|
| 0x0000 | VIDEO_MODE | R/W | 0 | `0`=test-pattern, `1`=text, `2`=framebuffer |

#### Test Pattern (0x0010–0x001F)

| Address | Name | Access | Default | Description |
|---------|------|--------|---------|-------------|
| 0x0010 | TP_PATTERN | R/W | 0 | `0`=color bars, `1`=grid, `2`=grayscale |
| 0x0011 | TP_STATUS | R | 0x02 | Gateware version (0x02 = supports text mode) |

#### Text Mode (0x0020–0x00FF)

| Address | Name | Access | Default | Description |
|---------|------|--------|---------|-------------|
| 0x0020 | TEXT_CONTROL | R/W | 0x00 | Bit 0: clear screen, Bit 1: cursor enable |
| 0x0021 | TEXT_CURSOR_X | R/W | 0 | Cursor X (0–79) |
| 0x0022 | TEXT_CURSOR_Y | R/W | 0 | Cursor Y (0–29) |
| 0x0023 | TEXT_ATTR | R/W | 0x07 | `[7:4]`=bg color, `[3:0]`=fg color |
| 0x0024 | TEXT_CHAR | W | — | Write char at cursor (auto-advance cursor) |
| 0x0025 | TEXT_ATTR_WR | W | — | Write attribute at cursor |
| 0x0026 | TEXT_ADDR_HI | R/W | 0 | Direct RAM access address high byte |
| 0x0027 | TEXT_ADDR_LO | R/W | 0 | Direct RAM access address low byte |
| 0x0028 | TEXT_DATA_WR | W | — | Write char data at direct address |
| 0x0029 | TEXT_ATTR_DATA | W | — | Write attr data at direct address |
| 0x002A | TEXT_FONT_ADDR | W | — | Custom font slot address (0–63) |
| 0x002B | TEXT_FONT_DATA | W | — | Custom font data byte |

#### Framebuffer (0x0100–0x7FFF)

| Address | Description |
|---------|-------------|
| 0x0100 + y*160 + x | Pixel at (x, y); format: RGB332 `[7:5]=R, [4:2]=G, [1:0]=B` |

#### RGB LED (0x8100–0x8103, via HDMIController)

| Address | Name | Access | Description |
|---------|------|--------|-------------|
| 0x8100 | REG_LED_GREEN | W | Green component (0–255) |
| 0x8101 | REG_LED_RED | W | Red component (0–255) |
| 0x8102 | REG_LED_BLUE | W | Blue component (0–255) |
| 0x8103 | REG_LED_CTRL | R | Bit 0: busy |

---

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

---

## Common Operations

### Firmware API (PapilioHdmi)

```cpp
// Initialize (SPI must be set up before begin())
PapilioHdmi hdmi;
hdmi.begin();

// Test patterns
hdmi.setPattern(0);        // color bars
hdmi.setPattern(1);        // grid
hdmi.setPattern(2);        // grayscale

// Text mode
hdmi.enableTextMode();
hdmi.clearScreen();
hdmi.setTextColor(HDMI_COLOR_WHITE, HDMI_COLOR_BLACK);
hdmi.setCursor(0, 0);
hdmi.println("Hello, Papilio!");

// Status
uint8_t mode = hdmi.getVideoMode();  // 0=test, 1=text, 2=fb
```

### Legacy API (HDMIController – unchanged)

```cpp
HDMIController hdmi;
hdmi.begin();
hdmi.setVideoPattern(1);   // grid
hdmi.enableTextMode();
hdmi.clearScreen();
hdmi.writeString("Hello!");
```

### CLI Commands (when ENABLE_PAPILIO_OS defined)

```
hdmi status              - Show mode, resolution, cursor position
hdmi pattern 0           - Color bars
hdmi pattern 1           - Grid
hdmi pattern 2           - Grayscale
hdmi pattern 3           - Text mode (alias for enableTextMode)
hdmi text <message>      - Write text (auto-enables text mode)
hdmi clear               - Clear screen
hdmi color <fg> [bg]     - Set text colors (0-15)
hdmi cursor <x> <y>      - Set cursor position
hdmi tutorial            - Interactive walkthrough
hdmi help                - All commands
```

### Wishbone Registers (direct access via HDMIController)

```cpp
// Switch to text mode directly
hdmi.controller()->wishboneWrite8(REG_VIDEO_MODE, VIDEO_MODE_TEXT);

// Write character to screen
hdmi.controller()->wishboneWrite8(REG_CHARRAM_CURSOR_X, 5);
hdmi.controller()->wishboneWrite8(REG_CHARRAM_CURSOR_Y, 2);
hdmi.controller()->wishboneWrite8(REG_CHARRAM_CHAR, 'A');
```

---

## Gateware Interface Patterns

### Instantiating video_top_modular

```verilog
video_top_modular u_hdmi (
    .I_clk          (clk_27mhz      ),
    .I_rst_n        (rst_n           ),
    .I_wb_clk       (wb_clk          ),
    .I_wb_adr       (slave_wb_adr    ),  // 16-bit
    .I_wb_dat       (slave_wb_dat_w  ),
    .I_wb_we        (wb_we           ),
    .I_wb_stb       (hdmi_wb_stb     ),
    .I_wb_cyc       (wb_cyc          ),
    .O_wb_ack       (hdmi_wb_ack     ),
    .O_wb_dat       (hdmi_wb_dat_r   ),
    .O_tmds_clk_p   (O_tmds_clk_p   ),
    .O_tmds_clk_n   (O_tmds_clk_n   ),
    .O_tmds_data_p  (O_tmds_data_p  ),
    .O_tmds_data_n  (O_tmds_data_n  )
);
```

### Minimal testpattern-only integration

```verilog
hdmi_phy_720p u_phy (
    .I_clk(clk_27mhz), .I_rst_n(rst_n),
    .I_rgb_r(tp_r), .I_rgb_g(tp_g), .I_rgb_b(tp_b),
    .I_rgb_de(tp_de), .I_rgb_hs(tp_hs), .I_rgb_vs(tp_vs),
    /* ... */
);

wb_video_testpattern u_tp (
    .clk(pix_clk), .rst_n(rst_n),
    /* Wishbone + RGB outputs */
);
```

---

## Board-Specific Pin Assignments

### Papilio Retrocade (GW2A-18C)

| Signal | Pins (p,n) | IO Type |
|--------|-----------|---------|
| `O_tmds_clk_p` | P6, T6 | LVCMOS18D |
| `O_tmds_data_p[0]` (Blue) | M6, T8 | LVCMOS18D |
| `O_tmds_data_p[1]` (Green) | T11, P11 | LVCMOS18D |
| `O_tmds_data_p[2]` (Red) | T12, R11 | LVCMOS18D |

Constraint file: `gateware/constraints/hdmi_papilio_retrocade.cst`

**Important:** Bank voltage must be set to 1.8V. Uses LVCMOS18D (1.8V differential).

---

## Adding Features

### Add a new CLI command

1. Declare static handler in `PapilioHdmiOS.h`
2. Register in `registerCommands()` using `PapilioOS.registerCommand("hdmi", ...)`
3. Implement handler as `static void handleFoo(int argc, char** argv)`
4. Add to tutorial if interactive demo is useful
5. Document in `hdmi help` output

### Add a new video mode

1. Create `wb_video_<mode>.v` in `gateware/` with Wishbone interface
2. Add to `video_top_modular.v` address decoder and output mux
3. Add register constants to `HDMIController.h`
4. Add firmware API to `HDMIController` and `PapilioHdmi`
5. Add CLI command in `PapilioHdmiOS`
6. Add testbench `tests/sim/tb_wb_<mode>.v`

---

## Troubleshooting

### No video output
- Check `I_clk` is 27MHz; the rPLL expects exactly 27MHz
- Verify TMDS pin assignments match `hdmi_papilio_retrocade.cst`
- Check bank voltage is set to 1.8V (LVCMOS18D)
- Run `hdmi status` to confirm firmware is responding

### Text mode not working
- Ensure `video_top_modular.v` is used (not `wb_video_ctrl.v` / `video_top_wb.v`)
- Check Wishbone address: VIDEO_MODE register is at 0x0000, not 0x0010
- Verify text module is included in gateware build

### Garbled text
- Screen may need to be cleared first: `hdmi clear`
- Check that attribute register is set correctly: `hdmi color 15 0`

### Framebuffer is black
- Ensure VIDEO_MODE register is set to 2 (framebuffer)
- Framebuffer base is 0x0100; first pixel is at 0x0100 (not 0x0000)
- Write some test pixels: `hdmi.controller()->wishboneWrite8(0x0100, 0xFF)` should show top-left white

---

## File Reference

| File | Purpose |
|------|---------|
| `src/PapilioHdmi.h` | Standard facade header |
| `src/PapilioHdmi.cpp` | Standard facade implementation |
| `src/PapilioHdmiOS.h` | CLI plugin header |
| `src/PapilioHdmiOS.cpp` | CLI plugin implementation |
| `src/HDMIController.h` | Full-featured legacy controller header |
| `src/HDMIController.cpp` | Full-featured legacy controller |
| `src/HQVGA.h` / `.cpp` | 240×160 HQVGA framebuffer API |
| `src/HDMILiquidCrystal.h` / `.cpp` | LCD-compatible text API |
| `gateware/video_top_modular.v` | Canonical FPGA top-level |
| `gateware/hdmi_phy_720p.v` | HDMI physical layer |
| `gateware/constraints/hdmi_papilio_retrocade.cst` | Retrocade pin assignments |
| `tests/sim/` | Simulation testbenches |
| `examples/HdmiCLI/` | Standard CLI example |
