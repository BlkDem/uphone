import 'package:flutter/material.dart';

class ChatPalette {
  final String id;
  final String name;
  final Color seedColor;
  final Color background;
  final Color ownBubble;
  final Color otherBubble;
  final Color ownText;
  final Color otherText;
  final Color quoteBackground;
  final Color readTick;

  const ChatPalette({
    required this.id,
    required this.name,
    required this.seedColor,
    required this.background,
    required this.ownBubble,
    required this.otherBubble,
    required this.ownText,
    required this.otherText,
    required this.quoteBackground,
    required this.readTick,
  });

  ChatPalette copyWith({
    String? id,
    String? name,
    Color? seedColor,
    Color? background,
    Color? ownBubble,
    Color? otherBubble,
    Color? ownText,
    Color? otherText,
    Color? quoteBackground,
    Color? readTick,
  }) {
    return ChatPalette(
      id: id ?? this.id,
      name: name ?? this.name,
      seedColor: seedColor ?? this.seedColor,
      background: background ?? this.background,
      ownBubble: ownBubble ?? this.ownBubble,
      otherBubble: otherBubble ?? this.otherBubble,
      ownText: ownText ?? this.ownText,
      otherText: otherText ?? this.otherText,
      quoteBackground: quoteBackground ?? this.quoteBackground,
      readTick: readTick ?? this.readTick,
    );
  }

  ChatPalette asCustom() => copyWith(id: 'custom', name: 'Custom');

  Map<String, int> get colorMap => {
        'seed': seedColor.toARGB32(),
        'background': background.toARGB32(),
        'own_bubble': ownBubble.toARGB32(),
        'other_bubble': otherBubble.toARGB32(),
        'own_text': ownText.toARGB32(),
        'other_text': otherText.toARGB32(),
        'quote_background': quoteBackground.toARGB32(),
        'read_tick': readTick.toARGB32(),
      };

  static ChatPalette fromColorMap(Map<String, int> colors) {
    return ChatPalette(
      id: 'custom',
      name: 'Custom',
      seedColor: Color(colors['seed'] ?? ChatPalettes.standard.seedColor.toARGB32()),
      background: Color(colors['background'] ?? ChatPalettes.standard.background.toARGB32()),
      ownBubble: Color(colors['own_bubble'] ?? ChatPalettes.standard.ownBubble.toARGB32()),
      otherBubble: Color(colors['other_bubble'] ?? ChatPalettes.standard.otherBubble.toARGB32()),
      ownText: Color(colors['own_text'] ?? ChatPalettes.standard.ownText.toARGB32()),
      otherText: Color(colors['other_text'] ?? ChatPalettes.standard.otherText.toARGB32()),
      quoteBackground: Color(colors['quote_background'] ?? ChatPalettes.standard.quoteBackground.toARGB32()),
      readTick: Color(colors['read_tick'] ?? ChatPalettes.standard.readTick.toARGB32()),
    );
  }
}

class ChatPaletteTheme extends ThemeExtension<ChatPaletteTheme> {
  final Color quoteBackground;
  final Color readTick;

  const ChatPaletteTheme({
    required this.quoteBackground,
    required this.readTick,
  });

  @override
  ChatPaletteTheme copyWith({Color? quoteBackground, Color? readTick}) {
    return ChatPaletteTheme(
      quoteBackground: quoteBackground ?? this.quoteBackground,
      readTick: readTick ?? this.readTick,
    );
  }

  @override
  ChatPaletteTheme lerp(covariant ChatPaletteTheme? other, double t) {
    if (other == null) return this;
    return ChatPaletteTheme(
      quoteBackground: Color.lerp(quoteBackground, other.quoteBackground, t)!,
      readTick: Color.lerp(readTick, other.readTick, t)!,
    );
  }
}

