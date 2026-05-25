import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';
import '../../widgets/common/user_avatar.dart';

class VideoCallScreen extends ConsumerStatefulWidget {
  final String callId;
  final bool isCaller;
  final UserModel? remoteUser;
  final String sdpOffer; // for receiver to answer

  const VideoCallScreen({
    super.key,
    required this.callId,
    required this.isCaller,
    this.remoteUser,
    this.sdpOffer = '',
  });

  @override
  ConsumerState<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends ConsumerState<VideoCallScreen> {
  final RTCVideoRenderer _localRenderer  = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  bool _muted           = false;
  bool _cameraOff       = false;
  bool _speaker         = true;
  bool _connecting      = true;
  bool _ended           = false;
  bool _controlsVisible = true;

  Timer? _durationTimer;
  Timer? _controlsTimer;
  int   _seconds = 0;

  @override
  void initState() {
    super.initState();
    _initRenderers();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    _setupCallbacks();
    if (!widget.isCaller) {
      await _answerCall();
    } else {
      // Caller: streams already started in initiateCall
      final webrtc = ref.read(webrtcServiceProvider);
      _localRenderer.srcObject  = webrtc.localStream;
      _remoteRenderer.srcObject = webrtc.remoteStream;
      if (mounted) setState(() {});
    }
  }

  void _setupCallbacks() {
    final webrtc = ref.read(webrtcServiceProvider);
    webrtc.onCallConnected = () {
      if (mounted) {
        setState(() => _connecting = false);
        _localRenderer.srcObject  = webrtc.localStream;
        _remoteRenderer.srcObject = webrtc.remoteStream;
        _startTimer();
      }
    };
    webrtc.onCallEnded = () {
      _durationTimer?.cancel();
      _controlsTimer?.cancel();
      if (mounted) setState(() { _ended = true; _connecting = false; });
      _scheduleClose();
    };
    webrtc.onRemoteStream = (stream) {
      if (mounted) {
        _remoteRenderer.srcObject = stream;
        setState(() {});
      }
    };
    webrtc.onLocalStream = (stream) {
      if (mounted) {
        _localRenderer.srcObject = stream;
        setState(() {});
      }
    };
  }

  Future<void> _answerCall() async {
    try {
      String offer = widget.sdpOffer;
      if (offer.isEmpty) {
        final row = await Supabase.instance.client
            .from('calls')
            .select('sdp_offer')
            .eq('id', widget.callId)
            .single();
        offer = row['sdp_offer'] as String? ?? '';
      }
      final webrtc = ref.read(webrtcServiceProvider);
      await webrtc.answerCall(widget.callId, offer, isVideo: true);
      if (mounted) {
        _localRenderer.srcObject  = webrtc.localStream;
        _remoteRenderer.srcObject = webrtc.remoteStream;
        setState(() {});
      }
    } catch (e) {
      if (mounted) setState(() { _connecting = false; _ended = true; });
    }
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _controlsTimer?.cancel();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  void _startTimer() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
    // Auto-hide controls after 4 seconds
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && !_ended) setState(() => _controlsVisible = false);
    });
  }

  void _scheduleClose() {
    Future.delayed(const Duration(milliseconds: 800), () {
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
    _controlsTimer?.cancel();
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

  void _toggleCamera() {
    setState(() => _cameraOff = !_cameraOff);
    ref.read(webrtcServiceProvider).toggleCamera(_cameraOff);
  }

  void _toggleSpeaker() {
    setState(() => _speaker = !_speaker);
    ref.read(webrtcServiceProvider).toggleSpeaker(_speaker);
  }

  Future<void> _flipCamera() async {
    await ref.read(webrtcServiceProvider).switchCamera();
  }

  void _onTapScreen() {
    setState(() => _controlsVisible = true);
    _controlsTimer?.cancel();
    _controlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && !_ended) setState(() => _controlsVisible = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _onTapScreen,
        child: Stack(
          children: [
            // ── Remote video (full screen) ─────────────
            Positioned.fill(
              child: _ended
                  ? const Center(
                      child: Text('Call ended',
                              style: AppText.custom(
                                  color: Colors.white54,
                                  fontSize: 18)))
                  : _connecting && _remoteRenderer.srcObject == null
                      ? _ConnectingView(
                          user: widget.remoteUser,
                          isCaller: widget.isCaller,
                        )
                      : RTCVideoView(
                          _remoteRenderer,
                          objectFit: RTCVideoViewObjectFit
                              .RTCVideoViewObjectFitCover,
                        ),
            ),

            // ── Local video (full-screen during connecting, pip after) ─────────
            if (_connecting && !_ended && _localRenderer.srcObject != null)
              Positioned.fill(
                child: ClipRRect(
                  child: _cameraOff
                      ? Container(
                          color: const Color(0xFF1A2B1A),
                          child: const Center(
                            child: Icon(Icons.videocam_off,
                                color: Colors.white54, size: 48),
                          ),
                        )
                      : RTCVideoView(
                          _localRenderer,
                          mirror: true,
                          objectFit: RTCVideoViewObjectFit
                              .RTCVideoViewObjectFitCover,
                        ),
                ),
              ),

            // ── Frosted overlay on local preview during connecting ─────────
            if (_connecting && !_ended)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.3),
                        Colors.transparent,
                        Colors.black.withOpacity(0.3),
                      ],
                    ),
                  ),
                ),
              ),

            // ── Remote connecting overlay ─────────────
            if (_connecting && !_ended)
              Positioned.fill(
                child: _ConnectingView(
                  user: widget.remoteUser,
                  isCaller: widget.isCaller,
                ),
              ),

            // ── Local video (bottom-right pip) AFTER connecting ─────────
            if (!_connecting && !_ended)
              Positioned(
                right: 16,
                bottom: 120,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 100,
                    height: 140,
                    child: _cameraOff
                        ? Container(
                            color: const Color(0xFF1A2B1A),
                            child: const Center(
                              child: Icon(Icons.videocam_off,
                                  color: Colors.white54, size: 32),
                            ),
                          )
                        : RTCVideoView(
                            _localRenderer,
                            mirror: true,
                            objectFit: RTCVideoViewObjectFit
                                .RTCVideoViewObjectFitCover,
                          ),
                  ),
                ),
              ),

            // ── Top status bar ─────────────────────────
            AnimatedOpacity(
              opacity: _controlsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding:
                      const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back,
                            color: AppColors.white),
                        onPressed: _endCall,
                      ),
                      const Spacer(),
                      Column(
                        children: [
                          Text(
                            widget.remoteUser?.name ?? 'Video Call',
                            style: AppText.name
                                .copyWith(color: AppColors.white),
                          ),
                          Text(
                            _ended
                                ? 'Call ended'
                                : _connecting
                                    ? 'Connecting...'
                                    : _durationLabel,
                            style: AppText.caption
                                .copyWith(color: Colors.white54),
                          ),
                        ],
                      ),
                      const Spacer(),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
              ),
            ),

            // ── Bottom controls ────────────────────────
            AnimatedOpacity(
              opacity: _controlsVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding:
                      const EdgeInsets.fromLTRB(24, 20, 24, 32),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.8),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _VideoCallBtn(
                        icon: _muted ? Icons.mic_off : Icons.mic,
                        label: _muted ? 'Unmute' : 'Mute',
                        onTap: _toggleMute,
                        active: _muted,
                      ),
                      _VideoCallBtn(
                        icon: _cameraOff
                            ? Icons.videocam_off
                            : Icons.videocam,
                        label: _cameraOff ? 'Cam Off' : 'Camera',
                        onTap: _toggleCamera,
                        active: _cameraOff,
                      ),
                      // End call
                      Column(
                        children: [
                          GestureDetector(
                            onTap: _endCall,
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: AppColors.danger,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.danger
                                        .withOpacity(0.4),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                  Icons.call_end_rounded,
                                  color: AppColors.white,
                                  size: 30),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text('End',
                              style: AppText.custom(
                                  fontSize: 11,
                                  color: Colors.white54)),
                        ],
                      ),
                      _VideoCallBtn(
                        icon: _speaker
                            ? Icons.volume_up_rounded
                            : Icons.volume_off_rounded,
                        label: 'Speaker',
                        onTap: _toggleSpeaker,
                        active: _speaker,
                      ),
                      _VideoCallBtn(
                        icon: Icons.flip_camera_ios_outlined,
                        label: 'Flip',
                        onTap: _flipCamera,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectingView extends StatelessWidget {
  final UserModel? user;
  final bool isCaller;
  const _ConnectingView({required this.user, required this.isCaller});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0D1A0D),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.accent, width: 2),
              ),
              child: ClipOval(
                child: UserAvatar(
                  imageUrl: user?.avatarUrl,
                  name: user?.name ?? '?',
                  size: 100,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              user?.name ?? 'Unknown',
              style: AppText.heading.copyWith(color: AppColors.white),
            ),
            const SizedBox(height: 8),
            Text(
              isCaller ? 'Calling...' : 'Incoming video call...',
              style:
                  AppText.bodyGrey.copyWith(color: Colors.white54),
            ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.accent),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoCallBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  const _VideoCallBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: active
                  ? AppColors.white
                  : Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon,
                size: 22,
                color: active ? AppColors.textDark : AppColors.white),
          ),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: AppText.custom(
                fontSize: 10,
                color: Colors.white54)),
      ],
    );
  }
}
