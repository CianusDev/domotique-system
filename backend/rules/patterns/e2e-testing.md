# Pattern — Tests e2e

Les tests e2e testent l'application de bout en bout via de vraies requêtes HTTP. Ils bootstrap l'intégralité du module NestJS et utilisent `supertest` pour envoyer des requêtes.

## Emplacement et configuration

```
test/
├── app.e2e-spec.ts   ← fichier de test e2e
└── jest-e2e.json     ← config Jest dédiée aux e2e
```

La config `jest-e2e.json` est séparée de celle des tests unitaires (pas de `moduleNameMapper` nécessaire ici car `rootDir` est `test/` et les imports sont relatifs).

## Lancer les tests e2e

```bash
pnpm run test:e2e
```

> Les tests e2e nécessitent une base de données réelle et toutes les variables d'environnement configurées (`.env`). Ne pas les lancer en CI sans infrastructure dédiée.

## Structure d'un fichier e2e

```typescript
// test/xxx.e2e-spec.ts
import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import request from 'supertest';
import { App } from 'supertest/types';
import { AppModule } from './../src/app.module';

describe('XxxController (e2e)', () => {
  let app: INestApplication<App>;

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();

    // Reproduire la config de main.ts
    app.useGlobalPipes(
      new ValidationPipe({
        whitelist: true,
        forbidNonWhitelisted: true,
        transform: true,
      }),
    );
    app.setGlobalPrefix('api');

    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  it('POST /api/auth/register - should register a new user', async () => {
    const response = await request(app.getHttpServer())
      .post('/api/auth/register')
      .send({
        email: 'e2e@example.com',
        username: 'e2euser',
        password: 'Password1!',
      })
      .expect(201);

    expect(response.body.success).toBe(true);
    expect(response.body.data.email).toBe('e2e@example.com');
    expect(response.body.data).not.toHaveProperty('password');
  });

  it('POST /api/auth/register - should return 409 if email already in use', async () => {
    await request(app.getHttpServer())
      .post('/api/auth/register')
      .send({
        email: 'e2e@example.com',
        username: 'other',
        password: 'Password1!',
      })
      .expect(409);
  });
});
```

## Différences clés avec les tests unitaires

| | Unitaire | E2E |
|---|---|---|
| Scope | Un service isolé | L'application complète |
| Dépendances | Mockées | Réelles (BDD, SMTP...) |
| Vitesse | Rapide (~4s) | Lent (BDD requise) |
| `beforeEach` vs `beforeAll` | `beforeEach` (reset mocks) | `beforeAll` (boot app une seule fois) |
| Fichier | `src/xxx/xxx.service.spec.ts` | `test/xxx.e2e-spec.ts` |

## Points d'attention

### Reproduire la config de `main.ts`

Le `createNestApplication()` ne charge pas automatiquement les pipes globaux ni le prefix. Il faut les redéclarer manuellement dans le `beforeAll` :

```typescript
app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
app.setGlobalPrefix('api');
app.use(cookieParser());
```

### Cookies dans supertest

Pour les routes qui retournent un cookie d'authentification et les routes protégées qui en attendent un :

```typescript
let authCookie: string;

it('POST /api/auth/login - should set auth cookie', async () => {
  const response = await request(app.getHttpServer())
    .post('/api/auth/login')
    .send({ email: 'test@example.com', password: 'Password1!' })
    .expect(200);

  // Extraire le cookie pour les requêtes suivantes
  authCookie = response.headers['set-cookie'][0];
});

it('GET /api/auth/profile - should return profile with cookie', async () => {
  await request(app.getHttpServer())
    .get('/api/auth/profile')
    .set('Cookie', authCookie)
    .expect(200);
});
```

### Isolation des données

Chaque suite e2e doit gérer sa propre isolation. Options :
- Utiliser une base de test dédiée (`DATABASE_URL` spécifique dans `.env.test`)
- Nettoyer les tables créées dans `afterAll`
- Utiliser des emails uniques par suite (ex: `e2e-${Date.now()}@example.com`)

### Variables d'environnement

Créer un fichier `.env.test` avec une base de données dédiée pour ne pas polluer les données de développement :

```env
DATABASE_URL=postgresql://user:pass@localhost:5432/nest_auth_test
JWT_SECRET=test-secret
FRONTEND_URL=http://localhost:3000
GMAIL_USER=test@gmail.com
GMAIL_PASS=test-pass
```

Charger ce fichier dans `jest-e2e.json` :

```json
{
  "moduleFileExtensions": ["js", "json", "ts"],
  "rootDir": ".",
  "testEnvironment": "node",
  "testRegex": ".e2e-spec.ts$",
  "transform": {
    "^.+\\.(t|j)s$": "ts-jest"
  },
  "moduleNameMapper": {
    "^src/(.*)$": "<rootDir>/../src/$1",
    "^generated/(.*)$": "<rootDir>/../generated/$1",
    "^(\\.{1,2}/.+)\\.js$": "$1"
  }
}
```

## Routes prioritaires à couvrir en e2e

| Route | Cas à tester |
|---|---|
| `POST /api/auth/register` | Succès, email déjà pris, DTO invalide |
| `POST /api/auth/login` | Succès (cookie positionné), mauvais mot de passe |
| `POST /api/auth/verify-email` | Code valide, code expiré, code incorrect |
| `POST /api/auth/forgot-password` | Email inconnu (retourne 200 sans erreur) |
| `POST /api/auth/reset-password` | Token valide, token expiré |
| `GET /api/auth/profile` | Avec cookie valide, sans cookie (401) |
| `POST /api/auth/logout` | Cookie supprimé |
