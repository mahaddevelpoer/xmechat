import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme.dart';
import '../../services/webrtc_service.dart';
import '../../models/models.dart';

class IncomingCallScreen extends StatefulWidget {
  final CallModel call;
  const IncomingCallScreen({super.key, required this.call});

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  late final String _myId;
  late final WebRTCService _webrtc;
  UserModel? _caller;

  @override
  void initState() {
    super.initState();
    _myId = Supabase.instance.client.auth.currentUser?.id ?? '';
    _webrtc = WebRTCService(_myId);
    _webrtc.onCallEnded = () => Navigator.pop(context);
    _loadCaller();
  }

  Future<void> _loadCaller() async {
    final data = await Supabase.instance.client
        .from('users')
        .select()
        .eq('id', widget.call.callerId)
        .maybeSingle();
    if (data != null && mounted) {
      setState(() => _caller = UserModel.fromMap(data));
    }
  }

  Future<void> _answer() async {
    final isVideo = widget.call.type == CallType.video;
    if (isVideo) {
      Navigator.pushReplacementNamed(context, '/video-call/${widget.call.id}', arguments: {
        'isIncoming': true,
        'sdpOffer': widget.call.sdpOffer,
        'otherUserId': widget.call.callerId,
        'otherUserName': _caller?.name ?? 'Unknown',
      });
    } else {
      Navigator.pushReplacementNamed(context, '/voice-call/${widget.call.id}', arguments: {
        'isIncoming': true,
        'sdpOffer': widget.call.sdpOffer,
        'otherUserId': widget.call.callerId,
        'otherUserName': _caller?.name ?? 'Unknown',
      });
    }
  }

  Future<void> _reject() async {
    try {
      await _webrtc.rejectCall(widget.call.id);
    } catch (_) {}
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.call.type == CallType.video;
    return Scaffold(
      backgroundColor: AppColors.callBg,
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            CircleAvatar(
              radius: 50,
              backgroundColor: AppColors.accentLight,
              child: Icon(
                isVideo ? Icons.videocam : Icons.phone,
                size: 40,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _caller?.name ?? 'Unknown',
              style: AppText.callName,
            ),
            const SizedBox(height: 8),
            Text(
              isVideo ? 'Incoming video call...' : 'Incoming voice call...',
              style: AppText.callTimer,
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _callButton(Icons.call, Colors.green, 'Answer', _answer),
                const SizedBox(width: 48),
                _callButton(Icons.call_end, AppColors.danger, 'Reject', _reject),
              ],
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _callButton(IconData icon, Color color, String label, VoidCallback onPressed) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: color,
          child: IconButton(
            icon: Icon(icon, color: Colors.white),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: AppText.timestamp.copyWith(color: Colors.white70)),
      ],
    );
  }
}
