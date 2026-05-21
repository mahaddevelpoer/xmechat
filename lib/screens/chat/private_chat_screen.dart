import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/chat/message_bubble.dart';
import '../../widgets/chat/chat_input_bar.dart';
import '../../widgets/chat/reply_preview.dart';
import '../../widgets/common/user_avatar.dart';

class PrivateChatScreen extends ConsumerStatefulWidget {
  final String chatId;
  final UserModel? otherUser;
  const PrivateChatScreen({super.key, required this.chatId, this.otherUser});
  @override
  ConsumerState<PrivateChatScreen> createState() => _PrivateChatScreenState();
}

class _PrivateChatScreenState extends ConsumerState<PrivateChatScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _recorder = AudioRecorder();
  bool _showEmoji = false;
  bool _isRecording = false;
  bool _uploading = false;
  bool _isMuted = false;
  String _wallpaperPath = '';
  MessageModel? _replyTo;
  List<MessageModel> _messages = [];
  UserModel? _otherUser;
  String? _recordPath;
  RealtimeChannel? _reactionsChannel;

  @override
  void initState() {
    super.initState();
    _otherUser = widget.otherUser;
    _loadMessages();
    _markRead();
    _loadOtherUser();
    _loadChatPrefs();

    _reactionsChannel = Supabase.instance.client
        .channel('reactions_${widget.chatId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'reactions',
          callback: (payload) {
            _loadMessages();
          },
        )
        .subscribe();
  }

  Future<void> _loadMessages() async {
    final msgs = await ref
        .read(chatServiceProvider)
        .fetchMessages(widget.chatId);
    if (!mounted) return;
    setState(() => _messages = msgs.reversed.toList());
  }

  Future<void> _loadOtherUser() async {
    if (_otherUser != null) return;
    final chat = (await ref.read(chatServiceProvider).fetchChats()).firstWhere(
      (c) => c.id == widget.chatId,
      orElse: () => ChatModel(
        id: '',
        user1Id: '',
        user2Id: '',
        lastMessageAt: DateTime.now(),
        createdAt: DateTime.now(),
      ),
    );
    final myId = ref.read(authServiceProvider).currentUserId;
    final otherId = chat.getOtherUserId(myId);
    final user = await ref.read(chatServiceProvider).getUserById(otherId);
    if (!mounted) return;
    setState(() => _otherUser = user);
  }

  Future<void> _markRead() async {
    await ref.read(chatServiceProvider).markAllRead(widget.chatId);
  }

  Future<void> _loadChatPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _isMuted = prefs.getBool('mute_${widget.chatId}') ?? false;
      _wallpaperPath = prefs.getString('wallpaper_${widget.chatId}') ?? '';
    });
  }

  Future<void> _toggleMute() async {
    final prefs = await SharedPreferences.getInstance();
    final newVal = !_isMuted;
    await prefs.setBool('mute_${widget.chatId}', newVal);
    if (!mounted) return;
    setState(() => _isMuted = newVal);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(newVal ? 'Chat muted' : 'Chat unmuted'),
        backgroundColor: AppColors.primaryGreen,
      ),
    );
  }

  Future<void> _pickWallpaper() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('wallpaper_${widget.chatId}', path);
    if (!mounted) return;
    setState(() => _wallpaperPath = path);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Wallpaper set!'),
        backgroundColor: AppColors.primaryGreen,
      ),
    );
  }

  Future<void> _confirmBlock() async {
    if (_otherUser == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Block User'),
        content: Text(
          'Block ${_otherUser!.name}? They won\'t be able to send you messages.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      final goRouter = GoRouter.of(context);
      await ref.read(chatServiceProvider).blockUser(_otherUser!.id);
      messenger.showSnackBar(
        SnackBar(
          content: Text('${_otherUser!.name} blocked'),
          backgroundColor: AppColors.error,
        ),
      );
      if (goRouter.canPop()) {
        goRouter.pop();
      }
    }
  }

  void _searchMessages() {
    final searchCtrl = TextEditingController();
    List<MessageModel> results = [];
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Search Messages'),
          content: SizedBox(
            width: 400,
            height: 350,
            child: Column(
              children: [
                TextField(
                  controller: searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Type to search...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: (q) {
                    setDialogState(() {
                      results = q.isEmpty
                          ? []
                          : _messages
                                .where(
                                  (m) => m.text.toLowerCase().contains(
                                    q.toLowerCase(),
                                  ),
                                )
                                .toList();
                    });
                  },
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: results.isEmpty
                      ? Center(
                          child: Text(
                            searchCtrl.text.isEmpty
                                ? 'Start typing to search'
                                : 'No results',
                            style: const TextStyle(color: AppColors.textHint),
                          ),
                        )
                      : ListView.builder(
                          itemCount: results.length,
                          itemBuilder: (_, i) {
                            final msg = results[i];
                            return ListTile(
                              title: Text(
                                msg.text,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                msg.createdAt.toString().substring(0, 16),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textHint,
                                ),
                              ),
                              onTap: () {
                                Navigator.pop(ctx);
                                final idx = _messages.indexOf(msg);
                                if (idx >= 0 && _scrollCtrl.hasClients) {
                                  _scrollCtrl.animateTo(
                                    idx * 72.0,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeOut,
                                  );
                                }
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendText() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    if (_otherUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contact is still loading. Try again.')),
      );
      return;
    }
    _textCtrl.clear();
    setState(() => _showEmoji = false);
    final msg = await ref
        .read(chatServiceProvider)
        .sendTextMessage(
          chatId: widget.chatId,
          receiverId: _otherUser!.id,
          text: text,
          replyTo: _replyTo?.id,
          replyPreview: _replyTo?.text ?? '',
        );
    setState(() {
      _messages.add(msg);
      _replyTo = null;
    });
    _scrollToBottom();
  }

  Future<void> _sendImage({bool camera = false}) async {
    if (_otherUser == null) return;
    setState(() => _uploading = true);
    try {
      final picker = ImagePicker();
      final img = await picker.pickImage(
        source: camera ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 75,
      );
      if (img == null) return;
      final bytes = await img.readAsBytes();
      final msg = await ref
          .read(chatServiceProvider)
          .sendMediaMessage(
            chatId: widget.chatId,
            receiverId: _otherUser!.id,
            bytes: bytes,
            type: MessageType.image,
            fileName: img.name,
          );
      if (mounted) setState(() => _messages.add(msg));
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not send image: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _sendFile() async {
    if (_otherUser == null) return;
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes =
        file.bytes ??
        (file.path == null ? null : await File(file.path!).readAsBytes());
    if (bytes == null || bytes.isEmpty) return;
    setState(() => _uploading = true);
    try {
      final type =
          (file.extension?.toLowerCase() == 'mp3' ||
              file.extension?.toLowerCase() == 'wav' ||
              file.extension?.toLowerCase() == 'aac')
          ? MessageType.audio
          : MessageType.document;
      final msg = await ref
          .read(chatServiceProvider)
          .sendMediaMessage(
            chatId: widget.chatId,
            receiverId: _otherUser!.id,
            bytes: bytes,
            type: type,
            fileName: file.name,
          );
      if (mounted) setState(() => _messages.add(msg));
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not send file: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _sendLocation() async {
    if (_otherUser == null) return;
    try {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
      final pos = await Geolocator.getCurrentPosition();
      final msg = await ref
          .read(chatServiceProvider)
          .sendLocation(
            chatId: widget.chatId,
            receiverId: _otherUser!.id,
            lat: pos.latitude,
            lng: pos.longitude,
            locationName: 'My Location',
          );
      if (mounted) setState(() => _messages.add(msg));
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Location error: $e')));
      }
    }
  }

  Future<void> _sendContact() async {
    if (_otherUser == null) return;
    String name = '';
    String phone = '';
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Send Contact'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Name'),
              onChanged: (v) => name = v,
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'Phone'),
              onChanged: (v) => phone = v,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (result == true && name.isNotEmpty && phone.isNotEmpty) {
      final msg = await ref
          .read(chatServiceProvider)
          .sendContact(
            chatId: widget.chatId,
            receiverId: _otherUser!.id,
            contactName: name,
            contactPhone: phone,
          );
      if (mounted) setState(() => _messages.add(msg));
      _scrollToBottom();
    }
  }

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) return;
    final dir = await getTemporaryDirectory();
    _recordPath = '${dir.path}/${const Uuid().v4()}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: _recordPath!,
    );
    setState(() => _isRecording = true);
  }

  Future<void> _stopRecording() async {
    if (_otherUser == null) return;
    final path = await _recorder.stop();
    setState(() => _isRecording = false);
    if (path == null) return;
    setState(() => _uploading = true);
    try {
      // Read actual audio file
      final audioBytes = await _readFileBytes(path);
      if (audioBytes.isEmpty) return;
      final msg = await ref
          .read(chatServiceProvider)
          .sendMediaMessage(
            chatId: widget.chatId,
            receiverId: _otherUser!.id,
            bytes: audioBytes,
            type: MessageType.audio,
            fileName: 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
          );
      if (mounted) setState(() => _messages.add(msg));
      _scrollToBottom();
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<Uint8List> _readFileBytes(String path) async {
    try {
      return await File(path).readAsBytes();
    } catch (_) {
      return Uint8List(0);
    }
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

  void _onMessageLongPress(MessageModel msg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _MessageActionsSheet(
        message: msg,
        myId: ref.read(authServiceProvider).currentUserId,
        onReply: () {
          setState(() => _replyTo = msg);
          Navigator.pop(context);
        },
        onCopy: () {
          Clipboard.setData(ClipboardData(text: msg.text));
          Navigator.pop(context);
        },
        onStar: () async {
          final nav = Navigator.of(context);
          await ref
              .read(chatServiceProvider)
              .toggleStar(msg.id, !msg.isStarred);
          nav.pop();
          _loadMessages();
        },
        onDelete: (forAll) async {
          final nav = Navigator.of(context);
          await ref
              .read(chatServiceProvider)
              .deleteMessage(msg.id, forEveryone: forAll);
          nav.pop();
          _loadMessages();
        },
        onReact: (emoji) async {
          final nav = Navigator.of(context);
          await ref.read(chatServiceProvider).addReaction(msg.id, emoji);
          nav.pop();
          _loadMessages();
        },
      ),
    );
  }

  @override
  void dispose() {
    _reactionsChannel?.unsubscribe();
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myId = ref.read(authServiceProvider).currentUserId;
    // Listen to realtime messages
    ref.listen(streamMessagesProvider(widget.chatId), (_, next) {
      if (next.value != null) {
        _loadMessages();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.chatBg,
      appBar: AppBar(
        leadingWidth: 30,
        title: GestureDetector(
          onTap: () => context.push('/chat-info/${widget.chatId}'),
          child: Row(
            children: [
              UserAvatar(
                url: _otherUser?.avatarUrl,
                name: _otherUser?.name ?? '?',
                isOnline: _otherUser?.isOnline ?? false,
                radius: 18,
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _otherUser?.name ?? 'Loading...',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _otherUser?.isOnline == true
                        ? 'online'
                        : 'last seen recently',
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: () async {
              if (_otherUser == null) return;
              if (_otherUser!.id == myId) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cannot call yourself.'),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }
              // Show a loading indicator in snackbar or dialog while checking online status
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Checking contact status...'),
                  duration: Duration(seconds: 1),
                ),
              );
              final latestUser = await ref
                  .read(chatServiceProvider)
                  .getUserById(_otherUser!.id);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              if (latestUser == null || !latestUser.isOnline) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${_otherUser?.name ?? "User"} is offline. Cannot initiate call.',
                    ),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }
              final callId = await ref
                  .read(webrtcServiceProvider)
                  .initiateCall(_otherUser!.id, isVideo: true);
              if (!context.mounted) return;
              context.push(
                '/video-call/$callId',
                extra: {'isCaller': true, 'user': _otherUser},
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () async {
              if (_otherUser == null) return;
              if (_otherUser!.id == myId) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Cannot call yourself.'),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Checking contact status...'),
                  duration: Duration(seconds: 1),
                ),
              );
              final latestUser = await ref
                  .read(chatServiceProvider)
                  .getUserById(_otherUser!.id);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              if (latestUser == null || !latestUser.isOnline) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${_otherUser?.name ?? "User"} is offline. Cannot initiate call.',
                    ),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }
              final callId = await ref
                  .read(webrtcServiceProvider)
                  .initiateCall(_otherUser!.id, isVideo: false);
              if (!context.mounted) return;
              context.push(
                '/voice-call/$callId',
                extra: {'isCaller': true, 'user': _otherUser},
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _searchMessages,
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'info') context.push('/chat-info/${widget.chatId}');
              if (v == 'mute') await _toggleMute();
              if (v == 'wallpaper') await _pickWallpaper();
              if (v == 'clear') {
                await ref.read(chatServiceProvider).clearChat(widget.chatId);
                _loadMessages();
              }
              if (v == 'block') await _confirmBlock();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'info', child: Text('Contact info')),
              PopupMenuItem(
                value: 'mute',
                child: Text(
                  _isMuted ? 'Unmute notifications' : 'Mute notifications',
                ),
              ),
              const PopupMenuItem(value: 'wallpaper', child: Text('Wallpaper')),
              const PopupMenuItem(value: 'clear', child: Text('Clear chat')),
              const PopupMenuItem(value: 'block', child: Text('Block')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_uploading)
            const LinearProgressIndicator(color: AppColors.accentGreen),
          Expanded(
            child: Container(
              decoration: _wallpaperPath.isNotEmpty
                  ? BoxDecoration(
                      image: DecorationImage(
                        image: FileImage(File(_wallpaperPath)),
                        fit: BoxFit.cover,
                      ),
                    )
                  : null,
              child: _messages.isEmpty
                  ? const Center(
                      child: Text(
                        'No messages yet',
                        style: TextStyle(color: AppColors.textHint),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      itemCount: _messages.length,
                      itemBuilder: (_, i) {
                        final msg = _messages[i];
                        if (msg.isDeletedForUser(myId)) {
                          return Align(
                            alignment: msg.senderId == myId
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                vertical: 2,
                                horizontal: 8,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                '🚫 This message was deleted',
                                style: TextStyle(
                                  color: AppColors.textHint,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          );
                        }
                        return MessageBubble(
                          message: msg,
                          isMe: msg.senderId == myId,
                          otherUserName: _otherUser?.name ?? 'Unknown',
                          onLongPress: () => _onMessageLongPress(msg),
                          onReply: (m) => setState(() => _replyTo = m),
                        );
                      },
                    ),
            ),
          ),
          if (_replyTo != null)
            ReplyPreview(
              message: _replyTo!,
              onClose: () => setState(() => _replyTo = null),
            ),
          if (_showEmoji)
            SizedBox(
              height: 280,
              child: EmojiPicker(
                onEmojiSelected: (_, emoji) => _textCtrl.text += emoji.emoji,
              ),
            ),
          ChatInputBar(
            controller: _textCtrl,
            isRecording: _isRecording,
            onSend: _sendText,
            onEmoji: () => setState(() => _showEmoji = !_showEmoji),
            onAttach: () => _showAttachSheet(),
            onStartRecord: _startRecording,
            onStopRecord: _stopRecording,
            onCamera: () => _sendImage(camera: true),
          ),
        ],
      ),
    );
  }

  void _showAttachSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Wrap(
          spacing: 20,
          runSpacing: 16,
          children: [
            _AttachItem(
              icon: Icons.image,
              label: 'Gallery',
              color: Colors.purple,
              onTap: () {
                Navigator.pop(context);
                _sendImage();
              },
            ),
            _AttachItem(
              icon: Icons.camera_alt,
              label: 'Camera',
              color: Colors.red,
              onTap: () {
                Navigator.pop(context);
                _sendImage(camera: true);
              },
            ),
            _AttachItem(
              icon: Icons.attach_file,
              label: 'Document',
              color: Colors.blue,
              onTap: () {
                Navigator.pop(context);
                _sendFile();
              },
            ),
            _AttachItem(
              icon: Icons.location_on,
              label: 'Location',
              color: Colors.green,
              onTap: () {
                Navigator.pop(context);
                _sendLocation();
              },
            ),
            _AttachItem(
              icon: Icons.contact_page,
              label: 'Contact',
              color: Colors.orange,
              onTap: () {
                Navigator.pop(context);
                _sendContact();
              },
            ),
            _AttachItem(
              icon: Icons.gif,
              label: 'GIF',
              color: Colors.teal,
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('GIF support coming soon!'),
                    backgroundColor: AppColors.primaryGreen,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _AttachItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageActionsSheet extends StatelessWidget {
  final MessageModel message;
  final String myId;
  final VoidCallback onReply, onCopy, onStar;
  final void Function(bool) onDelete;
  final void Function(String) onReact;

  const _MessageActionsSheet({
    required this.message,
    required this.myId,
    required this.onReply,
    required this.onCopy,
    required this.onStar,
    required this.onDelete,
    required this.onReact,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Reactions row
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['??', '??', '??', '??', '??', '??']
                .map(
                  (e) => GestureDetector(
                    onTap: () => onReact(e),
                    child: Text(e, style: const TextStyle(fontSize: 28)),
                  ),
                )
                .toList(),
          ),
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.reply),
          title: const Text('Reply'),
          onTap: onReply,
        ),
        if (message.type == MessageType.text)
          ListTile(
            leading: const Icon(Icons.copy),
            title: const Text('Copy'),
            onTap: onCopy,
          ),
        ListTile(
          leading: Icon(message.isStarred ? Icons.star : Icons.star_border),
          title: Text(message.isStarred ? 'Unstar' : 'Star'),
          onTap: onStar,
        ),
        ListTile(
          leading: const Icon(Icons.forward),
          title: const Text('Forward'),
          onTap: () => Navigator.pop(context),
        ),
        ListTile(
          leading: const Icon(Icons.delete, color: AppColors.error),
          title: const Text('Delete', style: TextStyle(color: AppColors.error)),
          onTap: () {
            final isMine = message.senderId == myId;
            if (isMine) {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Delete Message'),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        onDelete(false);
                      },
                      child: const Text('Delete for Me'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        onDelete(true);
                      },
                      child: const Text(
                        'Delete for Everyone',
                        style: TextStyle(color: AppColors.error),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ],
                ),
              );
            } else {
              onDelete(false);
            }
          },
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
