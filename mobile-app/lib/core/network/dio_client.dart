import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../storage/auth_storage.dart';

Dio createDioClient() {
  return Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ),
  )..interceptors.addAll([
      _AuthInterceptor(),
      LogInterceptor(requestBody: true, responseBody: true),
    ]);
}

/// Attaches stored JWT as Cookie header on every request.
/// On response, extracts Set-Cookie to keep token fresh.
class _AuthInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await AuthStorage.getToken();
    if (token != null) {
      options.headers['Cookie'] = 'authentication=$token';
    }
    handler.next(options);
  }

  @override
  Future<void> onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    final cookieHeaders = response.headers['set-cookie'];
    if (cookieHeaders != null) {
      for (final cookie in cookieHeaders) {
        final match = RegExp(r'authentication=([^;]*)').firstMatch(cookie);
        if (match != null) {
          final value = match.group(1) ?? '';
          if (value.isEmpty || value == 'deleted') {
            await AuthStorage.clearToken();
          } else {
            await AuthStorage.saveToken(value);
          }
          break;
        }
      }
    }
    handler.next(response);
  }
}
