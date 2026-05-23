import { Injectable } from '@nestjs/common';
import { Prisma } from 'generated/prisma/client';
import { PrismaService } from 'src/prisma/prisma.service';

@Injectable()
export class UsersRepository {
  constructor(private prisma: PrismaService) {}

  findOne(data: Prisma.UserWhereUniqueInput) {
    return this.prisma.user.findUnique({
      where: data,
    });
  }

  findAll(data?: Prisma.UserWhereInput) {
    return this.prisma.user.findMany({
      where: data,
    });
  }

  create(data: Prisma.UserCreateInput) {
    return this.prisma.user.create({
      data,
    });
  }

  update(where: Prisma.UserWhereUniqueInput, data: Prisma.UserUpdateInput) {
    return this.prisma.user.update({
      where,
      data,
    });
  }

  delete(data: Prisma.UserWhereUniqueInput) {
    return this.prisma.user.delete({
      where: data,
    });
  }
}
