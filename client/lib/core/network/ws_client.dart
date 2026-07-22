import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

typedef WSMessageHandler = void Function(Map<String, dynamic> message);
typedef TokenProvider = Future<String?> Function();
typedef TokenRefreshedCallback = void Function(String newToken);

class WsClient {
  WebSocketChannel? _channel;
  String? _token;
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  bool _shouldReconnect = true;
  int _reconnectAttempts = 0;
  static const int _maxReconnectDelay = 60;
  static const int _maxReconnectAttempts = 5;
  String? _wsUrl;
  final Map<String, WSMessageHandler> _messageHandlers = {};
  WSMessageHandler? _onConnect;
  WSMessageHandler? _onDisconnect;
  TokenProvider? _tokenProvider;
  TokenRefreshedCallback? _onTokenRefreshed;

  set onTokenRefreshed(TokenRefreshedCallback? callback) {
    _onTokenRefreshed = callback;
  }

  set onMessage(WSMessageHandler? handler) {
    if (handler != null) {
      _messageHandlers['_default'] = handler;
    } else {
      _messageHandlers.remove('_default');
    }
  }

  void addHandler(String id, WSMessageHandler handler) {
    _messageHandlers[id] = handler;
  }

  void removeHandler(String id) {
    _messageHandlers.remove(id);
  }

  void connect(String token, {
    String? wsUrl,
    WSMessageHandler? onMessage,
    WSMessageHandler? onConnect,
    WSMessageHandler? onDisconnect,
    TokenProvider? tokenProvider,
  }) {
    _token = token;
    _wsUrl = wsUrl;
    _tokenProvider = tokenProvider;
    if (onMessage != null) {
      _messageHandlers['_default'] = onMessage;
    }
    _onConnect = onConnect;
    _onDisconnect = onDisconnect;
    _shouldReconnect = true;
    _reconnectAttempts = 0;
    _doConnect();
  }

  Future<void> _refreshTokenIfNeeded() async {
    if (_tokenProvider == null) return;
    final freshToken = await _tokenProvider!();
    if (freshToken != null && freshToken.isNotEmpty && freshToken != _token) {
      _token = freshToken;
      _reconnectAttempts = 0;
      _onTokenRefreshed?.call(freshToken);
    }
  }

  void _doConnect() async {
    await _refreshTokenIfNeeded();
    if (_token == null || _token!.isEmpty) {
      _scheduleReconnect();
      return;
    }

    try {
      final uri = Uri.parse('${_wsUrl ?? "ws://localhost:8080/ws"}?token=$_token');
      _channel = WebSocketChannel.connect(uri);

      _channel!.stream.listen(
        (data) {
          try {
            final msg = jsonDecode(data as String) as Map<String, dynamic>;
            print('WS RECV: type=${msg['type']} handlers=${_messageHandlers.keys.toList()}');
            _reconnectAttempts = 0;
            for (final entry in _messageHandlers.entries.toList()) {
              try {
                entry.value(msg);
              } catch (e) {
                print('WS handler "${entry.key}" error: $e');
              }
            }
          } catch (e) {
            print('WS parse error: $e');
          }
        },
        onDone: () {
          _onDisconnect?.call({});
          _pingTimer?.cancel();
          _scheduleReconnect();
        },
        onError: (_) {
          _onDisconnect?.call({});
          _pingTimer?.cancel();
          _scheduleReconnect();
        },
      );

      _startPing();
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _onDisconnect?.call({'reason': 'max_retries_exceeded'});
      return;
    }
    final delay = _getReconnectDelay();
    _reconnectTimer = Timer(Duration(seconds: delay), _doConnect);
  }

  int _getReconnectDelay() {
    _reconnectAttempts++;
    final delay = (2 * _reconnectAttempts).clamp(2, _maxReconnectDelay);
    return delay;
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

  bool get isConnected => _channel != null;

  void reconnect() {
    if (_token == null || _token!.isEmpty) return;
    _reconnectAttempts = 0;
    _shouldReconnect = true;
    _pingTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _doConnect();
  }
}
