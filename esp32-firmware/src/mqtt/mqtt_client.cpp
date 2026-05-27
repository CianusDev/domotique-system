#include "mqtt_client.h"

MqttClient& MqttClient::instance() {
  static MqttClient inst;
  return inst;
}

void MqttClient::begin(const String& deviceId, const String& broker, uint16_t port) {
  _deviceId = deviceId;
  _broker   = broker;
  _port     = port;

  _client.setServer(broker.c_str(), port);
  _client.setCallback(staticCallback);
  _client.setBufferSize(1024);
}

void MqttClient::loop() {
  if (!_client.connected()) reconnect();
  _client.loop();
}

bool MqttClient::connected() {
  return _client.connected();
}

void MqttClient::reconnect() {
  if (_client.connected()) return;

  Serial.print("[MQTT] Connecting...");
  String clientId = "esp32-" + _deviceId;

  if (_client.connect(clientId.c_str(), nullptr, nullptr,
                      ("home/" + _deviceId + "/status").c_str(),
                      0, true, "offline")) {
    Serial.println(" connected");
    publishStatus("online");

    // Subscribe to add-sensor commands
    _client.subscribe(("home/" + _deviceId + "/sensors/control/add").c_str());
    // Subscribe to all actuator commands
    _client.subscribe(("home/" + _deviceId + "/actuators/+/cmd/state").c_str());
    // Subscribe to factory-reset command (sent by backend when device is deleted)
    _client.subscribe(("home/" + _deviceId + "/cmd/factory-reset").c_str());
  } else {
    Serial.printf(" failed (rc=%d), retry in 5s\n", _client.state());
    delay(5000);
  }
}

void MqttClient::publishSensorData(const String& sensorId, const JsonDocument& doc) {
  String topic = "home/" + _deviceId + "/sensors/" + sensorId + "/data";
  String payload;
  serializeJson(doc, payload);
  _client.publish(topic.c_str(), payload.c_str(), false);
}

void MqttClient::publishStatus(const String& status) {
  String topic = "home/" + _deviceId + "/status";
  _client.publish(topic.c_str(), status.c_str(), true); // retained
}

void MqttClient::publishDiscovery(const JsonDocument& doc) {
  String topic = "home/" + _deviceId + "/sensors/discovery";
  String payload;
  serializeJson(doc, payload);
  _client.publish(topic.c_str(), payload.c_str(), false);
}

void MqttClient::staticCallback(char* topic, uint8_t* payload, unsigned int len) {
  instance().handleMessage(topic, payload, len);
}

void MqttClient::handleMessage(const char* topic, const uint8_t* payload, unsigned int len) {
  String t(topic);

  // Factory-reset: home/{deviceId}/cmd/factory-reset
  // Check this FIRST (before JSON parse — payload is plain text, not JSON)
  if (t == "home/" + _deviceId + "/cmd/factory-reset") {
    Serial.println("[MQTT] Factory-reset command received — clearing NVS and restarting");
    if (_factoryResetCb) _factoryResetCb();
    return;
  }

  JsonDocument doc;
  DeserializationError err = deserializeJson(doc, payload, len);
  if (err) {
    Serial.printf("[MQTT] JSON parse error: %s\n", err.c_str());
    return;
  }

  String addTopic = "home/" + _deviceId + "/sensors/control/add";

  if (t == addTopic) {
    if (_addSensorCb) _addSensorCb(doc.as<JsonObject>());
    return;
  }

  // Actuator: home/{deviceId}/actuators/{type}/cmd/state
  if (t.startsWith("home/" + _deviceId + "/actuators/")) {
    // Extract type from topic
    int start = ("home/" + _deviceId + "/actuators/").length();
    int end   = t.indexOf("/cmd/state");
    if (end > start) {
      String actuatorType = t.substring(start, end);
      if (_actuatorCb) _actuatorCb(actuatorType, doc.as<JsonObject>());
    }
  }
}
