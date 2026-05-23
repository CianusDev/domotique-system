#pragma once
#include <Arduino.h>
#include <PubSubClient.h>
#include <WiFiClient.h>
#include <ArduinoJson.h>
#include <functional>

/**
 * Singleton MQTT client.
 * Topics follow: home/{deviceId}/...
 */
class MqttClient {
public:
  static MqttClient& instance();

  void begin(const String& deviceId, const String& broker, uint16_t port = 1883);
  void loop();
  bool connected();

  // Publish sensor reading: home/{deviceId}/sensors/{sensorId}/data
  void publishSensorData(const String& sensorId, const JsonDocument& doc);

  // Publish device status: home/{deviceId}/status
  void publishStatus(const String& status);

  // Publish sensor discovery: home/{deviceId}/sensors/discovery
  void publishDiscovery(const JsonDocument& doc);

  // Subscribe to add-sensor commands: home/{deviceId}/sensors/control/add
  using AddSensorCallback = std::function<void(const JsonObject&)>;
  void onAddSensor(AddSensorCallback cb) { _addSensorCb = cb; }

  // Subscribe to actuator commands: home/{deviceId}/actuators/+/cmd/state
  using ActuatorCallback = std::function<void(const String& type, const JsonObject&)>;
  void onActuator(ActuatorCallback cb) { _actuatorCb = cb; }

private:
  MqttClient() = default;
  void reconnect();
  void handleMessage(const char* topic, const uint8_t* payload, unsigned int len);
  static void staticCallback(char* topic, uint8_t* payload, unsigned int len);

  WiFiClient    _wifiClient;
  PubSubClient  _client{_wifiClient};
  String        _deviceId;
  String        _broker;
  uint16_t      _port = 1883;

  AddSensorCallback _addSensorCb;
  ActuatorCallback  _actuatorCb;
};
