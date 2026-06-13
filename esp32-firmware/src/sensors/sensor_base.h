#pragma once
#include <Arduino.h>
#include <ArduinoJson.h>

/**
 * Abstract base class for all sensor plugins.
 * Add a new sensor type by subclassing and implementing the 3 pure virtuals.
 */
class SensorBase {
public:
  struct Config {
    String sensorId;   // UUID from backend
    String type;       // e.g. "DHT22", "PIR", "DS18B20"
    uint8_t pin;       // GPIO pin
  };

  explicit SensorBase(Config cfg) : _cfg(cfg) {}
  virtual ~SensorBase() = default;

  // Called once after construction. params is valid only during this call —
  // do NOT store the reference; extract what you need before returning.
  virtual bool begin(const JsonObject& params) = 0;

  // Called on each loop tick — publishes to MQTT if data ready
  virtual void update() = 0;

  // Serialize latest reading to JSON
  virtual void toJson(JsonObject& out) = 0;

  const String& id()   const { return _cfg.sensorId; }
  const String& type() const { return _cfg.type; }
  uint8_t       pin()  const { return _cfg.pin; }

protected:
  Config _cfg;
};
