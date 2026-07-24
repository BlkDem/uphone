import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:uphone_client/features/contacts/presentation/web_contacts_sidebar.dart';

class WebShellScreen extends StatelessWidget {
  final Widget child;

  const WebShellScreen({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;

    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const WebChatSidebar(),
          Expanded(child: child),
        ],
      ),
    );
  }
}
