# nest-auth — Guide des règles du projet

Ce dossier contient les documents de référence pour tout agent IA ou développeur travaillant sur ce projet.

## Fichiers

| Fichier | Contenu |
|---|---|
| `prd.md` | Product Requirements Document — fonctionnalités attendues, périmètre du projet |
| `architecture.md` | Architecture technique — modules, flux, base de données, configuration |
| `disclaimer.md` | Directives pour agents IA — ce qu'il faut faire, ne pas faire, et comment intervenir |
| `tasks/` | Tâches d'implémentation à réaliser |

## Présentation du projet

**nest-auth** est un backend d'authentification complet développé avec NestJS. Il expose une API REST sécurisée couvrant :

- Authentification locale (email / mot de passe)
- Authentification via Google OAuth 2.0
- Vérification d'email par OTP
- Réinitialisation de mot de passe par lien sécurisé
- Gestion des sessions via cookie JWT (httpOnly)

**Stack :**
- Framework : NestJS 11
- Langage : TypeScript 5.7
- Base de données : PostgreSQL via Prisma 7
- Emails : Gmail SMTP (Nodemailer)
- Gestionnaire de paquets : pnpm

## Lancer le projet

```bash
# Installer les dépendances
pnpm install

# Configurer les variables d'environnement
cp .env.example .env

# Générer le client Prisma et appliquer les migrations
pnpm run prisma:generate
pnpm run prisma:migrate

# Démarrer en mode développement
pnpm run start:dev
```

L'API est accessible sur `http://localhost:5000/api`.

## Variables d'environnement requises

```env
NODE_ENV=development
PORT=5000
DATABASE_URL=postgresql://...
JWT_SECRET=...
FRONTEND_URL=http://localhost:3000
GOOGLE_CLIENT_ID=...
GOOGLE_CLIENT_SECRET=...
GOOGLE_CALLBACK_URL=http://localhost:5000/api/auth/google/callback
GMAIL_USER=...
GMAIL_PASS=...
CORS_ORIGIN=http://localhost:3000
```
