import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/calls/voice_call_screen.dart';
import '../screens/calls/video_call_screen.dart';
import '../screens/settings/settings_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: false,
    redirect: _authGuard,
    routes: _routes,
  );
});

String? _authGuard(BuildContext context, GoRouterState state) {
  final user = Supabase.instance.client.auth.currentUser;
  final isAuthenticated = user != null;

  const publicRoutes = {'/', '/login', '/signup', '/profile-setup'};

  final loc = state.matchedLocation;
  final isPublic = publicRoutes.any((r) => loc.startsWith(r));

  if (!isAuthenticated && !isPublic) return '/login';
  return null;
}

CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 150),
    reverseTransitionDuration: const Duration(milliseconds: 100),
    transitionsBuilder: (_, animation, __, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    ),
  );
}

final List<RouteBase> _routes = [
  GoRoute(
    path: '/',
    redirect: (_, __) => '/login',
  ),
  GoRoute(
    path: '/login',
    pageBuilder: (_, state) => _fadePage(state, const LoginScreen()),
  ),
  GoRoute(
    path: '/signup',
    pageBuilder: (_, state) => _fadePage(state, const SignupScreen()),
  ),
  GoRoute(
    path: '/profile-setup',
    pageBuilder: (_, state) => _fadePage(state, const SizedBox()),
    redirect: (_, __) {
      final email = Supabase.instance.client.auth.currentUser?.email ?? '';
      return '/profile-setup?email=$email';
    },
  ),
  GoRoute(
    path: '/home',
    pageBuilder: (_, state) => _fadePage(state, const HomeScreen()),
  ),
  GoRoute(
    path: '/chat/:chatId',
    pageBuilder: (_, state) {
      final chatId = state.pathParameters['chatId']!;
      final extra = state.extra as Map<String, dynamic>?;
      return _fadePage(state, ChatScreen(
        chatId: chatId,
        otherUserId: extra?['otherUserId'] as String?,
      ));
    },
  ),
  GoRoute(
    path: '/voice-call/:callId',
    pageBuilder: (_, state) {
      final callId = state.pathParameters['callId']!;
      final extra = state.extra as Map<String, dynamic>?;
      return _fadePage(state, VoiceCallScreen(
        callId: callId,
        isCaller: extra?['isCaller'] as bool? ?? false,
        remoteName: extra?['remoteName'] as String?,
        remoteUserId: extra?['remoteUserId'] as String?,
      ));
    },
  ),
  GoRoute(
    path: '/video-call/:callId',
    pageBuilder: (_, state) {
      final callId = state.pathParameters['callId']!;
      final extra = state.extra as Map<String, dynamic>?;
      return _fadePage(state, VideoCallScreen(
        callId: callId,
        isCaller: extra?['isCaller'] as bool? ?? false,
        remoteName: extra?['remoteName'] as String?,
        remoteUserId: extra?['remoteUserId'] as String?,
      ));
    },
  ),
  GoRoute(
    path: '/incoming-call',
    pageBuilder: (_, state) => _fadePage(state, const SizedBox()),
  ),
  GoRoute(
    path: '/settings',
    pageBuilder: (_, state) => _fadePage(state, const SettingsScreen()),
  ),
];
