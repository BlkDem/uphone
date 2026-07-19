import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uphone_client/features/auth/domain/auth_provider.dart';
import 'package:uphone_client/features/chat/domain/chat_provider.dart';
import 'package:uphone_client/shared/models/chat.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:uphone_client/features/chat/presentation/media_viewer_screen.dart';

class MediaGalleryScreen extends ConsumerStatefulWidget {
  final String chatId;

  const MediaGalleryScreen({super.key, required this.chatId});

  @override
  ConsumerState<MediaGalleryScreen> createState() => _MediaGalleryScreenState();
}

class _MediaGalleryScreenState extends ConsumerState<MediaGalleryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<ChatMessage> _mediaMessages = [];
  bool _isLoading = true;

  static const _tabs = [
    {'label': 'All', 'type': null},
    {'label': 'Images', 'type': 'image'},
    {'label': 'Video', 'type': 'video'},
    {'label': 'Audio', 'type': 'voice'},
    {'label': 'Files', 'type': 'file'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadMedia();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      _loadMedia();
    }
  }

  Future<void> _loadMedia() async {
    setState(() => _isLoading = true);
    final repo = ref.read(chatRepositoryProvider);
    final mediaType = _tabs[_tabController.index]['type'] as String?;
    final messages = await repo.getMediaMessages(widget.chatId, mediaType: mediaType);
    if (mounted) {
      setState(() {
        _mediaMessages = messages;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Media'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _tabs.map((t) => Tab(text: t['label'] as String)).toList(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _mediaMessages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_open, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(height: 12),
                      Text(
                        'No media found',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadMedia,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(4),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 4,
                      mainAxisSpacing: 4,
                    ),
                    itemCount: _mediaMessages.length,
                    itemBuilder: (context, index) {
                      final msg = _mediaMessages[index];
                      return _MediaTile(
                        message: msg,
                        onTap: () => _openViewer(index),
                      );
                    },
                  ),
                ),
    );
  }

  void _openViewer(int index) {
    final images = _mediaMessages
        .where((m) => m.type == 'image' && m.fileUrl.isNotEmpty)
        .toList();
    final initialIndex = images.indexOf(_mediaMessages[index]);
    if (initialIndex < 0) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MediaViewerScreen(
          messages: images,
          initialIndex: initialIndex,
          chatId: widget.chatId,
        ),
      ),
    );
  }
}

class _MediaTile extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback onTap;

  const _MediaTile({required this.message, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (message.type == 'image') {
      return GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: CachedNetworkImage(
            imageUrl: message.fileUrl,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            errorWidget: (_, __, ___) => Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Icon(Icons.broken_image,
                  color: Theme.of(context).colorScheme.error),
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getIcon(),
              size: 32,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                message.fileUrl.split('/').last,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon() {
    switch (message.type) {
      case 'video':
        return Icons.video_file;
      case 'voice':
        return Icons.mic;
      case 'file':
        return Icons.attach_file;
      default:
        return Icons.insert_drive_file;
    }
  }
}
