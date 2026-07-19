import 'package:flutter/material.dart';

Widget buildGoogleSignInButton({VoidCallback? onPressed}) {
  return SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.g_mobiledata, size: 24),
      label: const Text('Sign in with Google'),
    ),
  );
}
