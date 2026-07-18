import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uphone_client/features/auth/domain/auth_provider.dart';
import 'package:uphone_client/features/chat/domain/chat_provider.dart';
import 'package:uphone_client/features/chat/presentation/widgets/message_bubble.dart';
import 'package:uphone_client/features/chat/presentation/widgets/message_input.dart';
import 'package:uphone_client/features/calls/domain/call_provider.dart';
import 'package:uphone_client/features/calls/presentation/call_screen.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String chatId;

  const ChatScreen({super.key, required this.chatId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scrollController = ScrollController();
  String? _editingMessageId;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(chatProvider.notifier).openChat(widget.chatId);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final authState = ref.watch(authProvider);

    ref.listen<ChatState>(chatProvider, (prev, next) {
      if ((prev?.messages.length ?? 0) < next.messages.length) {
        _scrollToBottom();
      }
    });

    final currentChat = chatState.chats.firstWhere(
      (c) => c.id == widget.chatId,
      orElse: () => chatState.chats.isNotEmpty
          ? chatState.chats.first
          : throw Exception('Chat not found'),
    );

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            ref.read(chatProvider.notifier).closeChat();
            context.go('/chats');
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(currentChat.name.isNotEmpty ? currentChat.name : 'Chat'),
            if (chatState.typingUsers.isNotEmpty)
              Text(
                'typing...',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
          ],
        ),
        actions: [
          if (currentChat.type == 'personal')
            IconButton(
              icon: const Icon(Icons.videocam_outlined),
              onPressed: () => _startCall('video'),
            ),
          if (currentChat.type == 'personal')
            IconButton(
              icon: const Icon(Icons.call_outlined),
              onPressed: () => _startCall('audio'),
            ),
          if (currentChat.type != 'personal')
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () => context.go('/chats/${widget.chatId}/info'),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: chatState.isLoadingMessages
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    itemCount: chatState.messages.length,
                    itemBuilder: (context, index) {
                      final msg = chatState.messages[index];
                      final isMe = msg.senderId == authState.user?.id;
                      final showSender = !isMe &&
                          (index == 0 ||
                              chatState.messages[index - 1].senderId != msg.senderId);

                      return MessageBubble(
                        message: msg,
                        isMe: isMe,
                        showSender: showSender,
                        onEdit: isMe ? () => _startEdit(msg.id) : null,
                        onDelete: isMe ? () => _deleteMessage(msg.id) : null,
                        onReact: (emoji) => _addReaction(msg.id, emoji),
                      );
                    },
                  ),
          ),
          MessageInput(
            onSend: (content) => _sendMessage(content),
            onTypingStart: () =>
                ref.read(chatProvider.notifier).sendTypingStart(widget.chatId),
            onTypingStop: () =>
                ref.read(chatProvider.notifier).sendTypingStop(widget.chatId),
          ),
        ],
      ),
    );
  }

  void _sendMessage(String content) {
    if (_editingMessageId != null) {
      ref.read(chatProvider.notifier).editMessage(
            widget.chatId,
            _editingMessageId!,
            content,
          );
      setState(() => _editingMessageId = null);
    } else {
      ref.read(chatProvider.notifier).sendMessage(widget.chatId, content);
    }
  }

  void _startEdit(String msgId) {
    setState(() => _editingMessageId = msgId);
  }

  void _deleteMessage(String msgId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              ref.read(chatProvider.notifier).deleteMessage(widget.chatId, msgId);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _addReaction(String msgId, String emoji) {
    ref.read(chatProvider.notifier).addReaction(widget.chatId, msgId, emoji);
  }

  void _startCall(String callType) async {
    final authState = ref.read(authProvider);
    final currentUserId = authState.user?.id ?? '';

    String otherUserId = '';
    String otherUserName = 'User';

    final chatState = ref.read(chatProvider);
    final currentChat = chatState.chats.firstWhere(
      (c) => c.id == widget.chatId,
      orElse: () => chatState.chats.isNotEmpty
          ? chatState.chats.first
          : throw Exception('Chat not found'),
    );

    if (currentChat.type == 'personal') {
      final members = await ref.read(chatRepositoryProvider).getMembers(widget.chatId);
      for (final m in members) {
        final uid = m['user_id'] as String? ?? '';
        if (uid != currentUserId && uid.isNotEmpty) {
          otherUserId = uid;
          otherUserName = m['username'] as String? ?? 'User';
          break;
        }
      }
    }

    if (otherUserId.isEmpty) return;

    final webrtc = ref.read(webRTCServiceProvider);
    webrtc.init();

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CallScreen(
          remoteUserId: otherUserId,
          remoteUserName: otherUserName,
          callType: callType,
        ),
      ),
    );

    try {
      await webrtc.startCall(otherUserId, callType, chatId: widget.chatId);
    } catch (e) {
      debugPrint('startCall failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start call: $e')),
        );
      }
    }
  }
}
