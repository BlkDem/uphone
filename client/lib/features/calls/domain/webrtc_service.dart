import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:uphone_client/core/network/ws_client.dart';

class WebRTCService {
  final WsClient _wsClient;

  final Map<String, RTCPeerConnection> _peerConnections = {};
  final Map<String, MediaStream> _remoteStreams = {};
  MediaStream? _localStream;
  String? _currentCallId;
  bool _isInCall = false;
  bool _isAccepted = false;
  String? _chatId;
  bool _isGroupCall = false;

  bool get isInCall => _isInCall;
  String? get currentCallId => _currentCallId;
  MediaStream? get localStream => _localStream;
  bool get isGroupCall => _isGroupCall;
  String? get chatId => _chatId;
  Map<String, MediaStream> get remoteStreams => Map.unmodifiable(_remoteStreams);

  final StreamController<CallEvent> _callEventController =
      StreamController<CallEvent>.broadcast();
  Stream<CallEvent> get callEvents => _callEventController.stream;

  final StreamController<MediaStream> _localStreamController =
      StreamController<MediaStream>.broadcast();
  Stream<MediaStream> get localStreamEvents => _localStreamController.stream;

  final StreamController<RemoteStreamEvent> _remoteStreamController =
      StreamController<RemoteStreamEvent>.broadcast();
  Stream<RemoteStreamEvent> get remoteStreamEvents => _remoteStreamController.stream;

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

    print('>>> WebRTC _handleSignal: type=$type from=$fromUser callId=$callId');

    switch (type) {
      case 'call-request':
      case 'call-invite':
        break;

      case 'call-join':
        if (callId != null && payload is Map<String, dynamic>) {
          final participants = (payload['participants'] as List<dynamic>?)
                  ?.map((e) => e as String)
                  .toList() ??
              [];
          _handleJoinConference(callId, participants);
        }
        break;

      case 'participant-joined':
        if (callId != null && fromUser != null && payload is Map<String, dynamic>) {
          final userId = payload['user_id'] as String?;
          if (userId != null) {
            _handleParticipantJoined(callId, userId);
          }
        }
        break;

      case 'participant-left':
        if (callId != null && payload is Map<String, dynamic>) {
          final userId = payload['user_id'] as String?;
          if (userId != null) {
            _handleParticipantLeft(userId);
          }
        }
        break;

      case 'call-accept':
        if (callId != null) {
          _isInCall = true;
          _callEventController.add(CallAcceptedEvent(callId: callId));
          _createOfferForPeer(callId, message['from_user'] as String? ?? '');
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
        if (callId != null && fromUser != null && payload is Map<String, dynamic>) {
          final sdp = payload['sdp'] as String?;
          if (sdp != null) {
            _handleOffer(callId, fromUser, sdp);
          }
        }
        break;

      case 'answer':
        if (callId != null && fromUser != null && payload is Map<String, dynamic>) {
          final sdp = payload['sdp'] as String?;
          if (sdp != null) {
            _handleAnswer(fromUser, sdp);
          }
        }
        break;

      case 'ice-candidate':
        if (callId != null && fromUser != null && payload is Map<String, dynamic>) {
          final candidate = payload['candidate'] as String?;
          final sdpMid = payload['sdpMid'] as String?;
          final sdpMLineIndex = payload['sdpMLineIndex'] as int?;
          if (candidate != null && sdpMid != null && sdpMLineIndex != null) {
            _handleIceCandidate(fromUser, candidate, sdpMid, sdpMLineIndex);
          }
        }
        break;
    }
  }

