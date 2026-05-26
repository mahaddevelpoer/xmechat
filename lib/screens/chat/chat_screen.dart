import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:just_audio/just_audio.dart';
import '../../theme.dart';
import '../../widgets/chat/message_bubble.dart';
import '../../widgets/chat/chat_input_bar.dart';
import '../../widgets/chat/voice_note_player.dart';
import '../../services/chat_service.dart';
import '../../models/models.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String? otherUserId;

  const ChatScreen({
    super.key,
    required this.chatId,
    this.otherUserId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final Map<String, AudioPlayer> _audioPlayers = {};
  String? _activeAudioId;
  final String _recordingDuration = '0:00';

  List<MessageModel> _messages = [];
  bool _loading = true;
  String? _error;

  late final String _myId;
  late final ChatService _chatService;
  String? _otherUserId;
  UserModel? _otherUser;

  bool _isLoadingSend = false;
  bool _isRecording = false;

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
    for (final p in _audioPlayers.values) { p.stop(); p.dispose(); }
    _audioPlayers.clear();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      if (_otherUserId == null || _otherUserId!.isEmpty) {
        final userId = _myId;
        final data = await Supabase.instance.client
            .from('conversations')
            .select()
            .eq('id', widget.chatId)
            .maybeSingle();
        if (data != null) {
          _otherUserId = data['participant_1'] == userId ? data['participant_2'] : data['participant_1'];
        }
      }
      if (_otherUserId != null && _otherUserId!.isNotEmpty) {
        final user = await _chatService.getUserById(_otherUserId!);
        if (user != null && mounted) setState(() => _otherUser = user);
      }
      await _fetchMessages();
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _fetchMessages() async {
    try {
      final msgs = await _chatService.fetchMessages(widget.chatId, limit: 100);
      if (mounted) {
        setState(() { _messages = msgs; _loading = false; });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _listenForMessages() {
    _chatService.streamMessages(widget.chatId).listen((data) {
      if (!mounted) return;
      final msgs = data.map((m) => MessageModel.fromMap(m)).toList();
      setState(() => _messages = msgs);
      _scrollToBottom();
      _markAsRead();
    });
  }

  Future<void> _markAsRead() async {
    try {
      await _chatService.markAllRead(widget.chatId);
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 150), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _isLoadingSend || _otherUserId == null) return;
    setState(() => _isLoadingSend = true);
    try {
      await _chatService.sendTextMessage(chatId: widget.chatId, receiverId: _otherUserId!, text: text);
      _textCtrl.clear();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Send failed: $e')));
    }
    if (mounted) setState(() => _isLoadingSend = false);
  }

  void _onMicLongPressStart() { setState(() => _isRecording = true); }
  void _onMicLongPressEnd() { setState(() => _isRecording = false); }
  void _onCancelRecording() { setState(() => _isRecording = false); }

  void _onMessageLongPress(MessageModel msg) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(12))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: ['👍', '❤️', '😂', '😮', '😢', '🙏'].map((e) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () {
                      _chatService.addReaction(msg.id, e);
                      Navigator.pop(ctx);
                    },
                    child: CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.surface,
                      child: Text(e, style: const TextStyle(fontSize: 16)),
                    ),
                  ),
                );
              }).toList(),
            ),
            const Divider(),
            _actionTile(ctx, Icons.reply_outlined, 'Reply'),
            _actionTile(ctx, Icons.content_copy_outlined, 'Copy'),
            _actionTile(ctx, Icons.star_outline, 'Star', onTap: () {
              _chatService.toggleStar(msg.id, !msg.isStarred);
              Navigator.pop(ctx);
            }),
            _actionTile(ctx, Icons.forward_outlined, 'Forward'),
            _actionTile(ctx, Icons.info_outlined, 'Info'),
            const Divider(),
            _actionTile(ctx, Icons.delete_outline, 'Delete', color: AppColors.danger, onTap: () {
              _chatService.deleteMessage(msg.id, forEveryone: false);
              Navigator.pop(ctx);
            }),
          ],
        ),
      ),
    );
  }

  Widget _actionTile(BuildContext ctx, IconData icon, String label, {Color? color, VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, size: 20, color: color ?? AppColors.textPrimary),
      title: Text(label, style: AppText.message.copyWith(color: color ?? AppColors.textPrimary)),
      onTap: onTap ?? () => Navigator.pop(ctx),
      dense: true,
    );
  }

  String _displayName() {
    if (_otherUser == null) return 'Loading...';
    return _otherUser!.name.isNotEmpty ? _otherUser!.name : _otherUser!.email;
  }

  String _statusText() {
    if (_otherUser == null) return '';
    if (_otherUser!.isOnline) return 'online';
    final lastSeen = _otherUser!.lastSeen;
    try {
      final dt = lastSeen.toLocal();
      return 'last seen ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return ''; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildMessagesArea()),
          ChatInputBar(
            textController: _textCtrl,
            isLoading: _isLoadingSend,
            isRecording: _isRecording,
            recordingDuration: _recordingDuration,
            onSend: _sendMessage,
            onMicLongPressStart: _onMicLongPressStart,
            onMicLongPressEnd: _onMicLongPressEnd,
            onCancelRecording: _onCancelRecording,
            showSend: _textCtrl.text.isNotEmpty,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.arrow_back, size: 20), onPressed: () => Navigator.pop(context)),
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.accentLight,
            child: Text(
              _displayName().isNotEmpty ? _displayName()[0].toUpperCase() : '?',
              style: AppText.name.copyWith(color: AppColors.accent, fontSize: 13),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_displayName(), style: AppText.chatHeaderName),
                Text(_statusText(), style: AppText.timestamp.copyWith(color: AppColors.accent)),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.call_outlined, size: 20), onPressed: () {}, tooltip: 'Voice Call'),
          IconButton(icon: const Icon(Icons.videocam_outlined, size: 20), onPressed: () {}, tooltip: 'Video Call'),
          IconButton(icon: const Icon(Icons.search_outlined, size: 20), onPressed: () {}, tooltip: 'Search'),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: (v) {},
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'contact', child: Text('View Contact', style: TextStyle(fontSize: 13))),
              const PopupMenuItem(value: 'media', child: Text('Media, Links & Docs', style: TextStyle(fontSize: 13))),
              const PopupMenuItem(value: 'mute', child: Text('Mute Notifications', style: TextStyle(fontSize: 13))),
              const PopupMenuItem(value: 'clear', child: Text('Clear Chat', style: TextStyle(fontSize: 13))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessagesArea() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40, color: AppColors.danger),
            const SizedBox(height: 8),
            Text('Failed to load messages', style: AppText.preview),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _fetchMessages, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline, size: 48, color: AppColors.textHint.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text('No messages yet', style: AppText.preview),
            Text('Say hello to start the conversation!', style: AppText.timestamp),
          ],
        ),
      );
    }
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: ListView.builder(
        controller: _scrollCtrl,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final msg = _messages[index];
          final isSent = msg.senderId == _myId;
          final time = _formatTime(msg.createdAt.toIso8601String());

          String statusIcon = '';
          Color? statusColor;
          if (isSent) {
            switch (msg.status) {
              case MessageStatus.read:
                statusIcon = '✓✓';
                statusColor = const Color(0xFF53BDEB);
              case MessageStatus.delivered:
                statusIcon = '✓✓';
                statusColor = AppColors.textHint;
              default:
                statusIcon = '✓';
                statusColor = AppColors.textHint;
            }
          }

          Widget? voiceWidget;
          if (msg.type == MessageType.audio && msg.mediaUrl.isNotEmpty) {
            final player = _audioPlayers.putIfAbsent(msg.id, () => AudioPlayer());
            voiceWidget = VoiceNotePlayer(
              mediaUrl: msg.mediaUrl,
              durationSeconds: msg.duration,
              player: player,
              isPlaying: _activeAudioId == msg.id,
              progress: 0,
              onPlayPause: () => _togglePlayPause(msg.id, player, msg.mediaUrl),
              onSeek: (f) => player.seek(Duration(seconds: (f * msg.duration).round())),
              speed: player.speed,
              onSpeedChange: (s) => player.setSpeed(s),
            );
          }

          return MessageBubble(
            isSent: isSent,
            text: msg.text,
            time: time,
            imageUrl: msg.type == MessageType.image ? msg.mediaUrl : null,
            fileName: msg.type == MessageType.document ? msg.fileName : null,
            fileSize: msg.type == MessageType.document ? msg.fileSize : null,
            isVoiceNote: msg.type == MessageType.audio,
            voiceNoteWidget: voiceWidget,
            statusIcon: statusIcon,
            statusColor: statusColor,
            onLongPress: () => _onMessageLongPress(msg),
          );
        },
      ),
    );
  }

  void _togglePlayPause(String msgId, AudioPlayer player, String url) {
    if (_activeAudioId == msgId && player.playing) {
      player.pause();
      setState(() => _activeAudioId = null);
    } else {
      if (_activeAudioId != null) _audioPlayers[_activeAudioId]?.pause();
      player.setUrl(url);
      player.play();
      setState(() => _activeAudioId = msgId);
      player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed && mounted) {
          setState(() => _activeAudioId = null);
        }
      });
    }
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return ''; }
  }
}
