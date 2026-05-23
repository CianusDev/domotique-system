import { Injectable } from '@nestjs/common';
import { Prisma } from 'generated/prisma/client';
import { PrismaService } from 'src/prisma/prisma.service';

@Injectable()
export class ActuatorsRepository {
  constructor(private readonly prisma: PrismaService) {}

  findAllByDevice(deviceId: string) {
    return this.prisma.actuator.findMany({ where: { deviceId }, orderBy: { createdAt: 'asc' } });
  }

  findOne(id: string) {
    return this.prisma.actuator.findUnique({ where: { id }, include: { device: true } });
  }

  findByDeviceAndPin(deviceId: string, pin: number) {
    return this.prisma.actuator.findUnique({ where: { deviceId_pin: { deviceId, pin } } });
  }

  create(data: Prisma.ActuatorCreateInput) {
    return this.prisma.actuator.create({ data });
  }

  updateState(id: string, state: string) {
    return this.prisma.actuator.update({ where: { id }, data: { state } });
  }

  delete(id: string) {
    return this.prisma.actuator.delete({ where: { id } });
  }
}
