import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { OnEvent } from '@nestjs/event-emitter';
import { DevicesRepository } from 'src/devices/devices.repository';
import { MQTT_EVENTS, MqttService } from 'src/mqtt/mqtt.service';
import type { MqttActuatorStateEvent } from 'src/mqtt/mqtt.service';
import { ActuatorsRepository } from './actuators.repository';
import { ControlActuatorDto, CreateActuatorDto } from './dto/create-actuator.dto';

@Injectable()
export class ActuatorsService {
  constructor(
    private readonly actuatorsRepository: ActuatorsRepository,
    private readonly devicesRepository: DevicesRepository,
    private readonly mqttService: MqttService,
  ) {}

  findAllByDevice(deviceId: string) {
    return this.actuatorsRepository.findAllByDevice(deviceId);
  }

  async create(deviceId: string, userId: string, dto: CreateActuatorDto) {
    const device = await this.devicesRepository.findOne({ id: deviceId });
    if (!device || device.userId !== userId) throw new NotFoundException('Device not found');

    const pinConflict = await this.actuatorsRepository.findByDeviceAndPin(deviceId, dto.pin);
    if (pinConflict) throw new ConflictException(`GPIO pin ${dto.pin} already in use`);

    return this.actuatorsRepository.create({
      ...dto,
      device: { connect: { id: deviceId } },
    });
  }

  async control(id: string, userId: string, dto: ControlActuatorDto) {
    const actuator = await this.actuatorsRepository.findOne(id);
    if (!actuator || actuator.device.userId !== userId) throw new NotFoundException('Actuator not found');

    this.mqttService.publishActuatorCommand(actuator.device.id, actuator.type, {
      actuatorId: id,
      command: dto.command,
      ...(dto.params && { params: dto.params }),
    });

    // Optimistically update state
    const newState = dto.command === 'toggle'
      ? (actuator.state === 'on' ? 'off' : 'on')
      : dto.command;
    return this.actuatorsRepository.updateState(id, newState);
  }

  async delete(id: string, userId: string) {
    const actuator = await this.actuatorsRepository.findOne(id);
    if (!actuator || actuator.device.userId !== userId) throw new NotFoundException('Actuator not found');
    return this.actuatorsRepository.delete(id);
  }

  @OnEvent(MQTT_EVENTS.ACTUATOR_STATE)
  async handleActuatorState(event: MqttActuatorStateEvent) {
    const { actuatorId, state } = event.payload as { actuatorId?: string; state?: string };
    if (!actuatorId || !state) return;
    await this.actuatorsRepository.updateState(actuatorId, state).catch(() => {});
  }
}
