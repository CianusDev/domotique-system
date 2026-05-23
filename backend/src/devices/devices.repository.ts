import { Injectable } from '@nestjs/common';
import { DeviceStatus, Prisma } from 'generated/prisma/client';
import { PrismaService } from 'src/prisma/prisma.service';

@Injectable()
export class DevicesRepository {
  constructor(private readonly prisma: PrismaService) {}

  findAll(userId: string) {
    return this.prisma.device.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
    });
  }

  findOne(where: Prisma.DeviceWhereUniqueInput) {
    return this.prisma.device.findUnique({ where });
  }

  findByMac(macAddress: string) {
    return this.prisma.device.findUnique({ where: { macAddress } });
  }

  create(data: Prisma.DeviceCreateInput) {
    return this.prisma.device.create({ data });
  }

  update(id: string, data: Prisma.DeviceUpdateInput) {
    return this.prisma.device.update({ where: { id }, data });
  }

  updateStatus(id: string, status: DeviceStatus, ipAddress?: string) {
    return this.prisma.device.update({
      where: { id },
      data: {
        status,
        lastSeenAt: status === DeviceStatus.ONLINE ? new Date() : undefined,
        ...(ipAddress && { ipAddress }),
      },
    });
  }

  delete(id: string) {
    return this.prisma.device.delete({ where: { id } });
  }
}
