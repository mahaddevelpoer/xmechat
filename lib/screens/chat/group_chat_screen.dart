import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/chat/chat_input_bar.dart';
import '../../widgets/common/user_avatar.dart';

class GroupChatScreen extends ConsumerStatefulWidget {
  final String groupId;
  final GroupModel? group;
  const GroupChatScreen({super.key, required this.groupId, this.group});
  @override
  ConsumerState<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends ConsumerState<GroupChatScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _showEmoji = false;
  GroupMessageModel? _replyTo;
  List<GroupMessageModel> _messages = [];
  GroupModel? _group;
  List<GroupMemberModel> _members = [];
  bool _loading = false;

  bool _showMentionSuggestions = false;
  List<GroupMemberModel> _mentionSuggestions = [];
  late final ProviderSubscription _realtimeSub;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    _loadData();
    _listenRealtime();
    _textCtrl.addListener(_handleMentions);
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final msgs =
          await ref.read(groupServiceProvider).fetchGroupMessages(widget.groupId);
      final members =
          await ref.read(groupServiceProvider).fetchMembers(widget.groupId);
      if (!mounted) return;
      setState(() {
        _members = members;
        _messages = _attachSenderUsers(msgs.reversed.toList());
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _listenRealtime() {
    _realtimeSub =
        ref.listenManual(streamGroupMessagesProvider(widget.groupId), (_, next) {
      final rows = next.value;
      if (rows == null || !mounted) return;
      final msgs = rows.map((m) => GroupMessageModel.fromMap(m)).toList();
      setState(() => _messages = _attachSenderUsers(msgs));
    });
  }

  List<GroupMessageModel> _attachSenderUsers(List<GroupMessageModel> msgs) {
    final byId = <String, UserModel>{};
    for (final m in _members) {
      final u = m.user;
      if (u != null) byId[m.userId] = u;
    }
    for (final msg in msgs) {
      msg.senderUser = byId[msg.senderId];
    }
    return msgs;
  }

  Future<void> _sendText() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();
    final myId = ref.read(authServiceProvider).currentUserId;
    final senderMember = _members.firstWhere(
      (m) => m.userId == myId,
      orElse: () => GroupMemberModel(
        id: '',
        groupId: widget.groupId,
        userId: myId,
        joinedAt: DateTime.now(),
      ),
    );
    final mentions = _extractMentions(text);
    final msg = await ref.read(groupServiceProvider).sendGroupMessage(
      groupId: widget.groupId,
      text: text,
      replyTo: _replyTo?.id,
      replyPreview: _replyTo?.text ?? '',
      replySenderName: _replyTo?.senderUser?.name ?? '',
      mentions: mentions,
    );
    msg.senderUser = senderMember.user;
    setState(() {
      _messages.add(msg);
      _replyTo = null;
      _showMentionSuggestions = false;
    });
    _scrollToBottom();
  }

  @override
  void dispose() {
    _textCtrl.removeListener(_handleMentions);
    _realtimeSub.close();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleMentions() {
    final text = _textCtrl.text;
    final cursor = _textCtrl.selection.baseOffset;
    final idx = cursor >= 0 ? cursor : text.length;
    final before = idx <= text.length ? text.substring(0, idx) : text;
    final at = before.lastIndexOf('@');
    if (at < 0) {
      if (_showMentionSuggestions) {
        setState(() {
          _showMentionSuggestions = false;
          _mentionSuggestions = [];
        });
      }
      return;
    }
    // Stop if there is a whitespace after '@' (means mention token finished)
    final q = before.substring(at + 1);
    if (q.contains(' ') || q.contains('\n') || q.contains('\t')) {
      if (_showMentionSuggestions) {
        setState(() {
          _showMentionSuggestions = false;
          _mentionSuggestions = [];
        });
      }
      return;
    }

    final query = q.trim().toLowerCase();
    final suggestions = _members
        .where((m) => m.user != null)
        .where((m) => m.user!.name.toLowerCase().contains(query))
        .take(6)
        .toList();

    setState(() {
      _mentionSuggestions = suggestions;
      _showMentionSuggestions = suggestions.isNotEmpty;
    });
  }

  void _insertMention(GroupMemberModel member) {
    final u = member.user;
    if (u == null) return;
    final namePart = u.name.trim().split(' ').first;
    final text = _textCtrl.text;
    final cursor = _textCtrl.selection.baseOffset;
    final idx = cursor >= 0 ? cursor : text.length;
    final before = idx <= text.length ? text.substring(0, idx) : text;
    final after = idx <= text.length ? text.substring(idx) : '';
    final at = before.lastIndexOf('@');
    if (at < 0) return;
    final newText = '${before.substring(0, at)}@$namePart $after';
    _textCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
          offset: (before.substring(0, at).length + namePart.length + 2)),
    );
    setState(() {
      _showMentionSuggestions = false;
      _mentionSuggestions = [];
    });
  }

