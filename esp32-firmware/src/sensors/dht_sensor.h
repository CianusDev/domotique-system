#pragma once
#include "sensor_base.h"
#include <DHT.h>

class DhtSensor : public SensorBase {
public:
  explicit DhtSensor(Config cfg);
  bool begin() override;
  void update() override;
  void toJson(JsonObject& out) override;

private:
  DHT* _dht = nullptr;
  float _temperature = NAN;
  float _humidity    = NAN;
  unsigned long _lastRead = 0;
  static constexpr unsigned long READ_INTERVAL_MS = 2000;
};
