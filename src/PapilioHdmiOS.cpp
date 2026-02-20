// PapilioHdmiOS.cpp - CLI plugin implementation for papilio_wishbone_hdmi

#include "PapilioHdmiOS.h"

#ifdef ENABLE_PAPILIO_OS

PapilioHdmiOS* PapilioHdmiOS::_instance = nullptr;

PapilioHdmiOS::PapilioHdmiOS(PapilioHdmi* device) : _device(device) {
    _instance = this;
    registerCommands();
}

void PapilioHdmiOS::registerCommands() {
    PapilioOS.registerCommand("hdmi", "tutorial", handleTutorial, "Interactive HDMI tutorial");
    PapilioOS.registerCommand("hdmi", "help",     handleHelp,     "Show all hdmi commands");
    PapilioOS.registerCommand("hdmi", "status",   handleStatus,   "Show HDMI device status");
    PapilioOS.registerCommand("hdmi", "pattern",  handlePattern,  "Set test pattern (0=bars, 1=grid, 2=gray): hdmi pattern 1");
    PapilioOS.registerCommand("hdmi", "text",     handleText,     "Write text in text mode: hdmi text Hello");
    PapilioOS.registerCommand("hdmi", "clear",    handleClear,    "Clear screen in text mode");
    PapilioOS.registerCommand("hdmi", "color",    handleColor,    "Set text colors (fg [bg] 0-15): hdmi color 15 0");
    PapilioOS.registerCommand("hdmi", "cursor",   handleCursor,   "Set cursor position (x y): hdmi cursor 10 5");
    PapilioOS.registerCommand("hdmi", "fb",        handleFb,       "Framebuffer mode: hdmi fb [clear|pixel|fill|bars]");
}

// ===========================================================================
// Tutorial
// ===========================================================================

void PapilioHdmiOS::handleTutorial(int argc, char** argv) {
    Serial.println("\n========================================");
    Serial.println("   HDMI Interactive Tutorial");
    Serial.println("========================================\n");

    Serial.println("This tutorial guides you through the HDMI video library.");
    Serial.println("Type 'exit' at any prompt to quit the tutorial.\n");

    delay(1000);

    if (!_instance || !_instance->_device) {
        Serial.println("Note: Device not initialized. Tutorial will show commands anyway.");
        Serial.println("In your sketch, initialize in setup():\n");
        Serial.println("  PapilioHdmi hdmi;");
        Serial.println("  hdmi.begin();\n");
        delay(1000);
    }

    // Step 1: Check status
    if (!tutorialStep(1, "Check HDMI device status",
                      "hdmi status")) return;

    // Step 2: Color bars test pattern
    if (!tutorialStep(2, "Show color bars test pattern",
                      "hdmi pattern 0")) return;

    // Step 3: Grid test pattern
    if (!tutorialStep(3, "Switch to grid test pattern",
                      "hdmi pattern 1")) return;

    // Step 4: Grayscale test pattern
    if (!tutorialStep(4, "Switch to grayscale gradient pattern",
                      "hdmi pattern 2")) return;

    // Step 5: Enable text mode
    if (!tutorialStep(5, "Switch to text mode",
                      "hdmi pattern 3")) return;

    // Step 5b: Framebuffer demo
    if (!tutorialStep(11, "Switch to framebuffer mode and draw color bars (160x120 RGB332)",
                      "hdmi fb bars")) return;

    // Step 5c: Fill a region
    if (!tutorialStep(12, "Fill a red rectangle in the top-left corner",
                      "hdmi fb fill 0 0 40 30 0xE0")) return;

    // Step 6: Clear screen
    if (!tutorialStep(6, "Clear the screen",
                      "hdmi clear")) return;

    // Step 7: Set text color
    if (!tutorialStep(7, "Set text to white on blue (fg=15, bg=1)",
                      "hdmi color 15 1")) return;

    // Step 8: Write text
    if (!tutorialStep(8, "Write a message to the screen",
                      "hdmi text Hello from Papilio!")) return;

    // Step 9: Move cursor and write again
    if (!tutorialStep(9, "Move cursor to row 2 and write another line",
                      "hdmi cursor 0 2")) return;

    if (!tutorialStep(10, "Write a second line",
                      "hdmi text This is text mode!")) return;

    Serial.println("\n========================================");
    Serial.println("   Tutorial Complete!");
    Serial.println("========================================\n");

    Serial.println("You've learned how to:");
    Serial.println("  - Check HDMI device status");
    Serial.println("  - Switch between test patterns");
    Serial.println("  - Use text mode with colors and cursor");
    Serial.println("\nFor all commands, run: hdmi help");
}