class ChatPalettes {
  static const standard = ChatPalette(
    id: 'standard',
    name: 'Default',
    seedColor: Color(0xFF6750A4),
    background: Color(0xFFF7F5FA),
    ownBubble: Color(0xFFE8DEF8),
    otherBubble: Color(0xFFF0ECF4),
    ownText: Color(0xFF1D1B20),
    otherText: Color(0xFF1D1B20),
    quoteBackground: Color(0xFFDDD6E8),
    readTick: Color(0xFF6750A4),
  );

  static const telegram = ChatPalette(
    id: 'telegram',
    name: 'Telegram',
    seedColor: Color(0xFF3390EC),
    background: Color(0xFFDCE6F0),
    ownBubble: Color(0xFFEFFDDE),
    otherBubble: Color(0xFFFFFFFF),
    ownText: Color(0xFF0F0F0F),
    otherText: Color(0xFF0F0F0F),
    quoteBackground: Color(0xFFE3E9F0),
    readTick: Color(0xFF4EA7FF),
  );

  static const whatsapp = ChatPalette(
    id: 'whatsapp',
    name: 'WhatsApp',
    seedColor: Color(0xFF00A884),
    background: Color(0xFFECE5DD),
    ownBubble: Color(0xFFD9FDD3),
    otherBubble: Color(0xFFFFFFFF),
    ownText: Color(0xFF111B21),
    otherText: Color(0xFF111B21),
    quoteBackground: Color(0xFFEFE8DE),
    readTick: Color(0xFF34B7F1),
  );

  static const ocean = ChatPalette(
    id: 'ocean',
    name: 'Ocean',
    seedColor: Color(0xFF1565C0),
    background: Color(0xFFE3F2FD),
    ownBubble: Color(0xFF90CAF9),
    otherBubble: Color(0xFFBBDEFB),
    ownText: Color(0xFF0D1B3E),
    otherText: Color(0xFF0D1B3E),
    quoteBackground: Color(0xFFB0D0F2),
    readTick: Color(0xFF1565C0),
  );

  static const coral = ChatPalette(
    id: 'coral',
    name: 'Coral',
    seedColor: Color(0xFFE64A19),
    background: Color(0xFFFBE9E7),
    ownBubble: Color(0xFFFFCCBC),
    otherBubble: Color(0xFFFFF3EE),
    ownText: Color(0xFF3E2723),
    otherText: Color(0xFF3E2723),
    quoteBackground: Color(0xFFF0BBA8),
    readTick: Color(0xFFE64A19),
  );

  static const berry = ChatPalette(
    id: 'berry',
    name: 'Berry',
    seedColor: Color(0xFFAD1457),
    background: Color(0xFFFCE4EC),
    ownBubble: Color(0xFFF8BBD0),
    otherBubble: Color(0xFFFDE7EF),
    ownText: Color(0xFF3F0020),
    otherText: Color(0xFF3F0020),
    quoteBackground: Color(0xFFEEC7D4),
    readTick: Color(0xFFE91E63),
  );

  static const forest = ChatPalette(
    id: 'forest',
    name: 'Forest',
    seedColor: Color(0xFF2E7D32),
    background: Color(0xFFE8F5E9),
    ownBubble: Color(0xFFA5D6A7),
    otherBubble: Color(0xFFC8E6C9),
    ownText: Color(0xFF103118),
    otherText: Color(0xFF103118),
    quoteBackground: Color(0xFFB7D8B9),
    readTick: Color(0xFF2E7D32),
  );

  static const night = ChatPalette(
    id: 'night',
    name: 'Night',
    seedColor: Color(0xFFBB86FC),
    background: Color(0xFF121212),
    ownBubble: Color(0xFF2A2A3C),
    otherBubble: Color(0xFF1E1E28),
    ownText: Color(0xFFF2F2F7),
    otherText: Color(0xFFE6E6EE),
    quoteBackground: Color(0xFF34344A),
    readTick: Color(0xFFBB86FC),
  );

  static const all = [
    standard,
    telegram,
    whatsapp,
    ocean,
    coral,
    berry,
    forest,
    night,
  ];

  static ChatPalette? byId(String id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }
}
