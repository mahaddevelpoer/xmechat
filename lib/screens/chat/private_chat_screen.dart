import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme.dart';
import '../../services/chat_service.dart';
import '../../models/models.dart';
import '../../widgets/chat/message_bubble.dart';
import '../../widgets/chat/chat_input_bar.dart';

class PrivateChatScreen extends StatefulWidget {
  final String chatId;
  final String? otherUserId;

  const PrivateChatScreen({
    super.key,
    required this.chatId,
    this.otherUserId,
  });

  @override
  State<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends State<PrivateChatScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<MessageModel> _messages = [];
  bool _loading = true;
  bool _isLoadingSend = false;

  late final String _myId;
  late final ChatService _chatService;
  String? _otherUserId;
  UserModel? _otherUser;

  @override
  void initState() {
    super.initState();
    _myId = Supabase.instance.client.auth.currentUser?.id ?? '';
    _chatService = ChatService(_myId);
    _otherUserId = widget.otherUserId;
    _loadData();
    _listenForMessages();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      if (_otherUserId == null || _otherUserId!.isEmpty) {
        final data = await Supabase.instance.client
            .from('conversations')
            .select()
            .eq('id', widget.chatId)
            .maybeSingle();
        if (data != null) {
          _otherUserId = data['participant_1'] == _myId ? data['participant_2'] : data['participant_1'];
        }
      }
      if (_otherUserId != null && _otherUserId!.isNotEmpty) {
        final user = await _chatService.getUserById(_otherUserId!);
        if (user != null && mounted) setState(() => _otherUser = user);
      }
      final msgs = await _chatService.fetchMessages(widget.chatId);
      if (mounted) setState(() { _messages = msgs.reversed.toList(); _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _listenForMessages() {
    _chatService.streamMessages(widget.chatId).listen((data) {
      if (!mounted) return;
      setState(() => _messages = data.map((m) => MessageModel.fromMap(m)).toList());
    });
  }

  Future<void> _sendMessage() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _isLoadingSend = true);
    try {
      await _chatService.sendTextMessage(
        chatId: widget.chatId,
        receiverId: _otherUserId ?? '',
        text: text,
      );
      _textCtrl.clear();
    } catch (_) {}
    if (mounted) setState(() => _isLoadingSend = false);
  }

  Future<void> _pickMedia() async {
    try {
      final XFile? file = await openFile(
        acceptedTypeGroups: [XTypeGroup(extensions: ['jpg', 'jpeg', 'png', 'gif', 'mp4', 'mov', 'pdf', 'doc', 'docx'])],
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final ext = file.name.split('.').last.toLowerCase();
      final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);
      final isVideo = ['mp4', 'mov', 'avi'].contains(ext);
      final type = isVideo ? MessageType.video : isImage ? MessageType.image : MessageType.document;
      await _chatService.sendMediaMessage(
        chatId: widget.chatId,
        receiverId: _otherUserId ?? '',
        bytes: bytes,
        type: type,
        fileName: file.name,
      );
    } catch (_) {}
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return ''; }
  }

  Widget _buildMessageBubble(MessageModel msg) {
    final isMe = msg.senderId == _myId;
    return MessageBubble(
      isSent: isMe,
      text: msg.text,
      time: _formatTime(msg.createdAt.toIso8601String()),
      imageUrl: msg.type == MessageType.image ? msg.mediaUrl : null,
      fileName: msg.type == MessageType.document ? msg.fileName : null,
      fileSize: msg.fileSize,
      durationSeconds: msg.duration,
      isVoiceNote: msg.type == MessageType.audio,
      isDocument: msg.type == MessageType.document,
      statusIcon: isMe ? (msg.status == MessageStatus.read ? 'read' : msg.status == MessageStatus.delivered ? 'delivered' : 'sent') : '',
      statusColor: msg.status == MessageStatus.read ? AppColors.online : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(_otherUser?.name ?? 'Chat', style: AppText.chatHeaderName),
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
                          itemBuilder: (_, i) => _buildMessageBubble(_messages[i]),
                        ),
                ),
                ChatInputBar(
                  textController: _textCtrl,
                  isLoading: _isLoadingSend,
                  isRecording: false,
                  recordingDuration: '0:00',
                  onSend: _sendMessage,
                  onMicLongPressStart: () {},
                  onMicLongPressEnd: () {},
                  onCancelRecording: () {},
                  onEmojiTap: () {},
                  onAttachTap: _pickMedia,
                  showSend: _textCtrl.text.isNotEmpty,
                ),
              ],
            ),
    );
  }
}
