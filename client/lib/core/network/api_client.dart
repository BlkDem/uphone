import 'package:dio/dio.dart';
import '../config/app_config.dart';

class ApiClient {
  late final Dio _dio;
  String? _accessToken;
  String? _refreshToken;

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
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
  }

  void clearTokens() {
    _accessToken = null;
    _refreshToken = null;
  }

  String? get accessToken => _accessToken;

  Future<bool> _tryRefresh() async {
    try {
      final response = await _dio.post('/api/v1/auth/refresh', data: {
        'refresh_token': _refreshToken,
      });
      final data = response.data;
      _accessToken = data['access_token'];
      _refreshToken = data['refresh_token'];
      return true;
    } catch (_) {
      clearTokens();
      return false;
    }
  }

  Dio get dio => _dio;
}
