import 'package:dio/dio.dart';

/// Extracts a user-friendly message from Dio errors.
/// Backend returns: `{ message: string | string[], error, statusCode }`
String extractDioError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) {
      final msg = data['message'];
      if (msg is List && msg.isNotEmpty) return msg.first.toString();
      if (msg != null) return msg.toString();
    }
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'Serveur inaccessible. Vérifiez votre connexion.';
    }
    if (error.type == DioExceptionType.connectionError) {
      return 'Impossible de joindre le serveur.';
    }
  }
  return 'Une erreur est survenue. Réessayez.';
}
