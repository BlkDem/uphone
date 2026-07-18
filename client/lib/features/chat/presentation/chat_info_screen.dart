import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uphone_client/features/auth/domain/auth_provider.dart';
import 'package:uphone_client/features/chat/domain/chat_provider.dart';

class ChatInfoScreen extends ConsumerStatefulWidget {
  final String chatId;

  const ChatInfoScreen({super.key, required this.chatId});

  @override
  ConsumerState<ChatInfoScreen> createState() => _ChatInfoScreenState();
}

class _ChatInfoScreenState extends ConsumerState<ChatInfoScreen> {
  List<dynamic> _members = [];
  bool _isLoading = true;
  bool _isEditing = false;
  late TextEditingController _nameController;
  late TextEditingController _descController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descController = TextEditingController();
    _loadMembers();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    try {
      final dio = ref.read(apiClientProvider).dio;
      final response = await dio.get('/api/v1/chats/${widget.chatId}/members');
      setState(() {
        _members = response.data as List;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final authState = ref.watch(authProvider);
    final chat = chatState.chats.where((c) => c.id == widget.chatId).firstOrNull;
    final currentUserId = authState.user?.id ?? '';

    if (chat == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final myRole = _members
        .where((m) => m['user_id'] == currentUserId)
        .map((m) => m['role'])
        .firstOrNull;
    final isOwnerOrAdmin = myRole == 'owner' || myRole == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: Text(chat.name.isNotEmpty ? chat.name : 'Chat Info'),
        actions: [
          if (isOwnerOrAdmin)
            IconButton(
              icon: Icon(_isEditing ? Icons.check : Icons.edit),
              onPressed: () {
                if (_isEditing) {
                  _saveChanges(chat);
                } else {
                  _nameController.text = chat.name;
                  _descController.text = chat.description;
                  setState(() => _isEditing = true);
                }
              },
            ),
          if (!isOwnerOrAdmin)
            PopupMenuButton(
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'leave',
                  child: ListTile(
                    leading: Icon(Icons.exit_to_app, color: Colors.red),
                    title: Text('Leave Group', style: TextStyle(color: Colors.red)),
                  ),
                ),
              ],
              onSelected: (v) {
                if (v == 'leave') _leaveChat();
              },
            ),
        ],
      ),
      body: ListView(
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Text(
              chat.name.isNotEmpty ? chat.name[0].toUpperCase() : '?',
              style: TextStyle(
                fontSize: 36,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_isEditing) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
            ),
          ] else ...[
            Center(
              child: Text(
                chat.name.isNotEmpty ? chat.name : 'No name',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            if (chat.description.isNotEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    chat.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text('Members', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Text('${_members.length}', style: Theme.of(context).textTheme.bodyMedium),
                if (isOwnerOrAdmin) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.person_add),
                    onPressed: () => _showAddMemberDialog(),
                  ),
                ],
              ],
            ),
          ),
          const Divider(),
          if (_isLoading)
            const Center(child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ))
          else
            ..._members.map((member) => _buildMemberTile(member, myRole, currentUserId)),
        ],
      ),
    );
  }

  Widget _buildMemberTile(dynamic member, String? myRole, String currentUserId) {
    final role = member['role'] as String? ?? 'member';
    final isMe = member['user_id'] == currentUserId;

    return ListTile(
      leading: CircleAvatar(
        child: Text((member['username'] ?? '?')[0].toUpperCase()),
      ),
      title: Text(
        '${member['username'] ?? ''} ${isMe ? "(You)" : ""}',
      ),
      subtitle: Text(role.toUpperCase()),
      trailing: (myRole == 'owner' && role != 'owner')
          ? IconButton(
              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
              onPressed: () => _removeMember(member['user_id']),
            )
          : null,
    );
  }

  void _showAddMemberDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Member'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Username or email'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final query = controller.text.trim();
              if (query.isNotEmpty) {
                await _addMemberByQuery(query);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _addMemberByQuery(String query) async {
    try {
      final dio = ref.read(apiClientProvider).dio;
      final searchRes = await dio.get('/api/v1/users/search', queryParameters: {'q': query});
      final users = searchRes.data as List;
      if (users.isNotEmpty) {
        await dio.post('/api/v1/chats/${widget.chatId}/members', data: {
          'user_id': users[0]['id'],
        });
        _loadMembers();
      }
    } catch (_) {}
  }

  Future<void> _removeMember(String userId) async {
    try {
      final dio = ref.read(apiClientProvider).dio;
      await dio.delete('/api/v1/chats/${widget.chatId}/members/$userId');
      _loadMembers();
    } catch (_) {}
  }

  Future<void> _leaveChat() async {
    try {
      final dio = ref.read(apiClientProvider).dio;
      await dio.post('/api/v1/chats/${widget.chatId}/leave');
      ref.read(chatProvider.notifier).loadChats();
      if (mounted) context.go('/chats');
    } catch (_) {}
  }

  Future<void> _saveChanges(dynamic chat) async {
    try {
      final dio = ref.read(apiClientProvider).dio;
      await dio.put('/api/v1/chats/${widget.chatId}', data: {
        'name': _nameController.text.trim(),
        'description': _descController.text.trim(),
      });
      setState(() => _isEditing = false);
      ref.read(chatProvider.notifier).loadChats();
    } catch (_) {}
  }
}
