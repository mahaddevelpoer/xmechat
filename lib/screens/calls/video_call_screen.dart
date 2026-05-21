import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../core/constants/app_colors.dart';
import '../../models/models.dart';
import '../../providers/providers.dart';

class VideoCallScreen extends ConsumerStatefulWidget {
  final String callId;
  final bool isCaller;
  final UserModel? otherUser;
  const VideoCallScreen({
    super.key,
    required this.callId,
    required this.isCaller,
    this.otherUser,
  });

  @override
  ConsumerState<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends ConsumerState<VideoCallScreen> {
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();

  bool _muted = false;
  bool _cameraOff = false;
  bool _speakerOn = true;
  bool _connected = false;

  int _seconds = 0;
  Timer? _timer;

  Offset? _pipOffset;

  final _chatCtrl = TextEditingController();
  final List<String> _chatMessages = [];
  StreamSubscription<String>? _chatSub;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    await _setupWebRTC();
  }

  Future<void> _setupWebRTC() async {
    final webrtc = ref.read(webrtcServiceProvider);
    webrtc.onLocalStream = (stream) {
      if (mounted) setState(() => _localRenderer.srcObject = stream);
    };
    webrtc.onRemoteStream = (stream) {
      if (!mounted) return;
      setState(() {
        _remoteRenderer.srcObject = stream;
        _connected = true;
        _startTimer();
      });
    };
    webrtc.onCallEnded = () {
      if (mounted) Navigator.pop(context);
    };

    _chatSub = webrtc.dataMessages.listen((m) {
      if (!mounted) return;
      setState(() => _chatMessages.add(m));
    });

    // The call may be created/answered before this screen is pushed.
    final localStream = webrtc.localStream;
    final remoteStream = webrtc.remoteStream;
    if (localStream != null) _localRenderer.srcObject = localStream;
    if (remoteStream != null) {
      _remoteRenderer.srcObject = remoteStream;
      _connected = true;
      _startTimer();
    } else if (webrtc.isConnected) {
      _connected = true;
      _startTimer();
    }
  }

  void _startTimer() {
    _timer?.cancel();
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
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _pipOffset ??= Offset(MediaQuery.of(context).size.width - 126, 70);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Remote video (full screen)
          Positioned.fill(
            child: RTCVideoView(
              _remoteRenderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            ),
          ),

          // Overlay when not connected (Calling screen)
          if (!_connected)
            Container(
              color: Colors.black87,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage:
                          widget.otherUser?.avatarUrl.isNotEmpty == true
                          ? NetworkImage(widget.otherUser!.avatarUrl)
                          : null,
                      child: widget.otherUser?.avatarUrl.isEmpty != false
                          ? const Icon(
                              Icons.person,
                              size: 50,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      widget.otherUser?.name ?? 'Unknown',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.isCaller ? 'Calling...' : 'Connecting...',
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 18),
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
                ),
              ),
            ),

          // Local video preview (draggable)
          Positioned(
            left: _pipOffset!.dx,
            top: _pipOffset!.dy,
            width: 110,
            height: 150,
            child: GestureDetector(
              onPanUpdate: (d) {
                setState(() {
                  _pipOffset = Offset(
                    (_pipOffset!.dx + d.delta.dx).clamp(
                      0,
                      MediaQuery.of(context).size.width - 120,
                    ),
                    (_pipOffset!.dy + d.delta.dy).clamp(
                      0,
                      MediaQuery.of(context).size.height - 200,
                    ),
                  );
                });
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: RTCVideoView(
                  _localRenderer,
                  mirror: true,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              ),
            ),
          ),

          // Timer
          if (_connected)
            Positioned(
              top: 60,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  _callDuration,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ),

          // Controls
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _CallBtn(
                  icon: _muted ? Icons.mic_off : Icons.mic,
                  label: _muted ? 'Unmute' : 'Mute',
                  onTap: () {
                    ref.read(webrtcServiceProvider).toggleMute(!_muted);
                    setState(() => _muted = !_muted);
                  },
                ),
                _CallBtn(
                  icon: Icons.chat_bubble_outline,
                  label: 'Chat',
                  onTap: _openInCallChat,
                ),
                _CallBtn(
                  icon: Icons.call_end,
                  label: 'End',
                  color: AppColors.error,
                  size: 60,
                  onTap: () async {
                    await ref.read(webrtcServiceProvider).endCall();
                    if (!context.mounted) return;
                    Navigator.pop(context);
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
                  icon: Icons.cameraswitch,
                  label: 'Flip',
                  onTap: () => ref.read(webrtcServiceProvider).switchCamera(),
                ),
                _CallBtn(
                  icon: _speakerOn ? Icons.volume_up : Icons.volume_off,
                  label: _speakerOn ? 'Speaker' : 'Silent',
                  onTap: () async {
                    await ref
                        .read(webrtcServiceProvider)
                        .toggleSpeaker(!_speakerOn);
                    if (mounted) setState(() => _speakerOn = !_speakerOn);
                  },
                ),
              ],
            ),
          ),
        ],
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

class _CallBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final double size;
  final VoidCallback onTap;
  const _CallBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color = Colors.white30,
    this.size = 48,
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
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: size * 0.5),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