bool PapilioHdmiOS::tutorialStep(int stepNum, const char* description,
                                  const char* command) {
    Serial.printf("\nStep %d: %s\n", stepNum, description);
    Serial.printf("Try the command: %s\n", command);
    Serial.print("\nPress Enter when ready (or type 'exit' to quit): ");

    while (!Serial.available()) delay(10);

    String input = Serial.readStringUntil('\n');
    input.trim();
    Serial.println();

    if (input.equalsIgnoreCase("exit") || input.equalsIgnoreCase("quit")) {
        Serial.println("Tutorial exited.");
        return false;
    }

    Serial.printf("> %s\n", command);

    // Parse and dispatch the command
    char cmdCopy[256];
    strncpy(cmdCopy, command, sizeof(cmdCopy) - 1);
    cmdCopy[sizeof(cmdCopy) - 1] = '\0';

    char* argv2[16];
    int argc2 = 0;
    char* token = strtok(cmdCopy, " ");
    while (token && argc2 < 16) {
        argv2[argc2++] = token;
        token = strtok(nullptr, " ");
    }

    // Dispatch (skip module name "hdmi")
    if (argc2 >= 2) {
        if      (strcmp(argv2[1], "status")  == 0) handleStatus (argc2 - 1, &argv2[1]);
        else if (strcmp(argv2[1], "pattern") == 0) handlePattern(argc2 - 1, &argv2[1]);
        else if (strcmp(argv2[1], "text")    == 0) handleText   (argc2 - 1, &argv2[1]);
        else if (strcmp(argv2[1], "clear")   == 0) handleClear  (argc2 - 1, &argv2[1]);
        else if (strcmp(argv2[1], "color")   == 0) handleColor  (argc2 - 1, &argv2[1]);
        else if (strcmp(argv2[1], "cursor")  == 0) handleCursor (argc2 - 1, &argv2[1]);
        else if (strcmp(argv2[1], "fb")       == 0) handleFb     (argc2 - 1, &argv2[1]);
    }

    delay(1000);
    return true;
}

// ===========================================================================
// Help
// ===========================================================================

void PapilioHdmiOS::handleHelp(int argc, char** argv) {
    Serial.println("\nHDMI Commands:");
    Serial.println("  hdmi tutorial              - Interactive tutorial");
    Serial.println("  hdmi status                - Show device status");
    Serial.println("  hdmi pattern <n>           - Test pattern (0=bars, 1=grid, 2=gray)");
    Serial.println("  hdmi text <message>        - Write text in text mode");
    Serial.println("  hdmi clear                 - Clear screen in text mode");
    Serial.println("  hdmi color <fg> [bg]       - Set text colors (0-15)");
    Serial.println("  hdmi cursor <x> <y>        - Set cursor position (0-79, 0-29)");
    Serial.println("  hdmi fb                    - Enter framebuffer mode");
    Serial.println("  hdmi fb bars               - Draw color-bar demo");
    Serial.println("  hdmi fb clear [color]      - Clear framebuffer (color: RGB332 hex, default 0x00)");
    Serial.println("  hdmi fb pixel <x> <y> <c> - Set pixel (x:0-159, y:0-119, c: RGB332)");
    Serial.println("  hdmi fb fill <x> <y> <w> <h> <c> - Fill rectangle");
    Serial.println("\nColor values (0-15):");
    Serial.println("  0=Black  1=Blue    2=Green  3=Cyan");
    Serial.println("  4=Red    5=Magenta 6=Brown  7=Lt.Gray");
    Serial.println("  8=Dk.Gray 9=Lt.Blue 10=Lt.Green 11=Lt.Cyan");
    Serial.println("  12=Lt.Red 13=Lt.Magenta 14=Yellow 15=White");
    Serial.println("\nRGB332 color byte: bits [7:5]=R(0-7) [4:2]=G(0-7) [1:0]=B(0-3)");
    Serial.println("  0xE0=Red  0x1C=Green  0x03=Blue  0xFF=White  0x00=Black");
    Serial.println("\nVideo modes: 'hdmi pattern 3' = text, 'hdmi fb' = framebuffer");
}

