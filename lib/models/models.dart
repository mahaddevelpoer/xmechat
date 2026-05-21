// =====================================================
// ALL MODELS for XmeChat
// =====================================================

// ── UserModel ──────────────────────────────────────
class UserModel {
  final String id;
  final String email;
  final String name;
  final String phoneInfo;
  final String avatarUrl;
  final String bio;
  final DateTime lastSeen;
  final bool isOnline;
  final String pushToken;
  final DateTime createdAt;
  final bool isPrivate;

  const UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.phoneInfo = '',
    this.avatarUrl = '',
    this.bio = '',
    required this.lastSeen,
    this.isOnline = false,
    this.pushToken = '',
    required this.createdAt,
    this.isPrivate = false,
  });

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
    id: map['id'] ?? '',
    email: map['email'] ?? '',
    name: map['name'] ?? '',
    phoneInfo: map['phone_info'] ?? '',
    avatarUrl: map['avatar_url'] ?? '',
    bio: map['bio'] ?? '',
    lastSeen: map['last_seen'] != null ? DateTime.parse(map['last_seen']).toLocal() : DateTime.now(),
    isOnline: map['is_online'] ?? false,
    pushToken: map['push_token'] ?? '',
    createdAt: map['created_at'] != null ? DateTime.parse(map['created_at']).toLocal() : DateTime.now(),
    isPrivate: map['is_private'] ?? false,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'email': email,
    'name': name,
    'phone_info': phoneInfo,
    'avatar_url': avatarUrl,
    'bio': bio,
    'last_seen': lastSeen.toUtc().toIso8601String(),
    'is_online': isOnline,
    'push_token': pushToken,
    'is_private': isPrivate,
  };

  UserModel copyWith({
    String? name,
    String? phoneInfo,
    String? avatarUrl,
    String? bio,
    DateTime? lastSeen,
    bool? isOnline,
    String? pushToken,
    bool? isPrivate,
  }) => UserModel(
    id: id,
    email: email,
    name: name ?? this.name,
    phoneInfo: phoneInfo ?? this.phoneInfo,
    avatarUrl: avatarUrl ?? this.avatarUrl,
    bio: bio ?? this.bio,
    lastSeen: lastSeen ?? this.lastSeen,
    isOnline: isOnline ?? this.isOnline,
    pushToken: pushToken ?? this.pushToken,
    createdAt: createdAt,
    isPrivate: isPrivate ?? this.isPrivate,
  );
}

// ── ChatModel ──────────────────────────────────────
class ChatModel {
  final String id;
  final String user1Id;
  final String user2Id;
  final String lastMessage;
  final DateTime lastMessageAt;
  final String lastMessageType;
  final DateTime createdAt;
  int disappearTimer;
  UserModel? otherUser;
  int unreadCount;

  ChatModel({
    required this.id,
    required this.user1Id,
    required this.user2Id,
    this.lastMessage = '',
    required this.lastMessageAt,
    this.lastMessageType = 'text',
    required this.createdAt,
    this.disappearTimer = 0,
    this.otherUser,
    this.unreadCount = 0,
  });

  /// Supports both legacy schema:
  /// - chats(user1_id, user2_id)
  /// and new schema:
  /// - conversations(participant_1, participant_2)
  factory ChatModel.fromMap(Map<String, dynamic> map) => ChatModel(
    id: map['id'] ?? '',
    user1Id: map['participant_1'] ?? map['user1_id'] ?? '',
    user2Id: map['participant_2'] ?? map['user2_id'] ?? '',
    lastMessage: map['last_message'] ?? '',
    lastMessageAt: map['last_message_at'] != null
        ? DateTime.parse(map['last_message_at']).toLocal()
        : DateTime.now(),
    lastMessageType: map['last_message_type'] ?? 'text',
    createdAt: map['created_at'] != null
        ? DateTime.parse(map['created_at']).toLocal()
        : DateTime.now(),
    disappearTimer: map['disappear_timer'] ?? 0,
  );

  String getOtherUserId(String myId) => user1Id == myId ? user2Id : user1Id;
}

// ── MessageType ────────────────────────────────────
enum MessageType {
  text, image, video, audio, document, location,
  contact, gif, sticker, viewOnce, poll, deleted
}

extension MessageTypeExt on MessageType {
  String get value => name;
  static MessageType fromString(String s) =>
      MessageType.values.firstWhere((e) => e.name == s, orElse: () => MessageType.text);
}

// ── MessageStatus ──────────────────────────────────
enum MessageStatus { sending, sent, delivered, read }

