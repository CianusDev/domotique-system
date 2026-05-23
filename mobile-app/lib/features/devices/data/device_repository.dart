import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/providers/dio_provider.dart';
import 'device_model.dart';

class DeviceRepository {
  DeviceRepository(this._dio);
  final Dio _dio;

  Future<List<DeviceModel>> findAll() async {
    final res = await _dio.get(ApiConstants.devices);
    final list = res.data['data']['devices'] as List<dynamic>;
    return list
        .map((e) => DeviceModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<DeviceModel> create({
    required String name,
    required String macAddress,
    String? ipAddress,
    String? firmwareVersion,
  }) async {
    final res = await _dio.post(ApiConstants.devices, data: {
      'name': name,
      'macAddress': macAddress,
      if (ipAddress != null && ipAddress.isNotEmpty) 'ipAddress': ipAddress,
      if (firmwareVersion != null && firmwareVersion.isNotEmpty)
        'firmwareVersion': firmwareVersion,
    });
    return DeviceModel.fromJson(
      res.data['data']['device'] as Map<String, dynamic>,
    );
  }

  Future<void> delete(String id) async {
    await _dio.delete('${ApiConstants.devices}/$id');
  }
}

final deviceRepositoryProvider = Provider<DeviceRepository>(
  (ref) => DeviceRepository(ref.watch(dioProvider)),
);
