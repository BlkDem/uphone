import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'core/config/server_config.dart';
import 'core/config/app_settings.dart';
import 'core/notifications/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'features/auth/domain/auth_provider.dart';
import 'features/calls/presentation/incoming_call_listener.dart';

final themeModeProvider = StateProvider<ThemeMode>((ref) => AppSettings.instance.themeMode);
final chatFontSizeProvider = StateProvider<double>((ref) => AppSettings.instance.chatFontSize);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ServerConfig.instance.load();
  await AppSettings.getInstance();
  GoogleSignIn.instance.initialize();
  try {
    await Firebase.initializeApp();
    NotificationService.instance.initialize();
  } catch (e) {
    debugPrint('Firebase init failed (notifications disabled): $e');
  }

  final container = ProviderContainer();
  await container.read(authProvider.notifier).restoreSession();

  runApp(UncontrolledProviderScope(
    container: container,
    child: const UPhoneApp(),
  ));
}

class UPhoneApp extends ConsumerStatefulWidget {
  const UPhoneApp({super.key});

  @override
  ConsumerState<UPhoneApp> createState() => _UPhoneAppState();
}

class _UPhoneAppState extends ConsumerState<UPhoneApp> {
  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'UPhone',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) => IncomingCallListener(child: child ?? const SizedBox()),
    );
  }
}