  List<String> _extractMentions(String text) {
    // We insert mentions as @FirstName, so we map that back to userId.
    final words = text.split(RegExp(r'\s+'));
    final mentionedNames = words
        .where((w) => w.startsWith('@') && w.length > 1)
        .map((w) => w.substring(1).toLowerCase())
        .toSet();
    if (mentionedNames.isEmpty) return [];
    final ids = <String>[];
    for (final m in _members) {
      final u = m.user;
      if (u == null) continue;
      final first = u.name.trim().split(' ').first.toLowerCase();
      if (mentionedNames.contains(first)) ids.add(m.userId);
    }
    return ids;
  }

  Future<void> _showAttachSheet() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Wrap(spacing: 20, runSpacing: 16, children: [
          _AttachItem(
            icon: Icons.poll_outlined,
            label: 'Poll',
            color: Colors.deepPurple,
            onTap: () {
              Navigator.pop(context);
              _showCreatePollDialog();
            },
          ),
        ]),
      ),
    );
  }

  Future<void> _showCreatePollDialog() async {
    final qCtrl = TextEditingController();
    final opt1 = TextEditingController();
    final opt2 = TextEditingController();
    bool allowMultiple = false;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Create poll'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: qCtrl,
                  decoration: const InputDecoration(labelText: 'Question'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: opt1,
                  decoration: const InputDecoration(labelText: 'Option 1'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: opt2,
                  decoration: const InputDecoration(labelText: 'Option 2'),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Allow multiple answers'),
                  value: allowMultiple,
                  onChanged: (v) => setLocal(() => allowMultiple = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final question = qCtrl.text.trim();
                final o1 = opt1.text.trim();
                final o2 = opt2.text.trim();
                if (question.isEmpty || o1.isEmpty || o2.isEmpty) return;
                try {
                  final poll = await ref.read(groupServiceProvider).createPoll(
                        groupId: widget.groupId,
                        question: question,
                        options: [o1, o2],
                        allowMultiple: allowMultiple,
                      );
                  await ref.read(groupServiceProvider).sendGroupMessage(
                        groupId: widget.groupId,
                        text: question,
                        type: MessageType.poll,
                        mediaUrl: poll.id, // pollId stored here
                      );
                } finally {
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    qCtrl.dispose();
    opt1.dispose();
    opt2.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myId = ref.read(authServiceProvider).currentUserId;

    return Scaffold(
      backgroundColor: AppColors.chatBg,
      appBar: AppBar(
        leadingWidth: 30,
        title: GestureDetector(
          onTap: () => context.push('/group-info/${widget.groupId}'),
          child: Row(children: [
            CircleAvatar(
              radius: 18, backgroundColor: AppColors.accentGreen,
              backgroundImage: (_group?.iconUrl.isNotEmpty == true)
                  ? NetworkImage(_group!.iconUrl) : null,
              child: _group?.iconUrl.isEmpty != false
                  ? const Icon(Icons.group, color: Colors.white, size: 18) : null,
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_group?.name ?? 'Group',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              Text('${_members.length} members',
                style: const TextStyle(fontSize: 11, color: Colors.white70)),
            ]),
          ]),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.videocam), onPressed: () {}),
          IconButton(icon: const Icon(Icons.call), onPressed: () {}),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => context.push('/group-info/${widget.groupId}'),
          ),
        ],
      ),
      body: Column(children: [
        if (_loading)
          const LinearProgressIndicator(color: AppColors.accentGreen),
        Expanded(
          child: _messages.isEmpty
            ? const Center(child: Text('No messages yet', style: TextStyle(color: AppColors.textHint)))
            : ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                itemCount: _messages.length,
                itemBuilder: (_, i) {
                  final msg = _messages[i];
                  if (msg.deletedForEveryone) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                      child: Center(child: Text('🚫 This message was deleted',
                        style: TextStyle(color: AppColors.textHint, fontStyle: FontStyle.italic, fontSize: 12))),
                    );
                  }
                  return _GroupMessageBubble(
                    msg: msg, isMe: msg.senderId == myId,
                    onReply: (m) => setState(() => _replyTo = m),
                  );
                },
              ),
        ),
        if (_replyTo != null)
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(children: [
              Container(width: 4, height: 40, color: AppColors.accentGreen),
              const SizedBox(width: 8),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_replyTo!.senderUser?.name ?? 'Unknown',
                  style: const TextStyle(color: AppColors.accentGreen, fontWeight: FontWeight.bold, fontSize: 12)),
                Text(_replyTo!.text, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ])),
              IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() => _replyTo = null)),
            ]),
          ),
        if (_showMentionSuggestions)
          Container(
            color: Colors.white,
            constraints: const BoxConstraints(maxHeight: 180),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _mentionSuggestions.length,
              itemBuilder: (_, i) {
                final m = _mentionSuggestions[i];
                final u = m.user;
                if (u == null) return const SizedBox.shrink();
                return ListTile(
                  dense: true,
                  leading: UserAvatar(url: u.avatarUrl, name: u.name, radius: 16),
                  title: Text(u.name, style: const TextStyle(fontSize: 13)),
                  onTap: () => _insertMention(m),
                );
              },
            ),
          ),
        ChatInputBar(
          controller: _textCtrl,
          isRecording: false,
          onSend: _sendText,
          onEmoji: () => setState(() => _showEmoji = !_showEmoji),
          onAttach: _showAttachSheet,
          onStartRecord: () {},
          onStopRecord: () {},
          onCamera: () {},
        ),
      ]),
    );
  }
}

