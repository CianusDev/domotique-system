#include "dht_sensor.h"
#include "../mqtt/mqtt_client.h"

DhtSensor::DhtSensor(Config cfg) : SensorBase(cfg) {}

bool DhtSensor::begin() {
  uint8_t dhtType = (_cfg.type == "DHT11") ? DHT11 : DHT22;
  _dht = new DHT(_cfg.pin, dhtType);
  _dht->begin();
  return true;
}

void DhtSensor::update() {
  if (millis() - _lastRead < READ_INTERVAL_MS) return;
  _lastRead = millis();

  float t = _dht->readTemperature();
  float h = _dht->readHumidity();

  if (isnan(t) || isnan(h)) {
    Serial.printf("[DHT] Read failed on pin %d\n", _cfg.pin);
    return;
  }

  _temperature = t;
  _humidity    = h;

  // Publish to MQTT: home/{deviceId}/sensors/{sensorId}/data
  JsonDocument doc;
  JsonObject obj = doc.to<JsonObject>();
  toJson(obj);
  MqttClient::instance().publishSensorData(_cfg.sensorId, doc);
}

void DhtSensor::toJson(JsonObject& out) {
  out["sensorId"]    = _cfg.sensorId;
  out["type"]        = _cfg.type;
  out["temperature"] = _temperature;
  out["humidity"]    = _humidity;
  out["timestamp"]   = millis();
}
