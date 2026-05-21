import 'dart:typed_data';
import 'package:mime/mime.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/supabase_constants.dart';
import '../models/models.dart';

class ChatService {
  final _db = Supabase.instance.client;
  final String _uid;
  ChatService(this._uid);

  Future<String> getOrCreateChat(String otherUserId) async {
    final existing = await _db
        .from(SupabaseConstants.chatsTable)
        .select('id')
        .or(
          'and(participant_1.eq.$_uid,participant_2.eq.$otherUserId),and(participant_1.eq.$otherUserId,participant_2.eq.$_uid)',
        )
        .maybeSingle();
    if (existing != null) return existing['id'] as String;
    final result = await _db
        .from(SupabaseConstants.chatsTable)
        .insert({
          'participant_1': _uid,
          'participant_2': otherUserId,
          'last_message': '',
          'last_message_at': DateTime.now().toUtc().toIso8601String(),
        })
        .select('id')
        .single();
    return result['id'] as String;
  }

  Future<List<ChatModel>> fetchChats() async {
    final contacts = await _db
        .from('saved_contacts')
        .select('contact_id, nickname')
        .eq('user_id', _uid);
    final nicknameMap = {
      for (var c in contacts) c['contact_id']: c['nickname'],
    };

    final data = await _db
        .from(SupabaseConstants.chatsTable)
        .select('*, p1:participant_1(*), p2:participant_2(*)')
        .or('participant_1.eq.$_uid,participant_2.eq.$_uid')
        .order('last_message_at', ascending: false);
    return data.map<ChatModel>((m) {
      final chat = ChatModel.fromMap(m);
      final otherData = m['participant_1'] == _uid ? m['p2'] : m['p1'];
      if (otherData != null) {
        var otherUser = UserModel.fromMap(otherData);
        if (nicknameMap.containsKey(otherUser.id) &&
            nicknameMap[otherUser.id] != null &&
            nicknameMap[otherUser.id].toString().isNotEmpty) {
          otherUser = otherUser.copyWith(
            name: nicknameMap[otherUser.id].toString(),
          );
        }
        chat.otherUser = otherUser;
      }
      return chat;
    }).toList();
  }

  Stream<List<Map<String, dynamic>>> streamMessages(String chatId) {
    return _db
        .from(SupabaseConstants.messagesTable)
        .stream(primaryKey: ['id'])
        .eq('chat_id', chatId)
        .order('created_at');
  }

  Stream<UserModel?> streamUser(String userId) {
    return _db
        .from(SupabaseConstants.usersTable)
        .stream(primaryKey: const ['id'])
        .eq('id', userId)
        .map((rows) {
          if (rows.isEmpty) return null;
          return UserModel.fromMap(rows.first);
        });
  }

  Future<List<MessageModel>> fetchMessages(
    String chatId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final data = await _db
        .from(SupabaseConstants.messagesTable)
        .select('*, reactions(*)')
        .eq('chat_id', chatId)
        .eq('deleted_for_everyone', false)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return data.map<MessageModel>((m) {
      final msg = MessageModel.fromMap(m);
      if (m['reactions'] != null) {
        msg.reactions = (m['reactions'] as List)
            .map((r) => ReactionModel.fromMap(r))
            .toList();
      }
      return msg;
    }).toList();
  }

  Future<MessageModel> sendTextMessage({
    required String chatId,
    required String receiverId,
    required String text,
    String? replyTo,
    String replyPreview = '',
    bool isForwarded = false,
  }) async {
    final data = await _db
        .from(SupabaseConstants.messagesTable)
        .insert({
          'chat_id': chatId,
          'sender_id': _uid,
          'receiver_id': receiverId,
          'text': text,
          'type': 'text',
          'reply_to': replyTo,
          'reply_preview': replyPreview,
          'is_forwarded': isForwarded,
          'status': 'sent',
        })
        .select()
        .single();
    await _updateChatLastMessage(chatId, text, 'text');
    return MessageModel.fromMap(data);
  }

