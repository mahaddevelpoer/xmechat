import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme.dart';

class VoiceCallScreen extends StatefulWidget {
  final String callId;
  final bool isCaller;
  final String? remoteUserId;
  final String? remoteName;
  final String? remoteAvatar;

  const VoiceCallScreen({
    super.key,
    required this.callId,
    this.isCaller = false,
    this.remoteUserId,
    this.remoteName,
    this.remoteAvatar,
  });

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> {
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _connected = false;
  bool _showChat = false;
  int _seconds = 0;
  Timer? _timer;

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
      backgroundColor: AppColors.callBg,
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: AppColors.accentLight,
                  child: Text(
                    (widget.remoteName ?? '?')[0].toUpperCase(),
                    style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w700, color: AppColors.accent),
                  ),
                ),
                const SizedBox(height: 20),
                Text(widget.remoteName ?? 'Connecting...', style: AppText.callName),
                const SizedBox(height: 8),
                Text(
                  _connected ? 'Connected' : 'Calling...',
                  style: AppText.timestamp.copyWith(color: Colors.white54, fontSize: 14),
                ),
                if (_connected) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${(_seconds ~/ 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')}',
                    style: AppText.callTimer,
                  ),
                ],
                const SizedBox(height: 60),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _callControl(Icons.mic, _isMuted ? Icons.mic_off : Icons.mic, 'Mute', _isMuted ? Colors.red : Colors.white24, _isMuted, () {
                      setState(() => _isMuted = !_isMuted);
                    }),
                    const SizedBox(width: 20),
                    _callControl(Icons.volume_up, _isSpeakerOn ? Icons.volume_up : Icons.hearing, 'Speaker', Colors.white24, false, () {
                      setState(() => _isSpeakerOn = !_isSpeakerOn);
                    }),
                    const SizedBox(width: 20),
                    _endButton(),
                    const SizedBox(width: 20),
                    _callControl(Icons.chat_bubble_outline, Icons.chat_bubble_outline, 'Chat', Colors.white24, false, () {
                      setState(() => _showChat = !_showChat);
                    }),
                  ],
                ),
              ],
            ),
          ),
          if (_showChat) _buildInCallChat(),
        ],
      ),
    );
  }

  Widget _callControl(IconData icon, IconData activeIcon, String label, Color bgColor, bool isActive, VoidCallback onTap) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Icon(isActive ? activeIcon : icon, color: Colors.white, size: 24),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );
  }

  Widget _endButton() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _endCall,
          child: Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
            child: const Icon(Icons.call_end, color: Colors.white, size: 28),
          ),
        ),
        const SizedBox(height: 4),
        const Text('End', style: TextStyle(color: Colors.white70, fontSize: 11)),
      ],
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
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.white12)),
              ),
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
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Colors.white12)),
              ),
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
                  const SizedBox(width: 8),
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
