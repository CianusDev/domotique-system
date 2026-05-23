# Pattern — DTOs & Validation

Les DTOs (Data Transfer Objects) définissent et valident la forme des données entrantes. Ils s'appuient sur `class-validator` et `class-transformer`.

## Règles

- Un DTO par action (`CreateXxxDto`, `UpdateXxxDto`, etc.)
- Toujours utiliser des décorateurs `class-validator` — jamais de validation manuelle dans le service
- Activer `transform: true` dans le `ValidationPipe` global (déjà configuré dans `main.ts`)
- Typage strict : pas de `any`

## DTO simple

```typescript
// src/xxx/dto/create-xxx.dto.ts
import {
  IsEmail,
  IsString,
  IsOptional,
  MaxLength,
  MinLength,
} from 'class-validator';

export class CreateXxxDto {
  @IsEmail()
  email: string;

  @IsString()
  @MinLength(2)
  @MaxLength(50)
  name: string;

  @IsOptional()
  @IsString()
  @MaxLength(200)
  description?: string;
}
```

## DTO avec héritage

Utilisé dans ce projet pour les DTOs qui partagent des champs (ex: `ResendVerificationEmailDto` étend `ForgotPasswordDto`) :

```typescript
// src/auth/dto/forgot-password.dto.ts
export class ForgotPasswordDto {
  @IsEmail()
  email: string;
}

// src/auth/dto/resend-verification-email.ts
import { ForgotPasswordDto } from './forgot-password.dto';

export class ResendVerificationEmailDto extends ForgotPasswordDto {}
```

## Validation de mot de passe fort

Pattern utilisé dans `RegisterDto` et `VerifyResetPasswordDto` :

```typescript
import { Matches, MinLength } from 'class-validator';

@IsString()
@MinLength(8)
@Matches(/(?=.*[A-Z])/, { message: 'Password must contain at least one uppercase letter' })
@Matches(/(?=.*[a-z])/, { message: 'Password must contain at least one lowercase letter' })
@Matches(/(?=.*\d)/, { message: 'Password must contain at least one number' })
@Matches(/(?=.*[\W_])/, { message: 'Password must contain at least one special character' })
password: string;
```

## Validation d'un code OTP à 6 chiffres

Pattern utilisé dans `VerifyEmailDto` :

```typescript
import { Matches } from 'class-validator';

@IsString()
@Matches(/^\d{6}$/, { message: 'Code must be exactly 6 digits' })
code: string;
```

## Transformation automatique

Grâce à `transform: true` dans le `ValidationPipe`, les types primitifs sont automatiquement castés :

```typescript
// une query string "?page=2" sera transformée en number si le DTO déclare :
@IsInt()
@Min(1)
page: number;
```

Pour activer la transformation sur un champ spécifique :

```typescript
import { Type } from 'class-transformer';

@Type(() => Number)
@IsInt()
page: number;
```

## Décorateurs courants

| Décorateur | Usage |
|---|---|
| `@IsString()` | Valeur est une chaîne |
| `@IsEmail()` | Format email valide |
| `@IsInt()` | Entier |
| `@IsBoolean()` | Booléen |
| `@IsUUID()` | UUID valide |
| `@IsOptional()` | Champ optionnel (passe si absent) |
| `@IsNotEmpty()` | Chaîne non vide |
| `@MinLength(n)` | Longueur minimale |
| `@MaxLength(n)` | Longueur maximale |
| `@Min(n)` / `@Max(n)` | Valeur numérique min/max |
| `@Matches(regex)` | Correspond à l'expression régulière |
| `@IsEnum(Enum)` | Valeur dans un enum |
| `@IsArray()` | Tableau |
| `@ValidateNested()` | Valider un objet imbriqué |
| `@Type(() => Dto)` | Transformer un objet imbriqué |
