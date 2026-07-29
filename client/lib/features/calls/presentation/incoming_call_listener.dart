import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uphone_client/core/network/ws_client.dart';
import 'package:uphone_client/core/notifications/notification_service.dart';
import 'package:uphone_client/core/router/app_router.dart';
import 'package:uphone_client/features/auth/domain/auth_provider.dart';
import 'package:uphone_client/features/calls/domain/call_provider.dart';
import 'package:uphone_client/features/calls/domain/webrtc_service.dart';
import 'package:uphone_client/features/calls/presentation/call_screen.dart';
import 'package:uphone_client/features/calls/presentation/incoming_call_screen.dart';

class IncomingCallListener extends ConsumerStatefulWidget {
  final Widget child;
  const IncomingCallListener({super.key, required this.child});

  @override
  ConsumerState<IncomingCallListener> createState() =>
      _IncomingCallListenerState();
}

class _IncomingCallListenerState
    extends ConsumerState<IncomingCallListener> {
  StreamSubscription<CallEvent>? _sub;
  StreamSubscription<NotificationAction>? _notifSub;
  bool _isShowingIncomingCall = false;
  String? _pendingCallId;
  String? _pendingRemoteUserId;
  String? _pendingRemoteUserName;
  String? _pendingCallType;
  bool _pendingIsGroup = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _listen();
      _listenNotifications();
      _checkPendingNativeIntent();
    });
  }

  void _checkPendingNativeIntent() {
    final pending =
        NotificationService.instance.consumePendingNativeCallIntent();
    if (pending != null && pending.callId.isNotEmpty) {
      if (pending.action == 'SHOW') {
        _showIncomingCallFromNotification(pending);
      } else if (pending.action == 'ACCEPT') {
        _acceptFromNotification(pending);
      } else if (pending.action == 'REJECT') {
        _rejectFromNotification(pending);
      }
    }
  }

  Future<void> _ensureWsConnected() async {
    final apiClient = ref.read(apiClientProvider);
    final wsClient = ref.read(wsClientProvider);
    final token = apiClient.accessToken;
    if (token == null || token.isEmpty) return;
    if (wsClient.isConnected) return;
    wsClient.reconnect();
    for (int i = 0; i < 50; i++) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (wsClient.isConnected) return;
    }
    debugPrint('_ensureWsConnected: timeout waiting for WS');
  }

  void _listen() {
    final webrtc = ref.read(webRTCServiceProvider);
    webrtc.init();
    _sub = webrtc.callEvents.listen((event) {
      if (!mounted) return;
      if (event is IncomingCallEvent) {
        _showIncomingCallScreen(event);
      } else if (event is CallAcceptedEvent) {
        if (_pendingCallId != null && event.callId == _pendingCallId) {
          _pushCallScreen(
            callId: _pendingCallId!,
            remoteUserId: _pendingRemoteUserId!,
            remoteUserName: _pendingRemoteUserName!,
            callType: _pendingCallType!,
            isIncoming: true,
            isGroup: _pendingIsGroup,
          );
          _clearPending();
        }
      } else if (event is CallEndedEvent || event is CallRejectedEvent) {
        if (_isShowingIncomingCall && event.callId == _pendingCallId) {
          _closeIncomingCallScreen();
        }
        NotificationService.cancelCallNotification(callId: event.callId);
        _clearPending();
      }
    });
  }

  void _listenNotifications() {
    _notifSub = NotificationService.instance.actions.listen((action) {
      if (!mounted) return;
      if (action.action == 'ACCEPT') {
        _acceptFromNotification(action);
      } else if (action.action == 'REJECT') {
        _rejectFromNotification(action);
      } else if (action.action == 'SHOW') {
        _showIncomingCallFromNotification(action);
      } else if (action.action == 'END') {
        _closeIncomingCallScreen();
        NotificationService.cancelCallNotification(callId: action.callId);
        _clearPending();
        if (ref.read(webRTCServiceProvider).currentCallId != null) {
          final navKey = ref.read(navigatorKeyProvider);
          final navigator = navKey.currentState;
          if (navigator != null && navigator.canPop()) {
            navigator.pop();
          }
        }
      } else if (action.action == 'MISSED_CALL') {
        _handleMissedCall(action);
      }
    });
  }

  void _showIncomingCallFromNotification(NotificationAction action) {
    final navKey = ref.read(navigatorKeyProvider);
    final navigator = navKey.currentState;
    if (navigator == null) return;
    if (_isShowingIncomingCall) return;

    _pendingCallId = action.callId;
    _pendingRemoteUserId = action.fromUserId;
    _pendingRemoteUserName = action.fromName ?? 'Unknown';
    _pendingCallType = action.callType;
    _pendingIsGroup = action.isGroup;

    _isShowingIncomingCall = true;
    final route = MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => IncomingCallScreen(
        callId: action.callId,
        remoteUserId: action.fromUserId,
        remoteUserName: action.fromName ?? 'Unknown',
        callType: action.callType,
        isGroup: action.isGroup,
      ),
    );
    navigator.push<void>(route).then((_) {
      _isShowingIncomingCall = false;
    });
  }

  Future<void> _acceptFromNotification(NotificationAction action) async {
    NotificationService.cancelCallNotification(callId: action.callId);
    await _ensureWsConnected();
    if (!mounted) return;
    _isShowingIncomingCall = false;
    _pendingCallId = action.callId;
    _pendingRemoteUserId = action.fromUserId;
    _pendingRemoteUserName = action.fromName ?? 'Unknown';
    _pendingCallType = action.callType;
    _pendingIsGroup = action.isGroup;
    final webrtc = ref.read(webRTCServiceProvider);
    webrtc.acceptCall(
      action.callId,
      action.fromUserId,
      callType: action.callType,
      isGroup: action.isGroup,
    );
  }

  void _rejectFromNotification(NotificationAction action) {
    _closeIncomingCallScreen();
    NotificationService.cancelCallNotification(callId: action.callId);
    final webrtc = ref.read(webRTCServiceProvider);
    webrtc.rejectCall(action.callId, action.fromUserId);
  }

  void _showIncomingCallScreen(IncomingCallEvent event) {
    final navKey = ref.read(navigatorKeyProvider);
    final navigator = navKey.currentState;
    if (navigator == null) return;
    if (_isShowingIncomingCall) return;

    _pendingCallId = event.callId;
    _pendingRemoteUserId = event.fromUserId;
    _pendingRemoteUserName = event.fromName;
    _pendingCallType = event.callType;
    _pendingIsGroup = event.isGroup;

    _isShowingIncomingCall = true;
    final route = MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => IncomingCallScreen(
        callId: event.callId,
        remoteUserId: event.fromUserId,
        remoteUserName: event.fromName,
        callType: event.callType,
        isGroup: event.isGroup,
        chatName: event.chatName,
      ),
    );
    navigator.push<void>(route).then((_) {
      _isShowingIncomingCall = false;
    });
  }

  void _closeIncomingCallScreen() {
    if (!_isShowingIncomingCall) return;
    _isShowingIncomingCall = false;
    final navKey = ref.read(navigatorKeyProvider);
    final navigator = navKey.currentState;
    if (navigator != null && navigator.canPop()) {
      try {
        navigator.pop();
      } catch (_) {}
    }
  }

  void _clearPending() {
    _pendingCallId = null;
    _pendingRemoteUserId = null;
    _pendingRemoteUserName = null;
    _pendingCallType = null;
    _pendingIsGroup = false;
  }

  void _handleMissedCall(NotificationAction action) {
    final chatId = action.chatId;
    if (chatId != null && chatId.isNotEmpty) {
      final navKey = ref.read(navigatorKeyProvider);
      final router = ref.read(routerProvider);
      router.go('/chats/$chatId', extra: navKey);
    }
  }

  void _pushCallScreen({
    required String callId,
    required String remoteUserId,
    required String remoteUserName,
    required String callType,
    required bool isIncoming,
    required bool isGroup,
  }) {
    final replaceTop = _isShowingIncomingCall;
    _isShowingIncomingCall = false;
    final navKey = ref.read(navigatorKeyProvider);
    final navigator = navKey.currentState;
    if (navigator == null) return;

    final route = MaterialPageRoute(
      builder: (_) => CallScreen(
        callId: callId,
        remoteUserId: remoteUserId,
        remoteUserName: remoteUserName,
        callType: callType,
        isIncoming: isIncoming,
        isGroup: isGroup,
      ),
    );

    if (replaceTop) {
      navigator.pushReplacement(route);
    } else {
      navigator.push(route);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _notifSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
