import 'package:flutter_test/flutter_test.dart';
import 'package:uphone_client/features/calls/domain/webrtc_service.dart';

void main() {
  group('CallEvent', () {
    test('IncomingCallEvent contains all fields', () {
      const event = IncomingCallEvent(
        callId: 'call-123',
        fromUserId: 'user-1',
        fromName: 'Alice',
        callType: 'video',
      );

      expect(event.callId, 'call-123');
      expect(event.fromUserId, 'user-1');
      expect(event.fromName, 'Alice');
      expect(event.callType, 'video');
    });

    test('CallAcceptedEvent contains callId', () {
      const event = CallAcceptedEvent(callId: 'call-456');
      expect(event.callId, 'call-456');
    });

    test('CallRejectedEvent contains callId', () {
      const event = CallRejectedEvent(callId: 'call-789');
      expect(event.callId, 'call-789');
    });

    test('CallEndedEvent contains callId', () {
      const event = CallEndedEvent(callId: 'call-000');
      expect(event.callId, 'call-000');
    });

    test('OfferReceivedEvent contains sdp', () {
      const event = OfferReceivedEvent(
        callId: 'call-111',
        sdp: 'v=0\r\no=- 1234 1234 IN IP4 0.0.0.0\r\n',
      );
      expect(event.sdp, contains('v=0'));
    });

    test('AnswerReceivedEvent contains sdp', () {
      const event = AnswerReceivedEvent(
        callId: 'call-222',
        sdp: 'v=0\r\no=- 5678 5678 IN IP4 0.0.0.0\r\n',
      );
      expect(event.sdp, contains('v=0'));
    });

    test('ICECandidateReceivedEvent contains candidate info', () {
      const event = ICECandidateReceivedEvent(
        callId: 'call-333',
        candidate: 'candidate:1 1 UDP 2130706431 192.168.1.1 12345 typ host',
        sdpMid: '0',
        sdpMLineIndex: 0,
      );
      expect(event.candidate, contains('candidate:'));
      expect(event.sdpMid, '0');
      expect(event.sdpMLineIndex, 0);
    });
  });
}
