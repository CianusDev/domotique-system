import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcryptjs';
import { emailTemplates } from 'src/config/email-templates';
import { EmailService } from 'src/email/email.service';
import { OtpService } from 'src/otp/otp.service';
import { UserWithoutPassword } from 'src/users/users.interface';
import { UsersService } from 'src/users/users.service';
import { ForgotPasswordDto } from './dto/forgot-password.dto';
import { RegisterDto } from './dto/register.dto';
import { ResendVerificationEmailDto } from './dto/resend-verification-email';
import { ResendResetPasswordDto } from './dto/resend-reset-password';
import { VerifyEmailDto } from './dto/verify-email';
import { VerifyResetPasswordDto } from './dto/verify-reset-password';
import { JwtPayload } from './strategies/jwt.strategy';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    private readonly userService: UsersService,
    private readonly otpService: OtpService,
    private readonly emailService: EmailService,
    private readonly jwtService: JwtService,
  ) {}

  private async hashPassword(password: string): Promise<string> {
    const saltRounds = 10;
    const hash = await bcrypt.hash(password, saltRounds);
    return hash;
  }

  private async comparePasswords(
    plainTextPassword: string,
    hashedPassword: string,
  ): Promise<boolean> {
    return await bcrypt.compare(plainTextPassword, hashedPassword);
  }

  private fullName(firstName: string | null, lastName: string | null) {
    return `${firstName || ''} ${lastName || ''}`;
  }

  async validateUser(
    email: string,
    password: string,
  ): Promise<UserWithoutPassword | null> {
    const user = await this.userService.findOne({ email });
    const passwordValid = await this.comparePasswords(
      password,
      user?.password || '',
    );
    if (!user || !passwordValid) {
      throw new BadRequestException('Incorrect email or password');
    }
    if (user) {
      return {
        id: user.id,
        email: user.email,
        firstName: user.firstName,
        lastName: user.lastName,
      };
    }
    return null;
  }

  login(data: UserWithoutPassword): {
    access_token: string;
    user: UserWithoutPassword;
  } {
    const payload: JwtPayload = { sub: data.id, email: data.email };
    const token = this.jwtService.sign(payload);
    return {
      access_token: token,
      user: data,
    };
  }

  async register(data: RegisterDto): Promise<UserWithoutPassword | null> {
    const user = await this.userService.create({
      ...data,
      password: await this.hashPassword(data.password),
    });
    const otp = await this.otpService.generateOTP(user.email);
    await this.emailService.sendEmail({
      to: user.email,
      subject: emailTemplates.verificationEmail.subject,
      html: emailTemplates.verificationEmail.html({
        code: otp.code,
        fullName: this.fullName(user.firstName, user.lastName),
      }),
    });
    return {
      id: user.id,
      email: user.email,
      username: user.username,
      firstName: user.firstName,
      lastName: user.lastName,
      emailVerified: user.emailVerified,
    };
  }

  async forgotPassword(data: ForgotPasswordDto) {
    const existingUser = await this.userService.findOne({ email: data.email });
    if (!existingUser) {
      return true;
    }
    const otp = await this.otpService.generateOTP(existingUser.email);
    await this.emailService.sendEmail({
      to: existingUser.email,
      subject: emailTemplates.resetPasswordOtp.subject,
      html: emailTemplates.resetPasswordOtp.html({
        code: otp.code,
        fullName: this.fullName(existingUser.firstName, existingUser.lastName),
      }),
    });
    return true;
  }

  async resendVerificationEmail(data: ResendVerificationEmailDto) {
    const user = await this.userService.findOne({ email: data.email });
    if (!user) {
      return true;
    }
    const otp = await this.otpService.generateOTP(user.email);
    await this.emailService.sendEmail({
      to: user.email,
      subject: emailTemplates.verificationEmail.subject,
      html: emailTemplates.verificationEmail.html({
        code: otp.code,
        fullName: this.fullName(user.firstName, user.lastName),
      }),
    });
    return true;
  }

  async verifyEmail(data: VerifyEmailDto): Promise<{
    access_token: string;
    user: UserWithoutPassword;
  }> {
    const isVerified = await this.otpService.verifyOTP(data);
    if (!isVerified) {
      throw new BadRequestException('Invalid or expired verification code.');
    }
    const updatedUser = await this.userService.verifyEmail(data.email);
    const payload: JwtPayload = {
      sub: updatedUser.id,
      email: updatedUser.email,
    };
    const token = this.jwtService.sign(payload);
    return {
      access_token: token,
      user: {
        id: updatedUser.id,
        email: updatedUser.email,
        username: updatedUser.username,
        firstName: updatedUser.firstName,
        lastName: updatedUser.lastName,
        emailVerified: updatedUser.emailVerified,
      },
    };
  }

  async resendResetPassword(data: ResendResetPasswordDto) {
    const user = await this.userService.findOne({ email: data.email });
    if (!user) {
      return true;
    }
    const otp = await this.otpService.generateOTP(user.email);
    await this.emailService.sendEmail({
      to: user.email,
      subject: emailTemplates.resetPasswordOtp.subject,
      html: emailTemplates.resetPasswordOtp.html({
        code: otp.code,
        fullName: this.fullName(user.firstName, user.lastName),
      }),
    });
    return true;
  }

  async resetPassword(data: VerifyResetPasswordDto) {
    const isValid = await this.otpService.verifyOTP({
      email: data.email,
      code: data.code,
    });
    if (!isValid) {
      throw new BadRequestException('Code invalide ou expiré.');
    }

    const updatedUser = await this.userService.resetPassword({
      email: data.email,
      newPassword: await this.hashPassword(data.newPassword),
    });

    const payload: JwtPayload = {
      sub: updatedUser.id,
      email: updatedUser.email,
    };

    const token = this.jwtService.sign(payload);
    return {
      access_token: token,
      user: {
        id: updatedUser.id,
        email: updatedUser.email,
        username: updatedUser.username,
        firstName: updatedUser.firstName,
        lastName: updatedUser.lastName,
        emailVerified: updatedUser.emailVerified,
      },
    };
  }

  async profile(email: string): Promise<UserWithoutPassword> {
    const user = await this.userService.findOne({ email });
    if (!user) {
      throw new NotFoundException('User not found');
    }
    return {
      id: user.id,
      email: user.email,
      username: user.username,
      emailVerified: user.emailVerified,
      firstName: user.firstName,
      lastName: user.lastName,
    };
  }
}
