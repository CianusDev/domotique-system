import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the JWT extracted from the backend httpOnly cookie.
/// On mobile, Dio cannot use browser cookie jars — we manually
/// intercept Set-Cookie on login/verify and store here.
class AuthStorage {
  AuthStorage._();

  static const _tokenKey = 'auth_token';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  static Future<String?> getToken() => _storage.read(key: _tokenKey);

  static Future<void> clearToken() => _storage.delete(key: _tokenKey);

  static Future<bool> hasToken() async =>
      (await _storage.read(key: _tokenKey)) != null;
}
