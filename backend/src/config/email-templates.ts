import { APP_NAME } from './constants';

export type EmailTemplates = {
  verificationEmail: {
    subject: string;
    html: ({ code, fullName }: { code: string; fullName?: string }) => string;
  };
  resetPasswordOtp: {
    subject: string;
    html: ({ code, fullName }: { code: string; fullName?: string }) => string;
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
  resetPasswordOtp: {
    subject: `Code de réinitialisation - ${appName}`,
    html: ({ code, fullName }) => `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h1 style="color: #4F46E5;">Réinitialisation du mot de passe</h1>
        <p>Bonjour${fullName ? ` ${fullName}` : ''},</p>
        <p>Nous avons reçu une demande de réinitialisation de votre mot de passe pour votre compte ${appName}.</p>
        <p>Utilisez le code suivant dans l'application pour réinitialiser votre mot de passe :</p>
        <div style="background-color: #f3f4f6; padding: 20px; text-align: center; border-radius: 8px; margin: 20px 0;">
          <h2 style="color: #4F46E5; font-size: 32px; letter-spacing: 8px; margin: 0;">${code}</h2>
        </div>
        <p style="color: #6b7280;">Ce code expirera dans 10 minutes.</p>
        <p style="color: #6b7280;">Si vous n'avez pas demandé cette réinitialisation, veuillez ignorer cet email.</p>
        <p>Cordialement,<br/>L'équipe ${appName}</p>
      </div>
    `,
  },
};
