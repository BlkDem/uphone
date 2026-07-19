import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_config.dart';

class ServerConfig {
  static const String _key = 'uphone_servers';
  static const String _selectedKey = 'uphone_selected_server';
  static const String _defaultId = 'default';

  static final ServerConfig instance = ServerConfig._();
  ServerConfig._();

  late List<ServerEntry> _servers;
  late String _selectedId;

  List<ServerEntry> get servers => List.unmodifiable(_servers);
  ServerEntry get selected => _servers.firstWhere((s) => s.id == _selectedId);
  String get apiBaseUrl => selected.apiBaseUrl;
  String get wsUrl => selected.wsUrl;

  final ValueNotifier<ServerEntry> selectedNotifier = ValueNotifier(const ServerEntry(
    id: 'default',
    name: 'Default',
    host: 'localhost',
    port: 8080,
  ));

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      _servers = list.map((e) => ServerEntry.fromJson(e)).toList();
    } else {
      _servers = [
        ServerEntry(
          id: _defaultId,
          name: 'Default Server',
          host: AppConfig.defaultHost,
          port: AppConfig.defaultPort,
        ),
      ];
    }
    _selectedId = prefs.getString(_selectedKey) ?? _defaultId;
    if (!_servers.any((s) => s.id == _selectedId)) {
      _selectedId = _servers.first.id;
    }
    selectedNotifier.value = selected;
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_servers.map((e) => e.toJson()).toList()));
    await prefs.setString(_selectedKey, _selectedId);
    selectedNotifier.value = selected;
  }

  Future<void> select(String id) async {
    _selectedId = id;
    await _save();
  }

  Future<void> add(ServerEntry server) async {
    _servers.add(server);
    _selectedId = server.id;
    await _save();
  }

  Future<void> update(ServerEntry server) async {
    final idx = _servers.indexWhere((s) => s.id == server.id);
    if (idx >= 0) {
      _servers[idx] = server;
      await _save();
    }
  }

  Future<void> remove(String id) async {
    if (id == _defaultId) return;
    _servers.removeWhere((s) => s.id == id);
    if (_selectedId == id) {
      _selectedId = _servers.first.id;
    }
    await _save();
  }

  static String generateId() => DateTime.now().millisecondsSinceEpoch.toString();
}

@immutable
class ServerEntry {
  final String id;
  final String name;
  final String host;
  final int port;
  final bool useTls;

  const ServerEntry({
    required this.id,
    required this.name,
    required this.host,
    this.port = 8080,
    this.useTls = false,
  });

  String get apiBaseUrl => '${useTls ? "https" : "http"}://$host:$port';
  String get wsUrl => '${useTls ? "wss" : "ws"}://$host:$port/ws';

  ServerEntry copyWith({
    String? id,
    String? name,
    String? host,
    int? port,
    bool? useTls,
  }) {
    return ServerEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      host: host ?? this.host,
      port: port ?? this.port,
      useTls: useTls ?? this.useTls,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'host': host,
        'port': port,
        'useTls': useTls,
      };

  factory ServerEntry.fromJson(Map<String, dynamic> json) => ServerEntry(
        id: json['id'] as String,
        name: json['name'] as String,
        host: json['host'] as String,
        port: json['port'] as int? ?? 8080,
        useTls: json['useTls'] as bool? ?? false,
      );
}
