# Architecture technique — nest-auth

## Vue d'ensemble

```
nest-auth/
├── src/
│   ├── auth/           # Module d'authentification (stratégies, guards, DTOs)
│   ├── users/          # Module utilisateurs (service, repository)
│   ├── otp/            # Module OTP (génération, validation)
│   ├── email/          # Module email (envoi via Gmail SMTP)
│   ├── prisma/         # Module base de données (PrismaClient)
│   ├── config/         # Constantes, interfaces, templates, décorateurs
│   ├── app.module.ts   # Module racine
│   └── main.ts         # Bootstrap de l'application
├── prisma/
│   ├── schema.prisma   # Schéma de la base de données
│   └── migrations/     # Migrations Prisma
└── rules/              # Documentation du projet
```

## Modules

### AppModule (racine)

- Importe : `ConfigModule` (global), `ThrottlerModule`, `AuthModule`, `UsersModule`, `PrismaModule`, `OtpModule`, `EmailModule`
- Enregistre comme guards globaux : `ThrottlerGuard`, `JwtAuthGuard`

### AuthModule

- Importe : `PassportModule`, `JwtModule` (config async), `UsersModule`, `OtpModule`, `EmailModule`
- Fournit : `AuthService`, `JwtStrategy`, `LocalStrategy`, `GoogleStrategy`
- Expose : `AuthController`

### UsersModule

- Importe : `PrismaModule`
- Fournit : `UsersRepository`, `UsersService`
- Exporte : `UsersService`

### OtpModule

- Importe : `PrismaModule`
- Fournit : `OtpRepository`, `OtpService`
- Exporte : `OtpService`

### EmailModule

- Fournit : `EmailService`
- Exporte : `EmailService`

### PrismaModule

