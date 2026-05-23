import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { OtpService } from './otp.service';
import { OtpRepository } from './otp.repository';

const FRONTEND_URL = 'http://localhost:3000';

const mockOtp = {
  id: 'otp-uuid-1',
  code: '123456',
  email: 'test@example.com',
  expiresAt: new Date(Date.now() + 10 * 60 * 1000),
  createdAt: new Date(),
};

const expiredOtp = {
  ...mockOtp,
  expiresAt: new Date(Date.now() - 1000),
};

const mockOtpRepository = {
  create: jest.fn(),
  findOne: jest.fn(),
  findAll: jest.fn(),
  delete: jest.fn(),
  deleteByEmail: jest.fn(),
  deleteExpiredOtps: jest.fn(),
};

const mockConfigService = {
  getOrThrow: jest.fn().mockReturnValue(FRONTEND_URL),
};

describe('OtpService', () => {
  let service: OtpService;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        OtpService,
        { provide: OtpRepository, useValue: mockOtpRepository },
        { provide: ConfigService, useValue: mockConfigService },
      ],
    }).compile();

    service = module.get<OtpService>(OtpService);
    jest.clearAllMocks();
  });

  describe('generateOTP', () => {
    it('should delete existing OTP and create a new one', async () => {
      mockOtpRepository.deleteByEmail.mockResolvedValue(null);
      mockOtpRepository.create.mockResolvedValue(mockOtp);

      const result = await service.generateOTP(mockOtp.email);

      expect(mockOtpRepository.deleteByEmail).toHaveBeenCalledWith(mockOtp.email);
      expect(mockOtpRepository.create).toHaveBeenCalledTimes(1);
      expect(result.email).toBe(mockOtp.email);
      expect(result.code).toHaveLength(6);
    });

    it('should generate a 6-digit numeric code', async () => {
      mockOtpRepository.delete.mockResolvedValue(null);
      mockOtpRepository.create.mockImplementation((data: { code: string }) =>
        Promise.resolve({ ...mockOtp, code: data.code }),
      );

      const result = await service.generateOTP(mockOtp.email);

      expect(result.code).toMatch(/^\d{6}$/);
    });

    it('should set expiry 10 minutes in the future', async () => {
      const before = Date.now();
      mockOtpRepository.delete.mockResolvedValue(null);
      mockOtpRepository.create.mockImplementation(
        (data: { expiresAt: string }) =>
          Promise.resolve({ ...mockOtp, expiresAt: data.expiresAt }),
      );

      const result = await service.generateOTP(mockOtp.email);

      const expiresMs = result.expiresAt.getTime();
      expect(expiresMs).toBeGreaterThanOrEqual(before + 10 * 60 * 1000 - 100);
      expect(expiresMs).toBeLessThanOrEqual(before + 10 * 60 * 1000 + 1000);
    });
  });

  describe('verifyOTP', () => {
    it('should return false if no OTP found for email', async () => {
      mockOtpRepository.findOne.mockResolvedValue(null);

      const result = await service.verifyOTP({
        email: mockOtp.email,
        code: '123456',
      });

      expect(result).toBe(false);
    });

    it('should return false if code does not match', async () => {
      mockOtpRepository.findOne.mockResolvedValue(mockOtp);

      const result = await service.verifyOTP({
        email: mockOtp.email,
        code: '000000',
      });

      expect(result).toBe(false);
      expect(mockOtpRepository.delete).not.toHaveBeenCalled();
    });

    it('should return false if OTP is expired', async () => {
      mockOtpRepository.findOne.mockResolvedValue(expiredOtp);

      const result = await service.verifyOTP({
        email: expiredOtp.email,
        code: expiredOtp.code,
      });

      expect(result).toBe(false);
      expect(mockOtpRepository.delete).not.toHaveBeenCalled();
    });

    it('should return true and delete the OTP when valid', async () => {
      mockOtpRepository.findOne.mockResolvedValue(mockOtp);
      mockOtpRepository.delete.mockResolvedValue(null);

      const result = await service.verifyOTP({
        email: mockOtp.email,
        code: mockOtp.code,
      });

      expect(result).toBe(true);
      expect(mockOtpRepository.delete).toHaveBeenCalledWith({ id: mockOtp.id });
    });
  });

  describe('generateResetLinkOTP', () => {
    it('should return a reset link containing the OTP id', async () => {
      mockOtpRepository.delete.mockResolvedValue(null);
      mockOtpRepository.create.mockResolvedValue(mockOtp);

      const link = await service.generateResetLinkOTP(mockOtp.email);

      expect(link).toBe(`${FRONTEND_URL}/reset-password?token=${mockOtp.id}`);
    });

    it('should delete the existing OTP before creating a new one', async () => {
      mockOtpRepository.deleteByEmail.mockResolvedValue(null);
      mockOtpRepository.create.mockResolvedValue(mockOtp);

      await service.generateResetLinkOTP(mockOtp.email);

      expect(mockOtpRepository.deleteByEmail).toHaveBeenCalledWith(mockOtp.email);
    });
  });

  describe('verifyResetLinkOTP', () => {
    it('should return null if token not found', async () => {
      mockOtpRepository.findOne.mockResolvedValue(null);

      const result = await service.verifyResetLinkOTP('nonexistent-token');

      expect(result).toBeNull();
    });

    it('should return null if OTP is expired', async () => {
      mockOtpRepository.findOne.mockResolvedValue(expiredOtp);

      const result = await service.verifyResetLinkOTP(expiredOtp.id);

      expect(result).toBeNull();
      expect(mockOtpRepository.delete).not.toHaveBeenCalled();
    });

    it('should return the OTP and delete it when valid', async () => {
      mockOtpRepository.findOne.mockResolvedValue(mockOtp);
      mockOtpRepository.delete.mockResolvedValue(null);

      const result = await service.verifyResetLinkOTP(mockOtp.id);

      expect(result).toEqual(mockOtp);
      expect(mockOtpRepository.delete).toHaveBeenCalledWith({ id: mockOtp.id });
    });
  });

  describe('cleanupExpiredOtps', () => {
    it('should call deleteExpiredOtps on the repository', async () => {
      mockOtpRepository.deleteExpiredOtps.mockResolvedValue(undefined);

      await service.cleanupExpiredOtps();

      expect(mockOtpRepository.deleteExpiredOtps).toHaveBeenCalledTimes(1);
    });
  });
});
