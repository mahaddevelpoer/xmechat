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
import '../../services/chat_service.dart';
import '../../services/broadcast_service.dart';

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
  bool _showProfilePanel = false;
  bool _selectMode = false;
  final Set<String> _selectedMsgIds = {};

  static const double _panelWidth = 360;

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

  Future<void> _forwardMessage(MessageModel msg) async {
    final users = await ref.read(chatServiceProvider).getAllUsers();
    if (!mounted) return;
    final selected = await showDialog<UserModel>(
      context: context,
      builder: (_) => _ForwardDialog(users: users),
    );
    if (selected == null || !mounted) return;
    try {
      final targetChatId = await ref.read(chatServiceProvider).getOrCreateChat(selected.id);
      await ref.read(chatServiceProvider).forwardMessage(
        source: msg,
        targetChatId: targetChatId,
        targetReceiverId: selected.id,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Forwarded to ${selected.name}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Forward failed: $e')),
        );
      }
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

  void _toggleProfilePanel() {
    setState(() => _showProfilePanel = !_showProfilePanel);
  }

  void _showMoreOptions() {
    final chatId = widget.chatId;
    final otherId = _other?.id ?? '';
    final uid = ref.read(currentUserIdProvider);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (ctx) => _ChatMoreOptionsSheet(
        chatId: chatId,
        otherUserId: otherId,
        otherUser: _other,
        chatService: ref.read(chatServiceProvider),
        currentUserId: uid,
        onAction: (action) async {
          Navigator.pop(ctx);
          await _handleMoreAction(action);
        },
      ),
    );
  }

  Future<void> _handleMoreAction(ChatMoreAction action) async {
    final chatId = widget.chatId;
    final otherId = _other?.id ?? '';
    switch (action) {
      case ChatMoreAction.contactInfo:
        context.push('/contact/$otherId', extra: {'user': _other});
      case ChatMoreAction.search:
        _showSearchInChat();
      case ChatMoreAction.selectMessages:
        setState(() { _selectMode = !_selectMode; _selectedMsgIds.clear(); });
      case ChatMoreAction.mute:
        final muted = await ref.read(chatServiceProvider).getMuteStatus(chatId);
        await ref.read(chatServiceProvider).setMuteStatus(chatId, !muted);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(muted ? 'Unmuted notifications' : 'Muted notifications')));
      case ChatMoreAction.disappearingMessages:
        _showDisappearTimerDialog();
      case ChatMoreAction.addToFavourites:
        final isFav = await ref.read(chatServiceProvider).isFavourite(chatId);
        await ref.read(chatServiceProvider).toggleFavourite(chatId, !isFav);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isFav ? 'Removed from favourites' : 'Added to favourites')));
      case ChatMoreAction.addToList:
        _showAddToListDialog();
      case ChatMoreAction.closeChat:
        if (context.mounted) context.canPop() ? context.pop() : context.go('/home');
      case ChatMoreAction.sendCallLink:
        _sendCallLink();
      case ChatMoreAction.scheduleCall:
        _showScheduleCallDialog();
      case ChatMoreAction.newGroupCall:
        _startGroupCall();
      case ChatMoreAction.report:
        _showReportDialog();
      case ChatMoreAction.markUnread:
        await ref.read(chatServiceProvider).markAsUnread(chatId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked as unread')));
          context.canPop() ? context.pop() : context.go('/home');
        }
      case ChatMoreAction.block:
        final blocked = await ref.read(chatServiceProvider).isUserBlocked(otherId);
        if (blocked) {
          await ref.read(chatServiceProvider).unblockUser(otherId);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User unblocked')));
        } else {
          await ref.read(chatServiceProvider).blockUser(otherId);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User blocked')));
        }
      case ChatMoreAction.clearChat:
        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Clear chat?'),
            content: const Text('All messages will be deleted for you.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear', style: TextStyle(color: AppColors.danger))),
            ],
          ),
        );
        if (confirm == true) {
          await ref.read(chatServiceProvider).clearChat(chatId);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chat cleared')));
        }
      case ChatMoreAction.deleteChat:
        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Delete chat?'),
            content: const Text('This chat will be deleted for you.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: AppColors.danger))),
            ],
          ),
        );
        if (confirm == true) {
          await ref.read(chatServiceProvider).deleteChat(chatId);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Chat deleted')));
            context.canPop() ? context.pop() : context.go('/home');
          }
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUserIdProvider);
    final other = _other;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          Column(
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
            onMoreOptions: () => _showMoreOptions(),
            onProfileTap: _toggleProfilePanel,
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
                    .toList()
                  ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

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
                    final isSelected = _selectedMsgIds.contains(msg.id);
                    return Column(
                      children: [
                        if (showDate) _DateChip(dt: msg.createdAt),
                        GestureDetector(
                          onTap: _selectMode
                              ? () => setState(() {
                                    if (isSelected) _selectedMsgIds.remove(msg.id);
                                    else _selectedMsgIds.add(msg.id);
                                  })
                              : null,
                          child: Row(
                            children: [
                              if (_selectMode)
                                Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: Icon(
                                    isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                    color: isSelected ? AppColors.accent : AppColors.textHint,
                                    size: 22,
                                  ),
                                ),
                              Expanded(
                                child: Opacity(
                                  opacity: _selectMode && !isSelected ? 0.5 : 1.0,
                                  child: MessageBubble(
                                    message: msg,
                                    isSent: isSent,
                                    senderName: other?.name,
                                    senderAvatarUrl: other?.avatarUrl,
                                    onReply: _selectMode ? null : () => setState(() => _replyTo = msg),
                                    onDelete: _selectMode ? null : () => _deleteMessage(msg),
                                    onCopy: !_selectMode && msg.type == MessageType.text
                                        ? () => _copyMessage(msg)
                                        : null,
                                    onForward: _selectMode ? null : () => _forwardMessage(msg),
                                    onStar: _selectMode ? null : () => ref
                                        .read(chatServiceProvider)
                                        .toggleStar(msg.id, !msg.isStarred),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),

          // ── Select mode bar ────────────────────────────
          if (_selectMode)
            Container(
              height: AppSizes.inputBarHeight,
              color: AppColors.panel,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text('${_selectedMsgIds.length} selected', style: AppText.body),
                  const Spacer(),
                  if (_selectedMsgIds.isNotEmpty)
                    TextButton.icon(
                      onPressed: () {
                        for (final id in _selectedMsgIds.toList()) {
                          ref.read(chatServiceProvider).deleteMessage(id, forEveryone: false);
                        }
                        setState(() { _selectMode = false; _selectedMsgIds.clear(); });
                      },
                      icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                      label: const Text('Delete', style: TextStyle(color: AppColors.danger)),
                    ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => setState(() { _selectMode = false; _selectedMsgIds.clear(); }),
                    child: const Text('Cancel'),
                  ),
                ],
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
          if (_showProfilePanel)
            GestureDetector(
              onTap: _toggleProfilePanel,
              child: Container(color: AppColors.overlay),
            ),
          AnimatedPositioned(
            right: _showProfilePanel ? 0 : -_panelWidth,
            top: 0,
            bottom: 0,
            width: _panelWidth,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: _ProfilePanel(
              user: _other,
              onClose: _toggleProfilePanel,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startGroupCall() async {
    final users = await ref.read(chatServiceProvider).getAllUsers();
    if (!mounted) return;
    final others = users.where((u) => u.id != ref.read(currentUserIdProvider)).toList();
    List<UserModel> selected = [];
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select participants'),
        content: SizedBox(
          width: 300, height: 400,
          child: StatefulBuilder(
            builder: (ctx, setDState) => ListView.builder(
              itemCount: others.length,
              itemBuilder: (_, i) {
                final u = others[i];
                final isSelected = selected.contains(u);
                return CheckboxListTile(
                  dense: true,
                  value: isSelected,
                  title: Text(u.name, style: AppText.body),
                  subtitle: Text(u.email, style: AppText.caption),
                  onChanged: (v) {
                    setDState(() {
                      if (v == true) selected.add(u); else selected.remove(u);
                    });
                  },
                );
              },
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: selected.isNotEmpty ? () => Navigator.pop(ctx, true) : null,
            child: Text('Start call (${selected.length})'),
          ),
        ],
      ),
    );
    if (selected.isEmpty || !mounted) return;
    try {
      final callId = await ref.read(webrtcServiceProvider).initiateCall(
        selected.first.id,
        isVideo: false,
      );
      final names = selected.map((u) => u.name).join(', ');
      await ref.read(chatServiceProvider).sendTextMessage(
        chatId: widget.chatId,
        receiverId: _other?.id ?? '',
        text: '📞 Group call with $names started',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Group call started with $names')),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  // ── More options helpers ──────────────────────────

  Future<void> _showSearchInChat() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Search in chat', style: AppText.title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: AppText.body,
          decoration: const InputDecoration(hintText: 'Search messages...', prefixIcon: Icon(Icons.search)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, ctrl.text.trim()), child: const Text('Search')),
        ],
      ),
    );
    ctrl.dispose();
    if (result == null || result.isEmpty || !mounted) return;
    final msgs = await ref.read(chatServiceProvider).searchMessages(widget.chatId, result);
    if (!mounted || msgs.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No messages found')));
      return;
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Found ${msgs.length} messages'),
        content: SizedBox(
          width: 400,
          height: 300,
          child: ListView.builder(
            itemCount: msgs.length,
            itemBuilder: (_, i) => ListTile(
              dense: true,
              title: Text(msgs[i].text, style: AppText.body, maxLines: 2, overflow: TextOverflow.ellipsis),
              subtitle: Text(DateFormat('h:mm a').format(msgs[i].createdAt), style: AppText.caption),
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  Future<void> _showDisappearTimerDialog() async {
    final current = await ref.read(chatServiceProvider).getDisappearTimer(widget.chatId);
    final options = [0, 5, 10, 30, 60, 300, 600, 3600, 86400];
    final labels = ['Off', '5 seconds', '10 seconds', '30 seconds', '1 minute', '5 minutes', '10 minutes', '1 hour', '24 hours'];
    final selected = options.indexOf(current);
    final result = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Disappearing messages'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(options.length, (i) => RadioListTile<int>(
            dense: true,
            title: Text(labels[i], style: AppText.body),
            value: options[i],
            groupValue: current,
            onChanged: (v) => Navigator.pop(context, v),
          )),
        ),
      ),
    );
    if (result != null) {
      await ref.read(chatServiceProvider).setDisappearTimer(widget.chatId, result);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result == 0 ? 'Disappearing messages off' : 'Messages will disappear after ${labels[options.indexOf(result)]}')));
    }
  }

  Future<void> _showAddToListDialog() async {
    final lists = await ref.read(broadcastServiceProvider).fetchMyLists();
    if (!mounted) return;
    if (lists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No broadcast lists. Create one first.')));
      return;
    }
    final list = await showDialog<BroadcastListModel>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add to broadcast list'),
        content: SizedBox(
          width: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: lists.length,
            itemBuilder: (_, i) => ListTile(
              title: Text(lists[i].name, style: AppText.body),
              subtitle: Text('${lists[i].members.length} recipients', style: AppText.caption),
              onTap: () => Navigator.pop(context, lists[i]),
            ),
          ),
        ),
      ),
    );
    if (list != null && _other != null) {
      await ref.read(broadcastServiceProvider).addMembers(list.id, [_other!.id]);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${_other!.name} added to ${list.name}')));
    }
  }

  Future<void> _sendCallLink() async {
    final isVideo = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Send call link'),
        content: const Text('Choose call type:'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Voice')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Video')),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ],
      ),
    );
    if (isVideo == null || !mounted) return;
    try {
      final link = await ref.read(chatServiceProvider).generateCallLink(_other?.id ?? '', isVideo: isVideo);
      await ref.read(chatServiceProvider).sendTextMessage(
        chatId: widget.chatId,
        receiverId: _other?.id ?? '',
        text: isVideo ? '📹 Video call link: $link' : '📞 Voice call link: $link',
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Call link sent')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _showScheduleCallDialog() async {
    DateTime? selectedDate;
    TimeOfDay? selectedTime;
    bool isVideo = false;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: const Text('Schedule call'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(selectedDate != null ? DateFormat('MMM d, y').format(selectedDate!) : 'Pick date', style: AppText.body),
                leading: const Icon(Icons.calendar_today),
                onTap: () async {
                  final d = await showDatePicker(context: ctx, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 30)));
                  if (d != null) setDState(() => selectedDate = d);
                },
              ),
              ListTile(
                title: Text(selectedTime != null ? selectedTime!.format(ctx) : 'Pick time', style: AppText.body),
                leading: const Icon(Icons.access_time),
                onTap: () async {
                  final t = await showTimePicker(context: ctx, initialTime: TimeOfDay.now());
                  if (t != null) setDState(() => selectedTime = t);
                },
              ),
              SwitchListTile(
                title: const Text('Video call', style: AppText.body),
                value: isVideo,
                onChanged: (v) => setDState(() => isVideo = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: selectedDate != null && selectedTime != null ? () => Navigator.pop(ctx, true) : null,
              child: const Text('Schedule'),
            ),
          ],
        ),
      ),
    );
    if (selectedDate != null && selectedTime != null && mounted) {
      final dt = DateTime(selectedDate!.year, selectedDate!.month, selectedDate!.day, selectedTime!.hour, selectedTime!.minute);
      await ref.read(chatServiceProvider).scheduleCall(_other?.id ?? '', dt, isVideo: isVideo);
      final type = isVideo ? 'video' : 'voice';
      await ref.read(chatServiceProvider).sendTextMessage(
        chatId: widget.chatId,
        receiverId: _other?.id ?? '',
        text: '📅 Scheduled a $type call for ${DateFormat('MMM d, y h:mm a').format(dt)}',
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Call scheduled')));
    }
  }

  Future<void> _showReportDialog() async {
    final ctrl = TextEditingController();
    final reasons = ['Spam', 'Harassment', 'Inappropriate content', 'Fake account', 'Other'];
    String? selectedReason;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: const Text('Report user'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...reasons.map((r) => RadioListTile<String>(
                dense: true,
                title: Text(r, style: AppText.body),
                value: r,
                groupValue: selectedReason,
                onChanged: (v) => setDState(() => selectedReason = v),
              )),
              if (selectedReason == 'Other')
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextField(
                    controller: ctrl,
                    style: AppText.body,
                    decoration: const InputDecoration(hintText: 'Describe the issue...'),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: selectedReason != null ? () => Navigator.pop(ctx, true) : null,
              child: const Text('Report'),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
    if (selectedReason != null && mounted) {
      final reason = selectedReason == 'Other' ? ctrl.text.trim() : selectedReason!;
      await ref.read(chatServiceProvider).reportUser(_other?.id ?? '', reason);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User reported')));
    }
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
  final VoidCallback? onMoreOptions;
  final VoidCallback? onProfileTap;

  const _ChatHeader({
    required this.user,
    required this.loading,
    required this.onBack,
    required this.onVoiceCall,
    required this.onVideoCall,
    required this.onInfo,
    this.onMoreOptions,
    this.onProfileTap,
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
              onTap: onProfileTap,
            ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: onProfileTap,
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
          IconButton(
            icon: const Icon(Icons.more_vert, size: 20),
            tooltip: 'More',
            onPressed: onMoreOptions,
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

// ─── Forward dialog ───────────────────────────────────

class _ForwardDialog extends StatelessWidget {
  final List<UserModel> users;
  const _ForwardDialog({required this.users});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Text('Forward to...', style: AppText.title),
          ),
          const Divider(height: 1),
          SizedBox(
            height: 300,
            child: users.isEmpty
                ? const Center(child: Text('No contacts', style: TextStyle(color: AppColors.textGrey)))
                : ListView.builder(
                    itemCount: users.length,
                    itemBuilder: (_, i) {
                      final u = users[i];
                      return ListTile(
                        leading: UserAvatar(imageUrl: u.avatarUrl, name: u.name, size: 36),
                        title: Text(u.name, style: AppText.body),
                        subtitle: Text(u.email, style: AppText.caption),
                        onTap: () => Navigator.pop(context, u),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── ChatMoreAction enum ──────────────────────────────

enum ChatMoreAction {
  contactInfo, search, selectMessages, mute,
  disappearingMessages, addToFavourites, addToList, closeChat,
  sendCallLink, scheduleCall, newGroupCall, report,
  markUnread, block, clearChat, deleteChat,
}

// ─── More options bottom sheet ────────────────────────

class _ChatMoreOptionsSheet extends StatelessWidget {
  final String chatId;
  final String otherUserId;
  final UserModel? otherUser;
  final ChatService chatService;
  final String currentUserId;
  final ValueChanged<ChatMoreAction> onAction;

  const _ChatMoreOptionsSheet({
    required this.chatId,
    required this.otherUserId,
    required this.otherUser,
    required this.chatService,
    required this.currentUserId,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4, margin: const EdgeInsets.only(top: 8, bottom: 4),
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
            _option(context, Icons.info_outline, 'Contact info', ChatMoreAction.contactInfo),
            _option(context, Icons.search, 'Search', ChatMoreAction.search),
            _option(context, Icons.checklist, 'Select messages', ChatMoreAction.selectMessages),
            _option(context, Icons.notifications_off_outlined, 'Mute notifications', ChatMoreAction.mute),
            _option(context, Icons.timer_outlined, 'Disappearing messages', ChatMoreAction.disappearingMessages),
            _option(context, Icons.favorite_outline, 'Add to favourites', ChatMoreAction.addToFavourites),
            _option(context, Icons.campaign_outlined, 'Add to list', ChatMoreAction.addToList),
            _option(context, Icons.close, 'Close chat', ChatMoreAction.closeChat),
            _divider(),
            _option(context, Icons.link, 'Send call link', ChatMoreAction.sendCallLink),
            _option(context, Icons.schedule, 'Schedule call', ChatMoreAction.scheduleCall),
            _option(context, Icons.group_add_outlined, 'New group call', ChatMoreAction.newGroupCall),
            _divider(),
            _option(context, Icons.report_outlined, 'Report', ChatMoreAction.report, color: AppColors.textGrey),
            _option(context, Icons.markunread_outlined, '1 unread message', ChatMoreAction.markUnread),
            _option(context, Icons.block, 'Block', ChatMoreAction.block),
            _divider(),
            _option(context, Icons.delete_sweep_outlined, 'Clear chat', ChatMoreAction.clearChat),
            _option(context, Icons.delete_outline, 'Delete chat', ChatMoreAction.deleteChat, color: AppColors.danger),
          ],
        ),
      ),
    );
  }

  Widget _divider() => const Divider(height: 1, indent: 16, endIndent: 16);

  Widget _option(BuildContext context, IconData icon, String label, ChatMoreAction action, {Color? color}) {
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20, color: color ?? AppColors.textDark),
      title: Text(label, style: AppText.body.copyWith(color: color ?? AppColors.textDark)),
      onTap: () => onAction(action),
    );
  }
}

// ─── Profile panel ───────────────────────────────────

class _ProfilePanel extends StatelessWidget {
  final UserModel? user;
  final VoidCallback onClose;

  const _ProfilePanel({
    required this.user,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final u = user;
    return Material(
      elevation: 8,
      color: AppColors.panel,
      child: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────
            Container(
              height: AppSizes.headerHeight,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, size: 20),
                    onPressed: onClose,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: onClose,
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.border),
            // ── Profile ───────────────────────────────
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  const SizedBox(height: 24),
                  Center(
                    child: UserAvatar(
                      imageUrl: u?.avatarUrl,
                      name: u?.name ?? '?',
                      size: AppSizes.avatarXl,
                      showOnline: true,
                      isOnline: u?.isOnline ?? false,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(u?.name ?? 'Unknown', style: AppText.heading),
                  ),
                  if ((u?.bio ?? '').isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(u!.bio, style: AppText.bodyGrey, textAlign: TextAlign.center),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: (u?.isOnline ?? false) ? AppColors.accentLight : AppColors.border,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        (u?.isOnline ?? false) ? '● Online' : 'Last seen ${_lastSeen(u)}',
                        style: AppText.caption.copyWith(
                          color: (u?.isOnline ?? false) ? AppColors.accent : AppColors.textGrey,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Divider(height: 1, color: AppColors.border),
                  _infoTile(Icons.phone_outlined, 'Phone', u?.phoneInfo ?? 'Not shared'),
                  Divider(height: 1, color: AppColors.border),
                  _infoTile(Icons.email_outlined, 'Email', u?.email ?? 'Not shared'),
                  Divider(height: 1, color: AppColors.border),
                  _infoTile(Icons.info_outline, 'About', (u?.bio ?? '').isEmpty ? 'No bio' : u!.bio),
                  Divider(height: 1, color: AppColors.border),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(Icons.photo_library_outlined, size: 20, color: AppColors.textGrey),
                        const SizedBox(width: 8),
                        Text('Shared media', style: AppText.name),
                        const Spacer(),
                        Text('View all', style: AppText.link),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 80,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: 6,
                      itemBuilder: (_, i) => Container(
                        width: 72,
                        height: 72,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Icon(Icons.image_outlined, color: AppColors.textHint, size: 28),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _lastSeen(UserModel? u) {
    if (u == null) return '';
    final diff = DateTime.now().difference(u.lastSeen);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM d').format(u.lastSeen);
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20, color: AppColors.textGrey),
      title: Text(label, style: AppText.caption.copyWith(color: AppColors.textHint)),
      subtitle: Text(value, style: AppText.body),
    );
  }
}

// ─── Delete dialog ───────────────────────────────────

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
