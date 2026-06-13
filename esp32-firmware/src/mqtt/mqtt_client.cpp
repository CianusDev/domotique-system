#include "mqtt_client.h"

#define MQTT_RECONNECT_PERIOD_MS 5000UL  // wait this long between failed reconnects

MqttClient& MqttClient::instance() {
  static MqttClient inst;
  return inst;
}

void MqttClient::begin(const String& deviceId, const String& broker, uint16_t port,
                       const String& user, const String& password) {
  _deviceId  = deviceId;
  _broker    = broker;
  _port      = port;
  _user      = user;
  _password  = password;
  _started   = true;

  _client.setServer(broker.c_str(), port);
  _client.setCallback(staticCallback);
  _client.setBufferSize(1024);
  // Short keepalive → broker detects unclean disconnect faster → LWT fires in ~7s
  // (broker waits 1.5 × keepalive before publishing "offline")
  _client.setKeepAlive(5);
}

void MqttClient::loop() {
  if (!_started) return;
  if (!_client.connected()) {
    // Non-blocking reconnect: only attempt every MQTT_RECONNECT_PERIOD_MS.
    // Old code used delay(5000) on failure, which froze sensors + actuators.
    if (millis() - _lastReconnectAttempt >= MQTT_RECONNECT_PERIOD_MS) {
      _lastReconnectAttempt = millis();
      tryReconnect();
    }
    return;
  }
  _client.loop();
}

bool MqttClient::connected() {
  return _started && _client.connected();
}

void MqttClient::tryReconnect() {
  Serial.print("[MQTT] Connecting...");
  String clientId = "esp32-" + _deviceId;

  const char* user = _user.isEmpty()     ? nullptr : _user.c_str();
  const char* pass = _password.isEmpty() ? nullptr : _password.c_str();

  bool ok = _client.connect(
    clientId.c_str(), user, pass,
    ("home/" + _deviceId + "/status").c_str(),
    0, true, "offline"
  );

  if (!ok) {
    Serial.printf(" failed (rc=%d), retry in %lus\n",
                  _client.state(), MQTT_RECONNECT_PERIOD_MS / 1000);
    return;
  }

  Serial.println(" connected");
  publishStatus("online");

  // Subscribe to add-sensor commands
  _client.subscribe(("home/" + _deviceId + "/sensors/control/add").c_str());
  // Subscribe to all actuator commands
  _client.subscribe(("home/" + _deviceId + "/actuators/+/cmd/state").c_str());
  // Subscribe to factory-reset command (sent by backend when device is deleted)
  _client.subscribe(("home/" + _deviceId + "/cmd/factory-reset").c_str());
}

// Publish "offline" cleanly before a planned reboot (factory reset, OTA, etc).
// Without this, the broker would have to wait for the LWT timeout (~7s).
void MqttClient::publishOfflineAndDisconnect() {
  if (!_started || !_client.connected()) return;
  publishStatus("offline");
  _client.loop();      // flush outgoing
  delay(100);
  _client.disconnect();
}

void MqttClient::publishSensorData(const String& sensorId, const JsonDocument& doc) {
  if (!_client.connected()) return;
  String topic = "home/" + _deviceId + "/sensors/" + sensorId + "/data";
  String payload;
  serializeJson(doc, payload);
  _client.publish(topic.c_str(), payload.c_str(), false);
}

void MqttClient::publishStatus(const String& status) {
  if (!_client.connected()) return;
  String topic = "home/" + _deviceId + "/status";
  _client.publish(topic.c_str(), status.c_str(), true); // retained
}

void MqttClient::publishDiscovery(const JsonDocument& doc) {
  if (!_client.connected()) return;
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
    Serial.println("[MQTT] Factory-reset command received");
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
    int start = ("home/" + _deviceId + "/actuators/").length();
    int end   = t.indexOf("/cmd/state");
    if (end > start) {
      String actuatorType = t.substring(start, end);
      if (_actuatorCb) _actuatorCb(actuatorType, doc.as<JsonObject>());
    }
  }
}
