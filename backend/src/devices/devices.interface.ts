import { DeviceStatus } from 'generated/prisma/client';

export interface DeviceInterface {
  id: string;
  userId: string;
  name: string;
  macAddress: string;
  ipAddress?: string | null;
  status: DeviceStatus;
  firmwareVersion?: string | null;
  lastSeenAt?: Date | null;
  createdAt: Date;
  updatedAt: Date;
}
