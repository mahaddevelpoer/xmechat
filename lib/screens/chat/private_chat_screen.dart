import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_colors.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
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
  final bool _showTyping = false;
  String _wallpaperPath = '';
  MessageModel? _replyTo;
  MessageModel? _editingMessage;
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
                            style: const TextStyle(color: AppColors.outline),
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
                                  color: AppColors.outline,
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

  Future<void> _editMessage() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty || _editingMessage == null) return;
    final msgId = _editingMessage!.id;
    try {
      await ref.read(chatServiceProvider).editMessage(msgId, text);
      setState(() {
        final idx = _messages.indexWhere((m) => m.id == msgId);
        if (idx >= 0) {
          _messages[idx] = _messages[idx].copyWith(text: text);
        }
        _editingMessage = null;
      });
      _textCtrl.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not edit message: $e')),
        );
      }
    }
  }

  Future<void> _sendImage({bool camera = false}) async {
    if (_otherUser == null) return;
    setState(() => _uploading = true);
    try {
      Uint8List? bytes;
      String fileName = 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
      if (camera) {
        final picker = ImagePicker();
        final img = await picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 75,
        );
        if (img == null) {
          if (mounted) setState(() => _uploading = false);
          return;
        }
        bytes = await img.readAsBytes();
        fileName = img.name;
      } else {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.image,
          withData: true,
        );
        if (result == null || result.files.isEmpty) {
          if (mounted) setState(() => _uploading = false);
          return;
        }
        final file = result.files.first;
        bytes =
            file.bytes ??
            (file.path != null ? File(file.path!).readAsBytesSync() : null);
        fileName = file.name;
      }
      if (bytes == null) {
        if (mounted) setState(() => _uploading = false);
        return;
      }
      final msg = await ref
          .read(chatServiceProvider)
          .sendMediaMessage(
            chatId: widget.chatId,
            receiverId: _otherUser!.id,
            bytes: bytes,
            type: MessageType.image,
            fileName: fileName,
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
      backgroundColor: AppColors.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _MessageActionsSheet(
        message: msg,
        myId: ref.read(authServiceProvider).currentUserId,
        onReply: () {
          setState(() => _replyTo = msg);
          Navigator.pop(context);
        },
        onEdit: msg.senderId == ref.read(authServiceProvider).currentUserId && msg.type == MessageType.text
            ? () {
                Navigator.pop(context);
                setState(() => _editingMessage = msg);
                _textCtrl.text = msg.text;
                _textCtrl.selection = TextSelection.fromPosition(
                  TextPosition(offset: msg.text.length),
                );
              }
            : null,
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
    ref.listen(streamMessagesProvider(widget.chatId), (_, next) {
      if (next.value != null) {
        _loadMessages();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.surface,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(myId),
      body: Stack(
        children: [
          Column(
            children: [
              if (_uploading)
                const LinearProgressIndicator(
                  color: AppColors.secondary,
                  backgroundColor: AppColors.outlineVariant,
                ),
              Expanded(child: _buildMessageList(myId)),
              if (_replyTo != null)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.glassBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: ReplyPreview(
                        message: _replyTo!,
                        onClose: () => setState(() => _replyTo = null),
                      ),
                    ),
                  ),
                ),
              if (_editingMessage != null)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withAlpha(30),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.secondary.withAlpha(80)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.edit, size: 16, color: AppColors.secondary),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Editing message',
                          style: TextStyle(
                            color: AppColors.secondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _editingMessage = null;
                            _textCtrl.clear();
                          });
                        },
                        child: const Icon(Icons.close, size: 18, color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              if (_showEmoji)
                SizedBox(
                  height: 280,
                  child: EmojiPicker(
                    onEmojiSelected: (_, emoji) =>
                        _textCtrl.text += emoji.emoji,
                  ),
                ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.of(context).padding.bottom > 0 ? 0 : 8,
            child: _buildFloatingInputBar(),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(String myId) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight + 1),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface.withAlpha(180),
              border: Border(bottom: BorderSide(color: AppColors.glassBorder)),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.only(
                  left: 4,
                  right: 4,
                  top: MediaQuery.of(context).padding.top > 0 ? 0 : 8,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back,
                        color: AppColors.onSurface,
                      ),
                      onPressed: () => context.pop(),
                    ),
                    GestureDetector(
                      onTap: () => context.push('/chat-info/${widget.chatId}'),
                      child: Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: _otherUser?.isOnline == true
                                  ? [
                                      BoxShadow(
                                        color: AppColors.secondary.withAlpha(
                                          80,
                                        ),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: UserAvatar(
                              url: _otherUser?.avatarUrl,
                              name: _otherUser?.name ?? '?',
                              isOnline: _otherUser?.isOnline ?? false,
                              radius: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _otherUser?.name ?? 'Loading...',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                              Text(
                                _showTyping
                                    ? 'Typing...'
                                    : _otherUser?.isOnline == true
                                    ? 'online'
                                    : 'last seen recently',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.secondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(
                        Icons.videocam,
                        color: AppColors.onSurfaceVariant,
                      ),
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
                            .initiateCall(_otherUser!.id, isVideo: true);
                        if (!context.mounted) return;
                        context.push(
                          '/video-call/$callId',
                          extra: {'isCaller': true, 'user': _otherUser},
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.call,
                        color: AppColors.onSurfaceVariant,
                      ),
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
                      icon: const Icon(
                        Icons.search,
                        color: AppColors.onSurfaceVariant,
                      ),
                      onPressed: _searchMessages,
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert,
                        color: AppColors.onSurfaceVariant,
                      ),
                      onSelected: (v) async {
                        if (v == 'info') {
                          context.push('/chat-info/${widget.chatId}');
                        }
                        if (v == 'mute') await _toggleMute();
                        if (v == 'wallpaper') await _pickWallpaper();
                        if (v == 'clear') {
                          await ref
                              .read(chatServiceProvider)
                              .clearChat(widget.chatId);
                          _loadMessages();
                        }
                        if (v == 'block') await _confirmBlock();
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'info',
                          child: Text('Contact info'),
                        ),
                        PopupMenuItem(
                          value: 'mute',
                          child: Text(
                            _isMuted
                                ? 'Unmute notifications'
                                : 'Mute notifications',
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'wallpaper',
                          child: Text('Wallpaper'),
                        ),
                        const PopupMenuItem(
                          value: 'clear',
                          child: Text('Clear chat'),
                        ),
                        const PopupMenuItem(
                          value: 'block',
                          child: Text('Block'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingInputBar() {
    final enterToSend = ref.watch(enterToSendProvider);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        8,
        4,
        8,
        MediaQuery.of(context).padding.bottom > 0
            ? MediaQuery.of(context).padding.bottom
            : 12,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.glassBg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.glassBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(60),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: AppColors.glassInnerGlow,
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: AppColors.onSurfaceVariant,
                    size: 28,
                  ),
                  onPressed: () => _showAttachSheet(),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.mood,
                    color: AppColors.secondary,
                    size: 26,
                  ),
                  onPressed: () => setState(() => _showEmoji = !_showEmoji),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: TextField(
                      controller: _textCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Type a message',
                        hintStyle: TextStyle(color: AppColors.outline),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        fillColor: Colors.transparent,
                        filled: true,
                      ),
                      maxLines: 4,
                      minLines: 1,
                      textInputAction: enterToSend
                          ? TextInputAction.send
                          : TextInputAction.newline,
                      onSubmitted: enterToSend ? (_) => _sendText() : null,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppColors.onSurface,
                      ),
                    ),
                  ),
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _textCtrl,
                  builder: (context, value, child) {
                    final hasText = value.text.trim().isNotEmpty;
                    return Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: IconButton(
                        icon: Icon(
                          hasText
                              ? Icons.send
                              : (_isRecording ? Icons.stop : Icons.mic),
                          color: _isRecording
                              ? AppColors.error
                              : hasText
                              ? AppColors.secondary
                              : AppColors.onSurfaceVariant,
                          size: 26,
                        ),
                        onPressed: hasText
                            ? (_editingMessage != null ? _editMessage : _sendText)
                            : (_isRecording ? _stopRecording : _startRecording),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageList(String myId) {
    final entries = <_ListEntry>[];
    String? lastDate;
    for (final msg in _messages) {
      final d = DateFormat('yMMMd').format(msg.createdAt);
      if (d != lastDate) {
        entries.add(_ListEntry.date(msg.createdAt));
        lastDate = d;
      }
      entries.add(_ListEntry.message(msg));
    }

    if (_messages.isEmpty) {
      return const Center(
        child: Text(
          'No messages yet',
          style: TextStyle(color: AppColors.outline),
        ),
      );
    }

    return Stack(
      children: [
        if (_wallpaperPath.isNotEmpty)
          Positioned.fill(
            child: Image.file(File(_wallpaperPath), fit: BoxFit.cover),
          ),
        ListView.builder(
          controller: _scrollCtrl,
          padding: EdgeInsets.only(
            left: 8,
            right: 8,
            top: 10,
            bottom: MediaQuery.of(context).padding.bottom > 0 ? 72 : 80,
          ),
          itemCount: entries.length + (_showTyping ? 1 : 0),
          itemBuilder: (_, i) {
            if (_showTyping && i == entries.length) {
              return const _TypingIndicator();
            }
            final entry = entries[i];
            if (entry.isDivider) {
              return _DateDivider(date: entry.date!);
            }
            return _buildMessageBubble(entry.message!, myId);
          },
        ),
      ],
    );
  }

  Widget _buildMessageBubble(MessageModel msg, String myId) {
    final isMe = msg.senderId == myId;

    if (msg.isDeletedForUser(myId)) {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isMe ? AppColors.primary.withAlpha(60) : AppColors.glassBg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: isMe
                  ? const Radius.circular(16)
                  : const Radius.circular(4),
              bottomRight: isMe
                  ? const Radius.circular(4)
                  : const Radius.circular(16),
            ),
            border: isMe ? null : Border.all(color: AppColors.glassBorder),
          ),
          child: const Text(
            'This message was deleted',
            style: TextStyle(
              color: AppColors.outline,
              fontStyle: FontStyle.italic,
              fontSize: 13,
            ),
          ),
        ),
      );
    }

    final bubble = Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            child: isMe ? _SentBubble(msg: msg) : _ReceivedBubble(msg: msg),
          ),
          if (msg.reactions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: _ReactionsPill(reactions: msg.reactions, isMe: isMe),
            ),
        ],
      ),
    );

    return Dismissible(
      key: ValueKey('msg-${msg.id}'),
      direction: DismissDirection.startToEnd,
      dismissThresholds: const {DismissDirection.startToEnd: 0.25},
      confirmDismiss: (_) async {
        setState(() => _replyTo = msg);
        return false;
      },
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        child: const Icon(Icons.reply, color: AppColors.secondary),
      ),
      child: GestureDetector(
        onTap: null,
        onLongPress: () => _onMessageLongPress(msg),
        child: bubble,
      ),
    );
  }

  void _showAttachSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainerLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
              color: const Color(0xFF9c7cff),
              onTap: () {
                Navigator.pop(context);
                _sendImage();
              },
            ),
            _AttachItem(
              icon: Icons.camera_alt,
              label: 'Camera',
              color: const Color(0xFFff6b8a),
              onTap: () {
                Navigator.pop(context);
                _sendImage(camera: true);
              },
            ),
            _AttachItem(
              icon: Icons.attach_file,
              label: 'Document',
              color: const Color(0xFF4fc3f7),
              onTap: () {
                Navigator.pop(context);
                _sendFile();
              },
            ),
            _AttachItem(
              icon: Icons.location_on,
              label: 'Location',
              color: const Color(0xFF4fdbc8),
              onTap: () {
                Navigator.pop(context);
                _sendLocation();
              },
            ),
            _AttachItem(
              icon: Icons.contact_page,
              label: 'Contact',
              color: const Color(0xFFfdb85c),
              onTap: () {
                Navigator.pop(context);
                _sendContact();
              },
            ),
            _AttachItem(
              icon: Icons.gif,
              label: 'GIF',
              color: const Color(0xFFaccdcc),
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

// ─── Helper models ─────────────────────────────────────────────

class _ListEntry {
  final bool isDivider;
  final MessageModel? message;
  final DateTime? date;
  _ListEntry.message(this.message) : isDivider = false, date = null;
  _ListEntry.date(this.date) : isDivider = true, message = null;
}

// ─── Date Divider ───────────────────────────────────────────────

class _DateDivider extends StatelessWidget {
  final DateTime date;
  const _DateDivider({required this.date});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final diff = now.difference(date);
    String text;
    if (diff.inDays == 0) {
      text = 'Today';
    } else if (diff.inDays == 1) {
      text = 'Yesterday';
    } else {
      text = DateFormat('MMM d, yyyy').format(date);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant.withAlpha(51),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.glassBorder.withAlpha(100)),
              ),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.onSurfaceVariant.withAlpha(128),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Sent Bubble ────────────────────────────────────────────────

class _SentBubble extends StatelessWidget {
  final MessageModel msg;
  const _SentBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(4),
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withAlpha(60),
            blurRadius: 12,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (msg.replyPreview.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surface.withAlpha(60),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                msg.replyPreview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: AppColors.surface,
                ),
              ),
            ),
          _MessageContent(message: msg, isMe: true),
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DateFormat('h:mm a').format(msg.createdAt).toLowerCase(),
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.surface.withAlpha(180),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                msg.status == MessageStatus.sending
                    ? Icons.access_time
                    : msg.status == MessageStatus.read
                    ? Icons.done_all
                    : msg.status == MessageStatus.delivered
                    ? Icons.done_all
                    : Icons.done,
                size: 14,
                color: msg.status == MessageStatus.read
                    ? AppColors.surface
                    : AppColors.surface.withAlpha(150),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Received Bubble ────────────────────────────────────────────

