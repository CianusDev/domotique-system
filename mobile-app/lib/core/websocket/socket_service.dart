import 'package:socket_io_client/socket_io_client.dart' as io;
import '../constants/api_constants.dart';
import '../storage/auth_storage.dart';

/// Singleton Socket.IO client.
/// Call [connect] after login, [disconnect] on logout.
/// Listen to typed events via [on].
class SocketService {
  SocketService._();
  static final SocketService instance = SocketService._();

  io.Socket? _socket;

  bool get isConnected => _socket?.connected == true;

  /// Connect to the WebSocket server using the stored auth cookie.
  Future<void> connect() async {
    if (isConnected) return;

    final token = await AuthStorage.getToken();
    if (token == null) return; // not logged in

    _socket = io.io(
      ApiConstants.wsUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(double.infinity)  // retry forever
          .setReconnectionDelay(2000)
          .setExtraHeaders({'cookie': 'authentication=$token'})
          .build(),
    );

    _socket!.onConnect((_) {
      // ignore: avoid_print
      print('[WS] Connected');
    });
    _socket!.onDisconnect((_) {
      // ignore: avoid_print
      print('[WS] Disconnected');
    });
    _socket!.onConnectError((e) {
      // ignore: avoid_print
      print('[WS] Connect error: $e');
    });
  }

  /// Disconnect and clean up.
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  /// Subscribe to a WebSocket event.
  void on(String event, void Function(dynamic data) handler) {
    _socket?.on(event, handler);
  }

  /// Remove a specific handler.
  void off(String event, void Function(dynamic data) handler) {
    _socket?.off(event, handler);
  }

  /// Remove all handlers for an event.
  void offAll(String event) {
    _socket?.off(event);
  }
}
