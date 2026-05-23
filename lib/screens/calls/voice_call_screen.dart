import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/common/user_avatar.dart';

class VoiceCallScreen extends ConsumerStatefulWidget {
  final String callId;
  final bool isCaller;
  final UserModel? remoteUser;
  final String sdpOffer; // required for receiver to answer

  const VoiceCallScreen({
    super.key,
    required this.callId,
    required this.isCaller,
    this.remoteUser,
    this.sdpOffer = '',
  });

  @override
  ConsumerState<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends ConsumerState<VoiceCallScreen> {
  bool _muted      = false;
  bool _speaker    = false;
  bool _connecting = true;
  bool _ended      = false;

  Timer? _durationTimer;
  int   _seconds = 0;

  @override
  void initState() {
    super.initState();
    _setupCallbacks();
    if (!widget.isCaller) {
      _answerCall();
    }
    // For caller: call was already initiated in PrivateChatScreen.
    // Callbacks above will fire when connected.
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    super.dispose();
  }

  void _setupCallbacks() {
    final webrtc = ref.read(webrtcServiceProvider);
    webrtc.onCallConnected = () {
      if (mounted) {
        setState(() => _connecting = false);
        _startTimer();
      }
    };
    webrtc.onCallEnded = () {
      if (mounted) setState(() { _ended = true; _connecting = false; });
      _durationTimer?.cancel();
      _scheduleClose();
    };
  }

  Future<void> _answerCall() async {
    try {
      String offer = widget.sdpOffer;
      // Fetch sdp_offer from DB if not passed
      if (offer.isEmpty) {
        final row = await Supabase.instance.client
            .from('calls')
            .select('sdp_offer')
            .eq('id', widget.callId)
            .single();
        offer = row['sdp_offer'] as String? ?? '';
      }
      await ref
          .read(webrtcServiceProvider)
          .answerCall(widget.callId, offer, isVideo: false);
    } catch (e) {
      if (mounted) setState(() { _connecting = false; _ended = true; });
    }
  }

  void _startTimer() {
    _durationTimer =
        Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  void _scheduleClose() {
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) context.canPop() ? context.pop() : context.go('/home');
    });
  }

  String get _durationLabel {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _endCall() async {
    _durationTimer?.cancel();
    try {
      await ref.read(webrtcServiceProvider).endCall();
    } catch (_) {}
    if (mounted) {
      setState(() => _ended = true);
      _scheduleClose();
    }
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    ref.read(webrtcServiceProvider).toggleMute(_muted);
  }

  void _toggleSpeaker() {
    setState(() => _speaker = !_speaker);
    ref.read(webrtcServiceProvider).toggleSpeaker(_speaker);
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.remoteUser;

    return Scaffold(
      backgroundColor: const Color(0xFF1A2B1A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Avatar with glow
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.accent, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accent.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: ClipOval(
                child: UserAvatar(
                  imageUrl: user?.avatarUrl,
                  name: user?.name ?? '?',
                  size: 110,
                ),
              ),
            ),
            const SizedBox(height: 24),

            Text(
              user?.name ?? 'Unknown',
              style: AppText.heading.copyWith(color: AppColors.white),
            ),
            const SizedBox(height: 8),

            Text(
              _ended
                  ? 'Call ended'
                  : _connecting
                      ? (widget.isCaller ? 'Calling...' : 'Connecting...')
                      : _durationLabel,
              style: AppText.bodyGrey.copyWith(
                color: _ended ? AppColors.danger : Colors.white54,
              ),
            ),
            const SizedBox(height: 60),

            if (!_ended)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _CallButton(
                    icon: _muted ? Icons.mic_off : Icons.mic,
                    label: _muted ? 'Unmute' : 'Mute',
                    onTap: _toggleMute,
                    active: _muted,
                  ),
                  const SizedBox(width: 20),
                  _CallButton(
                    icon: Icons.call_end_rounded,
                    label: 'End',
                    onTap: _endCall,
                    color: AppColors.danger,
                    size: 64,
                  ),
                  const SizedBox(width: 20),
                  _CallButton(
                    icon: _speaker
                        ? Icons.volume_up_rounded
                        : Icons.volume_down_rounded,
                    label: _speaker ? 'Speaker' : 'Earpiece',
                    onTap: _toggleSpeaker,
                    active: _speaker,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool active;
  final double size;

  const _CallButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.active = false,
    this.size = 54,
  });

  @override
  Widget build(BuildContext context) {
    final bg = color ??
        (active ? AppColors.white : const Color(0xFF2C3E2C));

    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: bg,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              icon,
              size: size * 0.45,
              color: color != null
                  ? AppColors.white
                  : active
                      ? AppColors.textDark
                      : AppColors.white,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: AppText.caption.copyWith(color: Colors.white54)),
      ],
    );
  }
}
