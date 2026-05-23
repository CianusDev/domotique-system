# Pattern — OTP (One-Time Password)

L'`OtpService` gère deux types de codes : les **codes à 6 chiffres** (vérification email) et les **tokens UUID** (réinitialisation de mot de passe).

## API de l'OtpService

```typescript
// Générer un code 6 chiffres (vérification email)
generateOTP(email: string): Promise<string>

// Valider et consommer un code 6 chiffres
verifyOTP({ email, code }: { email: string; code: string }): Promise<Otp>

// Générer un lien de reset password (retourne l'URL complète)
generateResetLinkOTP(email: string): Promise<string>

// Valider et consommer un token de reset password
verifyResetLinkOTP(token: string): Promise<Otp>

// Supprimer les OTPs expirés (maintenance)
cleanupExpiredOtps(): Promise<void>
```

## Utiliser OtpService dans un autre module

1. Importer `OtpModule` dans le module consommateur :

```typescript
// src/xxx/xxx.module.ts
import { OtpModule } from 'src/otp/otp.module';

@Module({
  imports: [OtpModule],
  ...
})
export class XxxModule {}
```

2. Injecter `OtpService` dans le service :

```typescript
// src/xxx/xxx.service.ts
import { OtpService } from 'src/otp/otp.service';

@Injectable()
export class XxxService {
  constructor(private readonly otpService: OtpService) {}
}
```

## Flux vérification email

```typescript
// 1. Génération (après inscription)
const code = await this.otpService.generateOTP(user.email);
await this.emailService.sendEmail({
  to: user.email,
  subject: '...',
  html: `Votre code : ${code}`,
});

// 2. Validation (soumis par l'utilisateur)
const otp = await this.otpService.verifyOTP({ email, code });
// otp est supprimé automatiquement après vérification
```

## Flux réinitialisation de mot de passe

```typescript
// 1. Génération (retourne l'URL complète avec token)
const resetUrl = await this.otpService.generateResetLinkOTP(user.email);
// resetUrl = "{FRONTEND_URL}/reset-password?token={OTP_ID}"
await this.emailService.sendEmail({ to: user.email, html: `...${resetUrl}...` });

// 2. Validation (token = OTP.id extrait de l'URL par le frontend)
const otp = await this.otpService.verifyResetLinkOTP(token);
// otp.email permet de retrouver l'utilisateur
await this.usersService.resetPassword({ email: otp.email, newPassword });
```

## Comportement

- **Expiration** : 10 minutes après création
- **Unicité** : générer un nouvel OTP supprime l'OTP précédent pour le même email
- **Consommation** : un OTP est supprimé dès qu'il est validé (usage unique)
- **Codes 6 chiffres** : stockés en clair dans la colonne `code` (valeur numérique)
- **Tokens UUID** : l'`id` de l'enregistrement OTP sert de token (pas la colonne `code`)

## Interface Otp

```typescript
interface Otp {
  id: string;       // UUID — utilisé comme token reset password
  code: string;     // 6 chiffres — utilisé pour vérification email
  email: string;
  expiresAt: Date;
  createdAt: Date;
}
```

## Erreurs possibles

`verifyOTP` et `verifyResetLinkOTP` lèvent une `BadRequestException` si :
- Le code / token n'existe pas
- Le code / token est expiré (`expiresAt < now()`)
