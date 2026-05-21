import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/supabase_constants.dart';
import '../models/models.dart';

class BroadcastService {
  final _db = Supabase.instance.client;
  final String _uid;
  BroadcastService(this._uid);

  Future<BroadcastListModel> createList({
    required String name,
    required List<String> memberIds,
  }) async {
    final list = await _db.from('broadcast_lists').insert({
      'name': name,
      'created_by': _uid,
    }).select().single();
    final listId = list['id'] as String;
    if (memberIds.isNotEmpty) {
      await _db.from('broadcast_list_members').insert(
        memberIds.where((id) => id != _uid).map((id) => {
          'list_id': listId,
          'user_id': id,
        }).toList(),
      );
    }
    return BroadcastListModel.fromMap(list);
  }

  Future<List<BroadcastListModel>> fetchMyLists() async {
    final data = await _db.from('broadcast_lists')
        .select('*, members:broadcast_list_members(*, user:user_id(*))')
        .eq('created_by', _uid)
        .order('created_at', ascending: false);
    return data.map<BroadcastListModel>((m) => BroadcastListModel.fromMap(m)).toList();
  }

  Future<void> addMembers(String listId, List<String> userIds) async {
    await _db.from('broadcast_list_members').upsert(
      userIds.where((id) => id.isNotEmpty).map((id) => ({
        'list_id': listId,
        'user_id': id,
      })).toList(),
    );
  }

  Future<void> removeMember(String listId, String userId) async {
    await _db.from('broadcast_list_members')
        .delete().eq('list_id', listId).eq('user_id', userId);
  }

  Future<void> deleteList(String listId) async {
    await _db.from('broadcast_lists').delete().eq('id', listId);
  }

  Future<void> sendBroadcastMessage({
    required String listId,
    required String text,
    String type = 'text',
    String mediaUrl = '',
    String fileName = '',
  }) async {
    await _db.from('broadcast_messages').insert({
      'list_id': listId,
      'sender_id': _uid,
      'text': text,
      'type': type,
      'media_url': mediaUrl,
      'file_name': fileName,
    });
    final memberIds = await _db.from('broadcast_list_members')
        .select('user_id').eq('list_id', listId);
    for (final m in memberIds) {
      final receiverId = m['user_id'] as String;
      final chatId = await _getOrCreateChat(receiverId);
      await _db.from(SupabaseConstants.messagesTable).insert({
        'chat_id': chatId,
        'sender_id': _uid,
        'receiver_id': receiverId,
        'text': text,
        'type': type,
        'media_url': mediaUrl,
        'file_name': fileName,
        'status': 'sent',
      });
    }
  }

  Future<String> _getOrCreateChat(String otherUserId) async {
    final existing = await _db.from(SupabaseConstants.chatsTable)
        .select('id').or('and(participant_1.eq.$_uid,participant_2.eq.$otherUserId),and(participant_1.eq.$otherUserId,participant_2.eq.$_uid)')
        .maybeSingle();
    if (existing != null) return existing['id'] as String;
    final chat = await _db.from(SupabaseConstants.chatsTable).insert({
      'participant_1': _uid,
      'participant_2': otherUserId,
    }).select().single();
    return chat['id'] as String;
  }

  Future<List<BroadcastMessageModel>> fetchMessages(String listId) async {
    final data = await _db.from('broadcast_messages')
        .select().eq('list_id', listId).order('created_at', ascending: true);
    return data.map<BroadcastMessageModel>((m) => BroadcastMessageModel.fromMap(m)).toList();
  }
}
