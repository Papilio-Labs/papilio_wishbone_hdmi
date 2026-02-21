// PapilioHdmi.h - Standard Papilio facade for HDMIController
// Provides the standard Papilio<Name> interface for new code.
// Existing code using HDMIController directly continues to work unchanged.

#ifndef PAPILIO_HDMI_H
#define PAPILIO_HDMI_H

#include <Arduino.h>
#include "HDMIController.h"

// Standard Papilio Library interface for HDMI video output.
// Wraps HDMIController to provide the canonical Papilio<Name> entry point.
//
// Usage:
//   PapilioHdmi hdmi(0x0000);   // base address (optional, default 0x0000)
//   hdmi.begin();
//   hdmi.setPattern(1);          // grid pattern
//   hdmi.enableTextMode();
//   hdmi.print("Hello, Papilio!");
//
// For backward compatibility, HDMIController is still available directly.

class PapilioHdmi {
public:
    // Construct with optional base address (reserved for future use)
    // SPI must be initialized before calling begin()
    PapilioHdmi(uint16_t baseAddress = 0x0000);

    // Initialize HDMI controller; returns true on success
    bool begin();

    // -------------------------------------------------------------------------
    // Video mode control
    // -------------------------------------------------------------------------

    // Set test pattern (0=color bars, 1=grid, 2=grayscale)
    void setPattern(uint8_t pattern);
    uint8_t getPattern();

    // Enable text mode (pattern 3 / VIDEO_MODE_TEXT)
    void enableTextMode();

    // Disable text mode (return to color bars)
    void disableTextMode();

    // -------------------------------------------------------------------------
    // Text mode API
    // -------------------------------------------------------------------------

    // Clear screen and reset cursor to (0, 0)
    void clearScreen();

    // Set cursor position (x: 0-79, y: 0-29)
    void setCursor(uint8_t x, uint8_t y);

    // Set text colors (foreground and background, see HDMI_COLOR_* constants)
    void setTextColor(uint8_t fg, uint8_t bg);

    // Print a C-string at the current cursor position (auto-advance)
    void print(const char* str);

    // Print a C-string followed by newline
    void println(const char* str);

    // Write a single character at the current cursor position
    void writeChar(char c);

    // Get current cursor X position
    uint8_t getCursorX();

    // Get current cursor Y position
    uint8_t getCursorY();

    // -------------------------------------------------------------------------
    // Status
    // -------------------------------------------------------------------------

    // Get current video mode (0=test-pattern, 1=text, 2=framebuffer)
    uint8_t getVideoMode();

    // Get status byte from FPGA gateware (version etc.)
    uint8_t getVideoStatus();

    // Wait for FPGA to be ready (timeout in ms; returns true if ready)
    bool waitForFPGA(unsigned long timeoutMs = 5000);

    // -------------------------------------------------------------------------
    // Framebuffer mode API (160x120 RGB332)
    // -------------------------------------------------------------------------

    // Switch to framebuffer video mode
    void enableFramebuffer();

    // Fill entire framebuffer with a single RGB332 color (default black)
    void clearFramebuffer(uint8_t color = 0x00);

    // Set a single pixel (x: 0-159, y: 0-119, color: RGB332)
    void setPixel(uint8_t x, uint8_t y, uint8_t color);

    // Fill a rectangle with a color (x/y/w/h in pixels)
    void fillRect(uint8_t x, uint8_t y, uint8_t w, uint8_t h, uint8_t color);

    // Draw built-in color-bar demo pattern into the framebuffer
    void drawColorBars();

    // Convert r(0-7), g(0-7), b(0-3) to RGB332 byte
    static uint8_t rgb332(uint8_t r, uint8_t g, uint8_t b) {
        return HDMIController::rgb332(r, g, b);
    }

    // -------------------------------------------------------------------------
    // RGB LED helpers (also exposed on HDMIController for convenience)
    // -------------------------------------------------------------------------
    void setLEDColor(uint32_t color);
    void setLEDColorRGB(uint8_t red, uint8_t green, uint8_t blue);

    // -------------------------------------------------------------------------
    // Access to underlying controller (for advanced use)
    // -------------------------------------------------------------------------
    HDMIController* controller() { return _ctrl; }

    // -------------------------------------------------------------------------
    // Base address
    // -------------------------------------------------------------------------
    uint16_t getBaseAddress() const { return _baseAddress; }

private:
    uint16_t     _baseAddress;
    HDMIController* _ctrl;
};

#endif // PAPILIO_HDMI_H
