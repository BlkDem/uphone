import 'dart:async';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
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

  final StreamController<NotificationAction> _actionController =
      StreamController<NotificationAction>.broadcast();
  Stream<NotificationAction> get actions => _actionController.stream;

  String? _accessToken;
  String? _userId;

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

      // Create notification channel for calls
      if (Platform.isAndroid) {
        final androidPlugin =
            _localNotifications.resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlugin != null) {
          await androidPlugin.createNotificationChannel(
            const AndroidNotificationChannel(
              'uphone_calls',
              'Incoming Calls',
              description: 'UPhone incoming call notifications',
              importance: Importance.max,
              enableVibration: true,
              enableLights: true,
            ),
          );
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

      _showCallNotification(
        callId: callId,
        fromUserId: fromUserId,
        fromName: fromName,
        callType: callType,
        isGroup: isGroup,
      );
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
        action: 'ACCEPT',
        callId: callId,
        fromUserId: fromUserId,
        fromName: fromName,
        callType: callType,
        isGroup: isGroup,
      ));
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;

    // payload format: "type:callId:fromUserId:callType:isGroup"
    final parts = payload.split(':');
    if (parts.length >= 5) {
      final action = response.actionId == 'accept' ? 'ACCEPT' : 'REJECT';
      _actionController.add(NotificationAction(
        action: action,
        callId: parts[1],
        fromUserId: parts[2],
        callType: parts[3],
        isGroup: parts[4] == 'true',
      ));
    }
  }

  Future<void> _showCallNotification({
    required String callId,
    required String fromUserId,
    required String fromName,
    required String callType,
    required bool isGroup,
  }) async {
    final title = isGroup ? 'Group $callType call' : 'Incoming $callType call';
    final body = isGroup ? '$fromName is calling in group' : '$fromName is calling...';

    final payload = 'call:$callId:$fromUserId:$callType:$isGroup';

    final androidDetails = AndroidNotificationDetails(
      'uphone_calls',
      'Incoming Calls',
      channelDescription: 'UPhone incoming call notifications',
      importance: Importance.max,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      fullScreenIntent: true,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction('accept', 'Accept',
            showsUserInterface: true, cancelNotification: true),
        AndroidNotificationAction('reject', 'Reject',
            showsUserInterface: false, cancelNotification: true),
      ],
    );
    final details = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      callId.hashCode,
      title,
      body,
      details,
      payload: payload,
    );
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

  Future<void> cancelCallNotification(String callId) async {
    await _localNotifications.cancel(callId.hashCode);
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
