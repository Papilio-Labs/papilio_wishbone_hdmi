// PapilioHdmi.cpp - Standard Papilio facade for HDMIController

#include "PapilioHdmi.h"

PapilioHdmi::PapilioHdmi(uint16_t baseAddress)
    : _baseAddress(baseAddress), _ctrl(nullptr)
{
    _ctrl = new HDMIController();
}

bool PapilioHdmi::begin() {
    if (!_ctrl) return false;
    _ctrl->begin();
    return true;
}

// ---------------------------------------------------------------------------
// Video mode control
// ---------------------------------------------------------------------------

void PapilioHdmi::setPattern(uint8_t pattern) {
    if (_ctrl) _ctrl->setVideoPattern(pattern);
}

uint8_t PapilioHdmi::getPattern() {
    if (!_ctrl) return 0;
    return _ctrl->getVideoPattern();
}

void PapilioHdmi::enableTextMode() {
    if (_ctrl) _ctrl->enableTextMode();
}

void PapilioHdmi::disableTextMode() {
    if (_ctrl) _ctrl->disableTextMode();
}

// ---------------------------------------------------------------------------
// Text mode API
// ---------------------------------------------------------------------------

void PapilioHdmi::clearScreen() {
    if (_ctrl) _ctrl->clearScreen();
}

void PapilioHdmi::setCursor(uint8_t x, uint8_t y) {
    if (_ctrl) _ctrl->setCursor(x, y);
}

void PapilioHdmi::setTextColor(uint8_t fg, uint8_t bg) {
    if (_ctrl) _ctrl->setTextColor(fg, bg);
}

void PapilioHdmi::print(const char* str) {
    if (_ctrl) _ctrl->print(str);
}

void PapilioHdmi::println(const char* str) {
    if (_ctrl) _ctrl->println(str);
}

void PapilioHdmi::writeChar(char c) {
    if (_ctrl) _ctrl->writeChar(c);
}

uint8_t PapilioHdmi::getCursorX() {
    if (!_ctrl) return 0;
    return _ctrl->getCursorX();
}

uint8_t PapilioHdmi::getCursorY() {
    if (!_ctrl) return 0;
    return _ctrl->getCursorY();
}

// ---------------------------------------------------------------------------
// Status
// ---------------------------------------------------------------------------

uint8_t PapilioHdmi::getVideoMode() {
    if (!_ctrl) return 0;
    return _ctrl->getVideoMode();
}

uint8_t PapilioHdmi::getVideoStatus() {
    if (!_ctrl) return 0;
    return _ctrl->getVideoStatus();
}

bool PapilioHdmi::waitForFPGA(unsigned long timeoutMs) {
    if (!_ctrl) return false;
    return _ctrl->waitForFPGA(timeoutMs);
}

// ---------------------------------------------------------------------------
// RGB LED helpers
// ---------------------------------------------------------------------------

void PapilioHdmi::setLEDColor(uint32_t color) {
    if (_ctrl) _ctrl->setLEDColor(color);
}

void PapilioHdmi::setLEDColorRGB(uint8_t red, uint8_t green, uint8_t blue) {
    if (_ctrl) _ctrl->setLEDColorRGB(red, green, blue);
}
