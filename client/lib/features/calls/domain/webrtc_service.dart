import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uphone_client/core/network/ws_client.dart';

class WebRTCService {
  final WsClient _wsClient;

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  String? _currentCallId;
  String? _remoteUserId;
  bool _isInCall = false;
  bool _isCaller = false;

  bool get isInCall => _isInCall;
  String? get currentCallId => _currentCallId;
  MediaStream? get localStream => _localStream;

  final StreamController<CallEvent> _callEventController =
      StreamController<CallEvent>.broadcast();
  Stream<CallEvent> get callEvents => _callEventController.stream;

  final StreamController<MediaStream> _remoteStreamController =
      StreamController<MediaStream>.broadcast();
  Stream<MediaStream> get remoteStream => _remoteStreamController.stream;

  final StreamController<MediaStream> _localStreamController =
      StreamController<MediaStream>.broadcast();
  Stream<MediaStream> get localStreamEvents => _localStreamController.stream;

  static const _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ],
  };

  WebRTCService(this._wsClient);

  void init() {
    _wsClient.addHandler('webrtc', _handleSignal);
  }

  void _handleSignal(Map<String, dynamic> message) {
    final type = message['type'] as String?;
    final callId = message['call_id'] as String?;
    final fromUser = message['from_user'] as String?;
    final payload = message['payload'];

    print('>>> WebRTC _handleSignal CALLED: type=$type from=$fromUser callId=$callId');

    switch (type) {
      case 'call-request':
        if (callId != null && fromUser != null && payload is Map<String, dynamic>) {
          _currentCallId = callId;
          _remoteUserId = fromUser;
          _isCaller = false;
          _callEventController.add(IncomingCallEvent(
            callId: callId,
            fromUserId: fromUser,
            fromName: payload['from_name'] ?? 'Unknown',
            callType: payload['call_type'] ?? 'video',
          ));
        }
        break;
      case 'call-accept':
        if (callId != null) {
          _isInCall = true;
          _callEventController.add(CallAcceptedEvent(callId: callId));
          _createOffer();
        }
        break;
      case 'call-reject':
        if (callId != null) {
          _cleanup();
          _callEventController.add(CallRejectedEvent(callId: callId));
        }
        break;
      case 'call-end':
        if (callId != null) {
          _cleanup();
          _callEventController.add(CallEndedEvent(callId: callId));
        }
        break;
      case 'offer':
        if (callId != null && payload is Map<String, dynamic>) {
          final sdp = payload['sdp'] as String?;
          if (sdp != null) {
            _handleOffer(callId, sdp);
          }
        }
        break;
      case 'answer':
        if (callId != null && payload is Map<String, dynamic>) {
          final sdp = payload['sdp'] as String?;
          if (sdp != null) {
            _handleAnswer(sdp);
          }
        }
        break;
      case 'ice-candidate':
        if (callId != null && payload is Map<String, dynamic>) {
          final candidate = payload['candidate'] as String?;
          final sdpMid = payload['sdpMid'] as String?;
          final sdpMLineIndex = payload['sdpMLineIndex'] as int?;
          if (candidate != null && sdpMid != null && sdpMLineIndex != null) {
            _handleIceCandidate(candidate, sdpMid, sdpMLineIndex);
          }
        }
        break;
    }
  }

  Future<void> startCall(String toUserId, String callType, {String chatId = ''}) async {
    _isCaller = true;
    _remoteUserId = toUserId;
    final callId = 'call-${DateTime.now().millisecondsSinceEpoch}';
    _currentCallId = callId;

    try {
      await _initMedia(callType);
      await _createPeerConnection();
    } catch (e) {
      debugPrint('Failed to init media for call: $e');
      _cleanup();
      rethrow;
    }

    _wsClient.send({
      'type': 'call-request',
      'call_id': callId,
      'to_user': toUserId,
      'payload': {
        'call_type': callType,
        'chat_id': chatId,
        'from_name': '',
      },
    });
  }

  Future<void> acceptCall(String callId, String fromUserId, {String callType = 'video'}) async {
    _currentCallId = callId;
    _remoteUserId = fromUserId;
    _isCaller = false;

    try {
      await _initMedia(callType);
      await _createPeerConnection();
    } catch (e) {
      debugPrint('Failed to init media for accept: $e');
      rejectCall(callId, fromUserId);
      rethrow;
    }

    _wsClient.send({
      'type': 'call-accept',
      'call_id': callId,
      'to_user': fromUserId,
    });
  }

  void rejectCall(String callId, String toUserId) {
    _wsClient.send({
      'type': 'call-reject',
      'call_id': callId,
      'to_user': toUserId,
    });
    _cleanup();
  }

  void endCall() {
    if (_currentCallId != null && _remoteUserId != null) {
      _wsClient.send({
        'type': 'call-end',
        'call_id': _currentCallId,
        'to_user': _remoteUserId,
      });
    }
    _cleanup();
  }

  Future<void> _initMedia(String callType) async {
    try {
      final Map<String, dynamic> constraints = {
        'audio': true,
        'video': callType == 'video'
            ? {'facingMode': 'user', 'width': 640, 'height': 480}
            : false,
      };
      _localStream = await navigator.mediaDevices.getUserMedia(constraints);
      _localStreamController.add(_localStream!);
    } catch (e) {
      debugPrint('Failed to get user media: $e');
      rethrow;
    }
  }

  Future<void> _createPeerConnection() async {
    _peerConnection = await createPeerConnection(_iceServers);

    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        await _peerConnection!.addTrack(track, _localStream!);
      }
    }

    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (_remoteUserId != null && _currentCallId != null) {
        _wsClient.send({
          'type': 'ice-candidate',
          'call_id': _currentCallId,
          'to_user': _remoteUserId,
          'payload': {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
        });
      }
    };

    _peerConnection!.onTrack = (RTCTrackEvent event) {
      debugPrint('onTrack: ${event.track.kind}');
      if (event.streams.isNotEmpty) {
        _remoteStreamController.add(event.streams.first);
      }
    };

    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint('PeerConnection state: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        endCall();
      }
    };
  }

  Future<void> _createOffer() async {
    if (_peerConnection == null) return;

    final offer = await _peerConnection!.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': true,
    });
    await _peerConnection!.setLocalDescription(offer);

    if (_remoteUserId != null && _currentCallId != null) {
      _wsClient.send({
        'type': 'offer',
        'call_id': _currentCallId,
        'to_user': _remoteUserId,
        'payload': {'sdp': offer.sdp},
      });
    }
  }

  Future<void> _handleOffer(String callId, String sdp) async {
    if (_peerConnection == null) return;

    final offer = RTCSessionDescription(sdp, 'offer');
    await _peerConnection!.setRemoteDescription(offer);

    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    if (_remoteUserId != null) {
      _wsClient.send({
        'type': 'answer',
        'call_id': callId,
        'to_user': _remoteUserId,
        'payload': {'sdp': answer.sdp},
      });
    }
  }

  Future<void> _handleAnswer(String sdp) async {
    if (_peerConnection == null) return;

    final answer = RTCSessionDescription(sdp, 'answer');
    await _peerConnection!.setRemoteDescription(answer);
  }

  Future<void> _handleIceCandidate(String candidate, String sdpMid, int sdpMLineIndex) async {
    if (_peerConnection == null) return;

    final iceCandidate = RTCIceCandidate(candidate, sdpMid, sdpMLineIndex);
    await _peerConnection!.addCandidate(iceCandidate);
  }

  Future<void> toggleMute() async {
    if (_localStream != null) {
      final audioTracks = _localStream!.getAudioTracks();
      for (final track in audioTracks) {
        track.enabled = !track.enabled;
      }
    }
  }

  Future<void> toggleCamera() async {
    if (_localStream != null) {
      final videoTracks = _localStream!.getVideoTracks();
      for (final track in videoTracks) {
        track.enabled = !track.enabled;
      }
    }
  }

  void _cleanup() {
    _isInCall = false;
    _isCaller = false;
    _peerConnection?.close();
    _peerConnection = null;
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream = null;
    _currentCallId = null;
    _remoteUserId = null;
  }

  void dispose() {
    _cleanup();
    _wsClient.removeHandler('webrtc');
    _callEventController.close();
    _remoteStreamController.close();
    _localStreamController.close();
  }
}

abstract class CallEvent {
  final String callId;
  const CallEvent({required this.callId});
}

class IncomingCallEvent extends CallEvent {
  final String fromUserId;
  final String fromName;
  final String callType;

  const IncomingCallEvent({
    required super.callId,
    required this.fromUserId,
    required this.fromName,
    required this.callType,
  });
}

class CallAcceptedEvent extends CallEvent {
  const CallAcceptedEvent({required super.callId});
}

class CallRejectedEvent extends CallEvent {
  const CallRejectedEvent({required super.callId});
}

class CallEndedEvent extends CallEvent {
  const CallEndedEvent({required super.callId});
}

class OfferReceivedEvent extends CallEvent {
  final String sdp;
  const OfferReceivedEvent({required super.callId, required this.sdp});
}

class AnswerReceivedEvent extends CallEvent {
  final String sdp;
  const AnswerReceivedEvent({required super.callId, required this.sdp});
}

class ICECandidateReceivedEvent extends CallEvent {
  final String candidate;
  final String sdpMid;
  final int sdpMLineIndex;

  const ICECandidateReceivedEvent({
    required super.callId,
    required this.candidate,
    required this.sdpMid,
    required this.sdpMLineIndex,
  });
}
