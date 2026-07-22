import 'package:flutter/services.dart';

class WsServiceBridge {
  static const _channel = MethodChannel('com.uphone/ws_service');
  static bool _started = false;

  static Future<void> start(String wsUrl, String token) async {
    try {
      await _channel.invokeMethod('startWsService', {
        'wsUrl': wsUrl,
        'token': token,
      });
      _started = true;
    } catch (e) {
      print('WsServiceBridge start failed: $e');
    }
  }

  static Future<void> stop() async {
    try {
      await _channel.invokeMethod('stopWsService');
      _started = false;
    } catch (e) {
      print('WsServiceBridge stop failed: $e');
    }
  }

  static Future<String> readDebugLog() async {
    try {
      return await _channel.invokeMethod<String>('readWsDebugLog') ?? '';
    } catch (e) {
      return 'readLog error: $e';
    }
  }

  static bool get isStarted => _started;
}
