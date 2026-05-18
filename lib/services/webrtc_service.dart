import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/supabase_constants.dart';
import '../models/models.dart';

typedef OnRemoteStream = void Function(MediaStream stream);
typedef OnCallEnded = void Function();
typedef OnCallConnected = void Function();

class WebRTCService {
  final _db = Supabase.instance.client;
  final String _uid;
  WebRTCService(this._uid);

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  String? _currentCallId;
  RealtimeChannel? _channel;

  OnRemoteStream? onRemoteStream;
  OnCallEnded? onCallEnded;
  OnCallConnected? onCallConnected;
  void Function(MediaStream)? onLocalStream;

  final _iceServers = {
    'iceServers': [
      {'urls': SupabaseConstants.stunServer},
      {'urls': SupabaseConstants.stunServer2},
    ]
  };

  // ── Init Local Media ──────────────────────────────
  Future<MediaStream> initLocalStream({bool video = true}) async {
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': video ? {'facingMode': 'user'} : false,
    });
    onLocalStream?.call(_localStream!);
    return _localStream!;
  }

  // ── Create Peer Connection ────────────────────────
  Future<void> _createPeerConnection() async {
    _peerConnection = await createPeerConnection(_iceServers);

    _localStream?.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });

    _peerConnection!.onTrack = (event) {
      _remoteStream = event.streams.firstOrNull;
      if (_remoteStream != null) onRemoteStream?.call(_remoteStream!);
    };

    _peerConnection!.onIceCandidate = (candidate) async {
      if (_currentCallId == null) return;
      await _db.from(SupabaseConstants.iceCandidatesTable).insert({
        'call_id': _currentCallId, 'sender_id': _uid,
        'candidate': candidate.toMap().toString(),
      });
    };

    _peerConnection!.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        onCallConnected?.call();
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        onCallEnded?.call();
      }
    };
  }

  // ── Initiate Call (Caller) ────────────────────────
  Future<String> initiateCall(String receiverId, {bool isVideo = true}) async {
    await initLocalStream(video: isVideo);
    await _createPeerConnection();

    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    final callData = await _db.from(SupabaseConstants.callsTable).insert({
      'caller_id': _uid, 'receiver_id': receiverId,
      'type': isVideo ? 'video' : 'voice',
      'status': 'ringing', 'sdp_offer': offer.sdp,
    }).select().single();

    _currentCallId = callData['id'] as String;
    _listenForAnswer(_currentCallId!);
    _listenForIceCandidates(_currentCallId!);
    return _currentCallId!;
  }

  // ── Answer Call (Receiver) ────────────────────────
  Future<void> answerCall(String callId, String sdpOffer, {bool isVideo = true}) async {
    _currentCallId = callId;
    await initLocalStream(video: isVideo);
    await _createPeerConnection();

    await _peerConnection!.setRemoteDescription(RTCSessionDescription(sdpOffer, 'offer'));
    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    await _db.from(SupabaseConstants.callsTable).update({
      'sdp_answer': answer.sdp, 'status': 'connected',
      'connected_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', callId);

    _listenForIceCandidates(callId);
  }

  // ── Reject Call ───────────────────────────────────
  Future<void> rejectCall(String callId) async {
    await _db.from(SupabaseConstants.callsTable)
        .update({'status': 'rejected'}).eq('id', callId);
  }

  // ── End Call ──────────────────────────────────────
  Future<void> endCall() async {
    if (_currentCallId != null) {
      await _db.from(SupabaseConstants.callsTable).update({
        'status': 'ended',
        'ended_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', _currentCallId!);
    }
    await dispose();
    onCallEnded?.call();
  }

  void _listenForAnswer(String callId) {
    _channel = _db.channel('call_$callId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: SupabaseConstants.callsTable,
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'id', value: callId),
          callback: (payload) async {
            final newData = payload.newRecord;
            if (newData['sdp_answer'] != null && newData['sdp_answer'] != '') {
              await _peerConnection?.setRemoteDescription(
                RTCSessionDescription(newData['sdp_answer'], 'answer'),
              );
            }
            if (newData['status'] == 'rejected' || newData['status'] == 'ended') {
              onCallEnded?.call();
            }
          },
        )
        .subscribe();
  }

  void _listenForIceCandidates(String callId) {
    _db.channel('ice_$callId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: SupabaseConstants.iceCandidatesTable,
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'call_id', value: callId),
          callback: (payload) async {
            final data = payload.newRecord;
            if (data['sender_id'] != _uid) {
              // Parse and add ICE candidate
              final candidateStr = data['candidate'] as String;
              // Simplified: in real app parse the map properly
              await _peerConnection?.addCandidate(
                RTCIceCandidate(candidateStr, '', 0),
              );
            }
          },
        )
        .subscribe();
  }

  // ── Mute / Unmute ─────────────────────────────────
  void toggleMute(bool mute) {
    _localStream?.getAudioTracks().forEach((t) => t.enabled = !mute);
  }

  // ── Camera On/Off ─────────────────────────────────
  void toggleCamera(bool off) {
    _localStream?.getVideoTracks().forEach((t) => t.enabled = !off);
  }

  // ── Switch Camera ─────────────────────────────────
  Future<void> switchCamera() async {
    final videoTrack = _localStream?.getVideoTracks().firstOrNull;
    if (videoTrack != null) await Helper.switchCamera(videoTrack);
  }

  // ── Speaker Toggle ────────────────────────────────
  Future<void> toggleSpeaker(bool enable) async {
    if (_localStream != null) await Helper.setSpeakerphoneOn(enable);
  }

  // ── Listen for Incoming Calls ─────────────────────
  Stream<CallModel?> listenForIncomingCalls() {
    return _db.from(SupabaseConstants.callsTable)
        .stream(primaryKey: ['id'])
        .eq('receiver_id', _uid)
        .eq('status', 'ringing')
        .map((rows) => rows.isNotEmpty ? CallModel.fromMap(rows.first) : null);
  }

  // ── Fetch Call History ────────────────────────────
  Future<List<CallModel>> fetchCallHistory() async {
    final data = await _db.from(SupabaseConstants.callsTable)
        .select('*, caller:caller_id(*), receiver:receiver_id(*)')
        .or('caller_id.eq.$_uid,receiver_id.eq.$_uid')
        .order('created_at', ascending: false)
        .limit(50);
    return data.map<CallModel>((m) {
      final call = CallModel.fromMap(m);
      if (m['caller'] != null) call.caller = UserModel.fromMap(m['caller']);
      if (m['receiver'] != null) call.receiver = UserModel.fromMap(m['receiver']);
      return call;
    }).toList();
  }

  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;

  Future<void> dispose() async {
    _channel?.unsubscribe();
    _localStream?.getTracks().forEach((t) => t.stop());
    await _localStream?.dispose();
    await _peerConnection?.close();
    _peerConnection = null;
    _localStream = null;
    _remoteStream = null;
    _currentCallId = null;
  }
}
