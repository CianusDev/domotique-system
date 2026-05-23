import { Controller, Get } from '@nestjs/common';
import { Public } from './config/decorators/public.decorator';
import { EmailService } from './email/email.service';

@Public()
@Controller('app')
export class AppController {
  constructor(private readonly emailService: EmailService) {}

  @Get('verify-email-connection')
  async verifyEmailConnection() {
    await this.emailService.verifySmtpConnection();
    return { message: 'Email connection verified' };
  }
}
