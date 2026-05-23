# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

```bash
# Dev
pnpm run start:dev        # hot-reload
pnpm run build            # compile TypeScript

# Tests
pnpm run test             # all unit tests
pnpm run test:watch       # watch mode
pnpm run test:cov         # with coverage
pnpm run test:e2e         # end-to-end (./test/jest-e2e.json)

# Single test file
pnpm run test -- --testPathPattern=auth.service

# Lint / format
pnpm run lint
pnpm run format

# Prisma
pnpm run prisma:generate  # regenerate client after schema changes
pnpm run prisma:migrate   # apply migrations (dev)
pnpm run prisma:studio    # GUI
pnpm run prisma:seed      # seed SensorTypeRegistry (9 types)

# DB + MQTT broker (Docker)
docker compose up -d      # postgres :5432 + Mosquitto :1883/:9001
```

## Required env vars

```
DATABASE_URL=
JWT_SECRET=
FRONTEND_URL=
CORS_ORIGIN=              # comma-separated origins
MQTT_BROKER_URL=          # mqtt://localhost:1883
# Email (Gmail SMTP)
EMAIL_USER=
EMAIL_PASS=
```

## Architecture

NestJS + Prisma + PostgreSQL + Mosquitto MQTT. Runs on port 5000, all routes under `/api`.

**Three-layer pattern — enforced across all modules:**

| Layer | File | Rule |
|---|---|---|
| Repository | `xxx.repository.ts` | Prisma queries only. Uses `Prisma.XxxWhereInput` types. |
| Service | `xxx.service.ts` | Business logic only. Never calls PrismaService directly. |
| Controller | `xxx.controller.ts` | HTTP orchestration only. No business logic. |

**Module structure:**
- `auth/` — strategies (Local, JWT), guards, auth flows (no Google OAuth)
- `users/` — UsersRepository + UsersService (exported)
- `otp/` — 6-digit codes (email verify) + UUID tokens (password reset), 10 min TTL
- `email/` — Nodemailer/Gmail SMTP wrapper; templates in `src/config/email-templates.ts`
- `prisma/` — PrismaService using `@prisma/adapter-pg`
- `mqtt/` — Global singleton MQTT client; emits internal events via EventEmitter2
- `devices/` — ESP32 device CRUD; `@OnEvent(DEVICE_STATUS)` updates online/offline
- `sensor-types/` — Read-only registry seeded via `prisma:seed`
- `sensors/` — Dynamic sensor add (sends MQTT `control/add`); records `SensorData`; `@OnEvent(SENSOR_DISCOVERY/SENSOR_DATA)`
- `actuators/` — Actuator CRUD + control command via MQTT
- `automations/` — IF/THEN engine evaluated on `@OnEvent(SENSOR_DATA)`
- `alerts/` — Threshold alerts evaluated on `@OnEvent(SENSOR_DATA)`
- `config/` — constants, interfaces, `@Public()` decorator, email templates

**Generated Prisma client** lives at `generated/prisma/` (not inside `src/`). Import as:
```typescript
import { Prisma, SensorStatus } from 'generated/prisma/client';
```

## MQTT event flow

```
ESP32 → broker → MqttService → EventEmitter2 → @OnEvent handlers
                                                  DevicesService   (DEVICE_STATUS)
                                                  SensorsService   (SENSOR_DISCOVERY, SENSOR_DATA)
                                                  ActuatorsService (ACTUATOR_STATE)
                                                  AutomationsService (SENSOR_DATA → engine)
                                                  AlertsService    (SENSOR_DATA → threshold)
```

MQTT topics use **device UUID** (stored in ESP32 NVS during BLE provisioning), not MAC address.

## Auth flow

JWT extracted from `authentication` **httpOnly cookie** (not Authorization header). `JwtAuthGuard` is global — all routes require JWT unless decorated with `@Public()`.

Password reset uses OTP `id` (UUID) as token, not the 6-digit code.

## Global configuration

- **ThrottlerGuard** global: short 10/1s, medium 20/10s, long 100/60s. Login + register override: 6 req/6s.
- **ValidationPipe** global: `whitelist: true`, `forbidNonWhitelisted: true`, `transform: true`.
- **Helmet** security headers: production only.
- **CSRF** (`csrf-csrf`): code present but commented out.

## Response shape

All controllers return `ControllerResponse` from `src/config/config.interface.ts`:

```typescript
{ success: boolean; message: string; data?: Record<string, any> | null }
```

## Testing conventions

Unit tests target **Services** only. All repositories, Prisma, SMTP, JWT are mocked with `jest.fn()`. Call `jest.clearAllMocks()` in `beforeEach`.

```typescript
const mockXxxRepository = { findOne: jest.fn(), create: jest.fn(), ... };

{ provide: XxxRepository, useValue: mockXxxRepository }
```

Never test Prisma internals, real email sending, real JWT signing, or Passport guards in unit specs.

## Code rules

- Controllers inject Services only — never Repositories directly.
- Services inject Repositories only — never PrismaService directly.
- Interface files (`xxx.interface.ts`) mirror Prisma models without coupling to the generated client.
- No `any` unless no alternative exists.
- Use NestJS standard exceptions (`NotFoundException`, `BadRequestException`) — never silent catches.
- `forgot-password` returns `true` whether or not email exists (prevents enumeration).
- MQTT publish calls use `device.id` (UUID), never `device.macAddress`.
- `import type { ... }` required for event interfaces used only in `@OnEvent` method signatures (`isolatedModules` constraint).
