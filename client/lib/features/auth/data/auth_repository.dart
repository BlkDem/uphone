import 'package:dio/dio.dart';
import 'package:uphone_client/shared/models/user.dart';

class AuthRepository {
  final Dio _dio;

  AuthRepository(this._dio);

  Future<AuthResponse> register({
    required String username,
    required String email,
    required String password,
    String displayName = '',
  }) async {
    final response = await _dio.post('/api/v1/auth/register', data: {
      'username': username,
      'email': email,
      'password': password,
      'display_name': displayName,
    });
    return AuthResponse.fromJson(response.data);
  }

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post('/api/v1/auth/login', data: {
      'email': email,
      'password': password,
    });
    return AuthResponse.fromJson(response.data);
  }

  Future<AuthResponse> refresh(String refreshToken) async {
    final response = await _dio.post('/api/v1/auth/refresh', data: {
      'refresh_token': refreshToken,
    });
    return AuthResponse.fromJson(response.data);
  }

  Future<void> logout() async {
    await _dio.post('/api/v1/auth/logout');
  }

  Future<AuthResponse> googleSignIn(String idToken) async {
    final response = await _dio.post('/api/v1/auth/google', data: {
      'id_token': idToken,
    });
    return AuthResponse.fromJson(response.data);
  }

  Future<User> updateProfile({String? displayName, String? avatarUrl}) async {
    final data = <String, dynamic>{};
    if (displayName != null) data['display_name'] = displayName;
    if (avatarUrl != null) data['avatar_url'] = avatarUrl;
    final response = await _dio.put('/api/v1/users/me', data: data);
    return User.fromJson(response.data);
  }
}
