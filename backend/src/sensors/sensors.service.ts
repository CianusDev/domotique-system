import {
  ConflictException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { OnEvent } from '@nestjs/event-emitter';
import { Prisma, SensorStatus } from 'generated/prisma/client';
import { DevicesRepository } from 'src/devices/devices.repository';
import { MQTT_EVENTS, MqttService } from 'src/mqtt/mqtt.service';
import type { MqttSensorDataEvent, MqttSensorDiscoveryEvent } from 'src/mqtt/mqtt.service';
import { SensorTypesService } from 'src/sensor-types/sensor-types.service';
import { CreateSensorDto } from './dto/create-sensor.dto';
import { QuerySensorDataDto } from './dto/query-sensor-data.dto';
import { SensorsRepository } from './sensors.repository';

@Injectable()
export class SensorsService {
  private readonly logger = new Logger(SensorsService.name);

  constructor(
    private readonly sensorsRepository: SensorsRepository,
    private readonly devicesRepository: DevicesRepository,
    private readonly sensorTypesService: SensorTypesService,
    private readonly mqttService: MqttService,
  ) {}

  findAllByDevice(deviceId: string) {
    return this.sensorsRepository.findAllByDevice(deviceId);
  }

  async findOne(id: string) {
    const sensor = await this.sensorsRepository.findOne(id);
    if (!sensor) throw new NotFoundException('Sensor not found');
    return sensor;
  }

  async addSensor(deviceId: string, userId: string, dto: CreateSensorDto) {
    // Verify device belongs to user
    const device = await this.devicesRepository.findOne({ id: deviceId });
    if (!device || device.userId !== userId) {
      throw new NotFoundException('Device not found');
    }

    // Verify sensor type exists
    const sensorType = await this.sensorTypesService.findOne(dto.sensorTypeId);

    // Check pin not already in use
    const pinConflict = await this.sensorsRepository.findByDeviceAndPin(deviceId, dto.pin);
    if (pinConflict) {
      throw new ConflictException(`GPIO pin ${dto.pin} already in use on this device`);
    }

    // Create sensor record (status INACTIVE until ESP32 confirms)
    const sensor = await this.sensorsRepository.create({
      name: dto.name,
      pin: dto.pin,
      config: (dto.config ?? undefined) as Prisma.InputJsonValue | undefined,
      status: SensorStatus.INACTIVE,
      device: { connect: { id: deviceId } },
      sensorType: { connect: { id: sensorType.id } },
    });

    // Send MQTT command to ESP32 — topic uses device UUID (set in NVS during BLE provisioning)
    this.mqttService.publishAddSensor(device.id, {
      sensorId: sensor.id,
      type: sensorType.type,
      pin: dto.pin,
      ...(dto.config && { params: dto.config }),
    });

    return sensor;
  }

  async delete(id: string, userId: string) {
    const sensor = await this.findOne(id);
    if (sensor.device.userId !== userId) throw new NotFoundException('Sensor not found');
    return this.sensorsRepository.delete(id);
  }

  async getHistory(id: string, userId: string, query: QuerySensorDataDto) {
    const sensor = await this.findOne(id);
    if (sensor.device.userId !== userId) throw new NotFoundException('Sensor not found');

    return this.sensorsRepository.findData(
      id,
      query.from ? new Date(query.from) : undefined,
      query.to ? new Date(query.to) : undefined,
      query.limit,
    );
  }

  // ── MQTT event handlers ─────────────────────

  @OnEvent(MQTT_EVENTS.SENSOR_DISCOVERY)
  async handleDiscovery(event: MqttSensorDiscoveryEvent) {
    const { sensorId, status } = event.payload as { sensorId?: string; status?: string };
    if (!sensorId) return;

    const newStatus = status === 'added' ? SensorStatus.ACTIVE : SensorStatus.ERROR;
    await this.sensorsRepository.updateStatus(sensorId, newStatus).catch(() => {
      this.logger.warn(`Discovery for unknown sensor ${sensorId}`);
    });
  }

  @OnEvent(MQTT_EVENTS.SENSOR_DATA)
  async handleSensorData(event: MqttSensorDataEvent) {
    const sensor = await this.sensorsRepository.findOne(event.sensorId);
    if (!sensor) return;

    await Promise.all([
      this.sensorsRepository.recordData(event.sensorId, event.payload),
      this.sensorsRepository.updateLastRead(event.sensorId),
    ]);
  }
}
