import {
  BadRequestException,
  Body,
  Controller,
  Get,
  HttpCode,
  HttpStatus,
  Post,
  Request,
  Res,
  UseGuards,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import type { Request as Req, Response } from 'express';
import type { ControllerResponse } from 'src/config/config.interface';
import { ACCESS_TOKEN_MAX_AGE } from 'src/config/constants';
import { UserWithoutPassword } from 'src/users/users.interface';
import { AuthService } from './auth.service';
import { ForgotPasswordDto } from './dto/forgot-password.dto';
import { RegisterDto } from './dto/register.dto';
import { ResendVerificationEmailDto } from './dto/resend-verification-email';
import { ResendResetPasswordDto } from './dto/resend-reset-password';
import { VerifyEmailDto } from './dto/verify-email';
import { VerifyResetPasswordDto } from './dto/verify-reset-password';
import { LocalAuthGuard } from './guards/local-auth.guard';
import { JwtPayload } from './strategies/jwt.strategy';
import { Throttle } from '@nestjs/throttler';
import { Public } from 'src/config/decorators/public.decorator';

@Controller('auth')
export class AuthController {
  private readonly isProduction: boolean;

  constructor(
    private readonly authService: AuthService,
    private readonly configService: ConfigService,
  ) {
    this.isProduction =
      this.configService.get<string>('NODE_ENV') === 'production';
  }

  @Public()
  @Throttle({
    default: { limit: 6, ttl: 6000 },
  })
  @Post('login')
  @HttpCode(HttpStatus.OK)
  @UseGuards(LocalAuthGuard)
  login(
    @Request() request: Req & { user: UserWithoutPassword },
    @Res({ passthrough: true }) response: Response,
  ): ControllerResponse {
    const user = this.authService.login(request.user);

    response.cookie('authentication', user.access_token, {
      httpOnly: true,
      secure: this.isProduction,
      sameSite: 'lax',
      maxAge: ACCESS_TOKEN_MAX_AGE,
    });

    return {
      success: true,
      message: 'User logged in successfully',
      data: user,
    };
  }

  @Public()
  @Throttle({
    default: { limit: 6, ttl: 6000 },
  })
  @Post('register')
  @HttpCode(HttpStatus.CREATED)
  async register(@Body() body: RegisterDto): Promise<ControllerResponse> {
    const user = await this.authService.register({
      ...body,
    });
    if (!user) {
      throw new BadRequestException('Registration failed');
    }
    return {
      success: true,
      message: 'User registered successfully',
      data: user,
    };
  }

  @Public()
  @Post('forgot-password')
  @HttpCode(HttpStatus.OK)
  async forgotPassword(
    @Body() body: ForgotPasswordDto,
  ): Promise<ControllerResponse> {
    const isSendEmail = await this.authService.forgotPassword(body);
    if (!isSendEmail) {
      throw new BadRequestException('Failed to send password reset email');
    }
    return {
      success: true,
      message: 'Password reset email sent successfully',
    };
  }

  @Public()
  @Post('resend-verification-email')
  @HttpCode(HttpStatus.OK)
  async resendVerificationEmail(@Body() body: ResendVerificationEmailDto) {
    const isSendEmail = await this.authService.resendVerificationEmail(body);
    if (!isSendEmail) {
      throw new BadRequestException('Failed to resend verification email');
    }
    return {
      success: true,
      message: 'Verification email resent successfully',
    };
  }

  @Public()
  @Post('verify-email')
  @HttpCode(HttpStatus.OK)
  async verifyEmail(
    @Body() body: VerifyEmailDto,
    @Res({ passthrough: true }) response: Response,
  ): Promise<ControllerResponse> {
    const user = await this.authService.verifyEmail(body);
    response.cookie('authentication', user.access_token, {
      httpOnly: true,
      secure: this.isProduction,
      sameSite: 'lax',
      maxAge: ACCESS_TOKEN_MAX_AGE,
    });
    return {
      success: true,
      message: 'Email verified successfully',
      data: user,
    };
  }

  @Public()
  @Post('reset-password')
  @HttpCode(HttpStatus.OK)
  async resetPassword(
    @Body() body: VerifyResetPasswordDto,
  ): Promise<ControllerResponse> {
    const user = await this.authService.resetPassword(body);
    return {
      success: true,
      message: 'Reset password verified successfully',
      data: user,
    };
  }

  @Public()
  @Post('resend-reset-password')
  @HttpCode(HttpStatus.OK)
  async resendResetPassword(@Body() body: ResendResetPasswordDto) {
    const isSendEmail = await this.authService.resendResetPassword(body);
    if (!isSendEmail) {
      throw new BadRequestException('Failed to resend reset password email');
    }
    return {
      success: true,
      message: 'Reset password email resent successfully',
    };
  }

  @Get('profile')
  @HttpCode(HttpStatus.OK)
  async profile(
    @Request() req: Request & { user: JwtPayload },
  ): Promise<ControllerResponse> {
    const user = req.user;
    const profile = await this.authService.profile(user.email);
    return {
      success: true,
      message: 'User profile fetched successfully',
      data: profile,
    };
  }

  @Post('logout')
  @HttpCode(HttpStatus.OK)
  logout(@Res({ passthrough: true }) response: Response): ControllerResponse {
    response.clearCookie('authentication', {
      httpOnly: true,
      secure: this.isProduction,
      sameSite: 'lax',
    });
    return {
      success: true,
      message: 'User logged out successfully',
    };
  }
}
