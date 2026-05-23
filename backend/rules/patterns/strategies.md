# Pattern — Stratégies Passport

Les stratégies Passport définissent comment authentifier un utilisateur. Elles sont utilisées par les guards correspondants.

## Stratégies existantes

| Stratégie | Fichier | Nom Passport | Usage |
|---|---|---|---|
| `JwtStrategy` | `strategies/jwt.strategy.ts` | `'jwt'` | Valide le JWT depuis le cookie |
| `LocalStrategy` | `strategies/local.strategy.ts` | `'local'` | Valide email/password |
| `GoogleStrategy` | `strategies/google.strategy.ts` | `'google'` | OAuth 2.0 Google |

## Pattern — Stratégie JWT (extraction cookie)

Référence : `src/auth/strategies/jwt.strategy.ts`

```typescript
import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { Request } from 'express';

export interface JwtPayload {
  sub: string;
  email: string;
}

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy, 'jwt') {
  constructor(configService: ConfigService) {
    super({
      jwtFromRequest: ExtractJwt.fromExtractors([
        (request: Request) => request?.cookies?.authentication ?? null,
      ]),
      ignoreExpiration: false,
      secretOrKey: configService.getOrThrow<string>('JWT_SECRET'),
    });
  }

  validate(payload: JwtPayload): JwtPayload {
    return payload; // injecté dans req.user
  }
}
```

## Pattern — Stratégie Local (email/password)

Référence : `src/auth/strategies/local.strategy.ts`

```typescript
import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { Strategy } from 'passport-local';
import { AuthService } from '../auth.service';

@Injectable()
export class LocalStrategy extends PassportStrategy(Strategy, 'local') {
  constructor(private readonly authService: AuthService) {
    super({ usernameField: 'email' }); // champ email au lieu de username
  }

  async validate(email: string, password: string) {
    const user = await this.authService.validateUser(email, password);
    if (!user) {
      throw new UnauthorizedException('Invalid credentials');
    }
    return user; // injecté dans req.user
  }
}
```

## Pattern — Stratégie OAuth (Google)

Référence : `src/auth/strategies/google.strategy.ts`

```typescript
import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PassportStrategy } from '@nestjs/passport';
import { Strategy, VerifyCallback, Profile } from 'passport-google-oauth20';
import { AuthService } from '../auth.service';

@Injectable()
export class GoogleStrategy extends PassportStrategy(Strategy, 'google') {
  constructor(
    private readonly authService: AuthService,
    configService: ConfigService,
  ) {
    super({
      clientID: configService.getOrThrow<string>('GOOGLE_CLIENT_ID'),
      clientSecret: configService.getOrThrow<string>('GOOGLE_CLIENT_SECRET'),
      callbackURL: configService.getOrThrow<string>('GOOGLE_CALLBACK_URL'),
      scope: ['email', 'profile'],
    });
  }

  async validate(
    _accessToken: string,
    _refreshToken: string,
    profile: Profile,
    done: VerifyCallback,
  ) {
    const email = profile.emails?.[0]?.value;
    const user = await this.authService.validateGoogleUser({
      email,
      firstName: profile.name?.givenName,
      lastName: profile.name?.familyName,
      picture: profile.photos?.[0]?.value,
    });
    done(null, user);
  }
}
```

## Enregistrement dans le module

Toutes les stratégies sont déclarées dans les `providers` du module qui les utilise :

```typescript
// src/auth/auth.module.ts
import { JwtStrategy } from './strategies/jwt.strategy';
import { LocalStrategy } from './strategies/local.strategy';
import { GoogleStrategy } from './strategies/google.strategy';

@Module({
  providers: [AuthService, JwtStrategy, LocalStrategy, GoogleStrategy],
})
export class AuthModule {}
```

## Liaison Guard ↔ Stratégie

Le nom passé à `PassportStrategy(Strategy, 'nom')` doit correspondre à celui passé à `AuthGuard('nom')` :

```typescript
// stratégie
export class MaStrategy extends PassportStrategy(Strategy, 'ma-strategie') {}

// guard associé
export class MonGuard extends AuthGuard('ma-strategie') {}
```
