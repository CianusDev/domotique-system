import { IsArray, IsBoolean, IsOptional, IsString } from 'class-validator';

export class CreateSensorTypeDto {
  @IsString()
  type: string; // "DHT22", "PIR", etc.

  @IsString()
  name: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsArray()
  dataFields: object[]; // [{field:"temperature", unit:"°C", dataType:"float"}]

  @IsString()
  category: string; // "climate", "motion", etc.

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}
