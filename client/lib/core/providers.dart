import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uphone_client/core/network/api_client.dart';
import 'package:uphone_client/core/network/ws_client.dart';
import 'package:uphone_client/core/config/server_config.dart';
import 'package:uphone_client/features/calls/domain/webrtc_service.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ServerConfig.instance.apiBaseUrl);
});

final wsClientProvider = Provider<WsClient>((ref) {
  return WsClient();
});

final webRTCServiceProvider = Provider<WebRTCService>((ref) {
  final wsClient = ref.read(wsClientProvider);
  return WebRTCService(wsClient);
});
