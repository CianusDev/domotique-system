import { SensorStatus } from 'generated/prisma/client';

export interface SensorInterface {
  id: string;
  deviceId: string;
  sensorTypeId: string;
  name: string;
  pin: number;
  status: SensorStatus;
  config?: unknown | null;
  lastReadAt?: Date | null;
  createdAt: Date;
  updatedAt: Date;
}

export interface SensorDataInterface {
  id: string;
  sensorId: string;
  data: unknown;
  recordedAt: Date;
}
