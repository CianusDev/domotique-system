import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/websocket/socket_service.dart';

/// Holds the latest sensor reading payload (raw MQTT fields) per sensorId.
/// One instance per deviceId — subscribes to a single WebSocket listener and
/// routes incoming events by sensorId.
///
/// State: Map of sensorId → latest reading payload
class SensorReadingsNotifier
    extends StateNotifier<Map<String, Map<String, dynamic>>> {
  SensorReadingsNotifier(this._deviceId) : super(const {}) {
    _subscribe();
  }

  final String _deviceId;
  late final void Function(dynamic) _handler = _onSensorData;

  void _subscribe() {
    SocketService.instance.on('sensor:data', _handler);
  }

  void _onSensorData(dynamic data) {
    final map = data as Map<String, dynamic>;
    if (map['deviceId'] != _deviceId) return;

    final sensorId = map['sensorId'] as String?;
    final payload  = map['payload']  as Map<String, dynamic>?;
    if (sensorId == null || payload == null) return;

    // Immutable update
    state = {...state, sensorId: payload};
  }

  @override
  void dispose() {
    SocketService.instance.off('sensor:data', _handler);
    super.dispose();
  }
}

final sensorReadingsProvider = StateNotifierProvider.family<
    SensorReadingsNotifier,
    Map<String, Map<String, dynamic>>,
    String>(
  (ref, deviceId) => SensorReadingsNotifier(deviceId),
);
