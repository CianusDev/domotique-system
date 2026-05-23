import { IsEmail, Length, Matches } from 'class-validator';

export class VerifyEmailDto {
  @IsEmail(
    {},
    {
      message: "L'adresse e-mail doit être valide",
    },
  )
  email: string;
  @Length(6, 6, { message: 'Le code doit contenir exactement 6 caractères' })
  @Matches(/^\d{6}$/, {
    message: 'Le code doit contenir uniquement des chiffres',
  })
  code: string;
}
