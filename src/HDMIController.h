#ifndef HDMI_CONTROLLER_H
#define HDMI_CONTROLLER_H

#include <Arduino.h>
#include <SPI.h>

// SPI Wishbone Protocol Commands (guarded — also defined in WishboneSPI.h)
#ifndef CMD_WRITE
#define CMD_WRITE 0x01
#endif
#ifndef CMD_READ
#define CMD_READ  0x02
#endif

// 8-bit Wishbone Register Addresses - RGB LED (0x8100-0x810F)
#define REG_LED_GREEN  0x8100
#define REG_LED_RED    0x8101
#define REG_LED_BLUE   0x8102
#define REG_LED_CTRL   0x8103

// Video mode control register (0x0000-0x000F)
#define REG_VIDEO_MODE      0x0000

// 8-bit Wishbone Register Addresses - HDMI Video/Test Pattern (0x0010-0x001F)
#define REG_VIDEO_PATTERN  0x0010
#define REG_VIDEO_STATUS   0x0011

// 8-bit Wishbone Register Addresses - Character RAM (0x0020-0x00FF)
// Note: 0x0020 is local 0x00 (default/unused). Clear screen is at local 0x0A = 0x002A.
#define REG_CHARRAM_CONTROL   0x002A  // Write any value to trigger clear screen (local reg 0x0A)
#define REG_CHARRAM_CURSOR_X  0x0021
#define REG_CHARRAM_CURSOR_Y  0x0022
#define REG_CHARRAM_ATTR      0x0023
#define REG_CHARRAM_CHAR      0x0024
#define REG_CHARRAM_ATTR_WR   0x0025
#define REG_CHARRAM_ADDR_HI   0x0026
#define REG_CHARRAM_ADDR_LO   0x0027
#define REG_CHARRAM_DATA_WR   0x0028
#define REG_CHARRAM_ATTR_DATA 0x0029
#define REG_CHARRAM_FONT_ADDR 0x002A
#define REG_CHARRAM_FONT_DATA 0x002B

// Video modes
#define VIDEO_MODE_TEST_PATTERN  0x00
#define VIDEO_MODE_TEXT          0x01
#define VIDEO_MODE_FRAMEBUFFER   0x02

// Test pattern modes (when in test pattern video mode)
#define PATTERN_COLOR_BARS  0x00
#define PATTERN_GRID        0x01
#define PATTERN_GRAYSCALE   0x02
#define PATTERN_TEXT_MODE   0x03

// Framebuffer constants
#define FB_WIDTH   160
#define FB_HEIGHT  120
#define FB_BASE_ADDR  0x0100

// Text colors (4-bit: [3]=bright, [2]=red, [1]=green, [0]=blue)
#define HDMI_COLOR_BLACK         0x00
#define HDMI_COLOR_BLUE          0x01
#define HDMI_COLOR_GREEN         0x02
#define HDMI_COLOR_CYAN          0x03
#define HDMI_COLOR_RED           0x04
#define HDMI_COLOR_MAGENTA       0x05
#define HDMI_COLOR_BROWN         0x06
#define HDMI_COLOR_LIGHT_GRAY    0x07
#define HDMI_COLOR_DARK_GRAY     0x08
#define HDMI_COLOR_LIGHT_BLUE    0x09
#define HDMI_COLOR_LIGHT_GREEN   0x0A
#define HDMI_COLOR_LIGHT_CYAN    0x0B
#define HDMI_COLOR_LIGHT_RED     0x0C
#define HDMI_COLOR_LIGHT_MAGENTA 0x0D
#define HDMI_COLOR_YELLOW        0x0E
#define HDMI_COLOR_WHITE         0x0F

class HDMIController {
public:
  // Dedicated SPI mode (legacy / standalone)
  HDMIController(SPIClass* spi = nullptr, uint8_t csPin = 10, uint8_t spiClk = 12, uint8_t spiMosi = 11, uint8_t spiMiso = 9);

  // Shared-bus mode: uses global wishboneWrite8/wishboneRead8 with baseAddress offset
  // baseAddress is added to every register address (e.g. 0x2000 for extended tier)
  explicit HDMIController(uint16_t baseAddress);

  ~HDMIController();

  void begin();
  bool waitForFPGA(unsigned long timeoutMs = 5000);

  void setLEDColor(uint32_t color);
  void setLEDColorRGB(uint8_t red, uint8_t green, uint8_t blue);
  bool isLEDBusy();

  void setVideoPattern(uint8_t pattern);
  uint8_t getVideoPattern();
  uint8_t getVideoStatus();

  // Text mode functions
  void enableTextMode();
  void disableTextMode();
  void clearScreen();
  void setCursor(uint8_t x, uint8_t y);
  void setTextColor(uint8_t foreground, uint8_t background);
  void writeChar(char c);
  void writeString(const char* str);
  void println(const char* str);
  void print(const char* str);
  uint8_t getCursorX();
  uint8_t getCursorY();
  
  // Custom font functions (for LCD createChar support)
  void writeCustomFont(uint8_t charCode, const uint8_t fontData[8]);
  
  // Video mode control
  void setVideoMode(uint8_t mode);
  uint8_t getVideoMode();
  
  // Framebuffer functions (160x120 RGB332)
  void enableFramebuffer();
  void clearFramebuffer(uint8_t color = 0x00);
  void setPixel(uint8_t x, uint8_t y, uint8_t color);
  void fillRect(uint8_t x, uint8_t y, uint8_t w, uint8_t h, uint8_t color);
  void drawColorBars();
  
  // RGB332 color helper: r(0-7), g(0-7), b(0-3)
  static uint8_t rgb332(uint8_t r, uint8_t g, uint8_t b) {
    return ((r & 0x07) << 5) | ((g & 0x07) << 2) | (b & 0x03);
  }
  
  // Wishbone register access (public for HDMILiquidCrystal scroll functions)
  void wishboneWrite8(uint16_t address, uint8_t data);
  uint8_t wishboneRead8(uint16_t address);

private:
  SPIClass* _spi;
  bool _ownSpi;
  uint8_t _cs;
  uint8_t _clk, _mosi, _miso;
  bool _useSharedBus;    // true = route through global wishboneWrite8/Read8
  uint16_t _baseAddress; // offset added to all addresses in shared-bus mode
  void wishboneWrite(uint32_t address, uint32_t data);
  uint32_t wishboneRead(uint32_t address);
};

#endif // HDMI_CONTROLLER_H
