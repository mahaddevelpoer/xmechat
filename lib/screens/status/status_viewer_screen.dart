import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';
import '../../core/constants/app_colors.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';

class StatusViewerScreen extends ConsumerStatefulWidget {
  final String userId;
  final List<StatusModel> statuses;
  const StatusViewerScreen({super.key, required this.userId, required this.statuses});
  @override
  ConsumerState<StatusViewerScreen> createState() => _StatusViewerScreenState();
}

class _StatusViewerScreenState extends ConsumerState<StatusViewerScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _progressCtrl;
  final _replyCtrl = TextEditingController();
  VideoPlayerController? _videoCtrl;
  bool _isVideoLoading = false;

  @override
  void initState() {
    super.initState();
    _progressCtrl = AnimationController(vsync: this);
    _startProgress();
    _markViewed();
  }

  void _startProgress() async {
    _progressCtrl.stop();
    _progressCtrl.reset();

    // Safely dispose the old video player controller
    if (_videoCtrl != null) {
      final oldCtrl = _videoCtrl!;
      _videoCtrl = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        oldCtrl.dispose();
      });
    }

    if (_currentIndex >= widget.statuses.length) return;
    final status = widget.statuses[_currentIndex];

    if (status.type == 'video' && status.contentUrl.isNotEmpty) {
      setState(() {
        _isVideoLoading = true;
      });
      try {
        final controller = VideoPlayerController.networkUrl(Uri.parse(status.contentUrl));
        _videoCtrl = controller;
        await controller.initialize();
        if (!mounted || _videoCtrl != controller) {
          controller.dispose();
          return;
        }
        setState(() {
          _isVideoLoading = false;
        });
        _progressCtrl.duration = controller.value.duration;
        controller.play();
        _progressCtrl.forward().then((_) {
          if (mounted && _videoCtrl == controller) {
            _next();
          }
        });
      } catch (e) {
        debugPrint('Error loading video status: $e');
        if (mounted) {
          setState(() {
            _isVideoLoading = false;
          });
          _progressCtrl.duration = const Duration(seconds: 5);
          _progressCtrl.forward().then((_) => _next());
        }
      }
    } else {
      _progressCtrl.duration = const Duration(seconds: 5);
      _progressCtrl.forward().then((_) => _next());
    }
  }

  void _markViewed() async {
    if (_currentIndex < widget.statuses.length) {
      final status = widget.statuses[_currentIndex];
      final myId = ref.read(authServiceProvider).currentUserId;
      if (status.userId == myId) return; // don't mark self-status as viewed
      await ref.read(statusServiceProvider).markViewed(status.id);
      // Refresh list so ring color can update without manual refresh.
      unawaited(ref.refresh(statusesProvider.future));
    }
  }

  void _next() {
    if (_currentIndex < widget.statuses.length - 1) {
      setState(() => _currentIndex++);
      _startProgress();
      _markViewed();
    } else {
      Navigator.pop(context);
    }
  }

  void _prev() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _startProgress();
    }
  }

  @override
  void dispose() {
    _progressCtrl.dispose();
    _replyCtrl.dispose();
    _videoCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.statuses.isEmpty) {
      return const Scaffold(body: Center(child: Text('No statuses')));
    }
    final status = widget.statuses[_currentIndex];
    final myId = ref.read(authServiceProvider).currentUserId;
    final isMine = status.userId == myId;
    final user = isMine ? ref.watch(currentUserProvider).valueOrNull : status.user;
    final displayName = isMine ? (user?.name.isNotEmpty == true ? user!.name : 'Me') : (user?.name ?? 'Unknown');

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (d) {
          final x = d.globalPosition.dx;
          final width = MediaQuery.of(context).size.width;
          if (x < width / 3) {
            _prev();
          } else {
            _next();
          }
        },
        child: Stack(children: [
          // Content
          Positioned.fill(child: _buildContent(status)),
          // Top bar
          Positioned(top: 0, left: 0, right: 0,
            child: SafeArea(child: Column(children: [
              // Progress bars
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  children: List.generate(widget.statuses.length, (i) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: i < _currentIndex
                            ? Container(height: 3, color: Colors.white)
                            : i == _currentIndex
                              ? AnimatedBuilder(
                                  animation: _progressCtrl,
                                  builder: (_, __) => LinearProgressIndicator(
                                    value: _progressCtrl.value,
                                    backgroundColor: Colors.white38,
                                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                                    minHeight: 3,
                                  ),
                                )
                              : Container(height: 3, color: Colors.white38),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              // User row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: user?.avatarUrl.isNotEmpty == true
                      ? NetworkImage(user!.avatarUrl) : null,
                    child: user?.avatarUrl.isEmpty != false
                      ? const Icon(Icons.person, color: Colors.white) : null,
                  ),
                  const SizedBox(width: 10),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(displayName,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    Text(_timeAgo(status.createdAt),
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ]),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ]),
              ),
            ])),
          ),
          // Bottom area (reply OR viewers)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: isMine ? _mineBottomBar(status) : _replyBar(status, user),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _mineBottomBar(StatusModel status) {
    final viewsCount = status.views.length;
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _openViewers(status),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.remove_red_eye_outlined,
                      color: Colors.white, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    '$viewsCount seen',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.white),
          onPressed: () => _confirmDelete(status),
        ),
      ],
    );
  }

  Widget _replyBar(StatusModel status, UserModel? user) {
    return Row(children: [
      Expanded(
        child: TextField(
          controller: _replyCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Reply to status...',
            hintStyle: const TextStyle(color: Colors.white60),
            filled: true,
            fillColor: Colors.white24,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(25),
              borderSide: BorderSide.none,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          onTap: () {
            _progressCtrl.stop();
            _videoCtrl?.pause();
          },
          onSubmitted: (_) => _sendReply(status, user),
        ),
      ),
      const SizedBox(width: 8),
      GestureDetector(
        onTap: () => _sendReply(status, user),
        child: const Icon(Icons.send, color: Colors.white, size: 28),
      ),
    ]);
  }

  Future<void> _sendReply(StatusModel status, UserModel? user) async {
    final reply = _replyCtrl.text.trim();
    if (reply.isEmpty) return;
    final myId = ref.read(authServiceProvider).currentUserId;
    if (status.userId == myId) return;

    _progressCtrl.stop();
    _videoCtrl?.pause();
    _replyCtrl.clear();

    final chatSvc = ref.read(chatServiceProvider);
    final receiverId = status.userId;
    final otherUser = user ?? await chatSvc.getUserById(receiverId);
    final chatId = await chatSvc.getOrCreateChat(receiverId);
    final preview = status.type == 'image'
        ? '📷 Status photo'
        : (status.type == 'video' ? '🎥 Status video' : (status.text.isNotEmpty ? status.text : 'Status'));
    final text = '↩️ $preview\n$reply';

    await chatSvc.sendTextMessage(chatId: chatId, receiverId: receiverId, text: text);
    if (!mounted) return;

    // Open private chat screen (as requested).
    context.pushReplacement('/chat/$chatId', extra: {'user': otherUser});
  }

  void _openViewers(StatusModel status) async {
    _progressCtrl.stop();
    _videoCtrl?.pause();

    final views = status.views;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text('Seen by',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  Text('${views.length}',
                      style: const TextStyle(color: AppColors.textSecondary)),
                ],
              ),
              const SizedBox(height: 10),
              if (views.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text('No views yet',
                      style: TextStyle(color: AppColors.textSecondary)),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: views.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final v = views[i];
                      final u = v.viewer;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.bgSecondary,
                          backgroundImage: u?.avatarUrl.isNotEmpty == true
                              ? NetworkImage(u!.avatarUrl)
                              : null,
                          child: u?.avatarUrl.isEmpty != false
                              ? Text(
                                  (u?.name.isNotEmpty == true
                                          ? u!.name.trim()[0]
                                          : '?')
                                      .toUpperCase(),
                                  style: const TextStyle(
                                      color: AppColors.textPrimary),
                                )
                              : null,
                        ),
                        title: Text(u?.name ?? v.viewerId),
                        subtitle: Text(_timeAgo(v.viewedAt),
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 12)),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (mounted) {
      _videoCtrl?.play();
      _progressCtrl.forward();
    }
  }

  Future<void> _confirmDelete(StatusModel status) async {
    _progressCtrl.stop();
    _videoCtrl?.pause();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete status?'),
        content: const Text('This will remove the status for everyone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(statusServiceProvider).deleteStatus(status.id);
      await Future.wait([
        ref.refresh(myStatusesProvider.future),
        ref.refresh(statusesProvider.future),
      ]);
      if (!mounted) return;
      Navigator.pop(context);
    } else {
      if (mounted) {
        _videoCtrl?.play();
        _progressCtrl.forward();
      }
    }
  }

  Widget _buildContent(StatusModel status) {
    if (status.type == 'video' && status.contentUrl.isNotEmpty) {
      if (_isVideoLoading) {
        return const Center(child: CircularProgressIndicator(color: Colors.white));
      }
      if (_videoCtrl != null && _videoCtrl!.value.isInitialized) {
        return Center(
          child: AspectRatio(
            aspectRatio: _videoCtrl!.value.aspectRatio,
            child: VideoPlayer(_videoCtrl!),
          ),
        );
      }
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (status.type == 'image' && status.contentUrl.isNotEmpty) {
      return Image.network(status.contentUrl, fit: BoxFit.cover,
        loadingBuilder: (_, child, prog) =>
          prog == null ? child : const Center(child: CircularProgressIndicator()));
    }

    // Text status
    return Container(
      color: _hexToColor(status.bgColor),
      child: Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(status.text,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
      )),
    );
  }

  Color _hexToColor(String hex) {
    try {
      return Color(int.parse(hex.replaceAll('#', '0xFF')));
    } catch (_) { return AppColors.primaryGreen; }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}
