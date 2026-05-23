import {
  IsNotEmpty,
  IsString,
  IsStrongPassword,
  MinLength,
} from 'class-validator';

export class VerifyResetPasswordDto {
  @IsString({
    message: 'Le token doit être une chaîne de caractères',
  })
  @IsNotEmpty({
    message: 'Le token ne peut pas être vide',
  })
  token: string;

  @IsString({
    message: 'Le mot de passe doit être une chaîne de caractères',
  })
  @IsNotEmpty({
    message: 'Le mot de passe ne peut pas être vide',
  })
  @MinLength(8, {
    message: 'Le mot de passe doit contenir au moins 8 caractères',
  })
  @IsStrongPassword(
    {
      minLength: 8,
      minLowercase: 1,
      minUppercase: 1,
      minNumbers: 1,
      minSymbols: 1,
    },
    {
      message:
        'Le mot de passe doit contenir au moins 8 caractères, une majuscule, une minuscule, un chiffre et un caractère spécial',
    },
  )
  newPassword: string;
}
