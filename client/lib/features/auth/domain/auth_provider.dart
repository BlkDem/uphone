import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:uphone_client/core/network/api_client.dart';
import 'package:uphone_client/core/network/ws_client.dart';
import 'package:uphone_client/core/config/server_config.dart';
import 'package:uphone_client/core/notifications/notification_service.dart';
import 'package:uphone_client/shared/models/user.dart';
import 'package:uphone_client/features/auth/data/auth_repository.dart';
import 'package:uphone_client/core/config/remember_me_storage.dart';

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

final googleSignInProvider = Provider<GoogleSignIn>((ref) {
  return GoogleSignIn.instance;
});

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  final ApiClient _apiClient;
  final WsClient _wsClient;
  final GoogleSignIn _googleSignIn;
  bool _googleListenerSetup = false;

  AuthNotifier(this._repository, this._apiClient, this._wsClient, this._googleSignIn)
      : super(const AuthState()) {
    _setupGoogleListener();
  }

  void _setupGoogleListener() {
    if (_googleListenerSetup) return;
    _googleListenerSetup = true;
    _googleSignIn.authenticationEvents.listen((event) {
      if (event is GoogleSignInAuthenticationEventSignIn) {
        _handleGoogleSignInEvent(event.user);
      }
    });
  }

  Future<void> _handleGoogleSignInEvent(GoogleSignInAccount account) async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      final idToken = account.authentication.idToken;

      if (idToken == null) {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          error: 'Failed to get Google ID token',
        );
        return;
      }

      final response = await _repository.googleSignIn(idToken);
      _apiClient.setTokens(response.accessToken, response.refreshToken);
      NotificationService.instance.setAuth(response.accessToken, response.user.id);
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
      NotificationService.instance.setAuth(response.accessToken, response.user.id);
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
      NotificationService.instance.setAuth(response.accessToken, response.user.id);
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

  Future<void> googleSignIn() async {
    state = state.copyWith(status: AuthStatus.loading, error: null);
    try {
      await _googleSignIn.attemptLightweightAuthentication();
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
    NotificationService.instance.clearAuth();
    await RememberMeStorage.instance.clear();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  String _parseError(dynamic e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data.containsKey('error')) {
        return data['error'] as String;
      }
    }
    if (e is GoogleSignInException) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return 'Google sign-in was cancelled';
      }
      return e.description ?? 'Google sign-in failed';
    }
    return 'An error occurred';
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(
    ref.read(authRepositoryProvider),
    ref.read(apiClientProvider),
    ref.read(wsClientProvider),
    ref.read(googleSignInProvider),
  );
});
