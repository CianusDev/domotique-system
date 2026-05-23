# Product Requirements Document — nest-auth

## Objectif

Fournir un backend d'authentification prêt pour la production, réutilisable comme base pour tout projet NestJS nécessitant une gestion complète des utilisateurs et des sessions.

## Périmètre fonctionnel

### Authentification locale

- **Inscription** : un utilisateur peut créer un compte avec username, email et mot de passe fort.
- **Connexion** : validation des identifiants et retour d'un JWT stocké dans un cookie httpOnly.
- **Déconnexion** : suppression du cookie d'authentification.
- **Profil** : récupération des données de l'utilisateur connecté.

### Vérification d'email

- Après l'inscription, un code OTP à 6 chiffres est envoyé par email.
- L'utilisateur soumet le code pour valider son email.
- Il est possible de renvoyer le code si celui-ci a expiré (10 minutes).

### Réinitialisation de mot de passe

- L'utilisateur demande une réinitialisation en fournissant son email.
- Un lien contenant un token OTP est envoyé (valide 10 minutes).
- L'utilisateur clique sur le lien et soumet un nouveau mot de passe fort.
- Il est possible de renvoyer le lien si celui-ci a expiré.

### Authentification Google OAuth 2.0

- L'utilisateur peut se connecter via son compte Google.
- Si le compte n'existe pas, il est créé automatiquement.
- Après authentification, redirection vers le frontend avec le cookie positionné.

## Contraintes et règles métier

### Mot de passe

- Minimum 8 caractères
- Au moins une majuscule
- Au moins une minuscule
- Au moins un chiffre
- Au moins un caractère spécial

### OTP

- Code à 6 chiffres pour la vérification d'email
- Token UUID pour la réinitialisation de mot de passe
- Expiration dans 10 minutes
- Un seul OTP actif par email (l'ancien est supprimé à la génération d'un nouveau)

### Sécurité

- Les mots de passe sont hachés avec bcrypt (10 rounds)
- Les tokens JWT sont stockés dans des cookies httpOnly (non accessibles par JavaScript)
- Le rate limiting protège les endpoints sensibles (login : 6 requêtes / 6 secondes)
- CORS configurable via variable d'environnement
- Headers de sécurité via Helmet (actifs en production)

### Email

- Le retour de `forgot-password` ne révèle pas si l'email existe en base (protection contre l'énumération)

## Routes API

| Méthode | Route | Accès | Description |
|---|---|---|---|
| POST | /api/auth/register | Public | Créer un compte |
| POST | /api/auth/login | Public | Se connecter |
| POST | /api/auth/logout | JWT | Se déconnecter |
| GET | /api/auth/profile | JWT | Profil de l'utilisateur connecté |
| POST | /api/auth/verify-email | Public | Valider l'email via OTP |
| POST | /api/auth/resend-verification-email | Public | Renvoyer le code de vérification |
| POST | /api/auth/forgot-password | Public | Demander une réinitialisation |
| POST | /api/auth/resend-reset-password | Public | Renvoyer le lien de réinitialisation |
| POST | /api/auth/reset-password | Public | Réinitialiser le mot de passe |
| GET | /api/auth/google/login | Public | Initier le flux Google OAuth |
| GET | /api/auth/google/callback | Public | Callback Google OAuth |

## Ce qui est hors périmètre (pour l'instant)

- Gestion de rôles avancée (seul USER / ADMIN existe, sans middleware de contrôle d'accès)
- Refresh token
- 2FA (second facteur autre que l'OTP d'email)
- Protection CSRF (le code est présent mais commenté)
- API de gestion des utilisateurs (CRUD admin)
