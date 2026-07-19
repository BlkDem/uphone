import 'package:shared_preferences/shared_preferences.dart';

class RememberMeStorage {
  static const String _emailKey = 'uphone_remember_email';
  static const String _passwordKey = 'uphone_remember_password';
  static const String _enabledKey = 'uphone_remember_enabled';

  static final RememberMeStorage instance = RememberMeStorage._();
  RememberMeStorage._();

  Future<void> save(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, true);
    await prefs.setString(_emailKey, email);
    await prefs.setString(_passwordKey, password);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_enabledKey);
    await prefs.remove(_emailKey);
    await prefs.remove(_passwordKey);
  }

  Future<(String email, String password)?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_enabledKey) ?? false;
    if (!enabled) return null;
    final email = prefs.getString(_emailKey) ?? '';
    final password = prefs.getString(_passwordKey) ?? '';
    if (email.isEmpty) return null;
    return (email, password);
  }
}
