import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio/just_audio.dart';
import '../core/constants/supabase_constants.dart';
import '../models/models.dart';
import 'xmechat_root.dart';
import 'windows_notifier.dart';
import 'dart:io';

class CallService {
  static final CallService instance = CallService._();
  CallService._();

  final _supabase = Supabase.instance.client;
  RealtimeChannel? _callChannel;
  Timer? _backupTimer;
  String? _activeIncomingCallId;
  final AudioPlayer _ringtonePlayer = AudioPlayer();
  final Set<String> _processedIds = {};

  Future<void> start(String userId) async {
    _processedIds.clear();
    _listenForCalls(userId);
    _startBackupCallPoller(userId);
    debugPrint('CallService: Started for user $userId');
  }

  void _listenForCalls(String userId) {
    _callChannel = _supabase
        .channel('call_svc:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: SupabaseConstants.callsTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: userId,
          ),
          callback: (payload) {
            final row = payload.newRecord;
            if (row.isEmpty) return;
            final id = row['id']?.toString() ?? '';
            if (id.isNotEmpty) {
              if (_processedIds.contains(id)) return;
              _processedIds.add(id);
            }
            _handleIncomingCall(userId, row);
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: SupabaseConstants.callsTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: userId,
          ),
          callback: (payload) {
            final row = payload.newRecord;
            final status = row['status']?.toString() ?? '';
            if (status == 'ended' || status == 'rejected' || status == 'missed') {
              _ringtonePlayer.stop();
            }
          },
        )
        .subscribe();
  }

  void _startBackupCallPoller(String userId) {
    _backupTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _pollForCalls(userId);
    });
  }

  Future<void> _handleIncomingCall(String myId, Map<String, dynamic> row) async {
    final status = row['status']?.toString() ?? '';
    if (status != 'ringing') return;
    if (row['caller_id']?.toString() == myId) return; // skip self-calls

    if (_activeIncomingCallId == row['id']?.toString()) return;
    _activeIncomingCallId = row['id']?.toString();

    try {
      final prefs = await SharedPreferences.getInstance();
      final notify = prefs.getBool('notify_calls') ?? true;
      if (!notify) return;

      _playRingtone(prefs);

      final callerId = row['caller_id']?.toString() ?? '';
      final callerData = await _supabase
          .from(SupabaseConstants.usersTable)
          .select('name')
          .eq('id', callerId)
          .maybeSingle();
      final callerName = callerData?['name']?.toString() ?? 'Unknown';
      final isVideo = row['type']?.toString() == 'video';
      final title = isVideo ? 'Incoming video call' : 'Incoming voice call';

      final callModel = CallModel.fromMap(row);

      if (!kIsWeb && Platform.isWindows && WindowsNotifier.instance.isReady) {
        await WindowsNotifier.instance.show(
          title: title,
          body: callerName,
          onClick: () => XmeChatRoot.instance.showIncomingCall(callModel),
        );
      }

      XmeChatRoot.instance.showIncomingCall(callModel);
    } catch (e) {
      debugPrint('CallService: Error handling call: $e');
    }
  }

  Future<void> _playRingtone(SharedPreferences prefs) async {
    try {
      await _ringtonePlayer.setLoopMode(LoopMode.one);
      final ringtonePath = prefs.getString('ringtone_path');
      if (ringtonePath != null && ringtonePath.isNotEmpty) {
        if (ringtonePath.startsWith('http')) {
          await _ringtonePlayer.setUrl(ringtonePath);
        } else {
          await _ringtonePlayer.setFilePath(ringtonePath);
        }
      } else {
        await _ringtonePlayer.setUrl('https://actions.google.com/sounds/v1/alarms/phone_alerts_and_rings_01.ogg');
      }
      await _ringtonePlayer.play();
    } catch (_) {}
  }

  Future<void> _pollForCalls(String userId) async {
    try {
      final timeThreshold = DateTime.now()
          .subtract(const Duration(minutes: 2))
          .toUtc()
          .toIso8601String();

      final calls = await _supabase
          .from(SupabaseConstants.callsTable)
          .select()
          .eq('receiver_id', userId)
          .eq('status', 'ringing')
          .gt('created_at', timeThreshold);

      for (final row in calls) {
        final id = row['id']?.toString() ?? '';
        if (id.isNotEmpty && !_processedIds.contains(id)) {
          _processedIds.add(id);
          _handleIncomingCall(userId, row);
        }
      }
    } catch (e) {
      debugPrint('CallService: Backup poll error: $e');
    }
  }

  Future<void> stop() async {
    _backupTimer?.cancel();
    _backupTimer = null;
    _ringtonePlayer.stop();
    _ringtonePlayer.dispose();
    try {
      await _callChannel?.unsubscribe();
    } catch (_) {}
    _callChannel = null;
    _activeIncomingCallId = null;
    debugPrint('CallService: Stopped');
  }
}
