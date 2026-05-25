import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../screens/auth/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/auth/email_verification_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/profile_setup_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/chat/private_chat_screen.dart';
import '../screens/chat/group_chat_screen.dart';
import '../screens/calls/voice_call_screen.dart';
import '../screens/calls/video_call_screen.dart';
import '../screens/calls/incoming_call_screen.dart';
import '../screens/contacts/contacts_screen.dart';
import '../screens/groups/create_group_screen.dart';
import '../screens/status/create_status_screen.dart';
import '../screens/broadcast/broadcast_screen.dart';
import '../widgets/common/user_avatar.dart';

// ─────────────────────────────────────────────────────
// Router provider
// ─────────────────────────────────────────────────────
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: false,
    redirect: _authGuard,
    routes: _routes,
  );
});

// ─────────────────────────────────────────────────────
// Auth guard
// ─────────────────────────────────────────────────────
String? _authGuard(BuildContext context, GoRouterState state) {
  final user = Supabase.instance.client.auth.currentUser;
  final isAuthenticated = user != null;

  const publicRoutes = {
    '/',
    '/login',
    '/signup',
    '/verify-email',
    '/forgot-password',
  };

  final loc = state.matchedLocation;
  final isPublic = publicRoutes.any((r) => loc.startsWith(r));

  if (!isAuthenticated && !isPublic) return '/login';
  return null;
}

// ─────────────────────────────────────────────────────
// Page transition helper
// ─────────────────────────────────────────────────────
CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 150),
    reverseTransitionDuration: const Duration(milliseconds: 100),
    transitionsBuilder: (_, animation, __, child) => FadeTransition(
      opacity:
          CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: child,
    ),
  );
}

// ─────────────────────────────────────────────────────
// Route definitions
// ─────────────────────────────────────────────────────
final List<RouteBase> _routes = [

  // ── Splash / auth ────────────────────────────────
  GoRoute(
    path: '/',
    pageBuilder: (_, state) => _fadePage(state, const SplashScreen()),
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
    path: '/verify-email',
    pageBuilder: (_, state) {
      final email = state.extra as String? ?? '';
      return _fadePage(state, EmailVerificationScreen(email: email));
    },
  ),
  GoRoute(
    path: '/forgot-password',
    pageBuilder: (_, state) =>
        _fadePage(state, const ForgotPasswordScreen()),
  ),
  GoRoute(
    path: '/profile-setup',
    pageBuilder: (_, state) =>
        _fadePage(state, const ProfileSetupScreen()),
  ),

  // ── Main app ─────────────────────────────────────
  GoRoute(
    path: '/home',
    pageBuilder: (_, state) => _fadePage(state, const HomeScreen()),
  ),

  // ── Private chat ──────────────────────────────────
  GoRoute(
    path: '/chat/:chatId',
    pageBuilder: (_, state) {
      final chatId = state.pathParameters['chatId']!;
      final extra = state.extra as Map<String, dynamic>?;
      final otherUser = extra?['user'] as UserModel?;
      return _fadePage(
        state,
        PrivateChatScreen(chatId: chatId, otherUser: otherUser),
      );
    },
  ),

  // ── Group chat ────────────────────────────────────
  GoRoute(
    path: '/group-chat/:groupId',
    pageBuilder: (_, state) {
      final groupId = state.pathParameters['groupId']!;
      final extra = state.extra as Map<String, dynamic>?;
      final group = extra?['group'] as GroupModel?;
      return _fadePage(
        state,
        GroupChatScreen(groupId: groupId, group: group),
      );
    },
  ),

  // ── Voice call ────────────────────────────────────
  GoRoute(
    path: '/voice-call/:callId',
    pageBuilder: (_, state) {
      final callId = state.pathParameters['callId']!;
      final extra = state.extra as Map<String, dynamic>?;
      final isCaller  = extra?['isCaller'] as bool? ?? false;
      final user      = extra?['user'] as UserModel?;
      final sdpOffer  = extra?['sdpOffer'] as String? ?? '';
      return _fadePage(
        state,
        VoiceCallScreen(
          callId: callId,
          isCaller: isCaller,
          remoteUser: user,
          sdpOffer: sdpOffer,
        ),
      );
    },
  ),

  // ── Video call ────────────────────────────────────
  GoRoute(
    path: '/video-call/:callId',
    pageBuilder: (_, state) {
      final callId = state.pathParameters['callId']!;
      final extra  = state.extra as Map<String, dynamic>?;
      final isCaller  = extra?['isCaller'] as bool? ?? false;
      final user      = extra?['user'] as UserModel?;
      final sdpOffer  = extra?['sdpOffer'] as String? ?? '';
      return _fadePage(
        state,
        VideoCallScreen(
          callId: callId,
          isCaller: isCaller,
          remoteUser: user,
          sdpOffer: sdpOffer,
        ),
      );
    },
  ),

  // ── Real screens ──────────────────────────────────
  GoRoute(
    path: '/create-group',
    pageBuilder: (_, state) => _fadePage(state, const CreateGroupScreen()),
  ),
  GoRoute(
    path: '/create-status',
    pageBuilder: (_, state) => _fadePage(state, const CreateStatusScreen()),
  ),
  GoRoute(
    path: '/broadcast',
    pageBuilder: (_, state) => _fadePage(state, const BroadcastScreen()),
  ),
  GoRoute(
    path: '/contacts',
    pageBuilder: (_, state) => _fadePage(state, const ContactsScreen()),
  ),

  // ── Incoming call ────────────────────────────────────
  GoRoute(
    path: '/incoming-call',
    pageBuilder: (_, state) {
      final call = state.extra as CallModel?;
      if (call == null) return _fadePage(state, const SplashScreen());
      return _fadePage(state, IncomingCallScreen(call: call));
    },
  ),

  // ── Contact profile ───────────────────────────────
  GoRoute(
    path: '/contact/:userId',
    pageBuilder: (_, state) {
      final extra = state.extra as Map<String, dynamic>?;
      final user  = extra?['user'] as UserModel?;
      return _fadePage(
        state,
        _ContactProfileScreen(
          userId: state.pathParameters['userId']!,
          user: user,
        ),
      );
    },
  ),
];

