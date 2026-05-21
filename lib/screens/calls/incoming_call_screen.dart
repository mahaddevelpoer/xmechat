import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class IncomingCallScreen extends ConsumerStatefulWidget {
  final CallModel call;
  const IncomingCallScreen({super.key, required this.call});

  @override
  ConsumerState<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends ConsumerState<IncomingCallScreen> {
  Timer? _autoDeclineTimer;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    _playRingtone();
    _autoDeclineTimer = Timer(const Duration(seconds: 30), () async {
      if (_handled) return;
      _handled = true;
      try {
        await ref.read(webrtcServiceProvider).missCall(widget.call.id);
      } finally {
        if (mounted) Navigator.pop(context);
      }
    });
  }

  Future<void> _playRingtone() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ringtonePath = prefs.getString('ringtone_path');
      await _audioPlayer.setLoopMode(LoopMode.one);
      if (ringtonePath != null && ringtonePath.isNotEmpty) {
        if (ringtonePath.startsWith('http')) {
          await _audioPlayer.setUrl(ringtonePath);
        } else {
          await _audioPlayer.setFilePath(ringtonePath);
        }
      } else {
        await _audioPlayer.setUrl('https://actions.google.com/sounds/v1/alarms/phone_alerts_and_rings_01.ogg');
      }
      await _audioPlayer.play();
    } catch (_) {}
  }

  @override
  void dispose() {
    _autoDeclineTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _decline() async {
    if (_handled) return;
    _handled = true;
    _autoDeclineTimer?.cancel();
    _audioPlayer.stop();
    await ref.read(webrtcServiceProvider).rejectCall(widget.call.id);
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _accept(UserModel? caller, bool isVideo) async {
    if (_handled) return;
    _handled = true;
    _autoDeclineTimer?.cancel();
    _audioPlayer.stop();
    await ref.read(webrtcServiceProvider).answerCall(
      widget.call.id,
      widget.call.sdpOffer,
      isVideo: isVideo,
    );
    if (!mounted) return;
    Navigator.pop(context);
    final route = isVideo ? '/video-call/${widget.call.id}' : '/voice-call/${widget.call.id}';
    context.push(route, extra: {'isCaller': false, 'user': caller});
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.call.type == CallType.video;
    return Scaffold(
      backgroundColor: const Color(0xFF075E54),
      body: SafeArea(
        child: FutureBuilder<UserModel?>(
          future: ref.read(chatServiceProvider).getUserById(widget.call.callerId),
          builder: (_, snap) {
            final caller = snap.data;
            return Column(children: [
              const SizedBox(height: 60),
              Icon(
                isVideo ? Icons.videocam : Icons.phone_in_talk,
                size: 32,
                color: Colors.white54,
              ),
              const SizedBox(height: 12),
              Text(
                isVideo ? 'Incoming Video Call' : 'Incoming Voice Call',
                style: const TextStyle(color: Colors.white60, fontSize: 16),
              ),
              const SizedBox(height: 40),
              CircleAvatar(
                radius: 65,
                backgroundColor: Colors.white24,
                backgroundImage: caller?.avatarUrl.isNotEmpty == true
                    ? NetworkImage(caller!.avatarUrl)
                    : null,
                child: caller?.avatarUrl.isEmpty != false
                    ? const Icon(Icons.person, size: 65, color: Colors.white)
                    : null,
              ),
              const SizedBox(height: 28),
              Text(
                caller?.name ?? 'Unknown',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 60),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Decline
                    GestureDetector(
                      onTap: _decline,
                      child: Column(children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.call_end, color: Colors.white, size: 32),
                        ),
                        const SizedBox(height: 10),
                        const Text('Decline',
                            style: TextStyle(color: Colors.white70, fontSize: 14)),
                      ]),
                    ),
                    // Accept
                    GestureDetector(
                      onTap: () => _accept(caller, isVideo),
                      child: Column(children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: const BoxDecoration(
                            color: AppColors.accentGreen,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(isVideo ? Icons.videocam : Icons.call,
                              color: Colors.white, size: 32),
                        ),
                        const SizedBox(height: 10),
                        const Text('Accept',
                            style: TextStyle(color: Colors.white70, fontSize: 14)),
                      ]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 60),
            ]);
          },
        ),
      ),
    );
  }
}
