import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _listen();
    });
  }

  void _listen() {
    final webrtc = ref.read(webRTCServiceProvider);
    webrtc.init();
    _sub = webrtc.callEvents.listen((event) {
      if (event is IncomingCallEvent && mounted) {
        _showIncomingCallDialog(event);
      }
    });
  }

  void _showIncomingCallDialog(IncomingCallEvent event) {
    final navKey = ref.read(navigatorKeyProvider);
    final navigator = navKey.currentState;
    if (navigator == null) return;

    navigator.push<void>(
      DialogRoute(
        context: navigator.context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text('Incoming ${event.callType} call'),
          content: Text('${event.fromName} is calling...'),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                navigator.push(
                  MaterialPageRoute(
                    builder: (_) => CallScreen(
                      callId: event.callId,
                      remoteUserId: event.fromUserId,
                      remoteUserName: event.fromName,
                      callType: event.callType,
                      isIncoming: true,
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
                Navigator.pop(ctx);
              },
              child: const Text('Reject'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
