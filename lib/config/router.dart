import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/auth/splash_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/email_verification_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/chat/group_chat_screen.dart';
import '../screens/contacts/contacts_screen.dart';
import '../screens/groups/create_group_screen.dart';
import '../screens/broadcast/broadcast_screen.dart';
import '../screens/status/create_status_screen.dart';
import '../screens/calls/incoming_call_screen.dart';
import '../screens/calls/voice_call_screen.dart';
import '../screens/calls/video_call_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/auth/profile_setup_screen.dart';
import '../models/models.dart';

final _authNotifier = _AuthNotifier();

class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier() {
    Supabase.instance.client.auth.onAuthStateChange.listen((_) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: false,
    redirect: _authGuard,
    refreshListenable: _authNotifier,
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
  if (isAuthenticated && loc == '/login') return '/home';
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
    pageBuilder: (_, state) {
      final email = state.uri.queryParameters['email'] ?? Supabase.instance.client.auth.currentUser?.email ?? '';
      return _fadePage(state, ProfileSetupScreen(email: email));
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
    path: '/splash',
    pageBuilder: (_, state) => _fadePage(state, const SplashScreen()),
  ),
  GoRoute(
    path: '/forgot-password',
    pageBuilder: (_, state) => _fadePage(state, const ForgotPasswordScreen()),
  ),
  GoRoute(
    path: '/email-verification',
    pageBuilder: (_, state) {
      final email = state.uri.queryParameters['email'] ?? '';
      return _fadePage(state, EmailVerificationScreen(email: email));
    },
  ),
  GoRoute(
    path: '/contacts',
    pageBuilder: (_, state) => _fadePage(state, const ContactsScreen()),
  ),
  GoRoute(
    path: '/create-group',
    pageBuilder: (_, state) => _fadePage(state, const CreateGroupScreen()),
  ),
  GoRoute(
    path: '/broadcast',
    pageBuilder: (_, state) => _fadePage(state, const BroadcastScreen()),
  ),
  GoRoute(
    path: '/create-status',
    pageBuilder: (_, state) => _fadePage(state, const CreateStatusScreen()),
  ),
  GoRoute(
    path: '/group-chat/:groupId',
    pageBuilder: (_, state) {
      final groupId = state.pathParameters['groupId']!;
      final extra = state.extra as Map<String, dynamic>?;
      return _fadePage(state, GroupChatScreen(
        groupId: groupId,
        group: extra?['group'] as GroupModel?,
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
        isIncoming: extra?['isIncoming'] as bool? ?? false,
        otherUserName: extra?['otherUserName'] as String?,
        otherUserId: extra?['otherUserId'] as String?,
        sdpOffer: extra?['sdpOffer'] as String?,
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
        isIncoming: extra?['isIncoming'] as bool? ?? false,
        otherUserName: extra?['otherUserName'] as String?,
        otherUserId: extra?['otherUserId'] as String?,
        sdpOffer: extra?['sdpOffer'] as String?,
      ));
    },
  ),
  GoRoute(
    path: '/incoming-call',
    pageBuilder: (_, state) {
      final call = state.extra as CallModel?;
      return _fadePage(state, IncomingCallScreen(call: call ?? CallModel(
        id: '', callerId: '', receiverId: '',
        startedAt: DateTime.now(), createdAt: DateTime.now(),
      )));
    },
  ),
  GoRoute(
    path: '/settings',
    pageBuilder: (_, state) => _fadePage(state, const SettingsScreen()),
  ),
];
