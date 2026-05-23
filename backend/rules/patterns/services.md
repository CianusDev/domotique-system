# Pattern — Services & Repositories

## Séparation des responsabilités

| Couche | Rôle | Accès Prisma |
|---|---|---|
| **Repository** | Requêtes base de données uniquement | Direct |
| **Service** | Logique métier, orchestration | Via Repository |
| **Controller** | Orchestration HTTP | Via Service |

Un Service n'appelle **jamais** `PrismaService` directement. Il passe toujours par son Repository.

## Pattern Repository

```typescript
// src/xxx/xxx.repository.ts
import { Injectable } from '@nestjs/common';
import { Prisma } from 'generated/prisma';
import { PrismaService } from 'src/prisma/prisma.service';

@Injectable()
export class XxxRepository {
  constructor(private readonly prisma: PrismaService) {}

  async findOne(where: Prisma.XxxWhereUniqueInput) {
    return this.prisma.xxx.findUnique({ where });
  }

  async findAll(where?: Prisma.XxxWhereInput) {
    return this.prisma.xxx.findMany({ where });
  }

  async create(data: Prisma.XxxCreateInput) {
    return this.prisma.xxx.create({ data });
  }

  async update(
    where: Prisma.XxxWhereUniqueInput,
    data: Prisma.XxxUpdateInput,
  ) {
    return this.prisma.xxx.update({ where, data });
  }

  async delete(where: Prisma.XxxWhereUniqueInput) {
    return this.prisma.xxx.delete({ where });
  }
}
```

## Pattern Service

```typescript
// src/xxx/xxx.service.ts
import { Injectable, NotFoundException, BadRequestException } from '@nestjs/common';
import { XxxRepository } from './xxx.repository';
import type { Xxx } from './xxx.interface';

@Injectable()
export class XxxService {
  constructor(private readonly xxxRepository: XxxRepository) {}

  async findOne(id: string): Promise<Xxx> {
    const item = await this.xxxRepository.findOne({ id });
    if (!item) {
      throw new NotFoundException('Resource not found');
    }
    return item;
  }

  async create(data: Omit<Xxx, 'id' | 'createdAt'>): Promise<Xxx> {
    const existing = await this.xxxRepository.findOne({ email: data.email });
    if (existing) {
      throw new BadRequestException('Resource already exists');
    }
    return this.xxxRepository.create(data);
  }

  async update(id: string, data: Partial<Xxx>): Promise<Xxx> {
    await this.findOne(id); // vérifie l'existence
    return this.xxxRepository.update({ id }, data);
  }

  async delete(id: string): Promise<void> {
    await this.findOne(id); // vérifie l'existence
    await this.xxxRepository.delete({ id });
  }
}
```

## Interface du modèle

Chaque module expose son interface dans `xxx.interface.ts`. Elle reflète le modèle Prisma sans être couplée au client généré :

```typescript
// src/xxx/xxx.interface.ts
export interface Xxx {
  id: string;
  email: string;
  createdAt: Date;
}

export type XxxWithoutSensitive = Omit<Xxx, 'password'>;
```

## Typage strict

- Utiliser les types `Prisma.XxxWhereInput`, `Prisma.XxxCreateInput`, etc. dans les repositories
- Utiliser les interfaces du module dans les services et controllers
- `any` est interdit sauf si aucune alternative n'existe — dans ce cas, documenter pourquoi

## Injection dans le module

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
  exports: [XxxService], // exporter uniquement si consommé par un autre module
})
export class XxxModule {}
```
