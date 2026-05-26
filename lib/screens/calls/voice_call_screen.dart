import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme.dart';
import '../../services/webrtc_service.dart';
import '../../models/models.dart';

class VoiceCallScreen extends StatefulWidget {
  final String callId;
  final String? otherUserId;
  final String? otherUserName;
  final bool isIncoming;
  final String? sdpOffer;

  const VoiceCallScreen({
    super.key,
    required this.callId,
    this.otherUserId,
    this.otherUserName,
    this.isIncoming = false,
    this.sdpOffer,
  });

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen> {
  CallStatus _status = CallStatus.ringing;
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _showChat = false;
  final String _timer = '00:00';
  late final WebRTCService _webrtc;
  late final String _myId;
  final _chatCtrl = TextEditingController();
  final List<String> _chatMessages = [];

  @override
  void initState() {
    super.initState();
    _myId = Supabase.instance.client.auth.currentUser?.id ?? '';
    _webrtc = WebRTCService(_myId);
    _webrtc.onCallConnected = () => setState(() => _status = CallStatus.connected);
    _webrtc.onCallEnded = () => Navigator.pop(context);
    _webrtc.onRemoteStream = (_) {};
    _initCall();
  }

  Future<void> _initCall() async {
    try {
      if (widget.isIncoming && widget.sdpOffer != null) {
        await _webrtc.answerCall(widget.callId, widget.sdpOffer!, isVideo: false);
      } else if (!widget.isIncoming) {
        await _webrtc.initiateCall(widget.otherUserId!, isVideo: false);
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
    _chatCtrl.dispose();
    super.dispose();
  }

  void _toggleMute() {
    _isMuted = !_isMuted;
    _webrtc.toggleMute(_isMuted);
    setState(() {});
  }

  void _toggleSpeaker() {
    _isSpeakerOn = !_isSpeakerOn;
    _webrtc.toggleSpeaker(_isSpeakerOn);
    setState(() {});
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
          Column(
            children: [
              const Spacer(),
              CircleAvatar(
                radius: 50,
                backgroundColor: AppColors.accentLight,
                child: Text(
                  (widget.otherUserName ?? '?')[0].toUpperCase(),
                  style: TextStyle(fontSize: 40, color: AppColors.accent, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 16),
              Text(widget.otherUserName ?? 'Connecting...', style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(
                _status == CallStatus.ringing ? 'Calling...' : _status == CallStatus.connected ? _timer : 'Connecting...',
                style: const TextStyle(fontSize: 14, color: Colors.white70),
              ),
              const Spacer(),
              _buildControls(),
              const SizedBox(height: 48),
            ],
          ),
          if (_showChat) _buildChatOverlay(),
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
          _controlBtn(Icons.volume_up_outlined, _isSpeakerOn ? AppColors.accent : Colors.white70, _toggleSpeaker),
          _controlBtn(Icons.call_end, AppColors.danger, _endCall, size: 64),
          _controlBtn(Icons.chat_outlined, AppColors.accent, () => setState(() => _showChat = !_showChat)),
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
        width: 300,
        color: const Color(0xFF0F2318),
        child: Column(
          children: [
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  const Text('In-Call Chat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
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