  Future<MessageModel> sendMediaMessage({
    required String chatId,
    required String receiverId,
    required Uint8List bytes,
    required MessageType type,
    required String fileName,
    String? replyTo,
    String replyPreview = '',
    bool isViewOnce = false,
    int duration = 0,
  }) async {
    final ext = fileName.split('.').last;
    final bucket = type == MessageType.audio
        ? SupabaseConstants.voiceNotesBucket
        : type == MessageType.document
        ? SupabaseConstants.documentsBucket
        : SupabaseConstants.chatMediaBucket;
    final path = '$chatId/${DateTime.now().millisecondsSinceEpoch}.$ext';
    final ct = lookupMimeType(fileName) ?? 'application/octet-stream';
    await Supabase.instance.client.storage
        .from(bucket)
        .uploadBinary(path, bytes, fileOptions: FileOptions(contentType: ct));
    final url = Supabase.instance.client.storage
        .from(bucket)
        .getPublicUrl(path);
    final preview = type == MessageType.image
        ? '📷 Photo'
        : type == MessageType.audio
        ? '🎵 Voice note'
        : type == MessageType.video
        ? '🎥 Video'
        : '📄 $fileName';
    final data = await _db
        .from(SupabaseConstants.messagesTable)
        .insert({
          'chat_id': chatId,
          'sender_id': _uid,
          'receiver_id': receiverId,
          'media_url': url,
          'file_name': fileName,
          'file_size': bytes.length,
          'type': type.value,
          'duration': duration,
          'reply_to': replyTo,
          'reply_preview': replyPreview,
          'is_view_once': isViewOnce,
          'status': 'sent',
        })
        .select()
        .single();
    await _updateChatLastMessage(chatId, preview, type.value);
    return MessageModel.fromMap(data);
  }

  Future<MessageModel> sendLocation({
    required String chatId,
    required String receiverId,
    required double lat,
    required double lng,
    String locationName = '',
  }) async {
    final data = await _db
        .from(SupabaseConstants.messagesTable)
        .insert({
          'chat_id': chatId,
          'sender_id': _uid,
          'receiver_id': receiverId,
          'type': 'location',
          'latitude': lat,
          'longitude': lng,
          'location_name': locationName,
          'status': 'sent',
        })
        .select()
        .single();
    await _updateChatLastMessage(chatId, '📍 Location', 'location');
    return MessageModel.fromMap(data);
  }

  Future<MessageModel> sendContact({
    required String chatId,
    required String receiverId,
    required String contactName,
    required String contactPhone,
  }) async {
    final data = await _db
        .from(SupabaseConstants.messagesTable)
        .insert({
          'chat_id': chatId,
          'sender_id': _uid,
          'receiver_id': receiverId,
          'type': 'contact',
          'contact_name': contactName,
          'contact_phone': contactPhone,
          'status': 'sent',
        })
        .select()
        .single();
    await _updateChatLastMessage(chatId, '👤 Contact', 'contact');
    return MessageModel.fromMap(data);
  }

  Future<MessageModel> forwardMessage({
    required MessageModel source,
    required String targetChatId,
    required String targetReceiverId,
  }) async {
    final preview = source.type == MessageType.image
        ? '📷 Photo'
        : source.type == MessageType.audio
        ? '🎵 Voice note'
        : source.type == MessageType.video
        ? '🎥 Video'
        : source.type == MessageType.document
        ? '📄 ${source.fileName.isNotEmpty ? source.fileName : 'Document'}'
        : source.type == MessageType.location
        ? '📍 Location'
        : source.type == MessageType.contact
        ? '👤 Contact'
        : source.text;

    final data = await _db
        .from(SupabaseConstants.messagesTable)
        .insert({
          'chat_id': targetChatId,
          'sender_id': _uid,
          'receiver_id': targetReceiverId,
          'text': source.text,
          'type': source.type.value,
          'media_url': source.mediaUrl,
          'file_name': source.fileName,
          'file_size': source.fileSize,
          'duration': source.duration,
          'is_forwarded': true,
          // When forwarding, we never preserve view-once behaviour.
          'is_view_once': false,
          'status': 'sent',
        })
        .select()
        .single();

    await _updateChatLastMessage(targetChatId, preview, source.type.value);
    return MessageModel.fromMap(data);
  }

