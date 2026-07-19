import 'package:flutter/material.dart';
import 'package:google_sign_in_web/google_sign_in_web.dart' as web;
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart'
    show GoogleSignInPlatform;

Widget buildGoogleSignInButton({VoidCallback? onPressed}) {
  final plugin = GoogleSignInPlatform.instance;
  if (plugin is web.GoogleSignInPlugin) {
    return plugin.renderButton();
  }
  return SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.g_mobiledata, size: 24),
      label: const Text('Sign in with Google'),
    ),
  );
}
