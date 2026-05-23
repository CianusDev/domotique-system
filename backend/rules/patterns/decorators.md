# Pattern — Décorateurs custom

Les décorateurs permettent d'attacher des métadonnées à des routes ou classes, lisibles ensuite par les guards et intercepteurs via le `Reflector`.

## Décorateur existant : `@Public()`

Fichier : `src/config/decorators/public.decorator.ts`

```typescript
import { SetMetadata } from '@nestjs/common';

export const IS_PUBLIC_KEY = 'isPublic';
export const Public = () => SetMetadata(IS_PUBLIC_KEY, true);
```

Utilisé par `JwtAuthGuard` pour bypasser la validation JWT :

```typescript
const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
  context.getHandler(),
  context.getClass(),
]);
if (isPublic) return true;
```

## Créer un décorateur de métadonnée

Même pattern que `@Public()` — pour transmettre une valeur à un guard ou intercepteur :

```typescript
// src/config/decorators/roles.decorator.ts
import { SetMetadata } from '@nestjs/common';
import { UserRole } from 'generated/prisma';

export const ROLES_KEY = 'roles';
export const Roles = (...roles: UserRole[]) => SetMetadata(ROLES_KEY, roles);
```

Usage sur une route :

```typescript
@Roles(UserRole.ADMIN)
@Get('admin-only')
adminRoute() {}
```

Lecture dans un guard :

```typescript
const roles = this.reflector.getAllAndOverride<UserRole[]>(ROLES_KEY, [
  context.getHandler(),
  context.getClass(),
]);
```

## Créer un décorateur de paramètre (extraction de req.user)

Pratique pour éviter de répéter `@Request() req` dans chaque méthode :

```typescript
// src/config/decorators/current-user.decorator.ts
import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import { JwtPayload } from 'src/auth/strategies/jwt.strategy';

export const CurrentUser = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): JwtPayload => {
    const request = ctx.switchToHttp().getRequest();
    return request.user as JwtPayload;
  },
);
```

Usage dans un controller :

```typescript
// Avant (pattern actuel du projet)
@Get('profile')
async profile(@Request() req: Request & { user: JwtPayload }) {
  return this.authService.profile(req.user.email);
}

// Avec le décorateur
@Get('profile')
async profile(@CurrentUser() user: JwtPayload) {
  return this.authService.profile(user.email);
}
```

## Combiner plusieurs décorateurs

Pour factoriser des combinaisons fréquentes (`@Public()` + `@HttpCode()` + `@Post()`) :

```typescript
import { applyDecorators, HttpCode, HttpStatus, Post } from '@nestjs/common';
import { Public } from './public.decorator';

export const PublicPost = (path: string) =>
  applyDecorators(
    Public(),
    Post(path),
    HttpCode(HttpStatus.OK),
  );
```

Usage :

```typescript
@PublicPost('login')
login() {}
```

## Emplacement des décorateurs

Tous les décorateurs custom sont placés dans `src/config/decorators/`.
