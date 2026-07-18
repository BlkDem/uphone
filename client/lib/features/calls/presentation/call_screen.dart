import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  bool _isSpeakerOn = true;
  String _callStatus = 'Connecting...';

  @override
  void initState() {
    super.initState();
    if (!widget.isIncoming) {
      _callStatus = 'Ringing...';
    } else {
      _callStatus = 'Incoming call...';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
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
            const SizedBox(height: 8),
            Text(
              _callStatus,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const Spacer(flex: 3),
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
            const Spacer(),
          ],
        ),
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
          onTap: () => setState(() => _isMuted = !_isMuted),
          color: _isMuted ? colorScheme.error : colorScheme.onSurface,
        ),
        const SizedBox(width: 32),
        if (widget.callType == 'video')
          _ControlButton(
            icon: _isVideoOff ? Icons.videocam_off : Icons.videocam,
            label: _isVideoOff ? 'Camera On' : 'Camera Off',
            onTap: () => setState(() => _isVideoOff = !_isVideoOff),
            color: _isVideoOff ? colorScheme.error : colorScheme.onSurface,
          ),
        if (widget.callType == 'video') const SizedBox(width: 32),
        _ControlButton(
          icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_off,
          label: _isSpeakerOn ? 'Speaker' : 'Earpiece',
          onTap: () => setState(() => _isSpeakerOn = !_isSpeakerOn),
          color: _isSpeakerOn ? colorScheme.onSurface : colorScheme.error,
        ),
      ],
    );
  }

  void _endCall() {
    Navigator.of(context).pop();
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
