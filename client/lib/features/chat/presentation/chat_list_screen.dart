import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uphone_client/features/auth/domain/auth_provider.dart';
import 'package:uphone_client/features/chat/domain/chat_provider.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(chatProvider.notifier).loadChats());
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final authState = ref.watch(authProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('UPhone'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                ref.read(authProvider.notifier).logout();
                context.go('/login');
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      (authState.user?.displayName ?? 'U')[0].toUpperCase(),
                    ),
                  ),
                  title: Text(authState.user?.displayName ?? ''),
                  subtitle: Text(authState.user?.email ?? ''),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Sign Out'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: chatState.isLoadingChats
          ? const Center(child: CircularProgressIndicator())
          : chatState.chats.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 64,
                        color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No chats yet',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start a conversation',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: chatState.chats.length,
                  itemBuilder: (context, index) {
                    final chat = chatState.chats[index];
                    return ChatTile(
                      chat: chat,
                      currentUserId: authState.user?.id ?? '',
                      onTap: () {
                        ref.read(chatProvider.notifier).openChat(chat.id);
                        context.go('/chats/${chat.id}');
                      },
                    );
                  },
                ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'group',
            onPressed: () => context.go('/chats/create'),
            child: const Icon(Icons.group_add),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'chat',
            onPressed: () => _showNewChatDialog(context),
            child: const Icon(Icons.chat),
          ),
        ],
      ),
    );
  }

  void _showNewChatDialog(BuildContext context) {
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Chat'),
        content: TextField(
          controller: emailController,
          decoration: const InputDecoration(
            labelText: 'User email',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isNotEmpty) {
                await ref.read(chatProvider.notifier).createPersonalChat(email);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

class ChatTile extends StatelessWidget {
  final dynamic chat;
  final String currentUserId;
  final VoidCallback onTap;

  const ChatTile({
    super.key,
    required this.chat,
    required this.currentUserId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final lastMessage = chat.lastMessage;
    final timeStr = lastMessage != null
        ? DateFormat('HH:mm').format(lastMessage.createdAt)
        : '';

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Text(
          chat.name.isNotEmpty
              ? chat.name[0].toUpperCase()
              : '?',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        chat.name.isNotEmpty ? chat.name : 'Chat',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: lastMessage != null
          ? Text(
              lastMessage.isDeleted
                  ? 'Message deleted'
                  : lastMessage.content,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          : Text(
              'No messages yet',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
      trailing: lastMessage != null
          ? Text(
              timeStr,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            )
          : null,
    );
  }
}