class _GroupMessageBubble extends StatelessWidget {
  final GroupMessageModel msg;
  final bool isMe;
  final void Function(GroupMessageModel) onReply;
  const _GroupMessageBubble({required this.msg, required this.isMe, required this.onReply});

  @override
  Widget build(BuildContext context) {
    final bubble = Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMe ? AppColors.sentBubble : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: isMe ? const Radius.circular(12) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(12),
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withAlpha(15),
                blurRadius: 2,
                offset: const Offset(0, 1))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (!isMe)
            Text(msg.senderUser?.name ?? 'Unknown',
                style: const TextStyle(
                    color: AppColors.accentGreen,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          if (msg.replyTo != null)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: Colors.black.withAlpha(10),
                  borderRadius: BorderRadius.circular(8)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(msg.replySenderName,
                    style: const TextStyle(
                        color: AppColors.accentGreen,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
                Text(msg.replyPreview,
                    maxLines: 1,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              ]),
            ),
          if (msg.type == MessageType.poll)
            _PollBubble(pollId: msg.mediaUrl, question: msg.text)
          else
            Text(msg.text,
                style: const TextStyle(
                    fontSize: 15, color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(_formatTime(msg.createdAt),
              style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
        ]),
      ),
    );

    // Swipe right to reply (same behaviour as private chat)
    return Dismissible(
      key: ValueKey('gmsg-${msg.id}'),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (_) async {
        onReply(msg);
        return false;
      },
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        child: const Icon(Icons.reply, color: AppColors.primaryGreen),
      ),
      child: bubble,
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _AttachItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _AttachItem(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration:
              BoxDecoration(color: color.withAlpha(20), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 28),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ]),
    );
  }
}

class _PollBubble extends ConsumerStatefulWidget {
  final String pollId;
  final String question;
  const _PollBubble({required this.pollId, required this.question});

  @override
  ConsumerState<_PollBubble> createState() => _PollBubbleState();
}

class _PollBubbleState extends ConsumerState<_PollBubble> {
  int _refreshKey = 0;

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
    final pollId = widget.pollId;
    final question = widget.question;
    if (pollId.isEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.poll_outlined, size: 18, color: AppColors.textSecondary),
          SizedBox(width: 8),
          Text('Poll', style: TextStyle(color: AppColors.textSecondary)),
        ],
      );
    }

    return FutureBuilder<PollModel?>(
      key: ValueKey('poll-$pollId-$_refreshKey'),
      future: ref.read(groupServiceProvider).getPoll(pollId),
      builder: (context, snap) {
        final poll = snap.data;
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        if (poll == null) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.poll_outlined,
                  size: 18, color: AppColors.textSecondary),
              const SizedBox(width: 8),
              Text(question,
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.textPrimary)),
            ],
          );
        }

        return FutureBuilder<Map<int, int>>(
          key: ValueKey('poll-count-$pollId-$_refreshKey'),
          future: ref.read(groupServiceProvider).getPollCounts(poll.id),
          builder: (context, countSnap) {
            final counts = countSnap.data ?? {};
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.poll_outlined,
                        size: 18, color: AppColors.textSecondary),
                    SizedBox(width: 8),
                    Text('Poll',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(poll.question,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                for (int i = 0; i < poll.options.length; i++)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: OutlinedButton(
                      onPressed: () async {
                        await ref
                            .read(groupServiceProvider)
                            .votePoll(poll.id, i);
                        if (!mounted) return;
                        setState(() => _refreshKey++);
                      },
                      child: Row(
                        children: [
                          Expanded(child: Text(poll.options[i])),
                          Text('${counts[i] ?? 0}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
