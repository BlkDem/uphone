import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../domain/auth_provider.dart';
import '../../../core/config/server_config.dart';
import '../../../core/config/remember_me_storage.dart';
import '../../../core/utils/google_sign_in_helper.dart';

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
  bool _rememberMe = false;
  String? _selectedServerId;

  @override
  void initState() {
    super.initState();
    _selectedServerId = ServerConfig.instance.selected.id;
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final saved = await RememberMeStorage.instance.load();
    if (saved != null && mounted) {
      setState(() {
        _rememberMe = true;
        _emailController.text = saved.$1;
        _passwordController.text = saved.$2;
      });
    }
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        onChanged: (v) => setState(() => _rememberMe = v ?? false),
                      ),
                      const Text('Remember me'),
                    ],
                  ),
                  const SizedBox(height: 12),
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
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'or',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  buildGoogleSignInButton(),
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
    final nameCtrl = TextEditingController();
    final hostCtrl = TextEditingController();
    final portCtrl = TextEditingController(text: '8080');
    bool useTls = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Server'),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: hostCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Host',
                    hintText: '192.168.1.18',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: portCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Port',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text('TLS'),
                    const Spacer(),
                    Switch(
                      value: useTls,
                      onChanged: (v) => setDialogState(() => useTls = v),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      final name = nameCtrl.text.trim();
                      final host = hostCtrl.text.trim();
                      final port = int.tryParse(portCtrl.text.trim()) ?? 8080;
                      if (name.isEmpty || host.isEmpty) return;
                      Navigator.pop(ctx);
                      final server = ServerEntry(
                        id: ServerConfig.generateId(),
                        name: name,
                        host: host,
                        port: port,
                        useTls: useTls,
                      );
                      ServerConfig.instance.add(server).then((_) {
                        setState(() => _selectedServerId = server.id);
                        ref.invalidate(apiClientProvider);
                      });
                    },
                    child: const Text('Save'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ),
        ),
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

  void _submit() async {
    if (_formKey.currentState?.validate() ?? false) {
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      if (_rememberMe) {
        await RememberMeStorage.instance.save(email, password);
      } else {
        await RememberMeStorage.instance.clear();
      }

      ref.read(authProvider.notifier).login(
            email: email,
            password: password,
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
    final nameCtrl = TextEditingController();
    final hostCtrl = TextEditingController();
    final portCtrl = TextEditingController(text: '8080');
    bool useTls = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Add Server'),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: hostCtrl, decoration: const InputDecoration(labelText: 'Host', hintText: '192.168.1.18', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: portCtrl, decoration: const InputDecoration(labelText: 'Port', border: OutlineInputBorder()), keyboardType: TextInputType.number),
                const SizedBox(height: 8),
                Row(children: [const Text('TLS'), const Spacer(), Switch(value: useTls, onChanged: (v) => setDialogState(() => useTls = v))]),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      final name = nameCtrl.text.trim();
                      final host = hostCtrl.text.trim();
                      final port = int.tryParse(portCtrl.text.trim()) ?? 8080;
                      if (name.isEmpty || host.isEmpty) return;
                      Navigator.pop(ctx);
                      final server = ServerEntry(id: ServerConfig.generateId(), name: name, host: host, port: port, useTls: useTls);
                      ServerConfig.instance.add(server).then((_) {
                        widget.onSelected(server.id);
                        widget.onChanged?.call();
                      });
                    },
                    child: const Text('Save'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditServer(BuildContext context, ServerEntry server) {
    Navigator.pop(context);
    final nameCtrl = TextEditingController(text: server.name);
    final hostCtrl = TextEditingController(text: server.host);
    final portCtrl = TextEditingController(text: server.port.toString());
    bool useTls = server.useTls;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit Server'),
          content: SingleChildScrollView(
            child: ListBody(
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: hostCtrl, decoration: const InputDecoration(labelText: 'Host', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: portCtrl, decoration: const InputDecoration(labelText: 'Port', border: OutlineInputBorder()), keyboardType: TextInputType.number),
                const SizedBox(height: 8),
                Row(children: [const Text('TLS'), const Spacer(), Switch(value: useTls, onChanged: (v) => setDialogState(() => useTls = v))]),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      final name = nameCtrl.text.trim();
                      final host = hostCtrl.text.trim();
                      final port = int.tryParse(portCtrl.text.trim()) ?? 8080;
                      if (name.isEmpty || host.isEmpty) return;
                      Navigator.pop(ctx);
                      final updated = server.copyWith(name: name, host: host, port: port, useTls: useTls);
                      ServerConfig.instance.update(updated).then((_) => widget.onChanged?.call());
                    },
                    child: const Text('Save'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, ServerEntry server) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete server?'),
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              Text('Remove "${server.name}"?'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await ServerConfig.instance.remove(server.id);
                    widget.onSelected(ServerConfig.instance.selected.id);
                    widget.onChanged?.call();
                  },
                  child: const Text('Delete'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
