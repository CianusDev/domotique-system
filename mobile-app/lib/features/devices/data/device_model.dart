enum DeviceStatus { online, offline, unknown }

class DeviceModel {
  final String id;
  final String userId;
  final String name;
  final String macAddress;
  final String? ipAddress;
  final DeviceStatus status;
  final String? firmwareVersion;
  final DateTime? lastSeenAt;
  final DateTime createdAt;

  const DeviceModel({
    required this.id,
    required this.userId,
    required this.name,
    required this.macAddress,
    this.ipAddress,
    required this.status,
    this.firmwareVersion,
    this.lastSeenAt,
    required this.createdAt,
  });

  factory DeviceModel.fromJson(Map<String, dynamic> json) {
    return DeviceModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      name: json['name'] as String,
      macAddress: json['macAddress'] as String,
      ipAddress: json['ipAddress'] as String?,
      status: _parseStatus(json['status'] as String?),
      firmwareVersion: json['firmwareVersion'] as String?,
      lastSeenAt: json['lastSeenAt'] != null
          ? DateTime.tryParse(json['lastSeenAt'] as String)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  static DeviceStatus _parseStatus(String? s) {
    return switch (s?.toLowerCase()) {
      'online' => DeviceStatus.online,
      'offline' => DeviceStatus.offline,
      _ => DeviceStatus.unknown,
    };
  }

  bool get isOnline => status == DeviceStatus.online;
}
