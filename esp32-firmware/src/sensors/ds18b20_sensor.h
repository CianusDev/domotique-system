#pragma once
#include "sensor_base.h"
#include <OneWire.h>
#include <DallasTemperature.h>

class Ds18b20Sensor : public SensorBase {
public:
  explicit Ds18b20Sensor(Config cfg);
  bool begin() override;
  void update() override;
  void toJson(JsonObject& out) override;

private:
  OneWire*          _oneWire   = nullptr;
  DallasTemperature* _sensors  = nullptr;
  float _temperature = DEVICE_DISCONNECTED_C;
  unsigned long _lastRead = 0;
  static constexpr unsigned long READ_INTERVAL_MS = 1000;
};
