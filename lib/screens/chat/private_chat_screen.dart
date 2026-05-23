import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/common/user_avatar.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/chat/message_bubble.dart';
import '../../widgets/chat/chat_input_bar.dart';

class PrivateChatScreen extends ConsumerStatefulWidget {
  final String chatId;
  final UserModel? otherUser;

  const PrivateChatScreen({
    super.key,
    required this.chatId,
    this.otherUser,
  });

  @override
  ConsumerState<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends ConsumerState<PrivateChatScreen> {
  final _scrollCtrl = ScrollController();

  UserModel? _other;
  bool _loadingUser = false;
  MessageModel? _replyTo;
  bool _enterToSend = false;

  @override
  void initState() {
    super.initState();
    _other = widget.otherUser;
    if (_other == null) _loadOtherUser();
    _markRead();
    _loadPrefs();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await ref.read(settingsProvider.future);
    if (mounted) {
      setState(() => _enterToSend = prefs.getBool('enter_to_send') ?? false);
    }
  }

  Future<void> _loadOtherUser() async {
    setState(() => _loadingUser = true);
    final user = await ref.read(chatServiceProvider).getUserById(
          widget.otherUser?.id ?? '',
        );
    if (mounted) setState(() { _other = user; _loadingUser = false; });
  }

  void _markRead() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatServiceProvider).markAllRead(widget.chatId);
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ── Send handlers ────────────────────────────────────
  Future<void> _sendText(String text) async {
    try {
      await ref.read(chatServiceProvider).sendTextMessage(
            chatId: widget.chatId,
            receiverId: _other?.id ?? '',
            text: text,
            replyTo: _replyTo?.id,
            replyPreview: _replyTo?.text ?? '',
          );
      setState(() => _replyTo = null);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Send failed: $e')),
        );
      }
    }
  }

  Future<void> _sendVoice(Uint8List bytes, int durationMs, String ext) async {
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      await ref.read(chatServiceProvider).sendMediaMessage(
            chatId: widget.chatId,
            receiverId: _other?.id ?? '',
            bytes: bytes,
            type: MessageType.audio,
            fileName: 'voice_$ts.$ext',
            replyTo: _replyTo?.id,
            duration: (durationMs / 1000).round(),
          );
      if (mounted) setState(() => _replyTo = null);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Send failed: $e')),
        );
      }
    }
  }

  Future<void> _sendFile(
      Uint8List bytes, String fileName, MessageType type) async {
    try {
      await ref.read(chatServiceProvider).sendMediaMessage(
            chatId: widget.chatId,
            receiverId: _other?.id ?? '',
            bytes: bytes,
            type: type,
            fileName: fileName,
          );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Send failed: $e')),
        );
      }
    }
  }

  Future<void> _deleteMessage(MessageModel msg) async {
    final uid = ref.read(currentUserIdProvider);
    final choice = await showDialog<String>(
      context: context,
      builder: (_) => _DeleteDialog(isSent: msg.senderId == uid),
    );
    if (choice == null) return;
    try {
      await ref.read(chatServiceProvider).deleteMessage(
            msg.id,
            forEveryone: choice == 'everyone',
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  Future<void> _copyMessage(MessageModel msg) async {
    await Clipboard.setData(ClipboardData(text: msg.text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message copied')),
      );
    }
  }

  Future<void> _startCall(bool isVideo) async {
    try {
      final callId = await ref.read(webrtcServiceProvider).initiateCall(
            _other?.id ?? '',
            isVideo: isVideo,
          );
      if (!mounted) return;
      if (isVideo) {
        context.push('/video-call/$callId',
            extra: {'isCaller': true, 'user': _other, 'sdpOffer': ''});
      } else {
        context.push('/voice-call/$callId',
            extra: {'isCaller': true, 'user': _other, 'sdpOffer': ''});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Call failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUserIdProvider);
    final other = _other;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          // ── Header ──────────────────────────────────
          _ChatHeader(
            user: other,
            loading: _loadingUser,
            onBack: () => context.canPop() ? context.pop() : context.go('/home'),
            onVoiceCall: () => _startCall(false),
            onVideoCall: () => _startCall(true),
            onInfo: () => context.push(
                '/contact/${other?.id ?? ''}',
                extra: {'user': other}),
          ),
          const Divider(height: 1),

          // ── Messages ─────────────────────────────────
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: ref.read(chatServiceProvider).streamMessages(widget.chatId),
              builder: (ctx, snap) {
                if (snap.hasError) return ErrorState(error: snap.error);
                if (!snap.hasData) return const LoadingWidget();

                final rows = snap.data!;
                if (rows.isEmpty) {
                  return const EmptyState(
                    icon: Icons.chat_bubble_outline,
                    title: 'Start chatting!',
                    subtitle: 'Messages are end-to-end encrypted',
                  );
                }

                final msgs = rows
                    .map((r) => MessageModel.fromMap(r))
                    .where((m) => !m.isDeletedForUser(uid))
                    .toList();

                _scrollToBottom();

                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  itemCount: msgs.length,
                  itemBuilder: (_, i) {
                    final msg = msgs[i];
                    final isSent = msg.senderId == uid;
                    final showDate = i == 0 ||
                        !_sameDay(msgs[i - 1].createdAt, msg.createdAt);
                    return Column(
                      children: [
                        if (showDate) _DateChip(dt: msg.createdAt),
                        MessageBubble(
                          message: msg,
                          isSent: isSent,
                          senderName: other?.name,
                          senderAvatarUrl: other?.avatarUrl,
                          onReply: () => setState(() => _replyTo = msg),
                          onDelete: () => _deleteMessage(msg),
                          onCopy: msg.type == MessageType.text
                              ? () => _copyMessage(msg)
                              : null,
                          onForward: () {},
                          onStar: () => ref
                              .read(chatServiceProvider)
                              .toggleStar(msg.id, !msg.isStarred),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // ── Input bar ─────────────────────────────────
          ChatInputBar(
            onSendText: _sendText,
            onSendVoice: _sendVoice,
            onSendFile: _sendFile,
            replyTo: _replyTo,
            onCancelReply: () => setState(() => _replyTo = null),
            enterToSend: _enterToSend,
          ),
        ],
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────

class _ChatHeader extends StatelessWidget {
  final UserModel? user;
  final bool loading;
  final VoidCallback onBack;
  final VoidCallback onVoiceCall;
  final VoidCallback onVideoCall;
  final VoidCallback onInfo;

  const _ChatHeader({
    required this.user,
    required this.loading,
    required this.onBack,
    required this.onVoiceCall,
    required this.onVideoCall,
    required this.onInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSizes.headerHeight,
      color: AppColors.panel,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 20),
            onPressed: onBack,
          ),
          if (loading)
            const CircleAvatar(radius: 19, backgroundColor: AppColors.border)
          else
            UserAvatar(
              imageUrl: user?.avatarUrl,
              name: user?.name ?? '?',
              size: 38,
              showOnline: true,
              isOnline: user?.isOnline ?? false,
              onTap: onInfo,
            ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: onInfo,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user?.name ?? (loading ? 'Loading...' : 'Chat'),
                    style: AppText.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    (user?.isOnline ?? false)
                        ? '● online'
                        : 'last seen recently',
                    style: AppText.caption.copyWith(
                      color: (user?.isOnline ?? false)
                          ? AppColors.online
                          : AppColors.textHint,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.call_outlined, size: 20),
            tooltip: 'Voice Call',
            onPressed: onVoiceCall,
          ),
          IconButton(
            icon: const Icon(Icons.videocam_outlined, size: 20),
            tooltip: 'Video Call',
            onPressed: onVideoCall,
          ),
          IconButton(
            icon: const Icon(Icons.info_outlined, size: 20),
            tooltip: 'Info',
            onPressed: onInfo,
          ),
        ],
      ),
    );
  }
}

// ─── Date chip ────────────────────────────────────────

class _DateChip extends StatelessWidget {
  final DateTime dt;
  const _DateChip({required this.dt});

  String get _label {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    return DateFormat('MMMM d, y').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.border,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(_label, style: AppText.caption),
        ),
      ),
    );
  }
}

// ─── Delete dialog ────────────────────────────────────

class _DeleteDialog extends StatelessWidget {
  final bool isSent;
  const _DeleteDialog({required this.isSent});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Delete message?', style: AppText.title),
            const SizedBox(height: 16),
            if (isSent)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, 'everyone'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                  ),
                  child: const Text('Delete for everyone'),
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context, 'me'),
                child: const Text('Delete for me'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