// ── MessageModel ───────────────────────────────────
class MessageModel {
  final String id;
  final String? chatId;
  final String? groupId;
  final String senderId;
  final String? receiverId;
  final String text;
  final MessageType type;
  final String mediaUrl;
  final String fileName;
  final int fileSize;
  final int duration;
  final String? replyTo;
  final String replyPreview;
  final bool isForwarded;
  final bool isStarred;
  final bool isViewOnce;
  final bool viewOnceOpened;
  final MessageStatus status;
  final DateTime? seenAt;
  final DateTime? deliveredAt;
  final double? latitude;
  final double? longitude;
  final String locationName;
  final String contactName;
  final String contactPhone;
  final bool deletedForSender;
  final bool deletedForReceiver;
  final bool deletedForEveryone;
  final DateTime createdAt;
  List<ReactionModel> reactions;
  UserModel? senderUser;
  MessageModel? replyMessage;

  MessageModel({
    required this.id,
    this.chatId,
    this.groupId,
    required this.senderId,
    this.receiverId,
    this.text = '',
    this.type = MessageType.text,
    this.mediaUrl = '',
    this.fileName = '',
    this.fileSize = 0,
    this.duration = 0,
    this.replyTo,
    this.replyPreview = '',
    this.isForwarded = false,
    this.isStarred = false,
    this.isViewOnce = false,
    this.viewOnceOpened = false,
    this.status = MessageStatus.sent,
    this.seenAt,
    this.deliveredAt,
    this.latitude,
    this.longitude,
    this.locationName = '',
    this.contactName = '',
    this.contactPhone = '',
    this.deletedForSender = false,
    this.deletedForReceiver = false,
    this.deletedForEveryone = false,
    required this.createdAt,
    this.reactions = const [],
    this.senderUser,
    this.replyMessage,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map) => MessageModel(
    id: map['id'] ?? '',
    chatId: map['chat_id'],
    groupId: map['group_id'],
    senderId: map['sender_id'] ?? '',
    receiverId: map['receiver_id'],
    text: map['text'] ?? '',
    type: MessageTypeExt.fromString(map['type'] ?? 'text'),
    mediaUrl: map['media_url'] ?? '',
    fileName: map['file_name'] ?? '',
    fileSize: map['file_size'] ?? 0,
    duration: map['duration'] ?? 0,
    replyTo: map['reply_to'],
    replyPreview: map['reply_preview'] ?? '',
    isForwarded: map['is_forwarded'] ?? false,
    isStarred: map['is_starred'] ?? false,
    isViewOnce: map['is_view_once'] ?? false,
    viewOnceOpened: map['view_once_opened'] ?? false,
    status: _statusFromString(map['status'] ?? 'sent'),
    seenAt: map['seen_at'] != null ? DateTime.parse(map['seen_at']).toLocal() : null,
    deliveredAt: map['delivered_at'] != null ? DateTime.parse(map['delivered_at']).toLocal() : null,
    latitude: (map['latitude'] as num?)?.toDouble(),
    longitude: (map['longitude'] as num?)?.toDouble(),
    locationName: map['location_name'] ?? '',
    contactName: map['contact_name'] ?? '',
    contactPhone: map['contact_phone'] ?? '',
    deletedForSender: map['deleted_for_sender'] ?? false,
    deletedForReceiver: map['deleted_for_receiver'] ?? false,
    deletedForEveryone: map['deleted_for_everyone'] ?? false,
    createdAt: map['created_at'] != null
        ? DateTime.parse(map['created_at']).toLocal()
        : DateTime.now(),
  );

  static MessageStatus _statusFromString(String s) {
    switch (s) {
      case 'sending': return MessageStatus.sending;
      case 'delivered': return MessageStatus.delivered;
      case 'read': return MessageStatus.read;
      default: return MessageStatus.sent;
    }
  }

  Map<String, dynamic> toMap() => {
    'chat_id': chatId,
    'group_id': groupId,
    'sender_id': senderId,
    'receiver_id': receiverId,
    'text': text,
    'type': type.value,
    'media_url': mediaUrl,
    'file_name': fileName,
    'file_size': fileSize,
    'duration': duration,
    'reply_to': replyTo,
    'reply_preview': replyPreview,
    'is_forwarded': isForwarded,
    'is_view_once': isViewOnce,
    'status': status.name,
    'latitude': latitude,
    'longitude': longitude,
    'location_name': locationName,
    'contact_name': contactName,
    'contact_phone': contactPhone,
  };

  bool isDeletedForUser(String uid) =>
      deletedForEveryone ||
      (senderId == uid && deletedForSender) ||
      (receiverId == uid && deletedForReceiver);

  MessageModel copyWith({
    MessageStatus? status,
    DateTime? seenAt,
    DateTime? deliveredAt,
    bool? isStarred,
    List<ReactionModel>? reactions,
    bool? deletedForSender,
    bool? deletedForReceiver,
    bool? deletedForEveryone,
    bool? viewOnceOpened,
  }) => MessageModel(
    id: id, chatId: chatId, groupId: groupId, senderId: senderId,
    receiverId: receiverId, text: text, type: type, mediaUrl: mediaUrl,
    fileName: fileName, fileSize: fileSize, duration: duration,
    replyTo: replyTo, replyPreview: replyPreview, isForwarded: isForwarded,
    isStarred: isStarred ?? this.isStarred, isViewOnce: isViewOnce,
    viewOnceOpened: viewOnceOpened ?? this.viewOnceOpened,
    status: status ?? this.status, seenAt: seenAt ?? this.seenAt,
    deliveredAt: deliveredAt ?? this.deliveredAt,
    latitude: latitude, longitude: longitude, locationName: locationName,
    contactName: contactName, contactPhone: contactPhone,
    deletedForSender: deletedForSender ?? this.deletedForSender,
    deletedForReceiver: deletedForReceiver ?? this.deletedForReceiver,
    deletedForEveryone: deletedForEveryone ?? this.deletedForEveryone,
    createdAt: createdAt, reactions: reactions ?? this.reactions,
    senderUser: senderUser, replyMessage: replyMessage,
  );
}

// ── ReactionModel ──────────────────────────────────
class ReactionModel {
  final String id;
  final String messageId;
  final String userId;
  final String emoji;
  final DateTime createdAt;
  UserModel? user;

