import { IsOptional, IsString, Matches } from 'class-validator';

export class CreateDeviceDto {
  @IsString()
  name: string;

  @IsString()
  @Matches(/^([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}$/, {
    message: 'macAddress must be a valid MAC address (XX:XX:XX:XX:XX:XX)',
  })
  macAddress: string;

  @IsOptional()
  @IsString()
  ipAddress?: string;

  @IsOptional()
  @IsString()
  firmwareVersion?: string;
}
