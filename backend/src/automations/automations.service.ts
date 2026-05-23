import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { OnEvent } from '@nestjs/event-emitter';
import { ActuatorsRepository } from 'src/actuators/actuators.repository';
import { MQTT_EVENTS, MqttService } from 'src/mqtt/mqtt.service';
import type { MqttSensorDataEvent } from 'src/mqtt/mqtt.service';
import { AutomationsRepository } from './automations.repository';
import { CreateAutomationDto } from './dto/create-automation.dto';

type TriggerDef = {
  sensorId: string;
  field: string;
  operator: string;
  value: number | string | boolean;
};
type ActionDef = {
  actuatorId?: string;
  command?: string;
  type?: string;
  message?: string;
};

@Injectable()
export class AutomationsService {
  private readonly logger = new Logger(AutomationsService.name);

  constructor(
    private readonly repo: AutomationsRepository,
    private readonly mqttService: MqttService,
    private readonly actuatorsRepository: ActuatorsRepository,
  ) {}

  findAll(userId: string) {
    return this.repo.findAll(userId);
  }

  async findOne(id: string, userId: string) {
    const a = await this.repo.findOne(id);
    if (!a || a.userId !== userId)
      throw new NotFoundException('Automation not found');
    return a;
  }

  async create(userId: string, dto: CreateAutomationDto) {
    const trigger = dto.trigger as TriggerDef;
    return this.repo.create({
      name: dto.name,
      description: dto.description,
      trigger: dto.trigger as any,
      action: dto.action as any,
      isActive: dto.isActive ?? true,
      user: { connect: { id: userId } },
      ...(trigger.sensorId && {
        sensor: { connect: { id: trigger.sensorId } },
      }),
      ...((dto.action as ActionDef).actuatorId && {
        actuator: { connect: { id: (dto.action as ActionDef).actuatorId } },
      }),
    });
  }

  async toggleActive(id: string, userId: string, isActive: boolean) {
    await this.findOne(id, userId);
    return this.repo.update(id, { isActive });
  }

  async delete(id: string, userId: string) {
    await this.findOne(id, userId);
    return this.repo.delete(id);
  }

  // ── Automation engine ───────────────────────

  @OnEvent(MQTT_EVENTS.SENSOR_DATA)
  async evaluate(event: MqttSensorDataEvent) {
    const automations = await this.repo.findActiveBySensor(event.sensorId);
    for (const automation of automations) {
      const trigger = automation.trigger as unknown as TriggerDef;
      const action = automation.action as unknown as ActionDef;

      const sensorValue = (event.payload as Record<string, unknown>)[
        trigger.field
      ];
      if (sensorValue === undefined) continue;

      if (!this.evaluateCondition(sensorValue, trigger.operator, trigger.value))
        continue;

      this.logger.log(`Automation "${automation.name}" triggered`);
      await this.repo.update(automation.id, { lastTriggeredAt: new Date() });
      await this.executeAction(action);
    }
  }

  private evaluateCondition(
    actual: unknown,
    operator: string,
    expected: number | string | boolean,
  ): boolean {
    switch (operator) {
      case '>':  return Number(actual) >  Number(expected);
      case '<':  return Number(actual) <  Number(expected);
      case '>=': return Number(actual) >= Number(expected);
      case '<=': return Number(actual) <= Number(expected);
      case '==': return actual == expected;
      case '!=': return actual != expected;
      default:   return false;
    }
  }

  private async executeAction(action: ActionDef): Promise<void> {
    if (!action.actuatorId || !action.command) return;

    // Look up actuator to get its real type and device UUID
    const actuator = await this.actuatorsRepository.findOne(action.actuatorId);
    if (!actuator) {
      this.logger.warn(`Automation action: actuator ${action.actuatorId} not found`);
      return;
    }

    this.mqttService.publishActuatorCommand(
      actuator.device.id,
      actuator.type,
      { actuatorId: action.actuatorId, command: action.command },
    );
  }
}
