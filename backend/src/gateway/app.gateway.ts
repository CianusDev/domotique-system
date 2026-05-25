import {
  OnGatewayConnection,
  OnGatewayDisconnect,
  WebSocketGateway,
  WebSocketServer,
} from '@nestjs/websockets';
import { OnEvent } from '@nestjs/event-emitter';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { Server, Socket } from 'socket.io';
import { parse } from 'cookie';
import { DevicesRepository } from 'src/devices/devices.repository';
import type {
  MqttDeviceStatusEvent,
  MqttSensorDataEvent,
  MqttActuatorStateEvent,
} from 'src/mqtt/mqtt.service';
import { MQTT_EVENTS } from 'src/mqtt/mqtt.service';

@WebSocketGateway({
  cors: {
    origin: (
      _origin: string,
      cb: (err: Error | null, allow?: boolean) => void,
    ) => {
      cb(null, true); // mobile app — allow all origins, JWT still gates access
    },
    credentials: true,
  },
})
export class AppGateway implements OnGatewayConnection, OnGatewayDisconnect {
  @WebSocketServer()
  server!: Server;

  constructor(
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
    private readonly devicesRepository: DevicesRepository,
  ) {}

  // ── Connection lifecycle ───────────────────────────────────────────────────

  async handleConnection(client: Socket) {
    try {
      const userId = this.extractUserId(client);
      client.data.userId = userId;

      // Join personal room (broadcast to all user sessions)
      await client.join(`user:${userId}`);

      // Join a room per device so MQTT events can target device:{id}
      const devices = await this.devicesRepository.findAll(userId);
      for (const device of devices) {
        await client.join(`device:${device.id}`);
      }
    } catch {
      client.disconnect();
    }
  }

  handleDisconnect(_client: Socket) {
    // Socket.IO cleans up rooms automatically on disconnect
  }

  // ── MQTT events → WebSocket ────────────────────────────────────────────────

  @OnEvent(MQTT_EVENTS.DEVICE_STATUS)
  onDeviceStatus(event: MqttDeviceStatusEvent) {
    this.server.to(`device:${event.deviceId}`).emit('device:status', {
      deviceId: event.deviceId,
      status: event.status,
    });
  }

  @OnEvent(MQTT_EVENTS.SENSOR_DATA)
  onSensorData(event: MqttSensorDataEvent) {
    this.server.to(`device:${event.deviceId}`).emit('sensor:data', {
      deviceId: event.deviceId,
      sensorId: event.sensorId,
      payload: event.payload,
    });
  }

  @OnEvent(MQTT_EVENTS.ACTUATOR_STATE)
  onActuatorState(event: MqttActuatorStateEvent) {
    this.server.to(`device:${event.deviceId}`).emit('actuator:state', {
      deviceId: event.deviceId,
      type: event.type,
      payload: event.payload,
    });
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  private extractUserId(client: Socket): string {
    const cookieHeader = client.handshake.headers.cookie ?? '';
    const cookies = parse(cookieHeader);
    const token = cookies['authentication'];
    if (!token) throw new Error('No auth cookie');

    const payload = this.jwtService.verify<{ sub: string }>(token, {
      secret: this.configService.getOrThrow<string>('JWT_SECRET'),
    });
    return payload.sub;
  }
}
