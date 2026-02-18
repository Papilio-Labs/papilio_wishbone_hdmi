/**
 * HdmiCLI.ino — Standard Papilio HDMI example
 *
 * Demonstrates:
 *   1. Programmatic API via PapilioHdmi (standard facade)
 *   2. Optional CLI interface via PapilioHdmiOS (requires ENABLE_PAPILIO_OS)
 *
 * Hardware:
 *   - Papilio Retrocade (or compatible GW2A-18C board)
 *   - FPGA flashed with video_top_modular.v bitstream
 *   - ESP32 connected to FPGA via SPI
 *
 * Build flags for CLI mode:
 *   build_flags = -DENABLE_PAPILIO_OS
 *
 * CLI commands (when ENABLE_PAPILIO_OS is defined):
 *   hdmi tutorial        - Interactive walkthrough
 *   hdmi status          - Show current mode and cursor
 *   hdmi pattern 0       - Color bars
 *   hdmi pattern 1       - Grid
 *   hdmi pattern 2       - Grayscale
 *   hdmi pattern 3       - Text mode
 *   hdmi text <message>  - Write text
 *   hdmi clear           - Clear screen
 *   hdmi color <fg> [bg] - Set text colors (0-15)
 *   hdmi cursor <x> <y>  - Set cursor position
 *   hdmi help            - All commands
 *
 * License: MIT
 * Author: Papilio Labs
 */

#include <Arduino.h>
#include <PapilioHdmi.h>

#ifdef ENABLE_PAPILIO_OS
#include <PapilioOS.h>
#include <PapilioHdmiOS.h>
#endif

// ---------------------------------------------------------------------------
// Globals
// ---------------------------------------------------------------------------

PapilioHdmi hdmi;

#ifdef ENABLE_PAPILIO_OS
PapilioHdmiOS hdmi_os(&hdmi);
#endif

// ---------------------------------------------------------------------------
// Setup
// ---------------------------------------------------------------------------

void setup() {
    Serial.begin(115200);
    delay(500);

    Serial.println("\n========================================");
    Serial.println("   Papilio HDMI Example (HdmiCLI)");
    Serial.println("========================================\n");

    // Initialize HDMI controller
    if (!hdmi.begin()) {
        Serial.println("Warning: HDMI begin() returned false.");
        Serial.println("Ensure SPI is initialized and FPGA is ready.");
    }

    // Wait for FPGA to be ready (optional; remove if no timeout needed)
    Serial.print("Waiting for FPGA...");
    if (hdmi.waitForFPGA(3000)) {
        Serial.println(" Ready!");
    } else {
        Serial.println(" Timeout (continuing anyway)");
    }

    // ---------------------------------------------------------------------------
    // Programmatic API demonstration
    // ---------------------------------------------------------------------------

    // Start with color bars test pattern
    hdmi.setPattern(0);
    Serial.println("\n[Demo] Color bars pattern (0)");
    delay(1500);

    // Switch to grid
    hdmi.setPattern(1);
    Serial.println("[Demo] Grid pattern (1)");
    delay(1500);

    // Switch to grayscale
    hdmi.setPattern(2);
    Serial.println("[Demo] Grayscale pattern (2)");
    delay(1500);

    // Switch to text mode
    hdmi.enableTextMode();
    hdmi.clearScreen();

    // Write title line
    hdmi.setTextColor(HDMI_COLOR_YELLOW, HDMI_COLOR_BLUE);
    hdmi.setCursor(0, 0);
    hdmi.println("  Papilio Retrocade — HDMI Text Mode  ");

    // Write info
    hdmi.setTextColor(HDMI_COLOR_WHITE, HDMI_COLOR_BLACK);
    hdmi.setCursor(0, 2);
    hdmi.println("Resolution: 1280x720 @ 60Hz (720p)");
    hdmi.println("Interface:  Wishbone over SPI");
    hdmi.println("Library:    papilio_wishbone_hdmi");

    // Write color chart
    hdmi.setCursor(0, 7);
    hdmi.print("Colors: ");
    for (uint8_t c = 0; c < 16; c++) {
        hdmi.setTextColor(c, HDMI_COLOR_BLACK);
        hdmi.writeChar('#');
    }

    // Reset to white-on-black for status line
    hdmi.setTextColor(HDMI_COLOR_LIGHT_GREEN, HDMI_COLOR_BLACK);
    hdmi.setCursor(0, 10);
    hdmi.println("Text mode active. Type 'hdmi help' for CLI commands.");

    Serial.println("\n[Demo] Text mode active.");

#ifdef ENABLE_PAPILIO_OS
    // Initialize CLI
    PapilioOS.begin();
    Serial.println("\nCLI ready. Available commands:");
    Serial.println("  hdmi tutorial    - Interactive walkthrough");
    Serial.println("  hdmi help        - All commands");
    Serial.println("  hdmi status      - Device status");
    Serial.println("\nType a command:");
#else
    Serial.println("\n(CLI disabled — define ENABLE_PAPILIO_OS to enable)");
    Serial.println("See platformio.ini: build_flags = -DENABLE_PAPILIO_OS");
#endif
}

// ---------------------------------------------------------------------------
// Loop
// ---------------------------------------------------------------------------

void loop() {
#ifdef ENABLE_PAPILIO_OS
    PapilioOS.process();
#else
    // Without CLI, just cycle through patterns
    static unsigned long lastChange = 0;
    static uint8_t       pattern    = 0;

    if (millis() - lastChange > 5000) {
        lastChange = millis();
        pattern    = (pattern + 1) % 3;
        hdmi.setPattern(pattern);
    }
#endif
}
