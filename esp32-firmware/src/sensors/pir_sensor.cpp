#include "pir_sensor.h"
#include "../mqtt/mqtt_client.h"

PirSensor::PirSensor(Config cfg) : SensorBase(cfg) {}

bool PirSensor::begin() {
  pinMode(_cfg.pin, INPUT);
  return true;
}

void PirSensor::update() {
  bool state = digitalRead(_cfg.pin) == HIGH;

  // Publish only on state change
  if (state == _lastState) return;
  _lastState       = state;
  _motionDetected  = state;

  JsonDocument doc;
  JsonObject obj = doc.to<JsonObject>();
  toJson(obj);
  MqttClient::instance().publishSensorData(_cfg.sensorId, doc);
}

void PirSensor::toJson(JsonObject& out) {
  out["sensorId"] = _cfg.sensorId;
  out["type"]     = "PIR";
  out["motion"]   = _motionDetected;
  out["timestamp"] = millis();
}
