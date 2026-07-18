import 'dart:async';

import 'package:uphone_client/core/network/ws_client.dart';

class WebRTCService {
  final WsClient _wsClient;
  
  String? _currentCallId;
  String? _remoteUserId;
  bool _isInCall = false;

  bool get isInCall => _isInCall;
  String? get currentCallId => _currentCallId;

  final StreamController<CallEvent> _callEventController =
      StreamController<CallEvent>.broadcast();
  Stream<CallEvent> get callEvents => _callEventController.stream;

  WebRTCService(this._wsClient);

  void init() {
    _wsClient.connect(
      '',
      onMessage: _handleSignal,
    );
  }

  void _handleSignal(Map<String, dynamic> message) {
    final type = message['type'] as String?;
    final callId = message['call_id'] as String?;
    final fromUser = message['from_user'] as String?;
    final payload = message['payload'];

    switch (type) {
      case 'call-request':
        if (callId != null && fromUser != null && payload is Map<String, dynamic>) {
          _currentCallId = callId;
          _remoteUserId = fromUser;
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
        }
        break;
      case 'call-reject':
        if (callId != null) {
          _isInCall = false;
          _currentCallId = null;
          _remoteUserId = null;
          _callEventController.add(CallRejectedEvent(callId: callId));
        }
        break;
      case 'call-end':
        if (callId != null) {
          _isInCall = false;
          _currentCallId = null;
          _remoteUserId = null;
          _callEventController.add(CallEndedEvent(callId: callId));
        }
        break;
      case 'offer':
        if (callId != null && payload is Map<String, dynamic>) {
          _callEventController.add(OfferReceivedEvent(
            callId: callId,
            sdp: payload['sdp'] ?? '',
          ));
        }
        break;
      case 'answer':
        if (callId != null && payload is Map<String, dynamic>) {
          _callEventController.add(AnswerReceivedEvent(
            callId: callId,
            sdp: payload['sdp'] ?? '',
          ));
        }
        break;
      case 'ice-candidate':
        if (callId != null && payload is Map<String, dynamic>) {
          _callEventController.add(ICECandidateReceivedEvent(
            callId: callId,
            candidate: payload['candidate'] ?? '',
            sdpMid: payload['sdpMid'] ?? '',
            sdpMLineIndex: payload['sdpMLineIndex'] ?? 0,
          ));
        }
        break;
    }
  }

  String _generateCallId() {
    return 'call-${DateTime.now().millisecondsSinceEpoch}';
  }

  void startCall(String toUserId, String callType, {String chatId = ''}) {
    final callId = _generateCallId();
    _currentCallId = callId;
    _remoteUserId = toUserId;

    _wsClient.send({
      'type': 'call-request',
      'call_id': callId,
      'to_user': toUserId,
      'payload': {
        'call_type': callType,
        'chat_id': chatId,
      },
    });
  }

  void acceptCall(String callId, String toUserId) {
    _currentCallId = callId;
    _remoteUserId = toUserId;
    _isInCall = true;

    _wsClient.send({
      'type': 'call-accept',
      'call_id': callId,
      'to_user': toUserId,
    });
  }

  void rejectCall(String callId, String toUserId) {
    _wsClient.send({
      'type': 'call-reject',
      'call_id': callId,
      'to_user': toUserId,
    });
  }

  void endCall() {
    if (_currentCallId != null && _remoteUserId != null) {
      _wsClient.send({
        'type': 'call-end',
        'call_id': _currentCallId,
        'to_user': _remoteUserId,
      });
    }
    _isInCall = false;
    _currentCallId = null;
    _remoteUserId = null;
  }

  void sendOffer(String callId, String toUserId, String sdp) {
    _wsClient.send({
      'type': 'offer',
      'call_id': callId,
      'to_user': toUserId,
      'payload': {'sdp': sdp},
    });
  }

  void sendAnswer(String callId, String toUserId, String sdp) {
    _wsClient.send({
      'type': 'answer',
      'call_id': callId,
      'to_user': toUserId,
      'payload': {'sdp': sdp},
    });
  }

  void sendICECandidate(String callId, String toUserId, String candidate,
      String sdpMid, int sdpMLineIndex) {
    _wsClient.send({
      'type': 'ice-candidate',
      'call_id': callId,
      'to_user': toUserId,
      'payload': {
        'candidate': candidate,
        'sdpMid': sdpMid,
        'sdpMLineIndex': sdpMLineIndex,
      },
    });
  }

  void dispose() {
    _callEventController.close();
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
