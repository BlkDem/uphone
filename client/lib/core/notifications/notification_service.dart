import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:uphone_client/core/config/server_config.dart';
import 'package:uphone_client/core/platform/windows_tray_service.dart';

import 'package:dio/dio.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM background message: ${message.messageId}');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  static NotificationService get instance => _instance;
  NotificationService._();

  FirebaseMessaging? _fcm;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  static final _callChannel = MethodChannel('com.uphone/call_screen');
  final StreamController<NotificationAction> _actionController =
      StreamController<NotificationAction>.broadcast();
  Stream<NotificationAction> get actions => _actionController.stream;

  String? _accessToken;
  String? _userId;
  NotificationAction? _pendingNativeCallIntent;

  void setAuth(String accessToken, String userId) {
    _accessToken = accessToken;
    _userId = userId;
    if (_fcmToken != null) {
      _registerToken(_fcmToken!);
    }
  }

  void clearAuth() {
    _accessToken = null;
    _userId = null;
  }

  Future<void> initialize() async {
    try {
      // Initialize local notifications (Android)
      const androidSettings = AndroidInitializationSettings(
        '@mipmap/ic_launcher',
      );
      const initSettings = InitializationSettings(android: androidSettings);
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      // Android-specific: create notification channels
      if (Platform.isAndroid) {
        final androidPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        if (androidPlugin != null) {
          await androidPlugin.createNotificationChannel(
            const AndroidNotificationChannel(
              'uphone_messages',
              'Messages',
              description: 'UPhone message notifications',
              importance: Importance.high,
              enableVibration: true,
            ),
          );
          await androidPlugin.createNotificationChannel(
            const AndroidNotificationChannel(
              'uphone_calls',
              'Calls',
              description: 'UPhone call notifications',
              importance: Importance.high,
              enableVibration: true,
            ),
          );
        }
      }

      // Android-specific: FCM setup
      if (Platform.isAndroid) {
        try {
          _fcm = FirebaseMessaging.instance;
          FirebaseMessaging.onBackgroundMessage(
            _firebaseMessagingBackgroundHandler,
          );
          final settings = await _fcm!.requestPermission(
            alert: true,
            badge: true,
            sound: true,
            provisional: false,
            criticalAlert: true,
          );
          debugPrint('FCM permission: ${settings.authorizationStatus}');

          _fcmToken = await _fcm!.getToken();
          debugPrint('FCM token: $_fcmToken');

          _fcm!.onTokenRefresh.listen((token) {
            _fcmToken = token;
            _registerToken(token);
          });

          FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
          FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

          final initialMessage = await _fcm!.getInitialMessage();
          if (initialMessage != null) {
            _handleMessageOpenedApp(initialMessage);
          }

          _callChannel.setMethodCallHandler((call) async {
            if (call.method == 'onCallIntent') {
              final data = Map<String, String>.from(call.arguments as Map);
              _handleNativeCallIntent(data);
            }
          });

          if (_fcmToken != null) {
            _registerToken(_fcmToken!);
          }
        } catch (e) {
          debugPrint('FCM init skipped: $e');
        }
      }

      debugPrint(
        'NotificationService initialized (Android: ${Platform.isAndroid}, Windows: ${Platform.isWindows})',
      );

      // Windows: route toast activation clicks (Accept/Reject/Show) into the app
      if (Platform.isWindows) {
        WindowsTrayService.instance.toastActivations.listen((argument) {
          final action = parseCallActionPayload(argument);
          if (action != null) {
            _actionController.add(action);
          }
        });
      }
    } catch (e) {
      debugPrint('NotificationService initialize failed: $e');
    }
  }

  static NotificationAction? parseCallActionPayload(String payload) {
    if (payload.isEmpty) return null;
    final parts = payload.split(':');
    if (parts.length < 6) return null;
    final action = parts[0].toUpperCase();
    if (action != 'ACCEPT' && action != 'REJECT' && action != 'SHOW') {
      return null;
    }
    return NotificationAction(
      action: action,
      callId: parts[1],
      fromUserId: parts[2],
      fromName: parts[3],
      callType: parts[4],
      isGroup: parts[5] == 'true',
    );
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] ?? '';

    if (type == 'call-request' || type == 'call-invite') {
      final callId = data['call_id'] ?? '';
      final fromUserId = data['from_user'] ?? '';
      final fromName = data['from_name'] ?? 'Unknown';
      final callType = data['call_type'] ?? 'video';
      final isGroup = type == 'call-invite';

      _actionController.add(
        NotificationAction(
          action: 'SHOW',
          callId: callId,
          fromUserId: fromUserId,
          fromName: fromName,
          callType: callType,
          isGroup: isGroup,
        ),
      );
    } else if (type == 'missed_call') {
      final callId = data['call_id'] ?? '';
      final callerId = data['caller_id'] ?? '';
      final callerName = data['caller_name'] ?? 'Кто-то';
      final callType = data['call_type'] ?? 'video';
      final chatId = data['chat_id'] ?? '';
      final title = data['title'] ?? 'Пропущенный звонок';
      final body = data['body'] ?? '$callerName пытался(-ась) дозвониться';

      _actionController.add(
        NotificationAction(
          action: 'MISSED_CALL',
          callId: callId,
          fromUserId: callerId,
          fromName: callerName,
          callType: callType,
          chatId: chatId,
        ),
      );

      _showMissedCallNotification(title, body);
    } else {
      // Regular message notification
      final title = data['title'] ?? message.notification?.title ?? 'UPhone';
      final body = data['body'] ?? message.notification?.body ?? '';
      _showSimpleNotification(title, body);
    }
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    final data = message.data;
    final type = data['type'] ?? '';

    if (type == 'call-request' || type == 'call-invite') {
      final callId = data['call_id'] ?? '';
      final fromUserId = data['from_user'] ?? '';
      final fromName = data['from_name'] ?? 'Unknown';
      final callType = data['call_type'] ?? 'video';
      final isGroup = type == 'call-invite';

      _actionController.add(
        NotificationAction(
          action: 'SHOW',
          callId: callId,
          fromUserId: fromUserId,
          fromName: fromName,
          callType: callType,
          isGroup: isGroup,
        ),
      );
    } else if (type == 'missed_call') {
      final callId = data['call_id'] ?? '';
      final callerId = data['caller_id'] ?? '';
      final callerName = data['caller_name'] ?? 'Кто-то';
      final callType = data['call_type'] ?? 'video';
      final chatId = data['chat_id'] ?? '';

      _actionController.add(
        NotificationAction(
          action: 'MISSED_CALL',
          callId: callId,
          fromUserId: callerId,
          fromName: callerName,
          callType: callType,
          chatId: chatId,
        ),
      );
    }
  }

  void _handleNativeCallIntent(Map<String, String> data) {
    final action = data['call_action'] ?? 'SHOW';
    final callId = data['call_id'] ?? '';
    final fromUserId = data['from_user'] ?? '';
    final fromName = data['from_name'] ?? 'Unknown';
    final callType = data['call_type'] ?? 'video';
    final isGroup = data['is_group'] == 'true';

    debugPrint('Native call intent: action=$action callId=$callId');

    final notificationAction = NotificationAction(
      action: action,
      callId: callId,
      fromUserId: fromUserId,
      fromName: fromName,
      callType: callType,
      isGroup: isGroup,
    );

    _actionController.add(notificationAction);
    _pendingNativeCallIntent = notificationAction;
  }

  NotificationAction? consumePendingNativeCallIntent() {
    final action = _pendingNativeCallIntent;
    _pendingNativeCallIntent = null;
    return action;
  }

  static Future<void> showOverLockScreen() async {
    try {
      await _callChannel.invokeMethod('showOverLockScreen');
    } catch (_) {}
  }

  static Future<void> cancelCallNotification({String? callId}) async {
    if (Platform.isWindows) {
      if (callId != null && callId.isNotEmpty) {
        final tray = WindowsTrayService.instance;
        if (tray.isInitialized) {
          await tray.dismissCallNotification(callId);
        }
      }
      return;
    }
    try {
      await _callChannel.invokeMethod('cancelCallNotification', {
        'callId': callId,
      });
    } catch (_) {}
  }

  static Future<void> resetCallScreenFlags() async {
    try {
      await _callChannel.invokeMethod('resetCallScreenFlags');
    } catch (_) {}
  }

  void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    final parts = payload.split(':');
    if (parts.length >= 6) {
      String action;
      if (response.actionId == 'accept') {
        action = 'ACCEPT';
      } else if (response.actionId == 'reject') {
        action = 'REJECT';
      } else {
        action = 'SHOW';
      }
      _actionController.add(
        NotificationAction(
          action: action,
          callId: parts[1],
          fromUserId: parts[2],
          fromName: parts[3],
          callType: parts[4],
          isGroup: parts[5] == 'true',
        ),
      );
    }
  }

  Future<void> _showSimpleNotification(String title, String body) async {
    // On Windows, use system tray balloon
    if (Platform.isWindows) {
      try {
        final tray = WindowsTrayService.instance;
        if (tray.isInitialized) {
          tray.showNotification(title, body);
        }
      } catch (_) {}
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'uphone_messages',
      'Messages',
      channelDescription: 'UPhone message notifications',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }

  Future<void> _showMissedCallNotification(String title, String body) async {
    // On Windows, use system tray balloon
    if (Platform.isWindows) {
      try {
        final tray = WindowsTrayService.instance;
        if (tray.isInitialized) {
          tray.showNotification(title, body);
        }
      } catch (_) {}
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'uphone_calls',
      'Calls',
      channelDescription: 'UPhone call notifications',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: androidDetails);
    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }

  Future<void> _registerToken(String token) async {
    if (_accessToken == null || _userId == null) return;

    try {
      final dio = Dio(
        BaseOptions(
          baseUrl: ServerConfig.instance.apiBaseUrl,
          headers: {
            'Authorization': 'Bearer $_accessToken',
            'Content-Type': 'application/json',
          },
        ),
      );
      await dio.post('/api/v1/users/fcm-token', data: {'token': token});
      debugPrint('FCM token registered with server');
    } catch (e) {
      debugPrint('Failed to register FCM token: $e');
    }
  }

  void showNewMessageNotification(String title, String body) {
    if (Platform.isWindows) {
      try {
        final tray = WindowsTrayService.instance;
        if (tray.isInitialized) {
          tray.showNotification(title, body);
        }
      } catch (_) {}
      return;
    }
    _showSimpleNotification(title, body);
  }

  Future<void> cancelAllNotifications() async {
    await _localNotifications.cancelAll();
  }
}

class NotificationAction {
  final String action;
  final String callId;
  final String fromUserId;
  final String? fromName;
  final String callType;
  final bool isGroup;
  final String? chatId;

  const NotificationAction({
    required this.action,
    required this.callId,
    required this.fromUserId,
    this.fromName,
    this.callType = 'video',
    this.isGroup = false,
    this.chatId,
  });
}
