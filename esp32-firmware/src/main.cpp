#include <Arduino.h>
#include <WiFi.h>
#include <ArduinoOTA.h>

#include "config/config.h"
#include "ble/ble_provisioning.h"
#include "mqtt/mqtt_client.h"
#include "sensors/sensor_manager.h"
#include "wifi/wifi_check.h"

static SensorManager   sensorManager;
static BleProvisioning bleProvisioning;

#define PIN_LED_BUILTIN          2  // Built-in blue LED on most ESP32 DevKit boards

#define WIFI_INITIAL_TIMEOUT_MS  10000UL  // first connect attempt: 10s before falling back to BLE
#define WIFI_RECONNECT_PERIOD_MS 15000UL  // background reconnect attempts every 15s

// ── App state ────────────────────────────────────────────────────────────────
// Simple state machine for clarity. Transitions are linear except WIFI_ONLINE
// can drop back to WIFI_RECONNECTING (and back) without going through BLE.

enum class AppState {
  Booting,           // initial, before setup runs
  BleProvisioning,   // BLE only — not provisioned, captive portal, or WiFi failed
  WifiConnecting,    // attempting first connection (blocking, in setup())
  WifiOnline,        // connected, MQTT running
  WifiReconnecting,  // dropped connection, trying to recover
};

static AppState      g_state                = AppState::Booting;
static unsigned long g_lastWifiCheck        = 0;
static bool          g_mqttBegun            = false;
static bool          g_otaBegun             = false;

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

static void enterBleMode(const String& reason) {
  Serial.printf("[State] Entering BLE provisioning mode (%s)\n", reason.c_str());
  WiFi.disconnect(false);
  WiFi.mode(WIFI_OFF);
  delay(100);
  bleProvisioning.begin("Domotique-" + WiFi.macAddress().substring(9));
  g_state = AppState::BleProvisioning;
}

// Blocking WiFi connect with a hard timeout. Used only at boot — once we're up,
// reconnects are handled non-blockingly in loop().
static bool blockingConnectWifi(unsigned long timeoutMs) {
  Config& cfg = Config::instance();
  Serial.printf("[WiFi] Connecting to %s...\n", cfg.wifiSsid.c_str());

  WiFi.persistent(false);        // don't double-save credentials to ESP32 NVS
  WiFi.setAutoReconnect(true);   // let the SDK retry transient drops in background
  WiFi.mode(WIFI_STA);
  WiFi.begin(cfg.wifiSsid.c_str(), cfg.wifiPassword.c_str());

  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < timeoutMs) {
    delay(250);
    Serial.print(".");
  }
  Serial.println();

  if (WiFi.status() == WL_CONNECTED) {
    Serial.printf("[WiFi] Connected — IP: %s\n", WiFi.localIP().toString().c_str());
    return true;
  }
  Serial.println("[WiFi] Failed to connect within timeout");
  return false;
}

// ─────────────────────────────────────────────────────────────────────────────
// OTA
// ─────────────────────────────────────────────────────────────────────────────

static void setupOTA() {
  if (g_otaBegun) return;
  ArduinoOTA.setHostname("domotique-esp32");
  ArduinoOTA.onStart([]() { Serial.println("[OTA] Starting update..."); });
  ArduinoOTA.onEnd  ([]() { Serial.println("\n[OTA] Done"); });
  ArduinoOTA.onError([](ota_error_t e) { Serial.printf("[OTA] Error[%u]\n", e); });
  ArduinoOTA.begin();
  g_otaBegun = true;
}

// ─────────────────────────────────────────────────────────────────────────────
// MQTT callbacks
// ─────────────────────────────────────────────────────────────────────────────

