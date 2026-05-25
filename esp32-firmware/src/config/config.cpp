#include "config.h"

Config& Config::instance() {
  static Config inst;
  return inst;
}

void Config::load() {
  _prefs.begin(NVS_NS, true); // read-only
  wifiSsid     = _prefs.getString("ssid",      "");
  wifiPassword = _prefs.getString("wifi_pass", "");
  mqttBroker   = _prefs.getString("mqtt_host", "");
  mqttPort     = _prefs.getUShort("mqtt_port", 1883);
  deviceId     = _prefs.getString("device_id", "");
  lastError    = _prefs.getString("last_err",  "");
  _prefs.end();
}

void Config::save() {
  _prefs.begin(NVS_NS, false); // read-write
  _prefs.putString("ssid",      wifiSsid);
  _prefs.putString("wifi_pass", wifiPassword);
  _prefs.putString("mqtt_host", mqttBroker);
  _prefs.putUShort("mqtt_port", mqttPort);
  _prefs.putString("device_id", deviceId);
  _prefs.putString("last_err",  lastError);
  _prefs.end();
}

void Config::reset() {
  _prefs.begin(NVS_NS, false);
  _prefs.clear();
  _prefs.end();
  load();
}
