import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/common/user_avatar.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/empty_state.dart';
import '../../widgets/chat/message_bubble.dart';
import '../../widgets/chat/chat_input_bar.dart';

class GroupChatScreen extends ConsumerStatefulWidget {
  final String groupId;
  final GroupModel? group;

  const GroupChatScreen({
    super.key,
    required this.groupId,
    this.group,
  });

  @override
  ConsumerState<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends ConsumerState<GroupChatScreen> {
  final _scrollCtrl = ScrollController();

  GroupModel? _group;
  List<UserModel> _members = [];
  bool _loadingGroup = false;
  MessageModel? _replyTo;
  bool _showInfo = false;
  bool _enterToSend = false;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    if (_group == null) _loadGroup();
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

  Future<void> _loadGroup() async {
    setState(() => _loadingGroup = true);
    try {
      // Fetch the group record directly
      final db = Supabase.instance.client;
      final groupData = await db
          .from('groups')
          .select()
          .eq('id', widget.groupId)
          .maybeSingle();
      if (groupData != null && mounted) {
        setState(() => _group = GroupModel.fromMap(groupData));
      }

      // Fetch members (GroupMemberModel has .user attached)
      final memberModels =
          await ref.read(groupServiceProvider).fetchMembers(widget.groupId);
      final users = memberModels
          .map((m) => m.user)
          .whereType<UserModel>()
          .toList();

      if (mounted) {
        setState(() {
          _members = users;
          _loadingGroup = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingGroup = false);
    }
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

  UserModel? _memberById(String id) {
    try {
      return _members.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _sendText(String text) async {
    try {
      await ref.read(groupServiceProvider).sendGroupMessage(
            groupId: widget.groupId,
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
      final path = '${widget.groupId}/voice_$ts.$ext';
      final db = Supabase.instance.client;
      await db.storage
          .from('voice_notes')
          .uploadBinary(path, bytes,
              fileOptions:
                  const FileOptions(contentType: 'audio/wav'));
      final url = db.storage.from('voice_notes').getPublicUrl(path);
      await ref.read(groupServiceProvider).sendGroupMessage(
            groupId: widget.groupId,
            text: '',
            type: MessageType.audio,
            mediaUrl: url,
            fileName: 'voice_$ts.$ext',
            duration: (durationMs / 1000).round(),
          );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Send failed: $e')));
      }
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

  void _startGroupVideoCall() {
    if (_members.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No members to call')),
      );
      return;
    }
    final me = ref.read(currentUserIdProvider);
    final others = _members.where((m) => m.id != me).toList();
    if (others.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No other members to call')),
      );
      return;
    }
    final target = others.first;
    ref.read(webrtcServiceProvider).initiateCall(
      target.id,
      isVideo: true,
    ).then((callId) {
      if (mounted) {
        context.push('/video-call/$callId',
          extra: {'isCaller': true, 'user': target, 'sdpOffer': ''},
        );
      }
    }).catchError((e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Video call failed: $e')),
        );
      }
    });
  }

  Future<void> _sendFile(
      Uint8List bytes, String fileName, MessageType type) async {
    try {
      final ts = DateTime.now().millisecondsSinceEpoch;
      final bucket = type == MessageType.image
          ? 'chat_media'
          : type == MessageType.document
              ? 'documents'
              : 'chat_media';
      final path = '${widget.groupId}/${ts}_$fileName';
      final db = Supabase.instance.client;
      await db.storage
          .from(bucket)
          .uploadBinary(path, bytes);
      final url = db.storage.from(bucket).getPublicUrl(path);
      await ref.read(groupServiceProvider).sendGroupMessage(
            groupId: widget.groupId,
            text: '',
            type: type,
            mediaUrl: url,
            fileName: fileName,
          );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Send failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUserIdProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Row(
        children: [
          // Main chat column
          Expanded(
            child: Column(
              children: [
                // Header
                _GroupChatHeader(
                  group: _group,
                  memberCount: _members.length,
                  loading: _loadingGroup,
                  onBack: () => context.canPop()
                      ? context.pop()
                      : context.go('/home'),
                  onInfo: () => setState(() => _showInfo = !_showInfo),
                  onVideoCall: _startGroupVideoCall,
                ),
                const Divider(height: 1),

                // Messages
                Expanded(
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: ref
                        .read(groupServiceProvider)
                        .streamGroupMessages(widget.groupId),
                    builder: (ctx, snap) {
                      if (snap.hasError) return ErrorState(error: snap.error);
                      if (!snap.hasData) return const LoadingWidget();

                      final rows = snap.data!;
                      if (rows.isEmpty) {
                        return EmptyState(
                          icon: Icons.group_outlined,
                          title: _group?.name ?? 'Group Chat',
                          subtitle: 'Be the first to send a message!',
                        );
                      }

                      final msgs = rows
                          .map((r) => MessageModel.fromMap(r))
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
                          final sender = _memberById(msg.senderId);
                          final showDate = i == 0 ||
                              !_sameDay(
                                  msgs[i - 1].createdAt, msg.createdAt);

                          return Column(
                            children: [
                              if (showDate) _DateChip(dt: msg.createdAt),
                              MessageBubble(
                                message: msg,
                                isSent: isSent,
                                senderName: sender?.name,
                                senderAvatarUrl: sender?.avatarUrl,
                                showSenderName: !isSent,
                                onReply: () =>
                                    setState(() => _replyTo = msg),
                                onCopy: msg.type == MessageType.text
                                    ? () async {
                                        final m = ScaffoldMessenger.of(context);
                                        await Clipboard.setData(
                                            ClipboardData(text: msg.text));
                                        m.showSnackBar(
                                          const SnackBar(
                                              content: Text('Copied')),
                                        );
                                      }
                                    : null,
                                onForward: () => _forwardMessage(msg),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                ),

                // Input bar
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
          ),

          // Info panel (collapsible right side)
          if (_showInfo) ...[
            const VerticalDivider(width: 1),
            SizedBox(
              width: 280,
              child: _GroupInfoPanel(
                group: _group,
                members: _members,
                currentUserId: uid,
                onClose: () => setState(() => _showInfo = false),
                onLeave: () async {
                  final router = GoRouter.of(context);
                  await ref
                      .read(groupServiceProvider)
                      .leaveGroup(widget.groupId);
                  if (mounted) router.go('/home');
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Group header ─────────────────────────────────────

class _GroupChatHeader extends StatelessWidget {
  final GroupModel? group;
  final int memberCount;
  final bool loading;
  final VoidCallback onBack;
  final VoidCallback onInfo;
  final VoidCallback? onVideoCall;

  const _GroupChatHeader({
    required this.group,
    required this.memberCount,
    required this.loading,
    required this.onBack,
    required this.onInfo,
    this.onVideoCall,
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
          UserAvatar(
            imageUrl:
                group?.iconUrl.isNotEmpty == true ? group!.iconUrl : null,
            name: group?.name ?? '?',
            size: 38,
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
                    group?.name ?? (loading ? 'Loading...' : 'Group'),
                    style: AppText.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    memberCount > 0
                        ? '$memberCount members'
                        : 'Tap for info',
                    style: AppText.caption,
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.videocam_outlined, size: 20),
            tooltip: 'Group Video Call',
            onPressed: onVideoCall,
          ),
          IconButton(
            icon: const Icon(Icons.info_outlined, size: 20),
            tooltip: 'Group Info',
            onPressed: onInfo,
          ),
        ],
      ),
    );
  }
}

// ─── Group info panel ─────────────────────────────────

class _GroupInfoPanel extends StatelessWidget {
  final GroupModel? group;
  final List<UserModel> members;
  final String currentUserId;
  final VoidCallback onClose;
  final VoidCallback onLeave;

  const _GroupInfoPanel({
    required this.group,
    required this.members,
    required this.currentUserId,
    required this.onClose,
    required this.onLeave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.panel,
      child: Column(
        children: [
          SizedBox(
            height: AppSizes.headerHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Text('Group Info', style: AppText.title),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: onClose,
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        UserAvatar(
                          imageUrl: group?.iconUrl.isNotEmpty == true
                              ? group!.iconUrl
                              : null,
                          name: group?.name ?? '?',
                          size: 72,
                        ),
                        const SizedBox(height: 12),
                        Text(group?.name ?? '', style: AppText.title,
                            textAlign: TextAlign.center),
                        Text('${members.length} members',
                            style: AppText.bodyGrey),
                        if (group?.description.isNotEmpty == true) ...[
                          const SizedBox(height: 6),
                          Text(group!.description,
                              style: AppText.bodyGrey,
                              textAlign: TextAlign.center),
                        ],
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                    child: Text('Members',
                        style: AppText.caption
                            .copyWith(fontWeight: FontWeight.w600)),
                  ),
                  ...members.map((m) => ListTile(
                        dense: true,
                        leading: UserAvatar(
                            imageUrl: m.avatarUrl,
                            name: m.name,
                            size: 36),
                        title: Text(
                          m.name +
                              (m.id == currentUserId ? ' (You)' : ''),
                          style: AppText.body,
                        ),
                        subtitle: Text(m.bio,
                            style: AppText.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      )),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: OutlinedButton.icon(
                        onPressed: onLeave,
                        icon: const Icon(Icons.exit_to_app,
                            size: 16, color: AppColors.danger),
                        label: const Text('Leave Group'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.danger,
                          side: const BorderSide(
                              color: AppColors.danger),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
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
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
