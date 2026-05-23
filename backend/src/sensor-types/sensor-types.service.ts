import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { CreateSensorTypeDto } from './dto/create-sensor-type.dto';
import { SensorTypesRepository } from './sensor-types.repository';

@Injectable()
export class SensorTypesService {
  constructor(private readonly repo: SensorTypesRepository) {}

  findAll() {
    return this.repo.findAll();
  }

  async findOne(id: string) {
    const st = await this.repo.findOne(id);
    if (!st) throw new NotFoundException('Sensor type not found');
    return st;
  }

  async findByType(type: string) {
    const st = await this.repo.findByType(type);
    if (!st) throw new NotFoundException(`Sensor type "${type}" not found`);
    return st;
  }

  async create(dto: CreateSensorTypeDto) {
    const existing = await this.repo.findByType(dto.type);
    if (existing) throw new ConflictException(`Sensor type "${dto.type}" already exists`);
    return this.repo.create(dto as any);
  }
}
