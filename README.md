# papilio_wishbone_hdmi

PlatformIO/Arduino library for HDMI 720p video output on Papilio FPGA boards via Wishbone-over-SPI. Supports test patterns, text mode, framebuffer, and an optional interactive CLI.

## Features

- **720p Output**: 1280×720 @ 60Hz using open-source TMDS (no Gowin DVI IP required)
- **Test Patterns**: Color bars, grid, grayscale
- **Text Mode**: 80×30 character display, 16 foreground/background colors, 8×8 VGA font, cursor control
- **Framebuffer**: 160×120 RGB332 scaled 6× to 720p
- **Standard API**: `PapilioHdmi` facade class — or use `HDMIController` directly (backward compatible)
- **CLI Plugin**: `hdmi` command group via `papilio_os` (`ENABLE_PAPILIO_OS`)
- **Graphics Adapters**: Adafruit GFX, TFT_eSPI, U8g2, LVGL, LiquidCrystal-compatible APIs

## Hardware Requirements

- Papilio Retrocade (or other Gowin GW2A-18C board)
- HDMI TMDS differential pairs connected per `gateware/constraints/hdmi_papilio_retrocade.cst`
- ESP32 connected to FPGA via SPI (CLK=12, MISO=9, MOSI=11, CS=10 by default)

## Installation

```ini
; platformio.ini
lib_deps =
    https://github.com/Papilio-Labs/papilio_wishbone_hdmi.git#main
```

## Quick Start — Programmatic API

### Using `PapilioHdmi` (recommended for new code)

```cpp
#include <PapilioHdmi.h>

PapilioHdmi hdmi;

void setup() {
    Serial.begin(115200);
    // SPI is initialized by PapilioWishboneBus before this point
    hdmi.begin();

    // Test pattern
    hdmi.setPattern(0);   // 0=color bars, 1=grid, 2=grayscale

    // Text mode
    hdmi.enableTextMode();
    hdmi.clearScreen();
    hdmi.setTextColor(HDMI_COLOR_WHITE, HDMI_COLOR_BLACK);
    hdmi.setCursor(0, 0);
    hdmi.println("Hello, Papilio!");
}
```

### Using `HDMIController` (backward compatible — all existing examples unchanged)

```cpp
#include <HDMIController.h>

HDMIController hdmi(nullptr, 10, 12, 11, 9);  // CS, CLK, MOSI, MISO

void setup() {
    hdmi.begin();
    hdmi.setVideoPattern(1);   // grid
    hdmi.enableTextMode();
    hdmi.println("Hello, HDMI!");
}
```

## Quick Start — CLI Interface

Add `-DENABLE_PAPILIO_OS` to your build flags and include the OS plugin:

```cpp
#include <PapilioHdmi.h>
#include <PapilioHdmiOS.h>   // only included when ENABLE_PAPILIO_OS is defined

PapilioHdmi hdmi;
#ifdef ENABLE_PAPILIO_OS
PapilioHdmiOS hdmi_os(&hdmi);
#endif

void setup() {
    hdmi.begin();
    PapilioOS.begin();
}
void loop() { PapilioOS.process(); }
```

Then from the serial terminal:
```
> hdmi tutorial          # Interactive walkthrough
> hdmi status            # Show current mode and cursor
> hdmi pattern 1         # Grid test pattern
> hdmi pattern 3         # Enable text mode
> hdmi color 15 1        # White text on blue background
> hdmi text Hello World  # Write text to screen
> hdmi cursor 0 2        # Move cursor to row 2
> hdmi clear             # Clear screen
> hdmi help              # All commands
```

## API Reference

### PapilioHdmi

| Method | Description |
|--------|-------------|
| `begin()` | Initialize controller; returns `true` on success |
| `setPattern(n)` | Test pattern: 0=bars, 1=grid, 2=grayscale |
| `getPattern()` | Get current test pattern |
| `enableTextMode()` | Switch to text mode |
| `disableTextMode()` | Return to test pattern mode |
| `clearScreen()` | Clear screen, reset cursor to (0, 0) |
| `setCursor(x, y)` | Set cursor position (x: 0–79, y: 0–29) |
| `setTextColor(fg, bg)` | Set text colors (0–15) |
| `print(str)` | Print string at cursor |
| `println(str)` | Print string + newline |
| `writeChar(c)` | Write single character |
| `getCursorX()` / `getCursorY()` | Get cursor position |
| `getVideoMode()` | 0=test-pattern, 1=text, 2=framebuffer |
| `getVideoStatus()` | Gateware version byte |
| `waitForFPGA(ms)` | Wait for FPGA ready (default 5000ms) |
| `setLEDColor(grb)` | Set RGB LED (GRB format) |
| `setLEDColorRGB(r,g,b)` | Set RGB LED (RGB format) |
| `controller()` | Access underlying `HDMIController*` |

