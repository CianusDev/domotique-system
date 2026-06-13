import {
  IsEmail,
  IsNotEmpty,
  IsString,
  IsStrongPassword,
  Length,
  MinLength,
} from 'class-validator';

export class VerifyResetPasswordDto {
  @IsEmail({}, { message: "L'adresse e-mail est invalide" })
  @IsNotEmpty({ message: "L'e-mail ne peut pas être vide" })
  email: string;

  @IsString({ message: 'Le code doit être une chaîne de caractères' })
  @Length(6, 6, { message: 'Le code doit contenir exactement 6 chiffres' })
  @IsNotEmpty({ message: 'Le code ne peut pas être vide' })
  code: string;

  @IsString({ message: 'Le mot de passe doit être une chaîne de caractères' })
  @IsNotEmpty({ message: 'Le mot de passe ne peut pas être vide' })
  @MinLength(8, { message: 'Le mot de passe doit contenir au moins 8 caractères' })
  @IsStrongPassword(
    { minLength: 8, minLowercase: 1, minUppercase: 1, minNumbers: 1, minSymbols: 1 },
    {
      message:
        'Le mot de passe doit contenir au moins 8 caractères, une majuscule, une minuscule, un chiffre et un caractère spécial',
    },
  )
  newPassword: string;
}
