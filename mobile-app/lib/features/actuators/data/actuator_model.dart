class ActuatorModel {
  final String id;
  final String deviceId;
  final String type;
  final String name;
  final int pin;
  final String state; // "on" | "off" | "unknown"
  final DateTime createdAt;

  const ActuatorModel({
    required this.id,
    required this.deviceId,
    required this.type,
    required this.name,
    required this.pin,
    required this.state,
    required this.createdAt,
  });

  factory ActuatorModel.fromJson(Map<String, dynamic> json) {
    return ActuatorModel(
      id:        json['id'] as String,
      deviceId:  json['deviceId'] as String,
      type:      json['type'] as String,
      name:      json['name'] as String,
      pin:       json['pin'] as int,
      state:     (json['state'] as String?) ?? 'unknown',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  ActuatorModel copyWith({String? state}) => ActuatorModel(
        id: id,
        deviceId: deviceId,
        type: type,
        name: name,
        pin: pin,
        state: state ?? this.state,
        createdAt: createdAt,
      );

  bool get isOn => state == 'on';
}
