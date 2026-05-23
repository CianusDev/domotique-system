#pragma once
#include "sensor_base.h"

class PirSensor : public SensorBase {
public:
  explicit PirSensor(Config cfg);
  bool begin() override;
  void update() override;
  void toJson(JsonObject& out) override;

private:
  bool _lastState  = false;
  bool _motionDetected = false;
};
