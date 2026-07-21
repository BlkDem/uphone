import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uphone_client/core/notifications/notification_service.dart';
import 'package:uphone_client/core/router/app_router.dart';
import 'package:uphone_client/features/calls/domain/call_provider.dart';
import 'package:uphone_client/features/calls/domain/webrtc_service.dart';
import 'package:uphone_client/features/calls/presentation/call_screen.dart';

class IncomingCallListener extends ConsumerStatefulWidget {
  final Widget child;
  const IncomingCallListener({super.key, required this.child});

  @override
  ConsumerState<IncomingCallListener> createState() => _IncomingCallListenerState();
}

class _IncomingCallListenerState extends ConsumerState<IncomingCallListener> {
  StreamSubscription<CallEvent>? _sub;
  StreamSubscription<NotificationAction>? _notifSub;
  Route<void>? _activeDialogRoute;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _listen();
      _listenNotifications();
    });
  }

  void _listen() {
    final webrtc = ref.read(webRTCServiceProvider);
    webrtc.init();
    _sub = webrtc.callEvents.listen((event) {
      if (!mounted) return;
      if (event is IncomingCallEvent) {
        _showIncomingCallDialog(event);
      } else if (event is CallEndedEvent || event is CallRejectedEvent) {
        _closeActiveDialog();
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
      }
    });
  }

  void _acceptFromNotification(NotificationAction action) {
    final webrtc = ref.read(webRTCServiceProvider);
    webrtc.acceptCall(
      action.callId,
      action.fromUserId,
      callType: action.callType,
      isGroup: action.isGroup,
    );

    final navKey = ref.read(navigatorKeyProvider);
    final navigator = navKey.currentState;
    if (navigator == null) return;

    navigator.push(
      MaterialPageRoute(
        builder: (_) => CallScreen(
          callId: action.callId,
          remoteUserId: action.fromUserId,
          remoteUserName: action.fromName ?? 'Unknown',
          callType: action.callType,
          isIncoming: true,
          isGroup: action.isGroup,
        ),
      ),
    );
  }

  void _rejectFromNotification(NotificationAction action) {
    final webrtc = ref.read(webRTCServiceProvider);
    webrtc.rejectCall(action.callId, action.fromUserId);
  }

  void _showIncomingCallDialog(IncomingCallEvent event) {
    final navKey = ref.read(navigatorKeyProvider);
    final navigator = navKey.currentState;
    if (navigator == null) return;

    final title = event.isGroup
        ? 'Group ${event.callType} call'
        : 'Incoming ${event.callType} call';
    final from = event.isGroup
        ? '${event.fromName} is calling in ${event.chatName ?? 'group'}'
        : '${event.fromName} is calling...';

    _activeDialogRoute = DialogRoute<void>(
      context: navigator.context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(from),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _activeDialogRoute = null;
              final webrtc = ref.read(webRTCServiceProvider);
              webrtc.acceptCall(
                event.callId,
                event.fromUserId,
                callType: event.callType,
                isGroup: event.isGroup,
              );
              navigator.push(
                MaterialPageRoute(
                  builder: (_) => CallScreen(
                    callId: event.callId,
                    remoteUserId: event.fromUserId,
                    remoteUserName: event.fromName,
                    callType: event.callType,
                    isIncoming: true,
                    isGroup: event.isGroup,
                  ),
                ),
              );
            },
            child: const Text('Accept'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              final webrtc = ref.read(webRTCServiceProvider);
              webrtc.rejectCall(event.callId, event.fromUserId);
              _activeDialogRoute = null;
              Navigator.pop(ctx);
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    navigator.push<void>(_activeDialogRoute!);
  }

  void _closeActiveDialog() {
    if (_activeDialogRoute == null) return;
    final navKey = ref.read(navigatorKeyProvider);
    final navigator = navKey.currentState;
    if (navigator == null) return;

    navigator.removeRoute(_activeDialogRoute!);
    _activeDialogRoute = null;
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
