#include <Arduino.h>
#include <WiFi.h>
#include <ArduinoOTA.h>

#include "config/config.h"
#include "ble/ble_provisioning.h"
#include "mqtt/mqtt_client.h"
#include "sensors/sensor_manager.h"

static SensorManager sensorManager;
static BleProvisioning bleProvisioning;

// ──────────────────────────────────────────────
// WiFi
// ──────────────────────────────────────────────
void connectWifi() {
  Config& cfg = Config::instance();
  Serial.printf("[WiFi] Connecting to %s...\n", cfg.wifiSsid.c_str());
  WiFi.begin(cfg.wifiSsid.c_str(), cfg.wifiPassword.c_str());

  uint8_t attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.printf("\n[WiFi] Connected — IP: %s\n", WiFi.localIP().toString().c_str());
  } else {
    Serial.println("\n[WiFi] Failed — entering BLE provisioning mode");
    bleProvisioning.begin("Domotique-" + WiFi.macAddress().substring(9));
  }
}

// ──────────────────────────────────────────────
// OTA
// ──────────────────────────────────────────────
void setupOTA() {
  ArduinoOTA.setHostname("domotique-esp32");
  ArduinoOTA.onStart([]() {
    Serial.println("[OTA] Starting update...");
  });
  ArduinoOTA.onEnd([]() {
    Serial.println("\n[OTA] Done");
  });
  ArduinoOTA.onError([](ota_error_t e) {
    Serial.printf("[OTA] Error[%u]\n", e);
  });
  ArduinoOTA.begin();
}

// ──────────────────────────────────────────────
// MQTT callbacks
// ──────────────────────────────────────────────
void setupMqttCallbacks() {
  MqttClient::instance().onAddSensor([](const JsonObject& cmd) {
    bool ok = sensorManager.addSensor(cmd);

    // Publish discovery confirmation
    JsonDocument discovery;
    discovery["sensorId"] = cmd["sensorId"].as<String>();
    discovery["status"]   = ok ? "added" : "error";
    discovery["type"]     = cmd["type"].as<String>();
    MqttClient::instance().publishDiscovery(discovery);
  });
}

// ──────────────────────────────────────────────
// setup / loop
// ──────────────────────────────────────────────
void setup() {
  Serial.begin(115200);
  Serial.println("\n[Boot] Domotique ESP32 firmware");

  Config& cfg = Config::instance();
  cfg.load();

  if (!cfg.isProvisioned()) {
    Serial.println("[Boot] Not provisioned — BLE mode");
    bleProvisioning.begin("Domotique-Setup");
    return; // loop will just handle BLE
  }

  connectWifi();

  if (WiFi.status() == WL_CONNECTED) {
    setupOTA();

    MqttClient::instance().begin(cfg.deviceId, cfg.mqttBroker, cfg.mqttPort);
    setupMqttCallbacks();
  }
}

void loop() {
  if (WiFi.status() == WL_CONNECTED) {
    ArduinoOTA.handle();
    MqttClient::instance().loop();
    sensorManager.update();
  }
  delay(10);
}