  ReactionModel({
    required this.id,
    required this.messageId,
    required this.userId,
    required this.emoji,
    required this.createdAt,
    this.user,
  });

  factory ReactionModel.fromMap(Map<String, dynamic> map) => ReactionModel(
    id: map['id'] ?? '',
    messageId: map['message_id'] ?? '',
    userId: map['user_id'] ?? '',
    emoji: map['emoji'] ?? '',
    createdAt: map['created_at'] != null
        ? DateTime.parse(map['created_at']).toLocal()
        : DateTime.now(),
  );
}

// ── GroupModel ─────────────────────────────────────
class GroupModel {
  final String id;
  final String name;
  final String description;
  final String iconUrl;
  final String createdBy;
  final String lastMessage;
  final DateTime lastMessageAt;
  final String lastMessageType;
  final DateTime createdAt;
  List<GroupMemberModel> members;
  int unreadCount;

  GroupModel({
    required this.id,
    required this.name,
    this.description = '',
    this.iconUrl = '',
    required this.createdBy,
    this.lastMessage = '',
    required this.lastMessageAt,
    this.lastMessageType = 'text',
    required this.createdAt,
    this.members = const [],
    this.unreadCount = 0,
  });

  factory GroupModel.fromMap(Map<String, dynamic> map) => GroupModel(
    id: map['id'] ?? '',
    name: map['name'] ?? '',
    description: map['description'] ?? '',
    iconUrl: map['icon_url'] ?? '',
    createdBy: map['created_by'] ?? '',
    lastMessage: map['last_message'] ?? '',
    lastMessageAt: map['last_message_at'] != null
        ? DateTime.parse(map['last_message_at']).toLocal()
        : DateTime.now(),
    lastMessageType: map['last_message_type'] ?? 'text',
    createdAt: map['created_at'] != null
        ? DateTime.parse(map['created_at']).toLocal()
        : DateTime.now(),
  );
}

// ── GroupMemberModel ───────────────────────────────
class GroupMemberModel {
  final String id;
  final String groupId;
  final String userId;
  final bool isAdmin;
  final DateTime joinedAt;
  UserModel? user;

  GroupMemberModel({
    required this.id,
    required this.groupId,
    required this.userId,
    this.isAdmin = false,
    required this.joinedAt,
    this.user,
  });

  factory GroupMemberModel.fromMap(Map<String, dynamic> map) => GroupMemberModel(
    id: map['id'] ?? '',
    groupId: map['group_id'] ?? '',
    userId: map['user_id'] ?? '',
    isAdmin: map['is_admin'] ?? false,
    joinedAt: map['joined_at'] != null
        ? DateTime.parse(map['joined_at']).toLocal()
        : DateTime.now(),
  );
}

// ── GroupMessageModel ──────────────────────────────
class GroupMessageModel {
  final String id;
  final String groupId;
  final String senderId;
  final String text;
  final MessageType type;
  final String mediaUrl;
  final String fileName;
  final String? replyTo;
  final String replyPreview;
  final String replySenderName;
  final bool isForwarded;
  final bool isStarred;
  final List<String> mentions;
  final bool deletedForEveryone;
  final DateTime createdAt;
  List<ReactionModel> reactions;
  UserModel? senderUser;
  List<String> readBy;

