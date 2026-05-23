# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# PlatformIO CLI (add to PATH first)
export PATH="$HOME/.platformio/penv/bin:$PATH"

pio run                          # compile (esp32dev env)
pio run -e esp32dev_ota          # compile OTA env
pio run --target upload          # compile + flash via USB
pio run --target upload -e esp32dev_ota  # OTA flash (set upload_port first)
pio device monitor               # serial monitor 115200 baud
pio run --target clean           # clean build cache
pio lib install                  # install lib_deps from platformio.ini
```

> **VS Code:** Install "PlatformIO IDE" extension — all commands available via the PlatformIO sidebar.

## Architecture

Plugin-based sensor system — add sensors at runtime via MQTT, no reflash needed.

```
src/
├── main.cpp              # setup() / loop() — WiFi, OTA, MQTT, SensorManager
├── config/
│   ├── config.h/.cpp     # NVS persistent storage (WiFi creds, MQTT, deviceId)
├── ble/
│   ├── ble_provisioning  # BLE Nordic UART — receives JSON config from Flutter app
├── mqtt/
│   ├── mqtt_client.h/.cpp # Singleton MQTT — pub/sub, topic routing, callbacks
└── sensors/
    ├── sensor_base.h     # Abstract base: begin(), update(), toJson()
    ├── sensor_manager    # Map<sensorId, SensorBase*> — add/remove/update loop
    ├── dht_sensor        # DHT11 / DHT22 — temperature + humidity
    ├── pir_sensor        # PIR — motion detection (publishes on state change)
    └── ds18b20_sensor    # DS18B20 — precise temperature (OneWire)
```

## Adding a New Sensor Type

1. Create `src/sensors/mysensor.h` extending `SensorBase` — implement `begin()`, `update()`, `toJson()`
2. Add `#include "mysensor.h"` in `sensor_manager.cpp`
3. Add `else if (type == "MYTYPE") sensor = std::make_unique<MySensor>(cfg);` in `SensorManager::addSensor()`
4. That's it — backend sends MQTT command, firmware loads driver dynamically

## MQTT Topics

| Direction | Topic | Payload |
|---|---|---|
| ESP32 → broker | `home/{deviceId}/status` | `"online"` / `"offline"` (retained) |
| ESP32 → broker | `home/{deviceId}/sensors/{id}/data` | `{sensorId, type, value, timestamp}` |
| ESP32 → broker | `home/{deviceId}/sensors/discovery` | `{sensorId, status, type}` |
| broker → ESP32 | `home/{deviceId}/sensors/control/add` | `{sensorId, type, pin, params?}` |
| broker → ESP32 | `home/{deviceId}/actuators/{type}/cmd/state` | `{state, ...}` |

## Boot Flow

1. Load config from NVS (`Config::load()`)
2. If not provisioned → BLE mode (`Domotique-Setup`)
3. Connect WiFi — if fails → BLE mode (`Domotique-XX:XX`)
4. Start OTA (`ArduinoOTA`)
5. Connect MQTT, subscribe to `control/add` + `actuators/+/cmd/state`
6. `loop()`: OTA handle → MQTT loop → SensorManager update (every 10ms)

## BLE Provisioning

App sends JSON to Nordic UART RX characteristic:
```json
{"ssid":"...","password":"...","mqttBroker":"192.168.1.x","deviceId":"uuid"}
```
ESP32 saves to NVS → reboots → connects WiFi + MQTT.

## Libraries

| Library | Purpose |
|---|---|
| `PubSubClient` | MQTT |
| `ArduinoJson` v7 | JSON (StaticJsonDocument) |
| `DHT sensor library` | DHT11/DHT22 |
| `DallasTemperature` + `OneWire` | DS18B20 |
| `BLEDevice` (built-in ESP32) | BLE provisioning |
| `ArduinoOTA` (built-in ESP32) | OTA updates |
| `Preferences` (built-in ESP32) | NVS config storage |

## Environments

| Env | Usage |
|---|---|
| `esp32dev` | USB flash, debug logs enabled (`-DDEBUG_BUILD=1`) |
| `esp32dev_ota` | OTA flash — set `upload_port = <device-ip>` in platformio.ini |
