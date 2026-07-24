import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class BatteryOptimization {
  static const _channel = MethodChannel('com.uphone/battery_optimization');

  static Future<bool> isIgnoringBatteryOptimizations() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;
    try {
      return await _channel.invokeMethod<bool>('isIgnoringBatteryOptimizations') ?? false;
    } catch (_) {
      return true;
    }
  }

  static Future<bool> requestExemption(BuildContext context) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return true;

    final isAlreadyExempt = await isIgnoringBatteryOptimizations();
    if (isAlreadyExempt) return true;

    if (!context.mounted) return false;

    final shouldRequest = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.battery_saver),
        title: const Text('Battery Optimization'),
        content: const Text(
          'For reliable call notifications, UPhone needs to be excluded from battery optimization. '
          'This allows the app to receive calls when in the background.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );

    if (shouldRequest != true || !context.mounted) return false;

    try {
      await _channel.invokeMethod('requestIgnoreBatteryOptimizations');
      return true;
    } catch (_) {
      return false;
    }
  }
}