  GroupMessageModel({
    required this.id,
    required this.groupId,
    required this.senderId,
    this.text = '',
    this.type = MessageType.text,
    this.mediaUrl = '',
    this.fileName = '',
    this.replyTo,
    this.replyPreview = '',
    this.replySenderName = '',
    this.isForwarded = false,
    this.isStarred = false,
    this.mentions = const [],
    this.deletedForEveryone = false,
    required this.createdAt,
    this.reactions = const [],
    this.senderUser,
    this.readBy = const [],
  });

  factory GroupMessageModel.fromMap(Map<String, dynamic> map) => GroupMessageModel(
    id: map['id'] ?? '',
    groupId: map['group_id'] ?? '',
    senderId: map['sender_id'] ?? '',
    text: map['text'] ?? '',
    type: MessageTypeExt.fromString(map['type'] ?? 'text'),
    mediaUrl: map['media_url'] ?? '',
    fileName: map['file_name'] ?? '',
    replyTo: map['reply_to'],
    replyPreview: map['reply_preview'] ?? '',
    replySenderName: map['reply_sender_name'] ?? '',
    isForwarded: map['is_forwarded'] ?? false,
    isStarred: map['is_starred'] ?? false,
    mentions: List<String>.from(map['mentions'] ?? []),
    deletedForEveryone: map['deleted_for_everyone'] ?? false,
    createdAt: map['created_at'] != null
        ? DateTime.parse(map['created_at']).toLocal()
        : DateTime.now(),
  );

  Map<String, dynamic> toMap() => {
    'group_id': groupId,
    'sender_id': senderId,
    'text': text,
    'type': type.value,
    'media_url': mediaUrl,
    'file_name': fileName,
    'reply_to': replyTo,
    'reply_preview': replyPreview,
    'reply_sender_name': replySenderName,
    'is_forwarded': isForwarded,
    'mentions': mentions,
  };
}

// ── StatusModel ────────────────────────────────────
class StatusModel {
  final String id;
  final String userId;
  final String contentUrl;
  final String text;
  final String type;
  final String bgColor;
  final DateTime expiresAt;
  final DateTime createdAt;
  UserModel? user;
  List<StatusViewModel> views;
  bool viewedByMe;

  StatusModel({
    required this.id,
    required this.userId,
    this.contentUrl = '',
    this.text = '',
    this.type = 'text',
    this.bgColor = '#075E54',
    required this.expiresAt,
    required this.createdAt,
    this.user,
    this.views = const [],
    this.viewedByMe = false,
  });

  factory StatusModel.fromMap(Map<String, dynamic> map) => StatusModel(
    id: map['id'] ?? '',
    userId: map['user_id'] ?? '',
    contentUrl: map['content_url'] ?? '',
    text: map['text'] ?? '',
    type: map['type'] ?? 'text',
    bgColor: map['bg_color'] ?? '#075E54',
    expiresAt: map['expires_at'] != null
        ? DateTime.parse(map['expires_at']).toLocal()
        : DateTime.now().add(const Duration(hours: 24)),
    createdAt: map['created_at'] != null
        ? DateTime.parse(map['created_at']).toLocal()
        : DateTime.now(),
  );

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class StatusViewModel {
  final String id;
  final String statusId;
  final String viewerId;
  final DateTime viewedAt;
  UserModel? viewer;

  StatusViewModel({
    required this.id,
    required this.statusId,
    required this.viewerId,
    required this.viewedAt,
    this.viewer,
  });

  factory StatusViewModel.fromMap(Map<String, dynamic> map) => StatusViewModel(
    id: map['id'] ?? '',
    statusId: map['status_id'] ?? '',
    viewerId: map['viewer_id'] ?? '',
    viewedAt: map['viewed_at'] != null
        ? DateTime.parse(map['viewed_at']).toLocal()
        : DateTime.now(),
  );
}

// ── CallModel ──────────────────────────────────────
enum CallType { voice, video }
enum CallStatus { ringing, connected, ended, missed, rejected }

class CallModel {
  final String id;
  final String callerId;
  final String receiverId;
  final CallType type;
  CallStatus status;
  final String sdpOffer;
  final String sdpAnswer;
  final DateTime startedAt;
  final DateTime? connectedAt;
  final DateTime? endedAt;
  final int duration;
  final DateTime createdAt;
  UserModel? caller;
  UserModel? receiver;