// ===========================================================================
// Status
// ===========================================================================

void PapilioHdmiOS::handleStatus(int argc, char** argv) {
    if (!_instance || !_instance->_device) {
        Serial.println("Error: HDMI device not initialized");
        return;
    }

    PapilioHdmi* hdmi = _instance->_device;

    Serial.println("\nHDMI Device Status:");
    Serial.println("  Resolution: 1280x720 @ 60Hz (720p)");

    uint8_t mode = hdmi->getVideoMode();
    const char* modeStr =
        (mode == 0) ? "test-pattern" :
        (mode == 1) ? "text" :
        (mode == 2) ? "framebuffer" : "unknown";
    Serial.printf("  Video mode: %d (%s)\n", mode, modeStr);

    if (mode == 0 || mode == VIDEO_MODE_TEST_PATTERN) {
        uint8_t pattern = hdmi->getPattern();
        const char* patStr =
            (pattern == 0) ? "color bars" :
            (pattern == 1) ? "grid" :
            (pattern == 2) ? "grayscale" : "unknown";
        Serial.printf("  Test pattern: %d (%s)\n", pattern, patStr);
    }

    uint8_t status = hdmi->getVideoStatus();
    Serial.printf("  Firmware version: 0x%02X\n", status);

    if (mode == 1) {
        Serial.printf("  Cursor: (%d, %d)\n",
                      hdmi->getCursorX(), hdmi->getCursorY());
    }
}

// ===========================================================================
// Pattern
// ===========================================================================

void PapilioHdmiOS::handlePattern(int argc, char** argv) {
    if (!_instance || !_instance->_device) {
        Serial.println("Error: HDMI device not initialized");
        return;
    }

    if (argc < 2) {
        Serial.println("Usage: hdmi pattern <n>  (0=color bars, 1=grid, 2=grayscale, 3=text mode)");
        return;
    }

    uint8_t pattern = (uint8_t)atoi(argv[1]);
    PapilioHdmi* hdmi = _instance->_device;

    if (pattern == 3) {
        // Pattern 3 = text mode
        hdmi->enableTextMode();
        Serial.println("Text mode enabled");
    } else if (pattern > 2) {
        Serial.println("Error: pattern must be 0-3 (3=text mode)");
        return;
    } else {
        if (hdmi->getVideoMode() == VIDEO_MODE_TEXT) {
            hdmi->disableTextMode();
        }
        hdmi->setPattern(pattern);
        const char* names[] = { "color bars", "grid", "grayscale" };
        Serial.printf("Pattern set to %d (%s)\n", pattern, names[pattern]);
    }
}

// ===========================================================================
// Text
// ===========================================================================

void PapilioHdmiOS::handleText(int argc, char** argv) {
    if (!_instance || !_instance->_device) {
        Serial.println("Error: HDMI device not initialized");
        return;
    }

    if (argc < 2) {
        Serial.println("Usage: hdmi text <message>");
        return;
    }

    PapilioHdmi* hdmi = _instance->_device;

    // Enable text mode if not already active
    if (hdmi->getVideoMode() != VIDEO_MODE_TEXT) {
        hdmi->enableTextMode();
    }

    // Concatenate all remaining arguments as the message
    String msg = "";
    for (int i = 1; i < argc; i++) {
        if (i > 1) msg += " ";
        msg += argv[i];
    }

    hdmi->println(msg.c_str());
    Serial.printf("Wrote: \"%s\"\n", msg.c_str());
}

// ===========================================================================
// Clear
// ===========================================================================

void PapilioHdmiOS::handleClear(int argc, char** argv) {
    if (!_instance || !_instance->_device) {
        Serial.println("Error: HDMI device not initialized");
        return;
    }

    PapilioHdmi* hdmi = _instance->_device;

    if (hdmi->getVideoMode() != VIDEO_MODE_TEXT) {
        hdmi->enableTextMode();
    }

    hdmi->clearScreen();
    Serial.println("Screen cleared");
}

// ===========================================================================
// Color
// ===========================================================================

