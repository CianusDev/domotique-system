import { IsBoolean, IsObject, IsOptional, IsString } from 'class-validator';

export class CreateAlertDto {
  @IsString()
  sensorId: string;

  @IsString()
  name: string;

  /**
   * Condition: { field, operator (">"|"<"|">="|"<="|"=="|"!="), value }
   */
  @IsObject()
  condition: {
    field: string;
    operator: string;
    value: number | string | boolean;
  };

  @IsOptional()
  @IsString()
  message?: string;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}
