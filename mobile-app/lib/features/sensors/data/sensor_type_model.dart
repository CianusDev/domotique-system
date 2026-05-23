class SensorDataField {
  final String field;
  final String unit;
  final String dataType;

  const SensorDataField({
    required this.field,
    required this.unit,
    required this.dataType,
  });

  factory SensorDataField.fromJson(Map<String, dynamic> json) {
    return SensorDataField(
      field: json['field'] as String,
      unit: json['unit'] as String,
      dataType: json['dataType'] as String,
    );
  }
}

class SensorTypeModel {
  final String id;
  final String type;
  final String name;
  final String? description;
  final String category;
  final List<SensorDataField> dataFields;

  const SensorTypeModel({
    required this.id,
    required this.type,
    required this.name,
    this.description,
    required this.category,
    required this.dataFields,
  });

  factory SensorTypeModel.fromJson(Map<String, dynamic> json) {
    final fields = (json['dataFields'] as List<dynamic>? ?? [])
        .map((e) => SensorDataField.fromJson(e as Map<String, dynamic>))
        .toList();

    return SensorTypeModel(
      id: json['id'] as String,
      type: json['type'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      category: json['category'] as String,
      dataFields: fields,
    );
  }
}
