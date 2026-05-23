export interface Otp {
  id: string;
  code: string;
  email: string;
  expiresAt: Date;
  createdAt: Date;
}
