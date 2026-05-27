import {
  Injectable,
  Logger,
  OnModuleDestroy,
  OnModuleInit,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { EventEmitter2 } from '@nestjs/event-emitter';
import * as mqtt from 'mqtt';

export const MQTT_EVENTS = {
  DEVICE_STATUS: 'mqtt.device.status', // home/+/status
  SENSOR_DISCOVERY: 'mqtt.sensor.discovery', // home/+/sensors/discovery
  SENSOR_DATA: 'mqtt.sensor.data', // home/+/sensors/+/data
  ACTUATOR_STATE: 'mqtt.actuator.state', // home/+/actuators/+/cmd/state
};

export interface MqttDeviceStatusEvent {
  deviceId: string;
  status: 'online' | 'offline';
}
export interface MqttSensorDiscoveryEvent {
  deviceId: string;
  payload: Record<string, any>;
}
export interface MqttSensorDataEvent {
  deviceId: string;
  sensorId: string;
  payload: Record<string, any>;
}
export interface MqttActuatorStateEvent {
  deviceId: string;
  type: string;
  payload: Record<string, any>;
}

@Injectable()
export class MqttService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(MqttService.name);
  private client!: mqtt.MqttClient;

  constructor(
    private readonly configService: ConfigService,
    private readonly eventEmitter: EventEmitter2,
  ) {}

  onModuleInit() {
    const broker = this.configService.getOrThrow<string>('MQTT_BROKER_URL');

    this.client = mqtt.connect(broker, {
      clientId: `nestjs-backend-${Date.now()}`,
      clean: true,
      reconnectPeriod: 5000,
    });

    this.client.on('connect', () => {
      this.logger.log(`Connected to MQTT broker: ${broker}`);
      this.subscribe();
    });

    this.client.on('error', (err) => {
      this.logger.error(`MQTT error: ${err.message}`);
    });

    this.client.on('message', (topic, payload) => {
      this.handleMessage(topic, payload.toString());
    });
  }

  onModuleDestroy() {
    this.client?.end();
  }

  // ── Publish ────────────────────────────────

  publish(topic: string, payload: object | string): void {
    const message =
      typeof payload === 'string' ? payload : JSON.stringify(payload);
    this.client.publish(topic, message, { qos: 1 });
  }

  /** home/{deviceId}/sensors/control/add */
  publishAddSensor(deviceId: string, payload: object): void {
    this.publish(`home/${deviceId}/sensors/control/add`, payload);
  }

  /** home/{deviceId}/actuators/{type}/cmd/state */
  publishActuatorCommand(
    deviceId: string,
    type: string,
    payload: object,
  ): void {
    this.publish(`home/${deviceId}/actuators/${type}/cmd/state`, payload);
  }

  /**
   * home/{deviceId}/cmd/factory-reset
   * Published retained so the ESP32 receives it even if currently offline.
   * On receipt the ESP32 clears NVS and reboots into BLE provisioning.
   */
  publishFactoryReset(deviceId: string): void {
    this.client.publish(
      `home/${deviceId}/cmd/factory-reset`,
      'factory-reset',
      { qos: 1, retain: true },
    );
  }

  // ── Subscribe & route ───────────────────────

  private subscribe() {
    const topics = [
      'home/+/status',
      'home/+/sensors/discovery',
      'home/+/sensors/+/data',
      'home/+/actuators/+/cmd/state',
    ];
    this.client.subscribe(topics, { qos: 1 }, (err) => {
      if (err) this.logger.error(`Subscribe error: ${err.message}`);
      else this.logger.log(`Subscribed to ${topics.length} topic patterns`);
    });
  }

  private handleMessage(topic: string, raw: string) {
    let payload: Record<string, any>;
    try {
      payload = JSON.parse(raw);
    } catch {
      payload = { raw };
    }

    const parts = topic.split('/'); // home / deviceId / ...

    if (parts.length < 3) return;
    const deviceId = parts[1];

    // home/{deviceId}/status
    if (parts.length === 3 && parts[2] === 'status') {
      this.eventEmitter.emit(MQTT_EVENTS.DEVICE_STATUS, {
        deviceId,
        status:
          typeof payload === 'string' ? payload : (payload.raw ?? 'offline'),
      } satisfies MqttDeviceStatusEvent);
      return;
    }

    // home/{deviceId}/sensors/discovery
    if (
      parts.length === 4 &&
      parts[2] === 'sensors' &&
      parts[3] === 'discovery'
    ) {
      this.eventEmitter.emit(MQTT_EVENTS.SENSOR_DISCOVERY, {
        deviceId,
        payload,
      } satisfies MqttSensorDiscoveryEvent);
      return;
    }

    // home/{deviceId}/sensors/{sensorId}/data
    if (parts.length === 5 && parts[2] === 'sensors' && parts[4] === 'data') {
      this.eventEmitter.emit(MQTT_EVENTS.SENSOR_DATA, {
        deviceId,
        sensorId: parts[3],
        payload,
      } satisfies MqttSensorDataEvent);
      return;
    }

    // home/{deviceId}/actuators/{type}/cmd/state
    if (
      parts.length === 6 &&
      parts[2] === 'actuators' &&
      parts[4] === 'cmd' &&
      parts[5] === 'state'
    ) {
      this.eventEmitter.emit(MQTT_EVENTS.ACTUATOR_STATE, {
        deviceId,
        type: parts[3],
        payload,
      } satisfies MqttActuatorStateEvent);
    }
  }
}
