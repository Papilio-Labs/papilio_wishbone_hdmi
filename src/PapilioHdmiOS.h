// PapilioHdmiOS.h - CLI plugin for papilio_wishbone_hdmi
// Provides the 'hdmi' command group when ENABLE_PAPILIO_OS is defined.

#ifndef PAPILIO_HDMI_OS_H
#define PAPILIO_HDMI_OS_H

#ifdef ENABLE_PAPILIO_OS

#include <PapilioOS.h>
#include "PapilioHdmi.h"

// CLI plugin for PapilioHdmi.
// Auto-registers 'hdmi' commands when constructed.
//
// Required commands (per Papilio Library Standards):
//   hdmi tutorial    - Interactive step-by-step guide
//   hdmi help        - Show all commands
//   hdmi status      - Display device status (mode, resolution, cursor)
//
// Functional commands:
//   hdmi pattern <n>         - Set test pattern (0=bars, 1=grid, 2=gray)
//   hdmi text <message>      - Write text in text mode
//   hdmi clear               - Clear screen in text mode
//   hdmi color <fg> [bg]     - Set text colors (0-15)
//   hdmi cursor <x> <y>      - Set cursor position

class PapilioHdmiOS {
public:
    PapilioHdmiOS(PapilioHdmi* device);

private:
    PapilioHdmi* _device;
    void registerCommands();

    // Command handlers
    static void handleTutorial(int argc, char** argv);
    static void handleHelp(int argc, char** argv);
    static void handleStatus(int argc, char** argv);
    static void handlePattern(int argc, char** argv);
    static void handleText(int argc, char** argv);
    static void handleClear(int argc, char** argv);
    static void handleColor(int argc, char** argv);
    static void handleCursor(int argc, char** argv);

    // Tutorial helper: show step, prompt user, optionally execute command
    static bool tutorialStep(int stepNum, const char* description,
                             const char* command);

    static PapilioHdmiOS* _instance;
};

#endif // ENABLE_PAPILIO_OS
#endif // PAPILIO_HDMI_OS_H
