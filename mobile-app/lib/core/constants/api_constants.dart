class ApiConstants {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.32.182:5000/api',
  );

  static const String mqttBroker = String.fromEnvironment(
    'MQTT_BROKER',
    defaultValue: '192.168.32.182',
  );

  // Auth
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String profile = '/auth/profile';
  static const String verifyEmail = '/auth/verify-email';
  static const String resendVerification = '/auth/resend-verification-email';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';
  static const String resendReset = '/auth/resend-reset-password';
  // Devices
  static const String devices = '/devices';

  // Sensors
  static const String sensorTypes = '/sensor-types';

  // Actuators — /actuators/:id/control  |  /devices/:deviceId/actuators
  static const String actuators = '/actuators';

  // Automations
  static const String automations = '/automations';
}
