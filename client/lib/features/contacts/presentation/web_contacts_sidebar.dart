import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uphone_client/features/auth/domain/auth_provider.dart';
import 'package:uphone_client/features/chat/domain/chat_provider.dart';
import 'package:uphone_client/features/chat/presentation/chat_list_screen.dart';
import 'package:uphone_client/features/contacts/domain/contacts_provider.dart';
import 'package:uphone_client/features/contacts/presentation/contact_form_screen.dart';
import 'package:uphone_client/core/theme/chat_background.dart';
import 'package:uphone_client/core/config/app_providers.dart';

class WebChatSidebar extends ConsumerStatefulWidget {
  const WebChatSidebar({super.key});

  @override
  ConsumerState<WebChatSidebar> createState() => _WebChatSidebarState();
}

class _WebChatSidebarState extends ConsumerState<WebChatSidebar> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(chatProvider.notifier).loadChats();
      ref.read(contactsProvider.notifier).loadContacts();
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final authState = ref.watch(authProvider);
    final background = ref.watch(chatBackgroundProvider);

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
                  icon: const Icon(Icons.people_outline, size: 20),
                  tooltip: 'Contacts',
                  onPressed: () => _showContactsPanel(context),
                ),
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline, size: 20),
                  tooltip: 'New Chat',
                  onPressed: () => context.push('/chats/create'),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Menu',
                  onSelected: (value) {
                    switch (value) {
                      case 'settings':
                        context.push('/settings');
                        break;
                      case 'profile':
                        context.push('/settings/profile');
                        break;
                      case 'logout':
                        ref.read(authProvider.notifier).logout();
                        context.go('/login');
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'profile',
                      child: ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 16,
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
                      value: 'settings',
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.settings, size: 20),
                        title: Text('Settings'),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'logout',
                      child: ListTile(
                        dense: true,
                        leading: Icon(Icons.logout, size: 20),
                        title: Text('Sign Out'),
                      ),
                    ),
                  ],
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Text(
                      (authState.user?.displayName ?? 'U')[0].toUpperCase(),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ChatBackgroundView(
              background: background,
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
                                context.go('/chats/${chat.id}');
                              },
                            ),
                          );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  void _showContactsPanel(BuildContext context) {
    final contactsState = ref.read(contactsProvider);
    final authState = ref.read(authProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contacts'),
        content: SizedBox(
          width: 350,
          height: 400,
          child: Column(
            children: [
              Expanded(
                child: contactsState.contacts.isEmpty
                    ? const Center(child: Text('No contacts'))
                    : ListView.builder(
                        itemCount: contactsState.contacts.length,
                        itemBuilder: (context, index) {
                          final c = contactsState.contacts[index];
                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 18,
                              backgroundImage: c.avatarUrl != null && c.avatarUrl!.isNotEmpty
                                  ? NetworkImage(c.avatarUrl!)
                                  : null,
                              child: c.avatarUrl == null || c.avatarUrl!.isEmpty
                                  ? Text(c.displayName.isNotEmpty ? c.displayName[0].toUpperCase() : '?')
                                  : null,
                            ),
                            title: Text(c.displayName),
                            subtitle: Text(c.email ?? ''),
                            onTap: () async {
                              Navigator.pop(context);
                              try {
                                await ref.read(chatProvider.notifier).createPersonalChat(c.email ?? '');
                                if (context.mounted) {
                                  final chats = ref.read(chatProvider).chats;
                                  if (chats.isNotEmpty) {
                                    context.go('/chats/${chats.last.id}');
                                  }
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed to start chat: $e')),
                                  );
                                }
                              }
                            },
                          );
                        },
                      ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.person_add, size: 18),
                    label: const Text('Add Contact'),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ContactFormScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
