import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { OnEvent } from '@nestjs/event-emitter';
import { MQTT_EVENTS } from 'src/mqtt/mqtt.service';
import type { MqttSensorDataEvent } from 'src/mqtt/mqtt.service';
import { AlertsRepository } from './alerts.repository';
import { CreateAlertDto } from './dto/create-alert.dto';

type ConditionDef = { field: string; operator: string; value: number | string | boolean };

@Injectable()
export class AlertsService {
  private readonly logger = new Logger(AlertsService.name);

  constructor(private readonly repo: AlertsRepository) {}

  findAll(userId: string) { return this.repo.findAll(userId); }

  async findOne(id: string, userId: string) {
    const alert = await this.repo.findOne(id);
    if (!alert || alert.userId !== userId) throw new NotFoundException('Alert not found');
    return alert;
  }

  async create(userId: string, dto: CreateAlertDto) {
    return this.repo.create({
      name: dto.name,
      condition: dto.condition as any,
      message: dto.message,
      isActive: dto.isActive ?? true,
      user: { connect: { id: userId } },
      sensor: { connect: { id: dto.sensorId } },
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

  // ── Alert evaluation on sensor data ─────────

  @OnEvent(MQTT_EVENTS.SENSOR_DATA)
  async evaluate(event: MqttSensorDataEvent) {
    const alerts = await this.repo.findActiveBySensor(event.sensorId);
    for (const alert of alerts) {
      const cond = alert.condition as unknown as ConditionDef;
      const actual = (event.payload as Record<string, unknown>)[cond.field];
      if (actual === undefined) continue;
      if (!this.check(actual, cond.operator, cond.value)) continue;

      this.logger.warn(`Alert "${alert.name}" triggered — ${cond.field} ${cond.operator} ${cond.value}`);
      await this.repo.update(alert.id, { lastTriggeredAt: new Date() });
      // TODO: integrate push notification service
    }
  }

  private check(actual: unknown, op: string, expected: number | string | boolean): boolean {
    switch (op) {
      case '>':  return Number(actual) >  Number(expected);
      case '<':  return Number(actual) <  Number(expected);
      case '>=': return Number(actual) >= Number(expected);
      case '<=': return Number(actual) <= Number(expected);
      case '==': return actual == expected;
      case '!=': return actual != expected;
      default:   return false;
    }
  }
}
