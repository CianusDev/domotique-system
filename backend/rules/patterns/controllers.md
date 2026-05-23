# Pattern — Controllers

Les controllers orchestrent les requêtes HTTP. Ils ne contiennent **aucune logique métier**.

## Règles

- Injecter uniquement des **Services** (jamais de Repository directement)
- Toujours retourner un objet `ControllerResponse`
- Utiliser `@HttpCode()` explicitement sur chaque route
- Les routes publiques portent `@Public()`
- Les valeurs d'environnement nécessaires dans le controller sont récupérées via `ConfigService` dans le constructeur

## Structure type

```typescript
import {
  Controller,
  Post,
  Get,
  Body,
  HttpCode,
  HttpStatus,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { ControllerResponse } from 'src/config/config.interface';
import { Public } from 'src/config/decorators/public.decorator';
import { XxxService } from './xxx.service';
import { CreateXxxDto } from './dto/create-xxx.dto';

@Controller('xxx')
export class XxxController {
  constructor(
    private readonly xxxService: XxxService,
    private readonly configService: ConfigService,
  ) {}

  @Public()
  @Post()
  @HttpCode(HttpStatus.CREATED)
  async create(@Body() body: CreateXxxDto): Promise<ControllerResponse> {
    const result = await this.xxxService.create(body);
    return {
      success: true,
      message: 'Resource created successfully',
      data: result,
    };
  }

  @Get('me')
  @HttpCode(HttpStatus.OK)
  async findMe(): Promise<ControllerResponse> {
    return {
      success: true,
      message: 'Resource fetched successfully',
      data: null,
    };
  }
}
```

## Format de réponse

Toutes les réponses respectent `ControllerResponse` (`src/config/config.interface.ts`) :

```typescript
{
  success: boolean;
  message: string;
  data?: Record<string, any> | null;
}
```

## Gestion des erreurs

Lancer des exceptions NestJS standards, jamais les gérer silencieusement :

```typescript
import { BadRequestException, NotFoundException } from '@nestjs/common';

// Ressource introuvable
throw new NotFoundException('User not found');

// Condition métier non remplie
throw new BadRequestException('Email already in use');
```

## Rate limiting sur une route spécifique

```typescript
import { Throttle } from '@nestjs/throttler';

@Throttle({ default: { limit: 6, ttl: 6000 } })
@Post('login')
@HttpCode(HttpStatus.OK)
login() { ... }
```

## Cookie d'authentification

Pattern issu de `auth.controller.ts` — à reproduire identiquement pour les routes qui authentifient :

```typescript
import { Res } from '@nestjs/common';
import type { Response } from 'express';
import { ACCESS_TOKEN_MAX_AGE } from 'src/config/constants';

response.cookie('authentication', user.access_token, {
  httpOnly: true,
  secure: this.isProduction,
  sameSite: 'lax',
  maxAge: ACCESS_TOKEN_MAX_AGE,
});
```
