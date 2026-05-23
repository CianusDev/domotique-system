#pragma once
#include <Arduino.h>
#include <Preferences.h>

/**
 * Persistent config stored in ESP32 NVS (non-volatile storage).
 * WiFi credentials, MQTT broker, device ID.
 */
class Config {
public:
  static Config& instance();

  void load();
  void save();
  void reset();

  // WiFi
  String wifiSsid;
  String wifiPassword;

  // MQTT
  String mqttBroker;
  uint16_t mqttPort = 1883;

  // Device identity
  String deviceId; // UUID assigned by backend

  bool isProvisioned() const {
    return !wifiSsid.isEmpty() && !deviceId.isEmpty();
  }

private:
  Config() = default;
  Preferences _prefs;
  static constexpr const char* NVS_NS = "domotique";
};
