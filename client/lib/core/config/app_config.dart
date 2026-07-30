class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://up.umolab.ru',
  );

  static const String wsUrl = String.fromEnvironment(
    'WS_URL',
    defaultValue: 'wss://up.umolab.ru/ws',
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
