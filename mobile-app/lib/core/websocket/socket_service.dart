import 'package:socket_io_client/socket_io_client.dart' as io;
import '../constants/api_constants.dart';
import '../storage/auth_storage.dart';

/// Singleton Socket.IO client.
/// Call [connect] after login, [disconnect] on logout.
/// Listen to typed events via [on] / [off].
///
/// Handler registration is safe to call BEFORE [connect] — handlers are
/// stored internally and applied to the socket as soon as it is created.
/// This avoids the race condition where a Riverpod notifier subscribes
/// during the async gap inside [connect] (while awaiting the token).
class SocketService {
  SocketService._();
  static final SocketService instance = SocketService._();

  io.Socket? _socket;

  /// Per-event handler registry. Handlers are registered here first, then
  /// forwarded to the socket. This ensures handlers survive the async gap
  /// between [connect] being called and the socket actually being created.
  final Map<String, Set<void Function(dynamic)>> _handlers = {};

  bool get isConnected => _socket?.connected == true;

  /// Connect to the WebSocket server using the stored auth cookie.
  /// Safe to call multiple times — no-op if socket already created.
  Future<void> connect() async {
    if (_socket != null) return; // already created (connecting or connected)

    final token = await AuthStorage.getToken();
    if (token == null) return; // not logged in

    _socket = io.io(
      ApiConstants.wsUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(double.infinity) // retry forever
          .setReconnectionDelay(2000)
          .setExtraHeaders({'cookie': 'authentication=$token'})
          .build(),
    );

    // Apply handlers registered BEFORE the socket was created (race-condition fix)
    for (final entry in _handlers.entries) {
      for (final handler in entry.value) {
        _socket!.on(entry.key, handler);
      }
    }

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

  /// Disconnect and clean up. Called on logout.
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _handlers.clear(); // notifiers have been disposed at this point
  }

  /// Subscribe to a WebSocket event.
  /// Safe to call before [connect] — handler is queued and applied when the
  /// socket is created.
  void on(String event, void Function(dynamic data) handler) {
    _handlers.putIfAbsent(event, () => {}).add(handler);
    _socket?.on(event, handler); // apply immediately if socket exists
  }

  /// Remove a specific handler for an event.
  void off(String event, void Function(dynamic data) handler) {
    _handlers[event]?.remove(handler);
    _socket?.off(event, handler);
  }

  /// Remove all handlers for an event (use with caution — affects all notifiers).
  void offAll(String event) {
    _handlers.remove(event);
    _socket?.off(event);
  }
}
