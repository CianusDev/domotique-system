import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { DevicesModule } from 'src/devices/devices.module';
import { AppGateway } from './app.gateway';

@Module({
  imports: [
    DevicesModule,
    JwtModule.registerAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: (cs: ConfigService) => ({
        secret: cs.getOrThrow<string>('JWT_SECRET'),
      }),
    }),
  ],
  providers: [AppGateway],
})
export class GatewayModule {}
