#include "ble_provisioning.h"
#include "../config/config.h"
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <ArduinoJson.h>
#include <WiFi.h>

// Standard Nordic UART Service UUIDs
#define BLE_SERVICE_UUID  "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
#define BLE_CHAR_RX_UUID  "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"  // App writes here
#define BLE_CHAR_TX_UUID  "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"  // ESP32 notifies here

#define WIFI_SCAN_MAX_RESULTS 15   // cap network list
#define BLE_NOTIFY_CHUNK_DELAY 20  // ms between chunks

static BleProvisioning::DoneCallback s_doneCb;
static BLECharacteristic* s_txChar        = nullptr;
static volatile bool       s_scanRequested = false;  // set from BLE task, consumed in loop()

// ── WiFi test state ───────────────────────────────────────────────────────────
struct WifiTestRequest { String ssid; String password; };
static volatile bool   s_wifiTestRequested  = false;
static WifiTestRequest s_wifiTestCredentials;

// ── BLE TX helpers ────────────────────────────────────────────────────────────

/// Send a string over BLE TX, chunked to fit the negotiated MTU.
static void bleNotify(const String& data) {
  if (!s_txChar) return;

  size_t mtu       = BLEDevice::getMTU();
  size_t chunkSize = (mtu > 3) ? (mtu - 3) : 20;
  size_t len       = data.length();
  size_t offset    = 0;

  while (offset < len) {
    size_t end    = min(offset + chunkSize, len);
    String chunk  = data.substring(offset, end);
    s_txChar->setValue(chunk.c_str());
    s_txChar->notify();
    offset = end;
    if (offset < len) delay(BLE_NOTIFY_CHUNK_DELAY);
  }
}

// ── WiFi scan (runs on main task via update()) ────────────────────────────────

static void doWifiScan() {
  Serial.println("[BLE] Starting WiFi scan…");

  WiFi.mode(WIFI_STA);
  int n = WiFi.scanNetworks(/*async=*/false, /*show_hidden=*/false);

  JsonDocument doc;
  doc["type"]        = "wifi_list";
  JsonArray networks = doc["networks"].to<JsonArray>();

  // Attach last boot error if present, then clear it
  Config& cfg = Config::instance();
  if (cfg.lastError.length() > 0) {
    doc["lastError"] = cfg.lastError;
    doc["lastSsid"]  = cfg.wifiSsid;
    cfg.lastError    = "";
    cfg.save();
  }

  if (n > 0) {
    int count = min(n, WIFI_SCAN_MAX_RESULTS);
    for (int i = 0; i < count; i++) {
      JsonObject net = networks.add<JsonObject>();
      net["ssid"] = WiFi.SSID(i);
      net["rssi"] = (int)WiFi.RSSI(i);
      net["auth"] = (int)WiFi.encryptionType(i);  // WIFI_AUTH_OPEN == 0
    }
    WiFi.scanDelete();
    Serial.printf("[BLE] WiFi scan done — %d networks\n", count);
  } else {
    Serial.println("[BLE] WiFi scan returned no results");
  }

  String output;
  serializeJson(doc, output);
  Serial.printf("[BLE] TX payload (%d bytes): %s\n", output.length(), output.c_str());
  bleNotify(output);
}

// ── WiFi test (runs on main task via update()) ────────────────────────────────
// Tries to connect to the given WiFi WITHOUT saving credentials to NVS.
// Sends result back via BLE TX so the app can validate before registering
// the device in the backend.

static void doWifiTest() {
  const String ssid = s_wifiTestCredentials.ssid;
  const String pass = s_wifiTestCredentials.password;
  Serial.printf("[BLE] WiFi test — connecting to: %s\n", ssid.c_str());

  WiFi.disconnect(true);
  delay(200);
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid.c_str(), pass.c_str());

  // 12 s timeout — short enough to keep BLE interference manageable
  const unsigned long TIMEOUT_MS = 12000UL;
  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < TIMEOUT_MS) {
    delay(200);
  }

  JsonDocument doc;
  doc["type"] = "wifi_test";
  if (WiFi.status() == WL_CONNECTED) {
    doc["status"] = "connected";
    doc["ip"]     = WiFi.localIP().toString();
    Serial.printf("[BLE] WiFi test OK — IP: %s\n", WiFi.localIP().toString().c_str());
  } else {
    doc["status"] = "failed";
    Serial.println("[BLE] WiFi test FAILED (wrong password or SSID unreachable)");
  }

  // Always release the radio after test
  WiFi.disconnect(true);
  delay(200);

  String output;
  serializeJson(doc, output);
  Serial.printf("[BLE] TX wifi_test: %s\n", output.c_str());
  bleNotify(output);
}

