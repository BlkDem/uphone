import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uphone_client/features/admin/domain/admin_provider.dart';
import 'package:uphone_client/shared/models/user.dart';

class AdminPanelScreen extends ConsumerStatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  ConsumerState<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends ConsumerState<AdminPanelScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(adminProvider.notifier).loadUsers());
  }

  @override
  Widget build(BuildContext context) {
    final adminState = ref.watch(adminProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'Add User',
            onPressed: () => _showCreateUserDialog(context),
          ),
        ],
      ),
      body: adminState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : adminState.users.isEmpty
              ? const Center(child: Text('No users'))
              : ListView.builder(
                  itemCount: adminState.users.length,
                  itemBuilder: (context, index) {
                    final user = adminState.users[index];
                    return _UserTile(
                      user: user,
                      onRoleToggle: () {
                        final newRole = user.isAdmin ? 'user' : 'admin';
                        ref.read(adminProvider.notifier).changeUserRole(user.id, newRole);
                      },
                      onChangePassword: () => _showChangePasswordDialog(context, user),
                      onDelete: () => _showDeleteDialog(context, user),
                    );
                  },
                ),
    );
  }

  void _showCreateUserDialog(BuildContext context) {
    final usernameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final displayNameController = TextEditingController();
    bool makeAdmin = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create User'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: usernameController,
                  decoration: const InputDecoration(labelText: 'Username'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: displayNameController,
                  decoration: const InputDecoration(labelText: 'Display Name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  value: makeAdmin,
                  onChanged: (v) => setDialogState(() => makeAdmin = v ?? false),
                  title: const Text('Make Admin'),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final success = await ref.read(adminProvider.notifier).createUser(
                      username: usernameController.text.trim(),
                      email: emailController.text.trim(),
                      password: passwordController.text,
                      displayName: displayNameController.text.trim(),
                      role: makeAdmin ? 'admin' : 'user',
                    );
                if (context.mounted && success) Navigator.pop(context);
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context, User user) {
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Change Password: ${user.displayName}'),
        content: TextField(
          controller: passwordController,
          decoration: const InputDecoration(labelText: 'New Password'),
          obscureText: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final success = await ref
                  .read(adminProvider.notifier)
                  .changeUserPassword(user.id, passwordController.text);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(success ? 'Password updated' : 'Failed')),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, User user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete User'),
        content: Text('Delete ${user.displayName}? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await ref.read(adminProvider.notifier).deleteUser(user.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final User user;
  final VoidCallback onRoleToggle;
  final VoidCallback onChangePassword;
  final VoidCallback onDelete;

  const _UserTile({
    required this.user,
    required this.onRoleToggle,
    required this.onChangePassword,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        child: Text(user.displayName.isNotEmpty
            ? user.displayName[0].toUpperCase()
            : '?'),
      ),
      title: Row(
        children: [
          Flexible(child: Text(user.displayName, overflow: TextOverflow.ellipsis)),
          if (user.isAdmin) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Admin',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(user.email),
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          switch (value) {
            case 'role':
              onRoleToggle();
              break;
            case 'password':
              onChangePassword();
              break;
            case 'delete':
              onDelete();
              break;
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'role',
            child: ListTile(
              leading: Icon(user.isAdmin ? Icons.remove_circle : Icons.admin_panel_settings),
              title: Text(user.isAdmin ? 'Revoke Admin' : 'Make Admin'),
              dense: true,
            ),
          ),
          const PopupMenuItem(
            value: 'password',
            child: ListTile(
              leading: Icon(Icons.lock_reset),
              title: Text('Change Password'),
              dense: true,
            ),
          ),
          PopupMenuItem(
            value: 'delete',
            child: ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              dense: true,
            ),
          ),
        ],
      ),
    );
  }
}
