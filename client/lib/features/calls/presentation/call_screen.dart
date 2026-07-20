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
  final bool isGroup;
  final List<String> participants;

  const CallScreen({
    super.key,
    this.callId,
    this.remoteUserId,
    this.remoteUserName,
    this.callType = 'video',
    this.isIncoming = false,
    this.isGroup = false,
    this.participants = const [],
  });

  @override
  ConsumerState<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends ConsumerState<CallScreen> {
  bool _isMuted = false;
  bool _isVideoOff = false;
  String _callStatus = 'Connecting...';
  StreamSubscription<MediaStream>? _localSub;
  StreamSubscription<RemoteStreamEvent>? _remoteSub;
  StreamSubscription<CallEvent>? _callEventSub;

  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};
  bool _localRendererReady = false;
  MediaStream? _pendingLocalStream;

  @override
  void initState() {
    super.initState();
    _callStatus = widget.isIncoming ? 'Incoming call...' : 'Ringing...';
    _initRenderers();
    _listenStreams();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    if (mounted) {
      setState(() {
        _localRendererReady = true;
        if (_pendingLocalStream != null) {
          _localRenderer.srcObject = _pendingLocalStream;
          _pendingLocalStream = null;
        }
      });
    }
  }

  void _listenStreams() {
    final webrtc = ref.read(webRTCServiceProvider);

    _localSub = webrtc.localStreamEvents.listen((stream) {
      if (!mounted) return;
      if (_localRendererReady) {
        setState(() => _localRenderer.srcObject = stream);
      } else {
        _pendingLocalStream = stream;
      }
    });

    _remoteSub = webrtc.remoteStreamEvents.listen((event) async {
      if (!mounted) return;

      final renderer = _remoteRenderers[event.userId];
      if (renderer != null) {
        setState(() {
          renderer.srcObject = event.stream;
          _callStatus = 'In call';
        });
      } else {
        final newRenderer = RTCVideoRenderer();
        await newRenderer.initialize();
        newRenderer.srcObject = event.stream;
        if (mounted) {
          setState(() {
            _remoteRenderers[event.userId] = newRenderer;
            _callStatus = 'In call';
          });
        }
      }
    });

    _callEventSub = webrtc.callEvents.listen((event) {
      if (!mounted) return;

      switch (event) {
        case CallAcceptedEvent():
          setState(() => _callStatus = 'In call');
          break;
        case ConferenceJoinedEvent():
          setState(() {
            _callStatus = 'In call';
          });
          break;
        case ParticipantJoinedEvent():
          break;
        case ParticipantLeftEvent():
          final renderer = _remoteRenderers.remove(event.userId);
          renderer?.dispose();
          setState(() {});
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
      webrtc.acceptCall(
        widget.callId!,
        widget.remoteUserId!,
        callType: widget.callType,
        isGroup: widget.isGroup,
      );
    }
  }

  @override
  void dispose() {
    _localSub?.cancel();
    _remoteSub?.cancel();
    _callEventSub?.cancel();
    _localRenderer.dispose();
    for (final r in _remoteRenderers.values) {
      r.dispose();
    }
    _remoteRenderers.clear();
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

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Stack(
          children: [
            _buildVideoGrid(context),
            Positioned(
              left: 0,
              right: 0,
              bottom: 40,
              child: Column(
                children: [
                  if (_remoteRenderers.isEmpty)
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

  Widget _buildVideoGrid(BuildContext context) {
    final hasLocalVideo = _localRendererReady && _localRenderer.srcObject != null;
    final remoteCount = _remoteRenderers.length;
    final hasVideo = widget.callType == 'video';

    if (!hasVideo) {
      final hasAudio = _localRenderer.srcObject != null || _remoteRenderers.isNotEmpty;
      if (!hasAudio) return _buildAvatarView(context);
      return Stack(
        children: [
          _buildAvatarView(context),
          if (_localRenderer.srcObject != null)
            Positioned(
              width: 1,
              height: 1,
              child: RTCVideoView(_localRenderer),
            ),
          for (final entry in _remoteRenderers.entries)
            Positioned(
              width: 1,
              height: 1,
              child: RTCVideoView(entry.value),
            ),
        ],
      );
    }

    if (remoteCount == 0) {
      if (hasLocalVideo) {
        return Stack(
          children: [
            Positioned.fill(
              child: RTCVideoView(
                _localRenderer,
                mirror: true,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            ),
          ],
        );
      }
      return _buildAvatarView(context);
    }

    if (remoteCount == 1) {
      final entry = _remoteRenderers.entries.first;
      return Stack(
        children: [
          Positioned.fill(
            child: RTCVideoView(
              entry.value,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
          ),
          if (hasLocalVideo)
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
        ],
      );
    }

    final columns = remoteCount <= 2 ? 1 : 2;
    final rows = ((remoteCount + 1) / columns).ceil();

    return Column(
      children: [
        Expanded(
          flex: rows,
          child: Wrap(
            children: [
              for (final entry in _remoteRenderers.entries)
                SizedBox(
                  width: (MediaQuery.of(context).size.width / columns),
                  height: (MediaQuery.of(context).size.height * 0.6 / rows),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: RTCVideoView(
                          entry.value,
                          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        ),
                      ),
                      Positioned(
                        left: 8,
                        bottom: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            entry.key.substring(0, entry.key.length.clamp(0, 8)),
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (hasLocalVideo)
          SizedBox(
            height: 160,
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 120,
                    height: 160,
                    child: RTCVideoView(
                      _localRenderer,
                      mirror: true,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
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
              (widget.remoteUserName?.isNotEmpty == true ? widget.remoteUserName! : 'U')[0].toUpperCase(),
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
