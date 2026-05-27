#include "ldr_sensor.h"
#include "../mqtt/mqtt_client.h"

LdrSensor::LdrSensor(Config cfg) : SensorBase(cfg) {}

bool LdrSensor::begin() {
  // Override interval from backend params if provided
  if (_cfg.params.containsKey("interval_ms")) {
    _intervalMs = _cfg.params["interval_ms"].as<uint32_t>();
    if (_intervalMs < 500) _intervalMs = 500; // floor 500 ms
  }

  // ADC pins on ESP32: 32-39 are input-only, 0,2,4,12-15,25-27,34-39 are ADC capable.
  // We just configure INPUT — analogRead() works on any ADC pin.
  pinMode(_cfg.pin, INPUT);

  // Force immediate first read
  _lastRead = 0;

  Serial.printf("[LDR] begin on pin %d, interval=%ums\n", _cfg.pin, _intervalMs);
  return true;
}

void LdrSensor::update() {
  if (millis() - _lastRead < _intervalMs) return;
  _lastRead = millis();

  // Read raw ADC (12-bit: 0–4095)
  _rawValue = analogRead(_cfg.pin);

  // Voltage divider wiring: LDR to 3.3V, resistor to GND at ADC pin
  //   → More light = lower LDR resistance = higher voltage = higher ADC value
  // Lux estimate: log mapping tuned for typical indoor LDR + 10kΩ divider
  // Not a calibrated photometer — enough for "dark / dim / bright" automations.
  float ratio = static_cast<float>(_rawValue) / ADC_MAX; // 0.0 – 1.0
  // Map ratio to rough lux: 0 → 0 lux, 1.0 → 10000 lux (full sun)
  _lux = ratio * ratio * 10000.0f;

  _computeLevel();

  JsonDocument doc;
  JsonObject obj = doc.to<JsonObject>();
  toJson(obj);
  MqttClient::instance().publishSensorData(_cfg.sensorId, doc);

  Serial.printf("[LDR] pin=%d raw=%d light=%.1flux level=%s\n",
                _cfg.pin, _rawValue, _lux, _level.c_str());
}

void LdrSensor::toJson(JsonObject& out) {
  out["sensorId"]  = _cfg.sensorId;
  out["type"]      = "LDR";
  out["raw"]       = _rawValue;
  out["light"]     = _lux;   // matches backend dataField "light" (lux)
  out["level"]     = _level;
  out["timestamp"] = millis();
}

void LdrSensor::_computeLevel() {
  // Thresholds (raw ADC 0–4095):
  //   < 500  → dark  (night / blackout)
  //   < 1500 → dim   (indoor lamp, dusk)
  //   < 3000 → bright (daylight through window)
  //   ≥ 3000 → very_bright (direct sunlight / strong lamp)
  if      (_rawValue < 500)  _level = "dark";
  else if (_rawValue < 1500) _level = "dim";
  else if (_rawValue < 3000) _level = "bright";
  else                       _level = "very_bright";
}
