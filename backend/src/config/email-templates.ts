import { APP_NAME } from './constants';

export type EmailTemplates = {
  verificationEmail: {
    subject: string;
    html: ({ code, fullName }: { code: string; fullName?: string }) => string;
  };
  resetPasswordLink: {
    subject: string;
    html: ({ link, fullName }: { link: string; fullName?: string }) => string;
  };
};

const appName = process.env.APP_NAME || APP_NAME;
export const emailTemplates: EmailTemplates = {
  verificationEmail: {
    subject: `Bienvenue sur ${appName} !`,
    html: ({ code, fullName }) => `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h1 style="color: #4F46E5;">Bienvenue ${fullName || ''} !</h1>
        <p>Votre compte a été créé avec succès sur ${appName}.</p>
        <p>Pour activer votre compte, veuillez utiliser le code de vérification suivant :</p>
        <div style="background-color: #f3f4f6; padding: 20px; text-align: center; border-radius: 8px; margin: 20px 0;">
          <h2 style="color: #4F46E5; font-size: 32px; letter-spacing: 8px; margin: 0;">${code}</h2>
        </div>
        <p style="color: #6b7280;">Ce code expirera dans 10 minutes.</p>
        <p style="color: #6b7280;">Si vous n'avez pas créé ce compte, veuillez ignorer cet email.</p>
        <p>Cordialement,<br/>L'équipe ${appName}</p>
      </div>
    `,
  },
  resetPasswordLink: {
    subject: `Réinitialisation de votre mot de passe - ${appName}`,
    html: ({ link, fullName }) => `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h1 style="color: #4F46E5;">Réinitialisation du mot de passe</h1>
        <p>Bonjour${fullName ? ` ${fullName}` : ''},</p>
        <p>Nous avons reçu une demande de réinitialisation de votre mot de passe pour votre compte ${appName}.</p>
        <p>Pour réinitialiser votre mot de passe, veuillez cliquer sur le bouton ci-dessous :</p>
        <div style="text-align: center; margin: 30px 0;">
          <a href="${link}" style="background-color: #4F46E5; color: #fff; padding: 14px 28px; border-radius: 6px; text-decoration: none; font-size: 18px; display: inline-block;">
            Réinitialiser le mot de passe
          </a>
        </div>
        <p>Si le bouton ne fonctionne pas, copiez et collez le lien suivant dans votre navigateur :</p>
        <p style="word-break: break-all;"><a href="${link}" style="color: #4F46E5;">${link}</a></p>
        <p style="color: #6b7280;">Ce lien expirera dans 30 minutes.</p>
        <p style="color: #6b7280;">Si vous n'avez pas demandé cette réinitialisation, veuillez ignorer cet email.</p>
        <p>Cordialement,<br/>L'équipe ${appName}</p>
      </div>
    `,
  },
};
