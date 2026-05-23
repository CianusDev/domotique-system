import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/providers/dio_provider.dart';
import 'sensor_model.dart';
import 'sensor_type_model.dart';

class SensorRepository {
  SensorRepository(this._dio);
  final Dio _dio;

  Future<List<SensorTypeModel>> findAllTypes() async {
    final res = await _dio.get(ApiConstants.sensorTypes);
    final list = res.data['data']['types'] as List<dynamic>;
    return list
        .map((e) => SensorTypeModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<SensorModel>> findAllByDevice(String deviceId) async {
    final res = await _dio.get('${ApiConstants.devices}/$deviceId/sensors');
    final list = res.data['data']['sensors'] as List<dynamic>;
    return list
        .map((e) => SensorModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// POST /devices/:deviceId/sensors
  Future<SensorModel> addSensor({
    required String deviceId,
    required String sensorTypeId,
    required String name,
    required int pin,
    Map<String, dynamic>? config,
  }) async {
    final res = await _dio.post(
      '${ApiConstants.devices}/$deviceId/sensors',
      data: {
        'sensorTypeId': sensorTypeId,
        'name': name,
        'pin': pin,
        'config': config,
      },
    );
    return SensorModel.fromJson(
      res.data['data']['sensor'] as Map<String, dynamic>,
    );
  }

  Future<void> delete(String sensorId) async {
    await _dio.delete('/sensors/$sensorId');
  }
}

final sensorRepositoryProvider = Provider<SensorRepository>(
  (ref) => SensorRepository(ref.watch(dioProvider)),
);

final sensorTypesProvider = FutureProvider<List<SensorTypeModel>>((ref) {
  return ref.watch(sensorRepositoryProvider).findAllTypes();
});
