import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/providers/dio_provider.dart';
import '../../../shared/models/user_model.dart';

class AuthRepository {
  AuthRepository(this._dio);
  final Dio _dio;

  /// Returns the authenticated user. Cookie is saved by _AuthInterceptor.
  Future<UserModel> login(String email, String password) async {
    final res = await _dio.post(
      ApiConstants.login,
      data: {'email': email, 'password': password},
    );
    // data: { access_token, user }
    final data = res.data['data'] as Map<String, dynamic>;
    return UserModel.fromJson(data['user'] as Map<String, dynamic>);
  }

  /// Creates account and sends verification email.
  Future<void> register({
    required String username,
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    await _dio.post(ApiConstants.register, data: {
      'username': username,
      'email': email,
      'password': password,
      if (firstName != null && firstName.isNotEmpty) 'firstName': firstName,
      if (lastName != null && lastName.isNotEmpty) 'lastName': lastName,
    });
  }

  /// Verifies 6-digit OTP. Cookie saved by interceptor.
  Future<UserModel> verifyEmail(String email, String code) async {
    final res = await _dio.post(
      ApiConstants.verifyEmail,
      data: {'email': email, 'code': code},
    );
    final data = res.data['data'] as Map<String, dynamic>;
    return UserModel.fromJson(data['user'] as Map<String, dynamic>);
  }

  /// Fetches authenticated user profile.
  Future<UserModel> profile() async {
    final res = await _dio.get(ApiConstants.profile);
    // data is UserWithoutPassword directly (not nested)
    final data = res.data['data'] as Map<String, dynamic>;
    return UserModel.fromJson(data);
  }

  Future<void> logout() async {
    await _dio.post(ApiConstants.logout);
  }

  Future<void> forgotPassword(String email) async {
    await _dio.post(ApiConstants.forgotPassword, data: {'email': email});
  }

  Future<void> resendVerification(String email) async {
    await _dio.post(
      ApiConstants.resendVerification,
      data: {'email': email},
    );
  }

  /// Resets password using 6-digit OTP received by email.
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _dio.post(ApiConstants.resetPassword, data: {
      'email': email,
      'code': code,
      'newPassword': newPassword,
    });
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(dioProvider)),
);
