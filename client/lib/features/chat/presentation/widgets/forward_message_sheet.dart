import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uphone_client/features/chat/domain/chat_provider.dart';
import 'package:uphone_client/shared/models/chat.dart';

class ForwardMessageSheet extends ConsumerStatefulWidget {
  final String sourceChatId;
  final String messageId;

  const ForwardMessageSheet({
    super.key,
    required this.sourceChatId,
    required this.messageId,
  });

  @override
  ConsumerState<ForwardMessageSheet> createState() => _ForwardMessageSheetState();
}

class _ForwardMessageSheetState extends ConsumerState<ForwardMessageSheet> {
  List<Chat> _chats = [];
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    final repo = ref.read(chatRepositoryProvider);
    final chats = await repo.getChats();
    if (mounted) {
      setState(() {
        _chats = chats.where((c) => c.id != widget.sourceChatId).toList();
        _isLoading = false;
      });
    }
  }

  Future<void> _forwardTo(Chat target) async {
    if (_isSending) return;
    setState(() => _isSending = true);

    try {
      final repo = ref.read(chatRepositoryProvider);
      await repo.forwardMessage(widget.sourceChatId, widget.messageId, target.id);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Forwarded to ${target.name.isNotEmpty ? target.name : 'chat'}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Forward failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Forward to...',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            )
          else if (_chats.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No other chats'),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _chats.length,
                itemBuilder: (context, index) {
                  final chat = _chats[index];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        (chat.name.isNotEmpty ? chat.name : 'C')[0].toUpperCase(),
                      ),
                    ),
                    title: Text(chat.name.isNotEmpty ? chat.name : 'Chat'),
                    subtitle: Text(chat.type),
                    onTap: () => _forwardTo(chat),
                    enabled: !_isSending,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
