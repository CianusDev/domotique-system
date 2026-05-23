import { Module } from '@nestjs/common';
import { PrismaModule } from 'src/prisma/prisma.module';
import { DevicesModule } from 'src/devices/devices.module';
import { SensorTypesModule } from 'src/sensor-types/sensor-types.module';
import { SensorsController } from './sensors.controller';
import { SensorsRepository } from './sensors.repository';
import { SensorsService } from './sensors.service';

@Module({
  imports: [PrismaModule, DevicesModule, SensorTypesModule],
  controllers: [SensorsController],
  providers: [SensorsService, SensorsRepository],
  exports: [SensorsService, SensorsRepository],
})
export class SensorsModule {}
