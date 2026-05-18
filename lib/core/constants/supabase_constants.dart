// 🔧 REPLACE THESE WITH YOUR ACTUAL SUPABASE CREDENTIALS
// Get them from: https://supabase.com/dashboard -> Project Settings -> API

class SupabaseConstants {
  // Your Supabase Project URL
  static const String supabaseUrl = 'https://YOUR_PROJECT_ID.supabase.co';

  // Your Supabase Anon/Public Key
  static const String supabaseAnonKey = 'YOUR_ANON_KEY_HERE';

  // Storage Bucket Names
  static const String avatarsBucket = 'avatars';
  static const String chatMediaBucket = 'chat-media';
  static const String statusMediaBucket = 'status-media';
  static const String groupIconsBucket = 'group-icons';
  static const String documentsBucket = 'documents';
  static const String voiceNotesBucket = 'voice-notes';

  // Tables
  static const String usersTable = 'users';
  static const String chatsTable = 'chats';
  static const String messagesTable = 'messages';
  static const String groupsTable = 'groups';
  static const String groupMembersTable = 'group_members';
  static const String groupMessagesTable = 'group_messages';
  static const String groupMessageReadsTable = 'group_message_reads';
  static const String reactionsTable = 'reactions';
  static const String statusesTable = 'statuses';
  static const String statusViewsTable = 'status_views';
  static const String callsTable = 'calls';
  static const String iceCandidatesTable = 'ice_candidates';
  static const String blockedUsersTable = 'blocked_users';
  static const String starredMessagesTable = 'starred_messages';
  static const String pollsTable = 'polls';
  static const String pollVotesTable = 'poll_votes';

  // WebRTC STUN Server
  static const String stunServer = 'stun:stun.l.google.com:19302';
  static const String stunServer2 = 'stun:stun1.l.google.com:19302';
}
