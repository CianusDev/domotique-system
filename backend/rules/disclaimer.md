# Disclaimer — Directives pour agents IA

Ce document contient les règles à respecter impérativement pour tout agent IA intervenant sur ce projet.

## Principe général

Toute modification doit rester **minimale, ciblée et cohérente** avec l'architecture existante. Ne jamais refactoriser au-delà de la demande, ne jamais ajouter de couches non demandées.

## Architecture — ce qu'il faut respecter

### Pattern Repository / Service

Le projet sépare strictement les responsabilités :
- **Repository** : accès direct à Prisma, aucune logique métier
- **Service** : logique métier, orchestration
- **Controller** : orchestration HTTP, pas de logique

Ne jamais appeler `PrismaService` directement depuis un `Service`. Passer toujours par le `Repository`.

### Guard global `JwtAuthGuard`

Toutes les routes sont protégées par défaut. Pour rendre une route publique, utiliser **uniquement** le décorateur `@Public()` :

```typescript
import { Public } from 'src/config/decorators/public.decorator';

@Public()
@Post('ma-route')
maRoute() { ... }
```

Ne jamais désactiver le guard autrement.

### Réponses contrôleur

Toutes les réponses doivent respecter l'interface `ControllerResponse` :

```typescript
{
  success: boolean;
  message: string;
  data?: Record<string, any> | null;
}
```

### Cookies

L'authentification repose sur le cookie `authentication` (httpOnly). Ne pas migrer vers Authorization header sans validation explicite.

## Sécurité — règles non négociables

- Ne jamais retourner le mot de passe dans une réponse (utiliser `UserWithoutPassword`)
- Toujours hacher les mots de passe avec bcrypt (10 rounds) via `AuthService.hashPassword()`
- Ne jamais stocker un JWT en clair ou dans localStorage
- Les OTP doivent toujours avoir une date d'expiration (`expiresAt`)
- L'endpoint `forgot-password` ne doit pas révéler l'existence d'un email en base

## Base de données

- Utiliser **Prisma** exclusivement, jamais de SQL brut
- Chaque modification de schéma nécessite une migration : `pnpm run prisma:migrate`
- Régénérer le client après toute modification du schéma : `pnpm run prisma:generate`

## Dépendances

- Gestionnaire de paquets : **pnpm** uniquement (ne pas utiliser npm ou yarn)
- Ne pas ajouter `@nestjs/swagger` dans les controllers (swagger a été retiré intentionnellement)

## Conventions de code

### Nommage des fichiers

```
module.service.ts
module.repository.ts
module.controller.ts
module.module.ts
module.interface.ts
dto/action-name.dto.ts
guards/name-auth.guard.ts
strategies/name.strategy.ts
```

### DTOs

- Utiliser `class-validator` pour toutes les validations
- Toujours activer `whitelist: true` (déjà configuré globalement)
- Les DTOs peuvent étendre d'autres DTOs si les champs sont identiques

### Modules

Tout nouveau service ou repository doit :
1. Être déclaré dans le module correspondant (`providers`)
2. Être exporté si utilisé dans un autre module
3. Être importé dans le module consommateur

## Ce qui est intentionnellement désactivé

| Fonctionnalité | État | Raison |
|---|---|---|
| Swagger / OpenAPI | Retiré | Non utilisé dans ce projet |
| CSRF (csrf-csrf) | Commenté | En attente de décision sur l'implémentation frontend |

Ne pas réactiver ces fonctionnalités sans instruction explicite.

## Variables d'environnement

Ne jamais hardcoder une valeur qui doit venir de l'environnement. Utiliser `ConfigService.getOrThrow()` pour les variables obligatoires, `ConfigService.get()` pour les optionnelles.

## Priorités en cas de doute

1. Sécurité avant tout
2. Cohérence avec l'architecture existante
3. Minimalisme (faire le moins possible pour répondre au besoin)
4. Demander une clarification plutôt qu'improviser
5. typage strict , utilisation de `any` en dernier recours.
