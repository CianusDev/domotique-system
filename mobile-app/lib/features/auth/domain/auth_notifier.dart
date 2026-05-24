import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/storage/auth_storage.dart';
import '../../../shared/utils/dio_error_helper.dart';
import '../data/auth_repository.dart';
import 'auth_state.dart';

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._repo) : super(const AuthState.initial());

  final AuthRepository _repo;

  /// Called on app start — tries to restore session from stored token.
  Future<void> checkAuth() async {
    state = const AuthState.loading();
    try {
      // Timeout guards against FlutterSecureStorage keystore hang on first run.
      final hasToken = await AuthStorage.hasToken().timeout(
        const Duration(seconds: 4),
        onTimeout: () => false,
      );
      if (!hasToken) {
        state = const AuthState.unauthenticated();
        return;
      }
      final user = await _repo.profile();
      state = AuthState.authenticated(user);
    } catch (_) {
      await AuthStorage.clearToken().catchError((_) {});
      state = const AuthState.unauthenticated();
    }
  }

  Future<void> login(String email, String password) async {
    state = const AuthState.loading();
    try {
      final user = await _repo.login(email, password);
      state = AuthState.authenticated(user);
    } catch (e) {
      state = state.withError(extractDioError(e));
    }
  }

  /// register() returns — caller navigates to verify-email.
  /// Throws on error so the screen can catch it.
  Future<void> register({
    required String username,
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    state = const AuthState.loading();
    try {
      await _repo.register(
        username: username,
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
      );
      // Stay unauthenticated until email is verified
      state = const AuthState.unauthenticated();
    } catch (e) {
      state = state.withError(extractDioError(e));
      rethrow;
    }
  }

  Future<void> verifyEmail(String email, String code) async {
    state = const AuthState.loading();
    try {
      final user = await _repo.verifyEmail(email, code);
      state = AuthState.authenticated(user);
    } catch (e) {
      state = state.withError(extractDioError(e));
    }
  }

  Future<void> logout() async {
    try {
      await _repo.logout();
    } catch (_) {
      // logout best-effort
    } finally {
      await AuthStorage.clearToken();
      state = const AuthState.unauthenticated();
    }
  }

  Future<void> forgotPassword(String email) async {
    await _repo.forgotPassword(email);
  }

  Future<void> resendVerification(String email) async {
    await _repo.resendVerification(email);
  }

  void clearError() {
    if (state.error != null) {
      state = state.copyWith(error: null, status: AuthStatus.unauthenticated);
    }
  }
}

final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.read(authRepositoryProvider));
});
