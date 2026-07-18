import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/app_config.dart';

typedef WSMessageHandler = void Function(Map<String, dynamic> message);

class WsClient {
  WebSocketChannel? _channel;
  String? _token;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  bool _shouldReconnect = true;
  WSMessageHandler? _onMessage;
  WSMessageHandler? _onConnect;
  WSMessageHandler? _onDisconnect;

  void connect(String token, {
    WSMessageHandler? onMessage,
    WSMessageHandler? onConnect,
    WSMessageHandler? onDisconnect,
  }) {
    _token = token;
    _onMessage = onMessage;
    _onConnect = onConnect;
    _onDisconnect = onDisconnect;
    _shouldReconnect = true;
    _doConnect();
  }

  void _doConnect() {
    try {
      final uri = Uri.parse('${AppConfig.wsUrl}?token=$_token');
      _channel = WebSocketChannel.connect(uri);

      _channel!.stream.listen(
        (data) {
          try {
            final msg = jsonDecode(data as String) as Map<String, dynamic>;
            _onConnect?.call({});
            _onMessage?.call(msg);
          } catch (_) {}
        },
        onDone: () {
          _onDisconnect?.call({});
          _pingTimer?.cancel();
          if (_shouldReconnect) {
            _reconnectTimer = Timer(const Duration(seconds: 3), _doConnect);
          }
        },
        onError: (_) {
          _onDisconnect?.call({});
          _pingTimer?.cancel();
          if (_shouldReconnect) {
            _reconnectTimer = Timer(const Duration(seconds: 3), _doConnect);
          }
        },
      );

      _startPing();
    } catch (_) {
      if (_shouldReconnect) {
        _reconnectTimer = Timer(const Duration(seconds: 3), _doConnect);
      }
    }
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      send({'type': 'ping'});
    });
  }

  void send(Map<String, dynamic> message) {
    _channel?.sink.add(jsonEncode(message));
  }

  void disconnect() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
  }
}
