import {
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { OnEvent } from '@nestjs/event-emitter';
import { DeviceStatus } from 'generated/prisma/client';
import { MQTT_EVENTS } from 'src/mqtt/mqtt.service';
import type { MqttDeviceStatusEvent } from 'src/mqtt/mqtt.service';
import { CreateDeviceDto } from './dto/create-device.dto';
import { UpdateDeviceDto } from './dto/update-device.dto';
import { DevicesRepository } from './devices.repository';

@Injectable()
export class DevicesService {
  constructor(private readonly devicesRepository: DevicesRepository) {}

  findAll(userId: string) {
    return this.devicesRepository.findAll(userId);
  }

  async findOne(id: string, userId: string) {
    const device = await this.devicesRepository.findOne({ id });
    if (!device || device.userId !== userId) {
      throw new NotFoundException('Device not found');
    }
    return device;
  }

  async create(userId: string, dto: CreateDeviceDto) {
    const existing = await this.devicesRepository.findByMac(dto.macAddress);
    if (existing) {
      throw new ConflictException('A device with this MAC address already exists');
    }
    return this.devicesRepository.create({ ...dto, user: { connect: { id: userId } } });
  }

  async update(id: string, userId: string, dto: UpdateDeviceDto) {
    await this.findOne(id, userId);
    return this.devicesRepository.update(id, dto);
  }

  async delete(id: string, userId: string) {
    await this.findOne(id, userId);
    return this.devicesRepository.delete(id);
  }

  // ── MQTT event handler ──────────────────────

  @OnEvent(MQTT_EVENTS.DEVICE_STATUS)
  async handleDeviceStatus(event: MqttDeviceStatusEvent) {
    // event.deviceId = UUID stored in ESP32 NVS during BLE provisioning
    const device = await this.devicesRepository.findOne({ id: event.deviceId });
    if (!device) return;
    const status = event.status === 'online' ? DeviceStatus.ONLINE : DeviceStatus.OFFLINE;
    await this.devicesRepository.updateStatus(device.id, status);

    // On disconnect: reset all actuator states to 'off' so DB matches
    // ESP32 boot state (GPIO starts LOW). Prevents inverted toggle on reconnect.
    if (status === DeviceStatus.OFFLINE) {
      await this.devicesRepository.resetActuatorsState(device.id);
    }
  }
}