- Fournit : `PrismaService` (étend `PrismaClient`, utilise l'adapter `@prisma/adapter-pg`)
- Exporte : `PrismaService`

## Base de données (Prisma + PostgreSQL)

### Modèle User

```prisma
model User {
  id            String    @id @default(uuid())
  username      String?   @unique
  firstName     String?
  lastName      String?
  picture       String?
  email         String    @unique
  password      String
  emailVerified Boolean   @default(false)
  isActive      Boolean   @default(true)
  role          UserRole  @default(USER)
  createdAt     DateTime  @default(now())
}

enum UserRole { USER ADMIN }
```

### Modèle Otp

```prisma
model Otp {
  id        String   @id @default(uuid())
  code      String   @unique
  email     String
  expiresAt DateTime
  createdAt DateTime @default(now())

  @@index([code])
  @@index([email])
  @@index([expiresAt])
}
```

## Authentification

### Architecture Guards / Stratégies

```
Requête entrante
      │
      ▼
JwtAuthGuard (global)
  ├── @Public() → passe directement
  └── Extrait le JWT du cookie "authentication"
        │
        ▼
    JwtStrategy
      └── Valide le token, injecte JwtPayload dans req.user
```

### Stratégies Passport

| Stratégie | Fichier | Usage |
|---|---|---|
| `LocalStrategy` | `strategies/local.strategy.ts` | Login email/password, champ `email` comme username |
| `JwtStrategy` | `strategies/jwt.strategy.ts` | Extraction depuis cookie `authentication` |
| `GoogleStrategy` | `strategies/google.strategy.ts` | OAuth 2.0, création auto de compte |

### Guards

| Guard | Portée | Rôle |
|---|---|---|
| `JwtAuthGuard` | Global | Valide le JWT sur toutes les routes non publiques |
| `LocalAuthGuard` | Route `/auth/login` | Déclenche la stratégie locale |
| `GoogleAuthGuard` | Routes Google | Déclenche le flux OAuth Google |
| `ThrottlerGuard` | Global | Rate limiting |

### Décorateur `@Public()`

Positionné sur une route, il indique au `JwtAuthGuard` de ne pas vérifier le token.
Fichier : `src/config/decorators/public.decorator.ts`

## Flux d'authentification

### Inscription et vérification email

```
POST /auth/register
  → AuthService.register()
      → UsersService.create()      (bcrypt 10 rounds)
      → OtpService.generateOTP()  (code 6 chiffres, TTL 10 min)
      → EmailService.sendEmail()   (template vérification)

POST /auth/verify-email
  → OtpService.verifyOTP()
  → UsersService.verifyEmail()
  → AuthService.login()           (génère JWT)
  → Cookie "authentication" positionné
```

### Login / Logout

```
POST /auth/login
  → LocalAuthGuard → LocalStrategy.validate()
      → AuthService.validateUser()
          → UsersService.findOne()
          → bcrypt.compare()
  → AuthService.login()           (JwtService.sign({ sub, email }))
  → Cookie "authentication" positionné (httpOnly, maxAge 24h)

POST /auth/logout
  → response.clearCookie("authentication")
```

### Réinitialisation de mot de passe

```
POST /auth/forgot-password
  → OtpService.generateResetLinkOTP()
      → Crée un OTP (UUID comme code), TTL 10 min
      → Retourne {FRONTEND_URL}/reset-password?token={OTP_ID}
  → EmailService.sendEmail()      (template reset password)

POST /auth/reset-password
  → OtpService.verifyResetLinkOTP(token)
      → OTP.findUnique({ id: token })
      → Vérifie expiresAt > now()
      → Supprime l'OTP
  → UsersService.resetPassword()  (bcrypt 10 rounds)
  → AuthService.login()
  → Cookie "authentication" positionné
```

### Google OAuth

```
GET /auth/google/login
  → GoogleAuthGuard → redirect vers Google

GET /auth/google/callback
  → GoogleAuthGuard → GoogleStrategy.validate()
      → AuthService.validateGoogleUser()
          → UsersService.findOne() ou UsersService.create()
  → AuthService.login()
  → Cookie "authentication" positionné
  → Redirect vers {FRONTEND_URL}/login
```

## Configuration

### Constantes (`src/config/constants.ts`)

```typescript
ACCESS_TOKEN_EXPIRES_IN = '24h'
ACCESS_TOKEN_MAX_AGE    = 86_400_000  // ms
ACCESS_TOKEN            = 'access_token'
APP_NAME                = 'NestAuth'
```

### Interfaces (`src/config/config.interface.ts`)

```typescript
interface ControllerResponse {
  success: boolean;
  message: string;
  data?: Record<string, any> | null;
}
```

### Rate limiting global (ThrottlerModule)

| Tier | Limite | Fenêtre |
|---|---|---|
| short | 10 req | 1 s |
| medium | 20 req | 10 s |
| long | 100 req | 60 s |

Les routes `/auth/login` et `/auth/register` ont une limite spécifique : **6 req / 6 s**.

## Sécurité

| Mécanisme | Implémentation |
|---|---|
| Hachage mot de passe | bcrypt, 10 salt rounds |
| Stockage token | Cookie httpOnly, `sameSite: 'lax'` |
| Protection HTTP | Helmet (production uniquement) |
| Rate limiting | ThrottlerGuard global |
| Validation entrées | `ValidationPipe` global (whitelist, forbidNonWhitelisted) |
| CORS | Origines configurables via `CORS_ORIGIN` |
| CSRF | Configuré (csrf-csrf) mais désactivé |
| Proxy | `trust proxy: 'loopback'` actif |

## Scripts disponibles

```bash
pnpm run start:dev        # Dev avec hot-reload
pnpm run build            # Compilation TypeScript
pnpm run test             # Tests unitaires
pnpm run test:e2e         # Tests end-to-end
pnpm run prisma:generate  # Régénérer le client Prisma
pnpm run prisma:migrate   # Appliquer les migrations
pnpm run prisma:studio    # Ouvrir Prisma Studio
```
