# Pattern — Tests unitaires

Les tests unitaires ciblent en priorité les **Services**, qui concentrent toute la logique métier. Les repositories et dépendances externes (Prisma, SMTP, JWT) sont toujours mockés.

## Emplacement et convention de nommage

```
src/xxx/xxx.service.spec.ts   ← test du service
src/xxx/xxx.repository.spec.ts ← optionnel, rarement nécessaire
```

Jest est configuré pour détecter automatiquement tous les fichiers `*.spec.ts` dans `src/`.

## Lancer les tests

```bash
pnpm run test              # tous les tests
pnpm run test:watch        # mode watch
pnpm run test:cov          # avec rapport de couverture
```

## Structure d'un fichier spec

```typescript
import { Test, TestingModule } from '@nestjs/testing';
import { NotFoundException } from '@nestjs/common';
import { XxxService } from './xxx.service';
import { XxxRepository } from './xxx.repository';

// 1. Données de test stables
const mockItem = {
  id: 'uuid-1',
  email: 'test@example.com',
  // ...
};

// 2. Mock du repository (objet avec jest.fn())
const mockXxxRepository = {
  findOne: jest.fn(),
  create: jest.fn(),
  update: jest.fn(),
  delete: jest.fn(),
};

describe('XxxService', () => {
  let service: XxxService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        XxxService,
        { provide: XxxRepository, useValue: mockXxxRepository },
      ],
    }).compile();

    service = module.get<XxxService>(XxxService);
    jest.clearAllMocks(); // réinitialiser entre chaque test
  });

  describe('findOne', () => {
    it('should return the item when found', async () => {
      mockXxxRepository.findOne.mockResolvedValue(mockItem);

      const result = await service.findOne({ id: mockItem.id });

      expect(result).toEqual(mockItem);
      expect(mockXxxRepository.findOne).toHaveBeenCalledWith({ id: mockItem.id });
    });

    it('should throw NotFoundException when not found', async () => {
      mockXxxRepository.findOne.mockResolvedValue(null);

      await expect(service.findOne({ id: 'nonexistent' })).rejects.toThrow(
        NotFoundException,
      );
    });
  });
});
```

## Mocker des modules Node (ex: bcrypt)

```typescript
// En haut du fichier, avant les imports
jest.mock('bcrypt');

import * as bcrypt from 'bcrypt';

// Dans le test
(bcrypt.compare as jest.Mock).mockResolvedValue(true);
(bcrypt.hash as jest.Mock).mockResolvedValue('hashed-value');
```

## Mocker ConfigService

```typescript
const mockConfigService = {
  getOrThrow: jest.fn().mockReturnValue('http://localhost:3000'),
  get: jest.fn().mockReturnValue(undefined),
};

// Dans providers :
{ provide: ConfigService, useValue: mockConfigService }
```

## Mocker JwtService

```typescript
const mockJwtService = {
  sign: jest.fn().mockReturnValue('signed-jwt-token'),
  verify: jest.fn(),
};

{ provide: JwtService, useValue: mockJwtService }
```

## Mocker plusieurs appels successifs

Quand un mock est appelé plusieurs fois avec des résultats différents (ex: `findOne` vérifie d'abord l'email, puis le username) :

```typescript
mockRepository.findOne
  .mockResolvedValueOnce(null)        // premier appel → null
  .mockResolvedValueOnce(existingUser); // deuxième appel → user existant
```

## Ce qu'il faut toujours vérifier

| Cas | Assertion |
|---|---|
| Méthode appelée | `expect(mock.fn).toHaveBeenCalledWith(...)` |
| Méthode non appelée | `expect(mock.fn).not.toHaveBeenCalled()` |
| Exception levée | `await expect(...).rejects.toThrow(XxxException)` |
| Valeur retournée | `expect(result).toEqual(...)` |
| Champ absent | `expect(result).not.toHaveProperty('password')` |

## Ce qu'il ne faut pas tester dans les specs unitaires

- La logique interne de Prisma (c'est le rôle des tests d'intégration)
- L'envoi réel d'emails
- La signature réelle des JWT
- Les guards et stratégies Passport (trop couplés à la couche HTTP)

Ces éléments sont mockés. Les tester en isolation n'apporterait pas de valeur.

## Configuration Jest (package.json)

La config inclut un `moduleNameMapper` pour résoudre les imports absolus du projet :

```json
"moduleNameMapper": {
  "^src/(.*)$": "<rootDir>/$1",
  "^generated/(.*)$": "<rootDir>/../generated/$1",
  "^(\\.{1,2}/.+)\\.js$": "$1"
}
```

- `src/` → résout les imports absolus depuis `src/`
- `generated/` → résout le client Prisma généré
- `.js` → supprime l'extension `.js` des imports relatifs (le client Prisma généré utilise ESM avec `.js`, mais les fichiers source sont en `.ts`)
