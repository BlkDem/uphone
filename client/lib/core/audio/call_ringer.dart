import 'package:flutter/services.dart';

class CallRinger {
  static const _channel = MethodChannel('com.uphone/ringtone');

  static Future<void> start() async {
    try {
      await _channel.invokeMethod('startRingtone');
    } catch (e) {
      print('Failed to start ringtone: $e');
    }
  }

  static Future<void> stop() async {
    try {
      await _channel.invokeMethod('stopRingtone');
    } catch (_) {}
  }
}
