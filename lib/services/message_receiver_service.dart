import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/supabase_constants.dart';
import 'xmechat_root.dart';
import 'windows_notifier.dart';
import 'dart:io';

class MessageReceiverService {
  static final MessageReceiverService instance = MessageReceiverService._();
  MessageReceiverService._();

  final _supabase = Supabase.instance.client;
  RealtimeChannel? _primaryChannel;
  Timer? _backupTimer;
  Timer? _healthCheckTimer;
  bool _primaryActive = false;
  bool _running = false;
  final Set<String> _processedIds = {};
  DateTime? _lastPollTime;

  Future<void> start(String userId) async {
    _running = true;
    _lastPollTime = DateTime.now();
    _processedIds.clear();
    _startPrimaryChannel(userId);
    _startBackupPoller(userId);
    _startHealthCheck();
    debugPrint('MessageReceiverService: Started for user $userId');
  }

  void _startPrimaryChannel(String userId) {
    _primaryChannel = _supabase
        .channel('msg_receiver:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: SupabaseConstants.messagesTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: userId,
          ),
          callback: (payload) {
            _primaryActive = true;
            final msg = payload.newRecord;
            if (msg.isEmpty) return;
            final id = msg['id']?.toString() ?? '';
            if (id.isNotEmpty) {
              if (_processedIds.contains(id)) return;
              _processedIds.add(id);
            }
            _handleNewMessage(userId, msg);
          },
        )
        .subscribe();
  }

  void _startBackupPoller(String userId) {
    _backupTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!_running) return;
      // If primary channel hasn't received anything in a while, poll
      if (!_primaryActive) {
        _pollForMessages(userId);
      }
      // Always poll as backup in case primary missed something
      _pollForMessages(userId);
    });
  }

  void _startHealthCheck() {
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_primaryActive) {
        debugPrint('MessageReceiverService: Primary channel seems inactive, restarting...');
      }
    });
  }

  Future<void> _handleNewMessage(String myId, Map<String, dynamic> msg) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notify = prefs.getBool('notify_messages') ?? true;
      if (!notify) return;

      final senderData = await _supabase
          .from(SupabaseConstants.usersTable)
          .select('name, avatar_url')
          .eq('id', msg['sender_id'] as String)
          .maybeSingle();

      final senderName = senderData?['name']?.toString() ?? 'Someone';
      final preview = msg['type'] == 'text'
          ? (msg['text'] as String? ?? '')
          : '\uD83D\uDCCC Attachment';
      final chatId = msg['chat_id']?.toString() ?? '';

      if (!kIsWeb && Platform.isWindows && WindowsNotifier.instance.isReady) {
        await WindowsNotifier.instance.show(
          title: senderName,
          body: preview,
          onClick: () {
            if (chatId.isEmpty) return;
            XmeChatRoot.instance.navigateToChat(chatId);
          },
        );
      }
    } catch (e) {
      debugPrint('MessageReceiverService: Error handling message: $e');
    }
  }

  Future<void> _pollForMessages(String userId) async {
    try {
      final timeThreshold = _lastPollTime?.toUtc().toIso8601String() ??
          DateTime.now().subtract(const Duration(minutes: 5)).toUtc().toIso8601String();

      final messages = await _supabase
          .from(SupabaseConstants.messagesTable)
          .select('id, chat_id, sender_id, text, type, created_at, receiver_id')
          .eq('receiver_id', userId)
          .gt('created_at', timeThreshold);

      for (final msg in messages) {
        final id = msg['id']?.toString() ?? '';
        if (id.isNotEmpty && !_processedIds.contains(id)) {
          _processedIds.add(id);
          final createdAtStr = msg['created_at']?.toString() ?? '';
          final createdAt = DateTime.tryParse(createdAtStr)?.toLocal();
          if (createdAt != null && _lastPollTime != null && createdAt.isAfter(_lastPollTime!)) {
            _handleNewMessage(userId, msg);
          }
        }
      }
      _lastPollTime = DateTime.now();
    } catch (e) {
      debugPrint('MessageReceiverService: Poll error: $e');
    }
  }

  Future<void> stop() async {
    _running = false;
    _backupTimer?.cancel();
    _backupTimer = null;
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
    try {
      await _primaryChannel?.unsubscribe();
    } catch (_) {}
    _primaryChannel = null;
    _primaryActive = false;
    debugPrint('MessageReceiverService: Stopped');
  }
}
