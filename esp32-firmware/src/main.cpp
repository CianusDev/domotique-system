#include <Arduino.h>
#include <WiFi.h>
#include <ArduinoOTA.h>
#include <HTTPClient.h>

#include "config/config.h"
#include "ble/ble_provisioning.h"
#include "mqtt/mqtt_client.h"
#include "sensors/sensor_manager.h"

static SensorManager sensorManager;
static BleProvisioning bleProvisioning;

#define PIN_LED_BUILTIN 2  // Built-in blue LED on most ESP32 DevKit boards

// ──────────────────────────────────────────────
// Connectivity check (captive portal detection)
// ──────────────────────────────────────────────

/// Returns true if behind a captive portal (no real internet).
/// Hits Google's 204 endpoint — expects HTTP 204, anything else = portal.
static bool hasCaptivePortal() {
  HTTPClient http;
  http.setFollowRedirects(HTTPC_DISABLE_FOLLOW_REDIRECTS);
  http.setTimeout(5000);

  if (!http.begin("http://connectivitycheck.gstatic.com/generate_204")) {
    http.end();
    Serial.println("[WiFi] Connectivity check: failed to init HTTP");
    return true; // assume portal if we can't even reach it
  }

  int code = http.GET();
  http.end();
  Serial.printf("[WiFi] Connectivity check: HTTP %d\n", code);

  return code != HTTP_CODE_NO_CONTENT; // 204 = internet OK = no portal
}

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

    JsonDocument discovery;
    discovery["sensorId"] = cmd["sensorId"].as<String>();
    discovery["status"]   = ok ? "added" : "error";
    discovery["type"]     = cmd["type"].as<String>();
    MqttClient::instance().publishDiscovery(discovery);
  });

  MqttClient::instance().onActuator([](const String& type, const JsonObject& cmd) {
    String command = cmd["command"].as<String>();
    Serial.printf("[Actuator] type=%s command=%s\n", type.c_str(), command.c_str());

    if (type == "led") {
      bool on;
      if      (command == "on")     on = true;
      else if (command == "off")    on = false;
      else if (command == "toggle") on = !digitalRead(PIN_LED_BUILTIN);
      else return;

      digitalWrite(PIN_LED_BUILTIN, on ? HIGH : LOW);
      Serial.printf("[Actuator] LED %s\n", on ? "ON" : "OFF");
    }
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

  pinMode(PIN_LED_BUILTIN, OUTPUT);
  digitalWrite(PIN_LED_BUILTIN, LOW);

  connectWifi();

  if (WiFi.status() == WL_CONNECTED) {
    if (hasCaptivePortal()) {
      Serial.println("[WiFi] Captive portal detected — falling back to BLE mode");
      cfg.lastError = "captive_portal";
      cfg.save();
      bleProvisioning.begin("Domotique-" + WiFi.macAddress().substring(9));
      return; // loop() will handle BLE + update()
    }

    setupOTA();
    MqttClient::instance().begin(cfg.deviceId, cfg.mqttBroker, cfg.mqttPort);
    setupMqttCallbacks();
  }
}

void loop() {
  // BLE mode: process deferred commands (e.g. WiFi scan) on the main task
  bleProvisioning.update();

  if (WiFi.status() == WL_CONNECTED) {
    ArduinoOTA.handle();
    MqttClient::instance().loop();
    sensorManager.update();
  }
  delay(10);
}