// ─────────────────────────────────────────────────────
// Contact profile screen
// ─────────────────────────────────────────────────────
class _ContactProfileScreen extends ConsumerWidget {
  final String userId;
  final UserModel? user;
  const _ContactProfileScreen({required this.userId, this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.panel,
        elevation: 0,
        title: Text('Contact Info', style: AppText.title),
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(28),
            decoration: AppDeco.card,
            child: Column(
              children: [
                UserAvatar(
                  imageUrl: user?.avatarUrl,
                  name: user?.name ?? '?',
                  size: 80,
                ),
                const SizedBox(height: 16),
                Text(user?.name ?? 'Unknown', style: AppText.heading),
                if (user?.bio.isNotEmpty == true) ...[
                  const SizedBox(height: 6),
                  Text(user!.bio,
                      style: AppText.bodyGrey,
                      textAlign: TextAlign.center),
                ],
                const SizedBox(height: 4),
                Text(user?.email ?? '', style: AppText.caption),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final chatId = await ref
                              .read(chatServiceProvider)
                              .getOrCreateChat(userId);
                          if (context.mounted) {
                            context.push('/chat/$chatId',
                                extra: {'user': user});
                          }
                        },
                        icon: const Icon(Icons.chat_bubble_outline,
                            size: 16),
                        label: const Text('Message'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final callId = await ref
                              .read(webrtcServiceProvider)
                              .initiateCall(userId, isVideo: false);
                          if (context.mounted) {
                            context.push('/voice-call/$callId', extra: {
                              'isCaller': true,
                              'user': user,
                              'sdpOffer': '',
                            });
                          }
                        },
                        icon: const Icon(Icons.call_outlined, size: 16),
                        label: const Text('Call'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
