import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/dio_provider.dart';
import '../../../core/constants/api_constants.dart';
import 'actuator_model.dart';

class ActuatorRepository {
  ActuatorRepository(this._dio);
  final Dio _dio;

  Future<List<ActuatorModel>> findAll(String deviceId) async {
    final res = await _dio.get('${ApiConstants.devices}/$deviceId/actuators');
    final list = res.data['data']['actuators'] as List;
    return list
        .map((e) => ActuatorModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ActuatorModel> create(
    String deviceId, {
    required String type,
    required String name,
    required int pin,
  }) async {
    final res = await _dio.post(
      '${ApiConstants.devices}/$deviceId/actuators',
      data: {'type': type, 'name': name, 'pin': pin},
    );
    return ActuatorModel.fromJson(
      res.data['data']['actuator'] as Map<String, dynamic>,
    );
  }

  Future<ActuatorModel> control(String id, {required String command}) async {
    final res = await _dio.post(
      '${ApiConstants.actuators}/$id/control',
      data: {'command': command},
    );
    return ActuatorModel.fromJson(
      res.data['data']['actuator'] as Map<String, dynamic>,
    );
  }

  Future<void> delete(String id) async {
    await _dio.delete('${ApiConstants.actuators}/$id');
  }
}

final actuatorRepositoryProvider = Provider<ActuatorRepository>((ref) {
  return ActuatorRepository(ref.read(dioProvider));
});
