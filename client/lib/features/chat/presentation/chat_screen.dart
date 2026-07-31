import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:uphone_client/features/auth/domain/auth_provider.dart';
import 'package:uphone_client/features/chat/domain/chat_provider.dart';
import 'package:uphone_client/features/chat/presentation/widgets/message_bubble.dart';
import 'package:uphone_client/features/chat/presentation/widgets/message_input.dart';
import 'package:uphone_client/features/chat/presentation/widgets/forward_message_sheet.dart';
import 'package:uphone_client/features/chat/presentation/media_viewer_screen.dart';
import 'package:uphone_client/features/calls/domain/call_provider.dart';
import 'package:uphone_client/features/calls/presentation/call_screen.dart';
import 'package:uphone_client/features/contacts/domain/contacts_provider.dart';
import 'package:uphone_client/core/theme/chat_background.dart';
import 'package:uphone_client/core/config/app_providers.dart';
import 'package:uphone_client/shared/models/chat.dart';

const _ruMonths = [
  'января',
  'февраля',
  'марта',
  'апреля',
  'мая',
  'июня',
  'июля',
  'августа',
  'сентября',
  'октября',
  'ноября',
  'декабря',
];

class ChatScreen extends ConsumerStatefulWidget {
  final String chatId;

  const ChatScreen({super.key, required this.chatId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _itemScrollController = ItemScrollController();
  final _itemPositionsListener = ItemPositionsListener.create();
  final _scrollController = ScrollController();
  String? _editingMessageId;
  bool _isNearBottom = true;
  int _prevMessageCount = 0;
  bool _initialScrollDone = false;
  int _scrollRetries = 0;

  final Set<String> _selectedIds = {};
  List<ChatMessage> _quotedMessages = [];

  String get _replyToParam {
    if (_quotedMessages.isEmpty) return '';
    return _quotedMessages.map((m) => m.id).join(',');
  }

  bool get _isSelectionMode => _selectedIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _itemPositionsListener.itemPositions.addListener(_onScrollPositions);
    }
    _scrollController.addListener(_onScrollController);
    Future.microtask(() async {
      if (!mounted) return;
      await ref.read(chatProvider.notifier).loadChats();
      if (!mounted) return;
      await ref.read(chatProvider.notifier).openChat(widget.chatId);
      ref.read(contactsProvider.notifier).loadContacts();
    });
  }

