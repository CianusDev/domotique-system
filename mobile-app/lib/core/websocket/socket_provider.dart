import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'socket_service.dart';

/// Exposes the singleton [SocketService].
/// Connect on login, disconnect on logout — call from auth notifier.
final socketServiceProvider = Provider<SocketService>((ref) {
  return SocketService.instance;
});