// ── Provision handler (safe to run from BLE task — just NVS write + reboot) ──

static void doProvision(const JsonDocument& doc) {
  Config& cfg      = Config::instance();
  cfg.wifiSsid     = doc["ssid"].as<String>();
  cfg.wifiPassword = doc["password"].as<String>();
  cfg.mqttBroker   = doc["mqttBroker"].as<String>();
  cfg.deviceId     = doc["deviceId"].as<String>();
  cfg.save();

  Serial.println("[BLE] Provisioned — rebooting");
  if (s_doneCb) s_doneCb();
  delay(500);
  ESP.restart();
}

// ── BLE RX callback ───────────────────────────────────────────────────────────

class ProvisionCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* c) override {
    String data = c->getValue().c_str();
    Serial.printf("[BLE] RX: %s\n", data.c_str());

    JsonDocument doc;
    if (deserializeJson(doc, data) != DeserializationError::Ok) {
      Serial.println("[BLE] Invalid JSON — ignored");
      return;
    }

    const char* cmd = doc["cmd"] | "";

    if (strcmp(cmd, "scan_wifi") == 0) {
      // Defer to main task — WiFi scan must not run on the BLE task
      s_scanRequested = true;

    } else if (strcmp(cmd, "test_wifi") == 0) {
      // Test credentials WITHOUT saving to NVS — deferred to main task
      s_wifiTestCredentials.ssid     = doc["ssid"].as<String>();
      s_wifiTestCredentials.password = doc["password"].as<String>();
      s_wifiTestRequested = true;

    } else if (strcmp(cmd, "provision") == 0 || doc["ssid"].is<const char*>()) {
      // "provision" cmd OR legacy format (no cmd field, has ssid)
      doProvision(doc);

    } else {
      Serial.printf("[BLE] Unknown cmd: '%s'\n", cmd);
    }
  }
};

// ── Public API ────────────────────────────────────────────────────────────────

void BleProvisioning::begin(const String& deviceName) {
  s_doneCb = _doneCb;

  BLEDevice::init(deviceName.c_str());
  BLEServer*  server = BLEDevice::createServer();
  BLEService* svc    = server->createService(BLE_SERVICE_UUID);

  // RX: app → ESP32
  // PROPERTY_WRITE_NO_RESPONSE needed for provision cmd: ESP32 restarts before
  // sending the ATT Write Response, causing Android GATT_ERROR 133 on the app side.
  BLECharacteristic* rx = svc->createCharacteristic(
    BLE_CHAR_RX_UUID,
    BLECharacteristic::PROPERTY_WRITE | BLECharacteristic::PROPERTY_WRITE_NR
  );
  rx->setCallbacks(new ProvisionCallbacks());

  // TX: ESP32 → app (notify)
  s_txChar = svc->createCharacteristic(
    BLE_CHAR_TX_UUID,
    BLECharacteristic::PROPERTY_NOTIFY
  );
  s_txChar->addDescriptor(new BLE2902());

  svc->start();

  BLEAdvertising* adv = BLEDevice::getAdvertising();
  adv->addServiceUUID(BLE_SERVICE_UUID);
  adv->setScanResponse(true);
  BLEDevice::startAdvertising();

  Serial.printf("[BLE] Advertising as: %s\n", deviceName.c_str());
}

void BleProvisioning::stop() {
  BLEDevice::stopAdvertising();
}

void BleProvisioning::update() {
  if (s_scanRequested) {
    s_scanRequested = false;
    doWifiScan();
  }
  if (s_wifiTestRequested) {
    s_wifiTestRequested = false;
    doWifiTest();
  }
}
