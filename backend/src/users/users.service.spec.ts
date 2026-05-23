import { ConflictException, NotFoundException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { UsersRepository } from './users.repository';
import { UsersService } from './users.service';

const mockUser = {
  id: 'uuid-1',
  email: 'test@example.com',
  username: 'testuser',
  firstName: 'John',
  lastName: 'Doe',
  password: 'hashed-password',
  emailVerified: false,
  isActive: true,
  role: 'USER' as const,
  createdAt: new Date(),
};

const mockUsersRepository = {
  findOne: jest.fn(),
  findAll: jest.fn(),
  create: jest.fn(),
  update: jest.fn(),
  delete: jest.fn(),
};

describe('UsersService', () => {
  let service: UsersService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UsersService,
        { provide: UsersRepository, useValue: mockUsersRepository },
      ],
    }).compile();

    service = module.get<UsersService>(UsersService);
    jest.clearAllMocks();
  });

  describe('findOne', () => {
    it('should return a user when found', async () => {
      mockUsersRepository.findOne.mockResolvedValue(mockUser);

      const result = await service.findOne({ email: mockUser.email });

      expect(result).toEqual(mockUser);
      expect(mockUsersRepository.findOne).toHaveBeenCalledWith({
        email: mockUser.email,
      });
    });

    it('should return null when user does not exist', async () => {
      mockUsersRepository.findOne.mockResolvedValue(null);

      const result = await service.findOne({ email: 'unknown@example.com' });

      expect(result).toBeNull();
    });
  });

  describe('create', () => {
    it('should create a user successfully', async () => {
      mockUsersRepository.findOne.mockResolvedValue(null);
      mockUsersRepository.create.mockResolvedValue(mockUser);

      const result = await service.create({
        email: mockUser.email,
        username: mockUser.username,
        password: 'hashed-password',
      });

      expect(result).toEqual(mockUser);
      expect(mockUsersRepository.create).toHaveBeenCalledTimes(1);
    });

    it('should throw ConflictException if email is already in use', async () => {
      mockUsersRepository.findOne.mockResolvedValueOnce(mockUser);

      await expect(
        service.create({ email: mockUser.email, password: 'hashed' }),
      ).rejects.toThrow(ConflictException);

      expect(mockUsersRepository.create).not.toHaveBeenCalled();
    });

    it('should throw ConflictException if username is already taken', async () => {
      mockUsersRepository.findOne
        .mockResolvedValueOnce(null)
        .mockResolvedValueOnce(mockUser);

      await expect(
        service.create({
          email: 'new@example.com',
          username: mockUser.username,
          password: 'hashed',
        }),
      ).rejects.toThrow(ConflictException);

      expect(mockUsersRepository.create).not.toHaveBeenCalled();
    });
  });

  describe('delete', () => {
    it('should delete a user successfully', async () => {
      mockUsersRepository.findOne.mockResolvedValue(mockUser);
      mockUsersRepository.delete.mockResolvedValue(mockUser);

      await service.delete({ id: mockUser.id });

      expect(mockUsersRepository.delete).toHaveBeenCalledWith({
        id: mockUser.id,
      });
    });

    it('should throw NotFoundException if user does not exist', async () => {
      mockUsersRepository.findOne.mockResolvedValue(null);

      await expect(service.delete({ id: 'nonexistent-id' })).rejects.toThrow(
        NotFoundException,
      );

      expect(mockUsersRepository.delete).not.toHaveBeenCalled();
    });
  });

  describe('verifyEmail', () => {
    it('should mark the email as verified', async () => {
      const verifiedUser = { ...mockUser, emailVerified: true };
      mockUsersRepository.findOne.mockResolvedValue(mockUser);
      mockUsersRepository.update.mockResolvedValue(verifiedUser);

      const result = await service.verifyEmail(mockUser.email);

      expect(result.emailVerified).toBe(true);
      expect(mockUsersRepository.update).toHaveBeenCalledWith(
        { id: mockUser.id },
        { emailVerified: true },
      );
    });

    it('should throw NotFoundException if user does not exist', async () => {
      mockUsersRepository.findOne.mockResolvedValue(null);

      await expect(
        service.verifyEmail('unknown@example.com'),
      ).rejects.toThrow(NotFoundException);
    });
  });

  describe('resetPassword', () => {
    it('should update the user password', async () => {
      const updatedUser = { ...mockUser, password: 'new-hashed-password' };
      mockUsersRepository.findOne.mockResolvedValue(mockUser);
      mockUsersRepository.update.mockResolvedValue(updatedUser);

      const result = await service.resetPassword({
        email: mockUser.email,
        newPassword: 'new-hashed-password',
      });

      expect(mockUsersRepository.update).toHaveBeenCalledWith(
        { id: mockUser.id },
        { password: 'new-hashed-password' },
      );
      expect(result.password).toBe('new-hashed-password');
    });

    it('should throw NotFoundException if user does not exist', async () => {
      mockUsersRepository.findOne.mockResolvedValue(null);

      await expect(
        service.resetPassword({
          email: 'unknown@example.com',
          newPassword: 'new-password',
        }),
      ).rejects.toThrow(NotFoundException);
    });
  });
});
