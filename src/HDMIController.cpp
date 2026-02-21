#include "HDMIController.h"
#include <WishboneSPI.h>  // for shared-bus global functions

HDMIController::HDMIController(SPIClass* spi, uint8_t csPin, uint8_t spiClk, uint8_t spiMosi, uint8_t spiMiso)
  : _spi(spi), _ownSpi(false), _cs(csPin), _clk(spiClk), _mosi(spiMosi), _miso(spiMiso),
    _useSharedBus(false), _baseAddress(0x0000) {
  if (_spi == nullptr) {
    _ownSpi = true; // will create in begin()
  }
}

HDMIController::HDMIController(uint16_t baseAddress)
  : _spi(nullptr), _ownSpi(false), _cs(0), _clk(0), _mosi(0), _miso(0),
    _useSharedBus(true), _baseAddress(baseAddress) {
}

HDMIController::~HDMIController() {
  if (_ownSpi && _spi) {
    delete _spi;
    _spi = nullptr;
  }
}

void HDMIController::begin() {
  if (_useSharedBus) {
    // Shared-bus mode: SPI already initialised by wishboneInit(); nothing to set up
    return;
  }

  if (_spi == nullptr && _ownSpi) {
    _spi = new SPIClass(HSPI);
  }

  if (_spi) {
    _spi->begin(_clk, _miso, _mosi, _cs);
  }

  pinMode(_cs, OUTPUT);
  digitalWrite(_cs, HIGH);
  
  // Wait for FPGA to be ready
  waitForFPGA(5000);
}

bool HDMIController::waitForFPGA(unsigned long timeoutMs) {
  // Wait for FPGA bootloader (3 seconds) plus margin
  Serial.println("Waiting for FPGA bootloader...");
  delay(4000);
  
  // Poll until we can communicate with the FPGA
  Serial.println("Waiting for FPGA to be ready...");
  unsigned long start = millis();
  int attempts = 0;
  
  while (millis() - start < timeoutMs) {
    // Try to read video mode register - should return a valid mode (0, 1, or 2)
    uint8_t mode = getVideoMode();
    if (mode <= 2) {
      Serial.print("FPGA ready after ");
      Serial.print(attempts * 100);
      Serial.println("ms additional wait");
      return true;
    }
    delay(100);
    attempts++;
  }
  
  Serial.println("Warning: FPGA may not be responding correctly");
  return false;
}

void HDMIController::setLEDColor(uint32_t color) {
  uint8_t g = (color >> 16) & 0xFF;
  uint8_t r = (color >> 8) & 0xFF;
  uint8_t b = color & 0xFF;

  wishboneWrite8(REG_LED_GREEN, g);
  wishboneWrite8(REG_LED_RED, r);
  wishboneWrite8(REG_LED_BLUE, b);

  delay(100);
}

void HDMIController::setLEDColorRGB(uint8_t red, uint8_t green, uint8_t blue) {
  uint32_t color = ((uint32_t)green << 16) | ((uint32_t)red << 8) | blue;
  setLEDColor(color);
}

bool HDMIController::isLEDBusy() {
  uint8_t status = wishboneRead8(REG_LED_CTRL);
  return (status & 0x01) != 0;
}

void HDMIController::setVideoPattern(uint8_t pattern) {
  wishboneWrite8(REG_VIDEO_PATTERN, pattern);
}

uint8_t HDMIController::getVideoPattern() {
  return wishboneRead8(REG_VIDEO_PATTERN);
}

uint8_t HDMIController::getVideoStatus() {
  return wishboneRead8(REG_VIDEO_STATUS);
}

// 8-bit wishbone write
void HDMIController::wishboneWrite8(uint16_t address, uint8_t data) {
  if (_useSharedBus) {
    ::wishboneWrite8(_baseAddress + address, data);
    return;
  }

  if (!_spi) return;

  _spi->beginTransaction(SPISettings(8000000, MSBFIRST, SPI_MODE0));
  digitalWrite(_cs, LOW);

  _spi->transfer(CMD_WRITE);              // Command byte
  _spi->transfer((address >> 8) & 0xFF);  // Address high byte
  _spi->transfer(address & 0xFF);         // Address low byte
  _spi->transfer(data);                   // Data byte

  digitalWrite(_cs, HIGH);
  _spi->endTransaction();
}

// 8-bit wishbone read
uint8_t HDMIController::wishboneRead8(uint16_t address) {
  if (_useSharedBus) {
    return ::wishboneRead8(_baseAddress + address);
  }

  uint8_t data = 0;
  if (!_spi) return data;

  _spi->beginTransaction(SPISettings(8000000, MSBFIRST, SPI_MODE0));
  digitalWrite(_cs, LOW);

  _spi->transfer(0x00);                   // CMD_READ
  _spi->transfer((address >> 8) & 0xFF);  // Address high byte
  _spi->transfer(address & 0xFF);         // Address low byte
  delayMicroseconds(2);                   // Wait for Wishbone read
  data = _spi->transfer(0x00);            // Read result

  digitalWrite(_cs, HIGH);
  _spi->endTransaction();

  return data;
}