static void setupMqttCallbacks() {
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
      else { Serial.println("[Actuator] Unknown LED command"); return; }

      digitalWrite(PIN_LED_BUILTIN, on ? HIGH : LOW);
      Serial.printf("[Actuator] LED %s\n", on ? "ON" : "OFF");
    } else {
      Serial.printf("[Actuator] Unsupported type: %s\n", type.c_str());
    }
  });

  // Factory-reset: backend deleted this device from the app.
  // Publish "offline" cleanly, clear NVS, restart into BLE provisioning.
  MqttClient::instance().onFactoryReset([]() {
    Serial.println("[FactoryReset] Erasing config + restarting...");
    MqttClient::instance().publishOfflineAndDisconnect();
    Config::instance().reset();
    delay(500);
    ESP.restart();
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// State-specific bring-up
// ─────────────────────────────────────────────────────────────────────────────

// Called once we have a verified, non-captive WiFi connection.
static void enterOnlineMode() {
  if (!g_mqttBegun) {
    Config& cfg = Config::instance();
    MqttClient::instance().begin(cfg.deviceId, cfg.mqttBroker, cfg.mqttPort);
    setupMqttCallbacks();
    g_mqttBegun = true;
  }
  setupOTA();
  g_state = AppState::WifiOnline;
  Serial.println("[State] WiFi online");
}

// ─────────────────────────────────────────────────────────────────────────────
// setup / loop
// ─────────────────────────────────────────────────────────────────────────────

void setup() {
  Serial.begin(115200);
  Serial.println("\n[Boot] Domotique ESP32 firmware");

  Config& cfg = Config::instance();
  cfg.load();

  pinMode(PIN_LED_BUILTIN, OUTPUT);
  digitalWrite(PIN_LED_BUILTIN, LOW);

  if (!cfg.isProvisioned()) {
    Serial.println("[Boot] Not provisioned");
    enterBleMode("not provisioned");
    return;
  }

  g_state = AppState::WifiConnecting;
  if (!blockingConnectWifi(WIFI_INITIAL_TIMEOUT_MS)) {
    enterBleMode("WiFi connect timeout");
    return;
  }

  // Check captive portal — if we're behind one, MQTT will never reach the
  // broker over the internet (still works for local LAN brokers, but most
  // captive portals also block local subnets).
  ConnectivityResult conn = checkConnectivity();
  if (conn == ConnectivityResult::CaptivePortal) {
    Serial.println("[Boot] Captive portal detected");
    cfg.lastError = "captive_portal";
    cfg.save();
    enterBleMode("captive portal");
    return;
  }

  enterOnlineMode();
}

// Monitor WiFi state in loop(). The SDK auto-reconnect handles transient blips,
// but we also explicitly re-trigger WiFi.begin() if it stays down too long.
static void monitorWifi() {
  if (millis() - g_lastWifiCheck < 2000) return;  // throttle to every 2s
  g_lastWifiCheck = millis();

  const bool up = (WiFi.status() == WL_CONNECTED);

  if (g_state == AppState::WifiOnline && !up) {
    Serial.println("[WiFi] Connection lost — entering reconnect state");
    g_state = AppState::WifiReconnecting;
  } else if (g_state == AppState::WifiReconnecting && up) {
    Serial.printf("[WiFi] Reconnected — IP: %s\n", WiFi.localIP().toString().c_str());
    g_state = AppState::WifiOnline;
  } else if (g_state == AppState::WifiReconnecting) {
    // Kick the radio every 15s if SDK auto-reconnect hasn't recovered
    static unsigned long lastKick = 0;
    if (millis() - lastKick >= WIFI_RECONNECT_PERIOD_MS) {
      lastKick = millis();
      Config& cfg = Config::instance();
      Serial.println("[WiFi] Re-issuing WiFi.begin()");
      WiFi.disconnect(false);
      WiFi.begin(cfg.wifiSsid.c_str(), cfg.wifiPassword.c_str());
    }
  }
}

void loop() {
  // BLE mode: process deferred commands (WiFi scan / test). Always called —
  // safe no-op if BLE not started.
  bleProvisioning.update();

  switch (g_state) {
    case AppState::WifiOnline:
      ArduinoOTA.handle();
      MqttClient::instance().loop();
      sensorManager.update();
      monitorWifi();
      break;

    case AppState::WifiReconnecting:
      monitorWifi();
      break;

    case AppState::BleProvisioning:
    case AppState::WifiConnecting:
    case AppState::Booting:
    default:
      // Nothing to do — BLE provisioning is the only active subsystem.
      break;
  }

  delay(10);
}
