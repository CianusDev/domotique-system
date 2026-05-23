import '../../../shared/models/user_model.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? error;

  const AuthState({
    required this.status,
    this.user,
    this.error,
  });

  const AuthState.initial()
      : status = AuthStatus.initial,
        user = null,
        error = null;

  const AuthState.loading()
      : status = AuthStatus.loading,
        user = null,
        error = null;

  const AuthState.authenticated(this.user)
      : status = AuthStatus.authenticated,
        error = null;

  const AuthState.unauthenticated()
      : status = AuthStatus.unauthenticated,
        user = null,
        error = null;

  AuthState withError(String message) => AuthState(
        status: AuthStatus.error,
        user: user,
        error: message,
      );

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading => status == AuthStatus.loading;
  bool get isInitial => status == AuthStatus.initial;

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    String? error,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error ?? this.error,
    );
  }

  @override
  String toString() =>
      'AuthState(status: $status, user: ${user?.email}, error: $error)';
}
