import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import '../../core/constants/app_colors.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/common/user_avatar.dart';

class ChatInfoScreen extends ConsumerStatefulWidget {
  final String chatId;
  const ChatInfoScreen({super.key, required this.chatId});

  @override
  ConsumerState<ChatInfoScreen> createState() => _ChatInfoScreenState();
}

class _ChatInfoScreenState extends ConsumerState<ChatInfoScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  UserModel? _otherUser;
  List<MessageModel> _messages = [];
  bool _loading = true;
  int _disappearTimer = 0;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final chatService = ref.read(chatServiceProvider);
    final msgs = await chatService.fetchMessages(widget.chatId, limit: 500);
    final chats = await chatService.fetchChats();
    final chat = chats.firstWhere(
      (c) => c.id == widget.chatId,
      orElse: () => ChatModel(
          id: '', user1Id: '', user2Id: '',
          lastMessageAt: DateTime.now(), createdAt: DateTime.now()),
    );
    final myId = ref.read(authServiceProvider).currentUserId;
    final otherId = chat.getOtherUserId(myId);
    final user = await chatService.getUserById(otherId);

    if (!mounted) return;
    final starred = await ref.read(chatServiceProvider).fetchStarredMessages(widget.chatId);
    if (!mounted) return;
    setState(() {
      _otherUser = user;
      _messages = msgs;
      _starredMessages = starred;
      _loading = false;
      _disappearTimer = chat.disappearTimer;
    });
  }

  List<MessageModel> get _mediaMessages => _messages
      .where((m) => m.type == MessageType.image || m.type == MessageType.video)
      .toList();

  List<MessageModel> get _docMessages =>
      _messages.where((m) => m.type == MessageType.document).toList();

  List<MessageModel> get _linkMessages => _messages
      .where((m) =>
          m.type == MessageType.text &&
          (m.text.contains('http://') || m.text.contains('https://')))
      .toList();

  List<MessageModel> _starredMessages = [];

  Future<void> _setDisappearTimer(int seconds) async {
    final supabase = Supabase.instance.client;
    await supabase.from('conversations')
        .update({'disappear_timer': seconds}).eq('id', widget.chatId);
    if (!mounted) return;
    setState(() => _disappearTimer = seconds);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(seconds == 0
              ? 'Disappearing messages off'
              : 'Messages will disappear after ${_formatTimer(seconds)}'),
          backgroundColor: AppColors.primaryGreen,
        ),
      );
    }
  }

  String _formatTimer(int seconds) {
    if (seconds <= 0) return 'Off';
    if (seconds == 86400) return '24 hours';
    if (seconds == 604800) return '7 days';
    if (seconds == 2592000) return '90 days';
    return '$seconds sec';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: AppColors.primaryGreen)));
    }

    return Scaffold(
      backgroundColor: AppColors.bgSecondary,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, inner) => [
          SliverAppBar(
            pinned: true,
            expandedHeight: 220,
            backgroundColor: AppColors.bgSecondary,
            foregroundColor: AppColors.textPrimary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: Colors.white,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 60),
                    UserAvatar(
                        url: _otherUser?.avatarUrl,
                        name: _otherUser?.name ?? '?',
                        radius: 44),
                    const SizedBox(height: 12),
                    Text(_otherUser?.name ?? '',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    Text(
                      _otherUser?.isOnline == true ? 'Online' : 'Offline',
                      style: TextStyle(
                          fontSize: 13,
                          color: _otherUser?.isOnline == true
                              ? AppColors.primaryGreen
                              : AppColors.textHint),
                    ),
                  ],
                ),
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tabCtrl,
                  indicatorColor: AppColors.primaryGreen,
                  labelColor: AppColors.primaryGreen,
                  unselectedLabelColor: AppColors.textHint,
                  tabs: const [
                    Tab(text: 'Media'),
                    Tab(text: 'Docs'),
                    Tab(text: 'Links'),
                    Tab(text: 'Starred'),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: Column(children: [
          Container(
            color: Colors.white,
            child: ListTile(
              leading: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withAlpha(20),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.timer_outlined,
                    color: AppColors.primaryGreen, size: 22),
              ),
              title: const Text('Disappearing messages',
                  style: TextStyle(fontWeight: FontWeight.w500)),
              subtitle: Text(_formatTimer(_disappearTimer),
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showDisappearPicker(),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildMediaGrid(),
                _buildDocsList(),
                _buildLinksList(),
                _buildStarredList(),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  void _showDisappearPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Disappearing messages',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Messages will disappear from this chat after the selected duration.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 16),
            _TimerOption(label: 'Off', seconds: 0, selected: _disappearTimer == 0, onTap: () {
              Navigator.pop(context); _setDisappearTimer(0);
            }),
            _TimerOption(label: '24 hours', seconds: 86400, selected: _disappearTimer == 86400, onTap: () {
              Navigator.pop(context); _setDisappearTimer(86400);
            }),
            _TimerOption(label: '7 days', seconds: 604800, selected: _disappearTimer == 604800, onTap: () {
              Navigator.pop(context); _setDisappearTimer(604800);
            }),
            _TimerOption(label: '90 days', seconds: 2592000, selected: _disappearTimer == 2592000, onTap: () {
              Navigator.pop(context); _setDisappearTimer(2592000);
            }),
          ]),
        ),
      ),
    );
  }

  Widget _buildMediaGrid() {
    if (_mediaMessages.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.photo_library_outlined, size: 60, color: AppColors.textHint),
            SizedBox(height: 12),
            Text('No media yet', style: TextStyle(color: AppColors.textHint)),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: _mediaMessages.length,
      itemBuilder: (ctx, i) {
        final msg = _mediaMessages[i];
        return GestureDetector(
          onTap: () => _openFullScreen(msg),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: msg.mediaUrl,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(color: AppColors.bgSecondary),
                errorWidget: (_, __, ___) => Container(
                    color: AppColors.bgSecondary,
                    child: const Icon(Icons.broken_image_outlined, color: AppColors.textHint)),
              ),
              if (msg.type == MessageType.video)
                const Center(
                    child: Icon(Icons.play_circle_fill,
                        color: Colors.white, size: 36)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDocsList() {
    if (_docMessages.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_outlined, size: 60, color: AppColors.textHint),
            SizedBox(height: 12),
            Text('No documents yet', style: TextStyle(color: AppColors.textHint)),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: _docMessages.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
      itemBuilder: (ctx, i) {
        final msg = _docMessages[i];
        final ext = msg.mediaUrl.split('.').last.toLowerCase();
        return ListTile(
          leading: Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
                color: AppColors.bgSecondary,
                borderRadius: BorderRadius.circular(8)),
            child: Center(
              child: Text(ext.toUpperCase(),
                  style: const TextStyle(
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.bold,
                      fontSize: 12)),
            ),
          ),
          title: Text(msg.fileName.isNotEmpty ? msg.fileName : 'Document',
              style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: Text(
            '${(msg.fileSize / 1024).toStringAsFixed(1)} KB • '
            '${_formatDate(msg.createdAt)}',
            style: const TextStyle(fontSize: 12, color: AppColors.textHint),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.download_outlined, color: AppColors.primaryGreen),
            onPressed: () => _openUrl(msg.mediaUrl),
          ),
          onTap: () => _openUrl(msg.mediaUrl),
        );
      },
    );
  }

  Widget _buildLinksList() {
    if (_linkMessages.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.link_outlined, size: 60, color: AppColors.textHint),
            SizedBox(height: 12),
            Text('No links yet', style: TextStyle(color: AppColors.textHint)),
          ],
        ),
      );
    }

    final urlRegex = RegExp(r'https?://[^\s]+');

    return ListView.separated(
      itemCount: _linkMessages.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
      itemBuilder: (ctx, i) {
        final msg = _linkMessages[i];
        final match = urlRegex.firstMatch(msg.text);
        final url = match?.group(0) ?? msg.text;
        return ListTile(
          leading: Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
                color: AppColors.sentBubble,
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.link, color: AppColors.primaryGreen),
          ),
          title: Text(url,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: AppColors.primaryGreen,
                  decoration: TextDecoration.underline,
                  fontSize: 13)),
          subtitle: Text(_formatDate(msg.createdAt),
              style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
          onTap: () => _openUrl(url),
        );
      },
    );
  }

  Widget _buildStarredList() {
    if (_starredMessages.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_outline, size: 60, color: AppColors.textHint),
            SizedBox(height: 12),
            Text('No starred messages', style: TextStyle(color: AppColors.textHint)),
          ],
        ),
      );
    }
    return ListView.separated(
      itemCount: _starredMessages.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
      itemBuilder: (ctx, i) {
        final msg = _starredMessages[i];
        return ListTile(
          leading: Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
                color: AppColors.sentBubble,
                borderRadius: BorderRadius.circular(8)),
            child: Icon(
              msg.type == MessageType.image
                  ? Icons.image
                  : msg.type == MessageType.video
                      ? Icons.videocam
                      : msg.type == MessageType.document
                          ? Icons.description
                          : Icons.message,
              color: AppColors.primaryGreen,
            ),
          ),
          title: Text(
            msg.type == MessageType.text
                ? msg.text
                : msg.fileName.isNotEmpty
                    ? msg.fileName
                    : msg.type.name,
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            _formatDate(msg.createdAt),
            style: const TextStyle(fontSize: 12, color: AppColors.textHint),
          ),
          onTap: msg.type == MessageType.image || msg.type == MessageType.video
              ? () => _openFullScreen(msg)
              : null,
        );
      },
    );
  }

  void _openFullScreen(MessageModel msg) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FullScreenMedia(url: msg.mediaUrl, isVideo: msg.type == MessageType.video),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'Today ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _TimerOption extends StatelessWidget {
  final String label;
  final int seconds;
  final bool selected;
  final VoidCallback onTap;
  const _TimerOption({required this.label, required this.seconds, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label, style: TextStyle(
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          color: selected ? AppColors.primaryGreen : AppColors.textPrimary)),
      trailing: selected
          ? const Icon(Icons.check_circle, color: AppColors.primaryGreen)
          : null,
      onTap: onTap,
    );
  }
}

