import { Module } from '@nestjs/common';
import { PrismaModule } from 'src/prisma/prisma.module';
import { DevicesModule } from 'src/devices/devices.module';
import { ActuatorsController } from './actuators.controller';
import { ActuatorsRepository } from './actuators.repository';
import { ActuatorsService } from './actuators.service';

@Module({
  imports: [PrismaModule, DevicesModule],
  controllers: [ActuatorsController],
  providers: [ActuatorsService, ActuatorsRepository],
  exports: [ActuatorsService, ActuatorsRepository],
})
export class ActuatorsModule {}
