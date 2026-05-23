import { Module } from '@nestjs/common';
import { PrismaModule } from 'src/prisma/prisma.module';
import { SensorTypesController } from './sensor-types.controller';
import { SensorTypesRepository } from './sensor-types.repository';
import { SensorTypesService } from './sensor-types.service';

@Module({
  imports: [PrismaModule],
  controllers: [SensorTypesController],
  providers: [SensorTypesService, SensorTypesRepository],
  exports: [SensorTypesService],
})
export class SensorTypesModule {}
