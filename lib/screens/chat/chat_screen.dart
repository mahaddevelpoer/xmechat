import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:just_audio/just_audio.dart';
import '../../theme.dart';
import '../../widgets/chat/message_bubble.dart';
import '../../widgets/chat/chat_input_bar.dart';
import '../../widgets/chat/voice_note_player.dart';

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

  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  String? _error;

  String? _myId;
  String? _otherUserId;
  Map<String, dynamic>? _otherUser;

  bool _isLoadingSend = false;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _myId = Supabase.instance.client.auth.currentUser?.id;
    _otherUserId = widget.otherUserId;
    _loadData();
    _listenForMessages();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    for (final p in _audioPlayers.values) {
      p.stop();
      p.dispose();
    }
    _audioPlayers.clear();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final conv = await Supabase.instance.client
          .from('conversations')
          .select()
          .eq('id', widget.chatId)
          .maybeSingle();

      if (conv != null) {
        _otherUserId ??= conv['participant_1'] == _myId ? conv['participant_2'] : conv['participant_1'];
      }

      if (_otherUserId != null && _otherUserId!.isNotEmpty) {
        final userData = await Supabase.instance.client
            .from('users')
            .select()
            .eq('id', _otherUserId!)
            .maybeSingle();
        if (userData != null && mounted) {
          setState(() => _otherUser = Map<String, dynamic>.from(userData));
        }
      }

      await _fetchMessages();
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _fetchMessages() async {
    try {
      final data = await Supabase.instance.client
          .from('messages')
          .select()
          .eq('chat_id', widget.chatId)
          .eq('deleted_for_everyone', false)
          .order('created_at', ascending: true);
      if (mounted) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _listenForMessages() {
    Supabase.instance.client
        .channel('chat_${widget.chatId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'chat_id',
            value: widget.chatId,
          ),
          callback: (payload) {
            final msg = payload.newRecord;
            if (msg.isNotEmpty && mounted) {
              setState(() => _messages.add(Map<String, dynamic>.from(msg)));
              _scrollToBottom();
              _markAsRead();
            }
          },
        )
        .subscribe();
  }

  Future<void> _markAsRead() async {
    if (_myId == null || _otherUserId == null) return;
    try {
      await Supabase.instance.client
          .from('messages')
          .update({'status': 'read', 'seen_at': DateTime.now().toIso8601String()})
          .eq('chat_id', widget.chatId)
          .eq('sender_id', _otherUserId!)
          .isFilter('seen_at', null);
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
    if (text.isEmpty || _isLoadingSend) return;
    setState(() => _isLoadingSend = true);
    try {
      await Supabase.instance.client.from('messages').insert({
        'chat_id': widget.chatId,
        'sender_id': _myId,
        'text': text,
        'type': 'text',
        'status': 'sent',
        'created_at': DateTime.now().toIso8601String(),
      });
      await Supabase.instance.client
          .from('conversations')
          .update({'last_message': text, 'last_message_type': 'text', 'last_message_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', widget.chatId);
      _textCtrl.clear();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Send failed: $e')));
    }
    if (mounted) setState(() => _isLoadingSend = false);
  }

  void _onMicLongPressStart() {
    setState(() => _isRecording = true);
  }

  void _onMicLongPressEnd() {
    setState(() => _isRecording = false);
  }

  void _onCancelRecording() {
    setState(() => _isRecording = false);
  }

  void _onMessageLongPress(Map<String, dynamic> msg) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
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
                    onTap: () => Navigator.pop(ctx),
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
            _actionTile(ctx, Icons.star_outline, 'Star'),
            _actionTile(ctx, Icons.forward_outlined, 'Forward'),
            _actionTile(ctx, Icons.info_outlined, 'Info'),
            const Divider(),
            _actionTile(ctx, Icons.delete_outline, 'Delete', color: AppColors.danger),
          ],
        ),
      ),
    );
  }

  Widget _actionTile(BuildContext ctx, IconData icon, String label, {Color? color}) {
    return ListTile(
      leading: Icon(icon, size: 20, color: color ?? AppColors.textPrimary),
      title: Text(label, style: AppText.message.copyWith(color: color ?? AppColors.textPrimary)),
      onTap: () => Navigator.pop(ctx),
      dense: true,
    );
  }

  String _displayName() {
    if (_otherUser == null) return 'Loading...';
    return _otherUser!['name'] as String? ?? _otherUser!['email'] as String? ?? 'Unknown';
  }

  String _statusText() {
    if (_otherUser == null) return '';
    final online = _otherUser!['is_online'] as bool? ?? false;
    if (online) return 'online';
    final lastSeen = _otherUser!['last_seen'] as String?;
    if (lastSeen != null) {
      try {
        final dt = DateTime.parse(lastSeen).toLocal();
        return 'last seen ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }
    return '';
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
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
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
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
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
          final isSent = msg['sender_id'] == _myId;
          final text = msg['text'] as String? ?? '';
          final type = msg['type'] as String? ?? 'text';
          final time = _formatTime(msg['created_at'] as String? ?? '');
          final mediaUrl = msg['media_url'] as String? ?? '';
          final fileName = msg['file_name'] as String? ?? '';
          final fileSize = msg['file_size'] as int?;
          final duration = msg['duration_seconds'] as int? ?? msg['duration'] as int? ?? 0;
          final status = msg['status'] as String? ?? 'sent';

          String statusIcon = '';
          Color? statusColor;
          if (isSent) {
            if (status == 'read') {
              statusIcon = '✓✓';
              statusColor = const Color(0xFF53BDEB);
            } else if (status == 'delivered') {
              statusIcon = '✓✓';
              statusColor = AppColors.textHint;
            } else {
              statusIcon = '✓';
              statusColor = AppColors.textHint;
            }
          }

          Widget? voiceWidget;
          if (type == 'audio' && mediaUrl.isNotEmpty) {
            final player = _audioPlayers.putIfAbsent(msg['id'] as String, () => AudioPlayer());
            voiceWidget = VoiceNotePlayer(
              mediaUrl: mediaUrl,
              durationSeconds: duration,
              player: player,
              isPlaying: _activeAudioId == msg['id'],
              progress: 0,
              onPlayPause: () => _togglePlayPause(msg['id'] as String, player, mediaUrl),
              onSeek: (f) => player.seek(Duration(seconds: (f * duration).round())),
              speed: player.speed,
              onSpeedChange: (s) => player.setSpeed(s),
            );
          }

          return MessageBubble(
            isSent: isSent,
            text: text,
            time: time,
            imageUrl: type == 'image' ? mediaUrl : null,
            fileName: type == 'document' ? fileName : null,
            fileSize: type == 'document' ? fileSize : null,
            isVoiceNote: type == 'audio',
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
      if (_activeAudioId != null) {
        _audioPlayers[_activeAudioId]?.pause();
      }
      player.setUrl(url);
      player.play();
      setState(() => _activeAudioId = msgId);
      player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          if (mounted) setState(() => _activeAudioId = null);
        }
      });
    }
  }

  String _formatTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}
