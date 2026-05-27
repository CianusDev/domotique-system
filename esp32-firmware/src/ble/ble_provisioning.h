#pragma once
#include <Arduino.h>
#include <functional>

/**
 * BLE WiFi provisioning — Nordic UART Service (NUS).
 *
 * Protocol (app → ESP32 via RX char):
 *   {"cmd":"scan_wifi"}
 *       → ESP32 scans WiFi, responds on TX:
 *         {"type":"wifi_list","networks":[{"ssid":"…","rssi":-65,"auth":3}]}
 *         auth: 0=OPEN, 1=WEP, 2=WPA_PSK, 3=WPA2_PSK, 4=WPA_WPA2_PSK
 *
 *   {"cmd":"provision","ssid":"…","password":"…","mqttBroker":"…","deviceId":"…"}
 *       → saves to NVS, reboots
 *
 * Legacy format (no cmd field) also supported for backward compat:
 *   {"ssid":"…","password":"…","mqttBroker":"…","deviceId":"…"}
 */
class BleProvisioning {
public:
  using DoneCallback = std::function<void()>;

  void begin(const String& deviceName);
  void stop();

  /// Call from loop() — processes deferred WiFi scan off the BLE task
  void update();

  void onProvisioningDone(DoneCallback cb) { _doneCb = cb; }

  bool started() const { return _started; }

private:
  DoneCallback _doneCb;
  bool         _started = false;
};