// ============= Text Mode Functions =============

void HDMIController::enableTextMode() {
  // Switch master video mode mux to text mode (REG_VIDEO_MODE = 0x0000, value 0x01)
  setVideoMode(VIDEO_MODE_TEXT);
}

void HDMIController::disableTextMode() {
  // Restore master video mode to test pattern and reset to color bars
  setVideoMode(VIDEO_MODE_TEST_PATTERN);
  setVideoPattern(PATTERN_COLOR_BARS);
}

void HDMIController::clearScreen() {
  // Set clear screen bit in control register
  wishboneWrite8(REG_CHARRAM_CONTROL, 0x01);
  delay(10);  // Give time for clear to complete
  setCursor(0, 0);
}

void HDMIController::setCursor(uint8_t x, uint8_t y) {
  if (x < 80 && y < 30) {
    wishboneWrite8(REG_CHARRAM_CURSOR_X, x);
    wishboneWrite8(REG_CHARRAM_CURSOR_Y, y);
  }
}

void HDMIController::setTextColor(uint8_t foreground, uint8_t background) {
  uint8_t attr = ((background & 0x0F) << 4) | (foreground & 0x0F);
  wishboneWrite8(REG_CHARRAM_ATTR, attr);
}

void HDMIController::writeChar(char c) {
  if (c == '\n') {
    // Move to next line
    uint8_t y = wishboneRead8(REG_CHARRAM_CURSOR_Y);
    if (y < 29) {
      setCursor(0, y + 1);
    } else {
      // Scroll would go here - for now just wrap
      setCursor(0, 0);
    }
  } else if (c == '\r') {
    // Carriage return
    uint8_t y = wishboneRead8(REG_CHARRAM_CURSOR_Y);
    setCursor(0, y);
  } else if (c >= 32 && c <= 126) {
    // Printable character
    wishboneWrite8(REG_CHARRAM_CHAR, (uint8_t)c);
    // Cursor auto-advances in hardware
  }
}

void HDMIController::writeString(const char* str) {
  while (*str) {
    writeChar(*str++);
  }
}

void HDMIController::println(const char* str) {
  writeString(str);
  writeChar('\n');
}

void HDMIController::print(const char* str) {
  writeString(str);
}

uint8_t HDMIController::getCursorX() {
  return wishboneRead8(REG_CHARRAM_CURSOR_X);
}

uint8_t HDMIController::getCursorY() {
  return wishboneRead8(REG_CHARRAM_CURSOR_Y);
}

void HDMIController::writeCustomFont(uint8_t charCode, const uint8_t fontData[8]) {
  // Character codes 0-7 are custom characters
  if (charCode > 7) return;
  
  // Calculate font RAM address: charCode * 8 rows
  uint8_t fontAddr = charCode * 8;
  
  Serial.printf("Writing custom char %d at font addr %d\n", charCode, fontAddr);
  
  // Write all 8 rows of the character
  for (uint8_t row = 0; row < 8; row++) {
    // Set font address
    wishboneWrite8(REG_CHARRAM_FONT_ADDR, fontAddr + row);
    
    // Write font data for this row
    wishboneWrite8(REG_CHARRAM_FONT_DATA, fontData[row]);
    
    Serial.printf("  Row %d: 0x%02X (binary: ", row, fontData[row]);
    for (int bit = 7; bit >= 0; bit--) {
      Serial.print((fontData[row] & (1 << bit)) ? '1' : '0');
    }
    Serial.println(")");
  }
}

// ============= Video Mode Functions =============

void HDMIController::setVideoMode(uint8_t mode) {
  wishboneWrite8(REG_VIDEO_MODE, mode);
}

uint8_t HDMIController::getVideoMode() {
  return wishboneRead8(REG_VIDEO_MODE);
}

// ============= Framebuffer Functions =============

void HDMIController::enableFramebuffer() {
  setVideoMode(VIDEO_MODE_FRAMEBUFFER);
}

void HDMIController::clearFramebuffer(uint8_t color) {
  // One burst per row (160 bytes) — 120 transactions instead of 19,200
  uint8_t buf[FB_WIDTH];
  memset(buf, color, FB_WIDTH);
  for (uint8_t y = 0; y < FB_HEIGHT; y++) {
    wishboneWriteBurst8(FB_BASE_ADDR + (uint16_t)y * FB_WIDTH, buf, FB_WIDTH);
  }
}

