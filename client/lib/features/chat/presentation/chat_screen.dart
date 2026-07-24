import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uphone_client/features/auth/domain/auth_provider.dart';
import 'package:uphone_client/features/chat/domain/chat_provider.dart';
import 'package:uphone_client/features/chat/presentation/widgets/message_bubble.dart';
import 'package:uphone_client/features/chat/presentation/widgets/message_input.dart';
import 'package:uphone_client/features/chat/presentation/widgets/forward_message_sheet.dart';
import 'package:uphone_client/features/chat/presentation/media_viewer_screen.dart';
import 'package:uphone_client/features/calls/domain/call_provider.dart';
import 'package:uphone_client/features/calls/presentation/call_screen.dart';
import 'package:uphone_client/features/contacts/domain/contacts_provider.dart';
import 'package:uphone_client/shared/models/chat.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String chatId;

  const ChatScreen({super.key, required this.chatId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scrollController = ScrollController();
  String? _editingMessageId;
  bool _initialScrollDone = false;
  final _firstUnreadKey = GlobalKey();
  int? _firstUnreadIndex;
  int _savedUnreadCount = 0;

  @override
  void initState() {
    super.initState();
    final chatState = ref.read(chatProvider);
    final chat = chatState.chats.where((c) => c.id == widget.chatId).toList();
    if (chat.isNotEmpty) {
      _savedUnreadCount = chat.first.unreadCount;
    }
    Future.microtask(() {
      ref.read(chatProvider.notifier).openChat(widget.chatId);
      ref.read(contactsProvider.notifier).loadContacts();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  double _estimateMessageHeight(ChatMessage msg) {
    const double overhead = 40; // padding 4 + margin 4 + container padding 20 + time 12
    if (msg.type == 'image') return 160 + 32 + overhead; // image + buttons
    if (msg.type == 'video') return 124 + 32 + overhead; // 16:9 + buttons
    if (msg.type == 'file') return 60 + 32 + overhead;
    if (msg.type == 'voice') return 48 + 32 + overhead;
    final lines = (msg.content.length / 38).ceil().clamp(1, 20);
    return overhead + lines * 22;
  }

  void _performInitialScroll(ChatState chatState) {
    if (_initialScrollDone) return;
    _initialScrollDone = true;

    final unreadCount = _savedUnreadCount;

    if (unreadCount <= 0 || chatState.messages.length <= 1) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    } else {
      final unreadStart = chatState.messages.length - unreadCount;
      _firstUnreadIndex = unreadStart.clamp(0, chatState.messages.length - 1);

      // Phase 1: rough jump to get target widget into viewport
      double offset = 0;
      for (int i = 0; i < _firstUnreadIndex!; i++) {
        offset += _estimateMessageHeight(chatState.messages[i]);
      }
      _scrollController.jumpTo(offset.clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      ));

      // Phase 2: precise scroll after the target widget renders
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_firstUnreadKey.currentContext != null) {
          Scrollable.ensureVisible(
            _firstUnreadKey.currentContext!,
            alignment: 0.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final authState = ref.watch(authProvider);

    ref.listen<ChatState>(chatProvider, (prev, next) {
      if (!_initialScrollDone && !next.isLoadingMessages && next.messages.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _performInitialScroll(next);
          }
        });
      } else if ((prev?.messages.length ?? 0) < next.messages.length) {
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
    });

    final currentChat = chatState.chats.firstWhere(
      (c) => c.id == widget.chatId,
      orElse: () => chatState.chats.isNotEmpty
          ? chatState.chats.first
          : throw Exception('Chat not found'),
    );

    final contactsState = ref.watch(contactsProvider);
    final contactAvatar = currentChat.type == 'personal' && currentChat.avatarUrl.isEmpty
        ? _findContactAvatar(contactsState.contacts, currentChat.name)
        : null;

    final displayAvatar = currentChat.avatarUrl.isNotEmpty
        ? currentChat.avatarUrl
        : contactAvatar;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            ref.read(chatProvider.notifier).closeChat();
            context.go('/chats');
          },
        ),
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              backgroundImage: displayAvatar != null && displayAvatar.isNotEmpty
                  ? NetworkImage(displayAvatar)
                  : null,
              child: (displayAvatar == null || displayAvatar.isEmpty)
                  ? Text(
                      currentChat.name.isNotEmpty
                          ? currentChat.name[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    currentChat.name.isNotEmpty ? currentChat.name : 'Chat',
                    style: const TextStyle(fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (chatState.typingUsers.isNotEmpty)
                    Text(
                      'typing...',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_library_outlined),
            onPressed: () => context.push('/chats/${widget.chatId}/gallery'),
          ),
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
              icon: const Icon(Icons.videocam_outlined),
              onPressed: () => _startGroupCall('video'),
            ),
          if (currentChat.type != 'personal')
            IconButton(
              icon: const Icon(Icons.call_outlined),
              onPressed: () => _startGroupCall('audio'),
            ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => context.push('/chats/${widget.chatId}/info'),
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

                      final contactAvatars = <String, String>{};
                      for (final c in contactsState.contacts) {
                        if (c.avatarUrl != null && c.avatarUrl!.isNotEmpty) {
                          contactAvatars[c.displayName] = c.avatarUrl!;
                        }
                      }

                      return MessageBubble(
                        key: index == _firstUnreadIndex ? _firstUnreadKey : null,
                        message: msg,
                        isMe: isMe,
                        showSender: showSender,
                        contactAvatars: contactAvatars,
                        onEdit: isMe ? () => _startEdit(msg.id) : null,
                        onDelete: isMe ? () => _deleteMessage(msg.id) : null,
                        onReact: (emoji) => _addReaction(msg.id, emoji),
                        onForward: () => _forwardMessage(msg.id),
                        onTapImage: msg.type == 'image' && msg.fileUrl.isNotEmpty
                            ? () => _openImage(msg)
                            : null,
                      );
                    },
                  ),
          ),
          MessageInput(
            onSend: (content) => _sendMessage(content),
            onSendFile: (filename, mimeType, bytes) =>
                _sendFile(filename, mimeType, bytes),
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

  void _sendFile(String filename, String mimeType, Uint8List bytes) {
    ref.read(chatProvider.notifier).sendFile(widget.chatId, filename, mimeType, bytes);
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

  void _forwardMessage(String msgId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ForwardMessageSheet(
        sourceChatId: widget.chatId,
        messageId: msgId,
      ),
    );
  }

  void _openImage(ChatMessage msg) {
    final currentChatState = ref.read(chatProvider);
    final images = currentChatState.messages
        .where((m) => m.type == 'image' && m.fileUrl.isNotEmpty)
        .toList();
    final initialIndex = images.indexOf(msg);
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
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start call: $e')),
        );
      }
    }
  }

  void _startGroupCall(String callType) async {
    final authState = ref.read(authProvider);
    final currentUserId = authState.user?.id ?? '';
    final userName = authState.user?.username ?? 'User';

    final members = await ref.read(chatRepositoryProvider).getMembers(widget.chatId);
    final participantIds = <String>[];
    for (final m in members) {
      final uid = m['user_id'] as String? ?? '';
      if (uid.isNotEmpty && uid != currentUserId) {
        participantIds.add(uid);
      }
    }

    if (participantIds.isEmpty) return;

    final webrtc = ref.read(webRTCServiceProvider);
    webrtc.init();

    final chatState = ref.read(chatProvider);
    final currentChat = chatState.chats.firstWhere(
      (c) => c.id == widget.chatId,
      orElse: () => chatState.chats.first,
    );

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CallScreen(
          callType: callType,
          isGroup: true,
          remoteUserName: currentChat.name,
        ),
      ),
    );

    try {
      await webrtc.startGroupCall(
        callType,
        widget.chatId,
        participants: participantIds,
        fromName: userName,
      );
    } catch (e) {
      debugPrint('startGroupCall failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start group call: $e')),
        );
      }
    }
  }

  String? _findContactAvatar(List<dynamic> contacts, String chatName) {
    for (final c in contacts) {
      if (c.displayName == chatName &&
          c.avatarUrl != null &&
          c.avatarUrl!.isNotEmpty) {
        return c.avatarUrl;
      }
    }
    return null;
  }
}
