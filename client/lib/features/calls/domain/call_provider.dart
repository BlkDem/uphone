import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uphone_client/features/auth/domain/auth_provider.dart';
import 'package:uphone_client/features/calls/domain/webrtc_service.dart';

final webRTCServiceProvider = Provider<WebRTCService>((ref) {
  final wsClient = ref.read(wsClientProvider);
  return WebRTCService(wsClient);
});
