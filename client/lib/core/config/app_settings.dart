import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  static AppSettings? _instance;
  late SharedPreferences _prefs;

  AppSettings._();

  static Future<AppSettings> getInstance() async {
    if (_instance == null) {
      _instance = AppSettings._();
      _instance!._prefs = await SharedPreferences.getInstance();
    }
    return _instance!;
  }

  static AppSettings get instance {
    assert(_instance != null, 'AppSettings not initialized. Call getInstance() first.');
    return _instance!;
  }

  int get slideshowIntervalSeconds => _prefs.getInt('slideshow_interval') ?? 5;
  set slideshowIntervalSeconds(int value) => _prefs.setInt('slideshow_interval', value);

  bool get slideshowAutoplay => _prefs.getBool('slideshow_autoplay') ?? true;
  set slideshowAutoplay(bool value) => _prefs.setBool('slideshow_autoplay', value);

  ThemeMode get themeMode {
    final value = _prefs.getString('theme_mode') ?? 'system';
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  set themeMode(ThemeMode mode) {
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    _prefs.setString('theme_mode', value);
  }

  double get chatFontSize => _prefs.getDouble('chat_font_size') ?? 14.0;
  set chatFontSize(double value) => _prefs.setDouble('chat_font_size', value);
}
