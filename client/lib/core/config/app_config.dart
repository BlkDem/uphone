class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8080',
  );

  static const String wsUrl = String.fromEnvironment(
    'WS_URL',
    defaultValue: 'ws://localhost:8080/ws',
  );

  static String get defaultHost {
    final uri = Uri.parse(apiBaseUrl);
    return uri.host;
  }

  static int get defaultPort {
    final uri = Uri.parse(apiBaseUrl);
    return uri.port;
  }
}
