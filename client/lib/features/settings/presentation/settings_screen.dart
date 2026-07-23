import 'package:flutter/material.dart';
import 'package:uphone_client/core/config/app_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late int _slideshowInterval;
  late bool _slideshowAutoplay;

  @override
  void initState() {
    super.initState();
    _slideshowInterval = AppSettings.instance.slideshowIntervalSeconds;
    _slideshowAutoplay = AppSettings.instance.slideshowAutoplay;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
