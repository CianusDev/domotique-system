import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/websocket/socket_service.dart';
import '../data/actuator_model.dart';
import '../data/actuator_repository.dart';

class ActuatorsNotifier
    extends StateNotifier<AsyncValue<List<ActuatorModel>>> {
  ActuatorsNotifier(this._repo, this._deviceId)
      : super(const AsyncValue.loading()) {
    _subscribeToSocket();
  }

  final ActuatorRepository _repo;
  final String _deviceId;

  void _subscribeToSocket() {
    SocketService.instance.on('actuator:state', _onActuatorState);
    // When device goes offline backend resets states — re-sync local list
    SocketService.instance.on('device:status', _onDeviceStatus);
  }

  void _onActuatorState(dynamic data) {
    final map = data as Map<String, dynamic>;
    if (map['deviceId'] != _deviceId) return;
    final payload = map['payload'] as Map<String, dynamic>;
    final actuatorId = payload['actuatorId'] as String?;
    final newState = payload['state'] as String?;
    if (actuatorId == null || newState == null) return;

    state = state.whenData(
      (list) => list
          .map((a) => a.id == actuatorId ? a.copyWith(state: newState) : a)
          .toList(),
    );
  }

  void _onDeviceStatus(dynamic data) {
    final map = data as Map<String, dynamic>;
    if (map['deviceId'] != _deviceId) return;
    final status = map['status'] as String;
    // Device went offline → backend reset all actuators to 'off', sync locally
    if (status.toLowerCase() == 'offline') {
      state = state.whenData(
        (list) => list.map((a) => a.copyWith(state: 'off')).toList(),
      );
    }
  }

  @override
  void dispose() {
    SocketService.instance.offAll('actuator:state');
    SocketService.instance.offAll('device:status');
    super.dispose();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final actuators = await _repo.findAll(_deviceId);
      state = AsyncValue.data(actuators);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<ActuatorModel?> create({
    required String type,
    required String name,
    required int pin,
  }) async {
    try {
      final actuator =
          await _repo.create(_deviceId, type: type, name: name, pin: pin);
      state = state.whenData((list) => [...list, actuator]);
      return actuator;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> control(String id, {required String command}) async {
    try {
      final updated = await _repo.control(id, command: command);
      state = state.whenData(
        (list) => list.map((a) => a.id == id ? updated : a).toList(),
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    try {
      await _repo.delete(id);
      state = state.whenData((list) => list.where((a) => a.id != id).toList());
    } catch (e) {
      rethrow;
    }
  }
}

final actuatorsNotifierProvider = StateNotifierProvider.family<
    ActuatorsNotifier, AsyncValue<List<ActuatorModel>>, String>(
  (ref, deviceId) => ActuatorsNotifier(
    ref.read(actuatorRepositoryProvider),
    deviceId,
  ),
);
