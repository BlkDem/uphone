import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uphone_client/core/config/app_settings.dart';
import 'package:uphone_client/core/theme/chat_palette.dart';
import 'package:uphone_client/core/config/app_providers.dart';

class PaletteSettingsScreen extends ConsumerStatefulWidget {
  const PaletteSettingsScreen({super.key});

  @override
  ConsumerState<PaletteSettingsScreen> createState() => _PaletteSettingsScreenState();
}

class _PaletteSettingsScreenState extends ConsumerState<PaletteSettingsScreen> {
  late ChatPalette _palette;

  @override
  void initState() {
    super.initState();
    _palette = ref.read(chatPaletteProvider);
  }

  void _save(ChatPalette palette) {
    setState(() => _palette = palette);
    final custom = palette.asCustom();
    AppSettings.instance.chatPalette = custom;
    ref.read(chatPaletteProvider.notifier).state = custom;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Custom palette'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Reset to default',
            onPressed: () {
              _save(ChatPalettes.standard);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Reset to default palette')),
              );
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: _PalettePreview(palette: _palette),
          ),
          _ColorField(
            label: 'Accent color',
            color: _palette.seedColor,
            onPicked: (c) => _save(_palette.copyWith(seedColor: c)),
          ),
          _ColorField(
            label: 'Background',
            color: _palette.background,
            onPicked: (c) => _save(_palette.copyWith(background: c)),
          ),
          _ColorField(
            label: 'Own message bubble',
            color: _palette.ownBubble,
            onPicked: (c) => _save(_palette.copyWith(ownBubble: c)),
          ),
          _ColorField(
            label: 'Other message bubble',
            color: _palette.otherBubble,
            onPicked: (c) => _save(_palette.copyWith(otherBubble: c)),
          ),
          _ColorField(
            label: 'Own message text',
            color: _palette.ownText,
            onPicked: (c) => _save(_palette.copyWith(ownText: c)),
          ),
          _ColorField(
            label: 'Other message text',
            color: _palette.otherText,
            onPicked: (c) => _save(_palette.copyWith(otherText: c)),
          ),
          _ColorField(
            label: 'Quote background',
            color: _palette.quoteBackground,
            onPicked: (c) => _save(_palette.copyWith(quoteBackground: c)),
          ),
          _ColorField(
            label: 'Read ticks',
            color: _palette.readTick,
            onPicked: (c) => _save(_palette.copyWith(readTick: c)),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  static const List<Color> _pickerColors = [
    Color(0xFFE53935),
    Color(0xFFEF5350),
    Color(0xFFD81B60),
    Color(0xFFE91E63),
    Color(0xFFEC407A),
    Color(0xFF8E24AA),
    Color(0xFFAB47BC),
    Color(0xFF5E35B1),
    Color(0xFF7E57C2),
    Color(0xFF3949AB),
    Color(0xFF5C6BC0),
    Color(0xFF1E88E5),
    Color(0xFF42A5F5),
    Color(0xFF039BE5),
    Color(0xFF00ACC1),
    Color(0xFF00897B),
    Color(0xFF26A69A),
    Color(0xFF43A047),
    Color(0xFF66BB6A),
    Color(0xFF7CB342),
    Color(0xFF9CCC65),
    Color(0xFFC0CA33),
    Color(0xFFFDD835),
    Color(0xFFFFB300),
    Color(0xFFFB8C00),
    Color(0xFFFFA726),
    Color(0xFFF4511E),
    Color(0xFFFF7043),
    Color(0xFF6D4C41),
    Color(0xFF8D6E63),
    Color(0xFF546E7A),
    Color(0xFF78909C),
    Color(0xFF616161),
    Color(0xFF9E9E9E),
    Color(0xFF111111),
    Color(0xFF212121),
    Color(0xFFFFFFFF),
    Color(0xFFFAFAFA),
    Color(0xFFECEFF1),
    Color(0xFFE3F2FD),
    Color(0xFFE8F5E9),
    Color(0xFFFCE4EC),
    Color(0xFFFFF3E0),
    Color(0xFFECE5DD),
    Color(0xFFDCE6F0),
  ];
}

class _ColorField extends StatelessWidget {
  final String label;
  final Color color;
  final void Function(Color) onPicked;

  const _ColorField({
    required this.label,
    required this.color,
    required this.onPicked,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: GestureDetector(
        onTap: () => _openPicker(context),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: color.computeLuminance() > 0.7 ? Colors.black26 : Colors.transparent,
              width: 1.5,
            ),
          ),
        ),
      ),
      title: Text(label),
      subtitle: Text(
        '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _openPicker(context),
    );
  }

  void _openPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final c in _PaletteSettingsScreenState._pickerColors)
                    GestureDetector(
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        onPicked(c);
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: c.computeLuminance() > 0.7
                                ? Colors.black12
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: c == color
                            ? const Icon(Icons.check, color: Colors.white, size: 22)
                            : null,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PalettePreview extends StatelessWidget {
  final ChatPalette palette;

  const _PalettePreview({required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _mockMessage(
            bubbleColor: palette.otherBubble,
            textColor: palette.otherText,
            alignEnd: false,
            quote: null,
            sender: 'Anna',
          ),
          const SizedBox(height: 8),
          _mockMessage(
            bubbleColor: palette.ownBubble,
            textColor: palette.ownText,
            alignEnd: true,
            quote: palette,
            sender: null,
          ),
        ],
      ),
    );
  }

  Widget _mockMessage({
    required Color bubbleColor,
    required Color textColor,
    required bool alignEnd,
    required ChatPalette? quote,
    required String? sender,
  }) {
    return Align(
      alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 240),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(alignEnd ? 12 : 2),
            bottomRight: Radius.circular(alignEnd ? 2 : 12),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (sender != null)
              Text(
                sender,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: palette.seedColor,
                ),
              ),
            if (quote != null)
              Container(
                margin: const EdgeInsets.only(bottom: 4, top: 2),
                padding: const EdgeInsets.only(left: 10, top: 6, bottom: 6, right: 6),
                decoration: BoxDecoration(
                  color: quote.quoteBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: Border(
                    left: BorderSide(color: palette.seedColor, width: 3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'You',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: palette.seedColor,
                      ),
                    ),
                    Text(
                      'Quoted message preview',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: textColor.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
            Text(
              'Hello! How are you doing today?',
              style: TextStyle(color: textColor, fontSize: 14),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '14:32',
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.7),
                    fontSize: 10,
                  ),
                ),
                if (alignEnd) ...[
                  const SizedBox(width: 4),
                  Icon(
                    Icons.done_all,
                    size: 13,
                    color: palette.readTick,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
