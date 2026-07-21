import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'core/config/server_config.dart';
import 'core/notifications/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'features/calls/presentation/incoming_call_listener.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ServerConfig.instance.load();
  GoogleSignIn.instance.initialize();
  try {
    await Firebase.initializeApp();
    NotificationService.instance.initialize();
  } catch (e) {
    debugPrint('Firebase init failed (notifications disabled): $e');
  }
  runApp(const ProviderScope(child: UPhoneApp()));
}

class UPhoneApp extends ConsumerWidget {
  const UPhoneApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'UPhone',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
      builder: (context, child) => IncomingCallListener(child: child ?? const SizedBox()),
    );
  }
}
