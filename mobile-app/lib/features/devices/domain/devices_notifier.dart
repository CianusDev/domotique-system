import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/utils/dio_error_helper.dart';
import '../data/device_model.dart';
import '../data/device_repository.dart';

class DevicesNotifier
    extends StateNotifier<AsyncValue<List<DeviceModel>>> {
  DevicesNotifier(this._repo) : super(const AsyncValue.loading());

  final DeviceRepository _repo;

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final devices = await _repo.findAll();
      state = AsyncValue.data(devices);
    } catch (e, st) {
      state = AsyncValue.error(extractDioError(e), st);
    }
  }

  Future<DeviceModel?> create({
    required String name,
    required String macAddress,
    String? ipAddress,
  }) async {
    try {
      final device = await _repo.create(
        name: name,
        macAddress: macAddress,
        ipAddress: ipAddress,
      );
      state = state.whenData((list) => [...list, device]);
      return device;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    try {
      await _repo.delete(id);
      state = state.whenData(
        (list) => list.where((d) => d.id != id).toList(),
      );
    } catch (e) {
      rethrow;
    }
  }
}

final devicesNotifierProvider =
    StateNotifierProvider<DevicesNotifier, AsyncValue<List<DeviceModel>>>(
  (ref) => DevicesNotifier(ref.read(deviceRepositoryProvider)),
);
