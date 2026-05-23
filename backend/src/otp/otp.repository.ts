import { Injectable } from '@nestjs/common';
import { Prisma } from 'generated/prisma/client';
import { PrismaService } from 'src/prisma/prisma.service';

@Injectable()
export class OtpRepository {
  constructor(private prisma: PrismaService) {}

  create(data: Prisma.OTPCreateInput) {
    return this.prisma.oTP.create({ data });
  }

  findOne(data: Prisma.OTPWhereUniqueInput) {
    return this.prisma.oTP.findUnique({
      where: data,
    });
  }

  findAll(data: Prisma.OTPWhereInput) {
    return this.prisma.oTP.findMany({
      where: data,
    });
  }

  delete(data: Prisma.OTPWhereUniqueInput) {
    return this.prisma.oTP.delete({
      where: data,
    });
  }

  deleteByEmail(email: string) {
    return this.prisma.oTP.deleteMany({ where: { email } });
  }

  async deleteExpiredOtps() {
    const now = new Date();
    await this.prisma.oTP.deleteMany({
      where: { expiresAt: { lt: now } },
    });
  }
}