class _ReceivedBubble extends StatelessWidget {
  final MessageModel msg;
  const _ReceivedBubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final borderRadius = const BorderRadius.only(
      topLeft: Radius.circular(4),
      topRight: Radius.circular(16),
      bottomLeft: Radius.circular(16),
      bottomRight: Radius.circular(16),
    );
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.glassBg,
            borderRadius: borderRadius,
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (msg.replyPreview.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withAlpha(80),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    msg.replyPreview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: AppColors.onSurface,
                    ),
                  ),
                ),
              _MessageContent(message: msg, isMe: false),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('h:mm a').format(msg.createdAt).toLowerCase(),
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.onSurfaceVariant.withAlpha(180),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Reactions Pill ─────────────────────────────────────────────

class _ReactionsPill extends StatelessWidget {
  final List<ReactionModel> reactions;
  final bool isMe;
  const _ReactionsPill({required this.reactions, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final r in reactions) {
      counts[r.emoji] = (counts[r.emoji] ?? 0) + 1;
    }
    final entries = counts.entries.toList();
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh.withAlpha(200),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < entries.length; i++) ...[
              Text(entries[i].key, style: const TextStyle(fontSize: 14)),
              if (entries[i].value > 1)
                Padding(
                  padding: const EdgeInsets.only(left: 2, right: 6),
                  child: Text(
                    '${entries[i].value}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                )
              else if (i != entries.length - 1)
                const SizedBox(width: 6),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Message Content ────────────────────────────────────────────

class _MessageContent extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  const _MessageContent({required this.message, required this.isMe});

  Color get _textColor => isMe ? AppColors.surface : AppColors.onSurface;
  Color get _hintColor => isMe
      ? AppColors.surface.withAlpha(180)
      : AppColors.onSurfaceVariant.withAlpha(180);

  @override
  Widget build(BuildContext context) {
    switch (message.type) {
      case MessageType.text:
        return _buildText();

      case MessageType.image:
      case MessageType.viewOnce:
        return _buildImage(context);

      case MessageType.audio:
        return _VoiceMessageBubble(key: ValueKey('voice-${message.id}'), url: message.mediaUrl, isMe: isMe);

      case MessageType.video:
        return _buildVideo();

      case MessageType.document:
        return _buildDocument();

      case MessageType.location:
        final label = message.locationName.isNotEmpty
            ? message.locationName
            : 'Location';
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on, size: 16, color: _hintColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '📍 $label',
                style: TextStyle(color: _textColor, fontSize: 15),
              ),
            ),
          ],
        );

      case MessageType.contact:
        final name = message.contactName.isNotEmpty
            ? message.contactName
            : 'Contact';
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.person,
              size: 16,
              color: AppColors.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '👤 $name',
                style: TextStyle(color: _textColor, fontSize: 15),
              ),
            ),
          ],
        );

      case MessageType.gif:
        return Text('GIF', style: TextStyle(color: _textColor, fontSize: 15));

      case MessageType.poll:
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isMe
                ? AppColors.surface.withAlpha(40)
                : AppColors.surface.withAlpha(60),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.poll_outlined,
                size: 18,
                color: AppColors.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text('Poll', style: TextStyle(color: _textColor, fontSize: 15)),
            ],
          ),
        );

      case MessageType.sticker:
        return Text(
          'Sticker',
          style: TextStyle(color: _textColor, fontSize: 15),
        );

      case MessageType.deleted:
        return Text(
          'Deleted message',
          style: TextStyle(
            color: _hintColor,
            fontStyle: FontStyle.italic,
            fontSize: 14,
          ),
        );
    }
  }

  Widget _buildText() {
    return Text(
      message.text,
      style: TextStyle(fontSize: 15, color: _textColor),
    );
  }

  Widget _buildImage(BuildContext context) {
    if (message.isViewOnce && message.viewOnceOpened) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isMe
              ? AppColors.surface.withAlpha(40)
              : AppColors.surface.withAlpha(60),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.visibility_off_outlined, size: 18, color: _hintColor),
            const SizedBox(width: 8),
            Text(
              'View once photo (opened)',
              style: TextStyle(color: _hintColor, fontSize: 14),
            ),
          ],
        ),
      );
    }
    if (message.mediaUrl.isEmpty) {
      return Text(
        '📷 Photo',
        style: TextStyle(color: _textColor, fontSize: 15),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => showDialog(
            context: context,
            builder: (_) => Scaffold(
              backgroundColor: Colors.black,
              appBar: AppBar(
                backgroundColor: Colors.black,
                iconTheme: const IconThemeData(color: Colors.white),
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              body: Center(
                child: InteractiveViewer(
                  child: CachedNetworkImage(imageUrl: message.mediaUrl),
                ),
              ),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: message.mediaUrl,
              width: 240,
              height: 180,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                width: 240,
                height: 180,
                color: isMe
                    ? AppColors.surface.withAlpha(30)
                    : AppColors.surface.withAlpha(60),
                child: const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.secondary,
                  ),
                ),
              ),
              errorWidget: (_, __, ___) => Container(
                width: 240,
                height: 180,
                color: AppColors.surface.withAlpha(40),
                child: const Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: AppColors.outline,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (message.text.trim().isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(message.text, style: TextStyle(color: _textColor, fontSize: 15)),
        ],
      ],
    );
  }

  Widget _buildVideo() {
    if (message.isViewOnce && message.viewOnceOpened) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isMe
              ? AppColors.surface.withAlpha(40)
              : AppColors.surface.withAlpha(60),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.visibility_off_outlined, size: 18, color: _hintColor),
            const SizedBox(width: 8),
            Text(
              'View once video (opened)',
              style: TextStyle(color: _hintColor, fontSize: 14),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isMe
            ? AppColors.surface.withAlpha(40)
            : AppColors.surface.withAlpha(60),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.play_circle_outline,
            color: isMe ? AppColors.surface : AppColors.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Text('Video', style: TextStyle(color: _textColor, fontSize: 14)),
          if (message.isViewOnce) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surface.withAlpha(140),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.visibility, size: 14, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    'View once',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDocument() {
    final name = message.fileName.isNotEmpty ? message.fileName : 'Document';
    return InkWell(
      onTap: message.mediaUrl.isEmpty
          ? null
          : () async {
              final uri = Uri.tryParse(message.mediaUrl);
              if (uri == null) return;
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isMe
              ? AppColors.surface.withAlpha(40)
              : AppColors.surface.withAlpha(60),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.insert_drive_file_outlined,
              color: isMe ? AppColors.surface : AppColors.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: _textColor, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Voice Message Bubble ───────────────────────────────────────

class _VoiceMessageBubble extends StatefulWidget {
  final String url;
  final bool isMe;
  const _VoiceMessageBubble({super.key, required this.url, required this.isMe});

  @override
  State<_VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<_VoiceMessageBubble>
    with SingleTickerProviderStateMixin {
  final _player = AudioPlayer();
  StreamSubscription<Duration?>? _durSub;
  StreamSubscription<Duration>? _posSub;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _loading = false;
  late AnimationController _waveCtrl;
  late List<double> _barHeights;

  @override
  void initState() {
    super.initState();
    _barHeights = List.generate(20, (_) => 4 + math.Random().nextDouble() * 16);
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _durSub = _player.durationStream.listen((d) {
      if (!mounted) return;
      setState(() => _duration = d ?? Duration.zero);
    });
    _posSub = _player.positionStream.listen((p) {
      if (!mounted) return;
      setState(() => _position = p);
    });
  }

  Future<void> _togglePlay() async {
    if (widget.url.isEmpty) return;
    if (_player.playing) {
      await _player.pause();
      _waveCtrl.stop();
      return;
    }
    if (_player.processingState == ProcessingState.idle) {
      setState(() => _loading = true);
      try {
        await _player.setUrl(widget.url);
        await _player.play();
        _waveCtrl.repeat();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not play audio: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    } else {
      await _player.play();
      _waveCtrl.repeat();
    }
  }

  String get _remaining {
    final remaining = _duration - _position;
    if (remaining.inSeconds < 0) return '0:00';
    final m = remaining.inMinutes.remainder(60);
    final s = remaining.inSeconds.remainder(60);
    return '${m.toString().padLeft(1, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _durSub?.cancel();
    _posSub?.cancel();
    _player.dispose();
    _waveCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playing = _player.playing;
    final accentColor = widget.isMe ? AppColors.surface : AppColors.secondary;
    final bgColor = widget.isMe
        ? AppColors.surface.withAlpha(30)
        : AppColors.surface.withAlpha(60);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: _loading
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: accentColor,
                    ),
                  )
                : Icon(
                    playing ? Icons.pause : Icons.play_arrow,
                    color: accentColor,
                  ),
            onPressed: _togglePlay,
          ),
          // Waveform bars
          SizedBox(
            height: 28,
            width: 80,
            child: AnimatedBuilder(
              animation: _waveCtrl,
              builder: (_, __) {
                final phase = _waveCtrl.value;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(_barHeights.length, (i) {
                    final h =
                        _barHeights[i] *
                        (playing
                            ? (0.6 +
                                  0.4 *
                                      math
                                          .sin(phase * math.pi * 2 + i * 0.5)
                                          .abs())
                            : 0.5);
                    return Container(
                      width: 2.5,
                      height: h.clamp(4.0, 24.0),
                      decoration: BoxDecoration(
                        color: accentColor.withAlpha(playing ? 220 : 120),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _remaining,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: accentColor.withAlpha(200),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Typing Indicator ───────────────────────────────────────────

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.secondary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            3,
            (i) => AnimatedBuilder(
              animation: _controller,
              builder: (_, __) {
                final phase = ((i / 3) + _controller.value) % 1.0;
                final height = 6 + math.sin(phase * math.pi * 2).abs() * 5;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2.5),
                  child: Container(
                    width: 7,
                    height: height.clamp(5.0, 12.0),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withAlpha(180),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Attach Item ────────────────────────────────────────────────

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
              color: color.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Message Actions Sheet ──────────────────────────────────────

class _MessageActionsSheet extends StatelessWidget {
  final MessageModel message;
  final String myId;
  final VoidCallback onReply, onCopy, onStar;
  final VoidCallback? onEdit;
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
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.outlineVariant,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children:
                [
                      '\u2764\uFE0F',
                      '\uD83D\uDE06',
                      '\uD83D\uDE02',
                      '\uD83D\uDE22',
                      '\uD83D\uDE0D',
                      '\uD83D\uDE0A',
                    ]
                    .map(
                      (e) => GestureDetector(
                        onTap: () => onReact(e),
                        child: Text(e, style: const TextStyle(fontSize: 28)),
                      ),
                    )
                    .toList(),
          ),
        ),
        Divider(height: 1, color: AppColors.outlineVariant.withAlpha(120)),
        ListTile(
          leading: const Icon(Icons.reply, color: AppColors.onSurfaceVariant),
          title: const Text(
            'Reply',
            style: TextStyle(color: AppColors.onSurface),
          ),
          onTap: onReply,
        ),
        if (onEdit != null)
          ListTile(
            leading: const Icon(Icons.edit, color: AppColors.onSurfaceVariant),
            title: const Text('Edit', style: TextStyle(color: AppColors.onSurface)),
            onTap: onEdit!,
          ),
        if (message.type == MessageType.text)
          ListTile(
            leading: const Icon(Icons.copy, color: AppColors.onSurfaceVariant),
            title: const Text(
              'Copy',
              style: TextStyle(color: AppColors.onSurface),
            ),
            onTap: onCopy,
          ),
        ListTile(
          leading: Icon(
            message.isStarred ? Icons.star : Icons.star_border,
            color: AppColors.onSurfaceVariant,
          ),
          title: Text(
            message.isStarred ? 'Unstar' : 'Star',
            style: const TextStyle(color: AppColors.onSurface),
          ),
          onTap: onStar,
        ),
        ListTile(
          leading: const Icon(Icons.forward, color: AppColors.onSurfaceVariant),
          title: const Text(
            'Forward',
            style: TextStyle(color: AppColors.onSurface),
          ),
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
        const SizedBox(height: 12),
      ],
    );
  }
}
