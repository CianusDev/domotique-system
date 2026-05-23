# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## System Overview

Multi-user home automation system: Flutter app ↔ NestJS backend ↔ MQTT ↔ ESP32 devices.

```
Flutter (iOS/Android)
       │ REST + WebSocket
NestJS + PostgreSQL + Mosquitto MQTT broker
       │ MQTT
ESP32 + sensors/actuators
```

**Component status:**
- `backend/` — active, fully structured (see `backend/CLAUDE.md` for all backend details)
- `mobile-app/` — stub, not yet started
- `esp32-firmware/` — stub, not yet started

## Backend

NestJS auth backend on port 5000. All routes under `/api`. See **`backend/CLAUDE.md`** for commands, env vars, architecture, auth flow, testing conventions, and code rules.

```bash
cd backend
docker compose up -d          # start postgres
pnpm run start:dev            # hot-reload dev server
```

## MQTT Protocol

Topic namespace:

```
home/{device_id}/
├── status                    # device connection state
├── sensors/
│   ├── discovery             # ESP32 announces new sensor
│   ├── {sensor_id}/data      # sensor readings
│   └── control/add           # backend → ESP32: add sensor command
└── actuators/
    └── {type}/cmd/state      # backend ↔ ESP32: actuator commands/states
```

## Key Domain Concepts

**Sensor registry** (`sensor_types_registry` table) — catalogue of supported sensor types (DHT22, PIR, DS18B20, LDR, HC-SR04, BME280, etc.) with specs. Sensors can be added/removed without reflashing ESP32.

**Dynamic sensor flow:**
1. App selects ESP32 → chooses sensor type + GPIO pin
2. App → backend REST → MQTT `control/add` → ESP32
3. ESP32 loads driver, initialises, publishes to `discovery`
4. Backend confirms, data streams via `sensors/{id}/data`

**Automation engine:** IF/THEN rules evaluated server-side when sensor data arrives via MQTT. Triggers actuator commands back over MQTT.

## Planned Stack (mobile-app)

Flutter 3.16+, Riverpod state management, `dio` HTTP, `mqtt_client`, `flutter_blue_plus` (BLE WiFi setup), `fl_chart`.

## Planned Stack (esp32-firmware)

PlatformIO + Arduino framework, `PubSubClient` MQTT, `ArduinoJson`, modular sensor plugin architecture, OTA updates.
