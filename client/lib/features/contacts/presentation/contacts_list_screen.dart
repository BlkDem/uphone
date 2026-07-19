import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uphone_client/features/contacts/domain/contacts_provider.dart';
import 'package:uphone_client/features/contacts/presentation/contact_form_screen.dart';

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

  void _editContact(BuildContext context, dynamic contact) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ContactFormScreen(contact: contact),
      ),
    ).then((_) => ref.read(contactsProvider.notifier).refreshContacts());
  }

  void _deleteContact(BuildContext context, dynamic contact) {
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
    // For web: use a text input as import method
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
  final dynamic contact;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ContactTile({
    super.key,
    required this.contact,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Text(
          contact.displayName.isNotEmpty
              ? contact.displayName[0].toUpperCase()
              : '?',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      title: Text(
        contact.displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        contact.email ?? contact.phone ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: PopupMenuButton<String>(
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
    );
  }
}
