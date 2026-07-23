import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uphone_client/shared/models/chat.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:uphone_client/core/utils/download_helper.dart';
import 'package:uphone_client/core/utils/html_media_player.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final bool showSender;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final Function(String)? onReact;
  final VoidCallback? onForward;
  final VoidCallback? onTapImage;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.showSender = false,
    this.onEdit,
    this.onDelete,
    this.onReact,
    this.onForward,
    this.onTapImage,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (message.isDeleted) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, size: 14, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
            Text(
              'Message deleted',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (showSender)
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 12, top: 8),
              child: Text(
                message.sender?.displayName ?? 'Unknown',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          GestureDetector(
            onLongPress: () => _showContextMenu(context),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              margin: EdgeInsets.only(
                left: isMe ? 48 : 8,
                right: isMe ? 8 : 48,
                top: 2,
                bottom: 2,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe
                    ? colorScheme.primaryContainer
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(9),
                  topRight: const Radius.circular(9),
                  bottomLeft: Radius.circular(isMe ? 9 : 2),
                  bottomRight: Radius.circular(isMe ? 2 : 9),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.content.isNotEmpty)
                    Text(
                      message.content,
                      style: TextStyle(
                        color: isMe
                            ? colorScheme.onPrimaryContainer
                            : colorScheme.onSurface,
                      ),
                    ),
                  if (message.fileUrl.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    _buildFilePreview(context),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        DateFormat('HH:mm').format(message.createdAt),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: isMe
                                  ? colorScheme.onPrimaryContainer.withValues(alpha: 0.7)
                                  : colorScheme.onSurfaceVariant,
                              fontSize: 10,
                            ),
                      ),
                      if (message.isPinned) ...[
                        const SizedBox(width: 4),
                        Icon(
                          Icons.push_pin,
                          size: 10,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilePreview(BuildContext context) {
    if (message.type == 'image') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onTapImage,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: message.fileUrl,
                width: 220,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  width: 220,
                  height: 160,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                errorWidget: (context, url, error) => Container(
                  width: 220,
                  height: 120,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image, size: 32, color: Theme.of(context).colorScheme.error),
                      const SizedBox(height: 4),
                      Text(
                        'Failed to load',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _actionButton(
                context,
                icon: Icons.download,
                tooltip: 'Save',
                onPressed: () => _downloadFile(context),
              ),
              const SizedBox(width: 4),
              _actionButton(
                context,
                icon: Icons.share,
                tooltip: 'Share',
                onPressed: () => _shareFile(context),
              ),
            ],
          ),
        ],
      );
    }

    if (message.type == 'video') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: buildVideoPlayer(message.fileUrl),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _actionButton(
                context,
                icon: Icons.download,
                tooltip: 'Save',
                onPressed: () => _downloadFile(context),
              ),
              const SizedBox(width: 4),
              _actionButton(
                context,
                icon: Icons.share,
                tooltip: 'Share',
                onPressed: () => _shareFile(context),
              ),
            ],
          ),
        ],
      );
    }

    if (message.type == 'voice') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildAudioPlayer(message.fileUrl),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _actionButton(
                context,
                icon: Icons.download,
                tooltip: 'Save',
                onPressed: () => _downloadFile(context),
              ),
              const SizedBox(width: 4),
              _actionButton(
                context,
                icon: Icons.share,
                tooltip: 'Share',
                onPressed: () => _shareFile(context),
              ),
            ],
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getFileIcon(),
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  message.fileUrl.split('/').last,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _actionButton(
                context,
                icon: Icons.download,
                tooltip: 'Save',
                onPressed: () => _downloadFile(context),
              ),
              const SizedBox(width: 4),
              _actionButton(
                context,
                icon: Icons.share,
                tooltip: 'Share',
                onPressed: () => _shareFile(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getFileIcon() {
    switch (message.type) {
      case 'image':
        return Icons.image;
      case 'video':
        return Icons.video_file;
      case 'voice':
        return Icons.mic;
      default:
        return Icons.attach_file;
    }
  }

  Future<void> _downloadFile(BuildContext context) async {
    try {
      await DownloadHelper.downloadFile(message.fileUrl);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File saved')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    }
  }

  Future<void> _shareFile(BuildContext context) async {
    try {
      await Share.shareUri(Uri.parse(message.fileUrl));
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e')),
        );
      }
    }
  }

  Widget _actionButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 28,
      height: 28,
      child: IconButton(
        icon: Icon(icon, size: 16),
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    final hasActions = onEdit != null || onDelete != null || onForward != null;
    if (!hasActions) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onForward != null)
              ListTile(
                leading: const Icon(Icons.forward),
                title: const Text('Forward'),
                onTap: () {
                  Navigator.pop(context);
                  onForward?.call();
                },
              ),
            if (onEdit != null)
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit'),
                onTap: () {
                  Navigator.pop(context);
                  onEdit?.call();
                },
              ),
            if (onDelete != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  onDelete?.call();
                },
              ),
          ],
        ),
      ),
    );
  }
}
