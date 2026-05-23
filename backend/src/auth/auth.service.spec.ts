import { BadRequestException, NotFoundException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Test, TestingModule } from '@nestjs/testing';
import * as bcrypt from 'bcrypt';
import { EmailService } from 'src/email/email.service';
import { OtpService } from 'src/otp/otp.service';
import { UsersService } from 'src/users/users.service';
import { AuthService } from './auth.service';

jest.mock('bcrypt');

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

const mockOtp = {
  id: 'otp-uuid-1',
  code: '123456',
  email: mockUser.email,
  expiresAt: new Date(Date.now() + 10 * 60 * 1000),
  createdAt: new Date(),
};

const mockUsersService = {
  findOne: jest.fn(),
  create: jest.fn(),
  verifyEmail: jest.fn(),
  resetPassword: jest.fn(),
};

const mockOtpService = {
  generateOTP: jest.fn(),
  verifyOTP: jest.fn(),
  generateResetLinkOTP: jest.fn(),
  verifyResetLinkOTP: jest.fn(),
};

const mockEmailService = {
  sendEmail: jest.fn(),
};

const mockJwtService = {
  sign: jest.fn().mockReturnValue('signed-jwt-token'),
};

describe('AuthService', () => {
  let service: AuthService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        AuthService,
        { provide: UsersService, useValue: mockUsersService },
        { provide: OtpService, useValue: mockOtpService },
        { provide: EmailService, useValue: mockEmailService },
        { provide: JwtService, useValue: mockJwtService },
      ],
    }).compile();

    service = module.get<AuthService>(AuthService);
    jest.clearAllMocks();
  });

  describe('validateUser', () => {
    it('should return user data without password when credentials are valid', async () => {
      mockUsersService.findOne.mockResolvedValue(mockUser);
      (bcrypt.compare as jest.Mock).mockResolvedValue(true);

      const result = await service.validateUser(mockUser.email, 'plain-password');

      expect(result).toEqual({
        id: mockUser.id,
        email: mockUser.email,
        firstName: mockUser.firstName,
        lastName: mockUser.lastName,
      });
      expect(result).not.toHaveProperty('password');
    });

    it('should throw BadRequestException when password is incorrect', async () => {
      mockUsersService.findOne.mockResolvedValue(mockUser);
      (bcrypt.compare as jest.Mock).mockResolvedValue(false);

      await expect(
        service.validateUser(mockUser.email, 'wrong-password'),
      ).rejects.toThrow(BadRequestException);
    });

    it('should throw BadRequestException when user does not exist', async () => {
      mockUsersService.findOne.mockResolvedValue(null);
      (bcrypt.compare as jest.Mock).mockResolvedValue(false);

      await expect(
        service.validateUser('unknown@example.com', 'any-password'),
      ).rejects.toThrow(BadRequestException);
    });
  });

  describe('login', () => {
    it('should return an access_token and the user', () => {
      const { password: _, ...userWithoutPassword } = mockUser;

      const result = service.login(userWithoutPassword);

      expect(mockJwtService.sign).toHaveBeenCalledWith({
        sub: mockUser.id,
        email: mockUser.email,
      });
      expect(result.access_token).toBe('signed-jwt-token');
      expect(result.user).toEqual(userWithoutPassword);
    });
  });

  describe('register', () => {
    it('should create user, generate OTP and send verification email', async () => {
      (bcrypt.hash as jest.Mock).mockResolvedValue('hashed-password');
      mockUsersService.create.mockResolvedValue(mockUser);
      mockOtpService.generateOTP.mockResolvedValue(mockOtp);
      mockEmailService.sendEmail.mockResolvedValue(undefined);

      const result = await service.register({
        email: mockUser.email,
        username: mockUser.username!,
        password: 'plain-password',
      });

      expect(mockUsersService.create).toHaveBeenCalledTimes(1);
      expect(mockOtpService.generateOTP).toHaveBeenCalledWith(mockUser.email);
      expect(mockEmailService.sendEmail).toHaveBeenCalledTimes(1);
      expect(result).not.toHaveProperty('password');
      expect(result?.email).toBe(mockUser.email);
    });
  });

  describe('forgotPassword', () => {
    it('should return true without sending email if user does not exist', async () => {
      mockUsersService.findOne.mockResolvedValue(null);

      const result = await service.forgotPassword({ email: 'unknown@example.com' });

      expect(result).toBe(true);
      expect(mockOtpService.generateResetLinkOTP).not.toHaveBeenCalled();
      expect(mockEmailService.sendEmail).not.toHaveBeenCalled();
    });

    it('should generate reset link and send email when user exists', async () => {
      const resetLink = 'http://localhost:3000/reset-password?token=otp-uuid-1';
      mockUsersService.findOne.mockResolvedValue(mockUser);
      mockOtpService.generateResetLinkOTP.mockResolvedValue(resetLink);
      mockEmailService.sendEmail.mockResolvedValue(undefined);

      const result = await service.forgotPassword({ email: mockUser.email });

      expect(result).toBe(true);
      expect(mockOtpService.generateResetLinkOTP).toHaveBeenCalledWith(mockUser.email);
      expect(mockEmailService.sendEmail).toHaveBeenCalledTimes(1);
    });
  });

  describe('verifyEmail', () => {
    it('should verify email, sign token and return user', async () => {
      const verifiedUser = { ...mockUser, emailVerified: true };
      mockOtpService.verifyOTP.mockResolvedValue(true);
      mockUsersService.verifyEmail.mockResolvedValue(verifiedUser);

      const result = await service.verifyEmail({
        email: mockUser.email,
        code: mockOtp.code,
      });

      expect(mockUsersService.verifyEmail).toHaveBeenCalledWith(mockUser.email);
      expect(result.access_token).toBe('signed-jwt-token');
      expect(result.user.emailVerified).toBe(true);
    });

    it('should throw BadRequestException when OTP is invalid', async () => {
      mockOtpService.verifyOTP.mockResolvedValue(false);

      await expect(
        service.verifyEmail({ email: mockUser.email, code: '000000' }),
      ).rejects.toThrow(BadRequestException);

      expect(mockUsersService.verifyEmail).not.toHaveBeenCalled();
    });
  });

  describe('resetPassword', () => {
    it('should reset password and return a new token', async () => {
      const updatedUser = { ...mockUser, password: 'new-hashed' };
      mockOtpService.verifyResetLinkOTP.mockResolvedValue(mockOtp);
      (bcrypt.hash as jest.Mock).mockResolvedValue('new-hashed');
      mockUsersService.resetPassword.mockResolvedValue(updatedUser);

      const result = await service.resetPassword({
        token: mockOtp.id,
        newPassword: 'NewPassword1!',
      });

      expect(mockUsersService.resetPassword).toHaveBeenCalledWith({
        email: mockOtp.email,
        newPassword: 'new-hashed',
      });
      expect(result.access_token).toBe('signed-jwt-token');
    });

    it('should throw BadRequestException when reset token is invalid', async () => {
      mockOtpService.verifyResetLinkOTP.mockResolvedValue(null);

      await expect(
        service.resetPassword({ token: 'invalid-token', newPassword: 'New1!' }),
      ).rejects.toThrow(BadRequestException);

      expect(mockUsersService.resetPassword).not.toHaveBeenCalled();
    });
  });

  describe('profile', () => {
    it('should return user profile without password', async () => {
      mockUsersService.findOne.mockResolvedValue(mockUser);

      const result = await service.profile(mockUser.email);

      expect(result.email).toBe(mockUser.email);
      expect(result).not.toHaveProperty('password');
    });

    it('should throw NotFoundException when user does not exist', async () => {
      mockUsersService.findOne.mockResolvedValue(null);

      await expect(
        service.profile('unknown@example.com'),
      ).rejects.toThrow(NotFoundException);
    });
  });
});