class _FullScreenMedia extends StatefulWidget {
  final String url;
  final bool isVideo;
  const _FullScreenMedia({required this.url, required this.isVideo});

  @override
  State<_FullScreenMedia> createState() => _FullScreenMediaState();
}

class _FullScreenMediaState extends State<_FullScreenMedia> {
  VideoPlayerController? _videoCtrl;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      _videoCtrl = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      _videoCtrl!.initialize().then((_) {
        if (mounted) {
          _videoCtrl!.play();
          setState(() {});
        }
      });
    }
  }

  @override
  void dispose() {
    _videoCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined, color: Colors.white),
            onPressed: () async {
              final uri = Uri.tryParse(widget.url);
              if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
          ),
        ],
      ),
      body: Center(
        child: widget.isVideo
            ? (_videoCtrl != null && _videoCtrl!.value.isInitialized
                ? GestureDetector(
                    onTap: () {
                      if (_videoCtrl!.value.isPlaying) {
                        _videoCtrl!.pause();
                      } else {
                        _videoCtrl!.play();
                      }
                      setState(() {});
                    },
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: _videoCtrl!.value.aspectRatio,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            VideoPlayer(_videoCtrl!),
                            if (!_videoCtrl!.value.isPlaying)
                              const Icon(Icons.play_circle_fill, color: Colors.white, size: 80),
                          ],
                        ),
                      ),
                    ),
                  )
                : const CircularProgressIndicator(color: Colors.white))
            : InteractiveViewer(
                child: CachedNetworkImage(
                  imageUrl: widget.url,
                  fit: BoxFit.contain,
                  placeholder: (_, __) => const CircularProgressIndicator(color: Colors.white),
                  errorWidget: (_, __, ___) => const Icon(Icons.broken_image, color: Colors.white, size: 60),
                ),
              ),
      ),
    );
  }
}
