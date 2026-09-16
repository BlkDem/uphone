import 'package:flutter/material.dart';
import 'package:uphone_client/features/chat/domain/chat_provider.dart';

class PendingUploadBubble extends StatelessWidget {
  final PendingUpload pending;
  final VoidCallback? onRetry;

  const PendingUploadBubble({super.key, required this.pending, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final failed = pending.failed;
    final bubbleColor = failed
        ? colorScheme.errorContainer.withValues(alpha: 0.85)
        : colorScheme.primaryContainer.withValues(alpha: 0.85);
    final contentColor = failed
        ? colorScheme.onErrorContainer
        : colorScheme.onPrimaryContainer;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  failed ? Icons.error_outline : _iconForType(pending.type),
                  size: 22,
                  color: contentColor.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 180,
                      child: Text(
                        pending.filename,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: contentColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (failed) ...[
                      Text(
                        'Не удалось отправить',
                        style: TextStyle(
                          fontSize: 12,
                          color: contentColor.withValues(alpha: 0.85),
                        ),
                      ),
                    ] else ...[
                      SizedBox(
                        width: 180,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: pending.progress,
                            minHeight: 4,
                            backgroundColor: contentColor.withValues(
                              alpha: 0.15,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Uploading... ${(pending.progress * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 10,
                          color: contentColor.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ],
                ),
                if (failed && onRetry != null) ...[
                  const SizedBox(width: 4),
                  IconButton(
                    onPressed: onRetry,
                    icon: Icon(Icons.refresh, size: 20),
                    color: contentColor,
                    tooltip: 'Повторить',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'image':
        return Icons.image_outlined;
      case 'video':
        return Icons.videocam_outlined;
      case 'voice':
        return Icons.mic;
      default:
        return Icons.attach_file;
    }
  }
}