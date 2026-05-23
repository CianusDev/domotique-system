import { Body, Controller, Delete, Get, HttpCode, HttpStatus, Param, Post, Request } from '@nestjs/common';
import { JwtPayload } from 'src/auth/strategies/jwt.strategy';
import type { ControllerResponse } from 'src/config/config.interface';
import { ActuatorsService } from './actuators.service';
import { ControlActuatorDto, CreateActuatorDto } from './dto/create-actuator.dto';

@Controller()
export class ActuatorsController {
  constructor(private readonly actuatorsService: ActuatorsService) {}

  @Get('devices/:deviceId/actuators')
  async findAll(@Param('deviceId') deviceId: string): Promise<ControllerResponse> {
    const actuators = await this.actuatorsService.findAllByDevice(deviceId);
    return { success: true, message: 'Actuators fetched', data: { actuators } };
  }

  @Post('devices/:deviceId/actuators')
  @HttpCode(HttpStatus.CREATED)
  async create(
    @Param('deviceId') deviceId: string,
    @Body() dto: CreateActuatorDto,
    @Request() req: Request & { user: JwtPayload },
  ): Promise<ControllerResponse> {
    const actuator = await this.actuatorsService.create(deviceId, req.user.sub, dto);
    return { success: true, message: 'Actuator created', data: { actuator } };
  }

  @Post('actuators/:id/control')
  @HttpCode(HttpStatus.OK)
  async control(
    @Param('id') id: string,
    @Body() dto: ControlActuatorDto,
    @Request() req: Request & { user: JwtPayload },
  ): Promise<ControllerResponse> {
    const actuator = await this.actuatorsService.control(id, req.user.sub, dto);
    return { success: true, message: 'Command sent', data: { actuator } };
  }

  @Delete('actuators/:id')
  @HttpCode(HttpStatus.NO_CONTENT)
  async delete(
    @Param('id') id: string,
    @Request() req: Request & { user: JwtPayload },
  ): Promise<void> {
    await this.actuatorsService.delete(id, req.user.sub);
  }
}
