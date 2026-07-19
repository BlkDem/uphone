import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uphone_client/core/network/api_client.dart';
import 'package:uphone_client/features/admin/data/admin_repository.dart';
import 'package:uphone_client/features/auth/domain/auth_provider.dart';
import 'package:uphone_client/shared/models/user.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(ref.read(apiClientProvider).dio);
});

class AdminState {
  final List<User> users;
  final bool isLoading;
  final String? error;

  const AdminState({
    this.users = const [],
    this.isLoading = false,
    this.error,
  });

  AdminState copyWith({
    List<User>? users,
    bool? isLoading,
    String? error,
  }) {
    return AdminState(
      users: users ?? this.users,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AdminNotifier extends StateNotifier<AdminState> {
  final AdminRepository _repository;

  AdminNotifier(this._repository) : super(const AdminState());

  Future<void> loadUsers() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final users = await _repository.listUsers();
      state = state.copyWith(users: users, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load users');
    }
  }

  Future<bool> createUser({
    required String username,
    required String email,
    required String password,
    String displayName = '',
    String role = 'user',
  }) async {
    try {
      await _repository.createUser(
        username: username,
        email: email,
        password: password,
        displayName: displayName,
        role: role,
      );
      await loadUsers();
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to create user');
      return false;
    }
  }

  Future<bool> deleteUser(String userId) async {
    try {
      await _repository.deleteUser(userId);
      await loadUsers();
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete user');
      return false;
    }
  }

  Future<bool> changeUserRole(String userId, String role) async {
    try {
      await _repository.changeUserRole(userId, role);
      await loadUsers();
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to change role');
      return false;
    }
  }

  Future<bool> changeUserPassword(String userId, String password) async {
    try {
      await _repository.changeUserPassword(userId, password);
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to change password');
      return false;
    }
  }

  Future<bool> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      await _repository.changePassword(
        oldPassword: oldPassword,
        newPassword: newPassword,
      );
      return true;
    } catch (e) {
      state = state.copyWith(error: 'Failed to change password');
      return false;
    }
  }
}

final adminProvider = StateNotifierProvider<AdminNotifier, AdminState>((ref) {
  return AdminNotifier(ref.read(adminRepositoryProvider));
});
