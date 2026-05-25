/// BLE UUIDs matching esp32-firmware/src/ble/ble_provisioning.cpp
/// Nordic UART Service (NUS)
class BleConstants {
  static const String serviceUuid = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
  static const String rxCharUuid  = '6e400002-b5a3-f393-e0a9-e50e24dcca9e'; // app writes
  static const String txCharUuid  = '6e400003-b5a3-f393-e0a9-e50e24dcca9e'; // esp32 notifies

  /// ESP32 advertises with this prefix
  static const String deviceNamePrefix = 'Domotique-';

  // ── BLE commands (app → ESP32 via RX char) ────────────────────────────────
  /// Request WiFi scan. ESP32 responds on TX: {"type":"wifi_list","networks":[…]}
  static const String cmdScanWifi = '{"cmd":"scan_wifi"}';

  // ── BLE response types (ESP32 → app via TX char) ──────────────────────────
  /// wifi_list response: {"type":"wifi_list","networks":[{"ssid":"…","rssi":-65,"auth":3}]}
  /// auth=0 → OPEN, auth≥1 → secured (WEP/WPA/WPA2/WPA3)
  static const String responseWifiList = 'wifi_list';
}
