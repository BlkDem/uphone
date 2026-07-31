import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uphone_client/core/config/app_settings.dart';
import 'package:uphone_client/core/network/battery_optimization.dart';
import 'package:uphone_client/core/theme/chat_palette.dart';
import 'package:uphone_client/main.dart';
import 'package:uphone_client/features/settings/presentation/palette_settings_screen.dart';
import 'package:uphone_client/features/settings/presentation/profile_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late int _slideshowInterval;
  late bool _slideshowAutoplay;
  late double _chatFontSize;

  @override
  void initState() {
    super.initState();
    _slideshowInterval = AppSettings.instance.slideshowIntervalSeconds;
    _slideshowAutoplay = AppSettings.instance.slideshowAutoplay;
    _chatFontSize = AppSettings.instance.chatFontSize;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentPalette = ref.watch(chatPaletteProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          _SectionHeader(title: 'Account', theme: theme),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Profile'),
            subtitle: const Text('Edit display name and avatar'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
          const Divider(),
          _SectionHeader(title: 'Appearance', theme: theme),
          ListTile(
            leading: const Icon(Icons.text_fields),
            title: const Text('Chat font size'),
            subtitle: Text('${_chatFontSize.round()} sp'),
            trailing: SizedBox(
              width: 200,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: _chatFontSize > 10
                        ? () {
                            setState(() => _chatFontSize -= 1);
                            AppSettings.instance.chatFontSize = _chatFontSize;
                            ref.read(chatFontSizeProvider.notifier).state = _chatFontSize;
                          }
                        : null,
                  ),
                  Text(
                    '${_chatFontSize.round()}',
                    style: theme.textTheme.titleMedium,
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: _chatFontSize < 24
                        ? () {
                            setState(() => _chatFontSize += 1);
                            AppSettings.instance.chatFontSize = _chatFontSize;
                            ref.read(chatFontSizeProvider.notifier).state = _chatFontSize;
                          }
                        : null,
                  ),
                ],
              ),
            ),
          ),
          const Divider(),
          _SectionHeader(title: 'Chat Palette', theme: theme),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final palette in ChatPalettes.all)
                  _PaletteSwatch(
                    palette: palette,
                    selected: currentPalette.id == palette.id,
                    onTap: () {
                      AppSettings.instance.chatPalette = palette;
                      ref.read(chatPaletteProvider.notifier).state = palette;
                    },
                  ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('Customize colors'),
            subtitle: const Text('Edit each chat color individually'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PaletteSettingsScreen()),
            ),
          ),
          const Divider(),
          _SectionHeader(title: 'Media Gallery', theme: theme),
          SwitchListTile(
            title: const Text('Auto-play slideshow'),
            subtitle: const Text('Automatically advance through media'),
            value: _slideshowAutoplay,
            onChanged: (value) {
              setState(() => _slideshowAutoplay = value);
              AppSettings.instance.slideshowAutoplay = value;
            },
          ),
          ListTile(
            title: const Text('Slideshow interval'),
            subtitle: Text('$_slideshowInterval seconds per image'),
            trailing: SizedBox(
              width: 200,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: _slideshowInterval > 1
                        ? () {
                            setState(() => _slideshowInterval--);
                            AppSettings.instance.slideshowIntervalSeconds = _slideshowInterval;
                          }
                        : null,
                  ),
                  Text(
                    '$_slideshowInterval s',
                    style: theme.textTheme.titleMedium,
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: _slideshowInterval < 30
                        ? () {
                            setState(() => _slideshowInterval++);
                            AppSettings.instance.slideshowIntervalSeconds = _slideshowInterval;
                          }
                        : null,
                  ),
                ],
              ),
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Videos always play for their full duration during slideshow.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (!kIsWeb) ...[
            const Divider(),
            _SectionHeader(title: 'Battery', theme: theme),
            ListTile(
              leading: const Icon(Icons.battery_saver),
              title: const Text('Battery Optimization'),
              subtitle: const Text('Exclude from battery optimization for reliable call notifications'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => BatteryOptimization.requestExemption(context),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final ThemeData theme;

  const _SectionHeader({required this.title, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _PaletteSwatch extends StatelessWidget {
  final ChatPalette palette;
  final bool selected;
  final VoidCallback onTap;

  const _PaletteSwatch({
    required this.palette,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: palette.ownBubble,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? palette.seedColor : Colors.black12,
                width: selected ? 3 : 1.5,
              ),
            ),
            child: Center(
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: palette.seedColor,
                  shape: BoxShape.circle,
                ),
                child: selected
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 64,
            child: Text(
              palette.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.labelSmall?.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
