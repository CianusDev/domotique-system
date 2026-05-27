import '../../../shared/models/user_model.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

/// Sentinel used to distinguish "leave unchanged" from "set to null"
/// in [AuthState.copyWith]. Without this, copyWith(error: null) cannot
/// clear the error field (null falls through the ?? default).
const _kUnchanged = Object();

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
    Object? user  = _kUnchanged,
    Object? error = _kUnchanged,
  }) {
    return AuthState(
      status: status ?? this.status,
      user:  identical(user,  _kUnchanged) ? this.user  : user  as UserModel?,
      error: identical(error, _kUnchanged) ? this.error : error as String?,
    );
  }

  @override
  String toString() =>
      'AuthState(status: $status, user: ${user?.email}, error: $error)';
}
