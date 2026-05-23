import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Otp } from './otp.interface';
import { OtpRepository } from './otp.repository';
import { randomInt } from 'crypto';

@Injectable()
export class OtpService {
  private validityPeriod: number;
  private frontendUrl: string;
  constructor(
    private readonly otpRepository: OtpRepository,
    private readonly configService: ConfigService,
  ) {
    this.validityPeriod = 10 * 60 * 1000; // 10 minutes en millisecondes
    this.frontendUrl = this.configService.getOrThrow<string>('FRONTEND_URL');
  }

  private generateCode(length: number = 6): string {
    const digits = '0123456789';
    let otp = '';
    for (let i = 0; i < length; i++) {
      otp += digits[randomInt(0, digits.length)];
    }
    return otp;
  }

  async generateOTP(email: string) {
    await this.otpRepository.deleteByEmail(email);
    const code = this.generateCode();
    const expiresAt = new Date(Date.now() + this.validityPeriod);
    const otp = await this.otpRepository.create({
      code,
      expiresAt,
      email,
    });
    return otp;
  }

  async verifyOTP({
    email,
    code,
  }: {
    email: string;
    code: string;
  }): Promise<boolean> {
    const otp = await this.otpRepository.findOne({ code });
    if (!otp) return false;
    if (otp.code !== code) return false;
    if (otp.expiresAt < new Date()) return false;
    await this.otpRepository.delete({ id: otp.id });
    return true;
  }

  async generateResetLinkOTP(email: string) {
    await this.otpRepository.deleteByEmail(email);
    const otp = await this.generateOTP(email);
    const resetLink = `${this.frontendUrl}/reset-password?token=${otp.id}`;
    return resetLink;
  }

  async verifyResetLinkOTP(token: string): Promise<Otp | null> {
    const otp = await this.otpRepository.findOne({
      id: token,
    });
    if (!otp) {
      return null;
    }
    if (otp.expiresAt < new Date()) {
      return null;
    }
    await this.otpRepository.delete({ id: otp.id });
    return otp;
  }

  async cleanupExpiredOtps() {
    await this.otpRepository.deleteExpiredOtps();
  }
}
