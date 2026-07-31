import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum WallpaperFill {
  cover('cover', 'Cover'),
  tile('tile', 'Tile');

  const WallpaperFill(this.id, this.label);

  final String id;
  final String label;

  static WallpaperFill byId(String id) =>
      WallpaperFill.values.firstWhere((f) => f.id == id, orElse: () => WallpaperFill.cover);
}

class ChatBackground {
  final String id;
  final String name;
  final String? assetPath;
  final String? tilePath;
  final Uint8List? bytes;

  const ChatBackground({
    required this.id,
    required this.name,
    this.assetPath,
    this.tilePath,
    this.bytes,
  });

  bool get isNone => assetPath == null && bytes == null;
  bool get isCustom => id == 'custom';

  ChatBackground copyWith({
    String? id,
    String? name,
    String? assetPath,
    String? tilePath,
    Uint8List? bytes,
  }) {
    return ChatBackground(
      id: id ?? this.id,
      name: name ?? this.name,
      assetPath: assetPath ?? this.assetPath,
      tilePath: tilePath ?? this.tilePath,
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
    tilePath: 'assets/wallpapers/tiles/telegram.png',
  );

  static const whatsapp = ChatBackground(
    id: 'whatsapp',
    name: 'WhatsApp',
    assetPath: 'assets/wallpapers/whatsapp.png',
    tilePath: 'assets/wallpapers/tiles/whatsapp.png',
  );

  static const ocean = ChatBackground(
    id: 'ocean',
    name: 'Ocean',
    assetPath: 'assets/wallpapers/ocean.png',
    tilePath: 'assets/wallpapers/tiles/ocean.png',
  );

  static const coral = ChatBackground(
    id: 'coral',
    name: 'Coral',
    assetPath: 'assets/wallpapers/coral.png',
    tilePath: 'assets/wallpapers/tiles/coral.png',
  );

  static const berry = ChatBackground(
    id: 'berry',
    name: 'Berry',
    assetPath: 'assets/wallpapers/berry.png',
    tilePath: 'assets/wallpapers/tiles/berry.png',
  );

  static const forest = ChatBackground(
    id: 'forest',
    name: 'Forest',
    assetPath: 'assets/wallpapers/forest.png',
    tilePath: 'assets/wallpapers/tiles/forest.png',
  );

  static const night = ChatBackground(
    id: 'night',
    name: 'Night',
    assetPath: 'assets/wallpapers/night.png',
    tilePath: 'assets/wallpapers/tiles/night.png',
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
  final WallpaperFill fill;

  const ChatBackgroundView({
    super.key,
    required this.background,
    required this.child,
    this.fill = WallpaperFill.cover,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (!background.isNone) ...[
          if (fill == WallpaperFill.tile)
            _TiledImage(background: background)
          else if (background.isCustom)
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
    return base.withValues(alpha: 0.12);
  }
}

class _TiledImage extends StatefulWidget {
  final ChatBackground background;

  const _TiledImage({required this.background});

  @override
  State<_TiledImage> createState() => _TiledImageState();
}

class _TiledImageState extends State<_TiledImage> {
  ui.Image? _image;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _TiledImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.background != widget.background) {
      _image?.dispose();
      _image = null;
      _load();
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) return;
    _loading = true;
    final b = widget.background;
    try {
      final bytes = b.isCustom
          ? b.bytes!
          : (await rootBundle.load(b.tilePath ?? b.assetPath!)).buffer.asUint8List();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (mounted) {
        setState(() => _image = frame.image);
      } else {
        frame.image.dispose();
      }
    } catch (_) {
      if (mounted) setState(() => _image = null);
    } finally {
      _loading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.background;
    return LayoutBuilder(
      builder: (context, constraints) {
        final img = _image;
        if (img == null) return const SizedBox.expand();
        final scale = b.tilePath != null && !b.isCustom
            ? 1.0
            : min(
                constraints.maxWidth / img.width,
                constraints.maxHeight / img.height,
              );
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _TilePainter(image: img, scale: scale),
        );
      },
    );
  }
}

class _TilePainter extends CustomPainter {
  final ui.Image image;
  final double scale;

  _TilePainter({required this.image, required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    final tileW = image.width * scale;
    final tileH = image.height * scale;
    final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final paint = Paint()..filterQuality = FilterQuality.medium;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (double y = 0; y < size.height; y += tileH) {
      for (double x = 0; x < size.width; x += tileW) {
        canvas.drawImageRect(
          image,
          src,
          Rect.fromLTWH(x, y, tileW, tileH),
          paint,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TilePainter oldDelegate) =>
      oldDelegate.image != image || oldDelegate.scale != scale;
}

String encodeWallpaperBytes(Uint8List bytes) => base64Encode(bytes);

Uint8List? decodeWallpaperBytes(String value) {
  try {
    return base64Decode(value);
  } catch (_) {
    return null;
  }
}
