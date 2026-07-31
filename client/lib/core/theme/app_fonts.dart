import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppFont {
  final String id;
  final String name;
  final TextTheme Function(TextTheme base) apply;

  const AppFont({
    required this.id,
    required this.name,
    required this.apply,
  });
}

class AppFonts {
  static final inter = AppFont(
    id: 'inter',
    name: 'Inter',
    apply: GoogleFonts.interTextTheme,
  );

  static final roboto = AppFont(
    id: 'roboto',
    name: 'Roboto',
    apply: GoogleFonts.robotoTextTheme,
  );

  static final lora = AppFont(
    id: 'lora',
    name: 'Lora',
    apply: GoogleFonts.loraTextTheme,
  );

  static final jetBrainsMono = AppFont(
    id: 'jetbrains_mono',
    name: 'JetBrains Mono',
    apply: GoogleFonts.jetBrainsMonoTextTheme,
  );

  static final montserrat = AppFont(
    id: 'montserrat',
    name: 'Montserrat',
    apply: GoogleFonts.montserratTextTheme,
  );

  static final caveat = AppFont(
    id: 'caveat',
    name: 'Caveat',
    apply: GoogleFonts.caveatTextTheme,
  );

  static final all = [inter, roboto, lora, jetBrainsMono, montserrat, caveat];

  static AppFont byId(String id) {
    for (final f in all) {
      if (f.id == id) return f;
    }
    return inter;
  }
}
