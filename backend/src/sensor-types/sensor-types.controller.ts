import { Body, Controller, Get, HttpCode, HttpStatus, Param, Post } from '@nestjs/common';
import type { ControllerResponse } from 'src/config/config.interface';
import { SensorTypesService } from './sensor-types.service';
import { CreateSensorTypeDto } from './dto/create-sensor-type.dto';

@Controller('sensor-types')
export class SensorTypesController {
  constructor(private readonly sensorTypesService: SensorTypesService) {}

  @Get()
  async findAll(): Promise<ControllerResponse> {
    const types = await this.sensorTypesService.findAll();
    return { success: true, message: 'Sensor types fetched', data: { types } };
  }

  @Get(':id')
  async findOne(@Param('id') id: string): Promise<ControllerResponse> {
    const type = await this.sensorTypesService.findOne(id);
    return { success: true, message: 'Sensor type fetched', data: { type } };
  }

  @Post()
  @HttpCode(HttpStatus.CREATED)
  async create(@Body() dto: CreateSensorTypeDto): Promise<ControllerResponse> {
    const type = await this.sensorTypesService.create(dto);
    return { success: true, message: 'Sensor type created', data: { type } };
  }
}
