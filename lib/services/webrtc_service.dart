import 'dart:async';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/supabase_constants.dart';
import '../models/models.dart';

typedef OnRemoteStream = void Function(MediaStream stream);
typedef OnCallEnded = void Function();
typedef OnCallConnected = void Function();
typedef OnDataMessage = void Function(String message);

class WebRTCService {
  final _db = Supabase.instance.client;
  final String _uid;
  WebRTCService(this._uid);

  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  String? _currentCallId;

  RealtimeChannel? _signalChannel; // Supabase Broadcast channel
  RealtimeChannel? _callRowChannel; // DB row updates fallback

  RTCDataChannel? _dataChannel;
  final _dataMessagesCtrl = StreamController<String>.broadcast();
  Timer? _ringTimeoutTimer;
  bool _remoteDescriptionSet = false;
  bool _connected = false;

  OnRemoteStream? onRemoteStream;
  OnCallEnded? onCallEnded;
  OnCallConnected? onCallConnected;
  void Function(MediaStream)? onLocalStream;
  OnDataMessage? onDataMessage;

  final _iceServers = {
    'iceServers': [
      {'urls': SupabaseConstants.stunServer},
      {'urls': SupabaseConstants.stunServer2},
    ],
  };

  Stream<String> get dataMessages => _dataMessagesCtrl.stream;
  MediaStream? get localStream => _localStream;
  MediaStream? get remoteStream => _remoteStream;
  bool get isConnected => _connected;

