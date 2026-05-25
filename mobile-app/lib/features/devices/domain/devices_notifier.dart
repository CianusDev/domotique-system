import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/websocket/socket_service.dart';
import '../../../shared/utils/dio_error_helper.dart';
import '../data/device_model.dart';
import '../data/device_repository.dart';

class DevicesNotifier extends StateNotifier<AsyncValue<List<DeviceModel>>> {
  DevicesNotifier(this._repo) : super(const AsyncValue.loading()) {
    _subscribeToSocket();
  }

  final DeviceRepository _repo;

  // Keep named ref so dispose() removes only THIS notifier's listener
  late final void Function(dynamic) _deviceStatusHandler = _onDeviceStatus;

  void _subscribeToSocket() {
    SocketService.instance.on('device:status', _deviceStatusHandler);
  }

  void _onDeviceStatus(dynamic data) {
    final map = data as Map<String, dynamic>;
    final deviceId = map['deviceId'] as String;
    final rawStatus = map['status'] as String;
    final status = rawStatus.toLowerCase() == 'online'
        ? DeviceStatus.online
        : DeviceStatus.offline;

    state = state.whenData(
      (list) => list
          .map((d) => d.id == deviceId ? _DeviceModelExt.withStatus(d, status) : d)
          .toList(),
    );
  }

  @override
  void dispose() {
    SocketService.instance.off('device:status', _deviceStatusHandler);
    super.dispose();
  }

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

/// Helper to clone a DeviceModel with a new status (no Freezed needed).
class _DeviceModelExt {
  static DeviceModel withStatus(DeviceModel d, DeviceStatus status) {
    return DeviceModel(
      id: d.id,
      userId: d.userId,
      name: d.name,
      macAddress: d.macAddress,
      ipAddress: d.ipAddress,
      status: status,
      firmwareVersion: d.firmwareVersion,
      lastSeenAt: d.lastSeenAt,
      createdAt: d.createdAt,
    );
  }
}

final devicesNotifierProvider =
    StateNotifierProvider<DevicesNotifier, AsyncValue<List<DeviceModel>>>(
  (ref) => DevicesNotifier(ref.read(deviceRepositoryProvider)),
);
