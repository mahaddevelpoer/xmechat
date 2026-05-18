import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_colors.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';

class VideoCallScreen extends ConsumerStatefulWidget {
  final String callId;
  final bool isCaller;
  final UserModel? otherUser;
  const VideoCallScreen({super.key, required this.callId, required this.isCaller, this.otherUser});
  @override
  ConsumerState<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends ConsumerState<VideoCallScreen> {
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  bool _muted = false, _cameraOff = false, _speakerOn = true;
  bool _connected = false;
  int _seconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initRenderers();
    _setupWebRTC();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  Future<void> _setupWebRTC() async {
    final webrtc = ref.read(webrtcServiceProvider);
    webrtc.onLocalStream = (stream) {
      if (mounted) setState(() => _localRenderer.srcObject = stream);
    };
    webrtc.onRemoteStream = (stream) {
      if (mounted) setState(() {
        _remoteRenderer.srcObject = stream;
        _connected = true;
        _startTimer();
      });
    };
    webrtc.onCallEnded = () {
      if (mounted) context.pop();
    };

    if (widget.isCaller) {
      // Already initiated in calls tab — just set up renderers
      final stream = webrtc.localStream;
      if (stream != null) _localRenderer.srcObject = stream;
    }
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
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        // Remote video (full screen)
        Positioned.fill(
          child: RTCVideoView(_remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
        ),
        // Black overlay when not connected
        if (!_connected)
          Container(color: Colors.black87,
            child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              CircleAvatar(radius: 50, backgroundImage: widget.otherUser?.avatarUrl.isNotEmpty == true
                  ? NetworkImage(widget.otherUser!.avatarUrl) : null,
                child: widget.otherUser?.avatarUrl.isEmpty != false
                    ? const Icon(Icons.person, size: 50, color: Colors.white) : null),
              const SizedBox(height: 20),
              Text(widget.otherUser?.name ?? 'Unknown',
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Connecting...', style: TextStyle(color: Colors.white60, fontSize: 16)),
            ])),
          ),
        // Local video (PiP)
        Positioned(
          top: 60, right: 16, width: 100, height: 140,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: RTCVideoView(_localRenderer, mirror: true,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover),
          ),
        ),
        // Timer
        if (_connected)
          Positioned(top: 60, left: 0, right: 0,
            child: Center(child: Text(_callDuration,
              style: const TextStyle(color: Colors.white, fontSize: 18)))),
        // Controls
        Positioned(
          bottom: 40, left: 0, right: 0,
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _CallBtn(
              icon: _muted ? Icons.mic_off : Icons.mic,
              label: _muted ? 'Unmute' : 'Mute',
              onTap: () {
                ref.read(webrtcServiceProvider).toggleMute(!_muted);
                setState(() => _muted = !_muted);
              },
            ),
            _CallBtn(
              icon: Icons.call_end, label: 'End',
              color: AppColors.error, size: 60,
              onTap: () async {
                await ref.read(webrtcServiceProvider).endCall();
                if (!mounted) return;
                context.pop();
              },
            ),
            _CallBtn(
              icon: _cameraOff ? Icons.videocam_off : Icons.videocam,
              label: _cameraOff ? 'Cam On' : 'Cam Off',
              onTap: () {
                ref.read(webrtcServiceProvider).toggleCamera(!_cameraOff);
                setState(() => _cameraOff = !_cameraOff);
              },
            ),
            _CallBtn(
              icon: Icons.cameraswitch, label: 'Flip',
              onTap: () => ref.read(webrtcServiceProvider).switchCamera(),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _CallBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final double size;
  final VoidCallback onTap;
  const _CallBtn({required this.icon, required this.label, required this.onTap,
    this.color = Colors.white30, this.size = 48});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: size, height: size,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white, size: size * 0.5),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ]),
    );
  }
}
