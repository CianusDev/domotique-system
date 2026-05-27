import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/utils/dio_error_helper.dart';
import '../data/sensor_model.dart';
import '../data/sensor_repository.dart';

class SensorsNotifier
    extends StateNotifier<AsyncValue<List<SensorModel>>> {
  SensorsNotifier(this._repo, this.deviceId)
      : super(const AsyncValue.loading());

  final SensorRepository _repo;
  final String deviceId;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final sensors = await _repo.findAllByDevice(deviceId);
      state = AsyncValue.data(sensors);
    } catch (e, st) {
      state = AsyncValue.error(extractDioError(e), st);
    }
  }

  Future<SensorModel?> addSensor({
    required String sensorTypeId,
    required String name,
    required int pin,
    Map<String, dynamic>? config,
  }) async {
    try {
      final sensor = await _repo.addSensor(
        deviceId: deviceId,
        sensorTypeId: sensorTypeId,
        name: name,
        pin: pin,
        config: config,
      );
      state = state.whenData((list) => [...list, sensor]);
      return sensor;
    } catch (_) {
      rethrow;
    }
  }

  Future<void> delete(String sensorId) async {
    try {
      await _repo.delete(sensorId);
      state = state.whenData(
        (list) => list.where((s) => s.id != sensorId).toList(),
      );
    } catch (_) {
      rethrow;
    }
  }
}

/// Per-device family of providers
final sensorsNotifierProvider = StateNotifierProviderFamily<
    SensorsNotifier, AsyncValue<List<SensorModel>>, String>(
  (ref, deviceId) =>
      SensorsNotifier(ref.read(sensorRepositoryProvider), deviceId),
);
