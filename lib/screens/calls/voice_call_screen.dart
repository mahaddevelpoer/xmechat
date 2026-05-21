import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/common/user_avatar.dart';

class VoiceCallScreen extends ConsumerStatefulWidget {
  final String callId;
  final bool isCaller;
  final UserModel? otherUser;
  const VoiceCallScreen({
    super.key,
    required this.callId,
    required this.isCaller,
    this.otherUser,
  });
  @override
  ConsumerState<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends ConsumerState<VoiceCallScreen> {
  bool _muted = false, _speaker = false, _connected = false;
  int _seconds = 0;
  Timer? _timer;
  final _chatCtrl = TextEditingController();
  final List<String> _chatMessages = [];
  StreamSubscription<String>? _chatSub;

  @override
  void initState() {
    super.initState();
    final webrtc = ref.read(webrtcServiceProvider);
    webrtc.onCallConnected = () {
      if (mounted) {
        setState(() => _connected = true);
        _startTimer();
      }
    };
    webrtc.onCallEnded = () {
      if (mounted) Navigator.pop(context);
    };
    if (webrtc.isConnected || !widget.isCaller) {
      _connected = true;
      _startTimer();
    }
    _chatSub = webrtc.dataMessages.listen((m) {
      if (!mounted) return;
      setState(() => _chatMessages.add(m));
    });
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
  void dispose() {
    _timer?.cancel();
    _chatSub?.cancel();
    _chatCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusText = _connected
        ? _callDuration
        : (widget.isCaller ? 'Calling...' : 'Ringing...');
    return Scaffold(
      backgroundColor: AppColors.primaryGreen,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),
            UserAvatar(
              url: widget.otherUser?.avatarUrl,
              name: widget.otherUser?.name ?? '?',
              radius: 55,
            ),
            const SizedBox(height: 24),
            Text(
              widget.otherUser?.name ?? 'Unknown',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              statusText,
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            if (!_connected && widget.isCaller) ...[
              const SizedBox(height: 14),
              TextButton.icon(
                onPressed: () async {
                  await ref.read(webrtcServiceProvider).endCall();
                  if (!context.mounted) return;
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.close, color: Colors.white70),
                label: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _VoiceBtn(
                  icon: _muted ? Icons.mic_off : Icons.mic,
                  label: _muted ? 'Unmute' : 'Mute',
                  onTap: () {
                    ref.read(webrtcServiceProvider).toggleMute(!_muted);
                    setState(() => _muted = !_muted);
                  },
                ),
                _VoiceBtn(
                  icon: Icons.chat_bubble_outline,
                  label: 'Chat',
                  onTap: _openInCallChat,
                ),
                _VoiceBtn(
                  icon: Icons.call_end,
                  label: 'End',
                  bg: AppColors.error,
                  size: 65,
                  onTap: () async {
                    await ref.read(webrtcServiceProvider).endCall();
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  },
                ),
                _VoiceBtn(
                  icon: _speaker ? Icons.volume_up : Icons.volume_down,
                  label: _speaker ? 'Speaker' : 'Earpiece',
                  onTap: () async {
                    await ref
                        .read(webrtcServiceProvider)
                        .toggleSpeaker(!_speaker);
                    setState(() => _speaker = !_speaker);
                  },
                ),
              ],
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }

  void _openInCallChat() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SizedBox(
            height: 420,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'In-call chat',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const Divider(height: 20),
                Expanded(
                  child: _chatMessages.isEmpty
                      ? const Center(
                          child: Text(
                            'No messages yet',
                            style: TextStyle(color: AppColors.textHint),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _chatMessages.length,
                          itemBuilder: (_, i) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Text(_chatMessages[i]),
                          ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _chatCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Message...',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onSubmitted: (_) => _sendChatMsg(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        icon: const Icon(
                          Icons.send,
                          color: AppColors.primaryGreen,
                        ),
                        onPressed: _sendChatMsg,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _sendChatMsg() async {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty) return;
    _chatCtrl.clear();
    await ref.read(webrtcServiceProvider).sendInCallChatMessage(text);
  }
}

class _VoiceBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bg;
  final double size;
  final VoidCallback onTap;
  const _VoiceBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.bg = Colors.white24,
    this.size = 55,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: size * 0.45),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
