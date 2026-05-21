import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';

class BroadcastChatScreen extends ConsumerStatefulWidget {
  final String listId;
  final BroadcastListModel? list;
  const BroadcastChatScreen({super.key, required this.listId, this.list});
  @override
  ConsumerState<BroadcastChatScreen> createState() => _BroadcastChatScreenState();
}

class _BroadcastChatScreenState extends ConsumerState<BroadcastChatScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  BroadcastListModel? _list;
  List<BroadcastMessageModel> _messages = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _list = widget.list;
    _load();
  }

  Future<void> _load() async {
    if (_list == null) {
      final lists = await ref.read(broadcastServiceProvider).fetchMyLists();
      if (!mounted) return;
      _list = lists.firstWhere((l) => l.id == widget.listId,
          orElse: () => BroadcastListModel(
              id: widget.listId, name: 'Broadcast', createdBy: '', createdAt: DateTime.now()));
    }
    final msgs = await ref.read(broadcastServiceProvider).fetchMessages(widget.listId);
    if (!mounted) return;
    setState(() { _messages = msgs; _loading = false; });
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();
    await ref.read(broadcastServiceProvider).sendBroadcastMessage(
      listId: widget.listId, text: text);
    if (!mounted) return;
    await _load();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _showListInfo() async {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircleAvatar(
              backgroundColor: AppColors.primaryGreen,
              radius: 30,
              child: Text(
                (_list?.name.isNotEmpty == true ? _list!.name[0].toUpperCase() : 'B'),
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            Text(_list?.name ?? 'Broadcast',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('${_list?.members.length ?? 0} recipients',
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            const Divider(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/create-broadcast');
                },
                icon: const Icon(Icons.add),
                label: const Text('Add Recipients'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  @override
  void dispose() { _textCtrl.dispose(); _scrollCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.chatBg,
      appBar: AppBar(
        leadingWidth: 30,
        title: GestureDetector(
          onTap: _showListInfo,
          child: Row(children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppColors.primaryGreen,
              child: Text(
                (_list?.name.isNotEmpty == true ? _list!.name[0].toUpperCase() : 'B'),
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_list?.name ?? 'Broadcast',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              Text('${_list?.members.length ?? 0} recipients',
                  style: const TextStyle(fontSize: 11, color: Colors.white70)),
            ]),
          ]),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showListInfo,
          ),
        ],
      ),
      body: Column(children: [
        if (_loading)
          const LinearProgressIndicator(color: AppColors.accentGreen),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AppColors.accentGreen.withAlpha(20),
          child: Row(children: [
            const Icon(Icons.info_outline, size: 16, color: AppColors.primaryGreen),
            const SizedBox(width: 8),
            Expanded(
              child: Text('This message will be sent to ${_list?.members.length ?? 0} recipients',
                  style: const TextStyle(color: AppColors.primaryGreen, fontSize: 12)),
            ),
          ]),
        ),
        Expanded(
          child: _messages.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64, height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withAlpha(20),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send_to_mobile,
                          size: 32, color: AppColors.primaryGreen),
                    ),
                    const SizedBox(height: 16),
                    const Text('No broadcasts yet',
                        style: TextStyle(fontSize: 16, color: AppColors.textHint)),
                    const SizedBox(height: 8),
                    const Text('Type a message to broadcast to all recipients',
                        style: TextStyle(color: AppColors.textHint, fontSize: 13)),
                  ],
                ),
              )
            : ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                itemCount: _messages.length,
                itemBuilder: (_, i) {
                  final msg = _messages[i];
                  return Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                      constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.sentBubble,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                          bottomLeft: Radius.circular(12),
                        ),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withAlpha(15),
                              blurRadius: 2, offset: const Offset(0, 1))
                        ],
                      ),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(msg.text,
                            style: const TextStyle(fontSize: 15, color: AppColors.textPrimary)),
                        const SizedBox(height: 4),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.done_all, size: 14, color: AppColors.textHint),
                          const SizedBox(width: 4),
                          Text(
                            '${msg.createdAt.hour.toString().padLeft(2, '0')}:${msg.createdAt.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(fontSize: 10, color: AppColors.textHint),
                          ),
                        ]),
                      ]),
                    ),
                  );
                },
              ),
        ),
        Container(
          color: Colors.white,
          padding: EdgeInsets.only(
            left: 12, right: 12, top: 8,
            bottom: MediaQuery.of(context).padding.bottom + 8,
          ),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _textCtrl,
                decoration: InputDecoration(
                  hintText: 'Type a broadcast message',
                  hintStyle: const TextStyle(color: AppColors.textHint),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: AppColors.bgSecondary,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: const BoxDecoration(
                color: AppColors.primaryGreen,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: _send,
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}
