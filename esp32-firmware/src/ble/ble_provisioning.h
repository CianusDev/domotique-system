#pragma once
#include <Arduino.h>
#include <functional>

/**
 * BLE WiFi provisioning.
 * ESP32 advertises as "Domotique-XXXX".
 * App writes JSON: {"ssid":"...","password":"...","mqttBroker":"...","deviceId":"..."}
 * On receipt, saves to Config and reboots.
 */
class BleProvisioning {
public:
  using DoneCallback = std::function<void()>;

  void begin(const String& deviceName);
  void stop();
  void onProvisioningDone(DoneCallback cb) { _doneCb = cb; }

private:
  DoneCallback _doneCb;
};
