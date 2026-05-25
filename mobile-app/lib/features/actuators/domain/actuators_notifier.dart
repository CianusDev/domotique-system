import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/actuator_model.dart';
import '../data/actuator_repository.dart';

class ActuatorsNotifier
    extends StateNotifier<AsyncValue<List<ActuatorModel>>> {
  ActuatorsNotifier(this._repo, this._deviceId)
      : super(const AsyncValue.loading());

  final ActuatorRepository _repo;
  final String _deviceId;

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
