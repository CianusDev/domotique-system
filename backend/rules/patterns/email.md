# Pattern — Envoi d'emails

## Infrastructure

L'envoi d'emails est géré par `EmailService` (`src/email/email.service.ts`) via Gmail SMTP (Nodemailer).

**Variables d'environnement requises :**
```env
GMAIL_USER=ton-compte@gmail.com
GMAIL_PASS=mot-de-passe-application-google
APP_NAME=NomDuProjet
```

> Utiliser un **mot de passe d'application** Google (pas le mot de passe du compte). Générable dans les paramètres de sécurité Google.

## Utilisation

Injecter `EmailService` via `EmailModule` :

```typescript
// dans xxx.module.ts
imports: [EmailModule],

// dans xxx.service.ts
constructor(private readonly emailService: EmailService) {}

await this.emailService.sendEmail({
  to: 'user@example.com',
  subject: 'Sujet du mail',
  html: '<p>Contenu HTML</p>',
});
```

## Interface `EmailOptions`

```typescript
interface EmailOptions {
  to: string;
  subject: string;
  text?: string;   // version texte brut (fallback)
  html?: string;   // version HTML (prioritaire)
}
```

## Ajouter un template

Les templates sont centralisés dans `src/config/email-templates.ts`. Chaque template est une fonction qui prend des variables et retourne un objet `{ subject, html }`.

```typescript
// src/config/email-templates.ts

export const monNouveauTemplate = (variables: {
  fullName: string;
  lien: string;
}) => ({
  subject: `Action requise sur ${APP_NAME}`,
  html: `
    <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
      <h2>Bonjour ${variables.fullName},</h2>
      <p>Cliquez sur le lien ci-dessous :</p>
      <a href="${variables.lien}" style="
        display: inline-block;
        padding: 12px 24px;
        background-color: #4F46E5;
        color: white;
        text-decoration: none;
        border-radius: 6px;
      ">Accéder</a>
      <p>Ce lien expire dans 10 minutes.</p>
    </div>
  `,
});
```

Usage dans un service :

```typescript
import { monNouveauTemplate } from 'src/config/email-templates';

const { subject, html } = monNouveauTemplate({
  fullName: user.firstName ?? user.email,
  lien: resetUrl,
});

await this.emailService.sendEmail({ to: user.email, subject, html });
```

## Templates existants

| Fonction | Usage | Variables |
|---|---|---|
| `verificationEmailTemplate` | Vérification d'email après inscription | `code`, `fullName` |
| `resetPasswordEmailTemplate` | Réinitialisation de mot de passe | `link`, `fullName` |

## Tester la connexion SMTP

L'endpoint `GET /api/app/verify-email-connection` (public) appelle `EmailService.verifySmtpConnection()` et retourne l'état de la connexion Gmail. Utile en développement pour valider la configuration.

## Bonnes pratiques

- Toujours fournir les deux versions `text` et `html` si possible
- Ne jamais bloquer le flux principal sur l'envoi d'email : si l'email échoue, logger l'erreur mais ne pas lever d'exception utilisateur (sauf si critique)
- Les templates sont en français par défaut dans ce boilerplate — adapter à la langue du projet
