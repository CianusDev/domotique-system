import { IsBoolean, IsObject, IsOptional, IsString } from 'class-validator';

export class CreateAutomationDto {
  @IsString()
  name: string;

  @IsOptional()
  @IsString()
  description?: string;

  /**
   * Trigger: { sensorId, field, operator (">"|"<"|">="|"<="|"=="|"!="), value }
   */
  @IsObject()
  trigger: {
    sensorId: string;
    field: string;
    operator: string;
    value: number | string | boolean;
  };

  /**
   * Action: { actuatorId, command } or { type: "notification", message }
   */
  @IsObject()
  action: Record<string, unknown>;

  @IsOptional()
  @IsBoolean()
  isActive?: boolean;
}
