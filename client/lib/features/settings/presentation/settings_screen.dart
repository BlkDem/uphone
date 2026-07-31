import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uphone_client/core/config/app_settings.dart';
import 'package:uphone_client/core/network/battery_optimization.dart';
import 'package:uphone_client/core/theme/chat_background.dart';
import 'package:uphone_client/core/theme/chat_palette.dart';
import 'package:uphone_client/core/theme/app_fonts.dart';
import 'package:uphone_client/core/config/app_providers.dart';
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
    final currentBackground = ref.watch(chatBackgroundProvider);
    final currentFont = ref.watch(fontProvider);

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
          _SectionHeader(title: 'Chat font', theme: theme),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final font in AppFonts.all)
                  ChoiceChip(
                    label: Text(font.name),
                    selected: currentFont.id == font.id,
                    onSelected: (_) {
                      AppSettings.instance.fontFamilyId = font.id;
                      ref.read(fontProvider.notifier).state = font;
                    },
                  ),
              ],
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
          _SectionHeader(title: 'Wallpaper', theme: theme),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final bg in ChatBackgrounds.presets)
                  _WallpaperSwatch(
                    background: bg,
                    selected: currentBackground.id == bg.id,
                    onTap: () {
                      AppSettings.instance.chatBackground = bg;
                      ref.read(chatBackgroundProvider.notifier).state = bg;
                    },
                  ),
                if (currentBackground.isCustom)
                  _WallpaperSwatch(
                    background: currentBackground,
                    selected: true,
                    onTap: () {},
                  ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.add_photo_alternate_outlined),
            title: const Text('Custom image'),
            subtitle: const Text('Pick an image from your device'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickCustomWallpaper,
          ),
          if (currentBackground.isCustom)
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Remove custom image'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                AppSettings.instance.chatBackground = ChatBackgrounds.none;
                ref.read(chatBackgroundProvider.notifier).state = ChatBackgrounds.none;
              },
            ),
          ListTile(
            leading: const Icon(Icons.fit_screen_outlined),
            title: const Text('Fill mode'),
            subtitle: Text(
              ref.watch(chatBackgroundFillProvider).label,
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _selectFillMode(context),
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

  Future<void> _pickCustomWallpaper() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final raw = file.bytes;
    if (raw == null) return;
    final bytes = await compressWallpaperImage(raw);
    final bg = ChatBackgrounds.custom(bytes);
    AppSettings.instance.chatBackground = bg;
    ref.read(chatBackgroundProvider.notifier).state = bg;
  }

  void _selectFillMode(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Fill mode',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            for (final fill in WallpaperFill.values)
              ListTile(
                leading: Icon(
                  fill == WallpaperFill.tile
                      ? Icons.grid_view_outlined
                      : Icons.fit_screen_outlined,
                ),
                title: Text(fill.label),
                subtitle: Text(
                  fill == WallpaperFill.tile
                      ? 'Repeat the image to fill the area'
                      : 'Stretch the image to cover the area',
                ),
                trailing: ref.read(chatBackgroundFillProvider) == fill
                    ? Icon(Icons.check, color: Theme.of(ctx).colorScheme.primary)
                    : null,
                onTap: () {
                  AppSettings.instance.chatBackgroundFillId = fill.id;
                  ref.read(chatBackgroundFillProvider.notifier).state = fill;
                  Navigator.pop(ctx);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
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

class _WallpaperSwatch extends StatelessWidget {
  final ChatBackground background;
  final bool selected;
  final VoidCallback onTap;

  const _WallpaperSwatch({
    required this.background,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget preview;
    if (background.isNone) {
      preview = Container(
        color: theme.colorScheme.surfaceContainerHighest,
        child: Icon(Icons.wallpaper, color: theme.colorScheme.onSurfaceVariant),
      );
    } else if (background.isCustom) {
      preview = Image.memory(
        background.bytes!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    } else {
      preview = Image.asset(
        background.assetPath!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? theme.colorScheme.primary : Colors.black12,
                width: selected ? 3 : 1.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  preview,
                  if (selected)
                    Container(
                      color: theme.colorScheme.primary.withValues(alpha: 0.25),
                      child: const Icon(Icons.check, color: Colors.white, size: 20),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 64,
            child: Text(
              background.name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
