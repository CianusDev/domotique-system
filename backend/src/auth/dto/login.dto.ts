import { ApiProperty } from '@nestjs/swagger';
import { IsEmail, IsString } from 'class-validator';

export class LoginDto {
  @ApiProperty({
    description: "Adresse email de l'utilisateur",
    example: 'user@example.com',
  })
  @IsEmail({}, { message: "L'adresse e-mail doit être valide" })
  email: string;

  @ApiProperty({
    description: "Mot de passe de l'utilisateur",
    example: 'MonMotDePasse123!',
  })
  @IsString({ message: 'Le mot de passe doit être une chaîne de caractères' })
  password: string;
}
