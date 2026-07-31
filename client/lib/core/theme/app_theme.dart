import 'package:flutter/material.dart';
import 'package:uphone_client/core/theme/app_fonts.dart';
import 'package:uphone_client/core/theme/chat_palette.dart';

class AppTheme {
  static ThemeData light({ChatPalette? palette, AppFont? font}) {
    final colorScheme = _scheme(Brightness.light, palette);
    return _buildTheme(colorScheme, palette, font);
  }

  static ThemeData dark({ChatPalette? palette, AppFont? font}) {
    final colorScheme = _scheme(Brightness.dark, palette);
    return _buildTheme(colorScheme, palette, font);
  }

  static ColorScheme _scheme(Brightness brightness, ChatPalette? palette) {
    final p = palette ?? ChatPalettes.standard;
    return ColorScheme.fromSeed(
      seedColor: p.seedColor,
      brightness: brightness,
    ).copyWith(
      surface: p.background,
      surfaceContainerLowest: p.background,
      surfaceContainerLow: p.background,
      surfaceContainer: p.background,
      surfaceContainerHigh: p.background,
      surfaceContainerHighest: p.otherBubble,
      primaryContainer: p.ownBubble,
      onPrimaryContainer: p.ownText,
      onSurface: p.otherText,
      onSurfaceVariant: p.otherText.withValues(alpha: 0.7),
    );
  }

  static ThemeData _buildTheme(ColorScheme colorScheme, ChatPalette? palette, AppFont? font) {
    final p = palette ?? ChatPalettes.standard;
    final textTheme = (font ?? AppFonts.inter).apply(
      ThemeData(colorScheme: colorScheme).textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: p.background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          textStyle: textTheme.titleSmall,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        color: colorScheme.surface,
      ),
      extensions: [
        ChatPaletteTheme(
          quoteBackground: p.quoteBackground,
          readTick: p.readTick,
        ),
      ],
    );
  }
}