### Text Color Constants

```cpp
HDMI_COLOR_BLACK         // 0x00
HDMI_COLOR_BLUE          // 0x01
HDMI_COLOR_GREEN         // 0x02
HDMI_COLOR_CYAN          // 0x03
HDMI_COLOR_RED           // 0x04
HDMI_COLOR_MAGENTA       // 0x05
HDMI_COLOR_BROWN         // 0x06
HDMI_COLOR_LIGHT_GRAY    // 0x07
HDMI_COLOR_DARK_GRAY     // 0x08
HDMI_COLOR_LIGHT_BLUE    // 0x09
HDMI_COLOR_LIGHT_GREEN   // 0x0A
HDMI_COLOR_LIGHT_CYAN    // 0x0B
HDMI_COLOR_LIGHT_RED     // 0x0C
HDMI_COLOR_LIGHT_MAGENTA // 0x0D
HDMI_COLOR_YELLOW        // 0x0E
HDMI_COLOR_WHITE         // 0x0F
```

## Gateware Register Map

| Address | Register | Description |
|---------|----------|-------------|
| 0x0000 | VIDEO_MODE | 0=test-pattern, 1=text, 2=framebuffer |
| 0x0010 | TP_PATTERN | 0=color bars, 1=grid, 2=grayscale |
| 0x0011 | TP_STATUS | Gateware version |
| 0x0020 | TEXT_CONTROL | Bit 0: clear, Bit 1: cursor enable |
| 0x0021 | TEXT_CURSOR_X | Cursor X (0–79) |
| 0x0022 | TEXT_CURSOR_Y | Cursor Y (0–29) |
| 0x0023 | TEXT_ATTR | [7:4]=bg color, [3:0]=fg color |
| 0x0024 | TEXT_CHAR | Write character at cursor (auto-advance) |
| 0x0100–0x7FFF | FRAMEBUFFER | 160×120 RGB332 pixels |

## Gateware — Canonical Top-Level

Use `gateware/video_top_modular.v` — it supports all video modes with runtime switching.

```verilog
module video_top_modular (
    input         I_clk,       // 27MHz
    input         I_rst_n,
    input  [15:0] I_wb_adr,    // 16-bit Wishbone address
    input  [7:0]  I_wb_dat,
    input         I_wb_we, I_wb_stb, I_wb_cyc,
    output        O_wb_ack,
    output [7:0]  O_wb_dat,
    output        O_tmds_clk_p, O_tmds_clk_n,
    output [2:0]  O_tmds_data_p, O_tmds_data_n
);
```

See `gateware/README.md` for full file listing, register map, and constraint file documentation.

## Supported Boards

| Board | Constraint File |
|-------|----------------|
| Papilio Retrocade (GW2A-18C) | `gateware/constraints/hdmi_papilio_retrocade.cst` |

## Examples

| Example | Description |
|---------|-------------|
| `examples/HdmiCLI/` | Standard CLI + API example (new) |
| `examples/papilio_hdmi_example/` | Basic test patterns and RGB LED |
| `examples/papilio_hdmi_text_example/` | Text mode demonstration |
| `examples/gfx_demo/` | Adafruit GFX graphics |
| `examples/tft_espi_demo/` | TFT_eSPI display adapter |
| `examples/u8g2_demo/` | U8g2 graphics library |
| `examples/lvgl_demo/` | LVGL GUI framework |
| `examples/spaceinvaders_hqvga/` | Space Invaders on HQVGA |
| `examples/bricks_hqvga/` | Breakout game on HQVGA |

All existing examples use `HDMIController` / `HQVGA` directly and are preserved unchanged.

## Testing

### Simulation Tests (requires OSS CAD Suite / iverilog)

```bash
cd tests/sim
python run_all_sims.py
```

Testbenches cover:
- `tb_wb_video_ctrl.v` — Video control register read/write, pattern switching
- `tb_wb_char_ram.v` — Character RAM Wishbone interface, cursor, text write

### All Tests

```bash
python run_all_tests.py
```

## Development Guide

### Adding a new video mode

1. Create `gateware/wb_video_<mode>.v` with Wishbone interface
2. Add to `video_top_modular.v` address decoder and output mux
3. Add register constants to `src/HDMIController.h`
4. Add firmware methods to `HDMIController` and `PapilioHdmi`
5. Add CLI command to `PapilioHdmiOS`
6. Write testbench `tests/sim/tb_wb_<mode>.v`

See `AI_SKILL.md` for detailed patterns and troubleshooting.

