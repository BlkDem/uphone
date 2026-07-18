import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uphone_client/features/calls/domain/call_provider.dart';
import 'package:uphone_client/features/calls/domain/webrtc_service.dart';

class CallScreen extends ConsumerStatefulWidget {
  final String? callId;
  final String? remoteUserId;
  final String? remoteUserName;
  final String callType;
  final bool isIncoming;

  const CallScreen({
    super.key,
    this.callId,
    this.remoteUserId,
    this.remoteUserName,
    this.callType = 'video',
    this.isIncoming = false,
  });

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  bool _isMuted = false;
  bool _isVideoOff = false;
  String _callStatus = 'Connecting...';
  StreamSubscription<MediaStream>? _localSub;
  StreamSubscription<MediaStream>? _remoteSub;
  StreamSubscription<CallEvent>? _callEventSub;

  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _localRendererReady = false;
  bool _remoteRendererReady = false;

  @override
  void initState() {
    super.initState();
    _callStatus = widget.isIncoming ? 'Incoming call...' : 'Ringing...';
    _listenStreams();
    _initRenderers();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    if (mounted) {
      setState(() {
        _localRendererReady = true;
        _remoteRendererReady = true;
      });
    }
  }

  void _listenStreams() {
    final webrtc = ref.read(webRTCServiceProvider);

    _localSub = webrtc.localStreamEvents.listen((stream) {
      if (mounted) {
        setState(() => _localRenderer.srcObject = stream);
      }
    });

    _remoteSub = webrtc.remoteStream.listen((stream) {
      if (mounted) {
        setState(() {
          _remoteRenderer.srcObject = stream;
          _callStatus = 'In call';
        });
      }
    });

    _callEventSub = webrtc.callEvents.listen((event) {
      if (!mounted) return;

      switch (event) {
        case CallAcceptedEvent():
          setState(() => _callStatus = 'In call');
          break;
        case CallRejectedEvent():
          setState(() => _callStatus = 'Call rejected');
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) Navigator.of(context).pop();
          });
          break;
        case CallEndedEvent():
          setState(() => _callStatus = 'Call ended');
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) Navigator.of(context).pop();
          });
          break;
        default:
          break;
      }
    });

    if (widget.isIncoming && widget.callId != null && widget.remoteUserId != null) {
      webrtc.acceptCall(widget.callId!, widget.remoteUserId!, callType: widget.callType);
    }
  }

  @override
  void dispose() {
    _localSub?.cancel();
    _remoteSub?.cancel();
    _callEventSub?.cancel();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  void _endCall() {
    ref.read(webRTCServiceProvider).endCall();
    Navigator.of(context).pop();
  }

  void _toggleMute() {
    ref.read(webRTCServiceProvider).toggleMute();
    setState(() => _isMuted = !_isMuted);
  }

  void _toggleCamera() {
    ref.read(webRTCServiceProvider).toggleCamera();
    setState(() => _isVideoOff = !_isVideoOff);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasRemoteVideo = _remoteRendererReady && _remoteRenderer.srcObject != null;
    final hasLocalVideo = _localRendererReady && _localRenderer.srcObject != null;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Stack(
          children: [
            if (hasRemoteVideo && widget.callType == 'video')
              Positioned.fill(
                child: RTCVideoView(
                  _remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              )
            else
              _buildAvatarView(context),

            if (hasLocalVideo && widget.callType == 'video')
              Positioned(
                right: 16,
                top: 16,
                width: 120,
                height: 160,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: RTCVideoView(
                    _localRenderer,
                    mirror: true,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              ),

            Positioned(
              left: 0,
              right: 0,
              bottom: 40,
              child: Column(
                children: [
                  if (!hasRemoteVideo || widget.callType != 'video')
                    Text(
                      _callStatus,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  const SizedBox(height: 24),
                  _buildControlButtons(context),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: FloatingActionButton(
                      onPressed: _endCall,
                      backgroundColor: Colors.red,
                      child: const Icon(Icons.call_end, size: 36, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarView(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: colorScheme.primaryContainer,
            child: Text(
              (widget.remoteUserName ?? 'U')[0].toUpperCase(),
              style: TextStyle(
                fontSize: 48,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            widget.remoteUserName ?? 'Unknown',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButtons(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _ControlButton(
          icon: _isMuted ? Icons.mic_off : Icons.mic,
          label: _isMuted ? 'Unmute' : 'Mute',
          onTap: _toggleMute,
          color: _isMuted ? colorScheme.error : colorScheme.onSurface,
        ),
        const SizedBox(width: 32),
        if (widget.callType == 'video')
          _ControlButton(
            icon: _isVideoOff ? Icons.videocam_off : Icons.videocam,
            label: _isVideoOff ? 'Camera On' : 'Camera Off',
            onTap: _toggleCamera,
            color: _isVideoOff ? colorScheme.error : colorScheme.onSurface,
          ),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
