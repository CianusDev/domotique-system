import { Body, Controller, Delete, Get, HttpCode, HttpStatus, Param, Patch, Post, Request } from '@nestjs/common';
import { JwtPayload } from 'src/auth/strategies/jwt.strategy';
import type { ControllerResponse } from 'src/config/config.interface';
import { AlertsService } from './alerts.service';
import { CreateAlertDto } from './dto/create-alert.dto';

@Controller('alerts')
export class AlertsController {
  constructor(private readonly alertsService: AlertsService) {}

  @Get()
  async findAll(@Request() req: Request & { user: JwtPayload }): Promise<ControllerResponse> {
    const alerts = await this.alertsService.findAll(req.user.sub);
    return { success: true, message: 'Alerts fetched', data: { alerts } };
  }

  @Post()
  @HttpCode(HttpStatus.CREATED)
  async create(
    @Body() dto: CreateAlertDto,
    @Request() req: Request & { user: JwtPayload },
  ): Promise<ControllerResponse> {
    const alert = await this.alertsService.create(req.user.sub, dto);
    return { success: true, message: 'Alert created', data: { alert } };
  }

  @Patch(':id/toggle')
  async toggle(
    @Param('id') id: string,
    @Body('isActive') isActive: boolean,
    @Request() req: Request & { user: JwtPayload },
  ): Promise<ControllerResponse> {
    const alert = await this.alertsService.toggleActive(id, req.user.sub, isActive);
    return { success: true, message: 'Alert updated', data: { alert } };
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  async delete(
    @Param('id') id: string,
    @Request() req: Request & { user: JwtPayload },
  ): Promise<void> {
    await this.alertsService.delete(id, req.user.sub);
  }
}
