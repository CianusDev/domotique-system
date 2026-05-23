#pragma once
#include <Arduino.h>
#include <ArduinoJson.h>
#include <map>
#include <memory>
#include "sensor_base.h"

/**
 * Manages all active sensor instances.
 * Sensors are registered dynamically via MQTT command (no reflash needed).
 */
class SensorManager {
public:
  // Add sensor from MQTT JSON command: {sensorId, type, pin, params}
  // Returns false if type unknown or pin conflict
  bool addSensor(const JsonObject& cmd);

  // Remove sensor by ID
  bool removeSensor(const String& sensorId);

  // Called every loop()
  void update();

  // Check if pin already in use
  bool isPinTaken(uint8_t pin) const;

  size_t count() const { return _sensors.size(); }

private:
  std::map<String, std::unique_ptr<SensorBase>> _sensors;
};
