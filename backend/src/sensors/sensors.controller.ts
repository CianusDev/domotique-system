import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  Post,
  Query,
  Request,
} from '@nestjs/common';
import { JwtPayload } from 'src/auth/strategies/jwt.strategy';
import type { ControllerResponse } from 'src/config/config.interface';
import { CreateSensorDto } from './dto/create-sensor.dto';
import { QuerySensorDataDto } from './dto/query-sensor-data.dto';
import { SensorsService } from './sensors.service';

@Controller()
export class SensorsController {
  constructor(private readonly sensorsService: SensorsService) {}

  /** GET /devices/:deviceId/sensors */
  @Get('devices/:deviceId/sensors')
  async findAll(
    @Param('deviceId') deviceId: string,
  ): Promise<ControllerResponse> {
    const sensors = await this.sensorsService.findAllByDevice(deviceId);
    return { success: true, message: 'Sensors fetched', data: { sensors } };
  }

  /** POST /devices/:deviceId/sensors */
  @Post('devices/:deviceId/sensors')
  @HttpCode(HttpStatus.CREATED)
  async addSensor(
    @Param('deviceId') deviceId: string,
    @Body() dto: CreateSensorDto,
    @Request() req: Request & { user: JwtPayload },
  ): Promise<ControllerResponse> {
    const sensor = await this.sensorsService.addSensor(
      deviceId,
      req.user.sub,
      dto,
    );
    return {
      success: true,
      message: 'Sensor add command sent — awaiting ESP32 confirmation',
      data: { sensor },
    };
  }

  /** DELETE /sensors/:id */
  @Delete('sensors/:id')
  @HttpCode(HttpStatus.NO_CONTENT)
  async delete(
    @Param('id') id: string,
    @Request() req: Request & { user: JwtPayload },
  ): Promise<void> {
    await this.sensorsService.delete(id, req.user.sub);
  }

  /** GET /sensors/:id/history */
  @Get('sensors/:id/history')
  async getHistory(
    @Param('id') id: string,
    @Query() query: QuerySensorDataDto,
    @Request() req: Request & { user: JwtPayload },
  ): Promise<ControllerResponse> {
    const data = await this.sensorsService.getHistory(id, req.user.sub, query);
    return {
      success: true,
      message: 'Sensor history fetched',
      data: { history: data },
    };
  }
}
