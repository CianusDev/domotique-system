#include "ds18b20_sensor.h"
#include "../mqtt/mqtt_client.h"

Ds18b20Sensor::Ds18b20Sensor(Config cfg) : SensorBase(cfg) {}

bool Ds18b20Sensor::begin() {
  _oneWire  = new OneWire(_cfg.pin);
  _sensors  = new DallasTemperature(_oneWire);
  _sensors->begin();
  return _sensors->getDeviceCount() > 0;
}

void Ds18b20Sensor::update() {
  if (millis() - _lastRead < READ_INTERVAL_MS) return;
  _lastRead = millis();

  _sensors->requestTemperatures();
  float t = _sensors->getTempCByIndex(0);

  if (t == DEVICE_DISCONNECTED_C) {
    Serial.printf("[DS18B20] Disconnected on pin %d\n", _cfg.pin);
    return;
  }

  _temperature = t;

  JsonDocument doc;
  JsonObject obj = doc.to<JsonObject>();
  toJson(obj);
  MqttClient::instance().publishSensorData(_cfg.sensorId, doc);
}

void Ds18b20Sensor::toJson(JsonObject& out) {
  out["sensorId"]    = _cfg.sensorId;
  out["type"]        = "DS18B20";
  out["temperature"] = _temperature;
  out["timestamp"]   = millis();
}
