import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { APP_GUARD } from '@nestjs/core';
import { EventEmitterModule } from '@nestjs/event-emitter';
import { ThrottlerGuard, ThrottlerModule } from '@nestjs/throttler';
import { AppController } from './app.controller';
import { AuthModule } from './auth/auth.module';
import { JwtAuthGuard } from './auth/guards/jwt-auth.guard';
import { EmailModule } from './email/email.module';
import { OtpModule } from './otp/otp.module';
import { PrismaModule } from './prisma/prisma.module';
import { UsersModule } from './users/users.module';
import { MqttModule } from './mqtt/mqtt.module';
import { DevicesModule } from './devices/devices.module';
import { SensorTypesModule } from './sensor-types/sensor-types.module';
import { SensorsModule } from './sensors/sensors.module';
import { ActuatorsModule } from './actuators/actuators.module';
import { AutomationsModule } from './automations/automations.module';
import { AlertsModule } from './alerts/alerts.module';
import { GatewayModule } from './gateway/gateway.module';

@Module({
  imports: [
    ConfigModule.forRoot({ envFilePath: '.env', isGlobal: true }),
    EventEmitterModule.forRoot(),
    ThrottlerModule.forRoot([
      { name: 'short', ttl: 5000, limit: 10 },
      { name: 'medium', ttl: 20000, limit: 20 },
      { name: 'long', ttl: 80000, limit: 100 },
    ]),
    PrismaModule,
    AuthModule,
    UsersModule,
    OtpModule,
    EmailModule,
    MqttModule,
    DevicesModule,
    SensorTypesModule,
    SensorsModule,
    ActuatorsModule,
    AutomationsModule,
    AlertsModule,
    GatewayModule,
  ],
  controllers: [AppController],
  providers: [
    {
      provide: APP_GUARD,
      useClass: ThrottlerGuard,
    },
    {
      provide: APP_GUARD,
      useClass: JwtAuthGuard,
    },
  ],
})
export class AppModule {}
