import { Module } from '@nestjs/common';
import { OtpRepository } from './otp.repository';
import { OtpService } from './otp.service';
import { PrismaModule } from 'src/prisma/prisma.module';

@Module({
  imports: [PrismaModule],
  providers: [OtpRepository, OtpService],
  exports: [OtpService],
})
export class OtpModule {}
