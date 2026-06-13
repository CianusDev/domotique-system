#pragma once
#include "sensor_base.h"

/**
 * LDR (Light Dependent Resistor) sensor driver.
 *
 * Wiring (voltage divider):
 *   3.3V ── LDR ── pin ── 10kΩ ── GND
 *
 * Reads ADC (0–4095) every READ_INTERVAL_MS.
 * Publishes: raw ADC value + estimated lux + light level label.
 *
 * Optional params (from backend):
 *   params["interval_ms"]   — override read interval (default 5000 ms)
 *   params["adc_max"]       — override ADC full scale (default 4095, 12-bit)
 */
class LdrSensor : public SensorBase {
public:
  static constexpr uint32_t DEFAULT_INTERVAL_MS = 2000;
  static constexpr uint16_t ADC_MAX             = 4095;

  explicit LdrSensor(Config cfg);
  bool begin(const JsonObject& params)  override;
  void update() override;
  void toJson(JsonObject& out) override;

private:
  uint32_t _intervalMs  = DEFAULT_INTERVAL_MS;
  uint32_t _lastRead    = 0;
  int      _rawValue    = 0;

  // Voltage-divider: high ADC = more light (LDR resistance drops)
  // Rough lux estimate — good enough for home automation triggers
  float    _lux         = 0.0f;
  String   _level;          // "dark" | "dim" | "bright" | "very_bright"

  void _computeLevel();
};