  CallModel({
    required this.id,
    required this.callerId,
    required this.receiverId,
    this.type = CallType.voice,
    this.status = CallStatus.ringing,
    this.sdpOffer = '',
    this.sdpAnswer = '',
    required this.startedAt,
    this.connectedAt,
    this.endedAt,
    this.duration = 0,
    required this.createdAt,
    this.caller,
    this.receiver,
  });

  factory CallModel.fromMap(Map<String, dynamic> map) => CallModel(
    id: map['id'] ?? '',
    callerId: map['caller_id'] ?? '',
    receiverId: map['receiver_id'] ?? '',
    type: map['type'] == 'video' ? CallType.video : CallType.voice,
    status: _statusFromString(map['status'] ?? 'ringing'),
    sdpOffer: map['sdp_offer'] ?? '',
    sdpAnswer: map['sdp_answer'] ?? '',
    startedAt: map['started_at'] != null
        ? DateTime.parse(map['started_at']).toLocal()
        : DateTime.now(),
    connectedAt: map['connected_at'] != null ? DateTime.parse(map['connected_at']).toLocal() : null,
    endedAt: map['ended_at'] != null ? DateTime.parse(map['ended_at']).toLocal() : null,
    duration: map['duration'] ?? 0,
    createdAt: map['created_at'] != null
        ? DateTime.parse(map['created_at']).toLocal()
        : DateTime.now(),
  );

  static CallStatus _statusFromString(String s) {
    switch (s) {
      case 'connected': return CallStatus.connected;
      case 'ended': return CallStatus.ended;
      case 'missed': return CallStatus.missed;
      case 'rejected': return CallStatus.rejected;
      default: return CallStatus.ringing;
    }
  }
}

// ── PollModel ──────────────────────────────────────
class PollModel {
  final String id;
  final String groupId;
  final String createdBy;
  final String question;
  final List<String> options;
  final bool allowMultiple;
  final DateTime createdAt;
  Map<int, List<String>> votes; // optionIndex -> list of userIds

  PollModel({
    required this.id,
    required this.groupId,
    required this.createdBy,
    required this.question,
    required this.options,
    this.allowMultiple = false,
    required this.createdAt,
    this.votes = const {},
  });

  factory PollModel.fromMap(Map<String, dynamic> map) => PollModel(
    id: map['id'] ?? '',
    groupId: map['group_id'] ?? '',
    createdBy: map['created_by'] ?? '',
    question: map['question'] ?? '',
    options: List<String>.from(map['options'] ?? []),
    allowMultiple: map['allow_multiple'] ?? false,
    createdAt: map['created_at'] != null
        ? DateTime.parse(map['created_at']).toLocal()
        : DateTime.now(),
  );
}

/// Broadcast List Model
class BroadcastListModel {
  final String id;
  final String name;
  final String createdBy;
  final DateTime createdAt;
  List<UserModel> members;

  BroadcastListModel({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.createdAt,
    this.members = const [],
  });

  factory BroadcastListModel.fromMap(Map<String, dynamic> map) => BroadcastListModel(
    id: map['id'] ?? '',
    name: map['name'] ?? '',
    createdBy: map['created_by'] ?? '',
    createdAt: map['created_at'] != null
        ? DateTime.parse(map['created_at']).toLocal()
        : DateTime.now(),
    members: map['members'] != null
        ? (map['members'] as List).map((m) => UserModel.fromMap(m['user'] ?? {})).toList()
        : [],
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'created_by': createdBy,
  };
}

/// Broadcast Message Model
class BroadcastMessageModel {
  final String id;
  final String listId;
  final String senderId;
  final String text;
  final String type;
  final String mediaUrl;
  final String fileName;
  final DateTime createdAt;

  BroadcastMessageModel({
    required this.id,
    required this.listId,
    required this.senderId,
    this.text = '',
    this.type = 'text',
    this.mediaUrl = '',
    this.fileName = '',
    required this.createdAt,
  });

  factory BroadcastMessageModel.fromMap(Map<String, dynamic> map) => BroadcastMessageModel(
    id: map['id'] ?? '',
    listId: map['list_id'] ?? '',
    senderId: map['sender_id'] ?? '',
    text: map['text'] ?? '',
    type: map['type'] ?? 'text',
    mediaUrl: map['media_url'] ?? '',
    fileName: map['file_name'] ?? '',
    createdAt: map['created_at'] != null
        ? DateTime.parse(map['created_at']).toLocal()
        : DateTime.now(),
  );
}