void PapilioHdmiOS::handleColor(int argc, char** argv) {
    if (!_instance || !_instance->_device) {
        Serial.println("Error: HDMI device not initialized");
        return;
    }

    if (argc < 2) {
        Serial.println("Usage: hdmi color <fg> [bg]  (0-15)");
        return;
    }

    uint8_t fg = (uint8_t)atoi(argv[1]);
    uint8_t bg = (argc >= 3) ? (uint8_t)atoi(argv[2]) : 0;

    if (fg > 15 || bg > 15) {
        Serial.println("Error: color values must be 0-15");
        return;
    }

    _instance->_device->setTextColor(fg, bg);
    Serial.printf("Text color set: fg=%d, bg=%d\n", fg, bg);
}

// ===========================================================================
// Cursor
// ===========================================================================

void PapilioHdmiOS::handleCursor(int argc, char** argv) {
    if (!_instance || !_instance->_device) {
        Serial.println("Error: HDMI device not initialized");
        return;
    }

    if (argc < 3) {
        Serial.println("Usage: hdmi cursor <x> <y>  (x: 0-79, y: 0-29)");
        return;
    }

    uint8_t x = (uint8_t)atoi(argv[1]);
    uint8_t y = (uint8_t)atoi(argv[2]);

    if (x > 79 || y > 29) {
        Serial.println("Error: cursor x must be 0-79, y must be 0-29");
        return;
    }

    _instance->_device->setCursor(x, y);
    Serial.printf("Cursor set to (%d, %d)\n", x, y);
}

// ===========================================================================
// Framebuffer
// ===========================================================================

void PapilioHdmiOS::handleFb(int argc, char** argv) {
    if (!_instance || !_instance->_device) {
        Serial.println("Error: HDMI device not initialized");
        return;
    }

    PapilioHdmi* hdmi = _instance->_device;

    // No subcommand: just switch to framebuffer mode
    if (argc < 2) {
        hdmi->enableFramebuffer();
        Serial.println("Framebuffer mode enabled (160x120 RGB332)");
        return;
    }

    const char* sub = argv[1];

    // --- bars ---
    if (strcmp(sub, "bars") == 0) {
        hdmi->enableFramebuffer();
        Serial.print("Drawing color bars...");
        hdmi->drawColorBars();
        Serial.println(" done");
        return;
    }

    // --- clear [color] ---
    if (strcmp(sub, "clear") == 0) {
        uint8_t color = (argc >= 3) ? (uint8_t)strtol(argv[2], nullptr, 0) : 0x00;
        hdmi->enableFramebuffer();
        Serial.printf("Clearing framebuffer with color 0x%02X...", color);
        hdmi->clearFramebuffer(color);
        Serial.println(" done");
        return;
    }

    // --- pixel <x> <y> <color> ---
    if (strcmp(sub, "pixel") == 0) {
        if (argc < 5) {
            Serial.println("Usage: hdmi fb pixel <x> <y> <color>  (x:0-159, y:0-119, color: RGB332 e.g. 0xE0)");
            return;
        }
        uint8_t x = (uint8_t)atoi(argv[2]);
        uint8_t y = (uint8_t)atoi(argv[3]);
        uint8_t c = (uint8_t)strtol(argv[4], nullptr, 0);
        if (x >= 160 || y >= 120) {
            Serial.println("Error: x must be 0-159, y must be 0-119");
            return;
        }
        hdmi->setPixel(x, y, c);
        Serial.printf("Pixel (%d,%d) = 0x%02X\n", x, y, c);
        return;
    }

    // --- fill <x> <y> <w> <h> <color> ---
    if (strcmp(sub, "fill") == 0) {
        if (argc < 7) {
            Serial.println("Usage: hdmi fb fill <x> <y> <w> <h> <color>  (color: RGB332 e.g. 0x1C)");
            return;
        }
        uint8_t x = (uint8_t)atoi(argv[2]);
        uint8_t y = (uint8_t)atoi(argv[3]);
        uint8_t w = (uint8_t)atoi(argv[4]);
        uint8_t h = (uint8_t)atoi(argv[5]);
        uint8_t c = (uint8_t)strtol(argv[6], nullptr, 0);
        Serial.printf("Filling rect (%d,%d) %dx%d color 0x%02X...", x, y, w, h, c);
        hdmi->fillRect(x, y, w, h, c);
        Serial.println(" done");
        return;
    }

    Serial.println("Unknown fb subcommand. Options: bars, clear, pixel, fill");
    Serial.println("Run 'hdmi help' for usage.");
}

#endif // ENABLE_PAPILIO_OS
