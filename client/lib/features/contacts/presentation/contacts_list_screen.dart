import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uphone_client/features/auth/domain/auth_provider.dart';
import 'package:uphone_client/features/calls/domain/call_provider.dart';
import 'package:uphone_client/features/calls/presentation/call_screen.dart';
import 'package:uphone_client/features/chat/domain/chat_provider.dart';
import 'package:uphone_client/features/contacts/domain/contacts_provider.dart';
import 'package:uphone_client/features/contacts/presentation/contact_form_screen.dart';
import 'package:uphone_client/shared/models/contact.dart';

class ContactsListScreen extends ConsumerStatefulWidget {
  const ContactsListScreen({super.key});

  @override
  ConsumerState<ContactsListScreen> createState() => _ContactsListScreenState();
}

class _ContactsListScreenState extends ConsumerState<ContactsListScreen> {
  final _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(contactsProvider.notifier).loadContacts());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contactsState = ref.watch(contactsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/chats'),
        ),
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search contacts...',
                  border: InputBorder.none,
                ),
                onChanged: (q) {
                  ref.read(contactsProvider.notifier).loadContacts(query: q);
                },
              )
            : const Text('Contacts'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  ref.read(contactsProvider.notifier).loadContacts();
                }
              });
            },
          ),
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'import_vcard',
                child: ListTile(
                  leading: Icon(Icons.upload),
                  title: Text('Import vCard'),
                ),
              ),
              const PopupMenuItem(
                value: 'import_csv',
                child: ListTile(
                  leading: Icon(Icons.upload),
                  title: Text('Import CSV'),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'export_vcard',
                child: ListTile(
                  leading: Icon(Icons.download),
                  title: Text('Export vCard'),
                ),
              ),
              const PopupMenuItem(
                value: 'export_csv',
                child: ListTile(
                  leading: Icon(Icons.download),
                  title: Text('Export CSV'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: contactsState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : contactsState.contacts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_add_outlined,
                        size: 64,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No contacts yet',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add contacts to start chatting',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: contactsState.contacts.length,
                  itemBuilder: (context, index) {
                    final contact = contactsState.contacts[index];
                    return ContactTile(
                      contact: contact,
                      onEdit: () => _editContact(context, contact),
                      onDelete: () => _deleteContact(context, contact),
                      onChat: () => _startChat(contact),
                      onCall: () => _startCall(contact, false),
                      onVideoCall: () => _startCall(contact, true),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addContact(context),
        child: const Icon(Icons.person_add),
      ),
    );
  }

  void _addContact(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ContactFormScreen(),
      ),
    ).then((_) => ref.read(contactsProvider.notifier).refreshContacts());
  }

  void _editContact(BuildContext context, Contact contact) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ContactFormScreen(contact: contact),
      ),
    ).then((_) => ref.read(contactsProvider.notifier).refreshContacts());
  }

  void _deleteContact(BuildContext context, Contact contact) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Contact'),
        content: Text('Delete "${contact.displayName}"?'),
        actions: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(ctx);
                ref.read(contactsProvider.notifier).deleteContact(contact.id);
              },
              child: const Text('Delete'),
            ),
          ),
        ],
      ),
    );
  }

  void _startChat(Contact contact) async {
    if (contact.email == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contact has no email to start a chat')),
        );
      }
      return;
    }
    final chat = await ref.read(chatProvider.notifier).createPersonalChat(contact.email!);
    if (mounted && chat != null) {
      context.go('/chats/${chat.id}');
    }
  }

  void _startCall(Contact contact, bool isVideo) async {
    if (contact.email == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contact has no email to call')),
        );
      }
      return;
    }
    final chat = await ref.read(chatProvider.notifier).createPersonalChat(contact.email!);
    if (chat == null || !mounted) return;

    final authState = ref.read(authProvider);
    final currentUserId = authState.user?.id ?? '';

    String otherUserId = '';
    String otherUserName = contact.displayName;

    try {
      final members = await ref.read(chatRepositoryProvider).getMembers(chat.id);
      for (final m in members) {
        final uid = m['user_id'] as String? ?? '';
        if (uid != currentUserId && uid.isNotEmpty) {
          otherUserId = uid;
          otherUserName = m['username'] as String? ?? contact.displayName;
          break;
        }
      }
    } catch (e) {
      debugPrint('Failed to get chat members: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to start call')),
        );
      }
      return;
    }

    if (otherUserId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not find user to call')),
        );
      }
      return;
    }

    final callType = isVideo ? 'video' : 'audio';
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
      await webrtc.startCall(otherUserId, callType, chatId: chat.id);
    } catch (e) {
      debugPrint('startCall failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start call: $e')),
        );
      }
    }
  }

  void _handleMenuAction(String action) async {
    final notifier = ref.read(contactsProvider.notifier);

    switch (action) {
      case 'import_vcard':
        _showImportDialog(context, 'vcard');
        break;
      case 'import_csv':
        _showImportDialog(context, 'csv');
        break;
      case 'export_vcard':
        final data = await notifier.exportContacts(format: 'vcard');
        if (data != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contacts exported as vCard')),
          );
        }
        break;
      case 'export_csv':
        final data = await notifier.exportContacts(format: 'csv');
        if (data != null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contacts exported as CSV')),
          );
        }
        break;
    }
  }

  void _showImportDialog(BuildContext context, String format) async {
    final notifier = ref.read(contactsProvider.notifier);
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Import ${format.toUpperCase()}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              format == 'vcard'
                  ? 'Paste vCard data below:'
                  : 'Paste CSV data below (header: display_name,email,phone,notes):',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 8,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Paste data here...',
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Import'),
            ),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final bytes = Uint8List.fromList(result.codeUnits);
      final count = await notifier.importContacts(bytes, format: format);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported $count contacts')),
        );
      }
    }
  }
}

class ContactTile extends StatelessWidget {
  final Contact contact;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onChat;
  final VoidCallback onCall;
  final VoidCallback onVideoCall;

  const ContactTile({
    super.key,
    required this.contact,
    required this.onEdit,
    required this.onDelete,
    required this.onChat,
    required this.onCall,
    required this.onVideoCall,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: theme.colorScheme.primaryContainer,
              backgroundImage: contact.avatarUrl != null && contact.avatarUrl!.isNotEmpty
                  ? NetworkImage(contact.avatarUrl!)
                  : null,
              child: (contact.avatarUrl == null || contact.avatarUrl!.isEmpty)
                  ? Text(
                      contact.displayName.isNotEmpty
                          ? contact.displayName[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
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
                    contact.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  if (contact.email != null || contact.phone != null)
                    Text(
                      contact.email ?? contact.phone ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline, size: 20),
              tooltip: 'Chat',
              onPressed: onChat,
              color: theme.colorScheme.primary,
            ),
            IconButton(
              icon: const Icon(Icons.phone_outlined, size: 20),
              tooltip: 'Call',
              onPressed: onCall,
              color: theme.colorScheme.primary,
            ),
            IconButton(
              icon: const Icon(Icons.videocam_outlined, size: 20),
              tooltip: 'Video Call',
              onPressed: onVideoCall,
              color: theme.colorScheme.primary,
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') onEdit();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
