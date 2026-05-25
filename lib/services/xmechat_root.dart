import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/desktop.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/supabase_constants.dart';
import '../core/navigation/app_navigator.dart';
import '../models/models.dart';
import 'windows_notifier.dart';
import 'message_receiver_service.dart';
import 'call_service.dart';
import 'chat_service.dart';

class XmeChatRoot {
  static final XmeChatRoot instance = XmeChatRoot._();
  XmeChatRoot._();

  final _supabase = Supabase.instance.client;
  late final ChatService _chatService;
  bool _initialized = false;
  bool _uiReady = false;

  StreamSubscription<AuthState>? _authSub;

  RealtimeChannel? _messageChannel;
  RealtimeChannel? _callChannel;
  final List<RealtimeChannel> _groupMessageChannels = [];

  String? _activeIncomingCallId;
  final List<VoidCallback> _pendingNav = [];

  Timer? _fallbackTimer;
  Timer? _disappearTimer;
  Timer? _pingTimer;
  final Set<String> _processedNotificationIds = {};
  DateTime? _lastPollTime;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Only run native features on Windows desktop (not web)
    if (!kIsWeb && Platform.isWindows) {
      await WindowsNotifier.instance.init();
      await _applyWindowsAutoStartSetting();
    }

    _listenAuthAndAttach();
  }

  /// App (UI/router) ready signal, called from `XmeChat` root widget.
  void markUiReady() {
    _uiReady = true;
    _flushPendingNav();
  }

  Future<void> setWindowsAutoStartEnabled(bool enabled) async {
    if (kIsWeb || !Platform.isWindows) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('windows_autostart', enabled);
    await _setWindowsAutoStart(enabled);
  }

  Future<void> detachForLogout() async {
    _pendingNav.clear();
    _initialized = false;
    _uiReady = false;
    _activeIncomingCallId = null;
    await _disposeRealtime();
  }

  void _listenAuthAndAttach() {
    // Start immediately if already logged-in
    final uid = _supabase.auth.currentUser?.id;
    if (uid != null && uid.isNotEmpty) {
      unawaited(_attachRealtimeForUser(uid));
    }

    // Restart listeners on login/logout
    _authSub = _supabase.auth.onAuthStateChange.listen((event) {
      final userId = event.session?.user.id;
      if (userId == null || userId.isEmpty) {
        unawaited(_disposeRealtime());
        // Force navigate to login when signed out
        if (event.event == AuthChangeEvent.signedOut) {
          _navigateOrQueue(() {
            final ctx = rootNavigatorKey.currentContext;
            if (ctx == null) return;
            GoRouter.of(ctx).go('/login');
          });
        }
      } else {
        unawaited(_attachRealtimeForUser(userId));
      }
    });
  }

  Future<void> _applyWindowsAutoStartSetting() async {
    if (kIsWeb || !Platform.isWindows) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool('windows_autostart') ?? true;
      await _setWindowsAutoStart(enabled);
    } catch (e) {
      debugPrint('XmeChatRoot: auto-start registration skipped: $e');
    }
  }

  Future<void> _setWindowsAutoStart(bool enable) async {
    if (kIsWeb || !Platform.isWindows) return;

    final key = Registry.currentUser.createKey(
      r'Software\Microsoft\Windows\CurrentVersion\Run',
    );
    const valueName = 'XmeChat';
    if (enable) {
      // In debug this may point to flutter/dart; in release it points to app exe.
      key.createValue(
        RegistryValue(
          valueName,
          RegistryValueType.string,
          '"${Platform.resolvedExecutable}"',
        ),
      );
    } else {
      try {
        key.deleteValue(valueName);
      } catch (_) {}
    }
    key.close();
  }

  Future<void> _attachRealtimeForUser(String userId) async {
    await _disposeRealtime();
    _chatService = ChatService(userId);
    await MessageReceiverService.instance.start(userId);
    await CallService.instance.start(userId);

    _lastPollTime = DateTime.now();
    _processedNotificationIds.clear();

    _fallbackTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
      _pollFallbackUpdates(userId);
    });

    _disappearTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      unawaited(_chatService.deleteExpiredMessages());
    });

    // Keep realtime connection alive with ping every 25 seconds
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      try { _supabase.realtime.setAuth(''); } catch (_) {}
    });

    // ── Private messages INSERT (new message) ────────────────────────────────
    _messageChannel = _supabase
        .channel('bg_messages:$userId')
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
            final msg = payload.newRecord;
            if (msg.isEmpty) return;
            final id = msg['id']?.toString() ?? '';
            if (id.isNotEmpty) {
              if (_processedNotificationIds.contains(id)) return;
              _processedNotificationIds.add(id);
            }
            unawaited(_onNewMessage(userId, msg));
          },
        )
        .subscribe();

    // ── Calls (insert/update) ───────────────────────────────────────────────
    _callChannel = _supabase
        .channel('bg_calls:$userId')
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
              if (_processedNotificationIds.contains(id)) return;
              _processedNotificationIds.add(id);
            }
            unawaited(_onCallRow(userId, row));
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
            if (row.isEmpty) return;
            final id = row['id']?.toString() ?? '';
            if (id.isNotEmpty) {
              if (_processedNotificationIds.contains(id)) return;
              _processedNotificationIds.add(id);
            }
            unawaited(_onCallRow(userId, row));
          },
        )
        .subscribe();

    // ── Group messages (optional) ───────────────────────────────────────────
    await _attachGroupListeners(userId);
  }

  Future<void> _attachGroupListeners(String userId) async {
    _groupMessageChannels.clear();

    try {
      final rows = await _supabase
          .from(SupabaseConstants.groupMembersTable)
          .select('group_id')
          .eq('user_id', userId);
      final groupIds = rows
          .map<String>((r) => r['group_id']?.toString() ?? '')
          .where((g) => g.isNotEmpty)
          .toList();
      for (final gid in groupIds) {
        final ch = _supabase
            .channel('bg_group_messages:$gid')
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: SupabaseConstants.groupMessagesTable,
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'group_id',
                value: gid,
              ),
              callback: (payload) {
                final msg = payload.newRecord;
                if (msg.isEmpty) return;
                if (msg['sender_id']?.toString() == userId) return;
                final id = msg['id']?.toString() ?? '';
                if (id.isNotEmpty) {
                  if (_processedNotificationIds.contains(id)) return;
                  _processedNotificationIds.add(id);
                }
                unawaited(_onNewGroupMessage(userId, msg));
              },
            )
            .subscribe();
        _groupMessageChannels.add(ch);
      }
    } catch (e) {
      debugPrint('XmeChatRoot: group listeners skipped: $e');
    }
  }

  Future<void> _onNewMessage(String myId, Map<String, dynamic> msg) async {
    try {
      if (msg['sender_id']?.toString() == myId) return;
      final prefs = await SharedPreferences.getInstance();
      final notify = prefs.getBool('notify_messages') ?? true;
      if (!notify) return;

      final senderData = await _supabase
          .from(SupabaseConstants.usersTable)
          .select()
          .eq('id', msg['sender_id'] as String)
          .maybeSingle();

      final sender = senderData == null ? null : UserModel.fromMap(senderData);
      final senderName = sender?.name ?? 'Someone';
      final preview = msg['type'] == 'text'
          ? (msg['text'] as String? ?? '')
          : '📎 Attachment';

      // Windows toast
      if (!kIsWeb && Platform.isWindows && WindowsNotifier.instance.isReady) {
        final chatId = msg['chat_id']?.toString() ?? '';
        await WindowsNotifier.instance.show(
          title: senderName,
          body: preview,
          onClick: () {
            if (chatId.isEmpty) return;
            _navigateOrQueue(() {
              final ctx = rootNavigatorKey.currentContext;
              if (ctx == null) return;
              GoRouter.of(ctx).go('/chat/$chatId', extra: {'user': sender});
            });
          },
        );
      }
      // Always show in-app notification (visible when app is focused)
      _showInAppNotification(senderName, preview);
    } catch (e) {
      debugPrint('XmeChatRoot: message notification error: $e');
    }
  }

  Future<void> _onNewGroupMessage(String myId, Map<String, dynamic> msg) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notify = prefs.getBool('notify_messages') ?? true;
      if (!notify) return;

      final senderId = msg['sender_id']?.toString() ?? '';
      final senderData = await _supabase
          .from(SupabaseConstants.usersTable)
          .select()
          .eq('id', senderId)
          .maybeSingle();
      final sender = senderData == null ? null : UserModel.fromMap(senderData);

      final groupId = msg['group_id']?.toString() ?? '';
      final groupRow = await _supabase
          .from(SupabaseConstants.groupsTable)
          .select('id, name')
          .eq('id', groupId)
          .maybeSingle();
      final groupName = groupRow?['name']?.toString() ?? 'Group';

      final preview = msg['type'] == 'text'
          ? (msg['text'] as String? ?? '')
          : '📎 Media';

      if (!kIsWeb && Platform.isWindows && WindowsNotifier.instance.isReady) {
        await WindowsNotifier.instance.show(
          title: '$groupName • ${sender?.name ?? "Someone"}',
          body: preview,
          onClick: () {
            if (groupId.isEmpty) return;
            _navigateOrQueue(() {
              final ctx = rootNavigatorKey.currentContext;
              if (ctx == null) return;
              GoRouter.of(ctx).go(
                '/group-chat/$groupId',
                extra: {
                  'group': groupRow == null
                      ? null
                      : GroupModel.fromMap(groupRow),
                },
              );
            });
          },
        );
      } else {
        debugPrint('XmeChatRoot 👥 New group msg in $groupName: $preview');
      }
    } catch (e) {
      debugPrint('XmeChatRoot: group message notification error: $e');
    }
  }

  Future<void> _onCallRow(String myId, Map<String, dynamic> row) async {
    final status = row['status']?.toString() ?? '';
    if (status != 'ringing') return;
    if (row['receiver_id']?.toString() != myId) return;

    if (_activeIncomingCallId == row['id']?.toString()) return;
    _activeIncomingCallId = row['id']?.toString();

    try {
      final prefs = await SharedPreferences.getInstance();
      final notify = prefs.getBool('notify_calls') ?? true;
      if (!notify) return;

      final callerId = row['caller_id']?.toString() ?? '';
      final callerData = await _supabase
          .from(SupabaseConstants.usersTable)
          .select()
          .eq('id', callerId)
          .maybeSingle();
      final callerName = callerData?['name']?.toString() ?? 'Unknown';
      final isVideo = row['type']?.toString() == 'video';
      final title = isVideo ? 'Incoming video call' : 'Incoming voice call';

      final callModel = CallModel.fromMap(row);

      // Toast notification
      if (!kIsWeb && Platform.isWindows && WindowsNotifier.instance.isReady) {
        await WindowsNotifier.instance.show(
          title: title,
          body: callerName,
          onClick: () => _showIncomingCallPopup(callModel),
        );
      }

      _showIncomingCallPopup(callModel);
    } catch (e) {
      debugPrint('XmeChatRoot: call notification error: $e');
    }
  }

  // Show top-right in-app notification for new messages
  void _showInAppNotification(String title, String body) {
    _navigateOrQueue(() {
      final ctx = rootNavigatorKey.currentContext;
      if (ctx == null) return;
      ScaffoldMessenger.of(ctx).showSnackBar(
        SnackBar(
          content: Text('$title: $body', maxLines: 2, overflow: TextOverflow.ellipsis),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            top: 8,
            left: 8,
            right: 8,
            bottom: MediaQuery.of(ctx).size.height - 120,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    });
  }

  void _showIncomingCallPopup(CallModel call) {
    _navigateOrQueue(() {
      if (!kIsWeb && Platform.isWindows) {
        try {
          appWindow.show();
          try {
            // Some window managers require restore to bring to front.
            appWindow.restore();
          } catch (_) {}
        } catch (_) {}
      }

      final ctx = rootNavigatorKey.currentContext;
      if (ctx == null) return;
      GoRouter.of(ctx).push('/incoming-call', extra: call);
    });
  }

  void _navigateOrQueue(VoidCallback action) {
    if (_uiReady && rootNavigatorKey.currentContext != null) {
      action();
      return;
    }
    _pendingNav.add(action);
  }

  void _flushPendingNav() {
    if (!_uiReady) return;
    if (rootNavigatorKey.currentContext == null) return;
    if (_pendingNav.isEmpty) return;
    final actions = List<VoidCallback>.from(_pendingNav);
    _pendingNav.clear();
    for (final a in actions) {
      try {
        a();
      } catch (_) {}
    }
  }

  Future<void> _pollFallbackUpdates(String userId) async {
    try {
      final timeThreshold = DateTime.now()
          .subtract(const Duration(minutes: 1))
          .toUtc()
          .toIso8601String();

      // 1. Fallback for private messages
      final messages = await _supabase
          .from(SupabaseConstants.messagesTable)
          .select()
          .eq('receiver_id', userId)
          .gt('created_at', timeThreshold);
      for (final msg in messages) {
        final id = msg['id']?.toString() ?? '';
        if (id.isNotEmpty && !_processedNotificationIds.contains(id)) {
          _processedNotificationIds.add(id);
          if (_lastPollTime != null) {
            final createdAtStr = msg['created_at']?.toString() ?? '';
            final createdAt = DateTime.tryParse(createdAtStr)?.toLocal();
            if (createdAt != null && createdAt.isAfter(_lastPollTime!)) {
              unawaited(_onNewMessage(userId, msg));
            }
          }
        }
      }

      // 2. Fallback for group messages
      final memberRows = await _supabase
          .from(SupabaseConstants.groupMembersTable)
          .select('group_id')
          .eq('user_id', userId);
      final groupIds = memberRows
          .map<String>((r) => r['group_id']?.toString() ?? '')
          .where((g) => g.isNotEmpty)
          .toList();
      if (groupIds.isNotEmpty) {
        final groupMsgs = await _supabase
            .from(SupabaseConstants.groupMessagesTable)
            .select()
            .inFilter('group_id', groupIds)
            .gt('created_at', timeThreshold);
        for (final msg in groupMsgs) {
          final id = msg['id']?.toString() ?? '';
          if (msg['sender_id']?.toString() == userId) continue;
          if (id.isNotEmpty && !_processedNotificationIds.contains(id)) {
            _processedNotificationIds.add(id);
            if (_lastPollTime != null) {
              final createdAtStr = msg['created_at']?.toString() ?? '';
              final createdAt = DateTime.tryParse(createdAtStr)?.toLocal();
              if (createdAt != null && createdAt.isAfter(_lastPollTime!)) {
                unawaited(_onNewGroupMessage(userId, msg));
              }
            }
          }
        }
      }

      // 3. Fallback for ringing calls
      final calls = await _supabase
          .from(SupabaseConstants.callsTable)
          .select()
          .eq('receiver_id', userId)
          .eq('status', 'ringing')
          .gt('created_at', timeThreshold);
      for (final row in calls) {
        final id = row['id']?.toString() ?? '';
        if (id.isNotEmpty && !_processedNotificationIds.contains(id)) {
          _processedNotificationIds.add(id);
          if (_lastPollTime != null) {
            final createdAtStr = row['created_at']?.toString() ?? '';
            final createdAt = DateTime.tryParse(createdAtStr)?.toLocal();
            if (createdAt != null && createdAt.isAfter(_lastPollTime!)) {
              unawaited(_onCallRow(userId, row));
            }
          }
        }
      }
    } catch (e) {
      debugPrint('XmeChatRoot: Fallback poll error: $e');
    }
  }

  // ── Navigation Helpers (for services without context) ─────
  void navigateToChat(String chatId) {
    _navigateOrQueue(() {
      final ctx = rootNavigatorKey.currentContext;
      if (ctx == null) return;
      GoRouter.of(ctx).go('/chat/$chatId');
    });
  }

  void showIncomingCall(CallModel call) {
    _showIncomingCallPopup(call);
  }

  Future<void> _disposeRealtime() async {
    _fallbackTimer?.cancel();
    _fallbackTimer = null;
    _disappearTimer?.cancel();
    _disappearTimer = null;
    _pingTimer?.cancel();
    _pingTimer = null;
    _processedNotificationIds.clear();
    _lastPollTime = null;

    await MessageReceiverService.instance.stop();
    await CallService.instance.stop();

    try {
      await _messageChannel?.unsubscribe();
    } catch (_) {}
    try {
      await _callChannel?.unsubscribe();
    } catch (_) {}
    for (final ch in _groupMessageChannels) {
      try {
        await ch.unsubscribe();
      } catch (_) {}
    }
    _groupMessageChannels.clear();
    _messageChannel = null;
    _callChannel = null;
    _activeIncomingCallId = null;
  }

  Future<void> dispose() async {
    await _authSub?.cancel();
    await _disposeRealtime();
    _authSub = null;
  }
}