  Future<void> startCall(String toUserId, String callType, {String chatId = ''}) async {
    _isGroupCall = false;
    _chatId = chatId;
    final callId = 'call-${DateTime.now().millisecondsSinceEpoch}';
    _currentCallId = callId;

    try {
      await _initMedia(callType);
      await _createPeerConnection(toUserId);
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

  Future<void> startGroupCall(
    String callType,
    String chatId, {
    required List<String> participants,
    String fromName = '',
  }) async {
    _isGroupCall = true;
    _chatId = chatId;
    final callId = 'call-${DateTime.now().millisecondsSinceEpoch}';
    _currentCallId = callId;

    try {
      await _initMedia(callType);
    } catch (e) {
      debugPrint('Failed to init media for group call: $e');
      _cleanup();
      rethrow;
    }

    _isInCall = true;
    _callEventController.add(CallAcceptedEvent(callId: callId));

    _wsClient.send({
      'type': 'call-request',
      'call_id': callId,
      'payload': {
        'call_type': callType,
        'chat_id': chatId,
        'from_name': fromName,
        'participants': participants,
      },
    });
  }

  Future<void> acceptCall(String callId, String fromUserId,
      {String callType = 'video', bool isGroup = false}) async {
    if (_isAccepted) return;

    _currentCallId = callId;
    _isGroupCall = isGroup;

    try {
      await _initMedia(callType);
    } catch (e) {
      debugPrint('Failed to init media for accept: $e');
      rejectCall(callId, fromUserId);
      rethrow;
    }

    _isAccepted = true;
    _isInCall = true;

    if (!isGroup) {
      await _createPeerConnection(fromUserId);
      _wsClient.send({
        'type': 'call-accept',
        'call_id': callId,
        'to_user': fromUserId,
      });
    } else {
      _wsClient.send({
        'type': 'call-join',
        'call_id': callId,
      });
    }
  }

  void joinCall(String callId) {
    _currentCallId = callId;
    _isGroupCall = true;
    _wsClient.send({
      'type': 'call-join',
      'call_id': callId,
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
    final callId = _currentCallId ?? '';
    try {
      if (_currentCallId != null) {
        if (_isGroupCall) {
          _wsClient.send({
            'type': 'call-leave',
            'call_id': _currentCallId,
          });
        } else {
          _wsClient.send({
            'type': 'call-end',
            'call_id': _currentCallId,
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to send end call signal: $e');
    }
    try {
      _cleanup();
    } catch (e) {
      debugPrint('Failed to cleanup call: $e');
    }
    _callEventController.add(CallEndedEvent(callId: callId));
  }

  void _handleJoinConference(String callId, List<String> existingParticipants) {
    _isInCall = true;
    _currentCallId = callId;

    _callEventController.add(ConferenceJoinedEvent(
      callId: callId,
      existingParticipants: existingParticipants,
    ));

    for (final participantId in existingParticipants) {
      _createPeerConnectionAndOffer(participantId);
    }
  }

  Future<void> _handleParticipantJoined(String callId, String userId) async {
    _callEventController.add(ParticipantJoinedEvent(
      callId: callId,
      userId: userId,
    ));
  }

  void _handleParticipantLeft(String userId) {
    _closePeerConnection(userId);
    _remoteStreams.remove(userId);
    _callEventController.add(ParticipantLeftEvent(callId: _currentCallId ?? '', userId: userId));
  }

  Future<void> _createPeerConnectionAndOffer(String remoteUserId) async {
    final pc = await _createPeerConnection(remoteUserId);
    final offer = await pc.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': true,
    });
    await pc.setLocalDescription(offer);

    _wsClient.send({
      'type': 'offer',
      'call_id': _currentCallId,
      'to_user': remoteUserId,
      'payload': {'sdp': offer.sdp},
    });
  }

  Future<RTCPeerConnection> _createPeerConnection(String remoteUserId) async {
    final existing = _peerConnections[remoteUserId];
    if (existing != null) return existing;

    final pc = await createPeerConnection(_iceServers);

    if (_localStream != null) {
      for (final track in _localStream!.getTracks()) {
        await pc.addTrack(track, _localStream!);
      }
    }

    pc.onIceCandidate = (RTCIceCandidate candidate) {
      _wsClient.send({
        'type': 'ice-candidate',
        'call_id': _currentCallId,
        'to_user': remoteUserId,
        'payload': {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        },
      });
    };

    pc.onTrack = (RTCTrackEvent event) {
      debugPrint('onTrack from $remoteUserId: ${event.track.kind}');
      if (event.streams.isNotEmpty) {
        final stream = event.streams.first;
        _remoteStreams[remoteUserId] = stream;
        _remoteStreamController.add(RemoteStreamEvent(
          userId: remoteUserId,
          stream: stream,
        ));
      }
    };

    pc.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint('PeerConnection[$remoteUserId] state: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected) {
        _handleParticipantLeft(remoteUserId);
      }
    };

    _peerConnections[remoteUserId] = pc;
    return pc;
  }

  Future<void> _handleOffer(String callId, String fromUserId, String sdp) async {
    final pc = await _createPeerConnection(fromUserId);

    final offer = RTCSessionDescription(sdp, 'offer');
    await pc.setRemoteDescription(offer);

    final answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);

    _wsClient.send({
      'type': 'answer',
      'call_id': callId,
      'to_user': fromUserId,
      'payload': {'sdp': answer.sdp},
    });
  }

  Future<void> _createOfferForPeer(String callId, String remoteUserId) async {
    final pc = _peerConnections[remoteUserId];
    if (pc == null) {
      await _createPeerConnectionAndOffer(remoteUserId);
      return;
    }

    final offer = await pc.createOffer({
      'offerToReceiveAudio': true,
      'offerToReceiveVideo': true,
    });
    await pc.setLocalDescription(offer);

    _wsClient.send({
      'type': 'offer',
      'call_id': callId,
      'to_user': remoteUserId,
      'payload': {'sdp': offer.sdp},
    });
  }

  Future<void> _handleAnswer(String fromUserId, String sdp) async {
    final pc = _peerConnections[fromUserId];
    if (pc == null) return;

    final answer = RTCSessionDescription(sdp, 'answer');
    await pc.setRemoteDescription(answer);
  }

  Future<void> _handleIceCandidate(
      String fromUserId, String candidate, String sdpMid, int sdpMLineIndex) async {
    final pc = _peerConnections[fromUserId];
    if (pc == null) return;

    final iceCandidate = RTCIceCandidate(candidate, sdpMid, sdpMLineIndex);
    await pc.addCandidate(iceCandidate);
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

  void _closePeerConnection(String remoteUserId) {
    final pc = _peerConnections.remove(remoteUserId);
    pc?.close();
  }

  void _cleanup() {
    _isInCall = false;
    _isAccepted = false;
    _isGroupCall = false;
    for (final pc in _peerConnections.values) {
      pc.close();
    }
    _peerConnections.clear();
    _remoteStreams.clear();
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream = null;
    _currentCallId = null;
    _chatId = null;
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
  final String? chatName;
  final bool isGroup;

  const IncomingCallEvent({
    required super.callId,
    required this.fromUserId,
    required this.fromName,
    required this.callType,
    this.chatName,
    this.isGroup = false,
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

class ConferenceJoinedEvent extends CallEvent {
  final List<String> existingParticipants;
  const ConferenceJoinedEvent({
    required super.callId,
    required this.existingParticipants,
  });
}

class ParticipantJoinedEvent extends CallEvent {
  final String userId;
  const ParticipantJoinedEvent({
    required super.callId,
    required this.userId,
  });
}

class ParticipantLeftEvent extends CallEvent {
  final String userId;
  const ParticipantLeftEvent({
    required super.callId,
    required this.userId,
  });
}

class RemoteStreamEvent {
  final String userId;
  final MediaStream stream;
  const RemoteStreamEvent({required this.userId, required this.stream});
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
