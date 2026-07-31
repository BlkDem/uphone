import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class ChatBackground {
  final String id;
  final String name;
  final String? assetPath;
  final Uint8List? bytes;

  const ChatBackground({
    required this.id,
    required this.name,
    this.assetPath,
    this.bytes,
  });

  bool get isNone => assetPath == null && bytes == null;
  bool get isCustom => id == 'custom';

  ChatBackground copyWith({String? id, String? name, String? assetPath, Uint8List? bytes}) {
    return ChatBackground(
      id: id ?? this.id,
      name: name ?? this.name,
      assetPath: assetPath ?? this.assetPath,
      bytes: bytes ?? this.bytes,
    );
  }
}

class ChatBackgrounds {
  static const none = ChatBackground(id: 'none', name: 'None');

  static const telegram = ChatBackground(
    id: 'telegram',
    name: 'Telegram',
    assetPath: 'assets/wallpapers/telegram.png',
  );

  static const whatsapp = ChatBackground(
    id: 'whatsapp',
    name: 'WhatsApp',
    assetPath: 'assets/wallpapers/whatsapp.png',
  );

  static const ocean = ChatBackground(
    id: 'ocean',
    name: 'Ocean',
    assetPath: 'assets/wallpapers/ocean.png',
  );

  static const coral = ChatBackground(
    id: 'coral',
    name: 'Coral',
    assetPath: 'assets/wallpapers/coral.png',
  );

  static const berry = ChatBackground(
    id: 'berry',
    name: 'Berry',
    assetPath: 'assets/wallpapers/berry.png',
  );

  static const forest = ChatBackground(
    id: 'forest',
    name: 'Forest',
    assetPath: 'assets/wallpapers/forest.png',
  );

  static const night = ChatBackground(
    id: 'night',
    name: 'Night',
    assetPath: 'assets/wallpapers/night.png',
  );

  static const presets = [
    none,
    telegram,
    whatsapp,
    ocean,
    coral,
    berry,
    forest,
    night,
  ];

  static ChatBackground? byId(String id) {
    for (final p in presets) {
      if (p.id == id) return p;
    }
    return null;
  }

  static ChatBackground custom(Uint8List bytes) =>
      ChatBackground(id: 'custom', name: 'Custom', bytes: bytes);
}

/// Downscales and re-encodes an image to keep persisted wallpapers small.
Future<Uint8List> compressWallpaperImage(Uint8List input, {int maxDim = 1400}) async {
  final codec = await ui.instantiateImageCodec(input);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final longestSide = image.width > image.height ? image.width : image.height;

  ui.Image? resized;
  if (longestSide > maxDim) {
    final scale = maxDim / longestSide;
    final w = (image.width * scale).round();
    final h = (image.height * scale).round();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint()..filterQuality = FilterQuality.medium,
    );
    resized = await recorder.endRecording().toImage(w, h);
  }

  final target = resized ?? image;
  final byteData = await target.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  resized?.dispose();
  return byteData?.buffer.asUint8List() ?? input;
}

/// Applies the wallpaper behind [child] with a subtle scrim for readability.
class ChatBackgroundView extends StatelessWidget {
  final ChatBackground background;
  final Widget child;

  const ChatBackgroundView({
    super.key,
    required this.background,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (!background.isNone) ...[
          if (background.isCustom)
            Image.memory(background.bytes!, fit: BoxFit.cover, gaplessPlayback: true)
          else
            Image.asset(background.assetPath!, fit: BoxFit.cover, gaplessPlayback: true),
          Container(color: _scrimColor(context)),
        ],
        child,
      ],
    );
  }

  Color _scrimColor(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final base = surface.computeLuminance() > 0.5 ? Colors.black : Colors.white;
    return base.withValues(alpha: 0.08);
  }
}

String encodeWallpaperBytes(Uint8List bytes) => base64Encode(bytes);

Uint8List? decodeWallpaperBytes(String value) {
  try {
    return base64Decode(value);
  } catch (_) {
    return null;
  }
}
