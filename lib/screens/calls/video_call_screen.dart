import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme.dart';

class VideoCallScreen extends StatefulWidget {
  final String callId;
  final bool isCaller;
  final String? remoteUserId;
  final String? remoteName;
  final String? remoteAvatar;

  const VideoCallScreen({
    super.key,
    required this.callId,
    this.isCaller = false,
    this.remoteUserId,
    this.remoteName,
    this.remoteAvatar,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  bool _isMuted = false;
  bool _isCameraOn = true;
  bool _showChat = false;
  bool _connected = false;
  int _seconds = 0;
  Timer? _timer;
  Offset _localPosition = const Offset(20, 100);

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_connected) setState(() => _seconds++);
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _connected = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _endCall() {
    _timer?.cancel();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1A14),
      body: Stack(
        children: [
          Center(
            child: _connected
                ? Container(color: const Color(0xFF1A3A2F), child: const Center(child: Icon(Icons.videocam, size: 80, color: Colors.white12)))
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: AppColors.accentLight,
                        child: Text(
                          (widget.remoteName ?? '?')[0].toUpperCase(),
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.accent),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(widget.remoteName ?? 'Connecting...', style: AppText.callName.copyWith(fontSize: 18)),
                      const SizedBox(height: 8),
                      const Text('Connecting...', style: TextStyle(color: Colors.white54, fontSize: 13)),
                    ],
                  ),
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black54, Colors.transparent]),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.accent,
                    child: Text((widget.remoteName ?? '?')[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(width: 8),
                  Text(widget.remoteName ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                  const Spacer(),
                  Text(
                    '${(_seconds ~/ 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Segoe UI'),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            right: 20,
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() => _localPosition += details.delta);
              },
              child: Container(
                width: 120,
                height: 160,
                decoration: BoxDecoration(
                  color: const Color(0xFF2D4A3E),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white30, width: 1.5),
                ),
                child: Center(
                  child: _isCameraOn
                      ? const Icon(Icons.person, size: 48, color: Colors.white24)
                      : const Icon(Icons.videocam_off, size: 32, color: Colors.white38),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
              decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black87, Colors.transparent]),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _vcallBtn(Icons.mic, _isMuted ? Icons.mic_off : Icons.mic, _isMuted, () {
                    setState(() => _isMuted = !_isMuted);
                  }),
                  const SizedBox(width: 16),
                  _vcallBtn(Icons.videocam, _isCameraOn ? Icons.videocam : Icons.videocam_off, !_isCameraOn, () {
                    setState(() => _isCameraOn = !_isCameraOn);
                  }),
                  const SizedBox(width: 16),
                  _vcallBtn(Icons.flip_camera_android, Icons.flip_camera_android, false, () {}),
                  const SizedBox(width: 16),
                  _vcallEndBtn(),
                  const SizedBox(width: 16),
                  _vcallBtn(Icons.chat_bubble_outline, Icons.chat_bubble_outline, false, () {
                    setState(() => _showChat = !_showChat);
                  }),
                ],
              ),
            ),
          ),
          if (_showChat) _buildInCallChat(),
        ],
      ),
    );
  }

  Widget _vcallBtn(IconData icon, IconData activeIcon, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), shape: BoxShape.circle),
        child: Icon(isActive ? activeIcon : icon, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _vcallEndBtn() {
    return GestureDetector(
      onTap: _endCall,
      child: Container(
        width: 60,
        height: 60,
        decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
        child: const Icon(Icons.call_end, color: Colors.white, size: 24),
      ),
    );
  }

  Widget _buildInCallChat() {
    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      width: MediaQuery.of(context).size.width * 0.4,
      child: Container(
        color: Colors.black87,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Colors.white12))),
              child: Row(
                children: [
                  const Text('In-call Chat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 18),
                    onPressed: () => setState(() => _showChat = false),
                  ),
                ],
              ),
            ),
            const Expanded(child: Center(child: Text('Chat messages', style: TextStyle(color: Colors.white38)))),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: Colors.white12))),
              child: Row(
                children: [
                  const Expanded(
                    child: TextField(
                      style: TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: TextStyle(color: Colors.white38, fontSize: 13),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: AppColors.accent, size: 18),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
