import { ApiPropertyOptional } from '@nestjs/swagger';
import {
  IsEmail,
  IsNotEmpty,
  IsOptional,
  IsString,
  IsStrongPassword,
  MaxLength,
  MinLength,
} from 'class-validator';

export class RegisterDto {
  @IsString({
    message: "Le nom d'utilisateur doit être une chaîne de caractères",
  })
  @IsNotEmpty({
    message: "Le nom d'utilisateur ne peut pas être vide",
  })
  username: string;
  @ApiPropertyOptional({
    description: "Prénom de l'utilisateur",
    example: 'Jean',
  })
  @IsOptional()
  @IsString({ message: 'Le prénom doit être une chaîne de caractères' })
  @MaxLength(50, { message: 'Le prénom ne peut pas dépasser 50 caractères' })
  firstName?: string;

  @ApiPropertyOptional({
    description: "Nom de l'utilisateur",
    example: 'Dupont',
  })
  @IsOptional()
  @IsString({ message: 'Le nom doit être une chaîne de caractères' })
  @MaxLength(50, { message: 'Le nom ne peut pas dépasser 50 caractères' })
  lastName?: string;
  @IsEmail(
    {},
    {
      message: "L'adresse e-mail doit être valide",
    },
  )
  email: string;
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
  password: string;
}
