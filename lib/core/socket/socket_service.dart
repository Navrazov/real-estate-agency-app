import 'package:socket_io_client/socket_io_client.dart' as io;
import '../api/api_client.dart';

class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  io.Socket? _socket;
  final ApiClient _api = ApiClient();
  bool _connected = false;

  bool get connected => _connected;
  io.Socket? get socket => _socket;

  Future<void> connect() async {
    if (_socket != null && _connected) return;

    final token = await _api.getToken();
    if (token == null) return;

    // Derive socket URL from API base URL (remove /api suffix)
    const baseUrl = 'http://localhost:3000';

    _socket = io.io(
      baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      _connected = true;
    });

    _socket!.onDisconnect((_) {
      _connected = false;
    });

    _socket!.onConnectError((data) {
      _connected = false;
    });

    _socket!.connect();
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _connected = false;
  }

  void on(String event, Function(dynamic) handler) {
    _socket?.on(event, handler);
  }

  void off(String event) {
    _socket?.off(event);
  }

  void emit(String event, dynamic data) {
    _socket?.emit(event, data);
  }
}
