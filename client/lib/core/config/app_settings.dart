import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uphone_client/core/theme/app_fonts.dart';
import 'package:uphone_client/core/theme/chat_background.dart';
import 'package:uphone_client/core/theme/chat_palette.dart';

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

  String get fontFamilyId => _prefs.getString('font_family_id') ?? 'inter';
  set fontFamilyId(String value) => _prefs.setString('font_family_id', value);

  ChatPalette get chatPalette {
    final id = _prefs.getString('chat_palette_id') ?? 'standard';
    if (id == 'custom') {
      final colors = <String, int>{};
      for (final key in [
        'seed',
        'background',
        'own_bubble',
        'other_bubble',
        'own_text',
        'other_text',
        'quote_background',
        'read_tick',
      ]) {
        final v = _prefs.getInt('chat_custom_$key');
        if (v != null) colors[key] = v;
      }
      if (colors.isNotEmpty) {
        return ChatPalette.fromColorMap(colors);
      }
    }
    return ChatPalettes.byId(id) ?? ChatPalettes.standard;
  }

  set chatPalette(ChatPalette palette) {
    _prefs.setString('chat_palette_id', palette.id);
    if (palette.id == 'custom') {
      palette.colorMap.forEach((key, value) {
        _prefs.setInt('chat_custom_$key', value);
      });
    }
  }

  String get chatBackgroundId => _prefs.getString('chat_background_id') ?? 'none';
  set chatBackgroundId(String value) => _prefs.setString('chat_background_id', value);

  String get chatBackgroundBytesBase64 => _prefs.getString('chat_background_bytes') ?? '';
  set chatBackgroundBytesBase64(String value) => _prefs.setString('chat_background_bytes', value);

  ChatBackground get chatBackground {
    final id = chatBackgroundId;
    if (id == 'custom') {
      final encoded = chatBackgroundBytesBase64;
      if (encoded.isNotEmpty) {
        final bytes = decodeWallpaperBytes(encoded);
        if (bytes != null) return ChatBackgrounds.custom(bytes);
      }
    }
    return ChatBackgrounds.byId(id) ?? ChatBackgrounds.none;
  }

  set chatBackground(ChatBackground background) {
    chatBackgroundId = background.id;
    chatBackgroundBytesBase64 = background.isCustom && background.bytes != null
        ? encodeWallpaperBytes(background.bytes!)
        : '';
  }
}
