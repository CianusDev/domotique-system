import {
  Injectable,
  InternalServerErrorException,
  Logger,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import nodemailer from 'nodemailer';
import { EmailOptions } from './email.interface';
import { APP_NAME } from 'src/config/constants';

@Injectable()
export class EmailService {
  private readonly logger = new Logger(EmailService.name);

  constructor(private readonly configService: ConfigService) {}

  private createGmailTransporter() {
    return nodemailer.createTransport({
      host: 'smtp.gmail.com',
      port: 587,
      secure: false,
      auth: {
        user: this.configService.getOrThrow<string>('GMAIL_USER'),
        pass: this.configService.getOrThrow<string>('GMAIL_PASS'),
      },
    });
  }

  async sendEmail(options: EmailOptions) {
    const gmailUser = this.configService.getOrThrow<string>('GMAIL_USER');
    const defaultEmailOptions = {
      from: `"${APP_NAME}" <${gmailUser}>`,
    };
    const transporter = this.createGmailTransporter();

    const mailOptions = {
      ...defaultEmailOptions,
      ...options,
    };

    try {
      const info = await transporter.sendMail(mailOptions);
      this.logger.debug(`Email sent successfully: ${info.messageId}`);
      return info;
    } catch (error) {
      this.logger.error('Failed to send email:', error);
      throw new InternalServerErrorException('Failed to send email');
    }
  }

  async verifySmtpConnection() {
    try {
      const transporter = this.createGmailTransporter();
      await transporter.verify();
      this.logger.log('SMTP Gmail connection verified successfully');
      return true;
    } catch (error) {
      this.logger.error('SMTP Gmail connection error:', error);
      return false;
    }
  }
}
