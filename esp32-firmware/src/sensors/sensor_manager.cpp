#include "sensor_manager.h"
#include "dht_sensor.h"
#include "pir_sensor.h"
#include "ds18b20_sensor.h"

bool SensorManager::addSensor(const JsonObject& cmd) {
  String sensorId = cmd["sensorId"].as<String>();
  String type     = cmd["type"].as<String>();
  uint8_t pin     = cmd["pin"].as<uint8_t>();

  if (sensorId.isEmpty() || type.isEmpty()) return false;
  if (_sensors.count(sensorId)) return false; // already exists
  if (isPinTaken(pin)) {
    Serial.printf("[SensorManager] Pin %d already in use\n", pin);
    return false;
  }

  SensorBase::Config cfg;
  cfg.sensorId = sensorId;
  cfg.type     = type;
  cfg.pin      = pin;
  // params are optional extra config
  if (cmd["params"].is<JsonObject>()) {
    cfg.params = cmd["params"].as<JsonObject>();
  }

  std::unique_ptr<SensorBase> sensor;

  if      (type == "DHT22")   sensor = std::make_unique<DhtSensor>(cfg);
  else if (type == "DHT11")   sensor = std::make_unique<DhtSensor>(cfg);
  else if (type == "PIR")     sensor = std::make_unique<PirSensor>(cfg);
  else if (type == "DS18B20") sensor = std::make_unique<Ds18b20Sensor>(cfg);
  else {
    Serial.printf("[SensorManager] Unknown sensor type: %s\n", type.c_str());
    return false;
  }

  if (!sensor->begin()) {
    Serial.printf("[SensorManager] begin() failed for %s on pin %d\n", type.c_str(), pin);
    return false;
  }

  _sensors[sensorId] = std::move(sensor);
  Serial.printf("[SensorManager] Added %s (id=%s, pin=%d)\n", type.c_str(), sensorId.c_str(), pin);
  return true;
}

bool SensorManager::removeSensor(const String& sensorId) {
  return _sensors.erase(sensorId) > 0;
}

void SensorManager::update() {
  for (auto& [id, sensor] : _sensors) {
    sensor->update();
  }
}

bool SensorManager::isPinTaken(uint8_t pin) const {
  for (auto& [id, sensor] : _sensors) {
    if (sensor->pin() == pin) return true;
  }
  return false;
}
