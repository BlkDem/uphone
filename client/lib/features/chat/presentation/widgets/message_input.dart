import 'dart:async';
import 'dart:typed_data';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

class MessageInput extends StatefulWidget {
  final Function(String) onSend;
  final Function(String, String, Uint8List)? onSendFile;
  final VoidCallback? onTypingStart;
  final VoidCallback? onTypingStop;

  const MessageInput({
    super.key,
    required this.onSend,
    this.onSendFile,
    this.onTypingStart,
    this.onTypingStop,
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _typingTimer;
  bool _isTyping = false;
  bool _showEmojiPicker = false;
  bool _isUploading = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  void _onTextChanged(String text) {
    if (text.isNotEmpty && !_isTyping) {
      _isTyping = true;
      widget.onTypingStart?.call();
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (_isTyping) {
        _isTyping = false;
        widget.onTypingStop?.call();
      }
    });
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    widget.onSend(text);
    _controller.clear();
    _focusNode.requestFocus();

    if (_isTyping) {
      _isTyping = false;
      widget.onTypingStop?.call();
    }
    _typingTimer?.cancel();
  }

  void _onEmojiSelected(Emoji emoji) {
    if (_controller.text.isEmpty) {
      widget.onSend(emoji.emoji);
      return;
    }
    final text = _controller.text;
    final selection = _controller.selection;
    final before = text.substring(0, selection.start);
    final after = text.substring(selection.end);
    final newText = before + emoji.emoji + after;
    _controller.text = newText;
    _controller.selection = TextSelection.collapsed(
      offset: selection.start + emoji.emoji.length,
    );
  }

  Future<void> _pickImage() async {
    if (widget.onSendFile == null) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          final ext = file.name.split('.').last.toLowerCase();
          final mimeType = _getMimeType(ext);
          _sendFile(file.name, mimeType, file.bytes!);
        }
      }
    } catch (e) {
      debugPrint('Image pick failed: $e');
    }
  }

  Future<void> _pickVideo() async {
    if (widget.onSendFile == null) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: false,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          final ext = file.name.split('.').last.toLowerCase();
          final mimeType = _getMimeType(ext);
          _sendFile(file.name, mimeType, file.bytes!);
        }
      }
    } catch (e) {
      debugPrint('Video pick failed: $e');
    }
  }

  Future<void> _pickFile() async {
    if (widget.onSendFile == null) return;

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.bytes != null) {
          final ext = file.name.split('.').last.toLowerCase();
          final mimeType = _getMimeType(ext);
          _sendFile(file.name, mimeType, file.bytes!);
        }
      }
    } catch (e) {
      debugPrint('File pick failed: $e');
    }
  }

  String _getMimeType(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'mp4':
        return 'video/mp4';
      case 'webm':
        return 'video/webm';
      case 'mp3':
        return 'audio/mpeg';
      case 'ogg':
        return 'audio/ogg';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> _sendFile(String filename, String mimeType, Uint8List bytes) async {
    setState(() => _isUploading = true);
    try {
      await widget.onSendFile?.call(filename, mimeType, bytes);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_showEmojiPicker)
          SizedBox(
            height: 280,
            child: EmojiPicker(
              onEmojiSelected: (category, emoji) => _onEmojiSelected(emoji),
              onBackspacePressed: () {
                setState(() => _showEmojiPicker = false);
              },
              config: Config(
                height: 280,
                checkPlatformCompatibility: true,
                emojiViewConfig: EmojiViewConfig(
                  columns: 7,
                  emojiSizeMax: 28 * (Theme.of(context).platform == TargetPlatform.iOS ? 1.2 : 1.0),
                  backgroundColor: colorScheme.surface,
                ),
                bottomActionBarConfig: BottomActionBarConfig(
                  enabled: false,
                ),
                searchViewConfig: SearchViewConfig(
                  hintText: 'Search emoji...',
                ),
              ),
            ),
          ),
        if (_isUploading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: LinearProgressIndicator(),
          ),
        Container(
          padding: EdgeInsets.only(
            left: 8,
            right: 8,
            top: 8,
            bottom: MediaQuery.of(context).viewInsets.bottom + 8,
          ),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _ActionCircle(
                    icon: _showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions_outlined,
                    active: _showEmojiPicker,
                    activeColor: colorScheme.primary,
                    onTap: () {
                      setState(() => _showEmojiPicker = !_showEmojiPicker);
                      if (_showEmojiPicker) {
                        _focusNode.unfocus();
                      } else {
                        _focusNode.requestFocus();
                      }
                    },
                    tooltip: 'Emoji',
                  ),
                  const SizedBox(width: 6),
                  _ActionCircle(
                    icon: Icons.image_outlined,
                    onTap: _isUploading ? null : _pickImage,
                    tooltip: 'Image',
                  ),
                  const SizedBox(width: 6),
                  _ActionCircle(
                    icon: Icons.videocam_outlined,
                    onTap: _isUploading ? null : _pickVideo,
                    tooltip: 'Video',
                  ),
                  const SizedBox(width: 6),
                  _ActionCircle(
                    icon: Icons.attach_file,
                    onTap: _isUploading ? null : _pickFile,
                    tooltip: 'Attach file',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      maxLines: 5,
                      minLines: 1,
                      textInputAction: TextInputAction.newline,
                      onChanged: _onTextChanged,
                      decoration: InputDecoration(
                        hintText: 'Message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: (_controller.text.trim().isEmpty && !_isUploading)
                        ? null
                        : _send,
                    icon: const Icon(Icons.send, size: 20),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionCircle extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool active;
  final Color? activeColor;
  final String? tooltip;

  const _ActionCircle({
    required this.icon,
    this.onTap,
    this.active = false,
    this.activeColor,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = active ? (activeColor ?? colorScheme.primary) : colorScheme.onSurfaceVariant;

    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active
                ? colorScheme.primaryContainer.withValues(alpha: 0.6)
                : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
      ),
    );
  }
}
