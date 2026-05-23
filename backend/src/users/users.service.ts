import {
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { UsersRepository } from './users.repository';
import { Prisma } from 'generated/prisma/client';

@Injectable()
export class UsersService {
  constructor(private readonly usersRepository: UsersRepository) {}

  async findOne(data: Prisma.UserWhereUniqueInput) {
    return await this.usersRepository.findOne(data);
  }

  async findAll() {
    return await this.usersRepository.findAll();
  }

  async create(data: Prisma.UserCreateInput) {
    if (data.email) {
      const existingByEmail = await this.findOne({ email: data.email });
      if (existingByEmail) {
        throw new ConflictException('Email already in use');
      }
    }

    if (data.username) {
      const existingByUsername = await this.findOne({
        username: data.username,
      });
      if (existingByUsername) {
        throw new ConflictException('Username already taken');
      }
    }

    return await this.usersRepository.create(data);
  }

  async update(
    where: Prisma.UserWhereUniqueInput,
    data: Prisma.UserUpdateInput,
  ) {
    return await this.usersRepository.update(where, data);
  }

  async delete(data: Prisma.UserWhereUniqueInput) {
    const existingUser = await this.findOne({
      email: data.email || undefined,
      username: data.username || undefined,
      id: data.id || undefined,
    });
    if (!existingUser) {
      throw new NotFoundException('User not found');
    }
    return await this.usersRepository.delete(data);
  }

  async verifyEmail(email: string) {
    const user = await this.findOne({ email });
    if (!user) {
      throw new NotFoundException('User not found');
    }
    const updatedUser = await this.update(
      { id: user.id },
      { emailVerified: true },
    );
    return updatedUser;
  }

  async resetPassword({
    email,
    newPassword,
  }: {
    email: string;
    newPassword: string;
  }) {
    const user = await this.findOne({ email });
    if (!user) {
      throw new NotFoundException('User not found');
    }
    const updatedUser = await this.update(
      { id: user.id },
      { password: newPassword },
    );
    return updatedUser;
  }
}
