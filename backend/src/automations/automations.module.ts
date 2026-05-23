import { Module } from '@nestjs/common';
import { ActuatorsModule } from 'src/actuators/actuators.module';
import { PrismaModule } from 'src/prisma/prisma.module';
import { AutomationsController } from './automations.controller';
import { AutomationsRepository } from './automations.repository';
import { AutomationsService } from './automations.service';

@Module({
  imports: [PrismaModule, ActuatorsModule],
  controllers: [AutomationsController],
  providers: [AutomationsService, AutomationsRepository],
})
export class AutomationsModule {}
