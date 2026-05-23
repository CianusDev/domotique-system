import { Injectable } from '@nestjs/common';
import { Prisma, SensorStatus } from 'generated/prisma/client';
import { PrismaService } from 'src/prisma/prisma.service';

@Injectable()
export class SensorsRepository {
  constructor(private readonly prisma: PrismaService) {}

  findAllByDevice(deviceId: string) {
    return this.prisma.sensor.findMany({
      where: { deviceId },
      include: { sensorType: true },
      orderBy: { createdAt: 'asc' },
    });
  }

  findOne(id: string) {
    return this.prisma.sensor.findUnique({
      where: { id },
      include: { sensorType: true, device: true },
    });
  }

  findByDeviceAndPin(deviceId: string, pin: number) {
    return this.prisma.sensor.findUnique({ where: { deviceId_pin: { deviceId, pin } } });
  }

  create(data: Prisma.SensorCreateInput) {
    return this.prisma.sensor.create({ data, include: { sensorType: true } });
  }

  updateStatus(id: string, status: SensorStatus) {
    return this.prisma.sensor.update({
      where: { id },
      data: { status, ...(status === SensorStatus.ACTIVE ? { lastReadAt: new Date() } : {}) },
    });
  }

  delete(id: string) {
    return this.prisma.sensor.delete({ where: { id } });
  }

  // ── Sensor data ──────────────────────────────

  recordData(sensorId: string, data: Record<string, unknown>) {
    return this.prisma.sensorData.create({
      data: { sensorId, data: data as Prisma.InputJsonValue },
    });
  }

  findData(sensorId: string, from?: Date, to?: Date, limit = 100) {
    return this.prisma.sensorData.findMany({
      where: {
        sensorId,
        recordedAt: {
          ...(from ? { gte: from } : {}),
          ...(to ? { lte: to } : {}),
        },
      },
      orderBy: { recordedAt: 'desc' },
      take: limit,
    });
  }

  updateLastRead(id: string) {
    return this.prisma.sensor.update({
      where: { id },
      data: { lastReadAt: new Date() },
    });
  }
}
