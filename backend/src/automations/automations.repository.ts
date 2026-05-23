import { Injectable } from '@nestjs/common';
import { Prisma } from 'generated/prisma/client';
import { PrismaService } from 'src/prisma/prisma.service';

@Injectable()
export class AutomationsRepository {
  constructor(private readonly prisma: PrismaService) {}

  findAll(userId: string) {
    return this.prisma.automation.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });
  }

  findOne(id: string) {
    return this.prisma.automation.findUnique({ where: { id } });
  }

  findActiveBySensor(sensorId: string) {
    return this.prisma.automation.findMany({
      where: { sensorId, isActive: true },
    });
  }

  create(data: Prisma.AutomationCreateInput) {
    return this.prisma.automation.create({ data });
  }

  update(id: string, data: Prisma.AutomationUpdateInput) {
    return this.prisma.automation.update({ where: { id }, data });
  }

  delete(id: string) {
    return this.prisma.automation.delete({ where: { id } });
  }
}
