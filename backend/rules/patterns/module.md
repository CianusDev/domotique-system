# Pattern — Création d'un nouveau module

Guide pour ajouter un module fonctionnel dans ce boilerplate.

## Checklist

- [ ] Créer le dossier `src/xxx/`
- [ ] Créer `xxx.interface.ts`
- [ ] Créer `xxx.repository.ts` (si accès BDD nécessaire)
- [ ] Créer les DTOs dans `src/xxx/dto/`
- [ ] Créer `xxx.service.ts`
- [ ] Créer `xxx.controller.ts` (si routes HTTP nécessaires)
- [ ] Créer `xxx.module.ts`
- [ ] Importer `XxxModule` dans `AppModule`

## Structure minimale

```
src/xxx/
├── dto/
│   ├── create-xxx.dto.ts
│   └── update-xxx.dto.ts
├── xxx.controller.ts
├── xxx.interface.ts
├── xxx.module.ts
├── xxx.repository.ts
└── xxx.service.ts
```

## Module avec accès BDD

```typescript
// src/xxx/xxx.module.ts
import { Module } from '@nestjs/common';
import { PrismaModule } from 'src/prisma/prisma.module';
import { XxxRepository } from './xxx.repository';
import { XxxService } from './xxx.service';
import { XxxController } from './xxx.controller';

@Module({
  imports: [PrismaModule],
  providers: [XxxRepository, XxxService],
  controllers: [XxxController],
  exports: [XxxService],
})
export class XxxModule {}
```

## Module sans accès BDD

```typescript
// src/xxx/xxx.module.ts
import { Module } from '@nestjs/common';
import { XxxService } from './xxx.service';

@Module({
  providers: [XxxService],
  exports: [XxxService],
})
export class XxxModule {}
```

## Enregistrement dans AppModule

```typescript
// src/app.module.ts
import { XxxModule } from './xxx/xxx.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    ThrottlerModule.forRoot(...),
    PrismaModule,
    AuthModule,
    UsersModule,
    OtpModule,
    EmailModule,
    XxxModule, // <-- ajouter ici
  ],
  ...
})
export class AppModule {}
```

## DTOs

```typescript
// src/xxx/dto/create-xxx.dto.ts
import { IsEmail, IsString, IsOptional, MaxLength } from 'class-validator';

export class CreateXxxDto {
  @IsEmail()
  email: string;

  @IsString()
  @MaxLength(50)
  name: string;

  @IsOptional()
  @IsString()
  description?: string;
}
```

## Modifier le schéma Prisma

Si le module nécessite une nouvelle table :

1. Ajouter le modèle dans `prisma/schema.prisma`
2. Créer la migration : `pnpm run prisma:migrate`
3. Régénérer le client : `pnpm run prisma:generate`
4. Importer les types depuis `generated/prisma` dans le repository

```typescript
import { Prisma } from 'generated/prisma';
```

## Consommer un service d'un autre module

```typescript
// Dans xxx.module.ts, importer le module source
imports: [PrismaModule, EmailModule],

// Dans xxx.service.ts, injecter le service
constructor(
  private readonly xxxRepository: XxxRepository,
  private readonly emailService: EmailService,
) {}
```
