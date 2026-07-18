class User {
  final String id;
  final String username;
  final String email;
  final String displayName;
  final String avatarUrl;
  final String status;

  const User({
    required this.id,
    required this.username,
    required this.email,
    required this.displayName,
    this.avatarUrl = '',
    this.status = 'offline',
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      displayName: json['display_name'] ?? json['username'] ?? '',
      avatarUrl: json['avatar_url'] ?? '',
      status: json['status'] ?? 'offline',
    );
  }

  User copyWith({
    String? displayName,
    String? avatarUrl,
    String? status,
  }) {
    return User(
      id: id,
      username: username,
      email: email,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      status: status ?? this.status,
    );
  }
}

class AuthResponse {
  final String accessToken;
  final String refreshToken;
  final User user;

  const AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: json['access_token'] ?? '',
      refreshToken: json['refresh_token'] ?? '',
      user: User.fromJson(json['user'] ?? {}),
    );
  }
}
