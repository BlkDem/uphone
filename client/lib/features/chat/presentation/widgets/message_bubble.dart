import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uphone_client/shared/models/chat.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final bool showSender;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final Function(String)? onReact;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.showSender = false,
    this.onEdit,
    this.onDelete,
    this.onReact,
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
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
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
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
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

  void _showContextMenu(BuildContext context) {
    if (onEdit == null && onDelete == null) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
