import 'package:dio/dio.dart';
import 'package:uphone_client/shared/models/user.dart';

class AdminRepository {
  final Dio _dio;

  AdminRepository(this._dio);

  Future<List<User>> listUsers() async {
    final response = await _dio.get('/api/v1/admin/users');
    final data = response.data;
    final list = data is List ? data : data['value'] as List? ?? [];
    return list.map((j) => User.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<User> createUser({
    required String username,
    required String email,
    required String password,
    String displayName = '',
    String role = 'user',
  }) async {
    final response = await _dio.post('/api/v1/admin/users', data: {
      'username': username,
      'email': email,
      'password': password,
      'display_name': displayName,
      'role': role,
    });
    return User.fromJson(response.data);
  }

  Future<void> deleteUser(String userId) async {
    await _dio.delete('/api/v1/admin/users/$userId');
  }

  Future<void> changeUserRole(String userId, String role) async {
    await _dio.put('/api/v1/admin/users/$userId/role', data: {
      'role': role,
    });
  }

  Future<void> changeUserPassword(String userId, String password) async {
    await _dio.post('/api/v1/admin/users/$userId/password', data: {
      'password': password,
    });
  }

  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    await _dio.post('/api/v1/auth/change-password', data: {
      'old_password': oldPassword,
      'new_password': newPassword,
    });
  }
}
