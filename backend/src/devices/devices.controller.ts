import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Patch,
  Post,
  Request,
} from '@nestjs/common';
import type { ControllerResponse } from 'src/config/config.interface';
import { JwtPayload } from 'src/auth/strategies/jwt.strategy';
import { DevicesService } from './devices.service';
import { CreateDeviceDto } from './dto/create-device.dto';
import { UpdateDeviceDto } from './dto/update-device.dto';

@Controller('devices')
export class DevicesController {
  constructor(private readonly devicesService: DevicesService) {}

  @Get()
  async findAll(
    @Request() req: Request & { user: JwtPayload },
  ): Promise<ControllerResponse> {
    const devices = await this.devicesService.findAll(req.user.sub);
    return { success: true, message: 'Devices fetched', data: { devices } };
  }

  @Get(':id')
  async findOne(
    @Param('id') id: string,
    @Request() req: Request & { user: JwtPayload },
  ): Promise<ControllerResponse> {
    const device = await this.devicesService.findOne(id, req.user.sub);
    return { success: true, message: 'Device fetched', data: { device } };
  }

  @Post()
  @HttpCode(HttpStatus.CREATED)
  async create(
    @Body() dto: CreateDeviceDto,
    @Request() req: Request & { user: JwtPayload },
  ): Promise<ControllerResponse> {
    const device = await this.devicesService.create(req.user.sub, dto);
    return { success: true, message: 'Device created', data: { device } };
  }

  @Patch(':id')
  async update(
    @Param('id') id: string,
    @Body() dto: UpdateDeviceDto,
    @Request() req: Request & { user: JwtPayload },
  ): Promise<ControllerResponse> {
    const device = await this.devicesService.update(id, req.user.sub, dto);
    return { success: true, message: 'Device updated', data: { device } };
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  async delete(
    @Param('id') id: string,
    @Request() req: Request & { user: JwtPayload },
  ): Promise<void> {
    await this.devicesService.delete(id, req.user.sub);
  }
}
