#include "ble_provisioning.h"
#include "../config/config.h"
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <ArduinoJson.h>

// Standard Nordic UART Service UUIDs
#define BLE_SERVICE_UUID        "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"
#define BLE_CHAR_RX_UUID        "6E400002-B5A3-F393-E0A9-E50E24DCCA9E" // App writes here
#define BLE_CHAR_TX_UUID        "6E400003-B5A3-F393-E0A9-E50E24DCCA9E" // ESP32 notifies here

static BleProvisioning::DoneCallback s_doneCb;

class ProvisionCallbacks : public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic* c) override {
    String data = c->getValue().c_str();
    Serial.printf("[BLE] Received: %s\n", data.c_str());

    JsonDocument doc;
    if (deserializeJson(doc, data) != DeserializationError::Ok) {
      Serial.println("[BLE] Invalid JSON");
      return;
    }

    Config& cfg = Config::instance();
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
};

void BleProvisioning::begin(const String& deviceName) {
  s_doneCb = _doneCb;
  BLEDevice::init(deviceName.c_str());
  BLEServer* server = BLEDevice::createServer();
  BLEService* svc   = server->createService(BLE_SERVICE_UUID);

  BLECharacteristic* rx = svc->createCharacteristic(
    BLE_CHAR_RX_UUID,
    BLECharacteristic::PROPERTY_WRITE
  );
  rx->setCallbacks(new ProvisionCallbacks());

  BLECharacteristic* tx = svc->createCharacteristic(
    BLE_CHAR_TX_UUID,
    BLECharacteristic::PROPERTY_NOTIFY
  );
  tx->addDescriptor(new BLE2902());

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
