import { Injectable } from '@nestjs/common';
import { Prisma } from 'generated/prisma/client';
import { PrismaService } from 'src/prisma/prisma.service';

@Injectable()
export class SensorTypesRepository {
  constructor(private readonly prisma: PrismaService) {}

  findAll(onlyActive = true) {
    return this.prisma.sensorTypeRegistry.findMany({
      where: onlyActive ? { isActive: true } : undefined,
      orderBy: { category: 'asc' },
    });
  }

  findOne(id: string) {
    return this.prisma.sensorTypeRegistry.findUnique({ where: { id } });
  }

  findByType(type: string) {
    return this.prisma.sensorTypeRegistry.findUnique({ where: { type } });
  }

  create(data: Prisma.SensorTypeRegistryCreateInput) {
    return this.prisma.sensorTypeRegistry.create({ data });
  }

  update(id: string, data: Prisma.SensorTypeRegistryUpdateInput) {
    return this.prisma.sensorTypeRegistry.update({ where: { id }, data });
  }
}
