import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme.dart';
import '../../services/group_service.dart';
import '../../models/models.dart';
import '../../widgets/common/user_avatar.dart';

class GroupChatScreen extends StatefulWidget {
  final String groupId;
  final GroupModel? group;

  const GroupChatScreen({
    super.key,
    required this.groupId,
    this.group,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final _scrollCtrl = ScrollController();
  List<GroupMessageModel> _messages = [];
  bool _loading = true;
  late final String _myId;
  late final GroupService _groupService;
  GroupModel? _group;

  @override
  void initState() {
    super.initState();
    _myId = Supabase.instance.client.auth.currentUser?.id ?? '';
    _groupService = GroupService(_myId);
    _group = widget.group;
    _loadData();
    _listenForMessages();
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      if (_group == null) {
        final groups = await _groupService.fetchMyGroups();
        _group = groups.cast<GroupModel?>().firstWhere(
          (g) => g?.id == widget.groupId,
          orElse: () => null,
        );
      }
      final msgs = await _groupService.fetchGroupMessages(widget.groupId);
      if (mounted) setState(() { _messages = msgs.reversed.toList(); _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _listenForMessages() {
    _groupService.streamGroupMessages(widget.groupId).listen((data) {
      if (!mounted) return;
      setState(() => _messages = data.map((m) => GroupMessageModel.fromMap(m)).toList());
    });
  }

  Future<void> _sendText(String text) async {
    if (text.trim().isEmpty) return;
    try {
      await _groupService.sendGroupMessage(
        groupId: widget.groupId, text: text.trim(),
      );
    } catch (_) {}
  }

  Future<void> _showMembers() async {
    final members = await _groupService.fetchMembers(widget.groupId);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (_) => _buildMembersSheet(members),
    );
  }

  Widget _buildMembersSheet(List<GroupMemberModel> members) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Members (${members.length})', style: AppText.panelTitle),
          const SizedBox(height: 12),
          SizedBox(
            height: members.length * 56.0,
            child: ListView.builder(
              itemCount: members.length,
              itemBuilder: (_, i) {
                final m = members[i];
                final name = m.user?.name ?? m.userId;
                return ListTile(
                  leading: UserAvatar(name: name, imageUrl: m.user?.avatarUrl),
                  title: Text(name, style: AppText.name),
                  trailing: m.isAdmin
                      ? const Icon(Icons.star, size: 18, color: AppColors.accent)
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = _group?.name ?? 'Group';
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: GestureDetector(
          onTap: _showMembers,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: AppText.chatHeaderName),
              Text('Tap for info', style: AppText.timestamp),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, size: 20),
            onPressed: _showMembers,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: _messages.isEmpty
                      ? Center(child: Text('No messages yet', style: AppText.preview))
                      : ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.all(8),
                          itemCount: _messages.length,
                          itemBuilder: (_, i) => _buildGroupBubble(_messages[i]),
                        ),
                ),
                _buildInputBar(),
              ],
            ),
    );
  }

  Widget _buildGroupBubble(GroupMessageModel msg) {
    final isMe = msg.senderId == _myId;
    final senderName = msg.senderUser?.name ?? msg.senderId;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? AppColors.sentBubble : AppColors.recvBubble,
          borderRadius: BorderRadius.circular(AppSizes.radiusMsg),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(senderName, style: AppText.label.copyWith(color: AppColors.accent, fontSize: 11)),
              ),
            Text(msg.text, style: AppText.message),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                _formatTime(msg.createdAt.toIso8601String()),
                style: AppText.timestamp.copyWith(fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    final ctrl = TextEditingController();
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                hintText: 'Type a message...',
                isDense: true,
                border: InputBorder.none,
              ),
              onSubmitted: (v) {
                _sendText(v);
                ctrl.clear();
              },
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, size: 20),
            color: AppColors.accent,
            onPressed: () {
              _sendText(ctrl.text);
              ctrl.clear();
            },
          ),
        ],
      ),
    );
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return ''; }
  }
}
