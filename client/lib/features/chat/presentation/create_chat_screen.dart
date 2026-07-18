import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uphone_client/features/auth/domain/auth_provider.dart';
import 'package:uphone_client/features/chat/domain/chat_provider.dart';

class CreateChatScreen extends ConsumerStatefulWidget {
  const CreateChatScreen({super.key});

  @override
  ConsumerState<CreateChatScreen> createState() => _CreateChatScreenState();
}

class _CreateChatScreenState extends ConsumerState<CreateChatScreen> {
  final _nameController = TextEditingController();
  String _chatType = 'group';
  final List<String> _selectedUsers = [];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_chatType == 'group' ? 'New Group' : 'New Channel'),
        actions: [
          TextButton(
            onPressed: _selectedUsers.isEmpty ? null : _create,
            child: const Text('Create'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'group', label: Text('Group'), icon: Icon(Icons.group)),
                    ButtonSegment(value: 'channel', label: Text('Channel'), icon: Icon(Icons.campaign)),
                  ],
                  selected: {_chatType},
                  onSelectionChanged: (v) => setState(() => _chatType = v.first),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: _chatType == 'group' ? 'Group Name' : 'Channel Name',
                    hintText: _chatType == 'group' ? 'My Group' : 'My Channel',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _chatType == 'channel'
                      ? 'Channels are public. Anyone can view messages.'
                      : 'Groups are private. Only members can see messages.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  'Add members',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                Text(
                  '${_selectedUsers.length} selected',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _UserSearchList(
              selectedUsers: _selectedUsers,
              onToggle: (userId) {
                setState(() {
                  if (_selectedUsers.contains(userId)) {
                    _selectedUsers.remove(userId);
                  } else {
                    _selectedUsers.add(userId);
                  }
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  void _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    await ref.read(chatProvider.notifier).createGroupChat(
          name: name,
          type: _chatType,
          members: _selectedUsers,
        );

    if (mounted) {
      context.go('/chats');
    }
  }
}

class _UserSearchList extends ConsumerStatefulWidget {
  final List<String> selectedUsers;
  final Function(String) onToggle;

  const _UserSearchList({
    required this.selectedUsers,
    required this.onToggle,
  });

  @override
  ConsumerState<_UserSearchList> createState() => _UserSearchListState();
}

class _UserSearchListState extends ConsumerState<_UserSearchList> {
  final _searchController = TextEditingController();
  List<dynamic> _results = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.length < 2) {
      setState(() => _results = []);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final dio = ref.read(apiClientProvider).dio;
      final response = await dio.get('/api/v1/users/search', queryParameters: {'q': query});
      setState(() {
        _results = response.data as List;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              hintText: 'Search users...',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: _search,
          ),
        ),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: CircularProgressIndicator(),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: _results.length,
            itemBuilder: (context, index) {
              final user = _results[index];
              final userId = user['id'] as String;
              final isSelected = widget.selectedUsers.contains(userId);

              return ListTile(
                leading: CircleAvatar(
                  child: Text((user['username'] ?? '?')[0].toUpperCase()),
                ),
                title: Text(user['display_name'] ?? user['username'] ?? ''),
                subtitle: Text(user['email'] ?? ''),
                trailing: Checkbox(
                  value: isSelected,
                  onChanged: (_) => widget.onToggle(userId),
                ),
                onTap: () => widget.onToggle(userId),
              );
            },
          ),
        ),
      ],
    );
  }
}
