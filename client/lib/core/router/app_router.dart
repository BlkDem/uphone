import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uphone_client/features/auth/domain/auth_provider.dart';
import 'package:uphone_client/features/auth/presentation/login_screen.dart';
import 'package:uphone_client/features/auth/presentation/register_screen.dart';
import 'package:uphone_client/features/chat/presentation/chat_list_screen.dart';
import 'package:uphone_client/features/chat/presentation/chat_screen.dart';
import 'package:uphone_client/features/chat/presentation/chat_info_screen.dart';
import 'package:uphone_client/features/chat/presentation/create_chat_screen.dart';

final navigatorKeyProvider = Provider<GlobalKey<NavigatorState>>((ref) {
  return GlobalKey<NavigatorState>();
});

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);
  final navKey = ref.watch(navigatorKeyProvider);

  return GoRouter(
    navigatorKey: navKey,
    initialLocation: '/login',
    redirect: (context, state) {
      final isLoggedIn = authState.status == AuthStatus.authenticated;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register';

      if (!isLoggedIn && !isAuthRoute) {
        return '/login';
      }
      if (isLoggedIn && isAuthRoute) {
        return '/chats';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/chats',
        builder: (context, state) => const ChatListScreen(),
      ),
      GoRoute(
        path: '/chats/create',
        builder: (context, state) => const CreateChatScreen(),
      ),
      GoRoute(
        path: '/chats/:chatId',
        builder: (context, state) => ChatScreen(
          chatId: state.pathParameters['chatId']!,
        ),
      ),
      GoRoute(
        path: '/chats/:chatId/info',
        builder: (context, state) => ChatInfoScreen(
          chatId: state.pathParameters['chatId']!,
        ),
      ),
    ],
  );
});
