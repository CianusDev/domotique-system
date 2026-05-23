import { IsEmail } from 'class-validator';

export class ForgotPasswordDto {
  @IsEmail(
    {},
    {
      message: "L'adresse e-mail doit être valide",
    },
  )
  email: string;
}
