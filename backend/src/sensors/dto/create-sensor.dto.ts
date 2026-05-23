import { IsInt, IsObject, IsOptional, IsString, Min } from 'class-validator';

export class CreateSensorDto {
  @IsString()
  sensorTypeId: string;

  @IsString()
  name: string;

  @IsInt()
  @Min(0)
  pin: number;

  @IsOptional()
  @IsObject()
  config?: Record<string, unknown>;
}
