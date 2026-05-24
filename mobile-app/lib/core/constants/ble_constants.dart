/// BLE UUIDs matching esp32-firmware/src/ble/ble_provisioning.cpp
/// Nordic UART Service (NUS)
class BleConstants {
  static const String serviceUuid = '6e400001-b5a3-f393-e0a9-e50e24dcca9e';
  static const String rxCharUuid  = '6e400002-b5a3-f393-e0a9-e50e24dcca9e'; // app writes
  static const String txCharUuid  = '6e400003-b5a3-f393-e0a9-e50e24dcca9e'; // esp32 notifies

  /// ESP32 advertises with this prefix
  static const String deviceNamePrefix = 'Domotique-';
}
