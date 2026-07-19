import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/auth_provider.dart';
import '../../../core/config/server_config.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _selectedServerId;

  @override
  void initState() {
    super.initState();
    _selectedServerId = ServerConfig.instance.selected.id;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.status == AuthStatus.authenticated) {
        context.go('/chats');
      }
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: Colors.red),
        );
      }
    });

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.chat_rounded,
                    size: 72,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'UPhone',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to continue',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 32),
                  _buildServerSelector(context),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Enter your email';
                      }
                      if (!value.contains('@')) {
                        return 'Enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Enter your password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: authState.status == AuthStatus.loading
                        ? null
                        : _submit,
                    child: authState.status == AuthStatus.loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Sign In'),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.go('/register'),
                    child: const Text("Don't have an account? Sign Up"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServerSelector(BuildContext context) {
    final servers = ServerConfig.instance.servers;
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            Icon(Icons.dns_outlined, size: 20, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedServerId,
                  isExpanded: true,
                  items: servers.map((s) {
                    return DropdownMenuItem(
                      value: s.id,
                      child: Text(
                        s.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (id) async {
                    if (id == null) return;
                    await ServerConfig.instance.select(id);
                    setState(() => _selectedServerId = id);
                    ref.invalidate(apiClientProvider);
                  },
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Add server',
              onPressed: () => _showAddServer(context),
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Manage servers',
              onPressed: () => _showServerDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddServer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AddEditServerSheet(
        onSave: (server) async {
          await ServerConfig.instance.add(server);
          setState(() => _selectedServerId = server.id);
          ref.invalidate(apiClientProvider);
        },
      ),
    );
  }

  void _showServerDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ServerSheet(
        onSelected: (id) async {
          await ServerConfig.instance.select(id);
          setState(() => _selectedServerId = id);
          ref.invalidate(apiClientProvider);
        },
        onChanged: () => setState(() {}),
      ),
    );
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      ref.read(authProvider.notifier).login(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
    }
  }
}

class _ServerSheet extends ConsumerStatefulWidget {
  final void Function(String id) onSelected;
  final VoidCallback? onChanged;

  const _ServerSheet({required this.onSelected, this.onChanged});

  @override
  ConsumerState<_ServerSheet> createState() => _ServerSheetState();
}

class _ServerSheetState extends ConsumerState<_ServerSheet> {
  @override
  Widget build(BuildContext context) {
    final servers = ServerConfig.instance.servers;
    final selected = ServerConfig.instance.selected;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Servers',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add'),
                onPressed: () => _showAddServer(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...servers.map((s) {
            final isSelected = s.id == selected.id;
            return Card(
              child: ListTile(
                leading: Icon(
                  Icons.dns,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                title: Text(s.name),
                subtitle: Text(s.apiBaseUrl),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected)
                      Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary),
                    if (s.id != 'default') ...[
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        tooltip: 'Edit',
                        onPressed: () => _showEditServer(context, s),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        tooltip: 'Delete',
                        onPressed: () => _confirmDelete(context, s),
                      ),
                    ],
                  ],
                ),
                onTap: () {
                  widget.onSelected(s.id);
                  Navigator.pop(context);
                },
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showAddServer(BuildContext context) {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AddEditServerSheet(
        onSave: (server) async {
          await ServerConfig.instance.add(server);
          widget.onSelected(server.id);
          widget.onChanged?.call();
        },
      ),
    );
  }

  void _showEditServer(BuildContext context, ServerEntry server) {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _AddEditServerSheet(
        server: server,
        onSave: (updated) async {
          await ServerConfig.instance.update(updated);
          widget.onChanged?.call();
        },
        onDelete: () async {
          await ServerConfig.instance.remove(server.id);
          widget.onSelected(ServerConfig.instance.selected.id);
          widget.onChanged?.call();
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, ServerEntry server) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete server?'),
        content: Text('Remove "${server.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await ServerConfig.instance.remove(server.id);
              widget.onSelected(ServerConfig.instance.selected.id);
              widget.onChanged?.call();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _AddEditServerSheet extends StatefulWidget {
  final ServerEntry? server;
  final void Function(ServerEntry server) onSave;
  final VoidCallback? onDelete;

  const _AddEditServerSheet({
    this.server,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<_AddEditServerSheet> createState() => _AddEditServerSheetState();
}

class _AddEditServerSheetState extends State<_AddEditServerSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _hostController;
  late final TextEditingController _portController;
  late bool _useTls;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.server?.name ?? '');
    _hostController = TextEditingController(text: widget.server?.host ?? '');
    _portController = TextEditingController(
        text: (widget.server?.port ?? 8080).toString());
    _useTls = widget.server?.useTls ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.server == null ? 'Add Server' : 'Edit Server',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                prefixIcon: Icon(Icons.label_outline),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _hostController,
              decoration: const InputDecoration(
                labelText: 'Host',
                hintText: '192.168.1.18',
                prefixIcon: Icon(Icons.language),
              ),
              keyboardType: TextInputType.url,
              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _portController,
                    decoration: const InputDecoration(
                      labelText: 'Port',
                      prefixIcon: Icon(Icons.numbers),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      final n = int.tryParse(v.trim());
                      if (n == null || n < 1 || n > 65535) return 'Invalid port';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SwitchListTile(
                    title: const Text('TLS'),
                    value: _useTls,
                    onChanged: (v) => setState(() => _useTls = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (widget.onDelete != null)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                    onPressed: widget.onDelete,
                  ),
                const Spacer(),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _save,
                  child: const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final port = int.tryParse(_portController.text.trim()) ?? 8080;
    final server = ServerEntry(
      id: widget.server?.id ?? ServerConfig.generateId(),
      name: _nameController.text.trim(),
      host: _hostController.text.trim(),
      port: port,
      useTls: _useTls,
    );
    widget.onSave(server);
    Navigator.pop(context);
  }
}
