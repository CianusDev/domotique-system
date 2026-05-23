import { IsInt, IsOptional, IsString, Min } from 'class-validator';

export class CreateActuatorDto {
  @IsString()
  type: string; // "relay", "led", "fan"

  @IsString()
  name: string;

  @IsInt()
  @Min(0)
  pin: number;
}

export class ControlActuatorDto {
  @IsString()
  command: string; // "on" | "off" | "toggle"

  @IsOptional()
  params?: Record<string, unknown>;
}