  @override
  void dispose() {
    if (!kIsWeb) {
      _itemPositionsListener.itemPositions.removeListener(_onScrollPositions);
    }
    _scrollController.removeListener(_onScrollController);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScrollPositions() {
    if (kIsWeb) return;
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return;
    _handleScrollPosition(positions.map((p) => p.index).toList());
  }

  void _onScrollController() {
    if (!kIsWeb) return;
    if (!_scrollController.hasClients) return;
    final chatState = ref.read(chatProvider);
    final messages = chatState.messages;
    if (messages.isEmpty) return;

    try {
      final position = _scrollController.position;
      final maxExtent = position.maxScrollExtent;
      final pixels = position.pixels;
      final atBottom = maxExtent - pixels < 80;

      if (atBottom && !_isNearBottom) {
        _setNearBottom(true);
        if (_initialScrollDone) {
          ref
              .read(chatProvider.notifier)
              .markAsRead(widget.chatId, messages.last.id);
        }
      } else if (!atBottom && _isNearBottom) {
        _setNearBottom(false);
      }
    } catch (_) {}
  }

  void _setNearBottom(bool value) {
    if (_isNearBottom == value || !mounted) return;
    setState(() => _isNearBottom = value);
  }

  void _handleScrollPosition(List<int> indices) {
    final chatState = ref.read(chatProvider);
    final messages = chatState.messages;
    if (messages.isEmpty || indices.isEmpty) return;

    final maxIndex = indices.reduce((a, b) => a > b ? a : b);
    final atBottom = maxIndex >= messages.length - 2;

    if (atBottom && !_isNearBottom) {
      _setNearBottom(true);
      ref
          .read(chatProvider.notifier)
          .markAsRead(widget.chatId, messages.last.id);
    } else if (!atBottom && _isNearBottom) {
      _setNearBottom(false);
    }

    final minIndex = indices.reduce((a, b) => a < b ? a : b);
    if (minIndex < 5 &&
        chatState.hasMoreMessages &&
        !chatState.isLoadingOlder) {
      ref.read(chatProvider.notifier).loadOlderMessages();
    }
  }

  void _scrollToTarget() {
    final chatState = ref.read(chatProvider);
    if (chatState.isLoadingMessages || chatState.messages.isEmpty) return;

    final unreadCount = chatState.savedUnreadCount;
    final msgCount = chatState.messages.length;
    final targetIndex = unreadCount > 0
        ? (msgCount - unreadCount).clamp(0, msgCount - 1)
        : msgCount - 1;
    _setNearBottom(unreadCount == 0);

    debugPrint(
      'SCROLL unread=$unreadCount msgCount=$msgCount target=$targetIndex retries=$_scrollRetries',
    );

    if (kIsWeb) {
      _scrollToTargetWeb(targetIndex);
    } else {
      _scrollToTargetNative(targetIndex);
    }
  }

  void _scrollToTargetWeb(int targetIndex) {
    if (_scrollRetries > 20) {
      debugPrint('SCROLL web: giving up after 20 retries');
      return;
    }
    if (!mounted) return;

    try {
      if (!_scrollController.hasClients) {
        _scrollRetries++;
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _scrollToTargetWeb(targetIndex),
        );
        return;
      }

      final maxExtent = _scrollController.position.maxScrollExtent;
      final pixels = _scrollController.position.pixels;
      debugPrint(
        'SCROLL web: pixels=$pixels maxExtent=$maxExtent retries=$_scrollRetries',
      );

      if (maxExtent <= 0 && _scrollRetries < 10) {
        _scrollRetries++;
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) _scrollToTargetWeb(targetIndex);
        });
        return;
      }

      if (pixels >= maxExtent - 10) {
        _initialScrollDone = true;
        debugPrint('SCROLL web: already at bottom, skipping');
        return;
      }

      debugPrint('SCROLL web: scrolling to $maxExtent');
      _scrollController
          .animateTo(
            maxExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          )
          .then((_) {
            if (_scrollController.hasClients) {
              final newMax = _scrollController.position.maxScrollExtent;
              final pos = _scrollController.position.pixels;
              debugPrint(
                'SCROLL web: animate done, pixels=$pos newMax=$newMax',
              );
              if (newMax > pos + 1) {
                _scrollController.jumpTo(newMax);
                debugPrint('SCROLL web: snapped to $newMax');
              }
            }
            _initialScrollDone = true;
          })
          .catchError((e) {
            debugPrint('SCROLL web: scroll error: $e');
          });
    } catch (e) {
      debugPrint('SCROLL web: position error: $e, retrying');
      _scrollRetries++;
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _scrollToTargetWeb(targetIndex);
      });
    }
  }

  void _scrollToTargetNative(int targetIndex) {
    if (!_itemScrollController.isAttached) {
      _scrollRetries++;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _scrollToTargetNative(targetIndex),
      );
      return;
    }

    debugPrint('SCROLL native: jumpTo index=$targetIndex');
    _itemScrollController.jumpTo(index: targetIndex);
  }

  void _scrollToBottom() {
    if (kIsWeb) {
      if (!_scrollController.hasClients) return;
      try {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      } catch (_) {}
    } else {
      final chatState = ref.read(chatProvider);
      if (chatState.messages.isEmpty) return;
      if (!_itemScrollController.isAttached) return;
      _itemScrollController.scrollTo(
        index: chatState.messages.length - 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final authState = ref.watch(authProvider);

    ref.listen<ChatState>(chatProvider, (prev, next) {
      if (!next.isLoadingMessages &&
          next.messages.isNotEmpty &&
          !_initialScrollDone) {
        _scrollRetries = 0;
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToTarget());
      }

      if (_isNearBottom &&
          next.messages.isNotEmpty &&
          prev != null &&
          !prev.isLoadingMessages &&
          next.messages.length > prev.messages.length) {
        _prevMessageCount = next.messages.length;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (kIsWeb) {
            if (_scrollController.hasClients) {
              try {
                _scrollController.animateTo(
                  _scrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                );
              } catch (_) {}
            }
          } else {
            if (_itemScrollController.isAttached) {
              _itemScrollController.scrollTo(
                index: next.messages.length - 1,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
              );
            }
          }
        });
      } else if (next.messages.isNotEmpty) {
        _prevMessageCount = next.messages.length;
      }
    });

    final currentChat = chatState.chats
        .where((c) => c.id == widget.chatId)
        .firstOrNull;

    final contactsState = ref.watch(contactsProvider);
    final contactAvatar =
        currentChat != null &&
            currentChat.type == 'personal' &&
            currentChat.avatarUrl.isEmpty
        ? _findContactAvatar(contactsState.contacts, currentChat.name)
        : null;

    final displayAvatar =
        currentChat != null && currentChat.avatarUrl.isNotEmpty
        ? currentChat.avatarUrl
        : contactAvatar;

    final chat = chatState.chats.where((c) => c.id == widget.chatId).toList();
    final unreadCount = chat.isNotEmpty ? chat.first.unreadCount : 0;
    final chatName = currentChat?.name ?? 'Chat';
    final background = ref.watch(chatBackgroundProvider);
    final backgroundFill = ref.watch(chatBackgroundFillProvider);

    return Scaffold(
      appBar: _isSelectionMode
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(_selectedIds.clear),
              ),
              title: Text('${_selectedIds.length} selected'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.reply_outlined),
                  tooltip: 'Quote',
                  onPressed: _selectedIds.isNotEmpty
                      ? () => _quoteMessages(_selectedIds.toList())
                      : null,
                ),
                IconButton(
                  icon: const Icon(Icons.forward_outlined),
                  tooltip: 'Forward',
                  onPressed: _selectedIds.isNotEmpty ? _forwardSelected : null,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete',
                  onPressed: _deleteSelected,
                ),
              ],
            )
          : AppBar(
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
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    backgroundImage:
                        displayAvatar != null && displayAvatar.isNotEmpty
                        ? NetworkImage(displayAvatar)
                        : null,
                    child: (displayAvatar == null || displayAvatar.isEmpty)
                        ? Text(
                            chatName.isNotEmpty
                                ? chatName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
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
                          chatName,
                          style: const TextStyle(fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (chatState.typingUsers.isNotEmpty)
                          Text(
                            'typing...',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
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
                  onPressed: () =>
                      context.push('/chats/${widget.chatId}/gallery'),
                ),
                if (currentChat == null || currentChat.type == 'personal')
                  IconButton(
                    icon: const Icon(Icons.videocam_outlined),
                    onPressed: () => _startCall('video'),
                  ),
                if (currentChat == null || currentChat.type == 'personal')
                  IconButton(
                    icon: const Icon(Icons.call_outlined),
                    onPressed: () => _startCall('audio'),
                  ),
                if (currentChat != null && currentChat.type != 'personal')
                  IconButton(
                    icon: const Icon(Icons.videocam_outlined),
                    onPressed: () => _startGroupCall('video'),
                  ),
                if (currentChat != null && currentChat.type != 'personal')
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
      body: Stack(
        children: [
          Positioned.fill(
            child: ChatBackgroundView(
              background: background,
              fill: backgroundFill,
              child: Column(
                children: [
                  Expanded(
                    child: chatState.isLoadingMessages
                        ? const Center(child: CircularProgressIndicator())
                        : _buildMessageList(
                            chatState,
                            authState,
                            contactsState,
                          ),
                  ),
                  MessageInput(
                    onSend: (content) => _sendMessage(content),
                    onSendFile: (filename, mimeType, bytes) =>
                        _sendFile(filename, mimeType, bytes),
                    onTypingStart: () => ref
                        .read(chatProvider.notifier)
                        .sendTypingStart(widget.chatId),
                    onTypingStop: () => ref
                        .read(chatProvider.notifier)
                        .sendTypingStop(widget.chatId),
                    editingMessage: _editingMessageId != null
                        ? ref
                              .read(chatProvider)
                              .messages
                              .where((m) => m.id == _editingMessageId)
                              .firstOrNull
                        : null,
                    onCancelEdit: () =>
                        setState(() => _editingMessageId = null),
                    quotedMessages: _quotedMessages,
                    onCancelQuote: () => setState(() => _quotedMessages = []),
                  ),
                ],
              ),
            ),
          ),
          if (!_isNearBottom)
            Positioned(
              right: 16,
              bottom: 80,
              child: FloatingActionButton.small(
                onPressed: _scrollToBottom,
                elevation: 4,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.keyboard_arrow_down, size: 28),
                    if (unreadCount > 0)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          child: Text(
                            '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    final la = a.toLocal();
    final lb = b.toLocal();
    return la.year == lb.year && la.month == lb.month && la.day == lb.day;
  }

  Widget _buildDayChip(DateTime date) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _formatDayLabel(date),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  String _formatDayLabel(DateTime date) {
    final local = date.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Сегодня';
    if (diff == 1) return 'Вчера';
    return '${local.day} ${_ruMonths[local.month - 1]} ${local.year}';
  }

  Widget _buildMessageList(
    ChatState chatState,
    AuthState authState,
    ContactsState contactsState,
  ) {
    if (kIsWeb) {
      return _buildWebList(chatState, authState, contactsState);
    }
    return _buildNativeList(chatState, authState, contactsState);
  }

  Widget _buildWebList(
    ChatState chatState,
    AuthState authState,
    ContactsState contactsState,
  ) {
    final contactAvatars = <String, String>{};
    for (final c in contactsState.contacts) {
      if (c.avatarUrl != null && c.avatarUrl!.isNotEmpty) {
        contactAvatars[c.displayName] = c.avatarUrl!;
      }
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      itemCount: chatState.messages.length + (chatState.isLoadingOlder ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == chatState.messages.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final msg = chatState.messages[index];
        final isMe = msg.senderId == authState.user?.id;
        final showSender =
            !isMe &&
            (index == 0 ||
                chatState.messages[index - 1].senderId != msg.senderId);
        final quotedMessage = _resolveQuoted(msg, chatState);
        final showDayChip =
            index == 0 ||
            !_isSameDay(chatState.messages[index - 1].createdAt, msg.createdAt);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showDayChip) _buildDayChip(msg.createdAt),
            GestureDetector(
              child: MessageBubble(
                message: msg,
                isMe: isMe,
                showSender: showSender,
                contactAvatars: contactAvatars,
                isSelected: _selectedIds.contains(msg.id),
                selectionMode: _isSelectionMode,
                onTap: _isSelectionMode ? () => _toggleSelection(msg.id) : null,
                onSelect: () {
                  _onMessageLongPress(msg.id);
                },
                onEdit: isMe ? () => _startEdit(msg.id) : null,
                onDelete: () => _deleteMessage(msg.id),
                onReact: (emoji) => _addReaction(msg.id, emoji),
                onForward: () => _forwardMessage(msg.id),
                onTapImage: msg.type == 'image' && msg.fileUrl.isNotEmpty
                    ? () => _openImage(msg)
                    : null,
                quotedMessage: quotedMessage,
              ),
            ),
          ],
        );
      },
    );
  }

  ChatMessage? _resolveQuoted(ChatMessage msg, ChatState state) {
    if (msg.replyTo.isEmpty) return null;
    final ids = msg.replyToIds;
    if (ids.isEmpty) return null;
    return state.messageCache[ids.first];
  }

  Widget _buildNativeList(
    ChatState chatState,
    AuthState authState,
    ContactsState contactsState,
  ) {
    final contactAvatars = <String, String>{};
    for (final c in contactsState.contacts) {
      if (c.avatarUrl != null && c.avatarUrl!.isNotEmpty) {
        contactAvatars[c.displayName] = c.avatarUrl!;
      }
    }

    return ScrollablePositionedList.builder(
      itemScrollController: _itemScrollController,
      itemPositionsListener: _itemPositionsListener,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      itemCount: chatState.messages.length + (chatState.isLoadingOlder ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == chatState.messages.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final msg = chatState.messages[index];
        final isMe = msg.senderId == authState.user?.id;
        final showSender =
            !isMe &&
            (index == 0 ||
                chatState.messages[index - 1].senderId != msg.senderId);
        final quotedMessage = _resolveQuoted(msg, chatState);
        final showDayChip =
            index == 0 ||
            !_isSameDay(chatState.messages[index - 1].createdAt, msg.createdAt);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showDayChip) _buildDayChip(msg.createdAt),
            GestureDetector(
              child: MessageBubble(
                message: msg,
                isMe: isMe,
                showSender: showSender,
                contactAvatars: contactAvatars,
                isSelected: _selectedIds.contains(msg.id),
                selectionMode: _isSelectionMode,
                onTap: _isSelectionMode ? () => _toggleSelection(msg.id) : null,
                onSelect: () {
                  _onMessageLongPress(msg.id);
                },
                onEdit: isMe ? () => _startEdit(msg.id) : null,
                onDelete: () => _deleteMessage(msg.id),
                onReact: (emoji) => _addReaction(msg.id, emoji),
                onForward: () => _forwardMessage(msg.id),
                onTapImage: msg.type == 'image' && msg.fileUrl.isNotEmpty
                    ? () => _openImage(msg)
                    : null,
                quotedMessage: quotedMessage,
              ),
            ),
          ],
        );
      },
    );
  }

  void _sendMessage(String content) {
    if (_editingMessageId != null) {
      ref
          .read(chatProvider.notifier)
          .editMessage(widget.chatId, _editingMessageId!, content);
      setState(() => _editingMessageId = null);
    } else {
      final replyTo = _replyToParam;
      ref
          .read(chatProvider.notifier)
          .sendMessage(widget.chatId, content, replyTo: replyTo);
      if (replyTo.isNotEmpty) {
        setState(() => _quotedMessages = []);
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _sendFile(String filename, String mimeType, Uint8List bytes) {
    final replyTo = _replyToParam;
    ref
        .read(chatProvider.notifier)
        .sendFile(widget.chatId, filename, mimeType, bytes, replyTo: replyTo);
    if (replyTo.isNotEmpty) {
      setState(() => _quotedMessages = []);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _toggleSelection(String msgId) {
    setState(() {
      if (_selectedIds.contains(msgId)) {
        _selectedIds.remove(msgId);
      } else {
        _selectedIds.add(msgId);
      }
    });
  }

  void _onMessageLongPress(String msgId) {
    if (!_isSelectionMode) {
      setState(() {
        _selectedIds.add(msgId);
      });
    }
  }

  void _quoteMessages(List<String> msgIds) {
    final chatState = ref.read(chatProvider);
    final msgs = msgIds
        .map((id) => chatState.messages.where((m) => m.id == id).firstOrNull)
        .whereType<ChatMessage>()
        .toList();
    if (msgs.isNotEmpty) {
      setState(() {
        _quotedMessages = msgs;
        _selectedIds.clear();
      });
    }
  }

  void _deleteSelected() {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete messages'),
        content: Text('Delete $count message${count > 1 ? 's' : ''}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              for (final id in _selectedIds.toList()) {
                ref
                    .read(chatProvider.notifier)
                    .deleteMessage(widget.chatId, id);
              }
              setState(_selectedIds.clear);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _forwardSelected() {
    if (_selectedIds.isEmpty) return;
    final ids = _selectedIds.toList();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ForwardMessageSheet(sourceChatId: widget.chatId, messageIds: ids),
      ),
    );
    setState(_selectedIds.clear);
  }

  void _startEdit(String msgId) {
    setState(() => _editingMessageId = msgId);
  }

  void _deleteMessage(String msgId) {
    final chatState = ref.read(chatProvider);
    final authState = ref.read(authProvider);
    final currentChat = chatState.chats
        .where((c) => c.id == widget.chatId)
        .firstOrNull;
    final msg = chatState.messages.where((m) => m.id == msgId).firstOrNull;
    if (currentChat == null || msg == null) return;

    final isMe = msg.senderId == authState.user?.id;
    final isGroup =
        currentChat.type == 'group' || currentChat.type == 'channel';

    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Delete Message'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(context);
              ref
                  .read(chatProvider.notifier)
                  .deleteMessage(widget.chatId, msgId, mode: 'me');
            },
            child: const Text('Delete for me'),
          ),
          if (isMe)
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context);
                if (isGroup) {
                  _confirmDeleteForAll(msgId);
                } else {
                  ref
                      .read(chatProvider.notifier)
                      .deleteMessage(widget.chatId, msgId, mode: 'all');
                }
              },
              child: Text(
                isGroup
                    ? 'Delete for everyone'
                    : 'Delete for me and ${currentChat.name}',
              ),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteForAll(String msgId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete for everyone?'),
        content: const Text(
          'This message will be deleted for all members of this chat.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              ref
                  .read(chatProvider.notifier)
                  .deleteMessage(widget.chatId, msgId, mode: 'all');
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
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
      builder: (_) =>
          ForwardMessageSheet(sourceChatId: widget.chatId, messageIds: [msgId]),
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
    final currentChat = chatState.chats
        .where((c) => c.id == widget.chatId)
        .firstOrNull;
    if (currentChat == null) return;

    if (currentChat.type == 'personal') {
      final members = await ref
          .read(chatRepositoryProvider)
          .getMembers(widget.chatId);
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
      await webrtc.startCall(
        otherUserId,
        callType,
        chatId: widget.chatId,
        fromName: authState.user?.displayName ?? authState.user?.username ?? '',
      );
    } catch (e) {
      debugPrint('startCall failed: $e');
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to start call: $e')));
      }
    }
  }

  void _startGroupCall(String callType) async {
    final authState = ref.read(authProvider);
    final currentUserId = authState.user?.id ?? '';
    final userName = authState.user?.username ?? 'User';

    final members = await ref
        .read(chatRepositoryProvider)
        .getMembers(widget.chatId);
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
    final currentChat = chatState.chats
        .where((c) => c.id == widget.chatId)
        .firstOrNull;
    if (currentChat == null) return;

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
