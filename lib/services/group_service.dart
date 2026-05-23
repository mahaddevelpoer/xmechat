import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/supabase_constants.dart';
import '../models/models.dart';

class GroupService {
  final _db = Supabase.instance.client;
  final String _uid;
  GroupService(this._uid);

  Future<GroupModel> createGroup({
    required String name, String description = '',
    required List<String> memberIds, Uint8List? iconBytes,
  }) async {
    String iconUrl = '';
    if (iconBytes != null) {
      final path = 'group_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await _db.storage.from(SupabaseConstants.groupIconsBucket)
          .uploadBinary(path, iconBytes, fileOptions: const FileOptions(contentType: 'image/jpeg'));
      iconUrl = _db.storage.from(SupabaseConstants.groupIconsBucket).getPublicUrl(path);
    }
    final group = await _db.from(SupabaseConstants.groupsTable).insert({
      'name': name, 'description': description,
      'icon_url': iconUrl, 'created_by': _uid,
    }).select().single();
    final groupId = group['id'] as String;
    final allMembers = [_uid, ...memberIds.where((id) => id != _uid)];
    await _db.from(SupabaseConstants.groupMembersTable).insert(
      allMembers.map((id) => {
        'group_id': groupId, 'user_id': id, 'is_admin': id == _uid,
      }).toList(),
    );
    return GroupModel.fromMap(group);
  }

  Future<List<GroupModel>> fetchMyGroups() async {
    final memberRows = await _db.from(SupabaseConstants.groupMembersTable)
        .select('group_id').eq('user_id', _uid);
    final groupIds = memberRows.map<String>((r) => r['group_id'] as String).toList();
    if (groupIds.isEmpty) return [];
    final data = await _db.from(SupabaseConstants.groupsTable)
        .select().inFilter('id', groupIds).order('last_message_at', ascending: false);
    return data.map<GroupModel>((m) => GroupModel.fromMap(m)).toList();
  }

  Future<List<GroupMemberModel>> fetchMembers(String groupId) async {
    final data = await _db.from(SupabaseConstants.groupMembersTable)
        .select('*, user:user_id(*)').eq('group_id', groupId);
    return data.map<GroupMemberModel>((m) {
      final gm = GroupMemberModel.fromMap(m);
      if (m['user'] != null) gm.user = UserModel.fromMap(m['user']);
      return gm;
    }).toList();
  }

  Future<List<GroupMessageModel>> fetchGroupMessages(String groupId, {int limit = 50, int offset = 0}) async {
    final data = await _db.from(SupabaseConstants.groupMessagesTable)
        .select('*, sender:sender_id(*)')
        .eq('group_id', groupId)
        .eq('deleted_for_everyone', false)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return data.map<GroupMessageModel>((m) {
      final msg = GroupMessageModel.fromMap(m);
      if (m['sender'] != null) msg.senderUser = UserModel.fromMap(m['sender']);
      return msg;
    }).toList();
  }

  Stream<List<Map<String, dynamic>>> streamGroupMessages(String groupId) {
    return _db.from(SupabaseConstants.groupMessagesTable)
        .stream(primaryKey: ['id']).eq('group_id', groupId).order('created_at');
  }

  Future<GroupMessageModel> sendGroupMessage({
    required String groupId, required String text,
    MessageType type = MessageType.text, String mediaUrl = '',
    String fileName = '', int? duration, int? fileSize,
    String? replyTo, String replyPreview = '',
    String replySenderName = '', List<String> mentions = const [],
    bool isForwarded = false,
  }) async {
    final data = await _db.from(SupabaseConstants.groupMessagesTable).insert({
      'group_id': groupId, 'sender_id': _uid, 'text': text,
      'type': type.value, 'media_url': mediaUrl, 'file_name': fileName,
      'duration': duration, 'file_size': fileSize,
      'reply_to': replyTo, 'reply_preview': replyPreview,
      'reply_sender_name': replySenderName, 'mentions': mentions,
      'is_forwarded': isForwarded,
    }).select().single();
    await _db.from(SupabaseConstants.groupsTable).update({
      'last_message': text.isEmpty ? '📎 Media' : text,
      'last_message_at': DateTime.now().toUtc().toIso8601String(),
      'last_message_type': type.value,
    }).eq('id', groupId);
    return GroupMessageModel.fromMap(data);
  }

  Future<void> addMembers(String groupId, List<String> userIds) async {
    // Use upsert to avoid duplicate-member errors if user is already in group.
    await _db.from(SupabaseConstants.groupMembersTable).upsert(
      userIds
          .where((id) => id.isNotEmpty)
          .map((id) => {'group_id': groupId, 'user_id': id, 'is_admin': false})
          .toList(),
    );
  }

  Future<void> removeMember(String groupId, String userId) async {
    await _db.from(SupabaseConstants.groupMembersTable)
        .delete().eq('group_id', groupId).eq('user_id', userId);
  }

  Future<void> toggleAdmin(String groupId, String userId, bool makeAdmin) async {
    await _db.from(SupabaseConstants.groupMembersTable)
        .update({'is_admin': makeAdmin}).eq('group_id', groupId).eq('user_id', userId);
  }

  Future<void> updateGroup(String groupId, {String? name, String? description, String? iconUrl}) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;
    if (iconUrl != null) updates['icon_url'] = iconUrl;
    await _db.from(SupabaseConstants.groupsTable).update(updates).eq('id', groupId);
  }

  Future<void> leaveGroup(String groupId) async {
    await _db.from(SupabaseConstants.groupMembersTable)
        .delete().eq('group_id', groupId).eq('user_id', _uid);
  }

  Future<void> markGroupMessagesRead(String groupId, String messageId) async {
    await _db.from(SupabaseConstants.groupMessageReadsTable).upsert({
      'message_id': messageId, 'user_id': _uid,
    });
  }

  Future<PollModel> createPoll({
    required String groupId, required String question,
    required List<String> options, bool allowMultiple = false,
  }) async {
    final data = await _db.from(SupabaseConstants.pollsTable).insert({
      'group_id': groupId, 'created_by': _uid,
      'question': question, 'options': options, 'allow_multiple': allowMultiple,
    }).select().single();
    return PollModel.fromMap(data);
  }

  Future<void> votePoll(String pollId, int optionIndex) async {
    await _db.from(SupabaseConstants.pollVotesTable).upsert({
      'poll_id': pollId, 'user_id': _uid, 'option_index': optionIndex,
    });
  }

  Future<PollModel?> getPoll(String pollId) async {
    final data = await _db.from(SupabaseConstants.pollsTable)
        .select()
        .eq('id', pollId)
        .maybeSingle();
    return data == null ? null : PollModel.fromMap(data);
  }

  Future<Map<int, int>> getPollCounts(String pollId) async {
    final rows = await _db.from(SupabaseConstants.pollVotesTable)
        .select('option_index')
        .eq('poll_id', pollId);
    final counts = <int, int>{};
    for (final r in rows) {
      final idx = r['option_index'];
      if (idx is int) {
        counts[idx] = (counts[idx] ?? 0) + 1;
      } else {
        final parsed = int.tryParse(idx?.toString() ?? '');
        if (parsed != null) counts[parsed] = (counts[parsed] ?? 0) + 1;
      }
    }
    return counts;
  }

  Future<bool> isAdmin(String groupId) async {
    final data = await _db.from(SupabaseConstants.groupMembersTable).select('is_admin')
        .eq('group_id', groupId).eq('user_id', _uid).maybeSingle();
    return data?['is_admin'] == true;
  }
}
