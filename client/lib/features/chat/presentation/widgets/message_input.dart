import 'dart:async';
import 'package:flutter/material.dart';

class MessageInput extends StatefulWidget {
  final Function(String) onSend;
  final VoidCallback? onTypingStart;
  final VoidCallback? onTypingStop;

  const MessageInput({
    super.key,
    required this.onSend,
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.only(
        left: 12,
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            icon: const Icon(Icons.attach_file),
            onPressed: () {},
            color: colorScheme.onSurfaceVariant,
          ),
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
          const SizedBox(width: 4),
          IconButton.filled(
            onPressed: _controller.text.trim().isEmpty ? null : _send,
            icon: const Icon(Icons.send, size: 20),
          ),
        ],
      ),
    );
  }
}
