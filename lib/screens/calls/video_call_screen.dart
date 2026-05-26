import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../theme.dart';
import '../../services/webrtc_service.dart';
import '../../models/models.dart';

class VideoCallScreen extends StatefulWidget {
  final String callId;
  final String? otherUserId;
  final String? otherUserName;
  final bool isIncoming;
  final String? sdpOffer;

  const VideoCallScreen({
    super.key,
    required this.callId,
    this.otherUserId,
    this.otherUserName,
    this.isIncoming = false,
    this.sdpOffer,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  CallStatus _status = CallStatus.ringing;
  bool _isMuted = false;
  bool _isCameraOn = true;
  bool _showChat = false;
  final String _timer = '00:00';
  late final WebRTCService _webrtc;
  late final String _myId;
  final _chatCtrl = TextEditingController();
  final List<String> _chatMessages = [];
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();

  @override
  void initState() {
    super.initState();
    _myId = Supabase.instance.client.auth.currentUser?.id ?? '';
    _webrtc = WebRTCService(_myId);
    _initRenderers();
    _webrtc.onCallConnected = () => setState(() => _status = CallStatus.connected);
    _webrtc.onCallEnded = () => Navigator.pop(context);
    _webrtc.onRemoteStream = (stream) {
      _remoteRenderer.srcObject = stream;
      setState(() {});
    };
    _webrtc.onLocalStream = (stream) {
      _localRenderer.srcObject = stream;
      setState(() {});
    };
    _initCall();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  Future<void> _initCall() async {
    try {
      if (widget.isIncoming && widget.sdpOffer != null) {
        await _webrtc.answerCall(widget.callId, widget.sdpOffer!, isVideo: true);
      } else if (!widget.isIncoming) {
        await _webrtc.initiateCall(widget.otherUserId!, isVideo: true);
      }
      setState(() => _status = CallStatus.connected);
    } catch (_) {
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _webrtc.onCallConnected = null;
    _webrtc.onCallEnded = null;
    _webrtc.onRemoteStream = null;
    _webrtc.onLocalStream = null;
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _chatCtrl.dispose();
    super.dispose();
  }

  void _toggleMute() {
    _isMuted = !_isMuted;
    _webrtc.toggleMute(_isMuted);
    setState(() {});
  }

  void _toggleCamera() {
    _isCameraOn = !_isCameraOn;
    _webrtc.toggleCamera(!_isCameraOn);
    setState(() {});
  }

  Future<void> _switchCamera() async {
    await _webrtc.switchCamera();
  }

  Future<void> _endCall() async {
    await _webrtc.endCall();
    if (mounted) Navigator.pop(context);
  }

  void _sendChat() {
    final text = _chatCtrl.text.trim();
    if (text.isEmpty) return;
    _webrtc.sendInCallChatMessage(text);
    _chatMessages.add(text);
    _chatCtrl.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F2318),
      body: Stack(
        children: [
          // Remote video (or placeholder)
          if (_remoteRenderer.srcObject != null)
            RTCVideoView(_remoteRenderer)
          else
            _buildRemotePlaceholder(),
          // Local video (PIP)
          if (_isCameraOn && _localRenderer.srcObject != null)
            Positioned(
              right: 16, top: 56,
              child: GestureDetector(
                onTap: _switchCamera,
                child: Container(
                  width: 120, height: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: RTCVideoView(_localRenderer),
                  ),
                ),
              ),
            ),
          // Top bar
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 40, 16, 8),
              decoration: const BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black54, Colors.transparent]),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.accentLight,
                    child: Text(
                      (widget.otherUserName ?? '?')[0].toUpperCase(),
                      style: TextStyle(fontSize: 14, color: AppColors.accent, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(widget.otherUserName ?? 'Connecting...', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                  const Spacer(),
                  Text(_timer, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
          ),
          // Bottom controls
          Positioned(
            bottom: 32, left: 0, right: 0,
            child: _buildControls(),
          ),
          // Chat overlay
          if (_showChat) _buildChatOverlay(),
        ],
      ),
    );
  }

  Widget _buildRemotePlaceholder() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: AppColors.accentLight,
            child: Text(
              (widget.otherUserName ?? '?')[0].toUpperCase(),
              style: TextStyle(fontSize: 40, color: AppColors.accent, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 16),
          Text(widget.otherUserName ?? 'Connecting...', style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(_status == CallStatus.ringing ? 'Ringing...' : 'Connecting...', style: const TextStyle(fontSize: 14, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _controlBtn(Icons.mic_outlined, _isMuted ? AppColors.danger : Colors.white70, _toggleMute),
          _controlBtn(Icons.videocam_outlined, _isCameraOn ? AppColors.accent : AppColors.danger, _toggleCamera),
          _controlBtn(Icons.call_end, AppColors.danger, _endCall, size: 60),
          _controlBtn(Icons.flip_camera_ios_outlined, Colors.white70, _switchCamera),
          _controlBtn(Icons.chat_outlined, _showChat ? AppColors.accent : Colors.white70, () => setState(() => _showChat = !_showChat)),
        ],
      ),
    );
  }

  Widget _controlBtn(IconData icon, Color color, VoidCallback onTap, {double size = 48}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.2), shape: BoxShape.circle),
        child: Icon(icon, color: color, size: size * 0.45),
      ),
    );
  }

  Widget _buildChatOverlay() {
    return Positioned(
      right: 0, top: 0, bottom: 0,
      child: Container(
        width: 280,
        color: const Color(0xFF0F2318),
        child: Column(
          children: [
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Text('Chat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close, color: Colors.white70, size: 20), onPressed: () => setState(() => _showChat = false)),
                ],
              ),
            ),
            const Divider(color: Colors.white24),
            Expanded(
              child: ListView.builder(
                itemCount: _chatMessages.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Text(_chatMessages[i], style: const TextStyle(color: Colors.white, fontSize: 13)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _chatCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true, fillColor: Colors.white12,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.send, color: AppColors.accent, size: 20), onPressed: _sendChat),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
