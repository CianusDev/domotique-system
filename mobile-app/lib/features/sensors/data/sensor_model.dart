enum SensorStatus { active, inactive, error }

class SensorModel {
  final String id;
  final String deviceId;
  final String sensorTypeId;
  final String name;
  final int pin;
  final SensorStatus status;
  final Map<String, dynamic>? config;
  final DateTime? lastReadAt;
  final DateTime createdAt;

  const SensorModel({
    required this.id,
    required this.deviceId,
    required this.sensorTypeId,
    required this.name,
    required this.pin,
    required this.status,
    this.config,
    this.lastReadAt,
    required this.createdAt,
  });

  factory SensorModel.fromJson(Map<String, dynamic> json) {
    return SensorModel(
      id: json['id'] as String,
      deviceId: json['deviceId'] as String,
      sensorTypeId: json['sensorTypeId'] as String,
      name: json['name'] as String,
      pin: json['pin'] as int,
      status: _parseStatus(json['status'] as String?),
      config: json['config'] != null
          ? Map<String, dynamic>.from(json['config'] as Map)
          : null,
      lastReadAt: json['lastReadAt'] != null
          ? DateTime.tryParse(json['lastReadAt'] as String)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  static SensorStatus _parseStatus(String? s) {
    return switch (s) {
      'ACTIVE' => SensorStatus.active,
      'ERROR' => SensorStatus.error,
      _ => SensorStatus.inactive,
    };
  }

  bool get isActive => status == SensorStatus.active;
}
