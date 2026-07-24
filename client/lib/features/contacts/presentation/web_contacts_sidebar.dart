import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uphone_client/features/auth/domain/auth_provider.dart';
import 'package:uphone_client/features/chat/domain/chat_provider.dart';
import 'package:uphone_client/features/chat/presentation/chat_list_screen.dart';

class WebChatSidebar extends ConsumerStatefulWidget {
  const WebChatSidebar({super.key});

  @override
  ConsumerState<WebChatSidebar> createState() => _WebChatSidebarState();
}

class _WebChatSidebarState extends ConsumerState<WebChatSidebar> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(chatProvider.notifier).loadChats());
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final authState = ref.watch(authProvider);

    return Container(
      width: 320,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
            ),
            child: Row(
              children: [
                Icon(Icons.forum_outlined, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Chats',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline, size: 20),
                  tooltip: 'New Chat',
                  onPressed: () => context.push('/chats/create'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: chatState.isLoadingChats
                ? const Center(child: CircularProgressIndicator())
                : chatState.chats.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 48,
                              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No chats yet',
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
                          final isSelected = GoRouterState.of(context).pathParameters['chatId'] == chat.id;
                          return Material(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3)
                                : null,
                            child: ChatTile(
                              chat: chat,
                              currentUserId: authState.user?.id ?? '',
                              contacts: const [],
                              onTap: () {
                                ref.read(chatProvider.notifier).openChat(chat.id);
                                context.go('/chats/${chat.id}');
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
