import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uphone_client/core/config/app_settings.dart';
import 'package:uphone_client/core/theme/app_fonts.dart';
import 'package:uphone_client/core/theme/chat_background.dart';
import 'package:uphone_client/core/theme/chat_palette.dart';

final themeModeProvider = StateProvider<ThemeMode>((ref) => AppSettings.instance.themeMode);
final chatFontSizeProvider = StateProvider<double>((ref) => AppSettings.instance.chatFontSize);
final chatPaletteProvider = StateProvider<ChatPalette>((ref) => AppSettings.instance.chatPalette);
final chatBackgroundProvider = StateProvider<ChatBackground>((ref) => AppSettings.instance.chatBackground);
final fontProvider = StateProvider<AppFont>((ref) => AppFonts.byId(AppSettings.instance.fontFamilyId));