void HDMIController::setPixel(uint8_t x, uint8_t y, uint8_t color) {
  if (x >= FB_WIDTH || y >= FB_HEIGHT) return;
  uint16_t pixelIndex = y * FB_WIDTH + x;
  uint16_t addr = FB_BASE_ADDR + pixelIndex;  // Direct byte addressing
  wishboneWrite8(addr, color);
}

void HDMIController::fillRect(uint8_t x, uint8_t y, uint8_t w, uint8_t h, uint8_t color) {
  if (x >= FB_WIDTH || y >= FB_HEIGHT) return;
  uint8_t clampW = (x + w > FB_WIDTH) ? (FB_WIDTH - x) : w;
  uint8_t buf[FB_WIDTH];  // worst-case row width
  memset(buf, color, clampW);
  for (uint8_t py = y; py < y + h && py < FB_HEIGHT; py++) {
    wishboneWriteBurst8(FB_BASE_ADDR + (uint16_t)py * FB_WIDTH + x, buf, clampW);
  }
}

void HDMIController::drawColorBars() {
  // RGB332 colors for standard color bars
  static const uint8_t colors[8] = {
    0xFF,  // White
    0xFC,  // Yellow
    0x1F,  // Cyan
    0x1C,  // Green
    0xE3,  // Magenta
    0xE0,  // Red
    0x03,  // Blue
    0x00   // Black
  };

  // Build one row pattern, then burst the same row for all 120 lines
  // 120 burst transactions instead of 19,200 individual writes
  const uint8_t barWidth = FB_WIDTH / 8;  // 20 pixels per bar
  uint8_t rowBuf[FB_WIDTH];
  for (uint8_t x = 0; x < FB_WIDTH; x++) {
    uint8_t barIndex = x / barWidth;
    if (barIndex > 7) barIndex = 7;
    rowBuf[x] = colors[barIndex];
  }

  for (uint8_t y = 0; y < FB_HEIGHT; y++) {
    wishboneWriteBurst8(FB_BASE_ADDR + (uint16_t)y * FB_WIDTH, rowBuf, FB_WIDTH);
  }
}

// Burst write: one SPI transaction for 'count' sequential bytes
void HDMIController::wishboneWriteBurst8(uint16_t address, const uint8_t* data, uint16_t count) {
  if (_useSharedBus) {
    ::wishboneWriteBurst8(_baseAddress + address, data, count);
    return;
  }

  if (!_spi || count == 0) return;

  _spi->beginTransaction(SPISettings(8000000, MSBFIRST, SPI_MODE0));
  digitalWrite(_cs, LOW);

  _spi->transfer(CMD_BURST_WRITE_8);          // Burst write 8-bit command
  _spi->transfer((address >> 8) & 0xFF);      // Address high byte
  _spi->transfer(address & 0xFF);             // Address low byte
  _spi->transfer((count >> 8) & 0xFF);        // Count high byte
  _spi->transfer(count & 0xFF);               // Count low byte
  for (uint16_t i = 0; i < count; i++) {
    _spi->transfer(data[i]);
  }

  digitalWrite(_cs, HIGH);
  _spi->endTransaction();
}

// 32-bit write
void HDMIController::wishboneWrite(uint32_t address, uint32_t data) {
  if (!_spi) return;

  _spi->beginTransaction(SPISettings(100000, MSBFIRST, SPI_MODE1));
  digitalWrite(_cs, LOW);

  _spi->transfer(CMD_WRITE);
  _spi->transfer((address >> 24) & 0xFF);
  _spi->transfer((address >> 16) & 0xFF);
  _spi->transfer((address >> 8) & 0xFF);
  _spi->transfer(address & 0xFF);

  _spi->transfer((data >> 24) & 0xFF);
  _spi->transfer((data >> 16) & 0xFF);
  _spi->transfer((data >> 8) & 0xFF);
  _spi->transfer(data & 0xFF);

  digitalWrite(_cs, HIGH);
  _spi->endTransaction();
}

// 32-bit read
uint32_t HDMIController::wishboneRead(uint32_t address) {
  uint32_t data = 0;
  if (!_spi) return data;

  _spi->beginTransaction(SPISettings(100000, MSBFIRST, SPI_MODE1));
  digitalWrite(_cs, LOW);

  _spi->transfer(CMD_READ);
  _spi->transfer((address >> 24) & 0xFF);
  _spi->transfer((address >> 16) & 0xFF);
  _spi->transfer((address >> 8) & 0xFF);
  _spi->transfer(address & 0xFF);

  data |= ((uint32_t)_spi->transfer(0x00) << 24);
  data |= ((uint32_t)_spi->transfer(0x00) << 16);
  data |= ((uint32_t)_spi->transfer(0x00) << 8);
  data |= (uint32_t)_spi->transfer(0x00);

  digitalWrite(_cs, HIGH);
  _spi->endTransaction();

  return data;
}
