# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
flutter pub get                    # install / sync deps
flutter run                        # run on connected device/emulator
flutter run -d chrome              # run as web (debug only)
flutter build apk                  # Android release APK
flutter test                       # all unit + widget tests
flutter test test/path/to_test.dart  # single test file

# Code generation (Riverpod, Freezed, json_serializable)
dart run build_runner build --delete-conflicting-outputs
dart run build_runner watch --delete-conflicting-outputs
```

## Architecture

Feature-first structure under `lib/`:

```
lib/
├── core/
│   ├── constants/     # ApiConstants, MqttConstants
│   ├── network/       # dio_client.dart — Dio instance w/ cookie interceptor
│   ├── router/        # app_router.dart — GoRouter routes
│   └── theme/
├── features/
│   ├── auth/          # login, register, verify-email, forgot-password
│   ├── dashboard/     # real-time overview
│   ├── devices/       # ESP32 device management (BLE provisioning)
│   ├── sensors/       # dynamic sensor add/config/monitor ⭐
│   └── automations/   # IF/THEN rule builder
└── shared/
    ├── models/
    ├── widgets/
    └── utils/
```

Each feature follows `data/` → `domain/` → `presentation/` layering.

## Key Patterns

**State management:** Riverpod (`flutter_riverpod` + `riverpod_annotation`). Use `@riverpod` annotation; run codegen after changes.

**HTTP:** `Dio` via `core/network/dio_client.dart`. Backend uses httpOnly cookie auth — `withCredentials: true` set globally. Base URL from `ApiConstants.baseUrl` (env var `API_BASE_URL`, default `10.0.2.2:5000/api` for Android emulator).

**MQTT topics:** defined in `core/constants/mqtt_constants.dart`. Pattern: `home/{deviceId}/sensors/{sensorId}/data`.

**Navigation:** `GoRouter` in `core/router/app_router.dart`.

**Code generation:** `freezed` for models, `json_serializable` for JSON, `riverpod_generator` for providers. All generated files end in `.g.dart` or `.freezed.dart` — never edit manually.

## Backend Auth

JWT stored in httpOnly cookie (`authentication`). Cookie set by backend on login/verify-email/OAuth. No token handling needed client-side — Dio passes cookie automatically.

## MQTT Defaults

- Broker: `10.0.2.2:1883` (Android emulator → host) — override via `MQTT_BROKER` env var
- Package: `mqtt_client`
