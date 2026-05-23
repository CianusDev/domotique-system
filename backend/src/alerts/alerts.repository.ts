import { Injectable } from '@nestjs/common';
import { Prisma } from 'generated/prisma/client';
import { PrismaService } from 'src/prisma/prisma.service';

@Injectable()
export class AlertsRepository {
  constructor(private readonly prisma: PrismaService) {}

  findAll(userId: string) {
    return this.prisma.alert.findMany({ where: { userId }, orderBy: { createdAt: 'desc' } });
  }

  findOne(id: string) {
    return this.prisma.alert.findUnique({ where: { id } });
  }

  findActiveBySensor(sensorId: string) {
    return this.prisma.alert.findMany({ where: { sensorId, isActive: true } });
  }

  create(data: Prisma.AlertCreateInput) {
    return this.prisma.alert.create({ data });
  }

  update(id: string, data: Prisma.AlertUpdateInput) {
    return this.prisma.alert.update({ where: { id }, data });
  }

  delete(id: string) {
    return this.prisma.alert.delete({ where: { id } });
  }
}