  Future<void> markAllRead(String chatId) async {
    await _db
        .from(SupabaseConstants.messagesTable)
        .update({
          'status': 'read',
          'seen_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('chat_id', chatId)
        .eq('receiver_id', _uid)
        .neq('status', 'read');
  }

  Future<void> markDelivered(String chatId) async {
    await _db
        .from(SupabaseConstants.messagesTable)
        .update({
          'status': 'delivered',
          'delivered_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('chat_id', chatId)
        .eq('receiver_id', _uid)
        .eq('status', 'sent');
  }

  Future<void> markViewOnceOpened(String messageId) async {
    await _db
        .from(SupabaseConstants.messagesTable)
        .update({'view_once_opened': true})
        .eq('id', messageId)
        .eq('receiver_id', _uid);
  }

  Future<void> deleteMessage(
    String messageId, {
    required bool forEveryone,
  }) async {
    if (forEveryone) {
      await _db
          .from(SupabaseConstants.messagesTable)
          .update({'deleted_for_everyone': true, 'text': '', 'media_url': ''})
          .eq('id', messageId)
          .eq('sender_id', _uid);
    } else {
      final msg = await _db
          .from(SupabaseConstants.messagesTable)
          .select('sender_id')
          .eq('id', messageId)
          .maybeSingle();
      if (msg == null) return;
      if (msg['sender_id'] == _uid) {
        await _db
            .from(SupabaseConstants.messagesTable)
            .update({'deleted_for_sender': true})
            .eq('id', messageId);
      } else {
        await _db
            .from(SupabaseConstants.messagesTable)
            .update({'deleted_for_receiver': true})
            .eq('id', messageId);
      }
    }
  }

  Future<void> addReaction(String messageId, String emoji) async {
    await _db.from(SupabaseConstants.reactionsTable).upsert({
      'message_id': messageId,
      'user_id': _uid,
      'emoji': emoji,
    });
  }

  Future<void> removeReaction(String messageId) async {
    await _db
        .from(SupabaseConstants.reactionsTable)
        .delete()
        .eq('message_id', messageId)
        .eq('user_id', _uid);
  }

  Future<void> clearChat(String chatId) async {
    final msgs = await _db
        .from(SupabaseConstants.messagesTable)
        .select('id, sender_id')
        .eq('chat_id', chatId);
    for (final m in msgs) {
      if (m['sender_id'] == _uid) {
        await _db
            .from(SupabaseConstants.messagesTable)
            .update({'deleted_for_sender': true})
            .eq('id', m['id']);
      } else {
        await _db
            .from(SupabaseConstants.messagesTable)
            .update({'deleted_for_receiver': true})
            .eq('id', m['id']);
      }
    }
  }

  Future<void> toggleStar(String messageId, bool star) async {
    if (star) {
      await _db.from(SupabaseConstants.starredMessagesTable).insert({
        'user_id': _uid,
        'message_id': messageId,
      });
    } else {
      await _db
          .from(SupabaseConstants.starredMessagesTable)
          .delete()
          .eq('user_id', _uid)
          .eq('message_id', messageId);
    }
  }

  Future<List<UserModel>> searchUsers(String query) async {
    final contacts = await _db
        .from('saved_contacts')
        .select('contact_id, nickname')
        .eq('user_id', _uid);
    final nicknameMap = {
      for (var c in contacts) c['contact_id']: c['nickname'],
    };

    final data = await _db
        .from(SupabaseConstants.usersTable)
        .select()
        .neq('id', _uid)
        .or(
          'name.ilike.%$query%,email.ilike.%$query%,phone_info.ilike.%$query%',
        )
        .limit(20);
    return data.map<UserModel>((m) {
      var user = UserModel.fromMap(m);
      if (nicknameMap.containsKey(user.id) &&
          nicknameMap[user.id] != null &&
          nicknameMap[user.id].toString().isNotEmpty) {
        user = user.copyWith(name: nicknameMap[user.id].toString());
      }
      return user;
    }).toList();
  }

  Future<List<UserModel>> getAllUsers() async {
    final contacts = await _db
        .from('saved_contacts')
        .select('contact_id, nickname')
        .eq('user_id', _uid);
    final nicknameMap = {
      for (var c in contacts) c['contact_id']: c['nickname'],
    };

    final data = await _db
        .from(SupabaseConstants.usersTable)
        .select()
        .neq('id', _uid)
        .order('name');
    return data.map<UserModel>((m) {
      var user = UserModel.fromMap(m);
      if (nicknameMap.containsKey(user.id) &&
          nicknameMap[user.id] != null &&
          nicknameMap[user.id].toString().isNotEmpty) {
        user = user.copyWith(name: nicknameMap[user.id].toString());
      }
      return user;
    }).toList();
  }

  Future<UserModel?> getUserById(String userId) async {
    final data = await _db
        .from(SupabaseConstants.usersTable)
        .select()
        .eq('id', userId)
        .maybeSingle();
    return data != null ? UserModel.fromMap(data) : null;
  }

  Future<void> blockUser(String targetId) async {
    await _db.from(SupabaseConstants.blockedUsersTable).insert({
      'user_id': _uid,
      'blocked_user_id': targetId,
    });
  }

  Future<void> unblockUser(String targetId) async {
    await _db
        .from(SupabaseConstants.blockedUsersTable)
        .delete()
        .eq('user_id', _uid)
        .eq('blocked_user_id', targetId);
  }

  Future<bool> isUserBlocked(String targetId) async {
    final data = await _db
        .from(SupabaseConstants.blockedUsersTable)
        .select('id')
        .eq('user_id', _uid)
        .eq('blocked_user_id', targetId)
        .maybeSingle();
    return data != null;
  }

  Future<void> _updateChatLastMessage(
    String chatId,
    String msg,
    String type,
  ) async {
    await _db
        .from(SupabaseConstants.chatsTable)
        .update({
          'last_message': msg,
          'last_message_at': DateTime.now().toUtc().toIso8601String(),
          'last_message_type': type,
        })
        .eq('id', chatId);
  }
}
