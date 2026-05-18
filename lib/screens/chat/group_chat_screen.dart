import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/chat/message_bubble.dart';
import '../../widgets/chat/chat_input_bar.dart';
import '../../widgets/chat/reply_preview.dart';
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

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    _loadData();
  }

  Future<void> _loadData() async {
    final msgs = await ref.read(groupServiceProvider).fetchGroupMessages(widget.groupId);
    final members = await ref.read(groupServiceProvider).fetchMembers(widget.groupId);
    if (!mounted) return;
    setState(() { _messages = msgs.reversed.toList(); _members = members; });
  }

  Future<void> _sendText() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();
    final myId = ref.read(authServiceProvider).currentUserId;
    final senderMember = _members.firstWhere((m) => m.userId == myId, orElse: () => GroupMemberModel(id: '', groupId: widget.groupId, userId: myId, joinedAt: DateTime.now()));
    final msg = await ref.read(groupServiceProvider).sendGroupMessage(
      groupId: widget.groupId,
      text: text,
      replyTo: _replyTo?.id,
      replyPreview: _replyTo?.text ?? '',
      replySenderName: _replyTo?.senderUser?.name ?? '',
    );
    setState(() { _messages.add(msg); _replyTo = null; });
  }

  @override
  void dispose() { _textCtrl.dispose(); _scrollCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final myId = ref.read(authServiceProvider).currentUserId;

    ref.listen(streamGroupMessagesProvider(widget.groupId), (_, next) {
      if (next.value != null && mounted) {
        final msgs = next.value!.map((m) => GroupMessageModel.fromMap(m)).toList();
        setState(() => _messages = msgs);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.chatBg,
      appBar: AppBar(
        leadingWidth: 30,
        title: GestureDetector(
          onTap: () => context.push('/group-info/${widget.groupId}'),
          child: Row(children: [
            CircleAvatar(
              radius: 18, backgroundColor: AppColors.tealGreen,
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
        ChatInputBar(
          controller: _textCtrl,
          isRecording: false,
          onSend: _sendText,
          onEmoji: () => setState(() => _showEmoji = !_showEmoji),
          onAttach: () {},
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
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMe ? AppColors.sentBubble : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12), topRight: const Radius.circular(12),
            bottomLeft: isMe ? const Radius.circular(12) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(12),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 2, offset: const Offset(0, 1))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (!isMe)
            Text(msg.senderUser?.name ?? 'Unknown',
              style: const TextStyle(color: AppColors.accentGreen, fontWeight: FontWeight.bold, fontSize: 12)),
          if (msg.replyTo != null)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(10), borderRadius: BorderRadius.circular(8)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(msg.replySenderName, style: const TextStyle(color: AppColors.accentGreen, fontSize: 11, fontWeight: FontWeight.bold)),
                Text(msg.replyPreview, maxLines: 1, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ]),
            ),
          Text(msg.text, style: const TextStyle(fontSize: 15, color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(_formatTime(msg.createdAt), style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
        ]),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
