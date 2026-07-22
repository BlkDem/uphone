import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static const _kRefreshToken = 'uphone_refresh_token';
  static const _kAccessToken = 'uphone_access_token';

  late Dio _dio;
  String? _accessToken;
  String? _refreshToken;

  ApiClient(String baseUrl) {
    _dio = Dio(BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (_accessToken != null) {
          options.headers['Authorization'] = 'Bearer $_accessToken';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        if (error.response?.statusCode == 401 && _refreshToken != null) {
          final refreshed = await _tryRefresh();
          if (refreshed) {
            error.requestOptions.headers['Authorization'] = 'Bearer $_accessToken';
            final response = await _dio.fetch(error.requestOptions);
            handler.resolve(response);
            return;
          }
        }
        handler.next(error);
      },
    ));
  }

  void setTokens(String accessToken, String refreshToken) {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _persistTokens();
  }

  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;
    await _clearPersistedTokens();
  }

  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;

  Future<void> refreshAccessToken() async {
    await _tryRefresh();
  }

  Future<bool> loadPersistedTokens() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_kAccessToken);
    _refreshToken = prefs.getString(_kRefreshToken);
    return _accessToken != null && _refreshToken != null;
  }

  Future<void> _persistTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_accessToken != null) await prefs.setString(_kAccessToken, _accessToken!);
      if (_refreshToken != null) await prefs.setString(_kRefreshToken, _refreshToken!);
    } catch (_) {}
  }

  Future<void> _clearPersistedTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kAccessToken);
      await prefs.remove(_kRefreshToken);
    } catch (_) {}
  }

  Future<bool> _tryRefresh() async {
    try {
      final response = await _dio.post('/api/v1/auth/refresh', data: {
        'refresh_token': _refreshToken,
      });
      final data = response.data;
      _accessToken = data['access_token'];
      _refreshToken = data['refresh_token'];
      _persistTokens();
      return true;
    } catch (_) {
      await clearTokens();
      return false;
    }
  }

  Dio get dio => _dio;
}
