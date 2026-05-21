import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/auth_service.dart';
import '../services/chat_service.dart';
import '../services/group_service.dart';
import '../services/status_service.dart';
import '../services/webrtc_service.dart';

// ── Core Service Providers ────────────────────────
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final currentUserIdProvider = Provider<String>((ref) {
  final authState = ref.watch(authStateProvider).value;
  return authState?.session?.user.id ?? Supabase.instance.client.auth.currentUser?.id ?? '';
});

final chatServiceProvider = Provider<ChatService>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  return ChatService(uid);
});

final groupServiceProvider = Provider<GroupService>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  return GroupService(uid);
});

final statusServiceProvider = Provider<StatusService>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  return StatusService(uid);
});

final webrtcServiceProvider = Provider<WebRTCService>((ref) {
  final uid = ref.watch(currentUserIdProvider);
  return WebRTCService(uid);
});

// ── Auth State ────────────────────────────────────
final authStateProvider = StreamProvider<AuthState>((ref) {
  return Supabase.instance.client.auth.onAuthStateChange;
});

final currentUserProvider = FutureProvider<UserModel?>((ref) async {
  return ref.read(authServiceProvider).getCurrentUserProfile();
});

// ── Theme Mode ────────────────────────────────────
final themeProvider = StateProvider<bool>((ref) => false); // false = light

// ── All Chats ─────────────────────────────────────
final chatsProvider = FutureProvider.autoDispose<List<ChatModel>>((ref) async {
  return ref.read(chatServiceProvider).fetchChats();
});

// ── Messages for a chat ───────────────────────────
final messagesProvider = FutureProvider.autoDispose.family<List<MessageModel>, String>((ref, chatId) async {
  return ref.read(chatServiceProvider).fetchMessages(chatId);
});

// ── All Groups ────────────────────────────────────
final groupsProvider = FutureProvider.autoDispose<List<GroupModel>>((ref) async {
  return ref.read(groupServiceProvider).fetchMyGroups();
});

// ── Group Messages ────────────────────────────────
final groupMessagesProvider = FutureProvider.autoDispose.family<List<GroupMessageModel>, String>((ref, groupId) async {
  return ref.read(groupServiceProvider).fetchGroupMessages(groupId);
});

// ── Group Members ─────────────────────────────────
final groupMembersProvider = FutureProvider.autoDispose.family<List<GroupMemberModel>, String>((ref, groupId) async {
  return ref.read(groupServiceProvider).fetchMembers(groupId);
});

// ── Statuses ──────────────────────────────────────
final statusesProvider = FutureProvider.autoDispose<List<StatusModel>>((ref) async {
  return ref.read(statusServiceProvider).fetchAllStatuses();
});

final myStatusesProvider = FutureProvider.autoDispose<List<StatusModel>>((ref) async {
  return ref.read(statusServiceProvider).fetchMyStatuses();
});

// ── All Users (contacts) ──────────────────────────
final allUsersProvider = FutureProvider.autoDispose<List<UserModel>>((ref) async {
  return ref.read(chatServiceProvider).getAllUsers();
});

// ── Search Users ──────────────────────────────────
final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = FutureProvider.autoDispose<List<UserModel>>((ref) {
  final query = ref.watch(searchQueryProvider);
  if (query.isEmpty) return Future.value([]);
  return ref.read(chatServiceProvider).searchUsers(query);
});

// ── Call History ──────────────────────────────────
final callHistoryProvider = FutureProvider.autoDispose((ref) async {
  return ref.read(webrtcServiceProvider).fetchCallHistory();
});

// ── Typing Indicator ──────────────────────────────
final typingProvider = StateProvider.family<bool, String>((ref, chatId) => false);

// ── Reply Message ─────────────────────────────────
final replyMessageProvider = StateProvider.family<MessageModel?, String>((ref, chatId) => null);

// ── Chat Input Text ───────────────────────────────
final chatInputProvider = StateProvider.family<String, String>((ref, chatId) => '');

// ── Active Call ───────────────────────────────────
final activeCallProvider = StateProvider<CallModel?>((ref) => null);

// ── Incoming Call ─────────────────────────────────
final incomingCallProvider = StreamProvider.autoDispose<CallModel?>((ref) {
  return ref.read(webrtcServiceProvider).listenForIncomingCalls();
});

// ── Online Status of a User ───────────────────────
final userOnlineProvider = FutureProvider.autoDispose.family<UserModel?, String>((ref, userId) async {
  return ref.read(chatServiceProvider).getUserById(userId);
});

final userStreamProvider =
    StreamProvider.autoDispose.family<UserModel?, String>((ref, userId) {
  return ref.read(chatServiceProvider).streamUser(userId);
});

// ── Stream Messages Realtime ──────────────────────
final streamMessagesProvider = StreamProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, chatId) {
  return ref.read(chatServiceProvider).streamMessages(chatId);
});

// ── Stream Group Messages Realtime ────────────────
final streamGroupMessagesProvider = StreamProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, groupId) {
  return ref.read(groupServiceProvider).streamGroupMessages(groupId);
});

// ── Chats Stream (alias for desktop sidebar) ──────
final chatsStreamProvider = FutureProvider.autoDispose<List<ChatModel>>((ref) async {
  return ref.read(chatServiceProvider).fetchChats();
});

// ── Settings (SharedPreferences-backed) ───────────
final settingsProvider = FutureProvider<SharedPreferences>((ref) async {
  return SharedPreferences.getInstance();
});

final enterToSendProvider = Provider<bool>((ref) {
  final prefs = ref.watch(settingsProvider).valueOrNull;
  return prefs?.getBool('enter_to_send') ?? false;
});

final fontSizeProvider = Provider<double>((ref) {
  final prefs = ref.watch(settingsProvider).valueOrNull;
  return prefs?.getDouble('font_size') ?? 14.0;
});
