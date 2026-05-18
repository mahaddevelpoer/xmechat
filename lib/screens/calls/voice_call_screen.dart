import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/common/user_avatar.dart';

class VoiceCallScreen extends ConsumerStatefulWidget {
  final String callId;
  final bool isCaller;
  final UserModel? otherUser;
  const VoiceCallScreen({super.key, required this.callId, required this.isCaller, this.otherUser});
  @override
  ConsumerState<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends ConsumerState<VoiceCallScreen> {
  bool _muted = false, _speaker = false, _connected = false;
  int _seconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final webrtc = ref.read(webrtcServiceProvider);
    webrtc.onCallConnected = () { if (mounted) { setState(() => _connected = true); _startTimer(); } };
    webrtc.onCallEnded = () { if (mounted) context.pop(); };
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  String get _callDuration {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryGreen,
      body: SafeArea(
        child: Column(children: [
          const SizedBox(height: 60),
          UserAvatar(url: widget.otherUser?.avatarUrl, name: widget.otherUser?.name ?? '?', radius: 55),
          const SizedBox(height: 24),
          Text(widget.otherUser?.name ?? 'Unknown',
            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(_connected ? _callDuration : 'Ringing...',
            style: const TextStyle(color: Colors.white70, fontSize: 16)),
          const Spacer(),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _VoiceBtn(
              icon: _muted ? Icons.mic_off : Icons.mic,
              label: _muted ? 'Unmute' : 'Mute',
              onTap: () { ref.read(webrtcServiceProvider).toggleMute(!_muted); setState(() => _muted = !_muted); },
            ),
            _VoiceBtn(
              icon: Icons.call_end, label: 'End',
              bg: AppColors.error, size: 65,
              onTap: () async { await ref.read(webrtcServiceProvider).endCall(); if (!mounted) return; context.pop(); },
            ),
            _VoiceBtn(
              icon: _speaker ? Icons.volume_up : Icons.volume_down,
              label: _speaker ? 'Speaker' : 'Earpiece',
              onTap: () async {
                await ref.read(webrtcServiceProvider).toggleSpeaker(!_speaker);
                setState(() => _speaker = !_speaker);
              },
            ),
          ]),
          const SizedBox(height: 60),
        ]),
      ),
    );
  }
}

class _VoiceBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bg;
  final double size;
  final VoidCallback onTap;
  const _VoiceBtn({required this.icon, required this.label, required this.onTap,
    this.bg = Colors.white24, this.size = 55});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: size, height: size,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: size * 0.45),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ]),
    );
  }
}
