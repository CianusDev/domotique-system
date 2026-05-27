import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../constants/api_constants.dart';
import '../storage/auth_storage.dart';

Dio createDioClient() {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  // Order matters: log AFTER auth so secrets are still inspectable in debug,
  // but only when running in debug mode — never in release.
  dio.interceptors.add(_AuthInterceptor());

  if (kDebugMode) {
    dio.interceptors.add(_SafeLogInterceptor());
  }

  return dio;
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

/// Logs requests/responses with sensitive fields redacted.
/// Never enabled in release builds.
class _SafeLogInterceptor extends Interceptor {
  static const _sensitiveFields = {
    'password',
    'newPassword',
    'oldPassword',
    'token',
    'code',
  };

  Object? _redact(Object? data) {
    if (data is! Map) return data;
    final cleaned = <String, dynamic>{};
    data.forEach((k, v) {
      cleaned[k.toString()] = _sensitiveFields.contains(k) ? '***' : v;
    });
    return cleaned;
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('→ ${options.method} ${options.uri}');
    if (options.data != null) {
      debugPrint('  body: ${_redact(options.data)}');
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint('← ${response.statusCode} ${response.requestOptions.uri}');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint('✗ ${err.requestOptions.method} ${err.requestOptions.uri}'
        ' — ${err.response?.statusCode ?? err.type}');
    handler.next(err);
  }
}