  // ── Init Local Media ──────────────────────────────
  Future<MediaStream> initLocalStream({bool video = true}) async {
    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': video ? {'facingMode': 'user'} : false,
    });
    onLocalStream?.call(_localStream!);
    return _localStream!;
  }

  // ── Peer Connection ───────────────────────────────
  Future<void> _createPeerConnection() async {
    _peerConnection = await createPeerConnection(_iceServers);

    _localStream?.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });

    _peerConnection!.onTrack = (event) {
      _remoteStream = event.streams.isNotEmpty ? event.streams.first : null;
      if (_remoteStream != null) onRemoteStream?.call(_remoteStream!);
    };

    // ICE via Supabase Broadcast (free)
    _peerConnection!.onIceCandidate = (candidate) async {
      if (_currentCallId == null) return;
      await _sendSignal('ice', {
        'user_id': _uid,
        'candidate': candidate.candidate,
        'sdp_mid': candidate.sdpMid,
        'sdp_mline_index': candidate.sdpMLineIndex,
      });
    };

    _peerConnection!.onConnectionState = (state) async {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _ringTimeoutTimer?.cancel();
        _connected = true;
        onCallConnected?.call();
        final callId = _currentCallId;
        if (callId != null && callId.isNotEmpty) {
          await _db
              .from(SupabaseConstants.callsTable)
              .update({
                'status': 'connected',
                'connected_at': DateTime.now().toUtc().toIso8601String(),
              })
              .eq('id', callId);
        }
      } else if (state ==
              RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        onCallEnded?.call();
      }
    };

    // Data channel for in-call text chat
    _peerConnection!.onDataChannel = (dc) {
      _dataChannel = dc;
      _bindDataChannel(dc);
    };
  }

  Future<void> _ensureSignalChannel(String callId) async {
    if (_signalChannel != null) return;

    final ch = _db.channel('call:$callId');

    ch.onBroadcast(
      event: 'answer',
      callback: (payload) async {
        final data = payload['payload'];
        if (data is! Map) return;
        final sdp = data['sdp']?.toString() ?? '';
        if (sdp.isEmpty) return;
        await _setRemoteAnswer(sdp);
      },
    );

    ch.onBroadcast(
      event: 'ice',
      callback: (payload) async {
        final data = payload['payload'];
        if (data is! Map) return;
        final senderId = data['user_id']?.toString() ?? '';
        if (senderId == _uid) return;
        final cand = data['candidate']?.toString() ?? '';
        final mid = data['sdp_mid']?.toString();
        final mline = data['sdp_mline_index'];
        final idx = mline is int
            ? mline
            : int.tryParse(mline?.toString() ?? '');
        if (cand.isEmpty) return;
        await _peerConnection?.addCandidate(RTCIceCandidate(cand, mid, idx));
      },
    );

    ch.onBroadcast(
      event: 'reject',
      callback: (_) async {
        onCallEnded?.call();
        await dispose();
      },
    );

    ch.onBroadcast(
      event: 'end',
      callback: (_) async {
        onCallEnded?.call();
        await dispose();
      },
    );

    // Backup chat over broadcast if data-channel is not ready.
    ch.onBroadcast(
      event: 'chat',
      callback: (payload) {
        final data = payload['payload'];
        if (data is! Map) return;
        final senderId = data['user_id']?.toString() ?? '';
        if (senderId == _uid) return;
        final msg = data['message']?.toString() ?? '';
        if (msg.isEmpty) return;
        _dataMessagesCtrl.add(msg);
        onDataMessage?.call(msg);
      },
    );

    ch.subscribe();
    _signalChannel = ch;
  }

  Future<void> _sendSignal(String event, Map<String, dynamic> payload) async {
    final callId = _currentCallId;
    if (callId == null || callId.isEmpty) return;
    await _ensureSignalChannel(callId);
    await _signalChannel!.sendBroadcastMessage(event: event, payload: payload);
  }

  Future<void> _setupCallerDataChannel() async {
    final pc = _peerConnection;
    if (pc == null) return;
    final dc = await pc.createDataChannel('chat', RTCDataChannelInit());
    _dataChannel = dc;
    _bindDataChannel(dc);
  }

  void _bindDataChannel(RTCDataChannel dc) {
    dc.onMessage = (msg) {
      if (msg.isBinary) return;
      _dataMessagesCtrl.add(msg.text);
      onDataMessage?.call(msg.text);
    };
  }

  Future<void> sendInCallChatMessage(String message) async {
    final text = message.trim();
    if (text.isEmpty) return;
    if (_dataChannel != null) {
      _dataChannel!.send(RTCDataChannelMessage(text));
      _dataMessagesCtrl.add(text);
    } else {
      await _sendSignal('chat', {'user_id': _uid, 'message': text});
    }
  }

  // ── Initiate Call (Caller) ────────────────────────
  Future<String> initiateCall(String receiverId, {bool isVideo = true}) async {
    await initLocalStream(video: isVideo);
    await _createPeerConnection();
    await _setupCallerDataChannel();

    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    final callData = await _db
        .from(SupabaseConstants.callsTable)
        .insert({
          'caller_id': _uid,
          'receiver_id': receiverId,
          'type': isVideo ? 'video' : 'voice',
          'status': 'ringing',
          // Keep sdp_offer stored for reliability + for incoming popup screen.
          'sdp_offer': offer.sdp,
        })
        .select()
        .single();

    _currentCallId = callData['id'] as String;
    await _ensureSignalChannel(_currentCallId!);
    _listenForCallRowUpdates(_currentCallId!);

    // Per requirement: offer via Supabase Broadcast
    await _sendSignal('offer', {'user_id': _uid, 'sdp': offer.sdp});

    // Auto-end if no answer in 30 seconds
    _ringTimeoutTimer?.cancel();
    _ringTimeoutTimer = Timer(const Duration(seconds: 30), () async {
      final callId = _currentCallId;
      if (callId == null) return;
      final row = await _db
          .from(SupabaseConstants.callsTable)
          .select('status')
          .eq('id', callId)
          .maybeSingle();
      if (row != null && row['status'] == 'ringing') {
        await _db
            .from(SupabaseConstants.callsTable)
            .update({
              'status': 'missed',
              'ended_at': DateTime.now().toUtc().toIso8601String(),
            })
            .eq('id', callId);
        await _sendSignal('end', {'reason': 'timeout', 'user_id': _uid});
        onCallEnded?.call();
        await dispose();
      }
    });

    return _currentCallId!;
  }

  // ── Answer Call (Receiver) ────────────────────────
  Future<void> answerCall(
    String callId,
    String sdpOffer, {
    bool isVideo = true,
  }) async {
    _currentCallId = callId;
    await initLocalStream(video: isVideo);
    await _createPeerConnection();
    await _ensureSignalChannel(callId);

    await _peerConnection!.setRemoteDescription(
      RTCSessionDescription(sdpOffer, 'offer'),
    );
    final answer = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(answer);

    await _db
        .from(SupabaseConstants.callsTable)
        .update({
          'sdp_answer': answer.sdp,
          'status': 'connected',
          'connected_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', callId);

    await _sendSignal('answer', {'user_id': _uid, 'sdp': answer.sdp});
  }

  // ── Reject / Miss / End ───────────────────────────
  Future<void> rejectCall(String callId) async {
    await _db
        .from(SupabaseConstants.callsTable)
        .update({'status': 'rejected'})
        .eq('id', callId);
    _currentCallId = callId;
    await _sendSignal('reject', {'user_id': _uid});
  }

  Future<void> missCall(String callId) async {
    await _db
        .from(SupabaseConstants.callsTable)
        .update({
          'status': 'missed',
          'ended_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', callId);
    _currentCallId = callId;
    await _sendSignal('end', {'user_id': _uid, 'reason': 'missed'});
  }

  Future<void> endCall() async {
    if (_currentCallId != null) {
      await _db
          .from(SupabaseConstants.callsTable)
          .update({
            'status': 'ended',
            'ended_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', _currentCallId!);
      await _sendSignal('end', {'user_id': _uid});
    }
    await dispose();
    onCallEnded?.call();
  }

  void _listenForCallRowUpdates(String callId) {
    // Fallback lifecycle updates (rejected/ended/missed) + answer as backup.
    _callRowChannel = _db
        .channel('call_row:$callId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: SupabaseConstants.callsTable,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: callId,
          ),
          callback: (payload) async {
            final newData = payload.newRecord;
            final status = newData['status']?.toString() ?? '';
            final answer = newData['sdp_answer']?.toString() ?? '';
            if (answer.isNotEmpty) {
              await _setRemoteAnswer(answer);
            }
            if (status == 'rejected' ||
                status == 'ended' ||
                status == 'missed') {
              onCallEnded?.call();
              await dispose();
            }
          },
        )
        .subscribe();
  }

  Future<void> _setRemoteAnswer(String sdp) async {
    if (_remoteDescriptionSet || sdp.isEmpty) return;
    final pc = _peerConnection;
    if (pc == null) return;
    try {
      await pc.setRemoteDescription(RTCSessionDescription(sdp, 'answer'));
      _remoteDescriptionSet = true;
    } catch (_) {
      // Broadcast and DB fallback can both deliver the same answer.
    }
  }

  // ── Mute / Camera / Speaker / Switch ──────────────
  void toggleMute(bool mute) {
    _localStream?.getAudioTracks().forEach((t) => t.enabled = !mute);
  }

  void toggleCamera(bool off) {
    _localStream?.getVideoTracks().forEach((t) => t.enabled = !off);
  }

  Future<void> switchCamera() async {
    final videoTrack = _localStream?.getVideoTracks().firstOrNull;
    if (videoTrack != null) await Helper.switchCamera(videoTrack);
  }

  Future<void> toggleSpeaker(bool enable) async {
    if (_localStream != null) await Helper.setSpeakerphoneOn(enable);
  }

  // ── Incoming Calls Stream ─────────────────────────
  Stream<CallModel?> listenForIncomingCalls() {
    return _db
        .from(SupabaseConstants.callsTable)
        .stream(primaryKey: ['id'])
        .map((rows) {
          final incoming = rows.where(
            (r) => r['receiver_id'] == _uid && r['status'] == 'ringing',
          );
          return incoming.isNotEmpty ? CallModel.fromMap(incoming.first) : null;
        });
  }

  // ── Call History ──────────────────────────────────
  Future<List<CallModel>> fetchCallHistory() async {
    final data = await _db
        .from(SupabaseConstants.callsTable)
        .select('*, caller:caller_id(*), receiver:receiver_id(*)')
        .or('caller_id.eq.$_uid,receiver_id.eq.$_uid')
        .order('created_at', ascending: false)
        .limit(50);
    return data.map<CallModel>((m) {
      final call = CallModel.fromMap(m);
      if (m['caller'] != null) call.caller = UserModel.fromMap(m['caller']);
      if (m['receiver'] != null) {
        call.receiver = UserModel.fromMap(m['receiver']);
      }
      return call;
    }).toList();
  }

  Future<void> dispose() async {
    _ringTimeoutTimer?.cancel();
    await _signalChannel?.unsubscribe();
    await _callRowChannel?.unsubscribe();
    try {
      await _dataChannel?.close();
    } catch (_) {}

    _localStream?.getTracks().forEach((t) => t.stop());
    await _localStream?.dispose();
    await _peerConnection?.close();

    _peerConnection = null;
    _localStream = null;
    _remoteStream = null;
    _currentCallId = null;
    _signalChannel = null;
    _callRowChannel = null;
    _dataChannel = null;
    _remoteDescriptionSet = false;
    _connected = false;
  }
}
