import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  Timer? _timer;
  final _replyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _progressCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 5));
    _startProgress();
    _markViewed();
  }

  void _startProgress() {
    _progressCtrl.reset();
    _progressCtrl.forward().then((_) => _next());
  }

  void _markViewed() async {
    if (_currentIndex < widget.statuses.length) {
      await ref.read(statusServiceProvider).markViewed(widget.statuses[_currentIndex].id);
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
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.statuses.isEmpty) {
      return const Scaffold(body: Center(child: Text('No statuses')));
    }
    final status = widget.statuses[_currentIndex];
    final user = status.user;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (d) {
          final x = d.globalPosition.dx;
          final width = MediaQuery.of(context).size.width;
          if (x < width / 3) _prev() ; else _next();
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
                    Text(user?.name ?? 'Unknown',
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
          // Bottom reply
          Positioned(bottom: 0, left: 0, right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
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
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                      onTap: () => _progressCtrl.stop(),
                      onSubmitted: (_) { _progressCtrl.forward(); _replyCtrl.clear(); },
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {},
                    child: const Icon(Icons.thumb_up_outlined, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {},
                    child: const Icon(Icons.send, color: Colors.white, size: 28),
                  ),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildContent(StatusModel status) {
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
