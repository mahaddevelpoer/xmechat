import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/navigation/app_navigator.dart';
import '../providers/providers.dart';
import '../screens/auth/splash_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/email_verification_screen.dart';
import '../screens/auth/otp_verification_screen.dart';
import '../screens/auth/profile_setup_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/chat/private_chat_screen.dart';
import '../screens/chat/group_chat_screen.dart';
import '../screens/chat/chat_info_screen.dart';
import '../screens/groups/create_group_screen.dart';
import '../screens/groups/group_info_screen.dart';
import '../screens/calls/video_call_screen.dart';
import '../screens/calls/voice_call_screen.dart';
import '../screens/calls/incoming_call_screen.dart';
import '../screens/status/status_viewer_screen.dart';
import '../screens/status/create_status_screen.dart';
import '../screens/contacts/contacts_screen.dart';
import '../screens/contacts/user_profile_screen.dart';
import '../screens/contacts/search_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/settings/edit_profile_screen.dart';
import '../screens/settings/blocked_users_screen.dart';
import '../models/models.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.valueOrNull?.session?.user ?? Supabase.instance.client.auth.currentUser;
  return GoRouter(
    initialLocation: '/',
    navigatorKey: rootNavigatorKey,
    redirect: (ctx, state) {
      final isAuthRoute = state.matchedLocation.startsWith('/login') ||
          state.matchedLocation.startsWith('/signup') ||
          state.matchedLocation.startsWith('/forgot') ||
          state.matchedLocation == '/';
      if (user == null && !isAuthRoute) return '/login';
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
      GoRoute(path: '/forgot-password', builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(
        path: '/verify-email',
        builder: (_, state) => EmailVerificationScreen(email: state.extra as String? ?? ''),
      ),
      GoRoute(
        path: '/otp-verification',
        builder: (_, state) => OtpVerificationScreen(email: state.extra as String? ?? ''),
      ),
      GoRoute(path: '/profile-setup', builder: (_, __) => const ProfileSetupScreen()),
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(
        path: '/chat/:chatId',
        builder: (_, state) {
          final chatId = state.pathParameters['chatId']!;
          final extra = state.extra as Map<String, dynamic>?;
          return PrivateChatScreen(
            chatId: chatId,
            otherUser: extra?['user'] as UserModel?,
          );
        },
      ),
      GoRoute(
        path: '/group-chat/:groupId',
        builder: (_, state) {
          final groupId = state.pathParameters['groupId']!;
          final extra = state.extra as Map<String, dynamic>?;
          return GroupChatScreen(
            groupId: groupId,
            group: extra?['group'] as GroupModel?,
          );
        },
      ),
      GoRoute(
        path: '/chat-info/:chatId',
        builder: (_, state) => ChatInfoScreen(chatId: state.pathParameters['chatId']!),
      ),
      GoRoute(path: '/create-group', builder: (_, __) => const CreateGroupScreen()),
      GoRoute(
        path: '/group-info/:groupId',
        builder: (_, state) => GroupInfoScreen(groupId: state.pathParameters['groupId']!),
      ),
      GoRoute(
        path: '/video-call/:callId',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return VideoCallScreen(
            callId: state.pathParameters['callId']!,
            isCaller: extra?['isCaller'] ?? true,
            otherUser: extra?['user'] as UserModel?,
          );
        },
      ),
      GoRoute(
        path: '/voice-call/:callId',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return VoiceCallScreen(
            callId: state.pathParameters['callId']!,
            isCaller: extra?['isCaller'] ?? true,
            otherUser: extra?['user'] as UserModel?,
          );
        },
      ),
      GoRoute(
        path: '/incoming-call',
        builder: (_, state) => IncomingCallScreen(call: state.extra as CallModel),
      ),
      GoRoute(
        path: '/status/:userId',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return StatusViewerScreen(
            userId: state.pathParameters['userId']!,
            statuses: extra?['statuses'] as List<StatusModel>? ?? [],
          );
        },
      ),
      GoRoute(path: '/create-status', builder: (_, __) => const CreateStatusScreen()),
      GoRoute(path: '/contacts', builder: (_, __) => const ContactsScreen()),
      GoRoute(
        path: '/user-profile/:userId',
        builder: (_, state) => UserProfileScreen(userId: state.pathParameters['userId']!),
      ),
      GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(path: '/edit-profile', builder: (_, __) => const EditProfileScreen()),
      GoRoute(path: '/blocked-contacts', builder: (_, __) => const BlockedUsersScreen()),
    ],
  );
});
