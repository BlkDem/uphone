import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:uphone_client/core/network/api_client.dart';
import 'package:uphone_client/core/network/ws_client.dart';
import 'package:uphone_client/core/config/server_config.dart';
import 'package:uphone_client/shared/models/user.dart';
import 'package:uphone_client/features/auth/data/auth_repository.dart';

enum AuthStatus { initial, authenticated, unauthenticated, loading }

class AuthState {
  final AuthStatus status;
  final User? user;
  final String? error;

  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.error,
  });

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? error,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error,
    );
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ServerConfig.instance.apiBaseUrl);
});

final wsClientProvider = Provider<WsClient>((ref) {
  return WsClient();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.read(apiClientProvider).dio);
});

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  final ApiClient _apiClient;
  final WsClient _wsClient;

  AuthNotifier(this._repository, this._apiClient, this._wsClient)
      : super(const AuthState());

  Future<void> register({
    required String username,
    required String email,
    required String password,
    String displayName = '',
  }) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final response = await _repository.register(
        username: username,
        email: email,
        password: password,
        displayName: displayName,
      );
      _apiClient.setTokens(response.accessToken, response.refreshToken);
      _connectWs(response.accessToken);
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: response.user,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: _parseError(e),
      );
    }
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final response = await _repository.login(
        email: email,
        password: password,
      );
      _apiClient.setTokens(response.accessToken, response.refreshToken);
      _connectWs(response.accessToken);
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: response.user,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        error: _parseError(e),
      );
    }
  }

  void _connectWs(String accessToken) {
    _wsClient.connect(
      accessToken,
      wsUrl: ServerConfig.instance.wsUrl,
      tokenProvider: () async {
        await _apiClient.refreshAccessToken();
        return _apiClient.accessToken;
      },
    );
  }

  Future<void> logout() async {
    try {
      await _repository.logout();
    } catch (_) {}
    _wsClient.disconnect();
    _apiClient.clearTokens();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  String _parseError(dynamic e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data.containsKey('error')) {
        return data['error'] as String;
      }
    }
    return 'An error occurred';
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.read(authRepositoryProvider),
    ref.read(apiClientProvider),
    ref.read(wsClientProvider),
  );
});
