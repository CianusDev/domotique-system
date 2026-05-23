class MqttConstants {
  static const String broker = String.fromEnvironment(
    'MQTT_BROKER',
    defaultValue: '10.0.2.2',
  );
  static const int port = 1883;

  /// home/{deviceId}/status
  static String deviceStatus(String deviceId) => 'home/$deviceId/status';

  /// home/{deviceId}/sensors/discovery
  static String sensorDiscovery(String deviceId) =>
      'home/$deviceId/sensors/discovery';

  /// home/{deviceId}/sensors/{sensorId}/data
  static String sensorData(String deviceId, String sensorId) =>
      'home/$deviceId/sensors/$sensorId/data';

  /// home/{deviceId}/sensors/control/add
  static String sensorAdd(String deviceId) =>
      'home/$deviceId/sensors/control/add';

  /// home/{deviceId}/actuators/{type}/cmd/state
  static String actuatorCmd(String deviceId, String type) =>
      'home/$deviceId/actuators/$type/cmd/state';
}
