import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uphone_client/core/config/app_settings.dart';
import 'package:uphone_client/main.dart';
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
    final themeMode = ref.watch(themeModeProvider);

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
            leading: Icon(
              switch (themeMode) {
                ThemeMode.light => Icons.light_mode,
                ThemeMode.dark => Icons.dark_mode,
                ThemeMode.system => Icons.brightness_auto,
              },
            ),
            title: const Text('Theme'),
            subtitle: Text(
              switch (themeMode) {
                ThemeMode.light => 'Light',
                ThemeMode.dark => 'Dark',
                ThemeMode.system => 'System',
              },
            ),
            trailing: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode, size: 18)),
                ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto, size: 18)),
                ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode, size: 18)),
              ],
              selected: {themeMode},
              onSelectionChanged: (selected) {
                final mode = selected.first;
                ref.read(themeModeProvider.notifier).state = mode;
                AppSettings.instance.themeMode = mode;
              },
            ),
          ),
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
