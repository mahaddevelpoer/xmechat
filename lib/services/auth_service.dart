import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/models.dart';
import '../core/constants/supabase_constants.dart';

class AuthService {
  final _client = Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;
  String get currentUserId => currentUser?.id ?? '';
  bool get isLoggedIn => currentUser != null;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  // ── Sign Up ───────────────────────────────────────
  Future<AuthResponse> signUp({required String email, required String password}) async {
    return await _client.auth.signUp(email: email, password: password);
  }

  // ── Sign In ───────────────────────────────────────
  Future<AuthResponse> signIn({required String email, required String password}) async {
    return await _client.auth.signInWithPassword(email: email, password: password);
  }

  // ── Forgot Password ───────────────────────────────
  Future<void> resetPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  // ── Sign Out ──────────────────────────────────────
  Future<void> signOut() async {
    try {
      if (currentUserId.isNotEmpty) {
        await _client.from(SupabaseConstants.usersTable).update({
          'is_online': false,
          'last_seen': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', currentUserId);
      }
    } catch (_) {}
    await _client.auth.signOut();
  }

  // ── Check Profile Exists ──────────────────────────
  Future<bool> hasProfile() async {
    final data = await _client
        .from(SupabaseConstants.usersTable)
        .select('id, name')
        .eq('id', currentUserId)
        .maybeSingle();
    return data != null && (data['name'] as String).isNotEmpty;
  }

  // ── Get Current User Profile ──────────────────────
  Future<UserModel?> getCurrentUserProfile() async {
    final data = await _client
        .from(SupabaseConstants.usersTable)
        .select()
        .eq('id', currentUserId)
        .maybeSingle();
    if (data == null) return null;
    return UserModel.fromMap(data);
  }

  // ── Create/Update Profile ─────────────────────────
  Future<void> upsertProfile(UserModel user) async {
    await _client.from(SupabaseConstants.usersTable).upsert(user.toMap());
  }

  // ── Update Profile Picture ────────────────────────
  Future<String> uploadAvatar(Uint8List bytes, String ext) async {
    final path = '$currentUserId/avatar.$ext';
    await _client.storage
        .from(SupabaseConstants.avatarsBucket)
        .uploadBinary(path, bytes, fileOptions: FileOptions(upsert: true, contentType: 'image/$ext'));
    return _client.storage.from(SupabaseConstants.avatarsBucket).getPublicUrl(path);
  }

  // ── Update Online Status ──────────────────────────
  Future<void> updateOnlineStatus(bool isOnline) async {
    if (currentUserId.isEmpty) return;
    await _client.from(SupabaseConstants.usersTable).update({
      'is_online': isOnline,
      'last_seen': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', currentUserId);
  }

  // ── Update Push Token ─────────────────────────────
  Future<void> updatePushToken(String token) async {
    if (currentUserId.isEmpty) return;
    await _client.from(SupabaseConstants.usersTable)
        .update({'push_token': token}).eq('id', currentUserId);
  }

  // ── Update Profile Fields ─────────────────────────
  Future<void> updateProfile({String? name, String? phoneInfo, String? bio, String? avatarUrl}) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (phoneInfo != null) updates['phone_info'] = phoneInfo;
    if (bio != null) updates['bio'] = bio;
    // Always include avatar_url field (even when null) to prevent overwrite issues
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (updates.isEmpty) return;
    await _client.from(SupabaseConstants.usersTable).update(updates).eq('id', currentUserId);
  }

  // ── Delete Account ────────────────────────────────
  Future<void> deleteAccount() async {
    if (currentUserId.isEmpty) return;
    // Delete user data from all tables
    await _client.from(SupabaseConstants.messagesTable).delete().eq('sender_id', currentUserId);
    await _client.from(SupabaseConstants.usersTable).delete().eq('id', currentUserId);
    // Sign out (auth user deletion requires service_role key on server side)
    await _client.auth.signOut();
  }
}
