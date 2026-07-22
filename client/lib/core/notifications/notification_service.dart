import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:uphone_client/core/config/server_config.dart';

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
      _fcm = FirebaseMessaging.instance;

      // Register background handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Initialize local notifications
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initSettings = InitializationSettings(android: androidSettings);
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      // Create notification channel for messages
      if (Platform.isAndroid) {
        final androidPlugin =
            _localNotifications.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
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
        }
      }

      // Request permission
      final settings = await _fcm!.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        criticalAlert: true,
      );
      debugPrint('FCM permission: ${settings.authorizationStatus}');

      // Get token
      _fcmToken = await _fcm!.getToken();
      debugPrint('FCM token: $_fcmToken');

      // Listen for token refresh
      _fcm!.onTokenRefresh.listen((token) {
        _fcmToken = token;
        _registerToken(token);
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle notification tap when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

      // Check if app opened from notification
      final initialMessage = await _fcm!.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageOpenedApp(initialMessage);
      }

      // Listen for native full-screen intent call data (from CallNotificationService)
      _callChannel.setMethodCallHandler((call) async {
        if (call.method == 'onCallIntent') {
          final data = Map<String, String>.from(call.arguments as Map);
          _handleNativeCallIntent(data);
        }
      });

      // Register token with server
      if (_fcmToken != null) {
        _registerToken(_fcmToken!);
      }
    } catch (e) {
      debugPrint('NotificationService initialize failed: $e');
    }
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

      _actionController.add(NotificationAction(
        action: 'SHOW',
        callId: callId,
        fromUserId: fromUserId,
        fromName: fromName,
        callType: callType,
        isGroup: isGroup,
      ));
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

      _actionController.add(NotificationAction(
        action: 'SHOW',
        callId: callId,
        fromUserId: fromUserId,
        fromName: fromName,
        callType: callType,
        isGroup: isGroup,
      ));
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

  static Future<void> cancelCallNotification() async {
    try {
      await _callChannel.invokeMethod('cancelCallNotification');
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
      _actionController.add(NotificationAction(
        action: action,
        callId: parts[1],
        fromUserId: parts[2],
        fromName: parts[3],
        callType: parts[4],
        isGroup: parts[5] == 'true',
      ));
    }
  }

  Future<void> _showSimpleNotification(String title, String body) async {
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

  Future<void> _registerToken(String token) async {
    if (_accessToken == null || _userId == null) return;

    try {
      final dio = Dio(BaseOptions(
        baseUrl: ServerConfig.instance.apiBaseUrl,
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
      ));
      await dio.post('/api/v1/users/fcm-token', data: {'token': token});
      debugPrint('FCM token registered with server');
    } catch (e) {
      debugPrint('Failed to register FCM token: $e');
    }
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

  const NotificationAction({
    required this.action,
    required this.callId,
    required this.fromUserId,
    this.fromName,
    this.callType = 'video',
    this.isGroup = false,
  });
}
