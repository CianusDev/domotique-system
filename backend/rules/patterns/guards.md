# Pattern — Guards

Les guards déterminent si une requête peut accéder à une route. Ils s'exécutent avant les intercepteurs et les pipes.

## Guards existants

| Guard | Portée | Stratégie déclenchée |
|---|---|---|
| `JwtAuthGuard` | Global (AppModule) | `JwtStrategy` |
| `LocalAuthGuard` | Route `/auth/login` | `LocalStrategy` |
| `GoogleAuthGuard` | Routes Google | `GoogleStrategy` |

## Guard Passport (étend AuthGuard)

Pattern utilisé dans ce projet pour les guards liés à Passport :

```typescript
// src/xxx/guards/xxx-auth.guard.ts
import { Injectable } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

@Injectable()
export class XxxAuthGuard extends AuthGuard('xxx') {}
```

Le nom passé à `AuthGuard('nom')` correspond au nom déclaré dans la stratégie Passport correspondante.

## Guard custom avec logique métier

Pattern du `JwtAuthGuard` — à reproduire pour un guard qui doit court-circuiter selon une condition :

```typescript
// src/xxx/guards/xxx.guard.ts
import {
  Injectable,
  ExecutionContext,
  UnauthorizedException,
} from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { AuthGuard } from '@nestjs/passport';
import { IS_PUBLIC_KEY } from 'src/config/decorators/public.decorator';

@Injectable()
export class XxxGuard extends AuthGuard('jwt') {
  constructor(private reflector: Reflector) {
    super();
  }

  canActivate(context: ExecutionContext) {
    // Vérifier si la route est marquée @Public()
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);

    if (isPublic) return true;

    return super.canActivate(context);
  }

  handleRequest<T>(err: Error, user: T): T {
    if (err || !user) {
      throw err ?? new UnauthorizedException();
    }
    return user;
  }
}
```

## Guard de rôle (exemple pour futures extensions)

```typescript
// src/config/guards/roles.guard.ts
import { Injectable, CanActivate, ExecutionContext } from '@nestjs/common';
import { Reflector } from '@nestjs/core';

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredRoles = this.reflector.getAllAndOverride<string[]>('roles', [
      context.getHandler(),
      context.getClass(),
    ]);

    if (!requiredRoles) return true;

    const { user } = context.switchToHttp().getRequest();
    return requiredRoles.includes(user?.role);
  }
}
```

## Enregistrement

### Guard global (dans AppModule)

```typescript
// src/app.module.ts
import { APP_GUARD } from '@nestjs/core';

@Module({
  providers: [
    { provide: APP_GUARD, useClass: MonGuard },
  ],
})
export class AppModule {}
```

### Guard sur une route

```typescript
@UseGuards(MonGuard)
@Post('route')
maRoute() {}
```

### Guard sur tout un controller

```typescript
@UseGuards(MonGuard)
@Controller('xxx')
export class XxxController {}
```
